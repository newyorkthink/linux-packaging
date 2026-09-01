#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# Webcamoid AnyLinux AppImage
# ==============================================================================
# - 从 Webcamoid 最新稳定 Release 源码构建，不拉取私有 ExtraPlugins 子模块。
# - 打包 FFmpeg、Qt Multimedia、PipeWire、V4L2、v4l-utils、libuvc 与 Qt6 主题插件。
# - 默认简体中文、Adwaita Dark、Qt RHI + OpenGL。
# - 忽略 Dummy/v4l2loopback 设备，优先选择真实摄像头。
# - 禁用不可靠的 QSharedMemory 单实例检测，避免程序未运行时误报。
#
# 输出：dist/webcamoid.AppImage

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log() {
  echo "[Webcamoid] $*"
}

die() {
  echo "错误：$*" >&2
  exit 1
}

ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] || die "当前仅支持 x86_64，检测到：$ARCH"
export ARCH

readonly ROOT="$PWD"
readonly WORK_DIR="$ROOT/.work"
readonly SOURCE_DIR="$WORK_DIR/source"
readonly BUILD_DIR="$WORK_DIR/build"
readonly STAGE_DIR="$WORK_DIR/stage"
readonly APPDIR="$ROOT/AppDir"
readonly OUTDIR="$ROOT/dist"
readonly OUTFILE="$OUTDIR/webcamoid.AppImage"

rm -rf "$WORK_DIR" "$APPDIR" "$OUTDIR"
mkdir -p "$WORK_DIR" "$OUTDIR"

if pacman -Q ffmpeg-mini >/dev/null 2>&1; then
  log "移除 ffmpeg-mini，改用完整 FFmpeg"
  if [[ "$EUID" -eq 0 ]]; then
    pacman -Rdd --noconfirm ffmpeg-mini
  else
    sudo pacman -Rdd --noconfirm ffmpeg-mini
  fi
fi

log "安装构建、摄像头、音视频与 Qt6 主题依赖"
yay -S --needed --noconfirm \
  base-devel git cmake ninja pkgconf python curl wget file patchelf binutils \
  appstream-glib desktop-file-utils util-linux zsync dbus xorg-server-xvfb \
  ffmpeg libuvc v4l-utils libusb alsa-lib libpulse libproxy pipewire \
  qt6-base qt6-declarative qt6-multimedia qt6-svg qt6-tools qt6-wayland \
  qt6-imageformats qt6-shadertools qt6ct kvantum lxqt-qtplugin adwaita-qt6 fcitx5-qt \
  libglvnd mesa libx11 libxext libxfixes libxrender libxcb libxkbcommon \
  libxkbcommon-x11 xcb-util xcb-util-image xcb-util-keysyms \
  xcb-util-renderutil xcb-util-wm xcb-util-cursor

log "解析 Webcamoid 最新稳定 Release"
WEBCAMOID_REF="$(
  curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout 15 \
    --max-time 60 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    https://api.github.com/repos/webcamoid/webcamoid/releases/latest \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); tag=data.get("tag_name", ""); sys.stdout.write(tag if tag and not data.get("draft") and not data.get("prerelease") else "")'
)"
[[ -n "$WEBCAMOID_REF" ]] || die "无法解析 Webcamoid 最新稳定版本。"
[[ "$WEBCAMOID_REF" =~ ^v?[0-9]+([.][0-9]+){2}([.-][0-9A-Za-z._-]+)?$ ]] \
  || die "Webcamoid 最新稳定版本格式异常：$WEBCAMOID_REF"
readonly WEBCAMOID_REF
printf '%s\n' "$WEBCAMOID_REF" > "$OUTDIR/version.txt"

log "获取 Webcamoid 上游源码：$WEBCAMOID_REF"
git clone \
  --depth 1 \
  --branch "$WEBCAMOID_REF" \
  https://github.com/webcamoid/webcamoid.git \
  "$SOURCE_DIR"

log "应用深色主题、真实摄像头优先与单实例修复补丁"
python3 - "$SOURCE_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

palette_files = [
    root / "libAvKys/Lib/src/qml/akpalette.cpp",
    root / "libAvKys/Lib/src/qml/akpalettegroup.cpp",
]
replacements = (
    (
        'config.value("paletteName", "System").toString()',
        'config.value("paletteName", "Adwaita Dark").toString()',
    ),
    (
        'config.value("paletteName").toString()',
        'config.value("paletteName", "Adwaita Dark").toString()',
    ),
)
replaced = 0
for path in palette_files:
    text = path.read_text()
    for old, new in replacements:
        count = text.count(old)
        text = text.replace(old, new)
        replaced += count
    path.write_text(text)
if replaced != 3:
    raise SystemExit(f"默认深色配色补丁数量异常：{replaced}，预期为 3")

main_path = root / "StandAlone/src/main.cpp"
text = main_path.read_text()
old_include = "#include <QMutex>\n#include <QSysInfo>"
new_include = "#include <QMutex>\n#include <QSettings>\n#include <QSysInfo>"
if old_include not in text:
    raise SystemExit("main.cpp 中找不到 QSettings 插入位置")
text = text.replace(old_include, new_include, 1)
old_app = "    QApplication app(argc, argv);\n    CliOptions cliOptions;"
new_app = '''    QApplication app(argc, argv);

    if (qEnvironmentVariableIntValue("WEBCAMOID_FORCE_DARK") != 0) {
        QSettings settings;
        settings.beginGroup("ThemeConfigs");
        settings.setValue("paletteName", "Adwaita Dark");
        settings.endGroup();
        settings.sync();
    }

    CliOptions cliOptions;'''
if old_app not in text:
    raise SystemExit("main.cpp 中找不到应用初始化位置")
main_path.write_text(text.replace(old_app, new_app, 1))

media_tools_path = root / "StandAlone/src/mediatools.cpp"
text = media_tools_path.read_text()
old_single_instance = '''bool MediaToolsPrivate::isSecondInstance()
{
#if QT_CONFIG(sharedmemory)
    return !this->m_singleInstanceSM.create(1024)
           && this->m_singleInstanceSM.error() == QSharedMemory::AlreadyExists;
#else
    return false;
#endif
}'''
new_single_instance = '''bool MediaToolsPrivate::isSecondInstance()
{
    return false;
}'''
if old_single_instance not in text:
    raise SystemExit("mediatools.cpp 中找不到 QSharedMemory 单实例检测代码")
media_tools_path.write_text(text.replace(old_single_instance, new_single_instance, 1))

capture_path = root / "libAvKys/Plugins/VideoCapture/src/capture/v4l2sys/src/capturev4l2.cpp"
text = capture_path.read_text()
old_description = '''        if (x_ioctl(fd, VIDIOC_QUERYCAP, &capability) >= 0)
            description = reinterpret_cast<const char *>(capability.card);

        qInfo() << "Detected camera:" << description << "(" << fileName << ")";'''
new_description = '''        if (x_ioctl(fd, VIDIOC_QUERYCAP, &capability) >= 0)
            description = reinterpret_cast<const char *>(capability.card);

        auto normalizedDescription = description.toLower();
        auto driver = QString(reinterpret_cast<const char *>(capability.driver)).toLower();
        if (normalizedDescription.contains("dummy")
            || normalizedDescription.contains("loopback")
            || driver.contains("v4l2loopback")) {
            qInfo() << "Skipping virtual or dummy camera:" << description
                    << "(" << fileName << ")";
            x_close(fd);
            continue;
        }

        qInfo() << "Detected camera:" << description << "(" << fileName << ")";'''
if old_description not in text:
    raise SystemExit("capturev4l2.cpp 中找不到摄像头枚举位置")
text = text.replace(old_description, new_description, 1)
old_set_device = '''void CaptureV4L2::setDevice(const QString &device)
{
    if (this->d->m_device == device)
        return;'''
new_set_device = '''void CaptureV4L2::setDevice(const QString &device)
{
    if (!device.isEmpty()
        && !this->d->m_devices.contains(device)
        && !this->d->m_devices.isEmpty()) {
        this->setDevice(this->d->m_devices.first());
        return;
    }

    if (this->d->m_device == device)
        return;'''
if old_set_device not in text:
    raise SystemExit("capturev4l2.cpp 中找不到设备选择位置")
capture_path.write_text(text.replace(old_set_device, new_set_device, 1))
PY

QMAKE_EXECUTABLE="$(command -v qmake6 || true)"
[[ -n "$QMAKE_EXECUTABLE" ]] || QMAKE_EXECUTABLE=/usr/lib/qt6/bin/qmake
readonly LRELEASE_TOOL=/usr/lib/qt6/bin/lrelease
readonly LUPDATE_TOOL=/usr/lib/qt6/bin/lupdate

[[ -x "$QMAKE_EXECUTABLE" ]] || die "找不到 Qt6 qmake。"
[[ -x "$LRELEASE_TOOL" ]] || die "找不到 Qt6 lrelease。"
[[ -x "$LUPDATE_TOOL" ]] || die "找不到 Qt6 lupdate。"

log "配置并构建 Webcamoid"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$STAGE_DIR" \
  -DQT_QMAKE_EXECUTABLE="$QMAKE_EXECUTABLE" \
  -DLRELEASE_TOOL="$LRELEASE_TOOL" \
  -DLUPDATE_TOOL="$LUPDATE_TOOL" \
  -DDAILY_BUILD=OFF \
  -DNOCHECKUPDATES=ON \
  -DNOFFMPEG=OFF \
  -DNOLIBUVC=OFF \
  -DNOPIPEWIRE=OFF \
  -DNOQTCAMERA=OFF \
  -DNOV4L2=OFF \
  -DNOV4LUTILS=OFF

cmake --build "$BUILD_DIR" --parallel "$(nproc)"
cmake --install "$BUILD_DIR"

readonly WEBCAMOID_BIN="$STAGE_DIR/bin/webcamoid"
[[ -x "$WEBCAMOID_BIN" ]] || die "源码安装后没有找到 webcamoid 可执行文件。"

mapfile -d '' -t STAGE_SHARED_OBJECTS < <(
  find "$STAGE_DIR/lib" -type f \
    \( -name '*.so' -o -name '*.so.*' \) -print0 | sort -z
)
[[ "${#STAGE_SHARED_OBJECTS[@]}" -gt 0 ]] \
  || die "源码安装目录中没有找到 Webcamoid 动态库和插件。"

for required_plugin in \
  VideoCapture_v4l2sys \
  VideoCapture_v4lutils \
  VideoCapture_ffmpeg; do
  plugin_found=0
  for plugin_path in "${STAGE_SHARED_OBJECTS[@]}"; do
    if [[ "$plugin_path" == *"$required_plugin"* ]]; then
      plugin_found=1
      break
    fi
  done
  [[ "$plugin_found" -eq 1 ]] || die "缺少必需插件：$required_plugin"
done

readonly DESKTOP_FILE="$WORK_DIR/webcamoid.desktop"
cat > "$DESKTOP_FILE" <<'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=Webcamoid
Name[zh_CN]=Webcamoid 摄像头
Comment=Webcam capture and effects application
Comment[zh_CN]=摄像头捕获、录像与特效工具
Exec=webcamoid
Icon=webcamoid
Terminal=false
Categories=AudioVideo;Video;
StartupNotify=true
StartupWMClass=webcamoid
DESKTOP_EOF

ICON_FILE="$SOURCE_DIR/StandAlone/share/themes/WebcamoidTheme/icons/hicolor/256x256/webcamoid.png"
if [[ ! -f "$ICON_FILE" ]]; then
  ICON_FILE="$(find "$SOURCE_DIR/StandAlone/share/themes" -type f \
    \( -iname 'webcamoid.png' -o -iname 'webcamoid.svg' \) \
    -print | sort -V | tail -n 1)"
fi
[[ -f "$ICON_FILE" ]] || die "找不到 Webcamoid 图标。"

export APPDIR
export OUTPATH="$OUTDIR"
export OUTNAME="webcamoid.AppImage"
export DESKTOP="$DESKTOP_FILE"
export ICON="$ICON_FILE"
export STARTUPWMCLASS=webcamoid
export DEPLOY_QT=1
export DEPLOY_QML=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_PULSE=1
export DEPLOY_OPENGL=1
export DEPLOY_GSTREAMER=0
export NO_STRIP=1

DEPLOY_INPUTS=(
  "$WEBCAMOID_BIN"
  /usr/bin/ffmpeg
  /usr/bin/ffprobe
  /usr/bin/v4l2-ctl
)
DEPLOY_INPUTS+=("${STAGE_SHARED_OBJECTS[@]}")

mapfile -d '' -t QT_RUNTIME_PLUGINS < <(
  find /usr/lib/qt6/plugins /usr/lib/qt/plugins -type f -name '*.so' \
    \( -path '*/multimedia/*' \
       -o -path '*/styles/*' \
       -o -path '*/platformthemes/*' \) \
    -print0 2>/dev/null | sort -z
)
DEPLOY_INPUTS+=("${QT_RUNTIME_PLUGINS[@]}")

mapfile -d '' -t PRIVATE_RUNTIME_LIBS < <(
  find /usr/lib -type f \
    \( -name 'libpulsecommon-*.so' -o -name 'libpxbackend-*.so' \) \
    -print0 | sort -z
)
for required_private_lib in libpulsecommon- libpxbackend-; do
  private_lib_found=0
  for private_lib in "${PRIVATE_RUNTIME_LIBS[@]}"; do
    if [[ "$(basename "$private_lib")" == "$required_private_lib"* ]]; then
      private_lib_found=1
      break
    fi
  done
  [[ "$private_lib_found" -eq 1 ]] || die "找不到私有运行库：${required_private_lib}*.so"
done
DEPLOY_INPUTS+=("${PRIVATE_RUNTIME_LIBS[@]}")

export LD_LIBRARY_PATH="$STAGE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

log "使用 quick-sharun 收集运行依赖"
quick-sharun "${DEPLOY_INPUTS[@]}"

mkdir -p "$APPDIR/lib" "$APPDIR/share"
cp -a "$STAGE_DIR/lib/." "$APPDIR/lib/"
if [[ -d "$STAGE_DIR/share" ]]; then
  cp -a "$STAGE_DIR/share/." "$APPDIR/share/"
fi

for plugin_root in /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
  [[ -d "$plugin_root" ]] || continue
  for plugin_type in multimedia styles platformthemes; do
    [[ -d "$plugin_root/$plugin_type" ]] || continue
    mkdir -p "$APPDIR/lib/qt/plugins/$plugin_type"
    cp -a "$plugin_root/$plugin_type/." "$APPDIR/lib/qt/plugins/$plugin_type/"
  done
done

for private_lib in "${PRIVATE_RUNTIME_LIBS[@]}"; do
  relative_lib="${private_lib#/usr/lib/}"
  mkdir -p "$APPDIR/lib/$(dirname "$relative_lib")"
  cp -L "$private_lib" "$APPDIR/lib/$relative_lib"
done

find "$APPDIR" \( -type f -o -type l \) -print | while IFS= read -r item; do
  case "$(basename "$item")" in
    libEGL.so*|libGL.so*|libGLX.so*|libGLdispatch.so*|libOpenGL.so*|\
    libgbm.so*|libdrm.so*|libvulkan.so*)
      rm -f "$item"
      ;;
  esac
done
find "$APPDIR" -type d \
  \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

cat >> "$APPDIR/.env" <<'ENV_EOF'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
WEBCAMOID_FORCE_DARK=1
QT_STYLE_OVERRIDE=Adwaita-Dark
QT_MEDIA_BACKEND=ffmpeg
QT_QUICK_BACKEND=rhi
QSG_RHI_BACKEND=opengl
QSG_RENDER_LOOP=basic
QT_OPENGL=desktop
LIBGL_DRIVERS_PATH=
LIBVA_DRIVERS_PATH=
VDPAU_DRIVER_PATH=
__EGL_VENDOR_LIBRARY_DIRS=
__EGL_VENDOR_LIBRARY_FILENAMES=
VK_DRIVER_FILES=
VK_ICD_FILENAMES=
ENV_EOF

"$APPDIR/sharun" -g
mapfile -t APPDIR_LIB_DIRS < <(find "$APPDIR/lib" -type d -print | sort)
APPDIR_LD_LIBRARY_PATH="$(IFS=:; echo "${APPDIR_LIB_DIRS[*]}")"

log "检查摄像头后端和动态库"
for required_plugin in \
  VideoCapture_v4l2sys \
  VideoCapture_v4lutils \
  VideoCapture_ffmpeg; do
  plugin_path="$(find "$APPDIR" -type f -name "*${required_plugin}*.so*" -print -quit)"
  [[ -n "$plugin_path" ]] || die "AppDir 中缺少插件：$required_plugin"
done

if ! ffmpeg -hide_banner -decoders 2>/dev/null \
  | grep -E '[[:space:]]mjpeg[[:space:]]' >/dev/null; then
  die "当前 FFmpeg 没有 MJPEG 解码器。"
fi

missing_file="$WORK_DIR/missing-libraries.txt"
: > "$missing_file"
while IFS= read -r -d '' plugin; do
  LD_LIBRARY_PATH="$APPDIR_LD_LIBRARY_PATH" ldd "$plugin" 2>/dev/null \
    | grep 'not found' >> "$missing_file" || true
done < <(find "$APPDIR/lib/qt/plugins/avkys" -type f -name '*.so*' -print0)

if [[ -s "$missing_file" ]]; then
  sort -u "$missing_file" >&2
  die "Webcamoid 插件仍有缺失动态库。"
fi

log "生成 $OUTFILE"
quick-sharun --make-appimage
[[ -x "$OUTFILE" ]] || die "AppImage 生成失败。"
sha256sum "$OUTFILE" > "$OUTFILE.sha256"

log "已生成：$OUTFILE"
log "版本：$WEBCAMOID_REF"
log "默认界面：简体中文 + Adwaita Dark"
log "默认摄像头：忽略 Dummy/v4l2loopback，选择真实设备"
log "单实例检测：已禁用，直接启动无需 --new-instance"
