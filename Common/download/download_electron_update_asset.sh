#!/usr/bin/env bash
set -Eeuo pipefail

# 要求调用方明确提供清单、资产目录、完整文件名模板和输出路径。
if (( $# != 4 )); then
  printf '%s\n' '用法：download_electron_update_asset.sh <HTTPS 清单 URL> <HTTPS 资产目录 URL 模板> <含 {version} 的完整资产文件名模板> <输出文件>' >&2
  exit 2
fi

# 定位公共下载脚本，供清单和资产下载复用。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 从同一份 Electron 更新清单取得实际版本和唯一匹配资产的摘要。
python3 - "$SCRIPT_DIR/download_file.sh" "$@" <<'PY'
import base64
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

try:
    import yaml
except ImportError:
    sys.exit("错误：读取 Electron 更新清单需要 PyYAML（Arch Linux 软件包 python-yaml）。")


class UniqueKeyLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        # 清单使用字符串键，拒绝重复键，避免把后一个值误当成唯一来源。
        mapping = {}
        for key, value in self.construct_pairs(node, deep=deep):
            if not isinstance(key, str):
                raise ValueError("Electron 更新清单的键必须是字符串。")
            if key in mapping:
                raise ValueError(f"Electron 更新清单含有重复键：{key!r}。")
            mapping[key] = value
        return mapping


def parse_https_url(value, label):
    message = f"{label}必须是有效的 HTTPS URL，且不得含认证信息或片段。"
    if not value.startswith("https://") or re.search(r"[\s\x00-\x1f\x7f\\#]", value):
        raise ValueError(message)
    try:
        url = urlsplit(value)
        port = url.port
    except ValueError:
        raise ValueError(message) from None
    if not url.hostname or url.username is not None or port == 0 or re.search(r"[{}]", url.netloc):
        raise ValueError(message)
    return url


downloader, manifest_url, asset_directory, asset_pattern, output = sys.argv[1:]
version_field = "{version}"

try:
    manifest = parse_https_url(manifest_url, "清单地址")
    if re.search(r"[{}\[\]]", manifest.path + manifest.query):
        raise ValueError("清单地址不得含 URL 通配符。")

    directory = parse_https_url(asset_directory, "资产目录地址")
    version_segments = directory.path.split("/").count(version_field)
    if (
        "?" in asset_directory
        or directory.path.count(version_field) != version_segments
        or version_segments > 1
        or re.search(r"[{}\[\]]", directory.path.replace(version_field, ""))
    ):
        raise ValueError("资产目录地址不得含查询参数或通配符，{version} 只能作为一个完整路径段出现一次。")
    if asset_pattern.count(version_field) != 1 or not re.fullmatch(
        r"[A-Za-z0-9._+-]+", asset_pattern.replace(version_field, "0")
    ):
        raise ValueError("资产文件名模板必须含一个 {version}，其余字符限 ASCII 字母、数字、点、下划线、加号和连字符。")
    if not output or output.endswith("/") or Path(output).is_dir():
        raise ValueError("必须指定输出文件，不能使用目录。")
except (ValueError, OSError) as error:
    print(f"错误：{error}", file=sys.stderr)
    sys.exit(2)

try:
    with tempfile.TemporaryDirectory(prefix="electron-update-") as work_dir:
        manifest_file = Path(work_dir) / "latest.yml"

        # 通过公共脚本下载清单，下载日志写入 stderr。
        subprocess.run([downloader, manifest_url, str(manifest_file)], check=True, stdout=sys.stderr)

        document = yaml.load(manifest_file.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
        if not isinstance(document, dict):
            raise ValueError("Electron 更新清单的顶层必须是映射。")
        version = document.get("version")
        if not isinstance(version, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
            raise ValueError("Electron 更新清单的 version 必须是点分数字版本字符串。")
        files = document.get("files")
        if not isinstance(files, list):
            raise ValueError("Electron 更新清单缺少 files 列表。")

        asset_name = asset_pattern.replace(version_field, version)
        matches = [item for item in files if isinstance(item, dict) and item.get("url") == asset_name]
        if len(matches) != 1:
            raise ValueError(f"Electron 更新清单必须有且只有一条资产记录：{asset_name}。")
        sha512 = matches[0].get("sha512")
        if not isinstance(sha512, str):
            raise ValueError(f"资产缺少 Base64 SHA-512：{asset_name}。")
        try:
            digest = base64.b64decode(sha512, validate=True)
        except ValueError as error:
            raise ValueError(f"资产的 Base64 SHA-512 无效：{asset_name}。") from error
        if len(digest) != 64 or base64.b64encode(digest).decode("ascii") != sha512:
            raise ValueError(f"资产的 Base64 SHA-512 无效：{asset_name}。")

        # 公共下载脚本校验同一条清单记录的摘要后才替换输出文件。
        asset_url = f"{asset_directory.replace(version_field, version).rstrip('/')}/{asset_name}"
        subprocess.run([downloader, asset_url, output, f"sha512:{digest.hex()}"], check=True, stdout=sys.stderr)
except subprocess.CalledProcessError as error:
    sys.exit(error.returncode)
except (ValueError, OSError, yaml.YAMLError) as error:
    sys.exit(f"错误：{error}")

# 成功后只输出一个版本号，供构建脚本记录。
print(version)
PY
