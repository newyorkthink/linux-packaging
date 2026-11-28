#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "zotero" alsa-lib gtk3 fcitx5-gtk gcc-libs glibc lsof libx11 libxext libxi libxrandr libxrender libxtst libxcomposite libxdamage libxfixes mesa libglvnd xorg-server xorg-server-common xorg-server-xvfb

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 tar 包。
"$SCRIPT_DIR/../Common/download/download_file.sh" "https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64" work/zotero.tar

# 解包官方 tar 包。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/zotero.tar work/unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a work/unpacked/Zotero_linux-x86_64/. AppDir/bin/

# 本程序专属处理：保留官方图标和桌面入口，由原启动器传递 Zotero 的参数。
cp -a AppDir/bin/zotero.desktop work/zotero.desktop
cp -a AppDir/bin/icons/icon128.png work/zotero.png
chmod +x AppDir/bin/zotero-bin
sed -i 's#^Exec=.*#Exec=zotero -url %U#' work/zotero.desktop

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Zotero"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="zotero"
# 本程序专属处理：使用本次官方 tar 包提供的图标。
export ICON="$SCRIPT_DIR/work/zotero.png"
# 本程序专属处理：使用保留官方启动器的桌面入口。
export DESKTOP="$SCRIPT_DIR/work/zotero.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="zotero.AppImage"
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：保留原有的 OpenGL 部署设置。
export DEPLOY_OPENGL=1

# 本程序专属处理：从本次解包的 application.ini 提取版本。
awk -F= '$1 == "Version" {gsub(/\r/, "", $2); print $2; exit}' AppDir/bin/app/application.ini > work/source-version.txt

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" text work/source-version.txt)"

# 收集程序及其运行依赖。
quick-sharun ./AppDir/bin/zotero-bin /usr/bin/hostname /usr/lib/libnss* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/* /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/zotero.AppImage" "$VERSION" dist/version.txt
