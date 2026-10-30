# OBS Studio 模板差异

本页记录现有构建相对 [原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 的专属内容。通用阶段、注释和空行遵守标准模板；本次选定的官方代码按原文保留，包括其参数、制表符、空格、续行和顺序。

## 应用及依赖来源

使用 Arch 官方仓库的 `obs-studio` 二进制包，由 `common/arch/install_packages.sh` 安装；从系统真实入口收集，不重复下载或预复制主程序。Qt 6 输入模块使用现有的 `fcitx5-qt`，IBus 由基础包入口提供。

`qt6ct`、`kvantum` 和 `lxqt-qtplugin` 是 Qt 6 主题插件包，必须保留在应用依赖安装行中。quick-sharun 收集插件，不另行传入插件路径。完整警告及包名含义见 [Qt 主题插件](../../anylinux_projects.md#qt-主题插件)。

## 现有专属处理

| 所在阶段 | 保留内容 | 依据与影响 |
| --- | --- | --- |
| 打包元数据 | 保留 `DEPLOY_OPENGL=1`、`DEPLOY_PIPEWIRE=1`、`DEPLOY_PYTHON=1`、`DEPLOY_QT=1`。 | 对应现有 OpenGL、PipeWire、Python 和 Qt 6 部署需求，原有配置保持不变。 |
| 打包元数据 | 原样采用官方 `export DEPLOY_SDL=1`。 | 强制启用 SDL 相关运行库部署；这是本次明确选定的官方配置，不能据此宣称此前缺少 SDL 或已修复实际故障。 |
| 打包元数据 | 原样采用官方 `export PATH_MAPPING_HARDCODED='libobs.so*'`。 | 按文件名匹配包内 libobs，由工具处理其中的硬编码系统路径；官方未说明具体原因，完整行为与边界见 [官方处理取舍](./pkgforge-differences.md)。 |
| 依赖收集 | 原样采用官方完整 quick-sharun 命令。 | `/usr/bin/obs*` 收集程序及辅助入口，`/usr/lib/obs*` 覆盖模块和脚本模块，另显式收集 libobs、CEF 和 LuaJIT；官方续行作为原文保留。完整代码和落地行号见 [官方处理取舍](./pkgforge-differences.md#收集命令)。 |
| 模块数据 | 由 quick-sharun 扫描与程序同名的数据目录。 | 当前包提供 `/usr/share/obs`，工具按已收集的程序名扫描数据目录；本次不改写官方收集命令追加参数。该结论来自源码核查，不能代替新产物验证。 |
| 中文环境 | 在依赖收集后生成 `zh_CN.UTF-8`，向已有 `AppDir/.env` 追加语言和 locale 路径。 | 原有中文环境保持不变，不另写 `AppRun.sh`，不覆盖 quick-sharun 生成的入口。 |

## 版本读取与保存

版本记录按基础模板执行：在第一次 quick-sharun 之前，通过公共入口读取实际安装版本并赋给 `VERSION`；最终 AppImage 成功生成后，单行调用公共保存入口。此前把旧读取位置、小写变量和两行保存写法列为专属处理的说明已纠正。

## 核实来源与边界

本次修改基于本仓库 `8b8692540b1462cbb50393f8caae0edd1aa1bd4b`。pkgforge-dev 对应源码为 [`8c17c157a498876f75b84cb0a30307aba641b396`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh)；工具行为依据 [quick-sharun 源码 `862becf483277b2d2576cbc3fec6284489efd4ea`](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/862becf483277b2d2576cbc3fec6284489efd4ea/useful-tools/quick-sharun.sh)。官方原文、采用项、未启用项和原因分别记录在 [官方处理取舍](./pkgforge-differences.md)。

路径与原始故障记录继续保存在 [写死的路径](./hardcoded.md)；其中关于 CEF 路径的旧判断由本次新增更正说明取代，历史原文不删除。构建与运行状态仍以 [README](../README.md) 为准。
