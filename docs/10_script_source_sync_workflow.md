# Studio Source Sync Workflow

**Updated:** 2026-07-27
**Status:** Local receiver full-snapshot export/import workflow  
**Purpose:** Capture the current Roblox Studio hierarchy and all script sources into GitHub with minimal manual copying.

**Owned-garage camera scope note (2026-07-27):** the complete `21:26:44` mirror contains user-confirmed V2.2 with 192 mutually matching exported-manifest, source-manifest and checksum entries. The installed arbitration block matches the canonical installer exactly, V2.1 visible-surface ownership remains present and `MobileThumbstickSemanticConfirmWindowSeconds=0.35` is captured. Neither mirror area appears stale and no owned-garage camera refresh is pending. Do not commit `docs/studio-full-export-paste.txt`.

**Current scope note (2026-07-26):** the complete `22:35:11` mirror contains the user-confirmed Shared Vehicle Card V1.2 source. Its 189 checksum, source-manifest and exported-script entries match with zero mismatches; the browser V1.2 marker and all five V1.1 shared owners are present. Neither mirror area appears stale. Do not commit `docs/studio-full-export-paste.txt`.

**Confirmed racing scope note (2026-07-27):** Racing Presentation/Lifecycle V1.4 is user-confirmed and represented in the complete `10:05:47` mirror. Its 189 exported-script, source-manifest, checksum and hierarchy entries agree with zero mismatches. The mirror contains `NTR_RACING_PRESENTATION_LIFECYCLE_V1_4`, the adaptive-safe-edge canvas marker, retained V1.3 full-screen EXIT and V1.2 prompt/checkpoint markers, all three earlier legacy racing clients disabled, no standalone PB-board script, and retained authored `ArrowMarkers`. No refresh or Studio command is pending for ordinary use.

**Drive-to-earn/free-roam Cash scope note (2026-07-27):** V1.1 and the user-confirmed free-roam smoothing/full-formatting continuation are represented in the complete `11:26:30` mirror with 191 mutually matching exported-script, source-manifest and checksum entries. The mirror contains the shared presenter, desktop and mobile smoothing markers, all three `NTR_FREEROAM_CASH_SMOOTHING_V1` revision attributes and the five Theme controls. The drive service still safety-clamps the effective grant interval to `0.5 s`, although the exported config attribute is `0.1`. Neither mirror area appears stale and no Cash-scope refresh or Studio command is pending. Leave `docs/studio-full-export-paste.txt` unstaged.

## Why This Exists

Roblox Studio is still the live source of truth for Neo Tokyo Racers. GitHub stores docs, command-bar scripts, and a readable mirror of Studio script sources so Codex/ChatGPT can search, diff, review, and plan safe targeted patches.

This workflow exports the important Studio data in one pass:

- A hierarchy snapshot for the main game services.
- All `Script`, `LocalScript`, and `ModuleScript` sources.
- Metadata such as `ClassName`, Studio path, `Disabled` state, attributes, source line counts, byte counts, and checksums.
- A local HTTP receiver path so you do not have to manually copy dozens of `StringValue` chunks.
- Automatic HTTP chunking under Roblox Studio's 1024 KB post limit.
- Chunked `StringValue`s in `ReplicatedStorage` as a fallback if local HTTP is unavailable.

This is a mirror, not live Rojo sync. Editing files under `roblox/exported_scripts/` does not automatically update Studio.

Editing/scratch asset libraries captured by the mirror are documentation only. Production installers, runtime and committed-state audits must not require or compare them; owned-garage production readiness is determined solely from the authoritative ServerStorage hierarchy. Copying an approved asset into ServerStorage is an explicit authoring/publishing action, not an automatic runtime fallback.

When a refreshed mirror proves that Source edits committed but attributes/new Instances from the same Command Bar transaction did not, treat that hybrid mirror as the new diagnostic baseline. The recovery command must not assign `Source` again, even to identical text. Apply only the missing non-source state, restart Studio, and prove committed state with a separate read-only audit before Play or another mirror refresh.

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

In Codex desktop sessions, if neither `python` nor `py` is available on PATH, use the bundled workspace Python path reported by the app/runtime. The receiver does not require internet access.

Leave that PowerShell window open. It waits for Studio export chunks at:

```text
http://127.0.0.1:8765/ntr-studio-export-chunk
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

If the local receiver is running, Studio posts the full export to it in smaller HTTP chunks. The receiver then automatically writes/imports:

```text
docs/studio-full-export-paste.txt
roblox/exported_scripts/
roblox/studio_snapshot/
```

In Studio output, the good message looks like:

```text
[NTR Studio Export V2] Sent to local receiver in 13 chunks: http://127.0.0.1:8765/ntr-studio-export-chunk
```

In PowerShell, the good message is:

```text
Studio export received and imported successfully.
```

If the receiver reports that it could not write `docs/studio-full-export-paste.txt` but still says it is continuing with in-memory import, that is acceptable. The important outputs are the refreshed `roblox/exported_scripts/` and `roblox/studio_snapshot/` folders. The raw paste file is only a fallback artifact and should not be committed.

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

The exporter now scans both `ReplicatedFirst` and `SoundService` as well as the previously covered services. Mirrors created before the 2026-07-21 loading/start-screen Phase 5 tooling update omit `ReplicatedFirst`; mirrors created before the audio-system Phase 1 tooling update omit `SoundService`. Run the current exporter after a relevant install so loading/audio hierarchy and source are captured.

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

## Current Mirror Status

The current full mirror was generated on 2026-07-26 at 20:46:20 and contains 188 scripts. The exported manifest, source manifest and checksums each contain 188 matching entries. It contains confirmed Presentation Audio V1.3.2 with `NTR_PRESENTATION_AUDIO_CONTROLLER_V1_3_2_IMMEDIATE_ONESHOTS`, `InstallerRevision=NTR_PRESENTATION_AUDIO_UI_PREVIEW_RACE_V1_3_2`, both described preload controls and retained V5 reliable Ignition source. It also contains the confirmed Customisation Refinement V1.1 source/hierarchy recorded in its handoff.

Both mirror areas agree and neither appears stale for these confirmed baselines. No Presentation Audio or Customisation mirror refresh is currently pending.

The fresh mirror also shows active loose `StarterPlayerScripts` filming/camera helpers (`LocalScript`, `TrailerMode.client.lua`, and `TrailerShot01Camera`). Treat them as review items before publishing a normal gameplay build unless they are intentionally kept enabled.

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

If `docs/studio-full-export-paste.txt` appears modified after a mirror refresh, leave it unstaged or restore it before committing. The useful committed mirror state is under `roblox/exported_scripts/` and `roblox/studio_snapshot/`.

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
- If mirror import fails after all chunks arrive, inspect the receiver error before asking for repeated exports. The receiver now supports in-memory import when raw paste-file writing fails.

## Current Pending Refresh: Canonical Garage After Installation

The `2026-07-14 15:34:29` snapshot contains the required mobile/racing source markers:

```text
NTR_RACING_FLOW_COUNTDOWN_VISUAL_V2
NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2
NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION
```

After installing `scripts/roblox_ui_garage_canonical_experience.lua`, refresh again and confirm the new garage session, entrance and presentation owners plus the `NTR_GARAGE_CANONICAL_EXPERIENCE_V1` bridges are present before generating any repair.

Leave `docs/studio-full-export-paste.txt` unstaged as usual.

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
