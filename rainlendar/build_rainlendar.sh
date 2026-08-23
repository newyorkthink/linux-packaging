#!/usr/bin/env bash
set -euo pipefail

# 修改此脚本时，build.yml 只触发 Rainlendar 单项构建。
#
# Rainlendar AppImage 稳定基线：
# - 自动跟踪官方 latest Release，不写死 Rainlendar 版本号或 build 号。
# - GTK3 输入固定使用 IBus 模块连接宿主机 Fcitx5，禁止打包会导致随机闪退的 Fcitx5 GTK 模块。
# - 默认铃声预览固定从 Rainlendar 程序目录启动，并修正 libcanberra 的 Pulse 驱动搜索路径。
# - 上游 Rainlendar_GetPath 若仍通过同一个 static wxString 返回路径，会被多个网络同步线程并发改写；
#   构建时将该共享静态写入改成独立的进程生命周期 wxString 快照，保留 Google Tasks/Google Calendar 等同步功能。
# - 若以后上游已经移除共享静态实现，补丁会自动跳过；若二进制布局发生无法确认的变化，则构建直接失败，禁止盲目 patch。
# - 已知非致命日志：IBUS surrounding-text、部分 GtkSpinButton/GtkWidget CRITICAL、Fontconfig FcInit warning；
#   这些日志当前不作为构建失败条件，避免为了清日志破坏已经有效的输入、声音和同步基线。

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm docker
  else
    echo "错误：未找到 docker。" >&2
    exit 1
  fi
fi

if ! docker info >/dev/null 2>&1; then
  echo "错误：Docker daemon 不可用。" >&2
  exit 1
fi

# GitHub Actions 本身运行在容器中，复用现有工作区挂载。
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  DOCKER_MOUNT=(--volumes-from "$HOSTNAME")
  DOCKER_WORKDIR="$PWD"
else
  DOCKER_MOUNT=(-v "$PWD:/work")
  DOCKER_WORKDIR="/work"
fi

docker run --rm -i \
  "${DOCKER_MOUNT[@]}" \
  -w "$DOCKER_WORKDIR" \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  ubuntu:24.04 \
  bash -s <<'INNER_EOF'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=x86_64
export DEPLOY_GTK_VERSION=3

ROOT="$PWD"
APPDIR="$ROOT/AppDir"
OUTDIR="$ROOT/dist"
OUTFILE="$OUTDIR/rainlendar.AppImage"

apt-get update
apt-get install -y --no-install-recommends \
  adwaita-icon-theme \
  binutils \
  ca-certificates \
  coreutils \
  curl \
  desktop-file-utils \
  dpkg-dev \
  file \
  findutils \
  gnome-themes-extra \
  jq \
  ibus-gtk3 \
  libcanberra-gtk3-module \
  libcanberra-pulse \
  libcanberra0 \
  libgdk-pixbuf2.0-bin \
  libgdk-pixbuf2.0-dev \
  libgirepository1.0-dev \
  libglib2.0-bin \
  libglib2.0-dev \
  libgtk-3-bin \
  libgtk-3-dev \
  libpango1.0-dev \
  librsvg2-dev \
  libsm6 \
  libstdc++6 \
  libwebpdemux2 \
  libxkbcommon0 \
  patchelf \
  pkg-config \
  python3-minimal \
  squashfs-tools \
  xz-utils

# 始终从 Rainlendar 官方 GitHub 最新正式 Release 自动选择 Pro amd64 deb，避免写死版本号和 build 号。
RELEASE_API="https://api.github.com/repos/rainlendar/Rainlendar-Resources/releases/latest"
RELEASE_JSON="/tmp/rainlendar-latest-release.json"
curl -fsSL --retry 3 \
  -H 'Accept: application/vnd.github+json' \
  "$RELEASE_API" \
  -o "$RELEASE_JSON"

mapfile -t DEB_ASSETS < <(
  jq -r '
    .assets[]
    | select(.name | test("^rainlendar2-pro_.*_amd64\\.deb$"))
    | [.name, .browser_download_url, (.digest // "")]
    | @tsv
  ' "$RELEASE_JSON"
)

if (( ${#DEB_ASSETS[@]} != 1 )); then
  echo "错误：最新 Rainlendar Release 中应且只能有一个 Pro amd64 deb，实际找到 ${#DEB_ASSETS[@]} 个。" >&2
  printf '%s\n' "${DEB_ASSETS[@]}" >&2
  exit 1
fi

IFS=$'\t' read -r DEB DEB_URL DEB_DIGEST <<<"${DEB_ASSETS[0]}"
VERSION="$(jq -r '.tag_name // empty' "$RELEASE_JSON")"
if [[ -z "$VERSION" || -z "$DEB" || -z "$DEB_URL" ]]; then
  echo "错误：无法从 Rainlendar 最新 Release 解析版本或 deb 下载地址。" >&2
  exit 1
fi
printf 'Rainlendar 最新正式版：%s\n' "$VERSION"
printf '选择官方安装包：%s\n' "$DEB"

curl -fL --retry 3 "$DEB_URL" -o "/tmp/$DEB"

# GitHub Release API 提供 SHA-256 digest 时直接校验；旧资源没有 digest 时保留下载并输出实际哈希。
if [[ "$DEB_DIGEST" == sha256:* ]]; then
  DEB_SHA256="${DEB_DIGEST#sha256:}"
  printf '%s  %s\n' "$DEB_SHA256" "/tmp/$DEB" | sha256sum -c -
else
  echo "提示：上游 Release 未提供 SHA-256 digest，记录当前下载文件哈希："
  sha256sum "/tmp/$DEB"
fi

curl -fL --retry 3 \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
  -o /tmp/linuxdeploy
curl -fL --retry 3 \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
  -o /tmp/linuxdeploy-plugin-gtk.sh
curl -fL --retry 3 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o /tmp/appimagetool
curl -fL --retry 3 \
  https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 \
  -o /tmp/runtime-x86_64
chmod +x \
  /tmp/linuxdeploy \
  /tmp/linuxdeploy-plugin-gtk.sh \
  /tmp/appimagetool \
  /tmp/runtime-x86_64
export PATH="/tmp:$PATH"

rm -rf "$APPDIR"
mkdir -p "$APPDIR" "$OUTDIR"
rm -f "$OUTFILE"

# 官方 deb 已包含程序、资源、语言和图标，直接提取到 AppDir。
dpkg-deb -x "/tmp/$DEB" "$APPDIR"

test -x "$APPDIR/usr/lib/rainlendar2/rainlendar2"
test -f "$APPDIR/usr/share/applications/rainlendar2.desktop"
test -f "$APPDIR/usr/share/pixmaps/rainlendar2.png"

DEPLOY_DESKTOP_FILE="/tmp/rainlendar2.desktop"
DEPLOY_ICON_FILE="/tmp/rainlendar2.png"
cp -a "$APPDIR/usr/share/applications/rainlendar2.desktop" "$DEPLOY_DESKTOP_FILE"
cp -a "$APPDIR/usr/share/pixmaps/rainlendar2.png" "$DEPLOY_ICON_FILE"
sed -i \
  -e 's/^Icon=.*/Icon=rainlendar2/' \
  -e 's/^Categories=.*/Categories=Office;Calendar;/' \
  "$DEPLOY_DESKTOP_FILE"

# 避免 deb 内原始 desktop/icon 与 linuxdeploy 部署的修正版重复。
rm -f \
  "$APPDIR/usr/share/applications/rainlendar2.desktop" \
  "$APPDIR/usr/share/pixmaps/rainlendar2.png"

cat > /tmp/AppRun.rainlendar <<'APPRUN_EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(dirname "$(readlink -f "$0")")"
export APPDIR

for hook in "$APPDIR"/apprun-hooks/*.sh; do
  [[ -f "$hook" ]] && . "$hook"
done

# 自定义 AppRun 不会自动设置 linuxdeploy 的库搜索路径。
# 必须优先使用 AppImage 内的 Rainlendar、GTK3 和 C++ 运行库。
APPIMAGE_LIBRARY_PATH="$APPDIR/usr/lib/rainlendar2:$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu"
export LD_LIBRARY_PATH="$APPIMAGE_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 使用 GTK3 IBus 客户端连接 Fcitx5 的 IBus 前端：
# 不加载会随机破坏堆内存的 Fcitx GTK 模块，也不使用无法提交预编辑文本的 XIM。
GTK_IMMODULE_DIR="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
IBUS_IMMODULE="$GTK_IMMODULE_DIR/im-ibus.so"
IM_CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
IM_CACHE_FILE="$IM_CACHE_DIR/rainlendar-appimage-immodules-${UID:-0}.cache"

if [[ ! -f "$IBUS_IMMODULE" ]]; then
  echo "错误：Rainlendar AppImage 缺少 IBus GTK3 输入模块。" >&2
  exit 1
fi

mkdir -p "$IM_CACHE_DIR"
cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$IBUS_IMMODULE"
"ibus" "IBus (Intelligent Input Bus)" "ibus" "" "ja:ko:zh:*"
EOF

export GDK_BACKEND=x11
export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
export GTK_IM_MODULE=ibus
export XMODIFIERS="${XMODIFIERS:-@im=fcitx}"

# Rainlendar 的 GTK3 对话框固定使用深色 Adwaita；日历本体仍由 Rainlendar 皮肤控制。
export GTK_THEME=Adwaita:dark

# Rainlendar 通过 dlopen 加载 libcanberra；显式选择 Pulse 后端以兼容 PulseAudio/PipeWire-Pulse。
export CANBERRA_DRIVER=pulse
export LTDL_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/x86_64-linux-gnu${LTDL_LIBRARY_PATH:+:$LTDL_LIBRARY_PATH}"

export PATH="$APPDIR/usr/bin:${PATH:-/usr/bin:/bin}"
export XDG_DATA_DIRS="$APPDIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Rainlendar 的 DefaultAlarmFile 固定为相对路径 resources/alarm.wav。
# 必须从程序目录启动，否则“默认声音 -> 预览”会因当前工作目录不同而找不到 alarm.wav。
cd "$APPDIR/usr/lib/rainlendar2"
exec "$APPDIR/usr/lib/rainlendar2/rainlendar2" "$@"
APPRUN_EOF
chmod +x /tmp/AppRun.rainlendar

# Rainlendar 动态加载 libcanberra，linuxdeploy 无法从主程序的 ldd 自动发现。
CANBERRA_LIBRARY="$(ldconfig -p | awk '$1 == "libcanberra.so.0" {print $NF; exit}')"
CANBERRA_PULSE_MODULE="$(find /usr/lib -type f -name 'libcanberra-pulse.so' -print -quit)"
for required in "$CANBERRA_LIBRARY" "$CANBERRA_PULSE_MODULE"; do
  if [[ -z "$required" || ! -f "$required" ]]; then
    echo "错误：Rainlendar 铃声所需的 libcanberra Pulse 后端缺失。" >&2
    exit 1
  fi
done

# 官方二进制要求 GLIBC_2.38；使用 Ubuntu 24.04 收集依赖。
NO_STRIP=1 /tmp/linuxdeploy \
  --appdir "$APPDIR" \
  --deploy-deps-only "$APPDIR/usr/lib/rainlendar2/rainlendar2" \
  --library "$CANBERRA_LIBRARY" \
  --library "$CANBERRA_PULSE_MODULE" \
  --desktop-file "$DEPLOY_DESKTOP_FILE" \
  --icon-file "$DEPLOY_ICON_FILE" \
  --custom-apprun /tmp/AppRun.rainlendar \
  --plugin gtk

echo "linuxdeploy GTK3 依赖部署完成。"

# linuxdeploy 收尾可能覆盖自定义 AppRun，必须在打包前重新写回最终版本。
cp -f /tmp/AppRun.rainlendar "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

# linuxdeploy-plugin-gtk 遗留的 AppRun.wrapped 与最终 AppRun 重复，最终产物只保留唯一入口 AppRun。
rm -f "$APPDIR/AppRun.wrapped"
test ! -e "$APPDIR/AppRun.wrapped"

# Ubuntu 的 libcanberra 会把驱动插件目录编译成绝对路径；
# linuxdeploy 将插件部署到 AppDir/usr/lib 后，绝对路径会指向宿主机，导致 ca_context_open 返回 "No such driver"。
# 将包内 libcanberra 的唯一驱动模板改成相对名称，让 libltdl 按 LTDL_LIBRARY_PATH 加载 AppImage 内的 Pulse 插件。
CANBERRA_BUNDLED_LIBRARY="$APPDIR/usr/lib/libcanberra.so.0"
CANBERRA_PORTABLE_DRIVER_NAME='libcanberra-%s'
if [[ ! -f "$CANBERRA_BUNDLED_LIBRARY" ]]; then
  echo "错误：最终 AppDir 缺少 libcanberra.so.0。" >&2
  exit 1
fi
mapfile -t CANBERRA_DRIVER_TEMPLATES < <(
  strings "$CANBERRA_BUNDLED_LIBRARY" |
    grep -E '^/.*/libcanberra-[^/]+/libcanberra-%s$' || true
)
if (( ${#CANBERRA_DRIVER_TEMPLATES[@]} != 1 )); then
  echo "错误：无法唯一识别 libcanberra 编译时的驱动插件绝对路径模板。" >&2
  printf '%s\n' "${CANBERRA_DRIVER_TEMPLATES[@]}" >&2
  exit 1
fi
CANBERRA_COMPILED_DRIVER_PATH="${CANBERRA_DRIVER_TEMPLATES[0]}"
if (( ${#CANBERRA_PORTABLE_DRIVER_NAME} > ${#CANBERRA_COMPILED_DRIVER_PATH} )); then
  echo "错误：libcanberra 可移植驱动模板长度异常。" >&2
  exit 1
fi
mapfile -t CANBERRA_TEMPLATE_MATCHES < <(
  grep -Fabo "$CANBERRA_COMPILED_DRIVER_PATH" "$CANBERRA_BUNDLED_LIBRARY" || true
)
if (( ${#CANBERRA_TEMPLATE_MATCHES[@]} != 1 )); then
  echo "错误：libcanberra 驱动模板在二进制中不是唯一匹配。" >&2
  exit 1
fi
CANBERRA_TEMPLATE_OFFSET="${CANBERRA_TEMPLATE_MATCHES[0]%%:*}"
CANBERRA_TEMPLATE_PADDING=$(( ${#CANBERRA_COMPILED_DRIVER_PATH} - ${#CANBERRA_PORTABLE_DRIVER_NAME} ))
{
  printf '%s' "$CANBERRA_PORTABLE_DRIVER_NAME"
  head -c "$CANBERRA_TEMPLATE_PADDING" /dev/zero
} | dd \
  of="$CANBERRA_BUNDLED_LIBRARY" \
  bs=1 \
  seek="$CANBERRA_TEMPLATE_OFFSET" \
  conv=notrunc \
  status=none
if grep -Fqa "$CANBERRA_COMPILED_DRIVER_PATH" "$CANBERRA_BUNDLED_LIBRARY"; then
  echo "错误：libcanberra 仍包含宿主机绝对驱动路径。" >&2
  exit 1
fi
if ! grep -Fqa "$CANBERRA_PORTABLE_DRIVER_NAME" "$CANBERRA_BUNDLED_LIBRARY"; then
  echo "错误：libcanberra 可移植驱动模板写入失败。" >&2
  exit 1
fi
printf 'libcanberra 驱动路径已改为 AppImage 内部搜索：%s -> %s\n' \
  "$CANBERRA_COMPILED_DRIVER_PATH" \
  "$CANBERRA_PORTABLE_DRIVER_NAME"

# Rainlendar 的插件 API Rainlendar_GetPath 原本把每次路径结果写回同一个 static wxString。
# Google Tasks、Google Calendar、CalDAV、Office365、Microsoft To Do 等网络线程都会调用它；
# 多线程同时覆盖同一个 wxString 时会产生数据竞争，实际 core dump 已出现 malloc tcache 损坏并 SIGABRT。
# 这里仅替换共享静态写入区：保留上游 GetPath 计算、栈保护和调用 ABI，每次返回独立的 wxString 快照。
# 不改 Google Tasks 逻辑，也不关闭任何同步功能；上游布局不符合已确认结构时直接失败，禁止猜测修改。
cat > /tmp/patch_rainlendar_getpath.py <<'PY_EOF'
#!/usr/bin/env python3
import re
import struct
import subprocess
import sys

MODE = sys.argv[1]
BINARY = sys.argv[2]

if MODE not in {"patch", "check"}:
    raise SystemExit("用法：patch_rainlendar_getpath.py {patch|check} <rainlendar2>")


def run(*args):
    return subprocess.check_output(args, text=True, errors="strict")


NM_OUTPUT = run("nm", "-S", "-C", BINARY)


def find_symbol(name, required=True):
    matches = []
    for line in NM_OUTPUT.splitlines():
        match = re.match(r"^([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([A-Za-z])\s+(.+)$", line)
        if match and match.group(4) == name:
            matches.append((int(match.group(1), 16), int(match.group(2), 16)))
    matches = sorted(set(matches))
    if not matches and not required:
        return None
    if len(matches) != 1:
        raise SystemExit(f"错误：符号 {name!r} 应唯一存在，实际为 {matches}")
    return matches[0]


TARGET_ADDR, TARGET_SIZE = find_symbol("Rainlendar_GetPath")
STATIC_RESULT = find_symbol("Rainlendar_GetPath::strResult", required=False)

DISASSEMBLY = run(
    "objdump",
    "-d",
    "-C",
    f"--start-address={hex(TARGET_ADDR)}",
    f"--stop-address={hex(TARGET_ADDR + TARGET_SIZE)}",
    BINARY,
)

instructions = []
for line in DISASSEMBLY.splitlines():
    match = re.match(r"^\s*([0-9a-fA-F]+):\s+(?:[0-9a-fA-F]{2}\s+)+\s*(.*?)\s*$", line)
    if match:
        instructions.append((int(match.group(1), 16), match.group(2)))

getpath_calls = [
    address
    for address, asm in instructions
    if asm.startswith("call") and "<CRainlendar::GetPath(PATH_TYPE)>" in asm
]
move_assign_calls = [
    address
    for address, asm in instructions
    if asm.startswith("call") and "<wxString::operator=(wxString&&)>" in asm
]

if len(getpath_calls) != 1:
    raise SystemExit(f"错误：Rainlendar_GetPath 内 CRainlendar::GetPath 调用数量异常：{getpath_calls}")

GETPATH_CALL = getpath_calls[0]
PATCH_START = GETPATH_CALL + 5

# 如果上游以后删除共享静态返回值，并且不再执行 move-assign，则认为上游已修复，自动跳过二进制补丁。
if STATIC_RESULT is None and not move_assign_calls:
    print("Rainlendar_GetPath 已不再使用共享静态返回值；检测为上游已修复，跳过本地并发补丁。")
    raise SystemExit(0)

if STATIC_RESULT is None:
    raise SystemExit("错误：Rainlendar_GetPath 仍存在旧调用结构，但无法找到共享静态 strResult；拒绝猜测补丁。")

if STATIC_RESULT[1] != 48:
    raise SystemExit(f"错误：共享 wxString 大小异常：{STATIC_RESULT[1]}，拒绝补丁。")

MOVE_CTOR_ADDR, _ = find_symbol("wxString::wxString(wxString&&)")
DTOR_ADDR, _ = find_symbol("wxString::~wxString()")

# 保留原程序的 stack canary/leave/ret 收尾，只替换 GetPath 返回后的共享静态写入区。
canary_starts = [
    address
    for address, asm in instructions
    if address > PATCH_START and re.fullmatch(r"mov\s+-0x8\(%rbp\),%rdx", asm)
]
if len(canary_starts) != 1:
    raise SystemExit(f"错误：无法唯一定位 Rainlendar_GetPath 的 stack canary 收尾：{canary_starts}")

PATCH_END = canary_starts[0]
PATCH_SIZE = PATCH_END - PATCH_START

# 当前易受并发影响的实现中，CRainlendar::GetPath 的返回对象位于 rbp-0x40；
# rbp-0x50..rbp-0x49 是 0x50 字节栈帧中未使用的 8 字节槽，用来临时保存 heap 指针。
pre_getpath = "\n".join(asm for address, asm in instructions if GETPATH_CALL - 32 <= address < GETPATH_CALL)
if "-0x40(%rbp)" not in pre_getpath:
    raise SystemExit("错误：无法确认 Rainlendar_GetPath 的局部 wxString 位于 rbp-0x40，拒绝补丁。")
if not re.search(r"sub\s+\$0x50,%rsp", DISASSEMBLY):
    raise SystemExit("错误：Rainlendar_GetPath 栈帧不再是 0x50 字节，拒绝补丁。")

PLT_DISASSEMBLY = run("objdump", "-d", BINARY)
malloc_match = re.search(r"^([0-9a-fA-F]+) <malloc@plt>:$", PLT_DISASSEMBLY, re.MULTILINE)
if not malloc_match:
    raise SystemExit("错误：找不到 malloc@plt。")
MALLOC_ADDR = int(malloc_match.group(1), 16)


def build_patch():
    code = bytearray()

    def emit(hex_bytes):
        code.extend(bytes.fromhex(hex_bytes))

    def emit_call(destination):
        next_ip = PATCH_START + len(code) + 5
        relative = destination - next_ip
        if not -(1 << 31) <= relative < (1 << 31):
            raise SystemExit("错误：x86-64 rel32 调用超出范围。")
        code.extend(b"\xe8" + struct.pack("<i", relative))

    # 上游函数原本把每次 GetPath 结果 move-assign 到同一个 static wxString，多个同步线程会同时改写它。
    # 改为为本次调用分配独立的 48 字节 wxString 对象，并 move-construct 出不可再被其他线程覆盖的快照。
    # API 原本返回进程生命周期 static 对象的指针，调用方不会释放它；因此这里也让快照保留到进程退出。
    # 代价是每次路径查询保留一个很小的 wxString 对象，但路径查询只发生在启动/同步等低频路径，
    # 比继续共享同一个可变 wxString 更适合作为 AppImage 的稳定性修复。
    emit("bf30000000")      # mov edi, 48
    emit_call(MALLOC_ADDR)  # malloc(sizeof(wxString))
    emit("488945b0")        # mov [rbp-0x50], rax
    emit("4889c7")          # mov rdi, rax
    emit("488d75c0")        # lea rsi, [rbp-0x40]
    emit_call(MOVE_CTOR_ADDR)
    emit("488d7dc0")        # lea rdi, [rbp-0x40]
    emit_call(DTOR_ADDR)
    emit("488b45b0")        # mov rax, [rbp-0x50]

    if len(code) > PATCH_SIZE:
        raise SystemExit(f"错误：并发补丁需要 {len(code)} 字节，但安全区域只有 {PATCH_SIZE} 字节。")
    code.extend(b"\x90" * (PATCH_SIZE - len(code)))
    return bytes(code)


EXPECTED_PATCH = build_patch()

# ELF64 little-endian：把虚拟地址映射到文件偏移，避免假设 .text 的 VADDR 恰好等于文件偏移。
with open(BINARY, "rb") as handle:
    elf_header = handle.read(64)
if elf_header[:6] != b"\x7fELF\x02\x01":
    raise SystemExit("错误：只支持 ELF64 little-endian Rainlendar 二进制。")

program_header_offset = struct.unpack_from("<Q", elf_header, 32)[0]
program_header_size = struct.unpack_from("<H", elf_header, 54)[0]
program_header_count = struct.unpack_from("<H", elf_header, 56)[0]


def virtual_to_file_offset(vaddr):
    with open(BINARY, "rb") as handle:
        for index in range(program_header_count):
            handle.seek(program_header_offset + index * program_header_size)
            program_header = handle.read(program_header_size)
            p_type = struct.unpack_from("<I", program_header, 0)[0]
            if p_type != 1:  # PT_LOAD
                continue
            p_offset, p_vaddr, _, p_filesz = struct.unpack_from("<QQQQ", program_header, 8)
            if p_vaddr <= vaddr < p_vaddr + p_filesz:
                return p_offset + (vaddr - p_vaddr)
    raise SystemExit(f"错误：虚拟地址 0x{vaddr:x} 不在文件映射的 PT_LOAD 段中。")


PATCH_FILE_OFFSET = virtual_to_file_offset(PATCH_START)
with open(BINARY, "rb") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    CURRENT_PATCH_AREA = handle.read(PATCH_SIZE)

already_patched = CURRENT_PATCH_AREA == EXPECTED_PATCH

if MODE == "check":
    if already_patched:
        print("Rainlendar_GetPath 并发安全补丁验证通过。")
        raise SystemExit(0)
    if STATIC_RESULT is None and not move_assign_calls:
        print("Rainlendar_GetPath 已由上游修复，无需本地并发补丁。")
        raise SystemExit(0)
    raise SystemExit("错误：Rainlendar_GetPath 仍是共享静态返回实现，或补丁内容与预期不一致。")

if already_patched:
    print("Rainlendar_GetPath 并发安全补丁已存在，无需重复写入。")
    raise SystemExit(0)

# 只允许对已确认的共享静态 move-assign 实现动刀；上游布局发生变化时直接失败，禁止盲目 patch。
if len(move_assign_calls) != 1 or not (PATCH_START < move_assign_calls[0] < PATCH_END):
    raise SystemExit(f"错误：共享静态 move-assign 结构异常：{move_assign_calls}，拒绝补丁。")
if "Rainlendar_GetPath::strResult" not in DISASSEMBLY:
    raise SystemExit("错误：反汇编中没有共享静态 strResult 引用，拒绝补丁。")

with open(BINARY, "r+b") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    handle.write(EXPECTED_PATCH)

with open(BINARY, "rb") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    if handle.read(PATCH_SIZE) != EXPECTED_PATCH:
        raise SystemExit("错误：Rainlendar_GetPath 二进制补丁写入后校验失败。")

print(
    f"Rainlendar_GetPath 并发安全补丁完成："
    f"0x{PATCH_START:x}-0x{PATCH_END:x}，共享静态返回改为独立 wxString 快照。"
)
PY_EOF
chmod +x /tmp/patch_rainlendar_getpath.py

RAINLENDAR_BINARY="$APPDIR/usr/lib/rainlendar2/rainlendar2"
python3 /tmp/patch_rainlendar_getpath.py patch "$RAINLENDAR_BINARY"
python3 /tmp/patch_rainlendar_getpath.py check "$RAINLENDAR_BINARY"

# 官方二进制与 IBus GTK3 模块所需的非系统运行库必须随包提供；
# glibc 与动态加载器仍使用宿主机。
for soname in libstdc++.so.6 libgcc_s.so.1 libibus-1.0.so.5; do
  library="$(ldconfig -p | awk -v name="$soname" '$1 == name {print $NF; exit}')"
  if [[ -z "$library" || ! -f "$library" ]]; then
    echo "错误：找不到 $soname。" >&2
    exit 1
  fi
  cp -aL "$library" "$APPDIR/usr/lib/$soname"
done

# 使用与包内 GTK3 匹配的 IBus 模块，通过 D-Bus 连接宿主机 Fcitx5。
GTK_IMMODULE_DIR="$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
IBUS_IMMODULE_SOURCE="$(find /usr/lib -type f -path '*/gtk-3.0/*/immodules/im-ibus.so' -print -quit)"
if [[ -z "$IBUS_IMMODULE_SOURCE" || ! -f "$IBUS_IMMODULE_SOURCE" ]]; then
  echo "错误：构建环境中找不到 im-ibus.so。" >&2
  exit 1
fi
mkdir -p "$GTK_IMMODULE_DIR"
cp -aL "$IBUS_IMMODULE_SOURCE" "$GTK_IMMODULE_DIR/im-ibus.so"

# 禁止把会导致 Rainlendar 随机闪退的 Fcitx5 GTK 模块带入。
find "$APPDIR" -type f -name 'im-fcitx5.so' -delete
rm -f "$APPDIR/usr/lib/libFcitx5GClient.so.2"

test -f "$GTK_IMMODULE_DIR/im-ibus.so"
test -f "$APPDIR/usr/lib/libibus-1.0.so.5"
test -f "$APPDIR/usr/lib/rainlendar2/resources/alarm.wav"
test -n "$(find "$APPDIR/usr/lib" \( -type f -o -type l \) -name 'libcanberra.so.0' -print -quit)"
test -n "$(find "$APPDIR/usr/lib" \( -type f -o -type l \) -name 'libcanberra-pulse.so' -print -quit)"
python3 /tmp/patch_rainlendar_getpath.py check "$APPDIR/usr/lib/rainlendar2/rainlendar2"
if grep -Fqa "$CANBERRA_COMPILED_DRIVER_PATH" "$APPDIR/usr/lib/libcanberra.so.0"; then
  echo "错误：AppDir 中的 libcanberra 仍引用宿主机绝对驱动路径。" >&2
  exit 1
fi
if ! grep -Fqa "$CANBERRA_PORTABLE_DRIVER_NAME" "$APPDIR/usr/lib/libcanberra.so.0"; then
  echo "错误：AppDir 中的 libcanberra 缺少可移植驱动模板。" >&2
  exit 1
fi
if ! grep -Fq 'export GTK_THEME=Adwaita:dark' "$APPDIR/AppRun"; then
  echo "错误：AppRun 中缺少 GTK3 深色主题配置。" >&2
  exit 1
fi
if ! grep -Fq 'export CANBERRA_DRIVER=pulse' "$APPDIR/AppRun"; then
  echo "错误：AppRun 中缺少 libcanberra Pulse 后端配置。" >&2
  exit 1
fi
if ! grep -Fq 'export GTK_IM_MODULE=ibus' "$APPDIR/AppRun"; then
  echo "错误：AppRun 中缺少 GTK IBus 配置。" >&2
  exit 1
fi
if ! grep -Fq 'export LD_LIBRARY_PATH=' "$APPDIR/AppRun"; then
  echo "错误：AppRun 中缺少 AppImage 运行库搜索路径。" >&2
  exit 1
fi
if ! grep -Fq 'cd "$APPDIR/usr/lib/rainlendar2"' "$APPDIR/AppRun"; then
  echo "错误：AppRun 中缺少默认铃声相对路径所需的工作目录修复。" >&2
  exit 1
fi
(
  cd "$APPDIR/usr/lib/rainlendar2"
  test -f resources/alarm.wav
)
echo "GTK IBus 中文输入、Google Tasks 并发路径、铃声驱动路径、铃声工作目录与运行库路径验证完成。"

if find "$APPDIR" \( -type f -o -type l \) \
  \( -name 'libc.so.6' -o -name 'ld-linux-x86-64.so.2' \) \
  -print -quit | grep -q .; then
  echo "错误：AppDir 中不应包含 glibc 或动态加载器。" >&2
  exit 1
fi

/tmp/appimagetool -n \
  --runtime-file /tmp/runtime-x86_64 \
  "$APPDIR" \
  "$OUTFILE"
chmod +x "$OUTFILE"

# 解包最终产物，确认输入模块、Google Tasks 并发补丁、铃声驱动、资源和 glibc 排除没有丢失。
VERIFY_DIR="/tmp/rainlendar-appimage-verify"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  "$OUTFILE" --appimage-extract >/dev/null
)
VERIFY_APPDIR="$VERIFY_DIR/squashfs-root"
test -x "$VERIFY_APPDIR/usr/lib/rainlendar2/rainlendar2"
test ! -e "$VERIFY_APPDIR/AppRun.wrapped"
VERIFY_IMMODULE_DIR="$VERIFY_APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"
test -f "$VERIFY_APPDIR/usr/lib/libstdc++.so.6"
test -f "$VERIFY_APPDIR/usr/lib/libgcc_s.so.1"
test -f "$VERIFY_APPDIR/usr/lib/libibus-1.0.so.5"
test -f "$VERIFY_IMMODULE_DIR/im-ibus.so"
test -f "$VERIFY_APPDIR/usr/lib/rainlendar2/resources/alarm.wav"
test -n "$(find "$VERIFY_APPDIR/usr/lib" \( -type f -o -type l \) -name 'libcanberra.so.0' -print -quit)"
test -n "$(find "$VERIFY_APPDIR/usr/lib" \( -type f -o -type l \) -name 'libcanberra-pulse.so' -print -quit)"
python3 /tmp/patch_rainlendar_getpath.py check "$VERIFY_APPDIR/usr/lib/rainlendar2/rainlendar2"
if grep -Fqa "$CANBERRA_COMPILED_DRIVER_PATH" "$VERIFY_APPDIR/usr/lib/libcanberra.so.0"; then
  echo "错误：最终 AppImage 的 libcanberra 仍引用宿主机绝对驱动路径。" >&2
  exit 1
fi
if ! grep -Fqa "$CANBERRA_PORTABLE_DRIVER_NAME" "$VERIFY_APPDIR/usr/lib/libcanberra.so.0"; then
  echo "错误：最终 AppImage 的 libcanberra 缺少可移植驱动模板。" >&2
  exit 1
fi
test ! -e "$VERIFY_APPDIR/usr/lib/libFcitx5GClient.so.2"
if find "$VERIFY_APPDIR" -type f -name 'im-fcitx5.so' -print -quit | grep -q .; then
  echo "错误：最终 AppImage 中不应包含 im-fcitx5.so。" >&2
  exit 1
fi
grep -Fq 'rainlendar-appimage-immodules' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export GTK_IM_MODULE=ibus' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export GTK_IM_MODULE_FILE=' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export GTK_THEME=Adwaita:dark' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export CANBERRA_DRIVER=pulse' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export LTDL_LIBRARY_PATH=' "$VERIFY_APPDIR/AppRun"
grep -Fq 'export LD_LIBRARY_PATH=' "$VERIFY_APPDIR/AppRun"
grep -Fq 'cd "$APPDIR/usr/lib/rainlendar2"' "$VERIFY_APPDIR/AppRun"
(
  cd "$VERIFY_APPDIR/usr/lib/rainlendar2"
  test -f resources/alarm.wav
)
test ! -e "$VERIFY_APPDIR/usr/lib/libc.so.6"
test ! -e "$VERIFY_APPDIR/usr/lib/ld-linux-x86-64.so.2"

if ldd "$VERIFY_APPDIR/usr/lib/rainlendar2/rainlendar2" | grep -Fq 'not found'; then
  echo "错误：最终 AppImage 中仍有未满足的动态库。" >&2
  ldd "$VERIFY_APPDIR/usr/lib/rainlendar2/rainlendar2" >&2
  exit 1
fi

chown "$HOST_UID:$HOST_GID" "$OUTFILE" 2>/dev/null || true
echo "已生成并验证：$OUTFILE"
INNER_EOF
