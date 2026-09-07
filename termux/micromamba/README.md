# micromamba（Termux / PRoot）

**本方案必须使用 PRoot-Distro。不使用 PRoot 的原生 Termux 环境不适用，不作为本次 Python 安装问题的处理路线；原生编译适配见 [asdf](../asdf/README.md)。本目录保留供 PRoot 场景参考。**

## 用途与产物

- 用途：在 ARM64 Termux 中管理预编译 Python 和 Conda 环境，避免通过 asdf-python / pyenv 在手机上编译 CPython。
- 上游：[mamba-org/micromamba-docker](https://github.com/mamba-org/micromamba-docker)，采用官方 `ghcr.io/mamba-org/micromamba:latest` 的 Linux ARM64 镜像。
- 技术栈：C++ micromamba、Conda 二进制包、Linux glibc 运行环境，以及 Termux 的 PRoot-Distro。**这是 PRoot 适配包，不是 Android/Bionic 原生二进制。**
- 产物：`latest` Release 的 `micromamba.termux.tar.gz`，包含 `micromamba` 启动脚本、`micromamba.oci.tar` 完整镜像、README、来源记录和 SHA-256 校验文件。
- 官方镜像包含 micromamba、Bash、glibc 和 SSL 证书，初始不含 Python；创建环境时下载所选 Python 的预编译包。

## 打包方式

- 入口：`.github/workflows/termux.yml` 的 `build-micromamba` 独立 Job，手动选择 `micromamba`；沿用每日全量构建及 main 分支按目录变更构建。
- `build.sh` 在 Actions 临时目录通过 Skopeo 解析官方 `latest`，确认 Linux ARM64 后按当次 digest 复制完整 OCI 镜像；不运行镜像、不编译 Python、不固定应用版本。
- Skopeo 在复制时检查镜像内容摘要；归档额外附带镜像及启动脚本 SHA-256，`SOURCE.txt` 记录官方镜像 digest 和打包提交。
- 手机使用 Termux 官方 PRoot-Distro 5 或更新版本导入 OCI 镜像；无需 Docker daemon、root 权限或 QEMU 跨架构模拟。

## 安装与运行

以下均在 **Termux 终端**执行。先下载 Release 的 `micromamba.termux.tar.gz` 并进入下载文件所在目录。镜像和环境应存放在 Termux 应用内部存储，不在共享存储中直接展开 Linux 文件系统。

```bash
# 安装或更新 Termux 官方 PRoot-Distro，要求支持 OCI 导入的 5 或更新版本
pkg install proot-distro

# 准备独立解压目录
mkdir -p ./micromamba-package
# 解压下载的适配包
tar -xzf ./micromamba.termux.tar.gz -C ./micromamba-package

# 进入解压目录
cd ./micromamba-package
# 核对归档内镜像和启动脚本的校验值
sha256sum -c SHA256SUMS

# 一次性导入独立的 micromamba Linux 环境
proot-distro install --name micromamba-termux ./micromamba.oci.tar
```

`micromamba-termux` 是本包固定的容器名。导入需要镜像、解压后文件系统所需空间，后续还需 Python 环境和缓存空间。同名环境已存在时不要删除或重置，继续使用已有环境即可。

下面的命令只写入 `$PREFIX/bin/micromamba` 启动脚本；若已有同名文件会被替换，原有 asdf、smug、Python 环境和 shell 配置不受此命令修改。

```bash
# 将 Termux 启动脚本安装到 PATH
install -m 755 ./micromamba "$PREFIX/bin/micromamba"
```

后续命令可在 Termux 的项目目录执行。将 `<环境名>`、`<Python版本>`、`<脚本名>` 替换为实际值；当前目录作为容器内 `/work` 挂载，使用相对路径访问项目文件。

```bash
# 从 conda-forge 下载 Python 二进制包并创建独立环境
micromamba create -n "<环境名>" --override-channels -c conda-forge "python=<Python版本>" pip

# 使用指定环境的 Python 运行当前项目中的脚本
micromamba run -n "<环境名>" python "./<脚本名>.py"

# 进入指定环境的交互 Bash
micromamba run -n "<环境名>" bash
```

## 运行与兼容说明

- 环境保存在容器内部 `/opt/conda`，与 Termux 原生 Python、asdf 安装目录分开；容器退出后已安装环境仍保留。
- 启动脚本只进入已安装容器，不会自动安装、删除或重置容器，也不会修改宿主 `.zshrc` / `.bashrc`。
- 使用 `run` 执行程序；此入口不支持在 Termux 宿主执行 `activate` / `deactivate` / `shell` 初始化，避免将容器内部路径用于宿主 shell。
- `--isolated` 减少默认宿主路径绑定；当前项目目录可写，修改 `/work` 中的文件会修改真实项目。PRoot 不是安全沙箱。
- 所选 Python 版本必须在 conda-forge 提供 Linux aarch64 二进制包；额外使用 pip 安装仅提供源码的第三方扩展时，仍可能需要编译该扩展。
- PRoot 有系统调用转发开销；本包不保证与 Termux 原生库、原生二进制或所有 Android 内核功能兼容。
- PRoot-Distro 自身所需的 Python 由 Termux 包管理器提供预编译包，不需要通过 asdf 编译。

## 变更记录

### 2026-09-07：增加预编译 Python 的 Termux 使用入口

- 背景：asdf 已能添加 Python 插件并进入安装流程，但 python-build 编译 CPython 时出现 `close_range` 未声明错误；这是 CPython 与 Android C 库适配问题，不能通过重编 asdf 主程序解决。
- 修改文件：新增 `build.sh`、`micromamba`、本 README，并接入现有 Termux workflow；保留 asdf / smug 构建和运行实现。
- 路线：保留官方 Linux ARM64 micromamba 镜像，通过 PRoot-Distro 提供 glibc 环境，再下载 Conda Python 二进制包，不声称将 Linux 包转换成 Android 原生包。
- 已知结果：已核对官方镜像结构、ARM64 发布配置、PRoot-Distro 的 OCI 导入及参数传递源码，并完成 Bash / YAML / 路径静态检查；尚无本包的 Actions 构建和手机实测结果。

### 2026-09-07：明确 PRoot 使用边界

- 背景：需要原生 Termux 的 Python 安装方式，不采用 PRoot。
- 修改文件：仅本 README，在开头明确本方案必须使用 PRoot-Distro，并指向 asdf 的原生编译适配。
- 已知结果：本次只补充适用范围，保留现有打包文件和 workflow；没有将 micromamba 或 Conda 的 Linux 包描述为 Android 原生包。

依据：[micromamba 的 glibc 要求](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)、[官方镜像内容](https://micromamba-docker.readthedocs.io/en/latest/quick_start.html)、[PRoot-Distro OCI 导入与运行](https://github.com/termux/proot-distro#commands-reference)。
