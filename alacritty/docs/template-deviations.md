# Alacritty LinuxDeploy 专属差异

## 构建入口与标准

正式入口为 [build_alacritty.sh](../build_alacritty.sh)，由[统一工作流](../../.github/workflows/build.yml)中的 Alacritty 专用 Job 执行。脚本保留[LinuxDeploy 规范](../../linuxdeploy_projects.md)的十个标准阶段和[固定注释](../../docs/linuxdeploy-comments.md)，额外步骤均用 `# 本程序专属处理：` 标注。

现有 [linuxdeploy-cli-apt.sh](../../templates/appimage/linuxdeploy-cli-apt.sh) 面向 Ubuntu 软件包，不具备源码编译及应用 X11 IME 补丁的阶段。直接使用旧版 APT 软件包无法保留此前输入故障的修复。因此，本程序继续采用既有 LinuxDeploy 专用源码流程；不修改公共模板，不将此特例推广给其他程序。

## 实际差异

| 阶段 | 处理内容 | 依据和影响 |
| --- | --- | --- |
| 准备构建目录 | 复用 `prepare_build_workspace.sh` 管理当前程序的 `source`、`AppDir`、`dist`。 | 沿用标准工作区，不重复初始化。 |
| 准备构建环境 | 公共 APT 入口安装编译及 X11 依赖，增加 `librsvg2-bin` 供 SVG 图标转换。 | Ubuntu 22.04 GitHub Runner 已提供 Rust、Cargo 和 Rustup，不再通过 `curl` 重复安装。 |
| 下载打包工具 | 复用 `prepare_linuxdeploy_tools.sh`，不启用 GTK、Qt、GStreamer 插件。 | 工具、Type 2 runtime 和环境配置由公共入口负责。 |
| 下载并准备应用 | 公共 GitHub 入口取得最新正式版源码和标签；使用 `git apply --check` 核对并应用 `patches/0001-x11-keep-ime-enabled.patch`，随后 `cargo build --release`。 | 保留 X11 IME 常开保护；补丁不匹配则构建失败，不允许静默跳过。 |
| 准备桌面资源和运行库 | 复制源码编译的二进制并执行 `strip --strip-unneeded`；取同一正式版的 desktop 与 SVG 图标，复制 XKB / Compose 数据。 | 不使用 Ubuntu APT 的旧版程序；保留原 LinuxDeploy 输入运行环境。 |
| 准备 AppRun | 在主脚本内联写入 `AppDir/AppRun`，设置包内运行库路径、共享数据目录、XKB / Compose 数据和宿主 terminfo。 | 不继承外层 AppImage 的库路径；原外置 AppRun 不再使用。 |
| 核心打包 | 使用 LinuxDeploy，显式带入 `libxkbcommon-x11.so.0`、官方桌面入口和图标。 | 不额外强制添加其他 XKB 库；其余依赖按 LinuxDeploy 解析。 |
| 整理产物 | 单行调用 `package_appimage.sh`，封装 `dist/alacritty.AppImage` 并保存 `dist/version.txt`。 | Runtime、权限、校验值及版本记录由公共入口处理。 |

构建环境固定为 `ubuntu-22.04`，保持已记录的 LinuxDeploy 基线。具体路径与环境变量见[固定配置](./hardcoded.md)，pkgforge-dev 的取舍见[上游差异](./pkgforge-differences.md)，历史故障和版本记录见 [README](../README.md)。

此次只完成脚本结构、引用、注释及文档的静态核对。先前旧入口的构建记录不代表新入口已经完成实际构建或真实桌面长期验证。

## 2026-11-08：APT 依赖冲突

构建任务 [42479443759](https://github.com/newyorkthink/linux-packaging/actions/runs/42479443759/job/128728000116) 在「准备构建环境」阶段失败：公共 APT 入口已经安装 `pkgconf`，应用依赖列表又包含与其冲突的 `pkg-config`，报错为 `pkgconf : Breaks: pkg-config (>= 0.29-1)`，APT 退出码为 100。

本次只从应用依赖安装命令中移除 `pkg-config`，由公共 `pkgconf` 提供所需的 pkg-config 接口。公共脚本、Runner、其他依赖、补丁、编译及封装步骤均不改变。已静态核对修改范围，修复后的构建结果尚待实际验证。
