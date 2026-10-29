# WorkBuddy 标准模板差异

`build_workbuddy.sh` 遵守 [Electron 直接下载安装包标准模板](../../anylinux_projects.md#直接下载安装包的标准模板)。本文件记录允许变化的程序参数和已批准的专属扩展。除下述启动 PATH hook 外，其余通用注释、执行位置、代码结构和空行与标准模板保持一致；新增代码段不复制到其他应用。

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

## 启动 PATH hook

- 位置：原有中文环境配置之后、最终 `quick-sharun --make-appimage` 之前，生成 `AppDir/bin/99-workbuddy-host-path.hook`。
- 内容：`export PATH="/usr/bin:/bin${PATH:+:$PATH}"`。生成代码、注释和空行组成一个独立扩展段，其余原有代码和空行不移动。
- 依据：已发布产物顶层 `bin/cat`、`bin/head` 等文件与资源树内的代理脚本相同，使用 dash 解析时在第 620 行报错；原始报错见 [hardcoded.md](hardcoded.md#启动-path-与-99-workbuddy-host-pathhook)。
- 影响：AppRun 按文件名顺序加载 hook，本 hook 在现有默认 hook 之后将系统命令放在 PATH 最前，并保留原有 PATH 作为后备。它不改写资源树内的代理脚本，也不增加禁用沙盒参数；应用之后主动设置的命令环境不受本 hook 控制。
- 保留项：`/usr/bin/ls /usr/bin/mkdir /usr/bin/ln /usr/bin/grep` 及其顺序原样保留。由于新增这一专属扩展段，本脚本总行数与另一份标准脚本不同；扣除该段后，原有模板结构保持不变，通用标准文档和其他应用不修改。

## 验证边界

模板核对覆盖专属扩展段及其余代码的行数、注释、空行、命令结构和执行顺序；程序名、软件包、路径、下载与版本参数及额外运行命令按上述真实差异保留。已在解包产物的隔离副本中验证实际 AppRun 与 sharun 启动链上的 hook 顺序、系统命令优先及包内命令后备；该检查不等于新 AppImage 中 AI 命令执行和应用沙盒行为已经实机通过。
