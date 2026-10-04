;;; lens-source-reading.el --- Single-key source reading -*- lexical-binding: t; -*-
(require 'lens-lsp)
(require 'xref)
(require 'lens-codex)

(defconst lens-source-reading-shortcuts
  '(("t" lens-source-type "显示类型 / 符号说明（Clojure 为 hover 文档）")
    ("d" lens-source-definition "语义定义跳转")
    ("b" xref-go-back "返回跳转前位置")
    ("r" lens-source-references "语义引用")
    ("c" lens-codex-question "选择当前文件预设问题，发给只读 Codex CLI")
    ("f" project-find-file "项目文件选择（Vertico）")
    ("i" consult-imenu "定义索引")
    ("/" consult-line "当前 buffer 行搜索")
    ("s" consult-ripgrep "项目文本搜索")
    ("v" consult-buffer "切换 buffer")
    ("w" other-window "切换窗口")
    ("n" lens-source-next-definition "下一个定义")
    ("p" beginning-of-defun "上一个定义")
    ("q" lens-source-quit "关闭当前 buffer；未保存修改使用 y/n 确认")
    ("?" lens-source-reading-help "单键帮助")))
(defvar lens-source-reading-keys-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (entry lens-source-reading-shortcuts)
      (define-key map (kbd (car entry)) (cadr entry)))
    map))

(define-minor-mode lens-source-reading-keys-mode
  "Use single-character navigation only in read-only Clojure and OCaml reading buffers."
  :lighter nil :keymap lens-source-reading-keys-mode-map
  (unless (and (bound-and-true-p lens-reading-mode) buffer-read-only
               (lens-eglot-language))
    (setq lens-source-reading-keys-mode nil)))

(defun lens-sync-source-reading-keys ()
  "Restore normal character input as soon as the source buffer is unlocked."
  (lens-source-reading-keys-mode
   (if (and (bound-and-true-p lens-reading-mode) buffer-read-only
            (lens-eglot-language)) 1 -1)))
(add-hook 'read-only-mode-hook #'lens-sync-source-reading-keys)

(defun lens-source-semantic-identifier ()
  "Require a live Eglot session and a symbol before semantic reading commands."
  (unless (and (lens-eglot-language)
               (bound-and-true-p eglot--managed-mode)
               (eglot-current-server)
               (jsonrpc-running-p (eglot-current-server)))
    (user-error "Language server is not connected; use C-c r s to connect or retry"))
  (unless (thing-at-point 'symbol t)
    (user-error "No source symbol at point"))
  (xref-backend-identifier-at-point 'eglot))

(defun lens-source-type ()
  "Show the server's type/hover information without moving or editing the source."
  (interactive)
  (lens-source-semantic-identifier)
  (let* ((hover (jsonrpc-request (eglot-current-server) :textDocument/hover
                                 (eglot--TextDocumentPositionParams)))
         (contents (plist-get hover :contents))
         (text (and contents (eglot--hover-info contents)))
         (help-window-select nil))
    (unless (and text (not (string-empty-p text)))
      (user-error "No hover information for this source symbol"))
    (with-help-window "*Code Lens Symbol*" (princ text))))

(defun lens-source-definition ()
  "Find the semantic definition and preserve the normal xref return stack."
  (interactive)
  (xref-find-definitions (lens-source-semantic-identifier)))
(defun lens-source-references ()
  "Find semantic references through Eglot and Consult's xref interface."
  (interactive)
  (xref-find-references (lens-source-semantic-identifier)))
(defun lens-source-next-definition ()
  "Move to the next definition using the active language mode's structure navigation."
  (interactive)
  (beginning-of-defun -1))

(defun lens-source-quit ()
  "Close the current buffer after confirming any unsaved source input."
  (interactive)
  (when (or (not (buffer-modified-p))
            (yes-or-no-p (format "Buffer %s has unsaved changes; close it? " (buffer-name))))
    (kill-buffer (current-buffer))))

(defun lens-source-reading-help-text ()
  "Describe the source reading single keys and their activation condition."
  (concat "Clojure / OCaml 单键阅读（lens-reading-mode + 只读时启用）\n"
          (mapconcat (lambda (entry)
                       (format "  %-3s %s [%s]\n" (car entry) (nth 2 entry) (cadr entry)))
                     lens-source-reading-shortcuts "")
          "  C-c r e / C-x C-q 临时解锁后恢复普通字符输入；重新锁定再启用。\n"
          "  关闭 lens-reading-mode 同样恢复输入；t/d/r 需要已连接的语言服务器。\n"))
(defun lens-source-reading-help ()
  "Show single-key reading help in a separate buffer."
  (interactive)
  (with-help-window "*Code Lens Reading Keys*" (princ (lens-source-reading-help-text))))

(provide 'lens-source-reading)
