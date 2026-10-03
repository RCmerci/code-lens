;;; lens-bootstrap.el --- Offline locked package installation -*- lexical-binding: t; -*-
(require 'package)
(setq package-archives nil
      package-native-compile nil)
(package-initialize)
;; ELPA sources are already HTTPS-downloaded and SHA256-verified by bootstrap.py.
;; Avoid costly compilation on the shared machine; Emacs loads these small Lisp sources.
(cl-letf (((symbol-function 'package--compile) (lambda (&rest _) nil)))
  (dolist (file (delete "--" command-line-args-left))
    (let* ((name-version (file-name-sans-extension (file-name-nondirectory file)))
           (name (intern (replace-regexp-in-string "-[0-9].*\\'" "" name-version)))
           (version (substring name-version (1+ (length (symbol-name name))))))
      (unless (package-installed-p name (version-to-list version))
        (package-install-file file)))))
(setq command-line-args-left nil)
