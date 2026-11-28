# RustDesk 固定配置

## 包内 X11 会话类型

- 构建时通过[专属处理](../build_rustdesk.sh#L30-L32)将官方 `AppRun.env` 中的 `XDG_SESSION_TYPE` 设为 `x11`。保留读取该文件的官方 ELF `AppRun`，设置只写入包内。
- 依据是官方 AppImage 在 X11 桌面误判会话为 `tty`，以及[后续实机确认](../README.md#2026-09-23x11-主机端实机确认)启动提示消失、手机可以连接主机。
- 此产物面向 X11。Wayland 的使用说明见[RustDesk 官方文档](https://rustdesk.com/docs/en/client/linux/#x11-required)。
