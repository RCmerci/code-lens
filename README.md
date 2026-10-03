# Code Lens

一个独立的 Emacs 代码阅读 / review 配置，重点是 Clojure 与 OCaml。使用 Magit、clojure-mode、Tuareg、rainbow-delimiters、Consult、Vertico、Orderless、Marginalia、Modus Themes，以及 Emacs 内置的 project、imenu、xref、outline 和 Eglot。普通代码默认只读；Clojure / OCaml 文件自动连接语言服务器，不启动 REPL、不自动格式化。默认主题为 `modus-operandi-tinted`，确认问题用 `y` / `n`。

## 启动

需要 **Emacs 29.1+、Git、Python 3**；推荐 `rg`。本机可直接使用已安装的 Emacs 30.2：

```sh
cd ~/gh-repos/code-lens
./bin/bootstrap    # 首次安装；已有缓存时可离线重复执行
./bin/check        # batch ERT；交互项在下面单独检查
./bin/check-interactive  # 独立终端实例自动验证交互，结束后退出
./bin/code-lens    # GUI
./bin/code-lens -nw  # 终端
```

打开一个 review 项目：

```sh
cd ~/gh-repos/datascript
~/gh-repos/code-lens/bin/code-lens .
# 或直接打开代码
~/gh-repos/code-lens/bin/code-lens src/datascript/core.cljc
```

启动器先使用 `CODE_LENS_EMACS`，然后 PATH 中的 Emacs，再找 `/Applications/Emacs 2.app` 和 `/Applications/Emacs.app`。显式指定可执行文件：

```sh
CODE_LENS_EMACS='/Applications/Emacs 2.app/Contents/MacOS/Emacs' ./bin/code-lens
```

使用启动脚本，而不是把 init.el 复制到个人配置。脚本以 `-Q` 启动并显式加载本仓库文件；不读取个人 `.emacs` / `.emacs.d/init.el` 或 site init。包、custom、历史、项目列表、保存位置、备份和自动保存都在 `.local/`。不会创建 daemon、改动默认启动方式、设置全局 Git/opam 或推送远端。

## 最常用的键

启动后 `*scratch*` 显示阅读相关快捷键与实际安装的八个主要第三方包及版本，不讲解 Magit 用法；Git 快捷键仍保留。`C-c r ?` 在独立 Help 窗口重新生成最新速查，`q` 关闭；已有 scratch 笔记不会被重载或刷新覆盖。速查由 `lisp/lens-help.el` 的同一份功能表与实际 keymap 生成。

`C-` 表示 Ctrl，`M-` 表示 Meta；Mac GUI 通常是 Option，终端可用 Esc 后再按键。`C-c r` 是阅读命令前缀，后接表中的一个键。`C-h k` 查看某键用途，`C-h b` 查看当前全部绑定。

| 快捷键 | 用途 |
| --- | --- |
| `C-c r ?` | 重新生成中文速查到独立 Help 窗口 |
| `C-x g` / `C-c r g` | Magit status |
| `C-c r l` / `b` / `d` | 当前分支 log / 当前文件 blame / DWIM diff |
| `C-c r p` / `f` | 切换项目 / 查找项目文件，支持模糊筛选 |
| `C-c j` | Consult ripgrep 项目搜索 |
| `C-c r /` | Consult 项目搜索与预览；优先 `rg`，无 rg 时用 grep |
| `C-c r G` | 传统 grep 结果列表，保留原项目搜索与内置回退 |
| `C-s` / `C-c r L` | Consult 当前文件行搜索与预览；RET 跳转，C-g 取消 |
| `C-x b` | Consult 切换 buffer、最近文件与书签，可预览 |
| `C-c r o` | 当前文件 occur 列表 |
| `C-c r i` | Consult 当前文件定义索引与预览 |
| `C-c r I` | 同项目、同语言已打开 buffer 的定义索引与预览 |
| `M-.` / `M-,` | 定义 / 返回；也可用 `C-c r .` / `,` |
| `M-?` / `C-c r r` | xref 引用；是否语义准确取决于后端 |
| `C-c r s` | 连接 / 重试现有语言服务器 |
| `M-o` / `C-c r w` | 下一个窗口 |
| `C-c ←` / `C-c →` | 恢复上一 / 下一窗口布局 |
| `C-M-a` / `C-M-e` | 定义开头 / 结尾 |
| `C-M-f` / `C-M-b` / `C-M-u` | 结构向前 / 向后 / 向外；尤其适合 Clojure |
| `C-c r h` | 折叠 / 展开当前 outline 子项 |
| `C-c r t` | 切换长行截断 / 折行 |
| `C-c r e` / `C-x C-q` | 当前代码 buffer 临时解锁 / 再锁定 |
| `M-g g` / `C-x r SPC a` / `C-x r j a` | 跳到行 / 记录位置 a / 返回位置 a |

搜索结果中用 `RET` 打开，`M-g n` / `M-g p` 跳到下一 / 上一个命中。`C-x 2` / `C-x 3` 分屏，`C-x 1` 保留一个窗口，`C-x 0` 关闭当前窗口。

只读用于防止误敲字符，不是权限沙箱。临时解锁不写入文件，只有显式保存才会落盘；重新打开其他代码仍默认只读。Magit 提交消息等 buffer 不套用源码只读模式。目录局部配置只接受安全变量，不执行本地 eval。

## 补全与预览

Vertico 是唯一的 minibuffer 候选界面，Fido/Icomplete 已停用。`C-n` / `C-p` 选择候选，`RET` 确认，`C-g` 取消。Orderless 支持空格分隔的多词任意顺序匹配；文件路径同时保留 partial-completion。Marginalia 在命令、文件候选旁显示说明与属性。

Consult 搜索用 `#搜索表达式#结果过滤`，例如 `#answer#review.ml`：先在项目中搜索 answer，再筛选 review.ml 的结果。搜索按需异步执行，遵守 ignore；候选预览有短暂防抖，可能打开代码 buffer，但继续保持默认只读，Clojure / OCaml buffer 自动连接 Eglot。xref 的结果选择也接入 Consult，语义准确性仍取决于后端。`C-s` 打开 Consult 当前文件行搜索，`C-c r L` 是同一命令的别名；`RET` 跳转到选中行，`C-g` 取消并回到搜索前位置。搜索不会修改正文或只读状态，已有未保存输入会保留。`C-c r o` 保留 occur。

已有 Code Lens 实例可以在 `M-:` 执行以下表达式应用本次更新；保留 scratch 笔记、已有正文和只读状态，无需重启。随后 `C-c r ?` 在独立 Help 窗口查看新速查。

```elisp
(progn
  (package-initialize)
  (load "modus-themes" nil t)
  (dolist (file '("lens-lsp" "lens-source-reading" "lens-help" "lens-review"))
    (load (expand-file-name (concat "lisp/" file ".el") lens-root) nil t))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (lens-eglot-language)
        (lens-sync-source-reading-keys)
        (lens-auto-eglot)))))
```

## Review 流程

1. 从项目目录启动，`C-x g` 看 status；`l l` 看当前分支历史，`RET` 查看提交。
2. Magit 中 `d` 打开 diff 菜单；需要跨分支时 `M-x magit-diff-range` 输入例如 `main...HEAD`。
3. diff / status 中 `n` / `p` 按 section（文件、hunk）移动，`TAB` 展开 / 折叠，`M-n` / `M-p` 在同级 section 间移动，`RET` 打开位置，`SPC` / `DEL` 滚动关联 diff。`?` 看当前命令，`q` 返回。
4. 文件中 `C-c r b` 看 blame；`n` / `p` 切换 blame chunk，`RET` 看对应提交，`q` 退出 blame。
5. 用 imenu、结构移动、项目搜索定位相关代码；`M-,` 回到定义跳转前的位置。

Magit 保留自己的操作语义：`s` stage、`u` unstage、`c` commit 菜单等仍可用。源码只读不会封锁 Git 操作；本配置也不会在启动或打开文件时自动 checkout、stage、commit。为了避免 review 时顺手保存文件，Magit 不自动保存仓库 buffer。

## 单键阅读

Clojure / OCaml 源码中，`lens-reading-mode` 与只读同时启用时使用以下单字符键；包含相应派生模式、ClojureScript/ClojureC 与可用的 tree-sitter 模式。其他语言、Help、minibuffer 不启用这套键，原组合键仍可用。

| 单键 | 操作 |
| --- | --- |
| `t` | Eglot 类型 / 符号说明；OCaml 显示类型，Clojure 显示 hover 文档 |
| `d` / `b` | Eglot 定义 / xref 返回 |
| `r` | Eglot 引用，Consult 选择结果 |
| `i` | Consult 定义索引 |
| `/` / `s` | Consult 当前 buffer 行搜索 / ripgrep 项目搜索 |
| `v` / `w` | 切换 buffer / 窗口 |
| `n` / `p` | 下一个 / 上一个定义，使用语言模式的结构导航 |
| `q` | 正常关闭当前 buffer，未保存文件仍会询问确认 |
| `?` | 独立窗口显示完整单键帮助 |

`C-c r e` 或 `C-x C-q` 临时解锁后，字符恢复普通输入；重新锁定后单键恢复。关闭 `lens-reading-mode` 同样恢复编辑。`t/d/r` 在服务器未连接或当前位置没有符号时给出提示；`d/b` 保留正常 xref 返回栈。Clojure 是动态语言，hover 文档不等于静态类型推断。

## 文本导航与语义导航

打开 Clojure / OCaml 文件会自动排队启动 Eglot；第一条命令时连接，并复用同项目、同语言会话。经典模式及派生模式的 hook 已配置；tree-sitter 模式需要其本身和语法可用，本配置不另行安装语法或切换现有 major mode。

- Clojure：从启动 PATH 解析 `clojure-lsp` 的绝对路径。
- OCaml：从启动 PATH 解析 **目标项目的已有 opam switch** 中 `ocamllsp` 的绝对路径。从准备好的项目 shell 启动，或 `opam exec --switch=<已有switch> -- ~/gh-repos/code-lens/bin/code-lens .`；不创建/切换全局 switch，不运行 `dune build`。

`M-.` 连接后使用 Eglot 语义定义，连接前回退当前文件 imenu；`M-?` 查引用，`M-,` 返回。单键 `t/d/r` 要求 live server，不把文本结果充当语义结果。服务器缺失时基础阅读、行搜索、项目搜索和索引仍可用，`C-c r s` 可重试。`M-x eglot-shutdown` 断开当前 server；可设置 `lens-eglot-auto-start` 为 nil 来停用后续文件的自动连接。

源码只读不妨碍 LSP 的读取、类型与导航。格式化、rename、code action 能力被忽略，读取配置移除 Eglot 的保存时编辑 hook。语言服务器可以索引项目、解析依赖并写缓存。本仓库不安装服务器；GUI 从启动 shell 继承 PATH，其他项目应使用对应工具环境。

## 包与维护

主要第三方包：Magit **4.7.1**、clojure-mode **5.23.0**、Tuareg **3.1.0**、rainbow-delimiters **2.1.5**、Consult **3.10**、Vertico **2.15**、Orderless **1.8**、Marginalia **2.13**、Modus Themes **5.3.0**。Emacs 29 没有内置 tinted 主题，因此两版本统一加载锁定的官方 GNU ELPA Modus 包。启动清单由 `lisp/lens-packages.el` 的主要功能表读取实际安装的 package descriptors 生成，不混入内置功能或传递依赖。四个补全包来自官方 GNU ELPA，使用现有 Compat 依赖。

`packages.lock.json` 包含全部外部依赖的准确版本、官方 GNU/NonGNU ELPA HTTPS 下载地址和 SHA256。bootstrap 校验每个下载/缓存文件，校验失败会停止；平常启动不更新包。锁文件是首次从官方 HTTPS 取得源码时记录的校验值，不是独立的签名验证。

bootstrap 不做 native/byte 编译，避免共享机器重负载；运行时加载源码。`seq` 如内置版本已满足要求则直接使用 Emacs 自带实现。不要在此 profile 内用 package 菜单升级依赖；要更换版本应审阅锁文件并重新生成隔离包目录。删除 `.local/` 后重新运行 bootstrap 可恢复，但会清掉此配置自己的历史/自定义。个人 Emacs 配置不受影响。

文件组织：`early-init.el` 负责隔离，`init.el` 加载依赖，`lisp/lens-review.el` 定义阅读功能，`lisp/lens-lsp.el` 配置自动 Eglot，`lisp/lens-source-reading.el` 管理两语言单键，`lisp/lens-help.el` 维护快捷键与启动速查，`lisp/lens-packages.el` 维护主要包清单，`tests/review-test.el` 与 `tests/lsp-test.el` 是可重复的检查源码；LSP 检查只用一次性小项目，分别验证真实握手、符号、hover、定义/返回、引用和会话复用，不索引用户仓库。可运行 `./bin/code-lens --batch --load tests/lsp-test.el --eval '(ert-run-tests-batch-and-exit (quote lens-real-automatic-language-servers))'` 重复真实 LSP 检查；`./bin/code-lens -nw --load tests/lsp-test.el --load tests/interactive-runner.el` 验证单键输入、关闭确认和短回答。`bin/check` 创建一次性临时 Git 仓库测试只读、两种语言结构/索引、搜索/返回、Magit status/log/blame/diff/hunk，以及 stage 仍可执行；不对用户项目做 Git 写操作。新增检查覆盖实际多词匹配、文件/命令注释、Consult rg/ignore、版本清单和 scratch 保护。`bin/check-interactive` 在独立终端实例中用真实 minibuffer 验证行搜索、Clojure/OCaml imenu 和异步搜索跳转，自动结束，不操作现有 Emacs。真实项目检查结果与截图放在被忽略的 `docs/test-reports/`，缓存、elc、eln 和报告不提交。

官方参考：[Magit](https://magit.vc/manual/magit.html)、[GNU ELPA](https://elpa.gnu.org/)、[NonGNU ELPA](https://elpa.nongnu.org/)、[Emacs xref](https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html)。
