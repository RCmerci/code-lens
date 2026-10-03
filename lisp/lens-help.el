;;; lens-help.el --- Code Lens bindings and startup reference -*- lexical-binding: t; -*-
(require 'subr-x)

(defconst lens-shortcut-groups
  '(("项目与搜索"
     ("C-c r p" project-switch-project "切换项目")
     ("C-c r f" project-find-file "查找项目文件")
     ("C-c r /" lens-search "项目文本搜索；有 rg 时使用 ripgrep")
     ("C-c r o" occur "列出当前文件匹配行"))
    ("定义与结构导航"
     ("C-c r i" imenu "当前文件定义索引")
     ("C-c r ." lens-definition "定义：默认当前文件文本索引；连接 LSP 后用语义后端")
     ("M-." lens-definition "定义跳转，同 C-c r .")
     ("C-c r ," xref-go-back "返回定义跳转前的位置")
     ("M-," xref-go-back "返回，同 C-c r ,")
     ("C-c r r" xref-find-references "引用；结果准确性取决于 xref 后端")
     ("C-c r s" lens-semantic-navigation "手动连接已有 clojure-lsp / ocamllsp"))
    ("Git review"
     ("C-c r g" magit-status "仓库状态")
     ("C-x g" magit-status "仓库状态，同 C-c r g")
     ("C-c r l" magit-log-current "当前分支历史")
     ("C-c r b" magit-blame-addition "当前文件逐行来源 blame")
     ("C-c r d" magit-diff-dwim "按当前上下文查看 diff"))
    ("阅读与窗口"
     ("C-c r e" read-only-mode "当前代码临时解锁 / 再锁定；也可 C-x C-q")
     ("C-c r h" outline-toggle-children "折叠 / 展开 outline 子项")
     ("C-c r t" toggle-truncate-lines "长行截断 / 折行")
     ("C-c r w" other-window "下一个窗口")
     ("M-o" other-window "下一个窗口，同 C-c r w")
     ("C-c <left>" winner-undo "恢复上一窗口布局")
     ("C-c <right>" winner-redo "恢复下一窗口布局"))
    ("速查与帮助"
     ("C-c r ?" lens-show-help "重新生成速查到独立 Help 窗口；保留 scratch 笔记")))
  "Single source for Code Lens key bindings and their Chinese descriptions.")

(defvar lens-review-map (make-sparse-keymap)
  "Code Lens review prefix map, populated from `lens-shortcut-groups'.")

(defun lens-install-bindings ()
  "Install the shortcuts described by `lens-shortcut-groups'."
  (dolist (group lens-shortcut-groups)
    (dolist (entry (cdr group))
      (let ((key (car entry)) (command (cadr entry)))
        (if (string-prefix-p "C-c r " key)
            (keymap-set lens-review-map (string-remove-prefix "C-c r " key) command)
          (keymap-global-set key command)))))
  (keymap-global-set "C-c r" lens-review-map))

(defconst lens-builtin-help
  '(("C-s" "当前文件增量搜索")
    ("M-?" "xref 引用，同 C-c r r")
    ("C-M-a" "定义开头") ("C-M-e" "定义结尾")
    ("C-M-f" "结构向前") ("C-M-b" "结构向后") ("C-M-u" "移到外层结构")
    ("M-g g" "跳到行")
    ("M-g n" "下一搜索命中") ("M-g p" "上一搜索命中")
    ("C-x r SPC" "记录位置；随后输入一个寄存器字母")
    ("C-x r j" "返回寄存器位置；随后输入该字母")
    ("C-x 2" "上下分屏") ("C-x 3" "左右分屏")
    ("C-x 1" "保留当前窗口") ("C-x 0" "关闭当前窗口")
    ("C-x C-q" "当前 buffer 解锁 / 再锁定")
    ("C-h k" "查看某键用途") ("C-h b" "查看当前 buffer 全部绑定"))
  "Existing Emacs commands worth showing alongside the custom bindings.")

(defconst lens-magit-help-groups
  '(("Magit status / diff：菜单与 section" magit-status-mode-map
     ("n" "下一 section / 文件 / hunk") ("p" "上一 section / 文件 / hunk")
     ("M-n" "下一同级 section") ("M-p" "上一同级 section")
     ("TAB" "展开 / 折叠 section") ("RET" "打开当前位置对应的文件 / 提交")
     ("SPC" "显示 / 向下滚动关联 diff")
     ("DEL" "显示 / 向上滚动关联 diff")
     ("l" "历史菜单；再按 l 查看当前分支历史")
     ("d" "diff 菜单；跨分支可用 M-x magit-diff-range")
     ("s" "stage（会修改 Git index）") ("u" "unstage（会修改 Git index）")
     ("c" "commit 菜单（可创建提交）")
     ("?" "Magit 操作菜单") ("q" "退出当前 Magit buffer"))
    ("Magit diff：滚动当前差异" magit-diff-mode-map
     ("SPC" "向下滚动当前 diff") ("DEL" "向上滚动当前 diff"))
    ("Magit blame：逐行来源" magit-blame-read-only-mode-map
     ("n" "下一 blame chunk") ("p" "上一 blame chunk")
     ("RET" "查看对应提交") ("q" "退出 blame")))
  "Magit help descriptions; command names are read from the live maps.")

(defun lens-help-binding-line (key description &optional map)
  "Describe KEY and DESCRIPTION using its actual binding in MAP or the global map."
  (let ((binding (keymap-lookup (or map (current-global-map)) key)))
    (format "  %-16s %s [%s]\n" key description
            (if (symbolp binding) (or binding "未绑定") "前缀"))))

(defun lens-help-text ()
  "Generate the Chinese quick reference from the shortcuts and actual keymaps."
  (require 'magit)
  (require 'magit-blame)
  (concat
   "Code Lens · 代码阅读 / review 速查\n"
   "================================\n"
   "C- = Ctrl，M- = Meta（Mac 通常 Option；终端可先按 Esc）。\n"
   "C-c r 是阅读前缀：先按 C-c，再按 r，最后按所列的键。\n"
   "方括号内是实际 keymap 中的命令名；M-x 也可调用。\n\n"
   "启动\n"
   "  cd ~/gh-repos/code-lens\n"
   "  ./bin/code-lens        GUI；./bin/code-lens -nw        终端\n"
   "  ./bin/code-lens <项目目录或代码文件>\n\n"
   "阅读约定\n"
   "  代码默认只读。C-c r e / C-x C-q 只解锁当前 buffer，显式保存才写盘。\n"
   "  只读不限制 Magit 的 stage / commit 等 Git 操作；本配置不会自动执行它们。\n"
   "  默认不启动 REPL / LSP，不自动格式化；Clojure / OCaml 都可直接阅读。\n"
   "  未连接 LSP 时，定义跳转只用当前文件文本索引，不解析类型或命名空间。\n"
   "  跨文件精确语义导航：C-c r s 手动连接已有 clojure-lsp / ocamllsp。\n"
   "  OCaml 使用目标项目已有 opam switch 的环境；不创建 switch 或运行构建。\n"
   "  LSP 可索引、下载项目依赖或写缓存；M-x eglot-shutdown 可断开。\n"
   "  没有 LSP 时，用项目搜索查跨文件定义；引用结果不能当作完整语义关系。\n\n"
   (mapconcat
    (lambda (group)
      (concat (car group) "\n"
              (mapconcat (lambda (entry)
                           (lens-help-binding-line (car entry) (nth 2 entry)))
                         (cdr group) "")))
    lens-shortcut-groups "\n")
   "\nEmacs 内置阅读键\n"
   (mapconcat (lambda (entry) (lens-help-binding-line (car entry) (cadr entry)))
              lens-builtin-help "")
   "\nMagit 内常用键（只在相应 Magit buffer 生效）\n"
   "具体 section 可进一步重映射命令；C-h k 查看所在位置的实际操作。\n"
   (mapconcat
    (lambda (group)
      (concat (car group) "\n"
              (mapconcat (lambda (entry)
                           (lens-help-binding-line (car entry) (cadr entry)
                                                   (symbol-value (cadr group))))
                         (cddr group) "")))
    lens-magit-help-groups "\n")
   "\n此速查仅填充空且未修改的 *scratch*；已有笔记不会被重载覆盖。\n"
   "C-c r ? 随时在独立 Help 窗口查看最新速查，q 关闭该窗口。\n"))

(defun lens-initialize-scratch ()
  "Fill an empty, unmodified, writable scratch buffer with the quick reference."
  (when-let ((scratch (get-buffer "*scratch*")))
    (with-current-buffer scratch
      (when (and (zerop (buffer-size))
                 (not (buffer-modified-p))
                 (not buffer-read-only))
        (text-mode)
        (insert (lens-help-text))
        (goto-char (point-min))
        (set-buffer-modified-p nil)))))

(defun lens-show-help ()
  "Refresh the quick reference in a Help buffer without changing scratch notes."
  (interactive)
  (with-help-window "*Code Lens Help*"
    (princ (lens-help-text))))

(defun lens-configure-scratch ()
  "Set the isolated profile's scratch defaults and preserve any existing content."
  (setq initial-major-mode 'text-mode
        initial-scratch-message (lens-help-text))
  (lens-initialize-scratch))

(provide 'lens-help)
