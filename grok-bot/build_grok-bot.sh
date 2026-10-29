#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" grok-bot-bin dpkg gtk3 alsa-lib libpulse pipewire pipewire-audio libnotify libsecret libxss libxtst mesa libayatana-appindicator fcitx5-gtk cups

# 清掉上次的打包目录。
rm -rf -- AppDir dist grok-bot.deb grok-bot-unpacked grok-bot.version
mkdir -p AppDir/bin dist

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/download/download_json_deb_asset.sh" \
  'https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand' '.version' '.debUrl' \
  '^https://downloads\.cursor\.com/grokbot/stable/[0-9a-f]{40}/linux/x64/grok-bot_[0-9]+([.][0-9]+)+_amd64[.]deb$' 'grok-bot_{version}_amd64.deb' grok-bot amd64 grok-bot.deb > grok-bot.version

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" grok-bot.deb grok-bot-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "grok-bot-unpacked/opt/Grok Bot/." AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Grok Bot"
# 包里的真实程序名。
export MAIN_BIN=grok-bot
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=grok-bot
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/256x256/apps/grok-bot.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/grok-bot.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=grok-bot.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text grok-bot.version)"

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/* /usr/lib/libasound.so.2 /usr/lib/libpulse.so.0 /usr/lib/libpulse-simple.so.0 /usr/lib/libpipewire-0.3.so.0 /usr/lib/pulseaudio/libpulsecommon-*.so /usr/lib/libnotify.so.4 /usr/lib/libsecret-1.so.0 /usr/lib/libayatana-appindicator3.so.1

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 保留原有启动兼容处理，绕过部分系统的 Electron 沙箱启动限制。
cat > AppDir/bin/90-grok-bot-arguments.hook <<'HOOK'
set -- --no-sandbox "$@"
HOOK

# 启动时注册登录回调协议，使浏览器能够把登录结果交回当前 AppImage。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output AppDir/bin/20-grok-bot-protocol.hook \
  --desktop-file grok-bot.desktop \
  --name "Grok Bot" \
  --comment "Grok Bot desktop agent" \
  --icon grok-bot \
  --wm-class grok-bot \
  --categories "Development;" \
  --scheme grokbot \
  --scheme sand

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/grok-bot.AppImage "$VERSION" dist/version.txt
