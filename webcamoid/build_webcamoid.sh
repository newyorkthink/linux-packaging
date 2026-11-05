#!/usr/bin/env bash
# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 从最新稳定 Release 源码构建，不拉取私有 ExtraPlugins。
# 输出 dist/webcamoid.AppImage。保留 V4L2 摄像头和软件编码。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
cd "$SCRIPT_DIR"

die() {
  echo "错误：$*" >&2
  exit 1
}

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"

if pacman -Q ffmpeg-mini >/dev/null 2>&1; then
  if [[ "$EUID" -eq 0 ]]; then
    pacman -Rdd --noconfirm ffmpeg-mini
  else
    sudo pacman -Rdd --noconfirm ffmpeg-mini
  fi
fi

# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" \
  xorg-server-xvfb \
  ffmpeg libuvc v4l-utils libusb alsa-lib libpulse libproxy pipewire \
  qt6-base qt6-declarative qt6-multimedia qt6-svg qt6-tools qt6-wayland \
  qt6-imageformats qt6-shadertools qt6ct kvantum lxqt-qtplugin adwaita-qt6 fcitx5-qt \
  libglvnd mesa libx11 libxext libxfixes libxrender libxcb \
  libxkbcommon-x11 xcb-util xcb-util-image xcb-util-keysyms \
  xcb-util-renderutil xcb-util-wm xcb-util-cursor

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

WEBCAMOID_REF="$(
  bash "$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" \
    webcamoid/webcamoid \
    "$SCRIPT_DIR/work/source"
)"
printf '%s\n' "$WEBCAMOID_REF" > "$SCRIPT_DIR/dist/version.txt"

# 补上默认深色主题、真实摄像头优先，并跳过用不上的硬件编码器探测。
python3 "$SCRIPT_DIR/patches/default_dark_theme.py" "$SCRIPT_DIR/work/source"
python3 "$SCRIPT_DIR/patches/disable_single_instance.py" "$SCRIPT_DIR/work/source"
python3 "$SCRIPT_DIR/patches/prefer_real_camera.py" "$SCRIPT_DIR/work/source"
python3 "$SCRIPT_DIR/patches/skip_hardware_encoders.py" "$SCRIPT_DIR/work/source"

QMAKE_EXECUTABLE="$(command -v qmake6 || true)"
[[ -n "$QMAKE_EXECUTABLE" ]] || QMAKE_EXECUTABLE=/usr/lib/qt6/bin/qmake

# 关闭没有运行库的 GStreamer、加载失败的 wlroots，以及会打开 Dummy 设备的 libavdevice。
cmake -S "$SCRIPT_DIR/work/source" -B "$SCRIPT_DIR/work/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$SCRIPT_DIR/work/stage" \
  -DQT_QMAKE_EXECUTABLE="$QMAKE_EXECUTABLE" \
  -DLRELEASE_TOOL=/usr/lib/qt6/bin/lrelease \
  -DLUPDATE_TOOL=/usr/lib/qt6/bin/lupdate \
  -DDAILY_BUILD=OFF \
  -DNOCHECKUPDATES=ON \
  -DNOFFMPEG=OFF \
  -DNOGSTREAMER=ON \
  -DNOLIBAVDEVICE=ON \
  -DNOLIBUVC=OFF \
  -DNOPIPEWIRE=OFF \
  -DNOQTCAMERA=OFF \
  -DNOV4L2=OFF \
  -DNOV4LUTILS=OFF \
  -DNOWLROOTS=ON

cmake --build "$SCRIPT_DIR/work/build" --parallel "$(nproc)"
cmake --install "$SCRIPT_DIR/work/build"

# 去掉加载失败的桌面捕获 PipeWire 插件。音频 PipeWire 保留。
find "$SCRIPT_DIR/work/stage" -type f \( \
  -name 'libDesktopCapture_pipewire.so*' -o \
  -name 'libDesktopCapture_wlroots.so*' -o \
  -name '*[Gg]streamer*.so*' \
\) -delete

[[ -x "$SCRIPT_DIR/work/stage/bin/webcamoid" ]] || die "源码安装后没有找到 webcamoid 可执行文件。"

mapfile -d '' -t STAGE_SHARED_OBJECTS < <(
  find "$SCRIPT_DIR/work/stage/lib" -type f \
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

cat > "$SCRIPT_DIR/work/webcamoid.desktop" <<'DESKTOP_EOF'
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

ICON_FILE="$SCRIPT_DIR/work/source/StandAlone/share/themes/WebcamoidTheme/icons/hicolor/256x256/webcamoid.png"
if [[ ! -f "$ICON_FILE" ]]; then
  ICON_FILE="$(find "$SCRIPT_DIR/work/source/StandAlone/share/themes" -type f \
    \( -iname 'webcamoid.png' -o -iname 'webcamoid.svg' \) \
    -print | sort -V | tail -n 1)"
fi
[[ -f "$ICON_FILE" ]] || die "找不到 Webcamoid 图标。"

# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="webcamoid.AppImage"
export DESKTOP="$SCRIPT_DIR/work/webcamoid.desktop"
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
  "$SCRIPT_DIR/work/stage/bin/webcamoid"
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

export LD_LIBRARY_PATH="$SCRIPT_DIR/work/stage/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 收集程序及其运行依赖。
quick-sharun "${DEPLOY_INPUTS[@]}"

mkdir -p "$SCRIPT_DIR/AppDir/lib" "$SCRIPT_DIR/AppDir/share"
cp -a "$SCRIPT_DIR/work/stage/lib/." "$SCRIPT_DIR/AppDir/lib/"
if [[ -d "$SCRIPT_DIR/work/stage/share" ]]; then
  cp -a "$SCRIPT_DIR/work/stage/share/." "$SCRIPT_DIR/AppDir/share/"
fi

for plugin_root in /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
  [[ -d "$plugin_root" ]] || continue
  for plugin_type in multimedia styles platformthemes; do
    [[ -d "$plugin_root/$plugin_type" ]] || continue
    mkdir -p "$SCRIPT_DIR/AppDir/lib/qt/plugins/$plugin_type"
    cp -a "$plugin_root/$plugin_type/." "$SCRIPT_DIR/AppDir/lib/qt/plugins/$plugin_type/"
  done
done

for private_lib in "${PRIVATE_RUNTIME_LIBS[@]}"; do
  relative_lib="${private_lib#/usr/lib/}"
  mkdir -p "$SCRIPT_DIR/AppDir/lib/$(dirname "$relative_lib")"
  cp -L "$private_lib" "$SCRIPT_DIR/AppDir/lib/$relative_lib"
done

find "$SCRIPT_DIR/AppDir" \( -type f -o -type l \) -print | while IFS= read -r item; do
  case "$(basename "$item")" in
    libEGL.so*|libGL.so*|libGLX.so*|libGLdispatch.so*|libOpenGL.so*|\
    libgbm.so*|libdrm.so*|libvulkan.so*)
      rm -f "$item"
      ;;
  esac
done
find "$SCRIPT_DIR/AppDir" -type d \
  \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

cat >> "$SCRIPT_DIR/AppDir/.env" <<'ENV_EOF'
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

"$SCRIPT_DIR/AppDir/sharun" -g
mapfile -t APPDIR_LIB_DIRS < <(find "$SCRIPT_DIR/AppDir/lib" -type d -print | sort)
APPDIR_LD_LIBRARY_PATH="$(IFS=:; echo "${APPDIR_LIB_DIRS[*]}")"

for required_plugin in \
  VideoCapture_v4l2sys \
  VideoCapture_v4lutils \
  VideoCapture_ffmpeg; do
  plugin_path="$(find "$SCRIPT_DIR/AppDir" -type f -name "*${required_plugin}*.so*" -print -quit)"
  [[ -n "$plugin_path" ]] || die "AppDir 中缺少插件：$required_plugin"
done

if ! ffmpeg -hide_banner -decoders 2>/dev/null \
  | grep -E '[[:space:]]mjpeg[[:space:]]' >/dev/null; then
  die "当前 FFmpeg 没有 MJPEG 解码器。"
fi

missing_file="$SCRIPT_DIR/work/missing-libraries.txt"
: > "$missing_file"
while IFS= read -r -d '' plugin; do
  LD_LIBRARY_PATH="$APPDIR_LD_LIBRARY_PATH" ldd "$plugin" 2>/dev/null \
    | grep 'not found' >> "$missing_file" || true
done < <(find "$SCRIPT_DIR/AppDir/lib/qt/plugins/avkys" -type f -name '*.so*' -print0)

if [[ -s "$missing_file" ]]; then
  sort -u "$missing_file" >&2
  die "Webcamoid 插件仍有缺失动态库。"
fi

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage
# 确认最终 AppImage 非空可执行，并写出 SHA-256。
"$SCRIPT_DIR/../common/build/check_appimage_artifact.sh" \
  "$SCRIPT_DIR/dist/webcamoid.AppImage" \
  "$SCRIPT_DIR/dist/webcamoid.AppImage.sha256"
