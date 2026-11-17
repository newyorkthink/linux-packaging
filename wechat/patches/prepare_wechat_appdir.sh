#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAGE="${1:-}"
SOURCE_DIR="${2:-}"
APPDIR="${3:-}"

(( $# == 3 )) && [[ -n "$SOURCE_DIR" && -n "$APPDIR" ]] || {
  echo "用法：$0 <prepare|finalize> <source 目录> <AppDir 目录>" >&2
  exit 1
}

case "$STAGE" in
  prepare)
    # 本程序专属处理：在 AppDir 内规范主桌面入口，根 desktop 和图标交给 linuxdeploy 部署。
    [[ -x "$APPDIR/opt/wechat/wechat" && -f "$APPDIR/usr/share/applications/wechat.desktop" ]] || {
      echo "错误：官方 DEB 缺少 WeChat 主程序或桌面入口。" >&2
      exit 1
    }
    if grep -Eq '^NoDisplay=true$' "$APPDIR/usr/share/applications/wechat.desktop"; then
      echo "错误：WeChat 主桌面入口被标记为隐藏。" >&2
      exit 1
    fi
    sed -i -e 's|^Exec=.*$|Exec=wechat %U|' -e 's|^Icon=.*$|Icon=wechat|' "$APPDIR/usr/share/applications/wechat.desktop"

    # 本程序专属处理：复用公共入口部署同一构建环境的 NSS/NSPR 及动态加载模块。
    "$SCRIPT_DIR/../../common/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib" --with-nspr >&2

    # 本程序专属处理：阶段返回值仍取同一份官方 DEB 的完整版本元数据。
    dpkg-deb -f "$SOURCE_DIR/WeChatLinux_x86_64.deb" Version
    ;;
  finalize)
    # 本程序专属处理：AppRun 和 GTK 部署完成后，收集 opt 主程序及已确认需要的 PulseAudio 库。
    MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
    "$SOURCE_DIR/tools/linuxdeploy" --appdir "$APPDIR" --deploy-deps-only "$APPDIR/opt/wechat/wechat" --library "/usr/lib/$MULTIARCH/libpulse.so.0" --library "/usr/lib/$MULTIARCH/libpulse-simple.so.0" >&2
    ;;
  *)
    echo "错误：未知的 WeChat 准备阶段：$STAGE" >&2
    exit 1
    ;;
esac
