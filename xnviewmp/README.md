# XnView MP AppImage

## 用途与产物

本目录构建 XnView MP 的 x86_64 AppImage，正式 Release 资产固定为 `xnviewmp.AppImage`。

## 上游版本与校验

构建脚本每次读取 XnView 官方 `XnView_MP-CHECKSUMS.txt`，按版本号选择最新稳定版 `linux-x64.deb`，并使用同一份官方清单中的 SHA-256 校验。版本不再锁死为 1.11.5；实际打包版本写入 `dist/version.txt`。

统一清单键仍使用 `xnview`，Release 资产名仍为 `xnviewmp.AppImage`。

## 兼容环境

XnView MP 当前稳定版是 Qt6 应用，并自带 Qt、MDK 和 FFmpeg 组件。GitHub Actions 外层 runner 与实际打包容器均使用 Ubuntu 24.04，确保 qmake、Qt plugin、QML 扫描工具和输入法插件全部使用 Qt6。应用主体继续放在 `AppDir/opt/XnView`，且启动时优先使用其自带 Qt6 运行库。

## linuxdeploy 规范流程

1. 单行加载 `common/linuxdeploy/prepare_build_workspace.sh`，统一建立并清理标准 `source`、`AppDir`、`dist` 与 `source/tools` 工作区；APT 依赖和 linuxdeploy 工具也分别交给对应公共入口准备。
2. 单行调用 `common/linuxdeploy/initialize_appdir.sh`；公共入口在空目录执行原始普通 linuxdeploy 命令，只创建基础目录。随后由 `common/download/download_latest_checksum_asset.sh` 从官方校验清单选择最新版、验证 SHA-256 并返回实际版本。
3. 第一次初始化完成后下载同一份 XnView 官方 DEB，将它安装到 Ubuntu 24.04 隔离构建环境供依赖扫描，并由 `common/archive/extract_archive.sh` 按官方布局解包到 AppDir；上游 `opt/XnView` 与 `usr/bin/xnview` 原样保留，desktop 只把绝对图标路径改为 AppImage 可发现的图标名称。
4. 写入已经按最终 AppImage 核对过的完整根 `AppDir/AppRun`。无论主程序位于 `/opt`，仍固定保留 `usr/bin`、`usr/lib`、`usr/share`，分别加入 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`；Qt plugin 只使用 `opt/XnView/lib` 与 `usr/plugins`，QML 只使用 `opt/XnView/qml`，翻译使用 `usr/translations`。
5. 加载 `common/linuxdeploy/configure_environment.sh` 设置通用 linuxdeploy 环境，项目自身只追加 Qt6 的 `QT_SELECT` 与 `QMAKE`，再执行第二次 linuxdeploy；只追加允许的 `--desktop-file` 与 `--icon-file`。
6. Qt6 插件是否生成 hook 以当前官方工具实际产物为准；没有 hook 时完整根 AppRun 继续作为顶层入口，不人工补 `AppRun.wrapped`。
7. Qt 主版本变化后最终目录尚未重新确认，因此第二次 linuxdeploy 后恢复调用公共路径整理脚本；新成品确认后再固化最终路径并移除该调用。
8. XnView 打包永久禁止 `--executable`，不生成、不依赖 `AppDir/usr/bin/XnView` 副本。
9. linuxdeploy 输出只作为中间结果，最终由 `common/linuxdeploy/package_appimage.sh` 使用官方 appimagetool 和官方 Type 2 runtime 封装 `dist/xnviewmp.AppImage`；正式 AppImage 成功生成后再原子写入 `dist/version.txt`。

应用脚本只保留按指定库名收集必需媒体运行库等 XnView 特有逻辑；通用命令、下载、安装、解包、初始化和最终封装由公共入口负责。linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime 每次构建都由公共脚本取得官方最新版本，不需要人工或 AI 更新工具版本。正式脚本与工作流不提交 GUI smoke test、媒体样例生成或解包测试代码。

## 官方 DEB 启动入口

`usr/bin/xnview` 是 XnView 官方 DEB 自带的 88 字节 shell launcher，内容仅根据参数情况转发到 `/opt/XnView/XnView`。构建脚本没有创建、覆盖或修改这个文件，只通过公共解包入口把官方 DEB 的原始目录布局放入 AppDir。

AppImage 实际启动仍由构建脚本写入的根 `AppRun` 直接执行 `opt/XnView/XnView`；保留 `usr/bin/xnview` 是为了完整保留官方 DEB 布局，不是本仓库另外增加了一层启动包装。

## 运行

```bash
./xnviewmp.AppImage
```

## 变更记录

### 2026-09-29：处理 Qt6 部分视频黑屏与 Fcitx5 中文输入失效

真实运行中，同为 H.264 / AAC 的视频出现部分正常、部分只有黑屏的情况；FFmpeg 能正常识别黑屏文件的视频流，`No HW decoder found` 表示没有可用硬件解码器并回退软件解码，不等同于缺少 H.264 解码能力。与此同时，终端明确出现 `Xcb EGL gl-integration initialize failed`，而 AppRun 仍强制使用从旧 Qt5 运行结果延续下来的 `QT_XCB_GL_INTEGRATION=xcb_egl`。现有证据因此指向 Qt6 视频帧渲染路径，而不是视频文件无法解码。

构建脚本现移除强制 `xcb_egl`，保留已使用的 XCB 平台，并设置 `QT_DISABLE_HW_TEXTURES_CONVERSION=1`，让 Qt Multimedia 避开出现异常的 GPU 纹理转换路径。当前 Qt6 构建已经安装 `fcitx5-frontend-qt6` 并通过 `QT_PLUGIN_PATH` 接入 linuxdeploy 的 `usr/plugins`，但 AppRun 没有明确选择输入上下文；本次同时设置 `QT_IM_MODULE=fcitx`，其中 `fcitx` 是 Fcitx5 Qt 输入模块使用的变量值。

本次只调整 AppRun 运行环境，现有 Qt6、qmake 隔离、媒体运行库、动态版本和最终封装流程均未改动。已完成 Shell 语法、变量登记和完整 diff 静态检查；提交后不监控 Actions，新的构建结果以及视频播放、Fcitx5 中文输入的实际运行效果尚未验证。

### 2026-09-29：隔离系统 qmake6 与 XnView 自带 Qt 运行库

Actions Job `109297829710` 在第二次 linuxdeploy 的 Qt 插件阶段调用 `/usr/bin/qmake6` 时，错误加载了 `AppDir/opt/XnView/lib` 中的 Qt 6.10.3 运行库，出现 `undefined symbol: qtconfManualPath, version Qt_6_PRIVATE_API` 并退出。根因是依赖扫描所需的 `LD_LIBRARY_PATH` 同时传给了系统 qmake，造成 Ubuntu 24.04 的 qmake 与 XnView 自带 Qt 私有 ABI 混用，不是网络、下载或 SHA-256 校验故障。

构建脚本现于工具目录生成 `qmake6` 隔离入口，仅在执行系统 `/usr/bin/qmake6` 前清除 `LD_LIBRARY_PATH`；linuxdeploy 本身仍保留原有 XnView 库搜索路径，现有 Qt6、媒体运行库、AppRun、动态版本和最终封装流程均未改动。本次完成 Shell 语法与完整 diff 静态检查；提交后不监控 Actions，新的构建结果和实际运行效果尚未验证。

### 2026-09-29：随官方 1.12.0 从 Qt5 迁移到 Qt6

官方 1.12.0 DEB 的主程序已经依赖 `libQt6*.so.6`，包内运行库升级为 Qt 6.10.3，并提供 `libQt6XcbQpa.so.6.10.3`、Qt6 plugin 与 QML 目录；原脚本继续复制 `libQt5XcbQpa.so*`，导致 Actions Job `109289404064` 在该文件不存在时退出。

构建脚本现把实际打包容器改为 Ubuntu 24.04，Qt 构建与输入法依赖、qmake、翻译目录、XCB 平台库和 linuxdeploy 环境全部迁移到 Qt6；原有 GStreamer、PulseAudio、VA-API、Wayland、udev、AppRun 和最终 appimagetool + Type 2 runtime 封装流程继续保留。Qt6 官方插件不再假定必然生成 hook；Qt 主版本变化后重新启用公共 AppRun 路径整理，等待新成品确认后再固化。

本次已核对官方 DEB 的包元数据、主程序 ELF 依赖、RPATH、Qt6 运行库、plugin、QML 和输入上下文目录，并完成 Shell 语法与完整 diff 静态检查。提交后不监控 Actions，新的构建结果和实际运行效果尚未验证。

### 2026-09-21：改用官方 DEB 并修复版本元数据权限

XnView MP 改为从官方校验清单选择当前最新 `linux-x64.deb`，同一 DEB 同时安装到 Jammy 构建环境并通过公共归档入口解包到 AppDir，不再下载 TGZ、搜索主程序后手工复制目录。官方 `usr/bin/xnview` 与 `opt/XnView` 原样保留，desktop 只规范图标字段；已经确认有效的根 AppRun、Qt5、媒体运行库和第二次 linuxdeploy 配置不变。

公共校验清单入口只返回本次实际版本，不再提前生成 `version.txt`；最终封装公共入口在正式 AppImage 成功后原子写入 `dist/version.txt` 并统一设置 `0644`，避免容器内 root 创建的 `0600` 文件导致宿主 runner 无法上传版本元数据。linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime 仍由公共工具入口在构建时动态取得官方最新版本，不记录固定版本。

最终产物解包截图中的 `usr/bin/xnview` 已与当前官方 DEB 内同路径文件逐行核对一致；截图同时确认 XnView MP 正常启动、中文界面、中文输入和媒体浏览。当前正式 Actions 构建及版本元数据上传均成功，没有发现需要继续修改打包代码的问题。

### 2026-09-20：统一复用公共构建入口

标准工作区、APT 安装、官方校验清单最新版下载、linuxdeploy 通用环境、第一次空 AppDir 初始化和最终 appimagetool 封装均改为调用 `common/` 公共入口。应用脚本删除了重复的 root / sudo、命令存在性、解包后文件清单和最终产物检查；XnView 专用的 Jammy 容器、Qt5 配置、媒体运行库、第二次 linuxdeploy 参数及已验证 AppRun 内容保持不变。

### 2026-09-20：复用公共空 AppDir 初始化入口

第一次普通 linuxdeploy 已集中到 `common/linuxdeploy/initialize_appdir.sh`；本项目构建脚本只保留一行调用。XnView MP 专用 Qt5 环境、已确认 AppRun 和第二次 linuxdeploy 命令均未改变。

### 2026-09-20：核对正式 Release 成品并完成规范沉淀

重新下载并解包 `latest/xnviewmp.AppImage` 后确认：顶层 AppRun 正确加载 Qt hook 并执行 `AppRun.wrapped`；主程序在当前 AppDir 库路径下没有缺失的直接动态依赖；`opt/XnView/lib` 与 `usr/plugins` 都包含真实 Qt plugin 分类目录；`opt/XnView/Plugins` 是 XnView 自身格式解码库，`AddOn` 与 `UI` 也是应用私有目录，均不属于 `QT_PLUGIN_PATH`。

`opt/XnView/language` 保留 XnView 自带翻译，linuxdeploy 已把对应翻译逐项链接到 `usr/translations`，因此 `QT_TRANSLATIONS_PATH` 只保留 `usr/translations`。用户实际运行截图同时确认中文界面、中文路径、图片浏览和视频播放正常。终端中的 `libvdpau_va_gl.so` 信息表示宿主缺少可选 VDPAU 后端；当前视频已经通过其他后端正常播放，不构成 AppImage 打包失败。

本次只补充成品证据和后续 linuxdeploy 项目的核对方法，没有改动已经确认有效的 AppRun export 或启动命令。

### 2026-09-20：固化最终 AppRun 并复用公共下载入口

实际 Release AppImage 已确认视频播放、中文界面和中文输入正常。解包核对显示 `usr/qml` 不存在；`usr/translations` 已通过符号链接完整接入 `opt/XnView/language`；`opt/XnView/lib` 是 Qt plugin 根目录，而 `opt/XnView/Plugins` 是由主程序 `$ORIGIN/Plugins` RPATH 加载的图片格式组件，不属于 `QT_PLUGIN_PATH`。

构建脚本现直接写入上述最终路径，不再调用 `normalize_apprun_paths.sh`。XnView 官方文件统一通过 `common/download/download_file.sh` 下载，linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime 统一通过 `common/linuxdeploy/prepare_linuxdeploy_tools.sh` 动态取得并校验；项目保持独立，不依赖外部仓库。

### 2026-09-20：整理最终 AppRun 路径并处理视频 OpenGL 上下文

真实运行日志出现 `QXcbIntegration: Cannot create platform OpenGL context, neither GLX nor EGL are enabled`、`QOpenGLWidget: Failed to create context` 和连续 `composeAndFlush: makeCurrent() failed`。XnView 官方论坛针对 Linux 视频播放问题明确建议 `QT_XCB_GL_INTEGRATION=xcb_egl`，并有 AppImage 用户反馈该设置可恢复视频播放。

构建脚本把 XnView 自带的 `opt/XnView/lib` 加入 `QT_PLUGIN_PATH`，保留现有 Qt / 中文环境基线，并设置 `QT_XCB_GL_INTEGRATION=xcb_egl`。当时第二次 linuxdeploy 后通过公共脚本核对路径；最终目录确认后，整理结果已在上面的最新记录中固化回 AppRun。

本次已完成脚本静态语法、公共脚本合成 AppDir 行为和修改范围核对；提交后按仓库规则不监控 Actions，新产物的视频播放结果仍需真实运行确认。

### 2026-09-20：修正空 AppDir 初始化与第二阶段部署顺序

Actions Job `106072203246` 在第一次 linuxdeploy 时已经放入 XnView desktop，但 `AppDir/usr/bin` 为空且根 AppRun 尚未写入，因此 linuxdeploy 按 `Exec=XnView` 查找入口并报错。脚本现改为先在空目录执行普通 linuxdeploy，只接受基础目录已创建且没有非预期文件的初始化结果；随后再解压 XnView、写入包含 `usr/bin`、`usr/lib`、`usr/share` 基础路径的完整根 AppRun，最后执行 Qt linuxdeploy。全程不使用 `--executable`，也不制造 `usr/bin/XnView`。

### 2026-09-20：统一 linuxdeploy 与最终封装流程

改为动态解析官方最新稳定版；补齐两阶段 linuxdeploy、Qt5 `QMAKE`、真实 `AppRun`、Qt hook/`AppRun.wrapped` 及 appimagetool + Type 2 runtime 最终封装，并移除正式提交中的 smoke/test 代码。

### 2026-09-20：修复 XnView 入口布局、中文环境与 AppDir 路径

Actions Job `106070682762` 已成功完成打包；用户实际解包和运行确认 Qt hook、`AppRun.wrapped` 与中文输入法可用，同时发现界面语言退回英文。最终 AppDir 实际包含 `usr/bin`、`usr/lib`、`usr/plugins`、`usr/qml`、`usr/translations` 和 `usr/share`。根 AppRun 因此恢复 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并把这些 linuxdeploy 生成目录加入对应搜索路径。

两次 linuxdeploy 调用移除 `--executable AppDir/opt/XnView/XnView`：该参数会把上游位于 `/opt/XnView` 的主程序额外部署成 `AppDir/usr/bin/XnView`，不属于原始包布局。脚本不创建、不依赖该副本，根 AppRun 始终直接执行 `AppDir/opt/XnView/XnView`。

### 2026-09-20：补齐 Qt5 Declarative 与 QML 打包工具

Actions Job `106069546113` 在 Qt 插件的 QML 阶段调用 `/usr/bin/qmlimportscanner`，因 qtchooser 没有选中 Qt installation 而退出。构建脚本补装 Qt5 qmake、Declarative 开发工具、`qmlimportscanner` 和常用 Qt Quick/QML 模块，并把 `PATH`、`QT_SELECT`、`QMAKE` 明确绑定到 `/usr/lib/qt5/bin`。本次仅完成脚本语法和远端 diff 核对，提交后未监控 Actions，实际构建结果未验证。
