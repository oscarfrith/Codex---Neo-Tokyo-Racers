# Dealership / Customisation Split Phase 8

Superseded visually by Phase 9: `docs/dealership-customisation-split-phase9-2026-07-05.md`.

Date: 2026-07-04

## Purpose

Phase 8 polishes the responsive cockpit cards after the first Phase 7 test:

- image boxes fill the card width with equal left/right padding;
- card height is calculated from image, title/rating row, price row, and bottom padding instead of using the old tall ratio;
- dealership cards show the base cockpit tier/rating on the title row at the right;
- owned/customisation cards keep their per-vehicle tier/rating on the title row at the right;
- desktop/laptop still targets 4 cards across and mobile still targets 3 cards across.

## Studio Script

Run this in Roblox Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase8_compact_card_polish.lua
```

This is a guarded source patch against the active client bootstrap. It expects the Phase 6/7 cockpit-card markers and only replaces the cockpit card sizing/render helper path plus the card title/price render lines.

## Config Values

The script adds/updates values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Useful values:

- `CardOuterPadding`
- `ImageInnerPadding`
- `ImageZoom`
- `ImageToTextGap`
- `NameHeight`
- `NameTextSize`
- `PriceLineGap`
- `CardBottomPadding`
- `RatingTotalWidth`
- `RatingBadgeWidth`
- `RatingBadgeHeight`
- `RatingGap`
- `RatingTextSize`
- `DesktopColumns`
- `MobileColumns`

`DesktopMaxCardWidth` and `MobileMaxCardWidth` are set high enough that the requested column counts can fill the main grid width. `ImageZoom` defaults to `1`; raise it slightly, for example `1.08`, if an uploaded cockpit image has transparent margins and needs to sit larger inside the square frame.

## Verification

1. Run the Phase 8 script in Edit mode.
2. Restart Play.
3. On mobile, confirm 3 cards fit across and the cockpit image has a similar left/right buffer inside its square frame.
4. On PC/laptop, confirm 4 cards fit across the main frame.
5. Confirm cards no longer leave a large empty area below the cost.
6. Confirm the title row shows cockpit name on the left and tier/rating on the right.
7. Confirm selected card colour, Buy / Buy Another, customisation duplicate cards, and vertical scrolling still work.

## Risk And Rollback

This is a guarded patch against the large active client bootstrap. If it cannot find the Phase 6/7 markers or card render lines, refresh the Studio mirror before another layout patch.

Rollback is Roblox version history. For softer tuning, adjust the `CockpitMenuCards` values listed above.
