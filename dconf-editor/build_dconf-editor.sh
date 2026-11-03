#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

EXPECTED_DCONF_EDITOR_VERSION="45.0.1"
MAX_ALLOWED_GLIBC_VERSION="2.39"

# 本程序专属处理：确认构建环境固定为 Ubuntu 24.04，防止发行版变化再次抬高运行基线。
source /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] || {
  echo "错误：此脚本必须在 Ubuntu 24.04 构建，当前为 ${PRETTY_NAME:-unknown}。" >&2
  exit 1
}

############# 准备构建目录 #############

# 设置构建路径，并清理、重建当前应用的 source、AppDir 和 dist 目录。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_build_workspace.sh" "$SCRIPT_DIR" dconf-editor

DESKTOP_FILE="/usr/share/applications/ca.desrt.dconf-editor.desktop"
SMOKE_LOG="$SOURCE_DIR/dconf-editor-smoke.log"

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" binutils ca-certificates curl dbus dconf-cli dconf-editor dconf-gsettings-backend dconf-service desktop-file-utils fcitx5-frontend-gtk3 file gettext jq language-pack-gnome-zh-hans-base libgdk-pixbuf2.0-bin libglib2.0-bin libgtk-3-bin libgtk-3-dev librsvg2-bin locales patchelf pkgconf python3 squashfs-tools xauth xvfb

############# 下载打包工具 #############

# 下载并校验打包工具及所需插件，随后加载构建环境配置。
source "$SCRIPT_DIR/../common/linuxdeploy/prepare_linuxdeploy_tools.sh" "$TOOLS_DIR" gtk "$INTERMEDIATE_APPIMAGE" "$RUNTIME_FILE"

############ 初始化 AppDir #############

# 首次运行 linuxdeploy，创建 AppDir 的基础目录。
"$SCRIPT_DIR/../common/linuxdeploy/initialize_appdir.sh" "$APPDIR" "$TOOLS_DIR/linuxdeploy"

############ 下载并准备应用 #############

# 本程序专属处理：固定 dconf Editor 主版本；Ubuntu 安全更新允许包修订号变化，但程序版本必须保持 45.0.1。
INSTALLED_DCONF_EDITOR_VERSION="$(dpkg-query -W -f='${Version}' dconf-editor)"
[[ "$INSTALLED_DCONF_EDITOR_VERSION" == "$EXPECTED_DCONF_EDITOR_VERSION"-* ]] || {
  echo "错误：dconf-editor 版本不是预期的 $EXPECTED_DCONF_EDITOR_VERSION，当前为 $INSTALLED_DCONF_EDITOR_VERSION。" >&2
  exit 1
}

# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。
VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" dconf-editor "$APPDIR" dconf-cli)"

# 本程序专属处理：生成简体中文 UTF-8 locale，供构建阶段的翻译完整性检查和无界面启动测试使用。
sudo locale-gen zh_CN.UTF-8
locale -a | grep -Eiq '^zh_CN\.utf-?8$' || {
  echo "错误：zh_CN.UTF-8 locale 未生成。" >&2
  exit 1
}

# 本程序专属处理：确认 dconf Editor GUI、dconf CLI 和 desktop 文件存在。
[[ -x /usr/bin/dconf-editor ]] || {
  echo "错误：找不到 /usr/bin/dconf-editor。" >&2
  exit 1
}
[[ -x /usr/bin/dconf ]] || {
  echo "错误：找不到 /usr/bin/dconf。" >&2
  exit 1
}
[[ -f "$DESKTOP_FILE" ]] || {
  echo "错误：找不到 $DESKTOP_FILE。" >&2
  exit 1
}

# 本程序专属处理：自动选择发行版实际提供的 dconf Editor 图标，兼容 PNG 与 SVG 布局。
ICON_FILE=""
for candidate in \
  /usr/share/icons/hicolor/scalable/apps/ca.desrt.dconf-editor.svg \
  /usr/share/icons/hicolor/256x256/apps/ca.desrt.dconf-editor.png \
  /usr/share/icons/hicolor/128x128/apps/ca.desrt.dconf-editor.png \
  /usr/share/icons/hicolor/scalable/apps/ca.desrt.dconf-editor-symbolic.svg; do
  if [[ -f "$candidate" ]]; then
    ICON_FILE="$candidate"
    break
  fi
done
[[ -n "$ICON_FILE" ]] || {
  echo "错误：找不到 dconf Editor 应用图标。" >&2
  exit 1
}

# 本程序专属处理：查找 dconf GSettings backend；该模块由 GIO 动态加载，不能只依赖主程序的 ldd 自动收集。
DCONF_GIO_MODULE="$(find /usr/lib -type f -path '*/gio/modules/libdconfsettings.so' -print -quit)"
[[ -n "$DCONF_GIO_MODULE" && -f "$DCONF_GIO_MODULE" ]] || {
  echo "错误：找不到 libdconfsettings.so。" >&2
  exit 1
}

# 本程序专属处理：查找 Fcitx5 GTK3 输入法模块；后续将它与当前构建环境的 GTK/GLib 依赖一起封装。
FCITX_IM_MODULE="$(dpkg-query -L fcitx5-frontend-gtk3 | grep -E '/gtk-3\.0/.*/immodules/im-fcitx5\.so$' | head -n1)"
[[ -n "$FCITX_IM_MODULE" && -f "$FCITX_IM_MODULE" ]] || {
  echo "错误：找不到 Fcitx5 GTK3 输入法模块 im-fcitx5.so。" >&2
  exit 1
}

# 本程序专属处理：查找与当前 GTK3 包匹配的 gtk-query-immodules-3.0，用于生成 AppImage 专用输入法模块缓存。
GTK_QUERY_IMMODULES="$(find /usr/lib /usr/bin -type f -name 'gtk-query-immodules-3.0' -perm -111 -print -quit 2>/dev/null)"
[[ -n "$GTK_QUERY_IMMODULES" && -x "$GTK_QUERY_IMMODULES" ]] || {
  echo "错误：找不到 gtk-query-immodules-3.0。" >&2
  exit 1
}

# 本程序专属处理：确认 Ubuntu 简体中文语言包确实包含 dconf Editor 翻译。
ZH_CN_LANGPACK_DIR="/usr/share/locale-langpack/zh_CN"
DCONF_EDITOR_ZH_CN_MO="$ZH_CN_LANGPACK_DIR/LC_MESSAGES/dconf-editor.mo"
[[ -f "$DCONF_EDITOR_ZH_CN_MO" ]] || {
  echo "错误：简体中文语言包中缺少 dconf-editor.mo。" >&2
  exit 1
}

########## 准备桌面资源和运行库 #########

# 本程序专属处理：把 Ubuntu 的 zh_CN GNOME 语言包复制到标准 locale 目录，供 AppImage 内程序和 GTK/GLib 使用。
mkdir -p "$APPDIR/usr/share/locale"
cp -a "$ZH_CN_LANGPACK_DIR" "$APPDIR/usr/share/locale/zh_CN"

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
"$SCRIPT_DIR/../common/linuxdeploy/prepare_locale.sh" zh_CN UTF-8 "$APPDIR/usr/lib/locale/zh_CN.UTF-8"
test -s "$APPDIR/usr/lib/locale/zh_CN.UTF-8/LC_MESSAGES/SYS_LC_MESSAGES" || {
  echo "错误：AppImage 简体中文 locale 数据生成失败。" >&2
  exit 1
}

# 本程序专属处理：在进入 ELF 重定位前先确认 dconf Editor 中文目录实际可被 gettext 正确读取。
TRANSLATED_ARGUMENTS_DESCRIPTION="$({
  TEXTDOMAIN=dconf-editor \
  TEXTDOMAINDIR="$APPDIR/usr/share/locale" \
  LANGUAGE=zh_CN \
  LANG=zh_CN.UTF-8 \
  LC_ALL=zh_CN.UTF-8 \
  gettext 'Arguments description:'
})"
[[ -n "$TRANSLATED_ARGUMENTS_DESCRIPTION" && "$TRANSLATED_ARGUMENTS_DESCRIPTION" != 'Arguments description:' ]] || {
  echo "错误：dconf Editor 简体中文翻译检查失败。" >&2
  exit 1
}

# 本程序专属处理：编译 AppImage 内 dconf Editor 自身的 GSettings schema。
glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas"

# 本程序专属处理：使用 linuxdeploy 部署 dconf Editor、dconf CLI、GTK 查询工具及其运行依赖。
APPIMAGE_EXTRACT_AND_RUN=1 linuxdeploy \
  --appdir "$APPDIR" \
  --executable /usr/bin/dconf-editor \
  --executable /usr/bin/dconf \
  --executable "$GTK_QUERY_IMMODULES" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE"

# 本程序专属处理：dconf backend 放入 AppImage 专用 GIO 模块目录。
mkdir -p "$APPDIR/usr/lib/gio/modules"
cp -a "$DCONF_GIO_MODULE" "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"

# 本程序专属处理：为已复制的 dconf backend 部署依赖并修正 RPATH。
APPIMAGE_EXTRACT_AND_RUN=1 linuxdeploy \
  --appdir "$APPDIR" \
  --deploy-deps-only "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"

# 本程序专属处理：为 dconf backend 生成 GIO 模块缓存。
GIO_MODULE_DIR="$APPDIR/usr/lib/gio/modules"
LD_LIBRARY_PATH="$APPDIR/usr/lib" gio-querymodules "$GIO_MODULE_DIR"

# 本程序专属处理：Fcitx5 GTK3 模块保留 GTK 约定目录结构，避免运行时扫描宿主 IBus 模块。
APP_FCITX_IM_DIR="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
APP_FCITX_IM_MODULE="$APP_FCITX_IM_DIR/im-fcitx5.so"
mkdir -p "$APP_FCITX_IM_DIR"
cp -a "$FCITX_IM_MODULE" "$APP_FCITX_IM_MODULE"

# 本程序专属处理：为已复制的 Fcitx5 模块部署依赖并修正 RPATH，使其与 AppImage 内 GTK/GLib 使用同一套 ABI。
APPIMAGE_EXTRACT_AND_RUN=1 linuxdeploy \
  --appdir "$APPDIR" \
  --deploy-deps-only "$APP_FCITX_IM_MODULE"

# 本程序专属处理：确认 linuxdeploy 已把 gtk-query-immodules-3.0 放入 AppDir。
APP_GTK_QUERY_IMMODULES="$APPDIR/usr/bin/gtk-query-immodules-3.0"
[[ -x "$APP_GTK_QUERY_IMMODULES" ]] || {
  echo "错误：AppDir 中缺少 gtk-query-immodules-3.0。" >&2
  exit 1
}

# 本程序专属处理：生成一次构建阶段缓存并确认 Fcitx5 模块能被 AppImage 内 GTK 正确识别。
BUILD_IMMODULE_CACHE="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules.cache"
LD_LIBRARY_PATH="$APPDIR/usr/lib" \
  "$APP_GTK_QUERY_IMMODULES" "$APP_FCITX_IM_MODULE" > "$BUILD_IMMODULE_CACHE"
grep -Fq '"fcitx"' "$BUILD_IMMODULE_CACHE" || {
  echo "错误：Fcitx5 GTK3 模块缓存生成失败。" >&2
  exit 1
}

############# 准备 AppRun ##############

# 本程序专属处理：linuxdeploy 默认会创建 AppRun 软链；写自定义 AppRun 前必须删除，防止再次覆盖真正主程序。
rm -f "$APPDIR/AppRun"

# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APP_RUN_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

HERE="${APPDIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
cd "$HERE"

export APPDIR="$HERE"
export PATH="$HERE/usr/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

HOST_XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_DATA_DIRS="$HERE/usr/share:$HOST_XDG_DATA_DIRS"
export GIO_EXTRA_MODULES="$HERE/usr/lib/gio/modules${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"

# Type 2 runtime 会把用户实际调用的文件名放进 ARGV0；软链接名为 dconf 时直接运行内置 CLI。
ENTRY_NAME="$(basename -- "${ARGV0:-${APPIMAGE:-$0}}")"
if [[ "$ENTRY_NAME" == "dconf" ]]; then
  exec "$HERE/usr/bin/dconf" "$@"
fi

# 以下 GTK/Fcitx5/中文 locale 逻辑只属于 dconf Editor GUI；dconf CLI 不执行这些步骤。
FCITX_IM_MODULE="$HERE/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so"
GTK_QUERY_IMMODULES="$HERE/usr/bin/gtk-query-immodules-3.0"
[[ -f "$FCITX_IM_MODULE" ]] || { echo "错误：AppImage 内缺少 Fcitx5 GTK3 输入法模块。" >&2; exit 1; }
[[ -x "$GTK_QUERY_IMMODULES" ]] || { echo "错误：AppImage 内缺少 gtk-query-immodules-3.0。" >&2; exit 1; }

RUNTIME_TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
if [[ ! -d "$RUNTIME_TMP_DIR" || ! -w "$RUNTIME_TMP_DIR" ]]; then
  RUNTIME_TMP_DIR="/tmp"
fi
GTK_IM_CACHE="$(mktemp "$RUNTIME_TMP_DIR/dconf-editor-immodules.XXXXXX")"
trap 'rm -f "$GTK_IM_CACHE"' EXIT

"$GTK_QUERY_IMMODULES" "$FCITX_IM_MODULE" > "$GTK_IM_CACHE"
grep -Fq '"fcitx"' "$GTK_IM_CACHE" || { echo "错误：Fcitx5 GTK3 输入法模块缓存无效。" >&2; exit 1; }

export GTK_IM_MODULE_FILE="$GTK_IM_CACHE"
export GTK_IM_MODULE=fcitx

env LOCPATH="$HERE/usr/lib/locale" LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN \
  "$HERE/usr/bin/dconf-editor" "$@"
APP_RUN_EOF

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

# 本程序专属处理：静态检查 AppRun Shell 语法。
bash -n "$APPDIR/AppRun"

# 本程序专属处理：确认 AppRun 是独立文件，dconf Editor 和 dconf CLI 都仍保持真正 ELF，防止递归启动或错误软链接。
test ! -L "$APPDIR/AppRun"
[[ "$(head -c 4 "$APPDIR/usr/bin/dconf-editor")" == $'\x7fELF' ]] || {
  echo "错误：AppDir 中的 dconf-editor 主程序不是 ELF。" >&2
  exit 1
}
[[ "$(head -c 4 "$APPDIR/usr/bin/dconf")" == $'\x7fELF' ]] || {
  echo "错误：AppDir 中的 dconf CLI 不是 ELF。" >&2
  exit 1
}

# 本程序专属处理：确认 AppImage 已包含 dconf Editor schema、dconf CLI、dconf backend、中文翻译和 Fcitx5 模块。
test -x "$APPDIR/usr/bin/dconf"
test -f "$APPDIR/usr/share/glib-2.0/schemas/ca.desrt.dconf-editor.gschema.xml"
test -f "$APPDIR/usr/share/glib-2.0/schemas/gschemas.compiled"
test -f "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"
test -f "$APPDIR/usr/lib/gio/modules/giomodule.cache"
test -f "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/dconf-editor.mo"
test -s "$APPDIR/usr/lib/locale/zh_CN.UTF-8/LC_MESSAGES/SYS_LC_MESSAGES"
test -f "$APP_FCITX_IM_MODULE"
test -s "$BUILD_IMMODULE_CACHE"

# 本程序专属处理：确认 AppImage 内 GIO 提供 g_task_set_static_name，避免再次出现宿主 IBus 所触发的 undefined symbol 错误。
APP_GIO_LIBRARY="$(find "$APPDIR/usr/lib" -maxdepth 1 -type f -name 'libgio-2.0.so.0*' -print -quit)"
[[ -n "$APP_GIO_LIBRARY" && -f "$APP_GIO_LIBRARY" ]] || {
  echo "错误：AppDir 中缺少 libgio-2.0.so.0。" >&2
  exit 1
}
nm -D "$APP_GIO_LIBRARY" | grep -F ' g_task_set_static_name' >/dev/null || {
  echo "错误：AppImage 内 libgio 缺少 g_task_set_static_name。" >&2
  exit 1
}

# 本程序专属处理：检查所有已打包 ELF 的最高 GLIBC symbol 版本不得超过 Ubuntu 24.04 的 2.39。
MAX_GLIBC_VERSION="$({
  while IFS= read -r -d '' elf; do
    file "$elf" | grep -q 'ELF' || continue
    strings "$elf" | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' || true
  done < <(find "$APPDIR" -type f -print0)
} | sed 's/^GLIBC_//' | sort -V | tail -n1)"
[[ -n "$MAX_GLIBC_VERSION" ]] || {
  echo "错误：无法检测 AppDir 的 GLIBC symbol 版本。" >&2
  exit 1
}
dpkg --compare-versions "$MAX_GLIBC_VERSION" le "$MAX_ALLOWED_GLIBC_VERSION" || {
  echo "错误：AppDir 出现过新的 GLIBC_$MAX_GLIBC_VERSION 依赖。" >&2
  exit 1
}
echo "AppDir 最高 GLIBC symbol：GLIBC_$MAX_GLIBC_VERSION"

# 本程序专属处理：确认没有把 glibc 本体或动态加载器塞进 AppImage。
if find "$APPDIR" \( -name 'libc.so.6' -o -name 'ld-linux-x86-64.so.2' \) -print -quit | grep -q .; then
  echo "错误：AppDir 不应包含 glibc 本体或动态加载器。" >&2
  exit 1
fi

# 封装最终 AppImage，成功后输出 SHA-256 校验值并保存版本号。
"$SCRIPT_DIR/../common/linuxdeploy/package_appimage.sh" "$APPIMAGETOOL" "$APPDIR" "$OUTFILE" "$RUNTIME_FILE" "$VERSION" "$DIST_DIR/version.txt" --no-appstream

# 本程序专属处理：确认最终 AppImage 自报版本仍为 45.0.1。
FINAL_VERSION_OUTPUT="$(APPIMAGE_EXTRACT_AND_RUN=1 "$OUTFILE" --version)"
grep -Fq "$EXPECTED_DCONF_EDITOR_VERSION" <<< "$FINAL_VERSION_OUTPUT" || {
  echo "错误：最终 AppImage 版本检查失败：$FINAL_VERSION_OUTPUT" >&2
  exit 1
}

# 本程序专属处理：从英文宿主环境启动最终 AppImage，确认 AppRun 会主动切换到内置简体中文，而不是仅检查 .mo 文件存在。
FINAL_HELP_OUTPUT="$(LANG=C LC_ALL=C LANGUAGE= APPIMAGE_EXTRACT_AND_RUN=1 "$OUTFILE" --help 2>&1)"
grep -Fq '参数描述：' <<< "$FINAL_HELP_OUTPUT" || {
  echo "错误：最终 AppImage 简体中文界面检查失败。" >&2
  exit 1
}

# 本程序专属处理：创建临时 dconf 软链接，实际验证 Type 2 runtime 的 ARGV0 能把同一个 AppImage 分派到内置 dconf CLI。
DCONF_LINK="$DIST_DIR/dconf"
ln -sfn "$(basename -- "$OUTFILE")" "$DCONF_LINK"
DCONF_HELP_OUTPUT="$(LANG=C LC_ALL=C LANGUAGE= APPIMAGE_EXTRACT_AND_RUN=1 "$DCONF_LINK" help 2>&1)"
grep -Fq 'Usage:' <<< "$DCONF_HELP_OUTPUT" || {
  echo "错误：dconf 软链接分派检查失败。" >&2
  exit 1
}
rm -f "$DCONF_LINK"

# 本程序专属处理：使用独立 D-Bus + Xvfb 做一次无界面启动冒烟测试；外部环境故意设为英文，验证 AppRun 自身的中文设置。
set +e
LANG=C \
LC_ALL=C \
LANGUAGE= \
APPIMAGE_EXTRACT_AND_RUN=1 \
  timeout 8s dbus-run-session -- xvfb-run -a "$OUTFILE" >"$SMOKE_LOG" 2>&1
SMOKE_STATUS=$?
set -e

# 本程序专属处理：仅接受正常退出或预期的 GUI 超时。
if [[ "$SMOKE_STATUS" -ne 0 && "$SMOKE_STATUS" -ne 124 ]]; then
  cat "$SMOKE_LOG" >&2
  echo "错误：dconf Editor 无界面启动测试失败，退出码：$SMOKE_STATUS。" >&2
  exit 1
fi

# 本程序专属处理：冒烟日志中禁止再次出现此前已确认的 GLIBC / undefined symbol / 输入法模块加载失败问题。
if grep -Eiq 'GLIBC_[0-9.]+.*not found|undefined symbol|Loading IM context type .*(ibus|fcitx).*failed' "$SMOKE_LOG"; then
  cat "$SMOKE_LOG" >&2
  echo "错误：dconf Editor 冒烟测试发现动态库或输入法加载错误。" >&2
  exit 1
fi

# 本程序专属处理：删除仅用于构建的工具和冒烟日志，不影响最终 AppImage 产物。
rm -rf "$TOOLS_DIR"
rm -f "$SMOKE_LOG"
