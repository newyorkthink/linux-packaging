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

## 文档命名

**仓库自有 Markdown 文档使用稳定的主题名，禁止在文件名中加入日期或时间戳。** 例如使用 `quick-sharun-qt6-resources.md`，禁止使用 `20261023.md` 或 `quick-sharun-qt6-resources-20261023.md`。日期只写在正文或修复记录标题中。本规则用于新建和重命名文档，不要求追溯改名既有文件。

## 规范与公共机制

| 文档 | 主题与关键词 |
| --- | --- |
| [AI 仓库规范](../AGENTS.md) | 授权、稳定基线、完整阅读、提交、验证边界 |
| [维护者指南](./maintainer-guide.md) | 人工维护、入口、打包路线、提交前核对 |
| [Anylinux / quick-sharun 规范](../anylinux_projects.md) | Arch、sharun、AppDir、中文环境、输入模块、`.env`、Qt 主题插件、qt6ct、kvantum、lxqt-qtplugin、有窗口的 Qt 程序 |
| [linuxdeploy 规范](../linuxdeploy_projects.md) | Ubuntu、插件、AppRun、appimagetool |
| [AppImage 构建依赖清单](./appimage-build-dependency-list.md) | 基础包、Qt5 / Qt6、GTK、功能依赖 |
| [打包 export 登记表](./packaging-export-registry.md) | 环境变量、用途、登记后使用 |
| [AppRun 路径型环境变量](./apprun-path-environment.md) | PATH、LD_LIBRARY_PATH、XDG_DATA_DIRS、Qt 路径 |
| [AppImage 自定义协议登记](./appimage-scheme-handler.md) | scheme、OAuth、浏览器回调、desktop |
| [Release 发布历史](./release-history.md) | 发布机制历史；现行规则仍见 AGENTS.md |

## 通用问题笔记

| 记录 | 检索关键词 | 状态与范围 |
| --- | --- | --- |
| [quick-sharun 下 Qt5 转 Qt6 的程序路径变化](./packaging-cases/quick-sharun-qt6-resources.md) | Qt5、Qt6、applicationDirPath、AT_EXECFN、/proc/self/exe、shared/bin、资源、中文界面、Language、System default、辅助程序、native messaging | 程序目录变化、资源定位和辅助程序启动的通用机制、适用条件与排查方法；具体应用证据和验收结果见各应用目录 |
| [quick-sharun 说明](./packaging-cases/quick-sharun.md) | quick-sharun、更新 hook、self-updater、ADD_HOOKS、不会自动更新、Qt 主题插件、qt6ct、kvantum、lxqt-qtplugin | 已核对的 quick-sharun 行为。后续往该文件追加，不单开一篇 |

## 已知隐患与保留记录

| 入口 | 检索关键词与状态 |
| --- | --- |
| [已知隐患索引](./known-risks/README.md) | 只记录、暂时不改；Mesa / LLVM、i3wm 启动子程序、Electron user namespace |
| [Mesa / LLVM 红字的原有入口](./quick-sharun-mesa-llvm-explanation.md) | 历史入口保留，相关记录也可从已知隐患索引查找 |

单个软件的最新状态、遗留事项和实机反馈请继续查该软件目录的 README 及其链接的 `docs/` 专属记录，不在根 README 或本索引维护另一份应用待办清单。
