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
# quick-sharun 由与源仓库一致的 AnyLinux setup action 提供，不在本脚本另行覆盖。
# 源仓库 2026-08-20 成功发布时 appimagetool latest 为 0.3.3；这里只固定该版本，
# 避免 2026-08-31 发布的 0.3.4 改变 AppImage/uruntime 结构。

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

# 源仓库与目标仓库都由相同 AnyLinux setup action 提供 quick-sharun；不要在这里
# 再覆盖 quick-sharun，否则 01-path-mapping-hardcoded.hook 的格式可能偏离稳定基线。
export APPIMAGETOOL_LINK='https://github.com/pkgforge-dev/appimagetool/releases/download/0.3.3/appimagetool-x86_64-linux'

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

cc -shared -fPIC -O2 -Wall -Wextra -Werror \
  AppDir/.jriver-cef-shutdown-guard.c \
  -o AppDir/lib/jriver-cef-shutdown-guard.so -ldl
rm -f AppDir/.jriver-cef-shutdown-guard.c

# 由 Sharun 加载该极小 guard；只有 JRWeb wrapper 设置跳过变量，其他进程继续转发真实 cef_shutdown。
sed -i '/^jriver-cef-shutdown-guard\\.so$/d' AppDir/.preload
echo 'jriver-cef-shutdown-guard.so' >> AppDir/.preload

if ! nm -D --defined-only AppDir/lib/jriver-cef-shutdown-guard.so \
     | awk '{print $3}' | grep -qxF 'cef_shutdown'; then
  echo '错误：JRWeb CEF shutdown guard 未导出 cef_shutdown。' >&2
  exit 1
fi
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

preload_check_anchor = '''if lines.index("anylinux.so") > lines.index("jriver-cef-env.so"):
    raise SystemExit("jriver-cef-env.so must load after anylinux.so")
'''
preload_check_patch = preload_check_anchor + '''if lines.count("jriver-cef-shutdown-guard.so") != 1:
    raise SystemExit("jriver-cef-shutdown-guard.so preload entry must appear exactly once")
if lines.index("jriver-cef-env.so") > lines.index("jriver-cef-shutdown-guard.so"):
    raise SystemExit("CEF shutdown guard must load after jriver-cef-env.so")
'''

for name, anchor in (
    ("CEF private runtime", runtime_anchor),
    ("JRWeb wrapper exec", wrapper_anchor),
    ("preload order validator", preload_check_anchor),
):
    count = text.count(anchor)
    if count != 1:
        raise SystemExit(f"JRiver verified baseline changed: {name} anchor count={count}")

text = text.replace(runtime_anchor, runtime_patch, 1)
text = text.replace(wrapper_anchor, wrapper_patch, 1)
text = text.replace(preload_check_anchor, preload_check_patch, 1)

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
