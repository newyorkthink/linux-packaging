#!/usr/bin/env bash
set -Eeuo pipefail

if (( $# != 8 )); then
  echo "用法：$0 <已核验的 C 源文件> <架构预处理符号> <版本宏> <资产架构宏> <SHA-256 宏> <预期资产架构> '<含 {version} 的 HTTPS URL 模板>' '<输出文件模板>'" >&2
  exit 2
fi
SOURCE="$1"
ARCH_SYMBOL="$2"
VERSION_MACRO="$3"
ASSET_ARCH_MACRO="$4"
SHA256_MACRO="$5"
EXPECTED_ARCH="$6"
URL_TEMPLATE="$7"
OUTPUT_TEMPLATE="$8"
if [[ ! -f "$SOURCE" || "$URL_TEMPLATE" != https://*'{version}'* || -z "$OUTPUT_TEMPLATE" || "$OUTPUT_TEMPLATE" == */ ]]; then
  echo "错误：需要 C 源文件、含 {version} 的 HTTPS URL 和有效输出路径。" >&2
  exit 2
fi
for command_name in python3 cpp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：C 宏下载入口需要 $command_name。" >&2
    exit 1
  }
done

# 仅把预处理条件和待选定义的编号交给 cpp，不加载源文件的头文件或执行代码。
mapfile -t METADATA < <(
  python3 - "$SOURCE" "$ARCH_SYMBOL" "$VERSION_MACRO" "$ASSET_ARCH_MACRO" "$SHA256_MACRO" "$EXPECTED_ARCH" <<'PY'
from pathlib import Path
import re
import subprocess
import sys


def fail(message):
    raise SystemExit(f"错误：{message}")


source, symbol, version_name, arch_name, digest_name, expected_arch = sys.argv[1:]
names = {version_name, arch_name, digest_name}
if (
    len(names | {symbol}) != 4
    or any(not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) for name in names | {symbol})
    or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_+-]*", expected_arch)
):
    fail("宏名称或预期资产架构无效。")

text = Path(source).read_text(encoding="utf-8").replace("\\\n", "")
# 移除注释时保留字符串中的 URL 以及原有换行。
comments = re.compile(r"""("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')|//[^\n]*|/\*[\s\S]*?\*/""")
text = comments.sub(lambda match: match[1] or " " + "\n" * match[0].count("\n"), text)
directives = re.compile(
    r"^[ \t]*#[ \t]*(if|ifdef|ifndef|elif|elifdef|elifndef|else|endif|define|undef)\b([^\n]*)",
    re.MULTILINE,
)
identifier = r"[A-Za-z_][A-Za-z0-9_]*"
defined = re.compile(rf"\bdefined(?:\s*\(\s*{identifier}\s*\)|\s+{identifier}\b)")
conditions = []
definitions = []
for directive, argument in directives.findall(text):
    if directive in ("if", "elif"):
        if not re.fullmatch(r"[ \t01!&|()]+", defined.sub("0", argument)):
            fail("宏条件只支持 defined、0、1 和布尔运算。")
    elif directive in ("ifdef", "ifndef", "elifdef", "elifndef"):
        if not re.fullmatch(identifier, argument.strip()):
            fail("宏条件的符号无效。")
    elif directive in ("else", "endif"):
        if argument.strip():
            fail("宏条件的结束指令含多余内容。")
    if directive not in ("define", "undef"):
        conditions.append(f"#{directive}{argument}")
        continue
    field = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)(.*)", argument)
    if not field:
        continue
    name, literal = field.groups()
    if name == symbol:
        fail("来源文件不能重新定义或取消调用方指定的架构符号。")
    if name in names:
        conditions.append(str(len(definitions)))
        definitions.append((name, literal.strip() if directive == "define" else ""))

result = subprocess.run(
    ["cpp", "-E", "-P", "-undef", "-nostdinc", f"-D{symbol}=1", "-x", "c", "-"],
    input="\n".join(conditions) + "\n", encoding="utf-8", stdout=subprocess.PIPE, check=False,
)
if result.returncode != 0:
    fail("无法解析 C 源文件的架构条件。")

selected = {}
for index in result.stdout.split():
    if not index.isascii() or not index.isdecimal() or int(index) >= len(definitions):
        fail("预处理结果包含无效的宏记录。")
    name, literal = definitions[int(index)]
    value = re.fullmatch(r'"([^"\\]*)"', literal)
    if name in selected or not value:
        fail(f"所选架构下的宏 {name} 不唯一或不是字符串字面量。")
    selected[name] = value[1]

if selected.keys() != names or selected[arch_name] != expected_arch:
    fail("所选架构缺少完整的资产宏，或资产架构与预期不符。")
version, digest = selected[version_name], selected[digest_name]
if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
    fail("所选架构的版本或 SHA-256 无效。")
print(version)
print(digest.lower())
PY
)
if (( ${#METADATA[@]} != 2 )); then
  echo "错误：无法取得所选架构的版本和 SHA-256。" >&2
  exit 1
fi

# 将同一组宏给出的版本和摘要交给公共下载入口。
VERSION="${METADATA[0]}"
URL="${URL_TEMPLATE//\{version\}/$VERSION}"
OUTPUT="${OUTPUT_TEMPLATE//\{version\}/$VERSION}"
HTTPS_URL='^https://[^/?#@[:space:][:cntrl:]]+([/?#][^[:space:][:cntrl:]]*)? -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/download_file.sh" "$URL" "$OUTPUT" "${METADATA[1]}" >&2
printf '%s\n' "$VERSION"

if [[ ! "$URL" =~ $HTTPS_URL || -d "$OUTPUT" ]]; then
  echo "错误：展开后的 HTTPS URL 或输出文件路径无效。" >&2
  exit 2
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/download_file.sh" "$URL" "$OUTPUT" "${METADATA[1]}" >&2
printf '%s\n' "$VERSION"
