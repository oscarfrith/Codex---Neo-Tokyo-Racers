# Dealership / Customisation Split Phase 3

**Date:** 2026-07-04  
**Status:** Prepared in Git; first install exposed a summary helper repair  
**Script:** `scripts/roblox_dealership_customisation_split_phase3_instance_cards.lua`
**Repair:** `scripts/roblox_dealership_customisation_split_phase3_vehicle_summary_repair.lua`

## Goal

Refine the separate customisation menu so duplicate owned cockpits appear as separate cards instead of being grouped under one cockpit template.

Phase 3:

- adds `Profile.VehicleSummaries` to the garage profile response;
- renders one customisation card per owned vehicle instance;
- removes the `Owned xN` text from customisation-mode cockpit cards;
- shows each vehicle instance's tier and performance index, for example `A 920`;
- sends `VehicleId` to `SelectVehicleInstance` so duplicate cockpits open the correct owned vehicle.

## Implementation Notes

The dealership itself remains buy-only from Phase 1. This phase changes only the customisation-mode cockpit grid introduced in Phase 2.

The server summary is lightweight and derived during `V56_profileForClient`. It temporarily syncs each owned vehicle into the legacy profile fields, calculates the existing Phase AO performance result, stores only the summary fields needed by the client, then restores the original selected vehicle state.

If a vehicle summary cannot be calculated, the UI falls back to `-- ---` instead of blocking the menu.

The first Studio install exposed a nil call inside `V90_vehicleSummaries`: the helper was inserted before `V56_totalStats` was lexically visible in the live server source. The repair script adds a compact local summary-total fallback and updates the Phase 3 installer so future installs use `V90_summaryTotals(profile)` instead of directly calling `V56_totalStats(profile)`.

## Studio Steps

1. Confirm Phase 2 has already been run and tested.
2. In Studio Edit mode, run:

```text
scripts/roblox_dealership_customisation_split_phase3_instance_cards.lua
```

If the first install has already been run and entering/opening customisation reports an error in `V90_vehicleSummaries`, run this repair in Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase3_vehicle_summary_repair.lua
```

3. Restart Play.
4. Own two copies of the same cockpit.
5. Open the customisation zone.

## Manual Verification

- Duplicate owned cockpits appear as separate cards.
- Customisation cards no longer show `Owned xN`.
- Each customisation card shows a rating like `A 920`.
- Selecting a duplicate card and pressing `Customise` opens that specific vehicle instance.
- Switching categories still filters to owned vehicle instances in that category.
- Dealership buy mode still shows cockpit templates with price text.
- Start Driving still spawns the selected/customised vehicle.

## Rollback

Use Roblox version history for the Studio-side source changes.

Manual rollback points:

- remove the `VehicleSummaries = V90_vehicleSummaries(profile)` response field;
- remove the Phase 3 `V90_*` helper block from the garage action controller;
- restore the Phase 2 `renderDealershipPanel` and `renderCockpitShop` blocks in the active bootstrap.
