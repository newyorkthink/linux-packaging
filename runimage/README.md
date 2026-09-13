# RunImage Toolkit

用于构建和维护不同用途的 RunImage 环境。

## Browser RunImage 运行参数说明

### `RIM_NO_NVIDIA_CHECK=1`

禁用 RunImage 的 NVIDIA 驱动版本检查和自动驱动处理流程，避免 browser RunImage 自动检测、匹配、生成或下载 NVIDIA 驱动镜像。

该参数只关闭 RunImage 自己的 NVIDIA 驱动处理机制，不等于禁用 NVIDIA 显卡，也不等于关闭浏览器 GPU 硬件加速；浏览器最终使用哪块 GPU 仍由宿主机图形环境、驱动和浏览器自身设置决定。

### `RIM_RUN_IN_ONE=1` 和 `RIM_WAIT_RPIDS_EXIT=1`（已注释停用）

`setup_browser.sh` 已注释这两个参数，与 `setup_general_env.sh`、`setup_trading_env.sh` 保持一致，不再主动启用共享容器模式。

实际使用反馈显示，同时启用共享容器及等待相关程序退出的参数后，浏览器仍偶发闪退，因此暂时停用。共享容器下首个终端被中断或关闭也可能影响后续程序；本次闪退的具体根因尚未确认，不能保证停用后所有闪退都消失。

脚本以追加方式写入 `Run.rcfg`，注释这两行不会移除旧镜像或已有配置中的对应设置；已有产物不会因仓库脚本修改而自动改变。

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

## 修复记录

### 2026-09-13：停用 Browser 共享容器参数

- 故障现象：同时启用 `RIM_RUN_IN_ONE=1` 和 `RIM_WAIT_RPIDS_EXIT=1` 后，实际使用仍有浏览器偶发闪退反馈。
- 根因状态：尚未确认具体崩溃原因，本次按反馈暂时停用共享容器模式。
- 修改文件：`setup_browser.sh`、`README.md`。
- 处理内容：注释两条参数写入命令，补充停用原因，与 general_env、trading_env 的不启用策略保持一致；其他配置与打包命令不变。
- 验证状态：完成脚本语法和完整差异静态检查；未监控 Actions，构建及运行结果未验证。
