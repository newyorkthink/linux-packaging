#!/usr/bin/env bash
set -Eeuo pipefail

# dconf Editor AppImage 最终稳定打包方案：
# 1. 固定使用 Ubuntu 24.04 构建，直接采用发行版官方 dconf-editor 45.0.1。
# 2. 不打包 glibc 与动态加载器，最终 AppImage 的 GLIBC 运行基线不高于 Ubuntu 24.04 的 2.39。
# 3. 保留宿主 HOME、XDG_CONFIG_HOME、DBUS_SESSION_BUS_ADDRESS，实际读写宿主用户自己的 dconf 数据库。
# 4. XDG_DATA_DIRS 同时保留 AppImage 与宿主目录，使 dconf Editor 能读取自身和宿主 GSettings schemas。
# 5. 内置简体中文翻译和 zh_CN.UTF-8 locale 数据，并固定界面使用简体中文，避免依赖宿主语言包或宿主语言设置。
# 6. 内置 Fcitx5 GTK3 输入法模块并生成独立模块缓存，避免 GTK 加载宿主 IBus 模块导致 GLib ABI 冲突。
# 7. linuxdeploy、appimagetool 与 Type 2 runtime 均固定版本/摘要，避免后续构建工具静默漂移。
# 8. 同一个 AppImage 同时内置 dconf Editor GUI 和 dconf CLI；外部软链接名为 dconf 时由 Type 2 runtime 的 ARGV0 直接分派到 CLI。

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly OUTDIR="$SCRIPT_DIR/dist"
readonly TOOLDIR="$SCRIPT_DIR/.appimage-tools"
readonly LINUXDEPLOY="$TOOLDIR/linuxdeploy-x86_64.AppImage"
readonly APPIMAGETOOL="$TOOLDIR/appimagetool-x86_64.AppImage"
readonly RUNTIME="$TOOLDIR/runtime-x86_64"
readonly DESKTOP_FILE="/usr/share/applications/ca.desrt.dconf-editor.desktop"
readonly OUTPUT_FILE="$OUTDIR/dconf-editor.AppImage"
readonly SMOKE_LOG="$SCRIPT_DIR/.dconf-editor-smoke.log"

readonly EXPECTED_DCONF_EDITOR_VERSION="45.0.1"
readonly MAX_ALLOWED_GLIBC_VERSION="2.39"

readonly LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage"
readonly LINUXDEPLOY_SHA256="c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d"
readonly APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
readonly RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64"
readonly RUNTIME_SHA256="1cc49bcf1e2ccd593c379adb17c9f85a36d619088296504de95b1d06215aebbf"

die() {
  echo "错误：$*" >&2
  exit 1
}

# 确认构建环境固定为 Ubuntu 24.04，防止发行版变化再次抬高运行基线。
source /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] || \
  die "此脚本必须在 Ubuntu 24.04 构建，当前为 ${PRETTY_NAME:-unknown}。"

# 清理仅属于本项目的旧构建目录和旧产物，避免历史文件混入新包。
rm -rf "$APPDIR" "$OUTDIR" "$TOOLDIR"
rm -f "$SMOKE_LOG"

# 创建本次构建所需目录。
mkdir -p "$APPDIR" "$OUTDIR" "$TOOLDIR"

# 安装 dconf Editor、dconf CLI、简体中文语言包、Fcitx5 GTK3 模块以及静态检查/打包所需工具。
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  binutils \
  ca-certificates \
  curl \
  dbus \
  dconf-cli \
  dconf-editor \
  dconf-gsettings-backend \
  dconf-service \
  desktop-file-utils \
  fcitx5-frontend-gtk3 \
  file \
  gettext \
  language-pack-gnome-zh-hans-base \
  libglib2.0-bin \
  locales \
  patchelf \
  python3 \
  squashfs-tools \
  xauth \
  xvfb

# 生成简体中文 UTF-8 locale，供构建阶段的翻译完整性检查和无界面启动测试使用。
sudo locale-gen zh_CN.UTF-8
locale -a | grep -Eiq '^zh_CN\.utf-?8$' || die "zh_CN.UTF-8 locale 未生成。"

# 固定 dconf Editor 主版本；Ubuntu 安全更新允许包修订号变化，但程序版本必须保持 45.0.1。
INSTALLED_DCONF_EDITOR_VERSION="$(dpkg-query -W -f='${Version}' dconf-editor)"
[[ "$INSTALLED_DCONF_EDITOR_VERSION" == "$EXPECTED_DCONF_EDITOR_VERSION"-* ]] || \
  die "dconf-editor 版本不是预期的 $EXPECTED_DCONF_EDITOR_VERSION，当前为 $INSTALLED_DCONF_EDITOR_VERSION。"

# 确认 dconf Editor GUI、dconf CLI 和 desktop 文件存在。
[[ -x /usr/bin/dconf-editor ]] || die "找不到 /usr/bin/dconf-editor。"
[[ -x /usr/bin/dconf ]] || die "找不到 /usr/bin/dconf。"
[[ -f "$DESKTOP_FILE" ]] || die "找不到 $DESKTOP_FILE。"

# 自动选择发行版实际提供的 dconf Editor 图标，兼容 PNG 与 SVG 布局。
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
[[ -n "$ICON_FILE" ]] || die "找不到 dconf Editor 应用图标。"

# 查找 dconf GSettings backend；该模块由 GIO 动态加载，不能只依赖主程序的 ldd 自动收集。
DCONF_GIO_MODULE="$(find /usr/lib -type f -path '*/gio/modules/libdconfsettings.so' -print -quit)"
[[ -n "$DCONF_GIO_MODULE" && -f "$DCONF_GIO_MODULE" ]] || \
  die "找不到 libdconfsettings.so。"

# 查找 Fcitx5 GTK3 输入法模块；后续将它与当前构建环境的 GTK/GLib 依赖一起封装。
FCITX_IM_MODULE="$(dpkg-query -L fcitx5-frontend-gtk3 | grep -E '/gtk-3\.0/.*/immodules/im-fcitx5\.so$' | head -n1)"
[[ -n "$FCITX_IM_MODULE" && -f "$FCITX_IM_MODULE" ]] || \
  die "找不到 Fcitx5 GTK3 输入法模块 im-fcitx5.so。"

# 查找与当前 GTK3 包匹配的 gtk-query-immodules-3.0，用于生成 AppImage 专用输入法模块缓存。
GTK_QUERY_IMMODULES="$(find /usr/lib /usr/bin -type f -name 'gtk-query-immodules-3.0' -perm -111 -print -quit 2>/dev/null)"
[[ -n "$GTK_QUERY_IMMODULES" && -x "$GTK_QUERY_IMMODULES" ]] || \
  die "找不到 gtk-query-immodules-3.0。"

# 确认 Ubuntu 简体中文语言包确实包含 dconf Editor 翻译。
readonly ZH_CN_LANGPACK_DIR="/usr/share/locale-langpack/zh_CN"
readonly DCONF_EDITOR_ZH_CN_MO="$ZH_CN_LANGPACK_DIR/LC_MESSAGES/dconf-editor.mo"
[[ -f "$DCONF_EDITOR_ZH_CN_MO" ]] || \
  die "简体中文语言包中缺少 dconf-editor.mo。"

# 下载固定版本 linuxdeploy。
curl -fL --retry 3 --retry-all-errors "$LINUXDEPLOY_URL" -o "$LINUXDEPLOY"

# 校验 linuxdeploy 摘要，避免下载内容变化后继续构建。
printf '%s  %s\n' "$LINUXDEPLOY_SHA256" "$LINUXDEPLOY" | sha256sum -c -

# 下载固定版本 appimagetool。
curl -fL --retry 3 --retry-all-errors "$APPIMAGETOOL_URL" -o "$APPIMAGETOOL"

# 校验 appimagetool 摘要。
printf '%s  %s\n' "$APPIMAGETOOL_SHA256" "$APPIMAGETOOL" | sha256sum -c -

# 下载固定摘要的 Type 2 runtime；若 continuous 资产发生变化，摘要检查会直接终止而不是静默换版本。
curl -fL --retry 3 --retry-all-errors "$RUNTIME_URL" -o "$RUNTIME"

# 校验 Type 2 runtime 摘要。
printf '%s  %s\n' "$RUNTIME_SHA256" "$RUNTIME" | sha256sum -c -

# 赋予两个 AppImage 构建工具执行权限。
chmod +x "$LINUXDEPLOY" "$APPIMAGETOOL"

# 复制 dconf Editor 软件包自带的 /usr/share 数据，包括 schema、图标、AppStream、D-Bus service 等资源。
while IFS= read -r file; do
  [[ "$file" == /usr/share/* ]] || continue
  [[ -f "$file" || -L "$file" ]] || continue
  cp -a --parents "$file" "$APPDIR"
done < <(dpkg-query -L dconf-editor)

# 把 Ubuntu 的 zh_CN GNOME 语言包复制到标准 locale 目录，供 AppImage 内程序和 GTK/GLib 使用。
mkdir -p "$APPDIR/usr/share/locale"
cp -a "$ZH_CN_LANGPACK_DIR" "$APPDIR/usr/share/locale/zh_CN"

# 生成 AppImage 自带的 zh_CN.UTF-8 locale 数据，确保界面中文不依赖宿主是否生成中文 locale。
readonly APP_LOCALE_DIR="$APPDIR/usr/lib/locale"
mkdir -p "$APP_LOCALE_DIR"
localedef --no-archive -i zh_CN -f UTF-8 "$APP_LOCALE_DIR/zh_CN.UTF-8"
test -s "$APP_LOCALE_DIR/zh_CN.UTF-8/LC_MESSAGES/SYS_LC_MESSAGES" || \
  die "AppImage 简体中文 locale 数据生成失败。"

# 在进入 ELF 重定位前先确认 dconf Editor 中文目录实际可被 gettext 正确读取。
TRANSLATED_ARGUMENTS_DESCRIPTION="$({
  TEXTDOMAIN=dconf-editor \
  TEXTDOMAINDIR="$APPDIR/usr/share/locale" \
  LANGUAGE=zh_CN \
  LANG=zh_CN.UTF-8 \
  LC_ALL=zh_CN.UTF-8 \
  gettext 'Arguments description:'
})"
[[ -n "$TRANSLATED_ARGUMENTS_DESCRIPTION" && "$TRANSLATED_ARGUMENTS_DESCRIPTION" != 'Arguments description:' ]] || \
  die "dconf Editor 简体中文翻译检查失败。"

# 编译 AppImage 内 dconf Editor 自身的 GSettings schema。
glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas"

# 使用 linuxdeploy 部署 dconf Editor、dconf CLI、GTK 查询工具及其运行依赖。
APPIMAGE_EXTRACT_AND_RUN=1 "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --executable /usr/bin/dconf-editor \
  --executable /usr/bin/dconf \
  --executable "$GTK_QUERY_IMMODULES" \
  --desktop-file "$DESKTOP_FILE" \
  --icon-file "$ICON_FILE"

# dconf backend 放入 AppImage 专用 GIO 模块目录。
mkdir -p "$APPDIR/usr/lib/gio/modules"
cp -a "$DCONF_GIO_MODULE" "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"

# 为已复制的 dconf backend 部署依赖并修正 RPATH。
APPIMAGE_EXTRACT_AND_RUN=1 "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --deploy-deps-only "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"

# 为 dconf backend 生成 GIO 模块缓存。
GIO_MODULE_DIR="$APPDIR/usr/lib/gio/modules"
LD_LIBRARY_PATH="$APPDIR/usr/lib" gio-querymodules "$GIO_MODULE_DIR"

# Fcitx5 GTK3 模块保留 GTK 约定目录结构，避免运行时扫描宿主 IBus 模块。
readonly APP_FCITX_IM_DIR="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
readonly APP_FCITX_IM_MODULE="$APP_FCITX_IM_DIR/im-fcitx5.so"
mkdir -p "$APP_FCITX_IM_DIR"
cp -a "$FCITX_IM_MODULE" "$APP_FCITX_IM_MODULE"

# 为已复制的 Fcitx5 模块部署依赖并修正 RPATH，使其与 AppImage 内 GTK/GLib 使用同一套 ABI。
APPIMAGE_EXTRACT_AND_RUN=1 "$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --deploy-deps-only "$APP_FCITX_IM_MODULE"

# 确认 linuxdeploy 已把 gtk-query-immodules-3.0 放入 AppDir。
readonly APP_GTK_QUERY_IMMODULES="$APPDIR/usr/bin/gtk-query-immodules-3.0"
[[ -x "$APP_GTK_QUERY_IMMODULES" ]] || die "AppDir 中缺少 gtk-query-immodules-3.0。"

# 生成一次构建阶段缓存并确认 Fcitx5 模块能被 AppImage 内 GTK 正确识别。
readonly BUILD_IMMODULE_CACHE="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules.cache"
LD_LIBRARY_PATH="$APPDIR/usr/lib" \
  "$APP_GTK_QUERY_IMMODULES" "$APP_FCITX_IM_MODULE" > "$BUILD_IMMODULE_CACHE"
grep -Fq '"fcitx"' "$BUILD_IMMODULE_CACHE" || die "Fcitx5 GTK3 模块缓存生成失败。"

# 将 AppImage 内 ELF 的绝对 locale 路径改成相对路径。
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

# linuxdeploy 默认会创建 AppRun 软链；写自定义 AppRun 前必须删除，防止再次覆盖真正主程序。
rm -f "$APPDIR/AppRun"

# 写入自定义 AppRun：保留宿主配置/会话；dconf 软链接直接进入 CLI，其余入口保持 dconf Editor GUI。
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

# 赋予 AppRun 执行权限。
chmod +x "$APPDIR/AppRun"

# 静态检查 AppRun Shell 语法。
bash -n "$APPDIR/AppRun"

# 确认 AppRun 是独立文件，dconf Editor 和 dconf CLI 都仍保持真正 ELF，防止递归启动或错误软链接。
test ! -L "$APPDIR/AppRun"
[[ "$(head -c 4 "$APPDIR/usr/bin/dconf-editor")" == $'\x7fELF' ]] || \
  die "AppDir 中的 dconf-editor 主程序不是 ELF。"
[[ "$(head -c 4 "$APPDIR/usr/bin/dconf")" == $'\x7fELF' ]] || \
  die "AppDir 中的 dconf CLI 不是 ELF。"

# 确认 AppImage 已包含 dconf Editor schema、dconf CLI、dconf backend、中文翻译和 Fcitx5 模块。
test -x "$APPDIR/usr/bin/dconf"
test -f "$APPDIR/usr/share/glib-2.0/schemas/ca.desrt.dconf-editor.gschema.xml"
test -f "$APPDIR/usr/share/glib-2.0/schemas/gschemas.compiled"
test -f "$APPDIR/usr/lib/gio/modules/libdconfsettings.so"
test -f "$APPDIR/usr/lib/gio/modules/giomodule.cache"
test -f "$APPDIR/usr/share/locale/zh_CN/LC_MESSAGES/dconf-editor.mo"
test -s "$APPDIR/usr/lib/locale/zh_CN.UTF-8/LC_MESSAGES/SYS_LC_MESSAGES"
test -f "$APP_FCITX_IM_MODULE"
test -s "$BUILD_IMMODULE_CACHE"

# 确认 AppImage 内 GIO 提供 g_task_set_static_name，避免再次出现宿主 IBus 所触发的 undefined symbol 错误。
APP_GIO_LIBRARY="$(find "$APPDIR/usr/lib" -maxdepth 1 -type f -name 'libgio-2.0.so.0*' -print -quit)"
[[ -n "$APP_GIO_LIBRARY" && -f "$APP_GIO_LIBRARY" ]] || die "AppDir 中缺少 libgio-2.0.so.0。"
nm -D "$APP_GIO_LIBRARY" | grep -F ' g_task_set_static_name' >/dev/null || \
  die "AppImage 内 libgio 缺少 g_task_set_static_name。"

# 检查所有已打包 ELF 的最高 GLIBC symbol 版本不得超过 Ubuntu 24.04 的 2.39。
MAX_GLIBC_VERSION="$({
  while IFS= read -r -d '' elf; do
    file "$elf" | grep -q 'ELF' || continue
    strings "$elf" | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' || true
  done < <(find "$APPDIR" -type f -print0)
} | sed 's/^GLIBC_//' | sort -V | tail -n1)"
[[ -n "$MAX_GLIBC_VERSION" ]] || die "无法检测 AppDir 的 GLIBC symbol 版本。"
dpkg --compare-versions "$MAX_GLIBC_VERSION" le "$MAX_ALLOWED_GLIBC_VERSION" || \
  die "AppDir 出现过新的 GLIBC_$MAX_GLIBC_VERSION 依赖。"
echo "AppDir 最高 GLIBC symbol：GLIBC_$MAX_GLIBC_VERSION"

# 确认没有把 glibc 本体或动态加载器塞进 AppImage。
if find "$APPDIR" \( -name 'libc.so.6' -o -name 'ld-linux-x86-64.so.2' \) -print -quit | grep -q .; then
  die "AppDir 不应包含 glibc 本体或动态加载器。"
fi

# 使用固定 Type 2 runtime 生成最终 dconf-editor.AppImage；保留 AppStream 元数据，仅跳过新版校验器对 45.0.1 历史元数据的警告检查。
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" --no-appstream --runtime-file "$RUNTIME" "$APPDIR" "$OUTPUT_FILE"

# 确认最终产物存在且非空。
test -s "$OUTPUT_FILE"

# 确认最终 AppImage 自报版本仍为 45.0.1。
FINAL_VERSION_OUTPUT="$(APPIMAGE_EXTRACT_AND_RUN=1 "$OUTPUT_FILE" --version)"
grep -Fq "$EXPECTED_DCONF_EDITOR_VERSION" <<< "$FINAL_VERSION_OUTPUT" || \
  die "最终 AppImage 版本检查失败：$FINAL_VERSION_OUTPUT"

# 从英文宿主环境启动最终 AppImage，确认 AppRun 会主动切换到内置简体中文，而不是仅检查 .mo 文件存在。
FINAL_HELP_OUTPUT="$(LANG=C LC_ALL=C LANGUAGE= APPIMAGE_EXTRACT_AND_RUN=1 "$OUTPUT_FILE" --help 2>&1)"
grep -Fq '参数描述：' <<< "$FINAL_HELP_OUTPUT" || \
  die "最终 AppImage 简体中文界面检查失败。"

# 创建临时 dconf 软链接，实际验证 Type 2 runtime 的 ARGV0 能把同一个 AppImage 分派到内置 dconf CLI。
DCONF_LINK="$OUTDIR/dconf"
ln -sfn "$(basename -- "$OUTPUT_FILE")" "$DCONF_LINK"
DCONF_HELP_OUTPUT="$(LANG=C LC_ALL=C LANGUAGE= APPIMAGE_EXTRACT_AND_RUN=1 "$DCONF_LINK" help 2>&1)"
grep -Fq 'Usage:' <<< "$DCONF_HELP_OUTPUT" || \
  die "dconf 软链接分派检查失败。"
rm -f "$DCONF_LINK"

# 使用独立 D-Bus + Xvfb 做一次无界面启动冒烟测试；外部环境故意设为英文，验证 AppRun 自身的中文设置。
set +e
LANG=C \
LC_ALL=C \
LANGUAGE= \
APPIMAGE_EXTRACT_AND_RUN=1 \
  timeout 8s dbus-run-session -- xvfb-run -a "$OUTPUT_FILE" >"$SMOKE_LOG" 2>&1
SMOKE_STATUS=$?
set -e

# 仅接受正常退出或预期的 GUI 超时。
if [[ "$SMOKE_STATUS" -ne 0 && "$SMOKE_STATUS" -ne 124 ]]; then
  cat "$SMOKE_LOG" >&2
  die "dconf Editor 无界面启动测试失败，退出码：$SMOKE_STATUS。"
fi

# 冒烟日志中禁止再次出现此前已确认的 GLIBC / undefined symbol / 输入法模块加载失败问题。
if grep -Eiq 'GLIBC_[0-9.]+.*not found|undefined symbol|Loading IM context type .*(ibus|fcitx).*failed' "$SMOKE_LOG"; then
  cat "$SMOKE_LOG" >&2
  die "dconf Editor 冒烟测试发现动态库或输入法加载错误。"
fi

# 输出最终文件摘要，便于 Release 与本地下载后核对。
sha256sum "$OUTPUT_FILE"

# 删除仅用于构建的工具和冒烟日志，不影响最终 AppImage 产物。
rm -rf "$TOOLDIR"
rm -f "$SMOKE_LOG"
