# Code Lens

一个独立的 Emacs 代码阅读 / review 配置，重点是 Clojure 与 OCaml。使用 Magit、clojure-mode、Tuareg、rainbow-delimiters、Consult、Vertico、Orderless、Marginalia，以及 Emacs 内置的 project、imenu、xref、outline 和 Modus 主题。普通代码默认只读；不启动 REPL、不自动格式化、不自动启动语言服务器。

## 启动

需要 **Emacs 29.1+、Git、Python 3**；推荐 `rg`。本机可直接使用已安装的 Emacs 30.2：

```sh
cd ~/gh-repos/code-lens
./bin/bootstrap    # 首次安装；已有缓存时可离线重复执行
./bin/check        # batch ERT；真实 minibuffer 两项在下面单独检查
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
| `C-c r /` | Consult 项目搜索与预览；优先 `rg`，无 rg 时用 grep |
| `C-c r G` | 传统 grep 结果列表，保留原项目搜索与内置回退 |
| `C-s` / `C-c r L` | Consult 当前文件行搜索与预览；RET 跳转，C-g 取消 |
| `C-x b` | Consult 切换 buffer、最近文件与书签，可预览 |
| `C-c r o` | 当前文件 occur 列表 |
| `C-c r i` | Consult 当前文件定义索引与预览 |
| `C-c r I` | 同项目、同语言已打开 buffer 的定义索引与预览 |
| `M-.` / `M-,` | 定义 / 返回；也可用 `C-c r .` / `,` |
| `M-?` / `C-c r r` | xref 引用；是否语义准确取决于后端 |
| `C-c r s` | **手动**连接现有语言服务器 |
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

Consult 搜索用 `#搜索表达式#结果过滤`，例如 `#answer#review.ml`：先在项目中搜索 answer，再筛选 review.ml 的结果。搜索按需异步执行，遵守 ignore；候选预览有短暂防抖，可能打开代码 buffer，但继续保持默认只读，不启动 LSP。xref 的结果选择也接入 Consult，语义准确性仍取决于后端。`C-s` 打开 Consult 当前文件行搜索，`C-c r L` 是同一命令的别名；`RET` 跳转到选中行，`C-g` 取消并回到搜索前位置。搜索不会修改正文或只读状态，已有未保存输入会保留。`C-c r o` 保留 occur。

已有 Code Lens 实例可执行 `M-: (progn (load (expand-file-name "lisp/lens-help.el" lens-root) nil t) (lens-install-bindings) (lens-configure-scratch)) RET` 即时应用新按键；非空 scratch 笔记不会被覆盖。随后 `C-c r ?` 在独立 Help 窗口查看新速查，无需重启。

## Review 流程

1. 从项目目录启动，`C-x g` 看 status；`l l` 看当前分支历史，`RET` 查看提交。
2. Magit 中 `d` 打开 diff 菜单；需要跨分支时 `M-x magit-diff-range` 输入例如 `main...HEAD`。
3. diff / status 中 `n` / `p` 按 section（文件、hunk）移动，`TAB` 展开 / 折叠，`M-n` / `M-p` 在同级 section 间移动，`RET` 打开位置，`SPC` / `DEL` 滚动关联 diff。`?` 看当前命令，`q` 返回。
4. 文件中 `C-c r b` 看 blame；`n` / `p` 切换 blame chunk，`RET` 看对应提交，`q` 退出 blame。
5. 用 imenu、结构移动、项目搜索定位相关代码；`M-,` 回到定义跳转前的位置。

Magit 保留自己的操作语义：`s` stage、`u` unstage、`c` commit 菜单等仍可用。源码只读不会封锁 Git 操作；本配置也不会在启动或打开文件时自动 checkout、stage、commit。为了避免 review 时顺手保存文件，Magit 不自动保存仓库 buffer。

## 文本导航与语义导航

默认无需语言服务器。`M-.` 按当前文件 imenu 查找名字，成功跳转会压入 xref 返回栈；找不到会提示使用项目搜索或手动连接 server。**这是文件内的文本索引，不做类型/命名空间解析**，同名定义可能有歧义。OCaml 索引识别列首的常见 `let` / `val` / `external` / `type` / `module` / `class` / `exception`，跳过注释与字符串；嵌套模块、解构绑定、运算符定义等请用文本搜索或 LSP。没有安装可选的 caml/Merlin 包。

跨文件的精确定义、类型感知引用，需要项目可正常被语言服务器分析。在目标文件按 `C-c r s`：

- Clojure：使用 PATH 中的 `clojure-lsp`。
- OCaml：使用 **目标项目的 opam switch** 中的 `ocamllsp`。从准备好的项目 shell 启动，或 `opam exec --switch=<已有switch> -- ~/gh-repos/code-lens/bin/code-lens .`；本配置不创建/切换全局 switch，也不运行 `dune build`。

连接后 `M-.` / `M-?` 使用 Eglot 的语义后端，`M-,` 返回。没有 server 时引用可能是 xref 的文本匹配，不能当作完整的语义引用关系。服务器缺失时按键会给出说明，基础阅读仍可用。`M-x eglot-shutdown` 断开当前 server。

Eglot 的格式化、rename 和 code action 能力被忽略，没有保存时编辑 hook。手动连接仍可能下载项目依赖、索引并在项目目录写 server 自己的缓存；因此默认不开启。本仓库不安装这两个服务器。GUI 从启动 shell 继承 PATH；别的项目要使用其相应工具环境。

## 包与维护

主要第三方包：Magit **4.7.1**、clojure-mode **5.23.0**、Tuareg **3.1.0**、rainbow-delimiters **2.1.5**、Consult **3.10**、Vertico **2.15**、Orderless **1.8**、Marginalia **2.13**。启动清单由 `lisp/lens-packages.el` 的主要功能表读取实际安装的 package descriptors 生成，不混入内置功能或传递依赖。四个补全包来自官方 GNU ELPA，使用现有 Compat 依赖。

`packages.lock.json` 包含全部外部依赖的准确版本、官方 GNU/NonGNU ELPA HTTPS 下载地址和 SHA256。bootstrap 校验每个下载/缓存文件，校验失败会停止；平常启动不联网、不更新包。锁文件是首次从官方 HTTPS 取得源码时记录的校验值，不是独立的签名验证。

bootstrap 不做 native/byte 编译，避免共享机器重负载；运行时加载源码。`seq` 如内置版本已满足要求则直接使用 Emacs 自带实现。不要在此 profile 内用 package 菜单升级依赖；要更换版本应审阅锁文件并重新生成隔离包目录。删除 `.local/` 后重新运行 bootstrap 可恢复，但会清掉此配置自己的历史/自定义。个人 Emacs 配置不受影响。

文件组织：`early-init.el` 负责隔离，`init.el` 加载依赖，`lisp/lens-review.el` 定义阅读功能，`lisp/lens-help.el` 维护快捷键与启动速查，`lisp/lens-packages.el` 维护主要包清单，`tests/review-test.el` 是可重复的检查源码。`bin/check` 创建一次性临时 Git 仓库测试只读、两种语言结构/索引、搜索/返回、Magit status/log/blame/diff/hunk，以及 stage 仍可执行；不对用户项目做 Git 写操作。新增检查覆盖实际多词匹配、文件/命令注释、Consult rg/ignore、版本清单和 scratch 保护。`bin/check-interactive` 在独立终端实例中用真实 minibuffer 验证行搜索、Clojure/OCaml imenu 和异步搜索跳转，自动结束，不操作现有 Emacs。真实项目检查结果与截图放在被忽略的 `docs/test-reports/`，缓存、elc、eln 和报告不提交。

官方参考：[Magit](https://magit.vc/manual/magit.html)、[GNU ELPA](https://elpa.gnu.org/)、[NonGNU ELPA](https://elpa.nongnu.org/)、[Emacs xref](https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html)。
