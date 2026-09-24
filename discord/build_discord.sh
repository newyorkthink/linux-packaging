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
  gtk3 nss alsa-lib mesa systemd-libs wayland \
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
mkdir -p "$MODULES/discord_krisp/KMS/logs"

###### 构建 AppImage ######

export ARCH=x86_64 VERSION
export APPNAME=Discord MAIN_BIN=Discord STARTUPWMCLASS=discord
export ICON="$OFFICIAL_ICON" DESKTOP="$OFFICIAL_DESKTOP"
export OUTPATH="$SCRIPT_DIR/dist" OUTNAME=discord.AppImage
export DEPLOY_OPENGL=1 NO_STRIP=1

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

###### 配置 Discord 模块和运行环境 ######

# 把官方模块作为只读模板带入包内，启动时再同步到当前用户可写配置目录。
mkdir -p "$APPDIR/share/discord-modules"
cp -a "$MODULES"/. "$APPDIR/share/discord-modules"/

# 仅在包内模块版本变化时替换用户模块目录，避免 Discord 在只读挂载点写入失败。
cat > "$APPDIR/bin/stage-discord-modules.src.hook" <<EOF
#!/bin/false
mod_src="\${SHARUN_DIR}/share/discord-modules"
mod_dest="\${XDG_CONFIG_HOME:-\$HOME/.config}/discord/${VERSION}/modules"
if [ ! -f "\$mod_dest/installed.json" ] || ! cmp -s "\$mod_src/installed.json" "\$mod_dest/installed.json"; then
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
