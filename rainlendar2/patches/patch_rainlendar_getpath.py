#!/usr/bin/env python3
import re
import struct
import subprocess
import sys

MODE = sys.argv[1]
BINARY = sys.argv[2]

if MODE not in {"patch", "check"}:
    raise SystemExit("用法：patch_rainlendar_getpath.py {patch|check} <rainlendar2>")


def run(*args):
    return subprocess.check_output(args, text=True, errors="strict")


NM_OUTPUT = run("nm", "-S", "-C", BINARY)


def find_symbol(name, required=True):
    matches = []
    for line in NM_OUTPUT.splitlines():
        match = re.match(r"^([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([A-Za-z])\s+(.+)$", line)
        if match and match.group(4) == name:
            matches.append((int(match.group(1), 16), int(match.group(2), 16)))
    matches = sorted(set(matches))
    if not matches and not required:
        return None
    if len(matches) != 1:
        raise SystemExit(f"错误：符号 {name!r} 应唯一存在，实际为 {matches}")
    return matches[0]


TARGET_ADDR, TARGET_SIZE = find_symbol("Rainlendar_GetPath")
STATIC_RESULT = find_symbol("Rainlendar_GetPath::strResult", required=False)

DISASSEMBLY = run(
    "objdump",
    "-d",
    "-C",
    f"--start-address={hex(TARGET_ADDR)}",
    f"--stop-address={hex(TARGET_ADDR + TARGET_SIZE)}",
    BINARY,
)

instructions = []
for line in DISASSEMBLY.splitlines():
    match = re.match(r"^\s*([0-9a-fA-F]+):\s+(?:[0-9a-fA-F]{2}\s+)+\s*(.*?)\s*$", line)
    if match:
        instructions.append((int(match.group(1), 16), match.group(2)))

getpath_calls = [
    address
    for address, asm in instructions
    if asm.startswith("call") and "<CRainlendar::GetPath(PATH_TYPE)>" in asm
]
move_assign_calls = [
    address
    for address, asm in instructions
    if asm.startswith("call") and "<wxString::operator=(wxString&&)>" in asm
]

if len(getpath_calls) != 1:
    raise SystemExit(f"错误：Rainlendar_GetPath 内 CRainlendar::GetPath 调用数量异常：{getpath_calls}")

GETPATH_CALL = getpath_calls[0]
PATCH_START = GETPATH_CALL + 5

# 如果上游以后删除共享静态返回值，并且不再执行 move-assign，则认为上游已修复，自动跳过二进制补丁。
if STATIC_RESULT is None and not move_assign_calls:
    print("Rainlendar_GetPath 已不再使用共享静态返回值；检测为上游已修复，跳过本地并发补丁。")
    raise SystemExit(0)

if STATIC_RESULT is None:
    raise SystemExit("错误：Rainlendar_GetPath 仍存在旧调用结构，但无法找到共享静态 strResult；拒绝猜测补丁。")

if STATIC_RESULT[1] != 48:
    raise SystemExit(f"错误：共享 wxString 大小异常：{STATIC_RESULT[1]}，拒绝补丁。")

MOVE_CTOR_ADDR, _ = find_symbol("wxString::wxString(wxString&&)")
DTOR_ADDR, _ = find_symbol("wxString::~wxString()")

# 保留原程序的 stack canary/leave/ret 收尾，只替换 GetPath 返回后的共享静态写入区。
canary_starts = [
    address
    for address, asm in instructions
    if address > PATCH_START and re.fullmatch(r"mov\s+-0x8\(%rbp\),%rdx", asm)
]
if len(canary_starts) != 1:
    raise SystemExit(f"错误：无法唯一定位 Rainlendar_GetPath 的 stack canary 收尾：{canary_starts}")

PATCH_END = canary_starts[0]
PATCH_SIZE = PATCH_END - PATCH_START

# 当前易受并发影响的实现中，CRainlendar::GetPath 的返回对象位于 rbp-0x40；
# rbp-0x50..rbp-0x49 是 0x50 字节栈帧中未使用的 8 字节槽，用来临时保存 heap 指针。
pre_getpath = "\n".join(asm for address, asm in instructions if GETPATH_CALL - 32 <= address < GETPATH_CALL)
if "-0x40(%rbp)" not in pre_getpath:
    raise SystemExit("错误：无法确认 Rainlendar_GetPath 的局部 wxString 位于 rbp-0x40，拒绝补丁。")
if not re.search(r"sub\s+\$0x50,%rsp", DISASSEMBLY):
    raise SystemExit("错误：Rainlendar_GetPath 栈帧不再是 0x50 字节，拒绝补丁。")

PLT_DISASSEMBLY = run("objdump", "-d", BINARY)
malloc_match = re.search(r"^([0-9a-fA-F]+) <malloc@plt>:$", PLT_DISASSEMBLY, re.MULTILINE)
if not malloc_match:
    raise SystemExit("错误：找不到 malloc@plt。")
MALLOC_ADDR = int(malloc_match.group(1), 16)


def build_patch():
    code = bytearray()

    def emit(hex_bytes):
        code.extend(bytes.fromhex(hex_bytes))

    def emit_call(destination):
        next_ip = PATCH_START + len(code) + 5
        relative = destination - next_ip
        if not -(1 << 31) <= relative < (1 << 31):
            raise SystemExit("错误：x86-64 rel32 调用超出范围。")
        code.extend(b"\xe8" + struct.pack("<i", relative))

    # 上游函数原本把每次 GetPath 结果 move-assign 到同一个 static wxString，多个同步线程会同时改写它。
    # 改为为本次调用分配独立的 48 字节 wxString 对象，并 move-construct 出不可再被其他线程覆盖的快照。
    # API 原本返回进程生命周期 static 对象的指针，调用方不会释放它；因此这里也让快照保留到进程退出。
    # 代价是每次路径查询保留一个很小的 wxString 对象，但路径查询只发生在启动/同步等低频路径，
    # 比继续共享同一个可变 wxString 更适合作为 AppImage 的稳定性修复。
    emit("bf30000000")      # mov edi, 48
    emit_call(MALLOC_ADDR)  # malloc(sizeof(wxString))
    emit("488945b0")        # mov [rbp-0x50], rax
    emit("4889c7")          # mov rdi, rax
    emit("488d75c0")        # lea rsi, [rbp-0x40]
    emit_call(MOVE_CTOR_ADDR)
    emit("488d7dc0")        # lea rdi, [rbp-0x40]
    emit_call(DTOR_ADDR)
    emit("488b45b0")        # mov rax, [rbp-0x50]

    if len(code) > PATCH_SIZE:
        raise SystemExit(f"错误：并发补丁需要 {len(code)} 字节，但安全区域只有 {PATCH_SIZE} 字节。")
    code.extend(b"\x90" * (PATCH_SIZE - len(code)))
    return bytes(code)


EXPECTED_PATCH = build_patch()

# ELF64 little-endian：把虚拟地址映射到文件偏移，避免假设 .text 的 VADDR 恰好等于文件偏移。
with open(BINARY, "rb") as handle:
    elf_header = handle.read(64)
if elf_header[:6] != b"\x7fELF\x02\x01":
    raise SystemExit("错误：只支持 ELF64 little-endian Rainlendar 二进制。")

program_header_offset = struct.unpack_from("<Q", elf_header, 32)[0]
program_header_size = struct.unpack_from("<H", elf_header, 54)[0]
program_header_count = struct.unpack_from("<H", elf_header, 56)[0]


def virtual_to_file_offset(vaddr):
    with open(BINARY, "rb") as handle:
        for index in range(program_header_count):
            handle.seek(program_header_offset + index * program_header_size)
            program_header = handle.read(program_header_size)
            p_type = struct.unpack_from("<I", program_header, 0)[0]
            if p_type != 1:  # PT_LOAD
                continue
            p_offset, p_vaddr, _, p_filesz = struct.unpack_from("<QQQQ", program_header, 8)
            if p_vaddr <= vaddr < p_vaddr + p_filesz:
                return p_offset + (vaddr - p_vaddr)
    raise SystemExit(f"错误：虚拟地址 0x{vaddr:x} 不在文件映射的 PT_LOAD 段中。")


PATCH_FILE_OFFSET = virtual_to_file_offset(PATCH_START)
with open(BINARY, "rb") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    CURRENT_PATCH_AREA = handle.read(PATCH_SIZE)

already_patched = CURRENT_PATCH_AREA == EXPECTED_PATCH

if MODE == "check":
    if already_patched:
        print("Rainlendar_GetPath 并发安全补丁验证通过。")
        raise SystemExit(0)
    if STATIC_RESULT is None and not move_assign_calls:
        print("Rainlendar_GetPath 已由上游修复，无需本地并发补丁。")
        raise SystemExit(0)
    raise SystemExit("错误：Rainlendar_GetPath 仍是共享静态返回实现，或补丁内容与预期不一致。")

if already_patched:
    print("Rainlendar_GetPath 并发安全补丁已存在，无需重复写入。")
    raise SystemExit(0)

# 只允许对已确认的共享静态 move-assign 实现动刀；上游布局发生变化时直接失败，禁止盲目 patch。
if len(move_assign_calls) != 1 or not (PATCH_START < move_assign_calls[0] < PATCH_END):
    raise SystemExit(f"错误：共享静态 move-assign 结构异常：{move_assign_calls}，拒绝补丁。")
if "Rainlendar_GetPath::strResult" not in DISASSEMBLY:
    raise SystemExit("错误：反汇编中没有共享静态 strResult 引用，拒绝补丁。")

with open(BINARY, "r+b") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    handle.write(EXPECTED_PATCH)

with open(BINARY, "rb") as handle:
    handle.seek(PATCH_FILE_OFFSET)
    if handle.read(PATCH_SIZE) != EXPECTED_PATCH:
        raise SystemExit("错误：Rainlendar_GetPath 二进制补丁写入后校验失败。")

print(
    f"Rainlendar_GetPath 并发安全补丁完成："
    f"0x{PATCH_START:x}-0x{PATCH_END:x}，共享静态返回改为独立 wxString 快照。"
)
