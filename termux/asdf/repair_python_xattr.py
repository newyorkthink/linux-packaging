#!/usr/bin/env python3
"""为已安装的 Termux CPython 修补 shutil 扩展属性复制，无需重编译。"""

import ast
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile
import uuid


def main():
    # 使用当前解释器定位标准库；虚拟环境通常共用基础 Python 的此文件。
    if not os.environ.get("PREFIX") or sys.implementation.name != "cpython":
        raise SystemExit("请在 Termux 中使用需要修复的 CPython 执行。")
    path = Path(shutil.__file__).resolve()
    if path.suffix != ".py" or not path.is_relative_to(Path(sys.base_prefix).resolve()):
        raise SystemExit("标准库位置与当前基础 Python 不符，未修改任何文件。")

    original = path.read_bytes()
    source = original.decode("utf-8")
    marker = "TERMUX_SKIP_SHUTIL_XATTR"
    if marker in source or not hasattr(os, "listxattr"):
        print("当前 Python 已禁用此扩展属性复制，无需重复修补。")
        return

    # 只替换具名参数的 _copyxattr，保留 copyfile、chmod、utime 等行为。
    candidates = [
        node for node in ast.walk(ast.parse(source))
        if isinstance(node, ast.FunctionDef)
        and node.name == "_copyxattr"
        and [arg.arg for arg in node.args.args] == ["src", "dst"]
    ]
    if len(candidates) != 1:
        raise SystemExit("shutil 的扩展属性实现发生变化，未修改任何文件。")
    node = candidates[0]
    lines = source.splitlines(keepends=True)
    indent = " " * node.col_offset
    lines[node.lineno - 1:node.end_lineno] = [
        indent + "def _copyxattr(src, dst, *, follow_symlinks=True):\n",
        indent + "    # TERMUX_SKIP_SHUTIL_XATTR: Android 不允许复制安全扩展属性。\n",
        indent + "    return\n",
    ]
    updated = "".join(lines).encode("utf-8")

    # 备份只复制内容，避免备份操作再次调用有问题的 copy2 / copystat。
    backup = path.with_name(path.name + ".before-termux-xattr-" + uuid.uuid4().hex + ".bak")
    with backup.open("xb") as output:
        output.write(original)

    # 同目录原子替换并保留原文件权限，不触碰已安装包或虚拟环境目录。
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".shutil-xattr-", delete=False) as output:
            temporary = Path(output.name)
            output.write(updated)
        temporary.chmod(stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
    print(f"已修补：{path}\n原文件备份：{backup}\n请在新的 Python / pip 进程中重试原命令。")


def repair_cryptography():
    # 仅在显式选择时执行；默认 xattr 修补入口保持原样。
    if not os.environ.get("PREFIX") or sys.implementation.name != "cpython":
        raise SystemExit("请在 Termux 中使用需要修复的 CPython 执行。")

    # 保留已在 Termux 实测成功的备份及补链接步骤。
    from pathlib import Path
    from importlib.metadata import distribution
    import shutil
    import subprocess
    import sysconfig
    import uuid

    so = Path(distribution("cryptography").locate_file(
        "cryptography/hazmat/bindings/_rust.abi3.so")).resolve()
    lib = (Path(sysconfig.get_config_var("LIBDIR")) /
           sysconfig.get_config_var("LDLIBRARY")).resolve()
    if not so.is_file() or not lib.is_file():
        raise SystemExit("未找到当前 Python 的扩展或共享库，未修改文件。")

    needed = subprocess.check_output(
        ["patchelf", "--print-needed", str(so)], text=True).splitlines()
    if str(lib) not in needed:
        # 先备份扩展内容，避免复制扩展属性。
        backup = so.with_name(so.name + ".backup-" + uuid.uuid4().hex)
        shutil.copyfile(so, backup)
        # 使用当前解释器的完整库路径，避免混用其他 Python 版本。
        subprocess.run(["patchelf", "--add-needed", str(lib), str(so)], check=True)
        print(f"已补充依赖：{lib}\n备份：{backup}")
    else:
        print("此共享库依赖已存在，无需重复修改。")


if __name__ == "__main__":
    if sys.argv[1:] == ["--cryptography"]:
        repair_cryptography()
    elif sys.argv[1:]:
        raise SystemExit("用法：repair_python_xattr.py [--cryptography]")
    else:
        main()
