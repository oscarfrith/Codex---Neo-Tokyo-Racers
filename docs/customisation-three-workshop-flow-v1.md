# Customisation Three Workshop Flow V1

Status: user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

## High-Risk readiness contract

- **Goal:** Reorganise the confirmed vehicle customisation workspace into `Add Modules`, `Upgrade Modules`, and `Paint Shop` without changing its established layout or creating replacement gameplay owners.
- **Baseline:** `ModuleShopUIController` owns the current customisation route and preview composition; `GarageWorkspaceController` and `GarageReplacementComponents` own the shared workspace, rail, listing cards, action popup, upgrade budget and colour sliders; `GarageActionController_Shadow_Disabled` owns purchases, upgrades, colours, profile mutation and vehicle construction.
- **Required:** Preserve Add Modules behaviour; provide a module-location-only Upgrade rail; provide a Paint rail with All, Cockpit, Thrust, Underglow and fixed module locations; show Paint left and Neon Lights right for module locations; reveal Neon as a paint channel only after purchase; move successful Neon purchase directly into its colour sliders.
- **Preserved:** Existing card/layout geometry, camera, preview vehicle, module inventory, module-instance identity, upgrade-point allocation, paint application, module-light assets, vehicle build/spawn, Drive, cash, garage capacity, ProfileService and existing saved fields.
- **Excluded:** A new physical underbody-light asset, a new saved underglow schema, new remotes, new ScreenGuis, new VFX/runtime owners, material customisation, paint pricing and changes to owned-garage UI.
- **Presentation owner:** `ModuleShopUIController` remains the only route/composition owner. The shared workspace modules remain the only visual/layout owners.
- **State owner:** The controller retains one route state. Section changes clear transient module, upgrade, neon and preview selection before rendering the next route.
- **Authority:** The server remains authoritative for installed module identity, upgrade availability/cost, cash, Neon capability, Neon price, purchase and saved colours. The client only previews and requests existing actions.
- **Data:** No schema change. Existing `Vehicles`, `OwnedModuleInstances`, `ModuleColors`, `NeonOwned`, `CockpitColors` and `ThrustColor` remain canonical. `Underglow` is the existing bulk installed-module `Neon` editor, not a new underbody-light item.
- **Economy:** `BuyNeon` remains the only Neon purchase mutation. V1 adds `NeonAvailable` and a non-negative `NeonPrice` to the existing read-only module catalogue so the UI does not guess capability or price; the mutation clamps the same authored price before charging. Insufficient-cash presentation is red; the server still makes the final affordability decision.
- **Navigation:** Root bottom cards are the three workshops. Add retains its current steps and uses a three-workshop rail. Upgrade uses only fixed module locations. Paint uses All, Cockpit, Thrust, Underglow and fixed module locations. Only one sidebar exists at a time.
- **Capability rules:** Empty module locations remain stable rail entries and report that a module must be installed. Missing upgrade paths show the existing unavailable state. Unsupported module neon cannot be purchased or coloured. A purchased module Neon channel appears in Paint. Underglow remains unavailable until at least one installed module owns Neon, and its bulk commit touches owned Neon targets only.
- **Preview lifecycle:** Paint uses the current in-place paint preview. Neon purchase preview uses the current `PreviewNeonSlot`. Upgrade preview continues through the current performance resolver. Section/back/drive transitions clear transient preview state.
- **Performance:** No new loop, render connection, vehicle clone owner or hierarchy scan during navigation. Neon capability is calculated only while the server builds its existing catalogue. Existing shared scroll memory and responsive scaling remain active.
- **Device coverage:** Desktop, controller, tablet, phone portrait and phone landscape use the same shared canvas and one scrolling rail. Stable category/carousel keys preserve selection and scroll position.
- **Failure/rollback:** The canonical installer unique-checks one complete client workflow boundary and one server catalogue-function boundary, compiles both projected sources before mutation and after commit, and restores both sources plus icon attributes on failure.
- **Verification:** Restart Studio. Test every root route, all Add steps, every empty/installed Upgrade location, upgrade preview/purchase/budget, Paint special targets, module Paint, unsupported/supported Neon, insufficient cash, Neon purchase-to-slider, owned Neon customise, Back, Drive, vehicle switch and rejoin on desktop and mobile.
- **Done when:** The three workshops are isolated, no stale performance/cosmetic/paint action crosses routes, existing data persists, authoritative prices match, unsupported Neon stays unavailable, purchased Neon opens and saves correctly, mobile navigation remains usable and no previous customisation/Drive behaviour regresses.

## Installer

Run `scripts/roblox_customisation_three_workshop_flow_v1.lua` once in Studio Edit mode. Require:

```text
[NTR Customisation Three Workshop Flow V1] PASS
```

Restart Studio before Play verification. Refresh the complete Studio mirror only after the matrix passes.
