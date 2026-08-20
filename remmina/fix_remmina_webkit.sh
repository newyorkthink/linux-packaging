#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APPIMAGE="${1:-dist/remmina.AppImage}"
APPIMAGE="$(readlink -f "$APPIMAGE")"

if [[ ! -s "$APPIMAGE" ]]; then
  echo "错误：未找到 AppImage：$APPIMAGE" >&2
  exit 1
fi

for cmd in curl python3 ldd; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "错误：缺少命令：$cmd" >&2
    exit 1
  fi
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

chmod +x "$APPIMAGE"
cd "$WORKDIR"
"$APPIMAGE" --appimage-extract >/dev/null
APPDIR="$WORKDIR/squashfs-root"

WEBKIT_SOURCE_DIR="$(find "$APPDIR/usr/lib" -type d -path '*/webkit2gtk-4.1' -print -quit)"
if [[ -z "$WEBKIT_SOURCE_DIR" ]]; then
  echo "错误：AppImage 内没有 WebKitGTK 进程目录。" >&2
  exit 1
fi

OLD_BASE="${WEBKIT_SOURCE_DIR#"$APPDIR"}"
NEW_BASE="/proc/self/cwd/webkit"
rm -rf "$APPDIR/webkit"
cp -a "$WEBKIT_SOURCE_DIR" "$APPDIR/webkit"

python3 - "$APPDIR" "$OLD_BASE" "$NEW_BASE" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
old_text = sys.argv[2]
new_text = sys.argv[3]
old = old_text.encode()
new = new_text.encode()

if len(new) > len(old):
    raise SystemExit(f"replacement path is too long: {new_text}")

replacement = new + b"/" * (len(old) - len(new))
total = 0
for path in root.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    count = data.count(old)
    if count:
        path.write_bytes(data.replace(old, replacement))
        total += count

if total == 0:
    raise SystemExit(f"cannot find compiled WebKitGTK directory: {old_text}")
print(f"已修正 WebKitGTK 目录：{old_text} -> {new_text}，共 {total} 处")
PY

# 打包 fcitx5 和 IBus 的 GTK3 输入模块。模块目录以 AppImage 实际布局为准，
# 不能写死为 Debian multiarch 路径；linuxdeploy 当前使用 usr/lib/gtk-3.0。
FCITX_MODULE="$(find /usr/lib -type f -path '*/gtk-3.0/*/immodules/im-fcitx5.so' -print -quit)"
IBUS_MODULE="$(find /usr/lib -type f -path '*/gtk-3.0/*/immodules/im-ibus.so' -print -quit)"
GTK_IMMODULE_DIR="$(find "$APPDIR/usr/lib" -type d -path '*/gtk-3.0/3.0.0/immodules' -print -quit)"

for required in "$FCITX_MODULE" "$IBUS_MODULE" "$GTK_IMMODULE_DIR"; do
  if [[ -z "$required" ]]; then
    echo "错误：缺少 fcitx5、IBus 或 AppImage GTK 输入模块目录。" >&2
    exit 1
  fi
done

mkdir -p "$APPDIR/usr/lib"

is_glibc_runtime() {
  case "$(basename "$1")" in
    ld-linux*.so*|libc.so*|libpthread.so*|libdl.so*|librt.so*|libm.so*|\
    libresolv.so*|libutil.so*|libanl.so*|libBrokenLocale.so*|\
    libnss_*.so*|libthread_db.so*)
      return 0
      ;;
  esac
  return 1
}

copy_runtime_deps() {
  local binary="$1"
  local library destination

  while IFS= read -r library; do
    [[ -f "$library" ]] || continue
    is_glibc_runtime "$library" && continue
    destination="$APPDIR/usr/lib/$(basename "$library")"
    [[ -e "$destination" ]] || cp -aL "$library" "$destination"
  done < <(
    ldd "$binary" 2>/dev/null | awk '
      /=> \/.*\// { print $3 }
      /^[[:space:]]*\// { print $1 }
    ' | sort -u
  )
}

cp -aL "$FCITX_MODULE" "$GTK_IMMODULE_DIR/im-fcitx5.so"
cp -aL "$IBUS_MODULE" "$GTK_IMMODULE_DIR/im-ibus.so"
copy_runtime_deps "$FCITX_MODULE"
copy_runtime_deps "$IBUS_MODULE"

# Remmina 不使用 fluidsynth MIDI。移除该 GStreamer 插件，避免继续追逐
# JACK、PipeWire 等与远程桌面无关的可选音频依赖。
find "$APPDIR/usr/lib" -type f -name 'libgstfluidsynthmidi.so' -delete

# 禁止构建机 glibc 进入 AppImage。必须使用 if，不能用
# is_glibc_runtime && rm；否则 set -e + pipefail 会把普通的“不匹配”当失败。
find "$APPDIR/usr/lib" -maxdepth 1 \( -type f -o -type l \) -print | while IFS= read -r library; do
  if is_glibc_runtime "$library"; then
    rm -f "$library"
  fi
done

python3 - "$APPDIR/AppRun" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

webkit_line = 'export WEBKIT_EXEC_PATH="$APPDIR/webkit"'
if webkit_line not in text:
    marker = 'FREERDP_DIR="$(find "$APPDIR/usr/lib" -type d -name \'freerdp[0-9]*\' -print -quit)"'
    if marker not in text:
        raise SystemExit("cannot find AppRun WebKit insertion point")
    text = text.replace(marker, webkit_line + "\n\n" + marker, 1)

input_method_block = r'''# 为 fcitx5/IBus 生成包含当前 AppImage 挂载路径的 GTK3 模块缓存。
GTK_IMMODULE_DIR=""
for candidate in \
  "$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules" \
  "$APPDIR/usr/lib/"*/gtk-3.0/3.0.0/immodules; do
  if [[ -d "$candidate" ]]; then
    GTK_IMMODULE_DIR="$candidate"
    break
  fi
done

IM_HINT="${GTK_IM_MODULE:-} ${QT_IM_MODULE:-} ${SDL_IM_MODULE:-} ${XMODIFIERS:-}"
if [[ "${IM_HINT,,}" != *fcitx* ]] && command -v pgrep >/dev/null 2>&1 && pgrep -x fcitx5 >/dev/null 2>&1; then
  IM_HINT="$IM_HINT fcitx"
fi

IM_CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
IM_CACHE_FILE="$IM_CACHE_DIR/remmina-appimage-immodules-${UID:-0}.cache"

case "${IM_HINT,,}" in
  *fcitx*)
    if [[ -f "$GTK_IMMODULE_DIR/im-fcitx5.so" ]]; then
      cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$GTK_IMMODULE_DIR/im-fcitx5.so"
"fcitx" "Fcitx 5" "fcitx" "" "ja:ko:zh:*"
EOF
      export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
      export GTK_IM_MODULE="fcitx"
      export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"
    fi
    ;;
  *ibus*)
    if [[ -f "$GTK_IMMODULE_DIR/im-ibus.so" ]]; then
      cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$GTK_IMMODULE_DIR/im-ibus.so"
"ibus" "IBus" "ibus" "" "ja:ko:zh:*"
EOF
      export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
      export GTK_IM_MODULE="ibus"
    fi
    ;;
esac
unset candidate IM_HINT IM_CACHE_DIR IM_CACHE_FILE
'''

start = text.find('# 为 fcitx5/IBus 生成包含当前 AppImage 挂载路径的 GTK3 模块缓存。')
if start != -1:
    end_marker = "unset IM_HINT IM_CACHE_DIR IM_CACHE_FILE\n"
    end = text.find(end_marker, start)
    if end == -1:
        raise SystemExit("cannot find existing input method block end")
    end += len(end_marker)
    text = text[:start] + input_method_block + text[end:]
else:
    marker = 'LIBDIR="$APPDIR/usr/lib/x86_64-linux-gnu"'
    if marker not in text:
        raise SystemExit("cannot find AppRun GTK input method insertion point")
    text = text.replace(marker, input_method_block + "\n" + marker, 1)

auth_filter_block = r'''# 本 AppImage 面向本地/工作组 Windows RDP：默认禁用 Kerberos/U2U，直接使用可用的 NTLM/NLA。
# 只在 rdp_auth_filter 不存在或为空时写入；已有非空自定义值保持原样。
REMMINA_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME:-/tmp}/.config}"
REMMINA_PREF_FILE="$REMMINA_CONFIG_HOME/remmina/remmina.pref"
mkdir -p "$(dirname "$REMMINA_PREF_FILE")"

if [[ ! -f "$REMMINA_PREF_FILE" ]]; then
  printf '%s\n' '[remmina_pref]' 'rdp_auth_filter=!kerberos,!u2u' > "$REMMINA_PREF_FILE"
elif grep -Eq '^[[:space:]]*rdp_auth_filter[[:space:]]*=[[:space:]]*$' "$REMMINA_PREF_FILE"; then
  sed -Ei 's|^[[:space:]]*rdp_auth_filter[[:space:]]*=[[:space:]]*$|rdp_auth_filter=!kerberos,!u2u|' "$REMMINA_PREF_FILE"
elif ! grep -Eq '^[[:space:]]*rdp_auth_filter[[:space:]]*=' "$REMMINA_PREF_FILE"; then
  if grep -Eq '^[[:space:]]*\[remmina_pref\][[:space:]]*$' "$REMMINA_PREF_FILE"; then
    sed -Ei '/^[[:space:]]*\[remmina_pref\][[:space:]]*$/a rdp_auth_filter=!kerberos,!u2u' "$REMMINA_PREF_FILE"
  else
    printf '\n%s\n%s\n' '[remmina_pref]' 'rdp_auth_filter=!kerberos,!u2u' >> "$REMMINA_PREF_FILE"
  fi
fi
unset REMMINA_CONFIG_HOME REMMINA_PREF_FILE
'''

auth_marker = 'export GSETTINGS_SCHEMA_DIR="$APPDIR/usr/share/glib-2.0/schemas"'
if '# 本 AppImage 面向本地/工作组 Windows RDP：默认禁用 Kerberos/U2U' not in text:
    if auth_marker not in text:
        raise SystemExit("cannot find AppRun RDP auth insertion point")
    text = text.replace(auth_marker, auth_marker + "\n\n" + auth_filter_block, 1)

path.write_text(text)
PY
chmod +x "$APPDIR/AppRun"

for process in WebKitWebProcess WebKitNetworkProcess WebKitGPUProcess; do
  if [[ -e "$WEBKIT_SOURCE_DIR/$process" ]]; then
    test -x "$APPDIR/webkit/$process"
  fi
done

test -x "$APPDIR/webkit/WebKitWebProcess"
test -f "$GTK_IMMODULE_DIR/im-fcitx5.so"
test -f "$GTK_IMMODULE_DIR/im-ibus.so"
test ! -e "$APPDIR/usr/lib/libc.so.6"
test ! -e "$APPDIR/usr/lib/ld-linux-x86-64.so.2"
test -z "$(find "$APPDIR/usr/lib" -type f -name 'libgstfluidsynthmidi.so' -print -quit)"
grep -Fq 'GTK_IMMODULE_DIR=""' "$APPDIR/AppRun"
grep -Fq 'pgrep -x fcitx5' "$APPDIR/AppRun"
grep -Fq 'rdp_auth_filter=!kerberos,!u2u' "$APPDIR/AppRun"

path_contains() {
  python3 - "$1" "$2" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
needle = sys.argv[2].encode()
for path in root.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    try:
        if needle in path.read_bytes():
            raise SystemExit(0)
    except OSError:
        continue
raise SystemExit(1)
PY
}

if path_contains "$APPDIR" "$OLD_BASE"; then
  echo "错误：仍残留宿主 WebKitGTK 绝对目录。" >&2
  exit 1
fi
path_contains "$APPDIR" "$NEW_BASE"

APPIMAGETOOL="$WORKDIR/appimagetool"
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"

NEW_APPIMAGE="$WORKDIR/remmina-runtime-fixed.AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" -n "$APPDIR" "$NEW_APPIMAGE"
chmod +x "$NEW_APPIMAGE"

APPIMAGE_EXTRACT_AND_RUN=1 "$NEW_APPIMAGE" --version >/tmp/remmina-postfix-version.txt 2>&1

VERIFY_DIR="$WORKDIR/verify"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$NEW_APPIMAGE" --appimage-extract >/dev/null
)
VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
VERIFY_IMMODULE_DIR="$(find "$VERIFY_APPDIR/usr/lib" -type d -path '*/gtk-3.0/3.0.0/immodules' -print -quit)"

test -x "$VERIFY_APPDIR/webkit/WebKitWebProcess"
test -f "$VERIFY_IMMODULE_DIR/im-fcitx5.so"
test -f "$VERIFY_IMMODULE_DIR/im-ibus.so"
test ! -e "$VERIFY_APPDIR/usr/lib/libc.so.6"
test ! -e "$VERIFY_APPDIR/usr/lib/ld-linux-x86-64.so.2"
test -z "$(find "$VERIFY_APPDIR/usr/lib" -type f -name 'libgstfluidsynthmidi.so' -print -quit)"
grep -Fq 'GTK_IMMODULE_DIR=""' "$VERIFY_APPDIR/AppRun"
grep -Fq 'pgrep -x fcitx5' "$VERIFY_APPDIR/AppRun"
grep -Fq 'rdp_auth_filter=!kerberos,!u2u' "$VERIFY_APPDIR/AppRun"

if path_contains "$VERIFY_APPDIR" "$OLD_BASE"; then
  echo "错误：最终 AppImage 仍残留宿主 WebKitGTK 绝对目录。" >&2
  exit 1
fi
path_contains "$VERIFY_APPDIR" "$NEW_BASE"

cat "$NEW_APPIMAGE" > "$APPIMAGE"
chmod +x "$APPIMAGE"
echo "已修复 WebKitGTK、GTK 输入法、GStreamer 可选插件和本地 RDP 认证默认值：$APPIMAGE"
