#!/usr/bin/env python3

# 调整已解包副本：界面资源改到包内，宿主命令不再继承包内 Python 环境。
import pathlib
import sys

REPLACEMENTS = (
    ("'/usr/share/gufw/ui/", "os.environ['GUFW_SHARE'] + '/ui/"),
    ("'/usr/share/gufw/media/shields/'", "os.environ['GUFW_SHARE'] + '/media/shields/'"),
    ("DIR_PROFILES = '/etc/gufw/app_profiles'", "DIR_PROFILES = os.environ['GUFW_PROFILES']"),
)
VIEW_FILES = (
    "usr/share/gufw/gufw/gufw/view/gufw.py",
    "usr/share/gufw/gufw/gufw/view/preferences.py",
    "usr/share/gufw/gufw/gufw/view/about.py",
    "usr/share/gufw/gufw/gufw/view/add.py",
    "usr/share/gufw/gufw/gufw/view/update.py",
)
UI_FILES = (
    "usr/share/gufw/ui/gufw.ui",
    "usr/share/gufw/ui/preferences.ui",
    "usr/share/gufw/ui/about.ui",
)
BACKEND = "usr/share/gufw/gufw/gufw/model/ufw_backend.py"
OLD_RUN = """    def _run_cmd(self, cmd, lang_c=False):
        if lang_c:
            proc = subprocess.Popen(cmd, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={'LANG':'C'})
        else:
            proc = subprocess.Popen(cmd, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
"""
NEW_RUN = """    def _host_command_env(self, lang_c):
        blocked = {
            'PYTHONHOME', 'PYTHONPATH', 'PYTHONNOUSERSITE', 'PYTHONDONTWRITEBYTECODE',
            'PYTHONSAFEPATH', 'PYTHONSTARTUP', 'PYTHONUSERBASE',
            'LD_LIBRARY_PATH', 'LD_PRELOAD', 'GI_TYPELIB_PATH',
            'GTK_DATA_PREFIX', 'GTK_EXE_PREFIX', 'GTK_PATH', 'GTK_IM_MODULE_FILE',
            'GTK_THEME', 'GIO_MODULE_DIR', 'GDK_PIXBUF_MODULE_FILE',
            'GSETTINGS_SCHEMA_DIR', 'LOCPATH',
        }
        env = {key: value for key, value in os.environ.items() if key not in blocked}
        env['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        if lang_c:
            env['LANG'] = 'C'
            env['LC_ALL'] = 'C'
        return env

    def _run_cmd(self, cmd, lang_c=False):
        proc = subprocess.Popen(
            cmd, shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env=self._host_command_env(lang_c))
"""
LOCALE_BOOTSTRAP = """import os
import locale
import gettext

_gufw_locale = os.environ.get("GUFW_LOCALE")
if _gufw_locale:
    locale.bindtextdomain("gufw", _gufw_locale)
    locale.textdomain("gufw")
    gettext.bindtextdomain("gufw", _gufw_locale)
    gettext.textdomain("gufw")

"""


def fail(message):
    raise SystemExit(f"错误：{message}")


def ensure_import_os(text):
    if "import os\n" in text or "import os," in text:
        return text
    lines = text.splitlines(keepends=True)
    insert_at = 0
    for index, line in enumerate(lines):
        if line.startswith("import ") or line.startswith("from "):
            insert_at = index + 1
    lines.insert(insert_at, "import os\n")
    return "".join(lines)


def main():
    if len(sys.argv) != 2:
        fail(f"用法：{sys.argv[0]} <AppDir>")
    root = pathlib.Path(sys.argv[1])
    if not root.is_dir():
        fail(f"AppDir 不存在：{root}")
    entry = root / "usr/share/gufw/gufw/gufw.py"

    for relative in VIEW_FILES:
        path = root / relative
        if not path.is_file():
            fail(f"缺少界面模块：{relative}")
        text = path.read_text(encoding="utf-8")
        updated = text
        for old, new in REPLACEMENTS:
            if old in updated:
                updated = updated.replace(old, new)
        if "os.environ" in updated:
            updated = ensure_import_os(updated)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
        if "/usr/share/gufw" in path.read_text(encoding="utf-8"):
            fail(f"仍有固定界面资源路径：{relative}")

    add_text = (root / "usr/share/gufw/gufw/gufw/view/add.py").read_text(encoding="utf-8")
    if "os.environ['GUFW_PROFILES']" not in add_text:
        fail("预设规则目录仍指向固定系统路径")

    # 窗口按图标名称从包内 hicolor 查找，不使用宿主绝对路径。
    old_icon = '<property name="icon">/usr/share/icons/hicolor/48x48/apps/gufw.png</property>'
    new_icon = '<property name="icon_name">gufw</property>'
    for relative in UI_FILES:
        path = root / relative
        text = path.read_text(encoding="utf-8")
        updated = text.replace(old_icon, new_icon)
        if updated != text:
            path.write_text(updated, encoding="utf-8")

    # 普通规则和日志文本继承主题前景色，避免深色界面仍使用固定黑色。
    main_view = root / VIEW_FILES[0]
    text = main_view.read_text(encoding="utf-8")
    updated = text.replace("    BLACK  = '#000000'", "    BLACK  = None")
    if updated != text:
        main_view.write_text(updated, encoding="utf-8")

    backend = root / BACKEND
    if not backend.is_file():
        fail("缺少 ufw 后端")
    backend_text = backend.read_text(encoding="utf-8")
    if "_host_command_env" not in backend_text:
        if OLD_RUN not in backend_text:
            fail("未找到宿主命令的原始启动代码")
        backend.write_text(backend_text.replace(OLD_RUN, NEW_RUN, 1), encoding="utf-8")
    elif "env=self._host_command_env(lang_c)" not in backend.read_text(encoding="utf-8"):
        fail("宿主命令环境未接到实际调用")

    if not entry.is_file():
        fail("缺少 Gufw 入口脚本")
    entry_text = entry.read_text(encoding="utf-8")
    needle = "from gufw.controller import Controller"
    if needle not in entry_text:
        fail("未找到 Gufw 入口导入")
    if "GUFW_LOCALE" not in entry_text:
        entry.write_text(entry_text.replace(needle, LOCALE_BOOTSTRAP + needle, 1), encoding="utf-8")


if __name__ == "__main__":
    main()
