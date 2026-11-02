#!/usr/bin/env bash

# 命令失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 由调用方提供仓库、软件包和输出路径，不在公共入口固定应用。
if (( $# != 8 )); then
  echo "用法：$0 <HTTPS 仓库根地址> <suite> <component> <包名> <架构> <HTTPS 官方密钥地址> <输出 DEB> <来源版本文件>" >&2
  exit 2
fi
# 定位现有公共下载入口，不依赖调用者当前目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 构建环境提前提供校验工具，公共下载入口不安装依赖。
for command_name in python3 gpg gpgv dpkg dpkg-deb; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "错误：APT 仓库下载需要 $command_name。" >&2
    exit 1
  }
done

# 解析签名索引，校验并下载当前最高版本；不安装或执行应用。
python3 - "$SCRIPT_DIR" "$@" <<'PY'
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
import functools
import gzip
import lzma
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


def fail(message):
    raise SystemExit(f"错误：{message}")


def https_url(value):
    parsed = urlsplit(value)
    parsed.port
    if (
        parsed.scheme != "https" or not parsed.hostname
        or parsed.username is not None or parsed.password is not None
        or parsed.query or parsed.fragment
        or "\\" in value
        or re.search(r"[\x00-\x20\x7f]", value)
    ):
        fail("仓库和密钥必须使用不带凭据、查询参数或片段的 HTTPS 地址。")
    return value


# 读取 Debian 控制字段及续行，拒绝重复键，避免混用冲突的签名数据。
def fields(paragraph):
    result = {}
    key = None
    for line in paragraph.strip().splitlines():
        if line.startswith((" ", "\t")) and key is not None:
            result[key] += "\n" + line.strip()
        else:
            key, separator, value = line.partition(":")
            if not separator or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*", key) or key in result:
                fail("APT 元数据包含无效或重复字段。")
            result[key] = value.strip()
    return result


# 使用 Debian 自身的版本排序，保留 epoch、预发布标记和包修订号的语义。
def compare_versions(left, right):
    for relation, result in (("lt", -1), ("gt", 1)):
        status = subprocess.run(
            ["dpkg", "--compare-versions", left, relation, right], check=False,
        ).returncode
        if status == 0:
            return result
        if status != 1:
            fail("APT 索引包含无效的 Debian 版本。")
    return 0


def main():
    script_dir, repository, suite, component, package, architecture, key_url, output, version_file = sys.argv[1:]
    repository = https_url(repository).rstrip("/")
    key_url = https_url(key_url)
    for token in (suite, component, package, architecture):
        if not re.fullmatch(r"[a-z0-9][a-z0-9+.-]*", token) or token in (".", ".."):
            fail("suite、component、包名或架构无效。")
    if not output or not version_file:
        fail("DEB 和来源版本文件的输出路径不能为空。")
    output = Path(output).absolute()
    version_file = Path(version_file).absolute()
    if output.resolve() == version_file.resolve():
        fail("DEB 和来源版本文件必须使用不同路径。")
    if output.is_dir() or version_file.is_dir():
        fail("DEB 和来源版本文件的输出路径不能是目录。")
    output.parent.mkdir(parents=True, exist_ok=True)
    version_file.parent.mkdir(parents=True, exist_ok=True)
    downloader = Path(script_dir) / "download_file.sh"
    if not os.access(downloader, os.X_OK):
        fail("公共 download_file.sh 不存在或不可执行。")

    def download(url, destination, digest=None):
        args = [str(downloader), url, str(destination)]
        if digest is not None:
            args.append(digest)
        subprocess.run(args, check=True, stdout=sys.stderr)

    with tempfile.TemporaryDirectory(prefix=".apt-deb-", dir=output.parent) as directory:
        work = Path(directory)
        gnupg = work / "gnupg"
        gnupg.mkdir(mode=0o700)
        release_url = f"{repository}/dists/{suite}"
        # 密钥由调用方明确指定；隔离密钥目录，不读写宿主机的 GnuPG 配置。
        download(key_url, work / "key")
        download(f"{release_url}/InRelease", work / "InRelease")
        # 把二进制或 armored 公钥转成当前验证专用的 keyring。
        subprocess.run(
            ["gpg", "--batch", "--yes", "--homedir", str(gnupg), "--dearmor",
             "--output", str(work / "keyring.gpg"), str(work / "key")],
            check=True, stdout=sys.stderr,
        )
        # 只使用明确下载的密钥验证本次 InRelease，不读取系统信任库。
        subprocess.run(
            ["gpgv", "--homedir", str(gnupg), "--keyring", str(work / "keyring.gpg"),
             "--output", str(work / "Release"), str(work / "InRelease")],
            check=True, stdout=sys.stderr,
        )
        # 签名通过后才解析索引；仓库声明有效期时，过期索引不能继续使用。
        release = fields((work / "Release").read_text(encoding="utf-8"))
        if "Valid-Until" in release:
            deadline = parsedate_to_datetime(release["Valid-Until"])
            if deadline is None or deadline.tzinfo is None:
                fail("签名索引的 Valid-Until 无效。")
            if deadline <= datetime.now(timezone.utc):
                fail("签名索引已超过 Valid-Until。")
        if suite not in (release.get("Suite"), release.get("Codename")):
            fail("签名索引与请求的 suite 不一致。")
        for plural, singular, expected in (
            ("Architectures", "Architecture", architecture),
            ("Components", "Component", component),
        ):
            if expected not in release.get(plural, release.get(singular, "")).split():
                fail("签名索引不包含请求的 component 或架构。")
        # 只选择请求的 component 和架构；没有明文索引时支持 XZ、gzip 索引。
        index_name = f"{component}/binary-{architecture}/Packages"
        matches = []
        for index_path in (index_name, index_name + ".xz", index_name + ".gz"):
            for line in release.get("SHA256", "").splitlines():
                parts = line.split()
                if len(parts) == 3 and parts[2] == index_path:
                    digest, size, name = parts
                    if not re.fullmatch(r"[0-9a-fA-F]{64}", digest) or not re.fullmatch(r"[1-9][0-9]*", size):
                        fail("Packages 的 SHA-256 或大小无效。")
                    matches.append((digest.lower(), int(size), name))
            if matches:
                break
        if len(matches) != 1:
            fail("签名索引没有唯一的 Packages SHA-256 记录。")
        digest, size, name = matches[0]
        if release.get("Acquire-By-Hash", "").lower() == "yes":
            index_url = f"{release_url}/{name.rsplit('/', 1)[0]}/by-hash/SHA256/{digest}"
        else:
            index_url = f"{release_url}/{name}"
        download(index_url, work / "Packages", digest)
        if (work / "Packages").stat().st_size != size:
            fail("Packages 大小与签名索引不一致。")
        index = (work / "Packages").read_bytes()
        if name.endswith(".xz"):
            index = lzma.decompress(index)
        elif name.endswith(".gz"):
            index = gzip.decompress(index)

        # 仅匹配指定包名与架构，不回退到其他架构或较旧的软件包。
        candidates = {}
        for paragraph in re.split(r"\n\s*\n", index.decode("utf-8").strip()):
            if not paragraph:
                continue
            item = fields(paragraph)
            if item.get("Package") != package or item.get("Architecture") != architecture:
                continue
            version = item.get("Version", "")
            if (
                not re.fullmatch(r"[0-9][0-9A-Za-z.+:~-]*", version)
                or subprocess.run(["dpkg", "--validate-version", version], check=False).returncode != 0
            ):
                fail("软件包版本无效。")
            identity = (item.get("Filename"), item.get("SHA256"), item.get("Size"))
            if version in candidates and candidates[version][0] != identity:
                fail("同版本的软件包元数据存在冲突。")
            candidates[version] = (identity, item)
        if not candidates:
            fail("APT 仓库没有请求的软件包和架构。")
        version = max(candidates, key=functools.cmp_to_key(compare_versions))
        if any(other != version and compare_versions(other, version) == 0 for other in candidates):
            fail("APT 索引中的最高版本不唯一。")
        _, item = candidates[version]
        filename = item.get("Filename", "")
        digest = item.get("SHA256", "")
        size = item.get("Size", "")
        if (
            not filename.startswith("pool/") or not filename.endswith(".deb")
            or not re.fullmatch(r"[A-Za-z0-9/_.+~-]+", filename)
            or any(part in ("", ".", "..") for part in filename.split("/"))
            or not re.fullmatch(r"[0-9a-fA-F]{64}", digest)
            or not re.fullmatch(r"[1-9][0-9]*", size)
        ):
            fail("软件包路径、SHA-256 或大小无效。")
        # 通过原公共入口核对 SHA-256，再检查大小及 DEB 自身的三个身份字段。
        staged = work / "package.deb"
        download(f"{repository}/{filename}", staged, digest)
        if staged.stat().st_size != int(size):
            fail("DEB 大小与官方索引不一致。")
        for field, expected in (("Package", package), ("Architecture", architecture), ("Version", version)):
            actual = subprocess.check_output(["dpkg-deb", "-f", str(staged), field], text=True).strip()
            if actual != expected:
                fail(f"DEB 的 {field} 与官方索引不一致。")
        # 下载、摘要和身份检查全部成功后才替换输出，失败时保留已有文件。
        temporary_version = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", prefix=".apt-version-", dir=version_file.parent, delete=False,
            ) as stream:
                temporary_version = Path(stream.name)
                stream.write(version + "\n")
            os.replace(staged, output)
            os.replace(temporary_version, version_file)
        finally:
            if temporary_version is not None:
                temporary_version.unlink(missing_ok=True)
    print(version)


try:
    main()
except subprocess.CalledProcessError as exc:
    raise SystemExit(exc.returncode) from None
except (OSError, ValueError, lzma.LZMAError) as exc:
    fail(f"APT 下载或元数据处理失败：{exc}")
PY
