# Mobile Free-Roam UI Phase 1F Fitted Car Menu Layout

**Date:** 2026-07-13  
**Status:** Generated from installed Phase 1E screenshot evidence; awaiting Studio rerun and Device Emulator confirmation

## Phase 1E Finding

Phase 1E corrected clipping and PC dropdown/gradient parity, but treating the
earlier request as three complete grid rows forced the cards down to roughly
`120 x 105` at the reported viewport. The cards became too small while the
fixed-width panel retained unused horizontal space.

Phase 1F changes the fitting priority to two complete rows, which keeps at least
three individual cards visible and allows an approximately `1.5x` card increase.

## Installer

Run the complete canonical installer in the Roblox Studio Command Bar while in
Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer requires the live Phase 1E marker and canonically replaces the
same isolated mobile owners. It does not patch the PC controller, bootstrap,
server gameplay, driving physics, VFX, or LOD.

## Fitted Layout

At the reported `1350 x 613`-class viewport, the default calculation produces:

- cards near `180 x 158`;
- a panel near `378px` wide;
- two complete visible rows;
- panel width equal to two card widths, one card gap, and compact side padding.

The solver still constrains cards by viewport width and available two-row height
on smaller devices. It no longer derives card size from a preselected 430px
panel width.

Additional compaction:

- panel moves to 3px from the left and 2px from the bottom by default;
- title uses a 24px compact header area and smaller text;
- dropdowns reduce from 48px to 36px;
- Despawn reduces from 32px to 26px;
- card gap reduces to 6px;
- footer gap reduces to 4px;
- card top/bottom safety padding reduces to 4px while the 5px stroke-safe inset
  remains;
- image, badge, fallback, name, plus, and Buy More spacing is tightened.

Phase 1E PC gradients, card strokes/glow, facet pattern, and borderless choice
rows remain unchanged.

## Dropdown Toggle

The menu now tracks `carChoiceAnchor`:

- tapping the currently open Category or Sort field closes it;
- tapping the other field replaces the open list;
- selecting a choice, closing the car menu, or tapping outside clears both the
  list and its owner.

## Config

Editable attributes live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud
```

New Phase 1F controls:

- `CarMenuTargetCardWidth` (`180`)
- `CarMenuPanelPadding` (`6`)
- `CarMenuHeaderHeight` (`72`)
- `CarMenuDropdownHeight` (`36`)
- `CarMenuLeftMargin` (`3`)
- `CarMenuMaxWidthRatio` (`0.42`)

The installer migrates untouched Phase 1E layout defaults to the Phase 1F
values while preserving any values that were already manually customised.

## Verification

1. Stop Play and run the installer in Edit mode.
2. Start a fresh mobile Device Emulator session at the reported landscape size.
3. Confirm Output prints the Phase 1F installer and both Phase 1F startup
   messages without an assertion or runtime error.
4. Confirm cards are approximately `1.5x` larger and two complete rows remain
   above Despawn.
5. Confirm the panel width wraps its two card columns without a large empty
   right-hand region.
6. Confirm title, dropdowns, Despawn, internal card spacing, and component gaps
   are visibly tighter.
7. Confirm the panel sits close to the left and bottom edges without clipping its
   outer glow.
8. Open Category, then tap Category again; it must close. Repeat for Sort, then
   confirm tapping the other field switches lists.
9. Recheck all Phase 1E gradients, borderless choices, card edges, scrolling,
   spawn/despawn, outside-tap, top-HUD blocking, and driving-UI restoration.
10. Repeat at small-phone and tablet landscape sizes.

## Rollback

Restore both installed Phase 1E mobile controller sources. Do not patch the PC
controller or bootstrap and do not rerun the retired thumbstick patch ladder.

After confirmation, refresh the full Studio mirror. Commit generated changes
under `roblox/exported_scripts/` and `roblox/studio_snapshot/`, but do not commit
`docs/studio-full-export-paste.txt`.
