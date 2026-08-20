#!/usr/bin/env python3
from pathlib import Path
import sys

# 修补 4：Linux Overlay 需要直接访问 GTK/GDK，因此只给 Linux 目标增加 gtk3 依赖。
root = Path(sys.argv[1])
path = root / "src-tauri/Cargo.toml"
text = path.read_text()

linux_dep = '''[target.'cfg(target_os = "linux")'.dependencies]
gtk = { version = "0.18", features = ["v3_24"] }

'''
marker = '[target.\'cfg(target_os = "windows")\'.dependencies]\n'

if text.count(marker) != 1:
    raise SystemExit("错误：04_linux_gtk.py 找不到唯一的 Linux GTK 依赖插入点。")
if "[target.'cfg(target_os = \"linux\")'.dependencies]" in text:
    raise SystemExit("错误：04_linux_gtk.py 检测到源码已存在 Linux 专用依赖段，请人工确认。")

path.write_text(text.replace(marker, linux_dep + marker, 1))
