# XnView MP AppImage

## 用途与产物

本目录构建 XnView MP 的 x86_64 AppImage，正式 Release 资产固定为 `xnviewmp.AppImage`。

## 上游版本与校验

构建脚本每次读取 XnView 官方 `XnView_MP-CHECKSUMS.txt`，按版本号选择最新稳定版 `linux-x64.tgz`，并使用同一份官方清单中的 SHA-256 校验归档。版本不再锁死为 1.11.5；实际打包版本写入 `dist/version.txt`。

统一清单键仍使用 `xnview`，Release 资产名仍为 `xnviewmp.AppImage`。

## 兼容环境

XnView MP 是 Qt5 应用，并自带 Qt、MDK 和 FFmpeg 组件。GitHub Actions 外层 runner 使用 Ubuntu 24.04，但脚本会进入 Ubuntu 22.04 Jammy 容器完成打包，以保持已验证的 PulseAudio、GStreamer、VA-API、Wayland 和 XCB 运行时组合。应用主体继续放在 `AppDir/opt/XnView`，且启动时优先使用其自带库。

## linuxdeploy 规范流程

1. 普通 linuxdeploy 阶段使用 `--output appimage` 创建并规范化 `AppDir`。
2. 第一阶段完成后，脚本写入项目真实的根 `AppDir/AppRun`；入口直接执行 `/opt/XnView/XnView`，并同时加入上游 `/opt` 与 linuxdeploy 实际生成的 `usr/bin`、`usr/lib`、`usr/plugins`、`usr/qml`、`usr/translations`、`usr/share` 路径。
3. 把 `/usr/lib/qt5/bin` 放在 `PATH` 最前，设置 `QT_SELECT=qt5` 和 `QMAKE=/usr/lib/qt5/bin/qmake`，再执行 `--plugin qt --output appimage`；linuxdeploy 使用真实 Qt5 `qmake` / `qmlimportscanner` 生成 Qt hook、顶层入口和 `AppRun.wrapped`。
4. linuxdeploy 生成的 AppImage 只作为中间产物。
5. 最终从同一个 `AppDir` 使用官方 appimagetool 和官方 Type 2 runtime 重新封装 `dist/xnviewmp.AppImage`。

脚本中的检查只用于构建输入、官方摘要和最终产物的必要错误处理；正式脚本与工作流不提交 GUI smoke test、媒体样例生成或解包测试代码。

## 运行

```bash
./xnviewmp.AppImage
```

## 变更记录

### 2026-09-20：统一 linuxdeploy 与最终封装流程

改为动态解析官方最新稳定版；补齐两阶段 linuxdeploy、Qt5 `QMAKE`、真实 `AppRun`、Qt hook/`AppRun.wrapped` 及 appimagetool + Type 2 runtime 最终封装，并移除正式提交中的 smoke/test 代码。

### 2026-09-20：修复 XnView 入口布局、中文环境与 AppDir 路径

Actions Job `106070682762` 已成功完成打包；用户实际解包和运行确认 Qt hook、`AppRun.wrapped` 与中文输入法可用，同时发现界面语言退回英文。最终 AppDir 实际包含 `usr/bin`、`usr/lib`、`usr/plugins`、`usr/qml`、`usr/translations` 和 `usr/share`。根 AppRun 因此恢复 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并把这些 linuxdeploy 生成目录加入对应搜索路径。

两次 linuxdeploy 调用移除 `--executable AppDir/opt/XnView/XnView`：该参数会把上游位于 `/opt/XnView` 的主程序额外部署成 `AppDir/usr/bin/XnView`，不属于原始包布局。脚本不创建、不依赖该副本，根 AppRun 始终直接执行 `AppDir/opt/XnView/XnView`。

### 2026-09-20：补齐 Qt5 Declarative 与 QML 打包工具

Actions Job `106069546113` 在 Qt 插件的 QML 阶段调用 `/usr/bin/qmlimportscanner`，因 qtchooser 没有选中 Qt installation 而退出。构建脚本补装 Qt5 qmake、Declarative 开发工具、`qmlimportscanner` 和常用 Qt Quick/QML 模块，并把 `PATH`、`QT_SELECT`、`QMAKE` 明确绑定到 `/usr/lib/qt5/bin`。本次仅完成脚本语法和远端 diff 核对，提交后未监控 Actions，实际构建结果未验证。
