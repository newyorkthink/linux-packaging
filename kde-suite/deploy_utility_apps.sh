# KDE Suite 轻量实用工具部署：Qt6ct、KFind、KDF。
# 由 build_kde_suite.sh 在基础 AppDir 完成后、现有 deploy_suite_apps.sh 之前加载。

if [ "${KDE_SUITE_UTILITY_APPS_READY:-0}" = "1" ]; then
    return 0
fi
KDE_SUITE_UTILITY_APPS_READY=1

# Qt6ct 和 KDF 已由 build_core.sh 安装；KFind 由 build_kde_suite.sh 在基础构建前安装。
# 这里只把三个程序正式部署进 AppDir，不改宿主 /usr，也不引入 System Settings 或 Plasma Workspace。
quick-sharun \
  /usr/bin/qt6ct \
  /usr/bin/kfind \
  /usr/bin/kdf

# Qt6ct 的颜色方案和 QSS 属于运行数据；显式复制，避免配置界面只剩程序而缺少预设项。
mkdir -p AppDir/share
cp -a -- /usr/share/qt6ct AppDir/share/

# Qt6ct 从 AppImage 内选择配色时会把当前 FUSE 挂载目录保存为绝对路径；
# AppImage 下次挂载后旧 /tmp/.mount_* 路径会失效，导致已保存的明暗配色回退。
# 独立运行时 Hook 只迁移这种临时路径：把当前所选同名配色复制到当前用户的固定配置目录，
# 再把 qt6ct.conf 改为固定用户路径。配色名称不写死，因此浅色、深色和其他内置配色都保持用户最后选择；
# 已经使用固定路径或用户自定义外部配色时完全不改。
cat > AppDir/bin/01-kde-suite-qt6ct-color-path.hook <<'EOF_QT6CT_COLOR_PATH_HOOK'
#!/bin/sh

qt6ct_config_root="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct"
qt6ct_config_file="$qt6ct_config_root/qt6ct.conf"

if [ -f "$qt6ct_config_file" ]; then
    qt6ct_scheme_path="$(sed -n 's/^color_scheme_path=//p' "$qt6ct_config_file" | head -n 1)"

    case "$qt6ct_scheme_path" in
        /tmp/.mount_*/share/qt6ct/colors/*.conf)
            qt6ct_scheme_name="${qt6ct_scheme_path##*/}"
            qt6ct_scheme_source="$APPDIR/share/qt6ct/colors/$qt6ct_scheme_name"
            qt6ct_scheme_dir="$qt6ct_config_root/colors"
            qt6ct_scheme_target="$qt6ct_scheme_dir/$qt6ct_scheme_name"

            if [ -f "$qt6ct_scheme_source" ]; then
                mkdir -p "$qt6ct_scheme_dir" 2>/dev/null || true

                if cp -f -- "$qt6ct_scheme_source" "$qt6ct_scheme_target" 2>/dev/null; then
                    qt6ct_config_target="$(readlink -f -- "$qt6ct_config_file" 2>/dev/null || printf '%s\n' "$qt6ct_config_file")"
                    qt6ct_scheme_target_sed="$(printf '%s\n' "$qt6ct_scheme_target" | sed 's/[\\&|]/\\&/g')"
                    sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_scheme_target_sed|" "$qt6ct_config_target"
                fi
            fi
            ;;
    esac
fi
EOF_QT6CT_COLOR_PATH_HOOK
chmod +x AppDir/bin/01-kde-suite-qt6ct-color-path.hook

# 保留三个程序的桌面入口，供 KSycoca、文件服务和后续独立入口识别。
mkdir -p AppDir/share/applications
cp -a -- \
  /usr/share/applications/qt6ct.desktop \
  /usr/share/applications/org.kde.kfind.desktop \
  /usr/share/applications/org.kde.kdf.desktop \
  AppDir/share/applications/

# KFind 与 KDF 的应用图标位于 Hicolor；Qt6ct 桌面入口使用 Breeze 中已有的通用设置图标。
for utility_icon in kfind kdf; do
    while IFS= read -r -d '' icon_file; do
        relative_icon="${icon_file#/usr/share/icons/}"
        mkdir -p "AppDir/share/icons/$(dirname -- "$relative_icon")"
        cp -a -- "$icon_file" "AppDir/share/icons/$relative_icon"
    done < <(find /usr/share/icons/hicolor -type f -path "*/apps/$utility_icon.*" -print0)
done

# 在进入现有收尾脚本前先检查本次新增内容，避免缺程序、桌面入口、预设数据、配色迁移 Hook 或图标仍继续压缩。
test -x AppDir/bin/qt6ct
test -x AppDir/bin/kfind
test -x AppDir/bin/kdf
test -x AppDir/bin/01-kde-suite-qt6ct-color-path.hook
test -f AppDir/share/applications/qt6ct.desktop
test -f AppDir/share/applications/org.kde.kfind.desktop
test -f AppDir/share/applications/org.kde.kdf.desktop
test -d AppDir/share/qt6ct/colors
test -d AppDir/share/qt6ct/qss
grep -Fq 'qt6ct_config_root="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct"' AppDir/bin/01-kde-suite-qt6ct-color-path.hook
grep -Fq '/tmp/.mount_*/share/qt6ct/colors/*.conf)' AppDir/bin/01-kde-suite-qt6ct-color-path.hook
grep -Fq 'qt6ct_scheme_source="$APPDIR/share/qt6ct/colors/$qt6ct_scheme_name"' AppDir/bin/01-kde-suite-qt6ct-color-path.hook
grep -Fq 'color_scheme_path=$qt6ct_scheme_target_sed' AppDir/bin/01-kde-suite-qt6ct-color-path.hook
find AppDir/share/icons/hicolor -type f -path '*/apps/kfind.*' -print -quit | grep -q .
find AppDir/share/icons/hicolor -type f -path '*/apps/kdf.*' -print -quit | grep -q .
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kfind.mo
test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kdf.mo
desktop-file-validate AppDir/share/applications/qt6ct.desktop
desktop-file-validate AppDir/share/applications/org.kde.kfind.desktop
desktop-file-validate AppDir/share/applications/org.kde.kdf.desktop
