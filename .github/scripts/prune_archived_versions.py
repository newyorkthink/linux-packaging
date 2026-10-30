#!/usr/bin/env python3
"""只清理明确归档、停用且已无正式资产的软件版本记录。"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path, PurePosixPath


def unique_object(pairs: list[tuple]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON 存在重复键：{key}")
        result[key] = value
    return result


def read_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    except (OSError, ValueError) as exc:
        raise SystemExit(f"无法读取有效的 {path}：{exc}") from exc


def mentions(text: str, value: str) -> bool:
    return bool(re.search(r"(?<![A-Za-z0-9_./-])" + re.escape(value) + r"(?![A-Za-z0-9_./-])", text))


def plan(args: argparse.Namespace) -> None:
    root = Path.cwd()
    manifest = read_json(args.manifest)
    catalog = read_json(root / ".github/appimage-apps.json")
    archived = read_json(root / "archive/appimage-apps.json")
    pages = read_json(args.assets)
    if not isinstance(manifest, dict):
        raise SystemExit("software_versions.json 必须是 JSON 对象。")
    for label, data in (("活动构建清单", catalog), ("归档映射", archived)):
        if not isinstance(data, dict) or not isinstance(data.get("apps"), list):
            raise SystemExit(f"{label}必须包含 apps 数组。")
        if not all(isinstance(row, dict) for row in data["apps"]):
            raise SystemExit(f"{label}包含无效条目。")
    for app in catalog["apps"]:
        for field in ("software_key", "release_name", "dir", "script"):
            if field in app and not isinstance(app[field], str):
                raise SystemExit(f"活动构建清单的 {field} 类型无效，禁止清理。")
        if not app.get("dir") or not app.get("script"):
            raise SystemExit("活动构建清单缺少目录或脚本，禁止清理。")
    if not isinstance(pages, list) or not pages or not all(isinstance(page, list) for page in pages):
        raise SystemExit("Release 资产必须是完整分页数组，禁止用不完整响应判断资产缺失。")
    assets = [asset for page in pages for asset in page]
    if not all(isinstance(asset, dict) and isinstance(asset.get("name"), str) for asset in assets):
        raise SystemExit("Release 资产列表包含无效条目。")
    asset_names = {asset["name"] for asset in assets}
    workflows = list((root / ".github/workflows").glob("*.yml"))
    workflows += list((root / ".github/workflows").glob("*.yaml"))
    if not workflows:
        raise SystemExit("缺少工作流，无法确认构建入口已移除。")
    workflow_text = "\n".join(path.read_text(encoding="utf-8") for path in workflows)
    archive_index = (root / "archive/README.md").read_text(encoding="utf-8")
    by_asset = {}
    for row in archived["apps"]:
        directory, script, asset = (row.get(field) for field in ("dir", "script", "release_name"))
        if not isinstance(directory, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", directory):
            raise SystemExit("归档目录名无效。")
        if not isinstance(script, str) or not isinstance(asset, str):
            raise SystemExit("归档脚本和固定资产名必须是字符串。")
        parts = PurePosixPath(script).parts
        if len(parts) < 2 or parts[0] != directory or ".." in parts or not script.endswith(".sh"):
            raise SystemExit(f"归档脚本路径无效：{script}")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*[.]AppImage", asset):
            raise SystemExit(f"归档资产必须使用精确的 AppImage 文件名：{asset}")
        if asset in by_asset:
            raise SystemExit(f"归档映射的资产名重复：{asset}")
        by_asset[asset] = row

    result = dict(manifest)
    removed, retained = [], []
    for key, entry in manifest.items():
        asset = entry.get("asset") if isinstance(entry, dict) else None
        row = by_asset.get(asset) if isinstance(asset, str) else None
        if row is None:
            continue
        directory, script = row["dir"], row["script"]
        archived_dir = root / "archive" / directory
        archived_script = root / "archive" / script
        reasons = []
        if (
            not (archived_dir / "README.md").is_file()
            or not archived_script.is_file()
            or not archived_script.resolve().is_relative_to(root / "archive")
            or f"(./{directory}/README.md)" not in archive_index
        ):
            reasons.append("归档目录、脚本或归档登记不完整")
        if (root / directory).exists() or (root / directory).is_symlink():
            reasons.append("原应用目录仍存在")
        for app in catalog["apps"]:
            if (
                app.get("software_key") == key
                or app.get("release_name") == asset
                or app.get("dir") == directory
                or app.get("script") == script
            ):
                reasons.append("活动构建清单仍有对应入口")
                break
        if any(mentions(workflow_text, value) for value in (key, asset, script, f"archive/{script}")):
            reasons.append("工作流仍引用对应软件键、资产或脚本")
        if asset in asset_names:
            reasons.append("latest Release 仍有对应资产")
        if reasons:
            retained.append({"software_key": key, "asset": asset, "reason": "；".join(reasons)})
            continue
        del result[key]
        removed.append({"software_key": key, "asset": asset})

    # 删除集合必须完全等于批准清理的归档条目，其余记录逐项原样保留。
    removed_keys = {row["software_key"] for row in removed}
    if set(manifest) - set(result) != removed_keys or any(result[key] != manifest[key] for key in result):
        raise SystemExit("清理结果超出归档范围，禁止写入。")
    if removed:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    else:
        args.output.write_bytes(args.manifest.read_bytes())
    args.report.write_text(json.dumps({"removed": removed, "retained": retained}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def report(path: Path) -> None:
    data = read_json(path)
    lines = ["## 归档版本条目清理", ""]
    if data["removed"]:
        lines += [f"- 已删除：`{row['software_key']}` / `{row['asset']}`" for row in data["removed"]]
    else:
        lines.append("没有符合条件的归档版本条目，未修改版本清单。")
    for row in data["retained"]:
        lines.append(f"- 保留：`{row['software_key']}` / `{row['asset']}`：{row['reason']}。")
    text = "\n".join(lines) + "\n"
    print(text, end="")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    planner = subparsers.add_parser("plan")
    for name in ("manifest", "assets", "output", "report"):
        planner.add_argument(f"--{name}", type=Path, required=True)
    reporter = subparsers.add_parser("report")
    reporter.add_argument("path", type=Path)
    args = parser.parse_args()
    if args.command == "plan":
        plan(args)
    else:
        report(args.path)


if __name__ == "__main__":
    main()
