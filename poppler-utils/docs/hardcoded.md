# Poppler Utilities 固定配置

以下内容属于当前应用已验证的构建和运行基线。版本号仍由公共 APT 入口动态读取，不固定上游软件或打包工具版本。

| 配置 | 当前值及原因 |
| --- | --- |
| 构建环境 | GitHub Actions 的 `ubuntu-24.04`，与既有 linuxdeploy 实机通过产物一致；不切回 Arch / quick-sharun。 |
| 架构 | `x86_64`，与当前 LinuxDeploy 官方工具资源及发布资产一致。 |
| 程序来源 | Ubuntu 官方 `poppler-utils` 与 `poppler-data`，共同以已安装版本下载并解包，保留原始 DEB 目录布局。 |
| 发布产物 | `poppler-utils.AppImage`，一个包提供 13 个命令，最终 SHA-256 与版本号由公共封装入口写入。 |
| 套件入口 | `AppRun` 按 `ARGV0` 识别软链接入口，也接受命令名作为首参数；默认 `pdftotext`，且完整代码保留在构建脚本内。 |
| 桌面入口 | `usr/share/applications/poppler-utils.desktop`，使用 `Exec=pdftotext %F`、`Terminal=true`、`Icon=poppler-utils`。 |
| 图标 | `https://poppler.freedesktop.org/logo.png` 下载到 `usr/share/icons/hicolor/256x256/apps/poppler-utils.png`；这是当前套件已使用的官方来源和图标名称。 |
| 数据目录 | `usr/share/poppler` 的编码映射等资源随 `poppler-data` 保留，由 `XDG_DATA_DIRS` 加入包内共享路径。 |
| 动态库路径 | `AppRun` 保留 `usr/lib` 和 `usr/lib/x86_64-linux-gnu`，不改变已验证的运行时库搜索行为。 |

具体代码差异见 [模板差异](template-deviations.md)，完整运行方式、修复历史及已确认的 lf PDF 预览结果见 [README](../README.md)。
