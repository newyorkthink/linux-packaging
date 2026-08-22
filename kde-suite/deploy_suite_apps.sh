# 由 kde/build_kde_suite.sh 在基础 AppDir 完成后、生成 AppImage 前加载。
# 保留已经验证的 okular_ark.sh 原有逻辑，只在其外层补充套件级收尾处理。

if [ "${KDE_SUITE_DEPLOY_READY:-0}" = "1" ]; then
    return 0
fi
KDE_SUITE_DEPLOY_READY=1

# build_core.sh 在基础阶段暂时移除了这两个插件；最终阶段恢复它们，
# 使 Dolphin 能继续提取普通 SquashFS AppImage 自带的图标和元数据。
# 扫描 DwarFS 等其他格式时可能输出 sqfs_open_image 日志，这是保留兼容能力后的已知取舍。
quick-sharun \
  /usr/lib/qt6/plugins/kf6/thumbcreator/appimagethumbnail.so \
  /usr/lib/qt6/plugins/kf6/kfilemetadata/kfilemetadata_appimageextractor.so

# 增加 KDE 视频播放器 Haruna。必须先部署程序和桌面入口，再执行现有集成脚本，
# 使后续中文翻译恢复、桌面服务数据库和 KSycoca 生成能够包含 Haruna。
quick-sharun /usr/bin/haruna
mkdir -p AppDir/share/applications
cp -a -- /usr/share/applications/org.kde.haruna.desktop AppDir/share/applications/

# Haruna/libmpv 使用 PATH 中的 yt-dlp 解析视频网站链接。部署 Arch 仓库中的
# Python 版 yt-dlp、匹配的 yt-dlp-ejs 及 Deno，避免 PyInstaller ELF 在
# quick-sharun/AppImage 只读挂载中被再次处理后无法稳定运行。
yt_dlp_version="$(/usr/bin/yt-dlp --version)"
if ! printf '%s\n' "$yt_dlp_version" | grep -Eq '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}([.-].*)?$'; then
    echo "错误：Arch yt-dlp 版本输出异常：$yt_dlp_version" >&2
    exit 1
fi
if ! /usr/bin/python -c 'import yt_dlp, yt_dlp_ejs'; then
    echo "错误：yt-dlp 或 yt-dlp-ejs Python 模块不可用。" >&2
    exit 1
fi

deno_version="$(/usr/bin/deno --version | sed -n '1p')"
if ! printf '%s\n' "$deno_version" | grep -Eq '^deno [0-9]+\.[0-9]+\.[0-9]+'; then
    echo "错误：Deno 版本输出异常：$deno_version" >&2
    exit 1
fi

# 仅本次部署启用系统 Python，避免后续 KDE 可执行文件重复复制 Python 运行时。
DEPLOY_PYTHON=1 quick-sharun /usr/bin/yt-dlp /usr/bin/deno

appdir_abs="$(cd AppDir && pwd)"
bundled_yt_dlp_version="$(
    APPDIR="$appdir_abs" \
    PATH="$appdir_abs/bin:/usr/bin" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONNOUSERSITE=1 \
    "$appdir_abs/bin/yt-dlp" --version
)"
if [ "$bundled_yt_dlp_version" != "$yt_dlp_version" ]; then
    echo "错误：AppDir 内 yt-dlp 版本异常：$bundled_yt_dlp_version" >&2
    exit 1
fi

bundled_deno_version="$(
    APPDIR="$appdir_abs" \
    "$appdir_abs/bin/deno" --version | sed -n '1p'
)"
if [ "$bundled_deno_version" != "$deno_version" ]; then
    echo "错误：AppDir 内 Deno 版本异常：$bundled_deno_version" >&2
    exit 1
fi

APPDIR="$appdir_abs" \
PATH="$appdir_abs/bin:/usr/bin" \
PYTHONDONTWRITEBYTECODE=1 \
PYTHONNOUSERSITE=1 \
"$appdir_abs/bin/python" -c 'import yt_dlp, yt_dlp_ejs'

# Activities 需要先收集可执行文件和插件，再由现有脚本统一恢复完整简体中文翻译。
# shellcheck source=deploy_activities.sh
. "$SCRIPT_DIR/deploy_activities.sh"
deploy_activities_files

# 已验证的额外应用、KDE Connect、MIME、翻译、主题和 Fcitx5 集成保持原样。
# shellcheck source=okular_ark.sh
. "$SCRIPT_DIR/okular_ark.sh"

# 在现有运行时和 dbus-send 部署完成后接入 Activities，并统一使用 Breeze 图标。
deploy_activities_integration
# shellcheck source=deploy_icon_theme.sh
. "$SCRIPT_DIR/deploy_icon_theme.sh"
deploy_breeze_icon_theme

# 将 Haruna 声明的视频和音频格式加入 AppImage 内部默认关联。
# 仅修改 AppDir 中的 MIME 配置，不改动用户主目录中的宿主关联。
haruna_mime_defaults="AppDir/share/kde-suite/haruna-mime-defaults.list"
sed -n 's/^MimeType=//p' AppDir/share/applications/org.kde.haruna.desktop \
  | tr ';' '\n' \
  | while IFS= read -r mime_type; do
        [ -n "$mime_type" ] || continue
        printf '%s=org.kde.haruna.desktop;\n' "$mime_type"
    done > "$haruna_mime_defaults"

insert_haruna_mime_defaults() {
    mime_file=$1
    mime_tmp="${mime_file}.tmp"

    if grep -q '=org.kde.haruna.desktop;' "$mime_file"; then
        return 0
    fi

    awk -v defaults_file="$haruna_mime_defaults" '
        BEGIN {
            while ((getline line < defaults_file) > 0) {
                defaults[++count] = line
            }
            close(defaults_file)
        }
        /^\[Default Applications\]$/ {
            print
            section = "default"
            next
        }
        /^\[Added Associations\]$/ {
            if (section == "default") {
                for (i = 1; i <= count; i++) {
                    print defaults[i]
                }
            }
            print
            section = "added"
            next
        }
        { print }
        END {
            if (section == "added") {
                for (i = 1; i <= count; i++) {
                    print defaults[i]
                }
            }
        }
    ' "$mime_file" > "$mime_tmp"
    mv -- "$mime_tmp" "$mime_file"
}

insert_haruna_mime_defaults AppDir/share/applications/mimeapps.list
cp -a -- AppDir/share/applications/mimeapps.list AppDir/etc/xdg/mimeapps.list
update-desktop-database AppDir/share/applications

# Haruna 的桌面入口和最终 MIME 配置是在现有脚本生成版本号后加入的，
# 因此基于原版本号和新增文件生成新的 KSycoca 内容版本。
previous_ksycoca_version="$(cat AppDir/share/kde-suite/ksycoca-version)"
ksycoca_version="$(
    {
        printf '%s\n' "$previous_ksycoca_version"
        sha256sum \
          AppDir/share/applications/org.kde.haruna.desktop \
          AppDir/share/applications/mimeapps.list \
          AppDir/etc/xdg/mimeapps.list
    } | sha256sum | awk '{print $1}'
)"
printf '%s\n' "$ksycoca_version" > AppDir/share/kde-suite/ksycoca-version

# 本套件明确以简体中文为默认语言。只覆盖 gettext/KDE 的语言选择，
# 保留宿主 LANG 和区域格式，避免依赖宿主是否生成 zh_CN glibc locale。
cat > AppDir/bin/00-kde-suite-language.hook <<'EOF_LANGUAGE_HOOK'
#!/bin/sh

export LANGUAGE=zh_CN
EOF_LANGUAGE_HOOK
chmod +x AppDir/bin/00-kde-suite-language.hook

# 最终静态检查：AppImage 图标、Haruna 在线链接、Dolphin 下载服务 QML、
# 简体中文、MIME 默认项和 Breeze 主题均已部署。
test -f AppDir/lib/qt6/plugins/kf6/thumbcreator/appimagethumbnail.so
test -f AppDir/lib/qt6/plugins/kf6/kfilemetadata/kfilemetadata_appimageextractor.so
test -x AppDir/bin/haruna
test -x AppDir/bin/yt-dlp
test -x AppDir/bin/deno
test -x AppDir/bin/python
find AppDir/lib -type f -path '*/site-packages/yt_dlp/__init__.py' -print -quit | grep -q .
find AppDir/lib -type f -path '*/site-packages/yt_dlp_ejs/yt/solver/core.min.js' -print -quit | grep -q .
test -x AppDir/bin/sshfs
test ! -e AppDir/bin/fusermount3
find AppDir/lib -maxdepth 2 \( -type f -o -type l \) -name 'libfuse3.so*' -print -quit | grep -q .
test -x AppDir/bin/kiod6
for service_name in "${KIO_DBUS_SERVICES[@]}"; do
    test -f "AppDir/share/dbus-1/services/$service_name.service"
    grep -q '^Exec=kiod6$' "AppDir/share/dbus-1/services/$service_name.service"
done
test -d AppDir/lib/qt6/qml/org/kde/breeze
test -f AppDir/lib/qt6/qml/org/kde/breeze/qmldir
test -f AppDir/lib/qt6/qml/org/kde/breeze/libBreezeStyle.so
grep -q '^module org.kde.breeze$' AppDir/lib/qt6/qml/org/kde/breeze/qmldir
test -f AppDir/lib/qt6/plugins/kf6/kirigami/platform/org.kde.breeze.so
test -f AppDir/share/applications/org.kde.haruna.desktop
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/haruna.mo
find AppDir/share/icons/hicolor -type f -path '*/apps/haruna.*' -print -quit | grep -q .
test -s "$haruna_mime_defaults"
grep -q '^video/mp4=org.kde.haruna.desktop;$' AppDir/share/applications/mimeapps.list
grep -q '^video/mp4=org.kde.haruna.desktop;$' AppDir/etc/xdg/mimeapps.list
grep -q '^audio/mpeg=org.kde.haruna.desktop;$' AppDir/share/applications/mimeapps.list
test -x AppDir/bin/00-kde-suite-language.hook
test -x AppDir/bin/00-kde-suite-runtime.hook
grep -q '^export LANGUAGE=zh_CN$' AppDir/bin/00-kde-suite-language.hook
grep -q '^export QT_QPA_PLATFORMTHEME=qt6ct$' AppDir/bin/00-kde-suite-runtime.hook
grep -q '^unset QT_STYLE_OVERRIDE$' AppDir/bin/00-kde-suite-runtime.hook
! grep -q '^export QT_STYLE_OVERRIDE=' AppDir/bin/00-kde-suite-runtime.hook
grep -q '^export QT_QUICK_CONTROLS_STYLE=org.kde.breeze$' AppDir/bin/00-kde-suite-runtime.hook
test -f AppDir/share/icons/breeze/index.theme
test -f AppDir/share/icons/breeze-dark/index.theme
test -f AppDir/share/icons/Flat-Remix-Blue-Dark/index.theme
grep -q '^Inherits=breeze$' AppDir/share/icons/Flat-Remix-Blue-Dark/index.theme
test ! -e AppDir/share/licenses/flat-remix
test -s AppDir/share/kde-suite/ksycoca-version
desktop-file-validate AppDir/share/applications/org.kde.haruna.desktop

# apps.ini 是启动器的唯一应用清单；最终打包前逐项确认命令均为简单名称且已在 AppDir/bin 中可执行，
# 防止以后只更新清单或只安装程序，生成能够显示入口却无法启动应用的 AppImage。
while IFS= read -r launcher_exec; do
    [ -n "$launcher_exec" ] || continue
    case "$launcher_exec" in
        */*)
            echo "错误：apps.ini 中的 Exec 必须是 AppDir/bin 下的简单命令名：$launcher_exec" >&2
            exit 1
            ;;
    esac
    if [ ! -x "AppDir/bin/$launcher_exec" ]; then
        echo "错误：apps.ini 中的命令未打包或不可执行：$launcher_exec" >&2
        exit 1
    fi
done < <(sed -n 's/^Exec=//p' AppDir/share/kde-suite/apps.ini)

# 静态文件存在不代表 Qt Quick 最终选择了正确样式。实际在 Xvfb 中启动 AppDir 内 Haruna，
# 允许其进入事件循环后结束，并把任何 QML 模块/组件加载失败直接变成构建失败。
haruna_qml_log="$(mktemp)"
haruna_qml_status=0
timeout --signal=TERM --kill-after=2s 10s \
  xvfb-run -a -- env QT_QUICK_BACKEND=software AppDir/bin/haruna \
  >"$haruna_qml_log" 2>&1 || haruna_qml_status=$?

if grep -Eq 'QQmlApplicationEngine failed to load component|module "[^"]+" is not installed|Type [^ ]+ unavailable' \
  "$haruna_qml_log"; then
    cat "$haruna_qml_log" >&2
    rm -f -- "$haruna_qml_log"
    echo "错误：Haruna QML 运行时检查失败。" >&2
    exit 1
fi

case "$haruna_qml_status" in
    0|124|137)
        ;;
    *)
        cat "$haruna_qml_log" >&2
        rm -f -- "$haruna_qml_log"
        echo "错误：Haruna 运行时检查异常退出（状态 $haruna_qml_status）。" >&2
        exit 1
        ;;
esac
rm -f -- "$haruna_qml_log"
