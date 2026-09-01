#!/usr/bin/env bash
set -Eeuo pipefail

# 每次构建都使用全新的工作目录，避免旧产物或旧版本文件混入本次 AppImage。
rm -rf AppDir dist workbuddy.desktop workbuddy.png || true

ARCH="$(uname -m)"

# 当前只打包 Linux x86_64。
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

# 安装 AppImage 打包和 Electron 运行所需的基础依赖；WorkBuddy 自身 Linux 适配由 AUR 配方负责。
yay -S --noconfirm --needed \
  gcc base-devel git curl wget tar gzip binutils patchelf coreutils file p7zip \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss alsa-lib gtk3 at-spi2-core libsecret libxkbfile \
  libappindicator-gtk3 libnotify libxss libxtst shared-mime-info xdg-utils \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio ibus imagemagick

# 安装当前 AUR workbuddy；不在本仓库锁定 WorkBuddy 版本。
yay -S --noconfirm --needed workbuddy

# 从实际安装结果读取版本，避免在本仓库重复维护 WorkBuddy 版本号。
VERSION="$(pacman -Q workbuddy | awk '{print $2}')"

if [[ -z "$VERSION" ]]; then
  echo "Error: failed to resolve installed WorkBuddy version."
  exit 1
fi

echo "WorkBuddy AUR version: $VERSION"

# 输出 AUR 最终安装文件清单，后续失败时可以直接根据 Action 日志核对真实布局。
echo "=== Installed WorkBuddy files ==="
pacman -Ql workbuddy

# 从当前 AUR 实际安装文件清单动态定位展开后的 Electron payload，不锁定 /opt 下的目录大小写或版本布局。
APP_PACKAGE_JSON="$(pacman -Qlq workbuddy | grep -E '/app\.asar\.unpacked/package\.json$' | head -n 1 || true)"

if [[ -z "$APP_PACKAGE_JSON" || ! -f "$APP_PACKAGE_JSON" ]]; then
  echo "Error: WorkBuddy app.asar.unpacked/package.json was not found in the installed AUR package."
  exit 1
fi

APP_PAYLOAD_DIR="$(dirname "$APP_PACKAGE_JSON")"
AUR_RESOURCE_ROOT="$(dirname "$APP_PAYLOAD_DIR")"
echo "WorkBuddy payload: $APP_PAYLOAD_DIR"
echo "WorkBuddy resource root: $AUR_RESOURCE_ROOT"

# AUR 当前明确依赖系统 electron；先通过已验证可执行的版本命令取得主版本，再定位 Arch 的真实 runtime 目录。
ELECTRON_BIN="$(command -v electron || true)"

if [[ -z "$ELECTRON_BIN" || ! -e "$ELECTRON_BIN" ]]; then
  echo "Error: AUR dependency 'electron' is not installed."
  exit 1
fi

ELECTRON_VERSION="$(electron --no-sandbox --version)"
ELECTRON_MAJOR="${ELECTRON_VERSION#v}"
ELECTRON_MAJOR="${ELECTRON_MAJOR%%.*}"

if [[ ! "$ELECTRON_MAJOR" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to resolve Electron major version from: $ELECTRON_VERSION"
  exit 1
fi

ELECTRON_ROOT="/usr/lib/electron${ELECTRON_MAJOR}"
ELECTRON_REAL="$ELECTRON_ROOT/electron"
ELECTRON_NAME="electron"

if [[ ! -x "$ELECTRON_REAL" || ! -d "$ELECTRON_ROOT/resources" ]]; then
  echo "Error: Electron runtime is incomplete: $ELECTRON_ROOT"
  exit 1
fi

echo "Electron version: $ELECTRON_VERSION"
echo "Electron runtime: $ELECTRON_ROOT"

mkdir -p AppDir/bin/resources dist

# 复制完整 Linux Electron runtime，保留 locales、resources、snapshot 等运行文件。
cp -a "$ELECTRON_ROOT"/. AppDir/bin/

# Electron 的 Qt6 shim 只用于可选的 Qt 原生主题集成；Arch electron 不把 qt6-base 作为必需运行时依赖。
# AppImage 不捆绑整套 Qt6，避免 quick-sharun 把可选 shim 当作必需 ELF 并因缺少 Qt6 中止。
rm -f AppDir/bin/libqt6_shim.so

# 保留 Electron runtime 自己的 resources 内容，同时加入 AUR 已经完成 Linux 适配的 WorkBuddy 应用目录。
rm -rf AppDir/bin/resources/app.asar.unpacked
cp -a "$APP_PAYLOAD_DIR" AppDir/bin/resources/app.asar.unpacked

APPDIR_PAYLOAD="AppDir/bin/resources/app.asar.unpacked"

# 保持 8 月 28 日已验证的单引号资源路径修补语义，只动态代入当前 AUR 的实际资源根目录。
AUR_RESOURCE_LITERAL="'$AUR_RESOURCE_ROOT'"
mapfile -t RESOURCE_PATCH_FILES < <(
  grep -RIl --fixed-strings "$AUR_RESOURCE_LITERAL" "$APPDIR_PAYLOAD" 2>/dev/null || true
)

if [[ "${#RESOURCE_PATCH_FILES[@]}" -eq 0 ]]; then
  echo "Error: expected AUR resource-path patch was not found: $AUR_RESOURCE_LITERAL"
  exit 1
fi

for patched_file in "${RESOURCE_PATCH_FILES[@]}"; do
  sed -i "s#$AUR_RESOURCE_LITERAL#process.resourcesPath#g" "$patched_file"
done

# 修复后不允许应用文本代码继续保留当前 AUR 的单引号系统资源路径。
if grep -RIl --fixed-strings "$AUR_RESOURCE_LITERAL" "$APPDIR_PAYLOAD" 2>/dev/null | grep -q .; then
  echo "Error: hard-coded AUR resource root remains after AppImage resource-path restoration: $AUR_RESOURCE_LITERAL"
  exit 1
fi

echo "Restored process.resourcesPath in ${#RESOURCE_PATCH_FILES[@]} file(s)."

# 只保留当前 x86_64 所需的 @lydell node-pty 平台包，避免把 macOS/Windows/ARM 原生模块带入 Linux AppImage。
PTY_ROOT="$APPDIR_PAYLOAD/node_modules/@lydell"
if [[ -d "$PTY_ROOT" ]]; then
  while IFS= read -r -d '' platform_dir; do
    if [[ "$(basename "$platform_dir")" != "node-pty-linux-x64" ]]; then
      rm -rf "$platform_dir"
    fi
  done < <(find "$PTY_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'node-pty-*' -print0)
fi

# 当前 AUR 明确注入 Linux x64 node-pty；缺失时不生成伪可用 AppImage。
LINUX_PTY_DIR="$APPDIR_PAYLOAD/node_modules/@lydell/node-pty-linux-x64"
LINUX_PTY_NODE="$(find "$LINUX_PTY_DIR" -type f -name '*.node' -print -quit 2>/dev/null || true)"

if [[ -z "$LINUX_PTY_NODE" || ! -f "$LINUX_PTY_NODE" ]]; then
  echo "Error: Linux x64 node-pty native module is missing."
  exit 1
fi

if ! file -b "$LINUX_PTY_NODE" | grep -q '^ELF '; then
  echo "Error: Linux x64 node-pty module is not ELF: $LINUX_PTY_NODE"
  file "$LINUX_PTY_NODE" || true
  exit 1
fi

# 确认 AUR 适配后的 better-sqlite3 Linux x64 prebuild 确实存在。
SQLITE_PREBUILD="$(find "$APPDIR_PAYLOAD/node_modules/better-sqlite3/prebuilds" -maxdepth 1 -type f -name 'linux-x64*.node' -print -quit 2>/dev/null || true)"

if [[ -z "$SQLITE_PREBUILD" || ! -f "$SQLITE_PREBUILD" ]]; then
  echo "Error: better-sqlite3 Linux x64 prebuild is missing."
  exit 1
fi

if ! file -b "$SQLITE_PREBUILD" | grep -q '^ELF '; then
  echo "Error: better-sqlite3 Linux x64 prebuild is not ELF: $SQLITE_PREBUILD"
  file "$SQLITE_PREBUILD" || true
  exit 1
fi

# 固定 AppImage 内部入口；不创建或修改系统 WorkBuddy 安装目录。
cat > AppDir/bin/workbuddy <<EOF_WRAPPER
#!/usr/bin/env bash
set -e
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
export ELECTRON_FORCE_IS_PACKAGED=1
# GitHub Actions 容器的 /dev/shm 容量很小；仅在 CI 中让 Chromium 改用临时目录，避免 font_data 共享内存 ENOSPC。
if [[ "\${GITHUB_ACTIONS:-}" == "true" ]]; then
  exec "\$HERE/$ELECTRON_NAME" --disable-dev-shm-usage "\$HERE/resources/app.asar.unpacked" "\$@"
fi
exec "\$HERE/$ELECTRON_NAME" "\$HERE/resources/app.asar.unpacked" "\$@"
EOF_WRAPPER
chmod +x AppDir/bin/workbuddy

# 读取 AUR desktop，保证应用协议、WMClass 等元数据保持当前配方基线。
INSTALLED_DESKTOP="$(pacman -Qlq workbuddy | grep -E '/applications/[^/]*workbuddy[^/]*\.desktop$' | head -n 1 || true)"

if [[ -z "$INSTALLED_DESKTOP" || ! -f "$INSTALLED_DESKTOP" ]]; then
  echo "Error: WorkBuddy desktop entry was not found."
  exit 1
fi

cp -a "$INSTALLED_DESKTOP" ./workbuddy.desktop
sed -i \
  -e 's#^Exec=.*#Exec=workbuddy %U#' \
  -e 's#^Icon=.*#Icon=workbuddy#' \
  ./workbuddy.desktop

if grep -q '^X-AppImage-Version=' ./workbuddy.desktop; then
  sed -i "s#^X-AppImage-Version=.*#X-AppImage-Version=$VERSION#" ./workbuddy.desktop
else
  echo "X-AppImage-Version=$VERSION" >> ./workbuddy.desktop
fi

# AUR 已安装官方应用图标，直接复制，不重新生成图像内容。
ICON_SOURCE="$(pacman -Qlq workbuddy | grep -Ei '/icons/.*/workbuddy\.png$' | sort -V | tail -n 1 || true)"

if [[ -z "$ICON_SOURCE" || ! -f "$ICON_SOURCE" ]]; then
  echo "Error: WorkBuddy PNG icon was not found."
  exit 1
fi

cp -a "$ICON_SOURCE" ./workbuddy.png

# Linux AppIndicator 会从磁盘路径重新读取托盘图标；WorkBuddy Linux 适配固定读取
# path.dirname(process.resourcesPath)/.workbuddy-linux/workbuddy.png。
# AppImage 中 process.resourcesPath=AppDir/bin/resources，因此图标必须位于 AppDir/bin/.workbuddy-linux/。
TRAY_ICON_DIR="AppDir/bin/.workbuddy-linux"
TRAY_ICON="$TRAY_ICON_DIR/workbuddy.png"
mkdir -p "$TRAY_ICON_DIR"
cp -a "$ICON_SOURCE" "$TRAY_ICON"

# 构建阶段直接检查托盘图标，避免再次发布“程序可启动但 i3bar 托盘缺图标”的 AppImage。
if [[ ! -s "$TRAY_ICON" ]]; then
  echo "Error: WorkBuddy Linux tray icon is missing: $TRAY_ICON"
  exit 1
fi

# 记录实际 AUR 版本，沿用仓库其他项目的版本输出方式。
echo "$VERSION" > ~/version

export APPNAME=WorkBuddy
export STARTUPWMCLASS="$(sed -n 's/^StartupWMClass=//p' ./workbuddy.desktop | head -n 1)"
export STARTUPWMCLASS="${STARTUPWMCLASS:-WorkBuddy}"
export ICON=./workbuddy.png
export DESKTOP=./workbuddy.desktop
export OUTPATH=./dist
export OUTNAME=workbuddy.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 只对 Linux 实际会加载的关键 native module 做架构检查；平台可选资源本身不作为误报条件。
for native_file in "$LINUX_PTY_NODE" "$SQLITE_PREBUILD"; do
  echo "Native module: $native_file"
  file "$native_file"
  ldd "$native_file" || true
done

# 使用仓库统一 quick-sharun 路径部署 Electron 依赖，并补齐输入法、NSS、hostname 运行项。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/bin/ln \
  /usr/bin/grep \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

# 生成最终单文件 AppImage。
quick-sharun --make-appimage

# 最终目标必须存在且非空。
test -s ./dist/workbuddy.AppImage
