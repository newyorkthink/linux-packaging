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
PROTOCOL_SCHEME = re.compile(r"[a-z][a-z0-9.+-]*")
PROTOCOL_MIME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]*/[A-Za-z0-9][A-Za-z0-9._+-]*")
DESKTOP_CATEGORIES = re.compile(r"(?:[A-Za-z0-9-]+;)+")
SYSTEM_SCHEMES = {"file", "http", "https", "mailto"}
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


def protocol_text(value, field):
    label = f"PROTOCOL_HANDLER.{field}"
    text = clean_text(value, label)
    # 公共 hook 会直接嵌入这些字段，并替换自身的内部标记。
    if any(fragment in text for fragment in ("'", "\\", "{{", "}}", "SED_EXPR")):
        raise ValueError(f"{label} 含有公共协议 hook 无法原样写入的字符或标记。")
    return text


def protocol_list(value, field, pattern):
    if not isinstance(value, list):
        raise ValueError(f"PROTOCOL_HANDLER.{field} 必须是数组。")
    items = [protocol_text(item, field) for item in value]
    if len(set(items)) != len(items) or any(not pattern.fullmatch(item) for item in items):
        raise ValueError(f"PROTOCOL_HANDLER.{field} 含有无效或重复的值。")
    return items


def render_protocol_handler(value, template_values):
    fields = ("desktop_file", "name", "comment", "icon", "wm_class", "categories")
    required = set(fields) | {"schemes"}
    allowed = required | {"mime_extra"}
    if not isinstance(value, dict) or not required <= value.keys() <= allowed:
        raise ValueError(
            "PROTOCOL_HANDLER 必须包含 desktop_file、name、comment、icon、wm_class、categories 和 schemes。"
            "仅可额外提供 mime_extra。"
        )

    desktop = {field: protocol_text(value[field], field) for field in fields}
    if not BASENAME.fullmatch(desktop["desktop_file"]) or not desktop["desktop_file"].endswith(".desktop"):
        raise ValueError("PROTOCOL_HANDLER.desktop_file 必须是单个 .desktop 文件名。")
    if not BASENAME.fullmatch(desktop["icon"]):
        raise ValueError("PROTOCOL_HANDLER.icon 必须是单独的图标名。")
    if not DESKTOP_CATEGORIES.fullmatch(desktop["categories"]):
        raise ValueError("PROTOCOL_HANDLER.categories 必须用分号分隔分类，并以分号结尾。")

    schemes = protocol_list(value["schemes"], "schemes", PROTOCOL_SCHEME)
    if not schemes or SYSTEM_SCHEMES.intersection(schemes):
        raise ValueError("PROTOCOL_HANDLER.schemes 必须包含至少一个应用自定义协议。")
    mime_extra = protocol_list(value.get("mime_extra", []), "mime_extra", PROTOCOL_MIME)
    if any(f"x-scheme-handler/{scheme}" in mime_extra for scheme in schemes):
        raise ValueError("PROTOCOL_HANDLER.mime_extra 不能重复声明 schemes 中的协议。")

    basename = template_values.get("APP_BASENAME")
    if basename is None:
        raise ValueError("PROTOCOL_HANDLER 要求模板声明 APP_BASENAME。")

    args = [("output", f"AppDir/bin/20-{basename}-protocol.hook")]
    args.extend((field.replace("_", "-"), desktop[field]) for field in fields)
    args.extend(("scheme", scheme) for scheme in schemes)
    args.extend(("mime-extra", mime) for mime in mime_extra)
    command = ['bash "$SCRIPT_DIR/../common/desktop/write_scheme_hook.sh"']
    command.extend(f"  --{flag} {shlex.quote(argument)}" for flag, argument in args)

    protocols = "、".join(f"{scheme}://" for scheme in schemes)
    comment = f"# 本仓库兼容处理：启动时注册 {protocols}。包内 desktop 不会进入宿主 applications 目录。"
    return comment + "\n" + " \\\n".join(command)


OPTIONAL_SECTIONS = {
    "PROTOCOL_HANDLER": render_protocol_handler,
}


def load_template(name):
    index = (TEMPLATES / "README.md").read_text(encoding="utf-8")
    if name not in TEMPLATE_LINK.findall(index):
        raise ValueError(f"模板未在 templates/README.md 登记：{name}")
    path = TEMPLATES / name
    if path.resolve() != path or not path.is_file():
        raise ValueError(f"模板必须是目录内的普通文件：{name}")
    return path.read_bytes().decode("utf-8")



def gtk_deb_source_arguments(params):
    """为 GTK DEB 标准保留 GitHub 来源，并支持官网 HTTPS 直链。"""
    params = params.copy()
    if "DEB_URL" in params:
        url = clean_text(params["DEB_URL"], "DEB_URL")
        if not re.fullmatch(r"https://[^\s#]+", url):
            raise ValueError("DEB_URL 必须是不含空白或片段的 HTTPS URL。")
        if {"GITHUB_REPOSITORY", "RELEASE_ASSET_PATTERN"} & params.keys():
            raise ValueError("官网 DEB 与 GitHub Release 来源参数不能混用。")
        checksum = params.pop("DEB_SHA256", "")
        if not isinstance(checksum, str) or (
            checksum and not re.fullmatch(r"[0-9a-fA-F]{64}", checksum)
        ):
            raise ValueError("DEB_SHA256 必须是完整的 64 位十六进制值；无官方摘要时省略。")
        source = (
            "# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。\n"
            'VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" '
            '--url "__DEB_URL__" '
            f'"{checksum.lower()}" "$SOURCE_DIR/__DEB_FILENAME__" "$APPDIR" '
            '"__DEB_PACKAGE__" "__DEB_ARCH__")"'
        )
    else:
        source = (
            "# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。\n"
            'VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" '
            '"__GITHUB_REPOSITORY__" \'__RELEASE_ASSET_PATTERN__\' "$SOURCE_DIR/__DEB_FILENAME__" "$APPDIR")"'
        )
    return params, source


def cli_apt_source_arguments(params):
    """为无框架插件模板保留 APT 入口，并支持指定已归档的官方 DEB。"""
    params = params.copy()
    source = (
        "# 下载已安装版本的软件包并解包到 AppDir，成功后返回版本号。\n"
        'VERSION="$("$SCRIPT_DIR/../common/apt/extract_installed_package.sh" "__APT_MAIN_PACKAGE__" "$APPDIR" __APT_EXTRA_PACKAGES__)"'
    )
    desktop_block = ""
    deploy_args = ""
    desktop_fields = {"DESKTOP_FILE", "ICON_FILE", "DESKTOP_EXEC", "DESKTOP_ICON"}
    if "RELEASE_TAG" in params:
        needed = {"GITHUB_REPOSITORY", "DEB_FILENAME"}
        if not needed <= params.keys():
            raise ValueError("归档 DEB 缺少参数：" + "、".join(sorted(needed - params.keys())))
        tag = clean_text(params.pop("RELEASE_TAG"), "RELEASE_TAG")
        repo = clean_text(params.pop("GITHUB_REPOSITORY"), "GITHUB_REPOSITORY")
        filename = render_parameter("DEB_FILENAME", params.pop("DEB_FILENAME"), "appimage")
        if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", tag)
                or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo)
                or not filename.endswith(".deb")):
            raise ValueError("归档标签、仓库或 DEB 文件名无效。")
        source = (
            "# 下载并校验官方安装包，将其安装到构建环境并解包到 AppDir，成功后返回版本号。\n"
            f'VERSION="$("$SCRIPT_DIR/../common/github/install_and_extract_latest_stable_release_deb.sh" '
            f'--release-tag "{tag}" "{repo}" "{filename}" "$SOURCE_DIR/{filename}" "$APPDIR")"'
        )
        if desktop_fields & params.keys():
            if not desktop_fields <= params.keys():
                raise ValueError("桌面资源参数必须同时包含 DESKTOP_FILE、ICON_FILE、DESKTOP_EXEC、DESKTOP_ICON。")
            desktop = clean_text(params.pop("DESKTOP_FILE"), "DESKTOP_FILE")
            icon = clean_text(params.pop("ICON_FILE"), "ICON_FILE")
            executable = clean_text(params.pop("DESKTOP_EXEC"), "DESKTOP_EXEC")
            icon_name = clean_text(params.pop("DESKTOP_ICON"), "DESKTOP_ICON")
            if (not re.fullmatch(r"usr/share/applications/[A-Za-z0-9_.-]+[.]desktop", desktop)
                    or not re.fullmatch(r"/usr/share/icons/[A-Za-z0-9_./-]+[.]png", icon)
                    or not BASENAME.fullmatch(executable) or not BASENAME.fullmatch(icon_name)):
                raise ValueError("桌面文件、图标、启动命令或图标名称无效。")
            desktop_block = (
                "\n########## 准备桌面资源和运行库 #########\n\n"
                "# 本程序专属处理：校验官方桌面资源，并在包内副本中设置 AppImage 的启动入口和图标。\n"
                f'DEPLOY_DESKTOP_FILE="$SOURCE_DIR/{Path(desktop).name}"\n'
                f'cp -a "$APPDIR/{desktop}" "$DEPLOY_DESKTOP_FILE"\n'
                f"sed -i -e 's|^Exec=.*$|Exec={executable}|' -e 's|^Icon=.*$|Icon={icon_name}|' \"$DEPLOY_DESKTOP_FILE\"\n"
                'cp -a "$DEPLOY_DESKTOP_FILE" "$APPDIR/usr/share/applications/"\n'
                f'ICON_FILE="{icon}"\n'
                '[[ -f "$ICON_FILE" ]] || { echo "错误：找不到官方安装包的图标。" >&2; exit 1; }'
            )
            deploy_args = '--desktop-file "$DEPLOY_DESKTOP_FILE" --icon-file "$ICON_FILE" '
    elif desktop_fields & params.keys():
        raise ValueError("APT 模式不能使用归档 DEB 的桌面资源参数。")
    return params, {
        "CLI_SOURCE_BLOCK": source,
        "CLI_DESKTOP_PREPARE": desktop_block,
        "CLI_DEPLOY_ARGS": deploy_args,
    }


def render(template, params, family):
    if not isinstance(params, dict):
        raise ValueError("参数文件必须是 JSON 对象。")
    if "__GTK_DEB_SOURCE_BLOCK__" in template:
        params, source = gtk_deb_source_arguments(params)
        template = template.replace("__GTK_DEB_SOURCE_BLOCK__", source)
    if "__CLI_SOURCE_BLOCK__" in template:
        params, derived = cli_apt_source_arguments(params)
        for marker, value in derived.items():
            template = template.replace("__" + marker + "__", value)
    placeholders = set(TOKEN.findall(template))
    optional = placeholders & OPTIONAL_SECTIONS.keys()
    required = placeholders - optional
    missing = required - params.keys()
    extra = params.keys() - placeholders
    if missing or extra:
        details = []
        if missing:
            details.append("缺少参数：" + "、".join(sorted(missing)))
        if extra:
            details.append("多余参数：" + "、".join(sorted(extra)))
        raise ValueError("。".join(details))
    values = {name: render_parameter(name, params[name], family) for name in required}
    result = TOKEN.sub(lambda match: values.get(match[1], match[0]), template)
    for name in sorted(optional):
        marker = f"__{name}__"
        line = f"\n{marker}\n"
        if template.count(marker) != 1 or line not in template:
            raise ValueError(f"模板中的 {marker} 必须独占一行且只出现一次。")
        block = ""
        if name in params:
            block = OPTIONAL_SECTIONS[name](params[name], values) + "\n\n"
        # 保留占位行之外的原有换行。
        result = result.replace(line, "\n" + block, 1)
    return result


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
