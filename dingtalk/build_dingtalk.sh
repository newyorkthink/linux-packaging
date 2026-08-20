#!/usr/bin/env bash
# 使用 AUR dingtalk-bin 安装后的完整官方运行目录构建 DingTalk AppImage。
# 钉钉自带 Qt/CEF 和私有库，因此保留原目录结构，仅补充系统动态库并用 appimagetool 封装。
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
    printf '[DingTalk] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

readonly HOST_ARCH="$(uname -m)"
[[ "$HOST_ARCH" == "x86_64" ]] || die "当前仅支持 x86_64。"

for command_name in \
    appimagetool awk bash file find grep install ldd lddtree patchelf \
    readelf readlink sed sha256sum sort timeout xvfb-run; do
    command -v "$command_name" >/dev/null 2>&1 || \
        die "构建环境缺少命令：$command_name"
done

readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly SOURCE_RELEASE="$SOURCE_DIR/release"
readonly SOURCE_META="$SOURCE_DIR/meta"
readonly SOURCE_DESKTOP="$SOURCE_META/com.alibabainc.dingtalk.desktop"
readonly SOURCE_ICON="$SOURCE_META/com.alibabainc.dingtalk.svg"
readonly VERSION_FILE="$SOURCE_META/package-version"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly RELEASE_DIR="$APPDIR/opt/dingtalk/release"
# 钉钉主程序直接依赖该目录中的 libcef.so，官方启动器也会预加载此库。
readonly CEF_LIB_DIR="$RELEASE_DIR/plugins/dtwebview"
readonly RUNTIME_LIB="$APPDIR/usr/lib/dingtalk-runtime"
readonly DINGTALK_LIBRARY_PATH="$RELEASE_DIR:$CEF_LIB_DIR:$RUNTIME_LIB"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/DingTalk.AppImage"
readonly BUILD_LOG="$SCRIPT_DIR/dingtalk-smoke.log"

for required_path in \
    "$SOURCE_RELEASE/com.alibabainc.dingtalk" \
    "$SOURCE_RELEASE/plugins/dtwebview/libcef.so" \
    "$SOURCE_DESKTOP" \
    "$SOURCE_ICON" \
    "$VERSION_FILE"; do
    [[ -e "$required_path" ]] || die "缺少 AUR 提取文件：$required_path"
done
[[ -x "$SOURCE_RELEASE/com.alibabainc.dingtalk" ]] || \
    die "钉钉主程序不可执行。"
file "$SOURCE_RELEASE/com.alibabainc.dingtalk" | grep -q 'ELF 64-bit' || \
    die "钉钉主程序不是 64 位 ELF。"

readonly PACKAGE_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ -n "$PACKAGE_VERSION" ]] || die "AUR 包版本为空。"

rm -rf "$APPDIR" "$DIST_DIR" "$BUILD_LOG"
mkdir -p "$RELEASE_DIR" "$RUNTIME_LIB" "$APPDIR/usr/bin" \
    "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps" \
    "$DIST_DIR"

log "复制 AUR 安装后的完整钉钉运行目录"
cp -a "$SOURCE_RELEASE/." "$RELEASE_DIR/"
chmod 0755 "$RELEASE_DIR/com.alibabainc.dingtalk"

# 新内核和 glibc 会拒绝加载带可执行栈标记的钉钉私有库。
# 对所有 ELF 文件执行幂等清理，覆盖 dingtalk_dll.so、会议库及后续版本新增库。
log "清除钉钉 ELF 文件的可执行栈标记"
while IFS= read -r -d '' target; do
    readelf -h "$target" >/dev/null 2>&1 || continue
    elf_type="$(readelf -h "$target" | awk '/^[[:space:]]*Type:/{print $2; exit}')"
    case "$elf_type" in
        DYN|EXEC) patchelf --clear-execstack "$target" ;;
    esac
done < <(find "$RELEASE_DIR" -type f -print0)

copy_dependency() {
    local source="$1"
    local real source_name real_name

    [[ -f "$source" ]] || return 0
    case "$source" in
        "$RELEASE_DIR"/*|"$RUNTIME_LIB"/*)
            return 0
            ;;
    esac

    source_name="$(basename "$source")"
    case "$source_name" in
        ld-linux*.so*|libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|\
        libresolv.so.*|libutil.so.*|libnss_*.so.*|libanl.so.*|libthread_db.so.*|\
        libGL.so.*|libEGL.so.*|libGLX.so.*|libOpenGL.so.*|libvulkan.so.*|\
        libdrm.so.*|libgbm.so.*)
            return 0
            ;;
    esac

    real="$(readlink -f "$source")"
    [[ -f "$real" ]] || return 0
    real_name="$(basename "$real")"

    if [[ ! -e "$RUNTIME_LIB/$real_name" ]]; then
        cp -L "$real" "$RUNTIME_LIB/$real_name"
        chmod 0755 "$RUNTIME_LIB/$real_name"
    fi
    if [[ "$source_name" != "$real_name" ]]; then
        ln -sfn "$real_name" "$RUNTIME_LIB/$source_name"
    fi
}

collect_dependencies() {
    local target="$1"
    local dependency

    readelf -h "$target" >/dev/null 2>&1 || return 0
    while IFS= read -r dependency; do
        case "$dependency" in
            /*) copy_dependency "$dependency" ;;
        esac
    done < <(
        LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" \
            lddtree -l "$target" 2>/dev/null | sort -u
    )
}

# 扫描主程序、Qt/CEF 插件、会议组件和私有库，收集它们在 Ubuntu 24.04 上的外部依赖。
log "收集钉钉所有 ELF 文件的外部动态库"
while IFS= read -r -d '' target; do
    collect_dependencies "$target"
done < <(find "$RELEASE_DIR" -type f -print0)

# 再扫描一次已复制的运行库，保证其递归依赖完整。
while IFS= read -r -d '' target; do
    collect_dependencies "$target"
done < <(find "$RUNTIME_LIB" -type f -print0)

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
set -e

APPDIR="${APPDIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"
RELEASE_DIR="$APPDIR/opt/dingtalk/release"
CEF_LIB_DIR="$RELEASE_DIR/plugins/dtwebview"
RUNTIME_LIB="$APPDIR/usr/lib/dingtalk-runtime"

export PATH="$APPDIR/usr/bin:${PATH:-/usr/bin:/bin}"
export LD_LIBRARY_PATH="$RELEASE_DIR:$CEF_LIB_DIR:$RUNTIME_LIB"
# 预加载内置 CEF，保持与钉钉官方 Elevator.sh 的启动方式一致。
export LD_PRELOAD="$CEF_LIB_DIR/libcef.so${LD_PRELOAD:+:$LD_PRELOAD}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"
export QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"
export GTK_IM_MODULE="${GTK_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

if [ -d "$RELEASE_DIR/plugins" ]; then
    export QT_PLUGIN_PATH="$RELEASE_DIR/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
fi
if [ -d "$RELEASE_DIR/plugins/platforms" ]; then
    export QT_QPA_PLATFORM_PLUGIN_PATH="$RELEASE_DIR/plugins/platforms"
fi

cd "$RELEASE_DIR"
exec "$RELEASE_DIR/com.alibabainc.dingtalk" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun"
ln -sfn ../../AppRun "$APPDIR/usr/bin/dingtalk"

# AUR 当前 desktop 文件含重复 Name 键，appimagetool 会按 Desktop Entry 规范拒绝。
# 保留每个分组中首次出现的键，其他字段及顺序保持不变。
awk '
    /^\[/ {
        section = $0
        print
        next
    }
    /^[[:space:]]*($|#)/ {
        print
        next
    }
    {
        separator = index($0, "=")
        if (separator == 0) {
            print
            next
        }
        key = substr($0, 1, separator - 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
        scoped_key = section SUBSEP key
        if (!(scoped_key in seen)) {
            seen[scoped_key] = 1
            print
        }
    }
' "$SOURCE_DESKTOP" > "$APPDIR/com.alibabainc.dingtalk.desktop"
sed -i \
    -e 's|^Exec=.*|Exec=dingtalk|' \
    -e 's|^Icon=.*|Icon=com.alibabainc.dingtalk|' \
    "$APPDIR/com.alibabainc.dingtalk.desktop"
grep -Fx 'Exec=dingtalk' "$APPDIR/com.alibabainc.dingtalk.desktop" >/dev/null || \
    die "desktop Exec 修改失败。"
grep -Fx 'Icon=com.alibabainc.dingtalk' "$APPDIR/com.alibabainc.dingtalk.desktop" >/dev/null || \
    die "desktop Icon 修改失败。"
duplicate_desktop_keys="$(
    awk '
        /^\[/ {
            section = $0
            next
        }
        /^[[:space:]]*($|#)/ { next }
        {
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            scoped_key = section SUBSEP key
            if (++seen[scoped_key] == 2) print key
        }
    ' "$APPDIR/com.alibabainc.dingtalk.desktop"
)"
[[ -z "$duplicate_desktop_keys" ]] || \
    die "desktop 文件仍存在重复键：$duplicate_desktop_keys"
cp "$APPDIR/com.alibabainc.dingtalk.desktop" \
    "$APPDIR/usr/share/applications/com.alibabainc.dingtalk.desktop"

cp "$SOURCE_ICON" "$APPDIR/com.alibabainc.dingtalk.svg"
cp "$SOURCE_ICON" \
    "$APPDIR/usr/share/icons/hicolor/scalable/apps/com.alibabainc.dingtalk.svg"
ln -sfn com.alibabainc.dingtalk.svg "$APPDIR/.DirIcon"

bash -n "$APPDIR/AppRun"
[[ -x "$APPDIR/usr/bin/dingtalk" ]] || die "AppImage 命令入口不可执行。"
[[ -x "$RELEASE_DIR/com.alibabainc.dingtalk" ]] || die "AppImage 缺少钉钉主程序。"
[[ -f "$CEF_LIB_DIR/libcef.so" ]] || die "AppImage 缺少钉钉内置 CEF：$CEF_LIB_DIR/libcef.so"

main_dependencies="$(
    LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" \
        ldd "$RELEASE_DIR/com.alibabainc.dingtalk"
)"
printf '%s\n' "$main_dependencies"
if grep -F 'not found' <<<"$main_dependencies"; then
    die "钉钉主程序仍存在缺失动态库。"
fi

missing_dependencies=0
while IFS= read -r -d '' target; do
    readelf -h "$target" >/dev/null 2>&1 || continue
    dependencies="$(LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" ldd "$target" 2>&1 || true)"
    if grep -F 'not found' <<<"$dependencies"; then
        printf '缺失依赖文件：%s\n%s\n' "$target" "$dependencies" >&2
        missing_dependencies=1
    fi
done < <(find "$RELEASE_DIR" "$RUNTIME_LIB" -type f -print0)
[[ "$missing_dependencies" -eq 0 ]] || die "钉钉组件仍存在缺失动态库。"

log "执行 AppDir 图形启动测试"
set +e
QT_QPA_PLATFORM=xcb \
    timeout 15s xvfb-run -a "$APPDIR/AppRun" >"$BUILD_LOG" 2>&1
smoke_status=$?
set -e
if [[ "$smoke_status" -ne 124 ]]; then
    cat "$BUILD_LOG" >&2
    die "AppDir 启动测试提前退出，状态码：$smoke_status"
fi
if grep -E \
    'cannot enable executable stack|symbol lookup error|error while loading shared libraries|Could not load the Qt platform plugin|Segmentation fault|Aborted \(core dumped\)' \
    "$BUILD_LOG"; then
    cat "$BUILD_LOG" >&2
    die "AppDir 启动日志包含致命错误。"
fi

log "使用 appimagetool 生成 AppImage"
ARCH=x86_64 appimagetool "$APPDIR" "$OUTFILE" >/dev/null
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"
"$OUTFILE" --appimage-version >/dev/null
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

log "执行最终 AppImage 图形启动测试"
set +e
APPIMAGE_EXTRACT_AND_RUN=1 QT_QPA_PLATFORM=xcb \
    timeout 15s xvfb-run -a "$OUTFILE" >"$DIST_DIR/dingtalk-final-smoke.log" 2>&1
final_status=$?
set -e
if [[ "$final_status" -ne 124 ]]; then
    cat "$DIST_DIR/dingtalk-final-smoke.log" >&2
    die "最终 AppImage 启动测试提前退出，状态码：$final_status"
fi
if grep -E \
    'cannot enable executable stack|symbol lookup error|error while loading shared libraries|Could not load the Qt platform plugin|Segmentation fault|Aborted \(core dumped\)' \
    "$DIST_DIR/dingtalk-final-smoke.log"; then
    cat "$DIST_DIR/dingtalk-final-smoke.log" >&2
    die "最终 AppImage 启动日志包含致命错误。"
fi
rm -f "$DIST_DIR/dingtalk-final-smoke.log"

cat > "$DIST_DIR/dingtalk-version.txt" <<VERSION
package=dingtalk-bin
version=$PACKAGE_VERSION
source=https://aur.archlinux.org/packages/dingtalk-bin
method=vendor-runtime-plus-appimagetool
entry=opt/dingtalk/release/com.alibabainc.dingtalk
output=$(basename "$OUTFILE")
VERSION

log "已生成：$OUTFILE"
