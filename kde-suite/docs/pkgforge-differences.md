# KDE Suite 中 Filelight 的 pkgforge-dev 打包取舍

本页只核对本次 Filelight 菜单问题，不扩展为整个套件的官方打包审计。所读官方源码快照为 [`pkgforge-dev/Filelight-AppImage@45ecd9e746e27161a1a74b0a95b1cd6aded3f018`](https://github.com/pkgforge-dev/Filelight-AppImage/tree/45ecd9e746e27161a1a74b0a95b1cd6aded3f018)。快照仅用于追溯证据，不锁定应用或打包工具版本。

## 已读原文

[`make-appimage.sh`](https://github.com/pkgforge-dev/Filelight-AppImage/blob/45ecd9e746e27161a1a74b0a95b1cd6aded3f018/make-appimage.sh#L9)：

```sh
export ADD_HOOKS="self-updater.hook"
export ALWAYS_SOFTWARE=1
quick-sharun /usr/bin/filelight
quick-sharun --make-appimage
quick-sharun --test ./dist/*.AppImage
```

[`get-dependencies.sh`](https://github.com/pkgforge-dev/Filelight-AppImage/blob/45ecd9e746e27161a1a74b0a95b1cd6aded3f018/get-dependencies.sh#L9)：

```sh
pacman -Syu --noconfirm filelight kvantum qt6ct
get-debloated-pkgs --add-common --prefer-nano kiconthemes-mini
```

[`appimage.yml`](https://github.com/pkgforge-dev/Filelight-AppImage/blob/45ecd9e746e27161a1a74b0a95b1cd6aded3f018/.github/workflows/appimage.yml#L24) 使用独立 Arch 容器并调用这些脚本。没有 Filelight 专用菜单 QML 补丁、字体修复或启动包装；无需臆造不存在的官方菜单处理。

## 本次取舍

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 从 Arch 官方仓库安装并收集真实程序 | 保留本仓库既有流程，本次不改 | [`build_core.sh`](../build_core.sh) 已安装 `filelight`，并在原有多目标调用中收集 `/usr/bin/filelight`；[构建入口](../build_kde_suite.sh) 最终由 `quick-sharun --make-appimage` 完成封装 | [Arch 官方二进制包](https://archlinux.org/packages/extra/x86_64/filelight/) 可用，套件已有依赖部署；不是本次新增原样官方代码。 |
| 官方主题依赖安装、瘦身包替换 | 官方原命令未启用；保留本仓库既有安装和主题部署 | 本次无对应新增执行代码 | 当前套件已有 Qt6ct、Kvantum、Breeze 与 KDE 图标组件；没有证据表明菜单问题需要替换为 `kiconthemes-mini`。官方未说明这些命令与菜单重叠的因果关系。 |
| `ADD_HOOKS=self-updater.hook` | 未启用 | 本次无对应执行代码 | 本任务是菜单布局；不改变套件既有更新与发布方式。官方未说明它能解决菜单问题。 |
| `ALWAYS_SOFTWARE=1` | 未启用 | 本次无对应执行代码 | 没有本次故障需要强制软件渲染的证据；官方未说明对这处菜单问题的作用。 |
| `quick-sharun --test ./dist/*.AppImage` | 未启用 | 本次无对应执行代码 | 不增加测试调用或重复构建；保留本仓库既有构建检查。官方未说明此命令验证了菜单文字与快捷键的布局。 |
| Filelight 单程序 `org.kde.desktop` 包装 | 本仓库新增兼容处理；非官方原样复用 | [`deploy_suite_apps.sh`](../deploy_suite_apps.sh)；完整代码见 [模板差异](./template-deviations.md) | 依据 Filelight 上游默认样式与本目录 Haruna 已验证模式处理；不修改 Filelight 源码、公共 Hook 或其他应用样式。本次尚未实机验证。 |

本次只读核对不能证明官方独立 AppImage 是否在同一环境中出现相同现象，也不能把本仓库新增包装描述成官方修复。进一步的字体外观问题与菜单布局分别判断。
