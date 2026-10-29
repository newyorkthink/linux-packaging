#!/usr/bin/env bash
# DeepSeek Harness 桌面版：安装当前 AUR 包，把整个程序目录放进 AppDir/bin，再交给 quick-sharun。
# quick-sharun 自己生成 AppRun。这里不要写 AppRun.sh。

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# nodejs 26.12.1-2 需要 libsimdjson.so.34。镜像里的 simdjson 1:5.0.8-1 只提供 .so.35。
"$SCRIPT_DIR/../common/download/download_file.sh" \
  https://archlinux.org/packages/extra/x86_64/simdjson/download/ \
  simdjson.pkg.tar.zst
pacman -U --noconfirm simdjson.pkg.tar.zst
# 当前 AUR 包。中文输入只装 GTK 3 这一套。
"$SCRIPT_DIR/../common/arch/install_packages.sh" deepseek-harness-desktop fcitx5-gtk
# 内置 CPython 的 _crypt 需要 libcrypt.so.1。
"$SCRIPT_DIR/../common/arch/install_packages.sh" libxcrypt-compat

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p AppDir/bin dist

# 整个程序目录原样放进 AppDir/bin。/usr/bin 里的是 shell，不用它当入口。
cp -a /usr/lib/deepseek-harness-desktop/. AppDir/bin/

# 许可证留在系统原路径，放进包里。
install -Dm644 /usr/share/licenses/deepseek-harness-desktop/LICENSE \
  AppDir/share/licenses/deepseek-harness-desktop/LICENSE

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=deepseek-harness-desktop
# 包里的真实程序名。
export MAIN_BIN=deepseek-harness
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=deepseek-ai-dsh-desktop
# 使用系统里装好的图标。
export ICON=/usr/share/icons/hicolor/512x512/apps/deepseek-harness.png
# 使用系统里装好的桌面入口文件。
export DESKTOP=/usr/share/applications/deepseek-ai-dsh-desktop.desktop
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=deepseek-harness-desktop.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1

# 从本次安装结果读取版本，去掉 epoch 和 pkgrel。
VERSION="$(pacman -Q deepseek-harness-desktop | awk '{print $2}')"
VERSION="${VERSION#*:}"
VERSION="${VERSION%-*}"

# 内置 Python 的库不在系统路径上。只给这一次扫描使用。
LD_LIBRARY_PATH="AppDir/bin/resources/runtime/primary-runtime/dependencies/python/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun AppDir/bin/*

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
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  dist/deepseek-harness-desktop.AppImage "$VERSION" dist/version.txt