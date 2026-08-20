#!/usr/bin/env bash
set -e

rm -rf AppDir VSCode-linux-* || true

ARCH="$(uname -m)"

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

export ARCH

FARCH=x64

# 安装基础打包工具和依赖
yay -S --noconfirm gcc base-devel curl wget tar gzip binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# 安装 VS Code / Electron 运行相关依赖
# 参考 visual-studio-code-bin 的常见依赖，并补充 X11 / OpenGL / IBus 相关库，方便 quick-sharun 收集运行库。
yay -S --noconfirm libdbusmenu-glib libxkbfile gnupg gtk3 libsecret nss \
  gcc-libs libnotify libxss glibc lsof shared-mime-info xdg-utils alsa-lib \
  libx11 libxext libxi libxrandr libxtst libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  ibus

export STARTUPWMCLASS=Code
export ICON=https://raw.githubusercontent.com/microsoft/vscode/refs/heads/main/resources/linux/code.png
export DESKTOP=./AppDir/code.desktop
export OUTPATH=./dist
export OUTNAME="vscode.AppImage"
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1

# 下载官方 VS Code stable x64 tar 包
DOWNLOAD_URL="$(curl -fsSLI -o /dev/null -w '%{redirect_url}' \
  "https://code.visualstudio.com/sha/download?build=stable&os=linux-$FARCH")"

if [ -z "$DOWNLOAD_URL" ]; then
  DOWNLOAD_URL="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://code.visualstudio.com/sha/download?build=stable&os=linux-$FARCH")"
fi

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: failed to resolve VS Code download URL."
  exit 1
fi

echo "VS Code download URL: $DOWNLOAD_URL"

mkdir -p ./AppDir/bin ./AppDir/share/applications ./dist
wget --retry-connrefused --tries=30 "$DOWNLOAD_URL" -O /tmp/vscode.tar.gz

tar -xzf /tmp/vscode.tar.gz
VSCODE_DIR="$(find . -maxdepth 1 -type d -name 'VSCode-linux-*' | head -n 1)"

if [ -z "$VSCODE_DIR" ]; then
  echo "Error: extracted VSCode-linux-* directory not found."
  exit 1
fi

mv -v "$VSCODE_DIR"/* ./AppDir/bin/

# 提取版本号，供后续 release / desktop 元数据使用
VERSION="$(awk -F'\"' '/\"version\":/ {print $4; exit}' ./AppDir/bin/resources/app/package.json)"
echo "$VERSION" > ~/version
echo "VS Code version: $VERSION"

# 下载并修正官方 desktop 文件，保留 vscode:// URL handler
wget --retry-connrefused --tries=30 \
  https://raw.githubusercontent.com/microsoft/vscode/refs/heads/main/resources/linux/code.desktop \
  -O ./AppDir/code.desktop

wget --retry-connrefused --tries=30 \
  https://raw.githubusercontent.com/microsoft/vscode/refs/heads/main/resources/linux/code-url-handler.desktop \
  -O ./AppDir/share/applications/code-url-handler.desktop

sed -i \
  -e 's/@@NAME_SHORT@@/Code/g' \
  -e 's/@@NAME@@/code/g' \
  -e 's#@@EXEC@@#code#g' \
  -e 's/@@ICON@@/visual-studio-code/g' \
  -e 's/@@URLPROTOCOL@@/vscode/g' \
  -e 's/@@NAME_LONG@@/Visual Studio Code/g' \
  ./AppDir/code.desktop \
  ./AppDir/share/applications/code-url-handler.desktop

# 给 AppImage 追加版本元数据
for desktop_file in ./AppDir/code.desktop ./AppDir/share/applications/code-url-handler.desktop; do
  if [ -n "$VERSION" ] && ! grep -q '^X-AppImage-Version=' "$desktop_file"; then
    echo "X-AppImage-Version=$VERSION" >> "$desktop_file"
  fi
done

# 上游脚本移除了不需要的 linuxmusl copilot 目录，这里保留同样处理。
rm -rf ./AppDir/bin/resources/app/node_modules/@github/copilot-linuxmusl-x64

# 使用 quick-sharun 构建 AppDir，并补充 IBus GTK3 输入法模块
quick-sharun \
  ./AppDir/bin/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage
