#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create AppDir work dist

# 本程序专属处理：固定目标架构和官方资产名称，版本由公共入口动态选择。
ASSET="xberg-cli-x86_64-unknown-linux-gnu.tar.gz"
BUNDLE="xberg-cli-x86_64-unknown-linux-gnu"

# 本程序专属处理：先下载并校验用于构建系统安装的官方 GNU 归档。
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" xberg-io/xberg "$ASSET" work/install.tar.gz >&2

# 本程序专属处理：通过公共入口解包安装来源。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/install.tar.gz work/install

# 本程序专属处理：在隔离的 Arch 构建系统中安装完整目录，避免散放共享库。
install -d /opt/xberg /usr/local/bin
# 本程序专属处理：安装主程序、全部相邻运行库和许可证，保持官方相对布局。
cp -a "work/install/$BUNDLE/." /opt/xberg/
# 本程序专属处理：为本次构建提供系统命令入口。
ln -sfn /opt/xberg/xberg /usr/local/bin/xberg

# 读取本次打包使用的版本。
VERSION="$(
  "$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" xberg-io/xberg "$ASSET" work/xberg.tar.gz
)"

# 本程序专属处理：独立解包最终入包的官方归档，不复制系统安装目录。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/xberg.tar.gz work/package

# 本程序专属处理：准备完整程序目录的目标位置。
mkdir -p AppDir/bin
# 整个程序目录原样放进 AppDir/bin。
cp -a "work/package/$BUNDLE/." AppDir/bin/

# 本程序专属处理：为命令行工具提供桌面元数据，参数仍由真实程序解析。
cat > work/xberg.desktop <<'EOF_DESKTOP'
[Desktop Entry]
Type=Application
Name=Xberg
Comment=Extract document text, tables and metadata
Exec=xberg
Icon=xberg
Terminal=true
Categories=Utility;ConsoleOnly;
EOF_DESKTOP

# 本程序专属处理：复制独立维护的官方 SVG 图标到本次工作区。
cp -a "$SCRIPT_DIR/patched/xberg.svg" work/xberg.svg

# 本程序专属处理：复制独立维护的品牌资源 MIT 许可证到本次工作区。
cp -a "$SCRIPT_DIR/patched/branding-LICENSE" work/branding-LICENSE

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 本程序专属处理：使用本次准备的官方 SVG 图标。
export ICON="$SCRIPT_DIR/work/xberg.svg"
# 本程序专属处理：使用本次生成的命令行 desktop。
export DESKTOP="$SCRIPT_DIR/work/xberg.desktop"
# 包里的真实程序名。
export MAIN_BIN=xberg
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=xberg.AppImage
# 本程序专属处理：将同次最终归档的版本传入 AppImage 元数据。
export VERSION

# 收集程序及其运行依赖。
quick-sharun ./AppDir/bin/*

# 本程序专属处理：保留程序及配套品牌资源的许可证。
mkdir -p AppDir/share/licenses/xberg AppDir/share/licenses/xberg-branding
# 本程序专属处理：复制官方程序许可证和第三方许可清单。
cp -a "work/package/$BUNDLE/LICENSE" "work/package/$BUNDLE/THIRD_PARTY_LICENSES.md" AppDir/share/licenses/xberg/
# 本程序专属处理：复制官方品牌资源的 MIT 许可证。
cp -a work/branding-LICENSE AppDir/share/licenses/xberg-branding/LICENSE

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/xberg.AppImage "$VERSION" dist/version.txt
