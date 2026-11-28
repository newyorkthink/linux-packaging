#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --base
# 安装 AUR 软件包、运行依赖及 DEB 解包工具。
"$SCRIPT_DIR/../Common/arch/install_packages.sh" --aur-deb "parsec-bin" "$(uname -m)" --wayback --source-filename 'parsec-bin-{version}.deb' -- dpkg ffmpeg4.4 libjpeg-turbo libva

# 清掉上次的打包目录。
"$SCRIPT_DIR/../Common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/bin


# 下载官方当前 DEB。
"$SCRIPT_DIR/../Common/aur/download_deb_source.sh" "parsec-bin" "$(uname -m)" work/app.deb --wayback --source-filename 'parsec-bin-{version}.deb'

# 解包官方 DEB。
"$SCRIPT_DIR/../Common/archive/extract_archive.sh" work/app.deb work/unpacked

# 本程序专属处理：放置独立解包的 parsecd 主程序并确认官方 skel 资源与动态模块存在。
cp -a work/unpacked/usr/bin/parsecd AppDir/bin/
[[ -f work/unpacked/usr/share/parsec/skel/appdata.json ]] || {
  echo '错误：官方 DEB 缺少 /usr/share/parsec/skel/appdata.json。' >&2
  exit 1
}
compgen -G "work/unpacked/usr/share/parsec/skel/parsecd-*.so" >/dev/null || {
  echo '错误：官方 DEB 缺少 parsecd-*.so 模块。' >&2
  exit 1
}

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="Parsec"
# 包里的真实程序名。
export MAIN_BIN="parsecd"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="parsecd"
# 使用系统里装好的图标。
export ICON="/usr/share/icons/hicolor/256x256/apps/parsecd.png"
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/parsecd.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="parsec.AppImage"
# 官方包依赖 libglvnd，打包时打入 OpenGL。
export DEPLOY_OPENGL=1
# 官方包依赖 libpipewire，打包时打入 PipeWire。
export DEPLOY_PIPEWIRE=1
# 本程序专属处理：保留原生 ELF 不裁剪、skel 路径映射及 locale 部署设置。
export DEPLOY_LOCALE=1 NO_STRIP=1 PATH_MAPPING='/usr/share/parsec:${SHARUN_DIR}/share/parsec'

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../Common/build/read_app_version.sh" pacman "parsec-bin")"

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/parsecd work/unpacked/usr/share/parsec/skel/parsecd-*.so /usr/lib/libavcodec.so.58 /usr/lib/libavutil.so.56 /usr/lib/libswresample.so.3 /usr/lib/libjpeg.so.8 /usr/lib/libva.so.2 /usr/lib/libva-drm.so.2 /usr/lib/libva-x11.so.2

# 本程序专属处理：完整保留来自官方 DEB 的 /usr/share/parsec 启动资源。
mkdir -p AppDir/share/parsec
cp -a work/unpacked/usr/share/parsec/. AppDir/share/parsec/

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_CTYPE=zh_CN.UTF-8
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../Common/build/save_appimage_version.sh" "dist/parsec.AppImage" "$VERSION" dist/version.txt
