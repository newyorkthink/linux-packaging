# JRiver Media Center AppImage

本目录用于构建 **JRiver Media Center Linux AppImage**。

> **当前正式入口（2026-09-13）：** `build_jriver.sh` 使用 **RunImage + quick-sharun**；新路线的流程、Actions 故障与修复记录已独立迁移至 [README_runimage_quick.md](./README_runimage_quick.md)。本 README 第 1～13 节只保留旧版稳定路线及实机历史。

> **当前维护状态（2026-09-12）：** Kali Linux 实机已确认最新 `jriver.AppImage` 可以正常启动并显示 JRiver Media Center GUI，2026-09-11 的“进程启动但无可见 GUI”状态已被新的实机结果覆盖。当前新增已知问题：进入 **影院模式** 后，使用鼠标点击界面会卡住。构建兼容层、现有 CEF、网页音频、Fcitx5 和 glibc 隔离链本轮不再改动；详见第 13 节。下方历史记录继续保留。

> **2026-08-14：当前版本正式冻结为“最终可用稳定基线”。**
>
> 核心功能已经可用，但 **“文件 → 打开媒体文件 / 打开文件夹”仍会导致 JRiver/JRWeb 相关进程异常退出或当前实例闪退**。经过多轮最小补丁和 Kali Linux 实机验证后，没有拿到足以安全定位根因的 crash stack；因此停止继续根据 warning 猜测式修改。
