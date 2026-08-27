# Browser RunImage

用于构建和维护浏览器专用 `browser_runimage` RunImage 环境。

构建脚本：`setup_browser_runimage.sh`。

## 运行参数说明

### `RIM_NO_NVIDIA_CHECK=1`

禁用 RunImage 的 NVIDIA 驱动版本检查和自动驱动处理流程，避免 `browser_runimage` 自动检测、匹配、生成或下载 NVIDIA 驱动镜像。

该参数只关闭 RunImage 自己的 NVIDIA 驱动处理机制，不等于禁用 NVIDIA 显卡，也不等于关闭浏览器 GPU 硬件加速；浏览器最终使用哪块 GPU 仍由宿主机图形环境、驱动和浏览器自身设置决定。

### `RIM_RUN_IN_ONE=1`

同一个 `browser_runimage` 后续启动的浏览器共用同一个 RunImage 容器，避免同时运行多个浏览器时重复创建独立容器和挂载环境。

### `RIM_WAIT_RPIDS_EXIT=1`

等待共享容器内的相关程序全部退出后再结束 RunImage 容器。

`browser_runimage` 使用 `RIM_RUN_IN_ONE=1` 时应同时启用该参数，否则最先启动的浏览器退出后，可能连带结束后续进入同一容器的其他浏览器。启用后，例如先启动 Vivaldi、再启动 Firefox，关闭 Vivaldi 不会同时关闭 Firefox；等共享容器内的浏览器全部退出后，RunImage 才结束并清理容器。

`browser_runimage` 保留这两个参数，适合通过桌面入口、i3 快捷键等方式启动。若从终端启动共享容器中的第一个浏览器，之后对该终端执行 `Ctrl-C` 或直接关闭终端，可能影响同一共享容器内后续启动程序的终端输出通道；因此不要把会被手动中断或关闭的终端作为共享容器的长期启动入口。

## 软件包说明规则

`setup_browser_runimage.sh` 新增任何软件包时，都应在安装命令下方补充一行中文说明，注明新增原因和用途，避免以后无法判断某个依赖是否仍然需要。

当前额外加入 `libsecret`，用于为 Chromium 系浏览器提供 Secret Service 客户端库，使 Edge、Chrome、Brave、Vivaldi 等能够访问 KeePassXC、GNOME Keyring 等密码与凭据存储后端。
