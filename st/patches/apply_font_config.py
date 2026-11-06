# 本程序专属处理：按字体配置生成本次构建的 config.h，保留上游 config.def.h。
import json
import os
import pathlib
import re

source = pathlib.Path(os.environ["SOURCE_DIR"])
content = (source / "config.def.h").read_text()
primary = os.environ["ST_FONT_PRIMARY"].strip()
fallbacks = [name.strip() for name in os.environ["ST_FONT_FALLBACKS"].split(",") if name.strip()]
pixels = int(os.environ["ST_FONT_PIXELS"])
if not primary or not fallbacks or pixels <= 0:
    raise SystemExit("错误：font-config.sh 中的字体配置无效")
def pattern(name):
    return json.dumps(f"{name}:pixelsize={pixels}:antialias=true:autohint=true")
content, n = re.subn(r'^static char \*font = .*;$',
                     lambda _: f"static char *font = {pattern(primary)};",
                     content, flags=re.MULTILINE)
if n != 1:
    raise SystemExit("错误：上游 font 字段已变更")
content, n = re.subn(r'^static char \*font2\[\] = .*;$',
                     lambda _: "static char *font2[] = { " +
                     ", ".join(map(pattern, fallbacks)) + " };",
                     content, flags=re.MULTILINE)
if n != 1:
    raise SystemExit("错误：上游 font2 字段已变更")
(source / "config.h").write_text(content)
