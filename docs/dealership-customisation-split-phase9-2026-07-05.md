# Dealership / Customisation Split Phase 9

Superseded visually by Phase 10: `docs/dealership-customisation-split-phase10-2026-07-05.md`.

## Purpose

Phase 9 polishes the cockpit-card UI after the Phase 8 Studio test:

- moves tier/rating into one wider coloured badge in the top-right corner of the cockpit image;
- keeps the badge above the image layer;
- tightens image/name/price/bottom gaps so cards fit their content more closely;
- makes cockpit-card text scale in a smaller range so desktop cards do not create oversized spacing;
- makes dealership-card ratings use the same included-default-module stats path as the right stats panel;
- restores the free-roam car button to `FreeRoamNav.CarIcon` by default, keeping cockpit `MenuImage` for dealership/customisation/owned-car menus.

## Studio Script

```text
scripts/roblox_dealership_customisation_split_phase9_badge_overlay_tight_cards.lua
```

Run in Studio Edit mode after Phase 8 has been installed.

## Config

The script updates:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Useful Phase 9 values:

- `CardOuterPadding`
- `ImageInnerPadding`
- `ImageZoom`
- `ImageToTextGap`
- `NameHeight`
- `NameTextSize`
- `PriceLineGap`
- `CardBottomPadding`
- `RatingBadgeWidth`
- `RatingBadgeHeight`
- `RatingBadgeTopInset`
- `RatingBadgeRightInset`
- `RatingTextSize`
- `BadgeCornerRadius`
- `FreeRoamUsesCockpitMenuImage`

`FreeRoamUsesCockpitMenuImage` defaults to `false`, so the free-roam car button uses the plain configured `FreeRoamNav.CarIcon`. Set it to `true` only if the free-roam button should show the current cockpit thumbnail again later.

## Verification

1. Run the Phase 9 script in Edit mode.
2. Restart Play.
3. Open dealership on desktop/laptop and mobile.
4. Verify cockpit cards still fit 4 across on desktop/laptop and 3 across on mobile.
5. Verify the tier/rating badge sits inside the cockpit image's top-right corner and is not clipped.
6. Verify dealership card badge values match the right stats panel for the same cockpit.
7. Verify owned/customisation card badge values still match each specific owned vehicle instance.
8. Verify image/name/price/bottom gaps are tighter and closer to the rest of the dealership UI spacing.
9. Verify the free-roam car button shows the configured plain white car icon, not the cockpit `MenuImage`.

## Risk / Rollback

This is a guarded source patch against the active client bootstrap and the isolated free-roam nav controller. If it cannot find the Phase 8 marker or the free-roam helper anchors, stop and refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
