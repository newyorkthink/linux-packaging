#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "feishu-bin" dpkg gtk3 fcitx5-gtk alsa-lib cups libnotify libsecret libxss libxtst adwaita-icon-theme freetype2 cairo librsvg libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes libxcursor libxcb libxkbcommon-x11 libxkbfile libxshmfence mesa libglvnd libva libvdpau vulkan-icd-loader libpulse pipewire pipewire-audio gnutls libgcrypt libappindicator-gtk3 libdbusmenu-gtk3 pciutils libmfx libc++

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 DEB。
"$SCRIPT_DIR/../Common/download/download_json_deb_asset.sh" --user-agent 'Mozilla/5.0' --filename-version '^Feishu-linux_x64-([0-9]+([.][0-9]+)+)[.]deb$' --allow-md5 --allow-deb-revision 'https://www.feishu.cn/api/package_info?platform=10' '.data.version_number' '.data.download_link' '^https://([A-Za-z0-9-]+[.])*feishucdn[.]com/(.*/)?Feishu-linux_x64-[0-9]+([.][0-9]+)+[.]deb([?#].*)?$' 'Feishu-linux_x64-{version}.deb' "bytedance-feishu-stable" "amd64" work/app.deb '.data.hash' > work/source-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/app.deb work/unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "work/unpacked/opt/bytedance/feishu/." AppDir/bin/

# 本程序专属处理：若官方包包含 chrome-sandbox 则清除 setuid 位，适配 AppImage 无特权挂载环境。
if [[ -e AppDir/bin/chrome-sandbox ]]; then
  chmod 0755 AppDir/bin/chrome-sandbox
fi

# 本程序专属处理：使用官方 DEB 自带的桌面入口和 256px PNG 图标，并将入口指向包内启动器。
cp -a work/unpacked/usr/share/applications/bytedance-feishu.desktop work/feishu.desktop
cp -a AppDir/bin/product_logo_256.png work/feishu.png
sed -i -e 's|^Exec=.*|Exec=bytedance-feishu %U|' -e 's|^Icon=.*|Icon=bytedance-feishu|' work/feishu.desktop
desktop-file-validate work/feishu.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Feishu"
# 包里的真实程序名。
export MAIN_BIN="bytedance-feishu"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="Feishu"
# 使用官方 DEB 提供的图标。
export ICON="$SCRIPT_DIR/work/feishu.png"
# 使用官方 DEB 提供的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/work/feishu.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="feishu.AppImage"
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：保留图形、音频和原生库部署设置。
export DEPLOY_OPENGL=1 DEPLOY_VULKAN=1 DEPLOY_PIPEWIRE=1 STRACE_MODE=0 NO_STRIP=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text work/source-version.txt --desktop work/feishu.desktop)"

# 本程序专属处理：忽略未匹配到文件的运行库通配符。
shopt -s nullglob

# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* /usr/bin/hostname /usr/lib/libnss*.so* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/* /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so /usr/lib/libappindicator3.so* /usr/lib/libdbusmenu-gtk3.so*
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

# 本程序专属处理：保留官方运行目录及相邻库搜索路径，替代自写 AppRun.sh。
cat >> AppDir/.env <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/bin
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/feishu.AppImage" "$VERSION" dist/version.txt
