#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" "dconf-editor"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" curl dconf-cli dconf-editor dconf-gsettings-backend fcitx5-frontend-gtk3 jq libgdk-pixbuf2.0-bin libgtk-3-bin libgtk-3-dev librsvg2-bin pkgconf locales language-pack-gnome-zh-hans-base python3

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "dconf-editor" "$APPDIR" dconf-cli)"

########## 准备桌面资源和运行库 #########

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.UTF-8"

# 本程序专属处理：创建包内翻译目录。
mkdir -p "$APPDIR/usr/share/locale"

# 本程序专属处理：将 Ubuntu 简体中文译文放入包内翻译目录。
cp -a "/usr/share/locale-langpack/zh_CN" "$APPDIR/usr/share/locale/zh_CN"

############# 准备 AppRun ##############

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# GTK 运行环境：指定 GSettings schema 和 GIO 动态模块的目录。
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
export GIO_MODULE_DIR="$HERE/usr/lib/x86_64-linux-gnu/gio/modules"

# 设置简体中文界面环境。
export LOCPATH="$HERE/usr/lib/locale${LOCPATH:+:$LOCPATH}"
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 本程序专属处理：统一使用包内的简体中文 locale。
export LC_ALL=zh_CN.UTF-8

# 本程序专属处理：切换到包内根目录，使程序能读取相对路径下的译文。
cd "$HERE"

# 本程序专属处理：清除 GSETTINGS_SCHEMA_DIR，避免读取 schema 路径时发生越界。
# 启动包内程序，并保留传入的命令行参数。
exec env -u GSETTINGS_SCHEMA_DIR "$HERE/usr/bin/dconf-editor" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"

############### 核心打包 ###############

# 指定 GTK 主版本。
export DEPLOY_GTK_VERSION=3

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage

############### 整理产物 ###############

# 本程序专属处理：将 AppImage 内 ELF 的绝对 locale 路径改成相对路径。
# AppRun 会先 cd 到 AppImage 根目录，因此 usr/share/locale 会稳定解析为 AppImage 内置中文目录。
PATCH_APPDIR="$APPDIR" python3 <<'PY'
from pathlib import Path
import os

appdir = Path(os.environ["PATCH_APPDIR"])
elf_magic = b"\x7fELF"
replacements = (
    (b"/usr/share/locale-langpack\x00", b"usr/share/locale\x00"),
    (b"/usr/share/locale\x00", b"usr/share/locale\x00"),
)
patched = []

for path in appdir.rglob("*"):
    if not path.is_file() or path.is_symlink():
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    if not data.startswith(elf_magic):
        continue

    original = data
    for old, new in replacements:
        if old not in data:
            continue
        if len(new) > len(old):
            raise SystemExit(f"replacement is longer than source for {path}")
        padded = new + (b"\x00" * (len(old) - len(new)))
        data = data.replace(old, padded)

    if data != original:
        path.write_bytes(data)
        patched.append(str(path.relative_to(appdir)))

if "usr/bin/dconf-editor" not in patched:
    raise SystemExit("dconf-editor 主程序没有发现可重定位的 locale 路径")

print("已重定位 locale 路径的 ELF：")
for item in patched:
    print(item)
PY

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION"
