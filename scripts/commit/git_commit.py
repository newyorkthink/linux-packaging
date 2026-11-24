#!/usr/bin/env python3
# 按固定格式预览、执行或撤回一次本地 Git 提交。
#
# 运行环境为 Linux，需要 Git 和 Python 3.10 或更新版本。脚本只使用 Python 标准库。
# 脚本从自身所在目录查找 Git 仓库，可独立运行。终端的当前目录不影响目标仓库。
# 需要仓库处于普通分支上。合并、变基等 Git 操作尚未完成时，先处理该操作。
#
# 除 undo-preview 外，各模式从标准输入读取一个 JSON 对象。手动运行时，粘贴 JSON 后按 Ctrl+D。
# files 填相对于仓库根目录的文件路径数组。明确要提交全部改动时，填字符串 "all"。
# inspect 读取指定文件的完整差异并返回 diff_id。省略模式时默认执行 inspect。
# 查看完整差异时，同一文件若同时有暂存和未暂存改动，脚本会分别显示两部分。
# preview 接收 files、title、changes 和可选的 verification、diff_id。
# title 填中文标题。changes 填改动说明数组，每项一行。verification 只填实际检查结果。
# 如果 inspect 已返回 diff_id，可把它原样传给 preview。脚本核对差异后，只显示文件清单和提交说明。
# 未提供 diff_id 时，preview 同时显示完整差异。预览会返回 preview_id。
# commit 使用同一份 preview 输入，并加上 preview_id。调用者须先取得本次明确的提交同意。
# 脚本核对预览内容，完整暂存指定文件，在当前分支提交一次，再核对文件与提交说明。
# undo-preview 无须输入 JSON，只读预览当前分支最近一次普通提交，并返回 undo_id。
# undo 接收 commit（预览中的完整提交号）和 undo_id；调用者须先取得本次明确的撤回同意。
# 撤回只把当前分支移到该提交的父提交，保留工作区、暂存区和未跟踪文件，不新增反向提交。
# 撤回记录保留在分支 reflog 中。初始提交、合并提交和未完成的 Git 操作不支持撤回。
# 撤回后可继续修改文件，再使用 inspect、preview 和 commit 重新提交。
#
# inspect 和 preview 只读，不写入仓库文件、索引或预览文件。commit 写入本地 Git 索引和历史，
# 沿用仓库的提交钩子和签名设置。提交失败时，已完整暂存的文件保留在暂存区。
# undo-preview 只读；undo 只更新本地分支引用及 reflog，不改写文件、索引或 ORIG_HEAD。
# 退出码 0 表示当前操作成功。失败时输出原因。若已创建提交，核对失败时会列出提交号。
#
# 以下命令在脚本所在目录的 Linux 终端运行。路径、说明和校验值按本次结果填写。
#
# 查看帮助。
# python3 git_commit.py --help
#
# 读取文件差异，输入 {"files":["<仓库相对路径>"]}。
# python3 git_commit.py inspect
#
# 生成提交预览，输入 {"files":["<仓库相对路径>"],"title":"<中文标题>",
# "changes":["<改动及用途>"],"diff_id":"<inspect 返回的值>"}。
# python3 git_commit.py preview
#
# 获得本次明确同意后，输入同一份预览 JSON，并加上 "preview_id":"<预览返回的值>"。
# python3 git_commit.py commit
#
# 预览最近一次提交的撤回目标和影响，不需要输入 JSON。
# python3 git_commit.py undo-preview
#
# 获得本次明确同意后，输入 {"commit":"<预览中的完整提交号>","undo_id":"<预览返回的值>"}。
# python3 git_commit.py undo

from __future__ import annotations

import argparse
from dataclasses import dataclass
import fcntl
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


class CommitError(Exception):
    """用于报告提交脚本遇到的问题。"""


# 以脚本所在仓库和 Git 的字面路径为准，避免继承变量把操作指向别的索引或仓库。
REPOSITORY_ENV = {
    "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE", "GIT_NAMESPACE",
    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_GLOB_PATHSPECS", "GIT_NOGLOB_PATHSPECS", "GIT_ICASE_PATHSPECS",
}
GIT_ENV = {key: value for key, value in os.environ.items() if key not in REPOSITORY_ENV}
DIFF_OPTIONS = (
    "--no-ext-diff", "--no-textconv", "--no-color", "--no-relative",
    "--no-renames", "--full-index",
)
OPERATIONS = (
    "MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "sequencer",
)
UNMERGED = {"DD", "AU", "UD", "UA", "DU", "AA", "UU"}


# Git 参数固定传入子进程。只读命令关闭可选锁，避免状态查询刷新索引。
def git(
    root: Path,
    *args: str,
    accepted: tuple[int, ...] = (0,),
    data: bytes = b"",
) -> bytes:
    result = subprocess.run(
        ["git", "--no-optional-locks", "--literal-pathspecs", "-c", "core.quotePath=false",
         "-C", str(root), *args],
        env=GIT_ENV,
        input=data,
        capture_output=True,
    )
    if result.returncode not in accepted:
        detail = (result.stderr or result.stdout).decode("utf-8", errors="replace").strip()
        raise CommitError(f"Git {args[0]} 失败（退出码 {result.returncode}）。\n{detail}".rstrip())
    return result.stdout


# Git 的 NUL 分隔输出保留空格、中文和其他合法文件名。
def records(data: bytes) -> list[bytes]:
    return data.rstrip(b"\0").split(b"\0") if data else []


# 提交绑定当前分支和 HEAD。新仓库尚无提交时，HEAD 值留空。
def branch_head(root: Path) -> tuple[str, str]:
    branch = git(root, "symbolic-ref", "--quiet", "--short", "HEAD", accepted=(0, 1))
    if not branch:
        raise CommitError("当前处于游离 HEAD 状态，请在目标分支上使用本脚本。")
    head = git(root, "rev-parse", "--verify", "--quiet", "HEAD", accepted=(0, 1))
    return os.fsdecode(branch).rstrip("\n"), head.decode("ascii").strip()


# 按文件提交不能接管已有的合并、变基或其他 Git 操作。
def check_operation(root: Path) -> None:
    args = [part for name in OPERATIONS for part in ("--git-path", name)]
    paths = os.fsdecode(git(root, "rev-parse", *args)).splitlines()
    for path in paths:
        if (root / path).exists():
            raise CommitError(f"仓库中仍有 Git 操作待完成（{Path(path).name}）。")


# 拒绝重复字段，避免 JSON 中后出现的值覆盖已预览的内容。
def unique_fields(pairs: list[tuple[str, object]]) -> dict[str, object]:
    values = {}
    for key, value in pairs:
        if key in values:
            raise CommitError(f"输入含有重复字段 {key!r}。")
        values[key] = value
    return values


def read_request(mode: str) -> dict[str, object]:
    if sys.stdin.isatty():
        print("请粘贴 JSON，然后按 Ctrl+D 结束输入。", file=sys.stderr)
    request = json.load(sys.stdin, object_pairs_hook=unique_fields)
    if mode == "undo":
        if not isinstance(request, dict) or request.keys() != {"commit", "undo_id"}:
            raise CommitError("撤回须填写 commit 和 undo_id，不接受其他字段。")
        if not isinstance(request["commit"], str) or not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", request["commit"]):
            raise CommitError("commit 必须填写撤回预览中的完整提交号。")
        if not isinstance(request["undo_id"], str) or not re.fullmatch(r"[0-9a-f]{64}", request["undo_id"]):
            raise CommitError("undo_id 必须填写撤回预览返回的校验值。")
        return request
    required = {"files"} if mode == "inspect" else {"files", "title", "changes"}
    if mode == "commit":
        required.add("preview_id")
    optional = set() if mode == "inspect" else {"verification", "diff_id"}
    if not isinstance(request, dict) or not required <= request.keys() <= required | optional:
        raise CommitError(f"输入字段有遗漏或超出范围。必填 {sorted(required)}，选填 {sorted(optional)}。")
    files = request["files"]
    if files != "all" and (
        not isinstance(files, list) or not files
        or any(not isinstance(path, str) or not path or "\0" in path for path in files)
        or len(files) != len(set(files))
    ):
        raise CommitError('files 必须是具体文件的路径数组，或字符串 "all"。')
    for name in ("diff_id", "preview_id"):
        if name in request and (
            not isinstance(request[name], str) or not re.fullmatch(r"[0-9a-f]{64}", request[name])
        ):
            raise CommitError(f"{name} 必须填写脚本返回的校验值。")
    return request


# 标题和正文按单行接收，空行和列表标记由脚本统一添加。
def message_line(value: object, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise CommitError(f"{name} 必须填写非空的单行文字。")
    line = value.strip()
    if re.search(r"[\x00-\x1f\x7f-\x9f\u2028\u2029]", value):
        raise CommitError(f"{name} 必须填写单行文字。")
    if re.fullmatch(r"<[^<>]+>", line) or re.match(r"^(?:[-+*]\s|\d+[.)]\s|验证[:：])", line):
        raise CommitError(f"{name} 请填写实际正文，列表和验证标记由脚本生成。")
    return line


def format_message(request: dict[str, object]) -> str:
    title = message_line(request["title"], "title")
    if not re.search(r"[\u3400-\u4dbf\u4e00-\u9fff]", title):
        raise CommitError("title 必须使用中文标题。")
    changes = request["changes"]
    if not isinstance(changes, list) or not changes:
        raise CommitError("changes 至少填写一条改动。")
    lines = [title, "", *(f"- {message_line(item, 'changes')}" for item in changes)]
    if "verification" in request:
        lines.append(f"- 验证：{message_line(request['verification'], 'verification')}")
    return "\n".join(lines) + "\n"


# 预览校验值同时绑定文件差异和提交说明。换行分隔两部分输入。
def approval_id(diff_id: str, message: str) -> str:
    return sha256(f"{diff_id}\n{message}".encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class Snapshot:
    branch: str
    head: str
    paths: tuple[str, ...]
    statuses: dict[str, str]
    versions: tuple[tuple[int, str] | None, ...]
    patch: bytes
    diff_id: str


# 直接读取工作区中的完整文件。符号链接只读取链接目标文字，不跟随链接。
def worktree_versions(root: Path, paths: tuple[str, ...]) -> tuple[tuple[int, str] | None, ...]:
    versions = []
    for name in paths:
        path = root / name
        if not path.parent.resolve().is_relative_to(root):
            raise CommitError(f"路径 {name!r} 超出当前仓库范围。")
        try:
            mode = path.lstat().st_mode
        except FileNotFoundError:
            versions.append(None)
            continue
        if stat.S_ISLNK(mode):
            digest = sha256(os.fsencode(os.readlink(path))).hexdigest()
        elif stat.S_ISREG(mode):
            hasher = sha256()
            with path.open("rb") as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    hasher.update(block)
            digest = hasher.hexdigest()
        else:
            raise CommitError(f"路径 {name!r} 是目录、子模块或特殊文件，无法按普通文件提交。")
        versions.append((stat.S_IFMT(mode) | (mode & 0o111), digest))
    return tuple(versions)


# HEAD 差异涵盖已暂存和未暂存修改。未跟踪文件单独与空文件比较。
def snapshot(root: Path, requested: str | list[str]) -> Snapshot:
    check_operation(root)
    branch, head = branch_head(root)
    scope = [] if requested == "all" else requested
    raw = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames", "--", *scope)
    statuses = {}
    for item in records(raw):
        code = item[:2].decode("ascii")
        name = os.fsdecode(item[3:])
        if name in statuses or code in UNMERGED:
            raise CommitError(f"文件 {name!r} 有冲突，或同时被列为暂存删除和未跟踪。")
        statuses[name] = code

    paths = tuple(sorted(statuses if requested == "all" else requested))
    if not paths:
        raise CommitError("当前范围内没有可提交的改动。")
    missing = set(paths) - statuses.keys()
    if missing:
        raise CommitError(f"以下文件没有改动，或路径与 Git 状态中的相对路径不一致。{sorted(missing)!r}")

    versions = worktree_versions(root, paths)
    index = git(root, "ls-files", "--stage", "-z", "--", *paths)
    tracked = tuple(name for name in paths if head and statuses[name] != "??")
    patches = []
    if tracked:
        changed = git(root, "diff", *DIFF_OPTIONS, "--name-only", "-z", head, "--", *tracked)
        if set(map(os.fsdecode, records(changed))) != set(tracked):
            raise CommitError("部分文件的工作区内容与 HEAD 相同，请核对文件清单。")
        patches.append(git(root, "diff", *DIFF_OPTIONS, head, "--", *tracked))
    for name, version in zip(paths, versions):
        if not head or statuses[name] == "??":
            if version is None:
                raise CommitError(f"文件 {name!r} 已不存在，请重新核对差异。")
            patches.append(git(root, "diff", "--no-index", *DIFF_OPTIONS, "--",
                               "/dev/null", f"./{name}", accepted=(0, 1)))

    # 两部分改动可能互相抵消，单看 HEAD 差异看不出暂存区里原有的内容。
    mixed = tuple(name for name in paths if statuses[name] != "??" and " " not in statuses[name])
    if mixed:
        patches.extend((
            "\n同一文件已有的暂存差异\n".encode("utf-8"),
            git(root, "diff", *DIFF_OPTIONS, "--cached", "--", *mixed),
            "\n同一文件的未暂存差异\n".encode("utf-8"),
            git(root, "diff", *DIFF_OPTIONS, "--", *mixed),
        ))
    patch = b"".join(patches)

    # 生成校验值前，再核对分支、文件和暂存区。读取期间有变化时，脚本会提示重新检查。
    if (branch_head(root) != (branch, head)
            or worktree_versions(root, paths) != versions
            or git(root, "ls-files", "--stage", "-z", "--", *paths) != index
            or git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all",
                   "--no-renames", "--", *scope) != raw):
        raise CommitError("读取差异期间仓库内容发生变化，请重新检查。")
    identity = json.dumps(
        [str(root), branch, head, requested == "all", paths, statuses, versions,
         sha256(index).hexdigest(), sha256(patch).hexdigest()],
        sort_keys=True,
    )
    return Snapshot(branch, head, paths, statuses, versions, patch, sha256(identity.encode()).hexdigest())


def show_scope(root: Path, state: Snapshot) -> None:
    print(f"仓库 {root}\n分支 {state.branch}\n文件 {len(state.paths)} 项（前两列为 Git 暂存区和工作区状态）")
    for path in state.paths:
        print(f"  {state.statuses[path]} {path!r}")


# 从暂存区和提交树提取文件模式及对象编号，用于逐文件比较完整内容。
def object_versions(data: bytes, *, from_tree: bool = False) -> dict[bytes, tuple[bytes, bytes]]:
    entries = {}
    for item in records(data):
        metadata, name = item.split(b"\t", 1)
        mode, second, third = metadata.split()
        if not from_tree and third != b"0":
            raise CommitError(f"暂存区存在未合并的文件 {os.fsdecode(name)!r}。")
        entries[name] = (mode, third if from_tree else second)
    return entries


# 只暂存指定路径。Git 的路径提交保留清单外已经暂存的改动。
def create_commit(root: Path, state: Snapshot, message: str) -> None:
    to_stage = [path for path in state.paths if state.statuses[path][1] != " "]
    if to_stage:
        git(root, "add", "--all", "--", *to_stage)
    try:
        staged = git(root, "diff", "--cached", "--name-only", "--no-renames", "-z", "--", *state.paths)
        if set(map(os.fsdecode, records(staged))) != set(state.paths):
            raise CommitError("暂存区中的改动与确认的文件清单不一致。")
        if (branch_head(root) != (state.branch, state.head)
                or worktree_versions(root, state.paths) != state.versions
                or git(root, "diff", "--name-only", "-z", "--", *state.paths)):
            raise CommitError("暂存后分支或文件内容发生变化，请重新预览。")
        expected = object_versions(git(root, "ls-files", "--stage", "-z", "--", *state.paths))
        git(root, "commit", "--only", "--cleanup=verbatim", "--file=-", "--", *state.paths,
            data=message.encode("utf-8"))
    except (CommitError, OSError) as error:
        raise CommitError(f"{error}\n本次选定文件已暂存，请核对暂存区。") from error

    # 提交已产生时先给出提交号。核对失败交由调用者检查，不改写提交历史。
    branch, commit = branch_head(root)
    print(f"已创建本地提交 {commit}（{branch}）", flush=True)
    parent_line = git(root, "rev-list", "--parents", "-n", "1", commit).decode("ascii").split()
    expected_parents = [state.head] if state.head else []
    committed = git(root, "diff-tree", "--root", "--no-commit-id", "--name-only",
                    "--no-renames", "-r", "-z", commit)
    actual = object_versions(git(root, "ls-tree", "-z", commit, "--", *state.paths), from_tree=True)
    log_message = git(root, "log", "-1", "--format=%B", commit).decode("utf-8").rstrip("\n")
    if (branch != state.branch or parent_line != [commit, *expected_parents]
            or set(map(os.fsdecode, records(committed))) != set(state.paths)
            or actual != expected or log_message != message.rstrip("\n")):
        raise CommitError("提交后的文件、分支或说明与预览不一致，请核对上面的提交。")
    for path in state.paths:
        print(f"  {path!r}")


# 撤回预览单独记录完整暂存信息，允许工作区干净或暂存与未暂存改动互相抵消。
@dataclass(frozen=True)
class UndoSnapshot:
    branch: str
    head: str
    parent: str
    subject: str
    paths: tuple[str, ...]
    versions: tuple[tuple[int, str] | None, ...]
    index: bytes
    undo_id: str


def undo_snapshot(root: Path) -> UndoSnapshot:
    check_operation(root)
    branch, head = branch_head(root)
    if not head:
        raise CommitError("当前分支尚无提交，无法撤回。")
    parents = git(root, "rev-list", "--parents", "-n", "1", head).decode("ascii").split()
    if len(parents) == 1:
        raise CommitError("初始提交没有父提交，不支持撤回。")
    if len(parents) != 2:
        raise CommitError("合并提交有多个父提交，不支持直接撤回。")
    parent = parents[1]
    subject = git(root, "log", "-1", "--format=%s", head).decode("utf-8", errors="replace").rstrip("\n")
    status = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames")
    dirty = []
    for item in records(status):
        if item[:2].decode("ascii") in UNMERGED:
            raise CommitError("暂存区存在未解决的冲突，无法撤回提交。")
        dirty.append(os.fsdecode(item[3:]))
    changed = git(root, "diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", "-z", head)
    paths = tuple(sorted(set(dirty) | set(map(os.fsdecode, records(changed)))))
    versions = worktree_versions(root, paths)
    index = git(root, "ls-files", "--stage", "-z")
    if (branch_head(root) != (branch, head)
            or worktree_versions(root, paths) != versions
            or git(root, "ls-files", "--stage", "-z") != index
            or git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames") != status):
        raise CommitError("读取撤回预览期间仓库内容发生变化，请重新预览。")
    identity = json.dumps(
        ["undo", str(root), branch, head, parent, paths, versions,
         sha256(index).hexdigest(), sha256(status).hexdigest()],
        sort_keys=True,
    )
    return UndoSnapshot(branch, head, parent, subject, paths, versions, index,
                        sha256(identity.encode()).hexdigest())


def show_undo(root: Path, state: UndoSnapshot) -> None:
    print(f"仓库 {root}\n分支 {state.branch}")
    print(f"将撤回提交 {state.head} {state.subject}\n回到提交 {state.parent}")
    print("只撤回最近一次提交，工作区、暂存区和未跟踪文件原样保留。")
    print(f"核对文件 {len(state.paths)} 项（包括该提交涉及的文件及现有未提交文件）")
    for path in state.paths:
        print(f"  {path!r}")
    print(f"undo_id {state.undo_id}")


# 用完整分支引用和旧提交号原子核对目标，避免把新的提交或另一分支一并撤回。
def undo_commit(root: Path, request: dict[str, object]) -> None:
    git_dir = Path(os.fsdecode(git(root, "rev-parse", "--absolute-git-dir")).rstrip("\n"))
    lock = os.open(git_dir, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = undo_snapshot(root)
        if request["commit"] != state.head or request["undo_id"] != state.undo_id:
            raise CommitError("撤回目标、文件或暂存区与预览不一致，请重新运行 undo-preview。")
        git(root, "update-ref", "--create-reflog", "-m", "git_commit.py: undo last commit",
            f"refs/heads/{state.branch}", state.parent, state.head)
        print(f"已撤回本地提交 {state.head}（{state.branch}）", flush=True)
        print(f"当前分支头 {state.parent}", flush=True)
        if (branch_head(root) != (state.branch, state.parent)
                or git(root, "ls-files", "--stage", "-z") != state.index
                or worktree_versions(root, state.paths) != state.versions):
            raise CommitError("撤回已经发生，但后续核对发现分支、暂存区或文件发生变化；请检查上面的提交号，不要重复撤回。")
        print("文件和暂存内容已核对，均原样保留；可继续修改后重新预览并提交。")
    finally:
        os.close(lock)


def main() -> int:
    parser = argparse.ArgumentParser(description="预览、执行或撤回一次本地 Git 提交。")
    parser.add_argument(
        "mode", choices=("inspect", "preview", "commit", "undo-preview", "undo"), nargs="?", default="inspect",
        help="inspect 查看差异（默认），preview 预览，commit 提交，undo-preview 预览撤回，undo 确认撤回。",
    )
    mode = parser.parse_args().mode
    try:
        request = {} if mode == "undo-preview" else read_request(mode)
        here = Path(__file__).resolve().parent
        root = Path(os.fsdecode(git(here, "rev-parse", "--show-toplevel")).rstrip("\n")).resolve()
        if mode == "undo-preview":
            show_undo(root, undo_snapshot(root))
            return 0
        if mode == "undo":
            undo_commit(root, request)
            return 0
        if mode == "inspect":
            state = snapshot(root, request["files"])
            show_scope(root, state)
            print(state.patch.decode("utf-8", errors="replace"), end="")
            print(f"diff_id {state.diff_id}")
            return 0

        message = format_message(request)
        if mode == "preview":
            state = snapshot(root, request["files"])
            if "diff_id" in request and request["diff_id"] != state.diff_id:
                raise CommitError("文件差异与先前检查的内容不一致，请重新检查。")
            show_scope(root, state)
            if "diff_id" not in request:
                print(state.patch.decode("utf-8", errors="replace"), end="")
            print(f"\n提交说明\n{message}")
            print(f"preview_id {approval_id(state.diff_id, message)}")
            return 0

        # 对仓库的 Git 目录加进程锁，防止两个脚本实例同时提交或撤回。
        git_dir = Path(os.fsdecode(git(root, "rev-parse", "--absolute-git-dir")).rstrip("\n"))
        lock = os.open(git_dir, os.O_RDONLY | os.O_DIRECTORY)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            state = snapshot(root, request["files"])
            preview_id = approval_id(state.diff_id, message)
            if request["preview_id"] != preview_id or request.get("diff_id", state.diff_id) != state.diff_id:
                raise CommitError("文件、暂存区或提交说明与预览不一致，请重新预览。")
            create_commit(root, state, message)
        finally:
            os.close(lock)
    except json.JSONDecodeError as error:
        print(f"输入不是有效的 JSON（第 {error.lineno} 行，第 {error.colno} 列）。", file=sys.stderr)
        return 1
    except BlockingIOError:
        print("同一仓库已有脚本正在提交或撤回，稍后可重新检查。", file=sys.stderr)
        return 1
    except (CommitError, OSError, UnicodeError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
