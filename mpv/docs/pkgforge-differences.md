# mpv 与 pkgforge-dev 打包的取舍

本文保存本次核实的来源、对应原文、可核实用途、官方原因及当前决定。它是维护记录，不参与打包，不授权自动加入未启用项。[当前构建](../build_mpv.sh) 按本仓库原生系统入口标准执行，固定配置和历史依据另见 [hardcoded.md](./hardcoded.md)。

## 核实来源

- pkgforge-dev/mpv-AppImage：固定 commit `953226d87422e9ef2307afacd2e049b1ee0a7f56`。完整读取 `make-appimage.sh`、`get-dependencies.sh`、`AppDir/bin/mpv-launch-gui.src.hook`、`.github/workflows/appimage.yml` 和 `README.md`；对应 [源码快照](https://github.com/pkgforge-dev/mpv-AppImage/tree/953226d87422e9ef2307afacd2e049b1ee0a7f56)。
- quick-sharun 内置 hooks：固定 commit `7cd4d030b56a45edb170a8d38403b202f87bc451` 的 [quick-sharun.sh](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/quick-sharun.sh)；[get-yt-dlp 原文](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/quick-sharun.sh#L2466-L2503)、[self-updater 原文](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/quick-sharun.sh#L2640-L2779) 和 [hook 机制](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/hooks/hook-system.md)。
- 二进制来源：[Arch 官方 mpv](https://archlinux.org/packages/extra/x86_64/mpv/) 与 [文件表](https://archlinux.org/packages/extra/x86_64/mpv/files/)、[mpv-mpris 文件表](https://archlinux.org/packages/extra/x86_64/mpv-mpris/files/)，以及 [mpv 官方安装指引](https://mpv.io/installation/) 中的 Arch 仓库 / AUR 入口。当前选择官方仓库原生二进制；有适用二进制，不走 pkgforge 的源码构建链。
- yt-dlp 采用 [项目自己的最新正式 Release](https://github.com/yt-dlp/yt-dlp/releases/latest) 的 `yt-dlp_linux`，使用已有公共入口动态取资产和摘要。没有将本次查询到的 tag 或 digest 固定到构建中。

下列固定 commit 只用于记录已读源码，不锁定正式构建所用的应用或打包工具版本。此处“官方”指 pkgforge-dev 对应打包实现，与 mpv 项目本身及 Arch 打包方分别标明。

## 当前决定

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 程序来源、系统入口及封装 | 采用本仓库标准；入口与官方相同 | [当前构建代码](#当前构建代码) 中安装命令、`quick-sharun /usr/bin/mpv` 和 `quick-sharun --make-appimage`；[脚本第 13 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L13)、[第 34 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L34)、[第 49 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L49) | 已有 Arch 官方二进制，直接从真实入口收集，不预复制主程序。官方同样使用该入口；未将其源码编译、瘦身依赖或 workflow 迁入本仓库。 |
| locale | 采用，官方命令原样复用 | `echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env`；[脚本第 37 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L37) | 官方注释明确写出数值 locale 限制，原文见下。当前明确取代旧两行；不生成中文 locale、不额外部署 GTK / Qt 输入模块，覆盖宿主 locale 的影响如实保留。 |
| 无参数窗口 hook | 采用，独立文件中的可执行代码原样复用 | [完整 hook 及复制命令](#独立窗口-hook)；[脚本第 45 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L45) | 官方注释说明没有参数时需补伪 GUI 参数，否则双击没有窗口。复制命令是本仓库集成，不能标为官方原命令；有参数时不改参数。 |
| yt-dlp | 保留本仓库构建时内置；官方命令未启用 | [当前构建代码](#当前构建代码) 的完整下载三行；[脚本第 40 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L40) | 独立程序供在线媒体解析，依赖收集后下载。公共入口要求正式资产及 SHA-256，不增加新 helper。旧 patchelf 注释是历史意图，本次没有复现破坏。 |
| get-yt-dlp.hook | 未启用 | 官方 `export ADD_HOOKS="self-updater.hook:get-yt-dlp.hook"` 未写入构建；本仓库替代代码见上行 | 官方代码在运行时找不到 yt-dlp 且未拒绝时询问，下载 pkgforge-dev/yt-dlp-AppImage 到 BINDIR，默认用户程序目录；它不是构建时内置 yt-dlp/yt-dlp 的原始资产。当前明确选择我们自己的内置方式。 |
| self-updater.hook 与 UPINFO | 未启用 | 官方 ADD_HOOKS、UPINFO 原文见下；无对应当前执行代码 | 官方 README 说明询问用户是否检查更新并在可用时提示；hook 会记录策略、按需询问下载 AppImageUpdate 并更新 AppImage，存在指定管理器等条件时跳过。当前不接入这条运行时更新链，产物随仓库构建更新。 |
| 图标及构建元数据 | 使用本仓库已确认的标准值；部分官方命令未启用 | [当前构建代码](#当前构建代码) 中五个 export；[脚本第 20 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L20) | 官方选择 128x128 PNG，本仓库保留同一 Arch 包中的 SVG；desktop 相同。输出使用既有固定资产名和公共版本接口，不加入无需要的 APPNAME、VERSION export 或 GITHUB_REPOSITORY 更新参数。官方未说明选该 PNG 的原因。 |
| USE_HOST_DRIVERS_EXPERIMENTAL、URUNTIME_PRELOAD | 未启用 | 官方两条 export 原文见下；无对应当前执行代码 | 分别开启实验性宿主驱动处理和 runtime preload；mpv 官方打包文件未说明启用原因。本次没有加入这些开关的实际故障依据或用户要求。 |
| 源码编译、瘦身包、FFmpeg 补丁 | 未启用 | 官方 get-dependencies.sh 原文及固定链接见下；当前使用安装命令替代源码路线，不属于原样复用 | 官方补丁注释说明 --enable-small 会丢失 codec / profile 名称，使统计缺少 codec、HW 行；本次直接用 Arch 二进制，没有这套编译配置，不照抄补丁。官方未说明其他各个禁用模块和瘦身选择的逐项原因。 |
| 视频测试与上游独立 workflow | 未启用 | 官方 `quick-sharun --test ./dist/*.AppImage ./test-video.mp4` 及固定 workflow 原文链接；当前无对应执行代码 | 官方注释说明运行约 12 秒、CI 有问题时可换 simple-test。本仓库继续现有正式 build matrix，不把测试命令、视频文件或上游独立发布 workflow 加入正式流程。 |

## 当前构建代码

以下分别位于依赖安装、元数据、依赖收集、专属处理和最终封装阶段，命令与当前脚本一致。注释和相邻空行以 [完整 52 行脚本](../build_mpv.sh) 为准。

```bash
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" mpv mpv-mpris glycin libheif xorg-server xorg-server-common xorg-server-xvfb

export ARCH="$(uname -m)"
export ICON=/usr/share/icons/hicolor/scalable/apps/mpv.svg
export DESKTOP=/usr/share/applications/mpv.desktop
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=mpv.AppImage

VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman mpv)"

quick-sharun /usr/bin/mpv

echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env

mkdir -p AppDir/usr/bin
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" yt-dlp/yt-dlp yt-dlp_linux AppDir/usr/bin/yt-dlp
chmod +x AppDir/usr/bin/yt-dlp

mkdir -p AppDir/bin
cp "$SCRIPT_DIR/mpv-launch-gui.src.hook" AppDir/bin/mpv-launch-gui.src.hook

quick-sharun --make-appimage

"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/mpv.AppImage "$VERSION" dist/version.txt
```

### 独立窗口 hook

本仓库 [mpv-launch-gui.src.hook 第 1 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/mpv-launch-gui.src.hook#L1) 的完整内容如下。只将官方说明改为统一中文注释；可执行命令、参数、引号和制表符保持原样。

```sh
#!/bin/false

# 复用官方代码：未传入参数时启用窗口模式。
if [ -z "$1" ]; then
	set -- "--player-operation-mode=pseudo-gui"
fi
```

复制命令见上面的当前构建代码；hook 位于最终封装之前，由 AppRun 加载。本仓库不将它作为程序单独执行。

## 官方源码原文

下面保存本次所读的原文，**不表示全部启用**。官方原始注释和程序输出保留，不能据此自动加入新的功能。

### 官方 make-appimage.sh

[固定源码](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/make-appimage.sh)：

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:get-yt-dlp.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export DESKTOP=/usr/share/applications/mpv.desktop
export ICON=/usr/share/icons/hicolor/128x128/apps/mpv.png
export APPNAME=mpv
export USE_HOST_DRIVERS_EXPERIMENTAL=1
export URUNTIME_PRELOAD=1

# Deploy dependencies
quick-sharun /usr/bin/mpv

# mpv only supports LC_NUMERIC=C or LC_NUMERIC=C.UTF-8
# https://github.com/mpv-player/mpv/blob/c41ee4b95fa8d9827be943247249eae56b372847/player/main.c#L248-L264
# so we cannot be relying on anylinux.so to set the locale to anything else
echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage ./test-video.mp4
```

locale 原因就在上述原文注释中：mpv 只支持 C / C.UTF-8 数值 locale，不能依赖 anylinux.so 设置成其他值；其中附有 mpv 源码链接。实验性驱动和 runtime preload 的应用专属原因，官方未说明原因，不用推测补全。

### 官方窗口 hook 原文

[固定源码](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/AppDir/bin/mpv-launch-gui.src.hook)：

```sh
#!/bin/false

# We need to add --player-operation-mode=pseudo-gui when no args are given,
# otherwise no GUI will open when the user double clicks on the AppImage

if [ -z "$1" ]; then
	set -- "--player-operation-mode=pseudo-gui"
fi
```

### 官方 get-yt-dlp hook 原文，未启用

以下为 quick-sharun 生成该 hook 的 [完整函数原文](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/quick-sharun.sh#L2466-L2503)：

```sh
_add_get_yt_dlp_hook() {
	hook=$DST_BIN_DIR/05-get-yt-dlp.hook
	if [ -f "$hook" ]; then
		return 0
	fi

	cat <<-'QS_HOOK' > "$hook"
	#!/bin/sh
	set -e
	# Use this hook for applications that require yt-dlp

	_denyfile=$CACHEDIR/.no-ytdlp-${APPIMAGE##*/}
	PATH=$PATH:$BINDIR
	export PATH

	_yt_dlp_message="${APPIMAGE##*/} needs yt-dlp to play online videos, but yt-dlp is not installed on your system. Do you want to download and install it now? You can also install it using your distro’s package manager."

	_get_ytdlp() {
	        mkdir -p "$BINDIR"
	        _ytdlp_link=$(download - https://api.github.com/repos/pkgforge-dev/yt-dlp-AppImage/releases \
	          | sed 's/[()",{} ]/\n/g' | grep -oi "https.*$APPIMAGE_ARCH.*AppImage$" | head -n 1)
	        >&2 echo "Downloading '$_ytdlp_link'..."
	        download "$BINDIR"/yt-dlp "$_ytdlp_link"
	        chmod +x "$BINDIR"/yt-dlp
	}


	if ! command -v yt-dlp 1>/dev/null && [ ! -f "$_denyfile" ]; then
	        if notify -dq "$_yt_dlp_message"; then
	                _get_ytdlp || notify -de 'Something went wrong downloading yt-dlp'
	        else
	                mkdir -p "$CACHEDIR"
	                :> "$_denyfile"
	        fi
	fi
	QS_HOOK
	_echo "* Added $hook"
}
```

按 [hook-system.md](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/hooks/hook-system.md) 的说明，BINDIR 默认是 XDG_BIN_HOME 或 `~/.local/bin`。上述代码先检查命令，再询问是否下载安装；源为 pkgforge-dev 的 yt-dlp AppImage。当前选择构建时内置原项目资产，两种来源、执行时间和落盘位置不同，不能称为同一实现。

self-updater 的完整实现保留在 [同一固定 quick-sharun.sh 第 2640–2779 行](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/7cd4d030b56a45edb170a8d38403b202f87bc451/useful-tools/quick-sharun.sh#L2640-L2779)。官方 README 明确说明先询问检查更新，存在 am、soar、dbin 等管理器时默认禁用；源码还有可写性、禁用标记、策略文件和下载更新工具的判断。当前没有启用它，也不新增这类用户目录写入与后台更新处理。

### 官方依赖和源码路线，未启用

[完整 get-dependencies.sh](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/get-dependencies.sh) 安装构建依赖、取得瘦身软件包，再通过 mpv-build 编译。以下原文包含本次未采用的瘦身、编译选项及补丁；前面的普通依赖清单仍可从固定源码完整查阅。

```sh
echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Building mpv..."
echo "---------------------------------------------------------------"
git clone "https://github.com/mpv-player/mpv-build.git" ./mpv-build
cd ./mpv-build

if [ "${DEVEL_RELEASE-}" = 1 ]; then
	./use-mpv-master
else
	./use-mpv-release
fi

echo "--enable-libdav1d"       >> ./ffmpeg_options
echo "--enable-small"          >> ./ffmpeg_options
echo "--disable-gnutls"        >> ./ffmpeg_options
echo "--enable-openssl"        >> ./ffmpeg_options
echo "--enable-version3"       >> ./ffmpeg_options
echo "--disable-librsvg"       >> ./ffmpeg_options
echo "--disable-programs"      >> ./ffmpeg_options
echo "--disable-encoders"      >> ./ffmpeg_options
echo "--enable-encoder=rawvideo" >> ./ffmpeg_options
echo "--enable-encoder=png"    >> ./ffmpeg_options
echo "--disable-muxers"        >> ./ffmpeg_options
echo "--enable-muxer=mp4"      >> ./ffmpeg_options
echo "--enable-muxer=matroska" >> ./ffmpeg_options
echo "--enable-muxer=webm"     >> ./ffmpeg_options
echo "--enable-muxer=image2"   >> ./ffmpeg_options
echo "--disable-avdevice"      >> ./ffmpeg_options
echo "-Dlibmpv=false"          >> ./mpv_options
echo "-Dlibbluray=disabled"    >> ./mpv_options
echo "-Dvapoursynth=disabled"  >> ./mpv_options
echo "-Dpipewire=disabled"     >> ./mpv_options
echo "-Drubberband=disabled"   >> ./mpv_options
echo "-Dlibavdevice=disabled"  >> ./mpv_options

# install in /usr rather than /usr/local
sed -i -e 's|meson setup build|meson setup build --prefix=/usr|' ./scripts/mpv-config

# Same as ./rebuild, with the ffmpeg sources patched in between.
# --enable-small makes ffmpeg drop the codec names (codec_desc.c) and the
# profile names (profiles.c), so mpv prints no codec and no "HW:" line in its
# stats overlay, which looks like hardware decoding is off.
# codec_desc.c refers to the tables of profiles.c, so both need the patch.
export LC_ALL=C
./update
sed -i 's/NULL_IF_CONFIG_SMALL(\(.*\)),$/\1,/' ./ffmpeg/libavcodec/codec_desc.c
sed -i 's/^#if !CONFIG_SMALL$/#if 1/' ./ffmpeg/libavcodec/profiles.c
./clean
./build -j$(nproc)
sudo ./install
/usr/bin/mpv --version | awk '{print $2; exit}' > ~/version

echo "All done!"
echo "---------------------------------------------------------------"
```

该补丁针对官方自己使用 --enable-small 的 FFmpeg 构建，原因由其注释明确说明；本仓库没有采用该构建配置，不能据此宣称 Arch 包也有同样问题。[官方 workflow](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/.github/workflows/appimage.yml) 使用 Arch 容器、x86_64 / aarch64 matrix 和独立 release Job。本仓库沿用现有 mpv 的 x86_64 标准 matrix、稳定资产名和逐 Job 版本发布，不迁移官方架构矩阵及发布实现。

## 后续维护与验证边界

未启用项后续如果要加入，必须只针对该项重新核实 pkgforge-dev 当前源码是否仍存在、是否已改写或删除、是否适合当前二进制及 AppDir 布局；说明原文、作用和影响并取得当次批准，再同步代码、README、固定配置与模板差异。不要直接照抄这里的旧快照恢复。

本次依据已读源码、包文件表和公共入口接口完成静态检查，没有执行正式打包或实机播放。在线解析、MPRIS、双击窗口和跨发行版运行不能由文档或 Bash 语法检查代替验收；当前状态以 [README](../README.md) 为准。
