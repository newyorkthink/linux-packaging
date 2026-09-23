# RustDesk AppImage

## 来源和构建

`build_rustdesk.sh` 从 [RustDesk 官方正式 Release](https://github.com/rustdesk/rustdesk/releases)动态取得 x86_64 AppImage 及其发布摘要；保留官方运行目录和原来的 ELF `AppRun`，在 `AppRun.env` 中设置 X11 会话类型，使用官方 appimagetool 封装为 `dist/rustdesk.AppImage`。构建脚本在 Arch CI 容器运行，最终软件版本写入 `dist/version.txt`。

## 2026-09-23：tty 显示服务器误判

用户提供的 1.4.9 官方 AppImage 截图显示 GUI 提示“当前显示服务器 tty 不支持，请切换到 X11”，终端日志没有明确缺库错误。RustDesk 对应版本源码的 `hbb_common` 支持 `RUSTDESK_FORCED_DISPLAY_SERVER`。新 `AppRun` 只在 `DISPLAY` 存在、`XDG_SESSION_TYPE=tty` 且没有 `WAYLAND_DISPLAY` 时指定 `x11`，然后执行未经修改的官方启动器；其他会话按官方原样运行。该修复不能给纯 tty 创建 X11 桌面。构建和用户桌面实际效果尚未验证。

用户现有 `runimage/setup_general_env.sh` 没有改动。

上述“新 `AppRun`”方案已被后续 Linux 实机结果否定，见下文记录。

## 2026-09-23：首次 CI 构建失败

首次 CI 在解包步骤报 `Permission denied`：公共下载入口保存官方 AppImage 时没有执行权限。公共解包脚本在调用官方 `--appimage-extract` 前为下载文件设置可执行位；后续构建结果待确认。

## 2026-09-23：恢复官方 ELF AppRun

Linux 实机运行重封装产物报 `APPRUN ERROR: Unable to open file: (null)`。先前把官方 ELF `AppRun` 移到 `AppRun.official` 并以 shell 脚本转发的方案已被实机否定；ELF 也不能像 shell 脚本一样直接插入环境变量语句。`build_rustdesk.sh` 现原样保留官方 `AppRun`，只重封装官方目录。原来的 tty 误判仍需单独核对；新构建和实机运行尚未验证。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `README.md` 的「当前待处理」，未改写。

- `rustdesk` / `wemeet`：2026-09-23 实机分别报告 `APPRUN ERROR: Unable to open file: (null)` 和缺少 `libwemeet.so`。启动入口已按实际打包方式调整，新产物运行待确认，详见 [RustDesk](../rustdesk/README.md) 和 [腾讯会议](../wemeet/README.md)。

## 2026-09-23：在官方 AppRun.env 中设置 X11 会话

新截图仍显示“当前显示服务器 tty 不支持，请切换到 x11”；此前记录的 `export XDG_SESSION_TYPE=x11` 是该 X11 桌面会话的处理方式。上游 AppImage 的 ELF `AppRun` 读取 `AppRun.env` 并启动程序；因此 `build_rustdesk.sh` 保留 ELF 文件及其原有环境配置，仅替换 `AppRun.env` 中的 `XDG_SESSION_TYPE` 条目为 `x11`，不再移动或包装 ELF 入口，也不修改宿主会话。这个封装产物面向 X11；Wayland 会话不应使用该强制设置。此次按要求不进行构建、测试或实机验证，实际效果待用户后续运行反馈。
