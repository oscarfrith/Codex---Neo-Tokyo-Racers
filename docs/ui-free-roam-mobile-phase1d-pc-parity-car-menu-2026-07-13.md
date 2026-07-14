# Mobile Free-Roam UI Phase 1D PC-Parity Car Menu

**Date:** 2026-07-13  
**Status:** Generated from confirmed Phase 1C mirror; awaiting Studio install and Device Emulator confirmation

## Confirmed Input Baseline

The user approved Phase 1C visually and refreshed the Studio mirror at
`2026-07-13 15:33:06`. The mirror contains both Phase 1C source markers and the
`ArrowsThumbstickTiltPhase1C` / `Phase1CLayoutRefinement` version attributes.

## Installer

Run this whole file in the Roblox Studio Command Bar while in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

Phase 1D canonically replaces the same two isolated mobile owners. It does not
edit the confirmed PC controller, register-limited bootstrap, server vehicle
actions, driving physics, VFX, or LOD.

## Behavior

- Opens a responsive left-side `MY VEHICLES` panel beneath Roblox's built-in
  top controls.
- Reuses the PC vehicle/profile fields, category extraction, `RATING | PRICE |
  A-Z` sorting, tier colours, selected state, two-column cards, vehicle images,
  Buy More flow, spawn action, and Despawn action.
- Keeps the map, cash, and top game actions visible.
- Places a fully transparent outside-tap layer above the world and top game HUD,
  so none of them darken or accept input while the menu is open.
- Tapping anywhere outside the car panel closes it.
- Sets `NTRMobileFreeRoamCarMenuOpen` while open. The isolated control owner
  clears held input and hides arrows/thumbstick/Tilt controls, boost, and pedals;
  the HUD owner hides speed/boost telemetry and Exit.
- Closing restores the driving UI if the player remains in driving state.
- Successful spawn and Despawn close the panel. Failed spawn leaves it open and
  displays the existing error toast.

Editable sizing lives under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
```

Phase 1D adds `CarMenuWidth`, `CarMenuWidthRatio`, `CarMenuTop`,
`CarMenuBottomMargin`, and `CarMenuCardGap`.

## Verification

1. Stop Play and run the canonical installer in Edit mode.
2. Start a fresh landscape Device Emulator session.
3. Confirm Output prints the Phase 1D installer plus both Phase 1D client startup
   messages with no assertion or runtime error.
4. Tap Car while on foot. Confirm a scaled PC-style two-column panel appears on
   the left beneath Roblox's controls without darkening the world.
5. Confirm map, cash, and game action buttons remain visible but tapping them
   closes the car menu without triggering their actions.
6. Test Category and Sort dropdowns, scrolling, selected vehicle styling, tier
   colours, Buy More, spawn/swap, spawn failure feedback, and Despawn.
7. Open the menu while driving. Confirm all driving UI disappears immediately,
   held throttle/steer/boost is released, and the top HUD stays visible.
8. Tap outside the panel. Confirm the menu closes and driving UI returns.
9. Recheck all three steering modes, Exit, map parity, garage, race browser, and
   dealership teleport after the menu closes.
10. Repeat at a small-phone and tablet landscape size.

## Rollback

Restore the two Phase 1C mobile controller sources from the `15:33:06` mirror.
Do not rerun the old thumbstick patch ladder and do not patch the bootstrap.

After confirmation, refresh the Studio mirror again. Commit generated changes
under `roblox/exported_scripts/` and `roblox/studio_snapshot/`, but do not commit
`docs/studio-full-export-paste.txt`.
