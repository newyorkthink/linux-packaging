# RunImage Toolkit

用于构建和维护不同用途的 RunImage 环境。

## Browser RunImage 运行参数说明

### `RIM_NO_NVIDIA_CHECK=1`

禁用 RunImage 的 NVIDIA 驱动版本检查和自动驱动处理流程，避免 browser RunImage 自动检测、匹配、生成或下载 NVIDIA 驱动镜像。

该参数只关闭 RunImage 自己的 NVIDIA 驱动处理机制，不等于禁用 NVIDIA 显卡，也不等于关闭浏览器 GPU 硬件加速；浏览器最终使用哪块 GPU 仍由宿主机图形环境、驱动和浏览器自身设置决定。

### `RIM_RUN_IN_ONE=1`

同一个 browser RunImage 后续启动的浏览器共用同一个 RunImage 容器，避免同时运行多个浏览器时重复创建独立容器和挂载环境。

### `RIM_WAIT_RPIDS_EXIT=1`

等待共享容器内的相关程序全部退出后再结束 RunImage 容器。

browser 使用 `RIM_RUN_IN_ONE=1` 时应同时启用该参数，否则最先启动的浏览器退出后，可能连带结束后续进入同一容器的其他浏览器。启用后，例如先启动 Vivaldi、再启动 Firefox，关闭 Vivaldi 不会同时关闭 Firefox；等共享容器内的浏览器全部退出后，RunImage 才结束并清理容器。

browser 保留这两个参数，适合通过桌面入口、i3 快捷键等方式启动。若从终端启动共享容器中的第一个浏览器，之后对该终端执行 `Ctrl-C` 或直接关闭终端，可能影响同一共享容器内后续启动程序的终端输出通道；因此不要把会被手动中断或关闭的终端作为共享容器的长期启动入口。

## Browser RunImage 软件包说明规则

`setup_browser.sh` 新增任何软件包时，都应在安装命令下方补充一行中文说明，注明新增原因和用途，避免以后无法判断某个依赖是否仍然需要。

当前额外加入 `libsecret`，用于为 Chromium 系浏览器提供 Secret Service 客户端库，使 Edge、Chrome、Brave、Vivaldi 等能够访问 KeePassXC、GNOME Keyring 等密码与凭据存储后端。

## General Env RunImage 运行参数说明

`setup_general_env.sh` 保留 `RIM_NO_NVIDIA_CHECK=1` 等通用运行参数，但不启用 `RIM_RUN_IN_ONE=1` 和 `RIM_WAIT_RPIDS_EXIT=1`。

实际使用中，多个基于 `general_env` 启动的 GUI 程序共用一个容器时，如果最先启动程序所在终端被 `Ctrl-C` 中断或直接关闭，后续同容器程序可能出现 `write EIO`、卡死或异常退出。为避免 WPS、TradingView 等不同程序互相影响，`general_env` 保持每次启动使用独立容器。

## Trading Env RunImage 运行参数说明

`setup_trading_env.sh` 保留 `RIM_NO_NVIDIA_CHECK=1` 等通用运行参数，但不启用 `RIM_RUN_IN_ONE=1` 和 `RIM_WAIT_RPIDS_EXIT=1`。

原因与 `general_env` 相同：共享容器中的第一个程序如果绑定在随后被 `Ctrl-C` 中断或关闭的终端上，可能影响后续同容器 GUI 程序。交易环境因此保持每次启动使用独立容器，避免 IBKR、thinkorswim 等交易程序之间相互影响。

## General Env 软件包说明规则

`setup_general_env.sh` 新增任何软件包时，也应在安装命令下方补充一行中文说明，注明新增原因和用途。

当前额外加入：

- `qt5-svg`：补充 Qt5 程序的 SVG 图片、SVG 图标和相关渲染支持。
- `qt6-svg`：补充 Qt6 程序的 SVG 图片、SVG 图标和相关渲染支持。
- `libsecret`：提供 Secret Service 客户端库，供程序访问 KeePassXC、GNOME Keyring 等密码与凭据存储后端。
- `gsettings-desktop-schemas`：补充 GTK/GNOME 程序常用的 GSettings 桌面配置 schema，并自动依赖安装 `dconf`。

## JRiver Media Center RunImage 软件包说明

`setup_jriver.sh` 用于构建 JRiver Media Center RunImage。保留 `gvfs` 作为 GTK/GIO 虚拟文件系统依赖；文件选择器默认启动模式改为 `cwd`，并使用 `GIO_USE_VOLUME_MONITOR=unix`，避免启动文件选择器时依赖共享宿主会话 D-Bus 无法激活的容器内 UDisks2 GVFS 卷监视器。

## JRiver Media Center RunImage 修复记录

### 2026-09-10：文件选择器 Recent 报 `Operation not supported`

- 现象：JRiver 通过“打开媒体文件”调用 GTK 文件选择器时，首次进入 Recent 位置会提示 `The folder contents could not be displayed` / `Operation not supported`，切换到 Home 后可正常浏览本地目录。
- 根因：`setup_jriver.sh` 已包含 GTK3，但未安装提供 `gvfsd-recent` 和 `recent://` 后端的 `gvfs`。
- 修改文件：`runimage/setup_jriver.sh`。
- 修复：在 JRiver RunImage 依赖中加入 `gvfs`，同时保留原有运行参数和打包流程不变。
- 已知结果：构建依赖已补齐；重新构建后的实际文件选择器行为仍需实机确认。

### 2026-09-10：补充修复 RunImage 共享 D-Bus 下的 GVFS 激活失败

- 现象：加入 `gvfs` 后，文件选择器启动时仍提示 `Operation not supported`；终端同时报告 `org.gtk.vfs.UDisks2VolumeMonitor` 未由任何 D-Bus service file 提供。
- 根因：`gvfs` 软件包本身已经包含 `org.gtk.vfs.UDisks2VolumeMonitor.service`，并依赖 `udisks2`；问题不是继续缺包，而是 RunImage 默认共享宿主会话 D-Bus，宿主会话总线不会按容器内 `/usr/share/dbus-1/services` 自动激活该服务。前一项修复只补齐了容器文件，未解决该 D-Bus 激活边界。
- 修改文件：`runimage/setup_jriver.sh`、`runimage/README.md`。
- 修复：保留 `gvfs`；为 GTK3 的 `org.gtk.Settings.FileChooser` 写入 schema override，将默认 `startup-mode` 从 `recent` 改为 `cwd`，并重新编译 GSettings schema；同时在 RunImage 运行配置中设置 `GIO_USE_VOLUME_MONITOR=unix`，避免请求 UDisks2 远程卷监视器。
- 保留内容：不启用 `RIM_UNSHARE_DBUS`，不额外启动私有 `dbus-daemon`，不改变 JRiver 原有运行参数、宿主集成和 `rim-build mediacenter36` 打包流程。
- 已知结果：已按新的终端错误定位并调整配置；重新构建后的实际文件选择器行为仍需实机确认。
