;;; init.el --- Code Lens entry point -*- lexical-binding: t; -*-
(unless (featurep 'lens-early-init)
  (load (expand-file-name "early-init.el"
                          (file-name-directory (or load-file-name buffer-file-name))) nil t))
(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)
(dolist (package '(magit clojure-mode tuareg rainbow-delimiters))
  (unless (package-installed-p package)
    (error "Missing %s. Run %sbin/bootstrap first" package lens-root)))
(add-to-list 'load-path (expand-file-name "lisp/" lens-root))
(require 'lens-review)
(when (file-exists-p custom-file) (load custom-file nil t))
