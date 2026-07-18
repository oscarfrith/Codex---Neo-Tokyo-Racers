# Canonical Garage Flow Refinement V2

Date: 2026-07-18

## Scope

`scripts/roblox_ui_garage_flow_refinement_v2_installer.lua` is the single approved follow-up to the confirmed garage flow/navigation V1.1 baseline. It updates only the four canonical garage UI modules and five `GarageReplacement` layout attributes.

It does not edit the client bootstrap, legacy UI, server actions, inventory, persistence, performance, driving, camera, or racing systems.

## Root cause and routing repair

Owned Customisation could intermittently enter Paint because the vehicle-selection callback checked mutable `State.ShopMode` after a yielding server request. The three entrance events were also connected through an unordered table loop.

V2 captures the selection mode before the request and binds Dealership, owned Customisation, and Drive-In events explicitly. Dealership purchases still enter whole-vehicle Paint; owned Customisation enters the Garage hub.

## Shared presentation changes

- Browser and Workspace use the same configurable header title/subtitle sizes and header height.
- Build Modules uses two floating shared module-category cards for Build Modules and Customise Modules. There is no rail background.
- Mouse-wheel input over the category rail is forwarded to its scrolling frame, including when the pointer is over the selected card.
- Customise Modules > All opens an overview with Change Colour and Underglow. Change Colour owns Primary/Secondary/Detail; Underglow owns Neon.
- The paint tabs float above the existing-size control panel. H/S/B controls move upward and the palette remains below with a deliberate gap.
- The palette has 15 columns. Columns 1-2 are one live current-colour square, columns 3-4 are neutral pairs, column 5 starts red, and column 15 ends pink without a second red endpoint.

## Installation and acceptance

Run the installer once in the Studio Edit Command Bar, then restart Play. Require:

- `12 PASS / 0 FAIL` from the installer audit.
- Dealership selection routes to Paint.
- owned Customisation selection routes directly to Garage on repeated entries.
- Build and Customise navigation cards switch pages without showing a background rail.
- wheel scrolling continues while hovering the selected Customise category.
- All shows exactly Change Colour and Underglow.
- header title and description remain consistent on Browser, Paint, Hub, Build, and Customise.
- the 15-column palette fits at desktop, tablet, and phone scales.

The installer compiles all projected sources before assignment, enforces Roblox's source-size ceiling, and restores all four sources plus config attributes if assignment or audit fails.

## V2.1 narrow follow-up

`scripts/roblox_ui_garage_flow_refinement_v2_1_installer.lua` follows the confirmed V2 source shape and changes only `GarageWorkspaceController` and `ModuleShopUIController`:

- restores Neon inside All > Change Colour;
- gives both floating navigation rails the same shared dimensions, image scale and renderer as the bottom Owned/Buy action cards;
- removes the Customise rail backing surface through the existing `LeftFloating` contract;
- routes Customise category changes through the established transient-preview cleanup owner, which already clears `PreviewNeonSlot`.

Require `8 PASS / 0 FAIL`, then verify that an unpurchased Neon Lights preview disappears after changing category, switching Build/Customise, pressing Back, or driving.

## V2.2 compact Customise rail correction

V2.1 correctly introduced a shared-size context, but it applied that context to the long All/Cockpit/Thrust/module category rail as well as the two-card Build/Customise navigation rail. `scripts/roblox_ui_garage_customise_compact_rail_v2_2_installer.lua` separates those uses:

- Build/Customise navigation retains the shared bottom-action-card geometry and icon scale.
- The scrollable Customise category rail restores its previous `CustomiseCategoryCardHeight`, `CustomiseCategoryImageHeight`, and `1.04` artwork scale.
- Floating presentation, Neon colour, preview cleanup, selection, scrolling and mobile scaling remain unchanged.

Require `7 PASS / 0 FAIL` after installation.
