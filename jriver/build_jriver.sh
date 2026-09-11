#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# JRiver Media Center AnyLinux AppImage 构建入口
# ==============================================================================
# 迁移保持源仓库 jriver 目录结构：README.md / build_jriver.sh /
# jriver_cef_runtime.sh。源仓库稳定构建链原本依赖 private 仓库 Git 历史；目标仓库
# 不再要求 Actions checkout 必须包含旧 commit，而是从本仓库公开的固定迁移提交读取
# 已校验音频 wrapper 与核心基线，构建时临时展开，不把辅助层留在 jriver 目录中。
#
# quick-sharun 继续由 AnyLinux setup action 提供当前版本，不固定上游版本。
# 本入口只兼容 quick-sharun 的旧 .preload 布局与新版 lib/sharun-preload 布局，
# 保持 JRiver 既有 anylinux -> CEF 环境层 -> shutdown guard 的加载顺序。
# appimagetool 也使用当前 quick-sharun 自带的版本与校验值，不再单独固定。

cd "$(dirname "$0")"

BASE_COMMIT='4a08912cd31a5659bb43395dfeda0c5257abdeab'
AUDIO_BLOB='3a247e16dab1f444982e4e9ec66bd0eabe1183bc'
CORE_BLOB='a589c8f8e11480b1805226d8d8c247bc7d689d4e'
BASE_RAW="https://raw.githubusercontent.com/newyorkthink/linux-packaging/${BASE_COMMIT}/jriver"
WRAPPED="$(mktemp "$PWD/.build_jriver_verified.XXXXXX.sh")"
BASE_FILE="$PWD/build_jriver_base.sh"

cleanup() {
  rm -f "$WRAPPED" "$BASE_FILE"
}
trap cleanup EXIT

# 固定迁移提交是公开仓库内容，不依赖当前 checkout 是否保留完整 Git 历史。
curl -fL --retry 3 --retry-delay 2 \
  "$BASE_RAW/build_jriver_audio.sh" -o "$WRAPPED"
curl -fL --retry 3 --retry-delay 2 \
  "$BASE_RAW/build_jriver_base.sh" -o "$BASE_FILE"

if [[ "$(git hash-object "$WRAPPED")" != "$AUDIO_BLOB" ]]; then
  echo '错误：JRiver 已验证音频基线与固定 blob SHA 不一致。' >&2
  exit 1
fi
if [[ "$(git hash-object "$BASE_FILE")" != "$CORE_BLOB" ]]; then
  echo '错误：JRiver 核心稳定基线与固定 blob SHA 不一致。' >&2
  exit 1
fi

# quick-sharun 与 appimagetool 均使用 AnyLinux setup action 当前提供的版本。

# 在音频 wrapper 生成最终脚本后追加 CEF shutdown 保护和启动路径映射。
python3 - "$WRAPPED" <<'PY_OUTER_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

execute_anchor = '''chmod +x "$PATCHED"
bash -n "$PATCHED"
bash "$PATCHED" "$@"'''

execute_patch = r"""chmod +x "$PATCHED"

python3 - "$PATCHED" <<'PY_CEF_SHUTDOWN_PATCH'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

runtime_anchor = '''cp -a "$CEF_ROOT/Release/." "$CEF_PRIVATE_DIR/"
cp -a "$CEF_ROOT/Resources/." "$CEF_PRIVATE_DIR/"
'''
runtime_patch = runtime_anchor + r'''
# 2026-08-14：仅保护 JRWeb 的 CEF 退出阶段。
# 不替换 libcef.so，不改 CEF ABI，不改 Pulse/ALSA，也不恢复全局 LD_LIBRARY_PATH。
cat > AppDir/.jriver-cef-shutdown-guard.c <<'EOF_CEF_SHUTDOWN_GUARD'
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <dlfcn.h>
#include <stdlib.h>

typedef void (*cef_shutdown_fn_t)(void);

__attribute__((visibility("default")))
void cef_shutdown(void)
{
    const char *skip = getenv("JRIVER_CEF_SKIP_SHUTDOWN");
    cef_shutdown_fn_t real_shutdown;

    if (skip && *skip)
        return;

    real_shutdown = (cef_shutdown_fn_t)dlsym(RTLD_NEXT, "cef_shutdown");
    if (real_shutdown)
        real_shutdown();
}
EOF_CEF_SHUTDOWN_GUARD

JRIVER_SHUTDOWN_GUARD_LIB="$JRIVER_PRELOAD_DIR/jriver-cef-shutdown-guard.so"
cc -shared -fPIC -O2 -Wall -Wextra -Werror \
  AppDir/.jriver-cef-shutdown-guard.c \
  -o "$JRIVER_SHUTDOWN_GUARD_LIB" -ldl
rm -f AppDir/.jriver-cef-shutdown-guard.c

# 旧布局由 .preload 显式加载；新版 sharun-preload 目录由 Sharun 自动按文件名排序加载。
sed -i '/^jriver-cef-shutdown-guard\\.so$/d' AppDir/.preload 2>/dev/null || true
if [[ "$JRIVER_PRELOAD_MODE" == 'legacy' ]]; then
  echo 'jriver-cef-shutdown-guard.so' >> AppDir/.preload
fi

if ! nm -D --defined-only "$JRIVER_SHUTDOWN_GUARD_LIB" \
     | awk '{print $3}' | grep -qxF 'cef_shutdown'; then
  echo '错误：JRWeb CEF shutdown guard 未导出 cef_shutdown。' >&2
  exit 1
fi
'''


preload_layout_anchor = r'''cc -shared -fPIC -O2 -Wall -Wextra -Werror AppDir/.jriver-cef-env.c \
  -o AppDir/lib/jriver-cef-env.so -ldl
rm -f AppDir/.jriver-cef-env.c

if ! grep -qxF 'anylinux.so' AppDir/.preload; then
  echo '错误：quick-sharun 未启用 anylinux.so，无法保证 JRWebChromium 环境清理顺序。' >&2
  exit 1
fi
sed -i '/^jriver-cef-env\.so$/d' AppDir/.preload
echo 'jriver-cef-env.so' >> AppDir/.preload
'''

preload_layout_patch = r'''cc -shared -fPIC -O2 -Wall -Wextra -Werror AppDir/.jriver-cef-env.c \
  -o AppDir/lib/jriver-cef-env.so -ldl
rm -f AppDir/.jriver-cef-env.c

# quick-sharun 旧版把 anylinux.so 写入 AppDir/.preload；
# 新版将 helper preload 放入 lib/sharun-preload 并按文件名排序自动加载。
if [[ -f AppDir/lib/sharun-preload/anylinux.so ]]; then
  JRIVER_PRELOAD_MODE='directory'
  JRIVER_PRELOAD_DIR='AppDir/lib/sharun-preload'
  JRIVER_CEF_ENV_LIB="$JRIVER_PRELOAD_DIR/jriver-cef-env.so"
  mv -f AppDir/lib/jriver-cef-env.so "$JRIVER_CEF_ENV_LIB"
  sed -i '/^anylinux\.so$/d; /^jriver-cef-env\.so$/d; /^jriver-cef-shutdown-guard\.so$/d' \
    AppDir/.preload 2>/dev/null || true
elif [[ -f AppDir/lib/anylinux.so ]] && grep -qxF 'anylinux.so' AppDir/.preload; then
  JRIVER_PRELOAD_MODE='legacy'
  JRIVER_PRELOAD_DIR='AppDir/lib'
  JRIVER_CEF_ENV_LIB='AppDir/lib/jriver-cef-env.so'
  sed -i '/^jriver-cef-env\.so$/d' AppDir/.preload
  echo 'jriver-cef-env.so' >> AppDir/.preload
else
  echo '错误：无法识别 quick-sharun 的 anylinux.so preload 布局。' >&2
  exit 1
fi
'''

preload_validator_anchor = r'''# anylinux.so 必须先清理环境，jriver-cef-env.so 再精确补入 CEF 路径。
python3 - AppDir/.preload <<'PY_CEF_PRELOAD_ORDER'
from pathlib import Path
import sys

lines = [line.strip() for line in Path(sys.argv[1]).read_text().splitlines() if line.strip()]
if lines.count("anylinux.so") != 1:
    raise SystemExit("anylinux.so preload entry must appear exactly once")
if lines.count("jriver-cef-env.so") != 1:
    raise SystemExit("jriver-cef-env.so preload entry must appear exactly once")
if lines.index("anylinux.so") > lines.index("jriver-cef-env.so"):
    raise SystemExit("jriver-cef-env.so must load after anylinux.so")
PY_CEF_PRELOAD_ORDER
'''

preload_validator_patch = r'''# 按 Sharun 实际加载规则重建 preload 顺序：先 .preload，再新版 sharun-preload 排序目录。
python3 - AppDir/.preload "$JRIVER_PRELOAD_MODE" "$JRIVER_PRELOAD_DIR" <<'PY_CEF_PRELOAD_ORDER'
from pathlib import Path
import sys

preload_file = Path(sys.argv[1])
mode = sys.argv[2]
preload_dir = Path(sys.argv[3])

lines = []
if preload_file.exists():
    lines.extend(line.strip() for line in preload_file.read_text().splitlines() if line.strip())

if mode == "directory":
    libs = sorted(
        path.name
        for path in preload_dir.iterdir()
        if path.is_file() and (path.name.endswith(".so") or ".so." in path.name)
    )
    lines.extend(libs)
elif mode != "legacy":
    raise SystemExit(f"unknown JRiver preload mode: {mode}")

for required in ("anylinux.so", "jriver-cef-env.so", "jriver-cef-shutdown-guard.so"):
    if lines.count(required) != 1:
        raise SystemExit(f"{required} preload entry must appear exactly once")

if lines.index("anylinux.so") > lines.index("jriver-cef-env.so"):
    raise SystemExit("jriver-cef-env.so must load after anylinux.so")
if lines.index("jriver-cef-env.so") > lines.index("jriver-cef-shutdown-guard.so"):
    raise SystemExit("CEF shutdown guard must load after jriver-cef-env.so")
PY_CEF_PRELOAD_ORDER
'''

cef_symbols_anchor = '''CEF_ENV_SYMBOLS="$(nm -D --defined-only AppDir/lib/jriver-cef-env.so | awk '{print $3}')"
'''
cef_symbols_patch = '''CEF_ENV_SYMBOLS="$(nm -D --defined-only "$JRIVER_CEF_ENV_LIB" | awk '{print $3}')"
'''

wrapper_anchor = '''if [ "$CHILD_NAME" = "JRWeb" ] && [ -d "$HERE/cef-runtime" ]; then
  LD_LIBRARY_PATH="$HERE/cef-runtime"
  export LD_LIBRARY_PATH
fi

exec "$SHARUN_CHILD" "$@"
'''
wrapper_patch = '''if [ "$CHILD_NAME" = "JRWeb" ] && [ -d "$HERE/cef-runtime" ]; then
  LD_LIBRARY_PATH="$HERE/cef-runtime"
  export LD_LIBRARY_PATH

  # JRWeb 关闭内嵌 CEF 时存在 observer 未清理断言；仅该专用子进程跳过 cef_shutdown。
  # JRWebChromium、主程序及其它进程不设置此变量，不改变其 CEF 生命周期。
  JRIVER_CEF_SKIP_SHUTDOWN=1
  export JRIVER_CEF_SKIP_SHUTDOWN
fi

exec "$SHARUN_CHILD" "$@"
'''


for name, anchor in (
    ("CEF private runtime", runtime_anchor),
    ("quick-sharun preload layout", preload_layout_anchor),
    ("JRWeb wrapper exec", wrapper_anchor),
    ("preload order validator", preload_validator_anchor),
    ("CEF env symbol path", cef_symbols_anchor),
):
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"JRiver verified baseline changed: {name} anchor count={count}")

text = text.replace(runtime_anchor, runtime_patch, 1)
text = text.replace(preload_layout_anchor, preload_layout_patch, 1)
text = text.replace(wrapper_anchor, wrapper_patch, 1)
text = text.replace(preload_validator_anchor, preload_validator_patch, 1)
text = text.replace(cef_symbols_anchor, cef_symbols_patch, 1)

# 自定义 AppRun 绕过了 AppRun.sh，必须显式执行 JRiver 硬编码路径对应的 hook。
# 不恢复旧包的全局 LD_LIBRARY_PATH，也不改变 pathmap / run-mc.sh 的执行顺序。
pathmap_anchor = 'PATHMAP="$APPDIR/usr/bin/pathmap"\n'
pathmap_patch = '''# 先建立 quick-sharun 写入程序和插件的 /tmp 路径映射。
# 直接运行 bin/mediacenter 不会进入 AppRun.sh，因此不会自动执行此 hook。
JRIVER_PATH_HOOK="$APPDIR/bin/01-path-mapping-hardcoded.hook"
if [ ! -f "$JRIVER_PATH_HOOK" ]; then
  JRIVER_PATH_HOOK="$APPDIR/shared/bin/01-path-mapping-hardcoded.hook"
fi
if [ ! -f "$JRIVER_PATH_HOOK" ]; then
  echo '错误：JRiver 缺少硬编码路径映射 hook。' >&2
  exit 1
fi
. "$JRIVER_PATH_HOOK"

''' + pathmap_anchor
if text.count(pathmap_anchor) != 1:
    raise SystemExit("JRiver AppRun pathmap anchor changed")
text = text.replace(pathmap_anchor, pathmap_patch, 1)

# 历史固定基线含独立 CEF 自测及诊断输出；按仓库规则从实际构建脚本移除。
# 保留下载、输入文件、CEF ABI、私有音频依赖和运行时隔离所需的构建守卫。
for start, end in (
    ('# 9. 执行最终检查并生成 AppImage\n', '# AppRun 是宿主 shell 启动器，'),
    ('# 同时验证 exec 与 posix_spawn：', '# JRWeb 只允许在最终 exec 前设置唯一的私有 CEF 路径，'),
    ('/bin/sh -n AppDir/AppRun\n', 'quick-sharun --make-appimage\n'),
):
    if text.count(start) != 1 or text.count(end) != 1:
        raise SystemExit("JRiver historical diagnostic boundaries changed")
    first = text.index(start)
    last = text.index(end, first)
    text = text[:first] + text[last:]

path.write_text(text)
PY_CEF_SHUTDOWN_PATCH

bash "$PATCHED" "$@"
"""

if text.count(execute_anchor) != 1:
    raise SystemExit("JRiver audio wrapper changed: final execution anchor mismatch")

text = text.replace(execute_anchor, execute_patch, 1)
path.write_text(text)
PY_OUTER_PATCH

chmod +x "$WRAPPED"
bash "$WRAPPED" "$@"
