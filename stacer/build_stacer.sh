#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" "stacer" fcitx5-qt qt6ct kvantum lxqt-qtplugin

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist


# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="stacer"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/scalable/apps/stacer.svg"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/stacer.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="stacer.AppImage"
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "stacer")"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/stacer /usr/share/stacer

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：将包内翻译目录链接到主程序同级目录，匹配上游回退路径。
if [[ -d AppDir/share/stacer/translations ]]; then
  mkdir -p AppDir/bin
  ln -sfn ../share/stacer/translations AppDir/bin/translations
  if [[ -d AppDir/shared/bin ]]; then
    ln -sfn ../../share/stacer/translations AppDir/shared/bin/translations
  fi
else
  echo "错误：quick-sharun 未把 Stacer 翻译目录收集进 AppDir。" >&2
  exit 1
fi

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/stacer.AppImage" "$VERSION" dist/version.txt
