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
2. 第一阶段完成后，脚本写入项目真实的根 `AppDir/AppRun`。
3. 设置 Qt5 的 `export QMAKE=/usr/bin/qmake`，再执行 `--plugin qt --output appimage`；linuxdeploy 据此生成 Qt hook、顶层入口和 `AppRun.wrapped`。
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
