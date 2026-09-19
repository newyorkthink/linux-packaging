#!/usr/bin/env python3
"""监督 latest Release 中 software_versions.json 与正式资产 digest 的一致性。"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path


SHA256_RE = re.compile(r"[0-9a-fA-F]{64}")


def read_json(path: Path, label: str) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"无法读取有效的 {label}：{exc}") from exc


def write_output(name: str, value: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise SystemExit("缺少 GITHUB_OUTPUT。")
    with open(output, "a", encoding="utf-8") as fh:
        fh.write(f"{name}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, required=True)
    args = parser.parse_args()

    manifest = read_json(args.manifest, "software_versions.json")
    asset_pages = read_json(args.assets, "Release Assets 列表")
    catalog_data = read_json(args.catalog, "AppImage 构建清单")

    if not isinstance(manifest, dict):
        raise SystemExit("software_versions.json 必须是 JSON 对象。")
    if not isinstance(asset_pages, list):
        raise SystemExit("Release Assets 列表格式无效。")
    if asset_pages and all(isinstance(page, list) for page in asset_pages):
        assets = [asset for page in asset_pages for asset in page]
    else:
        assets = asset_pages
    if not all(isinstance(asset, dict) for asset in assets):
        raise SystemExit("Release Assets 列表包含无效条目。")
    if not isinstance(catalog_data, dict) or not isinstance(catalog_data.get("apps"), list):
        raise SystemExit("AppImage 构建清单格式无效。")

    assets_by_name: dict[str, list[dict]] = {}
    for asset in assets:
        name = asset.get("name")
        if isinstance(name, str) and name:
            assets_by_name.setdefault(name, []).append(asset)

    catalog_by_software_key: dict[str, list[dict]] = {}
    for app in catalog_data["apps"]:
        if not isinstance(app, dict):
            raise SystemExit("AppImage 构建清单包含无效条目。")
        software_key = app.get("software_key")
        if isinstance(software_key, str) and software_key:
            catalog_by_software_key.setdefault(software_key, []).append(app)

    mismatches: list[dict[str, str]] = []
    repair_keys: list[str] = []
    mapping_errors: list[str] = []

    for software_key, entry in sorted(manifest.items()):
        reasons: list[str] = []
        asset_name = entry.get("asset") if isinstance(entry, dict) else None
        manifest_sha256 = entry.get("sha256") if isinstance(entry, dict) else None

        if not isinstance(entry, dict):
            reasons.append("条目不是 JSON 对象")
        if not isinstance(asset_name, str) or not asset_name:
            reasons.append("asset 为空或类型无效")
        if not isinstance(manifest_sha256, str) or not SHA256_RE.fullmatch(manifest_sha256):
            reasons.append("sha256 不是 64 位十六进制值")

        matching_assets = assets_by_name.get(asset_name, []) if isinstance(asset_name, str) else []
        release_digest = ""
        release_sha256 = ""
        if len(matching_assets) != 1:
            reasons.append(f"同名 Release Asset 数量为 {len(matching_assets)}")
        else:
            digest = matching_assets[0].get("digest")
            release_digest = digest if isinstance(digest, str) else ""
            if not release_digest.startswith("sha256:") or not SHA256_RE.fullmatch(release_digest[7:]):
                reasons.append("Release Asset digest 不是有效的 sha256 digest")
            else:
                release_sha256 = release_digest[7:].lower()

        if (
            isinstance(manifest_sha256, str)
            and SHA256_RE.fullmatch(manifest_sha256)
            and release_sha256
            and manifest_sha256.lower() != release_sha256
        ):
            reasons.append("software_versions.json sha256 与 Release Asset digest 不一致")

        if not reasons:
            continue

        mismatches.append(
            {
                "software_key": software_key,
                "asset": asset_name if isinstance(asset_name, str) else "",
                "manifest_sha256": manifest_sha256 if isinstance(manifest_sha256, str) else "",
                "release_digest": release_digest,
                "reason": "；".join(reasons),
            }
        )

        mappings = catalog_by_software_key.get(software_key, [])
        if len(mappings) != 1:
            mapping_errors.append(
                f"{software_key}: AppImage 构建清单中 software_key 映射数量为 {len(mappings)}"
            )
            continue
        app = mappings[0]
        build_key = app.get("key")
        release_name = app.get("release_name")
        if not isinstance(build_key, str) or not build_key:
            mapping_errors.append(f"{software_key}: 构建 key 为空或类型无效")
            continue
        if not isinstance(release_name, str) or not release_name:
            mapping_errors.append(f"{software_key}: release_name 为空或类型无效")
            continue
        if isinstance(asset_name, str) and asset_name and release_name != asset_name:
            mapping_errors.append(
                f"{software_key}: 清单 asset={asset_name}，构建清单 release_name={release_name}"
            )
            continue
        if build_key not in repair_keys:
            repair_keys.append(build_key)

    has_mismatches = bool(mismatches)
    repairable = has_mismatches and not mapping_errors and bool(repair_keys)
    write_output("has_mismatches", "true" if has_mismatches else "false")
    write_output("repairable", "true" if repairable else "false")
    write_output("repair_keys", json.dumps(repair_keys, ensure_ascii=False, separators=(",", ":")))

    if not has_mismatches:
        print(f"software_versions.json 的 {len(manifest)} 个条目全部与 Release Asset digest 一致。")
    else:
        print("发现以下 Release 完整性异常：")
        for mismatch in mismatches:
            print(
                f"- {mismatch['software_key']} / {mismatch['asset']}: "
                f"{mismatch['reason']}；清单={mismatch['manifest_sha256'] or '<无>'}；"
                f"Release={mismatch['release_digest'] or '<无>'}"
            )
        if mapping_errors:
            print("以下异常无法安全映射到唯一构建：")
            for error in mapping_errors:
                print(f"- {error}")
        else:
            print("需要重新构建：" + ", ".join(repair_keys))

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write("## Release 完整性监督\n\n")
            if not has_mismatches:
                fh.write(f"`software_versions.json` 的 {len(manifest)} 个条目全部一致。\n")
            else:
                fh.write("| software_key | asset | 原因 |\n")
                fh.write("|---|---|---|\n")
                for mismatch in mismatches:
                    fh.write(
                        f"| `{mismatch['software_key']}` | `{mismatch['asset'] or '<无>'}` | "
                        f"{mismatch['reason']} |\n"
                    )
                if mapping_errors:
                    fh.write("\n无法安全自愈：\n\n")
                    for error in mapping_errors:
                        fh.write(f"- {error}\n")
                else:
                    fh.write("\n对应构建：`" + "`, `".join(repair_keys) + "`\n")


if __name__ == "__main__":
    main()
