# 国产 WPS Office（个人本地打包）

`build_wps-office-cn.sh` 使用 [AUR wps-office-cn](https://aur.archlinux.org/packages/wps-office-cn)及同一配方的 `wps-office-mui-zh-cn`，由其从[金山国内官网](https://www.wps.cn/product/wpslinux)取得当前正式版。保留 AUR 针对 Arch 运行环境的兼容处理、国内版完整 `office6`、中文 MUI 和原生入口，生成本机 `dist/wps-office-cn.AppImage`。

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





