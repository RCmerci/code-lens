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

(defun lens-toggle-ocaml-outline ()
  "Toggle this source's outline in the current frame.
From the outline, close only its associated views and return to its source.
An outline for another source is never used as the close target."
  (interactive)
  (let* ((from-outline (derived-mode-p 'ocaml-outline-mode))
         (source (if from-outline ocaml-outline-source-buffer
                   (and (eq (lens-eglot-language) 'ocaml) (current-buffer)))))
    (unless (buffer-live-p source)
      (user-error "Code Lens: the OCaml outline source no longer exists"))
    (let* ((outline (buffer-local-value 'ocaml-outline-buffer source))
           (owned (and (buffer-live-p outline)
                       (eq (buffer-local-value 'ocaml-outline-source-buffer outline) source)))
           (windows (and owned (get-buffer-window-list outline nil (selected-frame))))
           (source-window (and from-outline
                               (get-buffer-window source (selected-frame))))
           ;; A hidden source can reclaim its ordinary outline pane without
           ;; replacing an unrelated buffer through `pop-to-buffer'.
           (restore-window (and from-outline (not source-window)
                                (seq-find (lambda (window)
                                            (not (window-parameter window 'window-side)))
                                          windows))))
      (when (and from-outline (not (and owned (eq outline (current-buffer)))))
        (user-error "Code Lens: this outline is no longer associated with its source"))
      (if windows
          (progn
            (dolist (window windows)
              ;; Restore the hidden source in its own pane, or remove outline views.
              (if (and (window-parent window) (not (eq window restore-window)))
                  (delete-window window)
                (set-window-buffer window source)))
            (when from-outline
              (if-let ((window (or source-window restore-window
                                    (get-buffer-window source (selected-frame)))))
                  (select-window window)
                ;; A side outline whose source was hidden needs a fresh pane.
                (let ((split-height-threshold 0) (split-width-threshold nil))
                  (pop-to-buffer source
                                 '((display-buffer-reuse-window display-buffer-pop-up-window)
                                   (inhibit-same-window . t))))))
            nil)
        (with-current-buffer source (ocaml-outline))))))
(keymap-set ocaml-outline-mode-map "o" #'lens-toggle-ocaml-outline)
(provide 'lens-ocaml-outline)
