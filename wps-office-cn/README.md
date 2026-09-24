# 国产 WPS Office（个人本地打包）

`build_wps-office-cn.sh` 使用 [AUR wps-office-cn](https://aur.archlinux.org/packages/wps-office-cn)及同一配方的 `wps-office-mui-zh-cn`，由其从[金山国内官网](https://www.wps.cn/product/wpslinux)取得当前正式版。保留 AUR 针对 Arch 运行环境的兼容处理、国内版完整 `office6`、中文 MUI 和原生入口，生成本机 `dist/wps.AppImage`。

2026-09-23 检查了国内 DEB 与 AUR 配方；它们对应同一国内版本，而 `ivan-hc/WPS-Office-appimage` 使用国际版来源，因此本脚本不使用后者。金山包内的个人版许可明确限制重新发行、复制和修改；本目录仅提供个人本机打包脚本，未接入会公开发布二进制的统一 Release 工作流。构建和桌面启动尚未验证。用户原有的通用 RunImage 环境未改动。

## 2026-09-24：对齐公共入口并带上缺失符号字体

构建脚本改用 `prepare_x86_64_workspace.sh` 清理本项目目录。成品非空检查和 `version.txt` 写入改成一行 `save_appimage_version.sh`。原先手写的 `AppRun.sh` 尚未实机验证，库目录、工作目录和 Qt 插件改写入 `AppDir/.env`，不再自写入口。

WPS 启动时提示缺失的是符号字体，不是整套 Windows 字体。构建时从 [iykrichie/wps-office-19-missing-fonts-on-Linux](https://github.com/iykrichie/wps-office-19-missing-fonts-on-Linux) 只取这 6 个文件：`symbol.ttf`、`wingding.ttf`、`WINGDNG2.ttf`、`WINGDNG3.ttf`、`WEBDINGS.TTF`、`mtextra.ttf`。字体不提交进 Git。`20-wps-fonts.hook` 在启动时把它们加进字体搜索，并继续包含宿主的 `/etc/fonts/fonts.conf`。构建和桌面启动仍未验证。符号字体在第一次 `quick-sharun` 之后才复制进 `AppDir/share/fonts/wps`，封装前会再确认这 6 个文件都在。

## 2026-09-24：中文输入改为 fcitx5 的 Qt 模块

WPS 使用自带 Qt 的 xcb 平台插件，不是 GTK，也不使用 ibus。构建依赖里的 `ibus` 改为 `fcitx5-qt`。按成品里的 `libQt5Core` 或 `libQt6Core` 选择对应的 `libfcitx5platforminputcontextplugin.so`，放进 `office6/qt/plugins/platforminputcontexts/`，并交给同一次 `quick-sharun` 收集依赖。不设置 `QT_IM_MODULE`，继续用宿主会话里的输入法。

## 2026-09-24：接入 latest Release

用户确认可以公开发布。参照已有的 [ivan-hc/WPS-Office-appimage](https://github.com/ivan-hc/WPS-Office-appimage) Release，那份是国际版；本仓库仍用 AUR `wps-office-cn` 打国内版，不改用它的来源。`wps-office-cn` 已加入 `.github/appimage-apps.json` 和手动构建列表，成品名是 `wps-office-cn.AppImage`。上方关于个人许可、当时未接入发布的记录保持原样。

## 2026-09-24：修正 Qt 库名识别

Actions Run `35973581804` 的 WPS Job 在安装 `wps-office-cn 12.1.2.28080-1` 后退出，提示未识别 Qt 版本。包内实际文件是 `libQt5CoreKso.so.5.12.12`，上一节按 `libQt5Core.so` 查找因此落空。现改为匹配 `libQt5Core*.so*` 和 `libQt6Core*.so*`，Qt5 仍使用 Arch 的 fcitx5 Qt5 输入模块。这次只改识别条件，构建结果以下一次 Actions 为准。

## 2026-09-24：Kso 后缀是 WPS 自己编译的 Qt

用户说明：WPS 的 Qt 是自己编译的，所以库名加了 `Kso`，例如 `libQt5CoreKso.so.5.12.12`，不是发行版的 `libQt5Core.so`。以后在这个目录里认 Qt、选插件或对库名，都要按带 `Kso` 的文件，不能按 Arch 或 Debian 的普通 Qt 文件名。发行版的 fcitx5 Qt 插件是对着普通 Qt 编的，和这套自己编译的 Qt 不是同一个产物。

## 2026-09-24：不再放入发行版 fcitx5 插件

Actions Run `35974681502` 在 `quick-sharun` 退出：放进成品的 `libfcitx5platforminputcontextplugin.so` 缺少库。该文件来自 Arch `fcitx5-qt`，链接的是发行版 Qt，不是 WPS 的 `Kso` Qt。同一包里已经有 `office6/qt/plugins/platforminputcontexts/libfcitxplatforminputcontextplugin.so`，这是对着 WPS 自己的 Qt 编译的输入模块。现去掉 `fcitx5-qt` 依赖，不再覆盖这个文件，并把包内原模块交给 `quick-sharun`。不设置 `QT_IM_MODULE`。这次构建结果以下一次 Actions 为准。

## 2026-09-24：成品改名为 wps.AppImage，并修正启动目录

用户运行 `./wps.AppImage` 后终端只出现 `UNICODEMAP_JP is cp932`，随即回到提示符，窗口没有留下。`wps-office-cn.AppImage` 这个名字太长，发布文件名改为 `wps.AppImage`。

官方 `/usr/bin/wps` 一类脚本把 `gInstallPath` 写死，并用 `>/dev/null 2>&1` 丢掉报错。现把安装目录改成启动脚本所在目录，使旁边的 `office6` 能被找到，并去掉这层丢弃。`PATH_MAPPING` 再把程序内部的 `/usr/lib/office6` 指到包内的 `bin/office6`。实机是否能打开窗口，以下一次成品为准。

## 2026-09-24：构建时检查会不会马上退出

用户要求下次构建就能知道会不会启动。仓库里已有公共入口 `common/gui/check_appimage_gui.sh`，WPS 在生成 `wps.AppImage` 后调用它：虚拟显示里运行 20 秒，进程提前退出即构建失败，并保留 `source/gui-smoke/smoke.log`。不新写第二套冒烟测试。空窗口标题只表示进程还活着，不表示实机窗口、中文输入或文档功能正常。

## 2026-09-24：office6 不能被 quick-sharun 挪走

Actions Run `35978165252` 已经打出 AppImage。图形检查里解包到 100% 后只打印 `UNICODEMAP_JP is cp932`，退出码 255。日志写明 quick-sharun 把 `AppDir/bin/office6/wps` 移到 `shared/bin/wps`，再包一层 sharun。WPS 要在原来的 `office6` 目录里找资源和自编译 Qt，主程序被挪走后就会马上退出。libgallium 的红色提示这次没有中断构建。

现改为先用 `/usr/lib/office6` 收集依赖，再把没被改过的整份 `office6` 复制到 `AppDir/opt/office6`，官方入口改指向这里。`cmp` 确认 `wps` 与安装包里的原文件一致。是否还能马上退出，以下一次图形检查为准。

## 2026-09-24：按 ivan-hc 的目录关系放 office6

对照 [ivan-hc/WPS-Office-appimage](https://github.com/ivan-hc/WPS-Office-appimage) 的 `wps-office.sh`。那边用 pkg2appimage 解开国际版 DEB，`office6` 留在 `opt/kingsoft/wps-office/office6`，再把 `/usr/bin` 启动脚本的 `gInstallPath` 改成相对路径 `$currdir/../../opt/kingsoft/wps-office/`。不把主程序交给 sharun 挪走。

本仓库仍用 AUR `wps-office-cn` 的国内版，不用它的国际版来源、额外语言包和 pkg2appimage。AUR 配方把脚本里的 `/opt/kingsoft/wps-office` 换成了 `/usr/lib`。成品里改回 `AppDir/opt/kingsoft/wps-office/office6`。启动脚本在 `bin`，相对路径少一层，是 `../opt/kingsoft/wps-office`。quick-sharun 只收集依赖；随后用官方脚本盖住 `bin/wps`，让生成的 `AppRun.sh` 执行这个脚本。不隐藏标准错误。

## 2026-09-24：安装目录赋值带缩进

Actions Run `35981343485` 在改写 `wps` 后退出，提示未能改写安装目录。官方脚本是 `if/else`，`gInstallPath=/usr/lib` 行首有空白，上一版只匹配行首的 `gInstallPath=`。现连同缩进行一起替换。同时去掉 `> /dev/null 2>&1`，这个写法中间有空格，上一版没有匹配到。

## 2026-09-24：实机能打开，界面仍是英文

用户运行 `wps.AppImage` 后窗口留下，文档里打进了中文，候选栏也在。菜单是 File、Home、Insert，不是中文。终端会话语言是 `en`，WPS 跟着宿主显示英文。

现确认成品里有 `mui/zh_CN`，并在 `.env` 里固定 `LANG=zh_CN.UTF-8` 和 `LC_ALL=zh_CN.UTF-8`。用 `localedef` 把简体中文 locale 放进 `usr/lib/locale`，`LOCPATH` 指向这里，不改宿主语言。中文菜单是否出现，以下一次实机为准。

## 2026-09-24：locale 输出目录要先建

Actions Run `35985805447` 里 `localedef` 退出码 4：`cannot write output files to zh_CN.UTF-8: No such file or directory`。`usr/lib/locale` 还不存在。现先建这个目录再生成 locale。

## 2026-09-24：界面仍是英文，改用 LANGUAGE

10:34 UTC 的 `wps.AppImage` 在实机上仍是英文主页：New file、Recent、Documents。文档名是中文，菜单不是。之前备注过国内版要中文界面。`LANG`、`LC_ALL` 和 `LOCPATH` 没有切换 WPS 12 的界面，`LOCPATH` 还会挡住宿主自己的语言，这三项已去掉。

WPS 12 在英文系统上认启动脚本里的 `LANGUAGE=zh_CN`。四个入口都写上这个变量。`15-wps-language.hook` 只把 `~/.config/Kingsoft/Office.conf` 的 `languages` 设为 `zh_CN`、`UILanguage` 设为 `2052`，不删除已有配置。中文菜单是否出现，以下一次实机为准。

## 2026-09-24：实机核对结束

用户在本机运行 `wps.AppImage`。主页、文字、演示、个人中心都是中文。文字稿和幻灯片里都能打中文，候选栏在。账号页能打开。终端里的 `QObject` 槽警告、`IBUS-WARNING` 和 `UNICODEMAP_JP is cp932` 没有让窗口退出。这次核对结束。

## 2026-09-24：Rofi 调不起，终端有一行 awk

实机从终端运行 `wps.AppImage` 能打开。终端第一行是 `awk: cannot open "-F=" (No such file or directory)`。这是 mawk 把 `awk -F=` 当成文件名。四个官方入口改成 `awk -F "="`。

Rofi 用的是桌面文件。原文件若有 `TryExec=wps` 或 `DBusActivatable=true`，系统里没有 `wps` 命令时 Rofi 不会启动，终端直接跑 AppImage 不受影响。这两行已从桌面文件去掉。已安装过的旧入口还在 `~/.local/share/applications/`，要删掉里面的 WPS 项，再用新的 `wps.AppImage` 从终端启动一次，让它重新登记。

## 2026-09-24：Rofi 仍起不来

`fa7090f` 去掉 `TryExec` 之后，Rofi 还是起不来，终端可以。Rofi 和文件管理器会设置 `GIO_LAUNCHED_DESKTOP_FILE`。WPS 12 见到这个变量会马上退出，终端启动没有这个变量。`15-wps-language.hook` 和四个入口现在都执行 `unset GIO_LAUNCHED_DESKTOP_FILE`。不改窗口管理模式。

## 2026-09-24：从 i3 启动时 Qt 的 xcb 插件加载失败

用 i3 执行 `/home/user/Appimages/GeneralSoftwares/wps.AppImage` 时，日志是 `Could not load the Qt platform plugin "xcb"`，随后 `bin/wps` 第 161 行启动 `office6` 程序段错误。终端直接运行没有这段报错。i3 自己也是 AppImage，传下来的库路径让 WPS 这套自己编译的 Qt 找到了 xcb 插件但加载不了。其他 quick 包不用这套 Qt，所以不受影响。

`10-wps-runtime.hook` 去掉路径里其他 `.mount_` 挂载，并把 Qt 插件目录固定到本包的 `office6/qt/plugins`。从 i3 能否留下窗口，以下一次实机为准。

## 2026-09-24：不能把包内 libc 放进库路径

上一节的钩子把 `AppDir/lib` 加进 `LD_LIBRARY_PATH`。从 i3 启动后，系统的 `grep` 和 `/bin/bash` 加载了包内 `libc.so.6`，报 `__pointer_chk_guard`。包内 libc 不能给系统程序用。现只去掉其他 `.mount_` 路径，并固定 Qt 插件目录，不再把 `AppDir/lib` 加进去。

## 2026-09-24：i3 的 SHARUN_DIR 不能当成 WPS 的目录

`1fce34f` 之后从 i3 启动仍然是 `xcb` 插件找到了但加载失败，然后第 161 行段错误。前面还有 `awk: cannot open "1830"`，程序是在这行之前就继续往下跑的，不是这次退出的原因。

钩子用的 `SHARUN_DIR` 可能还是 i3 传下来的。这样会把 WPS 自己的 `.mount_` 库路径当成外来路径丢掉，Qt 插件就加载不了。终端里没有这个变量，所以能开。现改到四个入口脚本里，按脚本自己的路径计算本包目录，并在执行 `office6` 程序的那一行之前清路径。

## 2026-09-24：xcb 插件缺 libxkbcommon-x11

从 i3 加 `QT_DEBUG_PLUGINS=1` 启动后，日志是 `libqxcb.so` 打不开 `libxkbcommon-x11.so.0`。终端能开，是因为系统动态链接器还能找到这套库。i3 把库搜索范围换掉以后就找不到。构建时把 `libxkbcommon-x11.so.0`、`libxkbcommon.so.0`、`libxcb-xkb.so.1` 放进 `office6`。`office6` 已经在启动前的库路径里。缺任何一个，构建直接停。


## 2026-09-24：存在性检查被改坏

Actions Run `36004656067` 的图形检查失败，日志是 `wpsoffice does not exist!`。上一节把 `${gInstallPath}/office6/${gApp}` 全部加上了 `_wps_fix_env`，包含 `[ -x ... ]` 这种检查。检查变成了一个不存在的文件名，脚本就报程序不存在并退出。现只改不含 `[` 的启动行。












## 2026-09-24：补上 office6 的上级目录

Actions Run `35980290938` 在 `cp` 退出：`AppDir/opt/kingsoft/wps-office/office6` 的上级目录不存在。复制前先创建 `opt/kingsoft/wps-office`。











