# XnView MP AppImage

## 用途与产物

本目录构建 XnView MP 的 x86_64 AppImage，正式 Release 资产固定为 `xnviewmp.AppImage`。

## 上游版本与校验

构建脚本每次读取 XnView 官方 `XnView_MP-CHECKSUMS.txt`，按版本号选择最新稳定版 `linux-x64.tgz`，并使用同一份官方清单中的 SHA-256 校验归档。版本不再锁死为 1.11.5；实际打包版本写入 `dist/version.txt`。

统一清单键仍使用 `xnview`，Release 资产名仍为 `xnviewmp.AppImage`。

## 兼容环境

XnView MP 是 Qt5 应用，并自带 Qt、MDK 和 FFmpeg 组件。GitHub Actions 外层 runner 使用 Ubuntu 24.04，但脚本会进入 Ubuntu 22.04 Jammy 容器完成打包，以保持已验证的 PulseAudio、GStreamer、VA-API、Wayland 和 XCB 运行时组合。应用主体继续放在 `AppDir/opt/XnView`，且启动时优先使用其自带库。

## linuxdeploy 规范流程

1. 在空目录执行 `export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage`，只创建 `usr/bin`、`usr/lib`、`usr/share` 等基础目录。当前 linuxdeploy 因空 AppDir 尚无 desktop 会返回 1；脚本仅在目录已创建且没有非预期文件时接受该已知结果。
2. 第一次初始化完成后才下载并校验 XnView 官方 tar，把应用主体按上游布局解压到 `AppDir/opt/XnView`；Qt5、QML、输入法和媒体依赖同时安装在 Ubuntu 22.04 隔离构建环境中供 linuxdeploy 扫描。
3. 写入已经按最终 AppImage 核对过的完整根 `AppDir/AppRun`。无论主程序位于 `/opt`，仍固定保留 `usr/bin`、`usr/lib`、`usr/share`，分别加入 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`；Qt plugin 只使用 `opt/XnView/lib` 与 `usr/plugins`，QML 只使用 `opt/XnView/qml`，翻译使用 `usr/translations`。
4. 设置 `QT_SELECT=qt5` 和 `QMAKE=/usr/lib/qt5/bin/qmake`，再以 `export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage` 为基础命令执行第二次 linuxdeploy；只追加允许的 `--desktop-file` 与 `--icon-file`。
5. 第二次 linuxdeploy 把完整根 AppRun 保存为 `AppRun.wrapped`，并生成加载 Qt hook 的顶层 AppRun。
6. XnView 最终目录已经通过实际 Release AppImage 解包确认，因此构建脚本直接保留准确 AppRun，不再调用公共路径整理脚本。
7. XnView 打包永久禁止 `--executable`，不生成、不依赖 `AppDir/usr/bin/XnView` 副本。
8. linuxdeploy 输出只作为中间结果，最终从同一个 AppDir 使用官方 appimagetool 和官方 Type 2 runtime 封装 `dist/xnviewmp.AppImage`。

脚本中的检查只用于构建输入、官方摘要、第一次目录初始化状态和最终产物的必要错误处理；正式脚本与工作流不提交 GUI smoke test、媒体样例生成或解包测试代码。

## 运行

```bash
./xnviewmp.AppImage
```

## 变更记录

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
