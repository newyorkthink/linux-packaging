#!/usr/bin/env bash
# 从 OpenAI 官方 ChatGPT Linux x64 deb 重新封装 AnyLinux AppImage。
# 官方包同时包含 ChatGPT、Codex、Code Mode Host、插件和 Computer Use 运行组件；
# 本脚本完整保留官方应用目录，只补齐 AppImage 所需运行库和便携启动入口。
set -Eeuo pipefail

export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd "$SCRIPT_DIR"

log() {
  printf '[ChatGPT] %s\n' "$*"
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

HOST_ARCH="$(uname -m)"
readonly HOST_ARCH
[[ "$HOST_ARCH" == x86_64 ]] || die "当前仅支持 x86_64。"
command -v yay >/dev/null 2>&1 || die "构建环境缺少命令：yay"

readonly OFFICIAL_REPO_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb"
readonly PACKAGES_URL="$OFFICIAL_REPO_URL/dists/stable/main/binary-amd64/Packages"
readonly SOURCE_DIR="$SCRIPT_DIR/source"
readonly PACKAGES_FILE="$SOURCE_DIR/Packages"
readonly DEB_FILE="$SOURCE_DIR/chatgpt-official-amd64.deb"
readonly PACKAGE_ROOT="$SOURCE_DIR/package"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly APP_ROOT="$APPDIR/bin"
readonly DIST_DIR="$SCRIPT_DIR/dist"
readonly OUTFILE="$DIST_DIR/chatgpt.AppImage"
readonly VERIFY_DIR="$SCRIPT_DIR/verify"
readonly BUILD_DESKTOP="$SCRIPT_DIR/chatgpt.desktop"
readonly BUILD_ICON="$SCRIPT_DIR/chatgpt.png"
readonly SMOKE_HOME="$SCRIPT_DIR/smoke-home"
readonly SMOKE_RUNTIME="$SCRIPT_DIR/smoke-runtime"
readonly SMOKE_LOG="$SCRIPT_DIR/chatgpt-smoke.log"

# 每次只清理 ChatGPT 自己的构建目录、临时元数据和旧产物。
rm -rf \
  "$SOURCE_DIR" \
  "$APPDIR" \
  "$DIST_DIR" \
  "$VERIFY_DIR" \
  "$SMOKE_HOME" \
  "$SMOKE_RUNTIME"
rm -f "$BUILD_DESKTOP" "$BUILD_ICON" "$SMOKE_LOG"
mkdir -p "$SOURCE_DIR" "$PACKAGE_ROOT" "$APP_ROOT" "$DIST_DIR"

# 安装官方 deb 提取、Electron/Chromium 依赖部署、输入法和隔离图形启动测试所需组件。
yay -S --noconfirm --needed \
  base-devel binutils coreutils curl file findutils gawk grep inetutils patchelf sed tar xz zstd \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb \
  nss nspr gtk3 at-spi2-core cups dbus glib2 pango cairo expat fontconfig freetype2 \
  libx11 libxext libxi libxtst libxss libxrandr libxcomposite libxdamage libxfixes \
  libxkbcommon libxkbfile libxcb libdrm mesa libglvnd libva libvdpau wayland \
  alsa-lib libpulse pipewire pipewire-audio \
  libnotify libsecret libusb systemd-libs libcap shared-mime-info xdg-utils \
  hicolor-icon-theme adwaita-icon-theme ibus noto-fonts-cjk python

for command_name in \
  ar awk chmod cp curl dbus-run-session desktop-file-validate dirname file find grep hostname \
  install ldd quick-sharun readelf readlink sed sha256sum sort stat tar timeout xvfb-run \
  xdg-mime xdg-open xdg-settings python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    die "构建环境缺少命令：$command_name"
done

log "读取 OpenAI 官方 stable amd64 软件包元数据"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 120 \
  "$PACKAGES_URL" \
  -o "$PACKAGES_FILE"
[[ -s "$PACKAGES_FILE" ]] || die "OpenAI Packages 元数据为空。"

mapfile -t package_meta < <(
  python3 - "$PACKAGES_FILE" <<'PY'
import re
import sys


def parse_stanza(raw: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    current = ""
    for line in raw.splitlines():
        if line.startswith((" ", "\t")) and current:
            fields[current] += "\n" + line[1:]
            continue
        if ":" not in line:
            continue
        current, value = line.split(":", 1)
        fields[current] = value.strip()
    return fields


with open(sys.argv[1], "r", encoding="utf-8") as fh:
    stanzas = [parse_stanza(raw) for raw in re.split(r"\n\s*\n", fh.read().strip())]

matches = [
    stanza
    for stanza in stanzas
    if stanza.get("Package") == "chatgpt" and stanza.get("Architecture") == "amd64"
]
if len(matches) != 1:
    raise SystemExit(f"应当且只能解析到一个 chatgpt/amd64 软件包，实际为 {len(matches)}。")

package = matches[0]
version = package.get("Version", "")
filename = package.get("Filename", "")
size = package.get("Size", "")
sha256 = package.get("SHA256", "")

if not re.fullmatch(r"[0-9][0-9A-Za-z.+:~_-]*", version):
    raise SystemExit(f"无效的 ChatGPT 版本：{version}")
expected_filename = rf"pool/main/c/chatgpt/chatgpt_{re.escape(version)}_amd64\.deb"
if not re.fullmatch(expected_filename, filename):
    raise SystemExit(f"无效的 ChatGPT 软件包路径：{filename}")
if not re.fullmatch(r"[1-9][0-9]*", size):
    raise SystemExit(f"无效的软件包大小：{size}")
if not re.fullmatch(r"[0-9a-f]{64}", sha256):
    raise SystemExit("OpenAI Packages 元数据缺少有效 SHA-256。")

print(version)
print(filename)
print(size)
print(sha256)
PY
)
[[ ${#package_meta[@]} -eq 4 ]] || die "无法完整解析 OpenAI ChatGPT 软件包元数据。"

readonly VERSION="${package_meta[0]}"
readonly PACKAGE_FILENAME="${package_meta[1]}"
readonly PACKAGE_SIZE="${package_meta[2]}"
readonly PACKAGE_SHA256="${package_meta[3]}"
readonly DEB_URL="$OFFICIAL_REPO_URL/$PACKAGE_FILENAME"
[[ "$DEB_URL" == "$OFFICIAL_REPO_URL"/pool/main/c/chatgpt/chatgpt_*_amd64.deb ]] || \
  die "解析出的官方下载地址不符合预期：$DEB_URL"

printf 'ChatGPT version: %s\nChatGPT deb: %s\n' "$VERSION" "$DEB_URL"

log "下载 OpenAI 官方 ChatGPT x64 deb"
curl -fL \
  --retry 5 \
  --retry-all-errors \
  --retry-delay 2 \
  --connect-timeout 20 \
  --max-time 1800 \
  "$DEB_URL" \
  -o "$DEB_FILE"
[[ -s "$DEB_FILE" ]] || die "OpenAI 官方 deb 下载为空。"
file "$DEB_FILE" | grep -q 'Debian binary package' || \
  die "OpenAI 官方下载文件不是 Debian 软件包。"
[[ "$(stat -c '%s' "$DEB_FILE")" == "$PACKAGE_SIZE" ]] || \
  die "OpenAI 官方 deb 文件大小与 Packages 元数据不一致。"
printf '%s  %s\n' "$PACKAGE_SHA256" "$DEB_FILE" | sha256sum -c -

log "提取 OpenAI 官方 deb"
(
  cd "$SOURCE_DIR"
  ar x "$DEB_FILE"
)

shopt -s nullglob
control_archives=("$SOURCE_DIR"/control.tar.*)
data_archives=("$SOURCE_DIR"/data.tar.*)
shopt -u nullglob
[[ ${#control_archives[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能有一个 control.tar.*。"
[[ ${#data_archives[@]} -eq 1 ]] || \
  die "官方 deb 中应且只能有一个 data.tar.*。"

CONTROL_ENTRY="$(
  tar -tf "${control_archives[0]}" \
    | awk '$0 == "./control" || $0 == "control" {print; exit}'
)"
[[ -n "$CONTROL_ENTRY" ]] || die "官方 deb 的 control archive 缺少 control 文件。"
mapfile -t control_meta < <(
  tar -xOf "${control_archives[0]}" "$CONTROL_ENTRY" \
    | awk '
        $1 == "Package:" {package = $2}
        $1 == "Version:" {version = $2}
        $1 == "Architecture:" {architecture = $2}
        END {print package; print version; print architecture}
      '
)
[[ ${#control_meta[@]} -eq 3 ]] || die "无法解析官方 deb control 元数据。"
[[ "${control_meta[0]}" == chatgpt ]] || die "官方 deb 包名不是 chatgpt。"
[[ "${control_meta[1]}" == "$VERSION" ]] || die "官方 deb 版本与 Packages 元数据不一致。"
[[ "${control_meta[2]}" == amd64 ]] || die "官方 deb 架构不是 amd64。"

tar -xf "${data_archives[0]}" -C "$PACKAGE_ROOT"

readonly SOURCE_APP_ROOT="$PACKAGE_ROOT/usr/lib/chatgpt"
readonly SOURCE_MAIN="$SOURCE_APP_ROOT/ChatGPT"
readonly SOURCE_ASAR="$SOURCE_APP_ROOT/resources/app.asar"
readonly SOURCE_CODEX="$SOURCE_APP_ROOT/resources/codex"
readonly SOURCE_CODE_MODE_HOST="$SOURCE_APP_ROOT/resources/codex-code-mode-host"
readonly SOURCE_CUA_NODE="$SOURCE_APP_ROOT/resources/cua_node/bin/node"
readonly SOURCE_METADATA="$SOURCE_APP_ROOT/resources/linux-package-metadata.json"
readonly SOURCE_DESKTOP="$PACKAGE_ROOT/usr/share/applications/chatgpt.desktop"
readonly SOURCE_ICON="$PACKAGE_ROOT/usr/share/pixmaps/chatgpt.png"
readonly SOURCE_COPYRIGHT="$PACKAGE_ROOT/usr/share/doc/chatgpt/copyright"

[[ -x "$SOURCE_MAIN" ]] || die "官方 deb 缺少 ChatGPT 主程序。"
[[ -f "$SOURCE_ASAR" ]] || die "官方 deb 缺少 resources/app.asar。"
[[ -x "$SOURCE_CODEX" ]] || die "官方 deb 缺少 Codex 主程序。"
[[ -x "$SOURCE_CODE_MODE_HOST" ]] || die "官方 deb 缺少 Code Mode Host。"
[[ -x "$SOURCE_CUA_NODE" ]] || die "官方 deb 缺少 Computer Use Node 运行时。"
[[ -f "$SOURCE_METADATA" ]] || die "官方 deb 缺少 Linux 包元数据。"
[[ -f "$SOURCE_DESKTOP" ]] || die "官方 deb 缺少 chatgpt.desktop。"
[[ -f "$SOURCE_ICON" ]] || die "官方 deb 缺少 chatgpt.png。"
[[ -f "$SOURCE_COPYRIGHT" ]] || die "官方 deb 缺少 copyright 文件。"

file "$SOURCE_MAIN" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "ChatGPT 主程序不是 x86_64 ELF。"
file "$SOURCE_CODEX" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "Codex 主程序不是 x86_64 ELF。"
file "$SOURCE_CODE_MODE_HOST" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "Code Mode Host 不是 x86_64 ELF。"
file "$SOURCE_CUA_NODE" | grep -q 'ELF 64-bit LSB.*x86-64' || \
  die "Computer Use Node 运行时不是 x86_64 ELF。"
file "$SOURCE_ICON" | grep -q 'PNG image data' || die "官方 ChatGPT 图标不是 PNG。"

python3 - "$SOURCE_METADATA" "$VERSION" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    metadata = json.load(fh)

if metadata.get("codexAppBrand") != "chatgpt":
    raise SystemExit("官方 Linux 包品牌不是 chatgpt。")
if metadata.get("codexBuildFlavor") != "prod":
    raise SystemExit("官方 Linux 包不是 prod 构建。")
if metadata.get("version") != sys.argv[2]:
    raise SystemExit("官方 Linux 包内部版本与 Packages 元数据不一致。")
PY

# 在隔离目录中确认官方主程序能加载，并且自身报告的版本与仓库元数据一致。
readonly VERSION_CHECK_HOME="$SOURCE_DIR/version-check-home"
mkdir -p "$VERSION_CHECK_HOME"
REPORTED_VERSION="$(
  HOME="$VERSION_CHECK_HOME" \
  XDG_CONFIG_HOME="$VERSION_CHECK_HOME/.config" \
  XDG_CACHE_HOME="$VERSION_CHECK_HOME/.cache" \
  timeout 20s "$SOURCE_MAIN" \
    --no-sandbox \
    --disable-setuid-sandbox \
    --version
)"
readonly REPORTED_VERSION
[[ "$REPORTED_VERSION" == "$VERSION" ]] || \
  die "ChatGPT 主程序报告版本与 Packages 元数据不一致：$REPORTED_VERSION / $VERSION"

readonly SOURCE_ASAR_SHA256="$(sha256sum "$SOURCE_ASAR" | awk '{print $1}')"
readonly SOURCE_CODEX_SHA256="$(sha256sum "$SOURCE_CODEX" | awk '{print $1}')"
readonly SOURCE_CODE_MODE_HOST_SHA256="$(sha256sum "$SOURCE_CODE_MODE_HOST" | awk '{print $1}')"

# 保持 OpenAI 官方完整运行目录的相对布局，避免遗漏 Codex、插件或 Computer Use 资源。
cp -a "$SOURCE_APP_ROOT"/. "$APP_ROOT"/
install -Dm0644 "$SOURCE_COPYRIGHT" "$APPDIR/share/doc/chatgpt/copyright"

# Electron 登录和外部链接会调用 xdg-utils；将官方依赖声明中的便携脚本放入 AppImage PATH。
install -Dm0755 /usr/bin/xdg-open "$APP_ROOT/xdg-open"
install -Dm0755 /usr/bin/xdg-mime "$APP_ROOT/xdg-mime"
install -Dm0755 /usr/bin/xdg-settings "$APP_ROOT/xdg-settings"

# Node 原生模块供 Electron/Node dlopen，不需要执行位；避免被 quick-sharun 当作独立程序包装。
find "$APP_ROOT" -type f -name '*.node' -exec chmod 0644 {} +

mapfile -d '' source_node_modules < <(
  find "$APP_ROOT" -type f -name '*.node' -print0
)
[[ ${#source_node_modules[@]} -gt 0 ]] || die "官方 ChatGPT 运行目录缺少 Node 原生模块。"
printf 'ChatGPT Node native modules: %s\n' "${#source_node_modules[@]}"

# 使用 OpenAI 官方 desktop 和图标生成 AppImage 桌面集成文件。
install -Dm0644 "$SOURCE_DESKTOP" "$BUILD_DESKTOP"
install -Dm0644 "$SOURCE_ICON" "$BUILD_ICON"
[[ "$(grep -c '^Exec=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Exec 字段数量异常。"
[[ "$(grep -c '^Icon=' "$BUILD_DESKTOP")" -eq 1 ]] || \
  die "官方 desktop 的 Icon 字段数量异常。"
sed -i \
  -e 's|^Exec=.*|Exec=ChatGPT --no-sandbox --disable-setuid-sandbox %U|' \
  -e 's|^Icon=.*|Icon=chatgpt|' \
  "$BUILD_DESKTOP"
if grep -q '^StartupWMClass=' "$BUILD_DESKTOP"; then
  sed -i 's|^StartupWMClass=.*|StartupWMClass=ChatGPT|' "$BUILD_DESKTOP"
else
  printf 'StartupWMClass=ChatGPT\n' >> "$BUILD_DESKTOP"
fi
if grep -q '^X-AppImage-Version=' "$BUILD_DESKTOP"; then
  sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$VERSION|" "$BUILD_DESKTOP"
else
  printf 'X-AppImage-Version=%s\n' "$VERSION" >> "$BUILD_DESKTOP"
fi
desktop-file-validate "$BUILD_DESKTOP"

# 官方 deb 会按宿主 AppArmor 版本安装或启用针对固定程序路径的 userns 规则；
# AppImage 不写入 /etc，也没有可用的 setuid sandbox，因此便携入口只禁用 Chromium sandbox。
# OpenAI 官方 Codex 二进制及其内置 Linux 命令沙箱保持原样，不做资源或授权修改。
cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e

export PATH="$APPDIR/bin${PATH:+:$PATH}"
export SHARUN_EXTRA_LIBRARY_PATH="$APPDIR/bin${SHARUN_EXTRA_LIBRARY_PATH:+:$SHARUN_EXTRA_LIBRARY_PATH}"
export SHARUN_WORKING_DIR="$APPDIR/bin"

cd "$APPDIR/bin"
exec "$APPDIR/bin/ChatGPT" --no-sandbox --disable-setuid-sandbox "$@"
APPRUN_EOF
chmod 0755 "$APPDIR/AppRun.sh"
bash -n "$APPDIR/AppRun.sh"

export ARCH=x86_64
export VERSION
export APPNAME=ChatGPT
export MAIN_BIN=ChatGPT
export STARTUPWMCLASS=ChatGPT
export ICON="$BUILD_ICON"
export DESKTOP="$BUILD_DESKTOP"
export OUTPATH="$DIST_DIR"
export OUTNAME=chatgpt.AppImage
export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export STRACE_MODE=0
export NO_STRIP=1

# 收集官方目录中的 x86_64 glibc 动态 ELF；静态 Codex 组件保持原文件，
# 跨架构、musl 预构建模块和可选 Qt shim 只作为官方资源保留，不交给 glibc 依赖部署。
dynamic_elf_targets=()
source_linux_node_relative_paths=()
while IFS= read -r -d '' target; do
  machine="$(
    readelf -h "$target" 2>/dev/null \
      | awk -F: '/Machine:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' \
      || true
  )"
  [[ "$machine" == 'Advanced Micro Devices X86-64' ]] || continue

  relative_path="${target#"$APP_ROOT"/}"
  case "$relative_path" in
    libqt5_shim.so|libqt6_shim.so|*musl*|*/prebuilds/android-*|*/prebuilds/darwin-*|*/prebuilds/win32-*)
      continue
      ;;
  esac

  readelf -d "$target" 2>/dev/null | grep -q '(NEEDED)' || continue
  dynamic_elf_targets+=("$target")
  if [[ "$relative_path" == *.node ]]; then
    source_linux_node_relative_paths+=("$relative_path")
  fi
done < <(find "$APP_ROOT" -type f -print0)

[[ ${#dynamic_elf_targets[@]} -gt 0 ]] || die "官方 ChatGPT 目录中未找到动态 x86_64 ELF。"
[[ ${#source_linux_node_relative_paths[@]} -gt 0 ]] || \
  die "官方 ChatGPT 目录中未找到 glibc x86_64 Node 原生模块。"
printf 'ChatGPT dynamic x86_64 ELF files: %s\n' "${#dynamic_elf_targets[@]}"

main_target_found=false
for target in "${dynamic_elf_targets[@]}"; do
  if [[ "$target" -ef "$APP_ROOT/ChatGPT" ]]; then
    main_target_found=true
    break
  fi
done
[[ "$main_target_found" == true ]] || die "动态 ELF 列表缺少 ChatGPT 主程序。"

# 仅将动态 ELF 所在的官方私有目录加入构建期搜索路径。完整资源树接近千个目录，
# 全部拼接会超过 Linux 单个环境字符串上限；动态 ELF 目录已覆盖实际可加载库。
mapfile -t app_library_dirs < <(
  for target in "${dynamic_elf_targets[@]}"; do
    dirname -- "$target"
  done | sort -u
)
[[ ${#app_library_dirs[@]} -gt 0 ]] || die "官方 ChatGPT 运行目录为空。"
BUILD_LIBRARY_PATH="$(IFS=:; printf '%s' "${app_library_dirs[*]}")"
BUILD_LIBRARY_PATH="$BUILD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
[[ ${#BUILD_LIBRARY_PATH} -lt 65536 ]] || \
  die "官方 ChatGPT 动态库搜索路径异常过长：${#BUILD_LIBRARY_PATH} 字节。"
printf 'ChatGPT private library directories: %s (%s bytes)\n' \
  "${#app_library_dirs[@]}" "${#BUILD_LIBRARY_PATH}"

missing_dependencies=0
for target in "${dynamic_elf_targets[@]}"; do
  target_library_path="$(dirname -- "$target"):$BUILD_LIBRARY_PATH"
  target_dependencies="$(LD_LIBRARY_PATH="$target_library_path" ldd "$target" 2>&1 || true)"
  if grep -Fq 'not found' <<< "$target_dependencies"; then
    printf '缺失依赖文件：%s\n%s\n' "$target" "$target_dependencies" >&2
    missing_dependencies=1
  fi
done
[[ "$missing_dependencies" -eq 0 ]] || die "官方 ChatGPT glibc 组件仍存在缺失动态库。"

# 显式部署 Electron/Chromium 通过 dlopen 使用的音频、通知、密钥环、USB 和 udev 运行库。
runtime_targets=(
  /usr/bin/gio
  /usr/bin/hostname
  /usr/lib/libasound.so.2
  /usr/lib/libpulse.so.0
  /usr/lib/libpulse-simple.so.0
  /usr/lib/libpipewire-0.3.so.0
  /usr/lib/libnotify.so.4
  /usr/lib/libsecret-1.so.0
  /usr/lib/libusb-1.0.so.0
  /usr/lib/libudev.so.1
  /usr/lib/libsoftokn3.so
  /usr/lib/libfreeblpriv3.so
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
)
for runtime_target in "${runtime_targets[@]}"; do
  [[ -e "$runtime_target" ]] || die "构建环境缺少运行项：$runtime_target"
done

shopt -s nullglob
pulse_common_targets=(/usr/lib/pulseaudio/libpulsecommon-*.so)
nss_targets=(/usr/lib/libnss*.so*)
pkcs11_targets=(/usr/lib/pkcs11/*)
shopt -u nullglob
[[ ${#pulse_common_targets[@]} -gt 0 ]] || die "构建环境缺少 libpulsecommon。"
[[ ${#nss_targets[@]} -gt 0 ]] || die "构建环境缺少 NSS 模块。"
[[ ${#pkcs11_targets[@]} -gt 0 ]] || die "构建环境缺少 PKCS#11 模块。"

LD_LIBRARY_PATH="$BUILD_LIBRARY_PATH" quick-sharun \
  "${dynamic_elf_targets[@]}" \
  "${runtime_targets[@]}" \
  "${pulse_common_targets[@]}" \
  "${nss_targets[@]}" \
  "${pkcs11_targets[@]}"

quick-sharun --make-appimage
[[ -s "$OUTFILE" ]] || die "未生成预期文件：$OUTFILE"
chmod 0755 "$OUTFILE"

# 解包最终 AppImage，确认官方 Codex/插件资源和关键运行库都进入实际发布产物。
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
readonly VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
readonly VERIFY_APP_ROOT="$VERIFY_APPDIR/bin"
[[ -x "$VERIFY_APPDIR/AppRun" ]] || die "最终 AppImage 缺少 AppRun。"
[[ -f "$VERIFY_APPDIR/chatgpt.desktop" ]] || die "最终 AppImage 缺少 chatgpt.desktop。"
[[ -f "$VERIFY_APPDIR/chatgpt.png" ]] || die "最终 AppImage 缺少 chatgpt.png。"
[[ -f "$VERIFY_APP_ROOT/resources/app.asar" ]] || die "最终 AppImage 缺少 app.asar。"
[[ -x "$VERIFY_APP_ROOT/resources/codex" ]] || die "最终 AppImage 缺少 Codex。"
[[ -x "$VERIFY_APP_ROOT/resources/codex-code-mode-host" ]] || \
  die "最终 AppImage 缺少 Code Mode Host。"
[[ -x "$VERIFY_APP_ROOT/resources/cua_node/bin/node" ]] || \
  die "最终 AppImage 缺少 Computer Use Node 运行时。"
[[ -f "$VERIFY_APPDIR/share/doc/chatgpt/copyright" ]] || \
  die "最终 AppImage 缺少官方 copyright 文件。"
[[ ! -e "$VERIFY_APPDIR/etc/apparmor.d/chatgpt" ]] || \
  die "最终 AppImage 不应携带需要写入宿主 /etc 的 AppArmor 配置。"

[[ "$(sha256sum "$VERIFY_APP_ROOT/resources/app.asar" | awk '{print $1}')" == "$SOURCE_ASAR_SHA256" ]] || \
  die "最终 AppImage 中的 OpenAI app.asar 与官方包不一致。"
[[ "$(sha256sum "$VERIFY_APP_ROOT/resources/codex" | awk '{print $1}')" == "$SOURCE_CODEX_SHA256" ]] || \
  die "最终 AppImage 中的 Codex 二进制与官方包不一致。"
[[ "$(sha256sum "$VERIFY_APP_ROOT/resources/codex-code-mode-host" | awk '{print $1}')" == "$SOURCE_CODE_MODE_HOST_SHA256" ]] || \
  die "最终 AppImage 中的 Code Mode Host 与官方包不一致。"

for node_relative_path in "${source_linux_node_relative_paths[@]}"; do
  node_module="$VERIFY_APP_ROOT/$node_relative_path"
  [[ -f "$node_module" ]] || die "最终 AppImage 缺少 Node 原生模块：$node_relative_path"
  readelf -h "$node_module" >/dev/null 2>&1 || \
    die "最终 AppImage 中的 Node 原生模块不是 ELF：$node_relative_path"
  [[ ! "$node_module" -ef "$VERIFY_APPDIR/AppRun" ]] || \
    die "最终 AppImage 中的 Node 原生模块被错误替换成 sharun：$node_relative_path"
done

verify_bundled_library() {
  local library_pattern="$1"
  local library_label="$2"
  local library_path

  library_path="$(
    # quick-sharun 的 DwarFS uruntime 会把 squashfs-root 提取为指向 AppDir 的入口链接。
    find -H "$VERIFY_APPDIR" \
      -type f \
      -name "$library_pattern" \
      -print \
      -quit
  )"
  [[ -n "$library_path" ]] || die "最终 AppImage 缺少 $library_label 的实际库文件。"
}

verify_bundled_library 'libgtk-3.so.*' libgtk-3
verify_bundled_library 'libnss3.so' libnss3
verify_bundled_library 'libasound.so.*' libasound
verify_bundled_library 'libpulse.so.*' libpulse
verify_bundled_library 'libpipewire-0.3.so.*' libpipewire
verify_bundled_library 'libnotify.so.*' libnotify
verify_bundled_library 'libsecret-1.so.*' libsecret
verify_bundled_library 'libusb-1.0.so.*' libusb
verify_bundled_library 'libudev.so.*' libudev

# 在隔离 HOME、XDG 目录、D-Bus 会话和虚拟 X11 中直接启动最终 AppImage。
mkdir -p \
  "$SMOKE_HOME/.config" \
  "$SMOKE_HOME/.cache" \
  "$SMOKE_HOME/.local/share" \
  "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"
set +e
HOME="$SMOKE_HOME" \
XDG_CONFIG_HOME="$SMOKE_HOME/.config" \
XDG_CACHE_HOME="$SMOKE_HOME/.cache" \
XDG_DATA_HOME="$SMOKE_HOME/.local/share" \
XDG_RUNTIME_DIR="$SMOKE_RUNTIME" \
APPIMAGE_EXTRACT_AND_RUN=1 \
timeout 40s xvfb-run -a dbus-run-session -- \
  "$OUTFILE" \
  --disable-gpu \
  --user-data-dir="$SMOKE_HOME/profile" \
  >"$SMOKE_LOG" 2>&1
smoke_rc=$?
set -e

tail -n 250 "$SMOKE_LOG"
printf 'ChatGPT smoke test exit code: %s\n' "$smoke_rc"
if grep -Eqi \
  'error while loading shared libraries|cannot open shared object file|invalid ELF header|wrong ELF class|Exec format error|No usable sandbox|Running as root without --no-sandbox|Trace/breakpoint trap|Segmentation fault' \
  "$SMOKE_LOG"; then
  die "ChatGPT 冒烟测试检测到致命运行错误。"
fi
if [[ "$smoke_rc" -eq 124 ]]; then
  if grep -Ei 'FATAL:' "$SMOKE_LOG" \
    | grep -Evqi 'FATAL:electron/shell/browser/electron_browser_main_parts\.cc:[0-9]+\] Failed to shutdown\.$'; then
    die "ChatGPT 冒烟测试检测到致命运行错误。"
  fi
else
  tail -n 250 "$SMOKE_LOG" >&2 || true
  die "ChatGPT 在 Xvfb 冒烟测试中提前退出：$smoke_rc"
fi

sha256sum "$OUTFILE" > "$OUTFILE.sha256"
log "构建完成：$OUTFILE"
