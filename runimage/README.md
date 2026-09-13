# RunImage Toolkit

用于构建和维护不同用途的 RunImage 环境。

## Browser RunImage

浏览器环境已独立放在 [`browser/`](./browser/README.md)，构建脚本为 [`browser/setup_browser.sh`](./browser/setup_browser.sh)。运行参数、软件包说明及修复记录见该目录 README。

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
