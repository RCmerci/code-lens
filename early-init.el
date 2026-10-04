;;; early-init.el --- Isolated runtime -*- lexical-binding: t; -*-
(when (version< emacs-version "29.1")
  (error "Code Lens requires Emacs 29.1 or later"))
(defconst lens-root
  (file-name-as-directory
   (file-truename (or (getenv "CODE_LENS_ROOT")
                     (file-name-directory (or load-file-name buffer-file-name))))))
(setq user-emacs-directory (expand-file-name ".local/profile/" lens-root)
      package-user-dir (expand-file-name "elpa/" user-emacs-directory)
      package-directory-list nil
      package-enable-at-startup nil
      package-quickstart nil
      custom-file (expand-file-name "custom.el" user-emacs-directory)
      enable-local-variables :safe
      enable-local-eval nil
      native-comp-jit-compilation nil
      native-comp-deferred-compilation nil
      inhibit-startup-screen t
      initial-scratch-message nil
      create-lockfiles nil)
;; Defaults cover initial and later GUI frames; no user init is loaded.
(dolist (parameter '((tool-bar-lines . 0) (undecorated . t)))
  (setf (alist-get (car parameter) initial-frame-alist) (cdr parameter)
        (alist-get (car parameter) default-frame-alist) (cdr parameter)))
(make-directory user-emacs-directory t)
(when (and (fboundp 'startup-redirect-eln-cache)
           (boundp 'native-comp-eln-load-path))
  (startup-redirect-eln-cache (expand-file-name "eln-cache/" user-emacs-directory)))
(dolist (directory '("backups/" "auto-save/"))
  (make-directory (expand-file-name directory user-emacs-directory) t))
(setq backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory)))
      auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t))
      auto-save-list-file-prefix (expand-file-name "auto-save/.saves-" user-emacs-directory)
      project-list-file (expand-file-name "projects" user-emacs-directory)
      recentf-save-file (expand-file-name "recentf" user-emacs-directory)
      savehist-file (expand-file-name "history" user-emacs-directory)
      save-place-file (expand-file-name "places" user-emacs-directory)
      transient-levels-file (expand-file-name "transient/levels.el" user-emacs-directory)
      transient-values-file (expand-file-name "transient/values.el" user-emacs-directory)
      transient-history-file (expand-file-name "transient/history.el" user-emacs-directory))
(provide 'lens-early-init)
