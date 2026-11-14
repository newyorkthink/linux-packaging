#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装源码编译及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" xorg-server xorg-server-common xorg-server-xvfb libx11 libxmu libxft libxrender libxrandr libpng libxpm uthash

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

# 设置本次构建使用的源码目录。
SOURCE_DIR="$SCRIPT_DIR/work/source"

# 读取本次打包使用的版本。
ALTTAB_TAG="$(
  bash "$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" sagb/alttab "$SOURCE_DIR" --archive
)"

# 去掉常见的 v 前缀，作为 AppImage 版本信息；没有 v 前缀时保持原值。
ALTTAB_VERSION="${ALTTAB_TAG#v}"

# 本程序专属处理：保留源码补丁和构建逻辑参与更新版本计算的机制。
# AltTab 带有仓库维护的源码补丁，同一上游版本下补丁或打包逻辑变化也必须触发更新。
# 构建脚本先忽略空行和纯注释行，避免只改说明文字就产生新的更新版本；patch 内容按原字节参与指纹。
normalize_fingerprint_script() {
  sed -E '/^[[:space:]]*(#|$)/d' "$1"
}

ALTTAB_BUILD_FINGERPRINT="$(
  {
    normalize_fingerprint_script "$SCRIPT_DIR/build_alttab.sh"
    normalize_fingerprint_script "$SCRIPT_DIR/patches/apply-icon-patch.sh"

    while IFS= read -r patch_file; do
      printf '%s\0' "${patch_file#"$SCRIPT_DIR"/}"
      cat "$patch_file"
    done < <(
      find "$SCRIPT_DIR/patches" -maxdepth 1 -type f -name '*.patch' -print |
        LC_ALL=C sort
    )
  } | sha256sum | awk '{print substr($1, 1, 12)}'
)"

# software_versions.json 使用“上游版本 + 构建指纹”识别本仓库实际发布版本。
ALTTAB_UPDATE_VERSION="${ALTTAB_VERSION}+linuxpackaging.${ALTTAB_BUILD_FINGERPRINT}"
# 本程序专属处理：输出本仓库用于更新判断的版本。
printf 'AltTab update version: %s\n' "$ALTTAB_UPDATE_VERSION"

# 本程序专属处理：按原顺序应用全部独立补丁，任一补丁不匹配时立即停止。
bash "$SCRIPT_DIR/patches/apply-icon-patch.sh" "$SOURCE_DIR"

# 本程序专属处理：传入 GLib 头文件与链接参数，保留现有 configure 和 make 命令。
ALTTAB_GLIB_CFLAGS="$(pkg-config --cflags glib-2.0)"
ALTTAB_GLIB_LIBS="$(pkg-config --libs glib-2.0)"
export CPPFLAGS="${CPPFLAGS:-} $ALTTAB_GLIB_CFLAGS"
export LIBS="${LIBS:-} $ALTTAB_GLIB_LIBS"

# 本程序专属处理：配置 alttab，保持标准 /usr 安装前缀。
(
  cd "$SOURCE_DIR"
  ./configure --prefix=/usr
)

# 本程序专属处理：编译 alttab。
make -C "$SOURCE_DIR" -j"$(nproc)"

# 本程序专属处理：创建 AppImage 使用的 desktop 文件；alttab 是 X11 常驻窗口切换器。
cat > "$SCRIPT_DIR/work/alttab.desktop" <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=AltTab
Comment=X11 window switcher for minimalistic window managers
Exec=alttab
Icon=alttab
Terminal=false
Categories=Utility;
StartupNotify=false
StartupWMClass=AltTab
EOF_DESKTOP

# 校验 desktop 文件语法。
desktop-file-validate "$SCRIPT_DIR/work/alttab.desktop"

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：使用上游 SVG 图标。
export ICON="$SOURCE_DIR/doc/alttab.svg"
# 本程序专属处理：使用本次生成的 desktop 文件。
export DESKTOP="$SCRIPT_DIR/work/alttab.desktop"
# 包里的真实程序名。
export MAIN_BIN=alttab
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME="alttab.AppImage"

# 本程序专属处理：AppImage 内部保留纯上游版本号。
export VERSION="$ALTTAB_VERSION"

# 收集程序及其运行依赖。
quick-sharun "$SOURCE_DIR/src/alttab"

# 本程序专属处理：将上游 GPL-3.0 许可证随 AppImage 一并保留。
mkdir -p AppDir/share/licenses/alttab
# 本程序专属处理：复制上游许可证到包内对应目录。
cp -a "$SOURCE_DIR/COPYING" AppDir/share/licenses/alttab/COPYING

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/alttab.AppImage "$ALTTAB_UPDATE_VERSION" dist/version.txt
