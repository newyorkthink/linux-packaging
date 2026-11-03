# Newsboat 模板差异

[构建脚本](../build_newsboat.sh)是 [Arch 原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准)中同包双入口终端程序的基础参考。

| 脚本位置 | 注释和处理依据 |
| --- | --- |
| 安装环境与应用 | 通用注释逐字沿用固定表。公共基础包已覆盖原基础安装行，以及 `curl hicolor-icon-theme perl python git`，应用安装行保留其余原有包。 |
| 图标与桌面入口 | 图标使用 Arch 包内 SVG，沿用系统图标的固定注释。Arch 包没有 desktop，使用仓库维护的 `newsboat.desktop`，对应注释为「使用仓库提供的桌面入口文件。」 |
| 窗口类 | 沿用 `STARTUPWMCLASS=newsboat`，对应注释为「保留原有的启动窗口类设置。」这是现有元数据，不是双入口模板的必选项。 |
| 依赖收集 | `quick-sharun /usr/bin/newsboat /usr/bin/podboat` 原样保留。两个文件均来自同一个 Arch 官方包，沿用「收集程序及其运行依赖。」 |
| 版本及封装 | 读取版本、封装和保存版本的通用注释逐字沿用。版本取自已安装包，封装成功后由公共入口检查产物和保存版本。 |
| 工作目录 | 脚本切到应用目录，应用清单同步指向 `newsboat/dist`。发布资产名继续使用 `newsboat.AppImage`。 |

Newsboat 和 Podboat 均为终端程序，沿用现有语言环境。已按 Newsboat 名称检索 pkgforge-dev，未找到对应打包仓库。固定输入和原有依据见 [固定配置依据](./hardcoded.md)。
