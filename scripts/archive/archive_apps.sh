#!/usr/bin/env bash

set -Eeuo pipefail

# 定位脚本所属仓库，不使用个人目录或当前终端目录。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 用标准输入传递程序，预览阶段不创建文件、不查询远端。
python3 -B - "$SCRIPT_DIR/../.." "$@" <<'PY'
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import uuid


class ArchiveError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ArchiveError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "数据存在重复键，停止处理。")
        result[key] = value
    return result


def decode_json(data):
    return json.loads(data, object_pairs_hook=unique_object)


def run(argv, *, data=None, env=None, quiet=False):
    result = subprocess.run(argv, cwd=root, input=data, env=env, capture_output=True)
    require(result.returncode == 0, "命令失败，停止处理：" + " ".join(argv[:3]))
    # 不转发认证、Git remote 或工具环境的原始诊断。
    return result.stdout


def read(path):
    file = root / path
    require(not file.is_symlink() and file.is_file(), "缺少普通文件：" + path)
    return file.read_text(encoding="utf-8")


def json_file(path):
    return decode_json(read(path))


def yaml_file(text):
    return yaml.load(text, Loader=UniqueLoader)


def mentions(text, value):
    return bool(value and re.search(r"(?<![A-Za-z0-9_./-])" + re.escape(value)
                                   + r"(?![A-Za-z0-9_./-])", text))


def moved_link(path, target, new_path):
    if re.match(r"[A-Za-z][A-Za-z0-9+.-]*:", target) or target.startswith(("#", "/")):
        return target
    import posixpath
    file, separator, fragment = target.partition("#")
    absolute = posixpath.normpath(posixpath.join(posixpath.dirname(path), file))
    if path == new_path and absolute.split("/", 1)[0] not in fresh_dirs:
        return target
    if absolute.split("/", 1)[0] in fresh_dirs:
        absolute = "archive/" + absolute
    relative = posixpath.relpath(absolute, posixpath.dirname(new_path) or ".")
    if file.startswith("./") and not relative.startswith("."):
        relative = "./" + relative
    if file.endswith("/") and not relative.endswith("/"):
        relative += "/"
    return relative + ("#" + fragment if separator else "")


def fix_links(text, path, new_path):
    return re.sub(r"(\[[^\]]*\]\()([^)]+)\)",
                  lambda m: m[1] + moved_link(path, m[2], new_path) + ")", text)


def gh_json(endpoint, *options):
    return decode_json(run(["gh", "api", "--hostname", "github.com", endpoint, *options]))


def assets(release_id):
    pages = gh_json(f"repos/{args.repo}/releases/{release_id}/assets?per_page=100",
                    "--paginate", "--slurp")
    require(isinstance(pages, list) and pages and all(isinstance(p, list) for p in pages),
            "Release 附件分页无效。")
    result = [item for page in pages for item in page]
    require(all(isinstance(a, dict) and isinstance(a.get("name"), str) for a in result),
            "Release 附件元数据无效。")
    return result


def public_text(value):
    require(value.strip() and not any(ord(c) < 32 and c != "\n" for c in value),
            "原因或备注为空，或包含控制字符。")
    return value.replace("|", "&#124;").replace("\n", "<br>")


def main():
    global root, args, fresh_dirs, yaml, UniqueLoader
    parser = argparse.ArgumentParser(prog="archive_apps.sh", add_help=False,
        description="统一归档 AppImage 项目；默认只预览，不修改本地文件或 Release。",
        epilog="依赖 Bash、Python 3、PyYAML 和 Git；实际执行还需 gh、jq、timeout、sha256sum，"
               "以及已登录且具有仓库发布写权限的 GitHub 账户。"
               "在仓库的 Linux 终端运行。原因和备注会写入公共文档，只填写可公开内容。"
               "--yes 将移动目录、更新登记、提交并推送 main，再清理指定附件和归档版本条目。"
               "不会安装软件、改系统配置、触发额外构建或等待 Actions。失败后可用同一参数继续清理已归档项目。")
    parser._positionals.title = "应用目录"
    parser._optionals.title = "参数"
    parser.add_argument("--help", "-h", action="help", help="显示参数说明后退出")
    parser.add_argument("--repo", metavar="OWNER/REPO", help="GitHub.com 目标仓库；实际执行时必填")
    parser.add_argument("--reason", default="暂停维护，按需恢复", help="统一停用原因，不包含个人信息")
    parser.add_argument("--note", action="append", default=[], metavar="目录=公开说明",
                        help="可重复指定各项目的已知错误、验证范围或恢复待办；不会自动读取构建日志")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--yes", action="store_true", help="确认执行全部已列明的归档和发布清理操作")
    mode.add_argument("--dry-run", action="store_true", help="只预览，效果与默认模式相同")
    parser.add_argument("apps", nargs="+", metavar="应用目录", help="应用清单中的完整目录名，可填写多个")
    args = parser.parse_args(sys.argv[2:])
    root = Path(sys.argv[1]).resolve()
    require(len(set(args.apps)) == len(args.apps), "应用目录重复。")
    require(all(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", a) for a in args.apps),
            "应用目录必须是单个目录名，不能包含路径或通配符。")
    require(not args.yes or args.repo, "实际执行必须明确填写 --repo OWNER/REPO。")
    if args.repo:
        require(re.fullmatch(r"[A-Za-z0-9-]+/[A-Za-z0-9_.-]+", args.repo)
                and args.repo.split("/")[1] not in (".", ".."), "仓库名格式无效。")
    reason = public_text(args.reason)
    notes = {}
    for item in args.note:
        directory, separator, note = item.partition("=")
        require(separator and directory in args.apps and directory not in notes, "备注目录无效或重复。")
        notes[directory] = public_text(note)
    require(shutil.which("git"), "缺少 Git。")
    require(Path(run(["git", "rev-parse", "--show-toplevel"]).decode().strip()).resolve() == root,
            "脚本必须位于目标仓库的 scripts/archive/ 中。")
    require(not run(["git", "status", "--porcelain", "--untracked-files=all"]).strip(),
            "工作区存在未提交文件，停止处理，不暂存其他改动。")
    try:
        import yaml
    except ImportError:
        raise ArchiveError("缺少 Python PyYAML；请先准备依赖，脚本不会自动安装。")

    class UniqueLoader(yaml.BaseLoader):
        def construct_mapping(self, node, deep=False):
            pairs = [(self.construct_object(k, deep=deep), self.construct_object(v, deep=deep))
                     for k, v in node.value]
            return unique_object(pairs)

    catalog_path = ".github/appimage-apps.json"
    mapping_path = "archive/appimage-apps.json"
    workflow_path = ".github/workflows/build.yml"
    index_path = "archive/README.md"
    catalog, mapping = json_file(catalog_path), json_file(mapping_path)
    require(all(isinstance(x, dict) and isinstance(x.get("apps"), list) for x in (catalog, mapping)),
            "活动清单或归档映射格式无效。")
    selected, fresh = [], []
    for directory in args.apps:
        active = [a for a in catalog["apps"] if a.get("dir") == directory]
        archived = [a for a in mapping["apps"] if a.get("dir") == directory]
        require((len(active), len(archived)) in ((1, 0), (0, 1)), "应用登记缺失、重复或冲突：" + directory)
        app = copy.deepcopy((active or archived)[0])
        script, asset = app.get("script", ""), app.get("release_name", "")
        parts = PurePosixPath(script).parts
        require(len(parts) >= 2 and parts[0] == directory and ".." not in parts
                and script.endswith(".sh"), "应用脚本路径无效：" + directory)
        require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*\.AppImage", asset), "固定资产名无效。")
        require(sum(a.get("release_name") == asset for a in catalog["apps"] + mapping["apps"]) == 1,
                "资产映射不唯一：" + asset)
        require(not (root / directory).is_symlink() and not (root / "archive" / directory).is_symlink(),
                "应用目录不能是符号链接。")
        if active:
            require((root / directory).is_dir() and not (root / "archive" / directory).exists(),
                    "原目录缺失或归档目标已存在：" + directory)
            require(app.get("kind") in ("standard", "special") and isinstance(app.get("key"), str),
                    "应用构建类型或软件键无效。")
            require(not run(["git", "ls-files", "--others", "--ignored", "--exclude-standard", "--", directory]).strip(),
                    "应用目录含被忽略的文件，停止移动：" + directory)
            fresh.append(app)
        else:
            require(not (root / directory).exists() and (root / "archive" / directory / "README.md").is_file(),
                    "现有归档不完整：" + directory)
        require((root / ("" if active else "archive/") / script).is_file(), "构建脚本不存在。")
        selected.append(app)
    fresh_dirs = {a["dir"] for a in fresh}
    changes = {}
    if fresh:
        new_catalog = copy.deepcopy(catalog)
        new_catalog["apps"] = [a for a in catalog["apps"] if a["dir"] not in fresh_dirs]
        new_mapping = copy.deepcopy(mapping)
        new_mapping["apps"] += [{k: a[k] for k in ("dir", "script", "release_name")} for a in fresh]
        new_mapping["apps"].sort(key=lambda a: a["dir"])
        changes[catalog_path] = json.dumps(new_catalog, ensure_ascii=False, indent=2) + "\n"
        changes[mapping_path] = json.dumps(new_mapping, ensure_ascii=False, indent=2) + "\n"

        # 只移除精确匹配的手动选项和专属 Job，其余 YAML 语义必须不变。
        workflow = read(workflow_path)
        expected = copy.deepcopy(yaml_file(workflow))
        options = expected["on"]["workflow_dispatch"]["inputs"]["script_to_build"]["options"]
        for app in fresh:
            line = "          - " + app["script"] + "\n"
            require(options.count(app["script"]) == 1 and workflow.count(line) == 1,
                    "手动选项格式变化，需要先人工核对。")
            options.remove(app["script"])
            workflow = workflow.replace(line, "")
            if app["kind"] == "special":
                jobs = [key for key, job in expected["jobs"].items()
                        if re.search(r"needs\.plan\.outputs\.builds\)\." + re.escape(app["key"]) + r"\b",
                                     str(job.get("if", "")))]
                require(len(jobs) == 1, "无法唯一定位专属 Job：" + app["dir"])
                job = jobs[0]
                pattern = r"(?ms)^  " + re.escape(job) + r":\n.*?(?=^  [A-Za-z_][A-Za-z0-9_-]*:\s*$|\Z)"
                workflow, count = re.subn(pattern, "", workflow)
                require(count == 1, "专属 Job 排版变化，需要先人工核对。")
                del expected["jobs"][job]
                require(not any(mentions(str(j.get("needs", "")), job) for j in expected["jobs"].values()),
                        "其他 Job 仍依赖待归档 Job，停止处理。")
        require(yaml_file(workflow) == expected, "工作流发生非预期变化。")
        require(set(options) == {"all"} | {a["script"] for a in new_catalog["apps"]},
                "手动选项与活动应用清单不一致。")
        changes[workflow_path] = workflow

        # 按现有归档表登记，不删除旧条目或修复历史。
        index = read(index_path)
        match = re.search(r"(?m)^\| 目录 \| 停用日期 \| 原因 \| 替代 \|\n(?:\|[^\n]*\n)+", index)
        require(match is not None, "归档索引表格格式变化。")
        date = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        rows = "".join(f"| [{a['dir']}](./{a['dir']}/README.md) | {date} | {reason} | 无 |\n" for a in fresh)
        index = index[:match.end()] + rows + index[match.end():]
        index = re.sub(r"当前登记[^，。；\n]*个固定资产名", f"当前登记{len(new_mapping['apps'])}个固定资产名", index)
        changes[index_path] = index

        # 移动后修正相对链接，既有正文、脚本、权限和专属配置保留。
        markdown = run(["git", "ls-files", "-z", "--", "*.md"]).decode().split("\0")
        for path in filter(None, markdown):
            if path.startswith("archive/") or (root / path).is_symlink():
                continue
            text = read(path)
            destination = "archive/" + path if path.split("/", 1)[0] in fresh_dirs else path
            if path in ("docs/packaging-classification.md", "docs/upstream-packaging-index.md"):
                names = {str(a.get("name", a["dir"])).casefold() for a in fresh} | {a["dir"].casefold() for a in fresh}
                def keep(line):
                    if not line.startswith("| "):
                        return True
                    first = line.split("|", 2)[1].strip()
                    label = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", first).casefold()
                    return label not in names
                text = "".join(line for line in text.splitlines(keepends=True) if keep(line))
            updated = fix_links(text, path, destination)
            if destination != path or updated != read(path):
                changes[destination] = updated
        for app in fresh:
            directory = app["dir"]
            path = f"archive/{directory}/README.md"
            original = changes.get(path, "")
            require(not (root / directory / "README.md").is_symlink(), "应用 README 不能是符号链接。")
            header = (f"# 已归档\n\n{date} 起暂停维护，从 `{directory}/` 移到 `archive/{directory}/`。"
                      f"停用原因：{reason}；替代：无；后续按需恢复。\n\n"
                      f"归档前构建入口：`{app['script']}`；固定发布附件：`{app['release_name']}`。\n\n"
                      "脚本、配置和既有历史保留，不再参与构建与发布。恢复前先阅读下方记录，"
                      "再按[归档与恢复说明](../README.md#重新启用)恢复原目录、构建登记及活动索引。"
                      "归档不表示原有错误已修复，也不扩大已有验证范围。\n\n")
            if directory in notes:
                header += "## 归档备注\n\n" + notes[directory] + "\n\n"
            if original:
                header += "以下为归档前原有记录；其中的活动路径和发布状态仅作为历史保留。\n\n"
            changes[path] = header + original if original else header.rstrip() + "\n"

        registry = "docs/packaging-export-registry.md"
        if (root / registry).is_file():
            text = changes.get(registry, read(registry))
            note = "已归档项目的 export 记录仅保留为历史依据，启用状态以[归档索引](../archive/README.md)和活动应用清单为准。"
            if note not in text:
                heading, separator, rest = text.partition("\n")
                text = heading + separator + "\n" + note + "\n" + rest
            for app in fresh:
                text = text.replace("当前由 " + app["dir"] + " 显式启用", "归档前由 " + app["dir"] + " 显式启用")
            changes[registry] = text

    # 不认识的工作流引用必须提前停止，不能删掉别的项目来凑归档条件。
    for file in sorted((root / ".github/workflows").glob("*")):
        if file.suffix not in (".yml", ".yaml"):
            continue
        path = file.relative_to(root).as_posix()
        text = changes.get(path, read(path))
        for app in selected:
            tokens = [app["script"], app["release_name"], app.get("key"), app.get("software_key")]
            require(not any(mentions(text, token) for token in tokens), "其他工作流仍引用待归档项目：" + path)
    print("归档计划：" + "、".join(args.apps))
    for app in selected:
        print("- " + ("迁移目录：" if app in fresh else "复查现有归档：") + app["dir"])
        print("- 清理 latest 附件：" + app["release_name"])
    for path in sorted(changes):
        print("- 更新文件：" + path)
    if not args.yes:
        print("仅预览，未写入、提交、推送或访问 Release；确认计划后增加 --repo OWNER/REPO --yes。")
        return

    # 写入前核对仓库、分支、远端、依赖和认证，不安装或修改任何系统配置。
    for command in ("gh", "jq", "bash", "timeout", "sha256sum"):
        require(shutil.which(command), "缺少运行依赖：" + command)
    require(run(["git", "branch", "--show-current"]).decode().strip() == "main", "只允许在 main 执行。")
    origin = run(["git", "remote", "get-url", "origin"]).decode().strip()
    require(origin in (f"https://github.com/{args.repo}.git", f"https://github.com/{args.repo}",
                       f"git@github.com:{args.repo}.git", f"ssh://git@github.com/{args.repo}.git"),
            "origin 与明确指定的 GitHub 仓库不一致。")
    head = run(["git", "rev-parse", "HEAD"]).decode().strip()
    require(run(["git", "ls-remote", "--exit-code", "origin", "refs/heads/main"]).decode().split()[0] == head,
            "本地 main 与远端不一致，请先自行同步。")
    run(["gh", "auth", "status", "--hostname", "github.com"], quiet=True)
    release = gh_json(f"repos/{args.repo}/releases/tags/latest")
    require(release.get("tag_name") == "latest" and type(release.get("id")) is int, "latest Release 无效。")
    helpers = ("scripts/release/delete_asset.sh", ".github/scripts/prune_archived_versions.sh")
    for helper in helpers:
        read(helper)
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        token = run(["gh", "auth", "token", "--hostname", "github.com"], quiet=True).decode().strip()
    require(token, "未取得归档清理所需认证。")
    git_env = os.environ.copy()
    if changes:
        # 提交只使用 GitHub 公开用户名与 noreply 邮箱，不发布本机 Git 身份。
        account = gh_json("user")
        login, account_id = account.get("login", ""), account.get("id")
        require(re.fullmatch(r"[A-Za-z0-9-]+", login) and type(account_id) is int and account_id > 0,
                "无法确认公开提交身份，停止写入。")
        for role in ("AUTHOR", "COMMITTER"):
            git_env[f"GIT_{role}_NAME"] = login
            git_env[f"GIT_{role}_EMAIL"] = f"{account_id}+{login}@users.noreply.github.com"
        for app in fresh:
            (root / app["dir"]).rename(root / "archive" / app["dir"])
        for path, content in changes.items():
            file = root / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(content, encoding="utf-8")
        paths = sorted(set(changes) | fresh_dirs | {"archive/" + a for a in fresh_dirs})
        run(["git", "--literal-pathspecs", "add", "--pathspec-from-file=-", "--pathspec-file-nul"],
            data="".join(path + "\0" for path in paths).encode())
        run(["git", "diff", "--cached", "--check"])
        message = ("归档应用：" + "、".join(a["dir"] for a in fresh) + "\n\n"
                   "- 保留完整目录与历史，移除活动构建和索引登记，更新归档映射。\n"
                   "- 检查：核对清单、工作流语义和唯一资产映射；发布清理使用现有入口。\n")
        run(["git", "commit", "--file=-"], data=message.encode(), env=git_env)
        run(["git", "push", "origin", "HEAD:refs/heads/main"])

    # 附件删除、分页复查和版本写锁均复用现有入口，不另写删除或上传逻辑。
    for app in selected:
        run(["bash", helpers[0], "--repo", args.repo, "--tag", "latest", "--asset", app["release_name"], "--yes"])
    with tempfile.TemporaryDirectory(prefix="archive-apps-") as temporary:
        cleanup_env = dict(os.environ, GH_TOKEN=token, GH_HOST="github.com", GITHUB_REPOSITORY=args.repo,
                           RUNNER_TEMP=temporary, GITHUB_RUN_ID="manual-" + uuid.uuid4().hex,
                           GITHUB_JOB="archive-apps", GITHUB_RUN_ATTEMPT="1")
        cleanup_env.pop("GITHUB_STEP_SUMMARY", None)
        run(["bash", helpers[1]], env=cleanup_env)
    latest = gh_json(f"repos/{args.repo}/releases/tags/latest")
    require(latest.get("id") == release["id"], "操作期间 Release 已变化，无法确认结果。")
    remaining = assets(release["id"])
    names = {app["release_name"] for app in selected}
    require(not names & {asset["name"] for asset in remaining}, "仍有目标附件，归档清理未完成。")
    manifests = [a for a in remaining if a["name"] == "software_versions.json"]
    require(len(manifests) == 1, "版本清单不存在或不唯一。")
    manifest = manifests[0]
    body = run(["gh", "api", "--hostname", "github.com", "-H", "Accept: application/octet-stream",
                f"repos/{args.repo}/releases/assets/{manifest['id']}"])
    require(manifest.get("digest") == "sha256:" + hashlib.sha256(body).hexdigest(), "版本清单摘要不一致。")
    versions = decode_json(body)
    require(isinstance(versions, dict) and not any(isinstance(v, dict) and v.get("asset") in names
                                                for v in versions.values()), "版本清单仍有目标条目。")
    require(not run(["git", "status", "--porcelain", "--untracked-files=all"]).strip(), "归档后工作区不干净。")
    print("归档完成：目录、构建登记、指定附件和版本条目均已核对；未等待 Actions。")


root = None
try:
    main()
except (ArchiveError, OSError, ValueError, KeyError, TypeError) as error:
    print("错误：" + str(error) + "\n未确认归档完成；不自动重试、回滚或扩大操作范围。", file=sys.stderr)
    sys.exit(1)
PY
