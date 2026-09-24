# 打包 export 登记表

本表登记仓库 `.sh` 里已经出现的 `export` 环境变量。2026-09-24 对照 `384b663` 扫描，共 155 个。每个只说明它干什么。

以后打包要新增或修改 `export`，必须先把变量写进本表，写清用途和用在哪个程序。表里没有的不准用。用不到的变量不要为了凑齐硬加。已有脚本保持原样，不用为了对照本表去批量改。

`export -f` 导出的是函数，不是环境变量，不在本表里。

## 禁止

| 变量 | 说明 |
| --- | --- |
| `EXTRA_QT_MODULES` | 禁止。不要手工指定 `core`、`gui` 或其他 Qt 模块。Qt 插件必须自己从包里的 Qt 库识别模块。这个变量当前脚本里已经没有。 |

## 构建和打包工具

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `ARCH` | 告诉 linuxdeploy 和 appimagetool 打 x86_64。 | 80 个脚本，例如 Keyviz、adspower-global、aionui |
| `QMAKE` | 告诉 linuxdeploy 的 Qt 插件用哪个 qmake。Qt5 和 Qt6 不能混。 | 4 个脚本，例如 peazip、wemeet、xnconvert |
| `QT_SELECT` | 构建机上有多套 Qt 时，指定用 qt5 还是 qt6。 | 3 个脚本，例如 wemeet、xnconvert、xnviewmp |
| `DEPLOY_GTK_VERSION` | linuxdeploy 的 GTK 插件打哪一代。现有脚本都是 3。 | 6 个脚本，例如 baidunetdisk、binance、joplin |
| `APPIMAGE_EXTRACT_AND_RUN` | 让 AppImage 先解包再跑，不靠 FUSE。只在构建机使用，不写进最终包。 | 10 个脚本，例如 kitty、mediainfo、poppler-utils |
| `LDAI_OUTPUT` | linuxdeploy 中间 AppImage 的输出路径。这个文件不进发布目录。 | 3 个脚本，例如 mediainfo、poppler-utils |
| `LDAI_NO_APPSTREAM` | linuxdeploy 不生成 AppStream 元数据。 | 3 个脚本，例如 mediainfo、poppler-utils |
| `LDAI_RUNTIME_FILE` | linuxdeploy 使用的 AppImage runtime 文件。 | common |
| `DEBIAN_FRONTEND` | apt 安装时不弹问题。非交互构建用 noninteractive。 | 5 个脚本，例如 rainlendar2、realvnc-rvnc-connect、remmina |
| `NO_STRIP` | 打包时不剥调试符号。 | 21 个脚本，例如 aionui、bluemail、chatgpt |
| `VERSION` | 写进成品的上游软件版本。 | 23 个脚本，例如 aionui、alttab、bluemail |
| `OUTNAME` | 最终 AppImage 的文件名。 | 67 个脚本，例如 Keyviz、adspower-global、aionui |
| `OUTPATH` | 最终 AppImage 的输出目录，一般是 ./dist。 | 67 个脚本，例如 Keyviz、adspower-global、aionui |
| `APPNAME` | quick-sharun 用的应用名，用来生成入口和文件名。 | 32 个脚本，例如 aionui、android-tools、bluemail |
| `MAIN_BIN` | quick-sharun 的主程序文件名。必须是实际存在的程序，不能写错名字。 | 23 个脚本，例如 aionui、alttab、android-tools |
| `DESKTOP` | desktop 文件路径。quick-sharun 用它做菜单入口。 | 67 个脚本，例如 Keyviz、adspower-global、aionui |
| `ICON` | 图标文件路径。quick-sharun 用它做 AppImage 图标。 | 66 个脚本，例如 Keyviz、adspower-global、aionui |
| `STARTUPWMCLASS` | desktop 里的 StartupWMClass，让窗口能对上图标。 | 46 个脚本，例如 Keyviz、adspower-global、aionui |
| `UPINFO` | AppImage 的 zsync 更新信息，指向本仓库 latest Release。 | 3 个脚本，例如 android-tools、jriver、virt-manager |
| `OPTIMIZE_LAUNCH` | quick-sharun 打开启动优化。 | 2 个脚本，例如 jriver、virt-manager |
| `URUNTIME_PRELOAD` | 使用 uruntime 的 preload。 | 2 个脚本，例如 adspower-global、chromium |
| `RIM_ALLOW_ROOT` | 允许 RunImage 在 root 下运行。 | virt-manager |
| `STRACE_MODE` | quick-sharun 是否用 strace 扫依赖。0 是不用。 | 12 个脚本，例如 aionui、bluemail、chatgpt |
| `STRACE_BINARY` | quick-sharun 用 strace 跟踪哪个程序来找动态库。只在构建容器里用。 | 3 个脚本，例如 adspower-global、chromium、deepseek-harness |
| `STRACE_FLAGS` | 上面那个 strace 的附加参数，例如 --no-sandbox。不写进运行入口。 | 3 个脚本，例如 adspower-global、chromium、deepseek-harness |
| `PATH_MAPPING` | AnyLinux 把宿主路径映射到包内路径。 | 3 个脚本，例如 freerdp、i3wm、parsec |
| `PATH_MAPPING_HARDCODED` | AnyLinux 按文件名固定做路径映射，不靠自动扫描。 | obs-studio |
| `DWARFS_COMP` | dwarfs 压缩方式和级别。 | antigravity-ide |
| `CSC_IDENTITY_AUTO_DISCOVERY` | electron-builder 不自动找签名证书。这里只打 Linux 包，避免它去找 macOS 证书。 | hermes-desktop |
| `CPPFLAGS` | 编译时附加的头文件参数。只用于 alttab 编译。 | alttab |
| `LIBS` | 编译时附加的链接参数。只用于 alttab 编译。 | alttab |
| `QT_LOCATION` | 构建时 Qt 的安装位置。 | moderncsv |
| `SOURCE_DIR` | 传给 st 配置生成脚本的源码目录。 | st |
| `ST_FONT_PRIMARY` | 编译 st 时的主字体。 | st |
| `ST_FONT_FALLBACKS` | 编译 st 时的备用字体。 | st |
| `ST_FONT_PIXELS` | 编译 st 时的字体像素大小。 | st |
| `WINE_VERSION` | 把 WineHQ 包版本里的 ~rc 转成上游 tag 用的 -rc。 | wine |
| `WINPODX_BUNDLE_DIR` | WinPodX 在 CI 里的打包目录。 | .github |
| `WEBKIT2GTK_DIR` | WebKitGTK 库目录，构建时用来找到要打进包的文件。 | Keyviz |
| `PYTHONPATH` | Python 模块搜索路径。 | .github |
| `XDG_DATA_HOME` | 用户数据目录。CI 里指到临时目录，避免写到构建机家目录。 | .github |

## quick-sharun 开关

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `DEPLOY_GTK` | quick-sharun 是否打入 GTK。 | 29 个脚本，例如 Keyviz、aionui、antigravity-ide |
| `DEPLOY_OPENGL` | quick-sharun 是否打入 OpenGL / Mesa。 | 34 个脚本，例如 Keyviz、aionui、antigravity-ide |
| `DEPLOY_VULKAN` | quick-sharun 是否打入 Vulkan。 | 22 个脚本，例如 aionui、antigravity-ide、antigravity |
| `DEPLOY_PIPEWIRE` | quick-sharun 是否打入 PipeWire。 | 21 个脚本，例如 aionui、chatgpt、cursor |
| `DEPLOY_PULSE` | quick-sharun 是否打入 PulseAudio。 | webcamoid |
| `DEPLOY_QT` | quick-sharun 是否打入 Qt。 | 3 个脚本，例如 freedownloadmanager、obs-studio、webcamoid |
| `DEPLOY_QML` | quick-sharun 是否打入 Qt QML。 | webcamoid |
| `DEPLOY_LOCALE` | quick-sharun 是否打入 locale。 | 6 个脚本，例如 antigravity-ide、antigravity、freedownloadmanager |
| `DEPLOY_PYTHON` | quick-sharun 是否打入 Python 运行时。 | 2 个脚本，例如 obs-studio、smplayer |
| `DEPLOY_SDL` | quick-sharun 是否打入 SDL。 | obs-studio |
| `DEPLOY_GDK` | quick-sharun 是否打入 GDK。 | ripdrag |
| `DEPLOY_GLYCIN` | quick-sharun 是否打入 glycin 图片加载器。 | ripdrag |
| `DEPLOY_GSTREAMER` | quick-sharun 是否打入 GStreamer。0 是不打。 | webcamoid |
| `DEPLOY_WEBKIT2GTK` | quick-sharun 是否打入 WebKitGTK。 | Keyviz |
| `DEPLOY_ELECTRON` | quick-sharun 是否自动扫描 Electron。0 是关掉，避免它改官方 asar。 | chatgpt |
| `DEPLOY_CHROMIUM` | quick-sharun 是否自动按 Chromium 去扫依赖。0 是关掉。 | chatgpt |
| `DEPLOY_COMMON_LIBS` | quick-sharun 是否打入一批常见系统库。 | chatgpt |
| `DEPLOY_P11KIT` | quick-sharun 是否打入 p11-kit 证书模块。 | chatgpt |
| `DEPLOY_DATADIR` | quick-sharun 是否把数据目录打进包。0 是不打。 | deepseek-harness |
| `SHARUN_WORKING_DIR` | quick-sharun 的工作目录，一般是主程序所在目录。 | 12 个脚本，例如 aionui、chatgpt、feishu |
| `SHARUN_EXTRA_LIBRARY_PATH` | quick-sharun 额外扫描这些目录里的库。 | 12 个脚本，例如 aionui、chatgpt、feishu |
| `SHARUN_ALLOW_QT_PLUGIN_PATH` | 允许 quick-sharun 保留应用自己设的 QT_PLUGIN_PATH，不把它清掉。 | mailmaster。wps-office-cn 改在 AppDir/.env 里设置，构建脚本不再 export 它。 |
| `NO_AT_BRIDGE` | 不连接无障碍总线，避免启动时卡住或刷警告。 | 3 个脚本，例如 joplin、peazip、ventoy |

## 启动路径

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `PATH` | 可执行文件搜索路径。包内 bin 放前面。 | 20 个脚本，例如 baidunetdisk、binance、chatgpt |
| `LD_LIBRARY_PATH` | 动态库搜索路径。包内库放前面。 | 19 个脚本，例如 baidunetdisk、binance、dconf-editor |
| `XDG_DATA_DIRS` | 共享数据搜索目录，包括 desktop、locale 和 schema。包内 usr/share 放前面。 | 16 个脚本，例如 baidunetdisk、binance、dconf-editor |
| `XDG_CONFIG_DIRS` | 配置文件搜索目录。包内目录放前面。 | kde-suite |
| `APPDIR` | AppImage 解包后的根目录。运行时用来拼包内路径。 | 8 个脚本，例如 dconf-editor、kitty、mission-center |
| `LD_PRELOAD` | 程序启动前先加载指定的 so。 | 3 个脚本，例如 dingtalk、peazip、runimage |
| `FONTCONFIG_FILE` | 用包里的字体配置，避免宿主旧字体缓存影响启动。 | 3 个脚本，例如 github-desktop、keepass、wps-office-cn |
| `FONTCONFIG_PATH` | 字体配置的搜索目录。 | github-desktop |

## Qt

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `QT_PLUGIN_PATH` | Qt 插件目录。官方或应用自带目录放前面，linuxdeploy 的 usr/plugins 放后面。 | 10 个脚本，例如 dingtalk、kde-suite、mailmaster |
| `QT_QPA_PLATFORM_PLUGIN_PATH` | 只放平台插件的目录，比 QT_PLUGIN_PATH 更窄。官方目录放前面。 | 6 个脚本，例如 dingtalk、mailmaster、wemeet |
| `QT_QPA_PLATFORM` | Qt 用哪个平台插件。xcb 是 X11，wayland 是 Wayland。 | 9 个脚本，例如 dingtalk、mailmaster、obs-studio |
| `QT_QPA_PLATFORMTHEME` | Qt 平台主题，用来跟桌面外观。例如 qt6ct。 | 2 个脚本，例如 kde-suite、peazip |
| `QT_IM_MODULE` | Qt 输入法模块，常见是 fcitx 或 ibus。 | 4 个脚本，例如 dingtalk、kde-suite、mailmaster |
| `QT_TRANSLATIONS_PATH` | Qt 翻译文件目录。 | 3 个脚本，例如 peazip、xnconvert、xnviewmp |
| `QML_IMPORT_PATH` | QML 模块目录。 | 3 个脚本，例如 kde-suite、xnviewmp |
| `QML2_IMPORT_PATH` | Qt5 的 QML 模块目录。 | 3 个脚本，例如 kde-suite、xnviewmp |
| `QML_DISABLE_DISK_CACHE` | 禁止 Qt Quick 写磁盘缓存。 | kde-suite |
| `QT_QUICK_CONTROLS_STYLE` | Qt Quick Controls 的样式，例如 KDE Breeze。 | kde-suite |
| `QT_STYLE_OVERRIDE` | 强制 Qt 控件样式，盖过应用默认样式。 | 2 个脚本，例如 flameshot、peazip |
| `QT_AUTO_SCREEN_SCALE_FACTOR` | 让 Qt 按屏幕缩放界面。 | 4 个脚本，例如 dingtalk、peazip、wechat |
| `QT_SCALE_FACTOR` | Qt 界面缩放倍数。 | peazip |
| `QT_FONT_DPI` | 固定 Qt 字体 DPI。 | 2 个脚本，例如 peazip、xnviewmp |
| `QT_XCB_GL_INTEGRATION` | XCB 下用哪种 OpenGL 集成，例如 xcb_egl。 | 2 个脚本，例如 mailmaster、xnviewmp |

## GTK、语言和输入法

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `GTK_IM_MODULE` | GTK 文本框用哪个输入法模块，常见是 ibus 或 fcitx。 | 10 个脚本，例如 aionui、dconf-editor、dingtalk |
| `GTK_IM_MODULE_FILE` | GTK 输入法模块缓存文件的路径。 | 4 个脚本，例如 dconf-editor、rainlendar2、remmina |
| `GTK_THEME` | 强制使用的 GTK 主题名。 | 3 个脚本，例如 joplin、rainlendar2、ripdrag |
| `GTK_PATH` | GTK 模块搜索路径。 | keepass |
| `GTK_DIR` | GTK 模块所在的目录名，例如 gtk-4.0。 | mission-center |
| `GTK2_RC_FILES` | GTK2 的主题配置文件。 | keepass |
| `GDK_BACKEND` | GDK 用哪个显示后端。这里固定 x11。 | rainlendar2 |
| `GDK_GL` | 是否开 GDK 的 OpenGL。disable 是关掉。 | remmina |
| `GIO_MODULE_DIR` | GIO 模块目录。必须指向包内，不能指宿主。 | 4 个脚本，例如 baidunetdisk、binance、joplin |
| `GIO_EXTRA_MODULES` | 额外的 GIO 模块目录，追加在原有路径后面。 | dconf-editor |
| `GSETTINGS_SCHEMA_DIR` | GSettings 的 schema 目录，让 GTK 读包内设置定义。 | 5 个脚本，例如 baidunetdisk、binance、joplin |
| `GI_TYPELIB_PATH` | GObject Introspection 的 typelib 目录。 | remmina |
| `XMODIFIERS` | X11 输入法开关，例如 @im=ibus 或 @im=fcitx。 | 11 个脚本，例如 aionui、dingtalk、kde-suite |
| `GLFW_IM_MODULE` | kitty 的 GLFW 用哪个输入法模块。这里是 ibus。 | kitty |
| `IBUS_ADDRESS` | 这次启动要连的 IBus 套接字，不用外部环境里可能失效的地址。 | kitty |
| `LANG` | 界面语言。图形程序常用 zh_CN.UTF-8。 | 5 个脚本，例如 gitkraken、obs-studio、tencent-docs |
| `LANGUAGE` | 翻译语言的回退顺序，例如 zh_CN:zh。locale 不可用时用来保留中文界面。 | 9 个脚本，例如 gemini、gitkraken、kde-suite |
| `LC_ALL` | 强制整套 locale。有的构建用 C；图形程序要中文时才用 zh_CN.UTF-8。 | 6 个脚本，例如 chatgpt、gemini、gitkraken |
| `LOCPATH` | locale 档案目录。腾讯会议用它读包内的 zh_CN.UTF-8。 | wemeet |
| `TZ` | 时区。腾讯会议按官方脚本设成 Asia/Shanghai。 | wemeet |
| `XDG_SESSION_TYPE` | 当前会话类型。Wayland 上回退到 X11 时改成 x11。 | 2 个脚本，例如 jriver、wemeet |

## 声音、浏览器和个别程序

| 变量 | 干什么 | 哪里在用 |
| --- | --- | --- |
| `CANBERRA_DRIVER` | libcanberra 用哪个声音后端。这里选 Pulse，兼容 PulseAudio 和 PipeWire。 | rainlendar2 |
| `PIPEWIRE_MODULE_DIR` | PipeWire 模块目录。 | kde-suite |
| `SPA_PLUGIN_DIR` | PipeWire SPA 插件目录。 | kde-suite |
| `GSTREAMER_INCLUDE_BAD_PLUGINS` | 允许使用 GStreamer 的 bad 插件。 | remmina |
| `OPENSSL_MODULES` | OpenSSL 3 的 provider 目录。必须和包内的 libcrypto 配套。 | remmina |
| `FREERDP_PLUGIN_PATH` | Remmina 加载 FreeRDP 插件的目录。 | remmina |
| `VLC_PLUGIN_PATH` | VLC 插件目录。 | wechat |
| `WEBKIT_EXEC_PATH` | WebKit 子进程所在目录。 | remmina |
| `WEBKIT_DISABLE_DMABUF_RENDERER` | 关掉 WebKit 的 dmabuf 渲染，避免花屏。 | remmina |
| `CHROME_DESKTOP` | 告诉 Electron / Chromium 对应哪一个 desktop 文件。 | 2 个脚本，例如 github-desktop |
| `ELECTRON_FORCE_IS_PACKAGED` | 让 Electron 把自己当成已打包程序，而不是开发模式。 | workbuddy |
| `GITHUB_DESKTOP_DISABLE_HARDWARE_ACCELERATION` | GitHub Desktop 关闭硬件加速。 | github-desktop |
| `GNOME_KEYRING_CONTROL` | 把已解开的 gnome-keyring 套接字传给后续进程。 | hermes-desktop |
| `APPIMAGE_GTK_THEME` | 指定 AppImage 里 GTK 用哪套主题。 | realvnc-rvnc-connect |
| `DSH_HOME` | DeepSeek Harness 的配置目录。默认是用户自己的 ~/.dsh，升级包不覆盖。 | deepseek-harness |
| `HOME` | 临时改家目录。只在该脚本明确需要时用。 | hermes-desktop |
| `XDG_RUNTIME_DIR` | 运行时套接字和临时文件目录。 | hermes-desktop |
| `SHELL` | 当前 shell。Remmina 用它启动本地终端。 | remmina |
| `TERM` | 终端类型。没设置时用 xterm-256color。 | jriver |
| `TERMINFO` | terminfo 数据库目录。 | kitty |
| `TERMINFO_DIRS` | terminfo 的搜索目录列表。包内目录放前面。 | kitty |
| `WEMEET_XWAYLAND` | 腾讯会议走 XWayland 时的标记，沿用官方启动脚本。 | wemeet |
| `WINEPREFIX` | Wine 前缀目录。 | trae-work |
| `WINEARCH` | Wine 前缀架构。这里是 win64。 | trae-work |
| `WINEDEBUG` | Wine 调试输出。-all 是关掉。 | trae-work |
| `WINEDLLOVERRIDES` | Wine 的 DLL 覆盖规则。 | trae-work |
| `MONO_CFG_DIR` | Mono 配置目录。 | keepass |
| `MONO_CONFIG` | Mono 配置文件。 | keepass |
| `MONO_MWF_SCALING` | Mono WinForms 是否自己缩放。disable 是关掉。 | keepass |
| `LTDL_LIBRARY_PATH` | libltdl 的模块搜索路径。 | rainlendar2 |
| `REMMINA_HOST_SHELL` | Remmina 打开本地终端时用的用户原来的 shell。 | remmina |
| `REMMINA_LAUNCH_CWD` | Remmina 启动时所在的目录。本地终端要回到这里。 | remmina |
| `RVNC_HOST_PATH` | 改包内 PATH 之前，先记下宿主的 PATH，给 xdg-open 用。 | realvnc-rvnc-connect |
| `RVNC_HOST_LD_LIBRARY_PATH` | 改包内库路径之前，先记下宿主的 LD_LIBRARY_PATH，给 xdg-open 用。 | realvnc-rvnc-connect |
| `RVNC_HOST_XDG_DATA_DIRS` | 改包内数据路径之前，先记下宿主的 XDG_DATA_DIRS，给 xdg-open 用。 | realvnc-rvnc-connect |
| `PEAZIP_ORIGINAL_LD_PRELOAD` | PeaZip 先记下原来的 LD_PRELOAD。兼容层加载后立刻恢复，避免 7z 等子进程继承它。 | peazip |
| `JRIVER_CEF_SKIP_SHUTDOWN` | 只给 JRiver 的指定进程用，退出时跳过 CEF 清理。 | jriver |
| `JRIVER_FILECHOOSER_SAVED_PRELOAD` | 记下并清掉外层传来的 LD_PRELOAD，避免文件选择器继承别人的预加载库。 | runimage |
| `HOOK_NAME` | 生成 desktop 时写入的程序名。 | common |
| `HOOK_COMMENT` | 生成 desktop 时写入的 Comment。 | common |
| `HOOK_ICON` | 生成 desktop 时写入的图标名。 | common |
| `HOOK_DESKTOP` | 要生成或修改的 desktop 文件。 | common |
| `HOOK_CATEGORIES` | 生成 desktop 时写入的 Categories。 | common |
| `HOOK_WM_CLASS` | 生成 desktop 时写入的 StartupWMClass。 | common |
| `HOOK_MIME_EXTRA` | 额外写进 desktop 的 MIME 类型。 | common |
| `HOOK_SCHEMES` | 生成 desktop 时登记的 URL scheme。 | common |
| `HOOK_OUTPUT` | desktop hook 的输出路径。 | common |
