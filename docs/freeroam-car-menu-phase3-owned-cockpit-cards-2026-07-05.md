# Free Roam Car Menu Phase 3

Superseded for layout polish by Phase 4: `scripts/roblox_freeroam_car_menu_phase4_card_scaling_sort_future_spawn.lua` keeps the owned-card direction but enlarges images, changes the column counts, removes badge glow/blue outlines, sorts by rating, and adds future spawn/select attributes.

## Purpose

Phase 3 changes the free-roam `Car` pop-out into an owned-vehicle overview:

- uses dealership/customisation-style cockpit image cards;
- shows owned cockpit instances with per-vehicle tier/rating badges;
- shows 2 cockpit cards across on desktop/laptop;
- shows 1 cockpit card across on mobile;
- removes the old vehicle id text, `Exit Vehicle`, and `Customise` buttons;
- hides the car-panel bevel bars so the card grid feels cleaner;
- adds a fixed bottom `Despawn` button.

This stays inside the isolated `FreeRoamNavController_Active` script and does not patch the large dealership/customisation bootstrap.

## Studio Script

```text
scripts/roblox_freeroam_car_menu_phase3_owned_cockpit_cards.lua
```

Run in Studio Edit mode after the current free-roam map stack/controller is installed.

## Config

The script adds/touches these values under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

- `CarPanelWidthDesktop`
- `CarPanelWidthTouch`
- `CarPanelMinWidthDesktop`
- `CarPanelMinWidthTouch`
- `CarPanelCardGap`
- `CarPanelPadding`
- `CarPanelBottomPadding`
- `CarPanelDespawnHeight`
- `CarPanelDesktopColumns`
- `CarPanelMobileColumns`
- `CarPanelMaxCardWidthDesktop`
- `CarPanelMaxCardWidthTouch`
- `CarPanelImageToTextGap`
- `CarPanelCardBottomPadding`

The cards also reuse existing cockpit card/image values from:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

## Verification

1. Run the Phase 3 script in Studio Edit mode.
2. Restart Play.
3. Click the free-roam `Car` button.
4. Verify the pop-out shows owned cockpit cards instead of the old vehicle id/action buttons.
5. On desktop/laptop, verify the panel is wide enough for 2 cards across.
6. On mobile, verify the panel uses 1 card across and scrolls if needed.
7. Verify each card uses the cockpit image and the same per-vehicle tier/rating values seen in customisation.
8. Verify `Despawn` stays fixed at the bottom and still exits/despawns the current vehicle.

## Notes

The cockpit cards are informational in this phase. Clicking a non-current card shows a status hint instead of changing the active vehicle. Vehicle switching/customising should remain in the customisation zone unless a later phase deliberately adds free-roam vehicle selection.

## Risk / Rollback

This is a guarded source-text patch against the isolated free-roam nav controller. If it cannot find the expected anchors, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
