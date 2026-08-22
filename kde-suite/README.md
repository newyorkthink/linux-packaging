# KDE Suite

`kde-suite/build_kde_suite.sh` 构建一个共享挂载的 `kde-suite.AppImage`，内含 KDE Connect、Dolphin、KFind、Konsole、Filelight、KDF、Okular、Gwenview、Haruna、Ark、Kompare、Qt6ct、Plasma Activities 后台及必要的 KDE/KF6 运行组件。

## 稳定基线（2026.08.08）

当前版本按“核心功能可重复使用、已知日志不影响结果”验收，不以终端完全无输出作为稳定标准。已完成的实际验收包括：

- KDE Connect 可打开“共享文件”内置选择器，不再闪退；选择小文件后手机可完整收到。
- Dolphin“下载服务”可正常加载和显示项目，不再白屏；是否安装第三方服务由用户自行决定。
- Okular 可打开 PDF 和 Markdown，点击“打开文档”不再闪退。
- Haruna 可播放本地视频及 yt-dlp 支持的网络链接，网络视频可持续播放且不再因 yt-dlp 子进程处理错误卡住。
- Dolphin、Ark、Gwenview、Kompare、Konsole、Filelight、Activities、KIO 和 SSHFS 的关键入口均有构建期完整性检查。
- Qt6ct、KFind、KDF 已加入同一个 AppImage 和图形启动器；已确认 Qt6ct 设置界面能够正常打开。
- Qt6ct AppImage 配色路径持久化修复已完成实机验收：内置配色不再依赖失效的 `/tmp/.mount_*` 绝对路径，而是迁移到当前用户固定配置目录；修复不写死明暗主题，也不写死用户名。
- 图形启动器保持三列布局，所有应用卡片固定为 `180×150`，不再因最后一列文字宽度而横向拉伸。

这里的“稳定”不表示所有桌面会话、Portal、硬件解码器、视频编码和第三方下载源都没有上游警告；下文列出的边界仍然存在。

### 基准提交与回退规则

- 当前仓库迁移基准为 [`f4b0ace822ac90774c010b078f61d19afe5fb799`](https://github.com/newyorkthink/linux-packaging/commit/f4b0ace822ac90774c010b078f61d19afe5fb799)（`Migrate KDE Suite AppImage files`）。该提交把旧仓库 `wx-projects/appimage-builds/kde/` 的 12 个文件原样迁移到当前仓库 `kde-suite/`；它用于确认迁移内容完整，不代表重新进行了一次功能实机验收。
- 当前仓库工作流接入基准为 [`0df09c6494fc38bc45e85d3772f44fad2fd57cc1`](https://github.com/newyorkthink/linux-packaging/commit/0df09c6494fc38bc45e85d3772f44fad2fd57cc1)（`Integrate KDE Suite AppImage build [skip ci]`）。该提交将仓库路径统一为 `kde-suite/...`，并把 KDE Suite 接入当前 `.github/workflows/build.yml` 的独立 `build_kde_suite` job；它属于迁移适配，不替代下列迁移前已完成实机验收的功能基准。
- 迁移前最后一个已完成实机验收的功能源码基准为旧仓库 [`4c29370ffa2be58c65d0a9e00e63d2cff2ef58df`](https://github.com/wx-projects/appimage-builds/commit/4c29370ffa2be58c65d0a9e00e63d2cff2ef58df)（`修复 Qt6ct AppImage 配色路径持久化`）。该提交只在 `deploy_utility_apps.sh` 中增加独立 `01-kde-suite-qt6ct-color-path.hook` 及对应构建期检查，不修改已经验证有效的 Dolphin、Haruna、KDE Connect、KIO、MIME、图标主题和启动器运行逻辑；当时产物已完成实机验收，Qt6ct 配色路径持久化修复确认有效。
- 迁移前上一个 2026.08.08 功能稳定基准为旧仓库 [`0053f35d8c702fffe82ecd3b57a41a0196cc1a4f`](https://github.com/wx-projects/appimage-builds/commit/0053f35d8c702fffe82ecd3b57a41a0196cc1a4f)（`Fix KDE Suite launcher card sizes`），保留为 Qt6ct 配色持久化修复之前的历史回退点。
- 迁移前早期完整构建记录为旧仓库 [`447519e4196b4ff29434467dff7f4611eee051f5`](https://github.com/wx-projects/appimage-builds/commit/447519e4196b4ff29434467dff7f4611eee051f5)（`补充 KDE Suite 轻量工具说明`）。旧仓库 GitHub Actions Run `31241444761` 的 `build_kde` 已成功完成，并确认 Qt6ct、KFind、KDF 已进入套件；该记录只用于保留迁移前完整构建历史，不替代当前仓库的迁移基准或迁移前最后功能基准。
- 更早的迁移前功能稳定基准为旧仓库 [`2c33b838639f46cd9c92202d46352e20fc137b97`](https://github.com/wx-projects/appimage-builds/commit/2c33b838639f46cd9c92202d46352e20fc137b97)（`Finalize KDE Suite stable build checks`），继续作为 2026.07.31 版本的历史回退点。
- 后续功能修改必须建立在最近一次稳定基准之上。若新增改动出现构建失败、功能回退或实机异常，应撤销该基准之后尚未验证的功能改动，回到最近一次已验证的基准，不在错误方案上连续叠加修补。
- 稳定基准可以继续向前推进。新增功能完成后，只有在构建检查通过、现有功能未受影响且新增功能完成实机验收时，才把对应提交登记为新的当前稳定基准；原有基准继续保留为历史回退点。
- 每次形成新的稳定基准，都必须在本节记录日期、完整提交哈希、提交说明和实际验收结果。纯文档提交不替代功能源码基准。

## 启动入口

- `kde-suite`：打开 KDE Suite 图形启动器。
- `kdeconnect`：直接打开 KDE Connect。
- `dolphin`：直接打开 Dolphin。
- `kfind`：直接打开 KFind，查找文件和文件夹。
- `konsole`：直接打开 Konsole。
- `filelight`：直接打开 Filelight。
- `kdf`：直接打开 KDF，查看磁盘、挂载点和剩余空间。
- `okular`：直接打开 Okular，处理 PDF 和其他受支持文档。
- `gwenview`：直接打开 Gwenview，查看图片。
- `haruna`：直接打开 Haruna，播放视频和音频。
- `ark`：直接打开 Ark，管理压缩包。
- `kompare`：直接打开 Kompare，比较文本文件和文件夹差异。
- `qt6ct`：直接打开 Qt6ct，管理 Qt6 外观、字体和图标主题。

这些入口均指向同一个 AppImage。由启动器从当前 `$APPDIR/bin` 启动的内部程序共用同一个 FUSE 挂载。

## 已完成的集成

- 固定使用简体中文界面，并保留宿主区域格式。
- 打包 Fcitx5 Qt6 输入模块，Konsole 等 Qt6 应用可使用宿主 Fcitx5 输入中文。
- 图片默认使用 Gwenview，视频和音频默认使用 Haruna，PDF 默认使用 Okular。
- Haruna 内置 Arch 仓库版 `yt-dlp`、匹配的 `yt-dlp-ejs` 和 Deno，可解析 YouTube 等 yt-dlp 支持的网站链接；本地播放链路保持不变。
- Dolphin 可显示受支持 AppImage 的内置图标和元数据。
- KDE Connect 图形入口会复用现有 `kdeconnectd`；不存在时才启动 AppImage 内后台。
- Dolphin 会复用现有 `org.kde.ActivityManager`；不存在时由 AppImage 启动 `kactivitymanagerd`，不需要 `sudo`。
- Kompare 已接入 Dolphin 的“比较文件”，选择两个文本文件或两个文件夹时可用。
- Qt6ct、KFind 和 KDF 作为轻量实用工具进入同一个 AppImage；Qt6ct 继续使用用户级 `~/.config/qt6ct/qt6ct.conf`，不会修改宿主 `/usr`，KFind 与 KDF 也以普通用户权限运行。
- Qt6ct 只保存字体名称等 Qt6 外观配置；当前 AppImage 不额外内置 Cantarell 等字体文件，实际字体由宿主 Fontconfig/字体库解析和回退。
- Qt6ct 从 AppImage 内选择配色时可能把当前 FUSE 挂载目录保存到 `color_scheme_path`。运行时 Hook 只在该路径属于旧 `/tmp/.mount_*/share/qt6ct/colors/*.conf` 时，将当前 AppImage 内同名配色复制到 `${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/` 并改写为固定用户路径；不写死配色名称，因此浅色、深色和其他内置配色均保留用户最后选择，已经使用固定路径或用户自定义外部配色时不改。
- 图形启动器的应用卡片固定为 `180×150`；卡片不再使用 `QSizePolicy::Expanding`，三列宽度保持一致。
- Dolphin 的“下载服务”等 KDE NewStuff/Kirigami 窗口已包含 `qqc2-breeze-style`；运行时会清除优先级更高、但会被误当成 QML 模块的 `QT_STYLE_OVERRIDE=Breeze`，再固定使用 `org.kde.breeze`。同一修复也保证 Haruna 能加载主界面。
- KIO 已打包 `kiod6` 主进程、`kioexecd`、`kpasswdserver`、`kssld` 三个按需插件，以及 `org.kde.kiod6`、`org.kde.kioexecd6`、`org.kde.kpasswdserver6`、`org.kde.kssld6` 四个 D-Bus activation 文件。
- SSHFS 与 `libfuse3` 保留在 AppImage 内；`fusermount3` 必须使用宿主系统安装的特权 helper，不能复制进 AppImage。宿主需要安装 `fuse3` 并提供可执行的 `/usr/bin/fusermount3`。
- Qt6ct 仍负责配色和外观，但不打包 `libqgtk3.so` 与 `libqxdgdesktopportal.so` 文件对话框后端；Okular 和 KDE Connect 统一使用 Qt 内置选择器，避免连接宿主原生后端时崩溃。
- Ark、回收站、缩略图、文件预览、终端和磁盘空间分析组件均已集成。

## 明确不打包的组件

- 不加入 `org.kde.kuiserver`。它由 Plasma 工作区提供，只负责在 Plasma 中统一显示后台任务进度；KIO 实际复制、下载服务和 KDE Connect 文件传输不依赖它。为一条日志引入完整 `plasma-workspace` 会扩大体积和运行时耦合。
- 不加入 Kate/KWrite。当前套件定位为设备连接、文件管理、文档查看、图片和媒体处理，简单文本编辑可使用宿主编辑器。Kate 本身是稳定的 KDE 应用，若以后明确加入，会随 Arch 软件包在每次 AppImage 重建时更新，不需要像大型 IDE 那样单独维护更新器；但它不是当前稳定目标的依赖。
- 不在 AppImage 内启动完整桌面 Portal broker。`xdg-desktop-portal-kde` 后端已经随依赖进入构建环境，但 `org.freedesktop.portal.Desktop` 服务属于宿主桌面会话；没有该服务时，Input Capture 等 Portal 功能不能仅靠继续复制动态库解决。
- 不预装 Dolphin“下载服务”中的第三方项目。该窗口能够查询和展示内容即表示本地 KNewStuff 链路正常，第三方服务的安全性、兼容性和可用性不属于本仓库保证范围。

## 后续可选扩展

以下两项仅作为后续评估记录，当前稳定版均未实现，也不表示已经计划加入。没有明确使用需求时继续保持现有稳定基线，后续有时间再分别评估。

- **KRunner**：可在 i3 下提供搜索、程序启动、计算和命令入口。Arch 的 `krunner` 软件包本身只是框架库，真正的 `/usr/bin/krunner` 和核心搜索插件属于 `plasma-workspace`；若以后加入，应只选择性部署所需程序、插件、QML 和数据文件，不打包完整 Plasma 工作区。
- **Plasma Browser Integration**：技术上可以将 `plasma-browser-integration-host` 及其运行依赖打包进 KDE Suite，用于浏览器 MPRIS 媒体控制和通过 KDE Connect 发送网页链接。但浏览器扩展及 `NativeMessagingHosts` 配置仍需安装在宿主浏览器环境中；浏览器标签页和历史搜索还需要 KRunner，i3 会话下也不提供完整的 Plasma 下载通知，并可能产生一个由浏览器宿主进程保持的额外 AppImage 挂载。只有在明确需要这些功能并完成对应浏览器兼容性检查后再考虑加入。

## 图标主题

KDE Suite 统一使用标准 `breeze` 和 `breeze-dark` 图标，不再打包完整 Flat Remix 图标集。

若宿主 Qt6ct 仍设置为 `Flat-Remix-Blue-Dark`，AppImage 内提供同名兼容入口并直接继承 `breeze`。这样既不会出现主题不存在警告，也不会混用 Flat Remix 的文件夹、工具栏和状态图标；宿主系统中的其他程序不受影响。

## 构建结构

- `build_kde_suite.sh`：构建入口，预装额外应用、Activities、Breeze QML 样式、yt-dlp 和 Deno，再加载套件级部署。
- `build_core.sh`：已验证的 KDE Suite 基础构建逻辑。
- `deploy_utility_apps.sh`：部署 Qt6ct、KFind、KDF、Qt6ct 配色路径迁移 Hook 及其桌面入口、运行数据和 Hicolor 应用图标。
- `deploy_suite_apps.sh`：最终部署入口，按顺序组合 Haruna、Python 版 yt-dlp、yt-dlp-ejs、Deno、Activities、现有应用集成、MIME、语言和主题检查。
- `deploy_activities.sh`：部署 `kactivitymanagerd`、活动插件、Qt SQLite 驱动、D-Bus 描述和 Dolphin 启动包装。
- `deploy_icon_theme.sh`：保留 Breeze/Breeze Dark，并创建 `Flat-Remix-Blue-Dark` 到 Breeze 的兼容入口。
- `okular_ark.sh`：现有应用集成脚本，继续负责 Okular、Ark、Gwenview、Kompare、文件关联、KDE Connect 后台和 Fcitx5；文件名为历史名称，已验证逻辑保持不变。
- `apps.ini`：图形启动器的应用清单和中英文名称。

## 已知限制与非致命日志

- Dolphin“属性 → 共享”页面由 `kdenetwork-filesharing` 提供，但实际 Samba `smbd` 服务属于宿主系统，不在 AppImage 内启动。宿主未安装或未启用 Samba 时会显示“文件共享服务不可用”；如果不使用 Samba 文件夹共享功能可直接忽略，不影响 Dolphin 普通文件管理、KDE Connect 及套件其他功能。
- i3/Kali 会话没有运行 `org.freedesktop.portal.Desktop` 时，终端可能出现 `qt.qpa.theme.gnome ... ServiceUnknown` 或 KDE Connect Input Capture 错误。文件共享、设备连接和播放正常时可忽略；不要仅为消除日志给 AppImage 增加权限或强行启动桌面服务。
- KDE Connect 可能输出 QML `depends on non-bindable properties`、Breeze `Value is null`、通知扩展未实现或蓝牙 `Missing CAP_NET_ADMIN`。文件已完整送达、设备连接和多媒体控制正常时，这些是上游界面或可选能力日志。
- Qt 内置文件选择器在个别浅色配色下，选中目录的文字和背景对比度偏低。这是当前防崩溃方案的外观限制，不影响选择和传输；不要为改善颜色恢复 `qgtk3`/`qxdgdesktopportal` 后端。
- AppImage 缩略图插件主要读取 SquashFS；遇到 DwarFS 或其他格式时可能反复输出 `This doesn't look like a squashfs image`，对应文件可能使用通用图标，不影响执行。
- Dolphin 信息面板使用 Qt Multimedia/FFmpeg 预览，与 Haruna 的播放链路不同。个别视频可能只有声音、画面为黑色，或输出 VDPAU/PipeWire/AAC 时间戳提示；同一文件在 Haruna 中画面和声音正常时属于预览后端或编码差异。
- Okular 打开 Markdown 时会按 Markdown 标题层级使用不同字重，缺少完全匹配的中文字体时还可能回退到另一字重；内容和 PDF 输出正常时属于排版差异。
- Haruna 设置页可能输出 QML `width/null`、`Binding loop` 或 `not placed in the graphics scene` 警告；设置页面和播放功能正常时属于上游界面日志。
- Dolphin“下载服务”可能输出 Kirigami `Could not create delegate`、`Object or context destroyed during incubation` 或短暂的 `QSslSocket device not open`；列表已正常加载且窗口可操作时不影响功能。
- KDE Connect Indicator 偶尔输出 `QSystemTrayIcon::setVisible: No Icon set`；托盘图标和菜单随后正常出现时可忽略。
- Kompare 使用文本 `diff`，不提供 PDF 版面或内容语义比较；PDF 应使用专用 PDF 比较工具。
- 主动关闭 AppImage 时，仍在运行的子程序可能产生 FUSE 挂载 busy 或 `QProcess ... still running`；若播放一直停在加载状态并连续出现该日志，则不属于可忽略情况。

## 已踩过的坑

- 不直接复制 PyInstaller 版 yt-dlp 可执行文件。当前使用 Arch Python 版 `yt-dlp`、匹配的 `yt-dlp-ejs`、内置 Python 和 Deno，并在打包前实际执行版本及模块导入检查。
- `QT_STYLE_OVERRIDE=Breeze` 是 Widgets 风格名，不是 Qt Quick Controls 模块名。让它进入 Haruna/Kirigami 会导致 `module "Breeze" is not installed`、Haruna 无法启动或下载服务白屏；运行时必须清除它并使用 `org.kde.breeze`。
- Qt6ct 将 AppImage 内颜色方案保存为 `/tmp/.mount_*/share/qt6ct/colors/*.conf` 的绝对路径时，旧挂载在 AppImage 退出或系统重启后会消失，下一次启动就可能回退为默认浅色。不能写死某个深色配色；最终按配色文件名把当前用户最后选择迁移到固定用户配置目录，换用户、换电脑和明暗切换均使用各自 `$HOME`/`XDG_CONFIG_HOME`。
- 曾尝试只为 Dolphin 构建 C++/CMake 启动注入库，由 Dolphin 启动包装脚本通过 `LD_PRELOAD` 加载，校验进程名并从继承环境移除自身，再使用两次零延时 `QTimer::singleShot(0, ...)`，在 qt6ct 初始化后调用 `KColorSchemeManager::activateScheme()` 重新应用 `[UiSettings] ColorScheme`。初版因 `find_package(KF6 REQUIRED COMPONENTS ColorScheme)` 找不到 `KF6Config.cmake` 而构建失败；改为 `find_package(KF6ColorScheme REQUIRED)` 后构建通过，但实机测试对重启后的配色异常没有效果，因此相关源码、构建步骤和注入逻辑均已回退，稳定版不保留该方案。
- 宿主 Qt6ct 的 `standard_dialogs=gtk3/xdgdesktopportal` 会把 AppImage 文件选择交给不便携后端，曾导致 KDE Connect“共享文件”和 Okular“打开文档”闪退；最终只保留 Qt 内置选择器。
- `fusermount3` 是宿主上带特权属性的 helper。复制到 AppImage 后权限丢失且会遮蔽 `/usr/bin/fusermount3`，导致 SSHFS `Operation not permitted`；因此只打包 `sshfs` 和 `libfuse3`。
- 四个 KIO D-Bus 名称不是四个独立守护进程；它们共用 `kiod6`，另外三个功能由插件按需加载。仅复制程序或仅复制 `.service` 都不完整。
- KDE Connect 图形程序在当前 Qt/KDE 组合下使用 QML 磁盘缓存会在部分设备操作中崩溃；只对 `kdeconnect-app` 禁用缓存，避免影响其他 QML 应用。
- SquashFS 与 DwarFS AppImage 不能由同一个现有缩略图插件完整覆盖。最终保留普通 SquashFS AppImage 的图标/元数据能力，并把其他格式的解析日志记录为已知限制。

## 发布前检查

构建脚本会在压缩前自动检查启动器、`apps.ini` 中全部命令、Qt6ct/KFind/KDF、Qt6ct 配色路径迁移 Hook、KIO 服务与插件、SSHFS/FUSE 边界、Qt/Kirigami/Breeze、中文翻译、Fcitx5、MIME、图标、Activities、yt-dlp/Python/EJS/Deno，并在 Xvfb 中启动 Haruna 做 QML 运行时检查。

发布后至少人工确认以下结果：

1. KDE Connect 共享一个小文件，远端设备完整收到。
2. Dolphin“下载服务”能显示列表；无需安装第三方项目。
3. Okular 可通过“打开文档”选择并打开 PDF/Markdown。
4. Haruna 可播放一个本地文件和一个网络链接。
5. Dolphin 可预览常规图片/PDF；视频信息面板的黑屏限制与 Haruna 实际播放分开判断。
6. `sshfs` 只在宿主已安装可用 `/usr/bin/fusermount3` 时验收挂载。
7. KFind 可按名称查找普通文件或文件夹。
8. KDF 可显示宿主磁盘、挂载点、容量和剩余空间。
9. Qt6ct 可打开并读取当前 Qt6 外观配置；分别保存浅色和深色后重新启动仍保持最后选择，并确认 `color_scheme_path` 已从 `/tmp/.mount_*` 迁移到当前用户固定配置目录；整个过程不修改宿主 `/usr`。
10. KDE Suite 启动器保持三列布局，所有应用卡片尺寸一致并固定为 `180×150`。

## GitHub Actions

向 `main` 推送 `kde-suite/**` 下的变更时，`.github/workflows/build.yml` 会自动选择 KDE Suite，并由独立 `build_kde_suite` job 执行 `kde-suite/build_kde_suite.sh`，构建并上传 `kde-suite.AppImage`。

需要自动构建的提交信息不得包含 `[skip ci]`、`[ci skip]` 等跳过 CI 的标记。仅更新稳定基线说明等纯文档时应使用 `[skip ci]`，避免重复消耗 Actions 时间。

迁移前旧仓库的历史完整构建记录：2026-08-08 的 Run `31241444761` 已成功完成旧 `build_kde` job。该次完整构建约耗时 48 分钟；`quick-sharun` 在整理大量 `AppDir/lib` 依赖和最终处理阶段可能连续十几分钟没有新增网页日志，GitHub 页面会停留在最后一条库软链接输出。只要 job 仍处于运行状态，这种“日志静默”本身不能判断为死锁或失败。

工作流本身不配置构建缓存；相关路径、容器权限、依赖安装、脚本选择和产物目录必须在提交前静态检查。一次完整修改只推送一次 `main`，不要把 Actions 当成 Shell/YAML 基础错误的试运行环境。

### 构建隔离

KDE Suite 会安装大量 Qt6、KF6、Mesa 和 LXQt 相关依赖，必须继续保持独立 GitHub Actions job 和独立 Arch Linux 构建容器，不能与其他 AppImage 项目在同一个容器中串行构建。

原因是这些依赖会保留在容器的 `/usr/lib` 等系统目录中；后续项目使用 `quick-sharun`、动态依赖扫描或通配符收集库文件时，可能把 KDE Suite 的依赖误打包进去。旧仓库曾出现 KDE Suite 依赖被后续 KeePass 构建误收集，导致 KeePass AppImage 从约 120 MB 增长到约 225 MB。

因此 KDE Suite 的维护规则是：独立 job、独立构建容器；`plan` job 只负责选择构建项目和准备 Release，不安装 KDE Suite 的具体构建依赖。
