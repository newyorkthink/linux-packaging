# Discord 固定配置说明

## 程序来源与版本

| 配置 | 当前取值或规则 | 用途与依据 |
| --- | --- | --- |
| 发布通道与架构 | stable、Linux、x64；构建机仅支持 x86_64 | 与当前完整分发包、模块地址及 Krisp 处理一致。 |
| 官网 tar.gz | 仅提取 `Discord/discord.desktop` 和 `Discord/discord.png` | 使用官方桌面资源，不以归档内 bootstrap 代替完整主程序。 |
| 主程序与模块 | 同一次 stable manifest 的多份 `full.distro` | 每份使用对应官方 SHA-256，通过公共入口下载和解包。 |
| 清单版本 | `full.host_version` 数组还原为点分版本 | 不能交给只读取字符串 `version` 的 `package-json` 模式。 |
| 包内版本 | 完整程序的 `resources/build_info.json` | 公共版本入口读取后与清单比较，不一致则停止构建。 |
| 最终产物 | `dist/discord.AppImage`、`dist/version.txt` | 由既有正式构建入口发布，版本保存和执行权限复用公共入口。 |

## 程序布局与模块目录

| 配置 | 当前取值或规则 | 用途与依据 |
| --- | --- | --- |
| 真实程序树 | `AppDir/shared/bin` | 保留 Electron 的相邻 ICU、PAK、locales、resources 和自带库。 |
| launcher 目录 | `AppDir/bin` | 保留工具入口及既有相邻资源链接，不把真实程序树迁入此处。 |
| 包内模块模板 | `AppDir/share/discord-modules` | 保存完整官方模块、已安装版本和 Krisp 补丁摘要。 |
| 包内更新器配置 | `newUpdater=false` | 使用现有部署 hook 对应的旧版模块根，解决 `module_data` 与版本目录不一致的问题。 |
| 可写模块目录 | `${XDG_CONFIG_HOME:-$HOME/.config}/discord/<版本>/modules` | 由现有 hook 完整复制模块；版本由本次已核对的包内配置确定。 |
| Krisp 日志目录 | 可写模块目录中的 `discord_krisp/KMS/logs` | 保留创建逻辑，避免模块运行时向只读挂载点写日志。 |

`<版本>` 表示当前实际程序版本。没有设置 `XDG_CONFIG_HOME` 时，配置根默认为当前用户的 `$HOME/.config`。本次只修改包内 `newUpdater`，不添加 `localModulesRoot`，不改部署 hook 的原目标和复制条件。

## 依赖收集与图形配置

| 配置 | 当前取值或规则 | 用途与依据 |
| --- | --- | --- |
| `DEPLOY_OPENGL` | `0` | 关闭宿主 OpenGL 驱动的主动部署，不删除动态扫描实际收集的库。 |
| `DEPLOY_VULKAN` | `0` | 关闭宿主 Vulkan 驱动的主动部署，保留 Discord 自带的图形运行库。 |
| `NO_STRIP` | `1` | 保留主程序和原生模块符号，延续既有 Krisp 兼容处理。 |
| GTK3 输入模块 | 明确扫描 `im-ibus.so` 与 `im-fcitx5.so` | 保留中文输入支持，不增加 `DEPLOY_GTK=1`。 |
| Chromium 与动态加载库 | 保留当前显式扫描列表 | 不照搬其他应用或上游的宽泛扫描，不预防性扩充依赖。 |
| `SHARUN_EXTRA_LIBRARY_PATH` | 在既有值前追加包内 `shared/bin` | 保留完整程序的相邻库搜索路径。 |
| `SHARUN_WORKING_DIR` | 包内 `shared/bin` | 保持真实程序及其资源的工作目录。 |

## 官方主程序与 Krisp

依赖扫描后必须从已校验的官方完整分发包恢复 `Discord` 主程序，并由 `cmp` 确认逐字节一致。

`discord_krisp.node` 仍只修改 `IsSignedByDiscord` 检查失败后的预期 JE 指令，将其替换为等长 NOP；符号、代码段或指令无法识别，或者补丁位置的字节不匹配时立即停止。补丁摘要写入模块模板，现有部署 hook 据此更新同一程序版本的模块。

## 中文环境与原始问题

包内生成 `zh_CN.UTF-8` locale，保留 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8` 和包内 `LOCPATH`。不覆盖会话选择的输入法实现。

原始启动错误为 `Cannot find module 'discord_desktop_core'`，调用栈来自包内 `app.asar` 的 `bundle.js`；日志搜索 `discord/module_data`，已有 hook 写入 `discord/<版本>/modules`。完整故障与历史实机记录见 [README](../README.md)，来源和模板取舍见 [模板差异](./template-deviations.md) 与 [上游取舍](./pkgforge-differences.md)。
