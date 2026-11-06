# CopyQ 固定配置

本页说明当前构建的固定取值及既有兼容处理。软件版本仍从实际安装的 Arch 包读取，不固定 CopyQ 或打包工具版本。

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 程序来源 | Arch 官方 `copyq` 二进制包，入口 `/usr/bin/copyq`。 | [官方包](https://archlinux.org/packages/extra/x86_64/copyq/) 与 [文件列表](https://archlinux.org/packages/extra/x86_64/copyq/files/)；沿用系统真实入口路线。 |
| 图标与桌面入口 | `/usr/share/icons/hicolor/scalable/apps/copyq.svg`、`/usr/share/applications/com.github.hluk.copyq.desktop`。 | 原脚本取值，官方包同时提供这两个文件；保留 SVG，不改用上游打包脚本的 PNG。 |
| 窗口类 | `STARTUPWMCLASS=copyq`。 | 沿用原有窗口匹配值；[构建位置](../build_copyq.sh#L22)。 |
| 部署配置 | `DEPLOY_OPENGL=1`、`DEPLOY_QT=1`。 | 前者保留原有部署范围，后者来自 Qt6 系统入口标准；[OpenGL](../build_copyq.sh#L32)、[Qt](../build_copyq.sh#L34)。未设置上游的 `ALWAYS_SOFTWARE=1`。 |
| 产物 | `dist/copyq.AppImage`、`dist/version.txt`。 | 保留现有产物名与统一版本清单接口。 |
| 中文环境 | `zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、包内 `lib/locale/zh_CN.utf8`。 | 使用 quick-sharun 的 Qt 中文环境标准，向已有 .env 追加配置；[构建位置](../build_copyq.sh#L43)。 |
| 翻译目录 | `COPYQ_TRANSLATION_PREFIX=$APPDIR/share/copyq/translations`。 | 从原脚本逐字保留，通过带引号的 here-document 写入运行时值；[构建位置](../build_copyq.sh#L64)。 |

## 功能插件兼容路径

原脚本已记录：CopyQ 16 直接在 `lib/copyq` 查找功能插件，quick-sharun 将插件部署在其 `plugins` 子目录，导致图片插件存在但无法加载。当前保留原循环，分别处理 `AppDir/shared/lib/copyq` 和 `AppDir/lib/copyq`，仅在存在插件子目录时，为 `libitem*.so` 建立相对兼容链接。

循环及 `find`、`ln -sfn` 参数均保持原样；[当前实现](../build_copyq.sh#L54)。该处理仅作用于本次 AppDir 中的插件链接，不更改用户配置或剪贴板历史。原始记录来自 [基线脚本](https://github.com/newyorkthink/linux-packaging/blob/93063635ae4471345e6f406e60079c1546a89e74/copyq/build_copyq.sh) 的注释。

## 界面语言选择

上游 [翻译加载逻辑](https://github.com/hluk/CopyQ/blob/ae65a1a2980d9b36848ef29ea17219adfd235aba/src/app/app.cpp#L34) 先读取 `COPYQ_LOCALE`，未指定时读取自身设置中的 `Options/language`，两者均未指定时才使用系统 locale。因此，构建脚本中的 `LANG`、`LANGUAGE` 和包内 locale 提供默认语言环境，不强制覆盖已经保存的应用语言选择。

语言切换、中文输入和终端提示的实机结果统一见 [README 实机验证](../README.md#实机验证)。
