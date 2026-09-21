# Linux Packaging

用于构建、重打包和修复 Linux 应用，主要生成可分发的 AppImage / RunImage。

> [!IMPORTANT]
> **AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。**  
> 本仓库关于修改范围、安全要求、打包方式、GitHub Actions、Release 和验证流程的详细规范，均以 `AGENTS.md` 为准。

## 文档导航

- **人工维护与打包入口：** [维护者指南](./docs/maintainer-guide.md)
- **AI 完整操作规范：** [AGENTS.md](./AGENTS.md)
- **等待 AI 后续统一处理：** [PENDING_AI_TASKS.md](./PENDING_AI_TASKS.md)
- **当前遗留问题：** 本 README 的“当前待处理”
- **单个应用详情：** 对应应用目录中的 `README.md`

## 仓库说明

- 每个应用原则上使用独立目录维护构建脚本和相关文件。
- 正式 AppImage 构建统一由 `.github/workflows/build.yml` 管理；标准应用清单在 `.github/appimage-apps.json`。
- 已验证正常的现有构建方案视为稳定基线，修改时应遵循最小变更原则。
- 优先使用上游官方程序、资源和发布包，只处理 Linux 打包、依赖、启动及兼容性问题。

## 手动构建

GitHub Actions → **Build AppImages** → 在 `script_to_build` 下拉列表选择 `all` 或具体脚本。`script_search` 可选填应用名 / 脚本名称做模糊匹配，填写时优先于下拉选择。

标准 Arch 应用只改 `.github/appimage-apps.json`；特例仍在 `build.yml` 里单独 Job。RunImage 用 **Build RunImages**，Termux 用 **Build Termux**。

## 当前待处理

截至 2026-09-21，以下问题暂时保留，后续继续处理前必须先完整阅读对应目录现有 README / 问题记录；Wine、JRiver 与公共代码的统一暂停项另见 [PENDING_AI_TASKS.md](./PENDING_AI_TASKS.md)。已经解决的构建兼容层和已确认基线不得回退。

- `gemini`：2026-09-17 Google Omaha `prod` channel 的 Gemini 1.11.4 已包含 Windows PE 原生 Node 模块 `resources/app.asar.unpacked/src/gemini_native.node`，现有“Windows Electron 产品层 + 官方 Linux Electron runtime”路径不能安全直接移植该模块。当前构建保留原生模块检测，不删除或绕过，并在遇到此类上游版本时通过 Release 资产 ID、Release digest、`software_versions.json` 和实际文件 SHA-256 校验后继续保留最后一次成功构建的 Linux 兼容 `gemini.AppImage`，版本清单仍记录真实兼容版本。1.11.4 的原生模块 Linux 实现仍未解决；在没有来源可靠、ABI 匹配的 Linux 对应实现前不得强行发布。详见 [gemini/README.md](./gemini/README.md)。
- `runimage/jriver-media-center`：JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照；详见 [runimage/jriver-media-center/README.md](./runimage/jriver-media-center/README.md) 与 [TEST_ISSUE.md](./runimage/jriver-media-center/TEST_ISSUE.md)。
- `jriver`：2026-09-18 终端 GUI、简体中文界面和文件选择器已确认。Rofi run 无窗口已停止改包装，禁止改 `rofi/`，禁止再做 AppRun 包装或 Sharun/GVFS/D-Bus/`LD_PRELOAD` 环境清理。原因见 [jriver/README_runimage_quick.md 第 10 节](./jriver/README_runimage_quick.md)。旧 CEF / appimagetool 入口仍为 `jriver/build_jriver_legacy_20260913.sh`，CI 不跑。Fcitx5 实际中文输入、网页音频和影院模式仍未验证，没有新证据前不作为后续改包装任务。
- `remotedesktopmanager`：libc 泄漏已实机修好。IME 钩子已加载（启动日志已打印注册成功），Linux 实机仍确认 Fcitx5 选词键泄漏进 LocalTerm PTY。包装层修不了，停止再改打包脚本。不得回退 ICU、glycin-ng、WebView、`GTK_IM_MODULE=fcitx` 或重新写入 `LD_LIBRARY_PATH`。详见 [remotedesktopmanager/README.md](./remotedesktopmanager/README.md)。
- `parsec`：当前 AppImage 已确认 GUI 可正常启动，`libjpeg8` 缺失问题已修复，`Decoder` 已恢复为可用的 `Software`；硬件 Decoder 仍未恢复，VA-API / VDPAU 兼容问题后续继续处理。详见 [parsec/README.md](./parsec/README.md)。


## Releases

构建产物通常发布到仓库的 [Releases](https://github.com/newyorkthink/linux-packaging/releases)，持续更新版本使用 `latest` Release。

### AppImage 版本说明

当前统一版本元数据机制不会向 AppImage 文件内部额外写入版本信息，也不会为了版本管理修改 AppImage 内部内容。

版本信息单独通过构建目录中的 `version.txt` 和 `latest` Release 中的 `software_versions.json` 维护。

AppImage 在本机运行时也不会自动生成版本信息。

少数项目如果原本就存在 `X-AppImage-Version` 等内部版本字段，属于其原有打包逻辑，不是本次统一版本元数据机制新增的。

### 软件版本清单

`latest` Release 中的 `software_versions.json` 用于记录已接入版本元数据机制的软件版本、稳定资产名和 SHA-256；仓库 Git tree 不保存这份动态清单。

发布逻辑固定为：

1. 每个已接入版本元数据机制的 Build 独立构建并上传自己的 AppImage，Build 之间继续并行。
2. 某个 Build 的 Release AppImage 上传成功后，**由当前 Build 自己立即调用** `.github/actions/publish-software-versions`；不存在中央 publisher Job 等待或汇总其他 Build。
3. 共享 action 读取当前 Build 的 `version.txt`，确认目标 Release 资产的 GitHub SHA-256 与本次 Build 产出的 AppImage SHA-256 一致后，才允许写清单。
4. 多个 Build 同时完成时，仅允许在 `software_versions.json` 的“读取最新清单 → 合并当前软件唯一条目 → 写入 → 校验”临界区短暂等待 `software_versions.json.lock`；应用构建、AppImage 上传和当前资产校验不进入锁内。
5. 取得锁后立即通过唯一 Release 资产 ID 读取最新 `software_versions.json`，只覆盖当前软件自己的条目并完整保留其他条目，然后写回 `latest` Release。
6. 写入完成后重新取得正式清单的唯一 Release 资产 ID，并校验资产 digest、下载内容 SHA-256 和当前软件条目；确认正确后立即释放锁，当前 Build 随即结束。

Build 失败、Release 资产上传失败、版本文件无效、Release digest 与本次产物不一致或清单校验失败时，禁止写入错误条目。该架构禁止改回中央 publisher、汇总 Job、轮询 Job 或等待全部 Build 后统一更新的模式。

版本发布实现集中在 `.github/actions/publish-software-versions` composite action，但调用者始终是**各自的 Build Job 本身**。

### Release 完整性监督与自动自愈

手动选择 `all` 或每日定时执行的全量 **Build AppImages** 如果第一次运行失败，`.github/workflows/supervise-release-integrity.yml` 会调用 GitHub 官方 `rerun-failed-jobs` 接口，仅重新运行失败 Job 及依赖这些失败 Job 的后续 Job；已经成功的应用 Job 不会重复构建。自动重跑最多一次，第二次仍失败时停止，不再循环。单个软件手动构建、`push` 增量构建和 Release 完整性自愈构建不进入这项自动重跑。

自动重跑请求发出后，本次监督先结束；失败 Job 重跑完成后，监督 workflow 再按最终结果执行 Release 完整性检查，避免首次失败状态与重跑过程并行触发另一套修复。

`.github/workflows/supervise-release-integrity.yml` 在每次实际运行过应用构建的 **Build AppImages** 完成后启动，不区分原构建来自 `push`、`schedule` 还是 `workflow_dispatch`，也不以原 Workflow 的成功或失败状态代替 Release 完整性检查。

监督流程读取 `latest` Release 中唯一的 `software_versions.json`，遍历其中全部条目，根据每个条目的 `asset` 找到同一 Release 中的唯一资产，并比较清单 `sha256` 与 GitHub Release Asset 的 `sha256` digest。没有版本清单条目的软件不属于监督对象。

全部条目一致时监督正常结束，不修改 Release，也不触发构建。发现不一致时，根据 `.github/appimage-apps.json` 中的 `software_key` 和 `release_name` 映射到现有构建，只通过本仓库 `Build AppImages` 的内部 `workflow_dispatch` 输入重新构建异常软件，不复制应用构建逻辑，也不扩大到全量构建。

自愈 Build 仍由各自 Build Job 在发布成功后立即更新自己的 `software_versions.json` 条目；监督 Workflow 不写版本清单，不充当中央 publisher。自愈完成后自动再次监督；如果仍有异常则明确失败，不再触发第二次自愈，避免无限循环。

### 2026-09-17：改为每个 Build 成功后立即写自己的版本条目

此前使用独立 `Publish successful software versions` Job 轮询其他 Build。该 Job 如果仍在等待 runner，已经成功上传的新 AppImage 会先于 `software_versions.json` 更新，从而出现 Release 资产已经变化、清单仍保存旧 SHA-256 的时间窗口。

现已删除中央等待型 publisher Job。每个 Build 在自己的 Release AppImage 上传成功后立即写自己的条目；并发时只串行版本清单的短读改写临界区，不串行应用构建。

### 2026-09-17：写锁仅覆盖版本清单临界区

每个 Build 先独立完成构建、Release 上传及自身资产 SHA-256 校验，随后才为 `latest` Release 中的 `software_versions.json` 获取短期写锁。取得锁后立即读取最新清单、合并当前软件唯一条目、写入并按唯一 Release 资产 ID 校验，完成后立即释放；不会等待其他 Build、其他 Action 或 `all` 结束。

### 2026-09-17：修复全量构建时的写锁争抢误判

全量并发构建时，一个 Build 上传写锁发生同名资产冲突后，锁可能在随后的资产列表查询前已被持有者释放，或尚未出现在 Release 资产列表中。此前该窗口会被误判为“未发现其他 Job / Action 持有锁”并立即失败。现在仅对此类锁冲突继续短暂争抢，并在成功上传锁后等待取得唯一锁资产 ID；其他上传错误仍立即报告并终止。该重试只发生在清单写锁临界区，不等待其他构建状态或 `all`。

### 2026-09-17：修复全量构建期间版本清单读取不一致

此前版本发布会先上传临时清单资产，再把临时资产改名为固定的 `software_versions.json`。全量构建连续更新清单时，固定下载地址可能短暂取得上一资产的内容，而 Release API 已返回新资产的 digest，导致并发读取出现 SHA-256 不一致。

当前实现直接替换 Release 中的正式清单，并通过同一资产 ID 校验 digest 和下载内容；短期写锁只覆盖清单读取、合并、写入和校验。每个 Build 始终在上传自己的 AppImage 后立即更新自己的唯一条目，应用构建和 AppImage 上传继续并行。

> 本 README 仅作为仓库入口说明；AI 操作本仓库时请以 [AGENTS.md](./AGENTS.md) 为完整规范。
