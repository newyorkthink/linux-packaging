#!/usr/bin/env bash

set -e

# 使用主脚本提供的托盘插件解包目录。
KEEBUNTU_PAYLOAD_DIR="$1"

# 本程序专属处理：调用 Keebuntu 归档自带的安装脚本。
test -x "$KEEBUNTU_PAYLOAD_DIR/install.sh"
"$KEEBUNTU_PAYLOAD_DIR/install.sh" --app-dir /usr/share/keepass

# 确认 GTK2 XEmbed 托盘插件已经安装；它只创建 KeePass 图标，不会重新渲染其他程序的托盘图标。
test -f /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll

# 将托盘插件放到功能插件之前加载的位置。
mv -f /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll /usr/share/keepass/GtkStatusIcon.dll
test -f /usr/share/keepass/GtkStatusIcon.dll
test ! -e /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll
