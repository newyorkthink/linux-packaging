#!/usr/bin/env python3
from pathlib import Path
import sys

# 修补 3：给透明主覆盖层独立标题，便于排查窗口而不改变设置窗口语义。
root = Path(sys.argv[1])
path = root / "src-tauri/tauri.conf.json"
text = path.read_text()

old = '        "title": "Keyviz",'
new = '        "title": "Keyviz Overlay",'

if text.count(old) != 1:
    raise SystemExit("错误：03_window_title.py 与当前 Keyviz 源码不匹配，请先检查新版本差异。")

path.write_text(text.replace(old, new, 1))
