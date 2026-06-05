# Studio Source Sync Workflow

**Updated:** 2026-06-05  
**Status:** Local receiver full-snapshot export/import workflow  
**Purpose:** Capture the current Roblox Studio hierarchy and all script sources into GitHub with minimal manual copying.

## Why This Exists

Roblox Studio is still the live source of truth for Neo Tokyo Racers. GitHub stores docs, command-bar scripts, and a readable mirror of Studio script sources so Codex/ChatGPT can search, diff, review, and plan safe targeted patches.

This workflow exports the important Studio data in one pass:

- A hierarchy snapshot for the main game services.
- All `Script`, `LocalScript`, and `ModuleScript` sources.
- Metadata such as `ClassName`, Studio path, `Disabled` state, attributes, source line counts, byte counts, and checksums.
- A local HTTP receiver path so you do not have to manually copy dozens of `StringValue` chunks.
- Chunked `StringValue`s in `ReplicatedStorage` as a fallback if local HTTP is unavailable.

This is a mirror, not live Rojo sync. Editing files under `roblox/exported_scripts/` does not automatically update Studio.

## Current Best Workflow

### 1. Start The Local Receiver

In PowerShell, from the repo folder, run:

```text
python scripts/receive_studio_full_snapshot_export.py
```

If `python` is not on your PATH, try:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Leave that PowerShell window open. It waits for one Studio export at:

```text
http://127.0.0.1:8765/ntr-studio-export
```

### 2. Enable Studio HTTP Requests If Needed

In Roblox Studio, make sure HTTP requests are enabled:

```text
Game Settings > Security > Allow HTTP Requests
```

If Studio HTTP is disabled, the exporter will still make fallback chunks, but the receiver will not get the export automatically.

### 3. Run The Studio Exporter

In Roblox Studio, paste and run this whole file in the Command Bar:

```text
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

If the local receiver is running, Studio posts the full export to it. The receiver then automatically writes/imports:

```text
docs/studio-full-export-paste.txt
roblox/exported_scripts/
roblox/studio_snapshot/
```

In Studio output, the good message is:

```text
[NTR Studio Export V2] Sent to local receiver: http://127.0.0.1:8765/ntr-studio-export
```

In PowerShell, the good message is:

```text
Studio export received and imported successfully.
```

## Fallback Chunk Workflow

Use this only if the local receiver cannot be used.

The Studio exporter creates or refreshes this folder:

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

Create this local file in the repo:

```text
docs/studio-full-export-paste.txt
```

Copy the **Value** from each `StudioExport_###` StringValue in order and paste them into that one file. Do not copy the StringValue names, just the values.

Then run:

```text
python scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt
```

or:

```text
py scripts/import_studio_full_snapshot_export.py docs/studio-full-export-paste.txt
```

## What The Importer Writes

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

After running the receiver/exporter, check these files:

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
scripts/receive_studio_full_snapshot_export.py
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
Adds a local receiver, Studio Command Bar exporter, and importer for capturing the Roblox hierarchy, script sources, metadata, manifests, and checksums into GitHub without manually copying chunked StringValues.
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
