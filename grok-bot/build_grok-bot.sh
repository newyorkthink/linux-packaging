#!/usr/bin/env bash
# 从 Grok Bot 官方 Linux stable JSON 清单动态取得当前 x64 DEB，再用 quick-sharun 重新封装。
# 不同步官方 AppImage；当前重打包重点补齐 Electron 语音播放需要的 ALSA / PulseAudio 客户端库。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备 Arch 构建环境 ######

# 安装统一的 Arch AppImage 基础包。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 安装 Grok Bot 官方 DEB 依赖、GTK3 中文输入模块和音频客户端运行库。
# im-ibus.so 属于 ibus，不随 gtk3 安装；缺文件时 quick-sharun 会退出。
# libpulse 与 PipeWire 这里只用于客户端兼容；最终 AppImage 不启动 PulseAudio / PipeWire daemon。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  dpkg gtk3 nss nspr alsa-lib libpulse pipewire pipewire-audio libnotify libsecret \
  libxss libxtst mesa libayatana-appindicator ibus fcitx5-gtk cups

# 只清理当前 Grok Bot 项目的构建目录和旧产物。
rm -rf -- "$SCRIPT_DIR/source" "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/dist"
mkdir -p -- "$SCRIPT_DIR/source/package" "$SCRIPT_DIR/AppDir/shared/bin" "$SCRIPT_DIR/dist"

readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly DEB_FILE="$SOURCE_DIR/grok-bot.deb"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/shared/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly DESKTOP_FILE="$SOURCE_DIR/grok-bot.desktop"
readonly ICON_FILE="$SOURCE_DIR/grok-bot.png"
readonly OUTFILE="$DIST_DIR/grok-bot.AppImage"

###### 获取官方稳定版 ######

# 官方 stable manifest 同时给出 version 和 debUrl；公共入口负责下载、URL 约束和 DEB 元数据校验。
VERSION="$("$SCRIPT_DIR/../common/download/download_json_deb_asset.sh" \
  'https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand' \
  '.version' \
  '.debUrl' \
  '^https://downloads\\.cursor\\.com/grokbot/stable/[0-9a-f]{40}/linux/x64/grok-bot_[0-9]+([.][0-9]+)+_amd64[.]deb$' \
  'grok-bot_{version}_amd64.deb' \
  'grok-bot' \
  'amd64' \
  "$DEB_FILE")"
readonly VERSION

# 公共归档入口按官方 DEB 原始布局解包。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$DEB_FILE" "$PACKAGE_ROOT"

###### 整理官方 Electron 运行目录 ######

# 保留官方 /opt/Grok Bot 运行目录及其资源相对布局。
cp -a -- "$PACKAGE_ROOT/opt/Grok Bot/." "$APP_ROOT/"

# AppImage 不能依赖固定 /opt 路径下的 setuid sandbox；保留文件但只使用普通执行权限。
chmod 0755 "$APP_ROOT/chrome-sandbox"

# 使用官方 desktop 与 256x256 品牌图标作为 AppImage 桌面集成资源。
cp -a -- "$PACKAGE_ROOT/usr/share/applications/grok-bot.desktop" "$DESKTOP_FILE"
cp -a -- "$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps/grok-bot.png" "$ICON_FILE"
sed -i \
  -e 's|^Exec=.*|Exec=grok-bot %U|' \
  -e 's|^Icon=.*|Icon=grok-bot|' \
  "$DESKTOP_FILE"

###### 构建 AppImage ######

export ARCH=x86_64
export VERSION
export APPNAME="Grok Bot"
export MAIN_BIN=grok-bot
export STARTUPWMCLASS=grok-bot
export ICON="$ICON_FILE"
export DESKTOP="$DESKTOP_FILE"
export OUTPATH="$DIST_DIR"
export OUTNAME=grok-bot.AppImage
export DEPLOY_GTK=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 收集官方 Electron 主程序、Crashpad、通知/密钥环/托盘库以及音频客户端库。
# libpulse 连接宿主 PulseAudio 服务；宿主使用 PipeWire 时由 pipewire-pulse 提供兼容服务。
LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  quick-sharun \
  "$APP_ROOT/grok-bot" \
  "$APP_ROOT/chrome_crashpad_handler" \
  /usr/lib/libasound.so.2 \
  /usr/lib/libpulse.so.0 \
  /usr/lib/libpulse-simple.so.0 \
  /usr/lib/libpipewire-0.3.so.0 \
  /usr/lib/pulseaudio/libpulsecommon-*.so \
  /usr/lib/libnotify.so.4 \
  /usr/lib/libsecret-1.so.0 \
  /usr/lib/libayatana-appindicator3.so.1 \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 按 quick-sharun 机制补充运行目录和中文 locale，不覆盖宿主音频服务选择。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/lib/locale/zh_CN.utf8"
cat >> "$APPDIR/.env" <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/shared/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 在 quick-sharun 内置 hook 之后加入 AppImage 必需的 Electron no-sandbox 参数。
cat > "$APPDIR/bin/90-grok-bot-arguments.hook" <<'HOOK'
set -- --no-sandbox "$@"
HOOK

# 启动时把 grokbot:// 与兼容 sand:// 协议注册到当前 AppImage，保证登录回调可回到应用。
bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh" \
  --output "$APPDIR/bin/20-grok-bot-protocol.hook" \
  --desktop-file grok-bot.desktop \
  --name "Grok Bot" \
  --comment "Grok Bot desktop agent" \
  --icon grok-bot \
  --wm-class grok-bot \
  --categories "Development;" \
  --scheme grokbot \
  --scheme sand

# Electron 会从启动入口相邻目录查找 ICU、PAK、locales 和 resources；只建立指向官方原文件的相对链接。
for item in "$APP_ROOT"/*; do
  name="${item##*/}"
  [[ -e "$APPDIR/bin/$name" || -L "$APPDIR/bin/$name" ]] && continue
  ln -s "../shared/bin/$name" "$APPDIR/bin/$name"
done

# 正式生成 AppImage；版本元数据只在最终产物成功后写入。
quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || {
  echo "错误：Grok Bot AppImage 未生成。" >&2
  exit 1
}
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
