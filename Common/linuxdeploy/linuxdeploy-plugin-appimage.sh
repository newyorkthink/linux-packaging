#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 获取已安装输出入口所在的工具目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 插件探测和帮助查询直接交给官方入口，不要求 AppDir 已经存在。
case "${1:-}" in
  --plugin-api-version|--plugin-type|--help)
    exec "$SCRIPT_DIR/appimage-output" "$@"
    ;;
esac

# linuxdeploy 的输出插件接口固定传入 --appdir 和实际目录。
if [[ $# -ne 2 || "${1:-}" != --appdir || -z "${2:-}" ]]; then
  echo "用法：$0 --appdir <AppDir>" >&2
  exit 2
fi

# 本仓库兼容处理：依赖与根桌面资源部署完成后，统一准备权限和 PNG 图标。
"$SCRIPT_DIR/prepare_appdir_for_appimagetool.sh" "$2"

# 保留原始参数和 LDAI 环境配置，由当前官方输出插件完成中间封装。
exec "$SCRIPT_DIR/appimage-output" "$@"
