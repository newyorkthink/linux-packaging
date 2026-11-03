# Xephyr 模板差异

[构建脚本](../build_xephyr.sh)采用 [Arch 官方仓库原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准)。从已安装的 Arch 包直接收集 `/usr/bin/Xephyr` 和 `/usr/bin/xkbcomp`，版本在收集前经公共入口读取，产物成功封装后保存版本。

| 专属处理 | 位置与依据 | 作用 |
| --- | --- | --- |
| 临时桌面入口 | 导出 `DESKTOP` 前生成。Arch Xephyr 包没有桌面入口或图标，图标继续取自已安装的 Adwaita 主题。 | 向封装工具提供 desktop 和图标，临时目录随构建脚本退出清理。 |
| 关闭启动跟踪 | 收集前沿用 `STRACE_MODE=0`。构建环境没有供 Xephyr 连接的外层 X 显示。 | 依赖收集阶段跳过启动跟踪。 |
| XKB 路径映射 | 收集前保留 `PATH_MAPPING` 的两项原有映射。 | 让 Xephyr 使用包内的 xkbcomp 和键盘规则。 |
| 键盘规则与许可证 | 收集后、封装前复制。XKB 来源路径可能是符号链接，沿用 `cp -aL` 复制实际内容。 | 键盘规则及三个相关软件包的许可证随 AppImage 分发。 |

本轮按 Xephyr 和 xorg-server 名称检索 pkgforge-dev，未找到对应打包仓库。程序入口来自 [Arch 官方包文件表](https://archlinux.org/packages/extra/x86_64/xorg-server-xephyr/files/)，专属处理沿用[整理前脚本](https://github.com/newyorkthink/linux-packaging/blob/84c4f4fcd3f98e7ab106488a01495236c80a58db/xephyr/build_xephyr.sh)。

Xephyr 是嵌套 X server。键盘布局由 XKB 提供，客户端的中文界面和输入法由客户端所在会话处理。本包继续使用 quick-sharun 生成的启动入口。固定值和验证边界见 [固定配置依据](./hardcoded.md)和 [README](../README.md#验证状态)。
