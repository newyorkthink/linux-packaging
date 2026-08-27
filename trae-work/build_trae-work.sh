#!/usr/bin/env bash
set -Eeuo pipefail

rm -rf AppDir dist trae-work.desktop trae-work.png \
  /tmp/aur-trae /tmp/trae-linux /tmp/trae-linux.tar.gz \
  /tmp/traework-win /tmp/traework.exe /tmp/traecode-linux-app || true

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "Error: this experimental port only supports x86_64."
  exit 1
fi

# TraeWork Windows x64：来自 Microsoft winget-pkgs 中当前已核对的 0.1.54 清单。
TRAEWORK_VERSION="${TRAEWORK_VERSION:-0.1.54}"
TRAEWORK_BUILD="${TRAEWORK_BUILD:-2.3.76123}"
TRAEWORK_URL="${TRAEWORK_URL:-https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/app/releases/stable/${TRAEWORK_BUILD}/win32/TraeWork-Setup-x64.exe}"
TRAEWORK_SHA256="${TRAEWORK_SHA256:-DFA9F3B0F2005EBAD11DDE06E573D0553DE3A29C23B38CFA222612960296CCAD}"

# 安装与现有 Trae AppImage 相同的 Electron 运行依赖，并增加 innoextract / p7zip 用于解包 Windows Inno Setup。
yay -S --noconfirm gcc base-devel git curl wget tar gzip binutils patchelf coreutils file p7zip innoextract \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss alsa-lib gtk3 at-spi2-core libsecret libxkbfile zeromq \
  libappindicator-gtk3 libnotify libxss libxtst shared-mime-info xdg-utils \
  gcc-libs glibc lsof inetutils \
  libx11 libxext libxi libxrandr libxkbcommon \
  libxcomposite libxdamage libxfixes mesa libglvnd libva libvdpau \
  pulseaudio pulseaudio-alsa pipewire-audio ibus

# 使用仓库现有 trae 打包方式读取 AUR trae 的 Linux x64 运行时，不写死 TraeCode Linux 下载地址。
for attempt in 1 2 3; do
  rm -rf /tmp/aur-trae
  if git -c http.version=HTTP/1.1 clone --depth=1 https://aur.archlinux.org/trae.git /tmp/aur-trae; then
    break
  fi
  if [[ "$attempt" -eq 3 ]]; then
    echo "Error: failed to clone AUR trae repository."
    exit 1
  fi
  sleep 5
done

PKGBUILD=/tmp/aur-trae/PKGBUILD
if [[ ! -f "$PKGBUILD" ]]; then
  echo "Error: AUR trae PKGBUILD not found."
  exit 1
fi

TRAE_VERSION="$(sed -nE 's/^pkgver=([^[:space:]]+).*/\1/p' "$PKGBUILD" | head -n 1)"
TRAE_PKGREL="$(sed -nE 's/^pkgrel=([^[:space:]]+).*/\1/p' "$PKGBUILD" | head -n 1)"
TRAE_URL="$(sed -nE 's#^source_x86_64=.*::(https://[^\"]+).*#\1#p' "$PKGBUILD" | head -n 1)"
TRAE_B2SUM="$(sed -nE "s/^b2sums_x86_64=\\('([^']+)'.*/\\1/p" "$PKGBUILD" | head -n 1)"

if [[ -z "$TRAE_VERSION" || -z "$TRAE_PKGREL" || -z "$TRAE_URL" ]]; then
  echo "Error: failed to resolve Trae Linux package from AUR PKGBUILD."
  exit 1
fi

TRAE_URL="${TRAE_URL//\$\{pkgver\}/$TRAE_VERSION}"
TRAE_URL="${TRAE_URL//\$\{pkgrel\}/$TRAE_PKGREL}"

echo "TraeWork Windows version: $TRAEWORK_VERSION ($TRAEWORK_BUILD)"
echo "Trae Linux runtime version: $TRAE_VERSION-$TRAE_PKGREL"

mkdir -p AppDir/bin dist /tmp/trae-linux /tmp/traework-win

# 下载并校验 TraeWork Windows 安装包，避免错误或被替换的安装包进入实验产物。
wget --retry-connrefused --tries=30 "$TRAEWORK_URL" -O /tmp/traework.exe
printf '%s  %s\n' "$TRAEWORK_SHA256" /tmp/traework.exe | sha256sum -c -

# 优先使用 innoextract 展开 Inno Setup；失败时回退到 7-Zip。
if ! innoextract -s -d /tmp/traework-win /tmp/traework.exe >/tmp/traework-innoextract.log 2>&1; then
  rm -rf /tmp/traework-win
  mkdir -p /tmp/traework-win
  7z x -y /tmp/traework.exe -o/tmp/traework-win >/tmp/traework-7z.log
fi
WORK_APP_PACKAGE="$(find /tmp/traework-win -type f -path '*/resources/app/package.json' -print -quit || true)"
if [[ -z "$WORK_APP_PACKAGE" ]]; then
  echo "Error: TraeWork resources/app/package.json not found after extracting Windows installer."
  find /tmp/traework-win -maxdepth 4 -type f | sort | head -n 200
  exit 1
fi
WORK_APP="$(dirname "$WORK_APP_PACKAGE")"

# 下载并校验官方 Linux TraeCode/Trae 运行时。
wget --retry-connrefused --tries=30 "$TRAE_URL" -O /tmp/trae-linux.tar.gz
if [[ -n "$TRAE_B2SUM" && "$TRAE_B2SUM" != "SKIP" ]]; then
  printf '%s  %s\n' "$TRAE_B2SUM" /tmp/trae-linux.tar.gz | b2sum -c -
fi

tar -xzf /tmp/trae-linux.tar.gz -C /tmp/trae-linux
LINUX_ROOT=/tmp/trae-linux
if [[ ! -f "$LINUX_ROOT/resources/app/resources/linux/code.png" ]]; then
  TRAE_BINARY="$(find "$LINUX_ROOT" -maxdepth 2 -type f -name trae -print -quit || true)"
  if [[ -z "$TRAE_BINARY" ]]; then
    echo "Error: extracted Linux Trae executable not found."
    exit 1
  fi
  LINUX_ROOT="$(dirname "$TRAE_BINARY")"
fi

if [[ ! -x "$LINUX_ROOT/trae" ]]; then
  echo "Error: Linux Trae executable not found at $LINUX_ROOT/trae."
  exit 1
fi

LINUX_APP="$LINUX_ROOT/resources/app"
if [[ ! -d "$LINUX_APP" ]]; then
  echo "Error: Linux Trae resources/app not found."
  exit 1
fi

# 先复制完整 Linux Electron 壳和运行时；TraeWork 只替换 resources/app 的产品层。
cp -a "$LINUX_ROOT"/. AppDir/bin/
cp -a "$LINUX_APP" /tmp/traecode-linux-app
cp -a "$LINUX_APP/resources/linux/code.png" ./trae-work.png
rm -rf AppDir/bin/resources/app
cp -a "$WORK_APP" AppDir/bin/resources/app

# 将 Linux TraeCode 中已有的 ELF/.so/.node 原生组件覆盖/补入 TraeWork 对应目录。
# 这一步解决 Windows DLL/EXE 不能在 Linux 直接加载的问题，同时保留 TraeWork 自己的 JS/产品资源。
while IFS= read -r -d '' src; do
  rel="${src#/tmp/traecode-linux-app/}"
  dest="AppDir/bin/resources/app/$rel"
  parent="$(dirname "$dest")"
  [[ -d "$parent" ]] || continue

  base="$(basename "$src")"
  if [[ "$base" == *.so || "$base" == *.so.* || "$base" == *.node ]] || file -b "$src" | grep -q '^ELF '; then
    cp -a "$src" "$dest"
  fi
done < <(find /tmp/traecode-linux-app -type f -print0)

# 旧社区移植明确依赖的三个 Linux 原生组件单独补齐；不存在时不伪造。
for rel in \
  modules/ai-agent/libai_agent.so \
  modules/ckg/binary/libckg.so \
  node_modules/native-keymap/build/Release/keymapping.node; do
  if [[ -f "/tmp/traecode-linux-app/$rel" ]]; then
    mkdir -p "AppDir/bin/resources/app/$(dirname "$rel")"
    cp -a "/tmp/traecode-linux-app/$rel" "AppDir/bin/resources/app/$rel"
  fi
done

# 补充 Linux TraeCode 自带而 TraeWork Windows 未包含的标准扩展，不覆盖 TraeWork 已有扩展文件。
if [[ -d /tmp/traecode-linux-app/extensions ]]; then
  mkdir -p AppDir/bin/resources/app/extensions
  cp -an /tmp/traecode-linux-app/extensions/. AppDir/bin/resources/app/extensions/
fi

# 与现有 Trae AppImage 保持一致，移除可能和系统 gcc-libs 冲突的 ckg 自带运行库。
rm -f \
  AppDir/bin/resources/app/modules/ckg/binary/libstdc++.so.6 \
  AppDir/bin/resources/app/modules/ckg/binary/libgcc_s.so.1

# 保留 Linux Electron 主程序 trae，并提供独立 trae-work 入口，避免改动主程序本身。
cat > AppDir/bin/trae-work <<'WRAPPER'
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/trae" "$@"
WRAPPER
chmod +x AppDir/bin/trae-work AppDir/bin/trae

cat > trae-work.desktop <<EOF_DESKTOP
[Desktop Entry]
Name=TraeWork (Linux Experimental)
Comment=Experimental TraeWork Linux port
Exec=trae-work %U
Icon=trae-work
Terminal=false
Type=Application
Categories=Development;
MimeType=x-scheme-handler/solo;
StartupWMClass=TraeWork
X-AppImage-Version=$TRAEWORK_VERSION
EOF_DESKTOP

echo "$TRAEWORK_VERSION" > ~/version

# 生成诊断信息，用于判断 Windows TraeWork 与 Linux TraeCode 的 ai-agent 服务是否仍存在 lite/solo-lite 缺口。
REPORT=./dist/port-report.txt
WIN_AGENT="$(find /tmp/traework-win -type f \( -iname '*ai*agent*.dll' -o -iname '*ai*agent*.node' \) -print -quit || true)"
LINUX_AGENT=AppDir/bin/resources/app/modules/ai-agent/libai_agent.so
{
  echo "TraeWork Linux experimental port report"
  echo "TraeWork Windows: $TRAEWORK_VERSION ($TRAEWORK_BUILD)"
  echo "Trae Linux runtime: $TRAE_VERSION-$TRAE_PKGREL"
  echo "TraeWork app source: $WORK_APP"
  echo "Windows ai-agent candidate: ${WIN_AGENT:-not found}"
  echo "Linux ai-agent: $LINUX_AGENT"
  echo
  echo "=== Linux ai-agent service-related strings ==="
  if [[ -f "$LINUX_AGENT" ]]; then
    strings "$LINUX_AGENT" | grep -Ei 'solo-lite|projectservice|unknown service|(^|[^[:alpha:]])lite([^[:alpha:]]|$)' | head -n 120 || true
  else
    echo "Linux libai_agent.so not found"
  fi
  echo
  echo "=== Windows ai-agent service-related strings ==="
  if [[ -n "$WIN_AGENT" && -f "$WIN_AGENT" ]]; then
    strings "$WIN_AGENT" | grep -Ei 'solo-lite|projectservice|unknown service|(^|[^[:alpha:]])lite([^[:alpha:]]|$)' | head -n 120 || true
  else
    echo "Windows ai-agent candidate not found"
  fi
} > "$REPORT"

export APPNAME=TraeWork
export STARTUPWMCLASS=TraeWork
export ICON=./trae-work.png
export DESKTOP=./trae-work.desktop
export OUTPATH=./dist
export OUTNAME=trae-work.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# 使用仓库现有 quick-sharun Electron 打包路径；测试产物只交给独立 workflow 上传 Artifact。
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/libzmq.so* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so

quick-sharun --make-appimage

test -s ./dist/trae-work.AppImage
printf '\nAppImage: %s\nReport: %s\n' "$(realpath ./dist/trae-work.AppImage)" "$(realpath "$REPORT")"
