# PC Free-Roam UI Phase 2F Vehicle Card Content Offset

Date: 2026-07-10  
Status: Installed and confirmed working well; current vehicle-card layout baseline

## Purpose

Phase 2F applies the requested direct visual repair: the vehicle-card boxes are physically moved down by `Layout.CardTopSafePadding`, defaulting to 8 pixels.

Run in Studio Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2f_vehicle_card_content_offset.lua`

## Implementation

- Keeps `VehicleGrid.ClipsDescendants = true` so scrolled cards cannot overlap the dropdown/header area.
- Creates a transparent `VehicleGrid.CardContent` frame.
- Positions `CardContent` at `Y = CardTopSafePadding`.
- Parents `BuyMore` and all vehicle cards to `CardContent`.
- Parents `UIGridLayout` to `CardContent` and includes the physical offset in the scrolling canvas height.
- Removes the ineffective Phase 2E `UIPadding` path.

The installer canonically replaces only `DesktopFreeRoamHudController_Active`. It preserves the confirmed Phase 2D dropdown, glow, minimap, gradient, typography, inset, visibility, and laptop behavior.

## Verification

1. Stop Play, run Phase 2F, and start a fresh Play session.
2. Open My Vehicles and confirm the first-row boxes sit several pixels below the grid boundary with their complete top corners, border, and glow visible.
3. Scroll down and return to the top; the offset should remain and cards must not draw over the dropdowns.
4. If more clearance is desired, increase `Config.UI.DesktopFreeRoamHud.Layout.CardTopSafePadding` from `8` to `10` or `12`, then restart Play.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2d_component_polish.lua`. No in-game backup objects are created.

## Mirror

Refresh the Studio mirror after Phase 2F is accepted.
