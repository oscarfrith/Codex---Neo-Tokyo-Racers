# PC Free-Roam UI Phase 2D Component Polish

Date: 2026-07-10  
Status: Installed and substantially confirmed; superseded by Phase 2E for first-row card-top clearance

## Purpose

Phase 2D canonically replaces only `DesktopFreeRoamHudController_Active`. It keeps the confirmed Phase 2C inset, visibility, laptop eligibility, and responsive layout repairs while refining the reusable UI components.

## Studio script

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2d_component_polish.lua`

The installer does not patch the register-limited bootstrap, driving, server, VFX, dealership, or racing scripts. It recognises the Phase 1, Phase 2B, Phase 2C, and Phase 2D controller markers and refuses to replace an unknown controller source.

## Changes

- Added configurable `Layout.CardTopSafePadding`, but the Phase 2D outer scrolling-frame offset did not resolve top clipping because it moved the cards and clipping boundary together. Phase 2E applies this value as internal `UIPadding` instead.
- Makes each dropdown header toggle its own open list closed; opening the other dropdown replaces the current list.
- Replaces the decorated pink dropdown shell with a borderless neutral grey gradient surface and understated option rows.
- Adds a shared accent setter so a state change updates both the main border and outer glow colour.
- Removes the minimap `UIStroke`; its directional fade overlays now define its edges.
- Adds one neutral overlay gradient to buttons without replacing their semantic base colours.
- Adds `Bold` and `Italic` BoolValues for Heading, Button, Body, Caption, Metric, MetricUnit, and CashMetric typography roles.

Font weight/style support depends on the selected Roblox font family. Michroma may not visibly render every bold/italic combination; the values remain safe and editable, and another supported font can be selected through the existing font settings.

## Verification

1. Stop Play, run the Phase 2D installer in the Command Bar, then start a fresh Play session.
2. Open My Vehicles and confirm the first-row top border/glow is fully visible and horizontally aligned with the dropdowns.
3. Open Category, click Category again, and confirm it closes. Repeat with Sort, then switch directly between Category and Sort.
4. Confirm dropdown lists have a grey surface with no outer pink frame.
5. Select/open the cyan car action and confirm its outer glow changes to cyan with its border.
6. Confirm the minimap has no rectangular outline behind its faded edges.
7. Inspect dark, blue, cyan, and red buttons and confirm the same subtle neutral gradient is present without replacing their base colour.
8. Change one typography role's Bold/Italic values, restart Play, and confirm supported font variants respond.
9. Repeat at normal PC resolution and Laptop device emulation. The UI must appear without resizing the Studio window.

## Rollback

Rerun `scripts/roblox_ui_freeroam_pc_phase2c_inset_visibility_card_edge_repair.lua`. No in-game backup objects are created.

## Mirror

The pre-Phase-2D mirror was refreshed at approximately 21:00 on 2026-07-10 and contains the installed Phase 2C controller. Refresh the mirror again after Phase 2D is installed and accepted.
