#!/usr/bin/env python3
"""从登记的标准模板生成 build 脚本。"""

import argparse
import difflib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / "templates"
TOKEN = re.compile(r"__([A-Z][A-Z0-9_]*)__")
TEMPLATE_LINK = re.compile(r"\]\(\./([a-z0-9-]+/[a-z0-9-]+\.sh)\)")
OUTPUT_PATH = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*/build_[A-Za-z0-9][A-Za-z0-9._+-]*\.sh")
PACKAGE = re.compile(r"[A-Za-z0-9][A-Za-z0-9@._+:-]*")
BASENAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*")
GLOB = re.compile(r"[A-Za-z0-9_./+!*?\[\]-]+")
PACKAGE_LISTS = {"APT_PACKAGES", "APT_EXTRA_PACKAGES", "DEPENDENCY_ARGS"}
SCAN_LISTS = {"SCAN_ARGS"}
SINGLE_QUOTED = {"RELEASE_ASSET_PATTERN", "DEB_ASSET_REGEX", "AUR_DEB_FILENAME"}
RELATIVE_PATHS = {
    "APP_BIN_DIR", "APP_LIB_DIR", "DEB_PROGRAM_DIR", "GIO_MODULE_DIR",
    "MAIN_EXECUTABLE", "PACKAGE_JSON", "PREPARED_APPDIR", "QML_DIR",
    "QT_PLUGIN_DIR", "QT_TRANSLATIONS_DIR",
}
DOUBLE_QUOTED = RELATIVE_PATHS | {
    "APP_BASENAME", "APP_NAME", "APT_MAIN_PACKAGE", "CHECKSUM_URL", "DEB_ARCH",
    "DEB_FILENAME", "DEB_PACKAGE", "DEB_URL", "DESKTOP", "GITHUB_REPOSITORY",
    "ICON", "INSTALLED_PROGRAM_DIR", "MAIN_BIN", "STARTUPWMCLASS",
    "SYSTEM_PACKAGE", "VERSION_OPTION", "RELEASE_TAG_PREFIX",
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"参数文件中存在重复键：{key}")
        result[key] = value
    return result


def clean_text(value, name):
    if not isinstance(value, str) or not value or any(
        ord(char) < 32 or ord(char) == 127 for char in value
    ):
        raise ValueError(f"{name} 必须是非空的单行文本。")
    if TOKEN.search(value):
        raise ValueError(f"{name} 含有未替换的占位符。")
    return value


def scan_argument(value, name):
    if isinstance(value, dict) and set(value) == {"glob"}:
        pattern = clean_text(value["glob"], name)
        if not GLOB.fullmatch(pattern) or not pattern.startswith(("/", "AppDir/")) or ".." in pattern.split("/"):
            raise ValueError(f"{name} 含有无效的扫描通配路径：{pattern}")
        return pattern

    path = clean_text(value, name)
    if not path.startswith(("/", "AppDir/")):
        raise ValueError(f"{name} 的扫描路径必须以 / 或 AppDir/ 开头。")
    return shlex.quote(path)


def render_parameter(name, value, family):
    if name in PACKAGE_LISTS | SCAN_LISTS:
        if not isinstance(value, list) or (name in {"APT_PACKAGES", "SCAN_ARGS"} and not value):
            raise ValueError(f"{name} 必须是符合模板要求的参数数组。")
        if name in SCAN_LISTS:
            return " ".join(scan_argument(item, name) for item in value)
        packages = [clean_text(item, name) for item in value]
        if not all(PACKAGE.fullmatch(item) for item in packages):
            raise ValueError(f"{name} 含有无效的包名。")
        return " ".join(packages)

    if name == "VERSION_FIELD":
        if type(value) is not int or value < 1:
            raise ValueError("VERSION_FIELD 必须是正整数。")
        return str(value)

    value = clean_text(value, name)
    if name in {"APT_MAIN_PACKAGE", "SYSTEM_PACKAGE", "DEB_PACKAGE", "DEB_ARCH"} and not PACKAGE.fullmatch(value):
        raise ValueError(f"{name} 不是有效的包名或架构。")
    if (name in {"APP_BASENAME", "DEB_FILENAME", "MAIN_BIN"} or
            name == "APP_NAME" and family == "appimage") and not BASENAME.fullmatch(value):
        raise ValueError(f"{name} 必须是单独的名称。")
    if name in RELATIVE_PATHS and (value.startswith("/") or ".." in value.split("/")):
        raise ValueError(f"{name} 必须是目录内的相对路径。")
    if name in {"ICON", "DESKTOP", "INSTALLED_PROGRAM_DIR"} and not value.startswith("/"):
        raise ValueError(f"{name} 必须是绝对路径。")
    if name == "QMAKE":
        return shlex.quote(value)
    if name in SINGLE_QUOTED:
        return value.replace("'", "'\"'\"'")
    if name in DOUBLE_QUOTED:
        return re.sub(r'([\\$"\x60])', r'\\\1', value)
    raise ValueError(f"生成器未登记该占位参数：{name}")


def load_template(name):
    index = (TEMPLATES / "README.md").read_text(encoding="utf-8")
    if name not in TEMPLATE_LINK.findall(index):
        raise ValueError(f"模板未在 templates/README.md 登记：{name}")
    path = TEMPLATES / name
    if path.resolve() != path or not path.is_file():
        raise ValueError(f"模板必须是目录内的普通文件：{name}")
    return path.read_bytes().decode("utf-8")


def render(template, params, family):
    if not isinstance(params, dict):
        raise ValueError("参数文件必须是 JSON 对象。")
    required = set(TOKEN.findall(template))
    missing = required - params.keys()
    extra = params.keys() - required
    if missing or extra:
        details = []
        if missing:
            details.append("缺少参数：" + "、".join(sorted(missing)))
        if extra:
            details.append("多余参数：" + "、".join(sorted(extra)))
        raise ValueError("。".join(details))
    values = {name: render_parameter(name, params[name], family) for name in required}
    return TOKEN.sub(lambda match: values[match[1]], template)


def check_bash(content):
    env = {key: value for key, value in os.environ.items() if key not in {"BASH_ENV", "ENV"}}
    result = subprocess.run(
        ["bash", "--noprofile", "--norc", "-n"],
        input=content, text=True, capture_output=True, env=env, check=False,
    )
    if result.returncode:
        raise ValueError("Bash 语法检查失败。\n" + result.stderr.strip())


def output_file(name):
    if not OUTPUT_PATH.fullmatch(name):
        raise ValueError("输出必须是仓库内的 <应用目录>/build_<名称>.sh。")
    path = ROOT / name
    if not path.parent.is_dir() or path.resolve() != path:
        raise ValueError("应用目录必须已存在，输出路径不得经过软链接。")
    if path.exists() and not path.is_file():
        raise ValueError("输出路径必须指向普通文件。")
    return path


def write_build(path, previous, content):
    current = path.read_bytes() if path.exists() else None
    if current != previous or path.is_symlink():
        raise ValueError("输出文件在生成期间发生变化，请重新预览。")
    mode = stat.S_IMODE(path.stat().st_mode) if previous is not None else 0o755
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temp:
        temp_path = Path(temp.name)
        try:
            temp.write(content.encode("utf-8"))
            temp.close()
            temp_path.chmod(mode)
            temp_path.replace(path)
        finally:
            temp_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, help="模板索引中的相对路径")
    parser.add_argument("--params", required=True, help="参数 JSON 文件，或 - 从标准输入读取")
    parser.add_argument("--output", required=True, help="仓库内的应用构建脚本相对路径")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--stdout", action="store_true", help="只输出生成的完整脚本")
    mode.add_argument("--write", action="store_true", help="显式写入或覆盖输出脚本")
    args = parser.parse_args()

    try:
        path = output_file(args.output)
        template = load_template(args.template)
        raw_params = sys.stdin.read() if args.params == "-" else Path(args.params).read_text(encoding="utf-8")
        params = json.loads(raw_params, object_pairs_hook=unique_object)
        content = render(template, params, args.template.split("/", 1)[0])
        check_bash(content)
        for body in re.findall(r"<<'APPRUN'\n(.*?)\nAPPRUN(?:\n|$)", content, re.DOTALL):
            check_bash(body)

        if args.stdout:
            sys.stdout.write(content)
            return 0
        previous = path.read_bytes() if path.exists() else None
        if args.write:
            if previous != content.encode("utf-8"):
                write_build(path, previous, content)
            print(f"生成结果：{args.output}")
        else:
            old_lines = previous.decode("utf-8").splitlines(keepends=True) if previous is not None else []
            diff = difflib.unified_diff(
                old_lines, content.splitlines(keepends=True),
                fromfile=args.output if previous is not None else "/dev/null",
                tofile=args.output,
            )
            sys.stdout.writelines(diff)
    except (OSError, ValueError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
