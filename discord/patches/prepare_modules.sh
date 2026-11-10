#!/usr/bin/env bash

# 本程序专属处理：运行数据准备失败时不启动主程序。
set -Eeuo pipefail

# 本程序专属处理：从包内模块模板取得本次完整程序版本。
MODULE_SOURCE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../share/discord-modules" && pwd)"
VERSION="$(cat -- "$MODULE_SOURCE/.appimage-version")"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
  echo "错误：包内 Discord 模块版本无效。" >&2
  exit 1
}
MODULE_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/discord/$VERSION/modules"

# 本程序专属处理：来源变化或桌面核心缺失时，只重新部署当前版本的模块缓存。
if [[ ! -s "$MODULE_DEST/discord_desktop_core/index.js" || ! -s "$MODULE_DEST/discord_desktop_core/core.asar" ]] || ! cmp -s -- "$MODULE_SOURCE/.appimage-source.sha256" "$MODULE_DEST/.appimage-source.sha256"; then
  rm -rf -- "$MODULE_DEST"
  mkdir -p "$MODULE_DEST"
  cp -a -- "$MODULE_SOURCE"/. "$MODULE_DEST"/
fi

# 本程序专属处理：Krisp 日志写入用户模块目录，不写只读挂载点。
mkdir -p "$MODULE_DEST/discord_krisp/KMS/logs"
