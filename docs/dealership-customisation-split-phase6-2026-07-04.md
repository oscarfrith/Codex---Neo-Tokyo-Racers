# Dealership / Customisation Split Phase 6

Date: 2026-07-04

## Purpose

Phase 6 repairs and polishes the cockpit menu image work from Phase 5:

- cockpit images are looked up from the live cockpit model as well as the catalogue row;
- image lookup accepts `MenuImage` attributes, matching `StringValue`s, and matching `Decal` / `Texture` / `ImageLabel` objects;
- dealership and customisation cockpit cards use a square thumbnail box;
- cockpit card size, thumbnail size, text positions, and free-roam car-icon scale are configurable;
- the duplicate `C 538` style rating above the right-panel `Customise` button is removed.

## Studio Script

Run this in Roblox Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase6_square_images.lua
```

## Config Values

The script creates:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Useful values:

- `CardWidth`
- `CardHeight`
- `UseResponsiveGridWidth`
- `ImageBoxX`
- `ImageBoxY`
- `ImageBoxSize`
- `ImageInnerPadding`
- `ImageScaleType` (`Fit` or `Crop`)
- `NameY`
- `PriceY`
- `TierBadgeY`
- `RatingY`
- `FreeRoamCarIconScale`

Default layout keeps the old thumbnail width (`100` logical pixels inside the 118-wide card) but makes the box square.

## Where Images Can Live

Preferred:

```text
COCKPIT_MODEL.MenuImage = rbxassetid://YOUR_IMAGE_ID
```

Also accepted:

- cockpit attribute named `CockpitImage`, `ThumbnailImage`, `ImageId`, or `Image`;
- child `StringValue` with one of those names;
- child/descendant `Decal`, `Texture`, `ImageLabel`, or `ImageButton` whose name contains `MenuImage`, `CockpitImage`, or `Thumbnail`.

## Verification

1. Run the Phase 6 script in Edit mode.
2. Confirm `ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards` exists.
3. Set `MenuImage` on a cockpit model, preferably `rbxassetid://...`.
4. Restart Play.
5. Verify the dealership card uses a square image box and shows the cockpit image.
6. Verify the customisation duplicate-owned card uses the same image and still shows tier/rating inside the card.
7. Select a cockpit in customisation and confirm the right panel no longer shows the duplicate rating above `Customise`.
8. Return to free roam and confirm the car button uses the same current cockpit image.

## Register Limit Repair

The first Phase 6 install could make Play fail with:

```text
Out of local registers when trying to allocate init: exceeded limit 200
```

Root cause: the active client bootstrap was already close to Roblox's top-level local-register limit, and Phase 6 added more top-level `local function` helpers.

Run this in Studio Edit mode if that error appears:

```text
scripts/roblox_dealership_customisation_split_phase6_register_limit_repair.lua
```

The repair keeps the same image/card behavior but moves the Phase 6 helper functions off top-level locals. The main Phase 6 installer in Git has also been updated to use the register-safe helper style for future installs.

For the later responsive 4-wide desktop / 3-wide mobile cockpit grid, run:

```text
scripts/roblox_dealership_customisation_split_phase7_responsive_cockpit_grid.lua
```

## Risk And Rollback

This is still a guarded text patch against the large active dealership bootstrap plus the isolated free-roam nav controller. If it stops, use the exact Studio Output rather than rerunning older image scripts.

Rollback is Roblox version history, or set `MenuImage` empty and use the config values to shrink/reset the cards. If the register-limit repair cannot find the Phase 6 marker, refresh the Studio mirror before creating another patch.
