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
readonly OUTFILE="$DIST_DIR/Gemini.AppImage"
readonly BUILD_DESKTOP="$WORK_DIR/Gemini.desktop"
readonly BUILD_ICON="$WORK_DIR/Gemini.png"

# 只清理本项目目录。cache 仅删除不重建，用来满足公共入口必须有一个 --skip-create 目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" \
  "$SCRIPT_DIR" --skip-create cache work AppDir dist
rm -f -- "$SCRIPT_DIR/gemini.desktop" "$SCRIPT_DIR/gemini.png" \
  "$SCRIPT_DIR/Gemini.desktop" "$SCRIPT_DIR/Gemini.png"
mkdir -p "$EXTRACT_DIR" "$ELECTRON_DIR" "$APP_ROOT"

# 基础包走公共入口。这里只补 Gemini 移植额外需要、且不在 --base 里的包。
# 7z、python3、nss、xdg-utils 已由 --base 提供。fcitx5-gtk 仍交给 quick-sharun 的 GTK3 部署去收集输入法模块。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  asar icoutils alsa-lib gtk3 cups libxss libxtst \
  libnotify libsecret libpulse mesa fcitx5-gtk

for command_name in \
  7z asar awk curl file find grep hostname jq python3 quick-sharun sha256sum sort strings unzip wrestool; do
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
# Omaha 现在可能下发压缩或未压缩安装包，文件名必须和 manifest 版本一致。
expected_names = (
    f'GeminiSetup-{version}.exe',
    f'GeminiSetup-{version}_uncompressed.exe',
)
if installer_name not in expected_names:
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
"$SCRIPT_DIR/../common/download/download_file.sh" \
  "$INSTALLER_URL" "$INSTALLER" "$INSTALLER_SHA256"
[[ "$(stat -c '%s' "$INSTALLER")" == "$INSTALLER_SIZE" ]] || \
  die "Gemini 安装包大小与 Omaha 元数据不一致。"
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

"$SCRIPT_DIR/../common/download/download_file.sh" \
  "$ELECTRON_BASE_URL/SHASUMS256.txt" "$ELECTRON_SUMS"
ELECTRON_SHA256="$(awk -v name="$ELECTRON_ZIP_NAME" '$2 == name || $2 == "*" name {print $1; exit}' "$ELECTRON_SUMS")"
[[ "$ELECTRON_SHA256" =~ ^[0-9a-fA-F]{64}$ ]] || \
  die "Electron 官方 SHASUMS256.txt 中缺少 $ELECTRON_ZIP_NAME。"

"$SCRIPT_DIR/../common/download/download_file.sh" \
  "$ELECTRON_BASE_URL/$ELECTRON_ZIP_NAME" "$ELECTRON_ZIP" "$ELECTRON_SHA256"
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

# Linux 专用补丁都在 patches/，这里只按顺序调用。上游结构变化时补丁自己失败，构建不猜测。
LINUX_ASAR="$APP_ROOT/resources/app.asar"
LINUX_ASAR_DIR="$WORK_DIR/app-asar-linux"
rm -rf "$LINUX_ASAR_DIR"
mkdir -p "$LINUX_ASAR_DIR"
asar extract "$LINUX_ASAR" "$LINUX_ASAR_DIR"

WINDOWS_NATIVE_ADDON_REMOVED="$(
  bash "$SCRIPT_DIR/patches/remove_windows_native_addon.sh" "$APP_ROOT" "$LINUX_ASAR_DIR"
)"
python3 "$SCRIPT_DIR/patches/disable_visible_on_all_workspaces.py" \
  "$LINUX_ASAR_DIR" "$WINDOWS_NATIVE_ADDON_REMOVED"

# 官方图标要放进 resources，供窗口补丁在运行时读取。不放进 asar。
ICO_DIR="$WORK_DIR/ico"
mkdir -p "$ICO_DIR"
wrestool -x -t14 -o "$ICO_DIR" "$WINDOWS_EXE"
ICON_ICO="$(find "$ICO_DIR" -type f -name '*.ico' -print | sort -V | head -n 1)"
[[ -f "$ICON_ICO" ]] || die "无法从 Gemini.exe 提取官方 ICO 图标。"
python3 "$SCRIPT_DIR/patches/extract_ico_png.py" "$ICON_ICO" "$BUILD_ICON"
[[ -s "$BUILD_ICON" ]] || die "Gemini 官方 ICO 中没有可用 PNG 图标。"
install -m 644 "$BUILD_ICON" "$APP_ROOT/resources/gemini.png"
python3 "$SCRIPT_DIR/patches/set_linux_window_icon.py" "$LINUX_ASAR_DIR"

rm -f "$LINUX_ASAR"
asar pack "$LINUX_ASAR_DIR" "$LINUX_ASAR"

install -m 755 "$SCRIPT_DIR/patches/Gemini" "$APP_ROOT/Gemini"
chmod +x "$APP_ROOT/electron"

###### 生成 desktop ######

[[ -s "$BUILD_ICON" ]] || die "Gemini 官方图标还没有提取。"

cat > "$BUILD_DESKTOP" <<EOF_DESKTOP
[Desktop Entry]
Name=Gemini
Comment=Google Gemini desktop app
Exec=Gemini %U
Icon=Gemini
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=gemini
X-AppImage-Version=$VERSION
EOF_DESKTOP

###### quick-sharun 封装 ######

export APPNAME=Gemini
export STARTUPWMCLASS=gemini
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=Gemini.AppImage
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

# 记录当前上游版本，供构建成功后自动增量更新软件版本清单。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  "$OUTFILE" "$VERSION" "$DIST_DIR/version.txt"

log "构建完成：$OUTFILE"
