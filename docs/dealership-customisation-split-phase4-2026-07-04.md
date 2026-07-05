# Dealership / Customisation Split Phase 4

**Date:** 2026-07-04  
**Status:** Prepared in Git for Studio install/testing  
**Script:** `scripts/roblox_dealership_customisation_split_phase4_rating_badge_build_modules.lua`

## Goal

Polish the owned-cockpit customisation menu after Phase 3:

- fix the per-instance rating so it follows the same total-stat shape as the normal garage profile;
- add a colour-coded tier badge on each owned vehicle card;
- make the customisation-zone action open Build Modules / ModuleShop instead of the final Customise colour screen.

## Implementation Notes

Phase 3's summary repair avoided the nil `V56_totalStats` call, but its fallback total calculation was too rough and could show a rating that did not match the actual cockpit/build. Phase 4 replaces that fallback with a local copy of the main `V56_totalStats` logic shape: cockpit base stats, installed module template stats, and legacy invisible upgrade stats.

The card UI now splits the rating into:

- a small tier badge using the existing Phase AO tier colours;
- the numeric performance index beside it.

The right-side action button in customisation mode changes from `Customise` to `Build Modules` and opens `ModuleShop` with `ModuleMode = "Slots"`.

## Studio Steps

1. Confirm Phase 3 and the Phase 3 summary repair have been run if needed.
2. In Studio Edit mode, run:

```text
scripts/roblox_dealership_customisation_split_phase4_rating_badge_build_modules.lua
```

3. Restart Play.
4. Open the customisation zone.

## Manual Verification

- Each owned cockpit instance card shows a tier badge plus rating number.
- The rating matches the expected cockpit/build rating shown elsewhere for that vehicle.
- Duplicate cockpits still appear as separate cards.
- The customisation-mode right panel says `Build Modules`.
- Pressing `Build Modules` opens the module build menu, not the final colour/customise screen.
- Buying/equipping modules still works.
- Start Driving still spawns the selected/customised vehicle.

## Rollback

Use Roblox version history for Studio-side source changes.

Manual rollback points:

- restore the previous Phase 3 `V90_summaryTotals` function;
- restore the Phase 3 rating-card line in `renderCockpitShop`;
- restore the Phase 3 right-panel `Customise` action if you want to open the final customisation screen directly again.
