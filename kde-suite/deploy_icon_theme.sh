# KDE Suite 的标准 Breeze 图标主题兼容部署函数。

if [ "${KDE_SUITE_ICON_THEME_HELPERS_READY:-0}" = "1" ]; then
    return 0
fi
KDE_SUITE_ICON_THEME_HELPERS_READY=1

# KDE Suite 统一使用已经打包的 Breeze/Breeze Dark。
# 若宿主 Qt6ct 仍选择 Flat-Remix-Blue-Dark，则提供一个仅继承 Breeze 的兼容入口，
# 避免“主题不存在”警告，同时不再混入 Flat Remix 的文件夹、操作和状态图标。
deploy_breeze_icon_theme() {
    local compatibility_theme

    test -f AppDir/share/icons/breeze/index.theme
    test -f AppDir/share/icons/breeze-dark/index.theme
    test -f AppDir/share/icons/hicolor/index.theme

    compatibility_theme="AppDir/share/icons/Flat-Remix-Blue-Dark"
    rm -rf "$compatibility_theme" AppDir/share/licenses/flat-remix
    mkdir -p "$compatibility_theme/compat"

    cat > "$compatibility_theme/index.theme" <<'EOF_ICON_THEME'
[Icon Theme]
Name=Flat-Remix-Blue-Dark
Comment=Compatibility alias to the bundled Breeze icon theme
Inherits=breeze
Directories=compat

[compat]
Size=16
Context=Actions
Type=Fixed
EOF_ICON_THEME

    # 保留一个非图标占位文件，确保空的兼容目录进入最终 AppImage。
    : > "$compatibility_theme/compat/.keep"

    test -f "$compatibility_theme/index.theme"
    test -f "$compatibility_theme/compat/.keep"
    grep -q '^Inherits=breeze$' "$compatibility_theme/index.theme"
    grep -q '^Directories=compat$' "$compatibility_theme/index.theme"

    if find "$compatibility_theme" -type f \
      \( -name '*.svg' -o -name '*.png' -o -name '*.xpm' \) \
      -print -quit | grep -q .; then
        echo "错误：Flat-Remix-Blue-Dark 兼容入口中不应包含实际图标文件。" >&2
        exit 1
    fi
}
