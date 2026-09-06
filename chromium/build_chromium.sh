#!/usr/bin/env bash
set -Eeuo pipefail

###### 定位脚本目录，保证在仓库任意位置调用都固定在 chromium/ 目录内构建 ######
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

rm -rf AppDir dist chromium.desktop chromium.png || true

ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64." >&2
  exit 1
fi
export ARCH

export STARTUPWMCLASS=chromium
export OUTPATH=./dist
export OUTNAME="chromium.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1

###### 准备构建环境：安装最小基础包 ######
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

###### 安装 Chromium 官方仓库包及中文输入法（IBus / Fcitx5）GTK3 组件 ######
# Chromium 上游没有官方通用 Linux 二进制发行版；这里使用 Arch [extra] 官方仓库的 chromium 包，
# 该包直接基于 Google chromium-browser-official 官方源码构建，随 Arch 仓库持续更新，天然满足
# “应用版本必须动态获取”的要求。pacman 会校验官方包签名；chromium 自身的运行库依赖由包
# 管理器按真实依赖关系自动拉入，这里只需额外安装输入法组件。
yay -S --noconfirm chromium ibus fcitx5-gtk

if [ ! -x /usr/bin/chromium ]; then
  echo "Error: /usr/bin/chromium not found after installing the chromium package." >&2
  exit 1
fi

###### 解析主二进制真实位置：资源文件如与二进制同目录，需整体交给 quick-sharun ######
REAL_BIN="$(readlink -f /usr/bin/chromium)"
REAL_DIR="$(dirname "$REAL_BIN")"

CHROMIUM_TARGETS=("$REAL_BIN")
if [ -f "$REAL_DIR/resources.pak" ] || [ -d "$REAL_DIR/locales" ]; then
  # resources.pak / icudtl.dat / locales 等资源与主二进制同目录（非独立单文件布局）。
  # 仿照本仓库 vscode 等 Electron/Chromium 系应用的既有做法，把整个目录展开传给
  # quick-sharun，避免只收集到 ELF 共享库依赖、漏掉这些非 ELF 资源文件。
  CHROMIUM_TARGETS=("$REAL_DIR"/*)
fi

###### 准备 desktop 与图标：复制官方文件到本地再注入版本信息，不改系统原文件、不自制品牌 ######
if [ ! -f /usr/share/applications/chromium.desktop ]; then
  echo "Error: /usr/share/applications/chromium.desktop not found." >&2
  exit 1
fi
cp -v /usr/share/applications/chromium.desktop ./chromium.desktop

ICON_SRC=""
for candidate in \
  /usr/share/icons/hicolor/256x256/apps/chromium.png \
  /usr/share/icons/hicolor/128x128/apps/chromium.png \
  /usr/share/pixmaps/chromium.png; do
  if [ -f "$candidate" ]; then
    ICON_SRC="$candidate"
    break
  fi
done
if [ -z "$ICON_SRC" ]; then
  echo "Error: no chromium icon found under hicolor/pixmaps." >&2
  exit 1
fi
cp -v "$ICON_SRC" ./chromium.png

export DESKTOP=./chromium.desktop
export ICON=./chromium.png

###### 记录版本，供 Release / desktop 元数据使用 ######
VERSION="$(chromium --version | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n1 || true)"
if [ -z "$VERSION" ]; then
  echo "Error: failed to determine Chromium version." >&2
  exit 1
fi
echo "$VERSION" > ~/version
echo "Chromium version: $VERSION"
if ! grep -q '^X-AppImage-Version=' ./chromium.desktop; then
  echo "X-AppImage-Version=$VERSION" >> ./chromium.desktop
fi

###### 核心打包：quick-sharun 收集依赖并生成 AppImage ######
quick-sharun \
  "${CHROMIUM_TARGETS[@]}" \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

quick-sharun --make-appimage
