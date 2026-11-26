# Rofi 上游 pkgforge-dev 打包差异与取舍

## 核实来源

- **官方仓库**：[pkgforge-dev/rofi-AppImage](https://github.com/pkgforge-dev/rofi-AppImage)
- **固定提交**：`84953049a6ef24a02b722e4072c6dbc3e8d4fca9`
- **已读原文件**：
  - [get-dependencies.sh](https://github.com/pkgforge-dev/rofi-AppImage/blob/84953049a6ef24a02b722e4072c6dbc3e8d4fca9/get-dependencies.sh)
  - [make-appimage.sh](https://github.com/pkgforge-dev/rofi-AppImage/blob/84953049a6ef24a02b722e4072c6dbc3e8d4fca9/make-appimage.sh)
  - [AppDir/bin/rofi-datadir.src.hook](https://github.com/pkgforge-dev/rofi-AppImage/blob/84953049a6ef24a02b722e4072c6dbc3e8d4fca9/AppDir/bin/rofi-datadir.src.hook)
  - [.github/workflows/appimage.yml](https://github.com/pkgforge-dev/rofi-AppImage/blob/84953049a6ef24a02b722e4072c6dbc3e8d4fca9/.github/workflows/appimage.yml)
  - [README.md](https://github.com/pkgforge-dev/rofi-AppImage/blob/84953049a6ef24a02b722e4072c6dbc3e8d4fca9/README.md)

## 取舍总表

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 独立运行 hook `AppDir/bin/rofi-datadir.src.hook` | 采用（文件内容原样复用） | 本仓库独立文件 [rofi-datadir.src.hook](../rofi-datadir.src.hook)，并在 [build_rofi.sh](../build_rofi.sh#L40-L42) 复制：<br>`mkdir -p AppDir/bin`<br>`cp "$SCRIPT_DIR/rofi-datadir.src.hook" AppDir/bin/rofi-datadir.src.hook`（本仓库自写复制集成，hook 文件内容逐字复用官方） | **源码可核实作用**：启动时将 `${XDG_DATA_HOME:-~/.local/share}` 及 `/usr/local/share:/usr/share` 写入 `XDG_DATA_DIRS`，且在用户数据目录下不存在 `rofi/themes` 时复制包内 `$APPDIR/share/rofi/themes`。<br>**官方原因**：官方未说明原因（原文件、README 与 PR #33 均无说明）。<br>**依据与影响**：使无系统 `rofi` 主题目录的环境首次启动即可获得内置主题，同时保留宿主应用数据目录；若用户已有自定义 `rofi/themes` 目录则不覆盖。 |
| `export ICON` 与 `export DESKTOP` 系统路径 | 标准步骤一致 | [build_rofi.sh](../build_rofi.sh#L23-L26)：<br>`export ICON="/usr/share/icons/hicolor/scalable/apps/rofi.svg"`<br>`export DESKTOP="/usr/share/applications/rofi.desktop"`（标准模板步骤） | 与官方 `make-appimage.sh` 路径一致，直接使用 Arch 官方 `rofi` 软件包安装的图标与 desktop 文件。 |
| `quick-sharun` 扫描 `/usr/bin/rofi*` | 官方命令未启用（标准模板显式列表替代） | [build_rofi.sh](../build_rofi.sh#L38)：<br>`quick-sharun /usr/bin/rofi /usr/bin/rofi-sensible-terminal /usr/bin/rofi-theme-selector`（标准模板步骤） | 沿用本仓库既有显式入口列表，覆盖 `rofi` 包中的 3 个 `/usr/bin/rofi*` 可执行程序；避免在模板中引入无必要的通配扩展。 |
| `get-dependencies.sh` 从 `davatorium/rofi` 源码用 `meson` 编译 | 官方命令未启用（标准模板系统包替代） | [build_rofi.sh](../build_rofi.sh#L11-L13)：<br>`"$SCRIPT_DIR/../common/arch/install_packages.sh" --base`<br>`"$SCRIPT_DIR/../common/arch/install_packages.sh" "rofi" xorg-server xorg-server-common rofi-emoji bash cairo glibc libxcb libxkbcommon-x11 startup-notification wayland xcb-imdkit xcb-util xcb-util-cursor xcb-util-keysyms xcb-util-wm libva libvdpau`（标准模板步骤） | Arch 官方 `extra/rofi`（主线 2.x 已合并 Wayland 与 XCB 支持）直接提供预编译原生二进制，且本仓库同时保留 `rofi-emoji`；符合 Arch 官方仓库原生程序路线，无需现场拉源码编译。 |
| `get-debloated-pkgs --add-common --prefer-nano` | 未启用 | 未启用 | 官方未说明针对 `rofi` 的专用原因。按 [anylinux_projects.md](../../anylinux_projects.md#L215)，精简替换系统包不是本仓库默认步骤。 |
| `export URUNTIME_PRELOAD=1` | 未启用 | 未启用 | 官方未说明原因（随上游通用模板 PR #33 引入）。本仓库普通 Arch 原生程序未默认开启，暂不引入额外运行时变更。 |
| `ADD_HOOKS="self-updater.hook"`、`UPINFO`、`APPNAME=rofi`、`quick-sharun --test` | 未启用 | 未启用（文件名由 [build_rofi.sh](../build_rofi.sh#L30) `export OUTNAME="rofi.AppImage"` 固定，发布由 `.github/workflows/build.yml` 统一完成） | 属于上游自身的自更新与 CI 发布/测试流程，不适用于本仓库统一构建与 `latest` Release 机制。 |

## 上游原始代码摘录（commit `84953049a6ef24a02b722e4072c6dbc3e8d4fca9`）

### `AppDir/bin/rofi-datadir.src.hook`（已原样复用至 [rofi/rofi-datadir.src.hook](../rofi-datadir.src.hook)）

```sh
#!/bin/false

_datadir=${XDG_DATA_HOME:-~/.local/share}
_rofi_themes_dst=$_datadir/rofi/themes
_rofi_themes_src=$APPDIR/share/rofi/themes
XDG_DATA_DIRS=$_datadir:$XDG_DATA_DIRS:/usr/local/share:/usr/share
export XDG_DATA_DIRS

if [ ! -d "$_rofi_themes_dst" ] && [ -d "$_rofi_themes_src" ]; then
	mkdir -p "$_rofi_themes_dst"
	cp -r "$_rofi_themes_src"/. "$_rofi_themes_dst"
	>&2 echo "Copied rofi themes to $_rofi_themes_dst"
fi
```

### `make-appimage.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export DESKTOP=/usr/share/applications/rofi.desktop
export ICON=/usr/share/icons/hicolor/scalable/apps/rofi.svg
export APPNAME=rofi
export URUNTIME_PRELOAD=1

# Deploy dependencies
quick-sharun /usr/bin/rofi*

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
```

### `get-dependencies.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	check                \
	cppcheck             \
	gvfs                 \
	meson                \
	pango                \
	startup-notification \
	wget                 \
	xcb-util-cursor      \
	xcb-util             \
	xcb-util-keysyms     \
	xcb-util-wm          \
	xcb-util-xrm         \
	xkeyboard-config     \
	wayland-protocols

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Building rofi..."
echo "---------------------------------------------------------------"
git clone --depth 1 "https://github.com/davatorium/rofi.git" ./rofi && (
	cd ./rofi
	meson --buildtype=release --prefix /usr -Dwayland=enabled -Dxcb=enabled ./ ./build
	meson compile -C build
	meson install -C build
)
/usr/bin/rofi -v | awk -F'[- ]' '{print $2; exit}' > ~/version
```

## 验证边界

- 本次标准化与接入 `rofi-datadir.src.hook` 仅完成源码核对与静态检查，尚未经正式 CI 构建和实机运行验收。
