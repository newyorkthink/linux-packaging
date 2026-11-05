#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 本仓库兼容处理：卸掉会抢占完整 FFmpeg 的 ffmpeg-mini。
if pacman -Q ffmpeg-mini >/dev/null 2>&1; then
  if [[ "$EUID" -eq 0 ]]; then
    pacman -Rdd --noconfirm ffmpeg-mini
  else
    sudo pacman -Rdd --noconfirm ffmpeg-mini
  fi
fi

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" xorg-server-xvfb ffmpeg libuvc v4l-utils libusb alsa-lib libpulse libproxy pipewire qt6-base qt6-declarative qt6-multimedia qt6-svg qt6-tools qt6-wayland qt6-imageformats qt6-shadertools qt6ct kvantum lxqt-qtplugin adwaita-qt6 fcitx5-qt libglvnd mesa libx11 libxext libxfixes libxrender libxcb libxkbcommon-x11 xcb-util xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xcb-util-cursor

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

# 读取本次打包使用的版本。
VERSION="$(bash "$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" webcamoid/webcamoid work/source)"

# 本仓库兼容处理：补上默认深色主题、真实摄像头优先，并跳过用不上的硬件编码器探测。
python3 patches/default_dark_theme.py work/source
python3 patches/disable_single_instance.py work/source
python3 patches/prefer_real_camera.py work/source
python3 patches/skip_hardware_encoders.py work/source

# 定位 Qt6 的 qmake，找不到就用发行版路径。
QMAKE_EXECUTABLE="$(command -v qmake6 || true)"
[[ -n "$QMAKE_EXECUTABLE" ]] || QMAKE_EXECUTABLE=/usr/lib/qt6/bin/qmake

# 本仓库兼容处理：关闭没有运行库的 GStreamer、加载失败的 wlroots，以及会打开 Dummy 设备的 libavdevice。
cmake -S work/source -B work/build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$SCRIPT_DIR/work/stage" -DQT_QMAKE_EXECUTABLE="$QMAKE_EXECUTABLE" -DLRELEASE_TOOL=/usr/lib/qt6/bin/lrelease -DLUPDATE_TOOL=/usr/lib/qt6/bin/lupdate -DDAILY_BUILD=OFF -DNOCHECKUPDATES=ON -DNOFFMPEG=OFF -DNOGSTREAMER=ON -DNOLIBAVDEVICE=ON -DNOLIBUVC=OFF -DNOPIPEWIRE=OFF -DNOQTCAMERA=OFF -DNOV4L2=OFF -DNOV4LUTILS=OFF -DNOWLROOTS=ON
cmake --build work/build --parallel "$(nproc)"
cmake --install work/build

# 本仓库兼容处理：去掉加载失败的桌面捕获 PipeWire 插件。音频 PipeWire 保留。
find work/stage -type f \( -name 'libDesktopCapture_pipewire.so*' -o -name 'libDesktopCapture_wlroots.so*' -o -name '*[Gg]streamer*.so*' \) -delete

# 本仓库兼容处理：源码安装没有系统桌面入口，生成临时 desktop 文件。
cat > work/webcamoid.desktop <<'DESKTOP_EOF'
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

# 本仓库兼容处理：优先用源码主题里的 256 图标，没有再从主题目录里找。
ICON="work/source/StandAlone/share/themes/WebcamoidTheme/icons/hicolor/256x256/webcamoid.png"
if [[ ! -f "$ICON" ]]; then
  ICON="$(find work/source/StandAlone/share/themes -type f \( -iname 'webcamoid.png' -o -iname 'webcamoid.svg' \) -print | sort -V | tail -n 1)"
fi

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本仓库兼容处理：使用上面选出的源码图标。
export ICON
# 本仓库兼容处理：使用构建时生成的桌面入口。
export DESKTOP="$SCRIPT_DIR/work/webcamoid.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=webcamoid.AppImage
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=webcamoid
# 官方包依赖 qt6-base，打包时打入 Qt。
export DEPLOY_QT=1
# 本仓库兼容处理：界面是 QML，打包时打入 Qt Quick。
export DEPLOY_QML=1
# 官方包依赖 libpipewire，打包时打入 PipeWire。
export DEPLOY_PIPEWIRE=1
# 本仓库兼容处理：录音走 PulseAudio，打包时打入 Pulse。
export DEPLOY_PULSE=1
# 官方包依赖 libglvnd，打包时打入 OpenGL。
export DEPLOY_OPENGL=1
# 本仓库兼容处理：不打入 GStreamer。插件编了，运行库没带。
export DEPLOY_GSTREAMER=0
# 本仓库兼容处理：不剥离符号，避免插件加载失败。
export NO_STRIP=1

# 本仓库兼容处理：源码安装出的动态库和插件不在系统路径里，交给 quick-sharun 一起收集。
mapfile -d '' -t STAGE_SHARED_OBJECTS < <(find work/stage/lib -type f \( -name '*.so' -o -name '*.so.*' \) -print0 | sort -z)
# 本仓库兼容处理：补上多媒体、样式和平台主题插件，普通依赖扫描带不走。
mapfile -d '' -t QT_RUNTIME_PLUGINS < <(find /usr/lib/qt6/plugins /usr/lib/qt/plugins -type f -name '*.so' \( -path '*/multimedia/*' -o -path '*/styles/*' -o -path '*/platformthemes/*' \) -print0 2>/dev/null | sort -z)
# 本仓库兼容处理：补上 PulseAudio 和 libproxy 的私有库，依赖扫描看不到。
mapfile -d '' -t PRIVATE_RUNTIME_LIBS < <(find /usr/lib -type f \( -name 'libpulsecommon-*.so' -o -name 'libpxbackend-*.so' \) -print0 | sort -z)
# 本仓库兼容处理：让依赖扫描先看到源码安装目录里的库。
export LD_LIBRARY_PATH="work/stage/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 收集程序及其运行依赖。
quick-sharun work/stage/bin/webcamoid /usr/bin/ffmpeg /usr/bin/ffprobe /usr/bin/v4l2-ctl "${STAGE_SHARED_OBJECTS[@]}" "${QT_RUNTIME_PLUGINS[@]}" "${PRIVATE_RUNTIME_LIBS[@]}"

# 本仓库兼容处理：把源码安装出的插件、Qt 插件和私有库补进包内。
mkdir -p AppDir/lib AppDir/share
cp -a work/stage/lib/. AppDir/lib/
if [[ -d work/stage/share ]]; then
  cp -a work/stage/share/. AppDir/share/
fi
for plugin_root in /usr/lib/qt6/plugins /usr/lib/qt/plugins; do
  [[ -d "$plugin_root" ]] || continue
  for plugin_type in multimedia styles platformthemes; do
    [[ -d "$plugin_root/$plugin_type" ]] || continue
    mkdir -p "AppDir/lib/qt/plugins/$plugin_type"
    cp -a "$plugin_root/$plugin_type/." "AppDir/lib/qt/plugins/$plugin_type/"
  done
done
for private_lib in "${PRIVATE_RUNTIME_LIBS[@]}"; do
  relative_lib="${private_lib#/usr/lib/}"
  mkdir -p "AppDir/lib/$(dirname "$relative_lib")"
  cp -L "$private_lib" "AppDir/lib/$relative_lib"
done

# 本仓库兼容处理：不带宿主的 EGL、OpenGL 和 Vulkan 驱动。
find AppDir \( -type f -o -type l \) -print | while IFS= read -r item; do
  case "$(basename "$item")" in
    libEGL.so*|libGL.so*|libGLX.so*|libGLdispatch.so*|libOpenGL.so*|libgbm.so*|libdrm.so*|libvulkan.so*)
      rm -f "$item"
      ;;
  esac
done
find AppDir -type d \( -name dri -o -path '*/glvnd/egl_vendor.d' -o -path '*/vulkan/icd.d' \) -prune -exec rm -rf {} + 2>/dev/null || true

# 本仓库兼容处理：默认深色，并清掉宿主显卡驱动路径。
cat >> AppDir/.env <<'ENV_EOF'
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

# 本仓库兼容处理：补进插件和私有库后重新生成库路径。
AppDir/sharun -g

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/webcamoid.AppImage "$VERSION" dist/version.txt
