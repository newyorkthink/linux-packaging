#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --aur-deb "__SYSTEM_PACKAGE__" "$(uname -m)" --source-filename '__AUR_DEB_FILENAME__' -- dpkg __DEPENDENCY_ARGS__

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 DEB。
"$SCRIPT_DIR/../common/aur/download_deb_source.sh" "__SYSTEM_PACKAGE__" "$(uname -m)" work/app.deb --source-filename '__AUR_DEB_FILENAME__' --version-file work/source-version.txt

# 解包官方 DEB。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/app.deb work/unpacked

# 整个程序目录原样放进 AppDir/bin。
cp -a "work/unpacked/__DEB_PROGRAM_DIR__/." AppDir/bin/

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="__APP_NAME__"
# 包里的真实程序名。
export MAIN_BIN="__MAIN_BIN__"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="__STARTUPWMCLASS__"
# 使用系统里装好的图标。
export ICON="__ICON__"
# 使用系统里装好的桌面入口文件。
export DESKTOP="__DESKTOP__"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="__APP_BASENAME__.AppImage"

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text work/source-version.txt)"

# 收集程序及其运行依赖。
quick-sharun __SCAN_ARGS__

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

__PROTOCOL_HANDLER__
# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/__APP_BASENAME__.AppImage" "$VERSION" dist/version.txt
