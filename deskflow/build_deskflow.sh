#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "deskflow" fcitx5-qt qt6ct kvantum lxqt-qtplugin glycin libheif xorg-server xorg-server-common xorg-server-xvfb glibc libei gcc-libs libglvnd libice libportal libsm libx11 libxext libxi libxinerama libxkbcommon-x11 libxkbfile libxrandr libxtst qt6-base qt6-declarative qt6-svg libvdpau libva

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="deskflow"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/symbolic/apps/org.deskflow.deskflow-symbolic.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/org.deskflow.deskflow.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="deskflow.AppImage"
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "deskflow")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/deskflow /usr/bin/deskflow-core /usr/bin/xdotool

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：复制上游翻译目录并链接到主程序同级目录。
mkdir -p AppDir/share/deskflow AppDir/bin
cp -a /usr/share/deskflow/translations AppDir/share/deskflow/
ln -sfn ../share/deskflow/translations AppDir/bin/translations
if [ -d AppDir/shared/bin ]; then
  ln -sfn ../../share/deskflow/translations AppDir/shared/bin/translations
fi

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/deskflow.AppImage" "$VERSION" dist/version.txt
