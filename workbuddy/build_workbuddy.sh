#!/usr/bin/env bash
set -Eeuo pipefail

# 每次构建都使用全新的工作目录，避免旧产物或旧版本文件混入本次 AppImage。
rm -rf AppDir dist workbuddy.desktop workbuddy.png /tmp/workbuddy-app-payload || true

ARCH="$(uname -m)"

# 当前只打包 Linux x86_64，与现有仓库主要 Electron AppImage 构建保持一致。
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this script only supports x86_64 / linux-x64."
  exit 1
fi

# 在真正执行 AUR PKGBUILD 前，先运行仓库内的只读审计；审计失败就停止构建。
./test_workbuddy_aur.sh

# 安装 AppImage 打包和 Electron 运行所需的基础依赖；WorkBuddy 自身依赖由 AUR 配方继续负责。
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

# 直接安装当前 AUR workbuddy；该包已经跟踪 5.3.x，并负责完成当前 Linux 原生模块适配。
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

# 从 AUR 安装结果中寻找应用核心 app.asar；找不到就不猜路径，直接失败。
APP_ASAR="$(pacman -Qlq workbuddy | grep -E '/app\.asar$' | head -n 1 || true)"

if [[ -z "$APP_ASAR" || ! -f "$APP_ASAR" ]]; then
  echo "Error: WorkBuddy app.asar was not found in the installed AUR package."
  exit 1
fi

APP_PAYLOAD_DIR="$(dirname "$APP_ASAR")"
echo "WorkBuddy payload: $APP_PAYLOAD_DIR"

# 优先读取 AUR 自带 desktop 文件，保证应用名、协议和 WMClass 与当前配方一致。
INSTALLED_DESKTOP="$(pacman -Qlq workbuddy | grep -E '/applications/[^/]*workbuddy[^/]*\.desktop$' | head -n 1 || true)"

if [[ -z "$INSTALLED_DESKTOP" || ! -f "$INSTALLED_DESKTOP" ]]; then
  INSTALLED_DESKTOP="$(find /usr/share/applications -maxdepth 1 -type f -iname '*workbuddy*.desktop' -print -quit || true)"
fi

if [[ -z "$INSTALLED_DESKTOP" || ! -f "$INSTALLED_DESKTOP" ]]; then
  echo "Error: WorkBuddy desktop entry was not found."
  exit 1
fi

# 从 desktop Exec 取得 AUR 实际入口程序名；%U/%F 等 desktop 占位符不参与入口解析。
EXEC_LINE="$(sed -n 's/^Exec=//p' "$INSTALLED_DESKTOP" | head -n 1)"
EXEC_TOKEN="$(printf '%s\n' "$EXEC_LINE" | awk '{for (i=1;i<=NF;i++) if ($i !~ /^[A-Za-z_][A-Za-z0-9_]*=/ && $i !~ /^%/) {print $i; exit}}')"
EXEC_TOKEN="${EXEC_TOKEN%\"}"
EXEC_TOKEN="${EXEC_TOKEN#\"}"

if [[ -z "$EXEC_TOKEN" ]]; then
  EXEC_TOKEN="workbuddy"
fi

if [[ "$EXEC_TOKEN" == /* ]]; then
  INSTALLED_LAUNCHER="$EXEC_TOKEN"
else
  INSTALLED_LAUNCHER="$(command -v "$EXEC_TOKEN" || true)"
fi

if [[ -z "$INSTALLED_LAUNCHER" || ! -e "$INSTALLED_LAUNCHER" ]]; then
  INSTALLED_LAUNCHER="$(command -v workbuddy || true)"
fi

if [[ -z "$INSTALLED_LAUNCHER" || ! -e "$INSTALLED_LAUNCHER" ]]; then
  echo "Error: WorkBuddy launcher was not found."
  exit 1
fi

echo "WorkBuddy launcher: $INSTALLED_LAUNCHER"
file "$INSTALLED_LAUNCHER" || true

mkdir -p AppDir/bin dist /tmp/workbuddy-app-payload

# AUR 通常使用系统 Linux Electron + WorkBuddy app.asar；先从 launcher 和依赖中解析 Electron 包。
ELECTRON_COMMAND=""

if file -b "$INSTALLED_LAUNCHER" | grep -qiE 'script|text'; then
  ELECTRON_COMMAND="$(grep -oE 'electron[0-9]+' "$INSTALLED_LAUNCHER" | head -n 1 || true)"

  if [[ -z "$ELECTRON_COMMAND" ]]; then
    ELECTRON_COMMAND="$(grep -oE '(^|[[:space:]/])electron([[:space:]\"]|$)' "$INSTALLED_LAUNCHER" | head -n 1 | sed -E 's#^.*/##; s/[[:space:]\"]//g' || true)"
  fi
fi

# launcher 未直接写 Electron 名称时，从 pacman 依赖中找实际 electronNN 包。
if [[ -z "$ELECTRON_COMMAND" ]]; then
  ELECTRON_COMMAND="$(pacman -Qi workbuddy \
    | sed -n 's/^Depends On[[:space:]]*:[[:space:]]*//p' \
    | tr ' ' '\n' \
    | sed 's/[<>=].*$//' \
    | grep -E '^electron[0-9]*$' \
    | head -n 1 || true)"
fi

# 如果 AUR 本身已经安装了完整 Linux Electron 应用目录，则直接以 launcher 所在运行时为基线。
LAUNCHER_REAL="$(readlink -f "$INSTALLED_LAUNCHER")"
LAUNCHER_DIR="$(dirname "$LAUNCHER_REAL")"
BUNDLED_RUNTIME=0

if [[ -f "$LAUNCHER_DIR/resources/electron.asar" || -f "$LAUNCHER_DIR/resources/default_app.asar" ]]; then
  BUNDLED_RUNTIME=1
fi

if [[ "$BUNDLED_RUNTIME" -eq 1 ]]; then
  echo "Detected bundled Electron runtime: $LAUNCHER_DIR"

  # 复制 AUR 已经组装好的完整 Linux Electron 目录，不重新改动已经适配好的产品层。
  cp -a "$LAUNCHER_DIR"/. AppDir/bin/

  # 若 launcher 文件名不是 workbuddy，额外提供固定 AppImage 入口，但不修改原 launcher。
  LAUNCHER_NAME="$(basename "$LAUNCHER_REAL")"
  if [[ "$LAUNCHER_NAME" != "workbuddy" ]]; then
    cat > AppDir/bin/workbuddy <<EOF_WRAPPER
#!/usr/bin/env bash
set -e
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\$HERE/$LAUNCHER_NAME" "\$@"
EOF_WRAPPER
    chmod +x AppDir/bin/workbuddy
  fi
else
  # 系统 Electron 模式：解析 Electron ELF 的真实目录，并复制完整 Linux Electron runtime。
  if [[ -z "$ELECTRON_COMMAND" ]]; then
    echo "Error: unable to resolve the Electron runtime used by the AUR WorkBuddy launcher."
    echo "=== Launcher content ==="
    sed -n '1,160p' "$INSTALLED_LAUNCHER" || true
    echo "=== Package dependencies ==="
    pacman -Qi workbuddy || true
    exit 1
  fi

  ELECTRON_BIN="$(command -v "$ELECTRON_COMMAND" || true)"

  if [[ -z "$ELECTRON_BIN" || ! -e "$ELECTRON_BIN" ]]; then
    echo "Error: resolved Electron command '$ELECTRON_COMMAND' is not installed."
    exit 1
  fi

  ELECTRON_REAL="$(readlink -f "$ELECTRON_BIN")"
  ELECTRON_ROOT="$(dirname "$ELECTRON_REAL")"
  ELECTRON_NAME="$(basename "$ELECTRON_REAL")"

  echo "Electron command: $ELECTRON_COMMAND"
  echo "Electron runtime: $ELECTRON_ROOT"

  if [[ ! -x "$ELECTRON_REAL" ]]; then
    echo "Error: Electron executable is not executable: $ELECTRON_REAL"
    exit 1
  fi

  # 复制完整 Electron runtime，避免只复制主 ELF 后遗漏 resources/locales/chrome-sandbox 等文件。
  cp -a "$ELECTRON_ROOT"/. AppDir/bin/

  # 保留 AUR 已经完成 Linux native module 适配后的完整 WorkBuddy payload。
  cp -a "$APP_PAYLOAD_DIR"/. /tmp/workbuddy-app-payload/
  rm -rf AppDir/bin/workbuddy-app
  mv /tmp/workbuddy-app-payload AppDir/bin/workbuddy-app

  # 固定 AppImage 内部入口；用户配置仍由 WorkBuddy 自身写入 ~/.workbuddy/，不写入 AppImage。
  cat > AppDir/bin/workbuddy <<EOF_WRAPPER
#!/usr/bin/env bash
set -e
HERE="\$(cd "\$(dirname "\$0")" && pwd)"
export ELECTRON_FORCE_IS_PACKAGED=1
exec "\$HERE/$ELECTRON_NAME" "\$HERE/workbuddy-app/app.asar" "\$@"
EOF_WRAPPER
  chmod +x AppDir/bin/workbuddy
fi

# 确认最终 AppImage 入口和 app.asar 同时存在，避免生成只有 Electron 空壳的产物。
if [[ ! -x AppDir/bin/workbuddy ]]; then
  echo "Error: AppDir/bin/workbuddy launcher was not created."
  exit 1
fi

if ! find AppDir/bin -type f -name app.asar -print -quit | grep -q .; then
  echo "Error: no WorkBuddy app.asar exists inside AppDir."
  exit 1
fi

# 复制 AUR desktop 并只修正 AppImage 内部入口与图标名称。
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

# 优先使用 AUR 安装的 PNG 图标；若只有 SVG，则转换为 512x512 PNG。
ICON_SOURCE="$(pacman -Qlq workbuddy | grep -Ei '/(icons|pixmaps)/.*workbuddy.*\.png$' | sort -V | tail -n 1 || true)"

if [[ -z "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$(find "$APP_PAYLOAD_DIR" -type f -iname '*.png' -size +4k -print | head -n 1 || true)"
fi

if [[ -n "$ICON_SOURCE" && -f "$ICON_SOURCE" ]]; then
  cp -a "$ICON_SOURCE" ./workbuddy.png
else
  ICON_SOURCE="$(pacman -Qlq workbuddy | grep -Ei '/(icons|pixmaps)/.*workbuddy.*\.svg$' | head -n 1 || true)"

  if [[ -z "$ICON_SOURCE" || ! -f "$ICON_SOURCE" ]]; then
    echo "Error: WorkBuddy icon was not found."
    exit 1
  fi

  magick -background none "$ICON_SOURCE" -resize 512x512 ./workbuddy.png
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

# 在 quick-sharun 前检查 AppDir 内所有 ELF/.so/.node 的架构，禁止把 macOS Mach-O 或 Windows PE 原生模块误装进 Linux 包。
BAD_NATIVE=0
while IFS= read -r -d '' native_file; do
  kind="$(file -b "$native_file")"
  case "$kind" in
    *Mach-O*|*PE32*|*MS-DOS*)
      echo "Error: non-Linux native file remains in AppDir: $native_file"
      echo "       $kind"
      BAD_NATIVE=1
      ;;
  esac
done < <(find AppDir/bin -type f \( -name '*.node' -o -name '*.so' -o -name '*.dylib' -o -name '*.dll' \) -print0)

if [[ "$BAD_NATIVE" -ne 0 ]]; then
  exit 1
fi

# 使用仓库统一 quick-sharun 路径部署 Electron 依赖，并补齐输入法、NSS、hostname 运行项。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

# 生成最终单文件 AppImage。
quick-sharun --make-appimage

# 最终必须只有一个目标文件，且文件非空。
test -s ./dist/workbuddy.AppImage
