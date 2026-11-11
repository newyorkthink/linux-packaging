# SMPlayer 模板差异

SMPlayer 按 [Qt 系统入口规范](../../anylinux_projects.md#有窗口的-qt-程序)整理公共阶段和注释。Arch 官方 `smplayer` 依赖 `qt5-base` 和 `qt5-declarative`，本应用按 Qt5 配置。

| 阶段 | 处理与依据 |
| --- | --- |
| 软件来源 | 使用 [Arch 官方仓库的 SMPlayer](https://archlinux.org/packages/extra/x86_64/smplayer/)，主程序和 simple_web_server 直接从系统入口收集。AUR 的 [`smplayer-git`](https://aur.archlinux.org/packages/smplayer-git) 使用 Qt6 开发分支，本次继续采用 Arch 官方仓库的 Qt5 二进制包。 |
| Qt 插件 | `QT_DIR=qt` 选择 `/usr/lib/qt/plugins`。`fcitx5-qt` 按包管理器的依赖关系安装，收集目标为 Qt5 的 Fcitx5 和 IBus 模块。主题使用 `adwaita-qt5`，样式设为 `Adwaita-Dark`。`kvantum` 和 `lxqt-qtplugin` 对应 Qt6，SMPlayer 的 Qt5 样式由 Adwaita 提供。 |
| 依赖收集 | 同次扫描主程序、simple_web_server、mplayer、mpv、yt-dlp、`/usr/share/smplayer` 和 Qt5 输入模块。SMPlayer 的翻译、快捷键及播放配置来自其官方软件包。 |
| yt-dlp | 通过[固定资产名下载入口](../../common/github/download_latest_stable_named_asset.sh)获取官方 Python zipimport 可执行文件 `yt-dlp`。Release 查询使用 Actions 凭据，官方直链失败后按同一资产 ID 认证回退，下载结果须通过 SHA-256 校验。`DEPLOY_PYTHON=1` 随包部署 Python。 |
| 中文环境 | 在首次 quick-sharun 收集后按公共格式生成包内 locale。`LC_ALL=` 清空全局覆盖，`LC_NUMERIC=C` 固定数值解析，消息语言继续使用 `zh_CN.UTF-8`。 |

Qt5 输入模块路径见 [qt5-base 文件清单](https://archlinux.org/packages/extra/x86_64/qt5-base/files/)和 [fcitx5-qt 文件清单](https://archlinux.org/packages/extra/x86_64/fcitx5-qt/files/)。quick-sharun 根据链接的 Qt 库启用部署，并用 `QT_DIR` 定位插件，见[上游收集代码](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/f06e3fccba0cc6f6bd5d11a4809c3ad79797e6bd/useful-tools/quick-sharun.sh#L1074-L1102)。

在 pkgforge-dev 中按 SMPlayer 名称查询未找到对应的独立打包仓库。本应用使用现有公共入口与 quick-sharun 的 Qt 插件收集能力。固定值见[固定配置](./hardcoded.md)。
