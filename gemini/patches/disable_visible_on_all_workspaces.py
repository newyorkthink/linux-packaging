#!/usr/bin/env python3
"""Linux 补丁：取消 Gemini 主窗口的 visible-on-all-workspaces。

Windows 原版会把主窗口设为 visible-on-all-workspaces。Linux/i3 会把它映射成 sticky，
并且应用会在窗口创建后再次设置，导致 i3 的一次性 for_window 规则被覆盖。
这里只改写当前官方产品层里显式的 true / !0 调用。上游结构变化时直接失败，不猜测新逻辑。
"""

import re
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit(
        f"用法：{sys.argv[0]} <已提取的 app.asar 目录> <true|false>"
    )

root = Path(sys.argv[1])
native_addon_removed = sys.argv[2] == "true"
pattern = re.compile(r"setVisibleOnAllWorkspaces\(\s*(?:true|!0)(?=\s*[,\)])")
patched = []
native_fallback_found = False

for path in root.rglob("*"):
    if not path.is_file() or path.suffix not in {".js", ".cjs", ".mjs"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    if (
        "gemini_native addon unavailable; STC will use safe fallbacks" in text
        and "GEMINI_ENABLE_SPEAK_TO_WINDOW" in text
    ):
        native_fallback_found = True

    new_text, count = pattern.subn("setVisibleOnAllWorkspaces(false", text)
    if count:
        path.write_text(new_text, encoding="utf-8")
        patched.append((path.relative_to(root), count))

if not patched:
    raise SystemExit(
        "Gemini product layer no longer contains a recognized "
        "setVisibleOnAllWorkspaces(true/!0) call"
    )
if native_addon_removed and not native_fallback_found:
    raise SystemExit(
        "Gemini product layer no longer declares the safe fallback "
        "for the optional Windows native addon"
    )

total = sum(count for _, count in patched)
print(f"Patched Gemini visible-on-all-workspaces calls: {total}")
for path, count in patched:
    print(f"  {path}: {count}")
