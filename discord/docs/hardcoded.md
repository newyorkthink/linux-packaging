# Discord 固定配置说明

## 来源与实际版本

| 配置 | 当前取值或规则 | 用途 |
| --- | --- | --- |
| 引导 DEB | 官方稳定版 HTTPS DEB 动态入口 | 安装依赖并取得官方 desktop、图标；不作为真实客户端或最终版本来源。 |
| 包身份 | `discord` / `amd64` | 安装引导 DEB 前核对包名和架构。 |
| 完整分发 | stable、Linux、x64 的官方 manifest | 取得完整主程序和全部模块的 `full.distro` URL 及官方 SHA-256。 |
| 更新器标识 | `Discord-Updater/1` | 按官方更新分发方式请求 manifest、主程序及模块。 |
| 成品版本 | 完整程序 `resources/build_info.json` 的字符串 `version` | 必须与同次清单的 `full.host_version` 一致，覆盖引导 DEB 的临时版本。 |

## 程序与可写数据

| 配置 | 当前取值或规则 | 用途 |
| --- | --- | --- |
| 构建环境 | Ubuntu 22.04、x86_64 | 保留现有独立 Job，不使用 Arch 容器。 |
| 主程序 | `AppDir/usr/lib/discord/Discord` | 保持完整分发的相邻资源，同时参与 linuxdeploy 的 `usr/lib` 扫描。 |
| 包内模块 | `AppDir/usr/share/discord-modules` | 保存全部模块、已安装版本、实际主程序版本和来源标记。 |
| 更新器配置 | 包内 `newUpdater=false` | 模块从当前用户的版本目录加载，不指向只读挂载点。 |
| 可写模块 | `${XDG_CONFIG_HOME:-$HOME/.config}/discord/<版本>/modules` | 来源变化或桌面核心缺失时部署当前版本模块；Krisp 日志也写到这里。 |
| GTK | `DEPLOY_GTK_VERSION=3` | 保留标准 GTK3 部署与 GIO 模块目录。 |
| 最终产物 | `dist/discord.AppImage`、`dist/version.txt` | 由公共最终封装入口处理执行权限、SHA-256 和完整主程序实际版本。 |

完整程序和每个模块都核对官方摘要。依赖部署后恢复本次官方主程序，主程序必须与来源逐字节一致；模块模板不交给 ELF 改写。动态加载的运行库按明确列表收集，NSS/NSPR 使用同一构建环境的公共准备入口。只复制当前版本的模块缓存，不将整个 Discord 配置目录作为清理目标。

完整入口、`app.asar`、ICU 或 `discord_desktop_core` 缺失时停止构建。生成及恢复位置见[模板差异](./template-deviations.md)，历史问题见 [README](../README.md)。旧 quick 备份保持原样，本次没有启用其 Krisp 二进制补丁、图形开关或中文环境。
