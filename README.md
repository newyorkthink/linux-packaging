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
- `parsec`：当前 AppImage 已确认 GUI 可正常启动，`libjpeg8` 缺失问题已修复，`Decoder` 已恢复为可用的 `Software`；硬件 Decoder 仍未恢复，VA-API / VDPAU 兼容问题后续继续处理。详见 [parsec/README.md](./parsec/README.md)。


## Releases

构建产物通常发布到仓库的 [Releases](https://github.com/newyorkthink/linux-packaging/releases)，持续更新版本使用 `latest` Release。

### AppImage 版本说明

当前统一版本元数据机制不会向 AppImage 文件内部额外写入版本信息，也不会为了版本管理修改 AppImage 内部内容。

版本信息单独通过构建目录中的 `version.txt` 和 Release 中的 `software_versions.json` 维护。

AppImage 在本机运行时也不会自动生成版本信息。

少数项目如果原本就存在 `X-AppImage-Version` 等内部版本字段，属于其原有打包逻辑，不是本次统一版本元数据机制新增的。

### 软件版本清单

`latest` Release 中的 `software_versions.json` 用于记录已接入更新器的软件版本、稳定资产名和 SHA-256。

发布逻辑固定为：

1. `Publish successful software versions` Job 开始时只读取一次当前 `software_versions.json`，并把它作为本次 Job 唯一的本地工作清单。
2. 某个软件的独立构建 Job 成功后，发布器读取该软件的 `version.txt` 与当前 Release 资产 SHA-256，更新本地工作清单中的对应条目。
3. 每成功处理一个软件，就立即把当前这份本地工作清单上传并覆盖 `latest/software_versions.json`，因此成功的软件不需要等待其他软件全部完成。
4. 后续软件继续基于同一个已经更新过的本地工作清单追加或覆盖自己的条目；**禁止在每个软件成功后重新从 Release 下载清单，也禁止重新从空 `{}` 开始。**
5. 发布器使用独立 concurrency group 串行执行，避免多个新的 workflow run 同时写入同一个 `software_versions.json`。
6. 发布器 Job 位于 `Plan` 之后、各软件构建 Job 之前，使全量构建时优先进入 runner 队列，避免全部并发 runner 被构建任务占满后版本清单长时间不更新。

某个软件构建失败时，不更新该软件条目；已经写入本地工作清单的其他软件记录继续保留。

仅修改 `.github/workflows/build.yml` 本身时，不再自动触发全部 AppImage 重构建；需要全量构建时使用手动 `all` 或定时任务。

版本发布逻辑已从 `.github/workflows/build.yml` 的内嵌实现解耦到 `.github/actions/publish-software-versions` composite action；`build.yml` 仍保留同一个 `Publish successful software versions` Job 并调用该 action，因此 GitHub Actions 左侧不会额外出现独立的发布 workflow。

### 2026-09-17：修复全量构建时版本清单丢失

此前发布器在每个软件成功后都会重新从 Release 下载 `software_versions.json`。Release 资产刚被覆盖时存在短暂可见性 / 传播时序，下一轮可能重新读到旧清单，甚至按缺失分支从空对象开始，导致已经写入的条目丢失或 SHA-256 与最新 AppImage 不一致。

现改为“Job 开始时读取一次、同一份本地清单持续更新、成功一个立即上传一次”，并串行化发布器；应用各自的构建 Job、AppImage 打包逻辑和稳定资产名不因此改变。

> 本 README 仅作为仓库入口说明；AI 操作本仓库时请以 [AGENTS.md](./AGENTS.md) 为完整规范。
