#!/usr/bin/env python3
"""
Import Neo Tokyo Racers script source exported from Roblox Studio.

Usage:
    python scripts/import_studio_script_export.py docs/studio-script-export-paste.txt

The Studio exporter creates chunked StringValues in:
    ReplicatedStorage.NTR_GITHUB_SCRIPT_EXPORT

Paste the chunk values into the input text file in order, then run this importer.
It writes script source files into:
    roblox/exported_scripts
"""

from __future__ import annotations

import argparse
import base64
import json
import re
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "roblox" / "exported_scripts"


@dataclass
class ExportedScript:
    roblox_path: str
    class_name: str
    disabled: str
    source_lines: str
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


def path_for_script(output_dir: Path, script: ExportedScript) -> Path:
    parts = [sanitize_component(part) for part in script.roblox_path.split(".")]
    if not parts:
        parts = ["UnknownScript"]

    file_name = parts[-1] + extension_for(script.class_name)
    return output_dir.joinpath(*parts[:-1], file_name)


def parse_export(text: str) -> list[ExportedScript]:
    if "NTR_SCRIPT_EXPORT_V1" not in text:
        raise ValueError("Input does not look like an NTR_SCRIPT_EXPORT_V1 export.")

    lines = text.splitlines()
    scripts: list[ExportedScript] = []
    index = 0

    while index < len(lines):
        line = lines[index].strip()
        if line != "BEGIN_SCRIPT":
            index += 1
            continue

        fields: dict[str, str] = {}
        source_b64_lines: list[str] = []
        index += 1

        while index < len(lines):
            current = lines[index]
            stripped = current.strip()

            if stripped == "SourceBase64Begin":
                index += 1
                while index < len(lines) and lines[index].strip() != "SourceBase64End":
                    source_b64_lines.append(lines[index].strip())
                    index += 1
                if index >= len(lines):
                    raise ValueError("Malformed export: missing SourceBase64End.")
            elif stripped == "END_SCRIPT":
                break
            elif ": " in current:
                key, value = current.split(": ", 1)
                fields[key.strip()] = value

            index += 1

        if index >= len(lines) or lines[index].strip() != "END_SCRIPT":
            raise ValueError("Malformed export: missing END_SCRIPT.")

        source_b64 = "".join(source_b64_lines)
        try:
            source_bytes = base64.b64decode(source_b64.encode("ascii"), validate=False)
            source = source_bytes.decode("utf-8")
        except Exception as exc:
            raise ValueError(f"Could not decode source for {fields.get('Path', '<unknown>')}: {exc}") from exc

        scripts.append(
            ExportedScript(
                roblox_path=fields.get("Path", "Unknown.UnknownScript"),
                class_name=fields.get("ClassName", "Script"),
                disabled=fields.get("Disabled", "false"),
                source_lines=fields.get("SourceLines", "0"),
                source_checksum=fields.get("SourceChecksum", ""),
                source=source,
            )
        )

        index += 1

    return scripts


def write_scripts(scripts: list[ExportedScript], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = []
    written_paths: set[Path] = set()

    for script in scripts:
        target_path = path_for_script(output_dir, script)
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
                "roblox_path": script.roblox_path,
                "class_name": script.class_name,
                "disabled": script.disabled,
                "source_lines": script.source_lines,
                "source_checksum": script.source_checksum,
                "file": str(target_path.relative_to(REPO_ROOT)).replace("\\", "/"),
            }
        )

    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    manifest_md = [
        "# Exported Roblox Scripts",
        "",
        "Generated from Roblox Studio export.",
        "",
        "These files are a GitHub-readable mirror of Studio scripts. Treat Studio as live until a Rojo/source-sync migration is explicitly completed.",
        "",
        f"Script count: {len(manifest)}",
        "",
    ]

    for item in manifest:
        manifest_md.append(f"- `{item['roblox_path']}` -> `{item['file']}`")

    (output_dir / "MANIFEST.md").write_text("\n".join(manifest_md) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Neo Tokyo Racers Studio script export.")
    parser.add_argument("input", help="Path to pasted Studio export text.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT_DIR), help="Output folder for exported .lua files.")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output)
    if not output_dir.is_absolute():
        output_dir = REPO_ROOT / output_dir

    text = input_path.read_text(encoding="utf-8")
    scripts = parse_export(text)
    write_scripts(scripts, output_dir)

    print(f"Imported {len(scripts)} scripts into {output_dir}")
    print(f"Manifest: {output_dir / 'MANIFEST.md'}")


if __name__ == "__main__":
    main()
