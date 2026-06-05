# Architecture Phase K - HOVER_RACING_V2_KIT Migration

Generated: 2026-05-29

## Purpose

Phase K migrates the old `ReplicatedStorage.HOVER_RACING_V2_KIT` root into the newer `ReplicatedStorage.NeoTokyoRacers` architecture.

This is intended to be the first live cut away from the legacy kit root. It is deliberately guarded: the script preflights source patches first and stops before moving anything if it cannot remove all direct old kit references from live source.

## Script

Run in Roblox Studio Command Bar, Edit mode:

```text
scripts/roblox_architecture_phaseK_migrate_hover_kit_to_neotokyo.lua
```

## Target Structure

```text
ReplicatedStorage
  NeoTokyoRacers
    Assets
      Vehicles
        Categories
      VFX
        VehicleTemplates
      World
    Config
      Runtime
      Editable
      UI
        Theme
        PaintPresets
      Gameplay
      Vehicles
      VFX
      World
    Shared
      Modules
        Core
          PathResolver
        Client
        Common
        Input
        UI
        Vehicle
        VFX
      Remotes
        Garage
    Compatibility
      LegacyKitRemainders
      MigrationReports
```

## Migration Rules

- `VEHICLE_CATEGORIES` moves to `Assets.Vehicles.Categories`.
- `VFX_TEMPLATES` moves to `Assets.VFX.VehicleTemplates`.
- `REMOTES_DoNotRename` moves to `Shared.Remotes.Garage`.
- `CLIENT_MODULES` moves to `Shared.Modules.Client`.
- `SHARED_MODULES` moves to `Shared.Modules.Common`.
- `UI_THEME_DoNotRename` moves to `Config.UI.Theme`.
- `PAINT_PRESETS_EditColoursHere` moves to `Config.UI.PaintPresets`.
- `CONFIG` moves to `Config.Runtime`.
- `00_EDIT_ME_FIRST` moves to `Config.Editable`.
- Any unmapped child of the old kit is moved to `Compatibility.LegacyKitRemainders` for review.

The script keeps the inner folder shapes of `CLIENT_MODULES`, `SHARED_MODULES`, `CONFIG`, and `00_EDIT_ME_FIRST` stable for now. That is intentional: it avoids fragile rewrites while still removing the legacy top-level kit root.

## Expected Output

Successful run should print:

- `Phase K migration complete.`
- `No legacy kit source references remain.`
- A `PhaseK_HoverKitMigration` report under `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports`.

If the preflight stops, nothing should have moved yet. Paste the blocker list back into Codex so the patcher can be extended for the exact source shape.

## Confirmed Studio Result

Phase K completed successfully on 2026-05-29 at 17:31:59:

- Legacy kit existed: true.
- Source objects patched: 20.
- Text replacements applied: 112.
- Move/merge operations: 12.
- Final legacy source hits: 0.
- `VEHICLE_CATEGORIES`, `VFX_TEMPLATES`, `REMOTES_DoNotRename`, `CLIENT_MODULES`, `SHARED_MODULES`, `UI_THEME_DoNotRename`, `PAINT_PRESETS_EditColoursHere`, `CONFIG`, and `00_EDIT_ME_FIRST` were moved or merged into `ReplicatedStorage.NeoTokyoRacers`.

## Preflight Fixes

- 2026-05-29: Extended the source patcher for registry/path-string sources that contained `00_EDIT_ME_FIRST` or `UI_THEME_DoNotRename` outside direct `WaitForChild` calls. The first failed preflight was safe: it stopped before moving any objects.

## Play-Test Checklist

After running Phase K:

- Start Play mode fresh.
- Confirm garage UI opens.
- Confirm cash/catalogue loads.
- Buy/select/equip a cockpit/module path if possible.
- Spawn vehicle.
- Confirm driving starts.
- Confirm mobile/desktop HUD still appears correctly for the current device mode.
- Confirm engine/boost/stabiliser/hover VFX still respond.
- Confirm paint/thrust colour changes still apply.
- Confirm there are no warnings about missing `GarageInvoke`, `GaragePush`, `VehicleVFXController`, `DrivingControllerV47`, `VehicleStatsCache`, or `UITheme`.

## Follow-Up

After Phase K is confirmed working in Studio, Phase L should run a stricter post-migration audit. If that audit is clean, the remaining compatibility report folders and any `LegacyKitRemainders` contents can be reviewed.
