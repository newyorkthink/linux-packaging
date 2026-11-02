#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="$1"
SOURCE_DIR="$2"

# linuxdeploy 会调整 ELF 的 RPATH；恢复完整官方 bundle，保留 Flutter 的相邻 lib 和 data。
rm -rf "$APPDIR/usr/lib/rvncconnect"
cp -a "$SOURCE_DIR/rvncconnect" "$APPDIR/usr/lib/rvncconnect"

# 恢复官方 URL handler 文件，不干预 linuxdeploy 生成的 AppRun 或 hooks。
cp -a "$SOURCE_DIR/desktop-files/." "$APPDIR/usr/share/applications/"

# 保留原有排除规则，glibc 和 GPU 驱动使用宿主机版本，不改动恢复后的官方 bundle。
while IFS= read -r -d '' item; do
    case "${item##*/}" in
        ld-linux*.so*|libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|\
        libresolv.so*|libnss_*.so*|libEGL.so*|libGL.so*|libGLX.so*|\
        libGLdispatch.so*|libOpenGL.so*|libgbm.so*|libdrm.so*|libvulkan.so*)
            rm -f "$item"
            ;;
    esac
done < <(find "$APPDIR/usr/lib" -path "$APPDIR/usr/lib/rvncconnect" -prune -o \( -type f -o -type l \) -print0)

find "$APPDIR/usr/lib" -path "$APPDIR/usr/lib/rvncconnect" -prune -o -type d \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) -prune -exec rm -rf {} +
