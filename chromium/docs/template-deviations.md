# Chromium 模板差异

[正式构建脚本](../build_chromium.sh)由[已有完整程序目录模板](../../templates/quick-sharun/electron-installed.sh)生成。应用专项配置通过模板参数传入。

## 生成参数

| 阶段 | Chromium 参数及依据 |
| --- | --- |
| 程序及资源 | 使用 Arch `[extra]` 官方 `chromium` 包。`/usr/bin/chromium` 是启动器，安装目录为 `/usr/lib/chromium`。模板完整复制该目录，并指定 `MAIN_BIN=chromium`。 |
| Qt6 shim | 显式安装 `qt6-base`，解决 `libqt6_shim.so` 扫描时找不到 `libQt6Core.so.6`、`libQt6Gui.so.6` 和 `libQt6Widgets.so.6` 的问题。 |
| GTK3 输入 | `SCAN_ARGS` 包含 `AppDir/bin/*`、`im-ibus.so` 和 `im-fcitx5.so`。输入模块依赖为 `ibus` 和 `fcitx5-gtk`。 |
| 桌面与版本 | 使用系统的 `chromium.desktop` 和 hicolor 256×256 图标。版本从实际安装的软件包读取，发布版本写入 `dist/version.txt`。 |

## 专属处理

生成器通过 `QUICK_SHARUN_OPTIONS` 在 GTK 部署配置后、读取版本和收集依赖前输出以下三项。固定取值和旧版依据见[固定配置](./hardcoded.md)。

| 配置 | 用途与依据 |
| --- | --- |
| `DEPLOY_OPENGL=1` | 采用 [旧版脚本](https://github.com/newyorkthink/linux-packaging/blob/d93ce1379e509cbcfe7d64b188bd6e226fe4dac8/chromium/build_chromium_old.sh#L40) 的设置，显式部署 OpenGL 运行依赖。 |
| `URUNTIME_PRELOAD=1` | 保持多进程 Chromium 使用的 AppImage 挂载点，依据见 [旧版修复记录](../README.md#2026-09-06补充-chromium-多进程-appimage-挂载保持)。 |
| `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'` | 构建期对实际主程序探测动态加载的依赖。空白页用于离线探测，沙箱参数仅用于这次临时进程。依据见[旧版启动修复](../README.md#2026-09-06修复-appimage-启动立即退出)。 |
