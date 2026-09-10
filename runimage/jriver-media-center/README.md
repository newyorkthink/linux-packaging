# JRiver Media Center RunImage

本目录用于构建和维护 JRiver Media Center 的独立 RunImage。

## 用途与产物

- 构建脚本：`setup_jriver.sh`
- 上游软件：通过 AUR `jriver-media-center` 安装 JRiver Media Center Linux 版本。
- 最终产物：`mediacenter36` RunImage。
- `mediacenter36` 中的 `36` 为当前 JRiver 主版本号；后续主版本变化时，需要同步检查构建脚本和 workflow 中与产物名有关的逻辑。

## 技术栈

JRiver Media Center Linux 版本为 x86_64 原生应用，主要涉及 GTK3、GIO/GVFS、GStreamer、WebKitGTK、ALSA/PulseAudio、Mesa/Vulkan 等运行时组件。

当前 RunImage 基于 Arch Linux / BlackArch 环境构建，通过 `yay` 安装 JRiver 和依赖，再由 RunImage 自身完成瘦身与封装。

## 打包方式

构建流程保持现有 RunImage 路线：

1. 配置 Arch Linux 与 BlackArch 镜像源。
2. 生成中文 UTF-8 locale。
3. 安装 `yay`、JRiver Media Center 及运行依赖。
4. 写入 `/var/RunDir/config/Run.rcfg` 的运行参数。
5. 执行 `rim-shrink --all`。
6. 执行 `rim-build mediacenter36` 生成最终 RunImage。

GitHub Actions 入口为 `.github/workflows/build_runimage.yml`，JRiver 对应脚本路径为：

```text
runimage/jriver-media-center/setup_jriver.sh
```

用户手动选择该脚本时只构建 JRiver RunImage；正常发布资产名保持 `mediacenter36`。

## 运行

进入 `mediacenter36` 所在目录后直接执行：

```bash
./mediacenter36
```

## 当前运行与兼容说明

当前脚本保留以下 JRiver 专用兼容处理：

- `gvfs`：提供 GTK/GIO 的 Recent、Trash 等虚拟文件系统后端。
- GTK3 `org.gtk.Settings.FileChooser` 的 `startup-mode='cwd'` override：让文件选择器默认从当前工作目录启动。
- `GIO_USE_VOLUME_MONITOR=unix`：避免共享宿主会话 D-Bus 时请求容器内的 UDisks2 GVFS 卷监视器。

真实运行检查已经确认：

```text
gsettings get org.gtk.Settings.FileChooser startup-mode
=> 'cwd'

printenv GIO_USE_VOLUME_MONITOR
=> unix

gio list recent:///
=> Operation not supported
```

因此，`startup-mode='cwd'` 与 `GIO_USE_VOLUME_MONITOR=unix` 已实际生效，但它们没有解决 `recent:///` 本身的 GVFS 会话 D-Bus 激活问题。

进一步在 RunImage 内执行：

```text
dbus-run-session -- gio list recent:///
```

可以成功激活 `org.gtk.vfs.Daemon` 并列出 Recent 条目；独立 D-Bus 会话结束时仍会出现总线断开提示。该结果说明后续修复应继续围绕 JRiver 进程生命周期内的独立 session D-Bus 集成处理，当前尚未把这一启动方式写入正式构建脚本，也不应把该问题描述为已经完全修复。

## 修复记录

### 2026-09-10：文件选择器 Recent 报 `Operation not supported`

- 现象：JRiver 通过“打开媒体文件”调用 GTK 文件选择器时，首次进入 Recent 位置会提示 `The folder contents could not be displayed` / `Operation not supported`，切换到 Home 后可正常浏览本地目录。
- 根因：`setup_jriver.sh` 已包含 GTK3，但未安装提供 `gvfsd-recent` 和 `recent://` 后端的 `gvfs`。
- 修改文件：`runimage/setup_jriver.sh`。
- 修复：在 JRiver RunImage 依赖中加入 `gvfs`，同时保留原有运行参数和打包流程不变。
- 已知结果：构建依赖已补齐；重新构建后的实际文件选择器行为仍需实机确认。
- 对应提交：`ecca15ffc9d2ff4c58ba15fee684234fb241f01c`。

### 2026-09-10：补充修复 RunImage 共享 D-Bus 下的 GVFS 激活失败

- 现象：加入 `gvfs` 后，文件选择器启动时仍提示 `Operation not supported`；终端同时报告 `org.gtk.vfs.UDisks2VolumeMonitor` 未由任何 D-Bus service file 提供。
- 根因：`gvfs` 软件包本身已经包含 `org.gtk.vfs.UDisks2VolumeMonitor.service`，并依赖 `udisks2`；问题不是继续缺包，而是 RunImage 默认共享宿主会话 D-Bus，宿主会话总线不会按容器内 `/usr/share/dbus-1/services` 自动激活该服务。前一项修复只补齐了容器文件，未解决该 D-Bus 激活边界。
- 修改文件：`runimage/setup_jriver.sh`、`runimage/README.md`。
- 修复：保留 `gvfs`；为 GTK3 的 `org.gtk.Settings.FileChooser` 写入 schema override，将默认 `startup-mode` 从 `recent` 改为 `cwd`，并重新编译 GSettings schema；同时在 RunImage 运行配置中设置 `GIO_USE_VOLUME_MONITOR=unix`，避免请求 UDisks2 远程卷监视器。
- 保留内容：不启用 `RIM_UNSHARE_DBUS`，不额外启动私有 `dbus-daemon`，不改变 JRiver 原有运行参数、宿主集成和 `rim-build mediacenter36` 打包流程。
- 已知结果：后续真实运行确认这两项设置均已生效，但 `gio list recent:///` 仍返回 `Operation not supported`，因此该方案没有完成最终修复。
- 对应提交：`80edb90e3a7427d4d22bbfcf15830eeac380e18a`。

### 2026-09-10：定位 `recent:///` 到 session D-Bus 激活边界

- 现象：`startup-mode='cwd'` 和 `GIO_USE_VOLUME_MONITOR=unix` 均已实际生效，但 JRiver 文件选择器仍会进入 Recent 并提示 `Operation not supported`；RunImage 内直接执行 `gio list recent:///` 也得到相同错误。
- 定位：在同一 RunImage 内改用 `dbus-run-session -- gio list recent:///` 后，`org.gtk.vfs.Daemon` 可以成功激活并列出 Recent 条目，说明 `gvfs` 文件与后端本身存在，关键问题位于 session D-Bus 激活边界。
- 修改文件：本次只整理目录和文档，不修改已生成并实测的 JRiver 运行逻辑；`setup_jriver.sh` 原样迁移到 `runimage/jriver-media-center/`。
- 后续处理：若继续修复，应只在 JRiver 专用目录内处理其进程生命周期内的 D-Bus 启动方式，不修改其他 RunImage 环境。
- 已知结果：根因范围已经进一步缩小，但正式 JRiver 启动方式尚未调整，当前问题仍未标记为解决。

## 目录维护规则

JRiver RunImage 的依赖、启动兼容、故障记录和后续专用修复统一维护在本目录；`runimage/README.md` 只保留多个 RunImage 共用的通用说明，避免 JRiver 专用内容继续堆积在通用文档中。
