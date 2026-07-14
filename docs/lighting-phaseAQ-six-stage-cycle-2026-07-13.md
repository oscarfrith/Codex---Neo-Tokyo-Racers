# Lighting Phase AQ/AR: Automatic Lighting Cycle

**Created:** 2026-07-13  
**Status:** Installed, user-confirmed working, and mirrored through 2026-07-14 00:15:37

## Purpose

Phase AQ established the six-stage system. Phase AR extends the current ordered
cycle to eight stages:

| Stage | Duration weight | Street lights | Windows |
|---|---:|---|---|
| 7 AM | 1 | Off | Day |
| 10 AM | 1 | Off | Day |
| Day | 2 | Off | Day |
| 3 PM | 1 | Off | Day |
| 5 PM | 1 | Off | Day |
| 8 PM | 1 | On | Night |
| Night | 2 | On | Night |
| 4 AM | 1 | On | Night |

Day and Night therefore last twice as long as each transition stage. With the
default `BaseDurationSeconds = 300`, the expanded full cycle lasts 50 minutes.

## Installer And Current 5 PM Capture

Prepare the desired 5 PM Lighting, effects, and Sky in Studio Edit mode, then
run this whole file once in the Command Bar:

```text
scripts/roblox_lighting_phaseAQ_six_stage_cycle.lua
```

The installer captures the current edit-mode look directly into `FivePM`.
`SevenAM` is initialized as an independent copy of that capture. `EightPM` and
`FourAM` are initialized as independent copies of the confirmed `ClearNight`
preset when those presets do not already exist. Existing Day and ClearNight
values are preserved.

The installer performs a complete hierarchy/material/Sky preflight before its
first mutation. It uses canonical source replacement only for the small
isolated lighting owners; it does not use fragile text replacement.

## Easy Configuration

Runtime configuration is stored here:

```text
ReplicatedStorage.Shared.LightingCycleConfig
```

Editable Folder attributes:

- `AutoCycleEnabled` (`true` by default)
- `BaseDurationSeconds` (`300` by default)
- `ManualStage` (`Day` by default)
- `SynchronizeAcrossServers` (`true` by default)

Phase AS adds a `StageVisuals` child Folder. Every stage has an easy config
Folder containing `WindowMode`, `StreetLightsEnabled`, and
`StreetLightBrightness`. Environmental capture intentionally preserves these
attributes; Edit preview and runtime restore them from config.

Set `AutoCycleEnabled = false` and change `ManualStage` to any preset name for
a fixed test condition. The ordered `LightingCycleSchedule` child ModuleScript
owns stage order and duration weights. `StageVisuals` owns street-light state,
brightness, and window mode.

The automatic cycle uses server time when synchronization is enabled, so server
restarts and separate servers resolve the same approximate stage without a
DataStore. Lighting changes are discrete in Phase AQ; smooth cross-preset
blending remains deferred until all six looks are confirmed.

## Reusable Capture And Preview

The user confirmed the Phase AQ installation and initial FivePM capture worked
on 2026-07-13. The two reusable tools below are now the preferred workflow for
future preset editing.

To copy the current edit-mode Lighting/effects/Sky into one or more stages, edit
the list at the top of:

```text
scripts/roblox_lighting_capture_current_to_selected_stages.lua
```

Examples:

```lua
local TARGET_PRESETS = {"FivePM"}
local TARGET_PRESETS = {"FivePM", "SevenAM"}
local TARGET_PRESETS = {"EightPM", "FourAM"}
local TARGET_PRESETS = {"TenAM", "ThreePM"}
```

Each target receives an independent preset table and Sky asset, so initially
matching stages can be tuned separately later.

To preview one complete condition in Edit mode, change `PRESET_NAME` at the top
of and run:

```text
scripts/roblox_lighting_preview_selected_stage_edit_mode.lua
```

## Runtime Preview Keys

During Play, `TEMP_LightingPreview` supports:

```text
1 = 7 AM
2 = 10 AM
3 = Day
4 = 3 PM
5 = 5 PM
6 = 8 PM
7 = Night
8 = 4 AM
N = Night
M = Day
```

The server automatic cycle remains authoritative; a key preview is replaced when
the server advances to another stage. For sustained manual testing, disable
automatic cycling and set `ManualStage` instead.

## Verification

1. In Edit mode, prepare the intended current 5 PM look.
2. Run the Phase AQ installer and confirm it reports that FivePM was captured.
3. Run `scripts/roblox_lighting_phaseAQ_audit.lua`; expect `fail=0`.
4. Inspect `LightingCycleConfig` attributes and the eight-entry schedule.
5. Start a fresh Play session and confirm Output reports the applied stage.
6. Temporarily set `AutoCycleEnabled = false`; test all eight `ManualStage` names.
7. Confirm 8 PM, Night, and 4 AM enable every tagged managed street light and
   use `Windows Night`.
8. Confirm Day, 5 PM, and 7 AM disable those lights and use `Windows Day`.
9. Re-enable automatic cycling and temporarily shorten `BaseDurationSeconds`
   (for example, `10`) to observe a complete cycle.
10. Restore the intended production duration and test streamed city blocks.

## Rollback And Risks

- Use Roblox place version history to return to the pre-Phase-AQ place.
- No in-game backup folders or scripts are created.
- The installer canonically replaces only `LightingService_Active`, the two
  isolated lighting visual controllers, and `TEMP_LightingPreview`.
- Street-light control applies to lights tagged `NTR_NightLamppostLight`. If an
  intended street light does not change, inspect/tag or reinstall that asset;
  do not broaden the runtime into repeated whole-world scans.
- Run the installer only while the desired 5 PM look is actively visible,
  because rerunning intentionally recaptures `FivePM`.

## Mirror

After installation and verification, refresh the Studio mirror with the local
receiver and Studio full-snapshot exporter. Commit generated changes under
`roblox/exported_scripts/` and `roblox/studio_snapshot/`, but do not commit
`docs/studio-full-export-paste.txt`.
