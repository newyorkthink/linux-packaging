#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="$1"
SOURCE_DIR="$2"

# 保存未经 linuxdeploy 修改的 Flutter bundle，供最终封装前恢复。
cp -a "$APPDIR/usr/lib/rvncconnect" "$SOURCE_DIR/rvncconnect"

# linuxdeploy 自动选择主 desktop 时，暂存没有 Icon 的 URL handler，部署后恢复。
mkdir -p "$SOURCE_DIR/desktop-files" "$APPDIR/usr/bin"
mv "$APPDIR/usr/share/applications/com.realvnc.rvncconnect.connect.uri.desktop" "$SOURCE_DIR/desktop-files/"

# 保留官方桌面信息，规范 Desktop Entry 版本、启动参数和图标名称。
sed -i -e 's/\r$//' -e 's/^Version=.*/Version=1.0/' -e 's|^Exec=.*|Exec=rvncconnect %U|' -e 's/^Icon=.*/Icon=com.realvnc.rvncconnect/' -e 's/^Categories=.*/Categories=Network;RemoteAccess;/' "$APPDIR/usr/share/applications/com.realvnc.rvncconnect.desktop"

# 仅 RealVNC 已确认需要此隔离；以后其他程序有相同需求，再考虑移入公共脚本。
cat > "$APPDIR/usr/bin/xdg-open" <<'XDG_OPEN'
#!/usr/bin/env bash
set -Eeuo pipefail

host_path="${RVNC_HOST_PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
host_xdg_data_dirs="${RVNC_HOST_XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
host_ld_library_path="${RVNC_HOST_LD_LIBRARY_PATH:-}"

# 根 AppRun 执行前，官方 GTK hook 可能已经加上包内目录；宿主浏览器须去掉该前缀。
if [[ -n "${APPDIR:-}" ]]; then
    host_xdg_data_dirs="${host_xdg_data_dirs#"$APPDIR/usr/share:/usr/share:"}"
fi
host_xdg_data_dirs="${host_xdg_data_dirs:-/usr/local/share:/usr/share}"

host_xdg_open="$(PATH="$host_path" command -v xdg-open || true)"
if [[ -z "$host_xdg_open" ]]; then
    echo "错误：宿主机没有可用的 xdg-open。" >&2
    exit 127
fi

# 恢复宿主机搜索路径，并清除包内 GTK、GIO、Qt 和 AppImage 环境，避免影响浏览器。
env_args=(
    -u APPDIR -u APPIMAGE -u APPIMAGE_GTK_THEME -u APPIMAGE_SILENT_INSTALL
    -u ARGV0 -u OWD -u LD_LIBRARY_PATH -u LD_PRELOAD
    -u GTK_DATA_PREFIX -u GTK_EXE_PREFIX -u GTK_PATH -u GTK_IM_MODULE_FILE
    -u GTK_THEME -u GTK_MODULES -u GTK3_MODULES -u GDK_BACKEND
    -u GDK_PIXBUF_MODULE_FILE -u GDK_PIXBUF_MODULEDIR -u GSETTINGS_SCHEMA_DIR
    -u GI_TYPELIB_PATH -u GIO_MODULE_DIR -u GIO_EXTRA_MODULES
    -u PANGO_RC_FILE -u PANGO_LIBDIR -u PANGO_SYSCONFDIR
    -u PYTHONHOME -u PYTHONPATH -u QT_PLUGIN_PATH -u QML2_IMPORT_PATH
    -u RVNC_HOST_PATH -u RVNC_HOST_XDG_DATA_DIRS -u RVNC_HOST_LD_LIBRARY_PATH
    PATH="$host_path" XDG_DATA_DIRS="$host_xdg_data_dirs"
)
if [[ -n "$host_ld_library_path" ]]; then
    env_args+=(LD_LIBRARY_PATH="$host_ld_library_path")
fi
exec env "${env_args[@]}" "$host_xdg_open" "$@"
XDG_OPEN

chmod +x "$APPDIR/usr/bin/xdg-open"
