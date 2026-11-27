#!/usr/bin/env python3
from pathlib import Path
import sys

# 修补 2：Rust 后端读取与前端相同的 anylinux 配置键。
root = Path(sys.argv[1])
path = root / "src-tauri/src/app/state.rs"
text = path.read_text()

old = 'store.get("key_event_store")'
new = 'store.get("key_event_store_anylinux_v1")'

if text.count(old) != 1:
    raise SystemExit("错误：02_app_state.py 与当前 Keyviz 源码不匹配，请先检查新版本差异。")

path.write_text(text.replace(old, new, 1))
