;;; lens-ocaml-outline.el --- Adapt the vendored outline to isolated Code Lens -*- lexical-binding: t; -*-
(require 'ocaml-outline)

(defun lens-ocaml-outline-check-source (original &rest args)
  "Explain how to connect before opening an outline for an unmanaged source."
  (unless (bound-and-true-p eglot--managed-mode)
    (user-error "Code Lens: OCaml outline requires Eglot; use C-c r s to connect or retry"))
  (apply original args))
(advice-add 'ocaml-outline :around #'lens-ocaml-outline-check-source)

(defun lens-ocaml-outline-preserve-ranges (original &rest args)
  "Reuse the old-Eglot semantic index bridge, including when headers are disabled."
  (let ((lens-ocaml-outline-request t))
    (apply original args)))
(advice-add 'ocaml-outline-refresh :around #'lens-ocaml-outline-preserve-ranges)
(provide 'lens-ocaml-outline)
