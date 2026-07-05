# Dealership / Customisation Split Phase 7

Date: 2026-07-04

## Purpose

Phase 7 makes the cockpit-card grid responsive:

- desktop/laptop shows 4 cockpit cards per row by default;
- mobile shows 3 cockpit cards per row by default;
- extra cockpits continue vertically in the existing scroll area;
- card image/text/badge proportions scale from the calculated card width.

## Studio Script

Run this in Roblox Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase7_responsive_cockpit_grid.lua
```

This is a guarded source patch against the active client bootstrap. It replaces the Phase 6 cockpit-card helper block with a register-safe responsive version and changes the grid-size call to pass the visible grid width.

## Config Values

The script adds/updates values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Key values:

- `DesktopColumns` default `4`
- `MobileColumns` default `3`
- `DesktopMinCardWidth`
- `DesktopMaxCardWidth`
- `MobileMinCardWidth`
- `MobileMaxCardWidth`
- `ResponsiveCardScaleEnabled`
- `GridCellPadding`

The existing Phase 6 values such as `ImageBoxSize`, `NameY`, `PriceY`, `TierBadgeY`, and `RatingY` are treated as base proportions and scale with the card width while `ResponsiveCardScaleEnabled` is true.

## Verification

1. Run the Phase 7 script in Edit mode.
2. Restart Play.
3. On desktop/laptop, open dealership and confirm 4 cockpit cards fit across the main grid.
4. Open the customisation zone and confirm owned cockpit cards also use 4 across on desktop/laptop.
5. Test mobile/emulator and confirm 3 cards fit across.
6. Confirm extra cards scroll vertically rather than squeezing into more columns.
7. Confirm cockpit images, tier badges, rating text, names, and prices remain proportionate.

## Risk And Rollback

This depends on the Phase 6 helper marker in the active bootstrap. If the script cannot find the marker or grid-size call, refresh the Studio mirror before another layout patch.

Rollback is Roblox version history. For softer tuning, adjust `DesktopColumns`, `MobileColumns`, min/max card widths, or disable `ResponsiveCardScaleEnabled`.

## Superseded By Phase 8

The first Phase 7 screenshots showed the column counts were directionally right, but PC cards kept too much vertical space below the cost and image padding needed another pass. Run `scripts/roblox_dealership_customisation_split_phase8_compact_card_polish.lua` after Phase 7 for the current card layout baseline.
