# 腾讯会议 AppImage

## 上游与构建

`build_wemeet.sh` 从 [腾讯会议官网](https://meeting.tencent.com/download/)的 Linux x86_64 官方接口读取当前正式 DEB 版本和 CDN 地址。`wemeet-bin` 的 AUR 配方仅供核对上游，不使用第三方二进制。公共下载入口核对 DEB 的包名、版本和架构。

脚本保留官方 `opt/wemeet` 目录、Qt 5.15.8 插件、图标和其他资源，在 Ubuntu 24.04 使用 linuxdeploy Qt 插件整理依赖，再由 appimagetool 与官方 Type 2 runtime 生成 `dist/wemeet.AppImage` 和 `dist/version.txt`。根 `AppRun` 直接启动真实程序 `opt/wemeet/bin/wemeetapp`，并保留官方启动脚本的语言、时区、Wayland 回退、私有库及 Qt 插件环境。新路线成品尚待 Linux 实机确认。

## 2026-09-23 检查记录

已核对官网当前 DEB 的 `Package: wemeet`、`Architecture: amd64`，官方主程序、插件和桌面入口均在包内。用户目前通过 `runimage/setup_general_env.sh` 启动；此脚本和现有环境没有修改。

## 2026-09-23：首次 CI 构建失败

首次 CI 在 DEB 包身份校验时报 `dpkg-deb: command not found`。Arch 构建容器没有预装 `dpkg`；构建脚本现通过公共 Arch 安装入口安装 `dpkg`，再使用原有公共下载和解包入口。后续构建结果待确认。

第二轮 CI 已进入 quick-sharun 封装阶段；图标路径在 AppDir 内导致重复复制而退出，现改为从 AppDir 外提供图标与 desktop。第三轮 CI 提示 `Main binary is set to 'wemeet', but this file is NOT present`，官方下载的实际程序名为 `wemeetapp`；现已同步修正 `MAIN_BIN` 和桌面入口，后续构建待确认。

## 2026-09-23：运行时缺少 libwemeet.so

Linux 实机运行报 `libwemeet.so: cannot open shared object file`。已检查官网当前 DEB，`libwemeet.so` 位于 `opt/wemeet/lib/`，原脚本也保留该目录；问题在于自写 `AppRun.sh` 最后直接执行 `opt/wemeet/bin/wemeetapp`，绕过 sharun 的库加载器。`build_wemeet.sh` 删除自写入口，改由 quick-sharun 原生 `AppRun` 启动包装器，并通过 `.env` 提供私有库、工作目录及 Qt 插件路径。新构建及实机启动尚未验证。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `README.md` 的「当前待处理」，未改写。

- `rustdesk` / `wemeet`：2026-09-23 实机分别报告 `APPRUN ERROR: Unable to open file: (null)` 和缺少 `libwemeet.so`。启动入口已按实际打包方式调整，新产物运行待确认，详见 [RustDesk](../rustdesk/README.md) 和 [腾讯会议](../wemeet/README.md)。

## 2026-09-24：最新版启动后立即退出

Linux 实机运行当前 Release 的 `wemeet.AppImage` 时，仅打印 `wemeet:WemeetSatrt` 随即返回，未出现 GUI。该行是腾讯会议的启动日志，单独不能定位退出原因。本次核对的官网 DEB 为 `3.26.10.401`，其中官方 `wemeetapp.sh` 会设置程序目录、私有库、Qt 插件、语言和时区；当前 AppImage 使用 quick-sharun 的 `AppRun` 启动 `wemeetapp`，没有直接执行该脚本。

解包当前 Release 后发现 `AppDir/.env` 只剩构建脚本写入的五行，而产物含有 `cross-libc-dlopen.so`；quick-sharun 源码在部署该库时会向已有 `.env` 追加 `CROSS_LIBC_DLOPEN_ROOT=${SHARUN_DIR}`。原因是 `build_wemeet.sh` 在第一次 quick-sharun 调用后用 `cat >` 覆盖了 `.env`。本次改为 `cat >>`，保留 quick-sharun 生成的环境，并维持已有私有库、工作目录及 Qt 插件配置。当前仓库没有可对照的旧版 linuxdeploy 构建记录，本次不切换打包路线。

已通过官方 DEB 与现有 Release 的静态检查确认上述覆盖问题；修改后的 GitHub Actions 构建和 Linux 实机启动尚未验证。若新产物仍直接退出，再结合其完整运行日志核对官方启动脚本中的其余环境和 Qt 资源路径，不把 `WemeetSatrt` 当作根因。

## 2026-09-24：弃用 quick-sharun，迁移 linuxdeploy

追加 `CROSS_LIBC_DLOPEN_ROOT` 后生成的新 Release 在 Kali Linux i3wm 实机仍只打印 `wemeet:WemeetSatrt`，随后立即返回。下载同一 Release 资产并使用 `APPIMAGE_EXTRACT_AND_RUN=1` 在隔离环境复现后，调试日志确认修正后的 `.env` 已包含 `CROSS_LIBC_DLOPEN_ROOT`，程序成功加载到官方 `plugins/platforms/libqxcb.so`，随后由 quick-sharun 的 `cross-libc-dlopen.so` 路径结束为 `Aborted`。因此，覆盖 `.env` 只是已修复的独立问题，不是本次启动退出的最终根因。

本次不再继续修补 quick-sharun 路线，改为仓库统一的两阶段 linuxdeploy 流程：Ubuntu 24.04 首次初始化空 AppDir，安装并解包同一官方 DEB，第二次使用 Qt5 插件扫描，最后由 appimagetool 和官方 Type 2 runtime 封装正式资产。Wemeet 同步从 Arch 标准 matrix 改为 Ubuntu 24.04 独立 Job，避免混用发行版工具链。

新的根 `AppRun` 不调用上游使用 `$*` 传参的二级包装脚本，而是按其有效逻辑设置 `LC_ALL`、`TZ`、`PATH`、`LD_LIBRARY_PATH`、`QT_PLUGIN_PATH` 及 Wayland 回退，再用 `"$@"` 直接执行真实主程序。首次成品仍保留公共路径整理调用；待用户确认 GUI、登录、音视频和中文输入正常后，再依据最终 Release 解包结果固化 AppRun 路径。
