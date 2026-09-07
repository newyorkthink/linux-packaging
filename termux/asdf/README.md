# asdf（Termux）

## 用途与产物

- 上游：[asdf-vm/asdf](https://github.com/asdf-vm/asdf)，通过插件管理项目所需的语言及工具版本。
- 技术栈：Go、urfave/cli；插件及 hook 通过 Bash 执行，插件仓库由 Git 管理。
- 目标：Android ARM64（Termux aarch64），`GOOS=android GOARCH=arm64 CGO_ENABLED=0`。
- 产物：`latest` Release 中的 `asdf.termux.tar.gz`，归档内为单个 `asdf` 可执行文件。
- 运行依赖：正常的 Termux `sh`、`bash`、`git` 环境，以及所选插件实际需要的工具；手机不需要安装 Go。

## 打包方式

- 入口：`.github/workflows/termux.yml` 的 `build-asdf` 独立 Job，使用 `actions/setup-go` 提供的稳定版 Go。
- 手动构建选择 `asdf`；每日构建全部工具；main 分支 push 按工具目录改动选择 Job，单纯 Markdown 文档改动不触发构建。
- `build.sh` 保持原有上游默认分支来源，每次在独立 Actions 临时目录获取源码，不固定应用版本。
- `cmd_termux_compat.go` 复制到上游 `cmd/asdf/termux_compat_android.go`，由 `init` 在命令行解析前归一化 linker 参数。
- `execute_termux_compat.go` 复制到上游 `internal/execute/termux_compat_android.go`；同时接入 `internal/execute/execute.go` 的 Bash 子进程和 `internal/exec/exec.go` 的进程替换入口。
- `plugins_termux_python.go` 复制到上游 `internal/plugins/termux_python_android.go`，仅在 Python 插件的 `install` 回调补充编译环境，支持指定 Python 安装及根据 `.tool-versions` 批量安装。
- 补丁只替换已核对的入口，匹配失败即终止构建；保留上游版本信息，构建日志记录上游提交、打包提交和归档 SHA-256。
- 仅打包可执行文件，不打包插件、语言运行时或个人配置，不修改 shell 配置和 PATH。

## 运行与兼容说明

在 Termux 终端执行，以下以新产物的 `asdf` 已安装至 PATH 为前提。

```bash
# 查看 asdf 版本
asdf version
```

```bash
# 添加 Python 插件，沿用本次故障中的原命令
asdf plugin add python
```

- 仅在实际进程入口是 `linker64` 时移除多出的首个参数；不硬编码安装路径，正常直接启动时保持原参数。
- linker 模式下由系统 linker 启动 PATH 中的 Termux `sh`，再通过 `exec "$@"` 调用上游 Bash 或目标程序；应保留正常 Termux 环境及其 `LD_PRELOAD` 设置。
- `asdf exec`、shim 和插件扩展复用同一执行链，并保留进程替换及上游传入环境的语义。
- Python 安装回调默认设置 `ac_cv_func_close_range=no`、`ac_cv_func_copy_file_range=no`、`ac_cv_func_preadv2=no`、`ac_cv_func_pwritev2=no`，并设置 `LN=ln -s`，处理已出现的未声明函数及硬链接错误。保留已有 `PYTHON_CONFIGURE_OPTS`；显式设置的同名环境变量优先。
- Python 安装回调还根据当前 Termux 的 `$PREFIX`，向 `CPPFLAGS`、`LDFLAGS` 和 `PKG_CONFIG_PATH` 补入头文件、库及 pkg-config 目录，保留已有设置并避免重复添加。CPython 3.11 的扩展探测需要这些路径；仅让编译器默认找到头文件并不保证扩展探测能找到库。
- 这些设置只传入 Python 安装子进程，不改变 shell 配置、全局 PATH、系统 `ln` 或其他插件的环境。Python 仍在原生 Termux 中通过 python-build 编译，不需要 PRoot。
- 以上适配针对已记录的故障；其他语言运行时及 Python 扩展的 Android 支持仍取决于对应插件和上游项目，不能据此推定全部可用。

手动构建 `asdf` 并安装新产物后，在 **Termux 终端**执行；将 `<Python版本>` 替换为需要的版本。已有 Python 插件不必重复添加。

```bash
# 安装手机端的编译工具及 ctypes、curses、readline 所需依赖
pkg install clang make pkg-config libffi ncurses ncurses-ui-libs readline
```

`libffi` 对应 `_ctypes`，`ncurses` 对应 `_curses`，`ncurses-ui-libs` 提供 `_curses_panel` 所需的 panel 库，`readline` 对应行编辑扩展。这些依赖安装在 Termux 手机端，云端重新构建 asdf 不会替手机安装它们。

```bash
# 安装所需 Python，编译兼容设置由新产物自动传入
asdf install python "<Python版本>"
```

### 已安装但缺少扩展的版本

若日志最后出现 `Installed Python-...`，但前面提示 `_curses`、`_ctypes` 或 `readline` 未编译，说明解释器已安装、扩展不完整。补装库不会自动补编扩展，而 `asdf install` 会跳过已安装版本。

先完成上面的依赖安装并换用带搜索路径适配的新 asdf，再重装受影响版本。**下面的卸载会删除所选版本及安装在该版本内的 pip 包；需要保留的第三方包应先记录，重装后恢复。不要使用 `asdf plugin remove python`，它会连同其他已安装 Python 版本一起删除。** 在 **Termux 终端**执行，将两处 `<Python版本>` 替换为同一个受影响版本。

```bash
# 仅卸载扩展不完整的 Python 版本
asdf uninstall python "<Python版本>"

# 使用已补齐依赖和搜索路径的环境重新安装该版本
asdf install python "<Python版本>"
```

## 修复记录

### 2026-09-07：接入 Termux 参数与完整执行链适配

- 现象：`asdf plugin add python` 报 `invalid command provided: <asdf可执行文件路径>`，随后输出帮助信息。
- 根因：linker 启动使无 CGO Go 的参数偏移；原 `build.sh` 只下载上游并构建，没有复制仓库中的两个兼容文件。原参数修正函数未被调用且绑定固定路径，原子进程 helper 只是转发 `exec.Command`。此外，上游 `internal/exec/exec.go` 还有供 shim / exec / 插件扩展使用的直接 `syscall.Exec` 入口。
- 修改文件：`build.sh`、`cmd_termux_compat.go`、`execute_termux_compat.go`、新增本 README。
- 修复内容：接入参数初始化和两类执行入口，采用 smug 已实测的 linker / Termux shell 思路，并将 Linux PIE 目标改为 Android ARM64，使用 Go 的 Android 系统调用兼容分支。
- 已知结果：按当前上游源码核对入口、参数、环境、包依赖、补丁匹配、Bash / Go 语法及 workflow 产物路径；尚未取得本次 asdf 产物的 Actions 构建和手机实测结果，不能将 smug 的成功结论直接视为 asdf 已通过。

### 2026-09-07：确认插件入口可用，记录 CPython 编译边界

- 实测范围：`f21120f` 产物已成功执行 `asdf plugin add python`，安装命令能够下载并启动 python-build；本次保留三个构建 / 兼容源文件不变。
- 后续故障：CPython 3.11.13 的 `Python/fileutils.c` 编译报 `close_range` 未声明，属于插件构建 CPython 时的 Android C 库兼容问题，不是 asdf 自身云编译失败或原参数偏移复发。
- 源码依据：该调用受 `HAVE_CLOSE_RANGE` 控制，CPython 自带逐个关闭文件描述符的回退；仅禁用该特性可避开此处调用，但当前证据不能证明整个 Android Python 构建及扩展均可用。
- 处理：本次不向 asdf 主程序注入 Python 专用编译选项。需要避免手机编译 Python 时，使用新增的 [micromamba / PRoot 入口](../micromamba/README.md)。
- 修改文件：仅本 README；micromamba 的独立接入见对应目录。未声称 Python 安装或全部 asdf 功能已通过实测。

### 2026-09-07：补充原生 Termux 的 Python 编译适配

- 现象：禁用 `close_range` 后，继续报 `preadv2`、`pwritev2`、`copy_file_range` 未声明；补齐四项后，构建推进到 `libpython`，因 `ln -f` 创建硬链接被拒绝而失败。
- 根因：CPython 的函数链接探测与 Android 目标 API 头文件声明不一致；共享库 Makefile 默认使用硬链接，而当前 Android 应用环境拒绝创建硬链接。
- 修改文件：`build.sh`、新增 `plugins_termux_python.go`、本 README；已可用的命令参数和进程执行兼容文件保持原样。
- 修复内容：在 Python 安装回调中补齐四项 configure 缓存默认值，并通过 CPython 原有 `LN` 配置入口改用软链接；不替换系统工具、不修改插件仓库。此前 PRoot 路线不适用于原生 Termux 需求，本次使用此适配继续处理。
- 已知结果：现有实测日志证明四项禁用已使构建推进到共享库链接阶段；本次已核对上游环境传递、`LN` 配置及 Makefile 用途，并完成补丁匹配与语法静态检查。新产物尚待 Actions 构建及 Termux 实测，未声称整个 Python 安装已成功。

### 2026-09-07：补充 Python 扩展依赖与 Termux 搜索路径

- 实测进展：使用 `488738f` 对应适配后，原安装命令完成并输出 `Installed Python-3.11.13`，此前函数未声明及共享库硬链接错误已通过；保留对应五项环境默认值和启动执行链。
- 现象：安装结束前报告 `_curses`、`_ctypes`、`readline` 未编译，解释器可安装但这些标准库扩展不完整。
- 原因与边界：CPython 3.11 的 `setup.py` 通过自己的目录列表查找扩展依赖，并从 `CPPFLAGS` / `LDFLAGS` 加入非标准位置。此前未显式传入 Termux 的 `$PREFIX` 路径，README 也未列出这三个扩展的依赖。仅凭安装摘要无法判定手机上的每个依赖包是否已安装。
- 修改文件：`plugins_termux_python.go`、本 README。
- 修复内容：仅对 Python 安装回调补齐动态搜索路径，保留原有 flags；补充 Termux 依赖命令和单个已安装版本的重编步骤，不自动安装包或删除版本。
- 已知结果：已核对 CPython 扩展探测、Termux 包名及 asdf 的已安装版本跳过行为，并完成 Go 语法与 diff 静态检查；新产物及三个扩展的完整安装仍待 Termux 实测。

依据：[asdf 执行入口](https://github.com/asdf-vm/asdf/blob/master/internal/exec/exec.go)、[Termux linker 执行链](https://github.com/termux/termux-exec-package/blob/master/site/pages/en/projects/docs/technical/index.md)、[Go Android 系统调用分支](https://github.com/golang/go/blob/master/src/syscall/syscall_linux.go)、[本次 CPython 报错及回退源码](https://github.com/python/cpython/blob/v3.11.13/Python/fileutils.c)、[Termux 官方 Python 依赖与特性禁用](https://github.com/termux/termux-packages/blob/master/packages/python/build.sh)、[CPython 的 LN 配置](https://github.com/python/cpython/blob/v3.11.13/configure.ac)、[CPython 共享库链接规则](https://github.com/python/cpython/blob/v3.11.13/Makefile.pre.in)、[CPython 扩展搜索路径](https://github.com/python/cpython/blob/v3.11.13/setup.py)。
