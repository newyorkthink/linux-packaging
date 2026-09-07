# asdf（Termux）

## 用途与产物

- 上游：[asdf-vm/asdf](https://github.com/asdf-vm/asdf)，通过插件管理项目所需的语言及工具版本。
- 技术栈：Go、urfave/cli；插件及 hook 通过 Bash 执行，插件仓库由 Git 管理。
- 目标：Android ARM64（Termux aarch64），`GOOS=android GOARCH=arm64 CGO_ENABLED=0`。
- 产物：`latest` Release 中的 `asdf.termux.tar.gz`，归档内为单个 `asdf` 可执行文件。
- 运行依赖：正常的 Termux `sh`、`bash`、`git` 环境，以及所选插件实际需要的工具；手机不需要安装 Go。

## 已验证环境与重建顺序

2026-09-07 的实机反馈已确认：Python 安装、psutil 安装、cryptography 导入、coincurve 构建，以及两个项目的实际运行均已正常。当前环境无需重新安装或重复修补。以下用于以后重建本次已验证的依赖组合，不要求虚拟环境或 PRoot。

### repair_python_xattr.py 何时运行

| 场景 | 需要的处理 |
| --- | --- |
| 用本仓库带 xattr 配置的新 asdf 产物重新安装 Python | 安装回调已自动传入 `ac_cv_header_sys_xattr_h=no`，正常情况下无需运行脚本默认模式。仅更新 asdf 二进制不会修改旧 Python。 |
| 只重建虚拟环境，沿用已修好的基础 Python | xattr 修复仍在基础 Python 中，不必为每个虚拟环境重做；第三方包仍需重新安装。 |
| 旧 Python 仍在 `.egg-info.__bkp__` 出现扩展属性复制错误 | 在该 Python 中运行一次脚本默认模式；命令见后文对应故障说明。 |
| cryptography 重新安装后缺少 Python 符号 | 在包安装完成后运行 `--cryptography`；默认 xattr 模式不处理此问题。 |
| 从源码重新安装仍含旧许可证判断的 coincurve | 使用下面的源码修补步骤；不属于修补脚本的功能。已有修正后的同版本包时无需重编。 |

**不是 asdf 无法接入：Python 构建所需的 xattr 配置已经写入 `plugins_termux_python.go` 并接入构建。** 独立 `.py` 文件保留给旧解释器和已安装扩展使用；第三方包稍后才由 pip 安装，不能在创建 Python 时修补尚不存在的扩展文件。保持当前已可用的 asdf 和脚本逻辑。

### 两个项目的依赖安装顺序

在 **Termux 终端**执行。先按后文“运行与兼容说明”安装编译库及所需 Python，并按“pip 构建依赖提示缺少 Rust”准备工具链。使用已选定的 asdf Python；若原本使用虚拟环境，先激活它。所有命令须作用于同一个 Python 环境。将本目录的 `repair_python_xattr.py` 下载后，进入其所在目录执行。

coincurve 构建及 cryptography 补链接另需以下工具；这些 Termux 系统依赖不随虚拟环境重建而消失。

```bash
# 安装 coincurve 源码构建和 cryptography 补链接所需工具
pkg install git cmake ninja patchelf
```

下面保留本次成功的原命令及项目明确要求的版本，作为实测组合。**只有四条 pip 命令还不完整：需要时区库、coincurve 源码处理，以及适用时的 cryptography 补链接。**

```bash
# 更新当前 asdf Python 或已激活虚拟环境的 pip
pip install --upgrade pip

# 安装进程依赖
pip install psutil

# 安装第一个项目的原有依赖
pip install "tabulate>=0.9.0" "wcwidth>=0.2.0" pytest schwab-py==1.5.1

# 给当前 Python 补充项目需要的时区数据库
python -m pip install tzdata
```

每条命令成功后再继续。旧 Python 若在元数据复制阶段失败，先按后文修复 xattr，再重试失败的原命令。

接着执行下面原样保留的成功步骤。**本节和后文通用 coincurve 示例是同一处理，不需要执行两遍。** 这些固定版本是本次项目要求；未来项目变更版本时需重新核对，不能直接套用旧补丁。

```bash
(
# 任一步失败即停止本次安装
set -e

# 创建独立源码目录
coincurve_src="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/coincurve.XXXXXX")"

# 获取 ccxt 要求的 coincurve 原版源码
git clone --depth 1 --branch v21.0.0 https://github.com/ofek/coincurve.git "$coincurve_src"

# 仅修正新版 cffi 许可证的查找位置
python - "$coincurve_src/hatch_build.py" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
old = 'f.parent.name.endswith(".dist-info")'
new = 'f.parts[0].endswith(".dist-info")'
if source.count(old) != 1:
    raise SystemExit("源码入口不匹配，未修改文件。")
path.write_text(source.replace(old, new))
PY

# 安装修正后的同版本包，保留已有运行依赖
python -m pip install --no-deps "$coincurve_src"

# 原样执行你的安装命令
pip install ccxt==4.5.64 requests ntplib==0.4.0 pyyaml colorama pybit==5.17.0
)
```

最后，对于本次需要补 Python 共享库链接的 cryptography 安装，执行已保存的修补入口。它先备份扩展，再添加当前 Python 的共享库完整路径；相同依赖已存在时不重复修改。必须在包安装完成后执行，重新安装或升级该包可能覆盖此修改。

```bash
# 为本次 cryptography 安装补齐当前 Python 共享库依赖
python ./repair_python_xattr.py --cryptography
```

之后沿用两个项目已经成功的启动命令。以上是现有实机成功步骤的整理，未另行执行删除重建；未锁定的间接依赖会随上游发布变化，不能视为未来任意时间都完全相同的环境。

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
- 后续 Python 构建另设 `ac_cv_header_sys_xattr_h=no`，沿用 Termux 官方 Python 的配置，避免文件复制尝试写入 Android 不允许设置的扩展属性。此选项不会追溯修改已安装的解释器。
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

### 已安装 Python 的 pip 元数据复制错误

若安装源码包时在 `.egg-info.__bkp__` 出现批量 `Permission denied`，与 Termux 已记录的 `shutil.copytree` / 扩展属性复制问题吻合。此阶段还未开始编译该包的 C 扩展；不能通过更改 `ln` 解决。

目录中的 `repair_python_xattr.py` 可修补现有解释器，无需卸载 Python、虚拟环境或已安装包。默认入口仅将标准库 `shutil._copyxattr` 改为空操作，保留文件内容、权限和时间戳的复制逻辑；不会忽略普通文件读写权限错误。脚本先保存唯一命名的原文件备份，再原子替换。**修改作用于当前虚拟环境所用基础 Python 的 `shutil.py`，使用同一基础 Python 的其他虚拟环境也会生效。**

在 **Termux 终端**激活需要修复的虚拟环境，下载本目录的 `repair_python_xattr.py`，进入其所在目录后执行：

```bash
# 修补当前解释器的文件扩展属性复制兼容性
python ./repair_python_xattr.py
```

脚本首行指定 `#!/usr/bin/env python3`，也支持直接执行；此时使用当前 PATH 中的 `python3`。通过网页下载的文件可能没有执行权限，在同一 **Termux 终端**及脚本目录执行：

```bash
# 为下载的修补脚本添加执行权限
chmod +x ./repair_python_xattr.py

# 使用当前环境中的 Python 3 直接运行脚本
./repair_python_xattr.py
```

随后重试原来的 pip 安装命令。已有 Python 使用此入口即可；本次不必为了该问题重新运行 Actions 或重编 Python。默认入口只处理元数据复制，不代表目标包后续编译及全部运行功能已经通过验证。

### pip 构建依赖提示缺少 Rust

若 `cryptography` 安装在构建 `maturin` 时出现 `Rust not found, installing into a temporary directory`，随后报告 `Unsupported platform`，说明构建进程没有在 PATH 找到 `cargo`，转而尝试自动安装 Rust。原生 Termux 应使用自己的 Rust 工具链；重新构建 asdf 或 Python 不会补装该工具链。

在 **Termux 终端**补齐源码构建所需依赖，然后在原虚拟环境中重试原来的 pip 安装命令：

```bash
# 安装 Rust、C 编译工具及 cryptography 所需原生库
pkg install rust clang make pkg-config openssl libffi
```

补装工具链后已取得 cryptography 构建成功的实机反馈；其后出现的 Python 符号缺失由下文补链接步骤解决。依据：[maturin 的 cargo 探测与自动安装入口](https://github.com/PyO3/maturin/blob/main/setup.py)、[cryptography 源码构建依赖](https://cryptography.io/en/latest/installation/)、[Termux Rust 包](https://github.com/termux/termux-packages/blob/master/packages/rust/build.sh)。

### asdf Python 与已有安装的修补入口

可以直接使用 asdf 选定的 Python，虚拟环境用于隔离项目依赖，不是运行前提。上面的虚拟环境步骤仅适用于原本使用虚拟环境的项目；直接使用 asdf 时，应在该解释器环境中安装依赖和运行修补脚本。

`plugins_termux_python.go` 已把 xattr 特性禁用接入新 Python 的安装流程。独立脚本用于修补此前已经安装的解释器；`build.sh` 不会将该脚本嵌入 asdf 二进制。第三方包是在手机上由 pip 安装的，其安装后修补保留为显式操作。

若项目使用 `zoneinfo`，但报缺少 `tzdata` 或找不到命名时区，在 **Termux 当前 Python 环境**执行已确认有效的命令：

```bash
# 给当前 Python 补充时区数据库
python -m pip install tzdata
```

### cryptography 已安装但缺少 Python 符号

若 `_rust.abi3.so` 导入时报 `cannot locate symbol "PyExc_Warning"`，可使用目录中修补脚本新增的 `--cryptography` 选项。它沿用已实测成功的步骤：先备份扩展内容，再通过 `patchelf --add-needed` 补入当前 Python 的共享库完整路径；相同依赖已存在时不重复修改。**此选项会修改当前解释器所找到的 cryptography 扩展文件；重新安装或升级该包可能覆盖修补。** 默认的 xattr 入口不变。

在 **Termux 当前 Python 环境**、已下载的新版脚本所在目录执行；此选项需要系统已安装 `patchelf`：

```bash
# 仅修补当前 cryptography 的 Python 共享库依赖
python ./repair_python_xattr.py --cryptography
```

依据：[Termux 官方 cryptography 补链接步骤](https://github.com/termux/termux-packages/blob/master/packages/python-cryptography/build.sh)。

### coincurve 构建时找不到 cffi 许可证

`coincurve 21.0.0` 的 `hatch_build.py` 只接受 `.dist-info/LICENSE`，不能识别新版 cffi 的 `.dist-info/licenses/LICENSE`，因此在生成元数据时失败。可在所需版本的独立源码副本中采用上游已修正的路径判断；保留实际许可证文件及打包步骤，不降级当前环境的 cffi，不修改 cryptography。

在 **Termux 当前 Python 环境**执行；将 `<coincurve版本>` 替换为依赖实际要求、且仍使用该旧判断的版本。需要已有 Git、Clang、CMake、Ninja 和 pkg-config。括号内任一步失败即停止；源码目录会保留以便查看构建错误。

```bash
(
# 只在本次安装子 shell 中启用出错即停
set -e

# 创建独立源码目录
coincurve_src="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/coincurve.XXXXXX")"

# 下载依赖要求的原版源码
git clone --depth 1 --branch "v<coincurve版本>" https://github.com/ofek/coincurve.git "$coincurve_src"

# 仅修正许可证路径判断，源码不匹配时停止
python - "$coincurve_src/hatch_build.py" <<'PATCH_PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
old = 'f.parent.name.endswith(".dist-info")'
new = 'f.parts[0].endswith(".dist-info")'
if source.count(old) != 1:
    raise SystemExit("源码许可证入口不匹配，未修改文件。")
path.write_text(source.replace(old, new))
PATCH_PY

# 使用当前解释器安装修正后的同版本包，不更改已有运行依赖
python -m pip install --no-deps "$coincurve_src"
)
```

安装完成后，原样重试项目原来的 pip 安装命令。后续实机日志已确认 coincurve 21.0.0 的 wheel 构建和安装成功，原依赖命令完整执行成功；随后反馈确认项目运行正常。本文开头保存了对应的原命令。

依据：[旧版许可证判断](https://github.com/ofek/coincurve/blob/v21.0.0/hatch_build.py)、[上游路径修正](https://github.com/ofek/coincurve/blob/master/hatch_build.py)、[同类 Termux 问题](https://github.com/ofek/coincurve/issues/187)。

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

### 2026-09-07：补齐 pip 元数据复制的 xattr 兼容处理

- 实测进展：新一次 Python 安装完成，安装摘要中不再出现 `_curses`、`_ctypes`、`readline` 缺失提示；虚拟环境创建和 pip 升级也已成功。保留 `6c78eea` 的依赖路径及此前编译兼容处理。
- 新现象：安装 `psutil` 时，setuptools 备份 `.egg-info` 目录报批量 `Permission denied`，导致 `metadata-generation-failed`。
- 原因依据：上游 setuptools 在此调用 `shutil.copytree`；日志与 Termux 官方问题 #16879、#20809 的扩展属性复制失败一致。官方 CPython 使用 `ac_cv_header_sys_xattr_h=no` 处理该平台限制；现有安装摘要没有单独列出失败的系统调用，按此已知问题进行针对性适配。
- 修改文件：`plugins_termux_python.go`、新增 `repair_python_xattr.py`、本 README。
- 修复内容：为后续构建补充官方 xattr 配置；为已有解释器提供独立、带备份的标准库修补入口，不要求重新安装 Python 或虚拟环境。
- 已知结果：已核对官方配置与 setuptools / CPython 复制链，完成 Python、Go 语法及变更范围静态检查；当前修补尚待 Termux 实测，不声称 `psutil` 或其下游依赖全部可用。

### 2026-09-07：补齐修补脚本的直接执行入口

- 现象：直接执行 `./repair_python_xattr.py` 报 `import: not found` 和 shell 语法错误。
- 根因：脚本缺少解释器首行，直接启动被 shell 当作 shell 脚本解析。
- 修改文件：`repair_python_xattr.py`、本 README。
- 修复内容：添加 `#!/usr/bin/env python3` 和 Git 可执行权限，补充下载后的直接运行说明；原有修补逻辑和 `python ./repair_python_xattr.py` 命令保持原样。
- 已知结果：已完成 Python 语法和原有代码一致性静态检查；实测日志已显示 `psutil` 元数据生成、wheel 构建及安装成功。后续 `cryptography` 在 `maturin` 自动安装 Rust 阶段失败，README 补充原生工具链依赖，未将该依赖的完整构建标记为通过。

### 2026-09-07：保存已验证的 cryptography 修补及 coincurve 构建处理

- 实测进展：安装 Rust 后，cryptography 和业务依赖已完成安装；补充 tzdata 并为 cryptography 添加当前 Python 共享库依赖后，Schwab 导入及行情列表已正常运行，保留这些已验证步骤。
- 现象与根因：cryptography 的 Rust 扩展因缺少 Python 共享库链接而导入失败；另一次依赖安装中，coincurve 的旧许可证路径判断未匹配新版 cffi 的许可证布局。
- 修改文件：`repair_python_xattr.py`、本 README；asdf 构建及 Go 兼容源码保持原样。
- 修复内容：将已验证的备份和补链接代码收进 `--cryptography` 手动选项，完整保留原 xattr 函数；记录当前解释器与虚拟环境的关系，并给出仅修正 coincurve 许可证判断的同版本源码安装步骤。
- 已知结果：cryptography 的独立修补步骤已有实机成功结果；新增选项及 coincurve 指令完成静态检查，未在云端代替手机运行安装，不把尚未取得结果的 coincurve 构建标记为通过。

### 2026-09-07：确认两个项目运行正常并整理重建步骤

- 实测结果：coincurve 21.0.0 修正许可证判断后成功构建、安装；原 CCXT 及其余依赖安装完成，两个项目均反馈运行正常。
- 已解决的问题：旧 Python 的 xattr 复制错误、cryptography 缺少 Python 共享库链接，以及 coincurve 不识别新版 cffi 的许可证目录；各自根因及代码变更见前述记录和 `6378e6a`。
- 本次修改文件：仅本 README；没有改变 asdf、修补脚本、依赖版本或 workflow。
- 整理内容：区分重装 Python、重建虚拟环境和重装第三方包；保存原样成功的 coincurve 命令，补齐两个项目重建时的时区库和扩展补链接顺序。
- 验证边界：运行结论来自现有实机日志及反馈；本次仅整理文档，没有再次删除重建环境或运行 Actions。以前记录中的“待实测”描述保留为当时状态，以本条及开头当前状态为准。

依据：[asdf 执行入口](https://github.com/asdf-vm/asdf/blob/master/internal/exec/exec.go)、[Termux linker 执行链](https://github.com/termux/termux-exec-package/blob/master/site/pages/en/projects/docs/technical/index.md)、[Go Android 系统调用分支](https://github.com/golang/go/blob/master/src/syscall/syscall_linux.go)、[本次 CPython 报错及回退源码](https://github.com/python/cpython/blob/v3.11.13/Python/fileutils.c)、[Termux 官方 Python 依赖与特性禁用](https://github.com/termux/termux-packages/blob/master/packages/python/build.sh)、[CPython 的 LN 配置](https://github.com/python/cpython/blob/v3.11.13/configure.ac)、[CPython 共享库链接规则](https://github.com/python/cpython/blob/v3.11.13/Makefile.pre.in)、[CPython 扩展搜索路径](https://github.com/python/cpython/blob/v3.11.13/setup.py)、[setuptools 元数据备份](https://github.com/pypa/setuptools/blob/main/setuptools/command/dist_info.py)、[Termux 同类元数据复制错误](https://github.com/termux/termux-packages/issues/20809)。
