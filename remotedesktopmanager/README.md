# Remote Desktop Manager

## 用途与产物

本目录将 AUR / Arch 的官方 `remote-desktop-manager` 重新封装为可分发 AppImage。

- 上游项目：Devolutions Remote Desktop Manager Linux
- 软件来源：Arch `remote-desktop-manager`
- 架构：x86_64
- 稳定产物：`dist/remotedesktopmanager.AppImage`
- 构建入口：`build_remotedesktopmanager.sh`
- CI 入口：`.github/workflows/build.yml`（清单键 `remotedesktopmanager`）

Remote Desktop Manager 用于集中管理 RDP、SSH、VNC 等远程连接。

## 技术栈

RDM Linux 是 Avalonia / .NET 桌面应用，并嵌入：

- WebKitGTK 4.1（内部浏览器 / HTML 视图）
- VTE 3（内置终端）
- glycin-ng（图像加载兼容层，替换 GNOME glycin）
- ICU（.NET 全球化与多语言界面）

中文输入分两路：

- Avalonia 主界面通过 `AVALONIA_IM_MODULE=fcitx5` 连接宿主 Fcitx5 D-Bus
- WebKitGTK / VTE 通过随包 `fcitx5-gtk` 的 GTK3 模块 `im-fcitx5.so` 连接宿主 Fcitx5

AppImage 不内置 Fcitx5 守护进程或输入方案。

内置 LocalTerm 会 `posix_spawn` 宿主 `/bin/sh`。主进程依赖由 sharun 的 bundled ld-linux `--library-path` 提供，不能再用 `LD_LIBRARY_PATH` 指向包内 `lib/`，否则宿主 shell 会加载包内 `libc.so.6`。

## 打包方式

构建环境使用仓库统一的 Arch Linux AnyLinux 容器和 `quick-sharun`。

1. 先安装 `glycin-ng`，避免官方 `glycin` 抢先占用导致非交互冲突。
2. 安装 `remote-desktop-manager` 及其运行依赖，以及 `fcitx5-gtk`。
3. 修正 desktop `Exec` 为实际二进制名 `RemoteDesktopManager`。
4. 一次性把主程序、`libWebView-4.1.so` 和 `im-fcitx5.so` 交给 `quick-sharun`。
5. 向 `AppDir/.env` 写入 .NET 与中文输入环境变量，明确不写入 `LD_LIBRARY_PATH`；打包前再删除 `.env` 中可能残留的该变量。
6. 补齐 `/usr/lib/devolutions/RemoteDesktopManager` 与 ICU 运行库。
7. 写入 `AppDir/bin/rdm-gtk-immodules.src.hook`，启动时按当前 `$APPDIR` 生成 GTK3 `immodules.cache`。
8. 检查 WebView 辅助进程、Fcitx5 GTK3 模块、glycin-ng、输入环境变量和 `.env` 不含 `LD_LIBRARY_PATH` 后生成 AppImage。

## 运行

在当前目录执行：

```bash
./remotedesktopmanager.AppImage
```

需要宿主会话已经运行 Fcitx5，并已配置中文输入方案。

## 修复 / 变更记录

### 已撤销 .NET Invariant Mode

已撤销 .NET Invariant Mode，当前 AppImage 已正常打包 ICU，多语言界面可用。

### 内置终端 Fcitx5 候选按键泄漏

内置终端使用 Fcitx5 输入中文时，会将候选操作的原始按键同时发送到终端，导致出现 `^[[A`、`^[[D` 等转义字符。此前记录为 RDM 内置终端输入处理，构建脚本无法直接修复。

### 2026-09-18：修正 GTK3 Fcitx5 模块 ID 并补运行时 immodules 缓存

- 现象：内置终端（VTE / WebKitGTK）用 Fcitx5 选词时，方向键同时变成终端转义序列 `^[[A`、`^[[D`。
- 根因：`im-fcitx5.so` 在 GTK3 `immodules.cache` 中的模块 ID 是 `fcitx`，仓库内 Remmina、dconf-editor、Mission Center 等已验证方案均使用 `GTK_IM_MODULE=fcitx`。本项目却写成 `GTK_IM_MODULE=fcitx5`，GTK 找不到模块后回退，候选导航键不再被 IM 过滤。同时构建期缓存会留下构建机绝对路径，运行时也无法加载模块。
- 修改文件：`remotedesktopmanager/build_remotedesktopmanager.sh`、`remotedesktopmanager/README.md`、根目录 `README.md`。
- 修复内容：`.env` 改为 `GTK_IM_MODULE=fcitx`，保留 `AVALONIA_IM_MODULE=fcitx5`。启动 hook 按当前 AppImage 挂载路径生成只含 Fcitx5 的 GTK3 缓存，并导出 `GTK_IM_MODULE_FILE`。不回退 ICU、glycin-ng、WebView 4.1 或 Avalonia IME 基线。
- 已知结果：模块 ID 与仓库已验证 GTK3 Fcitx5 方案对齐；内置终端候选按键是否不再泄漏仍待 Linux 实机验证，不得视为已经实机解决。

### 2026-09-18：去掉 LD_LIBRARY_PATH，避免内置终端加载包内 libc

- 现象：打开内置终端后 LocalTerm 能 `posix_spawn` 宿主 `/bin/sh`，但立刻报 `symbol lookup error: .../lib/libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE`，随后 `read error errno=5`。
- 根因：构建脚本为替代上游 wrapper，向 `AppDir/.env` 写入 `LD_LIBRARY_PATH=${APPDIR}/bin:${APPDIR}/lib:...`。Anylinux / sharun 明确禁止用 `LD_LIBRARY_PATH`：它会遗传给子进程。宿主 `/bin/sh` 仍使用系统 `ld-linux`，却去加载 AppImage 里另一套 `libc.so.6`，`GLIBC_PRIVATE` 对不上。主进程本身应由 sharun 的 bundled ld-linux `--library-path` 解析依赖；ICU 与 RDM 原生库已在 `AppDir/bin`，.NET DllImport 会先搜程序目录。
- 修改文件：`remotedesktopmanager/build_remotedesktopmanager.sh`、`remotedesktopmanager/README.md`、根目录 `README.md`。
- 修复内容：不再写入 `LD_LIBRARY_PATH`；打包前删除 `.env` 中可能残留的该变量并拒绝带该变量出包。不回退 ICU、glycin-ng、WebView 4.1、GTK3 Fcitx5 模块 ID 或运行时 immodules 缓存。
- 已知结果：脚本与 Anylinux 文档对齐，内置终端不再被迫加载包内 libc。新 AppImage 是否能正常打开本地 shell 仍待 Linux 实机验证，不得视为已经实机解决。
