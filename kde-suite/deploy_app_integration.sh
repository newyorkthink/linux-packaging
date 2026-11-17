# 由 kde-suite/build_kde_suite.sh 在基础 AppDir 完成后、生成 AppImage 前加载。
# 当前 shell 已提供 SCRIPT_DIR、copy_support_files 和 quick-sharun。

if [ "${KDE_SUITE_OKULAR_ARK_READY:-0}" = "1" ]; then
    return 0
fi
KDE_SUITE_OKULAR_ARK_READY=1

# 部署主程序、回收站设置模块、Gwenview、Kompare、D-Bus 检查工具、Fcitx5 Qt6 输入模块，以及基础脚本未覆盖的插件目录。
quick-sharun /usr/bin/okular /usr/bin/ark /usr/bin/gwenview /usr/bin/kompare /usr/bin/diff /usr/bin/dbus-send \
  /usr/lib/qt6/plugins/kcm_trash.so \
  /usr/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so \
  /usr/lib/qt6/plugins/kf6/parts/gvpart.so \
  /usr/lib/qt6/plugins/kf6/kfileitemaction/slideshowfileitemaction.so \
  /usr/lib/qt6/plugins/kf6/parts/komparepart.so \
  /usr/lib/qt6/plugins/kf6/parts/komparenavtreepart.so

for plugin_dir in \
  /usr/lib/qt6/plugins/okular_generators \
  /usr/lib/qt6/plugins/kerfuffle \
  /usr/lib/qt6/plugins/imageformats
do
    if [ -d "$plugin_dir" ]; then
        quick-sharun "$plugin_dir"
    fi
done

copy_support_files /usr/lib/qt6/plugins/okular_generators AppDir/lib/qt6/plugins/okular_generators
copy_support_files /usr/lib/qt6/plugins/kerfuffle AppDir/lib/qt6/plugins/kerfuffle
copy_support_files /usr/lib/qt6/plugins/imageformats AppDir/lib/qt6/plugins/imageformats

# KDE Connect 图形入口复用已经运行的 kdeconnectd；没有现有后台时才启动同一 AppImage 内的服务。
# 将原 quick-sharun 入口移到其他目录但保留 kdeconnect-app 文件名，确保 sharun 仍能按 argv[0] 正确分派。
# 包装程序保持前台运行，并在图形界面退出时只结束本次启动的后台进程；外部 kdeconnect 入口仍使用该包装程序。
KDECONNECT_REAL_DIR="AppDir/libexec/kde-suite"
if [ -x AppDir/bin/kdeconnect-app ] && [ ! -e "$KDECONNECT_REAL_DIR/kdeconnect-app" ]; then
    mkdir -p "$KDECONNECT_REAL_DIR"
    mv AppDir/bin/kdeconnect-app "$KDECONNECT_REAL_DIR/kdeconnect-app"
    cat > AppDir/bin/kdeconnect-app <<'EOF_KDECONNECT_WRAPPER'
#!/bin/sh

daemon_pid=

stop_daemon() {
    if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
        kill "$daemon_pid" 2>/dev/null || true
        wait "$daemon_pid" 2>/dev/null || true
    fi
}

kdeconnect_service_running() {
    dbus_reply="$(
        "$APPDIR/bin/dbus-send" --session --print-reply=literal --reply-timeout=1000 \
          --dest=org.freedesktop.DBus /org/freedesktop/DBus \
          org.freedesktop.DBus.NameHasOwner string:org.kde.kdeconnect 2>/dev/null
    )" || return 1

    case "$dbus_reply" in
        *true*) return 0 ;;
    esac
    return 1
}

trap stop_daemon EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! kdeconnect_service_running; then
    "$APPDIR/bin/kdeconnectd" >/dev/null 2>&1 &
    daemon_pid=$!

    # 等待本次启动的后台服务取得 D-Bus 名称，避免图形界面再次请求无效的 D-Bus 激活入口。
    attempt=0
    while [ "$attempt" -lt 50 ] && ! kdeconnect_service_running; do
        kill -0 "$daemon_pid" 2>/dev/null || break
        sleep 0.1
        attempt=$((attempt + 1))
    done
fi

# Qt 6.11 与 KDE Connect 26.04 的 QML 缓存路径会在部分设备操作中触发崩溃；
# 只对 KDE Connect 图形程序禁用缓存，不影响套件中的其他 QML 程序。
unset QML_FORCE_DISK_CACHE
export QML_DISABLE_DISK_CACHE=1

"$APPDIR/libexec/kde-suite/kdeconnect-app" "$@"
status=$?
exit "$status"
EOF_KDECONNECT_WRAPPER
    chmod +x AppDir/bin/kdeconnect-app "$KDECONNECT_REAL_DIR/kdeconnect-app"
fi

# Dolphin 在 i3 等非 Plasma 会话中需要 Qt6ct 平台主题在 QApplication 创建前提供完整配色，
# 否则保存为深色后重新启动时，Breeze 样式可能先按浅色调色板创建部分控件，形成黑白混合界面。
QT6CT_PLATFORMTHEME="$(find /usr/lib/qt6/plugins/platformthemes -maxdepth 1 \( -type f -o -type l \) -name '*qt6ct*.so' -print -quit 2>/dev/null || true)"
if [ -z "$QT6CT_PLATFORMTHEME" ]; then
    echo "错误：未找到 Qt6ct 平台主题插件。" >&2
    exit 1
fi
# build_core.sh 已经将整个 platformthemes 目录交给 quick-sharun；这里只补充非可执行支持文件。
copy_support_files /usr/lib/qt6/plugins/platformthemes AppDir/lib/qt6/plugins/platformthemes

# qt6ct 会沿用宿主 qt6ct.conf 的 standard_dialogs；若宿主选择 gtk3 或
# xdgdesktopportal，AppImage 会把文件选择器交给包内原生主题，再连接宿主桌面服务。
# 这会让 Okular“打开文档”和 KDE Connect“共享文件”走同一条不便携路径并崩溃。
# 保留 qt6ct、KDE/LXQt 主题，只移除这两个原生文件对话框后端，让 qt6ct 回退到
# Qt 自带文件选择器；不会改写用户配置，也不影响已打包的 Breeze 外观。
# 个别浅色配色下选中行的对比度可能偏低，这是内置对话框的外观限制；不能为改善颜色恢复会崩溃的后端。
rm -f -- \
  AppDir/lib/qt6/plugins/platformthemes/libqgtk3.so \
  AppDir/lib/qt6/plugins/platformthemes/libqxdgdesktopportal.so

# quick-sharun 会根据可执行文件名裁剪翻译目录，kio-extras_kcms.mo、kxmlgui6.mo 等共享翻译会被误删。
# 所有部署步骤完成后恢复完整简体中文目录，确保回收站设置和 KDE 标准菜单均可翻译。
if [ ! -d /usr/share/locale/zh_CN ]; then
    echo "错误：未找到 /usr/share/locale/zh_CN，无法恢复 KDE Suite 简体中文翻译。" >&2
    exit 1
fi
mkdir -p AppDir/share/locale
rm -rf AppDir/share/locale/zh_CN
cp -a -- /usr/share/locale/zh_CN AppDir/share/locale/

# 文档后端、界面定义和配置描述文件。
mkdir -p AppDir/share
for data_dir in \
  /usr/share/okular \
  /usr/share/ark \
  /usr/share/gwenview \
  /usr/share/qt6ct \
  /usr/share/config.kcfg
do
    if [ -e "$data_dir" ]; then
        cp -a -- "$data_dir" AppDir/share/
    fi
done

mkdir -p AppDir/share/kxmlgui6
for ui_dir in /usr/share/kxmlgui6/okular /usr/share/kxmlgui6/ark; do
    if [ -e "$ui_dir" ]; then
        cp -a -- "$ui_dir" AppDir/share/kxmlgui6/
    fi
done

# 启动器与桌面菜单所需的 Hicolor 图标。
for app_icon in okular gwenview ark kompare; do
    while IFS= read -r -d '' icon_file; do
        relative_icon="${icon_file#/usr/share/icons/}"
        mkdir -p "AppDir/share/icons/$(dirname -- "$relative_icon")"
        cp -a -- "$icon_file" "AppDir/share/icons/$relative_icon"
    done < <(find /usr/share/icons/hicolor -type f -path "*/apps/$app_icon.*" -print0)
done

# Okular PDF、Gwenview 图片、Ark 压缩包管理以及 Kompare 文件比较入口。
mkdir -p AppDir/share/applications
cp -a -- /usr/share/applications/org.kde.okular.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/okularApplication_*.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/org.kde.gwenview.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/org.kde.ark.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/org.kde.kompare.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/kcm_trash.desktop AppDir/share/applications/

write_gwenview_mime_defaults() {
    sed -n 's/^MimeType=//p' /usr/share/applications/org.kde.gwenview.desktop \
      | tr ';' '\n' \
      | while IFS= read -r mime_type; do
            [ -n "$mime_type" ] || continue
            [ "$mime_type" = "inode/directory" ] && continue
            printf '%s=org.kde.gwenview.desktop;\n' "$mime_type"
        done
}

{
    printf '%s\n' '[Default Applications]'
    printf '%s\n' 'x-scheme-handler/kdeconnect=org.kde.dolphin.kdeconnect.desktop;'
    printf '%s\n' 'application/pdf=okularApplication_pdf.desktop;'
    write_gwenview_mime_defaults
    printf '\n%s\n' '[Added Associations]'
    printf '%s\n' 'x-scheme-handler/kdeconnect=org.kde.dolphin.kdeconnect.desktop;'
    printf '%s\n' 'application/pdf=okularApplication_pdf.desktop;'
    write_gwenview_mime_defaults
} > AppDir/share/applications/mimeapps.list

# 配置目录中的同一份默认关联优先于宿主的数据目录关联，但不会修改用户主目录中的任何 MIME 配置。
mkdir -p AppDir/etc/xdg
cp -a -- AppDir/share/applications/mimeapps.list AppDir/etc/xdg/mimeapps.list

update-desktop-database AppDir/share/applications

# KService/KSycoca 需要 applications.menu 才能稳定索引 AppImage 内的 Filelight、Okular、Gwenview、Ark、Kompare 等桌面服务。
# 使用最小菜单确保 AppImage 内应用被索引，避免依赖宿主是否安装桌面菜单包。
mkdir -p AppDir/etc/xdg/menus
cat > AppDir/etc/xdg/menus/applications.menu <<'EOF_APPLICATIONS_MENU'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
  <DefaultAppDirs/>
  <DefaultDirectoryDirs/>
  <Include>
    <All/>
  </Include>
</Menu>
EOF_APPLICATIONS_MENU

if [ -d /usr/share/desktop-directories ]; then
    cp -a -- /usr/share/desktop-directories AppDir/share/
fi

# 用最终 desktop 和 MIME 配置生成内容版本；同一构建只生成一次 KSycoca，替换 AppImage 后自动重建。
ksycoca_version="$(
    find AppDir/share/applications AppDir/etc/xdg/menus \
      -type f \( -name '*.desktop' -o -name 'mimeapps.list' -o -name 'applications.menu' \) \
      -print0 \
      | sort -z \
      | xargs -0 sha256sum \
      | sha256sum \
      | awk '{print $1}'
)"
printf '%s\n' "$ksycoca_version" > AppDir/share/kde-suite/ksycoca-version

# 覆盖基础运行时 Hook：
# - 加入 AppImage 自带的 XDG 菜单和 MIME 默认项，使 Dolphin 能找到内置应用并优先使用 Gwenview 打开图片；
# - 固定使用已打包的 Qt6ct，避免继承宿主 GNOME 平台主题后反复查询不存在的 Portal 服务；
# - 清除会被 Qt Quick Controls 优先读取的 QT_STYLE_OVERRIDE，再固定使用已打包的 org.kde.breeze；
#   否则 Widgets 风格名 Breeze 会被误当成 QML 模块名，导致 Haruna 无法启动且 NewStuff 窗口空白；
# - 指定已打包的 Fcitx5 Qt6 输入模块，使 Konsole 等 Qt6 程序可使用宿主 Fcitx5 输入中文；
# - 使用 hook 系统提供的 CACHEDIR，避免 XDG_CACHE_HOME 未设置时每次启动都重建并等待几十秒。
cat > AppDir/bin/00-kde-suite-runtime.hook <<'EOF_HOOK'
#!/bin/sh

export XDG_DATA_DIRS="$APPDIR/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_DIRS="$APPDIR/etc/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}"
export QT_PLUGIN_PATH="$APPDIR/lib/qt6/plugins"
export QT_QPA_PLATFORMTHEME=qt6ct
unset QT_STYLE_OVERRIDE
export QT_QUICK_CONTROLS_STYLE=org.kde.breeze
export QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"
export QML_IMPORT_PATH="$APPDIR/lib/qt6/qml"
export QML2_IMPORT_PATH="$APPDIR/lib/qt6/qml"

if [ -d "$APPDIR/lib/spa-0.2" ]; then
    export SPA_PLUGIN_DIR="$APPDIR/lib/spa-0.2"
fi
if [ -d "$APPDIR/lib/pipewire-0.3" ]; then
    export PIPEWIRE_MODULE_DIR="$APPDIR/lib/pipewire-0.3"
fi

cache_dir="${CACHEDIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"
mkdir -p "$cache_dir" 2>/dev/null || true
ksycoca_version="$(cat "$APPDIR/share/kde-suite/ksycoca-version" 2>/dev/null || printf 'default')"
ksycoca_marker="$cache_dir/.kde-suite-appimage-sycoca-$ksycoca_version"
if [ ! -e "$ksycoca_marker" ]; then
    "$APPDIR/bin/kbuildsycoca6" --noincremental >/dev/null 2>&1 || true
    find "$cache_dir" -maxdepth 1 -type f -name '.kde-suite-appimage-sycoca-*' ! -name ".kde-suite-appimage-sycoca-$ksycoca_version" -delete 2>/dev/null || true
    touch "$ksycoca_marker" 2>/dev/null || true
fi
EOF_HOOK
chmod +x AppDir/bin/00-kde-suite-runtime.hook

# 生成 AppImage 前确认主程序、KDE Connect 后台包装、回收站设置、文档与图片后端、Ark、Kompare、Fcitx5 输入模块和主题启动环境均已部署。
test -x AppDir/bin/okular
test -x AppDir/bin/gwenview
test -x AppDir/bin/ark
test -x AppDir/bin/kompare
test -x AppDir/bin/diff
test -x AppDir/bin/dbus-send
test -x AppDir/bin/kdeconnect-app
test -x AppDir/libexec/kde-suite/kdeconnect-app
grep -q 'kdeconnect_service_running' AppDir/bin/kdeconnect-app
grep -q 'if ! kdeconnect_service_running; then' AppDir/bin/kdeconnect-app
grep -q 'org.freedesktop.DBus.NameHasOwner string:org.kde.kdeconnect' AppDir/bin/kdeconnect-app
grep -q '"$APPDIR/bin/dbus-send"' AppDir/bin/kdeconnect-app
grep -q '"$APPDIR/bin/kdeconnectd"' AppDir/bin/kdeconnect-app
grep -q '"$APPDIR/libexec/kde-suite/kdeconnect-app"' AppDir/bin/kdeconnect-app
grep -q '^unset QML_FORCE_DISK_CACHE$' AppDir/bin/kdeconnect-app
grep -q '^export QML_DISABLE_DISK_CACHE=1$' AppDir/bin/kdeconnect-app
test -f AppDir/lib/qt6/plugins/kcm_trash.so
test -f AppDir/lib/qt6/plugins/kf6/parts/okularpart.so
test -f AppDir/lib/qt6/plugins/okular_generators/okularGenerator_poppler.so
test -f AppDir/lib/qt6/plugins/kf6/parts/arkpart.so
test -f AppDir/lib/qt6/plugins/kf6/parts/gvpart.so
test -f AppDir/lib/qt6/plugins/kf6/kfileitemaction/slideshowfileitemaction.so
test -f AppDir/lib/qt6/plugins/imageformats/libqjpeg.so
test -f AppDir/lib/qt6/plugins/kf6/parts/komparepart.so
test -f AppDir/lib/qt6/plugins/kf6/parts/komparenavtreepart.so
test -f AppDir/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
test -f AppDir/lib/qt6/plugins/kerfuffle/kerfuffle_libarchive.so
test -f AppDir/lib/qt6/plugins/kf6/kfileitemaction/compressfileitemaction.so
test -f AppDir/lib/qt6/plugins/kf6/kfileitemaction/extractfileitemaction.so
test -f AppDir/lib/qt6/plugins/kf6/kio_dnd/extracthere.so
test -f AppDir/share/applications/org.kde.okular.desktop
test -f AppDir/share/applications/okularApplication_pdf.desktop
test -f AppDir/share/applications/org.kde.gwenview.desktop
test -f AppDir/share/applications/org.kde.ark.desktop
test -f AppDir/share/applications/org.kde.kompare.desktop
test -f AppDir/share/applications/kcm_trash.desktop
test -f AppDir/share/applications/org.kde.filelight.desktop
grep -q '^Exec=filelight ' AppDir/share/applications/org.kde.filelight.desktop
test -f AppDir/etc/xdg/menus/applications.menu
grep -q '<All/>' AppDir/etc/xdg/menus/applications.menu
test -f AppDir/etc/xdg/mimeapps.list
grep -q '^image/jpeg=org.kde.gwenview.desktop;$' AppDir/share/applications/mimeapps.list
grep -q '^image/jpeg=org.kde.gwenview.desktop;$' AppDir/etc/xdg/mimeapps.list
! grep -q '^inode/directory=org.kde.gwenview.desktop;' AppDir/share/applications/mimeapps.list
test -s AppDir/share/kde-suite/ksycoca-version
find AppDir/lib/qt6/plugins/platformthemes -maxdepth 1 \( -type f -o -type l \) -name '*qt6ct*.so' -print -quit | grep -q .
test ! -e AppDir/lib/qt6/plugins/platformthemes/libqgtk3.so
test ! -e AppDir/lib/qt6/plugins/platformthemes/libqxdgdesktopportal.so
grep -q '^export QT_QPA_PLATFORMTHEME=qt6ct$' AppDir/bin/00-kde-suite-runtime.hook
grep -q '^unset QT_STYLE_OVERRIDE$' AppDir/bin/00-kde-suite-runtime.hook
! grep -q '^export QT_STYLE_OVERRIDE=' AppDir/bin/00-kde-suite-runtime.hook
grep -q '^export QT_QUICK_CONTROLS_STYLE=org.kde.breeze$' AppDir/bin/00-kde-suite-runtime.hook
grep -q 'QT_IM_MODULE="${QT_IM_MODULE:-fcitx}"' AppDir/bin/00-kde-suite-runtime.hook
grep -q 'XMODIFIERS="${XMODIFIERS:-@im=fcitx}"' AppDir/bin/00-kde-suite-runtime.hook
grep -q 'XDG_CONFIG_DIRS="$APPDIR/etc/xdg:' AppDir/bin/00-kde-suite-runtime.hook
grep -q 'CACHEDIR' AppDir/bin/00-kde-suite-runtime.hook
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/okular.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/okular_poppler.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/ark.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/gwenview.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kompare.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kio-extras_kcms.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kxmlgui6.mo
find AppDir/share/icons/hicolor -type f -path '*/apps/okular.*' -print -quit | grep -q .
find AppDir/share/icons/hicolor -type f -path '*/apps/gwenview.*' -print -quit | grep -q .
find AppDir/share/icons/hicolor -type f -path '*/apps/ark.*' -print -quit | grep -q .
find AppDir/share/icons/hicolor -type f -path '*/apps/kompare.*' -print -quit | grep -q .
test -f AppDir/share/gwenview/color-schemes/fullscreen.colors
test -f AppDir/share/kio/servicemenus/kompare.desktop
desktop-file-validate AppDir/share/applications/org.kde.okular.desktop
desktop-file-validate AppDir/share/applications/okularApplication_pdf.desktop
desktop-file-validate AppDir/share/applications/org.kde.gwenview.desktop
desktop-file-validate AppDir/share/applications/org.kde.ark.desktop
desktop-file-validate AppDir/share/applications/org.kde.kompare.desktop
desktop-file-validate AppDir/share/applications/kcm_trash.desktop
