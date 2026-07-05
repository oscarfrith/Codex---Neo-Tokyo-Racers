# Free Roam Car Menu Phase 5

Superseded for the clipped/odd card-border root fix by Phase 6: `scripts/roblox_freeroam_car_menu_phase6_card_surface_root_fix.lua` separates the transparent grid click cell from the visible card surface so UIStroke and grid sizing no longer fight each other.

## Purpose

Phase 5 polishes the free-roam `Car` pop-out after Phase 4:

- cockpit images use `Enum.ScaleType.Fit`;
- images use a fixed small inner padding instead of zooming beyond the frame;
- image boxes use the same pink outline style as the other free-roam frames;
- legacy tier-coloured/cyan selected-card outlines are repaired if still present;
- the card scroll area starts with the same top padding as the side padding;
- the `Despawn` button bottom offset matches the side padding.

This keeps the Phase 4 column counts, sorting, and future spawn/select attributes.

## Studio Script

```text
scripts/roblox_freeroam_car_menu_phase5_image_fit_border_padding.lua
```

Run in Studio Edit mode after Free Roam Car Menu Phase 4.

## Config

The script updates these values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

- `CarPanelImageZoom = 1`
- `CarPanelImageFitScale = 1`
- `CarPanelImageInnerPadding = 5`
- `CarPanelBottomPadding = 8`

Use `CarPanelImageInnerPadding` for the image/frame offset. Avoid raising `CarPanelImageFitScale` above `1`, because that can reintroduce clipping.

## Verification

1. Run the Phase 5 script in Studio Edit mode.
2. Restart Play.
3. Open the free-roam `Car` pop-out.
4. Verify cockpit images are fully visible inside their frames with an even small inset.
5. Verify card/image borders match the other pink free-roam frame borders.
6. Verify the `Despawn` button sits slightly lower and its bottom offset matches the side offset.
7. Recheck desktop and mobile sizing.

## Risk / Rollback

This is a guarded source-text patch against the isolated free-roam nav controller. If it cannot find the Phase 4 marker or exact source blocks, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
