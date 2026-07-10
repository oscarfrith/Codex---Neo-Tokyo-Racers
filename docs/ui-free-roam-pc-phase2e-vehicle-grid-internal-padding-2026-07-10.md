# PC Free-Roam UI Phase 2E Vehicle Grid Internal Padding

Date: 2026-07-10  
Status: Installed but ineffective visually; superseded by Phase 2F

## Root cause

`VehicleGrid` must keep `ClipsDescendants = true` so vehicle cards do not draw over the dropdown header while scrolling. Its `UIGridLayout`, however, placed the first row at local `Y = 0`. The card border and four-pixel outer glow therefore extended above the scrolling frame and were clipped.

Phase 2D's first attempt moved the scrolling frame down by `CardTopSafePadding`. That moved the clip boundary and the cards together, leaving their local relationship unchanged. It created a larger header gap but could not reveal the part of the stroke outside the scrolling frame.

## Repair

Run in Studio Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2e_vehicle_grid_internal_padding.lua`

Phase 2E canonically replaces only `DesktopFreeRoamHudController_Active` and preserves all confirmed Phase 2D changes. It adds a `UIPadding` named `CardStrokePadding` inside `VehicleGrid`, restores the scrolling frame to the header boundary, and applies `Layout.CardTopSafePadding` to `UIPadding.PaddingTop`.

## Verification

1. Stop Play, run the Phase 2E script, and start a fresh Play session.
2. Open My Vehicles and inspect the first-row cards at rest. Their complete top border and glow should be visible.
3. Scroll down and back to the top. Cards must remain clipped below the dropdown/header region while the first row retains its internal top clearance.
4. Test Category and Sort dropdown toggling to confirm Phase 2D remains intact.
5. Repeat in normal PC and Laptop device emulation.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2d_component_polish.lua`. No in-game backup objects are created.

## Mirror

The repo mirror currently predates the installed Phase 2D source. Refresh it after Phase 2E is installed and accepted so the canonical Phase 2E controller and config hierarchy are recorded.
