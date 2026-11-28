#!/usr/bin/env bash
set -Eeuo pipefail

# 用同一份 AUR 配方的来源和摘要预取 HTTPS 文件，再安装该配方生成的软件包。
if (( $# != 4 )) || [[ ! "$1" =~ ^[a-z0-9][a-z0-9@._+-]*$ || "$1" == *..* || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
  echo "用法：$0 <AUR 包名> <重试等待秒数> <官方 HTTPS 地址前缀> '<源文件名模板>'" >&2
  exit 2
fi

AUR_PACKAGE="$1"
RETRY_DELAY="$2"
HTTPS_PREFIX="$3"
SOURCE_PATTERN="$4"
if [[ ! "$HTTPS_PREFIX" =~ ^https://[A-Za-z0-9][A-Za-z0-9.-]*/([A-Za-z0-9._-]+/)*$ || "$HTTPS_PREFIX" == *..* || "$HTTPS_PREFIX" == *"/./"* ]]; then
  echo "错误：需要以 / 结尾且不含凭据、端口或查询参数的官方 HTTPS 地址前缀。" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
ARCH="$(uname -m)"
export LC_ALL=C

# 仅保留本次安装使用的配方、下载文件和来源目录。
INSTALL_WORK="$(mktemp -d "${TMPDIR:-/tmp}/arch-aur-https.XXXXXXXX")"
# 退出时删除本次创建的临时工作区。
cleanup() {
  rm -rf -- "$INSTALL_WORK"
}
trap cleanup EXIT

# 允许非 root 构建用户进入临时工作区并取得 AUR 配方。
chmod 711 "$INSTALL_WORK"
mkdir -m 1777 -- "$INSTALL_WORK/build"
(
  cd -- "$INSTALL_WORK/build"
  yay -G --noconfirm "aur/$AUR_PACKAGE"
)

# 使用配方目录的非 root 所有者生成元数据并安装。
AUR_BUILD_DIR="$INSTALL_WORK/build/$AUR_PACKAGE"
if [[ ! -d "$AUR_BUILD_DIR" || -L "$AUR_BUILD_DIR" || ! -f "$AUR_BUILD_DIR/PKGBUILD" || -L "$AUR_BUILD_DIR/PKGBUILD" ]]; then
  echo "错误：缺少同次获取的 AUR 配方：$AUR_PACKAGE" >&2
  exit 1
fi
AUR_BUILD_UID="$(stat -c '%u' -- "$AUR_BUILD_DIR")"
if [[ "$AUR_BUILD_UID" == 0 || ( "$EUID" != 0 && "$AUR_BUILD_UID" != "$EUID" ) ]]; then
  echo "错误：AUR 配方目录须属于可执行构建的非 root 用户。" >&2
  exit 1
fi

# 以配方目录的所有者身份运行 Arch 的 makepkg。
run_source_makepkg() {
  if (( EUID == 0 )); then
    sudo -HE -u "#$AUR_BUILD_UID" makepkg "$@"
  else
    makepkg "$@"
  fi
}

# 让配方属主可写入本次的来源目录，覆盖 makepkg 配置中的共享缓存。
SOURCE_DIR="$INSTALL_WORK/sources"
mkdir -m 755 -- "$SOURCE_DIR"
if (( EUID == 0 )); then
  chown -- "$AUR_BUILD_UID" "$SOURCE_DIR"
fi

# 从实际 PKGBUILD 重新生成元数据，避开上传时未同步的 .SRCINFO。
(
  cd -- "$AUR_BUILD_DIR"
  run_source_makepkg --printsrcinfo "SRCDEST=$SOURCE_DIR"
) > "$INSTALL_WORK/actual-srcinfo"

# 按当前架构及源条目的同组索引读取唯一文件及其原 SHA-256。
SOURCE_METADATA="$(
  python3 - "$INSTALL_WORK/actual-srcinfo" "$AUR_PACKAGE" "$ARCH" "$HTTPS_PREFIX" "$SOURCE_PATTERN" <<'PY'
import re
import sys
from pathlib import Path

metadata, package, architecture, prefix, pattern = sys.argv[1:]

fields = {}
for line in Path(metadata).read_text(encoding="utf-8").splitlines():
    key, sep, value = line.strip().partition(" = ")
    if sep:
        fields.setdefault(key, []).append(value)

if fields.get("pkgbase") != [package] or fields.get("pkgname") != [package]:
    raise SystemExit("错误：仅支持包基名与包名一致的 AUR 单包配方。")
architectures = fields.get("arch", [])
if architecture not in architectures and "any" not in architectures:
    raise SystemExit("错误：当前 AUR 配方不支持构建架构。")
versions = fields.get("pkgver", [])
if len(versions) != 1 or not versions[0] or pattern.count("{version}") != 1:
    raise SystemExit("错误：配方版本或源文件名模板无效。")

filename = pattern.replace("{version}", versions[0])
if ".." in filename or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", filename):
    raise SystemExit("错误：源文件名必须是安全的单个文件名。")

https_url = prefix + filename
http_url = "http://" + https_url.removeprefix("https://")
matches = []
for suffix in ("", "_" + architecture):
    sources = fields.get("source" + suffix, [])
    checksums = fields.get("sha256sums" + suffix, [])
    for index, entry in enumerate(sources):
        alias, sep, url = entry.partition("::")
        if not sep:
            url = entry
        if url not in (http_url, https_url):
            if sep or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", url) or ".." in url:
                raise SystemExit("错误：显式 HTTPS 模式仅支持一个指定远程源及同目录的本地来源。")
            continue
        if (sep and alias != filename) or len(checksums) != len(sources):
            raise SystemExit("错误：AUR 源文件名或 SHA-256 数组与实际配方不匹配。")
        checksum = checksums[index]
        if not re.fullmatch(r"[0-9A-Fa-f]{64}", checksum):
            raise SystemExit("错误：AUR 配方未提供有效的源文件 SHA-256。")
        matches.append(checksum.lower())

if len(matches) != 1:
    raise SystemExit("错误：无法按官方地址唯一匹配 AUR 源文件。")
print(filename)
print(https_url)
print(matches[0])
PY
)"
mapfile -t SOURCE_INFO <<< "$SOURCE_METADATA"
SOURCE_FILENAME="${SOURCE_INFO[0]}"
SOURCE_URL="${SOURCE_INFO[1]}"
EXPECTED_SHA256="${SOURCE_INFO[2]}"

# makepkg 优先使用配方目录的同名文件，要求本次下载是唯一的归档来源。
if [[ -e "$AUR_BUILD_DIR/$SOURCE_FILENAME" || -L "$AUR_BUILD_DIR/$SOURCE_FILENAME" ]]; then
  echo "错误：配方目录已有同名源文件，无法保证使用本次校验的下载。" >&2
  exit 1
fi

for attempt in 1 2; do
  # 在当前尝试的私有目录下载，网络失败直接返回公共下载器的错误。
  DOWNLOAD_DIR="$INSTALL_WORK/download-$attempt"
  mkdir -m 700 -- "$DOWNLOAD_DIR"
  printf '正在通过 HTTPS 获取 AUR 源文件：%s\n' "$SOURCE_URL" >&2
  "$DOWNLOAD_FILE" "$SOURCE_URL" "$DOWNLOAD_DIR/$SOURCE_FILENAME"

  # 单独核对摘要，避免把网络或磁盘错误当作校验失败重试。
  ACTUAL_SHA256="$(sha256sum < "$DOWNLOAD_DIR/$SOURCE_FILENAME")"
  if [[ "${ACTUAL_SHA256%% *}" != "$EXPECTED_SHA256" ]]; then
    printf '错误：AUR 源文件 %s 的 SHA-256 与配方不符。\n' "$SOURCE_FILENAME" >&2
    if (( attempt == 2 )); then
      exit 1
    fi
    printf '等待 %s 秒后通过 HTTPS 重新下载一次。\n' "$RETRY_DELAY" >&2
    sleep "$RETRY_DELAY"
    continue
  fi

  # 仅将已校验的文件交给非 root 构建用户，供原配方再次校验。
  install -m 644 -- "$DOWNLOAD_DIR/$SOURCE_FILENAME" "$SOURCE_DIR/$SOURCE_FILENAME"

  # 在同一份配方的目录内构建并安装软件包。
  (
    cd -- "$AUR_BUILD_DIR"
    run_source_makepkg --syncdeps --install --noconfirm "SRCDEST=$SOURCE_DIR"
  )
  exit 0
done
