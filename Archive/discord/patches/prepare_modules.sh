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

# 本程序专属处理：按实际启动日志使用 module_data，不以 newUpdater 推断版本目录。
MODULE_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/discord/module_data"
mkdir -p "$MODULE_DEST"

# 本程序专属处理：来源变化或桌面核心缺失时，仅替换包内提供的模块子目录。
if [[ ! -s "$MODULE_DEST/installed.json" || ! -s "$MODULE_DEST/discord_desktop_core/index.js" || ! -s "$MODULE_DEST/discord_desktop_core/core.asar" ]] || ! cmp -s -- "$MODULE_SOURCE/.appimage-source.sha256" "$MODULE_DEST/.appimage-source.sha256"; then
  rm -f -- "$MODULE_DEST/.appimage-source.sha256"
  for module_path in "$MODULE_SOURCE"/*/; do
    [[ -d "$module_path" ]] || continue
    module_name="${module_path%/}"
    module_name="${module_name##*/}"
    rm -rf -- "$MODULE_DEST/$module_name"
    mkdir -p "$MODULE_DEST/$module_name"
    cp -a -- "$module_path"/. "$MODULE_DEST/$module_name"/
  done
  cp -a -- "$MODULE_SOURCE/installed.json" "$MODULE_DEST/installed.json"
  cp -a -- "$MODULE_SOURCE/.appimage-version" "$MODULE_DEST/.appimage-version"
  cp -a -- "$MODULE_SOURCE/.appimage-source.sha256" "$MODULE_DEST/.appimage-source.sha256"
fi

# 本程序专属处理：Krisp 日志写入用户模块目录，不写只读挂载点。
mkdir -p "$MODULE_DEST/discord_krisp/KMS/logs"
