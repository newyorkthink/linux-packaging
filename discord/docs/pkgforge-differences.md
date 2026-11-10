# Discord 上游处理取舍

## 当前构建依据

正式入口 [build_discord.sh](../build_discord.sh) 按本次要求使用仓库 [LinuxDeploy GTK DEB 标准模板](../../templates/appimage/linuxdeploy-gtk-deb.sh)，由生成器原样生成。程序来自 Discord 官方稳定版 DEB，构建直接在 Ubuntu 22.04 runner 中运行。生成参数和公共入口见[模板差异](./template-deviations.md)。

pkgforge-dev 的 quick-sharun 方案保留为旧版参考，不与本次标准生成结果拼接。原 quick 流程逐字保存在 [build_discord_old.sh](../build_discord_old.sh)，不参与 Actions。

## 已核对的旧版参考

此前核对 [pkgforge-dev/Discord-AppImage](https://github.com/pkgforge-dev/Discord-AppImage/tree/3621ca5185b9f494894aaaef25e5208316bb74ac) 的 `3621ca5185b9f494894aaaef25e5208316bb74ac` 提交：

- [get-dependencies.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/get-dependencies.sh)：stable manifest、完整主程序和模块下载。
- [make-appimage.sh](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/make-appimage.sh)：quick-sharun 的扫描及封装。
- [disable-discord-updater.hook](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/AppDir/bin/disable-discord-updater.hook)：模块链接与更新器设置。
- [appimage.yml](https://github.com/pkgforge-dev/Discord-AppImage/blob/3621ca5185b9f494894aaaef25e5208316bb74ac/.github/workflows/appimage.yml)：Arch 容器中的构建与发布。

| 旧方案处理 | 本次标准生成范围 |
| --- | --- |
| 通过 manifest 下载完整主程序及模块 | 新版使用官方 DEB 来源，不带入该下载逻辑。 |
| 模块部署 hook、用户更新器设置与 `NODE_PRESERVE_SYMLINKS` | 新版不加入这些步骤或变量。 |
| quick-sharun 扫描、图形开关和 Krisp 处理 | 仅保留旧备份，不移植到 LinuxDeploy 脚本。 |
| Arch 容器 | 新版使用独立 Ubuntu runner，遵守 LinuxDeploy 禁止容器的要求。 |

此前 Flathub 配置及 `newUpdater` 问题的核对属于旧 quick 流程，不作为本次新增补丁的依据。原始模块故障、当时处理及历史实机结果继续保留在 [README](../README.md)；新路线的 AppImage 构建与桌面运行尚未验证。
