#!/usr/bin/env bash
# KDE Suite 构建入口。
# 基础构建逻辑保存在 build_core.sh；本入口预装 Okular、Ark、Gwenview、Haruna、KFind 与活动管理组件，
# 并在生成 AppImage 前补充其可执行文件、插件、数据、图标和桌面集成。

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
REAL_QUICK_SHARUN="$(type -P quick-sharun || true)"

if [ -z "$REAL_QUICK_SHARUN" ]; then
    echo "错误：未找到 quick-sharun。" >&2
    exit 1
fi

# 必须在基础脚本收集 KF6 插件、QML 模块和简体中文翻译前安装，确保额外应用、
# Activities、Dolphin 下载服务的 Breeze QML 样式及 Haruna 在线链接所需的 yt-dlp、EJS 和 Deno 一并进入 AppDir。
# Breeze 与 Breeze Dark 已由 build_core.sh 安装，不再安装完整 Flat Remix 及其额外继承主题。
# Kate/KWrite 是独立编辑器，kuiserver 属于 Plasma 工作区；它们不是当前套件功能依赖，不因可忽略日志单独加入。
yay -S --noconfirm okular ark gwenview haruna kfind kactivitymanagerd qqc2-breeze-style yt-dlp deno qt6-imageformats kimageformats

quick-sharun() {
    if [ "${1:-}" = "--make-appimage" ]; then
        # 基础 AppDir 已完成后、最终压缩前先部署轻量实用工具，再执行现有套件级收尾与静态检查。
        # shellcheck source=deploy_utility_apps.sh
        . "$SCRIPT_DIR/deploy_utility_apps.sh"
        # shellcheck source=deploy_suite_apps.sh
        . "$SCRIPT_DIR/deploy_suite_apps.sh"
    fi

    "$REAL_QUICK_SHARUN" "$@"
}

# shellcheck source=build_core.sh
. "$SCRIPT_DIR/build_core.sh"

# KDE Suite 是一个聚合 AppImage，没有单一上游版本。
# 更新器版本由“套件主要组件实际包版本 + 本目录功能文件内容”共同生成：
# - 任一主要组件升级，指纹变化；
# - 打包/启动/部署逻辑变化，指纹变化；
# - 相同组件版本与相同构建逻辑重复构建，指纹保持不变。
KDE_SUITE_COMPONENT_PACKAGES=(
    ark
    deno
    dolphin
    filelight
    gwenview
    haruna
    kactivitymanagerd
    kdeconnect
    kdf
    kfind
    kompare
    konsole
    okular
    qt6ct
    yt-dlp
)

KDE_SUITE_BUILD_FILES=(
    apps.ini
    build_core.sh
    build_kde_suite.sh
    deploy_activities.sh
    deploy_icon_theme.sh
    deploy_suite_apps.sh
    deploy_utility_apps.sh
    kde-suite.svg
    kde_suite_launcher.cpp
    okular_ark.sh
    org.kde.kdesuite.desktop
)

KDE_SUITE_FINGERPRINT_INPUT="$(mktemp)"
cleanup_kde_suite_fingerprint() {
    rm -f -- "$KDE_SUITE_FINGERPRINT_INPUT"
}
trap cleanup_kde_suite_fingerprint EXIT

for package_name in "${KDE_SUITE_COMPONENT_PACKAGES[@]}"; do
    package_query="$(pacman -Q "$package_name" 2>/dev/null)" || {
        echo "错误：无法读取 KDE Suite 组件版本：$package_name" >&2
        exit 1
    }
    package_version="${package_query#* }"
    if [ -z "$package_version" ] || [ "$package_version" = "$package_query" ]; then
        echo "错误：KDE Suite 组件版本格式异常：$package_name" >&2
        exit 1
    fi
    printf 'package\t%s\t%s\n' "$package_name" "$package_version" >> "$KDE_SUITE_FINGERPRINT_INPUT"
done

for relative_file in "${KDE_SUITE_BUILD_FILES[@]}"; do
    file_path="$SCRIPT_DIR/$relative_file"
    if [ ! -f "$file_path" ]; then
        echo "错误：KDE Suite 指纹文件不存在：$relative_file" >&2
        exit 1
    fi
    file_sha256="$(sha256sum "$file_path" | awk '{print $1}')"
    if [ -z "$file_sha256" ]; then
        echo "错误：无法计算 KDE Suite 指纹文件 SHA-256：$relative_file" >&2
        exit 1
    fi
    printf 'file\t%s\t%s\n' "$relative_file" "$file_sha256" >> "$KDE_SUITE_FINGERPRINT_INPUT"
done

KDE_SUITE_BUILD_FINGERPRINT="$(sha256sum "$KDE_SUITE_FINGERPRINT_INPUT" | awk '{print substr($1, 1, 12)}')"
if [ -z "$KDE_SUITE_BUILD_FINGERPRINT" ]; then
    echo "错误：无法生成 KDE Suite 构建指纹。" >&2
    exit 1
fi

KDE_SUITE_UPDATE_VERSION="kde-suite+linuxpackaging.$KDE_SUITE_BUILD_FINGERPRINT"
test -s "$SCRIPT_DIR/dist/kde-suite.AppImage"
printf '%s\n' "$KDE_SUITE_UPDATE_VERSION" > "$SCRIPT_DIR/dist/version.txt"
printf 'KDE Suite updater version: %s\n' "$KDE_SUITE_UPDATE_VERSION"

cleanup_kde_suite_fingerprint
trap - EXIT
