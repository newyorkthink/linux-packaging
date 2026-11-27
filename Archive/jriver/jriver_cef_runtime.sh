#!/usr/bin/env bash
set -euo pipefail

MC_VER="${1:?用法: jriver_cef_runtime.sh <MC主版本> [架构]}"
ARCH="${2:-$(uname -m)}"
APPDIR="${APPDIR:-$PWD/AppDir}"
JRWEB="/usr/lib/jriver/Media Center ${MC_VER}/JRWeb"
WORKDIR="$PWD/.jriver-cef-runtime"

if [[ ! -x "$JRWEB" ]]; then
  echo "错误：JRWeb 不存在：$JRWEB" >&2
  exit 1
fi

case "$ARCH" in
  x86_64) CEF_PLATFORM=linux64 ;;
  *)
    echo "错误：当前 JRiver CEF 自动打包仅支持 x86_64，检测到：$ARCH" >&2
    exit 1
    ;;
esac

# JRWeb 二进制中包含其编译时使用的 CEF 目录名，据此锁定完全一致的 CEF ABI 版本。
# 不使用 head 提前关闭管道，避免 pipefail 把正常的 SIGPIPE 误判成构建失败。
CEF_VERSION="$(strings "$JRWEB" \
  | sed -n 's#.*cef_binary_\([^/]*\)_linux64/.*#\1#p' \
  | sed -n '1p')"

if [[ -z "$CEF_VERSION" ]]; then
  echo '错误：无法从 JRWeb 识别 CEF 版本，停止打包，避免混入不匹配的 libcef.so。' >&2
  exit 1
fi

CEF_VERSION_URL="${CEF_VERSION//+/%2B}"
CEF_ARCHIVE="cef_binary_${CEF_VERSION}_${CEF_PLATFORM}_minimal.tar.bz2"
CEF_URL="https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION_URL}_${CEF_PLATFORM}_minimal.tar.bz2"

echo "检测到 JRWeb CEF：$CEF_VERSION"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

wget --retry-connrefused --tries=5 --timeout=30 \
  -O "$WORKDIR/$CEF_ARCHIVE" "$CEF_URL"

tar -xjf "$WORKDIR/$CEF_ARCHIVE" -C "$WORKDIR"

CEF_ROOT="$(find "$WORKDIR" -mindepth 1 -maxdepth 1 -type d \
  -name "cef_binary_*_${CEF_PLATFORM}_minimal" -print -quit)"
CEF_RELEASE="$CEF_ROOT/Release"
CEF_RESOURCES="$CEF_ROOT/Resources"

if [[ -z "$CEF_ROOT" || ! -f "$CEF_RELEASE/libcef.so" ]]; then
  echo '错误：CEF 压缩包中未找到 Release/libcef.so。' >&2
  exit 1
fi

# build_jriver.sh 已经用 quick-sharun 生成主 AppDir。
# CEF 必须在独立目录再次部署，否则第二次 quick-sharun 会尝试重复创建
# AppDir/lib 中已有的 GStreamer 等文件，并因 “File exists” 直接失败。
CEF_SHARUN_WORKDIR="$WORKDIR/sharun"
CEF_SHARUN_APPDIR="$CEF_SHARUN_WORKDIR/AppDir"
mkdir -p "$CEF_SHARUN_WORKDIR"

# 在干净目录中让 quick-sharun 收集 libcef.so 及其 ELF 依赖。
# 新版 quick-sharun 偶发返回 141（SIGPIPE）；141 本身不作为失败依据，
# 后面仍会严格检查隔离 AppDir 中的 libcef.so 和最终 CEF 资源。
set +e
(
  cd "$CEF_SHARUN_WORKDIR"
  quick-sharun "$CEF_RELEASE/libcef.so"
)
QUICK_SHARUN_RC=$?
set -e

if [[ $QUICK_SHARUN_RC -ne 0 && $QUICK_SHARUN_RC -ne 141 ]]; then
  echo "错误：quick-sharun 隔离部署 CEF 失败，退出码：$QUICK_SHARUN_RC" >&2
  exit "$QUICK_SHARUN_RC"
fi

if [[ $QUICK_SHARUN_RC -eq 141 ]]; then
  echo '提示：quick-sharun 返回 141（SIGPIPE），继续通过实际产物检查确认部署结果。'
fi

# 先验证隔离部署确实生成了完整的 libcef.so，避免把 quick-sharun 异常当成成功。
if [[ ! -s "$CEF_SHARUN_APPDIR/lib/libcef.so" && \
      ! -s "$CEF_SHARUN_APPDIR/shared/lib/libcef.so" ]]; then
  echo '错误：quick-sharun 未在隔离目录完整部署 libcef.so。' >&2
  exit 1
fi

# 只把隔离环境中新收集到的库合并回主 AppDir。
# 不覆盖主 quick-sharun 已部署并验证过的库，也不带入隔离环境的 lib.path。
mkdir -p "$APPDIR/lib"
rm -f "$CEF_SHARUN_APPDIR/lib/lib.path"
cp -an "$CEF_SHARUN_APPDIR/lib/." "$APPDIR/lib/"

# libcef.so 必须使用刚下载的、与 JRWeb ABI 完全匹配的版本。
if [[ -s "$CEF_SHARUN_APPDIR/lib/libcef.so" ]]; then
  cp -af "$CEF_SHARUN_APPDIR/lib/libcef.so" "$APPDIR/lib/libcef.so"
elif [[ -s "$CEF_SHARUN_APPDIR/shared/lib/libcef.so" ]]; then
  cp -af "$CEF_SHARUN_APPDIR/shared/lib/libcef.so" "$APPDIR/lib/libcef.so"
fi

CEF_RUNTIME_DEST="$APPDIR/shared/bin"
mkdir -p "$CEF_RUNTIME_DEST"

# CEF 在 Linux 下默认从实际应用可执行文件旁读取资源。
# Sharun 实际执行的是 shared/bin/JRWeb，因此资源固定放在该目录。
if [[ -d "$CEF_RESOURCES" ]]; then
  cp -a "$CEF_RESOURCES/." "$CEF_RUNTIME_DEST/"
fi

for cef_runtime_file in \
  chrome-sandbox \
  icudtl.dat \
  snapshot_blob.bin \
  v8_context_snapshot.bin \
  vk_swiftshader_icd.json \
  libEGL.so \
  libGLESv2.so \
  libvk_swiftshader.so; do
  if [[ -e "$CEF_RELEASE/$cef_runtime_file" ]]; then
    cp -a "$CEF_RELEASE/$cef_runtime_file" "$CEF_RUNTIME_DEST/"
  fi
done

# libcef.so 必须实际进入主 AppDir/lib（shared/lib 是其兼容链接）。
# 使用 -s 同时确认文件存在且非空，避免把不完整部署误判为成功。
if [[ ! -s "$APPDIR/lib/libcef.so" && ! -s "$APPDIR/shared/lib/libcef.so" ]]; then
  echo '错误：CEF libcef.so 未完整合并到主 AppDir。' >&2
  exit 1
fi

for required_cef_path in \
  "$CEF_RUNTIME_DEST/icudtl.dat" \
  "$CEF_RUNTIME_DEST/resources.pak" \
  "$CEF_RUNTIME_DEST/locales"; do
  if [[ ! -e "$required_cef_path" ]]; then
    echo "错误：CEF 必需运行文件缺失：$required_cef_path" >&2
    exit 1
  fi
done

rm -rf "$WORKDIR"
echo 'CEF 运行时已按 JRWeb ABI 完整加入 AppImage。'
