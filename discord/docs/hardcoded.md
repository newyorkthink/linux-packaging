# Discord 固定配置说明

## 当前 LinuxDeploy 配置

| 配置 | 当前取值或规则 | 用途与依据 |
| --- | --- | --- |
| 来源 | 官方稳定版 Linux DEB 动态入口 | 不固定 Discord 版本，不使用旧 quick 流程的多份 `full.distro`。 |
| 包身份 | `discord` / `amd64` | 公共入口在安装前核对实际包名和架构。 |
| 版本 | 同一份 DEB 的完整 `Version` 元数据 | 公共入口只向 stdout 返回版本，不用下载链接或目录名推测。 |
| 官方摘要 | 本次未提供 | 公共入口记录实际文件 SHA-256；记录不等于已比对官方摘要。 |
| 构建环境 | Ubuntu 22.04，x86_64 | 独立 Job 直接构建，不进入 Arch 容器 matrix。 |
| 真实主程序 | `AppDir/usr/share/discord/Discord` | 保留官方 DEB 原始布局，AppRun 直接执行该文件。 |
| 应用和相邻库目录 | `usr/share/discord` | 标准 AppRun 将其加入程序和动态库搜索路径，同时保留标准包内目录与原环境路径。 |
| GTK 插件 | `DEPLOY_GTK_VERSION=3` | 使用标准 GTK DEB 模板的 GTK3 部署阶段。 |
| GIO 模块目录 | `usr/lib/x86_64-linux-gnu/gio/modules` | AppRun 指向包内 Ubuntu amd64 模块目录。 |
| 最终产物 | `dist/discord.AppImage`、`dist/version.txt` | 由公共封装入口处理产物权限、SHA-256 和版本保存。 |

官方 DEB URL、生成参数和公共调用见[模板差异](./template-deviations.md)。软件和打包工具均通过动态入口取得，固定架构和目录表示本项目的包布局，不表示固定软件版本。

## 旧流程与验证范围

旧版 `newUpdater=false`、可写模块复制 hook、Krisp 补丁、主程序恢复、quick-sharun 图形开关、显式扫描及中文 locale 仅保留在 [build_discord_old.sh](../build_discord_old.sh)。这些内容未加入新标准脚本，旧故障与实机记录保留在 [README](../README.md)。

新路线不手工创建 linuxdeploy hook 或 `AppRun.wrapped`。生成器语法检查与静态核对已完成，实际构建、入口产物和桌面运行尚未验证。
