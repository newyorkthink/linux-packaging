# Falkon AppImage

Falkon 是基于 Qt 6 和 Qt WebEngine 的 KDE 浏览器。此目录用于准备 Linux x86_64 的 `falkon.AppImage`。程序来源为 [Arch Linux Extra 的 Falkon 软件包](https://archlinux.org/packages/extra/x86_64/falkon/)。

## 打包方式

- 按[从系统真实入口收集](../docs/packaging-classification.md#从系统真实入口收集)的方式使用 [Qt 6 系统入口模板](../templates/quick-sharun/qt-installed.sh)。
- 使用 [Generate build script](../.github/workflows/generate-build-script.yml) 生成 `falkon/build_falkon.sh`。模板通过公共入口安装软件包及其依赖，并读取实际安装版本。
- quick-sharun 从 `/usr/bin/falkon` 收集程序和依赖，使用同一软件包的桌面入口和图标。Qt WebEngine 的辅助进程与资源使用 quick-sharun 的自动部署逻辑。

## 当前状态

当前处于构建脚本生成准备阶段。AppImage 的构建和运行尚待验证，运行验收目标为 Ubuntu 24.04 x86_64 上的普通用户 X11 图形会话，检查窗口启动、HTTPS 和 JavaScript 页面加载及 Qt WebEngine 沙箱。
