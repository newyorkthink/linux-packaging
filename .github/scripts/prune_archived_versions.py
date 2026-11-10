#!/usr/bin/env python3
"""清理已被新名称接替或已确认归档的软件版本记录。"""

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


def prune_superseded_keys(
    manifest: dict, catalog: dict, assets: list[dict], only_key: str | None = None
) -> tuple[dict, list[dict[str, str]]]:
    """只清理已由唯一活动记录和正式资产共同确认接替的旧版本键。"""
    if not isinstance(manifest, dict):
        raise SystemExit("software_versions.json 必须是 JSON 对象。")
    if not isinstance(catalog, dict) or not isinstance(catalog.get("apps"), list):
        raise SystemExit("活动构建清单必须包含 apps 数组。")
    if not isinstance(assets, list) or not all(isinstance(asset, dict) for asset in assets):
        raise SystemExit("Release 资产列表格式无效，禁止清理旧版本键。")

    by_key: dict[str, list[dict]] = {}
    by_asset: dict[str, list[dict]] = {}
    for app in catalog["apps"]:
        if not isinstance(app, dict):
            raise SystemExit("活动构建清单包含无效条目。")
        key, asset = app.get("software_key"), app.get("release_name")
        if not isinstance(key, str) or not key or not isinstance(asset, str) or not asset:
            raise SystemExit("活动构建清单缺少有效的软件键或正式资产名，禁止清理。")
        by_key.setdefault(key, []).append(app)
        by_asset.setdefault(asset, []).append(app)

    assets_by_name: dict[str, list[dict]] = {}
    for asset in assets:
        name = asset.get("name")
        if isinstance(name, str):
            assets_by_name.setdefault(name, []).append(asset)

    result = dict(manifest)
    removed: list[dict[str, str]] = []
    for old_key, entry in manifest.items():
        # 活动软件键始终保留，不能把仍在使用的记录当作旧名称删除。
        if old_key in by_key or not isinstance(entry, dict):
            continue
        asset_name = entry.get("asset")
        if not isinstance(asset_name, str):
            continue
        owners = by_asset.get(asset_name, [])
        if len(owners) != 1:
            continue
        new_key = owners[0]["software_key"]
        if len(by_key[new_key]) != 1 or (only_key is not None and new_key != only_key):
            continue

        # 新名称必须已有完整版本记录，且恰好对应一个已上传的正式资产。
        replacement = manifest.get(new_key)
        matching_assets = assets_by_name.get(asset_name, [])
        if not isinstance(replacement, dict) or len(matching_assets) != 1:
            continue
        version, sha256 = replacement.get("version"), replacement.get("sha256")
        release_asset = matching_assets[0]
        digest = release_asset.get("digest")
        if (
            replacement.get("asset") != asset_name
            or not isinstance(version, str)
            or not version.strip()
            or not isinstance(sha256, str)
            or not re.fullmatch(r"[0-9a-fA-F]{64}", sha256)
            or release_asset.get("state") != "uploaded"
            or not isinstance(digest, str)
            or digest.lower() != f"sha256:{sha256.lower()}"
        ):
            continue

        # 只移除与已确认新记录指向同一正式资产、且已无活动入口的旧键。
        del result[old_key]
        removed.append({"software_key": old_key, "asset": asset_name, "replacement_key": new_key})
    return result, removed


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

    result, removed = prune_superseded_keys(manifest, catalog, assets)
    retained = []
    for key, entry in manifest.items():
        if key not in result:
            continue
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

    # 删除集合必须恰好等于已确认的旧名称和归档条目，其余记录逐项原样保留。
    removed_keys = {row["software_key"] for row in removed}
    if set(manifest) - set(result) != removed_keys or any(result[key] != manifest[key] for key in result):
        raise SystemExit("清理结果超出已确认范围，禁止写入。")
    if removed:
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    else:
        args.output.write_bytes(args.manifest.read_bytes())
    args.report.write_text(json.dumps({"removed": removed, "retained": retained}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def report(path: Path) -> None:
    data = read_json(path)
    lines = ["## 软件版本条目清理", ""]
    if data["removed"]:
        for row in data["removed"]:
            if "replacement_key" in row:
                lines.append(
                    f"- 已移除旧键：`{row['software_key']}`；"
                    f"已由 `{row['replacement_key']}` / `{row['asset']}` 接替。"
                )
            else:
                lines.append(f"- 已删除归档条目：`{row['software_key']}` / `{row['asset']}`")
    else:
        lines.append("没有符合条件的旧名称或归档条目，未修改版本清单。")
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
