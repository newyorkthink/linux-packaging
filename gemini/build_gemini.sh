#!/usr/bin/env bash
# 将 Google 官方 Gemini Windows x64 Electron 产品层移植到对应 Linux x64 Electron runtime，并封装为 AppImage。
set -Eeuo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[Gemini] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly OMAHA_URL='https://update.googleapis.com/service/update2'
readonly GEMINI_APP_ID='{533dd80c-942a-4464-b6a9-2e59428d784e}'
readonly WORK_DIR="$SCRIPT_DIR/work"
readonly OMAHA_RESPONSE="$WORK_DIR/omaha-response.xml"
readonly INSTALLER="$WORK_DIR/GeminiSetup.exe"
readonly EXTRACT_DIR="$WORK_DIR/windows"
readonly ELECTRON_DIR="$WORK_DIR/electron"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/gemini.AppImage"
readonly BUILD_DESKTOP="$SCRIPT_DIR/gemini.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/gemini.png"

# 每次只清理 Gemini 自己的构建目录、临时元数据和旧产物。
rm -rf -- "$WORK_DIR" "$APPDIR" "$DIST_DIR"
rm -f -- "$BUILD_DESKTOP" "$BUILD_ICON"
mkdir -p "$WORK_DIR" "$EXTRACT_DIR" "$ELECTRON_DIR" "$APP_ROOT" "$DIST_DIR"

# 安装仓库规定的 quick-sharun 最小基础工具。
yay -S --noconfirm base-devel git wget curl jq binutils patchelf file coreutils findutils \
  grep sed gawk tar gzip xz unzip rsync util-linux appstream-glib \
  desktop-file-utils zsync ca-certificates

# Gemini 当前上游只提供 Windows/macOS 桌面包；这里额外安装 NSIS 解包、ASAR 元数据读取、
# Windows 图标提取以及官方 Electron Linux runtime 实际依赖所需组件。
yay -S --noconfirm p7zip asar icoutils python \
  nss alsa-lib gtk3 at-spi2-core cups libdrm libxss libxtst \
  libnotify libsecret libpulse mesa xdg-utils

for command_name in \
  7z asar awk curl file find grep jq python3 quick-sharun sha256sum sort strings unzip wrestool; do
  command -v "$command_name" >/dev/null 2>&1 || die "构建环境缺少命令：$command_name"
done

###### 动态解析 Google 官方稳定版 ######

log "查询 Google Omaha 当前 Gemini Windows x64 正式版"
cat > "$WORK_DIR/request.xml" <<EOF_REQUEST
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" arch="x64" />
  <app appid="$GEMINI_APP_ID" version="" ap="prod">
    <updatecheck />
  </app>
</request>
EOF_REQUEST

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 120 \
  -H 'Content-Type: application/xml' \
  --data-binary "@$WORK_DIR/request.xml" \
  "$OMAHA_URL" \
  -o "$OMAHA_RESPONSE"
[[ -s "$OMAHA_RESPONSE" ]] || die "Google Omaha 返回为空。"

mapfile -t omaha_meta < <(
  python3 - "$OMAHA_RESPONSE" <<'PY'
import base64
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET


def local_name(tag: str) -> str:
    return tag.rsplit('}', 1)[-1]


def children(root, name: str):
    return [node for node in root.iter() if local_name(node.tag) == name]


root = ET.parse(sys.argv[1]).getroot()
apps = children(root, 'app')
if len(apps) != 1:
    raise SystemExit(f'expected one app in Omaha response, got {len(apps)}')

updatechecks = [node for node in apps[0].iter() if local_name(node.tag) == 'updatecheck']
if len(updatechecks) != 1:
    raise SystemExit(f'expected one updatecheck, got {len(updatechecks)}')
updatecheck = updatechecks[0]
if updatecheck.get('status') not in (None, 'ok'):
    raise SystemExit(f"Omaha updatecheck status is {updatecheck.get('status')!r}")

manifests = [node for node in updatecheck.iter() if local_name(node.tag) == 'manifest']
if len(manifests) != 1:
    raise SystemExit(f'expected one manifest, got {len(manifests)}')
manifest = manifests[0]
version = manifest.get('version', '')
if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){2,3}', version):
    raise SystemExit(f'invalid Gemini version: {version!r}')

urls = [
    node.get('codebase', '')
    for node in updatecheck.iter()
    if local_name(node.tag) == 'url' and node.get('codebase', '').startswith('https://dl.google.com/')
]
if len(urls) != 1:
    raise SystemExit(f'expected one dl.google.com codebase, got {len(urls)}')

actions = [
    node for node in manifest.iter()
    if local_name(node.tag) == 'action' and node.get('event') == 'install'
]
if len(actions) != 1 or not actions[0].get('run'):
    raise SystemExit('Omaha response does not contain exactly one install action')
installer_name = actions[0].get('run', '')
if not re.fullmatch(r'GeminiSetup-[0-9]+(?:\.[0-9]+){2,3}\.exe', installer_name):
    raise SystemExit(f'unexpected Gemini installer name: {installer_name!r}')

packages = [node for node in manifest.iter() if local_name(node.tag) == 'package']
matching = [node for node in packages if node.get('name') in ('', installer_name)]
package = matching[0] if len(matching) == 1 else (packages[0] if len(packages) == 1 else None)
if package is None:
    raise SystemExit(f'could not resolve installer package metadata from {len(packages)} package entries')

size = package.get('size', '')
if not re.fullmatch(r'[1-9][0-9]*', size):
    raise SystemExit(f'invalid Gemini installer size: {size!r}')

hash_value = package.get('hash_sha256', '').strip()
if re.fullmatch(r'[0-9A-Fa-f]{64}', hash_value):
    sha256 = hash_value.lower()
else:
    try:
        padded = hash_value + '=' * (-len(hash_value) % 4)
        digest = base64.urlsafe_b64decode(padded)
    except Exception as exc:
        raise SystemExit(f'invalid Omaha hash_sha256: {exc}') from exc
    if len(digest) != 32:
        raise SystemExit(f'Omaha hash_sha256 decoded to {len(digest)} bytes instead of 32')
    sha256 = digest.hex()

installer_url = urllib.parse.urljoin(urls[0], installer_name)
parsed = urllib.parse.urlparse(installer_url)
if parsed.scheme != 'https' or parsed.hostname != 'dl.google.com':
    raise SystemExit(f'unexpected installer host: {installer_url}')
if not urllib.parse.unquote(parsed.path).startswith('/release2/Google DeepMind/'):
    raise SystemExit(f'unexpected installer path: {installer_url}')

print(version)
print(installer_url)
print(size)
print(sha256)
PY
)
[[ ${#omaha_meta[@]} -eq 4 ]] || die "无法完整解析 Google Omaha Gemini 元数据。"

readonly VERSION="${omaha_meta[0]}"
readonly INSTALLER_URL="${omaha_meta[1]}"
readonly INSTALLER_SIZE="${omaha_meta[2]}"
readonly INSTALLER_SHA256="${omaha_meta[3]}"

log "Gemini version: $VERSION"
log "下载 Google 官方 Gemini Windows x64 完整安装包"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$INSTALLER_URL" \
  -o "$INSTALLER"
[[ -s "$INSTALLER" ]] || die "Gemini 官方安装包下载为空。"
[[ "$(stat -c '%s' "$INSTALLER")" == "$INSTALLER_SIZE" ]] || \
  die "Gemini 安装包大小与 Omaha 元数据不一致。"
printf '%s  %s\n' "$INSTALLER_SHA256" "$INSTALLER" | sha256sum -c -
file "$INSTALLER" | grep -Eq 'PE32.*Windows' || die "Google 下载文件不是 Windows PE 安装包。"

###### 提取 Windows Electron 产品层 ######

log "解包 Gemini NSIS 安装包"
7z x -y -o"$EXTRACT_DIR" "$INSTALLER" >/dev/null

mapfile -t app_asars < <(find "$EXTRACT_DIR" -type f -path '*/resources/app.asar' -print | sort)
[[ ${#app_asars[@]} -eq 1 ]] || \
  die "NSIS 解包后应且只能找到一个 resources/app.asar，实际为 ${#app_asars[@]}。"

readonly WINDOWS_ASAR="${app_asars[0]}"
readonly WINDOWS_RESOURCES="$(dirname "$WINDOWS_ASAR")"
readonly WINDOWS_APP_ROOT="$(dirname "$WINDOWS_RESOURCES")"
readonly WINDOWS_EXE="$WINDOWS_APP_ROOT/Gemini.exe"
[[ -f "$WINDOWS_EXE" ]] || die "未找到与 app.asar 对应的 Gemini.exe。"

# 原生 Node 模块无法从 Windows PE 直接搬到 Linux；发现 Windows .node 时立即停止，避免发布已知无效产物。
mapfile -t windows_node_modules < <(
  find "$WINDOWS_RESOURCES" -type f -name '*.node' -print0 \
    | while IFS= read -r -d '' node_file; do
        if file -b "$node_file" | grep -q '^PE32'; then
          printf '%s\n' "$node_file"
        fi
      done
)
if (( ${#windows_node_modules[@]} > 0 )); then
  printf '发现 Windows 原生 Node 模块，当前不能直接移植到 Linux：\n' >&2
  printf '  %s\n' "${windows_node_modules[@]}" >&2
  exit 1
fi

# 优先从 Gemini.exe 内嵌的 Electron 标识读取精确版本；若上游隐藏该字符串，再从 app.asar 的 package.json 元数据读取。
ELECTRON_VERSION="$(
  {
    strings -a "$WINDOWS_EXE" 2>/dev/null || true
    strings -el "$WINDOWS_EXE" 2>/dev/null || true
  } \
    | grep -Eo 'Electron[/ ]v?[0-9]+\.[0-9]+\.[0-9]+' \
    | sed -E 's#Electron[/ ]v?##' \
    | sort -Vu \
    | tail -n 1 \
    || true
)"

if [[ -z "$ELECTRON_VERSION" ]]; then
  ASAR_META_DIR="$WORK_DIR/asar-meta"
  PACKAGE_JSON="$ASAR_META_DIR/package.json"
  mkdir -p "$ASAR_META_DIR"
  if (cd "$ASAR_META_DIR" && asar extract-file "$WINDOWS_ASAR" package.json >/dev/null 2>&1) \
     && jq -e . "$PACKAGE_JSON" >/dev/null 2>&1; then
    ELECTRON_VERSION="$(
      python3 - "$PACKAGE_JSON" <<'PY'
import json
import re
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    data = json.load(fh)

candidates = []
for key in ('electronVersion',):
    value = data.get('build', {}).get(key) if isinstance(data.get('build'), dict) else None
    if isinstance(value, str):
        candidates.append(value)
for section in ('dependencies', 'devDependencies', 'optionalDependencies'):
    values = data.get(section)
    if isinstance(values, dict) and isinstance(values.get('electron'), str):
        candidates.append(values['electron'])

for value in candidates:
    match = re.search(r'([0-9]+\.[0-9]+\.[0-9]+)', value)
    if match:
        print(match.group(1))
        break
PY
    )"
  fi
fi

# 若 package.json 也未暴露 Electron 版本，则用 Gemini.exe 内嵌的 Chromium 精确版本映射 Electron 官方发布元数据。
if [[ -z "$ELECTRON_VERSION" ]]; then
  CHROME_VERSION="$(
    {
      strings -a "$WINDOWS_EXE" 2>/dev/null || true
      strings -el "$WINDOWS_EXE" 2>/dev/null || true
    } \
      | grep -Eo 'Chrome/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
      | sed 's#Chrome/##' \
      | sort -Vu \
      | tail -n 1 \
      || true
  )"
  if [[ "$CHROME_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ELECTRON_RELEASES="$WORK_DIR/electron-releases.json"
    curl -fL --retry 5 --retry-all-errors \
      https://releases.electronjs.org/releases.json \
      -o "$ELECTRON_RELEASES"
    ELECTRON_VERSION="$(
      python3 - "$ELECTRON_RELEASES" "$CHROME_VERSION" <<'PY'
import json
import re
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    releases = json.load(fh)
chrome = sys.argv[2]
versions = []
for release in releases:
    version = release.get('version', '')
    if release.get('chrome') == chrome and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        versions.append(version)
if versions:
    versions.sort(key=lambda item: tuple(int(part) for part in item.split('.')))
    print(versions[-1])
PY
    )"
  fi
fi

[[ "$ELECTRON_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
  die "无法从当前 Gemini 正式包确定 Electron 精确版本，停止以避免使用不匹配 runtime。"
log "Electron runtime: $ELECTRON_VERSION"

###### 下载同版本官方 Linux Electron runtime ######

readonly ELECTRON_TAG="v$ELECTRON_VERSION"
readonly ELECTRON_ZIP_NAME="electron-v${ELECTRON_VERSION}-linux-x64.zip"
readonly ELECTRON_BASE_URL="https://github.com/electron/electron/releases/download/$ELECTRON_TAG"
readonly ELECTRON_ZIP="$WORK_DIR/$ELECTRON_ZIP_NAME"
readonly ELECTRON_SUMS="$WORK_DIR/SHASUMS256.txt"

curl -fL --retry 5 --retry-all-errors "$ELECTRON_BASE_URL/SHASUMS256.txt" -o "$ELECTRON_SUMS"
ELECTRON_SHA256="$(awk -v name="$ELECTRON_ZIP_NAME" '$2 == name || $2 == "*" name {print $1; exit}' "$ELECTRON_SUMS")"
[[ "$ELECTRON_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || \
  die "Electron 官方 SHASUMS256.txt 中缺少 $ELECTRON_ZIP_NAME。"

curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$ELECTRON_BASE_URL/$ELECTRON_ZIP_NAME" \
  -o "$ELECTRON_ZIP"
printf '%s  %s\n' "$ELECTRON_SHA256" "$ELECTRON_ZIP" | sha256sum -c -
unzip -q "$ELECTRON_ZIP" -d "$ELECTRON_DIR"
[[ -x "$ELECTRON_DIR/electron" ]] || die "Electron Linux x64 runtime 缺少主程序。"

###### 组装 Linux 产品层 ######

cp -a "$ELECTRON_DIR"/. "$APP_ROOT/"
rm -f "$APP_ROOT/chrome-sandbox"
rm -rf "$APP_ROOT/resources"
mkdir -p "$APP_ROOT/resources"
cp -a "$WINDOWS_RESOURCES"/. "$APP_ROOT/resources/"

# Windows 更新器和 launcher 不是 Linux Electron 产品层的一部分，不随 AppImage 分发。
find "$APP_ROOT/resources" -type f \( -iname '*.exe' -o -iname '*.dll' \) -delete

cat > "$APP_ROOT/gemini" <<'EOF_WRAPPER'
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/electron" "$@"
EOF_WRAPPER
chmod +x "$APP_ROOT/gemini" "$APP_ROOT/electron"

###### 提取官方应用图标并生成 desktop ######

ICO_DIR="$WORK_DIR/ico"
mkdir -p "$ICO_DIR"
wrestool -x -t14 -o "$ICO_DIR" "$WINDOWS_EXE"
ICON_ICO="$(find "$ICO_DIR" -type f -name '*.ico' -print | sort -V | head -n 1)"
[[ -f "$ICON_ICO" ]] || die "无法从 Gemini.exe 提取官方 ICO 图标。"

# Gemini.exe 当前 ICO 资源包含一个 DIB 条目，其声明 bitmap 大小与实际数据存在差异；
# icotool 会因此终止整个图标提取。直接解析 ICO 目录，只取官方内嵌的最大 PNG 帧，
# 不修改图像内容，也不依赖有问题的 DIB 条目。
python3 - "$ICON_ICO" "$BUILD_ICON" <<'PY'
import struct
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
data = source.read_bytes()

if len(data) < 6:
    raise SystemExit("Gemini ICO header is truncated")

reserved, icon_type, count = struct.unpack_from("<HHH", data, 0)
if reserved != 0 or icon_type != 1 or count < 1:
    raise SystemExit("Gemini ICO header is invalid")

png_signature = b"\x89PNG\r\n\x1a\n"
candidates = []

for index in range(count):
    entry_offset = 6 + index * 16
    if entry_offset + 16 > len(data):
        continue

    bytes_in_resource, image_offset = struct.unpack_from("<II", data, entry_offset + 8)
    image_end = image_offset + bytes_in_resource
    if bytes_in_resource < 24 or image_offset < 0 or image_end > len(data):
        continue

    payload = data[image_offset:image_end]
    if not payload.startswith(png_signature) or payload[12:16] != b"IHDR":
        continue

    width, height = struct.unpack_from(">II", payload, 16)
    if width < 1 or height < 1:
        continue

    candidates.append((width * height, width, height, bytes_in_resource, index, payload))

if not candidates:
    raise SystemExit("Gemini ICO does not contain a usable embedded PNG frame")

_, width, height, _, index, payload = max(candidates)
target.write_bytes(payload)
print(f"Selected official Gemini ICO PNG frame #{index}: {width}x{height}")
PY

[[ -s "$BUILD_ICON" ]] || die "Gemini 官方 ICO 中没有可用 PNG 图标。"

cat > "$BUILD_DESKTOP" <<EOF_DESKTOP
[Desktop Entry]
Name=Gemini
Comment=Google Gemini desktop app
Exec=gemini %U
Icon=gemini
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=Gemini
X-AppImage-Version=$VERSION
EOF_DESKTOP

echo "$VERSION" > ~/version

###### quick-sharun 封装 ######

export APPNAME=Gemini
export STARTUPWMCLASS=Gemini
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=gemini.AppImage
export NO_STRIP=1

# 保留完整 Electron 相邻资源，只让 quick-sharun 收集其 ELF/系统动态依赖并生成 AppImage 入口。
quick-sharun \
  "$APP_ROOT"/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/*

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
log "构建完成：$OUTFILE"
