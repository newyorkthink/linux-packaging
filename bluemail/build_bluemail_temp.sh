#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装 AUR 软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" "bluemail" squashfs-tools openssl gtk3 nss libnotify libsecret libappindicator libxtst libxss ibus fcitx5-gtk

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir dist work
mkdir -p AppDir/shared/bin work

APP_ROOT="$SCRIPT_DIR/AppDir/shared/bin"

# 下载官方当前 Snap。
"$SCRIPT_DIR/../common/snap/download_stable_snap.sh" bluemail blix amd64 work/bluemail.snap > work/source-version.txt

# 解包官方 Snap。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/bluemail.snap "$APP_ROOT"

# 本程序专属处理：保留官方桌面入口和图标，并设置浏览器回调协议。
cp -a "$APP_ROOT/meta/gui/bluemail.desktop" work/bluemail.desktop
cp -a "$APP_ROOT/meta/gui/icon.png" work/bluemail.png
sed -i 's|^Icon=.*|Icon=bluemail|' work/bluemail.desktop
sed -i 's|^Exec=.*|Exec=bluemail %U|' work/bluemail.desktop
sed -i 's|^MimeType=.*|MimeType=x-scheme-handler/me.blueone.linux;x-scheme-handler/mailto;|' work/bluemail.desktop

# 本程序专属处理：去除 Snap 宿主运行时文件，保留应用自身资源。
rm -rf -- "$APP_ROOT/data-dir" "$APP_ROOT/gnome-platform" "$APP_ROOT/lib" "$APP_ROOT/meta" "$APP_ROOT/scripts" "$APP_ROOT/usr"
rm -f -- "$APP_ROOT/command.sh" "$APP_ROOT/desktop-init.sh" "$APP_ROOT/desktop-common.sh" "$APP_ROOT/desktop-gnome-specific.sh"

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME="BlueMail"
# 包里的真实程序名。
export MAIN_BIN="bluemail"
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS="BlueMail"
# 使用本次官方 Snap 提取的图标。
export ICON="$SCRIPT_DIR/work/bluemail.png"
# 使用本次官方 Snap 提取的桌面入口文件。
export DESKTOP="$SCRIPT_DIR/work/bluemail.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="bluemail.AppImage"
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本程序专属处理：保留已确认的符号与依赖扫描配置。
export NO_STRIP=1
export STRACE_MODE=0

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text work/source-version.txt)"

# 保留旧版向 quick-sharun 传递版本号的方式。
export VERSION

# 收集程序及其运行依赖。
# 本程序专属处理：保留 Electron 辅助程序及动态加载库。
LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun "$APP_ROOT/bluemail" "$APP_ROOT/chrome_crashpad_handler" \
  /usr/lib/libnotify.so.4 /usr/lib/libsecret-1.so.0 \
  /usr/lib/libappindicator3.so.1

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 本程序专属处理：保留 Electron 相邻库目录和工作目录。
cat >> AppDir/.env <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/shared/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin
ENV

# 本程序专属处理：保留已确认的启动参数和 OAuth URI 修正规则。
cat > AppDir/bin/90-bluemail-arguments.hook <<'HOOK'
_first=1
_have=0
for _arg in "$@"; do
    _have=1
    case $_arg in
        me.blueone.linux://*) ;;
        me.blueone.linux:/*) _arg=me.blueone.linux://${_arg#me.blueone.linux:/} ;;
        me.blueone.linux:*) _arg=me.blueone.linux://${_arg#me.blueone.linux:} ;;
    esac
    if [ "$_first" = 1 ]; then
        set -- "$_arg"
        _first=0
    else
        set -- "$@" "$_arg"
    fi
done
if [ "$_have" = 1 ]; then
    set -- --ozone-platform=x11 --no-sandbox "$@"
else
    set -- --ozone-platform=x11 --no-sandbox
fi
HOOK

# 本仓库兼容处理：启动时注册 me.blueone.linux://。包内 desktop 不会进入宿主 applications 目录。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output "$SCRIPT_DIR/AppDir/bin/20-bluemail-protocol.hook" \
  --desktop-file bluemail.desktop \
  --name BlueMail \
  --comment "BlueMail email client" \
  --icon bluemail \
  --wm-class BlueMail \
  --categories "Office;Network;Email;" \
  --scheme me.blueone.linux \
  --mime-extra x-scheme-handler/mailto

# 本程序专属处理：保留 Electron 启动入口与相邻资源的相对路径。
for item in "$APP_ROOT"/*; do
    name="${item##*/}"
    [[ "$name" == bluemail || -e "AppDir/bin/$name" || -L "AppDir/bin/$name" ]] && continue
    ln -s "../shared/bin/$name" "AppDir/bin/$name"
done

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/bluemail.AppImage" "$VERSION" dist/version.txt
