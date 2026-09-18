#!/usr/bin/env bash
# 同步腾讯官方 Linux QQ x86_64 AppImage。AUR linuxqq-appimage 只用来读取当前 CDN 地址和 SHA-256。
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

readonly AUR_PKGBUILD_URL='https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=linuxqq-appimage'
readonly SOURCE_DIR="${SCRIPT_DIR}/source"
readonly DIST_DIR="${SCRIPT_DIR}/dist"
readonly OFFICIAL_APPIMAGE="${SOURCE_DIR}/QQ-official.AppImage"
readonly OUTFILE="${DIST_DIR}/qq.AppImage"

rm -rf "${SOURCE_DIR}" "${DIST_DIR}"
mkdir -p "${SOURCE_DIR}" "${DIST_DIR}"

yay -S --noconfirm --needed curl jq coreutils ca-certificates
command -v curl >/dev/null 2>&1 || die "构建环境缺少命令：curl"
command -v jq >/dev/null 2>&1 || die "构建环境缺少命令：jq"
command -v sha256sum >/dev/null 2>&1 || die "构建环境缺少命令：sha256sum"

log "读取 AUR linuxqq-appimage 当前官方 x86_64 AppImage 元数据"
PKGBUILD="$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 "${AUR_PKGBUILD_URL}")"
[[ -n "${PKGBUILD}" ]] || die "无法获取 AUR linuxqq-appimage PKGBUILD。"

IMAGE_URL="$(
  awk -F= '
    $1 == "_image_url_x86_64" {
      url=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", url)
      gsub(/^"/, "", url)
      gsub(/"$/, "", url)
      print url
      exit
    }
  ' <<< "${PKGBUILD}"
)"
IMAGE_SHA256="$(
  awk -F= '
    $1 == "_image_sha256sums_x86_64" {
      sum=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", sum)
      gsub(/^"/, "", sum)
      gsub(/"$/, "", sum)
      print tolower(sum)
      exit
    }
  ' <<< "${PKGBUILD}"
)"
[[ "${IMAGE_URL}" =~ ^https://qqdl\.gtimg\.cn/qqfile/QQNTV2/.+_x86_64_01\.AppImage$ ]] || \
  die "AUR linuxqq-appimage 未给出有效的官方 x86_64 AppImage 地址：${IMAGE_URL}"
[[ "${IMAGE_SHA256}" =~ ^[0-9a-f]{64}$ ]] || \
  die "AUR linuxqq-appimage 未给出有效的 SHA-256：${IMAGE_SHA256}"

VERSION="$(
  awk -F= '
    $1 == "_version" {
      ver=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", ver)
      gsub(/^"/, "", ver)
      gsub(/"$/, "", ver)
      print ver
      exit
    }
  ' <<< "${PKGBUILD}"
)"
if [[ "${IMAGE_URL}" =~ QQ_([0-9]+\.[0-9]+\.[0-9]+)_([0-9]{6})_x86_64_01\.AppImage$ ]]; then
  VERSION="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
fi
[[ "${VERSION}" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]] || \
  die "无法从官方 AppImage 元数据解析有效版本：${VERSION}"

sign_download_url() {
  local unsigned_url="$1"
  local cookie signed
  cookie="$(mktemp)"
  curl -fsS --retry 5 --retry-all-errors --retry-delay 2 \
    -c "${cookie}" "https://im.qq.com" >/dev/null
  signed="$(
    curl -fsS --retry 5 --retry-all-errors --retry-delay 2 \
      --json "$(jq -nc --arg url "${unsigned_url}" '{url:$url}')" \
      -b "${cookie}" \
      -H 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' \
      "https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign" \
      | jq -r '.data.url // empty'
  )"
  rm -f -- "${cookie}"
  [[ "${signed}" == https://* ]] || die "无法获取官方 AppImage 签名下载地址。"
  printf '%s\n' "${signed}"
}

log "下载腾讯官方 x86_64 AppImage ${VERSION}"
DOWNLOAD_URL="$(sign_download_url "${IMAGE_URL}")"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "${DOWNLOAD_URL}" \
  -o "${OFFICIAL_APPIMAGE}"
[[ -s "${OFFICIAL_APPIMAGE}" ]] || die "官方下载文件为空。"

actual_sha256="$(sha256sum -- "${OFFICIAL_APPIMAGE}" | awk '{print tolower($1)}')"
[[ "${actual_sha256}" == "${IMAGE_SHA256}" ]] || \
  die "官方 AppImage SHA-256 与 AUR linuxqq-appimage 声明不一致。"

install -Dm0755 "${OFFICIAL_APPIMAGE}" "${OUTFILE}"
printf '%s\n' "${VERSION}" > ~/version
printf '%s\n' "${VERSION}" > "${DIST_DIR}/version.txt"
log "同步完成 ${VERSION}"
