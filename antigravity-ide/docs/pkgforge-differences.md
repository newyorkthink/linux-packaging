# Antigravity IDE 官方处理判断

核对日期：2026-10-30。参考仓库：[pkgforge-dev/Antigravity-IDE-AppImage](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage)；源码快照：`d4297876ff865da85f0dff592cc6ab39b51563f0`。官方代码的存在不等于本仓库必须采用，以下依据当前模板、已安装资源及实际构建链逐项判断。

## 采用与不采用

以下“作用”根据命令及本仓库流程说明；除明确引述的内容外，**官方未说明原因**，不得把本仓库的选择理由写成官方原始理由。

| 处理 | 决定 | 当前依据、用途与影响 |
| --- | --- | --- |
| GTK 部署 | 采用标准步骤，命令也与官方相同 | GTK 输入模块依靠标准模板的安装及自动收集，保留 `DEPLOY_GTK=1`，不另加输入法路径。 |
| OpenGL、Vulkan 部署 | 采用并原样复用 | 两项均为原构建已有的图形部署范围；当前仍为图形应用，保留该范围，不引入额外运行开关。官方未说明原因；没有据此宣称硬件加速实测通过。 |
| NSS 模块显式收集 | 采用并原样复用 | 原构建已携带这些动态加载模块，普通 ELF 依赖扫描不足以代表 NSS 按配置加载的模块集合，因此保留显式收集。官方未说明具体故障或选择这些模块的原因。 |
| bwrap 收集 | 不额外加入 | 官方 IDE 收集命令没有该参数；当前未确认独立调用消费者，不以另一个应用的需要作为加入依据。原有 bubblewrap 安装保留，不宣称包内沙箱完整或实测通过。 |
| 单独保留 URL handler | 不采用 | 主 desktop 由系统包提供；独立协议文件没有后续消费者，单独放入 AppImage 不会登记宿主协议。本次不新增宿主登记功能，因此不加 mkdir/sed/cp；浏览器回调未由此实现。 |
| 主 desktop、图标下载 | 不复用这些下载命令 | 标准模板已经先安装应用，直接使用系统包的主 desktop 和图标。它们不是需要再次下载或批量替换的未处理模板；本仓库的系统资源赋值不冒称官方原命令。 |
| 官网解析、下载、解包及版本写入 | 使用公共入口，不直接复用官方命令 | 标准模板已覆盖这些阶段；公共 HTML 下载入口同时记录本次所选 URL 的版本。独立下载、完整复制目录保持不变，不复制系统中的程序文件。 |
| 全系统升级与精简包替换 | 不采用官方命令 | 使用仓库公共基础包及应用依赖安装；当前没有需要 `get-debloated-pkgs` 替换系统包的依据，不额外增加升级和替换阶段。依赖覆盖见 [模板差异](template-deviations.md)。 |
| 自动更新 hook、UPINFO | 不采用 | 当前任务是构建与仓库既有发布流程，未授权增加运行时自更新；官方更新元数据绑定其 GitHub 发布布局，不能作为本仓库的更新地址。 |
| 官方 `--test` 启动 | 不接入脚本 | 本次使用标准模板的封装和版本保存阶段，不额外增加自动运行应用的操作；保留现有仓库构建流程，本次未执行 AppImage。 |
| 强制 `DEPLOY_LOCALE=1` | 不采用 | 属于旧脚本额外配置，当前两份官方脚本没有该开关。标准模板已显式生成包内中文 locale，无须为了旧脚本再强制部署 locale 数据；没有关闭工具自身的默认处理。 |
| `DWARFS_COMP="zstd:level=5"` | 不采用 | 旧脚本自定义压缩，标准模板和当前官方脚本均无此项；没有额外压缩需求，因此使用工具默认设置。 |
| AUR watcher 替换 | 不复制到最终程序 | 当前 AUR PKGBUILD 注明用于修复 watcher 退出故障；系统安装可能包含该处理，但最终程序独立取自官方 tar。本次没有授权修复上游程序，保持原版，不复制系统里的替换文件。 |

协议结论依据本仓库 [AppImage 自定义协议登记说明](../../docs/appimage-scheme-handler.md) 和 [AUR URL handler](https://github.com/archlinux/aur/blob/antigravity-ide/antigravity-ide-url-handler.desktop)：包内文件存在与宿主登记是两件事。此次未采用该收集步骤，不等于断言所有环境都不需要协议功能。

## 当前原样复用的专属代码

来源：[make-appimage.sh](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh)。部署开关位于元数据阶段；收集命令位于读取版本后、生成中文 locale 前。只改进对应中文注释，以下可执行内容不改写：

```bash
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*
```

## 官方源码快照

以下保存本次判断所依据的原始源码，包含采用与未采用内容；它们是记录，不会作为额外脚本执行。后续拟启用未采用项时，只重查该项的当前官方源码及适用性，取得本次加入授权后再接入，禁止直接从旧快照恢复。

### get-dependencies.sh

[固定源码链接](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/get-dependencies.sh)。

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm patchelf libnss_nis nss-mdns nss

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Getting binary..."
echo "---------------------------------------------------------------"

case "$ARCH" in
	x86_64)  farch=x64;;
	aarch64) farch=arm;;
esac

BASE_URL="https://antigravity.google"
link=$(curl -sL --compressed "$BASE_URL/download" | grep -oP "https://edgedl\.me\.gvt1\.com[^\"]+linux-$farch/Antigravity%20IDE\.tar\.gz")

curl -sSfL --retry 30 --retry-connrefused "$link" -o /tmp/temp.tar.gz
echo "$(echo "$link" | grep -oP 'stable/\K[0-9]+\.[0-9]+\.[0-9]+')" > ~/version

mkdir -p ./AppDir/bin ./AppDir/share/applications
curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity-ide.desktop?h=antigravity-ide" | sed 's|^Exec=/usr/bin/|Exec=|g' > ./AppDir/antigravity-ide.desktop
tar -xvzf /tmp/temp.tar.gz --strip-components=1 -C ./AppDir/bin
curl -sL "https://aur.archlinux.org/cgit/aur.git/plain/antigravity-ide-url-handler.desktop?h=antigravity-ide" | sed 's|^Exec=/usr/bin/|Exec=|g' > ./AppDir/share/applications/antigravity-ide-url-handler.desktop
```

### make-appimage.sh

[固定源码链接](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh)。

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON="./AppDir/bin/resources/app/resources/linux/code.png"

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1

quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*
quick-sharun --make-appimage
quick-sharun --test ./dist/*.AppImage
```

## 许可证与验证边界

以上官方源码采用 [MIT 许可证](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/LICENSE)，保留声明如下：

```text
MIT License

Copyright (c) 2025 Package Forge (Dev) 

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
```

静态核对不证明应用启动、图形加速、沙箱或协议回调已通过。此次没有修改上游程序源码，没有实机运行这两款应用。
