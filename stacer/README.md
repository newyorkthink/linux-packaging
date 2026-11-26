# Stacer AppImage

## 用途与产物

本目录将 [QuentiumYT/Stacer](https://github.com/QuentiumYT/Stacer) 官方 Linux 系统优化与监控工具重新封装为可分发 AppImage。

- 上游项目：Stacer（Linux System Optimizer and Monitoring）
- 软件来源：AUR `stacer`（从官方 GitHub 源码按当前稳定 tag 编译，对应当前 Arch Qt6）
- 架构：x86_64
- 稳定产物：`dist/stacer.AppImage`
- 构建入口：`build_stacer.sh`
- CI 入口：`.github/workflows/build.yml`（清单 key：`stacer`）

Stacer 提供仪表盘、进程、服务、启动项、系统清理、卸载器和资源监控等功能。服务/软件包管理会按上游逻辑调用宿主上的 `systemctl` 等命令，不在 AppImage 内再打一份 systemd。

本目录打包的是 **Stacer**，与仓库中的 `stacher`（视频下载器）不是同一个应用。

## 技术栈

Stacer 是 C++17 / Qt6 原生 Linux 桌面程序，核心依赖：

- `qt6-base`、`qt6-charts`、`qt6-svg`
- 官方 desktop：`/usr/share/applications/stacer.desktop`
- 官方图标：`/usr/share/icons/hicolor/scalable/apps/stacer.svg`
- 翻译：`/usr/share/stacer/translations`（`stacer_*.qm`）
- Fcitx5 中文输入使用与主程序相同 Qt 主版本的 `fcitx5-qt` 平台输入上下文插件；AppImage 不内置 Fcitx5 守护进程

官方 GitHub Release 的 AppImage / deb / rpm 由上游 CI 在 **Ubuntu 22.04 (jammy)** 上用 `probonopd/go-appimage` 的 `appimagetool -s deploy` 生成。该 deploy 会把构建环境的 glibc 打进 AppImage。jammy 的 glibc 是 2.35，不提供 `GLIBC_2.38`。

## 打包方式

不采用“官方 AppImage 原样同步”。官方 jammy AppImage 已确认会把旧 glibc 打进包内，在继承了更新共享库的环境中会直接无法启动。

当前路线是仓库标准 Arch Linux + `quick-sharun`，构建脚本已对齐 [qt-installed.sh](../templates/quick-sharun/qt-installed.sh)，专属差异与依赖覆盖见 [模板差异说明](./docs/template-deviations.md)：

1. 通过 `common/arch/install_packages.sh --base` 安装统一打包基础包，再经公共入口安装 AUR `stacer` 以及 Qt6 输入与主题插件（`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`），并由 `common/build/prepare_x86_64_workspace.sh` 清理工作区。
2. 设置 `DEPLOY_QT=1` 与 `STARTUPWMCLASS="stacer"`，通过 `common/build/read_app_version.sh` 读取本次实际安装的 `stacer` 版本。
3. 将 `/usr/bin/stacer` 与 `/usr/share/stacer` 交给 `quick-sharun` 收集依赖和翻译，按模板生成包内中文 locale。
4. 按上游查找顺序，校验 `AppDir/share/stacer/translations` 并将翻译目录链接到主程序同级的 `translations/`，对应 `applicationDirPath()/translations` 回退路径。
5. `quick-sharun --make-appimage` 生成稳定文件名 `dist/stacer.AppImage`，成功后经 `common/build/save_appimage_version.sh` 校验产物并写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=stacer` 接入统一 `software_versions.json`。

## 运行与兼容说明

在当前目录执行：

```bash
./stacer.AppImage
```

本地构建目录中的产物是：

```bash
./dist/stacer.AppImage
```

兼容说明：

- 这是系统优化工具，进程、服务、启动项、清理等功能操作的是**宿主系统**，不是 AppImage 内部的假环境。需要提权的操作走上游原有的 polkit / 系统授权流程，本打包不额外包装 `sudo`。
- `quick-sharun` / uruntime 自带与应用匹配的运行库，不依赖宿主提供 `GLIBC_2.38`，也不再混用父进程 AppImage 漏出的共享库与一份更旧的捆绑 glibc。
- 上游把 `/usr/share/stacer/translations` 写成宿主绝对路径，优先于 AppImage 内翻译。若宿主自己安装了另一份 Stacer 翻译目录，界面语言会跟那份宿主目录走；未安装时使用包内 `applicationDirPath()/translations`。
- Debian / Ubuntu 专属的 APT 源管理等功能在非 Debian 宿主上按上游原样不可用，不是本打包引入的回归。

## 修复记录

### 2026-11-27：按标准模板重写 `build_stacer.sh`

- 核实 `pkgforge-dev` 无 `stacer` 仓库，继续沿用 AUR `stacer`（Qt6）来源以避开官方 jammy AppImage 的旧 glibc 2.35。
- 按 [qt-installed.sh](../templates/quick-sharun/qt-installed.sh) 重写 [build_stacer.sh](./build_stacer.sh)，统一接入公共安装、工作区与版本脚本，补齐 Qt6 主题插件（`qt6ct`、`kvantum`、`lxqt-qtplugin`）、`DEPLOY_QT=1` 与包内中文 locale，保留 `STARTUPWMCLASS="stacer"` 及翻译目录收集、软链接与存在性检查，并新增 [模板差异说明](./docs/template-deviations.md)。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-17：检查关闭窗口黑屏是否由打包链引起

- **检查对象：** `stacer` 当前构建脚本（接入提交 `ca34fec`）及 `latest` Release 中的 `stacer.AppImage` 1.8.0。
- **问题现象：** Linux 实机更新后仪表盘和设置可正常打开，原先 `GLIBC_2.38` 无法启动已经消失。关闭窗口后客户区变成与 Stacer 深色主题相同的空窗，窗口管理器仍把 `stacer` 列为焦点；约 10 秒后窗口才真正退出。
- **检查范围：** 上游关闭逻辑；本仓库同类 Qt6 GUI 的打包路线；是否应改成 `linuxdeploy --appdir AppDir --plugin qt --output appimage`。
- **证据来源：** 上游 `stacer/app.cpp` 的 `closeEvent`；仪表盘 `checkUpdate()` 请求 `https://api.github.com/repos/QuentiumYT/Stacer/releases/latest`；启动时的 `QIODevice::read (QSslSocket): device not open`；实机约 10 秒后自行退出的运行反馈。
- **已确认结论：** 关窗卡住不是缺少 `linuxdeploy --plugin qt`。同类从 Arch 安装的 Qt6 GUI 在本仓库走 quick-sharun。上游在“不再询问”且选择 `close` 时，GUI 线程先 `QThreadPool::waitForDone()`（无超时）再 `QApplication::quit()`。等待期间界面不再刷新，所以看起来像黑屏卡住，线程池任务结束后窗口才会消失。仪表盘启动就会发 GitHub 更新检查，TLS 读写失败时常见约 10 秒才返回。`linuxdeploy --output appimage` 不得作为本仓库最终封装方式，也不改这条上游关闭逻辑。
- **是否建议修改：** 否。保持 Arch + quick-sharun，不改程序关闭逻辑，不改成 linuxdeploy Qt plugin。

### 2026-09-17：接入本仓库并避开官方 jammy AppImage 的旧 glibc

- **现象：** 运行官方 Stacer AppImage 时立即退出，报 `version 'GLIBC_2.38' not found`。动态链接器实际加载的是 Stacer AppImage 自带的 `libc.so.6`，而 `GLIBC_2.38` 符号来自另一个已挂载 AppImage 中的 `libxkbcommon.so.0` / `libbsd.so.0`。
- **根因：** 上游正式 AppImage 在 Ubuntu 22.04 (jammy) 上使用 go-appimage `appimagetool -s deploy`，会把 jammy 的 glibc 2.35 打进包内。子进程若继承了其他 AppImage 的库搜索路径，就会拿新库去链这份旧 libc，从而找不到 `GLIBC_2.38`。官方源码仓库本身能在 Ubuntu 22.04 / 24.04 上成功出包，问题出在这份 jammy AppImage 的运行库组合，而不是 Stacer 程序逻辑。
- **修改文件：** 新增 `stacer/build_stacer.sh`、`stacer/README.md`，并在 `.github/appimage-apps.json` 增加标准应用 `stacer`。
- **修复内容：** 不同步官方 AppImage。改为在 Arch Linux 上从官方源码安装当前稳定 Stacer，用 `quick-sharun` 收集与二进制匹配的 Qt6 / glibc / 输入上下文，并补上翻译目录链接。
- **已知结果：** 已提交正式构建入口，未监控 GitHub Actions。

## 实机验证

### 2026-11-27：用户实机验证通过

用户已确认 Stacer 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 仪表盘启动与中文界面 | 正常启动并显示简体中文仪表盘，实时展示 CPU、内存、磁盘、系统信息与网络收发面板。 |
| 页面切换与中文输入 | 搜索页正常打开，搜索框支持中文输入法正常输入。 |
