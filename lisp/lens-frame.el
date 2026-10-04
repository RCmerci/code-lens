;;; lens-frame.el --- Minimal chrome for Code Lens's own GUI frames -*- lexical-binding: t; -*-
(require 'frame)
(defun lens-configure-frame (frame)
  "Hide tool icons and window decorations on a graphical Code Lens FRAME."
  (when (display-graphic-p frame)
    (modify-frame-parameters frame '((tool-bar-lines . 0) (undecorated . t)))))
(add-hook 'after-make-frame-functions #'lens-configure-frame)
(mapc #'lens-configure-frame (frame-list))
(provide 'lens-frame)
