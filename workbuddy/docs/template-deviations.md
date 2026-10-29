# WorkBuddy 标准模板差异

本文件记录 `build_workbuddy.sh` 相对于 `anylinux_projects.md` 中 Electron 直接下载安装包流程的程序专属处理。下载、解包和复制仍各保留一条命令，模板中原有代码的执行阶段不变。

## JSON 下载入口与 DEB 校验

- 位置：清理构建目录之后、复制完整程序目录之前。
- 差异：官方下载入口返回 JSON，使用 `common/download/download_json_deb_asset.sh`，通过调用参数提供元数据地址、版本过滤器、资产地址过滤器、URL 正则、文件名模板、包名、架构和 SHA-256 字段。
- 原因与依据：官方更新接口的 `version` 包含构建号，DEB 的 `Version` 使用三段版本；版本过滤器 `.version | split(".") | .[0:3] | join(".")` 只向公共脚本提供 DEB 校验所需的版本。文件名模板保留构建号匹配，SHA-256 取自同一份 JSON 的 `.sha256hash`。
- 影响：公共脚本负责下载、摘要和 DEB 元数据校验；应用脚本不重复解析 JSON，不修改公共实现。该下载命令没有赋值给应用脚本的 `VERSION`。

## AUR 依赖、版本、图标和桌面入口

- 位置：AUR 包安装、元数据设置和版本读取均保留在原有执行阶段。
- 差异：继续安装 `workbuddy fcitx5-gtk dpkg`；版本仍由原位置的三行 `pacman -Q workbuddy` 代码读取。图标和 desktop 继续使用 AUR 安装结果。
- 原因：这些内容已由用户明确确认保留。AUR 提供构建依赖及版本记录，最终程序文件单独从官方 DEB 解包取得。
- 影响：不移动版本读取代码，不用下载命令返回的 DEB 校验版本覆盖 AUR 版本，不改图标、desktop 或其参数。

## 额外运行命令

- 位置：原有 `quick-sharun` 调用。
- 差异：继续显式传入 `/usr/bin/ls`、`/usr/bin/mkdir`、`/usr/bin/ln`、`/usr/bin/grep`。
- 原因与依据：原有故障、完整报错和处理记录见 [hardcoded.md](./hardcoded.md) 与 [README.md](../README.md)。
- 影响：本次不修改这些参数、中文 locale、AppImage 封装或版本保存逻辑。

## 验证范围

提交前核对 Bash 语法、官方下载调用、SHA-256、DEB 包名与版本及架构、解包目录和完整文件差异。本次不在本地构建 AppImage 或启动 WorkBuddy；新成品的构建和运行结果不属于上述检查结论。
