;;; lens-merlin.el --- Explicit OCaml type queries beside Eglot -*- lexical-binding: t; -*-
(require 'lens-lsp)
(require 'merlin)
(require 'seq)

;; Load the public query implementation without enabling its xref/CAPF/error mode.
(setq merlin-error-after-save nil
      merlin-favourite-caml-mode 'tuareg-mode
      merlin-arrow-keys-type-enclosing t
      merlin-allow-sit-for nil
      merlin-command #'lens-merlin-executable
      merlin-configuration-function #'lens-merlin-configuration)
(set-face-attribute 'merlin-type-face nil :inherit 'region)

(defun lens-merlin-executable ()
  "Resolve the launch environment's Merlin, or the compatible isolated tool.
An explicit CODE_LENS_MERLIN must be executable and does not silently fall back."
  (unless (and buffer-file-name (eq (lens-eglot-language) 'ocaml)
               (not (file-remote-p buffer-file-name)))
    (user-error "Code Lens: Merlin type queries need a local OCaml source file"))
  (let ((explicit (getenv "CODE_LENS_MERLIN"))
        (program (executable-find "ocamlmerlin"))
        (local (expand-file-name ".local/tools/merlin-5.8.1-505/bin/ocamlmerlin" lens-root)))
    (cond
     ((and explicit (not (string-empty-p explicit)))
      (or (and (file-executable-p explicit) explicit)
          (user-error "Code Lens: CODE_LENS_MERLIN is not executable: %s" explicit)))
     (program program)
     ((file-executable-p local)
      (unless (and (executable-find "ocamlc")
                   (string-prefix-p "5.5." (car (process-lines "ocamlc" "-version"))))
        (user-error "Code Lens: isolated Merlin requires OCaml 5.5; use this project's matching ocamlmerlin in PATH or CODE_LENS_MERLIN"))
      local)
     (t (user-error "Code Lens: ocamlmerlin missing; install Merlin for the project, or run bin/bootstrap-merlin for OCaml 5.5")))))

(defun lens-merlin-configuration ()
  "Keep Merlin and its helper binaries together, preserving the launch switch."
  (let ((program (lens-merlin-executable)))
    `((command . ,program)
      (env . (,(concat "PATH=" (file-name-directory program)
                       path-separator (or (getenv "PATH") "")))))))

(defun lens-merlin-enclosing-verbosity (&rest _)
  "Preserve the actual query verbosity when Merlin defers outer-layer types.
The pinned interface captures the previous query's verbosity and sends it in
an improper argument list, whose numeric tail bypasses string conversion.
Normalize the cached value after the query; leave native ranges and keys intact."
  (dolist (item merlin-enclosing-types)
    (when (consp (car item))
      (setf (nth 3 (car item))
            (number-to-string (or (cdr merlin--verbosity-cache) 0))))))
(advice-add 'merlin--type-enclosing-query :after #'lens-merlin-enclosing-verbosity)

(defconst lens-merlin-type-shortcuts
  '(("t" merlin-type-enclosing "仅 OCaml：光标处表达式类型；重复调用增加细节")
    ("T" merlin-type-expr "仅 OCaml：输入上下文表达式查询类型，不写入文件"))
  "One source for OCaml type query bindings and the scratch quick reference.")
(defvar lens-merlin-type-keys-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (entry lens-merlin-type-shortcuts)
      (keymap-set map (car entry) (cadr entry)))
    map))
(define-minor-mode lens-merlin-type-keys-mode
  "Expose t/T only in read-only OCaml Code Lens reading buffers."
  :lighter nil :keymap lens-merlin-type-keys-mode-map
  (unless (and (bound-and-true-p lens-source-reading-keys-mode)
               (eq (lens-eglot-language) 'ocaml))
    (setq lens-merlin-type-keys-mode nil)))
(defun lens-sync-merlin-type-keys ()
  "Restore ordinary t/T input on unlocking or leaving reading mode."
  (lens-merlin-type-keys-mode
   (if (and (bound-and-true-p lens-source-reading-keys-mode)
            (eq (lens-eglot-language) 'ocaml)) 1 -1)))

(defun lens-merlin-type-help-text ()
  "Describe the OCaml type keys from their actual keymap."
  (concat
   (mapconcat (lambda (entry)
                (format "  %-3s %s [%s]\n" (car entry) (nth 2 entry)
                        (keymap-lookup lens-merlin-type-keys-mode-map (car entry))))
              lens-merlin-type-shortcuts "")
   "  C-<up> / C-<down>：t 后逐层扩大 / 缩小 enclosing 范围；范围短暂高亮。\n"
   "  Merlin 仅显式查询类型；Eglot 继续负责导航，不添加 Merlin xref / 补全 / 自动检查。\n"))

(provide 'lens-merlin)
