#!/usr/bin/env python3
"""从 Gemini.exe 的 ICO 中取出最大的官方 PNG 帧。

当前 ICO 含有一个声明大小和实际数据不一致的 DIB 条目，icotool 会因此终止整个提取。
这里只解析 ICO 目录并复制内嵌 PNG，不改图像，也不依赖那个 DIB 条目。
"""

import struct
import sys
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit(f"用法：{sys.argv[0]} <输入.ico> <输出.png>")

source = Path(sys.argv[1])
target = Path(sys.argv[2])
data = source.read_bytes()

if len(data) < 6:
    raise SystemExit("Gemini ICO header is truncated")

reserved, icon_type, count = struct.unpack_from("<HHH", data, 0)
if reserved != 0 or icon_type != 1 or count < 1:
    raise SystemExit("Gemini ICO header is invalid")

png_signature = b"\x89PNG\r\n\x1a\n"
candidates = []

for index in range(count):
    entry_offset = 6 + index * 16
    if entry_offset + 16 > len(data):
        continue

    bytes_in_resource, image_offset = struct.unpack_from("<II", data, entry_offset + 8)
    image_end = image_offset + bytes_in_resource
    if bytes_in_resource < 24 or image_offset < 0 or image_end > len(data):
        continue

    payload = data[image_offset:image_end]
    if not payload.startswith(png_signature) or payload[12:16] != b"IHDR":
        continue

    width, height = struct.unpack_from(">II", payload, 16)
    if width < 1 or height < 1:
        continue

    candidates.append((width * height, width, height, bytes_in_resource, index, payload))

if not candidates:
    raise SystemExit("Gemini ICO does not contain a usable embedded PNG frame")

_, width, height, _, index, payload = max(candidates)
target.write_bytes(payload)
print(f"Selected official Gemini ICO PNG frame #{index}: {width}x{height}")
