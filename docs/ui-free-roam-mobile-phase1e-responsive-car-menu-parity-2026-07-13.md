# Mobile Free-Roam UI Phase 1E Responsive Car Menu Parity

**Date:** 2026-07-13  
**Status:** Generated from installed Phase 1D screenshot evidence; awaiting Studio rerun and Device Emulator confirmation

## Reported Phase 1D Result

Phase 1D worked overall, including the left-side menu, outside-tap behavior, top
HUD blocking, and driving-UI suppression. Screenshot review found three visual
issues:

- card height was derived only from two-column width, so the second row extended
  beyond the clipped scrolling viewport;
- cards were much larger than required and fewer than three rows were visible;
- expanded dropdown choices used the general mobile pink-outlined button style
  instead of the PC borderless neutral surface and gradients.

The repository mirror still stops at the approved Phase 1C export from
`15:33:06`. Phase 1E therefore guards against the installed Phase 1D source
marker and canonically replaces the same isolated owners.

## Installer

Run the complete canonical installer in the Roblox Studio Command Bar while in
Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

## Responsive Fit Repair

Phase 1E reserves the header, dropdown row, compact Despawn footer, footer gap,
and card safety padding before calculating the grid. It then:

1. calculates the maximum two-column width;
2. calculates the maximum card height that allows three complete visible rows;
3. converts that height through the PC `0.88` card aspect ratio;
4. uses the smaller width result;
5. centres the two columns;
6. builds scroll canvas height from `UIGridLayout.AbsoluteContentSize` plus the
   PC-style top and bottom safety padding.

The scrolling frame extends outward by the configured stroke-safe inset so card
strokes and glow cannot be clipped at the left, right, or top edges. Despawn is
reduced from 42px to 32px by default.

## PC Surface Parity

The car menu now reads the confirmed PC `DesktopFreeRoamHud.Effects` values and
ports its car-menu-specific visual helpers:

- panel `PanelSoft -> PanelDeep` surface gradient;
- card/button gradient strength and rotation;
- panel facet pattern;
- PC glow transparency;
- selected/unselected card stroke thickness;
- soft collapsed dropdown treatment;
- borderless, glow-free expanded dropdown choice rows inside a neutral
  `PanelSoft -> Panel` gradient surface;
- gradient treatment on Buy More and the smaller Despawn button.

These additions are scoped to the mobile car menu. They do not restyle the map,
telemetry, controls, cash, settings, or other modal surfaces.

## Config

Editable attributes remain under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
```

Phase 1E adds:

- `CarMenuVisibleRows` (`3`)
- `CarMenuCardAspect` (`0.88`)
- `CarMenuCardTopSafePadding` (`8`)
- `CarMenuCardBottomSafePadding` (`8`)
- `CarMenuCardStrokeSafePadding` (`5`)
- `CarMenuDespawnHeight` (`32`)
- `CarMenuFooterGap` (`8`)

## Verification

1. Stop Play and run the installer in Edit mode.
2. Start a fresh mobile Device Emulator session at the previously reported
   landscape size.
3. Confirm Output prints the Phase 1E installer and both Phase 1E startup
   messages without an assertion or runtime error.
4. Open the car menu and confirm three complete card rows fit above Despawn.
5. Confirm no card border, glow, badge, image, or name is clipped at any edge.
6. Confirm Despawn is visibly shorter and remains fixed below the scrolling grid.
7. Open Category and Sort. Confirm the choice surface and rows have no pink
   borders/glow and match the PC dark gradients and corner treatment.
8. Compare car panel, card, Buy More, selected card, dropdown, and Despawn
   gradients with the PC reference.
9. Recheck scrolling with more than six cards, Category/Sort behavior, spawn,
   failed spawn, Despawn, outside-tap close, top-HUD blocking, and driving-UI
   suppression/restoration.
10. Repeat at small-phone and tablet landscape sizes.

## Rollback

Restore both installed Phase 1D mobile controller sources. Do not patch the PC
controller or bootstrap and do not rerun the retired thumbstick patch ladder.

After confirmation, refresh the full Studio mirror and commit generated changes
under `roblox/exported_scripts/` and `roblox/studio_snapshot/`. Do not commit
`docs/studio-full-export-paste.txt`.
