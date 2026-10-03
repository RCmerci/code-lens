;;; lens-lsp.el --- Automatic language navigation -*- lexical-binding: t; -*-
(require 'eglot)

(defcustom lens-eglot-auto-start t
  "Automatically connect Clojure and OCaml source buffers to Eglot."
  :type 'boolean :group 'eglot)
(defconst lens-clojure-modes
  '(clojure-mode clojurescript-mode clojurec-mode clojure-ts-mode
                 clojurescript-ts-mode clojurec-ts-mode))
(defconst lens-ocaml-modes '(tuareg-mode caml-mode ocaml-ts-mode))
(defvar-local lens-eglot-auto-pending nil)

(defun lens-eglot-language ()
  "Return the supported language for the current mode, including derived modes."
  (cond ((apply #'derived-mode-p lens-clojure-modes) 'clojure)
        ((apply #'derived-mode-p lens-ocaml-modes) 'ocaml)))

(defun lens-eglot-contact (&optional _interactive)
  "Resolve the current language server to its real executable in the launch PATH."
  (let* ((language (lens-eglot-language))
         (name (pcase language ('clojure "clojure-lsp") ('ocaml "ocamllsp")))
         (program (and name (executable-find name))))
    (unless program
      (user-error "Code Lens: %s is absent from PATH; text navigation remains available"
                  (or name "this language's server")))
    (list program)))

(dolist (modes (list lens-clojure-modes lens-ocaml-modes))
  (let ((language (if (eq modes lens-ocaml-modes) "ocaml" "clojure")))
    (add-to-list 'eglot-server-programs
                 (cons (mapcar (lambda (mode) (list mode :language-id
                                             (if (string-prefix-p "clojurescript" (symbol-name mode))
                                                 "clojurescript" language))) modes)
                       #'lens-eglot-contact))))

(defun lens-eglot-reading-settings ()
  "Keep navigation and type information without formatting or save-time edits."
  (setq-local eglot-ignored-server-capabilities
              '(:documentFormattingProvider :documentRangeFormattingProvider
                :documentOnTypeFormattingProvider :codeActionProvider :renameProvider))
  (setq-local eglot-stay-out-of '(flymake company yasnippet)))

(defun lens-auto-eglot ()
  "Queue one automatic connection for a supported file buffer; reuse live sessions."
  (when (and lens-eglot-auto-start buffer-file-name (lens-eglot-language)
             (not (bound-and-true-p eglot--managed-mode)) (not lens-eglot-auto-pending))
    (lens-eglot-reading-settings)
    (condition-case failure
        (progn
          (lens-eglot-contact)
          (if (eglot-current-server)
              (eglot--maybe-activate-editing-mode)
            (setq lens-eglot-auto-pending t)
            (eglot-ensure)))
      (user-error (message "%s" (error-message-string failure))))))
(dolist (mode (append lens-clojure-modes lens-ocaml-modes))
  (add-hook (intern (format "%s-hook" mode)) #'lens-auto-eglot))
(defun lens-eglot-managed-reading-settings ()
  "Keep automatic sessions free of save-time server edits."
  (setq lens-eglot-auto-pending nil)
  (when (bound-and-true-p eglot--managed-mode)
    (remove-hook 'before-save-hook #'eglot--signal-textDocument/willSave t)))
(add-hook 'eglot-managed-mode-hook #'lens-eglot-managed-reading-settings)

(defun lens-semantic-navigation ()
  "Explicitly connect or retry the current language server."
  (interactive)
  (unless (lens-eglot-language)
    (user-error "Code Lens: semantic navigation supports Clojure and OCaml"))
  (lens-eglot-contact)
  (lens-eglot-reading-settings)
  (setq lens-eglot-auto-pending nil)
  (call-interactively #'eglot))

(provide 'lens-lsp)
