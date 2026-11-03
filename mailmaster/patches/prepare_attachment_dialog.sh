#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_BIN="$(cd -- "$1" && pwd)"
WORK_DIR="$(cd -- "$2" && pwd)"
CORE="$APP_BIN/libmastercore.so"
ORIGINAL='_ZN11QFileDialog16getOpenFileNamesEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE'

# 上游更换接口时保留原程序，等待重新核对附件调用。
if ! nm -D --undefined-only "$CORE" | awk -v symbol="$ORIGINAL@Qt_5" '$NF == symbol { found = 1 } END { exit !found }'; then
  echo "MailMaster：未找到原 Qt 5 文件选择接口，跳过附件起始目录补丁。" >&2
  exit 0
fi

# 保留导入原有的 Qt_5 符号版本，只为 libmastercore 增加专属兼容入口。
printf '%s %s\n' "$ORIGINAL" mailmaster_open_files > "$WORK_DIR/attachment-symbols.map"
printf '%s\n' 'Qt_5 { global: mailmaster_open_files; local: *; };' > "$WORK_DIR/attachment-exports.map"

# 使用 Qt 5 头文件编译兼容层，链接 DEB 自带的 Qt 运行库。
read -r -a QT_CFLAGS <<< "$(pkg-config --cflags Qt5Widgets)"
g++ -std=c++17 -shared -fPIC -fvisibility=default "${QT_CFLAGS[@]}" "$SCRIPT_DIR/attachment-dialog.cpp" -L"$APP_BIN/lib" -Wl,-rpath-link,"$APP_BIN/lib" -Wl,-z,defs -Wl,--version-script,"$WORK_DIR/attachment-exports.map" -Wl,-soname,libmailmaster-attachment.so -l:libQt5Widgets.so.5 -l:libQt5Core.so.5 -o "$APP_BIN/lib/libmailmaster-attachment.so"

# 只改 AppDir 内 libmastercore 的导入符号，不设置全局预加载。
patchelf --rename-dynamic-symbols "$WORK_DIR/attachment-symbols.map" --add-needed libmailmaster-attachment.so "$CORE"
