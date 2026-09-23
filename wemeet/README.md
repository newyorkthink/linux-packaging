# 腾讯会议 AppImage

## 上游与构建

`build_wemeet.sh` 从 [腾讯会议官网](https://meeting.tencent.com/download/)的 Linux x86_64 官方接口读取当前正式 DEB 版本和 CDN 地址。`wemeet-bin` 的 AUR 配方仅供核对上游，不使用第三方二进制。公共下载入口核对 DEB 的包名、版本和架构。

脚本保留官方 `opt/wemeet` 目录、Qt 插件、图标和其他资源，使用 quick-sharun 补齐外部依赖并生成 `dist/wemeet.AppImage` 与 `dist/version.txt`。默认直接执行官方 `bin/wemeetapp`。构建及用户桌面启动效果尚未经 CI 和实际 GUI 确认。

## 2026-09-23 检查记录

已核对官网当前 DEB 的 `Package: wemeet`、`Architecture: amd64`，官方主程序、插件和桌面入口均在包内。用户目前通过 `runimage/setup_general_env.sh` 启动；此脚本和现有环境没有修改。
