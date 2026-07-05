# Dealership / Customisation Split Phase 11

## Purpose

Phase 11 changes only menu ordering:

- dealership cockpit cards sort by price from lowest to highest;
- customisation owned-cockpit cards sort by vehicle rating from highest to lowest;
- category buttons sort alphabetically by display name.

The existing card layout, images, badges, stats panel, and buy/customise behavior are unchanged.

## Studio Script

```text
scripts/roblox_dealership_customisation_split_phase11_sorted_cockpit_cards.lua
```

Run in Studio Edit mode after the Phase 10 layout polish.

## Ordering Rules

Dealership:

- primary sort: `Price`, ascending;
- tie-breakers: cockpit display name, then cockpit id.

Customisation:

- primary sort: `VehicleSummaries[VehicleId].Overall.PerformanceIndex`, descending;
- tie-breakers: cockpit display name, then vehicle id.

Categories:

- primary sort: category display name, ascending;
- tie-breaker: category id.

The grid then fills in normal Roblox UI order: left-to-right across the row, then top-to-bottom.

## Verification

1. Run the Phase 11 script in Studio Edit mode.
2. Restart Play.
3. Open dealership and verify the cheapest cockpit is top-left and the most expensive cockpit is last.
4. Add/select multiple owned cockpits, enter the customisation zone, and verify the highest-rated vehicle instance is top-left.
5. If more categories are added, verify their buttons are alphabetical.
6. Confirm existing actions still work: `Buy`, `Buy Another`, cockpit selection, customisation entry, and Exit.

## Risk / Rollback

This is a guarded source-text patch against the active client bootstrap. It patches the render order only, but the bootstrap is large and sensitive, so if an anchor is missing, refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
