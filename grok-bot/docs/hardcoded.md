# Grok Bot 固定配置依据

核对日期：2026-10-30。这些是当前应用的实际构建参数，不作为其他应用的通用模板。脚本供隔离的 Arch Linux x86_64 构建环境使用。

| 固定项 | 当前值 | 依据与用途 |
| --- | --- | --- |
| 系统安装包 | `grok-bot-bin` | [AUR 固定 PKGBUILD](https://github.com/archlinux/aur/blob/7ece8a32a4f0be0b828c09eeb7d2eeb671d348e3/PKGBUILD)；程序来自 Cursor 官方 Grok Bot DEB。 |
| 动态接口 | `https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand；.version；.debUrl` | 原脚本使用的 stable manifest；沿用 CDN 正则和版本化资产模板。 |
| DEB 身份 | `grok-bot_{version}_amd64.deb；包名 grok-bot；架构 amd64` | 公共入口核对资源名、实际 DEB 元数据和接口版本。 |
| 归档根目录 | `grok-bot-unpacked/opt/Grok Bot` | 保留官方完整 Electron 目录，复制到 AppDir/bin。 |
| 程序及产物 | `APPNAME=Grok Bot；MAIN_BIN=grok-bot；STARTUPWMCLASS=grok-bot；dist/grok-bot.AppImage` | 保留既有程序标识、窗口匹配与发布名。 |
| 系统主 desktop | `/usr/share/applications/grok-bot.desktop` | AUR PKGBUILD 明确在此处理已安装的 desktop；本次只读取，不改系统文件。 |
| 系统图标 | `/usr/share/icons/hicolor/256x256/apps/grok-bot.png` | 沿用原脚本已使用的官方 DEB 256×256 图标。AUR 将 DEB 数据按原路径展开至系统；AUR 源码未逐个列图标文件，本次没有实际安装复核。 |
| 动态运行库 | `ALSA、libpulse、libpulse-simple、libpipewire、libpulsecommon、libnotify、libsecret、libayatana-appindicator` | 原脚本出声修复及已有动态依赖范围；完整文件路径见模板差异中的原始收集命令。 |
| 启动参数 | `--no-sandbox` | 保留已有启动兼容。Ubuntu 的用户命名空间限制可影响 Chromium 沙箱，参数会关闭应用自身沙箱，不能写成 AppImage 普遍必需。 |
| 协议 | `grokbot；sand` | 保留既有浏览器登录回调；公共 hook 登记当前 AppImage。 |
| 版本中间文件 | `grok-bot.version` | 同一次公共下载的 stdout 版本写入；公共 text 来源读取，不解析另一套元数据。 |
| 最终版本文件 | `dist/version.txt` | AppImage 成功生成后由公共保存入口检查产物并写入。 |
| 中文环境 | `LANG=zh_CN.UTF-8；LANGUAGE=zh_CN:zh；LC_MESSAGES=zh_CN.UTF-8；LOCPATH=${SHARUN_DIR}/lib/locale` | 按标准生成包内中文 locale，并保留运行时目录变量。 |

原始报错、修复经过和已有实机确认见 [README](../README.md)。采用及清理的具体代码位置见 [模板差异](template-deviations.md)。本次静态核对不替代新版本的完整构建或实机验收。
