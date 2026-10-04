;;; lens-packages.el --- Primary package inventory -*- lexical-binding: t; -*-
(require 'package)
(require 'cl-lib)

(defconst lens-primary-packages
  '((magit "Git 仓库状态、差异与历史")
    (clojure-mode "Clojure / ClojureScript 语法与定义索引")
    (tuareg "OCaml 语法与结构阅读")
    (rainbow-delimiters "括号层级配色")
    (consult "搜索、索引和 xref 候选预览")
    (vertico "纵向 minibuffer 候选界面")
    (orderless "多词任意顺序匹配")
    (marginalia "候选说明与文件信息")
    (embark "将当前候选收集到独立 buffer")
    (embark-consult "Consult 收集结果跳转与预览")
    (pulsar "成功跳转后的短暂定位高亮")
    (breadcrumb "项目路径与当前位置的代码结构层级")
    (modus-themes "modus-operandi-tinted 浅色主题")
    (codex-ide "当前文件预设问答；原生 Codex IDE，只读 CLI"))
  "Primary third-party features; builtin packages and support dependencies are omitted.")

(defun lens-primary-package-summary ()
  "List installed primary packages with versions from actual package descriptors."
  (concat
   "已安装的主要第三方 packages\n"
   (mapconcat
    #'identity
    (delq nil
          (mapcar (lambda (entry)
                    (when-let ((desc (cadr (assq (car entry) package-alist))))
                      (format "  %s %s — %s\n" (car entry)
                              (package-version-join (package-desc-version desc))
                              (cadr entry))))
                  lens-primary-packages))
    "")))

(provide 'lens-packages)
