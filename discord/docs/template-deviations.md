# Discord 模板差异说明

## 专用流程与标准参考

[build_discord.sh](../build_discord.sh) 保留官方完整分发包和模块的专用流程，登记在 [打包分类](../../docs/packaging-classification.md#专用打包流程)。现有 13 份固定模板不能直接覆盖这条流程，不新增模板，也不把官网 DEB 或 tar.gz 中的 bootstrap 作为完整主程序。

通用部分优先对照 [electron-deb.sh](../../templates/quick-sharun/electron-deb.sh)、[Cursor](../../cursor/build_cursor.sh) 和 [Obsidian](../../obsidian/build_obsidian.sh)。适用的初始化、架构与元数据注释、中文 locale、封装和版本保存片段沿用现有标准；参数按 Discord 的真实来源与目录填写。

## 复用的公共入口

| 阶段 | 公共入口 | 当前参数或作用 |
| --- | --- | --- |
| 构建环境 | `common/arch/install_packages.sh` | 先执行 `--base`，再安装既有运行依赖；不额外安装 bootstrap 或 DEB 工具。 |
| 工作目录 | `common/build/prepare_x86_64_workspace.sh` | 清理项目内的 `AppDir`、`dist`、`source`，重新创建后两者；真实程序子目录仍由脚本建立。 |
| 独立下载 | `common/download/download_file.sh` | 下载官网桌面资源、同次 stable manifest、完整主程序及全部模块；主程序和模块使用各自的官方 SHA-256。 |
| 解包 | `common/archive/extract_archive.sh` | 统一提取 tar.gz 与 Brotli 压缩的 `full.distro`，保持官方 `files/` 布局。 |
| 包内版本 | `common/build/read_app_version.sh` | 使用 `package-json` 读取 `AppDir/shared/bin/resources/build_info.json` 的字符串 `version`。 |
| 最终产物 | `common/build/save_appimage_version.sh` | AppImage 生成后保存 `dist/version.txt`，并统一最终产物的执行权限。 |

清单中的 `full.host_version` 是数组，继续由 `jq` 还原为点分版本；不把该清单交给只读取字符串 `version` 的 `package-json` 模式。包内版本与清单版本不一致时停止构建。

## 不适用的模板阶段

- 单个 DEB 的下载、解包和 `dpkg` 依赖不适用。官网 tar.gz 仅用于提取官方 desktop 和 PNG，完整主程序与模块来自同一 stable manifest 的多份 `full.distro`。
- `AppDir/bin` 不是本程序的真实程序树。完整应用固定放在 `AppDir/shared/bin`，launcher 相邻资源链接、工作目录及库路径保留原有处理。
- 系统图标与系统 desktop 的模板行不适用。两项资源均取自单独下载的官网归档。
- 不设置 `DEPLOY_GTK=1`。保留现有显式 IBus、Fcitx5 输入模块和动态加载库扫描。
- 不用模板生成结果覆盖完整专用脚本；候选 `build_discord_news.sh` 不参与正式构建。

## 模块加载配置与写入位置

完整程序复制到真实程序目录后，仅将其 `resources/build_info.json` 中的 `newUpdater` 设为 `false`，随后读取包内版本并与清单比较。该设置使程序继续查找现有 hook 部署的 `discord/<版本>/modules`，不改变 hook 路径。

模块以只读模板保存在 `AppDir/share/discord-modules`；启动时由原有 hook 复制到用户可写配置目录，并保留 `installed.json`、Krisp 补丁摘要和 `KMS/logs`。不把这些运行模块改为指向只读挂载点的符号链接，也不新增 `localModulesRoot` 或 `NODE_PRESERVE_SYMLINKS`。

## 保留的专属兼容处理

保留 `DEPLOY_OPENGL=0`、`DEPLOY_VULKAN=0`、`NO_STRIP=1`，不删除扫描实际收集的 Mesa 或 LLVM 库。依赖扫描完成后，从已校验的官方完整包恢复 `Discord` 主程序，并用 `cmp` 确认逐字节一致。

Krisp 仍只定位 `IsSignedByDiscord` 检查失败后的预期 JE 指令，并替换为等长 NOP。符号、代码段或指令不符合预期，或者补丁位置的实际字节不匹配时，立即停止构建，不尝试其他补丁方式。

固定路径和配置见 [hardcoded.md](./hardcoded.md)，上游取舍见 [pkgforge-differences.md](./pkgforge-differences.md)，历史实机记录及本次故障见 [README](../README.md)。正式构建仍使用现有统一 workflow，不增加专用 Job 或测试步骤。
