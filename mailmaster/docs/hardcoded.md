# MailMaster 固定配置依据

| 配置 | 依据及用途 |
| --- | --- |
| AUR 包 `mailmaster`，主 DEB 选择规则 `mailmaster-{version}.deb` | [AUR .SRCINFO](https://github.com/archlinux/aur/blob/28daf15d8ff9c1efe75dbe2edd1e0673b3ffbe46/.SRCINFO)中的来源别名。版本、HTTPS 地址和摘要均取自当前配方。 |
| `opt/mailmaster/.` → `AppDir/bin/` | 已解包核对的 DEB 布局。CEF 数据、Qt 插件和主程序保留相对路径。 |
| `/opt/mailmaster/launch.sh`、`/opt/mailmaster/lib/libnss_wrapper.so`、`/opt/mailmaster/lib/libgconf-2.so.4`、`/usr/share/licenses/mailmaster` | [AUR PKGBUILD](https://github.com/archlinux/aur/blob/28daf15d8ff9c1efe75dbe2edd1e0673b3ffbe46/PKGBUILD)的安装位置。保留启动脚本、兼容库和许可证。 |
| `APPNAME=MailMaster`、`MAIN_BIN=mailmaster`、`STARTUPWMCLASS=mailmaster` | 沿用原构建的应用名、真实程序名和窗口匹配值。 |
| `/usr/share/applications/mailmaster.desktop`、`/usr/share/icons/hicolor/256x256/apps/mailmaster.png` | AUR 安装的桌面入口和 256 像素图标。 |
| `QT_QPA_PLATFORM=xcb`、`QT_XCB_GL_INTEGRATION=none` | 保留 AUR 和原 AppImage 的 XCB 运行配置。 |
| `QT_IM_MODULE` 默认 `ibus`，`fcitx5-qt` 的 `/usr/lib/qt/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so` | 保留原输入法默认值。新增模块路径来自 [Arch 包文件清单](https://archlinux.org/packages/extra/x86_64/fcitx5-qt/files/)，对应 Qt 5。 |
| `SHARUN_ALLOW_QT_PLUGIN_PATH=1`、`QT_PLUGIN_PATH`、`QT_QPA_PLATFORM_PLUGIN_PATH`、`SHARUN_EXTRA_LIBRARY_PATH`、`SHARUN_WORKING_DIR` | 沿用应用自身的插件目录、库路径和工作目录，在 `.env` 使用包内相对位置。 |
| `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1`、`DEPLOY_PIPEWIRE=1` | 沿用原 MailMaster 构建的运行库部署范围。 |
| `zh_CN.UTF-8`、`zh_CN:zh`、`lib/locale` | quick-sharun 中文环境约定，供包内运行时读取。 |
| `--no-sandbox`、`chrome-sandbox` 权限 0755 | 沿用原 AppImage 的 CEF 启动参数和权限处理。 |
| `dist/mailmaster.AppImage`、`dist/version.txt` | 沿用现有 workflow、Release 资产名和版本元数据路径。 |
