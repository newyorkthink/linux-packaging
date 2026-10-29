# 文档索引

人工维护者和 AI 都从这里查找仓库规范、打包机制和专项问题。AI 开始任务仍须完整阅读 [AGENTS.md](../AGENTS.md)；本索引不能替代规则、应用 README 或具体故障记录，也不构成修改授权。

## 查找顺序与记录位置

1. 按下面的主题和关键词找到相关规范与专项记录。
2. 阅读对应应用目录的 `README.md`、目录内历史文件和 README 链接的 `docs/` 专属记录，确认当前实现、稳定基线和验证范围；具体应用状态以那里为准。
3. 阅读相关案例的原因、适用条件和验证边界，再决定本次修改清单。其他应用出现过同类现象，不代表可以直接照抄修复。

| 内容 | 记录位置 |
| --- | --- |
| 仓库强制规则与人工操作导航 | `AGENTS.md`、维护者指南和打包路线规范 |
| 应用实现、当前状态、修复和失败历史 | 对应应用目录的 `README.md` 或目录内历史文件 |
| 应用专属问题、实测证据与详细记录 | `<应用目录>/docs/`，由对应应用 README 提供链接 |
| 跨应用通用机制与排查方法 | `docs/` 中的主题文档、`docs/packaging-cases/` |
| 已核对、决定暂时不改的问题 | `docs/known-risks/`，有记录不表示要求修复 |

`docs/packaging-cases/` 只放通用问题笔记，禁止在文件名、正文、示例和链接中夹带具体被打包应用的名称或个案。Qt、sharun 等框架和打包工具名称可以按主题使用；通用示例采用 `<应用>`、`<程序>` 等占位符，需按实际环境替换。具体应用的产物、修复和验收记录放在其自身目录。

新增或更新通用笔记时同步维护本索引的主题、关键词、范围和链接；应用专属记录由对应应用 README 链接。已有历史完整保留，不用索引摘要替代详细记录。

## 应用配置说明文件

每个应用的 `docs/hardcoded.md` 和 `docs/template-deviations.md` 采用相同的用途约定，正文只记录所属应用的实际配置。明确决定暂不采用 pkgforge-dev 专属处理时，另用 `docs/pkgforge-differences.md` 保存原文、作用和未采用状态。这些文件都是维护说明，不参与打包执行，也不构成修改授权。

| 文件 | 说明什么 | 什么时候查看或更新 |
| --- | --- | --- |
| `<应用目录>/docs/hardcoded.md` | 固定路径、文件名和参数的具体取值、选择依据、用途及相关原始报错，回答“这个值为什么这样写”。 | 查找配置来源，或新增、修改固定值时查看，并同步维护对应记录。 |
| `<应用目录>/docs/template-deviations.md` | 相对标准模板必须保留的程序专属差异、所在阶段、原因和影响，回答“这里为什么与模板不同”。 | 套用模板或调整下载入口、版本来源、辅助命令等专属处理时查看，并同步维护对应记录。 |
| `<应用目录>/docs/pkgforge-differences.md` | pkgforge-dev 专属处理的源码快照、作用、官方理由和明确暂不采用的决定。 | 后续拟加入某项处理时，先核实官方当前是否仍保留以及是否适用，再取得本次加入的授权；禁止直接恢复历史快照。 |

例如，图标路径和主程序文件名的取值依据写在 `hardcoded.md`；采用不同版本来源或额外部署运行命令的原因写在 `template-deviations.md`。同一项配置同时涉及两类说明时，分别记录取值依据和模板差异原因，并保持内容一致。

这些文档用于防止后续维护时忘记配置来由、为了统一模板误删必需处理，或把明确未启用的历史方案误认为当前实现。具体应用的文档入口放在该应用的 README 中。

## 文档命名

**仓库自有 Markdown 文档使用稳定的主题名，禁止在文件名中加入日期或时间戳。** 例如使用 `quick-sharun-qt6-resources.md`，禁止使用 `20261023.md` 或 `quick-sharun-qt6-resources-20261023.md`。日期只写在正文或修复记录标题中。本规则用于新建和重命名文档，不要求追溯改名既有文件。

## 规范与公共机制

| 文档 | 主题与关键词 |
| --- | --- |
| [AI 仓库规范](../AGENTS.md) | 授权、稳定基线、完整阅读、提交、验证边界 |
| [维护者指南](./maintainer-guide.md) | 人工维护、入口、打包路线、提交前核对 |
| [Anylinux / quick-sharun 规范](../anylinux_projects.md) | Arch、sharun、AppDir、中文环境、输入模块、platforminputcontexts、自动收集、`.env`、Qt 主题插件、qt6ct、kvantum、lxqt-qtplugin、有窗口的 Qt 程序、Electron、程序目录、直接下载标准模板、公共版本读取、单行保存、行数与空行、暂不采用官方处理、加入前重新核实 |
| [打包分类](./packaging-classification.md) | quick-sharun、Electron、Qt、linuxdeploy、直接下载标准、系统安装、参数差异 |
| [linuxdeploy 规范](../linuxdeploy_projects.md) | Ubuntu、插件、AppRun、appimagetool |
| [AppImage 构建依赖清单](./appimage-build-dependency-list.md) | 基础包、Qt5 / Qt6、GTK、功能依赖 |
| [公共脚本入口](../common/README.md) | 下载、AUR DEB 来源与摘要、解包、依赖、公共版本来源、可选构建元数据、版本保存 |
| [打包 export 登记表](./packaging-export-registry.md) | 环境变量、用途、登记后使用 |
| [AppRun 路径型环境变量](./apprun-path-environment.md) | PATH、LD_LIBRARY_PATH、XDG_DATA_DIRS、Qt 路径 |
| [AppImage 自定义协议登记](./appimage-scheme-handler.md) | scheme、OAuth、浏览器回调、desktop |
| [Release 发布历史](./release-history.md) | 发布机制历史；现行规则仍见 AGENTS.md |

## 通用问题笔记

| 记录 | 检索关键词 | 状态与范围 |
| --- | --- | --- |
| [quick-sharun 下 Qt5 转 Qt6 的程序路径变化](./packaging-cases/quick-sharun-qt6-resources.md) | Qt5、Qt6、applicationDirPath、AT_EXECFN、/proc/self/exe、shared/bin、资源、中文界面、Language、System default、辅助程序、native messaging | 程序目录变化、资源定位和辅助程序启动的通用机制、适用条件与排查方法；具体应用证据和验收结果见各应用目录 |
| [quick-sharun 说明](./packaging-cases/quick-sharun.md) | quick-sharun、更新 hook、self-updater、ADD_HOOKS、不会自动加入更新 hook、Qt 主题插件、qt6ct、kvantum、lxqt-qtplugin | 已核对的 quick-sharun 行为。后续往该文件追加，不单开一篇 |

## 已知隐患与保留记录

| 入口 | 检索关键词与状态 |
| --- | --- |
| [已知隐患索引](./known-risks/README.md) | 只记录、暂时不改；Mesa / LLVM、i3wm 启动子程序、Electron user namespace、pkgforge Arch 镜像源、下载超时 |
| [Mesa / LLVM 红字的原有入口](./quick-sharun-mesa-llvm-explanation.md) | 历史入口保留，相关记录也可从已知隐患索引查找 |

单个软件的最新状态、遗留事项和实机反馈请继续查该软件目录的 README 及其链接的 `docs/` 专属记录，不在根 README 或本索引维护另一份应用待办清单。