# Free Roam Car Menu Phase 6

Superseded for the remaining clipped-border issue by Phase 7: `scripts/roblox_freeroam_car_menu_phase7_borderless_card_frames_compact_width.lua` removes `UIStroke` from cockpit-card/image borders entirely and uses filled border frames instead.

## Purpose

Phase 6 is the root fix for the odd/clipped cockpit-card border in the free-roam `Car` pop-out.

The likely cause was structural: the clickable grid cell was also carrying the visible card background and `UIStroke`, while the grid/scroll layout could clip or stretch that same object. Phase 6 separates those responsibilities:

- the outer clickable grid cell is transparent and has no visible border;
- an inner `CardSurface` frame owns the visible background and pink border;
- the card surface wraps the cockpit image plus name text instead of filling a large empty grid cell;
- image boxes use the same pink border style;
- desktop keeps the larger image size;
- mobile image max size is reduced slightly;
- the menu frame width and card sizing still use the Phase 4/5 responsive column setup;
- `VehicleId`, `CockpitId`, and future spawn/select attributes are preserved.

## Studio Script

```text
scripts/roblox_freeroam_car_menu_phase6_card_surface_root_fix.lua
```

Run in Studio Edit mode after Free Roam Car Menu Phase 5.

## Config

The script updates these values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

- `CarPanelWidthDesktop = 600`
- `CarPanelWidthTouch = 290`
- `CarPanelDesktopColumns = 3`
- `CarPanelMobileColumns = 2`
- `CarPanelMaxCardWidthDesktop = 190`
- `CarPanelMaxCardWidthTouch = 132`
- `CarPanelDesktopImageMaxSize = 174`
- `CarPanelMobileImageMaxSize = 104`
- `CarPanelImageInnerPadding = 5`

## Verification

1. Run the Phase 6 script in Studio Edit mode.
2. Restart Play.
3. Open the free-roam `Car` pop-out.
4. Verify the cockpit-card border is no longer clipped or doubled.
5. Verify the visible card frame wraps the cockpit image and name with consistent padding.
6. Verify desktop/laptop still shows 3 columns where there is room.
7. Verify mobile shows 2 columns with slightly smaller cockpit images.
8. Verify `Despawn` still sits with even side/bottom padding.

## Risk / Rollback

This is a guarded source-text patch against the isolated free-roam nav controller. If it cannot find the Phase 5 marker or exact source blocks, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
