# 本程序专属处理：从主题参数生成源码默认配色，只修改 config.h 的颜色与透明度。
import os
import pathlib
import re

source = pathlib.Path(os.environ["SOURCE_DIR"])
config_path = source / "config.h"
content = config_path.read_text()

colors = os.environ["ST_THEME_COLORS"].split()
names = ("ST_THEME_CURSOR", "ST_THEME_REVERSE_CURSOR", "ST_THEME_BACKGROUND", "ST_THEME_FOREGROUND")
special = [os.environ[name] for name in names]
color_pattern = re.compile(r"#[0-9a-fA-F]{6}")
if len(colors) != 16 or any(color_pattern.fullmatch(value) is None for value in colors + special):
    raise SystemExit("错误：主题颜色需要 16 个 ANSI 色值和 4 个有效特殊色值")

alpha = os.environ["ST_THEME_ALPHA"].strip()
if re.fullmatch(r"(?:0(?:\.[0-9]+)?|1(?:\.0+)?)", alpha) is None:
    raise SystemExit("错误：主题透明度必须介于 0.0 和 1.0 之间")

start = content.find("static const char *colorname[] = {")
if start < 0:
    raise SystemExit("错误：上游 colorname 数组已变更")
body_start = content.find("{", start) + 1
special_start = content.find("[255] = 0", body_start)
body_end = content.find("};", special_start)
if special_start < 0 or body_end < 0:
    raise SystemExit("错误：上游 colorname 数组索引布局已变更")

# 保留上游其余数组布局及注释，只替换 16 个 ANSI 色值和 4 个特殊色值。
literal = re.compile(r'"#[0-9a-fA-F]{6}"')


def replace_literals(block, replacements, label):
    if len(literal.findall(block)) != len(replacements):
        raise SystemExit(f"错误：上游 {label} 色值数量已变更")
    values = iter(replacements)
    return literal.sub(lambda _: '"' + next(values) + '"', block)


ansi_block = replace_literals(content[body_start:special_start], colors, "ANSI")
special_block = replace_literals(content[special_start:body_end], special, "特殊")
content = content[:body_start] + ansi_block + special_block + content[body_end:]

content, count = re.subn(
    r"(?m)^float alpha = [0-9]+(?:\.[0-9]+)?;$",
    lambda _: f"float alpha = {alpha};",
    content,
)
if count != 1:
    raise SystemExit("错误：上游 alpha 字段已变更")
config_path.write_text(content)
