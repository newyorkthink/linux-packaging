# Grok App 固定配置依据

核对日期：2026-10-30。这些是当前应用的实际构建参数，不作为其他应用的通用模板。脚本供隔离的 Arch Linux x86_64 构建环境使用。

| 固定项 | 当前值 | 依据与用途 |
| --- | --- | --- |
| 程序来源 | `RongleCat/grok-app；Grok_{version}_amd64.deb` | [官方 Release](https://github.com/RongleCat/grok-app/releases/tag/v0.2.50)；版本动态选择，不固定为 0.2.50。 |
| DEB 身份 | `包名 grok；架构 amd64` | 沿用既有公共下载入口校验参数。 |
| 程序及产物 | `APPNAME=Grok；MAIN_BIN=grok-app；STARTUPWMCLASS=grok-app；dist/grok-app.AppImage` | 保留本应用名称、真实程序名、窗口匹配值和既有发布名。 |
| 主 desktop | `grok-app-unpacked/usr/share/applications/Grok.desktop` | 沿用已记录的官方 DEB 布局，从本次独立解包目录读取。 |
| 图标 | `grok-app-unpacked/usr/share/icons/hicolor/128x128/apps/grok-app.png` | 沿用 README 中已核对的 DEB 128×128 图标，不改成未核实的系统路径。 |
| WebKitGTK | `DEPLOY_OPENGL=1；DEPLOY_WEBKIT2GTK=1；WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1` | 程序的 WebKitGTK 4.1 / GTK 3 依赖及既有部署方式。 |
| 托盘库 | `/usr/lib/libayatana-appindicator3.so.1` | 旧记录确认由程序动态加载，不在主程序 NEEDED 中。 |
| 选目录工具 | `zenity-rs 0.3.0；AppDir/bin/filechooser/zenity` | 原 2026-10-14 修复；无可用 portal 时供 rfd 回退，静态工具不交给 quick-sharun。 |
| 工具摘要 | `f7a351180f364501855181420ceecd40b42ff84742ab79eca7aec43fe8ec074a` | 保持原有官方资产 SHA-256；更换版本须重新核对参数、静态性质与摘要。 |
| 运行时路径 | `filechooser、/usr/bin、/bin、HOSTPATH、包内 bin` | 原 bwrap 修复的顺序；2026-10-07 用户实测已使用 /usr/bin/bwrap。 |
| 协议及 MIME | `grok；application/vnd.grok.skin` | 既有公共协议 hook 参数，与当前 AppImage 路径绑定。 |
| 版本中间文件 | `grok-app.version` | 同一次公共下载的 stdout 版本写入；公共 text 来源读取，不解析另一套元数据。 |
| 最终版本文件 | `dist/version.txt` | AppImage 成功生成后由公共保存入口检查产物并写入。 |
| 中文环境 | `LANG=zh_CN.UTF-8；LANGUAGE=zh_CN:zh；LC_MESSAGES=zh_CN.UTF-8；LOCPATH=${SHARUN_DIR}/lib/locale` | 按标准生成包内中文 locale，并保留运行时目录变量。 |

原始报错、修复经过和已有实机确认见 [README](../README.md)。采用及清理的具体代码位置见 [模板差异](template-deviations.md)。本次静态核对不替代新版本的完整构建或实机验收。
