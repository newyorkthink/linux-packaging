# 待 AI 后续统一处理

本文件记录截至 2026-09-21 仍未完成、未确认或需要重新完整检查的事项。

以下项目**暂不继续零散修改**，等待 AI 有足够额度和完整上下文后统一处理。后续开始前必须重新完整阅读 [AGENTS.md](./AGENTS.md)、本文件、对应应用 README、构建脚本、workflow 和相关公共代码。已经由实机确认有效的基线不得回退；没有实机证据的代码调整不得写成“已解决”。

## PeaZip

- 2026-09-21 已确认的是 **简体中文界面与原有 UTF-8 乱码修复正常**。这一部分属于稳定基线，后续不得因为整理公共代码、重构 AppRun 或调整 linuxdeploy 流程而擅自改写。
- PeaZip **整体功能尚未验收完成**。当前新构建的 `peazip.AppImage` 不能正常解压 AppImage；用户此前自己打包的旧 PeaZip 可以完成该操作，因此当前结果不能标记为“PeaZip 已解决”。
- RPM 包的打开 / 解包能力目前**尚未实机测试**，没有测试结果前不能写成支持正常，也不能据此修改后端。
- 后续应先对照“此前实际可解压 AppImage 的旧产物”和“当前产物”，检查归档后端是否完整保留、后端运行时依赖、路径和调用方式，再决定是否需要修改。没有新证据前，不得动已经确认的中文乱码修复基线。
- 详见 [peazip/README.md](./peazip/README.md)。

## Wine

- 最近一次已经取得的实机结果仍是：Wine GUI 最终可以启动，但启动前有明显延迟，约 **20～30 秒**；`winecfg` 仍未显示简体中文。
- 在上述实机结果之后，`main` 已新增提交 `5965be944de303afce0b75746c45c9372cb36b6a`（`Fix Wine locale portability and startup delay`），再次调整 locale 与启动延迟处理；**该提交当前尚无新的用户实机确认，不能提前标记为已解决。**
- [wine/README.md](./wine/README.md) 中 2026-09-21 的“修复记录”包含已经提交的代码调整以及仍待新产物验证的内容；后续必须区分“代码已修改”和“实机已确认”。
- 后续需要分别验证“启动延迟”和“中文 UI”是否真的解决，同时保留已经修复的 `wineserver` 启动链、FreeType / zlib 依赖链以及现有 Prefix 行为，避免修一个问题时回退另一个已经解决的问题。
- 在取得新的构建产物与实机证据前，不得把当前 Wine 状态写成“中文已解决”或“启动速度已恢复正常”。
- 详见 [wine/README.md](./wine/README.md)。

## runimage/jriver-media-center

- JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。
- 当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照。
- 详见 [runimage/jriver-media-center/README.md](./runimage/jriver-media-center/README.md) 与 [runimage/jriver-media-center/TEST_ISSUE.md](./runimage/jriver-media-center/TEST_ISSUE.md)。

## jriver

- 2026-09-18 终端 GUI、简体中文界面和文件选择器已确认。
- Rofi run 无窗口已停止改包装：**禁止改 `rofi/`，禁止再做 AppRun 包装或 Sharun / GVFS / D-Bus / `LD_PRELOAD` 环境清理。** 没有新的直接证据前，不得重新开启这些已经失败的方向。
- 原因见 [jriver/README_runimage_quick.md 第 10 节](./jriver/README_runimage_quick.md)。
- 旧 CEF / appimagetool 入口仍为 `jriver/build_jriver_legacy_20260913.sh`，CI 不跑。
- Fcitx5 实际中文输入、网页音频和影院模式仍未验证；没有新证据前不作为后续改包装任务。

## 公共代码与公共函数

- `common/` 当前包含 `apt/`、`archive/`、`download/`、`github/`、`linuxdeploy/`。本项只是标记为**需要后续重新完整审计**，不是认定这些公共实现当前一定有错误。
- 后续 AI 需要从调用方和公共实现两端一起检查，不能只看某一个 helper：确认职责边界是否正确、是否存在重复通用逻辑、参数语义是否一致、错误处理与返回码是否可靠、下载 / 校验 / DEB 元数据 / 解包 / linuxdeploy 初始化与最终封装是否由正确层负责。
- 重点检查近期从 PeaZip 等项目下沉到公共函数的逻辑，确认没有把应用专用规则错误公共化，也没有让应用脚本重复做公共入口已经负责的检查。
- 已经由用户明确确认有效的命令、调用顺序、AppRun 行为和打包基线必须逐字保留；公共化不能成为顺手重写这些稳定内容的理由。
- 必须同时检查所有受影响调用方，避免只修公共函数后才逐个发现调用参数、路径、返回值或行为不兼容。

## 后续处理原则

1. 等 AI 有足够额度后再统一继续，不在额度不足或上下文不完整时逐项试错。
2. 开始修改前先一次性读完整相关代码、README、workflow、公共函数和历史问题记录，确认稳定基线、未验证项和禁止重复的失败方向。
3. PeaZip 与 Wine 的后续修复都必须以真实构建产物和实机功能验证为准；构建成功、静态检查通过或代码看起来合理都不能替代实机结论。
4. JRiver 两条路线继续严格按各自现有停手边界执行，没有新证据不重复已经失败的包装实验。
5. 公共函数审计应一次覆盖公共实现和所有相关调用方；确认完整 diff 后再修改，避免反复小提交和依赖 GitHub Actions 失败结果试错。
