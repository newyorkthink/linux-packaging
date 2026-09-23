# 腾讯会议 AppImage

## 上游与构建

`build_wemeet.sh` 从 [腾讯会议官网](https://meeting.tencent.com/download/)的 Linux x86_64 官方接口读取当前正式 DEB 版本和 CDN 地址。`wemeet-bin` 的 AUR 配方仅供核对上游，不使用第三方二进制。公共下载入口核对 DEB 的包名、版本和架构。

脚本保留官方 `opt/wemeet` 目录、Qt 插件、图标和其他资源，使用 quick-sharun 补齐外部依赖并生成 `dist/wemeet.AppImage` 与 `dist/version.txt`。由 sharun 自带的 `AppRun` 启动 `wemeetapp` 包装器，`.env` 指向官方私有库和插件目录。修改后的用户桌面启动效果尚待确认。

## 2026-09-23 检查记录

已核对官网当前 DEB 的 `Package: wemeet`、`Architecture: amd64`，官方主程序、插件和桌面入口均在包内。用户目前通过 `runimage/setup_general_env.sh` 启动；此脚本和现有环境没有修改。

## 2026-09-23：首次 CI 构建失败

首次 CI 在 DEB 包身份校验时报 `dpkg-deb: command not found`。Arch 构建容器没有预装 `dpkg`；构建脚本现通过公共 Arch 安装入口安装 `dpkg`，再使用原有公共下载和解包入口。后续构建结果待确认。

第二轮 CI 已进入 quick-sharun 封装阶段；图标路径在 AppDir 内导致重复复制而退出，现改为从 AppDir 外提供图标与 desktop。第三轮 CI 提示 `Main binary is set to 'wemeet', but this file is NOT present`，官方下载的实际程序名为 `wemeetapp`；现已同步修正 `MAIN_BIN` 和桌面入口，后续构建待确认。

## 2026-09-23：运行时缺少 libwemeet.so

Linux 实机运行报 `libwemeet.so: cannot open shared object file`。已检查官网当前 DEB，`libwemeet.so` 位于 `opt/wemeet/lib/`，原脚本也保留该目录；问题在于自写 `AppRun.sh` 最后直接执行 `opt/wemeet/bin/wemeetapp`，绕过 sharun 的库加载器。`build_wemeet.sh` 删除自写入口，改由 quick-sharun 原生 `AppRun` 启动包装器，并通过 `.env` 提供私有库、工作目录及 Qt 插件路径。新构建及实机启动尚未验证。
