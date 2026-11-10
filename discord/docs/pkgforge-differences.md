# Discord 上游处理取舍

## 核对来源

本次核对 [pkgforge-dev/Discord-AppImage](https://github.com/pkgforge-dev/Discord-AppImage/tree/3621ca5185b9f494894aaaef25e5208316bb74ac) 的 `3621ca5185b9f494894aaaef25e5208316bb74ac` 提交：

- [get-dependencies.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/get-dependencies.sh)：安装依赖，读取 stable manifest，下载完整主程序和原生模块，生成 `installed.json` 并预建 Krisp 日志目录。
- [make-appimage.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/make-appimage.sh)：设置打包变量、扫描程序与附加库，再封装 AppImage。
- [disable-discord-updater.hook](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/AppDir/bin/disable-discord-updater.hook)：设置 `NODE_PRESERVE_SYMLINKS`，写入 `SKIP_HOST_UPDATE`，并把包内模块链接到版本配置目录。
- [appimage.yml](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/.github/workflows/appimage.yml)：在 Arch 容器中分别执行依赖和封装脚本，再交给上游发布流程。

本仓库优先复用 [固定模板](../../templates/quick-sharun/electron-deb.sh) 中适用的通用片段和已经标准化的公共入口，上游实现用于核实 Discord 完整分发和模块结构。具体模板差异见 [template-deviations.md](./template-deviations.md)。

## 采用的思路

| 上游处理 | 本仓库处理与依据 |
| --- | --- |
| 从 stable manifest 读取 `full.url` 并下载完整主程序 | 保留完整分发来源，通过公共下载入口核对同次 manifest 的 `package_sha256`，由公共归档入口解包。 |
| 下载原生模块并带入 AppImage | 保留 manifest 中全部模块及各自摘要，不在首次启动时临时下载桌面核心模块。 |
| 生成模块 `installed.json` | 保留官方模块版本记录，供现有可写复制 hook 判断是否需要更新。 |
| 预建 `discord_krisp/KMS/logs` | 保留日志目录；模块复制到用户配置目录后，Krisp 的日志写入仍位于可写目录。 |

## 保留本仓库实现的部分

| 上游原文或行为 | 当前取舍 |
| --- | --- |
| 真实程序放入 `./AppDir/bin`，扫描 `./AppDir/bin/*` | 保留本仓库 `AppDir/shared/bin` 真实程序树、显式 Chromium 库和两个 GTK3 输入模块，不改动已有相邻资源布局。 |
| hook 对用户模块目录执行 `ln -sf`，并导出 `NODE_PRESERVE_SYMLINKS=1` | 保留现有完整文件复制机制，确保模块目录可写；不引入该变量，也不把模块根指向只读挂载点。 |
| hook 写入 `SKIP_HOST_UPDATE=true` | 不引入关闭宿主版本更新检查的行为；当前修复只调整包内模块加载方式，不写这项用户设置。 |
| `export DEPLOY_OPENGL=1`、`export DEPLOY_VULKAN=1` | 保留本仓库已确认的两个 `0` 配置及 `NO_STRIP=1`；显式扫描列表保持原有范围。 |
| `export DEPLOY_PULSE=1` | 不新增该开关；保留当前 `libpulse` 安装与显式扫描。 |
| `pacman -Syu` 和 `get-debloated-pkgs` | 不复制系统升级或精简包流程，统一使用本仓库安装入口及既有应用依赖。 |
| `UPINFO`、`ADD_HOOKS` 和构建后的 `quick-sharun --test` | 不新增自更新配置或测试步骤，继续由本仓库现有构建与发布入口处理。 |

官方主程序的扫描后恢复、逐字节比较、Krisp 条件跳转补丁及补丁摘要更新继续沿用本仓库历史处理，不以不同的上游扫描方式替代。

## 本次模块根修复

[Flathub 当前配置](https://github.com/flathub/com.discordapp.Discord/blob/master/com.discordapp.Discord.yaml#L112) 同时设置 `newUpdater=false` 和它自己的 `localModulesRoot`，并非只修改前者。该路径属于 Flatpak 布局，不能直接作为本仓库 AppImage 的模块根。

本仓库已有可写模块复制 hook，因此仅在完整程序复制后设置包内 `newUpdater=false`，保持原有版本目录。包内 `version` 由公共入口读取并与官方清单比较，不设置 `localModulesRoot`。问题证据和处理记录见 [README](../README.md#2026-11-10修复-10169-的模块目录不一致)。
