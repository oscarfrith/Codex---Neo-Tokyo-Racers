# Lighting Phase AP: Window Material Day/Night

**Created:** 2026-06-13  
**Status:** Installed and user-confirmed working

## Purpose

Phase AP migrates building window MeshParts away from per-part SurfaceAppearance
textures and onto the shared `Windows Day` and `Windows Night`
MaterialVariants.

It only targets MeshParts with a direct SurfaceAppearance child named
`Windows` or `SurfaceAppearance Windows`.

## Studio Script

Run this whole file in the Roblox Studio Command Bar:

```text
scripts/roblox_lighting_phaseAP_window_material_day_night.lua
```

The installer:

- Aborts before changing anything unless both MaterialVariants exist.
- Requires both variants to use the same `BaseMaterial`.
- Clears the matching MeshPart texture content.
- Removes only the matching SurfaceAppearance child.
- Sets the MeshPart to `Windows Day`.
- Adds the `NTR_WindowMaterial` CollectionService tag.
- Installs `WindowMaterialController_Active` under the client World controllers.

## Runtime Behavior

The controller prefers this explicit Lighting attribute:

```lua
Lighting:SetAttribute("NTR_LightingPreset", "Day")
Lighting:SetAttribute("NTR_LightingPreset", "ClearNight")
```

For the current N/M preview workflow, it also watches `Lighting.Brightness`.
Brightness at or below `1` is treated as night because the current ClearNight
preset uses `ClockTime = 12.1`, so ClockTime cannot identify that preset.

There is no frame loop. The controller updates only when the preset attribute,
Brightness, or tagged streamed instances change.

## Edit Mode Preview

Use these separate Command Bar scripts while Studio is not playing:

```text
scripts/roblox_lighting_preview_day_edit_mode.lua
scripts/roblox_lighting_preview_night_edit_mode.lua
```

Each script applies the complete matching lighting preset, sky, post effects,
Lighting preset attribute, and tagged window MaterialVariant. This makes it
possible to edit and save the place while viewing either condition.

## Verification

1. Confirm `MaterialService` contains `Windows Day` and `Windows Night`.
2. Run the Phase AP installer and review its final counts.
3. Inspect several window MeshParts. The SurfaceAppearance should be gone,
   texture content empty, MaterialVariant `Windows Day`, and tag
   `NTR_WindowMaterial`.
4. Enter Play mode.
5. Press `N`; tagged windows should switch to `Windows Night`.
6. Press `M`; tagged windows should switch back to `Windows Day`.
7. Drive through streamed city blocks and confirm newly streamed tagged windows
   use the current mode.

## Rollback

Use Roblox place version history to restore the pre-Phase-AP place. The removed
SurfaceAppearance objects and texture assignments are destructive Studio edits;
the installer intentionally does not create in-game backups.

## Mirror

After Studio installation and verification, run the full Studio receiver/exporter
workflow and commit the refreshed `roblox/exported_scripts/` and
`roblox/studio_snapshot/` output.
