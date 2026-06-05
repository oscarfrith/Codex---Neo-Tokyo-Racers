#!/usr/bin/env python3
"""
Import a Neo Tokyo Racers full Roblox Studio snapshot export.

Usage:
    python scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt

The Studio exporter creates chunked StringValues in:
    ReplicatedStorage.NTR_STUDIO_FULL_EXPORT_V2

Copy the chunk values into one text file in order. This importer writes:
    roblox/exported_scripts/
    roblox/studio_snapshot/hierarchy.json
    roblox/studio_snapshot/hierarchy.md
    roblox/studio_snapshot/source_manifest.json
    roblox/studio_snapshot/checksums.json
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCRIPTS_DIR = REPO_ROOT / "roblox" / "exported_scripts"
DEFAULT_SNAPSHOT_DIR = REPO_ROOT / "roblox" / "studio_snapshot"
EXPORT_START = "NTR_STUDIO_FULL_EXPORT_V2"
EXPORT_END = "NTR_STUDIO_FULL_EXPORT_END"


@dataclass
class ExportedScript:
    script_id: str
    name: str
    roblox_path: str
    path_parts: list[str]
    class_name: str
    disabled: bool
    attributes: dict[str, Any]
    source_lines: int
    source_bytes: int
    source_checksum: str
    source: str


def sanitize_component(component: str) -> str:
    component = component.strip()
    component = re.sub(r'[<>:"/\\|?*\x00-\x1F]', "_", component)
    component = component.rstrip(". ")
    return component or "_"


def extension_for(class_name: str) -> str:
    if class_name == "ModuleScript":
        return ".module.lua"
    if class_name == "LocalScript":
        return ".client.lua"
    if class_name == "Script":
        return ".server.lua"
    return ".lua"


def read_payload(input_path: Path) -> dict[str, Any]:
    text = input_path.read_text(encoding="utf-8")
    start = text.find(EXPORT_START)
    if start < 0:
        raise ValueError(f"Input does not contain {EXPORT_START}.")

    start += len(EXPORT_START)
    end = text.find(EXPORT_END, start)
    if end < 0:
        json_text = text[start:]
    else:
        json_text = text[start:end]

    json_text = json_text.strip()
    if not json_text:
        raise ValueError("Export marker was found, but no JSON payload followed it.")

    payload = json.loads(json_text)
    if payload.get("format") != EXPORT_START:
        raise ValueError(f"Unexpected export format: {payload.get('format')!r}")
    return payload


def decode_scripts(payload: dict[str, Any]) -> list[ExportedScript]:
    scripts: list[ExportedScript] = []
    for item in payload.get("scripts", []):
        source_b64 = item.get("source_base64", "")
        try:
            source = base64.b64decode(source_b64.encode("ascii"), validate=False).decode("utf-8")
        except Exception as exc:  # noqa: BLE001 - command-line importer should explain the path that failed.
            path = item.get("path", "<unknown>")
            raise ValueError(f"Could not decode source for {path}: {exc}") from exc

        path_parts = item.get("path_parts") or str(item.get("path", "Unknown.UnknownScript")).split(".")
        scripts.append(
            ExportedScript(
                script_id=str(item.get("id", "")),
                name=str(item.get("name", path_parts[-1] if path_parts else "UnknownScript")),
                roblox_path=str(item.get("path", ".".join(path_parts))),
                path_parts=[str(part) for part in path_parts],
                class_name=str(item.get("class_name", "Script")),
                disabled=bool(item.get("disabled", False)),
                attributes=dict(item.get("attributes", {})),
                source_lines=int(item.get("source_lines", 0)),
                source_bytes=int(item.get("source_bytes", 0)),
                source_checksum=str(item.get("source_checksum", "")),
                source=source,
            )
        )
    return scripts


def path_for_script(output_dir: Path, script: ExportedScript) -> Path:
    parts = [sanitize_component(part) for part in script.path_parts]
    if not parts:
        parts = [sanitize_component(script.name or "UnknownScript")]
    file_name = parts[-1] + extension_for(script.class_name)
    return output_dir.joinpath(*parts[:-1], file_name)


def reset_output_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def write_scripts(scripts: list[ExportedScript], scripts_dir: Path) -> list[dict[str, Any]]:
    reset_output_dir(scripts_dir)
    manifest: list[dict[str, Any]] = []
    written_paths: set[Path] = set()

    for script in scripts:
        target_path = path_for_script(scripts_dir, script)
        original_target_path = target_path
        collision_index = 2
        while target_path in written_paths:
            target_path = original_target_path.with_name(
                original_target_path.stem + f"__{collision_index}" + original_target_path.suffix
            )
            collision_index += 1

        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(script.source, encoding="utf-8", newline="\n")
        written_paths.add(target_path)

        manifest.append(
            {
                "id": script.script_id,
                "roblox_path": script.roblox_path,
                "path_parts": script.path_parts,
                "class_name": script.class_name,
                "disabled": script.disabled,
                "attributes": script.attributes,
                "source_lines": script.source_lines,
                "source_bytes": script.source_bytes,
                "source_checksum": script.source_checksum,
                "file": str(target_path.relative_to(REPO_ROOT)).replace("\\", "/"),
            }
        )

    (scripts_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    manifest_md = [
        "# Exported Roblox Scripts",
        "",
        "Generated from the Roblox Studio full snapshot export.",
        "",
        "These files are a GitHub-readable mirror of Studio scripts. Treat Studio as live until a Rojo/source-sync migration is explicitly completed.",
        "",
        f"Script count: {len(manifest)}",
        "",
    ]
    for item in manifest:
        state = "disabled" if item["disabled"] else "enabled/module"
        manifest_md.append(f"- `{item['roblox_path']}` ({item['class_name']}, {state}) -> `{item['file']}`")

    (scripts_dir / "MANIFEST.md").write_text("\n".join(manifest_md) + "\n", encoding="utf-8")
    return manifest


def hierarchy_without_sources(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "format": payload.get("format"),
        "generated_in_studio": payload.get("generated_in_studio"),
        "place_id": payload.get("place_id"),
        "job_id": payload.get("job_id"),
        "include_disabled_scripts": payload.get("include_disabled_scripts"),
        "include_test_wip_assets": payload.get("include_test_wip_assets"),
        "services_scanned": payload.get("services_scanned", []),
        "script_count": payload.get("script_count"),
        "skipped_count": payload.get("skipped_count"),
        "hierarchy": payload.get("hierarchy", []),
        "skipped": payload.get("skipped", []),
    }


def walk_nodes(nodes: list[dict[str, Any]], depth: int = 0) -> list[str]:
    lines: list[str] = []
    for node in nodes:
        indent = "  " * depth
        class_name = node.get("class_name", "Instance")
        name = node.get("name", "<unnamed>")
        extras: list[str] = []
        if node.get("script_id"):
            extras.append(str(node["script_id"]))
        if node.get("disabled") is True:
            extras.append("Disabled")
        if node.get("source_lines") is not None:
            extras.append(f"{node.get('source_lines')} lines")
        if node.get("attributes"):
            extras.append(f"{len(node.get('attributes', {}))} attrs")
        suffix = f" [{', '.join(extras)}]" if extras else ""
        lines.append(f"{indent}- {name} ({class_name}){suffix}")
        children = node.get("children") or []
        lines.extend(walk_nodes(children, depth + 1))
    return lines


def write_snapshot(payload: dict[str, Any], manifest: list[dict[str, Any]], snapshot_dir: Path) -> None:
    reset_output_dir(snapshot_dir)
    hierarchy = hierarchy_without_sources(payload)
    (snapshot_dir / "hierarchy.json").write_text(json.dumps(hierarchy, indent=2), encoding="utf-8")
    (snapshot_dir / "source_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    checksums = {
        item["roblox_path"]: {
            "file": item["file"],
            "class_name": item["class_name"],
            "disabled": item["disabled"],
            "source_lines": item["source_lines"],
            "source_bytes": item["source_bytes"],
            "source_checksum": item["source_checksum"],
        }
        for item in manifest
    }
    (snapshot_dir / "checksums.json").write_text(json.dumps(checksums, indent=2), encoding="utf-8")

    hierarchy_md = [
        "# Roblox Studio Hierarchy Snapshot",
        "",
        f"Generated in Studio: {payload.get('generated_in_studio', 'unknown')}",
        f"Scripts exported: {len(manifest)}",
        f"Services scanned: {', '.join(payload.get('services_scanned', []))}",
        "",
        "## Hierarchy",
        "",
    ]
    hierarchy_md.extend(walk_nodes(payload.get("hierarchy", [])))

    skipped = payload.get("skipped") or []
    hierarchy_md.extend(["", "## Skipped", ""])
    if skipped:
        for item in skipped:
            hierarchy_md.append(f"- `{item.get('path', '<unknown>')}` - {item.get('reason', 'skipped')}")
    else:
        hierarchy_md.append("None")

    (snapshot_dir / "hierarchy.md").write_text("\n".join(hierarchy_md) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Neo Tokyo Racers full Studio snapshot export.")
    parser.add_argument("input", help="Path to pasted Studio export text.")
    parser.add_argument("--scripts-output", default=str(DEFAULT_SCRIPTS_DIR), help="Output folder for exported .lua files.")
    parser.add_argument("--snapshot-output", default=str(DEFAULT_SNAPSHOT_DIR), help="Output folder for hierarchy and checksum files.")
    args = parser.parse_args()

    input_path = Path(args.input)
    scripts_dir = Path(args.scripts_output)
    snapshot_dir = Path(args.snapshot_output)
    if not scripts_dir.is_absolute():
        scripts_dir = REPO_ROOT / scripts_dir
    if not snapshot_dir.is_absolute():
        snapshot_dir = REPO_ROOT / snapshot_dir

    payload = read_payload(input_path)
    scripts = decode_scripts(payload)
    manifest = write_scripts(scripts, scripts_dir)
    write_snapshot(payload, manifest, snapshot_dir)

    print(f"Imported {len(scripts)} scripts into {scripts_dir}")
    print(f"Wrote hierarchy snapshot to {snapshot_dir / 'hierarchy.json'}")
    print(f"Wrote readable hierarchy to {snapshot_dir / 'hierarchy.md'}")
    print(f"Wrote checksums to {snapshot_dir / 'checksums.json'}")


if __name__ == "__main__":
    main()
