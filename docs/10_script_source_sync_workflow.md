# Script Source Sync Workflow

**Created:** 2026-05-28  
**Status:** Lightweight Studio-to-GitHub script mirror workflow  
**Purpose:** Make Roblox Studio script sources available in GitHub for Codex/ChatGPT review and patch planning.

## Why This Exists

Roblox Studio is currently the live source of truth for the game. GitHub contains docs and command-bar scripts, but not every live `Script`, `LocalScript`, and `ModuleScript`.

For future Codex work, it is much easier and safer if the current Studio scripts are mirrored into GitHub as normal `.lua` files. That allows search, diffing, review, and targeted patch planning without relying on pasted output.

## Current Workflow

1. In Roblox Studio, run:

```text
scripts/roblox_studio_export_scripts_for_github_v1.lua
```

2. In Studio Explorer, open:

```text
ReplicatedStorage.NTR_GITHUB_SCRIPT_EXPORT
```

3. Copy the values from:

```text
ScriptExport_001
ScriptExport_002
ScriptExport_003
...
```

4. Paste them in order into a local text file, for example:

```text
docs/studio-script-export-paste.txt
```

There is an example file at:

```text
docs/studio-script-export-paste.example.txt
```

The real paste file is ignored by Git because it can become large.

5. Run locally from the repo:

```text
python scripts/import_studio_script_export.py docs/studio-script-export-paste.txt
```

If Python is not on your PATH, use the Python launcher if available:

```text
py scripts/import_studio_script_export.py docs/studio-script-export-paste.txt
```

6. The importer writes script source files to:

```text
roblox/exported_scripts
```

It also creates:

```text
roblox/exported_scripts/manifest.json
roblox/exported_scripts/MANIFEST.md
```

## What Gets Exported

The exporter scans these services:

```text
ReplicatedStorage
ServerScriptService
StarterPlayer
StarterGui
Workspace
ServerStorage
Lighting
```

It exports:

```text
Script
LocalScript
ModuleScript
```

By default it excludes:

```text
Workspace.Test + WIP Assets
```

Disabled legacy scripts are included so the repo has a useful historical reference.

## Important Safety Notes

- This is a mirror, not live Rojo sync.
- Studio remains authoritative until a source-control migration is explicitly planned.
- Do not edit `roblox/exported_scripts` and assume Studio will update automatically.
- Use these exported files for review, documentation, safer patch planning, and comparing changes.
- When a script is intentionally changed in Studio, run the export/import workflow again.

## Future Better System

Longer term, the cleaner option is a Rojo-based workflow:

- GitHub stores source files as the real source of truth.
- Rojo syncs them into Roblox Studio.
- Codex edits normal `.lua` files directly.
- Studio is used for assets, testing, and visual layout.

Do not jump to Rojo for the whole project until the current hierarchy is stable. A staged migration is safer:

1. Mirror scripts into GitHub.
2. Identify stable modules first.
3. Move one module/system into Rojo source.
4. Test in Studio.
5. Continue system by system.
