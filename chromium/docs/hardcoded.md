# Chromium 固定配置

本页登记正式构建通过 `QUICK_SHARUN_OPTIONS` 启用的专项取值。 [正式构建脚本](../build_chromium.sh)

| 固定取值 | 设置原因及作用 | 依据 |
| --- | --- | --- |
| `DEPLOY_OPENGL=1` | 显式部署 OpenGL 运行依赖。 | [正式构建脚本](../build_chromium.sh) |
| `URUNTIME_PRELOAD=1` | 保持 AppImage 挂载点，供多进程浏览器继续访问包内文件。 | [旧版修复记录](../README.md#2026-09-06补充-chromium-多进程-appimage-挂载保持) · [PkgForge Chrome 打包配置](https://github.com/pkgforge-dev/Chrome-AppImage/blob/1414e57841c196ac9e610a8836fd994b76602963/make-appimage.sh#L25) |
| `STRACE_BINARY=chromium`、`STRACE_FLAGS='about:blank --no-sandbox'` | 只在打包时启动真实主程序并探测动态加载的依赖。空白页无需联网，探测参数由构建容器中的临时进程使用。 | [旧版启动故障与修复](../README.md#2026-09-06修复-appimage-启动立即退出) |
