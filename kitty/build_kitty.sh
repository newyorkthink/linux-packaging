#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "::error file=build_kitty.sh,line=${LINENO}::命令失败（退出码 ${rc}）：${BASH_COMMAND}" >&2; exit "$rc"' ERR

cd "$(dirname "$0")"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "错误：仅支持 x86_64。" >&2
  exit 1
fi

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1

ROOT="$PWD"
APPDIR="$ROOT/AppDir"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/kitty.AppImage"
KITTY_DIR="$APPDIR/usr/lib/kitty.app"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib" "$OUTDIR"
rm -f "$OUTFILE" "$OUTFILE.zsync"

yay -S --needed --noconfirm \
  ca-certificates \
  curl \
  file \
  kitty-terminfo \
  libxcb \
  ncurses \
  squashfs-tools \
  tar \
  xz \
  zsync

# 使用 kitty 官方预编译包，并保持 bin、lib、share 的相对目录不变。
curl -fL --retry 3 \
  https://sw.kovidgoyal.net/kitty/installer.sh \
  -o /tmp/kitty-installer.sh

sh /tmp/kitty-installer.sh \
  dest="$APPDIR/usr/lib" \
  launch=n

test -x "$KITTY_DIR/bin/kitty"
test -x "$KITTY_DIR/bin/kitten"
test -f "$KITTY_DIR/share/applications/kitty.desktop"
test -f "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so"

# kitty 官方二进制包不包含 libxcb-xkb，部分宿主机也不会预装该库。
cp -a /usr/lib/libxcb-xkb.so.1* "$KITTY_DIR/lib/"
test -e "$KITTY_DIR/lib/libxcb-xkb.so.1"

# 使用 Arch 官方 kitty-terminfo 包提供的已编译数据库。
# 不再从 kitty 内部提取、下载源码或调用 tic。
TERMINFO_DIR="$KITTY_DIR/share/terminfo"
TERMINFO_FILE="$TERMINFO_DIR/x/xterm-kitty"

mkdir -p "$TERMINFO_DIR/x"
cp -a /usr/share/terminfo/x/xterm-kitty "$TERMINFO_FILE"
test -s "$TERMINFO_FILE"

# 验证 tmux/ncurses 能读取打包后的 xterm-kitty。
TERMINFO="$TERMINFO_DIR" \
TERMINFO_DIRS="$TERMINFO_DIR:" \
  infocmp xterm-kitty >/dev/null

# 在构建环境中提前检查 X11 GLFW 扩展是否仍存在未解析依赖。
if LD_LIBRARY_PATH="$KITTY_DIR/lib" \
  ldd "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so" \
  | grep -q 'not found'; then
  echo "错误：kitty X11 扩展仍存在未打包的动态库：" >&2
  LD_LIBRARY_PATH="$KITTY_DIR/lib" \
    ldd "$KITTY_DIR/lib/kitty-extensions/kitty.glfw-x11.so" >&2
  exit 1
fi

ICON_FILE="$(find "$KITTY_DIR/share/icons/hicolor" -type f \
  \( -name 'kitty.png' -o -name 'kitty.svg' \) \
  -print | sort -V | tail -n 1)"

if [[ -z "$ICON_FILE" || ! -f "$ICON_FILE" ]]; then
  echo "错误：未找到 kitty 图标。" >&2
  exit 1
fi

cp "$KITTY_DIR/share/applications/kitty.desktop" \
  "$APPDIR/kitty.desktop"

# 避免桌面环境在挂载 AppImage 前检查宿主机中的 kitty。
sed -i '/^TryExec=/d' "$APPDIR/kitty.desktop"

case "$ICON_FILE" in
  *.svg)
    cp "$ICON_FILE" "$APPDIR/kitty.svg"
    ln -sf kitty.svg "$APPDIR/.DirIcon"
    ;;
  *)
    cp "$ICON_FILE" "$APPDIR/kitty.png"
    ln -sf kitty.png "$APPDIR/.DirIcon"
    ;;
esac

cat > "$APPDIR/AppRun" <<'APPRUN_EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${APPDIR:-}" ]]; then
  APPDIR="$(cd -- "$(dirname -- "$0")" && pwd)"
fi

KITTY_HOME="$APPDIR/usr/lib/kitty.app"
KITTY_TERMINFO_DIR="$KITTY_HOME/share/terminfo"

export APPDIR
export PATH="$KITTY_HOME/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$KITTY_HOME/lib:${LD_LIBRARY_PATH:-}"
export XDG_DATA_DIRS="$KITTY_HOME/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# kitty 设置 TERM=xterm-kitty；tmux 和其他 ncurses 程序必须能读取对应数据库。
# TERMINFO 指向 AppImage 内数据库，TERMINFO_DIRS 末尾空项继续搜索系统默认目录。
existing_terminfo_dirs="${TERMINFO_DIRS:-}"
export TERMINFO="$KITTY_TERMINFO_DIR"
if [[ -n "$existing_terminfo_dirs" ]]; then
  export TERMINFO_DIRS="$KITTY_TERMINFO_DIR:$existing_terminfo_dirs"
else
  export TERMINFO_DIRS="$KITTY_TERMINFO_DIR:"
fi

# AppImage runtime 将原始启动路径保存在 ARGV0 中。
# 通过 kitten 软链接启动时调用内部 kitten，其余名称调用 kitty。
command_name="$(basename -- "${ARGV0:-${APPIMAGE:-$0}}")"
case "$command_name" in
  kitten)
    KITTY_COMMAND="$KITTY_HOME/bin/kitten"
    ;;
  *)
    KITTY_COMMAND="$KITTY_HOME/bin/kitty"
    ;;
esac

# Fcitx5 在 X11 下通过 kitty 的 IBus GLFW 后端提供输入法。
# 不继承外部 IBUS_ADDRESS，避免旧会话或固定地址让 kitty 接入失效的 IBus。
export XMODIFIERS=@im=fcitx
unset IBUS_ADDRESS
unset GLFW_IM_MODULE

# 按 kitty/Fcitx5 的规则计算当前显示器对应的原生 IBus 地址文件。
get_ibus_address_file() {
  if [[ -n "${IBUS_ADDRESS_FILE:-}" ]]; then
    printf '%s\n' "$IBUS_ADDRESS_FILE"
    return 0
  fi

  local machine_id=""
  if [[ -r /etc/machine-id ]]; then
    machine_id="$(tr -d '\r\n' < /etc/machine-id)"
  elif [[ -r /var/lib/dbus/machine-id ]]; then
    machine_id="$(tr -d '\r\n' < /var/lib/dbus/machine-id)"
  fi
  [[ -n "$machine_id" && -n "${HOME:-}" ]] || return 1

  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local host="unix"
  local display_number=""
  local display_value=""

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    display_number="$WAYLAND_DISPLAY"
  else
    display_value="${DISPLAY:-:0.0}"
    [[ "$display_value" == *:* ]] || return 1
    host="${display_value%:*}"
    display_number="${display_value##*:}"
    display_number="${display_number%%.*}"
    [[ -n "$host" ]] || host="unix"
  fi

  [[ -n "$display_number" ]] || return 1
  printf '%s/ibus/bus/%s-%s-%s\n' \
    "$config_home" "$machine_id" "$host" "$display_number"
}

# --version/+runpy/kitten 不创建正常终端窗口，不等待输入法。
should_check_ibus=1
if [[ "$command_name" == "kitten" ]]; then
  should_check_ibus=0
else
  case "${1:-}" in
    --version|--help|+runpy)
      should_check_ibus=0
      ;;
  esac
fi

if [[ "$should_check_ibus" -eq 1 ]]; then
  ibus_file="$(get_ibus_address_file 2>/dev/null || true)"
  ibus_ready=0

  # 用本次系统启动时间识别上一次开机留下的旧 IBus 地址文件。
  now_epoch="$(date +%s 2>/dev/null || printf '0')"
  uptime_seconds="$(cut -d. -f1 /proc/uptime 2>/dev/null || printf '0')"
  boot_epoch=0
  if [[ "$now_epoch" =~ ^[0-9]+$ && "$uptime_seconds" =~ ^[0-9]+$ ]]; then
    boot_epoch=$((now_epoch - uptime_seconds))
  fi

  # 地址文件已是本次开机生成且至少稳定 3 秒时，手动启动 kitty 不增加等待。
  if [[ -n "$ibus_file" && -r "$ibus_file" ]]; then
    ibus_address="$(sed -n 's/^IBUS_ADDRESS=//p' "$ibus_file" 2>/dev/null | head -n 1)"
    ibus_mtime="$(stat -c %Y "$ibus_file" 2>/dev/null || printf '0')"
    if [[ -n "$ibus_address" && "$ibus_mtime" =~ ^[0-9]+$ ]]; then
      if (( boot_epoch == 0 || ibus_mtime >= boot_epoch )); then
        ibus_age=$((now_epoch - ibus_mtime))
        if (( ibus_age >= 3 )); then
          ibus_ready=1
        fi
      fi
    fi
  fi

  # 开机自启时最多等待 20 秒；必须是本次开机的新地址，并连续 3 秒没有再变化。
  if [[ "$ibus_ready" -eq 0 && -n "$ibus_file" ]]; then
    previous_snapshot=""
    stable_ticks=0
    for ((attempt=0; attempt<80; attempt++)); do
      if [[ -r "$ibus_file" ]]; then
        ibus_address="$(sed -n 's/^IBUS_ADDRESS=//p' "$ibus_file" 2>/dev/null | head -n 1)"
        ibus_mtime="$(stat -c %Y "$ibus_file" 2>/dev/null || printf '0')"

        if [[ -n "$ibus_address" && "$ibus_mtime" =~ ^[0-9]+$ ]] && \
           (( boot_epoch == 0 || ibus_mtime >= boot_epoch )); then
          snapshot="$ibus_address|$ibus_mtime"
          if [[ "$snapshot" == "$previous_snapshot" ]]; then
            stable_ticks=$((stable_ticks + 1))
          else
            previous_snapshot="$snapshot"
            stable_ticks=0
          fi

          if (( stable_ticks >= 12 )); then
            ibus_ready=1
            break
          fi
        else
          previous_snapshot=""
          stable_ticks=0
        fi
      fi
      sleep 0.25
    done
  fi

  if [[ "$ibus_ready" -eq 1 ]]; then
    export GLFW_IM_MODULE=ibus

    # Fcitx5 显式指定自定义地址文件时，让 kitty 使用同一个动态维护文件。
    if [[ -n "${IBUS_ADDRESS_FILE:-}" ]]; then
      export IBUS_ADDRESS="$ibus_file"
    fi
  fi
fi

# kitty 是新的独立终端窗口，不应继承父级 tmux 的客户端环境。
# 否则从 Alacritty 的 tmux 启动 kitty 后，smug 会误用父级 switch-client。
if [[ "$command_name" != "kitten" && -n "${TMUX:-}" ]]; then
  unset TMUX TMUX_PANE
fi

# 只过滤没有 desktop portal 时产生的已知无害警告。
"$KITTY_COMMAND" "$@" 2> >(
  sed -u '/process_desktop_settings: failed with error: org\.freedesktop\.DBus\.Error\.ServiceUnknown:/d' >&2
)
APPRUN_EOF

chmod +x "$APPDIR/AppRun"
bash -n "$APPDIR/AppRun"
grep -q '^export XMODIFIERS=@im=fcitx$' "$APPDIR/AppRun"
grep -q '^unset GLFW_IM_MODULE$' "$APPDIR/AppRun"
grep -q 'boot_epoch=' "$APPDIR/AppRun"
grep -q 'attempt<80' "$APPDIR/AppRun"
grep -q 'stable_ticks >= 12' "$APPDIR/AppRun"
grep -q '^    export GLFW_IM_MODULE=ibus$' "$APPDIR/AppRun"
grep -q '^unset IBUS_ADDRESS$' "$APPDIR/AppRun"
if grep -q 'kitty-ibus-address-' "$APPDIR/AppRun"; then
  echo "错误：AppRun 不应生成固定的临时 IBus 地址文件。" >&2
  exit 1
fi
grep -q '^export TERMINFO=' "$APPDIR/AppRun"
grep -q 'ARGV0:-' "$APPDIR/AppRun"
grep -q 'KITTY_COMMAND="$KITTY_HOME/bin/kitten"' "$APPDIR/AppRun"
grep -q '^  unset TMUX TMUX_PANE$' "$APPDIR/AppRun"

# --version 不会完整验证嵌入式 Python；使用 +runpy 检查真正入口。
TEST_OUTPUT="$(
  "$KITTY_DIR/bin/kitty" \
    +runpy 'print("kitty-python-ok")'
)"

if [[ "$TEST_OUTPUT" != *"kitty-python-ok"* ]]; then
  echo "错误：kitty 官方目录 Python 入口测试失败。" >&2
  exit 1
fi

curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o /tmp/appimagetool

curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o /tmp/runtime-x86_64

chmod +x /tmp/appimagetool /tmp/runtime-x86_64

APPIMAGE_EXTRACT_AND_RUN=1 \
  /tmp/appimagetool -n \
  --runtime-file /tmp/runtime-x86_64 \
  "$APPDIR" \
  "$OUTFILE"

test -x "$OUTFILE"

APPIMAGE_EXTRACT_AND_RUN=1 "$OUTFILE" --version

TEST_OUTPUT="$(
  APPIMAGE_EXTRACT_AND_RUN=1 \
    "$OUTFILE" \
    +runpy 'print("kitty-appimage-python-ok")'
)"

if [[ "$TEST_OUTPUT" != *"kitty-appimage-python-ok"* ]]; then
  echo "错误：最终 AppImage 的 kitty Python 入口测试失败。" >&2
  exit 1
fi

# 验证成品中的 terminfo 文件和导出的 TERMINFO 路径。
TERMINFO_TEST="$(
  APPIMAGE_EXTRACT_AND_RUN=1 \
    "$OUTFILE" \
    +runpy 'import os; p=os.environ.get("TERMINFO", ""); print("ok" if os.path.isfile(os.path.join(p, "x", "xterm-kitty")) else "missing")'
)"

if [[ "$TERMINFO_TEST" != *"ok"* ]]; then
  echo "错误：最终 AppImage 未正确提供 xterm-kitty terminfo。" >&2
  exit 1
fi

# 验证 kitten 软链接确实分流到内部 kitten。
KITTEN_LINK="$OUTDIR/kitten"
ln -sf "$(basename -- "$OUTFILE")" "$KITTEN_LINK"
KITTEN_HELP="$(APPIMAGE_EXTRACT_AND_RUN=1 "$KITTEN_LINK" --help)"
rm -f "$KITTEN_LINK"

if [[ "$KITTEN_HELP" != *"Usage: kitten"* ]]; then
  echo "错误：kitten 软链接未分流到内部 kitten。" >&2
  exit 1
fi

echo "已生成：$OUTFILE"
