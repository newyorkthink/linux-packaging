#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" dpkg gtk3 webkit2gtk-4.1 fcitx5-gtk libayatana-appindicator

# 清掉上次的打包目录。
rm -rf -- AppDir dist source grok-app.deb grok-app-unpacked grok-app.version
mkdir -p AppDir/bin dist source

# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/github/download_latest_stable_release_asset.sh" \
  RongleCat/grok-app 'Grok_{version}_amd64.deb' \
  grok-app.deb grok amd64 > grok-app.version

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" grok-app.deb grok-app-unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a grok-app-unpacked/usr/bin/. AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=Grok
# 包里的真实程序名。
export MAIN_BIN=grok-app
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=grok-app
# 使用官方 DEB 提供的图标。
export ICON=grok-app-unpacked/usr/share/icons/hicolor/128x128/apps/grok-app.png
# 使用官方 DEB 提供的桌面入口文件。
export DESKTOP=grok-app-unpacked/usr/share/applications/Grok.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=grok-app.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 保留原有的 OpenGL 部署设置。
export DEPLOY_OPENGL=1
# 保留必需的 WebKitGTK 部署设置。
export DEPLOY_WEBKIT2GTK=1
# 使用构建系统提供的 WebKitGTK 运行目录。
export WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text grok-app.version)"

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/* /usr/lib/libayatana-appindicator3.so.1

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 添加项目由 rfd 选目录：先问 xdg-desktop-portal，失败后再执行 PATH 上的 zenity。
# i3 上经常没有 org.freedesktop.portal.Desktop。Arch 的 zenity 是 GTK 4，没有 portal 时窗口照样不出现，
# 还会把 GTK 4 拉进这个 GTK 3 的包。这里改放 zenity-rs 0.3.0 的静态 PIE，没有 DT_NEEDED，自己画选目录窗口。
# rfd 实际传入 --no-markup、--file-selection、--directory；保存时还有 --save、--confirm-overwrite、--filename、--file-filter。
# 不交给 quick-sharun，避免打包时改掉它的解释器。bin/zenity 是相对符号链接，留给宿主没有 bwrap、包内 bin 仍在 PATH 最前的情况。
readonly ZENITY_RS_VERSION="0.3.0"
readonly ZENITY_RS_SHA256="f7a351180f364501855181420ceecd40b42ff84742ab79eca7aec43fe8ec074a"
"$SCRIPT_DIR/../common/download/download_file.sh" \
  "https://github.com/QaidVoid/zenity-rs/releases/download/v${ZENITY_RS_VERSION}/zenity-rs-x86_64-linux" \
  "source/zenity-rs-${ZENITY_RS_VERSION}-x86_64" \
  "$ZENITY_RS_SHA256"
mkdir -p AppDir/bin/filechooser
install -m 755 "source/zenity-rs-${ZENITY_RS_VERSION}-x86_64" AppDir/bin/filechooser/zenity
ln -sfn filechooser/zenity AppDir/bin/zenity

# Grok CLI 用 PATH 上的第一个 bwrap。quick-sharun 把包内 bin 放在最前时，
# 打包工具带入的 bwrap 会把 --proc 当成 capability：bwrap: unknown cap: --proc。
# 不覆盖 AppRun。宿主没有 /usr/bin/bwrap 时保持原 PATH。
# 宿主有 bwrap 时，只把 filechooser 放在 /usr/bin 前面。宿主日后装上的 GTK 4 zenity 不能再抢走选目录。
cat > AppDir/bin/15-grok-host-bwrap.hook <<'HOOK'
if [ -x /usr/bin/bwrap ]; then
  export PATH="$APPDIR/bin/filechooser:/usr/bin:/bin${HOSTPATH:+:$HOSTPATH}:$APPDIR/bin"
fi
HOOK

# 启动时把 grok:// 和官方皮肤 MIME 指到当前 AppImage。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output AppDir/bin/20-grok-app-protocol.hook \
  --desktop-file grok-app.desktop \
  --name "Grok" \
  --comment "desktop workbench for Grok Build CLI" \
  --icon grok-app \
  --wm-class grok-app \
  --categories "Development;" \
  --scheme grok \
  --mime-extra application/vnd.grok.skin

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/grok-app.AppImage "$VERSION" dist/version.txt
