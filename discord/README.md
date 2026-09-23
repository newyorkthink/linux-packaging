# Discord AppImage

## 来源与构建

`build_discord.sh` 从 [Discord 官网](https://discord.com/download)下载 stable Linux tar.gz。2026-09-23 获取的官网归档只有约 2 MB：其中 `discord` 是调用 `updater_bootstrap` 的 Shell 入口，不是完整程序。因此构建阶段调用官方 bootstrap 下载完整 stable 程序，确认其 `Discord` 可执行文件存在后，再使用 quick-sharun 封装 `dist/discord.AppImage` 和 `dist/version.txt`。

不运行官方 `postinst.sh`，不修改宿主机 AppArmor、服务或用户配置。官方安装器下载需要访问 `updates.discord.com`；构建环境无法连接时构建会失败，不会发布只有安装器的假 AppImage。实际 CI 构建与桌面启动尚未验证。
