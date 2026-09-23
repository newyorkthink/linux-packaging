# RustDesk AppImage

## 来源和构建

`build_rustdesk.sh` 从 [RustDesk 官方正式 Release](https://github.com/rustdesk/rustdesk/releases)动态取得 x86_64 AppImage 及其发布摘要；保留官方运行目录和原来的 ELF `AppRun`，使用官方 appimagetool 封装为 `dist/rustdesk.AppImage`。构建脚本在 Arch CI 容器运行，最终软件版本写入 `dist/version.txt`。

## 2026-09-23：tty 显示服务器误判

用户提供的 1.4.9 官方 AppImage 截图显示 GUI 提示“当前显示服务器 tty 不支持，请切换到 X11”，终端日志没有明确缺库错误。RustDesk 对应版本源码的 `hbb_common` 支持 `RUSTDESK_FORCED_DISPLAY_SERVER`。新 `AppRun` 只在 `DISPLAY` 存在、`XDG_SESSION_TYPE=tty` 且没有 `WAYLAND_DISPLAY` 时指定 `x11`，然后执行未经修改的官方启动器；其他会话按官方原样运行。该修复不能给纯 tty 创建 X11 桌面。构建和用户桌面实际效果尚未验证。

用户现有 `runimage/setup_general_env.sh` 没有改动。
