#!/usr/bin/env bash
#
# KDE Suite AppImage 构建说明
#
# 本脚本将 KDE Connect、Dolphin、Konsole、Filelight、KIO、SSHFS、KDialog 及必要的 KDE/KF6 运行组件打包为一个 KDE Suite AppImage。
# - kde-suite.AppImage 默认启动可配置的 Qt6 Widgets 图形启动器，应用列表读取 kde/apps.ini；以后增加程序只需打包程序并更新配置，不必改启动器源码。
# - 启动器支持简体中文，并可在浅色与深色界面之间切换；Breeze 与 Breeze Dark 图标主题同时打包。
# - kde-suite、kdeconnect、dolphin、konsole 等外部软链接都指向同一个 AppImage 文件，不需要分别制作或保存多个 AppImage。
# - kde-suite 启动器从当前已挂载的 $APPDIR/bin 直接启动 KDE Connect、Dolphin、Konsole 和 Filelight；启动器保持运行期间，所有内部程序共用同一个 FUSE 挂载，不需要分别挂载。
# - kdeconnect、dolphin、konsole、filelight 等直接入口会匹配 AppImage 内的同名 bin 入口；从外部独立重复执行 AppImage 时，才可能临时出现额外挂载。
# - 为 kdeconnect:// 注册 AppImage 内部处理程序，避免误调用宿主系统中的 Dolphin 或 KIO。
# - 打包简体中文翻译；最终套件仅固定 LANGUAGE=zh_CN，继续继承宿主的 LANG、LC_ALL 和区域格式。
# - 支持 LAN 与蓝牙连接；两种链路同时存在时，KDE Connect 通常优先使用速度更快的 LAN。
#
# 当前已知限制和可忽略日志：
# 1. Share input devices（电脑键鼠跨屏控制手机）在当前 i3/X11 环境下不可用。
#    宿主会话没有提供 KDE Connect 所需的 org.freedesktop.portal.Desktop InputCapture Portal；
#    这是桌面会话能力限制，不是缺少普通动态库，也不能仅靠继续向 AppImage 添加依赖解决。
#    不使用该功能时应在设备插件设置中取消勾选 Share input devices，避免启动时报错。
# 2. Virtual Monitor 需要远端设备声明虚拟显示/RDP能力；当前 Galaxy S20 Ultra 的 Android 客户端未声明支持，
#    因此插件不会加载。本构建不把该功能视为必须完成的目标。
# 3. qt.bluetooth.bluez 的 Missing CAP_NET_ADMIN 仅表示 Qt 无法判断扫描地址是随机地址还是公开地址；
#    已配对设备能够正常发现和连接时，不应为 AppImage 添加高权限或使用 root 运行。
# 4. No uuids found 通常来自附近其他蓝牙设备，不代表已经配对的手机连接失败。
# 5. SendNotificationsPlugin received...、Unimplemented conversation of type 'r' 等通知日志，
#    表示某些通知扩展字段没有被当前插件解析；通知文字和常规同步正常时可以忽略。
# 6. AppImage 缩略图和元数据插件只支持 SquashFS；最终套件为兼容普通 AppImage 会恢复这两个插件，
#    因此扫描 DwarFS 等其他格式时仍可能出现 sqfs_open_image 日志，但不影响文件执行和其他预览。
# 7. 若出现 org.kde.kuiserver 或 PowerManagement.Inhibit 缺失，只会影响全局传输进度界面或阻止休眠，
#    不影响实际传输；长时间传输时应避免电脑自动休眠。
#
# 以上限制均已确认不影响当前目标中的配对、通知、剪贴板、文件发送、Browse device、托盘和蓝牙功能。

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

# KDE Suite 使用自己的启动器桌面文件和图标；直接运行 AppImage 或 kde-suite 入口时打开启动器。
export ICON="$SCRIPT_DIR/kde-suite.svg"
export DESKTOP="$SCRIPT_DIR/org.kde.kdesuite.desktop"
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME="kde-suite.AppImage"
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1
export STARTUPWMCLASS="kde-suite-launcher"

# 基本依赖（包括常见的编译、打包工具以及 X11/Wayland 基础库）
yay -S --noconfirm gcc base-devel pkgconf wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux glycin libheif zsync xorg-server xorg-server-common xorg-server-xvfb

# 常用包及剪贴板、输入法、Qt 主题、Breeze 风格和图标组件
yay -S --noconfirm wl-clipboard xclip fcitx5-qt egl-wayland libxcb xcb-util xcb-util-keysyms libxss extra-cmake-modules \
  xcb-util-renderutil xcb-util-wm xcb-util-image xcb-util-cursor libxkbcommon libxkbcommon-x11 mesa libglvnd \
  adwaita-qt6 qt6-base qt6-svg qt6-tools qt6ct lxqt-qtplugin kvantum breeze breeze-icons

# 编译通用 Qt6 Widgets 启动器。应用清单由 apps.ini 提供，后续增加应用不需要修改或重新设计启动器源码。
LAUNCHER_BIN="/tmp/kde-suite-launcher"
g++ -std=c++17 -O2 -pipe -fPIC "$SCRIPT_DIR/kde_suite_launcher.cpp" -o "$LAUNCHER_BIN" \
  $(pkg-config --cflags --libs Qt6Widgets)

# KDE Connect 及相关运行时依赖；SSHFS、KIO Extras、KDialog 和 Portal 用于文件浏览、发送和选择
yay -S --noconfirm kdeconnect dbus glib2 glibc kconfig kcoreaddons kcrash kdbusaddons kdeclarative kguiaddons ki18n kio kirigami kirigami-addons kitemmodels kjobwidgets knotifications kpeople kservice kstatusnotifieritem kwindowsystem libei libevdev libfakekey libstdc++ libx11 libxkbcommon libxtst modemmanager-qt openssl pulseaudio-qt qqc2-desktop-style qt6-connectivity qt6-declarative qt6-multimedia solid wayland nautilus-python sshfs kpackage wayland-protocols nss openssh xdg-utils kio-extras kdialog xdg-desktop-portal-kde

# Dolphin、Konsole、Filelight 及其关联组件（作为内置文件管理器、终端和磁盘空间分析器）
yay -S --noconfirm dolphin baloo baloo-widgets kbookmarks kcmutils kcodecs kcolorscheme kcompletion kconfigwidgets kfilemetadata kiconthemes knewstuff kparts ktextwidgets kuserfeedback kwidgetsaddons kxmlgui dolphin-plugins ffmpegthumbs filelight kde-cli-tools kdegraphics-thumbnailers kdenetwork-filesharing kdf kio-admin kompare konsole purpose extra-cmake-modules kdoctools libappimage openexr

quick-sharun \
  "$LAUNCHER_BIN" \
  /usr/bin/kdeconnect-app \
  /usr/bin/kdeconnect-cli \
  /usr/bin/kdeconnect-handler \
  /usr/bin/kdeconnect-indicator \
  /usr/bin/kdeconnect-sms \
  /usr/bin/kdeconnectd \
  /usr/bin/sshfs \
  /usr/bin/sftp \
  /usr/bin/xdg-open \
  /usr/bin/kdialog \
  /usr/bin/dolphin \
  /usr/bin/konsole \
  /usr/bin/filelight \
  /usr/bin/kbuildsycoca6 \
  /usr/lib/qt6/plugins/styles/breeze6.so \
  /usr/lib/kf6/kiod6 \
  /usr/lib/kf6/kioexec \
  /usr/lib/kf6/kioworker

# fusermount3 依赖宿主机 root 所有且带 setuid/capability 的特权安装；复制进 AppImage 后这些权限不可用，
# 反而会优先于宿主 helper 并导致 SSHFS mount failed: Operation not permitted。保留 sshfs 与 libfuse3，
# 明确不打包 helper，让 SSHFS 从宿主 PATH 使用系统的 /usr/bin/fusermount3。
rm -f AppDir/bin/fusermount3

# quick-sharun 的运行时目录是 AppDir/lib，而不是 AppDir/usr/lib。
# 将 KF6、KDE Connect、Dolphin、Konsole、Filelight 和 QML 目录交给 quick-sharun，以保留正确目录结构并自动收集动态库依赖。
KDE_RUNTIME_DIRS=()
for dir in \
  /usr/lib/qt6/plugins/kf6 \
  /usr/lib/qt6/plugins/kdeconnect \
  /usr/lib/qt6/plugins/dolphin \
  /usr/lib/qt6/plugins/konsoleplugins \
  /usr/lib/qt6/plugins/plasma \
  /usr/lib/qt6/plugins/platforms \
  /usr/lib/qt6/qml
do
    if [ -d "$dir" ]; then
        KDE_RUNTIME_DIRS+=("$dir")
    fi
done

if [ ${#KDE_RUNTIME_DIRS[@]} -gt 0 ]; then
    quick-sharun "${KDE_RUNTIME_DIRS[@]}"
fi

# 安装启动器配置并创建明确的内部命令入口。
# 外部 kde-suite、kdeconnect、dolphin、konsole、filelight 软链接会由 AppRun 按同名 bin 入口分派；不再依赖默认程序回退。
mkdir -p AppDir/share/kde-suite
cp -a -- "$SCRIPT_DIR/apps.ini" AppDir/share/kde-suite/apps.ini
ln -sfn kde-suite-launcher AppDir/bin/kde-suite
ln -sfn kdeconnect-app AppDir/bin/kdeconnect

# quick-sharun 只处理动态库和可执行文件；补充 QML、插件元数据等非可执行支持文件。
copy_support_files() {
    local source_root="$1"
    local target_root="$2"
    local source_file relative_path target_file

    [ -d "$source_root" ] || return 0
    mkdir -p "$target_root"

    while IFS= read -r -d '' source_file; do
        relative_path="${source_file#"$source_root"/}"
        target_file="$target_root/$relative_path"
        mkdir -p "$(dirname -- "$target_file")"
        cp -a -- "$source_file" "$target_file"
    done < <(find "$source_root" \
        \( -type l ! -name '*.so*' -o -type f ! -name '*.so*' ! -perm /111 \) \
        -print0)
}

copy_support_files /usr/lib/qt6/plugins/kf6 AppDir/lib/qt6/plugins/kf6
copy_support_files /usr/lib/qt6/plugins/kdeconnect AppDir/lib/qt6/plugins/kdeconnect
copy_support_files /usr/lib/qt6/plugins/dolphin AppDir/lib/qt6/plugins/dolphin
copy_support_files /usr/lib/qt6/plugins/konsoleplugins AppDir/lib/qt6/plugins/konsoleplugins
copy_support_files /usr/lib/qt6/plugins/plasma AppDir/lib/qt6/plugins/plasma
copy_support_files /usr/lib/qt6/plugins/platforms AppDir/lib/qt6/plugins/platforms
copy_support_files /usr/lib/qt6/qml AppDir/lib/qt6/qml

# 补充 KIO、Dolphin、Konsole、Filelight、KNewStuff、Breeze、Solid 和 KDE Connect 的运行时数据文件。
mkdir -p AppDir/share
for dir in \
  /usr/share/kio* \
  /usr/share/kf6 \
  /usr/share/kservices6 \
  /usr/share/kservicetypes6 \
  /usr/share/dolphin \
  /usr/share/knsrcfiles \
  /usr/share/color-schemes \
  /usr/share/kstyle \
  /usr/share/knotifications6 \
  /usr/share/solid \
  /usr/share/remoteview \
  /usr/share/kdeconnect
do
    if [ -e "$dir" ]; then
        cp -a -- "$dir" AppDir/share/
    fi
done

# 打包简体中文翻译。复制完整 zh_CN 目录可以同时覆盖 KDE Connect、Dolphin、Konsole、KIO 和 KF6 组件；
# 最终由 deploy_suite_apps.sh 仅固定 LANGUAGE=zh_CN，不改 LANG、LC_ALL 和日期、数字等宿主区域格式。
if [ -d /usr/share/locale/zh_CN ]; then
    mkdir -p AppDir/share/locale
    cp -a -- /usr/share/locale/zh_CN AppDir/share/locale/
else
    echo "错误：未找到 /usr/share/locale/zh_CN，无法生成带简体中文翻译的 KDE Suite AppImage。" >&2
    exit 1
fi

# KDE Connect 在 Linux 上将 Breeze 作为后备图标主题；完整打包明暗主题，避免插件界面缺少图标产生空 Pixmap。
mkdir -p AppDir/share/icons
for icon_theme in breeze breeze-dark; do
    if [ -d "/usr/share/icons/$icon_theme" ]; then
        cp -a -- "/usr/share/icons/$icon_theme" AppDir/share/icons/
    fi
done
mkdir -p AppDir/share/icons/hicolor/scalable/apps
cp -a -- /usr/share/icons/hicolor/index.theme AppDir/share/icons/hicolor/index.theme
cp -a -- "$SCRIPT_DIR/kde-suite.svg" AppDir/share/icons/hicolor/scalable/apps/kde-suite.svg

while IFS= read -r -d '' filelight_icon; do
    relative_icon="${filelight_icon#/usr/share/icons/}"
    mkdir -p "AppDir/share/icons/$(dirname -- "$relative_icon")"
    cp -a -- "$filelight_icon" "AppDir/share/icons/$relative_icon"
done < <(find /usr/share/icons/hicolor -type f -path '*/apps/filelight.*' -print0)

# KDE Connect Indicator 的托盘 SVG 使用百分比宽高时，部分 Qt 托盘后端会申请异常大的缓冲区。
# 仅固定该图标的画布尺寸为其原始 viewBox 22×22，不改动图标内容和托盘启动逻辑。
TRAY_ICON="AppDir/share/icons/hicolor/scalable/apps/kdeconnectindicatordark.svg"
if [ -f "$TRAY_ICON" ]; then
    sed -i \
      -e 's/width="100%"/width="22"/' \
      -e 's/height="100%"/height="22"/' \
      "$TRAY_ICON"
fi

# 补充 KDE Connect 的 D-Bus 服务文件，避免后台服务回退到宿主系统路径。
mkdir -p AppDir/share/dbus-1/services
for service_file in /usr/share/dbus-1/services/*kdeconnect*; do
    if [ -f "$service_file" ]; then
        cp -a -- "$service_file" AppDir/share/dbus-1/services/
        sed -i -E 's|^Exec=.*/kdeconnectd$|Exec=kdeconnectd|' \
            "AppDir/share/dbus-1/services/${service_file##*/}"
    fi
done

# KIO 的四个 D-Bus 名称都由同一个 kiod6 进程提供：kioexecd、kpasswdserver 和 kssld 是按需加载插件，
# 不是四个额外守护进程。打包 kiod6、三个插件和四个 activation 文件，并把绝对 Exec 改为 AppDir 的 PATH 入口。
KIO_DBUS_SERVICES=(
  org.kde.kiod6
  org.kde.kioexecd6
  org.kde.kpasswdserver6
  org.kde.kssld6
)
for service_name in "${KIO_DBUS_SERVICES[@]}"; do
    service_file="/usr/share/dbus-1/services/$service_name.service"
    if [ ! -f "$service_file" ]; then
        echo "错误：未找到 KIO D-Bus 服务文件 $service_file。" >&2
        exit 1
    fi

    cp -a -- "$service_file" AppDir/share/dbus-1/services/
    sed -i -E 's|^Exec=[^[:space:]]*/kiod6$|Exec=kiod6|' \
        "AppDir/share/dbus-1/services/$service_name.service"
done

# 为 kdeconnect:// 注册 AppImage 内部处理程序，使 Browse device 优先启动内置 Dolphin。
mkdir -p AppDir/share/applications AppDir/share/kglobalaccel
cp -a -- "$SCRIPT_DIR/org.kde.kdesuite.desktop" AppDir/share/applications/
cp -a -- /usr/share/applications/org.kde.konsole.desktop AppDir/share/applications/
cp -a -- /usr/share/applications/org.kde.filelight.desktop AppDir/share/applications/
cp -a -- /usr/share/kglobalaccel/org.kde.konsole.desktop AppDir/share/kglobalaccel/
cat > AppDir/share/applications/org.kde.dolphin.kdeconnect.desktop <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=KDE Connect Device Browser
Exec=dolphin --new-window %U
Icon=org.kde.dolphin
NoDisplay=true
Terminal=false
MimeType=x-scheme-handler/kdeconnect;
EOF_DESKTOP

cat > AppDir/share/applications/mimeapps.list <<'EOF_MIMEAPPS'
[Default Applications]
x-scheme-handler/kdeconnect=org.kde.dolphin.kdeconnect.desktop;

[Added Associations]
x-scheme-handler/kdeconnect=org.kde.dolphin.kdeconnect.desktop;
EOF_MIMEAPPS

update-desktop-database AppDir/share/applications

# AppRun 启动时固定使用 AppImage 内的 KDE 数据、Qt 插件和 QML，并刷新当前 AppImage 的 KSycoca 缓存。
cat > AppDir/bin/00-kde-suite-runtime.hook <<'EOF_HOOK'
#!/bin/sh

export XDG_DATA_DIRS="$APPDIR/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export QT_PLUGIN_PATH="$APPDIR/lib/qt6/plugins"
unset QT_STYLE_OVERRIDE
export QML_IMPORT_PATH="$APPDIR/lib/qt6/qml"
export QML2_IMPORT_PATH="$APPDIR/lib/qt6/qml"

if [ -d "$APPDIR/lib/spa-0.2" ]; then
    export SPA_PLUGIN_DIR="$APPDIR/lib/spa-0.2"
fi
if [ -d "$APPDIR/lib/pipewire-0.3" ]; then
    export PIPEWIRE_MODULE_DIR="$APPDIR/lib/pipewire-0.3"
fi

ksycoca_marker="$XDG_CACHE_HOME/.kde-suite-appimage-sycoca"
if [ ! -e "$ksycoca_marker" ] || { [ -n "${APPIMAGE:-}" ] && [ "$APPIMAGE" -nt "$ksycoca_marker" ]; }; then
    "$APPDIR/bin/kbuildsycoca6" --noincremental >/dev/null 2>&1 || true
    touch "$ksycoca_marker" 2>/dev/null || true
fi
EOF_HOOK
chmod +x AppDir/bin/00-kde-suite-runtime.hook

# 如果 KIO 仍通过 xdg-open 处理 kdeconnect://，仅对该协议强制改用 AppImage 内置 Dolphin；其他链接保持原行为。
if [ -f AppDir/bin/xdg-open ]; then
    mv AppDir/bin/xdg-open AppDir/bin/xdg-open.real
    cat > AppDir/bin/xdg-open <<'EOF_XDG_OPEN'
#!/bin/sh

case "${1:-}" in
    kdeconnect://*)
        exec "$APPDIR/bin/dolphin" --new-window "$@"
        ;;
esac

exec "$APPDIR/bin/xdg-open.real" "$@"
EOF_XDG_OPEN
    chmod +x AppDir/bin/xdg-open AppDir/bin/xdg-open.real
fi

# 移除不需要的拼写检查插件，避免引出额外字典依赖导致打包中断。
rm -rf AppDir/lib/qt6/plugins/kf6/sonnet || true

# 基础阶段先移除只支持 SquashFS 的 AppImage 插件；deploy_suite_apps.sh 会在最终阶段恢复，
# 同时兼顾普通 AppImage 图标/元数据提取，并把 DwarFS 报错保留为已知的非致命日志。
rm -f \
  AppDir/lib/qt6/plugins/kf6/thumbcreator/appimagethumbnail.so \
  AppDir/lib/qt6/plugins/kf6/kfilemetadata/kfilemetadata_appimageextractor.so

# 构建前静态检查关键文件，避免生成缺少启动器、命令入口、KIO、Dolphin、Konsole、Filelight、主题、音频插件或中文翻译的无效 AppImage。
test -x AppDir/bin/kde-suite-launcher
test -L AppDir/bin/kde-suite
test "$(readlink AppDir/bin/kde-suite)" = "kde-suite-launcher"
test -L AppDir/bin/kdeconnect
test "$(readlink AppDir/bin/kdeconnect)" = "kdeconnect-app"
test -f AppDir/share/kde-suite/apps.ini
grep -q '^Exec=kdeconnect-app$' AppDir/share/kde-suite/apps.ini
grep -q '^Exec=dolphin$' AppDir/share/kde-suite/apps.ini
grep -q '^Exec=konsole$' AppDir/share/kde-suite/apps.ini
grep -q '^Exec=filelight$' AppDir/share/kde-suite/apps.ini
test -f AppDir/share/applications/org.kde.kdesuite.desktop
test -f AppDir/share/icons/hicolor/index.theme
test -f AppDir/share/icons/hicolor/scalable/apps/kde-suite.svg
find AppDir/share/icons/hicolor -type f -path '*/apps/filelight.*' -print -quit | grep -q .
test -f AppDir/lib/qt6/plugins/kf6/kio/kdeconnect.so
test -s AppDir/share/knsrcfiles/servicemenu.knsrc
test -x AppDir/bin/sshfs
test ! -e AppDir/bin/fusermount3
find AppDir/lib -maxdepth 2 \( -type f -o -type l \) -name 'libfuse3.so*' -print -quit | grep -q .
test -x AppDir/bin/kiod6
test -f AppDir/lib/qt6/plugins/kf6/kiod/kioexecd.so
test -f AppDir/lib/qt6/plugins/kf6/kiod/kpasswdserver.so
test -f AppDir/lib/qt6/plugins/kf6/kiod/kssld.so
for service_name in "${KIO_DBUS_SERVICES[@]}"; do
    test -f "AppDir/share/dbus-1/services/$service_name.service"
    grep -q "^Name=$service_name$" "AppDir/share/dbus-1/services/$service_name.service"
    grep -q '^Exec=kiod6$' "AppDir/share/dbus-1/services/$service_name.service"
done
test -x AppDir/bin/dolphin
test -x AppDir/bin/konsole
test -x AppDir/bin/filelight
test -f AppDir/lib/qt6/plugins/kf6/parts/konsolepart.so
test -x AppDir/bin/xdg-open
test -f AppDir/share/applications/org.kde.dolphin.kdeconnect.desktop
test -f AppDir/share/applications/org.kde.konsole.desktop
test -f AppDir/share/applications/org.kde.filelight.desktop
test -f AppDir/share/kglobalaccel/org.kde.konsole.desktop
test -f AppDir/share/icons/hicolor/scalable/apps/kdeconnectindicatordark.svg
test -f AppDir/share/icons/breeze/index.theme
test -f AppDir/share/icons/breeze-dark/index.theme
test -f AppDir/lib/qt6/plugins/styles/breeze6.so
test -f AppDir/share/color-schemes/BreezeDark.colors
test -f AppDir/share/color-schemes/BreezeLight.colors
test -f AppDir/share/kstyle/themes/breeze.themerc
test -f AppDir/lib/spa-0.2/support/libspa-support.so
test -d AppDir/lib/pipewire-0.3
test ! -e AppDir/lib/qt6/plugins/kf6/thumbcreator/appimagethumbnail.so
test ! -e AppDir/lib/qt6/plugins/kf6/kfilemetadata/kfilemetadata_appimageextractor.so
test -d AppDir/share/locale/zh_CN/LC_MESSAGES
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/dolphin.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/konsole.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/filelight.mo
find AppDir/share/locale/zh_CN/LC_MESSAGES -type f -name '*.mo' -print -quit | grep -q .
desktop-file-validate AppDir/share/applications/org.kde.kdesuite.desktop
desktop-file-validate AppDir/share/applications/org.kde.dolphin.kdeconnect.desktop
desktop-file-validate AppDir/share/applications/org.kde.konsole.desktop
desktop-file-validate AppDir/share/applications/org.kde.filelight.desktop

quick-sharun --make-appimage
