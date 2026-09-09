#!/usr/bin/env bash
set -e

rm -rf AppDir dist || true

ARCH="$(uname -m)"
export ARCH

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: this script only supports x86_64."
  exit 1
fi

export APPNAME="Free Download Manager"
export STARTUPWMCLASS="Free Download Manager"
export ICON="/opt/freedownloadmanager/icon.png"
export DESKTOP="/usr/share/applications/freedownloadmanager.desktop"
export OUTPATH=./dist
export OUTNAME="freedownloadmanager.AppImage"

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_QT=1
export DEPLOY_LOCALE=1

# 基础打包工具
yay -S --noconfirm \
  gcc base-devel debugedit wget curl tar gzip xz binutils patchelf coreutils \
  appstream-glib desktop-file-utils util-linux zsync \
  xorg-server xorg-server-common xorg-server-xvfb

# FDM AUR 当前可能 sha256 校验失效，临时跳过完整性校验
yay -S --noconfirm --mflags "--skipinteg" freedownloadmanager

# FDM 运行依赖
yay -S --noconfirm \
  ffmpeg gst-plugins-base libtorrent openssl qt6-wayland xdg-utils \
  nss nspr \
  glib2 glibc gcc-libs zlib ca-certificates \
  libx11 libxext libxi libxtst libxss libxrandr libxinerama \
  libxcomposite libxdamage libxfixes libxcb libxkbcommon libxkbcommon-x11 \
  mesa libglvnd libva libvdpau vulkan-icd-loader \
  alsa-lib pulseaudio pulseaudio-alsa pipewire-audio \
  gtk3 ibus fcitx5-qt shared-mime-info hicolor-icon-theme adwaita-icon-theme \
  fontconfig freetype2 harfbuzz cairo pango gdk-pixbuf2 librsvg \
  qt6-base qt6-declarative qt6-svg qt6-multimedia \
  qt6ct kvantum lxqt-qtplugin

###### 核心打包 ######

FDM_LIB_DIR="/opt/freedownloadmanager/lib"

# FDM 的下载模块由主程序按需加载，启动阶段不会全部触发；quick-sharun 只接收文件，因此显式收集这些运行库。
mapfile -t FDM_RUNTIME_LIBS < <(
  find "$FDM_LIB_DIR" -maxdepth 1 \
    \( -type f -o -type l \) \
    \( -name 'libdownloads*.so*' \
       -o -name 'liblogger.so*' \
       -o -name 'libvmsclshared.so*' \
       -o -name 'libquazip.so*' \) \
    -print | sort
)

if [ "${#FDM_RUNTIME_LIBS[@]}" -eq 0 ]; then
  echo "Error: FDM runtime libraries were not found."
  exit 1
fi

# 解析 FDM 私有库时优先使用系统 Qt/OpenSSL，只在系统没有对应 SONAME 时回退到 FDM 私有目录。
FDM_DEPLOY_LD_LIBRARY_PATH="/usr/lib:$FDM_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 在进入 quick-sharun 前检查主程序与全部 FDM 私有运行库，避免遗漏依赖后继续生成残缺 AppImage。
FDM_LDD_OUTPUT="$(
  LD_LIBRARY_PATH="$FDM_DEPLOY_LD_LIBRARY_PATH" \
    ldd /opt/freedownloadmanager/fdm "${FDM_RUNTIME_LIBS[@]}" 2>&1 || true
)"

if grep -q '=> not found' <<<"$FDM_LDD_OUTPUT"; then
  echo "Error: unresolved FDM runtime libraries:" >&2
  printf '%s\n' "$FDM_LDD_OUTPUT" >&2
  exit 1
fi

# 保留标准入口，显式带入 FDM 按需运行库、Qt6 输入模块及网络状态检测后端。
LD_LIBRARY_PATH="$FDM_DEPLOY_LD_LIBRARY_PATH" \
quick-sharun \
  /opt/freedownloadmanager/fdm \
  "${FDM_RUNTIME_LIBS[@]}" \
  /usr/bin/xdg-open \
  /usr/lib/qt6/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so \
  /usr/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so \
  /usr/lib/qt6/plugins/networkinformation/libqnetworkmanager.so \
  /usr/lib/qt6/plugins/networkinformation/libqglib.so \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/*

###### 恢复 FDM 私有模块相对路径 ######

# FDM 会按真实主程序目录下的 lib/ 查找下载模块；恢复上游 fdm + lib/ 的相对布局，不增加自定义启动逻辑。
ln -s ../../lib/freedownloadmanager/lib AppDir/shared/bin/lib

###### 保留 FDM 翻译资源 ######

# FDM 翻译是非 ELF 资源，需另行保留完整目录。
cp -a /opt/freedownloadmanager/translations AppDir/shared/bin/

# 标准 sharun 入口与真实程序共用同一份翻译，不增加启动脚本。
ln -s ../shared/bin/translations AppDir/bin/translations

###### 配置中文环境 ######

# 生成 AppImage 自带的简体中文 UTF-8 locale，不依赖宿主机是否已生成 zh_CN.UTF-8
mkdir -p AppDir/lib/locale
localedef --no-archive \
  -i zh_CN \
  -f UTF-8 \
  AppDir/lib/locale/zh_CN.utf8

# 固定界面消息优先使用简体中文；输入法类型仍由宿主会话选择
cat >> AppDir/.env <<'EOF_LOCALE'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF_LOCALE

quick-sharun --make-appimage
