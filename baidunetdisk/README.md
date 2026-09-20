# 百度网盘 AppImage

本目录把百度网盘官方当前稳定版 Linux x86_64 DEB 重新封装为 `baidunetdisk.AppImage`。正式构建入口为 `.github/workflows/build.yml` 中独立的 `Build Baidu Netdisk` Job。

## 上游来源

- 构建脚本读取百度网盘官方 Linux 客户端接口中的 `linux.version` 和 `linux.url_1`，不再根据版本自行拼接 CDN 地址。
- 仅接受百度 HTTPS 域名、与版本一致的 `baidunetdisk_<版本>_amd64.deb`、`baidunetdisk` 包名和 `amd64` 架构。
- 官方接口当前没有提供 DEB 摘要；公共下载脚本负责 HTTPS、失败退出、重试、临时文件和输出本次下载文件的 SHA-256，不把本地计算值描述为上游校验。
- 保留官方 `/opt/baidunetdisk`、`resources/app.asar`、desktop、图标和 `--no-sandbox %U` 启动参数，不修改官方 `app.asar`。

## 技术栈与运行依赖

- 上游程序是 Electron/Chromium 应用，主 ELF 同时直接依赖 GTK3、GLib/GIO、NSS、X11、音频和图形运行库。
- 官方 DEB 的强依赖包含 `libgtkmm-2.4-1v5`，推荐依赖包含 `libappindicator3-1`；应用还会通过 Koffi 动态加载 GTKmm，因此第二次 linuxdeploy 使用精确 `-l` 参数补入 GTKmm 2.4 和 AppIndicator。
- `ibus-gtk3` 和 `libibus-1.0-5` 用于部署 GTK3 IBus 输入模块及运行库；不在 AppRun 中强制覆盖宿主会话的输入法环境变量。
- Ubuntu 22.04 的 Adwaita 图标和 GTK 主题资源直接解包进 AppDir。
- NSS 核心库及其动态模块保持来自同一套 Ubuntu 22.04 `libnss3`，避免 AppImage 内外 NSS 版本混用。

## linuxdeploy 规范流程

1. 通过 `common/linuxdeploy/prepare_linuxdeploy_tools.sh` 动态取得 linuxdeploy、官方 GTK 插件、appimagetool 和 Type 2 runtime。公共脚本校验官方 GTK 文件，并在上游仍遗漏时补入 GIO dynamic modules 复制逻辑。
2. 第一次在空目录执行 `export ARCH=x86_64; linuxdeploy --appdir AppDir --output appimage`，只接受基础目录已经创建、没有非预期文件且退出状态为 0 或 1 的初始化结果。
3. 从官方接口取得 DEB，安装同一文件到 Ubuntu 22.04 隔离构建环境供 linuxdeploy 解析依赖，并按上游布局解包到 AppDir。
4. 第二次 linuxdeploy 前写入完整根 `AppDir/AppRun`，保留 `usr/bin`、`usr/lib`、`usr/lib/x86_64-linux-gnu`、`usr/share` 等已确认路径，直接执行 `/opt/baidunetdisk/baidunetdisk --no-sandbox "$@"`，不再创建人工 `AppDir/usr/bin/baidunetdisk` 二次转发入口，也不切换工作目录。
5. 设置 `DEPLOY_GTK_VERSION=3`，执行带 GTK 插件、desktop、图标以及 GTKmm/AppIndicator 精确动态库的第二次 `linuxdeploy --output appimage`。linuxdeploy 检测到 GTK hook 后生成顶层 AppRun，并把完整启动逻辑保留到 `AppRun.wrapped`。
6. 最终 AppImage 已经解包确认目录，构建脚本直接保留准确 AppRun，不再调用公共路径整理脚本。
7. linuxdeploy 生成的 AppImage 只作为中间产物；正式 `dist/baidunetdisk.AppImage` 由官方 appimagetool 使用明确的 Type 2 runtime 对同一个 AppDir 重新封装。

## AppRun

当前根 AppRun 基于官方 8.7.0 DEB 的实际布局：

- `PATH`：`opt/baidunetdisk`、`usr/bin`；
- `LD_LIBRARY_PATH`：`opt/baidunetdisk`、`usr/lib`、`usr/lib/x86_64-linux-gnu`；
- `XDG_DATA_DIRS`：`usr/share`；
- `GSETTINGS_SCHEMA_DIR`：`usr/share/glib-2.0/schemas`；
- `GIO_MODULE_DIR`：`usr/lib/x86_64-linux-gnu/gio/modules`；
- 唯一入口：`opt/baidunetdisk/baidunetdisk --no-sandbox "$@"`。

最终 AppImage 已解包确认存在顶层 `AppRun`、`AppRun.wrapped`、GTK hook、空的 `usr/bin`、`usr/lib/x86_64-linux-gnu`、`usr/share` 和完整的 `opt/baidunetdisk`。以上路径已经固化；GUI、登录、托盘、上传下载、中文输入和文件关联仍需分别以实际运行结果为准。

## 版本与正式资产

- 最终 Release 资产名固定为 `baidunetdisk.AppImage`。
- 构建脚本使用本次实际下载 DEB 的 `VERSION` 写入 `dist/version.txt`。
- workflow 上传 `software-version-baidunetdisk`，并在成功构建后增量更新 `latest/software_versions.json`。
- 软件版本与最终文件 SHA-256 含义不同，不互相替代。

## 验证边界

- 已核对当前官方 8.7.0 DEB 的包名、版本、amd64 架构、`/opt/baidunetdisk` 主程序、`resources/app.asar`、desktop、图标、`$ORIGIN` RPATH 和包依赖声明。
- 已根据最终 AppImage 解包结果确认 AppRun 包装关系和实际目录，并固化 `usr/lib/x86_64-linux-gnu`；这项证据不等于 GUI 功能验证。
- 本次删除构建内的 Xvfb、两轮 smoke test、AppImage 自解包验证和批量 `ldd` 检查；不以无真实桌面的自动启动替代用户 GUI、登录、托盘、上传下载、中文输入和文件关联验证。
- 新链路提交前只进行 Shell 语法、ShellCheck、Markdown、workflow 关系和完整 diff 检查。最终 AppImage 的实际运行结果需由新产物验证后补充。

## 变更记录

### 2026-09-20：固化最终 AppRun

根据最终 AppImage 解包结果，把 `usr/lib/x86_64-linux-gnu` 固化到 `LD_LIBRARY_PATH`，删除不需要的工作目录切换，直接执行百度网盘真实入口；同时删除只供目录尚未确认时使用的 `normalize_apprun_paths.sh` 调用。以后以这份 AppRun 为稳定基线。

### 2026-09-20：迁移到公共 GTK linuxdeploy 两阶段流程

旧脚本自行拼接下载地址、仓库内固定一份 GTK 插件、直接解包 DEB、创建 `usr/bin/baidunetdisk` 二次 launcher，并把单次 linuxdeploy 输出直接作为正式资产。现已改为使用官方接口返回的实际 DEB URL、安装并解包同一文件、公共 GTK/GIO 工具入口、空 AppDir 初始化、完整根 AppRun、第二次 GTK linuxdeploy，以及官方 appimagetool + Type 2 runtime 最终封装。

保留已明确需要的 `--no-sandbox`、GTKmm 2.4、AppIndicator、Adwaita、IBus 和同版本 NSS 处理；删除仓库内固定 GTK 插件及构建内 Xvfb/smoke/test 逻辑。新产物尚未完成真实 GUI 验证，不把本次静态检查写成运行成功。

### 2026-09-16：接入统一软件版本元数据

- 构建脚本使用官方客户端接口得到的 `VERSION` 写入 `dist/version.txt`。
- 正式 workflow 接入统一版本清单。
