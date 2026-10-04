;;; lens-navigation-display.el --- Scope crumbs and successful jump feedback -*- lexical-binding: t; -*-
(require 'breadcrumb)
(require 'pulsar)
(require 'cl-lib)

(setq breadcrumb-imenu-max-length 0.65
      breadcrumb-project-max-length 0.25
      breadcrumb-idle-time 0.5
      pulsar-delay 0.04
      pulsar-iterations 4
      pulsar-face 'pulsar-yellow
      pulsar-pulse-functions nil
      pulsar-pulse-region-functions nil
      pulsar-pulse-on-window-change nil)

(defconst lens-breadcrumb-header '(:eval (lens-breadcrumb-header-text)))

(defun lens-breadcrumb-namespace ()
  "Return an unambiguous Clojure namespace from Eglot's semantic index.
A namespace declaration is file context, not a range enclosing defns."
  (when (and (bound-and-true-p eglot--managed-mode)
             (eq (lens-eglot-language) 'clojure))
    (let ((names (cl-loop for entry in imenu--index-alist
                          for name = (car entry)
                          when (and (stringp name)
                                    (equal (get-text-property 0 'breadcrumb-kind name)
                                           "Namespace"))
                          collect name)))
      (when (= (length names) 1) (car names)))))

(defun lens-breadcrumb-header-text ()
  "Display actual symbol scope first and project path second.
Without Eglot the native textual Imenu approximation is explicitly labelled."
  (let* ((scope (or (breadcrumb-imenu-crumbs) ""))
         (namespace (lens-breadcrumb-namespace))
         (width (max 20 (window-body-width)))
         (structure (concat
                     (unless (bound-and-true-p eglot--managed-mode) "[文本] ")
                     (when (and namespace
                                (not (equal (substring-no-properties scope)
                                            (substring-no-properties namespace))))
                       (concat namespace " · "))
                     scope))
         (path (breadcrumb-project-crumbs))
         (structure (truncate-string-to-width structure (floor (* width 0.70)) nil nil "…"))
         (remaining (max 0 (- width (string-width structure) 6))))
    (concat " " structure
            (when (and path (> remaining 8))
              (concat "  |  " (truncate-string-to-width path remaining nil nil "…"))))))

(define-minor-mode lens-breadcrumb-mode
  "Use Breadcrumb in language files that do not already own a header line.
Existing headers and which-function displays keep their established layout."
  :lighter nil
  (if lens-breadcrumb-mode
      (if (or header-line-format (bound-and-true-p which-function-mode))
          (setq lens-breadcrumb-mode nil)
        (setq-local header-line-format lens-breadcrumb-header))
    (when (equal header-line-format lens-breadcrumb-header)
      (setq-local header-line-format nil))))

(defun lens-breadcrumb-document-symbol-node (symbol)
  "Preserve one LSP DocumentSymbol's name, range and actual children.
Compatibility for Emacs 29 Eglot, which otherwise flattens these nodes."
  (let* ((range (eglot--range-region (plist-get symbol :range)))
         (name (propertize (plist-get symbol :name)
                           'breadcrumb-region range
                           'breadcrumb-kind
                           (alist-get (plist-get symbol :kind) eglot--symbol-kind-names "Unknown")))
         (children (plist-get symbol :children)))
    (cons name (if (> (length children) 0)
                   (mapcar #'lens-breadcrumb-document-symbol-node children)
                 (car range)))))

(defun lens-breadcrumb-eglot-imenu (original &rest args)
  "Retain DocumentSymbol hierarchy in old Eglot for supported header buffers.
New Eglot supplies these range properties itself.  SymbolInformation servers
retain their native index; no hierarchy is inferred from source text."
  (if (and lens-breadcrumb-mode (lens-eglot-language)
           (not (fboundp 'eglot--imenu-DocumentSymbol)))
      (let ((symbols (jsonrpc-request
                      (eglot-current-server) :textDocument/documentSymbol
                      (list :textDocument (eglot--TextDocumentIdentifier))
                      :cancel-on-input non-essential)))
        (if (cl-every (lambda (symbol) (and (plist-get symbol :range)
                                            (plist-get symbol :selectionRange))) symbols)
            (mapcar #'lens-breadcrumb-document-symbol-node symbols)
          (apply original args)))
    (apply original args)))
(advice-add 'eglot-imenu :around #'lens-breadcrumb-eglot-imenu)

(defun lens-breadcrumb-invalidate ()
  "Refresh Imenu when Eglot starts or stops, even without a text edit."
  (when lens-breadcrumb-mode
    (when breadcrumb--idle-timer (cancel-timer breadcrumb--idle-timer))
    (setq imenu--index-alist nil
          breadcrumb--idle-timer nil
          breadcrumb--last-update-tick -1
          breadcrumb--ipath-plain-cache nil)
    (force-mode-line-update)))
(add-hook 'eglot-managed-mode-hook #'lens-breadcrumb-invalidate)

(defun lens-navigation-display-setup ()
  "Enable quiet navigation feedback only for Clojure and OCaml files."
  (when (and buffer-file-name (lens-eglot-language))
    (pulsar-mode 1)
    (lens-breadcrumb-mode 1)))
(dolist (mode (append lens-clojure-modes lens-ocaml-modes))
  (add-hook (intern (format "%s-hook" mode)) #'lens-navigation-display-setup t))

(defvar lens-pulse-last-location nil)
(defun lens-pulse-reset () (setq lens-pulse-last-location nil))
(add-hook 'pre-command-hook #'lens-pulse-reset)

(defun lens-pulse-successful-jump (&rest _)
  "Pulse a successful source jump once, excluding minibuffer previews."
  (when (and (lens-eglot-language) (bound-and-true-p pulsar-mode)
             (not (active-minibuffer-window)))
    (let ((location (cons (current-buffer) (point))))
      (unless (equal location lens-pulse-last-location)
        (setq lens-pulse-last-location location)
        (pulsar-pulse-line)))))

(defun lens-pulse-xref ()
  "Use Pulsar in Code Lens source buffers and native xref feedback elsewhere."
  (if (and (lens-eglot-language) (bound-and-true-p pulsar-mode))
      (lens-pulse-successful-jump)
    (xref-pulse-momentarily)))
(dolist (hook '(xref-after-jump-hook xref-after-return-hook))
  (remove-hook hook #'xref-pulse-momentarily)
  (add-hook hook #'lens-pulse-xref))
(add-hook 'consult-after-jump-hook #'lens-pulse-successful-jump)

(defun lens-pulse-text-definition (&rest _)
  "Add feedback to the successful non-LSP current-file fallback."
  (unless (bound-and-true-p eglot--managed-mode)
    (lens-pulse-successful-jump)))
(advice-add 'lens-definition :after #'lens-pulse-text-definition)

(defun lens-pulse-embark-grep (original &rest args)
  "Avoid Embark's second native pulse after the Consult jump hook."
  (let ((native (symbol-function 'pulse-momentary-highlight-one-line)))
    (cl-letf (((symbol-function 'pulse-momentary-highlight-one-line)
               (lambda (&rest pulse-args)
                 (if (and (lens-eglot-language) (bound-and-true-p pulsar-mode))
                     (lens-pulse-successful-jump)
                   (apply native pulse-args)))))
	     (apply original args))))
(advice-add 'embark-consult-goto-grep :around #'lens-pulse-embark-grep)
(provide 'lens-navigation-display)
