#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

export ARCH="$(uname -m)"
if [[ "$ARCH" != x86_64 ]]; then
  echo "错误：JRiver 官方 Linux 包仅支持 x86_64，当前为 $ARCH。" >&2
  exit 1
fi

# 此入口由统一 Actions 的 Arch 容器调用，builduser 由公共 Action 创建。
if [[ "${GITHUB_ACTIONS:-}" != true || "$EUID" != 0 ]]; then
  echo '错误：请通过 GitHub Actions 的 Build JRiver 执行此构建脚本。' >&2
  exit 1
fi

# 保留已有构建目录，避免覆盖上一次产物。
if [[ -e "$SCRIPT_DIR/AppDir" || -e "$SCRIPT_DIR/dist" ]]; then
  echo '错误：AppDir 或 dist 已存在，请使用干净的 CI checkout。' >&2
  exit 1
fi

# 在当前项目中创建本次构建专用目录。
WORK_DIR="$(mktemp -d "$SCRIPT_DIR/.runimage-build.XXXXXX")"
# 允许普通构建用户在该目录内安装和生成 RunImage。
chown builduser "$WORK_DIR"
cd "$WORK_DIR"

###### 下载上游 RunImage ######

# 与 virt-manager 一样使用上游 continuous 构建运行时。
curl --fail --location --retry 3 --retry-delay 5 --connect-timeout 30 --max-time 600 \
  "https://github.com/VHSgunzo/runimage/releases/download/continuous/runimage-$ARCH" \
  --output runimage
# 记录本次下载的运行时摘要。
sha256sum runimage
# 允许执行构建运行时。
chmod +x runimage

###### 在 RunImage 内安装 JRiver ######

run_install() {
  set -Eeuo pipefail

  # 更新 RunImage 内部软件包。
  rim-update
  # 安装 AUR 构建所需的基础工具。
  pac --needed --noconfirm -S base-devel git yay
  # 按当前 AUR 配方安装 JRiver 官方包及声明的依赖，并使用配方校验值。
  yay --needed --noconfirm -S jriver-media-center
  # 补齐官方 DEB 声明的运行依赖，以及既有音频和 GTK 中文输入支持。
  pac --needed --noconfirm -S libxss nss nspr python xdg-utils mesa lcms2 libva \
    vulkan-icd-loader pulseaudio-alsa fcitx5-gtk

  # 从安装结果读取真实入口，不固定 JRiver 主版本。
  local -a launchers
  mapfile -t launchers < <(pacman -Qlq jriver-media-center | grep -E '^/usr/bin/mediacenter[0-9]+$')
  if [[ "${#launchers[@]}" != 1 || ! -x "${launchers[0]}" ]]; then
    echo '错误：无法从 JRiver 包中确定唯一的主程序入口。' >&2
    exit 1
  fi
  local launcher="${launchers[0]##*/}"
  local major="${launcher#mediacenter}"
  local desktop="/usr/share/applications/media_center_${major}.desktop"
  if [[ ! -s "$desktop" ]]; then
    echo "错误：JRiver 官方 desktop 文件缺失：$desktop" >&2
    exit 1
  fi

  # 将版本和官方 desktop 路径传回外层封装阶段。
  pacman -Q jriver-media-center | awk '{print $2}' > version
  printf '%s\n' "$desktop" > desktop-path

  # 在包内生成中文 locale，不覆盖运行时的宿主语言选择。
  if ! grep -qxF 'zh_CN.UTF-8 UTF-8' /etc/locale.gen; then
    printf '%s\n' 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
  fi
  # 更新包内 locale 数据。
  locale-gen

  # 写入标准 RunImage 配置，直接启动包管理器安装的 JRiver 入口。
  cat > "$RUNDIR/config/Run.rcfg" <<'EOF_CONFIG'
RIM_SYS_NVLIBS="${RIM_SYS_NVLIBS:=1}"
RIM_SHARE_ICONS="${RIM_SHARE_ICONS:=1}"
RIM_SHARE_FONTS="${RIM_SHARE_FONTS:=1}"
RIM_SHARE_THEMES="${RIM_SHARE_THEMES:=1}"
RIM_HOST_XDG_OPEN="${RIM_HOST_XDG_OPEN:=1}"
EOF_CONFIG
  # 把动态识别的主程序名称写入自动启动配置。
  printf 'RIM_AUTORUN=%q\n' "$launcher" >> "$RUNDIR/config/Run.rcfg"

  # 只清理包缓存，保留翻译、资源和原始二进制。
  rim-shrink --pkgcache
  # 生成供下一阶段解包的临时 SquashFS RunImage。
  rim-build -s "$PWD/jriver.RunImage"
}

# 将安装函数写入临时脚本，避免 sudo 过滤导出的 Bash 函数。
declare -f run_install > install.sh
# 在 RunImage 内执行安装函数。
printf '\nrun_install\n' >> install.sh
# AUR 的 makepkg 必须以普通用户运行；这些设置仅用于 CI 构建。
sudo -H -u builduser env RIM_OVERFS_MODE=1 RIM_NO_NVIDIA_CHECK=1 RIM_BIND_PWD=1 \
  ./runimage bash ./install.sh

###### 解包并封装 AppImage ######

# 提取完整 RunImage 环境。
./jriver.RunImage --runtime-extract
# 将完整 RunDir 作为 AppImage 内容。
mv ./RunDir "$SCRIPT_DIR/AppDir"
# 沿用 RunImage 自带入口。
mv "$SCRIPT_DIR/AppDir/Run" "$SCRIPT_DIR/AppDir/AppRun"

ROOTFS="$SCRIPT_DIR/AppDir/rootfs"
DESKTOP_SOURCE="$ROOTFS$(cat desktop-path)"
ICON_SOURCE="$(awk -F= '/^Icon=/{print substr($0, 6); exit}' "$DESKTOP_SOURCE")"
if [[ "$ICON_SOURCE" != /* || ! -s "$ROOTFS$ICON_SOURCE" ]]; then
  echo '错误：JRiver 官方 desktop 未指向有效的包内图标。' >&2
  exit 1
fi

# 保留官方 desktop 信息，只调整 AppImage 顶层入口和图标名称。
cp "$DESKTOP_SOURCE" ./jriver.desktop
# 原始文件仍保留在 rootfs 内，此处只修改外层 desktop 副本。
sed -i -e 's|^Exec=.*|Exec=jriver %F|' -e 's|^Icon=.*|Icon=jriver|' \
  -e '/^TryExec=/d' -e '/^Path=/d' ./jriver.desktop
# 使用官方 Logo 作为 AppImage 图标。
cp "$ROOTFS$ICON_SOURCE" ./jriver.png

export VERSION="$(cat version)"
export DESKTOP="$WORK_DIR/jriver.desktop"
export ICON="$WORK_DIR/jriver.png"
export APPNAME=jriver
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=jriver.AppImage
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|jriver.AppImage.zsync"
export OPTIMIZE_LAUNCH=1
cd "$SCRIPT_DIR"

# quick-sharun 只封装完整 RunImage，不重新收集 JRiver 的依赖。
quick-sharun --make-appimage
