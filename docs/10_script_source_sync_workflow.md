# Studio Source Sync Workflow

**Updated:** 2026-06-05  
**Status:** Single Studio full-snapshot export/import workflow  
**Purpose:** Capture the current Roblox Studio hierarchy and all script sources into GitHub with minimal manual copying.

## Why This Exists

Roblox Studio is still the live source of truth for Neo Tokyo Racers. GitHub stores docs, command-bar scripts, and a readable mirror of Studio script sources so Codex/ChatGPT can search, diff, review, and plan safe targeted patches.

This workflow exports the important Studio data in one pass:

- A hierarchy snapshot for the main game services.
- All `Script`, `LocalScript`, and `ModuleScript` sources.
- Metadata such as `ClassName`, Studio path, `Disabled` state, attributes, source line counts, byte counts, and checksums.
- Chunked `StringValue`s in `ReplicatedStorage` so the export can be copied from Studio into one local text file.

This is a mirror, not live Rojo sync. Editing files under `roblox/exported_scripts/` does not automatically update Studio.

## Current Best Workflow

### 1. Run The Studio Exporter

In Roblox Studio, paste and run this whole file in the Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

The script creates or refreshes this folder:

```text
ReplicatedStorage.NTR_STUDIO_FULL_EXPORT_V2
```

Inside it you will see:

```text
README_HOW_TO_IMPORT
StudioExport_001
StudioExport_002
StudioExport_003
...
```

The exporter does not patch gameplay scripts. It only replaces its own export folder/chunks.

### 2. Paste The Export Chunks Locally

Create this local file in the repo:

```text
docs/studio-full-export-paste.txt
```

Copy the **Value** from each `StudioExport_###` StringValue in order and paste them into that one file:

```text
StudioExport_001 value first
StudioExport_002 value second
StudioExport_003 value third
...
```

Do not copy the StringValue names, just the values. It is okay if there are no blank lines between chunks.

The real paste file is intentionally not meant to be committed because it can become large.

### 3. Run The Local Importer

From the repo folder, run:

```text
python scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt
```

If `python` is not on your PATH, try:

```text
py scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt
```

### 4. What The Importer Writes

The importer refreshes:

```text
roblox/exported_scripts/
```

It also writes:

```text
roblox/studio_snapshot/hierarchy.json
roblox/studio_snapshot/hierarchy.md
roblox/studio_snapshot/source_manifest.json
roblox/studio_snapshot/checksums.json
```

`roblox/exported_scripts/MANIFEST.md` lists every exported Studio script and the `.lua` file it maps to.

## How To Verify It Worked

After running the importer, check these files:

```text
roblox/exported_scripts/MANIFEST.md
roblox/studio_snapshot/hierarchy.md
roblox/studio_snapshot/checksums.json
```

Good signs:

- `MANIFEST.md` shows the expected active scripts, including the current `NeoTokyoRacersClient` runtime scripts.
- `hierarchy.md` includes the main services and current folders from Studio.
- `checksums.json` exists and has one entry per exported script.
- Old removed paths, such as `ReplicatedStorage.HOVER_RACING_V2_KIT`, should disappear after a fresh export if they are no longer in Studio.

## Current Staleness Warning

The existing `roblox/exported_scripts/` mirror in GitHub appears stale until this V2 workflow is run again in Studio. It still includes old paths such as:

```text
ReplicatedStorage.HOVER_RACING_V2_KIT
StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client
```

Project docs say `HOVER_RACING_V2_KIT` was removed and the active main client moved into `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient`. Refresh the export before using the mirror as current truth.

## What To Commit In GitHub Desktop

After a successful import, commit these paths:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
scripts/import_studio_full_snapshot_export.py
docs/10_script_source_sync_workflow.md
roblox/exported_scripts/
roblox/studio_snapshot/
```

Do not commit:

```text
docs/studio-full-export-paste.txt
```

Suggested commit title:

```text
Add Studio full snapshot export workflow
```

Suggested commit description:

```text
Adds a single Studio Command Bar exporter and local importer for capturing the Roblox hierarchy, script sources, metadata, manifests, and checksums into GitHub. Refreshes the workflow docs so the exported_scripts mirror and studio_snapshot folder can be regenerated from one pasted export file.
```

## Safety Notes

- Studio remains authoritative until a Rojo/source-sync migration is explicitly planned.
- This exporter does not create in-game backup folders or patch live gameplay scripts.
- The importer refreshes the local mirror folders so stale removed Studio paths do not remain in GitHub after a fresh export.
- When a script is intentionally changed in Studio, run the export/import workflow again.

## Older Script-Only Workflow

The older script-only workflow used:

```text
scripts/roblox_studio_export_scripts_for_github_v1.lua
scripts/import_studio_script_export.py
```

Keep those files as historical fallback for now, but prefer the V2 full snapshot workflow above.

## Future Better System

Longer term, the cleaner option is a Rojo-based workflow:

- GitHub stores source files as the real source of truth.
- Rojo syncs them into Roblox Studio.
- Codex edits normal `.lua` files directly.
- Studio is used for assets, testing, and visual layout.

Do not jump to Rojo for the whole project until the current hierarchy is stable. A staged migration is safer:

1. Mirror scripts and hierarchy into GitHub.
2. Identify stable modules first.
3. Move one module/system into Rojo source.
4. Test in Studio.
5. Continue system by system.
