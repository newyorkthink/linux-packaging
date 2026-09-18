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

当前路线是仓库标准 Arch Linux + `quick-sharun`：

1. 安装 quick-sharun 所需最小基础工具，不预装 Qt / Fcitx / Mesa。
2. `yay -S stacer` 安装 AUR 当前稳定版；由包管理器按真实依赖拉入 Qt6 Charts / SVG 等运行时。应用版本不写死在仓库里。
3. 再单独安装 `fcitx5-qt`，为 Qt6 GUI 提供同主版本的 `platforminputcontexts` 插件。
4. 将 `/usr/bin/stacer` 与 `/usr/share/stacer` 交给 `quick-sharun` 收集依赖和翻译。
5. 按上游查找顺序，把翻译目录链接到主程序同级的 `translations/`，对应 `applicationDirPath()/translations` 回退路径。
6. `quick-sharun --make-appimage` 生成稳定文件名 `dist/stacer.AppImage`。
7. 从本次实际安装的 `stacer` 包解析上游版本，去掉 epoch / pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=stacer` 接入统一 `software_versions.json`。

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

### 2026-09-17：检查关闭窗口黑屏是否由打包链引起

- **检查对象：** `stacer` 当前构建脚本（接入提交 `ca34fec`）及 `latest` Release 中的 `stacer.AppImage` 1.8.0。
- **问题现象：** Linux 实机更新后仪表盘和设置可正常打开，原先 `GLIBC_2.38` 无法启动已经消失。关闭窗口后客户区变黑，窗口管理器仍把 `stacer` 列为焦点窗口。
- **检查范围：** 上游关闭逻辑；本仓库同类 Qt6 GUI 的打包路线；是否应改成 `linuxdeploy --appdir AppDir --plugin qt --output appimage`。
- **证据来源：** 上游 `stacer/app.cpp` 的 `closeEvent`；实机窗口仍映射的运行反馈；仓库对 quick-sharun / linuxdeploy 的既定规则；官方 jammy AppImage 已用 go-appimage deploy，正是旧 glibc 崩溃来源。
- **已确认结论：** 关窗黑屏不是缺少 `linuxdeploy --plugin qt`。同类从 Arch 安装的 Qt6 GUI 在本仓库走 quick-sharun。上游在“不再询问”为真时：`close` 先 `QThreadPool::waitForDone()` 再退出，`hide` 则 `event->ignore()` 并 `hide()` 到托盘。窗口仍在且发黑，符合进程未退、窗口仍映射，而不是 Qt plugin 没收集全。`linuxdeploy --output appimage` 不得作为本仓库最终封装方式；该命令也不改上游 `closeEvent`，还会丢掉 quick-sharun / uruntime 对父进程 AppImage 共享库的隔离，有机会把已修好的 glibc 混链再带回来。官方已经用过 deploy 式 Qt 捆绑，换回同类工具不能解释、也不能修关闭逻辑。
- **未确认事项：** 实机这次走的是 `hide` 还是卡住的 `waitForDone()`；窗口隐藏或销毁时合成器是否把 ARGB 窗口画成黑。二者都不改变“不是打包链选型错误”的结论。
- **是否建议修改：** 否。保持 Arch + quick-sharun，不改成 linuxdeploy Qt plugin。

### 2026-09-17：接入本仓库并避开官方 jammy AppImage 的旧 glibc

- **现象：** 运行官方 Stacer AppImage 时立即退出，报 `version 'GLIBC_2.38' not found`。动态链接器实际加载的是 Stacer AppImage 自带的 `libc.so.6`，而 `GLIBC_2.38` 符号来自另一个已挂载 AppImage 中的 `libxkbcommon.so.0` / `libbsd.so.0`。
- **根因：** 上游正式 AppImage 在 Ubuntu 22.04 (jammy) 上使用 go-appimage `appimagetool -s deploy`，会把 jammy 的 glibc 2.35 打进包内。子进程若继承了其他 AppImage 的库搜索路径，就会拿新库去链这份旧 libc，从而找不到 `GLIBC_2.38`。官方源码仓库本身能在 Ubuntu 22.04 / 24.04 上成功出包，问题出在这份 jammy AppImage 的运行库组合，而不是 Stacer 程序逻辑。
- **修改文件：** 新增 `stacer/build_stacer.sh`、`stacer/README.md`，并在 `.github/appimage-apps.json` 增加标准应用 `stacer`。
- **修复内容：** 不同步官方 AppImage。改为在 Arch Linux 上从官方源码安装当前稳定 Stacer，用 `quick-sharun` 收集与二进制匹配的 Qt6 / glibc / 输入上下文，并补上翻译目录链接。
- **已知结果：** 已提交正式构建入口，未监控 GitHub Actions，构建及实机结果待验证。
