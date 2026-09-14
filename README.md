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

截至 2026-09-14，以下问题暂时保留，后续继续处理前必须先完整阅读对应目录现有 README / 问题记录；已经解决的构建兼容层和已确认基线不得回退。

- `runimage/jriver-media-center`：JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照；详见 [runimage/jriver-media-center/README.md](./runimage/jriver-media-center/README.md) 与 [TEST_ISSUE.md](./runimage/jriver-media-center/TEST_ISSUE.md)。
- `jriver`：2026-09-13 RunImage + quick-sharun 入口已实机确认从终端启动时 GUI、简体中文界面和文件选择器正常，NVIDIA 自动处理已禁用，成品已启用安静模式。2026-09-14 已确认通过 Rofi AppImage 启动时外层程序、DwarFS、SSRV 和包内 `mediacenter36` 完整进程链均存在，但始终没有 GUI，窗口切换列表中也没有 JRiver；其他 AppImage 通过同一 Rofi 启动正常。外层入口包装曾造成自递归回归，随后改用 `Run.rcfg` 清理父级 Sharun 环境也未解决，因此两种改动均已移除，构建脚本恢复到最后实机确认正常的版本。当前根因不确定，问题保持搁置；没有新证据前不得继续重复环境清理或猜测 GVFS、D-Bus、`LD_PRELOAD`、TTY / 后台等待等方向。Fcitx5 实际中文输入、网页音频和影院模式鼠标操作仍未验证。详见 [RunImage + quick-sharun 路线记录](./jriver/README_runimage_quick.md)；[旧版稳定路线记录](./jriver/README.md) 继续独立保留。
- `remotedesktopmanager`：AppImage 当前可以正常打包，ICU 与多语言界面可用。现存问题是内置终端使用 Fcitx5 中文输入时，会把候选操作的原始按键同时发送到终端，出现 `^[[A`、`^[[D` 等转义字符；当前 AppImage 构建脚本无法直接修复。后续应继续从 Remote Desktop Manager 内置终端的输入事件处理或上游实现方向定位；详见 [remotedesktopmanager/README.md](./remotedesktopmanager/README.md)。
- `parsec`：Run `#440` 已成功构建，真实 Linux 运行确认 Decoder 已从空白恢复为 `Software`。后续显式封装 Intel / NVIDIA / VDPAU 厂商 backend 的版本出现真实启动黑屏，因此已撤下这些厂商 backend，保留 FFmpeg 4.4、通用 libva 与真实 `libjpeg.so.8` 修复。下一份产物需确认 GUI 恢复、黄色 libjpeg8 提示是否消失，以及宿主驱动栈能否提供硬件 Decoder；详见 [parsec/README.md](./parsec/README.md)。


## Releases

构建产物通常发布到仓库的 [Releases](https://github.com/newyorkthink/linux-packaging/releases)，持续更新版本使用 `latest` Release。

> 本 README 仅作为仓库入口说明；AI 操作本仓库时请以 [AGENTS.md](./AGENTS.md) 为完整规范。
