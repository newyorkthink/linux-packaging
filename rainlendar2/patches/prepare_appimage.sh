#!/usr/bin/env bash
set -Eeuo pipefail

# 输出应用准备失败的原因。
fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

(( $# == 2 )) || fail '用法：prepare_appimage.sh <prepare|finalize> <AppDir>'
phase="$1"
appdir="$(cd -- "$2" && pwd -P)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

program_dir="$appdir/usr/lib/rainlendar2"
program="$program_dir/rainlendar2"
ibus_module="$appdir/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so"
canberra_library="$appdir/usr/lib/libcanberra.so.0"
canberra_pulse="$appdir/usr/lib/libcanberra-pulse.so"

[[ -x "$program" && -f "$program_dir/resources/alarm.wav" ]] ||
  fail '官方 DEB 缺少 Rainlendar2 主程序或默认铃声。'

# 将 libcanberra 编译时的绝对驱动路径改为由包内 LTDL_LIBRARY_PATH 解析的名称。
patch_canberra_driver() {
  local library="$1"
  local portable='libcanberra-%s'
  local original offset padding
  local -a templates matches

  mapfile -t templates < <(
    LC_ALL=C strings -- "$library" | grep -E '^/.*/libcanberra-[^/]+/libcanberra-%s$'
  )
  [[ -n "${templates[0]:-}" && ! -v 'templates[1]' ]] ||
    fail '无法唯一识别 libcanberra 的绝对驱动路径。'
  original="${templates[0]}"
  (( ${#portable} <= ${#original} )) || fail 'libcanberra 的驱动路径长度异常。'

  mapfile -t matches < <(LC_ALL=C grep -Fabo -- "$original" "$library")
  [[ -n "${matches[0]:-}" && ! -v 'matches[1]' ]] ||
    fail 'libcanberra 的绝对驱动路径在二进制中不唯一。'
  offset="${matches[0]%%:*}"
  padding=$(( ${#original} - ${#portable} ))

  {
    printf '%s' "$portable"
    head -c "$padding" /dev/zero
  } | dd of="$library" bs=1 seek="$offset" conv=notrunc status=none

  if grep -Fqa -- "$original" "$library"; then
    fail 'libcanberra 仍引用宿主驱动目录。'
  fi
  grep -Fqa -- "$portable" "$library" || fail 'libcanberra 的相对驱动路径写入失败。'
}

case "$phase" in
  prepare)
    # 保留上游桌面文件和 PNG，由 linuxdeploy 部署根入口与图标。
    desktop="$appdir/usr/share/applications/rainlendar2.desktop"
    icon="$appdir/usr/share/pixmaps/rainlendar2.png"
    [[ -f "$desktop" && -f "$icon" ]] || fail '官方 DEB 缺少桌面入口或 PNG 图标。'
    sed -i -e 's/^Icon=.*/Icon=rainlendar2/' -e 's/^Categories=.*/Categories=Office;Calendar;/' "$desktop"

    # 在 linuxdeploy 扫描 usr/lib 前放入通过 dlopen 加载的库和 GTK3 输入模块。
    multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
    system_lib="/usr/lib/$multiarch"
    pulse_source="$(find "$system_lib" -type f -name libcanberra-pulse.so -print -quit)"
    ibus_source="$(find "$system_lib" -type f -path '*/gtk-3.0/*/immodules/im-ibus.so' -print -quit)"
    [[ -f "$pulse_source" && -f "$ibus_source" ]] || fail '构建环境缺少 Pulse 驱动或 GTK3 IBus 模块。'

    for soname in libstdc++.so.6 libgcc_s.so.1 libibus-1.0.so.5 libcanberra.so.0; do
      [[ -f "$system_lib/$soname" ]] || fail "构建环境缺少 $soname。"
      install -D -m 0644 -- "$system_lib/$soname" "$appdir/usr/lib/$soname"
    done
    install -D -m 0644 -- "$pulse_source" "$canberra_pulse"
    install -D -m 0644 -- "$ibus_source" "$ibus_module"
    ;;

  finalize)
    # 保留 linuxdeploy 的启动包装层，只移除会导致 Rainlendar2 闪退的 Fcitx GTK 模块。
    find "$appdir/usr/lib" \( -type f -o -type l \) \
      \( -name im-fcitx5.so -o -name 'libFcitx5GClient.so*' \) -delete

    [[ -f "$ibus_module" && -f "$canberra_pulse" && -f "$canberra_library" ]] ||
      fail '部署后缺少 IBus 模块或铃声库。'

    # 确认待修改文件仍位于 AppDir，再执行已知布局的兼容补丁。
    library="$(readlink -f -- "$canberra_library")"
    binary="$(readlink -f -- "$program")"
    [[ "$library" == "$appdir/"* && "$binary" == "$program_dir/"* ]] ||
      fail '待打补丁的文件不在 AppDir 预期位置。'

    patch_canberra_driver "$library"
    python3 "$script_dir/patch_rainlendar_getpath.py" patch "$binary"
    python3 "$script_dir/patch_rainlendar_getpath.py" check "$binary"

    # glibc 和动态加载器继续由宿主提供。
    if [[ -n "$(find "$appdir" \( -type f -o -type l \) \
      \( -name libc.so.6 -o -name ld-linux-x86-64.so.2 \) -print -quit)" ]]; then
      fail 'AppDir 中不应包含 glibc 或动态加载器。'
    fi
    ;;

  *)
    fail "未知准备阶段：$phase"
    ;;
esac
