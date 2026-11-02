#!/usr/bin/env bash

# 命令失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 定位公共下载入口，不依赖调用者当前目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 本入口只查询并下载完整安装包，不执行更新器或安装程序。
if (( $# != 11 )); then
  echo "用法：$0 <服务 URL> <应用 ID> <渠道> <平台> <系统版本> <架构> <允许的 HTTPS 源> <解码后的路径前缀> <含 {version} 的文件名正则> <安装包输出文件> <版本输出文件>" >&2
  exit 2
fi

# XML、地址与摘要解析使用标准库，不执行远端返回的内容。
command -v python3 >/dev/null 2>&1 || {
  echo "错误：Omaha 下载需要 python3。" >&2
  exit 1
}

# 查询当前版本，校验元数据并复用公共下载入口取得完整安装包。
python3 - "$SCRIPT_DIR" "$@" <<'PY'
import base64
import binascii
import os
from pathlib import Path
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import quote, unquote, urljoin, urlsplit
import xml.etree.ElementTree as ET


# 统一输出可读错误，不把失败信息混入版本标准输出。
def fail(message):
    raise SystemExit(f"错误：{message}")


# 拒绝带凭据、片段或控制字符的地址，只允许 HTTPS。
def https_url(value):
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        fail(f"无效的 HTTPS 地址：{exc}")
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.fragment
        or any(character.isspace() or ord(character) < 32 for character in value)
        or "\x7f" in value
    ):
        fail(f"无效的 HTTPS 地址：{value!r}")
    return parsed, (parsed.hostname.lower(), port or 443)


# 去除 XML 命名空间，只在协议规定的直接子元素中选择。
def children(element, name):
    return [
        child for child in element
        if child.tag.rsplit("}", 1)[-1] == name
    ]


# 必须取得唯一的协议元素，避免静默选择不确定的包。
def one_child(element, name):
    matches = children(element, name)
    if len(matches) != 1:
        fail(f"Omaha 响应应包含唯一的 {name}，实际为 {len(matches)} 个。")
    return matches[0]


# 同时接受十六进制和标准或 URL 安全的 Base64 SHA-256。
def sha256_digest(value):
    value = value.strip()
    if re.fullmatch(r"[0-9a-fA-F]{64}", value):
        return value.lower()
    try:
        padded = value + "=" * (-len(value) % 4)
        digest = base64.b64decode(padded, altchars=b"-_", validate=True)
    except (ValueError, binascii.Error):
        fail("Omaha 响应中的 SHA-256 格式无效。")
    if len(digest) != 32:
        fail("Omaha 响应中的 SHA-256 长度无效。")
    return digest.hex()


# 所有应用参数由调用方传入，公共入口不内置应用或下载域名。
def main():
    (
        script_dir, endpoint, app_id, channel, platform, os_version, arch,
        allowed_origin, path_prefix, filename_pattern, output_name, version_name,
    ) = sys.argv[1:]
    if any(not argument for argument in sys.argv[1:]):
        fail("所有参数均须为非空值。")
    https_url(endpoint)
    origin, origin_key = https_url(allowed_origin)
    if origin.path not in ("", "/") or origin.query:
        fail("允许的 HTTPS 源只能包含协议、主机和可选端口。")
    if (
        not path_prefix.startswith("/")
        or not path_prefix.endswith("/")
        or "\\" in path_prefix
        or re.search(r"[\x00-\x1f\x7f]", path_prefix)
        or (posixpath.normpath(path_prefix).rstrip("/") + "/") != path_prefix
    ):
        fail("路径前缀必须是解码后、以 / 开始并结束的规范目录路径。")
    if "{version}" not in filename_pattern:
        fail("文件名正则必须包含 {version} 占位符。")
    try:
        re.compile(filename_pattern.replace("{version}", "1[.]2[.]3"))
    except re.error as exc:
        fail(f"文件名正则无效：{exc}")
    if re.search(r"[\x00-\x1f\x7f]", app_id + channel + platform + os_version + arch):
        fail("请求参数不能包含控制字符。")

    output = Path(os.path.abspath(output_name))
    version_file = Path(os.path.abspath(version_name))
    if os.path.realpath(output) == os.path.realpath(version_file):
        fail("安装包和版本文件不能使用同一路径。")
    if output.is_dir() or version_file.is_dir():
        fail("安装包和版本输出必须是文件路径。")
    downloader = Path(script_dir) / "download_file.sh"
    if not os.access(downloader, os.X_OK):
        fail("公共 download_file.sh 不存在或不可执行。")
    if shutil.which("curl") is None:
        fail("Omaha 查询需要 curl。")

    output.parent.mkdir(parents=True, exist_ok=True)
    version_file.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".omaha-", dir=output.parent) as temporary:
        work = Path(temporary)
        request_file = work / "request.xml"
        response_file = work / "response.xml"

        # 用 XML 序列化传入参数，避免把参数直接拼进请求正文。
        request = ET.Element("request", {"protocol": "3.0"})
        ET.SubElement(request, "os", {
            "platform": platform, "version": os_version, "arch": arch,
        })
        app = ET.SubElement(request, "app", {
            "appid": app_id, "version": "", "ap": channel,
        })
        ET.SubElement(app, "updatecheck")
        ET.ElementTree(request).write(
            request_file, encoding="UTF-8", xml_declaration=True,
        )

        # Omaha 元数据使用带 XML 正文的 HTTPS POST，沿用现有重试与超时。
        subprocess.run([
            "curl", "--fail", "--location",
            "--proto", "=https", "--proto-redir", "=https", "--tlsv1.2",
            "--retry", "5", "--retry-all-errors", "--retry-delay", "2",
            "--connect-timeout", "20", "--max-time", "120",
            "-H", "Content-Type: application/xml",
            "--data-binary", f"@{request_file}",
            endpoint, "--output", str(response_file),
        ], check=True, stdout=sys.stderr)
        try:
            response = ET.parse(response_file).getroot()
        except ET.ParseError as exc:
            fail(f"Omaha 返回的 XML 无效：{exc}")
        if (
            response.tag.rsplit("}", 1)[-1] != "response"
            or response.get("protocol") != "3.0"
        ):
            fail("服务没有返回有效的 Omaha 3.0 响应。")
        apps = [
            item for item in children(response, "app")
            if item.get("appid", "").casefold() == app_id.casefold()
        ]
        if len(apps) != 1:
            fail("Omaha 响应没有唯一匹配所请求应用 ID 的条目。")
        app = apps[0]
        if app.get("status") != "ok":
            fail(f"Omaha 应用状态不是 ok：{app.get('status')!r}")
        update = one_child(app, "updatecheck")
        if update.get("status") != "ok":
            fail(f"Omaha 更新状态不是 ok：{update.get('status')!r}")
        manifest = one_child(update, "manifest")
        version = manifest.get("version", "")
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,3}", version):
            fail(f"Omaha 版本不是一至四段数字：{version!r}")

        # 只下载 install action 指定的完整包，不选择差分包或其他产品。
        actions = [
            action for action in children(one_child(manifest, "actions"), "action")
            if action.get("event") == "install"
        ]
        if len(actions) != 1:
            fail("Omaha 响应没有唯一的安装动作。")
        package_name = actions[0].get("run", "")
        if (
            not package_name or package_name in (".", "..")
            or "/" in package_name or "\\" in package_name
            or re.search(r"[\x00-\x1f\x7f]", package_name)
            or re.fullmatch(
                filename_pattern.replace("{version}", re.escape(version)),
                package_name,
            ) is None
        ):
            fail("安装包名称不符合当前版本的文件名规则。")
        packages = [
            package for package in children(one_child(manifest, "packages"), "package")
            if package.get("name") == package_name
        ]
        if len(packages) != 1:
            fail("无法唯一匹配安装动作对应的完整包元数据。")
        package = packages[0]
        size = package.get("size", "")
        if not re.fullmatch(r"[1-9][0-9]*", size):
            fail("安装包大小必须是正整数。")
        digest = sha256_digest(package.get("hash_sha256", ""))

        # 下载地址必须同时匹配调用方指定的源和解码后的目录前缀。
        candidates = []
        for entry in children(one_child(update, "urls"), "url"):
            codebase = entry.get("codebase", "")
            if not codebase.lower().startswith("https://"):
                continue
            parsed, key = https_url(codebase)
            decoded_path = unquote(parsed.path)
            if (
                key != origin_key or parsed.query
                or not parsed.path.endswith("/")
                or "\\" in decoded_path
                or re.search(r"[\x00-\x1f\x7f]", decoded_path)
                or not (posixpath.normpath(decoded_path).rstrip("/") + "/").startswith(path_prefix)
            ):
                continue
            candidates.append(urljoin(codebase, quote(package_name, safe="")))
        if len(candidates) != 1:
            fail("Omaha 响应没有唯一符合下载源和目录限制的完整包地址。")

        # 先在隔离目录校验 SHA-256 和大小，失败时不覆盖已有输出文件。
        staged_package = work / "package"
        subprocess.run(
            [str(downloader), candidates[0], str(staged_package), digest],
            check=True, stdout=sys.stderr,
        )
        if staged_package.stat().st_size != int(size):
            fail("安装包大小与 Omaha 元数据不一致。")

        # 版本临时文件与目标位于同一目录，校验完成后分别原子替换输出。
        temporary_version = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", prefix=".omaha-version-",
                dir=version_file.parent, delete=False,
            ) as stream:
                temporary_version = Path(stream.name)
                stream.write(version + "\n")
            os.replace(staged_package, output)
            os.replace(temporary_version, version_file)
        finally:
            if temporary_version is not None:
                temporary_version.unlink(missing_ok=True)
    print(version)


# 子命令失败时保留其退出状态，其他文件错误以中文说明。
try:
    main()
except subprocess.CalledProcessError as exc:
    raise SystemExit(exc.returncode) from None
except OSError as exc:
    fail(f"Omaha 下载或文件写入失败：{exc}")
PY
