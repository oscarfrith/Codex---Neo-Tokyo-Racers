#!/usr/bin/env python3
"""
Import a Roblox full Roblox Studio snapshot export.

Usage:
    python scripts/import_studio_snapshot.py docs/studio-full-export-paste.txt

The receiver imports HTTP chunks directly. No Studio dump instances are created.
An explicitly saved text export can also be imported. Outputs:
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
import hashlib
import uuid
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCRIPTS_DIR = REPO_ROOT / "roblox" / "exported_scripts"
DEFAULT_SNAPSHOT_DIR = REPO_ROOT / "roblox" / "studio_snapshot"
EXPORT_START = "STUDIO_SNAPSHOT_V1"
EXPORT_END = "STUDIO_SNAPSHOT_END"


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
    return parse_payload(text)


def parse_payload(text: str) -> dict[str, Any]:
    start = text.find(EXPORT_START)
    if start < 0:
        raise ValueError(f"Input does not contain {EXPORT_START}.")

    start += len(EXPORT_START)
    end = text.find(EXPORT_END, start)
    if end < 0:
        raise ValueError("Incomplete export: missing end marker")
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
            source = base64.b64decode(source_b64.encode("ascii"), validate=True).decode("utf-8")
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


def validate_payload(payload: dict[str, Any]) -> list[ExportedScript]:
    """Reject incomplete/ambiguous sources before touching the current mirror."""
    if payload.get("format") != EXPORT_START or payload.get("place_id") not in (121304917315753, 71491191583884):
        raise ValueError("BLOCKER: wrong format/place; expected Space Racers v2 (or historical v1)")
    expected = {'ReplicatedFirst', 'ReplicatedStorage', 'ServerScriptService', 'ServerStorage', 'StarterPlayer', 'StarterGui', 'Workspace', 'Lighting', 'SoundService'}
    if set(payload.get('services_scanned', [])) != expected or {n.get('name') for n in payload.get('hierarchy', [])} != expected:
        raise ValueError("BLOCKER: incomplete service coverage")
    if payload.get('include_disabled_scripts') is not True:
        raise ValueError("BLOCKER: disabled scripts must be included")
    scripts = decode_scripts(payload)
    if not scripts or len(scripts) != payload.get("script_count"):
        raise ValueError("BLOCKER: missing sources or script count mismatch")
    paths, files, ids = set(), set(), set()
    for script in scripts:
        raw = script.source.encode("utf-8")
        checksum = str(sum(i * b for i, b in enumerate(raw, 1)) % 1000000007)
        lines = script.source.count("\n") + 1 if script.source else 0
        if (len(raw), checksum, lines) != (script.source_bytes, script.source_checksum, script.source_lines):
            raise ValueError(f"BLOCKER: source integrity mismatch: {script.roblox_path}")
        file_key = str(path_for_script(Path('.'), script)).casefold()
        if script.roblox_path in paths or file_key in files or script.script_id in ids:
            raise ValueError(f"BLOCKER: ambiguous source path/id: {script.roblox_path}")
        if not script.path_parts or script.roblox_path != '.'.join(script.path_parts):
            raise ValueError(f"BLOCKER: inconsistent path: {script.roblox_path}")
        if script.class_name not in {"Script", "LocalScript", "ModuleScript"}:
            raise ValueError("BLOCKER: unsupported script class")
        paths.add(script.roblox_path); files.add(file_key); ids.add(script.script_id)
    nodes = list(payload.get("hierarchy", []))
    source_nodes = {}
    while nodes:
        node = nodes.pop()
        nodes.extend(node.get("children", []))
        if node.get("script_id"):
            if node["script_id"] in source_nodes:
                raise ValueError("BLOCKER: duplicate hierarchy script id")
            source_nodes[node["script_id"]] = node
    for script in scripts:
        node = source_nodes.get(script.script_id, {})
        if (node.get("path"), node.get("source_checksum"), node.get("class_name"), node.get("disabled")) != (script.roblox_path, script.source_checksum, script.class_name, script.disabled):
            raise ValueError(f"BLOCKER: hierarchy/source mismatch: {script.roblox_path}")
    if len(source_nodes) != len(scripts):
        raise ValueError("BLOCKER: hierarchy contains unmatched sources")
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


def write_scripts(scripts: list[ExportedScript], scripts_dir: Path, logical_dir: Path | None = None) -> list[dict[str, Any]]:
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
                "source_sha256": hashlib.sha256(script.source.encode("utf-8")).hexdigest(),
                "file": str((path_for_script(logical_dir, script) if logical_dir else target_path).relative_to(REPO_ROOT)).replace("\\", "/"),
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
        "schema_revision": payload.get("schema_revision", 2),
        "property_schema": payload.get("property_schema", {}),
        "diagnostics": payload.get("diagnostics", {}),
        "export_mode": payload.get("export_mode", "unknown"),
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


def write_hierarchy_json(path: Path, value: dict[str, Any]) -> None:
    """Keep tree layout readable, but write typed attributes/properties on one line.

    Deep indentation of each scalar made the same snapshot exceed 100 MB.
    This preserves every value and gives stable key ordering without a giant one-line blob.
    """
    def emit(item, depth=0, compact=False):
        if compact or not isinstance(item, (dict, list)) or not item:
            yield json.dumps(item, sort_keys=True, ensure_ascii=True, separators=(',', ':'))
        elif isinstance(item, dict):
            yield '{\n'
            keys = sorted(item)
            for index, key in enumerate(keys):
                yield '  ' * (depth + 1) + json.dumps(key) + ': '
                yield from emit(item[key], depth + 1, key in {'attributes', 'properties'})
                yield ',\n' if index < len(keys) - 1 else '\n'
            yield '  ' * depth + '}'
        else:
            yield '[\n'
            for index, child in enumerate(item):
                yield '  ' * (depth + 1)
                yield from emit(child, depth + 1)
                yield ',\n' if index < len(item) - 1 else '\n'
            yield '  ' * depth + ']'
    with path.open('w', encoding='utf-8', newline='\n') as handle:
        handle.writelines(emit(value))
        handle.write('\n')


def write_snapshot(payload: dict[str, Any], manifest: list[dict[str, Any]], snapshot_dir: Path) -> None:
    reset_output_dir(snapshot_dir)
    hierarchy = hierarchy_without_sources(payload)
    write_hierarchy_json(snapshot_dir / "hierarchy.json", hierarchy)
    (snapshot_dir / "source_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    checksums = {
        item["roblox_path"]: {
            "file": item["file"],
            "class_name": item["class_name"],
            "disabled": item["disabled"],
            "source_lines": item["source_lines"],
            "source_bytes": item["source_bytes"],
            "source_checksum": item["source_checksum"],
            "source_sha256": item["source_sha256"],
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


def rename_with_retry(source: Path, target: Path) -> None:
    """Bound transient Windows sharing/access locks; preserve rollback on failure."""
    for attempt in range(21):
        try:
            source.rename(target)
            return
        except OSError as error:
            if getattr(error, 'winerror', None) not in (5, 32, 33) or attempt == 20:
                raise
            time.sleep(0.25)


def import_payload(payload: dict[str, Any], scripts_dir: Path = DEFAULT_SCRIPTS_DIR,
                   snapshot_dir: Path = DEFAULT_SNAPSHOT_DIR) -> list[dict[str, Any]]:
    scripts = validate_payload(payload)
    roots = [scripts_dir.resolve(), snapshot_dir.resolve()]
    repo = REPO_ROOT.resolve()
    for root in roots:
        if not root.is_relative_to(repo) or root == repo or root.parent == repo:
            raise ValueError("BLOCKER: output must be a nested directory inside this repo")
        if any(part in {'.git', '.agents', '.codex'} for part in root.relative_to(repo).parts):
            raise ValueError("BLOCKER: protected output path")
    if roots[0].is_relative_to(roots[1]) or roots[1].is_relative_to(roots[0]):
        raise ValueError("BLOCKER: mirror outputs overlap")
    # Stage beside the repo outputs, then swap both with rollback on ordinary I/O failure.
    # Not power-loss atomic: retain .mirror-stage-* if the process is interrupted mid-swap.
    # These candidates become user-facing repo files. On Windows, mkdtemp's
    # 0o700 ACL can restrict them to the sandbox account even after promotion.
    # Inherit the repo parent's ACL instead; mkdir remains exclusive on collision.
    stage = repo / 'roblox' / f'.mirror-stage-{uuid.uuid4().hex}'
    stage.mkdir(mode=0o777)
    promoted, saved = [], []
    safe_to_remove = True
    try:
        manifest = write_scripts(scripts, stage / 'scripts', roots[0])
        write_snapshot(payload, manifest, stage / 'snapshot')
        for index, (candidate, target) in enumerate(zip([stage / 'scripts', stage / 'snapshot'], roots)):
            target.parent.mkdir(parents=True, exist_ok=True)
            previous = stage / f'previous-{index}'
            if target.exists():
                rename_with_retry(target, previous)
                saved.append((previous, target))
            rename_with_retry(candidate, target)
            promoted.append(target)
        return manifest
    except Exception:
        try:
            for target in reversed(promoted):
                shutil.rmtree(target)
            for previous, target in reversed(saved):
                rename_with_retry(previous, target)
        except Exception:
            safe_to_remove = False
            raise RuntimeError(f"Rollback incomplete; recovery files retained at {stage}")
        raise
    finally:
        if safe_to_remove:
            shutil.rmtree(stage)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Roblox full Studio snapshot export.")
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
    manifest = import_payload(payload, scripts_dir, snapshot_dir)

    print(f"Imported {len(manifest)} scripts into {scripts_dir}")
    print(f"Wrote hierarchy snapshot to {snapshot_dir / 'hierarchy.json'}")
    print(f"Wrote readable hierarchy to {snapshot_dir / 'hierarchy.md'}")
    print(f"Wrote checksums to {snapshot_dir / 'checksums.json'}")


if __name__ == "__main__":
    main()
