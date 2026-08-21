#!/usr/bin/env bash
# OBS Studio AnyLinux AppImage：默认中文环境、Yami 深色主题和 Fcitx5 Qt6 中文输入。
set -Eeuo pipefail
shopt -s nullglob

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  printf '[OBS Studio] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == "x86_64" ]] || die "当前仅支持 x86_64。"
command -v quick-sharun >/dev/null 2>&1 || die "构建环境缺少 quick-sharun。"

rm -rf AppDir dist
mkdir -p dist

log "安装 OBS Studio、Browser Source、PipeWire、Qt6、Fcitx5 和中文资源"
pacman -Syu --noconfirm --needed \
  desktop-file-utils \
  fcitx5-qt \
  ffmpeg \
  kvantum \
  libfdk-aac \
  libva \
  libxtst \
  luajit \
  lxqt-qtplugin \
  mesa \
  noto-fonts-cjk \
  noto-fonts-emoji \
  obs-studio \
  obs-studio-plugin-browser \
  pipewire-audio \
  pipewire-jack \
  qrcodegencpp-cmake \
  qt6-base \
  qt6-svg \
  qt6ct \
  xdg-utils

# 生成中文 UTF-8 locale，供 DEPLOY_LOCALE 打包。
if [[ -f /etc/locale.gen ]]; then
  sed -i 's/^#\s*\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  grep -q '^zh_CN.UTF-8 UTF-8$' /etc/locale.gen || \
    printf '%s\n' 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
fi

# 与上游 OBS AnyLinux 构建保持一致，压缩 Intel 媒体驱动体积。
if command -v get-debloated-pkgs >/dev/null 2>&1; then
  get-debloated-pkgs --add-common --prefer-nano intel-media-driver-mini '!' qt6-base
else
  pacman -S --noconfirm --needed libva-intel-driver
fi

[[ -x /usr/bin/obs ]] || die "没有找到 OBS Studio 主程序。"
[[ -f /usr/share/applications/com.obsproject.Studio.desktop ]] || die "没有找到 OBS desktop 文件。"
[[ -f /usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png ]] || die "没有找到 OBS 图标。"

readonly FCITX_QT6_PLUGIN=/usr/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
[[ -f "$FCITX_QT6_PLUGIN" ]] || die "没有找到 Fcitx5 Qt6 输入模块。"

VERSION="$(pacman -Q obs-studio | awk '{print $2; exit}' | sed -E 's/-[0-9]+$//')"
[[ -n "$VERSION" ]] || die "无法识别 OBS Studio 版本。"
printf '%s\n' "$VERSION" > dist/version.txt
log "检测到 OBS Studio $VERSION"

export ARCH=x86_64
export VERSION
export APPNAME=OBS_Studio
export STARTUPWMCLASS=obs
export OUTPATH=./dist
export OUTNAME=obs-studio.AppImage
export DESKTOP=/usr/share/applications/com.obsproject.Studio.desktop
export ICON=/usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png
export DEPLOY_LOCALE=1
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_PYTHON=1
export DEPLOY_QT=1
export DEPLOY_SDL=1
export DEPLOY_VULKAN=1
export PATH_MAPPING_HARDCODED='libobs.so*'

# 不加入 AnyLinux 的 self-updater hook 和 zsync 更新元数据。
unset ADD_HOOKS UPINFO GITHUB_REPOSITORY

QS_ARGS=(
  /usr/bin/obs
  /usr/lib/obs-plugins
  /usr/lib/libobs.so
  /usr/lib/cef
  /usr/share/obs
  "$FCITX_QT6_PLUGIN"
)

for candidate in \
  /usr/bin/obs-* \
  /usr/lib/libobs.so.* \
  /usr/lib/libluajit*.so*; do
  [[ -e "$candidate" ]] && QS_ARGS+=("$candidate")
done

log "收集 OBS、Browser Source、PipeWire、Qt6 与 Fcitx5 依赖"
quick-sharun "${QS_ARGS[@]}"

[[ -d AppDir ]] || die "quick-sharun 没有生成 AppDir。"
[[ -x AppDir/bin/obs ]] || die "AppDir 中缺少 OBS 主程序。"

cat > AppDir/bin/obs-studio-wrapper <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -e

HERE="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

# OBS 官方 Yami 深色主题；只在用户没有设置主题时写入默认值。
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/obs-studio"
CONFIG_FILE="${CONFIG_DIR}/global.ini"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_FILE" ]]; then
  printf '%s\n' '[Appearance]' 'Theme=com.obsproject.Yami' > "$CONFIG_FILE"
elif ! grep -q '^Theme=' "$CONFIG_FILE"; then
  if grep -q '^\[Appearance\]$' "$CONFIG_FILE"; then
    sed -i '/^\[Appearance\]$/a Theme=com.obsproject.Yami' "$CONFIG_FILE"
  else
    printf '\n%s\n' '[Appearance]' 'Theme=com.obsproject.Yami' >> "$CONFIG_FILE"
  fi
fi

exec "$HERE/obs" "$@"
WRAPPER_EOF
chmod 0755 AppDir/bin/obs-studio-wrapper

cat >> AppDir/.env <<'ENV_EOF'
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
QT_QPA_PLATFORM=xcb
ENV_EOF

mkdir -p AppDir/shared/bin
ln -sfn ../bin/obs-studio-wrapper AppDir/shared/bin/exe

find AppDir -type f -path '*platforminputcontexts*' -iname '*fcitx*.so' -print -quit | grep -q . || \
  die "最终 AppDir 缺少 Fcitx5 Qt6 输入模块。"
find AppDir -type f -iname 'Yami.obt' -print -quit | grep -q . || \
  die "最终 AppDir 缺少 OBS Yami 深色主题。"
find AppDir -type f \( -iname '*zh-CN*' -o -iname '*zh_CN*' \) -print -quit | grep -q . || \
  die "最终 AppDir 缺少中文资源。"
find AppDir -type f -path '*obs-plugins*' -iname '*browser*' -print -quit | grep -q . || \
  die "最终 AppDir 缺少 OBS Browser 插件。"

# OBS 为 Qt6 程序；禁止混入 Qt5 运行库。
if find AppDir -type f -name 'libQt5*.so*' -print -quit | grep -q .; then
  die "最终 AppDir 意外混入 Qt5 运行库。"
fi

log "生成无自动更新 hook 的 AppImage"
quick-sharun --make-appimage
[[ -x dist/obs-studio.AppImage ]] || die "AppImage 生成失败。"

# 与官方 OBS AnyLinux 脚本一致：直接启动并保持 12 秒，不传会立即退出的 --version。
log "执行官方 12 秒启动自检"
quick-sharun --test ./dist/*.AppImage
sha256sum dist/obs-studio.AppImage > dist/obs-studio.AppImage.sha256
log "已生成并验证：dist/obs-studio.AppImage"
