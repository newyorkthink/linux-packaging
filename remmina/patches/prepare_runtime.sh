#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 接收 AppDir 路径，并拒绝空路径、无效目录和根目录。
if [[ $# -ne 1 || -z "${1:-}" || ! -d "$1" ]]; then
  echo "用法：$0 <AppDir>" >&2
  exit 2
fi
APPDIR="$(cd -- "$1" && pwd -P)"
[[ "$APPDIR" != / ]] || {
  echo "错误：不能将根目录作为 AppDir。" >&2
  exit 2
}

# Remmina 的桌面入口通过发行版 wrapper 启动，改为包内真实程序入口。
DESKTOP_FILE="$APPDIR/usr/share/applications/org.remmina.Remmina.desktop"
sed -E -i 's|^Exec=remmina-file-wrapper(.*)$|Exec=remmina\1|' "$DESKTOP_FILE"

# Remmina 的插件路径编译为绝对路径，保留插件原布局，并额外准备运行时插件目录。
RDP_PLUGIN="$(find /usr/lib -type f -name 'remmina-plugin-rdp.so' -print -quit)"
[[ -n "$RDP_PLUGIN" ]] || { echo "错误：构建环境中缺少 Remmina RDP 插件。" >&2; exit 1; }
PLUGIN_SOURCE_DIR="$(dirname "$RDP_PLUGIN")"
mkdir -p "$APPDIR/plugins"
cp -a "$PLUGIN_SOURCE_DIR"/. "$APPDIR/plugins/"

# 补入 Remmina 简体中文翻译，避免语言包拆分导致界面回退为英文。
ZH_CN_MO=""
for locale_root in /usr/share/locale /usr/share/locale-langpack; do
  if [[ -f "$locale_root/zh_CN/LC_MESSAGES/remmina.mo" ]]; then
    ZH_CN_MO="$locale_root/zh_CN/LC_MESSAGES/remmina.mo"
    break
  fi
done
[[ -n "$ZH_CN_MO" ]] || { echo "错误：构建环境中缺少 Remmina 简体中文翻译。" >&2; exit 1; }
mkdir -p "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES"
cp -a "$ZH_CN_MO" "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/remmina.mo"

# WebKit 使用独立子进程，保留其原布局，并准备修正后的运行目录。
WEBKIT_SOURCE_DIR="$(find /usr/lib -type d -path '*/webkit2gtk-4.1' -print -quit)"
[[ -n "$WEBKIT_SOURCE_DIR" ]] || { echo "错误：构建环境中缺少 WebKitGTK 4.1 子进程目录。" >&2; exit 1; }
mkdir -p "$APPDIR$WEBKIT_SOURCE_DIR" "$APPDIR/webkit"
cp -a "$WEBKIT_SOURCE_DIR"/. "$APPDIR$WEBKIT_SOURCE_DIR/"
cp -a "$WEBKIT_SOURCE_DIR"/. "$APPDIR/webkit/"

# 将 WebKit 子进程临时放入 usr/bin 供 linuxdeploy 收集依赖，最终封装前移除这些扫描副本。
while IFS= read -r webkit_exec; do
  cp -a "$webkit_exec" "$APPDIR/usr/bin/"
done < <(find "$WEBKIT_SOURCE_DIR" -type f -name 'WebKit*Process' -perm /111 -print | sort)

# WebKit 的沙箱需要 bubblewrap 和 D-Bus 代理，连同程序一起交给依赖收集。
cp -a /usr/bin/bwrap /usr/bin/xdg-dbus-proxy "$APPDIR/usr/bin/"

# 保留 FreeRDP 自带的运行模块目录，供 RDP 插件按原布局加载。
while IFS= read -r freerdp_dir; do
  mkdir -p "$APPDIR/$(dirname "${freerdp_dir#/}")"
  cp -a "$freerdp_dir" "$APPDIR/$(dirname "${freerdp_dir#/}")/"
done < <(find /usr/lib -maxdepth 4 -type d -name 'freerdp[0-9]*' -print | sort -u)

# FreeRDP 的 NTLM 需要 OpenSSL legacy provider，必须与 libcrypto、libssl 来自同一构建环境。
OPENSSL_LEGACY_MODULE="$(find /usr/lib -type f -path '*/ossl-modules/legacy.so' -print -quit)"
OPENSSL_LIBCRYPTO="$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -type f -name 'libcrypto.so.3' -print -quit)"
OPENSSL_LIBSSL="$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -type f -name 'libssl.so.3' -print -quit)"
[[ -n "$OPENSSL_LIBCRYPTO" && -n "$OPENSSL_LIBSSL" && -n "$OPENSSL_LEGACY_MODULE" ]] || { echo "错误：构建环境中缺少 OpenSSL 3 运行库或 legacy provider。" >&2; exit 1; }
OPENSSL_APP_LIBDIR="$APPDIR/usr/lib/x86_64-linux-gnu"
mkdir -p "$OPENSSL_APP_LIBDIR/ossl-modules"
cp -aL "$OPENSSL_LIBCRYPTO" "$OPENSSL_APP_LIBDIR/libcrypto.so.3"
cp -aL "$OPENSSL_LIBSSL" "$OPENSSL_APP_LIBDIR/libssl.so.3"
cp -aL "$OPENSSL_LEGACY_MODULE" "$OPENSSL_APP_LIBDIR/ossl-modules/legacy.so"

# Remmina 需要包内 Fcitx5 和 IBus 模块，统一交给 linuxdeploy 收集配套依赖。
FCITX_MODULE="$(find /usr/lib -type f -path '*/gtk-3.0/*/immodules/im-fcitx5.so' -print -quit)"
IBUS_MODULE="$(find /usr/lib -type f -path '*/gtk-3.0/*/immodules/im-ibus.so' -print -quit)"
[[ -n "$FCITX_MODULE" && -n "$IBUS_MODULE" ]] || { echo "错误：构建环境中缺少 GTK3 Fcitx5 或 IBus 输入模块。" >&2; exit 1; }
GTK_IMMODULE_DIR="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
mkdir -p "$GTK_IMMODULE_DIR"
cp -aL "$FCITX_MODULE" "$GTK_IMMODULE_DIR/im-fcitx5.so"
cp -aL "$IBUS_MODULE" "$GTK_IMMODULE_DIR/im-ibus.so"
