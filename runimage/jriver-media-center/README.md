# JRiver Media Center RunImage

本目录用于构建和维护 JRiver Media Center 的独立 RunImage。

## 用途与产物

- 构建脚本：`setup_jriver.sh`
- 上游软件：通过 AUR `jriver-media-center` 安装 JRiver Media Center Linux 版本。
- 最终产物：`mediacenter36` RunImage。
- `mediacenter36` 中的 `36` 为当前 JRiver 主版本号；后续主版本变化时，需要同步检查构建脚本和 workflow 中与产物名有关的逻辑。

## 目录文件

- `setup_jriver.sh`：安装 JRiver、依赖与运行时配置，并编译、安装兼容代码。
- `filechooser-empty-path.c`：JRiver 文件选择器空路径兼容 Patch；仅把 `gtk_file_chooser_set_current_folder()` 收到的空字符串替换为运行时 Home。
- `jriver-filechooser-launch.sh`：JRiver 专用启动器；仅为主进程加载兼容库，随后执行未修改的 `/usr/bin/mediacenter36`。
- `README.md`：记录当前打包方式、兼容逻辑、实机结果和历史修复。

`filechooser-empty-path.c` 与 `jriver-filechooser-launch.sh` 必须作为独立源码维护，不再内嵌到 `setup_jriver.sh`；后续修改兼容逻辑时直接修改对应文件，避免大型 heredoc 难以审阅。

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
- `/etc/gtk-3.0/settings.ini` 的 `gtk-recent-files-enabled=false`：保留既有 Recent 列表设置；该设置不能修正应用主动传入的空目录。
- `jriver-filechooser-launch.sh`：构建时安装为 `/usr/local/bin/jriver-filechooser-launch`；`RIM_AUTORUN` 仍通过 `dbus-run-session` 调用它，保持独立 session D-Bus 生命周期。
- `filechooser-empty-path.c`：构建时编译为 `/usr/local/lib/jriver/filechooser-empty-path.so`；只在 JRiver 主进程中处理 `gtk_file_chooser_set_current_folder()` 的空字符串，将其替换为运行时 Home；非空路径原样交给 GTK。加载后立即恢复原 `LD_PRELOAD` 环境，避免把新增兼容库传给 JRWeb 或外部 helper。

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

可以成功激活 `org.gtk.vfs.Daemon` 并列出 Recent 条目；独立 D-Bus 会话结束时仍会出现总线断开提示。该结果证明 GVFS Recent 后端文件本身可用，关键问题位于 session D-Bus 激活边界。

后续真实运行日志已确认独立 session D-Bus 中的 `org.gtk.vfs.Daemon`、`org.gtk.vfs.Metadata` 和 `ca.desrt.dconf` 成功激活，但打开文件选择器仍报错，点 Home 后可正常浏览。因此不能再把该弹窗直接等同于 Recent 后端激活失败。

后续 Linux 实机验证已经确认：加入空路径兼容层后，“打开媒体文件”直接进入 Home，原 `The folder contents could not be displayed` / `Operation not supported` 弹窗消失。该行为以提交 `c8b020a08a63cacddd438ac9f2270d841563fba7` 为稳定逻辑基线。

当前重构只把已经验证有效的 C Patch 和启动器从 `setup_jriver.sh` heredoc 拆成独立文件；兼容逻辑、编译参数、安装路径、`LD_PRELOAD` 范围、D-Bus 启动方式和上游 JRiver 可执行文件均保持不变。

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

### 2026-09-10：使用独立 session D-Bus 启动 JRiver

- 现象：RunImage 默认启动 JRiver 时，GTK 文件选择器仍无法访问 `recent:///`；但同一镜像内 `dbus-run-session -- gio list recent:///` 已能成功激活 `org.gtk.vfs.Daemon` 并列出 Recent 条目。
- 根因：JRiver 默认继承的宿主 session D-Bus 无法根据 RunImage 内的 GVFS service 文件完成容器内后端激活；GVFS 后端文件和命令本身并未缺失。
- 修改文件：`runimage/jriver-media-center/setup_jriver.sh`、`runimage/jriver-media-center/README.md`。
- 修复：在 `Run.rcfg` 中加入 `RIM_AUTORUN=("dbus-run-session" "--" "mediacenter36")`，由 RunImage autorun 在容器内先建立独立 session D-Bus，再启动 JRiver，使 JRiver 及其子进程在同一总线生命周期内使用容器内 GVFS 服务。
- 保留内容：保留已经实际生效的 `startup-mode='cwd'`、`GIO_USE_VOLUME_MONITOR=unix`、既有宿主集成和打包流程；不启用全局 `RIM_UNSHARE_DBUS`，不修改其他 RunImage 项目或 workflow。
- 已知结果：`dbus-run-session` 对 `recent:///` 的直接验证已经成功；正式重新构建后的 JRiver 文件选择器行为仍需真实运行确认。

### 2026-09-10：补充空初始目录的 GTK/GIO 兼容处理

- 现象：独立 D-Bus 已成功激活 GVFS 和 dconf，文件选择器仍提示 `Operation not supported`；关闭提示后内容空白，点 Home 后正常。
- 定位依据：上游 JRiver 的 `libJRTools.so` 在创建文件选择器后直接调用 `gtk_file_chooser_set_current_folder()`，调用处没有空字符串检查。GTK 将该参数交给 `g_file_new_for_path()`；GIO 对空字符串构造不支持目录查询的 dummy file，并返回相同错误。默认目录 schema 与 Recent 开关不能拦截这一显式调用。参考 [GTK 调用实现](https://github.com/GNOME/gtk/blob/gtk-3-24/gtk/gtkfilechooser.c)、[GIO 空路径处理](https://github.com/GNOME/glib/blob/main/gio/glocalvfs.c) 和 [GIO 目录查询错误](https://github.com/GNOME/glib/blob/main/gio/gfile.c)。这些证据确认了空路径兼容性缺口，但尚未直接确认报错实机传入的参数。
- 修改文件：`runimage/jriver-media-center/setup_jriver.sh`、`runimage/jriver-media-center/README.md`。
- 修复：构建时生成仅拦截上述 GTK 函数的兼容库；只将空字符串替换为运行时 Home，Home 未设置为绝对路径时使用根目录。非空路径、NULL 参数和 GTK 返回值保持原有行为，不强制 local-only，不屏蔽真实目录错误。
- 启动范围：在既有独立 D-Bus 内经专用启动器加载兼容库，再执行上游主程序并完整传递参数。兼容库加载后立即恢复原有预加载环境；不修改上游二进制、系统 GTK/GIO 库、JRWeb、音频链或其他 RunImage 项目。
- 已知结果：后续 Linux 实机验证确认“打开媒体文件”直接进入 Home，原 `Operation not supported` 弹窗消失；提交 `c8b020a08a63cacddd438ac9f2270d841563fba7` 作为该修复的稳定逻辑基线。

### 2026-09-10：将内嵌兼容 Patch 拆分为独立源码

- 目的：把已经实机确认有效的文件选择器兼容逻辑从 `setup_jriver.sh` heredoc 中独立出来，降低后续审阅和维护成本。
- 修改文件：`runimage/jriver-media-center/setup_jriver.sh`、`filechooser-empty-path.c`、`jriver-filechooser-launch.sh`、`README.md`。
- 调整：`setup_jriver.sh` 只负责从当前应用目录安装独立源码和启动器，再使用原有 `cc -shared -fPIC -O2 -Wall -Wextra -Werror ... -ldl -pthread` 参数编译兼容库。
- 保留内容：C Patch 逻辑、启动器逻辑、安装路径、`LD_PRELOAD` 作用范围、`RIM_AUTORUN`、独立 session D-Bus 和 `/usr/bin/mediacenter36` 均不改变。
- 已知结果：这是代码组织重构，不引入新的运行兼容逻辑；运行行为继续以 `c8b020a08a63cacddd438ac9f2270d841563fba7` 的实机验证结果为基线。

## 已知运行日志

以下日志在已确认文件选择器正常的运行中仍可能出现，不应单独作为本兼容修复失效的判断依据：

- `dbind-WARNING` / `at-spi`：无障碍总线连接警告。
- `Fontconfig warning`：字体配置兼容警告。
- `xdg-desktop-portal` 的 `last-resort fallback`、PipeWire / RealtimeKit 相关提示：容器内桌面 Portal 或媒体服务的回退信息。
- `org.gtk.vfs.Daemon`、`org.gtk.vfs.Metadata`、`ca.desrt.dconf` 的 `Successfully activated`：独立 session D-Bus 下的正常服务激活信息。
- `free(): invalid next size (normal)` 属于内存分配器异常信息；如果后续伴随实际崩溃或闪退，应单独定位，不得归入上述普通警告。

## 目录维护规则

JRiver RunImage 的依赖、启动兼容、故障记录和后续专用修复统一维护在本目录；`runimage/README.md` 只保留多个 RunImage 共用的通用说明，避免 JRiver 专用内容继续堆积在通用文档中。
