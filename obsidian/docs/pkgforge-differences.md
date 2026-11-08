# Obsidian 上游打包差异与取舍

## 核对来源

- 参考仓库：[Obsidian-AppImage-Enhanced](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/tree/138798b2139d4cafd8e3f86ada4c804397585a2a)，核对 commit `138798b2139d4cafd8e3f86ada4c804397585a2a`。
- 官方打包文件：[get-dependencies.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/get-dependencies.sh)、[make-appimage.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/make-appimage.sh)、[AppDir/obsidian.desktop](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/AppDir/obsidian.desktop)、[workflow](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/.github/workflows/appimage.yml)。
- 本仓库替换前脚本：[build_obsidian.sh](https://github.com/newyorkthink/linux-packaging/blob/10b63b344943519468de0c994ae0bb0e37c5c281/obsidian/build_obsidian.sh)；现行正式脚本：[build_obsidian.sh](../build_obsidian.sh)。

上游从官方 tar.gz 准备程序并使用 quick-sharun 封装。本仓库改用官方正式 Release DEB，保留完整 Electron 程序目录；下载及部署命令分别按实际来源记录，不把不同命令标成官方原样复用。

## 采用与未采用

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装程序及依赖 | 采用仓库标准公共安装入口；上游直接 `pacman -Syu` 与 `get-debloated-pkgs` 未启用。 | [基础包](../build_obsidian.sh#L11)、[应用依赖](../build_obsidian.sh#L13)。 | 安装 AUR `obsidian-bin`、图形、输入法和音频依赖；不直接复制上游升级及瘦身操作。 |
| 官方下载和完整程序目录 | 采用仓库标准 DEB 下载；上游 tar.gz 下载和移动命令未启用。 | [下载](../build_obsidian.sh#L21)、[复制](../build_obsidian.sh#L27)。 | 公共入口核对 GitHub SHA-256、DEB 包名与架构，再完整复制 `opt/Obsidian`。 |
| OpenGL、Vulkan、PipeWire | 采用仓库原脚本的三项专属部署配置；不是直接复用 pkgforge 上游。 | [OpenGL](../build_obsidian.sh#L48)、[Vulkan](../build_obsidian.sh#L50)、[PipeWire](../build_obsidian.sh#L52)。 | 部署图形及音频运行组件。上游未说明这些本仓库原有选项的必要性。 |
| NSS、hostname、GTK3 IBus | 采用仓库原有扫描目标；上游仅扫描程序目录。 | [收集](../build_obsidian.sh#L59)，完整命令见下节。 | 额外收集原脚本指定的库、命令及输入模块。 |
| 图标与 desktop | 使用安装包提供的系统资源；上游额外复制 `resources/icon.png` 与 `.DirIcon` 的命令未启用。 | [ICON](../build_obsidian.sh#L38)、[DESKTOP](../build_obsidian.sh#L40)。 | 不另外维护图标副本；从已有安装包路径取得桌面资源。 |
| 窗口类 | 采用原脚本的 `STARTUPWMCLASS=obsidian`。 | [窗口类](../build_obsidian.sh#L36)。 | 上游 desktop 为 `md.obsidian.Obsidian`；未迁移该值。 |
| quick-sharun 封装 | 采用仓库标准步骤，命令与上游相同。 | [封装](../build_obsidian.sh#L79)。 | quick-sharun 生成 AppRun 与 AppImage，不自写启动入口。 |
| 自更新及命名空间 hook | 未启用。 | 未启用 `ADD_HOOKS`、`UPINFO`，原文见下节。 | 上游 README 说明自更新会提示检查新版本；未引入相应 hook 和更新配置。 |
| 启动优化 | 未启用。 | 未启用 `OPTIMIZE_LAUNCH=1`，原文见下节。 | 不额外启用上游优化设置；上游未进一步说明应用的必要性。 |
| 构建后测试 | 未启用。 | 未启用 `quick-sharun --test ./dist/*.AppImage`。 | 不修改现有构建步骤以加入上游测试。 |
| 上游容器和发布 workflow | 未启用。 | [现有构建清单](../../.github/appimage-apps.json)。 | 本仓库仍按现有 Actions 调度和发布。 |
| 宿主协议注册 | 未启用额外 hook。 | 上游 desktop 声明 `MimeType=x-scheme-handler/obsidian;`。 | desktop 声明不等于宿主协议已注册，当前不声称外部回调已实现。 |

## 本仓库实际代码

以下命令在 [build_obsidian.sh](../build_obsidian.sh) 的对应阶段执行，属于本仓库标准集成及应用专属处理：

```bash
# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "obsidian-bin" dpkg gtk3 ibus libnotify libsecret libxss libxtst nss util-linux-libs xdg-utils alsa-lib libx11 libxrandr mesa libglvnd xorg-server xorg-server-common xorg-server-xvfb gcc-libs glibc lsof libxext libxi libxkbfile libxcomposite libxdamage libxfixes libva libvdpau pulseaudio pulseaudio-alsa pipewire-audio
# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" --tag-prefix "v" "obsidianmd/obsidian-releases" 'obsidian_{version}_amd64.deb' work/app.deb "obsidian" "amd64" > work/source-version.txt
# 整个程序目录原样放进 AppDir/bin。
cp -a "work/unpacked/opt/Obsidian/." AppDir/bin/
```

```bash
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1
# 本程序专属处理：部署 Vulkan 运行依赖。
export DEPLOY_VULKAN=1
# 本程序专属处理：部署 PipeWire 音频组件。
export DEPLOY_PIPEWIRE=1
```

```bash
# 收集程序及其运行依赖。
# 本程序专属处理：收集 hostname、NSS 安全库及 GTK3 IBus 输入模块。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
```

```bash
# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage
```

## 未启用的上游原始命令

下列命令取自上述固定 commit 的源码，仅作取舍记录，不在当前构建脚本执行：

```bash
get-debloated-pkgs --add-common --prefer-nano
cp -v ./AppDir/bin/resources/icon.png ./AppDir
cp -v ./AppDir/bin/resources/icon.png ./AppDir/.DirIcon
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export OPTIMIZE_LAUNCH=1
quick-sharun --test ./dist/*.AppImage
```

官方 README 解释了 self-updater 的更新提示用途；对其他专属开关没有逐项说明原因，故不以推测补充官方原始理由。具体启用范围与实际构建结果分别以当前脚本和 GitHub Actions 为准。
