#!/usr/bin/env python3
"""根据 .github/appimage-apps.json 决定本次要构建的 AppImage Job。"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def normalize_search(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def git_ok(args: list[str]) -> bool:
    return subprocess.call(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0


def git_out(args: list[str]) -> str:
    return subprocess.check_output(args, text=True)


def resolve_search(catalog: list[dict], query_raw: str) -> str:
    query = normalize_search(query_raw)
    if not query:
        raise SystemExit(f"模糊输入没有有效字符：{query_raw}")
    if query == "all":
        return "all"
    exact: list[dict] = []
    fuzzy: list[dict] = []
    for app in catalog:
        key_n = normalize_search(app["key"])
        script_n = normalize_search(app["script"])
        dir_n = normalize_search(app["dir"])
        name_n = normalize_search(app["name"])
        if query in (key_n, script_n, dir_n, name_n):
            exact.append(app)
        elif query in key_n or query in script_n or query in dir_n or query in name_n:
            fuzzy.append(app)
    matches = exact or fuzzy
    if len(matches) == 1:
        print(f"模糊输入已匹配：{query_raw} -> {matches[0]['script']}", flush=True)
        return matches[0]["script"]
    if not matches:
        raise SystemExit(f"未找到匹配脚本：{query_raw}")
    print(f"模糊输入匹配到多个脚本：{query_raw}", file=sys.stderr)
    for app in matches:
        print(f"  - {app['script']}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    catalog = json.loads(Path(".github/appimage-apps.json").read_text(encoding="utf-8"))["apps"]
    keys = [app["key"] for app in catalog]
    script_key = {app["script"]: app["key"] for app in catalog}
    dir_key = {app["dir"]: app["key"] for app in catalog}

    event_name = os.environ["EVENT_NAME"]
    selected_script = os.environ.get("SELECTED_SCRIPT") or "all"
    script_search = os.environ.get("SCRIPT_SEARCH") or ""
    release_integrity_repair = (os.environ.get("RELEASE_INTEGRITY_REPAIR") or "").lower() == "true"
    release_integrity_keys = os.environ.get("RELEASE_INTEGRITY_KEYS") or ""
    before_sha = os.environ.get("BEFORE_SHA") or ""
    after_sha = os.environ["AFTER_SHA"]
    build = {key: False for key in keys}

    def select_all() -> None:
        for key in keys:
            build[key] = True

    if release_integrity_repair:
        if event_name != "workflow_dispatch":
            raise SystemExit("Release 完整性自愈只能通过 workflow_dispatch 运行。")
        try:
            repair_keys = json.loads(release_integrity_keys)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"Release 完整性自愈 key 不是有效 JSON：{exc}") from exc
        if not isinstance(repair_keys, list) or not repair_keys:
            raise SystemExit("Release 完整性自愈 key 必须是非空 JSON 数组。")
        if any(not isinstance(key, str) or not key for key in repair_keys):
            raise SystemExit("Release 完整性自愈 key 必须全部是非空字符串。")
        unknown_keys = sorted(set(repair_keys) - set(keys))
        if unknown_keys:
            raise SystemExit("Release 完整性自愈包含未知构建 key：" + ", ".join(unknown_keys))
        for key in dict.fromkeys(repair_keys):
            build[key] = True
    elif event_name == "workflow_dispatch" and script_search.strip():
        selected_script = resolve_search(catalog, script_search)

    if release_integrity_repair:
        pass
    elif event_name == "workflow_dispatch":
        if selected_script == "all":
            select_all()
        elif selected_script in script_key:
            build[script_key[selected_script]] = True
        else:
            selected_script = resolve_search(catalog, selected_script)
            if selected_script == "all":
                select_all()
            else:
                build[script_key[selected_script]] = True
    elif event_name == "push":
        missing_before = (not before_sha or re.fullmatch(r"0+", before_sha)
                          or not git_ok(["git", "cat-file", "-e", f"{before_sha}^{{commit}}"]))
        if missing_before:
            changed = git_out(["git", "show", "--pretty=", "--name-only", after_sha])
        else:
            changed = git_out(["git", "diff", "--name-only", before_sha, after_sha])
        files = [line for line in changed.splitlines() if line]
        if any(path.startswith(".github/actions/build-anylinux/") for path in files):
            select_all()
        else:
            if any(path.startswith("common/linuxdeploy/") for path in files):
                marker = "common/linuxdeploy/normalize_apprun_paths.sh"
                for app in catalog:
                    script_path = Path(app["script"])
                    if script_path.is_file() and marker in script_path.read_text(encoding="utf-8"):
                        build[app["key"]] = True

            for path in files:
                if path == ".github/scripts/ci_build_dingtalk.sh":
                    build["dingtalk"] = True
                elif path == ".github/scripts/ci_build_winpodx.sh":
                    build["winpodx"] = True
                else:
                    top = path.split("/", 1)[0]
                    if top in dir_key:
                        build[dir_key[top]] = True
    elif event_name == "schedule":
        select_all()
    else:
        raise SystemExit(1)

    selected_standard = [app for app in catalog if app.get("kind") == "standard" and build[app["key"]]]
    builds_json = {key: ("true" if build[key] else "false") for key in keys}
    should_build = any(build.values())
    matrix = {
        "include": [
            {
                "name": app["name"],
                "script": app["script"],
                "artifact_dir": app["artifact_dir"],
                "release_name": app["release_name"],
                "software_key": app.get("software_key", ""),
                "timeout_minutes": int(app.get("timeout_minutes", 60)),
                "run_from_root": app.get("run_from_root", "false"),
            }
            for app in selected_standard
        ]
    }

    out = Path(os.environ["GITHUB_OUTPUT"])
    with out.open("a", encoding="utf-8") as fh:
        fh.write(f"builds={json.dumps(builds_json, separators=(',', ':'))}\n")
        fh.write(f"should_build={'true' if should_build else 'false'}\n")
        fh.write(f"standard_count={len(matrix['include'])}\n")
        if matrix["include"]:
            fh.write("matrix<<MATRIX_EOF\n")
            fh.write(json.dumps(matrix, separators=(",", ":")) + "\n")
            fh.write("MATRIX_EOF\n")
        else:
            fh.write("matrix=\n")


if __name__ == "__main__":
    main()
