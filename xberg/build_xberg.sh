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

# 本程序专属处理：使用官方原始品牌图标，保留 SVG 正文和内嵌图像。
cat > work/xberg.svg <<'EOF_ICON'
<svg
  xmlns="http://www.w3.org/2000/svg"
  viewBox="0 0 169 169"
  width="169"
  height="169"
  role="img"
  aria-label="Xberg Rotated Junction V5 monochrome black"
>
  <title>Xberg Rotated Junction V5 monochrome black</title>

  <image
    href="data:image/png;base64,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"
    x="0"
    y="0"
    width="169"
    height="169"
  />
</svg>
EOF_ICON

# 本程序专属处理：保留品牌资源的 MIT 许可证正文。
cat > work/branding-LICENSE <<'EOF_BRANDING_LICENSE'
MIT License

Copyright (c) 2025-2026 Kreuzberg, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF_BRANDING_LICENSE

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
