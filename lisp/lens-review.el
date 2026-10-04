;;; lens-review.el --- Reading and review commands -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'project)
(require 'xref)
(require 'imenu)
(require 'outline)
(require 'clojure-mode)
(require 'tuareg)
(require 'rainbow-delimiters)
(require 'consult)
(require 'vertico)
(require 'orderless)
(require 'marginalia)
(require 'embark)
(require 'embark-consult)
;; This chord is unbound in the inherited minibuffer maps and Vertico.
(keymap-set minibuffer-local-map "C-c C-o" #'embark-collect)
(require 'lens-lsp)
(require 'lens-source-reading)

;; One standard completion UI, with live navigation previews and rich annotations.
(setq read-process-output-max (* 1024 1024)
      scroll-conservatively 101
      scroll-margin 4
      compilation-scroll-output nil
      completion-styles '(orderless basic)
      completion-category-defaults nil
      completion-category-overrides '((file (styles partial-completion orderless)))
      consult-preview-key '(:debounce 0.2 any)
      xref-show-xrefs-function #'consult-xref
      xref-show-definitions-function #'consult-xref
      tab-always-indent nil
      sentence-end-double-space nil
      ring-bell-function #'ignore
      help-window-select t
      xref-search-program (if (executable-find "rg") 'ripgrep 'grep))
(menu-bar-mode 1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(require 'modus-themes)
(mapc #'disable-theme custom-enabled-themes)
(load-theme 'modus-operandi-tinted t)
(setq use-short-answers t)
(show-paren-mode 1)
(column-number-mode 1)
(size-indication-mode 1)
(winner-mode 1)
(fido-vertical-mode -1)
(fido-mode -1)
(icomplete-mode -1)
(vertico-mode 1)
(marginalia-mode 1)
(save-place-mode 1)
(savehist-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)
(when (display-graphic-p)
  (set-face-attribute 'default nil :height 140)
  (setq frame-title-format '("Code Lens — " (:eval (buffer-name)))))

(define-minor-mode lens-reading-mode
  "Keep source buffers read-only until explicitly unlocked with C-c r e."
  :lighter " Lens"
  (read-only-mode (if lens-reading-mode 1 -1))
  (lens-sync-source-reading-keys))

(defun lens-source-setup ()
  "Improve source legibility without edit or format hooks."
  (setq-local truncate-lines t)
  (setq-local show-trailing-whitespace t)
  (setq-local display-line-numbers-width 4)
  (display-line-numbers-mode 1)
  (hl-line-mode 1)
  (outline-minor-mode 1)
  (lens-reading-mode 1))
(add-hook 'prog-mode-hook #'lens-source-setup)
(defun lens-ocaml-index-setup ()
  "Use a lightweight top-level textual index without Merlin or a server."
  (setq-local imenu-create-index-function #'imenu-default-create-index-function)
  (setq-local imenu-generic-skip-comments-and-strings t)
  (setq-local imenu-generic-expression
              '((nil "^\\(?:let\\|val\\|external\\)[ \t]+\\(?:rec[ \t]+\\)?\\([[:alnum:]_']+\\)" 1)
                ("Types" "^type[ \t]+\\(?:('[[:alnum:]_, \t]+)[ \t]+\\|'[[:alnum:]_]+[ \t]+\\)?\\([[:alnum:]_']+\\)" 1)
                ("Modules" "^module[ \t]+\\(?:type[ \t]+\\|rec[ \t]+\\)?\\([[:alnum:]_']+\\)" 1)
                ("Classes" "^class[ \t]+\\(?:virtual[ \t]+\\)?\\([[:alnum:]_']+\\)" 1)
                ("Exceptions" "^exception[ \t]+\\([[:alnum:]_']+\\)" 1)))
  (setq-local outline-regexp "^\\(?:let\\|val\\|type\\|module\\|class\\|exception\\|external\\|and\\)\\_>")
  (setq-local outline-level (lambda () 1)))
(add-hook 'tuareg-mode-hook #'lens-ocaml-index-setup)

(dolist (hook '(clojure-mode-hook clojurescript-mode-hook clojurec-mode-hook emacs-lisp-mode-hook))
  (add-hook hook #'rainbow-delimiters-mode))

(defun lens-consult-search (&optional directory initial)
  "Search DIRECTORY with Consult previews, using ripgrep or the grep fallback."
  (interactive "P")
  (if (executable-find "rg")
      (consult-ripgrep directory initial)
    (consult-grep directory initial)))

(defun lens-search (regexp)
  "Search project text for REGEXP with ripgrep; results are navigable hits."
  (interactive (list (read-string "Project text (regexp): " (thing-at-point 'symbol t))))
  (if (executable-find "rg")
      (let ((default-directory (project-root (project-current t))))
        (require 'grep)
        (compilation-start
         (concat "rg --line-number --column --no-heading --color=never --smart-case -- "
                 (shell-quote-argument regexp) " .")
         'grep-mode (lambda (_) "*Code Lens search*")))
    (project-find-regexp regexp)))

(defun lens-index-entries (index)
  "Flatten INDEX into navigable imenu entries."
  (mapcan (lambda (entry)
            (cond ((imenu--subalist-p entry) (lens-index-entries (cdr entry)))
                  ((number-or-marker-p (cdr entry)) (list entry))))
          index))

(defun lens-definition (identifier)
  "Find IDENTIFIER using Eglot, or a definition in the current file's index."
  (interactive (list (or (thing-at-point 'symbol t)
                         (read-string "Definition name: "))))
  (if (bound-and-true-p eglot--managed-mode)
      (xref-find-definitions identifier)
    (let* ((name (car (last (split-string identifier "[/.:]" t))))
           (index (lens-index-entries (imenu--make-index-alist t)))
           (entry (assoc name index)))
      (unless entry
        (user-error "No current-file definition for %s; use C-c r / for text or C-c r s for semantics" identifier))
      (xref-push-marker-stack)
      (goto-char (cdr entry))
      (when (get-buffer-window (current-buffer)) (recenter)))))

;; Magit owns its maps and write operations. No stage/checkout/commit runs on startup.
(with-eval-after-load 'magit
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1
        magit-diff-refine-hunk t
        magit-save-repository-buffers nil))
(require 'lens-navigation-display)
(require 'lens-help)
(lens-install-bindings)
(lens-configure-scratch)
(provide 'lens-review)
