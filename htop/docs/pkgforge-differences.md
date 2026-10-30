# htop 与 pkgforge-dev 打包的取舍

本次按自己的 Arch 官方仓库原生程序系统入口标准整理 htop。本文件保存已读官方源码及取舍，区分当前执行的代码与未启用项；不参与打包，也不授权后续自动加入功能。

## 来源与已读范围

- pkgforge-dev/htop-AppImage 固定 commit：`138bc266d885f0ac987921a99417aa1278169b76`。[源码快照](https://github.com/pkgforge-dev/htop-AppImage/tree/138bc266d885f0ac987921a99417aa1278169b76)。
- 已完整读取该提交的 `make-appimage.sh`、`get-dependencies.sh`、`.github/workflows/appimage.yml` 和 `README.md`；该快照没有应用专用 hook 或 wrapper 文件。
- 当前二进制来源为 [Arch 官方 htop 包](https://archlinux.org/packages/extra/x86_64/htop/)，入口、SVG、desktop 由其 [文件表](https://archlinux.org/packages/extra/x86_64/htop/files/) 核实。已有适用二进制，本仓库不采用源码编译。
- 外部命令、温度库和延迟统计库的作用，依据 [htop 手册](https://man.archlinux.org/man/htop.1.en) 中的快捷键与 EXTERNAL LIBRARIES 说明；完整收集输入继承本仓库 [重写前脚本](https://github.com/newyorkthink/linux-packaging/blob/c32d1e811cb2483a728027bf62732c64e302ff51/htop/build_htop.sh)。

固定 commit 只用于保存本次核实的源码证据，不锁定实际安装的软件包或打包工具版本。本文的“官方打包”指 pkgforge-dev 的对应项目，与 htop 软件项目及 Arch 官方包分别说明。

## 当前决定

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 程序与依赖来源 | 使用本仓库标准，官方源码路线未启用 | [完整当前构建代码](#当前构建代码) 的两条安装命令；[脚本第 11 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L11)、[第 13 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L13) | Arch 官方已有二进制；原有 17 项依赖全部保留。pkgforge 自行构建 ncurses、libsensors、htop 的代码未接入。 |
| 主程序入口及封装 | 采用本仓库标准，入口与官方相同 | 当前代码中的 `quick-sharun --make-appimage`；[脚本第 39 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L39)；收集完整命令见下行 | 不预复制主程序到 AppDir/bin，由工具收集系统入口和生成 AppRun。不是把官方静态构建产物搬到本仓库。 |
| 多入口和动态库收集 | 保留本仓库既有输入，官方单入口命令未采用 | `quick-sharun /usr/bin/htop /usr/bin/lsof /usr/bin/strace /usr/lib/libsensors.so* /usr/lib/libnl-3.so* /usr/lib/libnl-genl-3.so*`；[脚本第 36 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L36) | 整条调用保持原参数和顺序。lsof、strace 对应 Open Files / Trace；动态加载库对应温度、延迟统计。来自当前手册和已有代码，不冒称官方原样复用。 |
| MAIN_BIN | 保留既有明确入口 | `export MAIN_BIN=htop`；[脚本第 30 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L30) | 多个程序共同收集时继续明确指定 htop。注释用统一的“包里的真实程序名。”，不为凑齐模板增加其他元数据。 |
| 图标和 desktop | 保留本仓库原值，官方 PNG 赋值未采用 | 当前代码中的 ICON、DESKTOP；[脚本第 22 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L22)、[第 24 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L24) | Arch 包同时提供 SVG 和 PNG；本仓库原 SVG 路径继续使用，desktop 与官方同源。官方未说明选择 PNG 的原因。 |
| 版本与输出 | 采用公共接口及既有固定资产名 | 当前代码中的 VERSION、OUTPATH、OUTNAME 和保存命令；[脚本第 26 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L26)、[第 28 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L28)、[第 33 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L33)、[第 42 行](https://github.com/newyorkthink/linux-packaging/blob/main/htop/build_htop.sh#L42) | 读取实际安装的 htop 版本；最终产物非空后才保存版本。官方在源码构建中从选定 tag 写 ~/version 的方式未启用，不把构建机文件路径带入运行时。 |
| 静态源码构建 | 未启用 | 官方 get-dependencies.sh 原文见下；无对应当前执行代码 | 官方自行克隆、配置和编译 ncurses、libsensors、htop，并使用静态构建选项。官方未说明这样构建的原因；不能凭配置选项断言最终产物已完全静态链接。本仓库有官方二进制，继续使用已安装的运行库和既有动态库收集方式。 |
| UPINFO | 未启用 | 官方 `export UPINFO` 原文见下；无对应当前执行代码 | 该值设置 GitHub Release zsync 更新信息；当前保留自己的固定资产和统一版本清单流程，不接入这套更新元数据。官方未说明该应用单独设置它的原因。 |
| simple-test | 未启用 | 官方 `quick-sharun --simple-test ./dist/*.AppImage`；当前无对应执行代码 | 官方注释将其用于构建后检查；本仓库不把测试命令加入正式应用脚本。静态检查在提交前完成，不写成构建或实机验证已通过。 |
| 上游 workflow | 未迁入 | [固定 workflow](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/.github/workflows/appimage.yml)；当前继续现有 build matrix | 官方使用 x86_64 / aarch64 matrix、独立 release Job 和发布 Action。本仓库保留现有 htop 的 x86_64 标准任务及逐 Job 版本发布，没有新增 workflow、Job 或架构矩阵。 |

没有另外加入 locale、输入法模块、hook、启动参数或 wrapper。本次所读官方构建脚本没有这些应用专用步骤，不制造不存在的“官方处理”清单。官方 README 虽描述了自更新，但该 make-appimage.sh 没有设置 ADD_HOOKS；不能只凭 README 宣称本仓库启用了自更新 hook，当前也未新增这种运行时流程。

## 当前构建代码

以下是本次实际写入的完整 42 行脚本。主程序名两行及已有额外收集输入是已记录差异，其余公共部分按原生模板逐行保留。

```bash
#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" htop ncurses libcap libnl lm_sensors lsof strace

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/scalable/apps/htop.svg
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/htop.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=htop.AppImage
# 包里的真实程序名。
export MAIN_BIN=htop

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman htop)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/htop /usr/bin/lsof /usr/bin/strace /usr/lib/libsensors.so* /usr/lib/libnl-3.so* /usr/lib/libnl-genl-3.so*

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/htop.AppImage "$VERSION" dist/version.txt
```

配置的具体取值及原有基线说明见 [hardcoded.md](./hardcoded.md)，模板逐项对应见 [template-deviations.md](./template-deviations.md)。

## 官方源码原文，仅作核实记录

以下原文不表示全部启用；当前取舍以上表和实际构建代码为准。

### make-appimage.sh

[固定源码](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/make-appimage.sh)：

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/pixmaps/htop.png
export DESKTOP=/usr/share/applications/htop.desktop

# Deploy dependencies
quick-sharun /usr/bin/htop

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
```

官方单入口命令面对的是它自行编译安装的程序；本仓库使用 Arch 包，并保留原有辅助命令与 dlopen 库输入。两种完整收集命令不同，不能把本仓库的扩展调用标成逐字复用官方。

### get-dependencies.sh

[固定源码](https://github.com/pkgforge-dev/htop-AppImage/blob/138bc266d885f0ac987921a99417aa1278169b76/get-dependencies.sh)：

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
# pacman -Syu --noconfirm PACKAGESHERE

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
# get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here
echo "Building static ncurses..."
echo "---------------------------------------------------------------"
git clone --depth 1 https://github.com/mirror/ncurses.git /tmp/ncurses && (
	cd /tmp/ncurses
	./configure \
		--disable-shared     \
		--enable-static      \
		--enable-widec       \
		--prefix=/tmp/static \
		--with-termlib       \
		--without-ada        \
		--without-cxx        \
		--without-debug
	make -j"$(nproc)"
	make install
)

echo "Building static libsensors..."
echo "---------------------------------------------------------------"
git clone --depth 1 https://github.com/lm-sensors/lm-sensors.git /tmp/lm-sensors && (
	cd /tmp/lm-sensors
	make BUILD_LIB=1 BUILD_SHARED_LIB=0 BUILD_STATIC_LIB=1
	cp -v ./lib/libsensors.a /tmp/static/lib
	cp -v ./lib/sensors.h   /tmp/static/include
)

echo "Building htop statically..."
echo "---------------------------------------------------------------"
git clone https://github.com/htop-dev/htop.git ./htop && (
	cd ./htop

	git fetch --tags origin
	TAG=$(git tag --sort=-v:refname | grep -vi 'rc\|alpha\|beta' | head -1)
	git checkout "$TAG"
	echo "$TAG" > ~/version

	./autogen.sh
	export CPPFLAGS="-I/tmp/static/include"
	export LDFLAGS="-L/tmp/static/lib"
	./configure \
		--disable-shared \
		--enable-sensors \
		--enable-static  \
		--prefix=/usr    \
		--with-ncursesw
	make -j"$(nproc)"
	make install
)
```

其中静态构建、源码 tag 选择和 ~/version 写入均未进入本仓库。文件中的占位安装命令本来就是注释，不能把它们解释成已执行的包安装，也不按这份源码脚本删除本仓库原有依赖。

## 后续维护与验证边界

后续拟加入当前未启用的处理时，只针对该项重新查看 pkgforge-dev 当前源码，确认是否仍存在、是否已改写或删除、是否适合当前二进制和布局，再说明原文、作用、具体范围并取得当次授权；不能直接恢复这里的历史快照。

本次只完成 Shell 语法、依赖覆盖、模板与链接、代码原文的静态检查，没有执行正式打包或实机功能检查。不将存在 lsof、strace 或库文件写成 Open Files、Trace、温度和延迟统计均已实测成功；当前记录见 [README](../README.md#维护文档与验证范围)。
