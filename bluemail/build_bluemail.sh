#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 当前应用只清理自身构建目录，避免旧版资源混入新产物。
rm -rf -- "$SCRIPT_DIR/AppDir" "$SCRIPT_DIR/source" "$SCRIPT_DIR/dist"
mkdir -p -- "$SCRIPT_DIR/source" "$SCRIPT_DIR/dist" "$SCRIPT_DIR/AppDir/shared/bin"

SOURCE_DIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
APP_ROOT="$APPDIR/shared/bin"
SNAP_FILE="$SOURCE_DIR/bluemail.snap"
OUTFILE="$SCRIPT_DIR/dist/bluemail.AppImage"

###### 准备 Arch 构建环境 ######

# 公共入口安装 quick-sharun 构建所需的最小基础工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 安装 BlueMail 应用级运行库与 GTK3 输入法模块。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  squashfs-tools openssl gtk3 nss libnotify libsecret libappindicator libxtst libxss \
  ibus fcitx5-gtk

###### 获取官方稳定版 ######

# 公共入口动态下载 latest/stable amd64 Snap，并校验官方 SHA3-384。
VERSION="$("$SCRIPT_DIR/../common/snap/download_stable_snap.sh" \
  bluemail blix amd64 "$SNAP_FILE")"

# 公共归档入口把 Snap 解包到真实程序目录，保留 Electron 资源相对布局。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SNAP_FILE" "$APP_ROOT"

###### 整理 BlueMail 目录 ######

# 保存官方 desktop 和图标；修正 AppImage 图标及浏览器 OAuth 回调参数。
cp -a -- "$APP_ROOT/meta/gui/bluemail.desktop" "$SOURCE_DIR/bluemail.desktop"
cp -a -- "$APP_ROOT/meta/gui/icon.png" "$SOURCE_DIR/bluemail.png"
sed -i 's|^Icon=.*|Icon=bluemail|' "$SOURCE_DIR/bluemail.desktop"
sed -i 's|^Exec=.*|Exec=bluemail %U|' "$SOURCE_DIR/bluemail.desktop"
sed -i 's|^MimeType=.*|MimeType=x-scheme-handler/me.blueone.linux;x-scheme-handler/mailto;|' \
  "$SOURCE_DIR/bluemail.desktop"

# 去掉 Snap 宿主运行时目录；保留应用自身 Chromium 库和资源。
rm -rf -- "${APP_ROOT:?}/data-dir" "${APP_ROOT:?}/gnome-platform" \
  "${APP_ROOT:?}/lib" "${APP_ROOT:?}/meta" "${APP_ROOT:?}/scripts" "${APP_ROOT:?}/usr"
rm -f -- "$APP_ROOT/command.sh" "$APP_ROOT/desktop-init.sh" \
  "$APP_ROOT/desktop-common.sh" "$APP_ROOT/desktop-gnome-specific.sh"

###### 构建 AppImage ######

export ARCH=x86_64
export VERSION
export APPNAME=BlueMail
export MAIN_BIN=bluemail
export STARTUPWMCLASS=BlueMail
export ICON="$SOURCE_DIR/bluemail.png"
export DESKTOP="$SOURCE_DIR/bluemail.desktop"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=bluemail.AppImage
export DEPLOY_GTK=1
export NO_STRIP=1
export STRACE_MODE=0

# 收集主程序与上游 Electron 按名称动态加载的通知、密钥和托盘库。
LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  quick-sharun "$APP_ROOT/bluemail" "$APP_ROOT/chrome_crashpad_handler" \
  /usr/lib/libnotify.so.4 /usr/lib/libsecret-1.so.0 \
  /usr/lib/libappindicator3.so.1

# 按 quick-sharun 官方机制追加运行时环境，保留工具已写入的 .env 内容。
cat >> "$APPDIR/.env" <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/shared/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin
ENV

# 在上游内置 hook 之后追加官方 Snap 的固定参数，并保留用户传入参数。
cat > "$APPDIR/bin/90-bluemail-arguments.hook" <<'HOOK'
set -- --ozone-platform=x11 --no-sandbox "$@"
HOOK

# 启动时注册 OAuth 回调协议。包内 desktop 不会进入宿主 applications 目录；
# Kali/XFCE 的 xdg-mime 也经常不能设置自定义协议，所以直接写 mimeapps.list。
cat > "$APPDIR/bin/20-bluemail-protocol.hook" <<'HOOK'
# 把当前 AppImage 注册为 me.blueone.linux 的处理程序。
# AppRun 会在 set -e 下 source 本文件：不得修改 "$@"，失败也不得阻止启动。
export CHROME_DESKTOP="${CHROME_DESKTOP:-bluemail.desktop}"
(
	set +e
	[ -n "$APPIMAGE" ] || exit 0
	[ -n "$HOME" ] || exit 0
	case $APPIMAGE in
		*[[:cntrl:]]*) exit 0 ;;
	esac
	if command -v readlink >/dev/null 2>&1; then
		_abs=$(readlink -f "$APPIMAGE" 2>/dev/null) || _abs=""
		if [ -n "$_abs" ]; then
			APPIMAGE=$_abs
		fi
	fi
	[ -f "$APPIMAGE" ] || exit 0

	data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
	config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
	app_dir=$data_home/applications
	desktop=$app_dir/bluemail.desktop
	mimeapps=$config_home/mimeapps.list
	scheme=x-scheme-handler/me.blueone.linux
	mkdir -p "$app_dir" "$config_home" "$data_home/icons/hicolor/256x256/apps" || exit 0

	icon_line="Icon=bluemail"
	for _icon in \
		"${APPDIR:-}/bluemail.png" \
		"${APPDIR:-}/.DirIcon"
	do
		if [ -f "$_icon" ]; then
			_icon_dst=$data_home/icons/hicolor/256x256/apps/bluemail.png
			if [ ! -f "$_icon_dst" ] || ! cmp -s "$_icon" "$_icon_dst"; then
				cp -f "$_icon" "$_icon_dst" 2>/dev/null || icon_line="Icon=bluemail"
			fi
			break
		fi
	done

	exec_escaped=$(printf '%s' "$APPIMAGE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/%/%%/g') || exit 0
	tmp=$desktop.tmp.$$
	{
		printf '%s\n' \
			'[Desktop Entry]' \
			'Version=1.0' \
			'Type=Application' \
			'Name=BlueMail' \
			'Comment=BlueMail email client'
		printf 'Exec="%s" %%U\n' "$exec_escaped"
		printf '%s\n' \
			"$icon_line" \
			'Terminal=false' \
			'StartupWMClass=BlueMail' \
			'Categories=Office;Network;Email;' \
			"MimeType=${scheme};x-scheme-handler/mailto;"
	} >"$tmp" || {
		rm -f "$tmp"
		exit 0
	}
	if [ -f "$desktop" ] && cmp -s "$tmp" "$desktop"; then
		rm -f "$tmp"
	else
		mv -f "$tmp" "$desktop" || rm -f "$tmp"
	fi

	line="${scheme}=bluemail.desktop"
	if [ -f "$mimeapps" ]; then
		tmpm=$mimeapps.tmp.$$
		awk -v line="$line" -v key="${scheme}=" '
			BEGIN { in_def=0; seen_def=0; done=0 }
			/^\[Default Applications\][[:space:]]*$/ {
				print
				in_def=1
				seen_def=1
				next
			}
			/^\[/ {
				if (in_def && !done) { print line; done=1 }
				in_def=0
				print
				next
			}
				in_def && index($0, key)==1 {
				if (!done) { print line; done=1 }
				next
			}
			{ print }
			END {
				if (!seen_def) {
					print ""
					print "[Default Applications]"
					print line
				} else if (!done) {
					print line
				}
			}
		' "$mimeapps" >"$tmpm" && mv -f "$tmpm" "$mimeapps" || rm -f "$tmpm"
	else
		printf '%s\n' '[Default Applications]' "$line" >"$mimeapps" || exit 0
	fi

	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "$app_dir" >/dev/null 2>&1
	fi
	if command -v xdg-mime >/dev/null 2>&1; then
		xdg-mime default bluemail.desktop "$scheme" >/dev/null 2>&1
	fi
	exit 0
) || true
HOOK

# Electron 从包装器所在目录寻找 ICU、PAK、locales 和 resources；用包内链接保留原文件。
for item in "$APP_ROOT"/*; do
  name="${item##*/}"
  [[ "$name" == bluemail || -e "$APPDIR/bin/$name" || -L "$APPDIR/bin/$name" ]] && continue
  ln -s "../shared/bin/$name" "$APPDIR/bin/$name"
done

# 正式封装并只在产物生成后写入本次实际下载的版本。
quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || {
  echo "错误：BlueMail AppImage 未生成。" >&2
  exit 1
}
printf '%s\n' "$VERSION" > "$SCRIPT_DIR/dist/version.txt"
