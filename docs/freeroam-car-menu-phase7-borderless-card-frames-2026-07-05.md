# Free Roam Car Menu Phase 7

## Purpose

Phase 7 removes the remaining clipped cockpit-card border issue by no longer using `UIStroke` for the free-roam car-menu cockpit cards or image boxes.

Instead, the card uses normal filled frames:

- transparent outer grid/click cell;
- pink `CardSurface` border frame;
- inset `CardFill` content frame;
- pink `ImageBox` border frame;
- inset `ImageFill` image frame.

This avoids the Roblox `UIStroke` half-inside/half-outside rendering behavior that can look clipped inside scroll/grid layouts.

Phase 7 also narrows the default car pop-out so it fits the intended number of cards:

- desktop/laptop: 3 compact cards wide;
- mobile: 2 compact cards wide.

## Studio Script

```text
scripts/roblox_freeroam_car_menu_phase7_borderless_card_frames_compact_width.lua
```

Run in Studio Edit mode after Free Roam Car Menu Phase 6.

## Config

The script updates these values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

- `CarPanelWidthDesktop = 512`
- `CarPanelWidthTouch = 260`
- `CarPanelDesktopColumns = 3`
- `CarPanelMobileColumns = 2`
- `CarPanelMaxCardWidthDesktop = 160`
- `CarPanelMaxCardWidthTouch = 118`
- `CarPanelDesktopImageMaxSize = 144`
- `CarPanelMobileImageMaxSize = 88`
- `CarPanelBorderThickness = 2`

## Verification

1. Run the Phase 7 script in Studio Edit mode.
2. Restart Play.
3. Open the free-roam `Car` pop-out.
4. Verify the odd/clipped cockpit-card border is gone.
5. Verify the panel is not wider than needed for 3 compact PC cards.
6. Verify mobile still fits 2 cards wide.
7. Verify image/text padding still looks even.
8. Verify `Despawn` still works.

## Risk / Rollback

This is a guarded source-text patch against the isolated free-roam nav controller. If it cannot find the Phase 6 marker or exact source blocks, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
