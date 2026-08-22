#!/usr/bin/env bash
# KDE Suite 构建入口。
# 基础构建逻辑保存在 build_core.sh；本入口预装 Okular、Ark、Gwenview、Haruna、KFind 与活动管理组件，
# 并在生成 AppImage 前补充其可执行文件、插件、数据、图标和桌面集成。

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
