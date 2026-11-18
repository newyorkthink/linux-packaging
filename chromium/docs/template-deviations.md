# Chromium 模板差异

[正式构建脚本](../build_chromium.sh)由[已有完整程序目录模板](../../templates/quick-sharun/electron-installed.sh)生成。应用专项配置通过模板参数传入。

## 生成参数

| 阶段 | Chromium 参数及依据 |
| --- | --- |
| 程序及资源 | 使用 Arch `[extra]` 官方 `chromium` 包。`/usr/bin/chromium` 是启动器，安装目录为 `/usr/lib/chromium`。模板完整复制该目录，并指定 `MAIN_BIN=chromium`。 |
| Qt6 shim | 显式安装 `qt6-base`，解决 `libqt6_shim.so` 扫描时找不到 `libQt6Core.so.6`、`libQt6Gui.so.6` 和 `libQt6Widgets.so.6` 的问题。 |
| GTK3 输入 | `SCAN_ARGS` 包含 `AppDir/bin/*`、`im-ibus.so` 和 `im-fcitx5.so`。输入模块依赖为 `ibus` 和 `fcitx5-gtk`。 |
| 桌面与版本 | 使用系统的 `chromium.desktop` 和 hicolor 256×256 图标。版本从实际安装的软件包读取，发布版本写入 `dist/version.txt`。 |

## 旧版专项记录

以下处理可在[重写前的构建脚本](../build_chromium_old.sh)和 [README 的修复记录](../README.md#修复记录)中查阅。正式脚本使用生成器输出。

| 旧版处理 | 用途 |
| --- | --- |
| `URUNTIME_PRELOAD=1` | 保持多进程浏览器使用的 AppImage 挂载点。 |
| `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'` | 构建时对浏览器主程序探测动态加载的依赖。 |
| `DEPLOY_OPENGL=1` | 显式启用 OpenGL 部署。 |
| `LANGUAGE=zh-CN` | 修复旧版 UI 继承宿主英文的问题。当前模板生成包内中文 locale。 |
| desktop 暂存与 `chromium --version` | 旧版写入 `~/version` 和 desktop 的 `X-AppImage-Version`。 |
