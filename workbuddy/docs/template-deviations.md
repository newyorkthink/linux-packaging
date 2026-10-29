# WorkBuddy 标准模板差异

`build_workbuddy.sh` 遵守 [Electron 直接下载安装包标准模板](../../anylinux_projects.md#直接下载安装包的标准模板)。本文件记录允许变化的程序参数及其依据，通用注释、执行位置、代码结构和空行与另一份标准脚本逐行一致。

## JSON 下载入口与 DEB 校验

- 位置：清理构建目录之后、设置打包元数据之前。
- 参数：使用 `common/download/download_json_deb_asset.sh`，将官方 JSON 地址、版本和 URL 字段、下载地址正则、文件名模板、包名、架构和摘要字段作为调用参数。
- 依据与影响：接口版本包含构建号，DEB 的 `Version` 使用三段版本；过滤器只提取 DEB 校验所需的前三段，文件名匹配保留构建号，SHA-256 来自同一 JSON 的 `.sha256hash`。下载阶段的校验版本不覆盖应用脚本的 `VERSION`。

## AUR 依赖、版本、图标和桌面入口

- 位置：AUR 安装、打包元数据和版本读取都保留在原有阶段。
- 参数：安装 `workbuddy fcitx5-gtk dpkg`，版本调用为 `read_app_version.sh pacman workbuddy`；图标和 desktop 取自已安装的软件包。
- 依据与影响：公共版本入口复用现有 Arch 包版本读取脚本，保留去掉 epoch 和 pkgrel 的规则。最终程序文件仍从单独下载的官方 DEB 提取，不增加 Cursor 的构建版本文件或 desktop 写入参数。

## 额外运行命令

- 位置：原有 quick-sharun 调用。
- 参数：保留 `/usr/bin/ls`、`/usr/bin/mkdir`、`/usr/bin/ln`、`/usr/bin/grep`。
- 依据与影响：对应故障和完整报错继续保存在 [hardcoded.md](hardcoded.md)，不把这些专属参数复制给其他应用。

## 验证边界

模板核对覆盖总行数、注释、空行、命令结构和执行顺序；程序名、软件包、路径、下载与版本参数及额外运行命令按上述真实差异保留。公共入口的语法和行为检查不等于 AppImage 构建或实机运行验证。
