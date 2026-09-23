# 待 AI 后续统一处理

本文件记录截至 2026-09-21 仍未完成、未确认或需要重新完整检查的事项。

以下项目**暂不继续零散修改**，等待 AI 有足够额度和完整上下文后统一处理。后续开始前必须重新完整阅读 [AGENTS.md](./AGENTS.md)、本文件、对应应用 README、构建脚本、workflow 和相关公共代码。已经由实机确认有效的基线不得回退；没有实机证据的代码调整不得写成“已解决”。

## Wine

### 当前实机基线

截至 2026-09-21，用户已经用当前发布的 `wine.AppImage` 实机确认：

- `winecfg` 可以正常打开，GUI 可用；
- `winecfg` 已显示**简体中文**，中文环境修复完成；
- 早期的 `wine: could not exec wineserver` 已不再出现；
- 早期反复出现的 `Wine cannot find the FreeType font library` 已不再出现；
- 后续出现过的 `setlocale: LC_MESSAGES/LC_ALL: cannot change locale` 已不再出现在最新实机结果中；
- 早期截图中的 `wgl:internal_context_create Failed to create internal global context` 在最新实机结果中也已不再出现；
- 默认 Prefix 行为仍保持 Wine 官方语义：wrapper 不设置 `WINEPREFIX`，默认继续使用 `~/.wine`，用户显式传入的 Prefix 原样生效。

### 当前唯一明确遗留问题

- 从终端执行 `./wine.AppImage` 到 `winecfg` 窗口真正出现，实机仍需要约 **30 秒**。
- 这不是期望的日常启动速度。当前已经停止继续叠加猜测性修复，**暂不再改 Wine 包装代码**。
- 该问题不能再简单归因于中文 locale、FreeType、`wineserver`、此前的 EGL 报错或“第一次创建 Prefix”；这些方向已经分别处理过，最新实机仍保留约 30 秒延迟。

### 后续重新处理时的固定方法

后续只有在 AI coding 额度和上下文都足够时再继续。开始前必须重新完整阅读 `AGENTS.md`、本文件、`wine/README.md`、`wine/build_wine.sh`、`wine/wine-staging.yml`、`wine/wrapper`、Wine workflow 以及当前上游 Wine/AppRun/AppImageBuilder 行为。

第一步**不是继续改代码**，而是对同一个现有 Prefix 做可重复的分段计时和系统调用/进程时间线采样，至少区分：

1. uruntime / DwarFS 挂载耗时；
2. AppRun 初始化、runtime 选择和 hook 注入耗时；
3. wrapper 自身耗时；
4. `wineserver` / `wineboot` / services 启动与等待耗时；
5. `winecfg` 进程创建到窗口可见的耗时。

优先使用 `time`、时间戳日志、`strace -f -tt -T`、进程树和必要的 Wine debug channel 做一次完整采样，再根据最长阻塞点决定是否需要处理 AppRun v2、Wine 11.x、Prefix service、DwarFS 或其他具体组件。

**禁止重复的方向：**

- 不得为了启动速度删除或重建用户 `~/.wine`；
- 不得把宿主 NVIDIA/Mesa 驱动或 ICD 打进 AppImage；
- 不得重新加入启动前 `wine reg add`、`localedef` 或其他会额外启动 Wine/增加启动阶段工作的逻辑；
- 不得回退已经实机确认有效的中文 UI、`wineserver-launcher`、FreeType/zlib 修复和 Prefix 语义；
- 在没有分段计时证据前，不得再把 30 秒延迟归因于某一个组件并直接修改。

详见 [wine/README.md](./wine/README.md)。


## runimage/jriver-media-center

- JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。
- 当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照。
- 详见 [runimage/jriver-media-center/README.md](./runimage/jriver-media-center/README.md) 与 [runimage/jriver-media-center/TEST_ISSUE.md](./runimage/jriver-media-center/TEST_ISSUE.md)。

## jriver

- 2026-09-23 正式 CI 已切回 `jriver/build_jriver_anylinux_sharun.sh`。这条历史旧路线实际使用 quick-sharun、appimagetool 和私有 CEF / 音频 / glibc 隔离修复，不是 linuxdeploy；最后一次旧产物实机记录为 2026-09-12 GUI 正常、影院模式鼠标点击卡住。本次新产物的构建与实机结果尚未确认，详见 [旧路线完整记录](./jriver/REPAIR_HISTORY_ANYLINUX_SHARUN.md)。
- `jriver/build_jriver_anylinux_runimage.sh` 保留但 CI 不调用。该路线 2026-09-18 曾确认终端 GUI、简体中文界面和文件选择器，Rofi run 无窗口已停止改包装：**禁止改 `rofi/`，禁止再做 AppRun 包装或 Sharun / GVFS / D-Bus / `LD_PRELOAD` 环境清理。** 没有新的直接证据前，不得重新开启这些已经失败的方向；详见 [RunImage 完整记录第 10 节](./jriver/REPAIR_HISTORY_ANYLINUX_RUNIMAGE.md)。
- Fcitx5 实际中文输入、网页音频和影院模式需要按新产物分别确认；旧路线与 RunImage 路线的实机结论不能互相替代。

## 公共代码与公共函数

- `common/` 当前包含 `apt/`、`archive/`、`download/`、`github/`、`linuxdeploy/`。本项只是标记为**需要后续重新完整审计**，不是认定这些公共实现当前一定有错误。
- 后续 AI 需要从调用方和公共实现两端一起检查，不能只看某一个 helper：确认职责边界是否正确、是否存在重复通用逻辑、参数语义是否一致、错误处理与返回码是否可靠、下载 / 校验 / DEB 元数据 / 解包 / linuxdeploy 初始化与最终封装是否由正确层负责。
- 重点检查近期从 PeaZip 等项目下沉到公共函数的逻辑，确认没有把应用专用规则错误公共化，也没有让应用脚本重复做公共入口已经负责的检查。
- 已经由用户明确确认有效的命令、调用顺序、AppRun 行为和打包基线必须逐字保留；公共化不能成为顺手重写这些稳定内容的理由。
- 必须同时检查所有受影响调用方，避免只修公共函数后才逐个发现调用参数、路径、返回值或行为不兼容。

## 后续处理原则

1. 等 AI 有足够额度后再统一继续，不在额度不足或上下文不完整时逐项试错。
2. 开始修改前先一次性读完整相关代码、README、workflow、公共函数和历史问题记录，确认稳定基线、未验证项和禁止重复的失败方向。
3. Wine 的后续修复必须以真实构建产物和实机功能验证为准；构建成功、静态检查通过或代码看起来合理都不能替代实机结论。
4. JRiver 两条路线继续严格按各自现有停手边界执行，没有新证据不重复已经失败的包装实验。
5. 公共函数审计应一次覆盖公共实现和所有相关调用方；确认完整 diff 后再修改，避免反复小提交和依赖 GitHub Actions 失败结果试错。
