# ToDesk AppImage

## 用途与来源

本目录把 ToDesk Linux x86_64 客户端重新封装为单一 AppImage。

- 上游程序：ToDesk 官方 Linux 客户端。
- 软件包来源：AUR `todesk-bin`；AUR 当前从 ToDesk 官方 `dl.todesk.com` 下载 x86_64 DEB。
- 构建环境：Arch Linux AnyLinux 容器。
- 打包工具：`quick-sharun`。
- 最终产物：`dist/todesk.AppImage`。
- Release 资产名：`todesk.AppImage`。
- 构建版本不写死；每次从本次实际安装的 `todesk-bin` 读取，并在成功生成 AppImage 后写入 `dist/version.txt`。

AUR 当前包保留 ToDesk 官方 `/opt/todesk` 布局，主要运行组件包括 `ToDesk`、`ToDesk_Service`、`ToDesk_Session`、`CrashReport`、`bin/*.so*`、`res/` 和 `config/`。AUR 同时明确使用 `!strip`，因此本项目也保持官方闭源二进制和私有库不 strip。

## 打包方式

ToDesk 采用 **Arch Linux + quick-sharun**，不使用 linuxdeploy，也不安装 AppImage 自己的 systemd 服务。

构建过程：

1. 通过仓库统一 Arch 基础环境安装构建依赖。
2. 动态安装当前 AUR `todesk-bin`，同时安装与 ToDesk GTK3 技术栈匹配的 Fcitx5 GTK3 输入模块；IBus 来自统一基础环境。
3. 完整复制 `/opt/todesk` 到 `AppDir/shared/bin/todesk/`，保持官方 `bin / res / config` 相对布局。
4. 在同一次 `quick-sharun` 调用中收集 `ToDesk`、`ToDesk_Service`、`ToDesk_Session`、`CrashReport` 和 GTK3 IBus/Fcitx5 输入模块。
5. 不自制 `AppRun`。使用 quick-sharun 默认入口按 AppImage/软链接文件名选择 `AppDir/bin/` 中的同名程序。
6. 加入独立 `zh_CN.UTF-8` locale。
7. 通过 quick-sharun hook 处理 ToDesk 固定 `/opt/todesk` 路径、可写 `config` 和服务日志路径。
8. 最终由 `quick-sharun --make-appimage` 生成一个 `todesk.AppImage`。

不固定封装 Intel、NVIDIA 或 AMD 的宿主 GPU 驱动，也不强制设置 `LIBVA_DRIVER_NAME=iHD`。ToDesk 官方随包提供的私有编码相关 `.so` 保持原样，实际硬件加速继续取决于宿主显卡与驱动环境。

## 单 AppImage 多入口

quick-sharun 默认 `AppRun` 会先检查启动文件名是否与 `AppDir/bin/` 中的程序同名。因此只需要一个 AppImage，通过软链接即可得到多个入口：

- `todesk.AppImage`：默认启动 `ToDesk` 图形界面。
- `ToDesk`：启动 `ToDesk` 图形界面。
- `ToDesk_Service`：启动 ToDesk 后台服务组件。
- `ToDesk_Session`：ToDesk 会话组件，通常由后台服务按需拉起。
- `CrashReport`：ToDesk 崩溃处理组件，通常由程序按需拉起。

不需要复制多份 AppImage。

## 可写运行目录

ToDesk 官方 Linux 布局固定使用 `/opt/todesk`，官方排障文档也会直接操作 `/opt/todesk/config/config.ini`。AppImage 挂载内容本身只读，因此不能让服务直接把配置写回 AppImage。

运行时 hook 会把官方程序目录复制到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/todesk-appimage/runtime
```

服务日志映射到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/todesk-appimage/logs
```

`/opt/todesk` 和 `/var/log/todesk` 的访问通过 path mapping 重定向到上述用户目录。更新 AppImage 后，程序文件会按新版本刷新，但原有 `config/` 会保留，避免无条件重置设备配置。

普通便携使用建议让 `ToDesk_Service` 和 GUI 以同一个用户运行，使两者共享同一份运行目录和配置。若用 `sudo` 单独启动服务，`HOME / XDG_DATA_HOME` 通常会切换到 root 环境，从而产生另一份状态目录，因此本项目不把 `sudo` 作为默认启动方式。

## 运行

ToDesk Linux 当前官方说明要求 X11 桌面环境；无桌面/纯 SSH 模式不属于当前 Linux 客户端支持范围。

在 **Linux 终端**、AppImage 所在目录执行。

```bash
# 赋予 AppImage 执行权限
chmod +x todesk.AppImage

# 创建后台服务入口软链接
ln -sfn todesk.AppImage ToDesk_Service

# 启动 ToDesk 后台服务组件；保持该进程运行
./ToDesk_Service

# 启动 ToDesk 图形界面
./todesk.AppImage
```

如果还需要显式入口，可另外创建：

```bash
# 创建 ToDesk GUI 同名入口
ln -sfn todesk.AppImage ToDesk

# 创建 ToDesk Session 入口
ln -sfn todesk.AppImage ToDesk_Session

# 创建 CrashReport 入口
ln -sfn todesk.AppImage CrashReport
```

`ToDesk_Session` 和 `CrashReport` 通常不需要手工启动。

## 系统集成边界

这个 AppImage 面向便携的用户会话运行方式：

- 不向宿主 `/opt/todesk` 写文件。
- 不向宿主 `/var/log/todesk` 写日志。
- 不创建或修改 `/etc/systemd/system/todeskd.service`。
- 不执行 `systemctl enable/start/restart`。
- 不修改宿主显卡驱动、VA-API 配置、网络、防火墙或其他系统设置。

ToDesk 官方发行版安装包使用 `todeskd.service` 提供系统级后台服务。若需要开机即启动、系统级无人值守或官方 systemd 服务语义，应使用 ToDesk 官方发行版安装方式；本 AppImage 不伪装成系统安装包。

## 当前验证状态

2026-09-24 新增 ToDesk AppImage 打包实现时，已依据以下内容完成静态设计核对：

- 当前 AUR `todesk-bin` 的包布局和 `!strip` 规则。
- ToDesk 官方 Linux 文档中的 `/opt/todesk/config/config.ini`、服务日志位置和 X11 要求。
- 本仓库 `anylinux_projects.md` 的 quick-sharun 多入口、非标准 `/opt` 布局、GTK3 中文输入和 locale 规则。
- 私有仓库 EasyConnect 已有“单 AppImage 多入口 + 可写后台运行目录 + 固定路径映射”的实现经验。

本条只表示构建脚本和路径设计已经静态核对；首次 GitHub Actions 正式构建、最终 AppImage 启动、服务与 GUI 通信、真实远程连接仍需以之后实际产物结果为准，不提前标记为已验证。
