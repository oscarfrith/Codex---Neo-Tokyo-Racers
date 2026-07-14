# Mobile Free-Roam UI Phase 1C Layout Refinement

**Date:** 2026-07-13  
**Status:** Generated; awaiting Studio install, Device Emulator review, and mirror refresh

## Installer

Phase 1C upgrades the same canonical installer. Run the whole file in the Roblox
Studio Command Bar while in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

It canonically replaces only the isolated mobile HUD and control owners. It does
not patch the register-limited bootstrap, driving physics, server gameplay, VFX,
or LOD.

## Layout Changes

- Pins the map to the top-right safe margin.
- Aligns the PC-proportioned horizontal action row immediately left of the map,
  with matching top edges; Car remains double-width.
- Places cash directly beneath the map with the same narrow cluster gap.
- Makes each arrow `1.5x` its previous width while preserving its height,
  inter-button gap, two-column alignment, and left screen anchor.
- Centres the real boost touch target above the arrow cluster. It reuses the PC
  lightning asset at `1.5x` visual scale and retains transparent touch padding.
- Moves the speed cluster down to the bottom safe margin.
- Rebuilds the 16 speed segments as a shallow arc above the MPH number.
- Places a narrow boost meter to the right of MPH, filling bottom-to-top, with a
  display-only PC lightning icon beneath it.
- Keeps Exit immediately left of MPH and leaves the pedals unchanged from the
  enlarged Phase 1B sizing.

Editable Phase 1C attributes are under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
```

The new tuning attributes are `ArrowWidthMultiplier`, `BoostIconScale`,
`TopClusterGap`, and `TelemetryBottomMargin`.

## Verification

1. Stop Play and run the installer in Edit mode.
2. Start a fresh landscape mobile Device Emulator session and enter a vehicle.
3. Confirm Output shows the Phase 1C installer and both Phase 1C client startup
   messages with no assertion or runtime error.
4. Confirm the action row is left of the top-right map, their top edges align,
   and cash is directly beneath the map.
5. Confirm the arrow buttons are wider but keep equal gaps and left alignment.
6. Hold the lightning icon above the arrows and confirm boost activates and
   releases correctly. The lightning icon below the meter must not be clickable.
7. Confirm speed sits low at bottom-centre, 16 segments form a shallow overhead
   arc, Exit sits left of MPH, and boost fills upward in the right-side meter.
8. Recheck map orientation/fades/corners, old-HUD suppression, both pedals, all
   three mobile steering modes, car menu, garage, races, and dealership teleport.
9. Test Tilt on a real gyroscope device.

## Rollback

Restore the two mobile controller sources from the last accepted Studio version.
Do not rerun the old thumbstick patch ladder and do not patch the bootstrap.

After confirmation, refresh the full Studio mirror and commit generated changes
under `roblox/exported_scripts/` and `roblox/studio_snapshot/`. Do not commit
`docs/studio-full-export-paste.txt`.
