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

###### 准备非特权构建运行时 ######

# 上游 RunImage 会拒绝 AppArmor 限制的非特权 user namespace；仅调整临时 CI runner。
if [[ -e /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]] &&
   [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)" == 1 ]]; then
  printf '0\n' > /proc/sys/kernel/apparmor_restrict_unprivileged_userns
fi

# RunImage 的 FUSE 和 UnionFS 挂载需要系统提供 SUID fusermount。
pacman -S --needed --noconfirm fuse2
if [[ ! -x /usr/bin/fusermount ]]; then
  echo '错误：fuse2 未提供预期的 fusermount。' >&2
  exit 1
fi
# 仅在临时 CI 容器内确保 fusermount 保留 SUID 位。
chmod u+s /usr/bin/fusermount

# 当前 CI 容器禁止非特权 user namespace；提取上游自带的 Bubblewrap。
./runimage --runtime-extract
if [[ ! -x ./RunDir/static/bwrap ]]; then
  echo '错误：RunImage 未包含预期的 Bubblewrap。' >&2
  exit 1
fi
# 仅在临时 CI 容器内安装 SUID Bubblewrap，让 builduser 能进入 RunImage。
install -o root -g root -m 4755 ./RunDir/static/bwrap /usr/bin/bwrap
# 清理临时提取目录，避免与后续成品 RunImage 解包目录冲突。
rm -rf ./RunDir

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
  printf '%s\n' "$launcher" > launcher-name

  # 在包内生成中文 locale。
  if ! grep -qxF 'zh_CN.UTF-8 UTF-8' /etc/locale.gen; then
    printf '%s\n' 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
  fi
  # 更新包内 locale 数据。
  locale-gen
  # 沿用通用 RunImage 基线，在包内设置默认简体中文环境。
  cat > /etc/locale.conf <<'EOF_LOCALE'
LANG=zh_CN.utf8
LC_ALL=zh_CN.utf8
LANGUAGE=zh_CN:zh
EOF_LOCALE

  # 包内启动脚本：去掉 Rofi/i3 AppImage 泄漏到 PATH 的 /tmp/.mount_*，并把 stdin/out/err 写到日志。不改外层 AppRun。
  cat > /usr/bin/jriver-launch <<'EOF_LAUNCH'
#!/bin/bash
_path=""
IFS=:
for _p in $PATH; do
  case "$_p" in
    /tmp/.mount_*) ;;
    "") ;;
    *) _path="${_path:+$_path:}$_p" ;;
  esac
done
unset IFS
PATH="$_path"
export PATH
export TERM="${TERM:-xterm-256color}"
export XDG_SESSION_TYPE=x11
logdir="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$logdir"
exec /usr/bin/JRIVER_LAUNCHER "$@" </dev/null >>"$logdir/jriver-launch.log" 2>&1
EOF_LAUNCH
  sed -i "s|JRIVER_LAUNCHER|${launcher}|g" /usr/bin/jriver-launch
  chmod 0755 /usr/bin/jriver-launch

  # 写入标准 RunImage 配置。
  cat > "$RUNDIR/config/Run.rcfg" <<'EOF_CONFIG'
# 禁用 RunImage 的 NVIDIA 驱动检查，避免自动检测、匹配、生成或下载驱动镜像。
RIM_NO_NVIDIA_CHECK=1
# 隐藏 RunImage 的普通信息和警告，错误仍正常输出。
RIM_QUIET_MODE=1
# 共享宿主图标。
RIM_SHARE_ICONS="${RIM_SHARE_ICONS:=1}"
# 共享宿主字体。关闭共享未能解开 Pango fontconfig 死锁，已回退。
RIM_SHARE_FONTS="${RIM_SHARE_FONTS:=1}"
# 共享宿主主题。
RIM_SHARE_THEMES="${RIM_SHARE_THEMES:=1}"
# 使用宿主 xdg-open。
RIM_HOST_XDG_OPEN="${RIM_HOST_XDG_OPEN:=1}"
# 默认使用简体中文 UTF-8 环境。
LANG=zh_CN.utf8
LANGUAGE=zh_CN:zh
# GTK 程序使用宿主 Fcitx5。
GTK_IM_MODULE=fcitx
# Qt 程序使用宿主 Fcitx5。
QT_IM_MODULE=fcitx
# X11 程序使用宿主 Fcitx5。
XMODIFIERS=@im=fcitx
# SDL 程序使用宿主 Fcitx5。
SDL_IM_MODULE=fcitx
# Rofi run 可能传入控制台 TERM=linux 和 XDG_SESSION_TYPE=tty；覆盖为 X11 GUI 会话。
TERM=xterm-256color
XDG_SESSION_TYPE=x11
EOF_CONFIG
  printf 'RIM_AUTORUN=%q\n' jriver-launch >> "$RUNDIR/config/Run.rcfg"

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
# 发布名跟随包内主程序：mediacenter36.AppImage，主版本升级后自动变成 mediacenter37.AppImage。
launcher="$(cat launcher-name)"
if [[ ! "$launcher" =~ ^mediacenter[0-9]+$ ]]; then
  echo "错误：无法从主程序名生成 AppImage 文件名：$launcher" >&2
  exit 1
fi
export OUTNAME="${launcher}.AppImage"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|${launcher}.AppImage.zsync"
export OPTIMIZE_LAUNCH=1
mkdir -p "$SCRIPT_DIR/dist"
printf '%s\n' "$OUTNAME" > "$SCRIPT_DIR/dist/release-name.txt"
# 删除改名前留下的旧资产；主版本变化时也删掉其它 mediacenterN.AppImage。
if [[ -n "${GH_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null; then
  gh release delete-asset latest jriver.AppImage --repo "$GITHUB_REPOSITORY" --yes >/dev/null 2>&1 || true
  while IFS= read -r old_asset; do
    [[ "$old_asset" == "$OUTNAME" ]] && continue
    gh release delete-asset latest "$old_asset" --repo "$GITHUB_REPOSITORY" --yes >/dev/null 2>&1 || true
  done < <(gh release view latest --repo "$GITHUB_REPOSITORY" --json assets --jq '.assets[].name' | grep -E '^mediacenter[0-9]+\.AppImage$' || true)
fi
cd "$SCRIPT_DIR"

# quick-sharun 只封装完整 RunImage，不重新收集 JRiver 的依赖。
quick-sharun --make-appimage
