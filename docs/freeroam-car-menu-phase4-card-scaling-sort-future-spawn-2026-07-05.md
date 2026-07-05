# Free Roam Car Menu Phase 4

Superseded for image fit/border polish by Phase 5: `scripts/roblox_freeroam_car_menu_phase5_image_fit_border_padding.lua` keeps the Phase 4 columns, sorting, and future attributes but replaces zoomed images with fitted images plus fixed inner padding.

## Purpose

Phase 4 polishes the free-roam `Car` pop-out after the first Studio test:

- enlarges cockpit images inside their square frames;
- changes desktop/laptop layout to 3 cockpit cards across;
- changes mobile layout to 2 cockpit cards across;
- removes text glow from the tier/rating badge text in this menu;
- removes the cyan/blue selected-card outline by using the normal pink button outline;
- sorts vehicles by rating only, highest rated first;
- adds future spawn/select metadata to each card.

## Studio Script

```text
scripts/roblox_freeroam_car_menu_phase4_card_scaling_sort_future_spawn.lua
```

Run in Studio Edit mode after Free Roam Car Menu Phase 3.

## Config

The script updates these values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

- `CarPanelWidthDesktop = 600`
- `CarPanelWidthTouch = 330`
- `CarPanelDesktopColumns = 3`
- `CarPanelMobileColumns = 2`
- `CarPanelMaxCardWidthDesktop = 190`
- `CarPanelMaxCardWidthTouch = 160`
- `CarPanelImageZoom = 1.28`
- `CarPanelClickAction = "PreviewOnly"`

`CarPanelClickAction` is a future hook. This phase does not spawn or switch vehicles yet.

## Future Spawn / Despawn Prep

Each card now gets attributes:

- `VehicleId`
- `CockpitId`
- `IsCurrentVehicle`
- `FreeRoamVehicleAction`

The next phase can use those attributes to call a real spawn/select action without parsing UI text.

## Verification

1. Run the Phase 4 script in Studio Edit mode.
2. Restart Play.
3. Open the free-roam `Car` pop-out.
4. Verify cockpit images fill their frames better.
5. Verify desktop/laptop shows 3 cockpit cards across when there is room.
6. Verify mobile shows 2 cockpit cards across.
7. Verify tier/rating badge text has no outer glow.
8. Verify card outlines are no longer blue/cyan.
9. Verify vehicles sort by rating descending, highest rated top-left.
10. Verify `Despawn` still works as before.

## Risk / Rollback

This is a guarded source-text patch against the isolated free-roam nav controller. If it cannot find the Phase 3 marker or exact source blocks, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
