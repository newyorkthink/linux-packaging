#!/usr/bin/env bash
set -Eeuo pipefail

# 写出 AppImage 启动时注册自定义协议的 hook。
# 协议由调用方传入。hook 只把这些协议指到当前 AppImage，不改其它默认程序。

output=""
desktop_file=""
app_name=""
comment=""
icon_name=""
wm_class=""
categories=""
schemes=()
mime_extra=()

usage() {
  echo "用法：$0 --output <hook> --desktop-file <name.desktop> --name <名称> --comment <说明> --icon <图标名> --wm-class <类名> --categories <分类> --scheme <协议> [--scheme <协议>] [--mime-extra <完整MIME>]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="${2:-}"; shift 2 ;;
    --desktop-file) desktop_file="${2:-}"; shift 2 ;;
    --name) app_name="${2:-}"; shift 2 ;;
    --comment) comment="${2:-}"; shift 2 ;;
    --icon) icon_name="${2:-}"; shift 2 ;;
    --wm-class) wm_class="${2:-}"; shift 2 ;;
    --categories) categories="${2:-}"; shift 2 ;;
    --scheme) schemes+=("${2:-}"); shift 2 ;;
    --mime-extra) mime_extra+=("${2:-}"); shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$output" && -n "$desktop_file" && -n "$app_name" && -n "$comment" && -n "$icon_name" && -n "$wm_class" && -n "$categories" && ${#schemes[@]} -gt 0 ]] || usage
[[ "$desktop_file" != */* && "$desktop_file" == *.desktop ]] || {
  echo "错误：--desktop-file 必须是单个 .desktop 文件名。" >&2
  exit 2
}

token='^[A-Za-z0-9._+-]+$'
extra_token='^[A-Za-z0-9._+/-]+$'
for scheme in "${schemes[@]}"; do
  [[ "$scheme" =~ $token ]] || {
    echo "错误：协议名无效：$scheme" >&2
    exit 2
  }
done
if [[ ${#mime_extra[@]} -gt 0 ]]; then
  for extra in "${mime_extra[@]}"; do
    [[ "$extra" =~ $extra_token && "$extra" == */* ]] || {
      echo "错误：附加 MIME 无效：$extra" >&2
      exit 2
    }
  done
fi
for value in "$app_name" "$comment" "$icon_name" "$wm_class" "$categories"; do
  [[ "$value" != *$'\n'* ]] || {
    echo "错误：参数不能包含换行。" >&2
    exit 2
  }
done

mkdir -p -- "$(dirname -- "$output")"
export HOOK_OUTPUT="$output"
export HOOK_DESKTOP="$desktop_file"
export HOOK_NAME="$app_name"
export HOOK_COMMENT="$comment"
export HOOK_ICON="$icon_name"
export HOOK_WM_CLASS="$wm_class"
export HOOK_CATEGORIES="$categories"
export HOOK_SCHEMES="${schemes[*]}"
export HOOK_MIME_EXTRA="${mime_extra[*]-}"

python3 - <<'PY'
import os
from pathlib import Path

desktop = os.environ["HOOK_DESKTOP"]
name = os.environ["HOOK_NAME"]
comment = os.environ["HOOK_COMMENT"]
icon = os.environ["HOOK_ICON"]
wm_class = os.environ["HOOK_WM_CLASS"]
categories = os.environ["HOOK_CATEGORIES"]
schemes = os.environ["HOOK_SCHEMES"].split()
extras = os.environ.get("HOOK_MIME_EXTRA", "").split()
mime = "".join(f"x-scheme-handler/{scheme};" for scheme in schemes)
mime += "".join(f"{extra};" for extra in extras)
registers = "\n".join(f"\t_register_scheme x-scheme-handler/{scheme}" for scheme in schemes)
xdg = "\n".join(
    f"\t\txdg-mime default {desktop} x-scheme-handler/{scheme} >/dev/null 2>&1"
    for scheme in schemes
)

text = f"""# 把当前 AppImage 注册为调用方指定协议的处理程序。
# AppRun 会在 set -e 下 source 本文件：不得修改 "$@"，失败也不得阻止启动。
export CHROME_DESKTOP="${{CHROME_DESKTOP:-{desktop}}}"
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

	data_home=${{XDG_DATA_HOME:-"$HOME/.local/share"}}
	config_home=${{XDG_CONFIG_HOME:-"$HOME/.config"}}
	app_dir=$data_home/applications
	desktop=$app_dir/{desktop}
	mimeapps=$config_home/mimeapps.list
	mkdir -p "$app_dir" "$config_home" "$data_home/icons/hicolor/256x256/apps" || exit 0

	icon_line="Icon={icon}"
	for _icon in \\
		"${{APPDIR:-}}/{icon}.png" \\
		"${{APPDIR:-}}/.DirIcon"
	do
		if [ -f "$_icon" ]; then
			_icon_dst=$data_home/icons/hicolor/256x256/apps/{icon}.png
			if [ ! -f "$_icon_dst" ] || ! cmp -s "$_icon" "$_icon_dst"; then
				cp -f "$_icon" "$_icon_dst" 2>/dev/null || icon_line="Icon={icon}"
			fi
			break
		fi
	done

	exec_escaped=$(printf '%s' "$APPIMAGE" | sed 'SED_EXPR') || exit 0
	tmp=$desktop.tmp.$$
	{{
		printf '%s\\n' \\
			'[Desktop Entry]' \\
			'Version=1.0' \\
			'Type=Application' \\
			'Name={name}' \\
			'Comment={comment}'
		printf 'Exec="%s" %%U\\n' "$exec_escaped"
		printf '%s\\n' \\
			"$icon_line" \\
			'Terminal=false' \\
			'StartupWMClass={wm_class}' \\
			'Categories={categories}' \\
			'MimeType={mime}'
	}} >"$tmp" || {{
		rm -f "$tmp"
		exit 0
	}}
	if [ -f "$desktop" ] && cmp -s "$tmp" "$desktop"; then
		rm -f "$tmp"
	else
		mv -f "$tmp" "$desktop" || rm -f "$tmp"
	fi

	_register_scheme() {{
		line="$1={desktop}"
		key="$1="
		if [ -f "$mimeapps" ]; then
			tmpm=$mimeapps.tmp.$$
			awk -v line="$line" -v key="$key" '
				BEGIN {{ in_def=0; seen_def=0; done=0 }}
				/^\\[Default Applications\\][[:space:]]*$/ {{
					print
					in_def=1
					seen_def=1
					next
				}}
				/^\\[/ {{
					if (in_def && !done) {{ print line; done=1 }}
					in_def=0
					print
					next
				}}
				in_def && index($0, key)==1 {{
					if (!done) {{ print line; done=1 }}
					next
				}}
				{{ print }}
				END {{
					if (!seen_def) {{
						print ""
						print "[Default Applications]"
						print line
					}} else if (!done) {{
						print line
					}}
				}}
			' "$mimeapps" >"$tmpm" && mv -f "$tmpm" "$mimeapps" || rm -f "$tmpm"
		else
			printf '%s\\n' '[Default Applications]' "$line" >"$mimeapps" || return 0
		fi
	}}
{registers}
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database "$app_dir" >/dev/null 2>&1
	fi
	if command -v xdg-mime >/dev/null 2>&1; then
{xdg}
	fi
	exit 0
) || true
"""
# The f-string above doubled braces for Python. Shell braces must remain single.
text = text.replace(
    "SED_EXPR",
    "s/" + ("\\" * 4) + "/" + ("\\" * 8) + "/g; "
    + 's/"/' + ("\\" * 4) + '"/g; '
    + "s/%/%%/g",
)
text = text.replace("{{", "{").replace("}}", "}")
Path(os.environ["HOOK_OUTPUT"]).write_text(text)
PY
