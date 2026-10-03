# Code Lens

一个独立的 Emacs 代码阅读 / review 配置，重点是 Clojure 与 OCaml。使用 Magit、clojure-mode、Tuareg、rainbow-delimiters，以及 Emacs 内置的 project、imenu、xref、outline 和 Modus 主题。普通代码默认只读；不启动 REPL、不自动格式化、不自动启动语言服务器。

## 启动

需要 **Emacs 29.1+、Git、Python 3**；推荐 `rg`。本机可直接使用已安装的 Emacs 30.2：

```sh
cd ~/gh-repos/code-lens
./bin/bootstrap    # 首次安装；已有缓存时可离线重复执行
./bin/check        # 可重复的 ERT 集成检查
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

`C-` 表示 Ctrl，`M-` 表示 Meta；Mac GUI 通常是 Option，终端可用 Esc 后再按键。`C-c r` 是阅读命令前缀，后接表中的一个键。`C-h k` 查看某键用途，`C-h b` 查看当前全部绑定。

| 快捷键 | 用途 |
| --- | --- |
| `C-x g` / `C-c r g` | Magit status |
| `C-c r l` / `b` / `d` | 当前分支 log / 当前文件 blame / DWIM diff |
| `C-c r p` / `f` | 切换项目 / 查找项目文件，支持模糊筛选 |
| `C-c r /` | `rg` 项目正则搜索，遵守 Git ignore；无 rg 时用内置搜索 |
| `C-c r o` / `C-s` | 当前文件 occur 列表 / 增量搜索 |
| `C-c r i` | 当前文件定义索引 imenu |
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

`packages.lock.json` 包含全部外部依赖的准确版本、官方 GNU/NonGNU ELPA HTTPS 下载地址和 SHA256。bootstrap 校验每个下载/缓存文件，校验失败会停止；平常启动不联网、不更新包。锁文件是首次从官方 HTTPS 取得源码时记录的校验值，不是独立的签名验证。

bootstrap 不做 native/byte 编译，避免共享机器重负载；运行时加载源码。`seq` 如内置版本已满足要求则直接使用 Emacs 自带实现。不要在此 profile 内用 package 菜单升级依赖；要更换版本应审阅锁文件并重新生成隔离包目录。删除 `.local/` 后重新运行 bootstrap 可恢复，但会清掉此配置自己的历史/自定义。个人 Emacs 配置不受影响。

文件组织：`early-init.el` 负责隔离，`init.el` 加载依赖，`lisp/lens-review.el` 定义阅读功能，`tests/review-test.el` 是可重复的检查源码。`bin/check` 创建一次性临时 Git 仓库测试只读、两种语言结构/索引、搜索/返回、Magit status/log/blame/diff/hunk，以及 stage 仍可执行；不对用户项目做 Git 写操作。真实项目检查结果与截图放在被忽略的 `docs/test-reports/`，缓存、elc、eln 和报告不提交。

官方参考：[Magit](https://magit.vc/manual/magit.html)、[GNU ELPA](https://elpa.gnu.org/)、[NonGNU ELPA](https://elpa.nongnu.org/)、[Emacs xref](https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html)。
