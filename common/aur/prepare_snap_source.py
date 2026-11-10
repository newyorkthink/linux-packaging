#!/usr/bin/env python3
"""将已校验的官方稳定版 Snap 接入本次临时 AUR 配方，不联网或安装应用。"""

import hashlib
import json
import os
import re
import shlex
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit


# 只解析当前 .SRCINFO 的字段，不执行上游 PKGBUILD。
def read_fields(path):
    fields = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator:
            raise SystemExit("错误：AUR 来源元数据格式无效。")
        fields.setdefault(key.strip(), []).append(value.strip())
    return fields


# 仅定位普通 Shell 数组中的单个词，拒绝无法与元数据一一对应的写法。
def array_tokens(script, name):
    starts = list(re.finditer(r"(?m)^[ \t]*" + re.escape(name) + r"[ \t]*=[ \t]*\(", script))
    if len(starts) != 1:
        raise SystemExit("错误：AUR 配方须为选中的来源和摘要使用唯一的数组赋值。")
    start = starts[0].end()
    position, depth, quote, escaped = start, 1, "", False
    while position < len(script):
        char = script[position]
        if escaped:
            escaped = False
        elif quote:
            if char == quote:
                quote = ""
            elif char == "\\" and quote == '"':
                escaped = True
        elif char in "'\"":
            quote = char
        elif char == "\\":
            escaped = True
        elif char == "#":
            newline = script.find("\n", position)
            position = len(script) if newline < 0 else newline
            continue
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                break
        position += 1
    if depth:
        raise SystemExit("错误：AUR 来源或摘要数组未正常结束。")
    body = script[start:position]
    pattern = re.compile(r"""#[^\n]*|'[^']*'|"(?:\\.|[^"\\])*"|[^\s'"]+""")
    tokens = []
    for match in pattern.finditer(body):
        raw = match.group()
        if raw.startswith("#"):
            continue
        try:
            words = shlex.split(raw)
        except ValueError as error:
            raise SystemExit("错误：AUR 数组包含无法解析的引号。") from error
        if len(words) != 1:
            raise SystemExit("错误：AUR 来源或摘要必须使用独立的普通数组元素。")
        tokens.append((words[0], start + match.start(), start + match.end()))
    return tokens


# 替换已经核对的数组元素，其他元素及其顺序保持原样。
def replace_item(script, name, index, count, expected, replacement):
    tokens = array_tokens(script, name)
    if len(tokens) != count or tokens[index][0] != expected:
        raise SystemExit("错误：PKGBUILD 数组与同次 .SRCINFO 不一致，停止更新。")
    _, start, end = tokens[index]
    return script[:start] + shlex.quote(replacement) + script[end:]


# 同步本次配方与来源缓存，所有检查通过后才允许后续包管理器安装。
def main():
    if len(sys.argv) != 9:
        raise SystemExit("用法：prepare_snap_source.py <AUR 包名> <架构> <文件名模板> "
                         "<临时配方目录> <已校验 Snap> <来源缓存> <官方元数据 JSON> <实际版本>")
    package, architecture, pattern, recipe_dir, snap_path, cache_path, metadata_path, version = sys.argv[1:]
    recipe = Path(recipe_dir)
    pkgbuild = recipe / "PKGBUILD"
    srcinfo = recipe / ".SRCINFO"
    if any(path.is_symlink() or not path.is_file() for path in (pkgbuild, srcinfo, Path(snap_path))):
        raise SystemExit("错误：临时配方、来源元数据或 Snap 不是普通文件。")
    fields = read_fields(srcinfo)
    if fields.get("pkgbase") != [package] or fields.get("pkgname") != [package]:
        raise SystemExit("错误：仅支持包基名与包名一致的单包配方。")
    if architecture not in fields.get("arch", []) and "any" not in fields.get("arch", []):
        raise SystemExit("错误：AUR 配方不支持指定架构。")
    if len(fields.get("pkgver", [])) != 1:
        raise SystemExit("错误：AUR 配方的原版本不唯一。")
    old_version = fields["pkgver"][0]
    metadata = json.loads(Path(metadata_path).read_text(encoding="utf-8"))
    if (metadata.get("version") != version or
            not re.fullmatch(r"[0-9]+(?:[.][0-9]+)+(?:[+._-][a-zA-Z0-9]+)*", version) or
            metadata.get("architecture") != {"x86_64": "amd64", "aarch64": "arm64"}.get(architecture)):
        raise SystemExit("错误：官方 Snap 版本或架构与本次下载结果不一致。")
    expected_sha3 = metadata.get("sha3_384", "")
    if not isinstance(expected_sha3, str) or not re.fullmatch(r"[0-9a-fA-F]{96}", expected_sha3):
        raise SystemExit("错误：官方 Snap 元数据缺少有效的 SHA3-384。")
    filename = pattern.replace("{version}", version)
    old_filename = pattern.replace("{version}", old_version)
    if "{version}" not in pattern or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*[.]snap", filename):
        raise SystemExit("错误：Snap 文件名模板无效。")

    # 唯一定位原始 Snap，要求新旧下载 URL 属于同一个官方 Snap ID。
    matches = []
    for suffix in ("", "_" + architecture):
        sources = fields.get("source" + suffix, [])
        for index, source in enumerate(sources):
            alias, separator, url = source.partition("::")
            if not separator:
                url, alias = source, urlsplit(source).path.rsplit("/", 1)[-1]
            if alias == old_filename:
                matches.append((suffix, index, source, url, len(sources)))
    if len(matches) != 1:
        raise SystemExit("错误：无法唯一确定 AUR 配方中的原始 Snap。")
    suffix, index, old_source, old_url, count = matches[0]
    url_pattern = r"https://api[.]snapcraft[.]io/api/v1/snaps/download/([a-zA-Z0-9]+)_[0-9]+[.]snap"
    old_id = re.fullmatch(url_pattern, old_url)
    url = metadata.get("url", "")
    new_id = re.fullmatch(url_pattern, url) if isinstance(url, str) else None
    if old_id is None or new_id is None or old_id[1] != new_id[1]:
        raise SystemExit("错误：AUR 来源与官方稳定通道的 Snap ID 不一致。")

    # 仅更新同组同索引的有效 SHA-256 / SHA-512，不跳过任何其他摘要。
    algorithms = {}
    for name in ("sha256", "sha512"):
        key = name + "sums" + suffix
        if key not in fields:
            continue
        checksums = fields[key]
        length = hashlib.new(name).digest_size * 2
        if len(checksums) != count or not re.fullmatch(r"[0-9a-fA-F]{" + str(length) + "}", checksums[index]):
            raise SystemExit("错误：原 Snap 摘要无效，不能更新或跳过。")
        algorithms[name] = (key, checksums[index])
    supported = {value[0] for value in algorithms.values()}
    if not algorithms or any(key.endswith("sums" + suffix) and key not in supported for key in fields):
        raise SystemExit("错误：此模式仅支持选中来源使用有效 SHA-256 或 SHA-512 的配方。")

    script = pkgbuild.read_text(encoding="utf-8")
    tokens = array_tokens(script, "source" + suffix)
    if len(tokens) != count:
        raise SystemExit("错误：PKGBUILD 来源数量与元数据不一致。")
    source_token = tokens[index][0]
    expanded = source_token
    for key, value in (("pkgname", package), ("pkgver", old_version)):
        expanded = expanded.replace("$" + "{" + key + "}", value).replace("$" + key, value)
    if expanded != old_source:
        raise SystemExit("错误：选中来源不是可安全同步的普通文件或版本变量。")
    script = replace_item(script, "source" + suffix, index, count, source_token, filename + "::" + url)
    version_pattern = (r"(?m)^([ \t]*pkgver[ \t]*=[ \t]*)(?:'" + re.escape(old_version) + r"'|\"" +
                       re.escape(old_version) + r"\"|" + re.escape(old_version) + r")([ \t]*(?:#.*)?)$")
    if len(list(re.finditer(version_pattern, script))) != 1:
        raise SystemExit("错误：AUR 版本须使用唯一的普通 pkgver 赋值。")

    # 原始文件复制和官方摘要复核使用同一份字节，保证缓存与新配方一致。
    cache = Path(cache_path)
    cache.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=filename + ".part.", dir=cache)
    digests = {name: hashlib.new(name) for name in algorithms}
    digests["sha3_384"] = hashlib.sha3_384()
    try:
        with os.fdopen(fd, "wb") as target, Path(snap_path).open("rb") as source:
            while chunk := source.read(1024 * 1024):
                target.write(chunk)
                for digest in digests.values():
                    digest.update(chunk)
        if digests["sha3_384"].hexdigest() != expected_sha3.lower():
            raise SystemExit("错误：复用的 Snap 未通过本次官方 SHA3-384，停止安装。")
        for name, (key, expected) in algorithms.items():
            script = replace_item(script, key, index, count, expected, digests[name].hexdigest())
        script = re.sub(version_pattern, lambda match: match[1] + shlex.quote(version) + match[2], script)
        os.chmod(temporary, 0o644)
        os.replace(temporary, cache / filename)
    finally:
        Path(temporary).unlink(missing_ok=True)

    # 保留配方文件的原所有者，让 yay 以构建用户重新生成真实 .SRCINFO。
    pkgbuild.write_text(script, encoding="utf-8")
    srcinfo.unlink()
    print("已同步本次 AUR Snap 来源：" + old_version + " -> " + version, file=sys.stderr)


if __name__ == "__main__":
    main()
