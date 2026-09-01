#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# JRiver Media Center AnyLinux AppImage 网页音频稳定层
# ==============================================================================
# 2026-09-01：迁移到 linux-packaging 后，不再依赖源仓库 Git 历史。
# 已验证核心基线以 build_jriver_base.sh 原样保存在本目录，并继续校验原始 blob SHA。
# 本层只应用 JRWeb 网页音频修复；主程序、CEF 注入、pathmap、AppRun、glibc 隔离及
# 其它已验证逻辑全部来自该固定基线，不做整文件重写。
#
# Kali 实测链路：
# 1. libasound_module_pcm_pulse.so 已能找到；
# 2. 首先缺 libpulse.so.0；
# 3. 补当前 Arch Pulse 后继续缺 libsndfile.so.1。
# 说明不能再按报错逐层复制 Arch 当前库。Arch runner 已滚动到更高 glibc，继续复制会把
# 新 ABI 带给 Kali。这里改为固定 Debian 12/bookworm 的 Pulse 客户端与 libsndfile codec
# 闭包，只放入 JRWebChromium 已允许的 cef-runtime；不恢复旧版宽泛 LD_LIBRARY_PATH，
# 不把 shared/lib、AppDir/lib 或包内 glibc 暴露给宿主侧 Chromium。

cd "$(dirname "$0")"

BASE_FILE="$PWD/build_jriver_base.sh"
BASE_BLOB='a589c8f8e11480b1805226d8d8c247bc7d689d4e'
PATCHED="$(mktemp "$PWD/.build_jriver_patched.XXXXXX.sh")"

cleanup() {
  rm -f "$PATCHED"
}
trap cleanup EXIT

if [[ ! -f "$BASE_FILE" ]]; then
  echo "错误：缺少 JRiver 固定基线文件：$BASE_FILE" >&2
  exit 1
fi

cp -f "$BASE_FILE" "$PATCHED"

if [[ "$(git hash-object "$PATCHED")" != "$BASE_BLOB" ]]; then
  echo '错误：JRiver 固定基线与源仓库已验证 blob SHA 不一致。' >&2
  exit 1
fi

python3 - "$PATCHED" <<'PY_JRWEB_PULSE_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

runtime_anchor = '''cp -a "$CEF_ROOT/Release/." "$CEF_PRIVATE_DIR/"
cp -a "$CEF_ROOT/Resources/." "$CEF_PRIVATE_DIR/"
'''
runtime_patch = runtime_anchor + r'''
# 2026-08-14：不要复制 Arch rolling 的 Pulse/libsndfile 链。
# 固定 Debian 12/bookworm amd64 运行库；这些库只给外部 JRWebChromium 使用。
DEB_AUDIO_WORKDIR="$(mktemp -d "$PWD/.jriver-deb-audio.XXXXXX")"
DEB_AUDIO_ROOT="$DEB_AUDIO_WORKDIR/root"
mkdir -p "$DEB_AUDIO_ROOT"

extract_deb_audio_package() {
  local url="$1"
  local name="$2"
  local deb="$DEB_AUDIO_WORKDIR/$name.deb"
  local ar_dir="$DEB_AUDIO_WORKDIR/$name-ar"
  local data_archive

  curl -fL --retry 3 --retry-delay 2 "$url" -o "$deb"
  mkdir -p "$ar_dir"
  (
    cd "$ar_dir"
    ar x "$deb"
  )
  data_archive="$(find "$ar_dir" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
  if [[ -z "$data_archive" ]]; then
    echo "错误：Debian 音频包缺少 data.tar：$name" >&2
    exit 1
  fi
  tar -xf "$data_archive" -C "$DEB_AUDIO_ROOT"
}

DEBIAN_MIRROR='https://deb.debian.org/debian/pool/main'
extract_deb_audio_package "$DEBIAN_MIRROR/p/pulseaudio/libpulse0_16.1+dfsg1-2+b1_amd64.deb" libpulse0
extract_deb_audio_package "$DEBIAN_MIRROR/liba/libasyncns/libasyncns0_0.8-6+b3_amd64.deb" libasyncns0
extract_deb_audio_package "$DEBIAN_MIRROR/libs/libsndfile/libsndfile1_1.2.0-1+deb12u1_amd64.deb" libsndfile1
extract_deb_audio_package "$DEBIAN_MIRROR/f/flac/libflac12_1.4.2+ds-2_amd64.deb" libflac12
extract_deb_audio_package "$DEBIAN_MIRROR/l/lame/libmp3lame0_3.100-6_amd64.deb" libmp3lame0
extract_deb_audio_package "$DEBIAN_MIRROR/m/mpg123/libmpg123-0_1.31.2-1+deb12u1_amd64.deb" libmpg123-0
extract_deb_audio_package "$DEBIAN_MIRROR/libo/libogg/libogg0_1.3.5-3_amd64.deb" libogg0
extract_deb_audio_package "$DEBIAN_MIRROR/o/opus/libopus0_1.3.1-3_amd64.deb" libopus0
extract_deb_audio_package "$DEBIAN_MIRROR/libv/libvorbis/libvorbis0a_1.3.7-1_amd64.deb" libvorbis0a
extract_deb_audio_package "$DEBIAN_MIRROR/libv/libvorbis/libvorbisenc2_1.3.7-1_amd64.deb" libvorbisenc2

DEB_LIBDIR="$DEB_AUDIO_ROOT/usr/lib/x86_64-linux-gnu"
for audio_soname in \
  libpulse.so.0 \
  libasyncns.so.0 \
  libsndfile.so.1 \
  libFLAC.so.12 \
  libmp3lame.so.0 \
  libmpg123.so.0 \
  libogg.so.0 \
  libopus.so.0 \
  libvorbis.so.0 \
  libvorbisenc.so.2; do
  audio_source="$DEB_LIBDIR/$audio_soname"
  if [[ ! -e "$audio_source" ]]; then
    echo "错误：Debian 音频闭包缺少 $audio_soname" >&2
    exit 1
  fi
  install -Dm755 "$(readlink -f "$audio_source")" "$CEF_PRIVATE_DIR/$audio_soname"
done

PULSE_COMMON_SOURCE="$(find "$DEB_LIBDIR/pulseaudio" -maxdepth 1 -type f -name 'libpulsecommon-*.so' -print -quit)"
if [[ -z "$PULSE_COMMON_SOURCE" ]]; then
  echo '错误：Debian libpulse0 缺少 libpulsecommon。' >&2
  exit 1
fi
install -Dm755 "$PULSE_COMMON_SOURCE" "$CEF_PRIVATE_DIR/$(basename "$PULSE_COMMON_SOURCE")"
rm -rf "$DEB_AUDIO_WORKDIR"
'''

check_anchor = '''check_path file "$CEF_PRIVATE_DIR/libcef.so"
'''
check_patch = check_anchor + r'''check_path file "$CEF_PRIVATE_DIR/libpulse.so.0"
check_path file "$CEF_PRIVATE_DIR/libasyncns.so.0"
check_path file "$CEF_PRIVATE_DIR/libsndfile.so.1"
check_path file "$CEF_PRIVATE_DIR/libFLAC.so.12"
check_path file "$CEF_PRIVATE_DIR/libmp3lame.so.0"
check_path file "$CEF_PRIVATE_DIR/libmpg123.so.0"
check_path file "$CEF_PRIVATE_DIR/libogg.so.0"
check_path file "$CEF_PRIVATE_DIR/libopus.so.0"
check_path file "$CEF_PRIVATE_DIR/libvorbis.so.0"
check_path file "$CEF_PRIVATE_DIR/libvorbisenc.so.2"
if find "$CEF_PRIVATE_DIR" -maxdepth 1 -type f -name 'libpulsecommon-*.so' -print -quit | grep -q .; then
  echo 'CHECK OK: JRWebChromium private Debian libpulsecommon'
else
  echo 'CHECK MISSING: JRWebChromium private Debian libpulsecommon' >&2
fi
'''

layout_anchor = '''if ! grep -aFq "$CEF_API_HASH" "$CEF_PRIVATE_DIR/libcef.so" || \\
   ! grep -aFq "$CEF_API_HASH" "$JRIVER_APPDIR/JRWeb.real"; then
'''
layout_patch = r'''# JRWebChromium 私有目录必须一次包含 Pulse + libsndfile codec 闭包。
for required_audio_lib in \
  libpulse.so.0 libasyncns.so.0 libsndfile.so.1 libFLAC.so.12 \
  libmp3lame.so.0 libmpg123.so.0 libogg.so.0 libopus.so.0 \
  libvorbis.so.0 libvorbisenc.so.2; do
  if [[ ! -f "$CEF_PRIVATE_DIR/$required_audio_lib" ]]; then
    echo "错误：JRWebChromium 私有音频闭包缺少 $required_audio_lib" >&2
    exit 1
  fi
done
if ! find "$CEF_PRIVATE_DIR" -maxdepth 1 -type f -name 'libpulsecommon-*.so' -print -quit | grep -q .; then
  echo '错误：JRWebChromium 私有音频闭包缺少 libpulsecommon。' >&2
  exit 1
fi

# 外部 Chromium 仍禁止拿到 AppImage 的 glibc/动态加载器。
if find "$CEF_PRIVATE_DIR" -maxdepth 1 -type f \
     \( -name 'libc.so*' -o -name 'ld-linux*.so*' -o -name 'libpthread.so*' \) \
     -print -quit | grep -q .; then
  echo '错误：cef-runtime 中出现 glibc 核心库，拒绝破坏宿主隔离。' >&2
  exit 1
fi

''' + layout_anchor

for name, anchor in (
    ("CEF runtime copy", runtime_anchor),
    ("final check", check_anchor),
    ("CEF ABI check", layout_anchor),
):
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"JRiver stable baseline changed: {name} anchor count={count}")

text = text.replace(runtime_anchor, runtime_patch, 1)
text = text.replace(check_anchor, check_patch, 1)
text = text.replace(layout_anchor, layout_patch, 1)
path.write_text(text)
PY_JRWEB_PULSE_PATCH

chmod +x "$PATCHED"
bash -n "$PATCHED"
bash "$PATCHED" "$@"
