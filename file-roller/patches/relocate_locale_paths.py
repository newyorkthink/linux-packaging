from pathlib import Path
import os

appdir = Path(os.environ["PATCH_APPDIR"])
elf_magic = b"\x7fELF"
replacements = (
    (b"/usr/share/locale-langpack\x00", b"usr/share/locale\x00"),
    (b"/usr/share/locale\x00", b"usr/share/locale\x00"),
)
patched = []

for path in appdir.rglob("*"):
    if not path.is_file() or path.is_symlink():
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    if not data.startswith(elf_magic):
        continue

    original = data
    for old, new in replacements:
        if old not in data:
            continue
        if len(new) > len(old):
            raise SystemExit(f"replacement is longer than source for {path}")
        padded = new + (b"\x00" * (len(old) - len(new)))
        data = data.replace(old, padded)

    if data != original:
        path.write_bytes(data)
        patched.append(str(path.relative_to(appdir)))

if "usr/bin/file-roller" not in patched:
    raise SystemExit("file-roller 主程序没有发现可重定位的 locale 路径")

print("已重定位 locale 路径的 ELF：")
for item in patched:
    print(item)
