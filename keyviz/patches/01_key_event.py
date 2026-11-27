#!/usr/bin/env python3
from pathlib import Path
import sys

# 修补 1：使用独立 anylinux 配置键，并让普通按键默认直接显示。
root = Path(sys.argv[1])
path = root / "src/stores/key_event.ts"
text = path.read_text()

old_store = 'export const KEY_EVENT_STORE = "key_event_store";'
new_store = 'export const KEY_EVENT_STORE = "key_event_store_anylinux_v1";'
old_filter = '        filter: "modifiers",'
new_filter = '        filter: "none",'

if text.count(old_store) != 1 or text.count(old_filter) != 1:
    raise SystemExit("错误：01_key_event.py 与当前 Keyviz 源码不匹配，请先检查新版本差异。")

text = text.replace(old_store, new_store, 1)
text = text.replace(old_filter, new_filter, 1)
path.write_text(text)
