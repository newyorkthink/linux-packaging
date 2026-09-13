# Browser RunImage

本目录用于构建包含 Firefox、Microsoft Edge、Google Chrome、Zen Browser、Brave 和 Vivaldi 的浏览器 RunImage 环境。

## 用途与打包方式

- 构建脚本：`setup_browser.sh`。
- 发布产物：`browser`，目标架构为 x86_64。
- 上游基础环境：[VHSgunzo/runimage](https://github.com/VHSgunzo/runimage)；浏览器及依赖通过 Arch 官方仓库和 AUR 安装。
- 技术栈：Firefox / Zen 使用 Gecko，Edge / Chrome / Brave / Vivaldi 使用 Chromium，并配置 GTK/Qt、字体、音频、图形和输入法相关依赖。
- 构建入口：仓库 `.github/workflows/build_runimage.yml` 的 Browser Job，脚本路径为 `runimage/browser/setup_browser.sh`。
- 打包过程：在 GitHub Actions 临时 RunImage 环境中安装软件、写入 `Run.rcfg`，再执行现有瘦身和打包命令；产物继续上传至 `latest` Release，资产名不变。

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

## 修复记录

### 2026-09-13：停用 Browser 共享容器参数

- 故障现象：同时启用 `RIM_RUN_IN_ONE=1` 和 `RIM_WAIT_RPIDS_EXIT=1` 后，实际使用仍有浏览器偶发闪退反馈。
- 根因状态：尚未确认具体崩溃原因，本次按反馈暂时停用共享容器模式。
- 修改文件：`setup_browser.sh`、`README.md`。
- 处理内容：注释两条参数写入命令，补充停用原因，与 general_env、trading_env 的不启用策略保持一致；其他配置与打包命令不变。
- 验证状态：完成脚本语法和完整差异静态检查；未监控 Actions，构建及运行结果未验证。

## 变更记录

### 2026-09-13：浏览器环境迁入独立目录

- 将 `runimage/setup_browser.sh` 原样迁移到 `runimage/browser/setup_browser.sh`，保留脚本内容、可执行权限和共享容器参数的注释状态。
- 将 Browser 运行参数、软件包说明和既有修复记录迁入本 README；上级 README 保留入口及其他环境说明。
- 同步更新 workflow 的 push 路径、手动选项、计划映射和 Browser Job 脚本路径；构建产物名仍为 `browser`。
- 验证状态：核对迁移前后脚本 Git blob SHA、路径映射和完整差异；未监控 Actions，构建及运行结果未验证。
