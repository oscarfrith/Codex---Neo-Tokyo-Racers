# Canonical Dealership And Customisation Experience

**Date:** 2026-07-14  
**Status:** Browser V1.4 user-approved; Garage Workspace V3 generated and awaiting Studio install/verification  
**Installers:** `scripts/roblox_ui_garage_replacement_foundation_browser.lua`, then `scripts/roblox_ui_garage_workspace_remaining_menus.lua`

## Outcome

This is the first consolidated stage of the approved complete garage UI replacement. It preserves the authoritative entrance/session/camera, garage catalogue, purchases, persistence, vehicle instances, Phase AO upgrades, preview assembly and spawn behavior while replacing cockpit-browser visual ownership with isolated shared components and one canonical controller.

The installer includes hierarchy/source preflight, generated-source compilation, a post-install static audit and a runtime absolute-geometry audit. Do not layer another layout patch over it: if testing finds a browser defect, update this same replacement installer.

## Replacement ownership and next pages

- `GarageReplacementComponents` owns shared gradient panels, image-first vehicle/module cards and the single card-relative popup positioner.
- `GarageBrowserController` owns dealership and owned-customisation geometry. It disables `GarageExperienceController_Active` so legacy and replacement geometry cannot both run.
- The module-card contract reserves a configurable artwork slot and puts the module name beneath it even before module image IDs are supplied.
- `GarageWorkspaceController` now owns Build Modules, Cockpit Paint, Owned/Buy Modules and module customisation presentation. The bootstrap retains only page state, view-model assembly and proven action callbacks; its legacy page surfaces are hidden while the canonical workspace is active. The same desktop composition scales down for mobile.
- Every migrated BUY, EQUIP and CUSTOMISE popup must call the shared popup positioner; no page gets independent hard-coded popup offsets.
- V2 makes reuse literal: `GarageReplacementComponents.LayoutGarageShell` and `RenderPerformance` are called by both the vehicle browser and remaining workspace pages. Build Module Slots has no left rail, post-selection pages have no Exit, Paint has no Back, and module readiness/badges share the current vehicle's installed-instance resolver.
- V3 establishes the safe legacy-removal boundary: Browser and Workspace live under an independent runtime `CanonicalGarageGui`, share one canonical scale, and no longer accept the legacy `UI.Gui` or `UI.Scale`. Legacy garage construction remains temporarily only because cash/property/action bridges still reference it; removal waits for the explicit zero-reference gate rather than risking another partial flow break.
- `GarageModuleArtworkRegistry` is the single category definition owner for Build Modules and Customise Modules. Both pages use its order, labels, target IDs and image attributes together with the same shared module-card factory.

## Installed Owners

- `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageSessionService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.GarageEntranceController_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageExperienceController_Active`
- `ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageExperience`

The old on-foot and countdown drive-in entrance clients are disabled and marked as superseded. The dealership intro remains enabled for its objective/tether presentation, but automatic distance opening is disabled. The active bootstrap receives only guarded flow/data bridges: `ALL` browsing, ascending-rating ordering, automatic leftmost preview, bottom-carousel geometry, early garage camera activation, cross-category purchase context, owned-count card text, and owned/drive-in customisation starting at Cockpit Colour.

## Interaction And Session Flow

- Dealership: approach the garage desk and press `E`, tap the prompt on touch, or use the shown controller action.
- On-foot customisation: use the same prompt at `CustomisationDeskTrigger`.
- Drive-in customisation: drive an owned vehicle into the bay, then use the same prompt. The countdown/polling owner is retired.
- The server validates entry, stores the return transform, moves the character to the existing hold point, freezes it and hides its parts/effects on the server so other players cannot see it.
- Dealership/owned-picker Exit restores the saved entrance transform.
- Starting the final vehicle releases the session without returning the character to the entrance.
- Owned-picker and drive-in selections open Cockpit Colour rather than Build Modules.

## Dealership Presentation

- Shared free-roam/racing semantic colours: charcoal panels, pink structure, cyan selection, blue purchase, red destructive actions and unchanged tier badges.
- `ALL` is fixed above alphabetically sorted categories.
- Dealership and owned-customisation vehicles sort by rating ascending, then name/ID. Unrated entries follow rated entries rather than being treated as the weakest cars.
- Garage entry defaults to `ALL`, moves immediately to the existing garage preview camera and automatically builds the leftmost eligible vehicle. Changing category repeats that deterministic leftmost selection for the new category.
- The next canonical rerun changes that entry orbit to the exact Cockpit Colour framing (`135°` yaw, `-12°` pitch, distance `33`) after the generic preview marker produced an overhead close-up.
- Cards keep image, name and tier/rating, and add `OWNED xN` only when the count is positive. Purchase price moves into the selected-card action popup to keep the card hierarchy consistent with other vehicle menus.
- Existing `BUY ANOTHER` behavior is preserved.
- The vehicle carousel is a transparent, clipped horizontal strip along the bottom. Narrow previous/next rails remain at the screen edges, and cards cannot draw over them.
- Dealership and owned-customisation cards now use the same image-led composition as the free-roam vehicle cards: large fitted vehicle image, centred name below it, tier/rating badge over the image at top-right, pink structure and cyan selected state.
- Selecting a card loads its preview and displays the existing authoritative `BUY`, `BUY ANOTHER` or `CUSTOMISE` callback in a dedicated non-clipping popup positioned from the selected card's rendered top-centre. V3 creates that button under a permanent garage overlay owner rather than inside the stats panel, so stats rerenders can no longer destroy it before presentation attaches.
- Vehicle cards resize both the image container and nested `ImageLabel`, so the artwork fills the intended image area while retaining `Fit` scaling.
- Garage panels/buttons now read the approved `DesktopFreeRoamHud.Colours` and `Effects` tokens and use idempotent surface gradients, button overlays, semantic strokes, restrained outer glow and hover treatment. Tier colours remain informational.
- Cockpit-selection headline stats place label/value/delta above a full-width dynamic bar. Fill uses the free-roam Electric Blue-to-Telemetry gradient and an editable `StatBarReference` default of `180`; module pages retain their compact comparison layout.
- Categories retain their dark gradient back panel close beneath Roblox controls and stop above the carousel with the larger editable `CategoryCarouselGap`.
- Garage spaces and cash are equal `58 px` compact free-roam-style chips beneath stats. Their combined width plus the normal gap exactly matches the `360 px` stats panel width; the original shop callbacks remain on the new `+` controls.
- The compact top panel uses the race metric-card surface treatment. Exit is reduced to `88 x 30` immediately above the carousel's right edge. Cockpit cards default to `240 x 154` with a larger clipped artwork area and no image-frame border.
- One `1600x900` composition is scaled for PC and touch. PC retains the editable `0.68-1.02` range; touch may scale to the separate `MobileMinScale` default of `0.42` for landscape phones.

## Module Artwork

Configure shared Build/Customise category images under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.ModuleArtwork
├── All
├── Cockpit
├── ThrustColour
├── FrontEngine
├── RearEngine
├── Stabilisers
├── Boost
├── FrontBumper
├── RearBumper
├── SidePods
└── Spoiler
```

Each category is a `Folder` with `Image`, `DisplayName`, `TargetId`, `SortOrder`, `ShowInBuild`, and `ShowInCustomise` attributes. Category folders must contain no child folders, `StringValue` objects, or other instances. Build Modules and Customise Modules read the same ordered registry and shared card factory, so category-card changes cannot drift between pages. An empty `Image` attribute retains the readable text fallback.

## Studio Installation

1. Open Studio in Edit mode.
2. Paste and run the complete contents of `scripts/roblox_ui_garage_replacement_foundation_browser.lua` in the Command Bar.
3. Confirm `[NTR Garage Replacement] INSTALL PASS`.
4. Stop and report the complete Output if any preflight/compile/anchor assertion fires. Do not broaden the source replacement.
5. Restart Play before verification. Each tested viewport/mode must print `[NTR Garage Replacement Runtime] GEOMETRY PASS ...`; stop and copy any `GEOMETRY FAIL` output.

The installer performs guarded exact source replacement in the active bootstrap and garage server. This is intentionally fragile: it refuses unknown/ambiguous source shapes before live source mutation. The bootstrap edits add no new top-level local helpers.

The first V3 run reached its post-install audit but reported `Stat-column renderer missing`: V3 had correctly replaced the superseded V2 marker before the audit checked for it. The same installer now accepts either marker during migration and treats `NTR_GARAGE_CANONICAL_LAYOUT_V3` as authoritative. Because the failure occurred after source assignment, rerunning the corrected installer is the intended recovery and is idempotent.

The first V3 screenshot then exposed a separate ownership conflict: the isolated presentation applied the new composition, but bootstrap `applyDealershipLayout()` ran again during cockpit rendering and restored its older full-height stats, left-stacked economy panels, centre-offset carousel and large Exit geometry. The same installer now replaces that function with scroll-axis invariants only and marks `NTR_GARAGE_CANONICAL_PRESENTATION_OWNS_GEOMETRY`; the isolated controller is the sole geometry owner. A bounded `0.12 s` browser-only refresh reapplies layout to pooled cards/action controls that are populated after ScreenGui creation without running during driving or other garage stages.

The first clean-replacement Play run then failed before layout verification: `UDim2.zero` yielded a nil Position, and the bootstrap Exit event rejected the table-field callback passed to `Connect`. Replacement V1.1 corrects the position constructor, restores the original inline legacy Exit connection, uses a separate inline close/session-release callback for the new browser, and recognizes/removes the partial V1 Exit bridge when rerun. Do not revert; rerun the same replacement installer and restart Play.

V1.1 then loaded and established the correct clean composition. Approved V1.2 refinement removes border/glow from chrome panels while keeping gradients, insets smaller category buttons, raises the category-panel bottom above the selected-card action, crops 512x340 artwork into rounded near-full-card image regions, overlays a larger centred vehicle name, and removes the popup's outer wrapper. Stats are explicitly ordered rating/Speed/Acceleration/Handling/Drift/Braking/Boost, use the pre-V3 gradient-bar hierarchy, and sit above shorter paired economy cards. Carousel rails are larger and borderless without reducing the existing scroller width; measured canvas bounds control directional visibility, and short rows are centred. The server summary adds only its already-calculated `Headline` table beside `Overall`, repairing owned-stat zeroes without changing calculation authority.

V1.3 corrects the last observed composition details. Short rows now centre only after the scroller's final scaled `AbsoluteSize` is available and recalculate on later size changes; the geometry audit compares the rendered card-row centre with the actual screen centre. Vehicle art uses `Fit` rather than `Crop`, preserving the complete 512x340 image from top to bottom, while the name plate is independently anchored at the card bottom. Cash/garage chips use the established blue outline without glow. The top-centre panel was already replacement-owned; it now visibly uses the exact race `metricCard` PanelSoft background, configured transparency/corner radius, transparent PanelSoft-to-PanelDeep gradient, and no strokes.

V1.4 applies only the approved final image/header adjustment: vehicle artwork is enlarged to `1.06` within rounded holder/image clipping so it fills the card width with slight accepted vertical crop; module artwork remains `1.0`. The metric-card header title and description are larger and both use the standard white text token.

## Verification Matrix

### Entry and lifecycle

- PC dealership `E`; touch dealership tap; controller dealership prompt.
- On-foot customisation prompt and Exit return.
- Drive an owned vehicle into the bay; prompt appears only when eligible; enter without countdown.
- Use a second client to confirm the held character is hidden from other players.
- Verify movement, jump and rotation remain locked while the garage is open.
- Dealership Exit restores the exact entrance position/facing and normal camera/HUD.
- Final Start Driving unlocks before spawn/seating and produces a driveable hover vehicle.
- Reset/death/disconnect during a session does not leave a persistent lock.

### Pages and data

- `ALL` appears first; remaining categories are alphabetical.
- Dealership and owned-customisation cards sort lowest rating left to highest rating right; unrated entries come last.
- Entry opens on `ALL`, uses the existing garage camera immediately, and previews the leftmost card without requiring a click.
- Entry framing matches Cockpit Colour rather than the former overhead/close generic marker view.
- Changing category automatically previews that category's leftmost card.
- Vehicle artwork fills each borderless card image area without clipping or stretching; the card surface alone owns gradient, border and glow. Full cockpit name and optional ownership text remain below the image.
- The selected card always owns the visible centred BUY/CUSTOMISE popup, including the automatically selected first card.
- Panels/buttons visibly retain the free-roam family gradients, pink/cyan/blue semantic strokes, restrained glow and hover state after repeated card/category rerenders.
- `OWNED xN` and `BUY ANOTHER` are correct for duplicate vehicles.
- Clicking a card loads the correct preview and centres the action popup directly above that card at every tested resolution; scrolling hides it and it returns over the selected card after layout settles.
- Vehicle cards match the free-roam card image/name/rating hierarchy on PC and mobile.
- Cockpit-selection stat labels, values and deltas render above full-width gradient bars; fill proportions remain distinct above 100 and use the configured reference maximum.
- Buying enters Cockpit Colour with no browser Back/Exit.
- Owned customisation lists distinct saved vehicle instances and previews their saved colours/modules/upgrades.
- On-foot `CUSTOMISE` and drive-in entry both start at Cockpit Colour.
- Cockpit Colour -> Build Modules -> Owned/Buy Modules -> Customise Modules -> Start Driving completes.
- Module compatibility, locked cards, BUY/EQUIP popup placement, purchases and Phase AO upgrades remain correct.
- Add one temporary diagram image ID and confirm it appears on the matching Build Modules and Customise Modules cards.

### Responsive sizes

- PC: `1280x720`, `1366x768`, `1600x900`, `1920x1080`, `2560x1440`, `3440x1440`.
- Phone landscape and tablet landscape.
- Confirm bottom carousel, left panels, stats and Exit never overlap; scrolling remains usable; Roblox safe-area controls remain clear.

## Rollback

No in-game backup scripts/folders are created. Use Roblox version history to return to the pre-install place version. If a failure occurs before mutation, the installer assertion is the rollback: no live source should have changed. After a successful install, refresh the full Studio mirror before creating any repair.

## Mirror

The initial V1 install was refreshed at `2026-07-14 20:05:44` and exposed two ownership defects: the bootstrap still expanded the legacy centre grid and delayed the garage camera until preview unlock. The revised canonical installer now replaces those exact owners and remains the only Studio rerun. Refresh the mirror again after verification; do not commit `docs/studio-full-export-paste.txt`.
