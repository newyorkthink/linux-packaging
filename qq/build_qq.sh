#!/usr/bin/env bash
# 从腾讯官方 Linux QQ x86_64 DEB 重新封装 AnyLinux AppImage。
# AUR linuxqq 只用来动态读取当前官方 DEB 地址和 SHA512，不作为二进制来源。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[QQ] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "${HOST_ARCH}" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly AUR_SRCINFO_URL='https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=linuxqq'
readonly SOURCE_DIR="${SCRIPT_DIR}/source"
readonly PACKAGE_ROOT="${SOURCE_DIR}/package"
readonly DEB_FILE="${SOURCE_DIR}/linuxqq_amd64.deb"
readonly APPDIR="${SCRIPT_DIR}/AppDir"
readonly APP_ROOT="${APPDIR}/bin"
readonly DIST_DIR="${SCRIPT_DIR}/dist"
readonly OUTFILE="${DIST_DIR}/qq.AppImage"
readonly BUILD_DESKTOP="${SCRIPT_DIR}/qq.desktop"
readonly BUILD_ICON="${SCRIPT_DIR}/qq.png"

rm -rf "${SOURCE_DIR}" "${APPDIR}" "${DIST_DIR}"
rm -f "${BUILD_DESKTOP}" "${BUILD_ICON}"
mkdir -p "${SOURCE_DIR}" "${PACKAGE_ROOT}" "${APP_ROOT}" "${DIST_DIR}"

# 安装 quick-sharun 最小基础工具。
yay -S --noconfirm --needed \
  base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# 安装 Linux QQ 官方 DEB 声明的运行依赖，供 ldd / quick-sharun 解析外部库。
yay -S --noconfirm --needed \
  nss alsa-lib gtk3 gjs at-spi2-core openjpeg2 openslide \
  libappindicator-gtk3 libnotify libsecret libxss libxtst \
  nspr cups dbus glib2 pango cairo fontconfig freetype2 \
  libx11 libxext libxi libxrender libxrandr libxcomposite libxdamage libxfixes \
  libxcb libxkbcommon libxkbcommon-x11 mesa libglvnd

for command_name in \
  ar awk chmod curl desktop-file-validate file find grep install ldd \
  quick-sharun readelf readlink sed sha512sum sort stat tar; do
  command -v "${command_name}" >/dev/null 2>&1 || \
    die "构建环境缺少命令：${command_name}"
done

#######################################################################
# 1. 动态读取 AUR linuxqq 当前官方 DEB 地址并下载
#######################################################################

log "读取 AUR linuxqq 当前官方 x86_64 DEB 元数据"
SRCINFO="$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 "${AUR_SRCINFO_URL}")"
[[ -n "${SRCINFO}" ]] || die "无法获取 AUR linuxqq .SRCINFO。"

DEB_URL="$(
  awk '
    $1 == "source_x86_64" && $2 == "=" {
      print $3
      exit
    }
  ' <<< "${SRCINFO}"
)"
DEB_SHA512="$(
  awk '
    $1 == "sha512sums_x86_64" && $2 == "=" {
      print $3
      exit
    }
  ' <<< "${SRCINFO}"
)"
[[ "${DEB_URL}" =~ ^https://qqdl\.gtimg\.cn/qqfile/QQNT/.+_amd64\.deb$ ]] || \
  die "AUR linuxqq 未给出有效的官方 amd64 DEB 地址：${DEB_URL}"
[[ "${DEB_SHA512}" =~ ^[0-9a-f]{128}$ ]] || \
  die "AUR linuxqq 未给出有效的 SHA512：${DEB_SHA512}"

log "下载腾讯官方 x86_64 DEB"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  "${DEB_URL}" \
  -o "${DEB_FILE}"
[[ -s "${DEB_FILE}" ]] || die "官方下载文件为空。"
file "${DEB_FILE}" | grep -q 'Debian binary package' || \
  die "官方下载文件不是 Debian 软件包。"

actual_sha512="$(sha512sum -- "${DEB_FILE}" | awk '{print $1}')"
[[ "${actual_sha512}" == "${DEB_SHA512}" ]] || \
  die "官方 DEB SHA512 与 AUR linuxqq 声明不一致。"

#######################################################################
# 2. 提取官方 DEB 并解析版本
#######################################################################

log "提取官方 DEB"
(
  cd "${SOURCE_DIR}"
  ar x "${DEB_FILE}"
)

shopt -s nullglob
control_archives=("${SOURCE_DIR}"/control.tar.*)
data_archives=("${SOURCE_DIR}"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || die "官方 deb 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || die "官方 deb 中应且只能有一个 data.tar.*。"

VERSION="$(
  tar -xOf "${control_archives[0]}" ./control \
    | awk '$1 == "Version:" {print $2; exit}'
)"
[[ "${VERSION}" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]] || \
  die "无法从官方 deb 解析有效版本：${VERSION}"
log "QQ version: ${VERSION}"

tar -xf "${data_archives[0]}" -C "${PACKAGE_ROOT}"
readonly SOURCE_APP_ROOT="${PACKAGE_ROOT}/opt/QQ"
[[ -x "${SOURCE_APP_ROOT}/qq" ]] || die "官方 deb 缺少可执行主程序 /opt/QQ/qq。"
file "${SOURCE_APP_ROOT}/qq" | grep -q 'ELF 64-bit' || \
  die "官方 QQ 主程序不是 64 位 ELF。"

mapfile -d '' desktop_candidates < <(
  find "${PACKAGE_ROOT}/usr/share/applications" \
    -maxdepth 1 \
    -type f \
    -iname '*qq*.desktop' \
    -print0
)
[[ ${#desktop_candidates[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能找到一个 QQ desktop 文件，实际为 ${#desktop_candidates[@]}。"
readonly SOURCE_DESKTOP="${desktop_candidates[0]}"

mapfile -d '' icon_candidates < <(
  find "${PACKAGE_ROOT}/usr/share/icons" \
    -type f \
    \( -iname 'qq.png' -o -iname 'linuxqq.png' \) \
    -print0
)
[[ ${#icon_candidates[@]} -gt 0 ]] || die "官方 deb 中未找到 qq.png。"

SOURCE_ICON="${icon_candidates[0]}"
source_icon_size="$(stat -c '%s' "${SOURCE_ICON}")"
for icon_candidate in "${icon_candidates[@]:1}"; do
  icon_size="$(stat -c '%s' "${icon_candidate}")"
  if (( icon_size > source_icon_size )); then
    SOURCE_ICON="${icon_candidate}"
    source_icon_size="${icon_size}"
  fi
done
readonly SOURCE_ICON
file "${SOURCE_ICON}" | grep -q 'PNG image data' || die "找到的 QQ 图标不是 PNG。"

#######################################################################
# 3. 保持官方 /opt/QQ 相对布局并做已知兼容处理
#######################################################################

log "复制官方运行目录"
cp -a "${SOURCE_APP_ROOT}"/. "${APP_ROOT}"/

# AUR linuxqq 会删除官方包自带的 libssh2，避免与系统库冲突。
find "${APP_ROOT}" -type f -name 'libssh2.so.1' -delete

# AppImage 无法保留 chrome-sandbox 的 setuid，启动时改走 --no-sandbox。
if [[ -e "${APP_ROOT}/chrome-sandbox" ]]; then
  chmod 0755 "${APP_ROOT}/chrome-sandbox"
fi

find "${APP_ROOT}" -type f -name '*.node' -exec chmod 0644 {} +

install -Dm0644 "${SOURCE_DESKTOP}" "${BUILD_DESKTOP}"
install -Dm0644 "${SOURCE_ICON}" "${BUILD_ICON}"
[[ "$(grep -c '^Exec=' "${BUILD_DESKTOP}")" -eq 1 ]] || \
  die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "${BUILD_DESKTOP}")" -eq 1 ]] || \
  die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=qq %U|' \
  -e 's|^Icon=.*|Icon=qq|' \
  "${BUILD_DESKTOP}"
if ! grep -q '^StartupWMClass=' "${BUILD_DESKTOP}"; then
  printf 'StartupWMClass=QQ\n' >> "${BUILD_DESKTOP}"
fi
if ! grep -q '^X-AppImage-Version=' "${BUILD_DESKTOP}"; then
  printf 'X-AppImage-Version=%s\n' "${VERSION}" >> "${BUILD_DESKTOP}"
fi
desktop-file-validate "${BUILD_DESKTOP}"

# 入口固定从包内程序目录启动；Electron 在 AppImage 中需要 --no-sandbox。
cat > "${APPDIR}/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"

cd "$APPDIR/bin"
exec "$APPDIR/bin/qq" --no-sandbox "$@"
APPRUN_EOF
chmod 0755 "${APPDIR}/AppRun.sh"
bash -n "${APPDIR}/AppRun.sh"

printf '%s\n' "${VERSION}" > ~/version

export ARCH=x86_64
export VERSION
export APPNAME=QQ
export MAIN_BIN=qq
export STARTUPWMCLASS=QQ
export ICON="${BUILD_ICON}"
export DESKTOP="${BUILD_DESKTOP}"
export OUTPATH="${DIST_DIR}"
export OUTNAME=qq.AppImage
export DEPLOY_GTK=1

log "使用 quick-sharun 收集主程序外部库"
LD_LIBRARY_PATH="${APP_ROOT}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" quick-sharun \
  "${APP_ROOT}/qq"

quick-sharun --make-appimage
[[ -s "${OUTFILE}" ]] || die "未生成预期文件：${OUTFILE}"
chmod 0755 "${OUTFILE}"

printf '%s\n' "${VERSION}" > "${DIST_DIR}/version.txt"
log "更新完成 ${VERSION}"
