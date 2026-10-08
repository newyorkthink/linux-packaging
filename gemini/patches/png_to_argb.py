#!/usr/bin/env python3
"""把官方 PNG 收成 set_gemini_icon 用的小端 ARGB。

只接受 8 位、非交错的 RGB 或 RGBA。上游图标不符合时构建停止。
"""

import struct
import sys
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def decode_png(data: bytes) -> tuple[int, int, bytes, int]:
    if not data.startswith(PNG_SIGNATURE):
        raise SystemExit("Gemini 图标不是 PNG")
    offset = len(PNG_SIGNATURE)
    width = height = color_type = None
    idat = bytearray()
    while offset + 8 <= len(data):
        length, chunk_type = struct.unpack_from(">I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + length]
        offset += length + 4
        if len(chunk) != length:
            raise SystemExit("Gemini PNG 块被截断")
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            if bit_depth != 8 or compression != 0 or filter_method != 0 or interlace != 0:
                raise SystemExit("Gemini PNG 不是 8 位非交错图")
            if color_type not in (2, 6):
                raise SystemExit(f"Gemini PNG 颜色类型不支持：{color_type}")
        elif chunk_type == b"IDAT":
            idat.extend(chunk)
        elif chunk_type == b"IEND":
            break
    if width is None or height is None or not idat:
        raise SystemExit("Gemini PNG 缺少图像数据")
    channels = 4 if color_type == 6 else 3
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    expected = (stride + 1) * height
    if len(raw) < expected:
        raise SystemExit("Gemini PNG 像素数据不完整")
    rows: list[bytearray] = []
    source = 0
    for _ in range(height):
        filter_type = raw[source]
        source += 1
        row = bytearray(raw[source : source + stride])
        source += stride
        previous = rows[-1] if rows else bytearray(stride)
        if filter_type == 1:
            for index in range(len(row)):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + left) & 0xFF
        elif filter_type == 2:
            for index in range(len(row)):
                row[index] = (row[index] + previous[index]) & 0xFF
        elif filter_type == 3:
            for index in range(len(row)):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + ((left + previous[index]) // 2)) & 0xFF
        elif filter_type == 4:
            for index in range(len(row)):
                left = row[index - channels] if index >= channels else 0
                up = previous[index]
                upper_left = previous[index - channels] if index >= channels else 0
                row[index] = (row[index] + paeth(left, up, upper_left)) & 0xFF
        elif filter_type != 0:
            raise SystemExit(f"Gemini PNG 过滤器不支持：{filter_type}")
        rows.append(row)
    return width, height, b"".join(rows), channels


def paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    distances = (
        abs(estimate - left),
        abs(estimate - up),
        abs(estimate - upper_left),
    )
    return (left, up, upper_left)[distances.index(min(distances))]


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"用法：{sys.argv[0]} <输入.png> <输出.argb>")
    width, height, pixels, channels = decode_png(Path(sys.argv[1]).read_bytes())
    out = bytearray()
    out += struct.pack("<II", width, height)
    for offset in range(0, len(pixels), channels):
        red, green, blue = pixels[offset : offset + 3]
        alpha = pixels[offset + 3] if channels == 4 else 255
        out += struct.pack("<I", (alpha << 24) | (red << 16) | (green << 8) | blue)
    Path(sys.argv[2]).write_bytes(out)
    print(f"Wrote Gemini ARGB icon: {width}x{height}")


if __name__ == "__main__":
    main()
