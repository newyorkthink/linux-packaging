# RustDesk 上游打包差异

参考仓库为 `pkgforge-dev/RustDesk-AppImage-Enhanced`，核对的 commit 为 `85c6e0eeb2fb537e784a20472e03516336b390a8`。其 [工作流](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/.github/workflows/appimage.yml#L24-L32) 在 Arch 容器中先执行依赖脚本，再调用打包脚本。

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 软件来源与依赖 | 未启用 | [上游依赖脚本](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/get-dependencies.sh#L7-L20)，对应原文见下节。实际下载入口见[本仓库脚本](../build_rustdesk.sh#L22)。 | 上游从系统包构建并安装额外的音视频依赖，未说明各包的选择原因。本仓库从 RustDesk 正式 Release 取得已有运行目录的 AppImage。 |
| 版本读取、资源选择与依赖收集 | 未启用 | [上游构建脚本](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/make-appimage.sh#L5-L22)，对应原文见下节。本仓库由同一下载入口返回版本，经公共脚本[解包](../build_rustdesk.sh#L25)并[直接封装](../build_rustdesk.sh#L42)。 | 上游 README 说明 quick-sharun 用于生成便携包。本仓库保留官方 AppImage 的 ELF AppRun、程序与私有库布局。 |
| 自更新 Hook 与 zsync 信息 | 未启用 | [上游构建脚本](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/make-appimage.sh#L9-L10)，对应原文见下节。 | [上游说明](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/README.md#L28-L30)记录该 Hook 用于提示检查更新。本仓库沿用现有发布流程和固定资产名。 |
| 构建内运行检查 | 未启用 | [上游构建脚本](https://github.com/pkgforge-dev/RustDesk-AppImage-Enhanced/blob/85c6e0eeb2fb537e784a20472e03516336b390a8/make-appimage.sh#L24-L26)，对应原文见下节。 | 上游注释将其用于 CI 中的短时启动检查。本仓库的公共封装入口负责检查产物并写入版本。 |

## 对应上游原文

依赖准备与包来源。

```sh
pacman -Syu --noconfirm pipewire-audio pipewire-jack gst-plugins-bad
get-debloated-pkgs --add-common --prefer-nano intel-media-driver-mini
if [ "$ARCH" = 'x86_64' ]; then
	pacman -S --noconfirm libva-intel-driver
fi
make-aur-package --chaotic-aur rustdesk
```

版本、资源、封装、自更新与启动检查。

```sh
ARCH=$(uname -m)
VERSION=$(pacman -Q rustdesk | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/rustdesk.png
export DESKTOP=/usr/share/applications/rustdesk.desktop
export DEPLOY_PIPEWIRE=1
export DEPLOY_GSTREAMER=1

# Deploy dependencies
quick-sharun /usr/bin/rustdesk
quick-sharun --make-appimage
# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
```
