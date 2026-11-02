#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 仅整理本次已解包的 AppDir，并使用同次取得的 AUR 桌面资源。
if (( $# != 2 )) || [[ -z "$1" || -z "$2" ]]; then
    echo "用法：$0 <AppDir> <AUR 源目录>" >&2
    exit 2
fi
APPDIR="$(readlink -m -- "$1")"
AUR_DIR="$(readlink -m -- "$2")"
[[ -d "$APPDIR" && "$APPDIR" != / ]] || {
    echo "错误：AppDir 必须存在且不能是根目录。" >&2
    exit 1
}
VENDOR_ROOT="$APPDIR/opt/apps/com.alibabainc.dingtalk"
VENDOR_FILES="$VENDOR_ROOT/files"
RELEASE_DIR="$APPDIR/opt/dingtalk/release"
SOURCE_DESKTOP="$AUR_DIR/com.alibabainc.dingtalk.desktop"
SOURCE_ICON="$AUR_DIR/com.alibabainc.dingtalk.svg"

# 按 AUR 当前布局选择唯一的官方运行目录，不固定软件版本。
mapfile -d '' -t release_dirs < <(find "$VENDOR_FILES" -mindepth 1 -maxdepth 1 -type d -name '*-Release.*' -print0)
(( ${#release_dirs[@]} == 1 )) || {
    echo "错误：官方 DEB 必须包含唯一的 *-Release.* 运行目录。" >&2
    exit 1
}

# 沿用 AUR 的目录布局，完整保留 Qt、CEF、插件和相邻程序资源。
mkdir -p "$APPDIR/opt/dingtalk" "$APPDIR/usr/share/doc" "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"
mv -- "${release_dirs[0]}" "$RELEASE_DIR"
mv -- "$VENDOR_FILES/version" "$APPDIR/opt/dingtalk/version"
mv -- "$VENDOR_FILES/doc/com.alibabainc.dingtalk" "$APPDIR/usr/share/doc/dingtalk"
rm -rf -- "$VENDOR_ROOT"

# 沿用 AUR 的工作台中文输入兼容处理，使用构建环境提供的 GTK2。
rm -rf -- "$RELEASE_DIR"/libgtk-x11-2.0.so.*

# 沿用 AUR 的组件清理，移除平台无关资源和将由系统依赖补齐的冲突运行库。
rm -rf -- "$RELEASE_DIR/libm.so.6" "$RELEASE_DIR/Resources/i18n/tool/"*.exe "$RELEASE_DIR/Resources/qss/mac" "$RELEASE_DIR/Resources/web_content/NativeWebContent_"*.zip "$RELEASE_DIR"/libstdc* "$RELEASE_DIR"/libharfbuzz* "$RELEASE_DIR"/libgbm* "$RELEASE_DIR/libcurl.so.4" "$RELEASE_DIR"/libz* "$RELEASE_DIR"/libGL*

# 仅从本次 AppDir 移除依赖旧 libpangox、主程序不使用的诊断组件。
rm -f -- "$RELEASE_DIR/doctor" "$RELEASE_DIR"/libgtkglext-x11-1.0.so* "$RELEASE_DIR"/libgdkglext-x11-1.0.so*

# 保留官方主程序的执行权限与原有 64 位 ELF 输入约束。
chmod 0755 "$RELEASE_DIR/com.alibabainc.dingtalk"
file "$RELEASE_DIR/com.alibabainc.dingtalk" | grep -q 'ELF 64-bit' || {
    echo "错误：钉钉主程序不是 64 位 ELF。" >&2
    exit 1
}

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
sed -i -e 's|^Exec=.*|Exec=dingtalk|' -e 's|^Icon=.*|Icon=com.alibabainc.dingtalk|' "$APPDIR/com.alibabainc.dingtalk.desktop"

# 安装同一份桌面入口和 SVG 图标，PNG 根图标由公共封装入口准备。
cp "$APPDIR/com.alibabainc.dingtalk.desktop" "$APPDIR/usr/share/applications/com.alibabainc.dingtalk.desktop"
cp "$SOURCE_ICON" "$APPDIR/com.alibabainc.dingtalk.svg"
cp "$SOURCE_ICON" "$APPDIR/usr/share/icons/hicolor/scalable/apps/com.alibabainc.dingtalk.svg"

# 保留 dingtalk 命令入口，指向随后由主 build 生成的根 AppRun。
ln -sfn ../../AppRun "$APPDIR/usr/bin/dingtalk"
