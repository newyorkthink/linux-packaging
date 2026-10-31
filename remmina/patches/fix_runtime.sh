#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 接收 AppDir 路径，并拒绝空路径、无效目录和根目录。
if [[ $# -ne 1 || -z "${1:-}" || ! -d "$1" ]]; then
  echo "用法：$0 <AppDir>" >&2
  exit 2
fi
APPDIR="$(cd -- "$1" && pwd -P)"
[[ "$APPDIR" != / ]] || {
  echo "错误：不能将根目录作为 AppDir。" >&2
  exit 2
}

# 从包内原始布局确定编译路径，避免依赖宿主机的安装位置。
mapfile -t RDP_PLUGINS < <(find "$APPDIR/usr/lib" -type f -path '*/remmina/plugins/remmina-plugin-rdp.so' -print)
mapfile -t WEBKIT_DIRS < <(find "$APPDIR/usr/lib" -type d -path '*/webkit2gtk-4.1' -print)
if (( ${#RDP_PLUGINS[@]} != 1 || ${#WEBKIT_DIRS[@]} != 1 )); then
  echo "错误：无法唯一确定包内 Remmina 插件目录或 WebKitGTK 目录。" >&2
  exit 1
fi
PLUGIN_SOURCE_DIR="$(dirname "${RDP_PLUGINS[0]#"$APPDIR"}")"
WEBKIT_SOURCE_DIR="${WEBKIT_DIRS[0]}"

# Remmina 的协议插件路径编译为绝对路径，部署后改为随 AppDir 工作目录加载。
python3 - "$APPDIR/usr/bin/remmina" "$PLUGIN_SOURCE_DIR" <<'PY'
from pathlib import Path
import sys

binary = Path(sys.argv[1])
old = sys.argv[2].encode() + b"\0"
new = b"/proc/self/cwd/plugins\0"
data = binary.read_bytes()

if new in data:
    pass
elif data.count(old) == 1:
    if len(new) > len(old):
        raise SystemExit("runtime plugin path is longer than compiled plugin path")
    data = data.replace(old, new + b"\0" * (len(old) - len(new)), 1)
    binary.write_bytes(data)
else:
    raise SystemExit(f"cannot find unique compiled plugin path: {sys.argv[2]}")
PY

# Remmina 主程序和协议插件使用绝对翻译目录，部署后改为 AppDir 内的相对目录。
python3 - "$APPDIR/usr/bin/remmina" "$APPDIR/plugins" <<'PY'
from pathlib import Path
import sys

targets = [Path(sys.argv[1]), *sorted(Path(sys.argv[2]).glob("*.so"))]
old = b"/usr/share/locale\0"
new = b"usr/share/locale\0"

patched = 0
already_patched = 0
for target in targets:
    data = target.read_bytes()
    count = data.count(old)
    if count:
        data = data.replace(old, new + b"\0" * (len(old) - len(new)))
        target.write_bytes(data)
        patched += count
    else:
        already_patched += data.count(new)

if patched == 0 and already_patched == 0:
    raise SystemExit("cannot find compiled Remmina locale path")
PY

# WebKit 依赖库由 linuxdeploy 部署后才能完整修正，此处将其子进程目录改为包内运行目录。
OLD_BASE="${WEBKIT_SOURCE_DIR#"$APPDIR"}"
NEW_BASE="/proc/self/cwd/webkit"
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
already_patched = 0
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
    else:
        already_patched += data.count(new)

if total == 0 and already_patched == 0:
    raise SystemExit(f"cannot find compiled WebKitGTK directory: {old_text}")
print(f"已修正 WebKitGTK 目录：{old_text} -> {new_text}，共 {total} 处")
PY

# 部署完成后清理宿主 GPU 驱动库和 WebKit 扫描副本，运行时继续使用宿主图形驱动。
find "$APPDIR" \( -type f -o -type l \) -print | while IFS= read -r item; do
  case "$(basename "$item")" in
    libEGL.so*|libGL.so*|libGLX.so*|libGLdispatch.so*|libOpenGL.so*|libgbm.so*|libdrm.so*|libvulkan.so*)
      rm -f "$item"
      ;;
  esac
done
find "$APPDIR" -type d \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) -prune -exec rm -rf {} + 2>/dev/null || true

rm -f "$APPDIR/usr/bin/WebKitWebProcess" "$APPDIR/usr/bin/WebKitNetworkProcess" "$APPDIR/usr/bin/WebKitGPUProcess"

# Remmina 不使用 fluidsynth MIDI，移除 GStreamer 自动部署的可选插件。
find "$APPDIR/usr/lib" -type f -name 'libgstfluidsynthmidi.so' -delete

# 清理打包结果中的 glibc 运行库，避免与宿主加载器混用。
is_glibc_runtime() {
  case "$(basename "$1")" in
    ld-linux*.so*|libc.so*|libpthread.so*|libdl.so*|librt.so*|libm.so*|libresolv.so*|libutil.so*|libanl.so*|libBrokenLocale.so*|libnss_*.so*|libthread_db.so*)
      return 0
      ;;
  esac
  return 1
}

find "$APPDIR/usr/lib" -maxdepth 1 \( -type f -o -type l \) -print | while IFS= read -r library; do
  if is_glibc_runtime "$library"; then
    rm -f "$library"
  fi
done
