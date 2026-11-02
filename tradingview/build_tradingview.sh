#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" tradingview-bin-latest dpkg gtk3 libsecret libnotify fcitx5-gtk

# 清掉上次的打包目录。
rm -rf -- AppDir dist source tradingview.deb tradingview-unpacked tradingview-source-version.txt
mkdir -p AppDir/bin dist

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/download/download_apt_repository_deb.sh" \
  https://tvd-packages.tradingview.com/ubuntu/stable jammy multiverse tradingview amd64 \
  https://tvd-packages.tradingview.com/keyring.gpg tradingview.deb tradingview-source-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" tradingview.deb tradingview-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a tradingview-unpacked/opt/TradingView/. AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=TradingView
# 包里的真实程序名。
export MAIN_BIN=tradingview
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=TradingView
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/512x512/apps/tradingview.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/tradingview.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=tradingview.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 本仓库兼容处理：保留程序和原生模块的符号。
export NO_STRIP=1
# 本仓库兼容处理：沿用原有依赖收集模式。
export STRACE_MODE=0

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text tradingview-source-version.txt)"
# 沿用原有版本环境，供打包工具读取。
export VERSION

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* AppDir/bin/resources/app.asar.unpacked/keytar.node /usr/lib/libnotify.so.4

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本仓库兼容处理：工作目录跟随完整程序目录，保留工具已有的库路径配置。
cat >> AppDir/.env <<'ENV'
SHARUN_WORKING_DIR=${SHARUN_DIR}/bin
ENV

# 本仓库兼容处理：沿用已验证的固定启动参数，并保留用户传入参数。
cat > AppDir/bin/90-tradingview-arguments.hook <<'HOOK'
set -- --no-sandbox "$@"
HOOK

# 启动时注册 tradingview://。包内 desktop 不会进入宿主 applications 目录。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output AppDir/bin/20-tradingview-protocol.hook \
  --desktop-file tradingview.desktop \
  --name TradingView \
  --comment "TradingView Desktop" \
  --icon tradingview \
  --wm-class TradingView \
  --categories "Finance;Office;" \
  --scheme tradingview

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/tradingview.AppImage "$VERSION" dist/version.txt
