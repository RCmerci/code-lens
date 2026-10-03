;;; lens-help.el --- Code Lens bindings and startup reference -*- lexical-binding: t; -*-
(require 'subr-x)
(require 'lens-packages)

(defconst lens-shortcut-groups
  '(("项目与搜索"
     ("C-c r p" project-switch-project "切换项目")
     ("C-c r f" project-find-file "查找项目文件")
     ("C-c r /" lens-consult-search "Consult 项目搜索预览；优先 rg，无 rg 时用 grep")
     ("C-c r G" lens-search "传统 grep 结果列表；M-g n / p 移动命中")
     ("C-c r L" consult-line "当前文件行搜索与预览；C-s 仍为增量搜索")
     ("C-x b" consult-buffer "切换 buffer / 最近文件 / 书签，可预览")
     ("C-c r o" occur "列出当前文件匹配行"))
    ("定义与结构导航"
     ("C-c r i" consult-imenu "当前文件定义索引与预览")
     ("C-c r I" consult-imenu-multi "同项目、同语言已打开 buffer 的定义索引")
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

(defun lens-help-binding-line (key description &optional map)
  "Describe KEY and DESCRIPTION using its actual binding in MAP or the global map."
  (let ((binding (keymap-lookup (or map (current-global-map)) key)))
    (format "  %-16s %s [%s]\n" key description
            (if (symbolp binding) (or binding "未绑定") "前缀"))))

(defun lens-help-text ()
  "Generate the Chinese quick reference from the shortcuts and actual keymaps."
  (concat
   "Code Lens · 代码阅读 / review 速查\n"
   "================================\n"
   "C- = Ctrl，M- = Meta（Mac 通常 Option；终端可先按 Esc）。\n"
   "C-c r 是阅读前缀：先按 C-c，再按 r，最后按所列的键。\n"
   "方括号内是实际 keymap 中的命令名；M-x 也可调用。\n\n"
   (lens-primary-package-summary)
   "\n补全与预览\n"
   "  Vertico：C-n / C-p 选择候选，RET 确认，C-g 取消。\n"
   "  Orderless：用空格分隔多个词，顺序不限；Marginalia 在候选旁显示说明。\n"
   "  Consult 搜索：#搜索表达式#结果过滤；输入后异步搜索，可预览跳转。\n"
   "  预览会打开相关文件；代码仍默认只读，不自动启动语言服务器。\n\n"
   "启动\n"
   "  cd ~/gh-repos/code-lens\n"
   "  ./bin/code-lens        GUI；./bin/code-lens -nw        终端\n"
   "  ./bin/code-lens <项目目录或代码文件>\n\n"
   "阅读约定\n"
   "  代码默认只读。C-c r e / C-x C-q 只解锁当前 buffer，显式保存才写盘。\n"
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
    (cl-remove-if (lambda (group) (string= (car group) "Git review"))
                  lens-shortcut-groups) "\n")
   "\nEmacs 内置阅读键\n"
   (mapconcat (lambda (entry) (lens-help-binding-line (car entry) (cadr entry)))
              lens-builtin-help "")
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
