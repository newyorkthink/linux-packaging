#!/usr/bin/env bash
# 完整程序和模块都打进 AppImage。启动时不再跑官方下载器。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
[[ "$(uname -m)" == x86_64 ]] || { echo '仅支持 x86_64。' >&2; exit 1; }

DOWNLOAD="$SCRIPT_DIR/../common/download/download_file.sh"
EXTRACT="$SCRIPT_DIR/../common/archive/extract_archive.sh"
WORKDIR="$SCRIPT_DIR/source"
APPDIR="$SCRIPT_DIR/AppDir"
APP_ROOT="$APPDIR/shared/bin"
HOST_DIR="$WORKDIR/host"
MODULES="$WORKDIR/modules"
OFFICIAL_ARCHIVE="$WORKDIR/discord-official.tar.gz"
OFFICIAL_DIR="$WORKDIR/official"

###### 准备 Arch 构建环境 ######

# 公共入口安装 quick-sharun 构建、下载、解析和封装所需的统一基础包。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# Discord 本体链接这些库；输入法、托盘和打开链接是额外要带走的。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  gtk3 nss alsa-lib systemd-libs wayland \
  libappindicator-gtk3 libpulse libnotify libxss cups \
  ibus fcitx5-gtk xdg-utils brotli

###### 清理并创建构建目录 ######

# 只清理 Discord 自己的临时目录和产物，避免旧文件混入本次 AppImage。
rm -rf -- "$WORKDIR" "$APPDIR" "$SCRIPT_DIR/dist"

# Discord 是非标准完整程序包，真实程序树固定放入 shared/bin 保持相邻资源布局。
mkdir -p "$HOST_DIR" "$MODULES" "$SCRIPT_DIR/dist" "$APP_ROOT"

###### 获取官方桌面资源 ######

# 从 Discord 官网稳定版 tar.gz 提取官方 desktop 和图标，不在仓库内手写桌面元数据。
"$DOWNLOAD" \
  'https://discord.com/api/download?platform=linux&format=tar.gz' \
  "$OFFICIAL_ARCHIVE"
"$EXTRACT" "$OFFICIAL_ARCHIVE" "$OFFICIAL_DIR"
OFFICIAL_DESKTOP="$OFFICIAL_DIR/Discord/discord.desktop"
OFFICIAL_ICON="$OFFICIAL_DIR/Discord/discord.png"
[[ -f "$OFFICIAL_DESKTOP" && -f "$OFFICIAL_ICON" ]] || {
  echo 'Discord 官方归档缺少 desktop 或图标。' >&2
  exit 1
}

###### 获取并核对官方完整主程序 ######

# 官方 stable manifest 同时提供主程序版本、下载地址和 SHA-256。
"$DOWNLOAD" \
  'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64' \
  "$WORKDIR/manifest.json"
VERSION="$(jq -er '.full.host_version | map(tostring) | join(".")' "$WORKDIR/manifest.json")"
HOST_URL="$(jq -er '.full.url' "$WORKDIR/manifest.json")"
HOST_SHA="$(jq -er '.full.package_sha256' "$WORKDIR/manifest.json")"

# 地址必须属于本次 stable 版本，禁止下载清单版本之外的主程序。
[[ "$HOST_URL" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/full.distro ]] || {
  echo "主程序地址与版本不一致：$HOST_URL" >&2
  exit 1
}

# 下载并校验完整主程序，再由公共归档入口解开 Brotli 压缩的 distro 包。
"$DOWNLOAD" "$HOST_URL" "$WORKDIR/host.distro" "$HOST_SHA"
"$EXTRACT" "$WORKDIR/host.distro" "$HOST_DIR"
[[ -x "$HOST_DIR/files/Discord" && -f "$HOST_DIR/files/resources/build_info.json" ]] || {
  echo '完整包缺少 Discord 或 build_info.json。' >&2
  exit 1
}

# 清单版本必须与完整包内的真实程序版本一致，否则停止发布。
ACTUAL_VERSION="$(jq -er '.version' "$HOST_DIR/files/resources/build_info.json")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || {
  echo "清单版本是 $VERSION，包内版本是 $ACTUAL_VERSION；停止发布。" >&2
  exit 1
}
echo "Discord 主程序版本：$ACTUAL_VERSION"

# 把已核对的完整程序树放入 AppImage 的真实应用目录。
cp -a "$HOST_DIR/files"/. "$APP_ROOT"/

###### 获取 Discord 官方模块 ######

# 逐个下载 manifest 声明的官方模块，并用对应 SHA-256 校验后解包。
while IFS=$'\t' read -r name url sha; do
  [[ "$url" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/${name}/*/full.distro ]] || {
    echo "模块地址不合法：$name $url" >&2
    exit 1
  }
  "$DOWNLOAD" "$url" "$WORKDIR/${name}.distro" "$sha"
  module_source="$WORKDIR/module-source/$name"
  "$EXTRACT" "$WORKDIR/${name}.distro" "$module_source"
  [[ -d "$module_source/files" ]] || {
    echo "模块缺少 files 目录：$name" >&2
    exit 1
  }
  mkdir -p "$MODULES/$name"
  cp -a "$module_source/files"/. "$MODULES/$name"/
done < <(jq -er '.modules | to_entries[] | [.key, .value.full.url, .value.full.package_sha256] | @tsv' "$WORKDIR/manifest.json")

# 桌面核心模块是 Discord 启动必需内容，缺失时禁止继续封装。
[[ -f "$MODULES/discord_desktop_core/index.js" && -f "$MODULES/discord_desktop_core/core.asar" ]] || {
  echo '缺少 discord_desktop_core。' >&2
  exit 1
}

# 生成 Discord 识别的已安装模块清单，并预建 Krisp 运行时日志目录。
jq -c '.modules | with_entries(.value = {installedVersion: .value.full.module_version})' \
  "$WORKDIR/manifest.json" > "$MODULES/installed.json"

# quick-sharun 以自带加载器运行 Discord，/proc/<pid>/exe 因而不是官方主程序；
# Krisp 会把这个加载器判为未签名。只把签名失败后的条件跳转替换成 NOP，
# 保留官方模块的其余内容，并在上游指令布局变化时明确停止构建。
KRISP_MODULE="$MODULES/discord_krisp/discord_krisp.node"
[[ -f "$KRISP_MODULE" ]] || { echo '缺少 discord_krisp.node。' >&2; exit 1; }
KRISP_OFFICIAL_SHA="$(sha256sum "$KRISP_MODULE" | awk '{print $1}')"
KRISP_INIT_SYMBOL="$(readelf -Ws --wide "$KRISP_MODULE" \
  | awk '$4 == "FUNC" && $8 ~ /DoKrispInitializeEv$/ && !found { print $8; found=1 }')"
KRISP_SIGN_SYMBOL="$(readelf -Ws --wide "$KRISP_MODULE" \
  | awk '$4 == "FUNC" && $8 ~ /IsSignedByDiscord/ && !found { print $8; found=1 }')"
[[ -n "$KRISP_INIT_SYMBOL" && -n "$KRISP_SIGN_SYMBOL" ]] || {
  echo '无法定位 Krisp 主程序签名检查函数。' >&2
  exit 1
}

KRISP_PATCH_RECORD="$(objdump -d --disassemble="$KRISP_INIT_SYMBOL" "$KRISP_MODULE" \
  | awk -v target="<$KRISP_SIGN_SYMBOL>" '
      index($0, target) { seen_call=1; next }
      seen_call && /test[[:space:]]+%al,%al/ { seen_test=1; next }
      seen_test && /je[[:space:]]/ && !found {
        address=$1
        sub(/:$/, "", address)
        bytes=""
        for (i=2; i<=NF && $i ~ /^[[:xdigit:]]{2}$/; i++) bytes=bytes $i
        print address, bytes
        found=1
      }
    ')"
read -r KRISP_PATCH_VADDR KRISP_PATCH_HEX <<< "$KRISP_PATCH_RECORD"
[[ "$KRISP_PATCH_HEX" == 74?? || "$KRISP_PATCH_HEX" == 0f84???????? ]] || {
  echo "Krisp 签名失败分支不是预期的 JE 指令：${KRISP_PATCH_HEX:-未找到}" >&2
  exit 1
}

read -r KRISP_TEXT_VADDR KRISP_TEXT_OFFSET <<< "$(
  objdump -h "$KRISP_MODULE" | awk '$2 == ".text" && !found { print $4, $6; found=1 }'
)"
[[ -n "$KRISP_TEXT_VADDR" && -n "$KRISP_TEXT_OFFSET" ]] || {
  echo '无法定位 discord_krisp.node 的 .text 段。' >&2
  exit 1
}
KRISP_PATCH_OFFSET=$((
  16#$KRISP_PATCH_VADDR - 16#$KRISP_TEXT_VADDR + 16#$KRISP_TEXT_OFFSET
))

python3 - "$KRISP_MODULE" "$KRISP_PATCH_OFFSET" "$KRISP_PATCH_HEX" <<'PY'
import pathlib
import sys

module = pathlib.Path(sys.argv[1])
offset = int(sys.argv[2])
expected = bytes.fromhex(sys.argv[3])
data = bytearray(module.read_bytes())
actual = bytes(data[offset:offset + len(expected)])
if actual != expected:
    raise SystemExit(
        f"Krisp 补丁位置内容变化：预期 {expected.hex()}，实际 {actual.hex()}"
    )
data[offset:offset + len(expected)] = b"\x90" * len(expected)
module.write_bytes(data)
PY

KRISP_PATCHED_SHA="$(sha256sum "$KRISP_MODULE" | awk '{print $1}')"
[[ "$KRISP_PATCHED_SHA" != "$KRISP_OFFICIAL_SHA" ]] || {
  echo 'Krisp 签名检查补丁没有改变模块。' >&2
  exit 1
}
# 同一 Discord 版本重新构建时，运行时 hook 也据此替换旧的未修复模块。
printf '%s\n' "$KRISP_PATCHED_SHA" \
  > "$MODULES/discord_krisp/.appimage-patch.sha256"
echo "Krisp 模块补丁：$KRISP_OFFICIAL_SHA -> $KRISP_PATCHED_SHA"

mkdir -p "$MODULES/discord_krisp/KMS/logs"

###### 构建 AppImage ######

export ARCH=x86_64 VERSION
export APPNAME=Discord MAIN_BIN=Discord STARTUPWMCLASS=discord
export ICON="$OFFICIAL_ICON" DESKTOP="$OFFICIAL_DESKTOP"
export OUTPATH="$SCRIPT_DIR/dist" OUTNAME=discord.AppImage
# Discord 已自带 Electron 图形运行库；不要让 quick-sharun 自动打入宿主 Mesa 驱动。
export DEPLOY_OPENGL=0 DEPLOY_VULKAN=0 NO_STRIP=1

# 收集真实主程序、Discord 自带的 Chromium 库、中文输入模块及动态加载的运行库。
LD_LIBRARY_PATH="$APP_ROOT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
quick-sharun "$APP_ROOT/Discord" \
  "$APP_ROOT/libffmpeg.so" "$APP_ROOT/libEGL.so" "$APP_ROOT/libGLESv2.so" \
  "$APP_ROOT/libvulkan.so.1" "$APP_ROOT/libvk_swiftshader.so" \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  /usr/lib/libappindicator3.so* \
  /usr/lib/libpulse.so* \
  /usr/lib/libnotify.so* \
  /usr/lib/libXss.so* \
  /usr/lib/libcups.so* \
  /usr/lib/libasound.so* \
  /usr/lib/libwayland-client.so*

# Krisp 会校验 Discord 主程序本身；恢复 quick-sharun 路径扫描前的官方原始文件。
cp -a -- "$HOST_DIR/files/Discord" "$APP_ROOT/Discord"

# 主程序必须与已校验的官方 full.distro 逐字节一致，禁止发布被路径替换改写的文件。
cmp -s "$HOST_DIR/files/Discord" "$APP_ROOT/Discord" || {
  echo '恢复后的 Discord 主程序与官方完整包不一致。' >&2
  exit 1
}

# 构建容器中 Mesa 可能被间接安装；动态库扫描仍会带入驱动及其 LLVM 依赖。
# 只从 Discord 的 AppDir 移除这组构建机驱动，保留官方 Electron 图形库。
find "$APPDIR/lib" -maxdepth 1 \( -name 'libgallium*.so*' -o -name 'libLLVM.so*' \
  -o -name 'libGLX_mesa.so*' \) -delete
# quick-sharun 已生成 lib.path；移除库后同步重建 sharun 的实际搜索清单。
"$APPDIR/sharun" -g

###### 配置 Discord 模块和运行环境 ######

# 把已校验并完成 Krisp 兼容处理的模块作为只读模板带入包内，启动时再同步到用户配置目录。
mkdir -p "$APPDIR/share/discord-modules"
cp -a "$MODULES"/. "$APPDIR/share/discord-modules"/

# 仅在包内模块版本变化时替换用户模块目录，避免 Discord 在只读挂载点写入失败。
cat > "$APPDIR/bin/stage-discord-modules.src.hook" <<EOF
#!/bin/false
mod_src="\${SHARUN_DIR}/share/discord-modules"
mod_dest="\${XDG_CONFIG_HOME:-\$HOME/.config}/discord/${VERSION}/modules"
if [ ! -f "\$mod_dest/installed.json" ] \\
  || ! cmp -s "\$mod_src/installed.json" "\$mod_dest/installed.json" \\
  || ! cmp -s "\$mod_src/discord_krisp/.appimage-patch.sha256" "\$mod_dest/discord_krisp/.appimage-patch.sha256"; then
  rm -rf "\$mod_dest"
  mkdir -p "\$mod_dest"
  cp -a "\$mod_src"/. "\$mod_dest"/
fi
mkdir -p "\$mod_dest/discord_krisp/KMS/logs"
EOF

# Electron 从 launcher 目录寻找 ICU、PAK、locales 和 resources；软链接保留唯一真实程序树。
for item in "$APP_ROOT"/*; do
  name="${item##*/}"
  [[ "$name" == Discord || -e "$APPDIR/bin/$name" || -L "$APPDIR/bin/$name" ]] && continue
  ln -s "../shared/bin/$name" "$APPDIR/bin/$name"
done

# 追加 shared/bin 的相邻库路径和固定工作目录，保留 quick-sharun 已生成的环境内容。
cat >> "$APPDIR/.env" <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/shared/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin
ENV

# 在包内生成中文 locale，不依赖用户系统是否预先生成 zh_CN.UTF-8。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/lib/locale/zh_CN.utf8"

# 设置中文界面环境；不覆盖用户会话选择的输入法实现。
cat >> "$APPDIR/.env" <<'LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
LOCALE

###### 生成并核对正式产物 ######

# 使用 quick-sharun 的默认入口生成最终 AppImage，不手写 AppRun。
quick-sharun --make-appimage

# 只有正式产物存在且非空时才写入本次实际构建版本。
[[ -s "$SCRIPT_DIR/dist/discord.AppImage" ]] || { echo 'Discord AppImage 未生成。' >&2; exit 1; }
printf '%s\n' "$VERSION" > "$SCRIPT_DIR/dist/version.txt"
