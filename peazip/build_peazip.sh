#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

###### 准备构建环境 ######

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64，检测到：$HOST_ARCH"

readonly WORK_DIR="$SCRIPT_DIR/.work"
readonly AR_DIR="$WORK_DIR/ar"
readonly PACKAGE_ROOT="$WORK_DIR/package"
readonly CONTROL_ROOT="$WORK_DIR/control"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/shared/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/peazip.AppImage"

# 只清理 PeaZip 当前应用目录内的构建文件和旧产物。
rm -rf "$WORK_DIR" "$APPDIR" "$DIST_DIR"
mkdir -p "$AR_DIR" "$PACKAGE_ROOT" "$CONTROL_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装 quick-sharun / AppImage 打包所需的最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# PeaZip 官方 DEB 使用 zstd；Qt6 和 Fcitx5 插件必须与主程序保持同一 Qt 主版本。
yay -S --noconfirm zstd qt6-base fcitx5-qt libx11

###### 下载并校验官方最新稳定版 ######

readonly RELEASE_API='https://api.github.com/repos/peazip/PeaZip/releases/latest'
readonly RELEASE_JSON="$WORK_DIR/latest-release.json"

api_headers=(
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28'
)
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers+=( -H "Authorization: Bearer $GH_TOKEN" )
fi

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 120 \
  "${api_headers[@]}" \
  "$RELEASE_API" \
  -o "$RELEASE_JSON"

jq -e '.draft == false and .prerelease == false' "$RELEASE_JSON" >/dev/null
VERSION="$(jq -er '.tag_name | strings | select(length > 0)' "$RELEASE_JSON")"
readonly VERSION
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+){2}$ ]] || die "PeaZip Release tag 格式异常：$VERSION"

ASSET_NAME="peazip_${VERSION}.LINUX.Qt6-1_amd64.deb"
readonly ASSET_NAME
mapfile -t asset_rows < <(
  jq -r --arg name "$ASSET_NAME" \
    '.assets[] | select(.name == $name) | [.browser_download_url, (.digest // "")] | @tsv' \
    "$RELEASE_JSON"
)
[[ ${#asset_rows[@]} -eq 1 ]] || die "官方 Release 中应且只能有一个 $ASSET_NAME。"

IFS=$'\t' read -r ASSET_URL ASSET_DIGEST <<< "${asset_rows[0]}"
readonly ASSET_URL ASSET_DIGEST
readonly EXPECTED_URL="https://github.com/peazip/PeaZip/releases/download/${VERSION}/${ASSET_NAME}"
[[ "$ASSET_URL" == "$EXPECTED_URL" ]] || die "PeaZip Release 资产 URL 不符合预期：$ASSET_URL"
[[ "$ASSET_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]] || die "官方 Release 缺少有效的 SHA-256 digest。"

readonly DEB_FILE="$WORK_DIR/$ASSET_NAME"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 600 \
  "$ASSET_URL" \
  -o "$DEB_FILE"

[[ -s "$DEB_FILE" ]] || die "PeaZip 官方 DEB 下载结果为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || die "下载文件不是 Debian 软件包。"

EXPECTED_SHA256="${ASSET_DIGEST#sha256:}"
EXPECTED_SHA256="${EXPECTED_SHA256,,}"
ACTUAL_SHA256="$(sha256sum "$DEB_FILE" | awk '{print $1}')"
readonly EXPECTED_SHA256 ACTUAL_SHA256
[[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] || die "PeaZip 官方 DEB SHA-256 校验失败。"
printf 'PeaZip version: %s\nPeaZip DEB SHA-256: %s\n' "$VERSION" "$ACTUAL_SHA256"

###### 解包并核对官方 DEB ######

(
  cd "$AR_DIR"
  ar x "$DEB_FILE"
)

shopt -s nullglob
control_archives=("$AR_DIR"/control.tar.*)
data_archives=("$AR_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || die "官方 DEB 中应且只能有一个 data.tar.*。"

tar -xf "${control_archives[0]}" -C "$CONTROL_ROOT"
tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

readonly CONTROL_FILE="$CONTROL_ROOT/control"
[[ -f "$CONTROL_FILE" ]] || die "官方 DEB 缺少 control 元数据。"
PACKAGE_NAME="$(awk -F': ' '$1 == "Package" {print $2; exit}' "$CONTROL_FILE")"
PACKAGE_VERSION="$(awk -F': ' '$1 == "Version" {print $2; exit}' "$CONTROL_FILE")"
PACKAGE_ARCH="$(awk -F': ' '$1 == "Architecture" {print $2; exit}' "$CONTROL_FILE")"
readonly PACKAGE_NAME PACKAGE_VERSION PACKAGE_ARCH
[[ "$PACKAGE_NAME" == peazip ]] || die "官方 DEB 包名异常：$PACKAGE_NAME"
[[ "$PACKAGE_VERSION" == "$VERSION" ]] || die "Release tag 与 DEB 版本不一致：$VERSION / $PACKAGE_VERSION"
[[ "$PACKAGE_ARCH" == amd64 ]] || die "官方 DEB 架构不是 amd64：$PACKAGE_ARCH"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/usr/lib/peazip"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/peazip"
readonly SOURCE_HELPER="$SOURCE_APP_ROOT/pea"
readonly SOURCE_BACKENDS="$SOURCE_APP_ROOT/res/bin"
readonly SOURCE_SHARE="$PACKAGE_ROOT/usr/share/peazip"
readonly SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/peazip.desktop"
readonly SOURCE_ICON="$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps/peazip.png"
readonly SOURCE_COPYRIGHT="$PACKAGE_ROOT/usr/share/doc/peazip/copyright"

[[ -x "$SOURCE_MAIN" ]] || die "官方 DEB 缺少 PeaZip 主程序。"
[[ -x "$SOURCE_HELPER" ]] || die "官方 DEB 缺少 pea 辅助程序。"
[[ -d "$SOURCE_BACKENDS" ]] || die "官方 DEB 缺少归档后端目录。"
[[ -d "$SOURCE_SHARE" ]] || die "官方 DEB 缺少 PeaZip 资源目录。"
[[ -f "$SOURCE_DESKTOP" ]] || die "官方 DEB 缺少 desktop 文件。"
[[ -f "$SOURCE_ICON" ]] || die "官方 DEB 缺少 256x256 PNG 图标。"
[[ -f "$SOURCE_COPYRIGHT" ]] || die "官方 DEB 缺少版权说明。"
file "$SOURCE_MAIN" | grep -q 'ELF 64-bit.*x86-64' || die "PeaZip 主程序不是 x86_64 ELF。"

###### 准备 AppDir ######

# 完整保留官方 /usr/lib/peazip 程序目录和 /usr/share/peazip 资源目录。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
mkdir -p "$APPDIR/share/peazip" "$APPDIR/share/licenses/peazip"
cp -a "$SOURCE_SHARE"/. "$APPDIR/share/peazip"/
cp -a "$SOURCE_COPYRIGHT" "$APPDIR/share/licenses/peazip/copyright"

# 官方 DEB 的绝对链接只适用于系统安装；AppImage 内改为等价相对链接。
[[ -L "$APP_ROOT/res/share" ]] || die "官方 PeaZip 资源入口不是预期的符号链接。"
[[ "$(readlink "$APP_ROOT/res/share")" == /usr/share/peazip ]] || \
  die "官方 PeaZip 资源链接目标发生变化。"
ln -sfn ../../../share/peazip "$APP_ROOT/res/share"

# 保留官方 desktop action 使用的主图标、添加图标和解压图标。
if [[ -d "$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps" ]]; then
  mkdir -p "$APPDIR/share/icons/hicolor/256x256/apps"
  cp -a "$PACKAGE_ROOT/usr/share/icons/hicolor/256x256/apps"/peazip*.png \
    "$APPDIR/share/icons/hicolor/256x256/apps"/
fi

desktop-file-validate "$SOURCE_DESKTOP"

###### 核心打包 ######

export ARCH=x86_64
export APPNAME=PeaZip
export MAIN_BIN=peazip
export ICON="$SOURCE_ICON"
export DESKTOP="$SOURCE_DESKTOP"
export OUTPATH="$DIST_DIR"
OUTNAME="$(basename "$OUTFILE")"
export OUTNAME
export DEPLOY_QT=1
export NO_STRIP=1

# 主程序和 pea helper 都链接上游随包 libQt6Pas；64 位后端作为真实运行依赖一并交给 quick-sharun。
deploy_targets=("$APP_ROOT/peazip" "$APP_ROOT/pea")
while IFS= read -r -d '' backend; do
  if file "$backend" | grep -q 'ELF 64-bit' && \
     readelf -d "$backend" 2>/dev/null | grep -q '(NEEDED)'; then
    deploy_targets+=("$backend")
  fi
done < <(find "$APP_ROOT/res/bin" -type f -print0 | sort -z)

LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  quick-sharun "${deploy_targets[@]}"
quick-sharun --make-appimage

###### 整理产物 ######

[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
printf '%s\n' "$VERSION" > "$DIST_DIR/version.txt"
sha256sum "$OUTFILE"
printf '已生成：%s（PeaZip %s）\n' "$OUTFILE" "$VERSION"
