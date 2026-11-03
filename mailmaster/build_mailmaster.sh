#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --aur-deb mailmaster "$(uname -m)" --source-filename 'mailmaster-{version}.deb' -- dpkg fcitx5-qt qt5-base xorg-server xorg-server-common xorg-server-xvfb alsa-lib cups gtk3 libnotify libsecret adwaita-icon-theme libx11 libxext libxi libxrender libxrandr libxinerama libxcomposite libxdamage libxfixes libxss libxtst libxcb xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm libxkbcommon-x11 mesa libglvnd libva libvdpau pulseaudio pulseaudio-alsa pipewire-audio

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create work AppDir dist
mkdir -p work AppDir/bin AppDir/share/licenses

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/aur/download_deb_source.sh" mailmaster "$(uname -m)" work/mailmaster.deb --source-filename 'mailmaster-{version}.deb' --version-file work/source-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/mailmaster.deb work/mailmaster-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a work/mailmaster-unpacked/opt/mailmaster/. AppDir/bin/

# 本仓库兼容处理：保留 AUR 安装时提供的启动脚本。
cp -a /opt/mailmaster/launch.sh "AppDir/bin/"
# 本仓库兼容处理：补回 AUR 安装时提供的 NSS Wrapper 和 GConf 兼容库。
cp -a /opt/mailmaster/lib/libnss_wrapper.so /opt/mailmaster/lib/libgconf-2.so.4 "AppDir/bin/lib/"

# 本仓库兼容处理：按 AUR 配方停用 XCB GL 集成插件。
for plugin in AppDir/bin/plugins/xcbglintegrations/*.so; do
  mv -- "$plugin" "$plugin.disabled"
done
# 本仓库兼容处理：按 AUR 配方停用程序自带的旧 Fcitx 插件。
mv -- "AppDir/bin/plugins/platforminputcontexts/libfcitxplatforminputcontextplugin.so"{,.disabled}

# 本仓库兼容处理：配合 CEF 的 --no-sandbox 启动参数，清除 chrome-sandbox 的 setuid 位。
chmod 0755 "AppDir/bin/chrome-sandbox"

# 本仓库兼容处理：将 AUR 包的 libsasl2 绝对链接改为包内相对链接。
SASL_SOURCE="$(readlink -f /usr/lib/libsasl2.so.3)"
rm -f "AppDir/bin/lib/libsasl2.so.2" "AppDir/bin/lib/libsasl2.so.3"
cp -aL "$SASL_SOURCE" "AppDir/bin/lib/libsasl2.so.3"
ln -s libsasl2.so.3 "AppDir/bin/lib/libsasl2.so.2"

# 本仓库兼容处理：保留 AUR 包安装的许可证文件。
cp -a /usr/share/licenses/mailmaster "$SCRIPT_DIR/AppDir/share/licenses/"

# 本仓库兼容处理：把 Qt 5 Fcitx5 模块放入程序实际读取的输入法插件目录。
install -m 644 /usr/lib/qt/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so "AppDir/bin/plugins/platforminputcontexts/"

# 本仓库兼容处理：修正附件选择器的起始目录。
bash "$SCRIPT_DIR/patches/prepare_attachment_dialog.sh" AppDir/bin work

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=MailMaster
# 包里的真实程序名。
export MAIN_BIN=mailmaster
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=mailmaster
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/256x256/apps/mailmaster.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/mailmaster.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=mailmaster.AppImage
# 本仓库兼容处理：保留 CEF 所需的 GTK、图形和音频部署设置。
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text work/source-version.txt)"

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin:$SCRIPT_DIR/AppDir/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* /usr/bin/curl /usr/bin/hostname /usr/lib/libnss* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/* "AppDir/bin/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so" "AppDir/bin/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本仓库兼容处理：保留 MailMaster 自带的 Qt 插件路径、CEF 库路径和工作目录。
cat >> AppDir/.env <<'ENV'
QT_QPA_PLATFORM=xcb
QT_XCB_GL_INTEGRATION=none
SHARUN_ALLOW_QT_PLUGIN_PATH=1
QT_PLUGIN_PATH=${SHARUN_DIR}/bin/plugins
QT_QPA_PLATFORM_PLUGIN_PATH=${SHARUN_DIR}/bin/plugins/platforms
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_DIR}/bin/lib:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/bin
ENV

# 本仓库兼容处理：沿用原输入法默认值、主题隔离和 CEF 启动参数。
cat > AppDir/bin/90-mailmaster-arguments.hook <<'HOOK'
unset QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_STYLE
export QT_IM_MODULE="${QT_IM_MODULE:-ibus}"
set -- --no-sandbox "$@"
HOOK

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/mailmaster.AppImage "$VERSION" dist/version.txt
