# Legacy cleanup — Space Racers v1

2026-09-05. All five architecture phases were user-confirmed before this separate cleanup request. Installed directly in place `121304917315753`; user cleanup playtest pending. No publishing performed.

## Contract and ownership

High-Risk lane because this retires legacy objects. Remove only individually reviewed, unused code and migration bookkeeping. Preserve all gameplay source, active owners, remotes, saved schema, balance/tuning, device behaviour, development tools and physical content. No new system, state transition or persistence operation. No models, meshes, parts, assets, placement or their attributes may be changed. No in-game backups. One installer, exact baseline preflight, transactional failure recovery, explicit rollback, source compilation and full mirror verification.

Canonical owners remain ServerBase/ClientBase and the existing feature modules. Old Services and client namespaces are used by canonical modules for relative paths, runtime events and attributes; they are not dead folders. The user explicitly requested keeping opt-in development tools.

## Removed

**117 objects:** 11 disabled executable scripts, four unused ModuleScripts, 16 folders and 86 value objects. Their 208 attached historical attributes disappear with those objects. Separately removed **70 obsolete `Phase…SourcePatchedAt/By` attributes** from surviving code objects; no source text changes.

The 11 disabled scripts had no source-name callers, no children/tags and no external ObjectValue references:

- Server Services/Garage: `GarageInteriorService_Active`, `GarageInteriorCustomizationService_Active`.
- Client Controllers/Intro: `CockpitCustomisationZoneClient_Active`, `DriveInCustomisationZoneClient_Active`.
- Client Controllers/Racing: `RaceClient_Active`, `RaceSessionControlsClient_Active`, `RaceHudExitCleanupClient_Active`.
- Client Controllers/UI: `GarageExperienceController_Active`.
- Client Controllers/World: `GarageAccessClient_Active`, `GarageInteriorClient_Active`, `GarageInteriorCustomizationClient_Active`.

Removed `ReplicatedStorage.NeoTokyoRacers.Compatibility` with its unused May PathResolver/LiveSystemRegistry, stale ObjectValue links and cleanup/migration reports. This is distinct from the **retained active** `Shared.Modules.Core.PathResolver` and Player.ProfileCompatibility modules. Also removed the separate `NeoTokyoRacers.MigrationReports` folder and the unused ConfigRegistry modules at `Shared.Config.ConfigRegistry` and `Shared.Modules.Data.ConfigRegistry`.

Removed descriptive-only old Shared.Config scaffolding under Driving, Camera, Economy, VFX, Vehicles, World, Racing, Mobile and Diagnostics; the README_ConfigLayer; and nine obsolete UI migration notes. These contained old future-layer descriptions, statuses and path strings, not active tuning. Live runtime config folders and designer shortcut links stay.

Exact instance paths, original classes, sources, primitive attributes, tags, StringValue contents and ObjectValue targets are frozen in `scripts/legacy_cleanup/baseline.json` and embedded in the canonical installer. Reports/recovery history belong in this repository, not the live place. Historical installers remain history and must not be rerun indiscriminately.

## Retained and uncertain items

| Area | Decision |
|---|---|
| Trailer cameras, HUD toggle, lighting preview | Keep by explicit user instruction; four ClientTools flags remain off. Studio cash/telemetry tools also stay. |
| Former Services/client paths, bootstrap adapters, ProfileCompatibility | Keep: active compatibility paths and runtime anchors. Removing them requires migrating callers and runtime endpoints together. |
| `Shared.Config.UI.Theme` and README_BackExitColors | Keep pending a dedicated fallback/theme consumer review. No claim that every mirrored theme value is needed. |
| `Shared.Config.Vehicle`, legacy performance tuning and V2 configs | Keep: empty/config/shadow naming alone does not establish disuse. Performance compatibility/default readers still exist. |
| GarageClient's dormant UI/fallback blocks | Keep: embedded in a large active closure, not safely deletable as standalone objects. Needs callgraph/helper extraction work. |
| Other migration/SourceHash/SourceScriptPath/CreatedBy attributes | Retain unless individually reviewed; broad metadata deletion can invalidate recovery/diagnostic contracts. Current phase folder markers remain useful for recovery. |
| Physical/template assets, authored folders, parts/models/meshes, unused-looking assets | Protected by user scope. No deletions or attribute/property edits. |

Do not interpret this cleanup as proof that every remaining item is runtime-used. The ambiguous areas above were deliberately retained rather than guessed at; no answer is needed to keep the verified cleanup installed.

## Verification and handoff

- Read-only preflight passed against the fresh 12:02:06 mirror and live Edit state. No fragile source replacement is used.
- Installer AUDIT, INSTALL, repeat INSTALL, ROLLBACK and reinstall passed. All restored retired sources and metadata were checked against their original records during rollback.
- All **323 surviving sources compile** and retain exact SHA-256 parity with the pre-cleanup mirror.
- Fresh normal Play: **26 server entries ready, 40 client entries ready, four development entries skipped**. Existing LOD owner status was `running`. No alternate MCP require-cache owners were started.
- Final receiver/exporter mirror **2026-09-05 12:07:40**, 323 verified sources and 267,069 property values. Both mirror areas are current. Raw paste untouched. Existing 2,918 duplicate non-source path warnings remain; mutations use unambiguous path parts.
- All **42,745 remaining exported nodes** match the expected hierarchy/property/attribute projection exactly, including physical content. Only approved patch stamps differ. Export-local sequence IDs are normalised because deleting scripts renumbers them; actual Studio properties are not normalised away. Coverage is the exporter's explicit property schema, not every possible engine property.

Evidence: `legacy-cleanup-verification.json`. Recheck locally with `scripts/legacy_cleanup/verify_cleanup.py` and `scripts/verify_studio_mirror.py`. The builder freezes its baseline once; do not regenerate it from the cleaned mirror.

**Studio script:** `scripts/roblox_legacy_cleanup.lua`, already run through MCP. Nothing needs running for ordinary use. In Edit, set its single `MODE` to `AUDIT` for read-only checks or `ROLLBACK` to restore this exact retirement set. Unrecognised changes block the installer before mutation. Restore cleanup before earlier architecture exact-baseline recovery, then undo dependent phases newest first. Refresh the mirror after any recovery. No game-version revert is needed for the verified cleanup; the user's whole-place backup remains broader recovery.

**User verification:** start a fresh Play session; complete loading/dealership, buy or spawn a vehicle, customise/paint, enter/exit owned garage, drive through the city, and start/finish/exit a race or time trial. Check for new Output errors and repeat important transitions. Try landscape touch if available. Report the first failing action if anything changed. Studio sandbox suppresses saves; production save/rejoin, published streaming and representative device profiling remain separate release gates.

**Commit:** include cleanup installer/support records, docs and both generated mirror areas with the existing approved architecture work. Exclude `docs/studio-full-export-paste.txt`. No Git commit or publication was performed by this cleanup.

## Workflow lesson

Retire by exact identity and caller evidence, not by Disabled/Legacy/Shadow names. Preserve opt-in tools as development dependencies. Pair metadata removal with a repository-backed recovery inventory, and compare the entire remaining exported hierarchy to catch unintended physical changes. Source manifests alone cannot prove that folders/attributes/placement stayed intact.
