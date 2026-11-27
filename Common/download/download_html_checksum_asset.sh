#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/download_file.sh"
JSON_HTML_FIELD=""
if [[ "${1:-}" == --json-html ]]; then
  JSON_HTML_FIELD="${2:-}"
  [[ "$JSON_HTML_FIELD" =~ ^[A-Za-z_][A-Za-z0-9_]*([.][A-Za-z_][A-Za-z0-9_]*)*$ ]] || {
    echo "错误：JSON HTML 字段必须是用点分隔的非空对象键。" >&2
    exit 1
  }
  shift 2
fi

CHECKSUM_URL="${1:-}"
ASSET_REGEX="${2:-}"
ASSET_BASE_URL="${3:-}"
OUTPUT="${4:-}"

# 页面、资产匹配规则、下载目录和输出文件全部由调用方提供。
if (( $# != 4 )) || [[ -z "$CHECKSUM_URL" || -z "$ASSET_REGEX" || -z "$ASSET_BASE_URL" || -z "$OUTPUT" ]]; then
  echo "用法：$0 [--json-html <JSON HTML 字段>] <HTTPS 校验来源 URL> '<完整资产名的 Python 正则>' <HTTPS 资产目录 URL> <输出文件>" >&2
  exit 1
fi
[[ "$CHECKSUM_URL" == https://* && "$ASSET_BASE_URL" == https://* ]] || {
  echo "错误：校验表和资产目录必须使用 HTTPS。" >&2
  exit 1
}
[[ "$ASSET_REGEX" == ^* && "$ASSET_REGEX" == *'$' ]] || {
  echo "错误：资产名正则必须同时包含 ^ 和 $ 锚点。" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载脚本不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}

CHECKSUM_FILE="$(mktemp)"

# 退出时只删除本次下载的临时校验来源文件。
cleanup() {
  rm -f -- "$CHECKSUM_FILE"
}
trap cleanup EXIT

# 实际请求复用公共下载入口，不在这里重复实现重试、超时或摘要校验。
"$DOWNLOAD_FILE" "$CHECKSUM_URL" "$CHECKSUM_FILE" >&2

# 只配对同一 HTML 表格行中的文件名和 SHA-256，拒绝缺失、冲突或不唯一的匹配。
ASSET_METADATA="$(python3 - "$CHECKSUM_FILE" "$ASSET_REGEX" "$ASSET_BASE_URL" "$JSON_HTML_FIELD" <<'PY'
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote, urlsplit


# 收集表格行及单元格文本，兼容 code、链接和 HTML 实体等嵌套内容。
class ChecksumTableParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.row = None
        self.cell = None
        self.table_depth = 0

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.table_depth += 1
        elif tag == "tr" and self.table_depth:
            self.row = []
        elif tag in {"td", "th"} and self.row is not None:
            self.cell = []
        elif tag == "br" and self.cell is not None:
            self.cell.append(" ")

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in {"td", "th"} and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None
            self.cell = None
        elif tag == "table":
            self.table_depth = max(0, self.table_depth - 1)


# 版本只从匹配的资产名读取，程序名称、平台和架构由完整正则限定。
try:
    asset_pattern = re.compile(sys.argv[2])
except re.error as error:
    raise SystemExit(f"错误：资产名正则无效：{error}")

base_url = sys.argv[3].rstrip("/")
base_parts = urlsplit(base_url)
if base_parts.scheme != "https" or not base_parts.hostname or base_parts.query or base_parts.fragment:
    raise SystemExit("错误：资产目录必须是没有查询参数和片段的完整 HTTPS URL。")

# API 来源只读取调用方明确指定的 HTML 字段；普通 HTML 来源保持原样。
html = Path(sys.argv[1]).read_text(encoding="utf-8-sig")
if sys.argv[4]:
    try:
        html = json.loads(html)
    except json.JSONDecodeError as error:
        raise SystemExit(f"错误：校验来源不是有效 JSON：{error}")
    for key in sys.argv[4].split("."):
        if not isinstance(html, dict) or key not in html:
            raise SystemExit(f"错误：JSON 校验来源缺少 HTML 字段：{sys.argv[4]}")
        html = html[key]
    if not isinstance(html, str) or not html.strip():
        raise SystemExit("错误：JSON HTML 字段必须是非空字符串。")

parser = ChecksumTableParser()
parser.feed(html)
parser.close()
candidates = {}

for row in parser.rows:
    names = {cell for cell in row if asset_pattern.fullmatch(cell)}
    if not names:
        continue
    if len(names) != 1:
        raise SystemExit("错误：同一校验表行匹配了多个资产名，请缩小匹配范围。")
    name = names.pop()
    if ".." in name or any(char in name for char in "/\\") or any(char.isspace() or ord(char) < 32 for char in name):
        raise SystemExit(f"错误：校验表包含不安全的资产名：{name}")
    hashes = {cell.lower() for cell in row if re.fullmatch(r"[0-9a-fA-F]{64}", cell)}
    if len(hashes) != 1:
        raise SystemExit(f"错误：资产所在行必须包含唯一的 SHA-256：{name}")
    digest = hashes.pop()
    if name in candidates and candidates[name][0] != digest:
        raise SystemExit(f"错误：同一资产出现相互冲突的 SHA-256：{name}")
    version_match = re.search(r"[0-9]+(?:\.[0-9]+)+", name)
    if version_match is None:
        raise SystemExit(f"错误：无法从资产名读取点分数字版本：{name}")
    version = version_match.group()
    candidates[name] = (digest, version)

if not candidates:
    raise SystemExit("错误：HTML 校验表中没有匹配的资产。")

# 按数字版本选择最新资产；同一最高版本存在多个文件时不擅自挑选。
latest_version = max(tuple(map(int, value[1].split("."))) for value in candidates.values())
latest = [(name, value) for name, value in candidates.items() if tuple(map(int, value[1].split("."))) == latest_version]
if len(latest) != 1:
    raise SystemExit("错误：最高版本匹配了多个资产，请在正则中明确平台和架构。")
name, (digest, version) = latest[0]
asset_url = base_url + "/" + quote(name, safe="")
print(f"{version}\t{asset_url}\t{digest}")
PY
)"

IFS=$'\t' read -r VERSION ASSET_URL ASSET_SHA256 <<< "$ASSET_METADATA"

# 校验成功后才替换输出文件，具体下载和 SHA-256 处理仍由公共入口完成。
printf '官方稳定版来源：%s\n' "$ASSET_URL" >&2
"$DOWNLOAD_FILE" "$ASSET_URL" "$OUTPUT" "$ASSET_SHA256" >&2

# stdout 只返回版本，便于统一安装和解包入口读取。
printf '%s\n' "$VERSION"
