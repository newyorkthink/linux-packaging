#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 本程序专属处理：先安装预编译 Electron 37，满足 AUR 软件包的依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "electron37-bin"
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "aionui-bin" dpkg python-yaml alsa-lib cairo cups freetype2 gtk3 fcitx5-gtk libnotify libsecret adwaita-icon-theme librsvg libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxss libxtst libxcb libxkbcommon-x11 mesa libglvnd libva libvdpau vulkan-icd-loader libpulse pipewire-audio

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 DEB。
"$SCRIPT_DIR/../Common/download/download_electron_update_asset.sh" "https://static.aionui.com/releases/latest-linux.yml" 'https://static.aionui.com/releases/{version}' 'AionUi-{version}-linux-amd64.deb' work/app.deb > work/source-version.txt

# 本程序专属处理：核对官网清单所选 DEB 的架构。
"$SCRIPT_DIR/../Common/archive/check_deb_metadata.sh" work/app.deb "" "" amd64

# 解包官方 DEB。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/app.deb work/unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "work/unpacked/opt/AionUi/." AppDir/bin/

# 本程序专属处理：复制官方桌面入口和图标，保留自定义协议字段。
cp -a work/unpacked/usr/share/applications/AionUi.desktop work/AionUi.desktop
cp -a AppDir/bin/resources/app.png work/aionui.png
sed -i -e 's|^Exec=.*|Exec=AionUi %U|' -e 's|^Icon=.*|Icon=aionui|' work/AionUi.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="AionUi"
# 包里的真实程序名。
export MAIN_BIN="AionUi"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="AionUi"
# 使用官方 DEB 提供的图标。
export ICON="$SCRIPT_DIR/work/aionui.png"
# 使用官方 DEB 提供的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/work/AionUi.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="aionui.AppImage"
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：保留图形、音频和原生库部署设置。
export DEPLOY_OPENGL=1 DEPLOY_VULKAN=1 DEPLOY_PIPEWIRE=1 STRACE_MODE=0 NO_STRIP=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text work/source-version.txt)"

# 本程序专属处理：忽略未匹配到文件的运行库通配符。
shopt -s nullglob

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* AppDir/bin/resources/bundled-aioncore/linux-x64/aioncore /usr/bin/hostname /usr/lib/libnss*.so* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/* /usr/lib/libasound.so.2 /usr/lib/libpulse.so.0 /usr/lib/libpulse-simple.so.0 /usr/lib/libpipewire-0.3.so.0 /usr/lib/pulseaudio/libpulsecommon-*.so /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so
shopt -u nullglob

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：沿用官方程序目录作为运行时工作目录。
printf '%s\n' 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> AppDir/.env

# 本程序专属处理：保留便携启动参数，并完整传递用户参数。
cat > AppDir/bin/90-aionui-arguments.hook <<'HOOK'
set -- --no-sandbox --disable-setuid-sandbox "$@"
HOOK

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/aionui.AppImage" "$VERSION" dist/version.txt
