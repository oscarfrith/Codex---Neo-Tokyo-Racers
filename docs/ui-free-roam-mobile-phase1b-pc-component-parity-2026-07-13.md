# Mobile Free-Roam UI Phase 1B PC Component Parity

**Date:** 2026-07-13  
**Status:** Generated from refreshed post-Phase-1 mirror; awaiting Studio rerun and visual confirmation

## Source Evidence

The Studio mirror was refreshed at `2026-07-13 14:58:02` with 114 scripts and
contains both installed Phase 1 owners. Screenshot review and the mirror confirmed:

- Phase 1 omitted the PC map flips, rotation offset, edge fades, and exact map
  position equation.
- Phase 1 created a vertical action stack instead of the PC horizontal action bar.
- Phase 1 approximated the PC telemetry instead of porting its boost icon,
  gradient, metric proportions, and 16 curved gauge segments.
- the duplicate interface is the bootstrap-created exact ScreenGui
  `PlayerGui.HOVER_RACING_V2_DriveHUD`.

## Installer

Phase 1B upgrades the existing canonical installer in place. Run this whole file
again in the Studio Command Bar while in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer canonically replaces only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active
```

It does not patch the register-limited bootstrap. Its post-write smoke requires
the Phase 1B marker, exact legacy-HUD name, map fades/flips, PC boost icon, curved
gauge, larger controls, and transparent boost hit target.

## Changes

- Reuses the PC Phase 4A map tile order and position/heading equations, including
  `MapFlipX`, `MapFlipZ`, `MapCoordinateRotationDegrees`, and
  `MapRotationOffsetDegrees`.
- Reuses four PC-style directional edge fades and rounded borderless clipping.
- Places the five PC actions in one top horizontal row; Car keeps the PC
  double-width proportion.
- Ports the PC boost icon, blue-to-cyan gradient bar, large MPH metric, unit
  label, and 16 curved gauge segments into the bottom-centre mobile cluster.
- Makes the configured boost icon itself the invisible-padded touch target.
- Places the small Exit button to the left of the MPH number.
- Enlarges arrow, thumbstick, accelerator, and brake controls by roughly 12-15%.
- Clips and constrains text fallbacks so `BOOST`, `BRAKE`, and `ACCEL` cannot
  overflow before image ids are assigned.
- Hides and guards only the exact `MobileDriveControls`, `DriveHUD`, and
  `DriveMenu` GuiObjects beneath `PlayerGui.HOVER_RACING_V2_DriveHUD`. The
  ScreenGui remains enabled because the confirmed mobile/VFX helper uses that
  state as a driving signal for camera and Roblox touch-control ownership. No
  broad UI scan is introduced.

## Verification

1. Stop Play, rerun the canonical installer in Edit mode, then start a fresh
   mobile Device Emulator session.
2. Confirm Output prints the Phase 1B install and both Phase 1B client startup
   messages without an assertion or runtime error.
3. Confirm the old black/pink drive panel, old arrows, old pedals, and old Exit
   menu are gone.
4. Compare the action row to the PC reference: horizontal, double-width Car,
   four square actions, shared icons and strokes.
5. Compare telemetry to the PC reference: configured lightning icon, gradient
   boost bar, large number, centred `MPH`, and 16 right-side curved segments.
6. Confirm Exit is immediately left of the MPH number and the boost icon is
   touchable without a second visible Boost button.
7. Confirm the map is north-up with the same road orientation/player heading as
   PC, rounded corners, and visible fades on all four edges.
8. Confirm larger arrows and pedals fit at both small-phone and tablet landscape
   sizes, and exercise Arrow, Thumbstick, Tilt, brake/reverse, boost, and exit.
9. Recheck car spawn/despawn, race browser, garage, dealership teleport, and
   presentation ownership.

## Rollback

Restore the Studio version from immediately after the first Phase 1 install, or
restore the two installed Phase 1 sources from the `14:58:02` mirror. Do not run
the older thumbstick patch ladder and do not patch the bootstrap.

After confirmation, refresh the full Studio mirror again and commit the new
`roblox/exported_scripts/` and `roblox/studio_snapshot/` outputs. Do not commit
`docs/studio-full-export-paste.txt`.
