#!/usr/bin/env python3
"""检查 UTC 当天每日全量构建是否已启动，未启动且未暂停时自动补发一次。"""

from __future__ import annotations

from datetime import datetime, timezone
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urlencode


TARGETS = (
    {
        "key": "appimage",
        "label": "AppImage",
        "workflow": "build.yml",
        "full_dispatch_title": "Build all AppImages",
        "dispatch_input_key": "script_to_build",
        "dispatch_input_value": "all",
    },
    {
        "key": "runimage",
        "label": "RunImage",
        "workflow": "build_runimage.yml",
        "full_dispatch_title": "Build all RunImages",
        "dispatch_input_key": "script_to_build",
        "dispatch_input_value": "all",
    },
    {
        "key": "termux",
        "label": "Termux",
        "workflow": "termux.yml",
        "full_dispatch_title": "Build all Termux tools",
        "dispatch_input_key": "tool",
        "dispatch_input_value": "all",
    },
)

TRANSIENT_ERROR = re.compile(r"HTTP (?:408|429|5\d\d)|unexpected end of JSON input")


def format_cell(value: str) -> str:
    return html.escape(" ".join(value.split())).replace("|", "&#124;")


def run_read_command(args: list[str], label: str) -> str:
    for attempt in range(1, 4):
        result = subprocess.run(args, text=True, capture_output=True)
        if result.returncode == 0:
            return result.stdout
        detail = (result.stderr or result.stdout).strip()
        print(f"{label} 失败（第 {attempt}/3 次，退出码 {result.returncode}）：{detail}", file=sys.stderr)
        if attempt == 3 or not TRANSIENT_ERROR.search(detail):
            raise RuntimeError(f"{label} 失败：{detail or f'退出码 {result.returncode}'}")
        time.sleep(attempt * 2)
    raise RuntimeError(f"{label} 失败。")


def is_daily_paused(target_key: str) -> bool:
    output = run_read_command(
        ["bash", ".github/scripts/daily_build_paused.sh", target_key],
        f"读取 {target_key} 每日构建暂停状态",
    ).strip()
    if output == "true":
        return True
    if output == "false":
        return False
    raise RuntimeError(f"daily_build_paused.sh 返回无效结果：{output!r}")


def list_today_runs(repo: str, workflow: str, today_utc: str) -> list[dict[str, object]]:
    query = urlencode({"branch": "main", "created": f">={today_utc}", "per_page": "100"})
    endpoint = f"repos/{repo}/actions/workflows/{workflow}/runs?{query}"
    raw = run_read_command(
        ["gh", "api", "--paginate", "--slurp", "-H", "Cache-Control: no-cache", endpoint],
        f"查询 {workflow} 当日运行记录",
    )
    pages = json.loads(raw)
    return [run for page in pages for run in page.get("workflow_runs", [])]


def find_today_daily_runs(
    runs: list[dict[str, object]],
    full_dispatch_title: str,
    day_start: str,
) -> list[dict[str, object]]:
    matched: list[dict[str, object]] = []
    for run in runs:
        created_at = run.get("created_at")
        if not isinstance(created_at, str) or created_at < day_start:
            continue
        event = run.get("event")
        if event == "schedule":
            matched.append(run)
        elif event == "workflow_dispatch" and run.get("display_title") == full_dispatch_title:
            matched.append(run)
    return matched


def dispatch_full_build(repo: str, target: dict[str, str]) -> None:
    endpoint = f"repos/{repo}/actions/workflows/{target['workflow']}/dispatches"
    result = subprocess.run(
        [
            "gh", "api", "--method", "POST", endpoint,
            "-f", "ref=main",
            "-f", f"inputs[{target['dispatch_input_key']}]={target['dispatch_input_value']}",
        ],
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"补发 {target['workflow']} 失败：{detail or f'退出码 {result.returncode}'}")


def write_summary(today_utc: str, dry_run: bool, rows: list[tuple[str, str, str, str]]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    mode_note = "仅检查（dry-run）" if dry_run else "自动补发模式"
    lines = [
        f"### 每日构建巡检汇总（UTC {today_utc}，{mode_note}）",
        "",
        "| 类型 | 工作流 | 结果 | 详情 |",
        "| --- | --- | --- | --- |",
    ]
    for label, workflow, status, detail in rows:
        lines.append(f"| {format_cell(label)} | `{workflow}` | {format_cell(status)} | {detail} |")
    with Path(summary_path).open("a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def main() -> int:
    repo = os.environ["GITHUB_REPOSITORY"]
    selected = (os.environ.get("CHECK_TARGET") or "all").strip()
    dry_run_raw = (os.environ.get("DRY_RUN") or "false").strip().lower()
    if dry_run_raw not in {"true", "false"}:
        raise SystemExit(f"DRY_RUN 参数无效：{dry_run_raw!r}")
    dry_run = dry_run_raw == "true"

    valid_keys = {target["key"] for target in TARGETS}
    if selected != "all" and selected not in valid_keys:
        raise SystemExit(f"CHECK_TARGET 参数无效：{selected!r}")

    today_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    day_start = f"{today_utc}T00:00:00Z"
    active_targets = [target for target in TARGETS if selected == "all" or target["key"] == selected]

    rows: list[tuple[str, str, str, str]] = []
    had_error = False

    for target in active_targets:
        label = target["label"]
        workflow = target["workflow"]
        try:
            if is_daily_paused(target["key"]):
                print(f"[{label}] 每日构建已暂停，跳过。")
                rows.append((label, workflow, "已暂停（跳过）", "Daily Build State 当前为关闭状态"))
                continue

            runs = list_today_runs(repo, workflow, today_utc)
            matched = find_today_daily_runs(runs, target["full_dispatch_title"], day_start)
            if matched:
                latest = matched[0]
                run_number = latest.get("run_number", "?")
                event = latest.get("event", "unknown")
                status = latest.get("status", "unknown")
                conclusion = latest.get("conclusion")
                state_text = f"{status}/{conclusion}" if conclusion else str(status)
                html_url = latest.get("html_url")
                print(f"[{label}] UTC {today_utc} 已有全量记录：#{run_number} ({event}, {state_text})，跳过。")
                if isinstance(html_url, str) and html_url.startswith("https://"):
                    detail = f"已有 [#{run_number}]({html_url})（`{event}`，{format_cell(state_text)}）"
                else:
                    detail = f"已有 #{run_number}（`{event}`，{format_cell(state_text)}）"
                rows.append((label, workflow, "当日已启动（跳过）", detail))
                continue

            if dry_run:
                print(f"[{label}] UTC {today_utc} 未发现每日全量构建（dry-run 不补发）。")
                rows.append((label, workflow, "当日未启动（仅检查）", "dry-run 开启，未执行补发"))
                continue

            dispatch_full_build(repo, target)
            print(f"[{label}] UTC {today_utc} 未发现每日全量构建，已补发 workflow_dispatch（all）。")
            rows.append((label, workflow, "已补发全量构建", f"触发 `workflow_dispatch`（`{target['dispatch_input_key']}=all`）"))
        except Exception as error:
            had_error = True
            message = str(error)
            print(f"[{label}] 检查或补发异常：{message}", file=sys.stderr)
            rows.append((label, workflow, "检查失败", format_cell(message)))

    write_summary(today_utc, dry_run, rows)
    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
