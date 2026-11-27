# Discord 上游处理取舍

## 本次核对来源

完整分发参考 [pkgforge-dev/Discord-AppImage](https://github.com/pkgforge-dev/Discord-AppImage/tree/3621ca5185b9f494894aaaef25e5208316bb74ac) 的 `3621ca5185b9f494894aaaef25e5208316bb74ac` 提交：

- [get-dependencies.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/get-dependencies.sh)：使用官方 stable manifest 下载完整主程序与原生模块，生成 `installed.json`。
- [make-appimage.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/make-appimage.sh)：quick-sharun 的依赖扫描及封装。
- [disable-discord-updater.hook](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/AppDir/bin/disable-discord-updater.hook)：旧 quick 方案的模块部署参考。

LinuxDeploy 扫描范围核对官方提交 `07333c6e942c7d71782b66be924c5d867f9dfdfc` 的 [appdir.cpp](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/core/appdir.cpp)：`usr/bin` 识别可执行文件，`usr/lib` 递归识别 ELF 并部署依赖；扫描后会处理 RPATH。因此完整程序放入 `usr/lib/discord` 参与扫描，部署后恢复官方主程序原文件。模块原文件放在 `usr/share/discord-modules`，其已确认的动态加载依赖显式收集。

完整客户端的运行依赖补查 [NixOS 当前 Linux 实现](https://github.com/NixOS/nixpkgs/blob/c0f37fa6dfb282ccf80dfeec471b984e276a7ce9/pkgs/by-name/di/discord/linux.nix)：包含 C++、PulseAudio 及 NSS 等运行库，并明确说明未使用的 `discord_dispatch` 仍链接旧 OpenSSL。本次不让模块模板参与全量 ELF 改写，保留其原文件；按明确的实际运行库列表准备 C++、PulseAudio 等依赖，不为该未使用模块引入旧 OpenSSL。

## 当前处理

| 上游或旧版行为 | 本次取舍 |
| --- | --- |
| 从 stable manifest 下载完整主程序和原生模块 | 采用；所有下载复用公共入口，并核对清单中的官方 SHA-256。 |
| 使用 `Discord-Updater/1` | 采用官方分发所需的客户端标识，由公共下载入口接收，不自行实现下载器。 |
| Arch 容器、quick-sharun 和 `AppDir/bin` | 保留 LinuxDeploy 的 Ubuntu runner、标准 AppRun、GTK3 部署和公共最终封装；真实程序改放 `usr/lib/discord` 以参与扫描。 |
| 模块链接到用户版本目录 | 继续使用可写复制，按 1.0.169 实机日志部署到 `discord/module_data`；通过普通 AppRun 调用准备，不创建 linuxdeploy hook。 |
| 按 Arch 安装包读取版本 | 最终版本改取同次完整程序配置，并与 manifest 强制比对。 |
| 图形开关、自更新、系统升级与上游测试 | 不迁入本次来源修复。 |

恢复的完整来源、模块复制和主程序比对均对应已有实际问题；旧 quick 的 Krisp JE/NOP 补丁未恢复。具体位置、生成参数与验证事实见[模板差异](./template-deviations.md)及 [README](../README.md)。
