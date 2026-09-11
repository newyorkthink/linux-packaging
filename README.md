# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成可分发的 AppImage / RunImage。

> [!IMPORTANT]
> **AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。**  
> 本仓库关于修改范围、安全要求、打包方式、GitHub Actions、Release 和验证流程的详细规范，均以 `AGENTS.md` 为准。

## 仓库说明

- 每个应用原则上使用独立目录维护构建脚本和相关文件。
- 正式 AppImage 构建统一由 `.github/workflows/build.yml` 管理。
- 已验证正常的现有构建方案视为稳定基线，修改时应遵循最小变更原则。
- 优先使用上游官方程序、资源和发布包，只处理 Linux 打包、依赖、启动及兼容性问题。

## 当前待处理

截至 2026-09-12，以下问题暂时保留，后续有空或 AI coding 额度充足时再继续处理。继续前必须先完整阅读对应目录现有 README / 问题记录；已经解决的构建兼容层和已确认基线不得回退。

- `runimage/jriver-media-center`：JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照；详见 [runimage/jriver-media-center/README.md](./runimage/jriver-media-center/README.md) 与 [TEST_ISSUE.md](./runimage/jriver-media-center/TEST_ISSUE.md)。
- `jriver`：JRiver AppImage 的 quick-sharun / preload / appimagetool 构建兼容问题已经修复，当前可以正常完成 AppImage 构建和发布，但实机启动后仍没有可见 GUI。后续不要再次回退已经解决的构建兼容层，也不要破坏现有 CEF、网页音频、Fcitx5 和 glibc 隔离链；下一轮应直接定位 `AppRun → 01-path-mapping-hardcoded.hook → pathmap / run-mc.sh → Sharun → mediacenter36` 的实际运行时启动链，优先采集完整启动日志或 `strace -f`。详见 [jriver/README.md](./jriver/README.md)。
- `remotedesktopmanager`：AppImage 当前可以正常打包，ICU 与多语言界面可用。现存问题是内置终端使用 Fcitx5 中文输入时，会把候选操作的原始按键同时发送到终端，出现 `^[[A`、`^[[D` 等转义字符；当前 AppImage 构建脚本无法直接修复。后续应继续从 Remote Desktop Manager 内置终端的输入事件处理或上游实现方向定位；详见 [remotedesktopmanager/README.md](./remotedesktopmanager/README.md)。

## Releases

构建产物通常发布到仓库的 [Releases](https://github.com/newyorkthink/linux-packaging/releases)，持续更新版本使用 `latest` Release。

> 本 README 仅作为仓库入口说明；AI 操作本仓库时请以 [AGENTS.md](./AGENTS.md) 为完整规范。
