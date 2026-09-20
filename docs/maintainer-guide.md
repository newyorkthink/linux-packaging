# Linux Packaging 维护者指南

这份文档面向仓库维护者，用于快速判断打包路线、找到正确入口并完成提交前核对。它不是 AI 规则的精简版，也不覆盖单个应用的技术细节。

强制规则以 [AGENTS.md](../AGENTS.md) 为准；当前遗留事项以根目录 [README.md](../README.md) 的“当前待处理”为准；某个应用的实际打包方式、稳定基线和修复历史以该应用目录的 `README.md` 为准。

## 文档怎么分工

| 文档 | 用途 | 是否保存具体应用细节 |
| --- | --- | --- |
| 根目录 `README.md` | 仓库入口、手动构建入口、当前待处理、Release 架构 | 只保存仓库级状态和待办索引 |
| `AGENTS.md` | 所有 AI 必须全文阅读的完整强制规范 | 保存跨应用规则、例外和禁止方向 |
| `docs/maintainer-guide.md` | 人工维护时的路线导航、顺序和检查清单 | 不保存容易过期的单个应用实现 |
| `<应用目录>/README.md` | 当前应用的技术栈、上游、打包方式、运行要求、检查和修复历史 | 保存该应用的完整稳定基线 |

不要建立内容随意堆放的 `note/` 目录，也不要把旧命令合集、万能 AppRun、临时排障命令或个人电脑环境直接提交到仓库。能够长期复用的跨应用结论写入 `AGENTS.md`；只属于一个应用的结论写入该应用 README；仍未确认的个人草稿留在仓库外。

## 开始前先判断任务类型

| 任务 | 先看什么 | 主要结果 |
| --- | --- | --- |
| 新增应用 | `AGENTS.md`、2～3 个同技术栈应用、统一 workflow 和应用清单 | 新应用目录、构建脚本、README、正式 workflow 接入 |
| 修复已有应用 | 根 README 待办、应用 README、当前脚本、相关 workflow、已有日志或产物 | 在稳定基线上做最小修复并追加修复记录 |
| 只做检查 | 应用 README、脚本、workflow、已有构建和产物证据 | 把检查范围、证据、结论和未确认项写入应用 README |
| 从其他仓库迁移 | 源仓库完整文件树、源 workflow、成功记录、许可证和本仓库同类实现 | 先原样迁移并核对 SHA，再做本仓库适配 |
| Release 或版本清单问题 | 根 README 的 Release 章节、相关 workflow、共享发布 action | 只处理当前软件，保持每个 Build 独立即时写入自己的版本条目 |

## 打包路线怎么选

先确认上游包格式、程序技术栈、ELF 依赖、插件或 `dlopen` 依赖、目标架构、glibc / loader 要求和相近项目的稳定做法。已有应用已经确认有效的路线不因个人偏好更换。

| 路线 | 适合场景 | 构建环境与最终产物 |
| --- | --- | --- |
| 上游官方 AppImage 原样同步 | 上游已有正式 AppImage，当前没有必须修复的问题 | 动态取得并校验上游资产，保持内容不变，以仓库稳定资产名发布 |
| quick-sharun / sharun | Arch 官方仓库或 AUR 可安装、标准 `/usr/bin` 入口，或已有同类应用使用该路线 | 实际依赖收集和 AppDir 构建在 Arch Linux 完成，由 quick-sharun 生成 AppImage |
| linuxdeploy + 官方 appimagetool | Ubuntu / Debian 来源、需要 linuxdeploy 收集 ELF 依赖，或需要 Qt / GTK / GStreamer 输入插件 | 在 Ubuntu 中用 linuxdeploy 整理 AppDir，最后单独使用官方 appimagetool 和明确 runtime 封装 |
| 官方 appimagetool 直接封装 | 上游或现有逻辑已经提供完整 AppDir，依赖无需再自动收集 | appimagetool 只负责把完整 AppDir 转为 AppImage |
| RunImage | 需要共享运行环境或项目已经采用 RunImage | 使用 `.github/workflows/build_runimage.yml`，不要混入普通 AppImage workflow |
| Termux 原生工具 | Android / Termux 原生工具 | 使用 `.github/workflows/termux.yml` 和 `termux/<工具名>/` |

### linuxdeploy 插件

- Qt 应用按实际 Qt 主版本选择 `linuxdeploy-plugin-qt`，通过 `--plugin qt` 部署 Qt plugins、QML 和翻译；非 Qt 应用不添加。
- GTK、GStreamer 等输入插件也只在技术栈和证据需要时启用，不能为了“打得更全”一次加入全部插件。
- `linuxdeploy-plugin-native_packages` 用于输出 DEB / RPM，不是 AppImage 依赖收集插件。
- `linuxdeploy-plugin-appimage` 对应 `--output appimage`。本仓库的 linuxdeploy 路线不使用它作为最终封装，继续单独调用官方 appimagetool。

### AppRun 与 libunionpreload

- AppRun 只保留当前应用需要的入口和环境，不使用万能模板，不统一强制语言、浏览器、主题、显示后端、字体 DPI、输入法或用户目录。
- `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`、Qt / QML / GTK 路径变量的用途，以及首次打包时可选的 linuxdeploy 路径整理方式，见 [AppRun 路径型环境变量说明](./apprun-path-environment.md)。已经确认的 AppRun 直接固化准确路径，不再自动整理。
- 启动链只保留一条真实可到达的 `exec ... "$@"`，路径和参数必须正确引用。
- 程序确实写死 `/usr`、`/opt`、`/lib` 等绝对路径，且普通 RPATH、搜索路径或小范围 wrapper 无法解决时，可以评估 libunionpreload。
- libunionpreload 不是 mount、真正的 union filesystem 或安全沙箱。使用前必须核对动态链接方式、架构、glibc ABI、子进程传播、文件写入和许可证要求。

## 新增或重做应用的顺序

1. 阅读根 README 的“当前待处理”，确认没有应保持搁置的同名问题。
2. 阅读 2～3 个同技术栈、同包格式的成熟应用，不把其他项目的特殊 workaround 整段复制过来。
3. 核对上游官方来源、许可证、目标架构和最新稳定版获取方式；应用版本默认必须动态获取。
4. 确定唯一打包路线和对应构建环境，先采用最小基础依赖和最短打包链路。
5. 准备 desktop、图标、真实程序入口和必要资源，保持上游目录布局，不盲目复制整个 `/usr/lib` 或 plugin 树。
6. 只在日志、ELF、上游元数据或真实运行反馈证明缺失时，补入当前根因所需的最小依赖。
7. 生成最终 AppImage 后写出 `version.txt`，版本必须来自本次实际打包的上游版本。
8. 标准应用写入 `.github/appimage-apps.json`；构建环境或步骤不同的特例才在 `build.yml` 中维护独立 Job。
9. 同步维护应用 README，说明上游、技术栈、打包方式、运行要求、证据状态和已完成修复。
10. 提交前检查完整 diff、文件路径、引用、权限、YAML / JSON / Shell 语法关系和 workflow 入口，不用 GitHub Actions 失败结果反复试错。

普通 HTTPS 文件下载优先调用 `common/download/download_file.sh`；linuxdeploy、appimagetool、Type 2 runtime 和已支持的 GTK / Qt 插件优先调用 `common/linuxdeploy/prepare_linuxdeploy_tools.sh`。项目脚本只保留当前应用的 URL、输出路径、摘要来源和必要解析逻辑。

## GitHub Actions 中怎么运行

在 GitHub 仓库页面进入 **Actions → Build AppImages → Run workflow**：

- `script_to_build` 选择 `all` 或具体构建脚本。
- `script_search` 可以填写应用名或脚本名称做模糊匹配；填写后优先于下拉选择。
- 标准 AppImage 使用 **Build AppImages**。
- RunImage 使用 **Build RunImages**。
- Termux 工具使用 **Build Termux**。

提交到 `main` 后，应用目录内的变更由 Plan 映射到对应应用；共享构建 action 变更才会选择全部应用。纯仓库级文档修改即使启动 Plan，也不会选择应用构建。AI 提交后默认只核对远端提交、文件和 diff，不持续监控 Actions；需要查看某次运行时再明确提出。

## Release 与版本清单

- 持续更新产物统一发布到 `latest` Release，资产名保持稳定。
- 每个 Build 完成自己的构建和 AppImage 上传后，立即由当前 Build 更新自己的 `software_versions.json` 条目。
- 多个 Build 并发时，只允许版本清单的短读改写临界区使用互斥锁；不得建立等待全部应用的中央 publisher。
- 版本表示软件版本，Release asset digest / SHA-256 表示具体文件内容，两者不能互相替代。
- 构建失败或资产摘要不一致时，不写入新的成功版本记录，也不删除其他应用资产。

## 出现问题时怎么处理

- 构建失败：先读取失败 Job 的完整日志，定位下载、依赖、路径、权限或工具链问题，再一次性修改；不要连续提交多个猜测版本。
- 运行失败：优先保存完整运行日志并结合应用 README、ELF 依赖、AppRun 和已有产物判断；没有证据时不更换整个打包框架。
- 证据不足：明确记录“未确认”，等待新的真实日志、产物或运行反馈；不新增测试 workflow、测试 Job、冒烟脚本或测试代码。
- 暂时无法解决：在应用 README 记录详细现状，并在根 README 的“当前待处理”增加简明索引，避免后续重复失败方向。
- 问题解决：用修复记录替换对应的过时检查条目，同时更新根 README 中已经失效的待办。

## 提交前人工检查清单

- [ ] 修改范围只包含当前任务需要的文件，没有顺手重构其他应用。
- [ ] 已完整阅读当前应用 README、脚本和 workflow，保留已确认稳定基线。
- [ ] 上游来源、架构、资产名和版本解析均已核实，应用版本没有被 AI 擅自锁定。
- [ ] 构建环境与打包路线一致：quick-sharun 在 Arch，linuxdeploy + appimagetool 在 Ubuntu。
- [ ] Qt 主版本、Qt plugins 和输入法 plugin 一致，没有混用 Qt 5 / Qt 6。
- [ ] AppRun 只有当前应用需要的环境和唯一入口，没有万能模板或无证据 preload。
- [ ] 没有宽泛通配安装、`dist-upgrade`、`chmod 777`、整个 `/usr/lib` 复制或无关系统修改。
- [ ] 最终封装、`version.txt`、稳定资产名和 workflow 发布路径互相一致。
- [ ] 标准应用清单、特例 Job、手动下拉选项、目录和脚本路径没有遗漏或重复。
- [ ] 应用 README 已同步当前实现，并准确区分静态检查、已有构建证据和真实运行反馈。
- [ ] 仓库中没有新增任何测试、冒烟测试、测试 workflow、测试 Job 或测试专用代码。
- [ ] 已检查完整 diff，确认没有无关修改、旧文件、临时产物、凭据或个人环境信息。

## 这份指南怎么维护

这里只维护人工工作顺序、路线导航和长期稳定的仓库级概念。新的强制规则必须写入 `AGENTS.md`；应用特有命令、依赖、兼容处理和故障历史必须写入对应应用 README；动态待办写入根 README。

不要为了让本指南“更完整”复制整份 `AGENTS.md`，也不要在这里保存旧脚本片段或一次性命令。发生冲突时，以 `AGENTS.md` 和对应应用 README 的当前内容为准。
