#!/usr/bin/env python3
"""从 Gemini.exe 提取的全部 ICO 中优先取出最大的官方 PNG 帧。

曾有 DIB 条目的声明大小和实际数据不一致，icotool 会因此终止整个 ICO 的提取。
保留内嵌 PNG 原样复制；没有可用 PNG 时，只把单个 DIB 帧交给 icotool 转换。
"""

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

if len(sys.argv) != 3:
    raise SystemExit(f"用法：{sys.argv[0]} <输入.ico或ICO目录> <输出.png>")

source = Path(sys.argv[1])
target = Path(sys.argv[2])
sources = sorted(source.glob("*.ico")) if source.is_dir() else [source]
png_signature = b"\x89PNG\r\n\x1a\n"
candidates = []


# 读取 PNG 自身的尺寸，保留原始图像字节。
def png_size(payload):
    if len(payload) < 33 or not payload.startswith(png_signature):
        return None
    if payload[8:16] != b"\x00\x00\x00\x0dIHDR":
        return None
    width, height = struct.unpack_from(">II", payload, 16)
    return (width, height) if width > 0 and height > 0 else None


for icon in sources:
    data = icon.read_bytes()
    if len(data) < 6:
        continue

    reserved, icon_type, count = struct.unpack_from("<HHH", data, 0)
    directory_end = 6 + count * 16
    if reserved != 0 or icon_type != 1 or count < 1 or directory_end > len(data):
        continue

    for index in range(count):
        entry_offset = 6 + index * 16
        entry = data[entry_offset:entry_offset + 16]
        bytes_in_resource, image_offset = struct.unpack_from("<II", entry, 8)
        image_end = image_offset + bytes_in_resource
        if bytes_in_resource < 24 or image_offset < directory_end or image_end > len(data):
            continue

        payload = data[image_offset:image_end]
        is_png = payload.startswith(png_signature)
        if is_png:
            size = png_size(payload)
            if size is None:
                continue
            width, height = size
        else:
            width, height = entry[0] or 256, entry[1] or 256

        bit_depth = struct.unpack_from("<H", entry, 6)[0]
        candidates.append((
            is_png, width * height, width, height, bit_depth, bytes_in_resource,
            icon, index, entry[:8], payload,
        ))

# 优先选择内嵌 PNG；否则按尺寸和色深逐帧转换，坏帧不影响后续候选。
for candidate in sorted(candidates, key=lambda item: item[:6], reverse=True):
    is_png, _, width, height, _, _, icon, index, entry_header, payload = candidate
    if not is_png:
        with tempfile.TemporaryDirectory(prefix="gemini-ico-", dir=target.parent) as work:
            frame = Path(work) / "frame.ico"
            frame.write_bytes(
                struct.pack("<HHH", 0, 1, 1)
                + entry_header + struct.pack("<II", len(payload), 22) + payload
            )
            result = subprocess.run(
                ["icotool", "--extract", "--output=-", str(frame)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
        size = png_size(result.stdout)
        if result.returncode != 0 or size is None:
            detail = result.stderr.decode("utf-8", errors="replace").strip()
            print(
                f"跳过无法转换的 Gemini ICO 帧：{icon.name} #{index}；"
                f"{detail or '未生成有效 PNG'}",
                file=sys.stderr,
            )
            continue
        payload = result.stdout
        width, height = size

    target.write_bytes(payload)
    method = "原样提取 PNG" if is_png else "转换 DIB"
    print(f"已选择官方 Gemini ICO 帧：{icon.name} #{index}，{width}x{height}（{method}）")
    break
else:
    raise SystemExit("Gemini ICO 中没有可用的 PNG 或可转换的 DIB 图标")
