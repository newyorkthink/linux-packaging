#!/usr/bin/env bash

# 本程序专属处理：命令失败、引用未定义变量或管道失败时立即退出。
set -Eeuo pipefail

# 本程序专属处理：接收标准生成器传入的阶段、来源目录和 AppDir。
[[ $# == 3 && ( "${1:-}" == prepare || "${1:-}" == finalize ) && -d "${2:-}" && -d "${3:-}" && "${2:-}" != / && "${3:-}" != / ]] || {
  echo "用法：$0 <prepare|finalize> <source 目录> <AppDir>" >&2
  exit 2
}
STAGE="$1"
SOURCE_DIR="$2"
APPDIR="$3"
PATCH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$(cd -- "$PATCH_DIR/../../common" && pwd)"
APP_ROOT="$APPDIR/usr/lib/discord"
HOST_SOURCE="$SOURCE_DIR/discord-host/files"
MODULE_SOURCE="$SOURCE_DIR/discord-modules"

# 本程序专属处理：在正式部署前取得同次 stable 清单中的完整程序和全部模块。
if [[ "$STAGE" == prepare ]]; then
  MANIFEST="$SOURCE_DIR/discord-manifest.json"
  MANIFEST_URL='https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=linux&arch=x64'

  # 本程序专属处理：使用官方更新器标识下载清单，下载日志不混入版本输出。
  "$COMMON_DIR/download/download_file.sh" "$MANIFEST_URL" "$MANIFEST" "" "Discord-Updater/1" >&2

  # 本程序专属处理：读取真实主程序版本、地址和官方 SHA-256，不使用引导 DEB 的版本。
  MANIFEST_VERSION="$(jq -er '.full.host_version | map(tostring) | join(".")' "$MANIFEST")"
  HOST_URL="$(jq -er '.full.url' "$MANIFEST")"
  HOST_SHA="$(jq -er '.full.package_sha256' "$MANIFEST")"
  [[ "$MANIFEST_VERSION" =~ ^[0-9]+([.][0-9]+)+$ && "$HOST_SHA" =~ ^[[:xdigit:]]{64}$ && "$HOST_URL" == https://*.discordapp.net/distro/app/stable/linux/x64/${MANIFEST_VERSION}/full.distro ]] || {
    echo "错误：完整主程序地址与 stable 清单版本不一致。" >&2
    exit 1
  }

  # 本程序专属处理：下载并核对官方完整主程序，再复用公共 distro 解包入口。
  "$COMMON_DIR/download/download_file.sh" "$HOST_URL" "$SOURCE_DIR/discord-host.distro" "$HOST_SHA" "Discord-Updater/1" >&2
  "$COMMON_DIR/archive/extract_archive.sh" "$SOURCE_DIR/discord-host.distro" "$SOURCE_DIR/discord-host" >&2
  [[ -s "$HOST_SOURCE/Discord" && -s "$HOST_SOURCE/resources/app.asar" && -s "$HOST_SOURCE/icudtl.dat" ]] || {
    echo "错误：完整分发包缺少 Discord、app.asar 或 icudtl.dat，禁止封装引导器。" >&2
    exit 1
  }

  # 本程序专属处理：设置官方主程序的执行权限，不改变文件内容。
  chmod 0755 -- "$HOST_SOURCE/Discord"

  # 本程序专属处理：读取包内实际版本，并与同次清单强制比对。
  VERSION="$("$COMMON_DIR/build/read_app_version.sh" package-json "$HOST_SOURCE/resources/build_info.json")"
  [[ "$VERSION" == "$MANIFEST_VERSION" ]] || {
    echo "错误：完整程序版本 $VERSION 与清单版本 $MANIFEST_VERSION 不一致。" >&2
    exit 1
  }

  # 本程序专属处理：保留完整相邻资源布局，并放入 linuxdeploy 会扫描的应用目录。
  mkdir -p "$APP_ROOT" "$MODULE_SOURCE"
  cp -a -- "$HOST_SOURCE"/. "$APP_ROOT"/

  # 本程序专属处理：先完整解析模块清单，解析失败时不进入下载循环。
  jq -er '.modules | to_entries[] | [.key, .value.full.url, .value.full.package_sha256] | @tsv' "$MANIFEST" > "$SOURCE_DIR/discord-modules.tsv"

  # 本程序专属处理：逐项校验并解包官方模块，不依赖首次启动时临时下载桌面核心。
  while IFS=$'\t' read -r name url sha; do
    [[ "$name" =~ ^[A-Za-z0-9_-]+$ && "$sha" =~ ^[[:xdigit:]]{64}$ && "$url" == https://*.discordapp.net/distro/app/stable/linux/x64/${VERSION}/${name}/*/full.distro ]] || {
      echo "错误：模块名称或地址不符合本次 stable 清单：$name" >&2
      exit 1
    }
    "$COMMON_DIR/download/download_file.sh" "$url" "$SOURCE_DIR/${name}.distro" "$sha" "Discord-Updater/1" >&2
    "$COMMON_DIR/archive/extract_archive.sh" "$SOURCE_DIR/${name}.distro" "$SOURCE_DIR/discord-module-source/$name" >&2
    [[ -d "$SOURCE_DIR/discord-module-source/$name/files" ]] || {
      echo "错误：官方模块缺少 files 目录：$name" >&2
      exit 1
    }
    mkdir -p "$MODULE_SOURCE/$name"
    cp -a -- "$SOURCE_DIR/discord-module-source/$name/files"/. "$MODULE_SOURCE/$name"/
  done < "$SOURCE_DIR/discord-modules.tsv"

  # 本程序专属处理：缺少真实桌面核心时立即停止，避免再次生成只有运行库的 AppImage。
  [[ -s "$MODULE_SOURCE/discord_desktop_core/index.js" && -s "$MODULE_SOURCE/discord_desktop_core/core.asar" ]] || {
    echo "错误：官方分发缺少 discord_desktop_core。" >&2
    exit 1
  }

  # 本程序专属处理：保存模块版本、主程序版本及来源标记，供运行时识别当前完整分发。
  jq -ce '.modules | with_entries(.value = {installedVersion: (.value.full.module_version | tonumber)})' "$MANIFEST" > "$MODULE_SOURCE/installed.json"
  printf '%s\n' "$VERSION" > "$MODULE_SOURCE/.appimage-version"
  sha256sum -- "$MANIFEST" | awk '{print $1}' > "$MODULE_SOURCE/.appimage-source.sha256"
  mkdir -p "$MODULE_SOURCE/discord_krisp/KMS/logs" "$APPDIR/usr/share/discord-modules"
  cp -a -- "$MODULE_SOURCE"/. "$APPDIR/usr/share/discord-modules"/

  # 本程序专属处理：显式收集完整客户端及原生模块动态加载的已确认运行库。
  for runtime_library in libc++.so.1 libpulse.so.0 libappindicator3.so.1 libnotify.so.4 libXss.so.1 libcups.so.2 libasound.so.2 libwayland-client.so.0 libatomic.so.1; do
    install -m 0644 -- "/usr/lib/x86_64-linux-gnu/$runtime_library" "$APPDIR/usr/lib/$runtime_library"
  done

  # 本程序专属处理：复用公共入口收集 Electron 所需的 NSS 核心库及动态加载模块。
  "$COMMON_DIR/linuxdeploy/copy_nss_runtime.sh" "$APPDIR/usr/lib" --with-nspr >&2

  # 本程序专属处理：使用与可写模块复制对应的加载方式，只修改包内配置。
  jq '.newUpdater = false' "$APP_ROOT/resources/build_info.json" > "$SOURCE_DIR/discord-build-info.json"
  install -m 0644 -- "$SOURCE_DIR/discord-build-info.json" "$APP_ROOT/resources/build_info.json"

  # 本程序专属处理：让官方桌面命令对应完整程序，并安装普通运行数据准备脚本。
  ln -sfnT ../lib/discord/Discord "$APPDIR/usr/bin/discord"
  install -m 0755 -- "$PATCH_DIR/prepare_modules.sh" "$APP_ROOT/prepare_modules.sh"

  # 本程序专属处理：最终版本只返回完整主程序实际版本。
  printf '%s\n' "$VERSION"
  exit 0
fi

# 本程序专属处理：依赖部署结束后恢复官方主程序，保留已收集的公共运行库和未改写的模块模板。
[[ -x "$HOST_SOURCE/Discord" && -s "$MODULE_SOURCE/installed.json" ]] || {
  echo "错误：缺少本次已校验的完整程序来源，停止最终封装。" >&2
  exit 1
}
cp -a -- "$HOST_SOURCE/Discord" "$APP_ROOT/Discord"

# 本程序专属处理：确保正式入口存在且与本次官方完整主程序逐字节一致。
cmp -s -- "$HOST_SOURCE/Discord" "$APP_ROOT/Discord" || {
  echo "错误：最终 Discord 主程序与官方完整分发不一致。" >&2
  exit 1
}
