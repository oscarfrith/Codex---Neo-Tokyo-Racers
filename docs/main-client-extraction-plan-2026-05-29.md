# Main Client Extraction Plan

**Created:** 2026-05-29  
**Current status:** Phase A-E completed / clean checkpoint  
**Target script:** `StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client`  
**Goal:** Restructure the remaining large client owner into the new `NeoTokyoRacersClient` architecture with the fewest safe phases.

## Why This Needs Its Own Plan

`HOVER_RACING_V2_Client` was the only expected active legacy-named script after the Phase 21 audit. It has now been replaced as the active owner by the Phase D architecture-owned client, while the old script remains disabled as rollback.

It is not a simple owner-location switch. It currently owns several connected systems:

- Dealership / cockpit selection UI
- Cockpit paint UI
- Module shop UI
- Customisation UI
- Colour picker
- Vehicle preview building
- Preview camera orbit
- Server action calls through `GarageInvoke`
- Driving handoff after spawn
- Some remaining drive HUD / mobile control setup paths
- Camera input setup
- Init order

Because these systems share local state, extracting them carelessly can break menus, previews, purchases, vehicle spawn, or driving handoff. This plan keeps the number of phases low while avoiding a single risky rewrite.

## Current Known Shape

Source mirror:

```text
roblox/exported_scripts/StarterPlayer/StarterPlayerScripts/HOVER_RACING_V2_Client.client.lua
```

Approximate size:

```text
108 KB
```

Important function groups observed:

```text
Theme / UI primitives:
readThemeColor, refreshThemeFromValues, new, clear, corner, stroke, label, button, panel

Catalog / profile access:
callServer, getCategory, sortedSlots, getSlot, getCockpit, getModule, modulesForSlot

Preview / paint:
previewRoot, findTemplateByAttribute, resolvePaintChannel, applyColors, getSlotMount,
pivotModuleToSlot, moduleColors, buildPreview, setCameraSection, updateCamera

Shared UI render helpers:
renderStatsOnly, renderStatsPanel, makeArrowScroller, updateNav, showStage

Dealership and cockpit paint:
renderDealershipPanel, renderCockpitShop, renderColourPicker, renderCockpitPaint

Module shop:
renderSlotSelection, renderModuleOptions, renderModuleShop

Customisation:
renderCustomiseLeft, folderHasBuyableNeon, templateHasChannel,
colourChannelsForTarget, renderCosmetics, renderCustomise

Driving handoff / remaining runtime:
setJumpLocked, getPlayerVehicle, waitForPlayerVehicle, setupControls,
ensureDriveHud, startDriving, closeGarage

Input/init:
handleDriftAction, handleBoostAction, handleResetAction, setupUI,
setupCameraInput, init
```

## Migration Principles

- Do not rewrite behaviour and architecture at the same time.
- Move state boundaries before moving UI screens.
- Keep `GarageInvoke` response shapes unchanged.
- Keep `DrivingControllerV47` and the Phase 16-20 active owners untouched.
- Keep rollback paths until each phase is tested.
- Avoid editing server logic during this client extraction.
- Use shadow/parity first, then switch one client responsibility group at a time.
- Do not delete `HOVER_RACING_V2_Client` until the replacement bootstrap fully owns all required behaviour.

## Proposed Phases

### Phase A: Client State And Services Boundary

**Risk:** Low-medium  
**Status:** Installed and user-tested successfully  
**Purpose:** Extract shared state, server calls, catalog lookup helpers, theme reads, and colour utility logic into modules while keeping `HOVER_RACING_V2_Client` live.

Create or populate:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientState
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.GarageApiClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.CatalogClient
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.ClientThemeAdapter
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Core.PaintClient
```

What moves:

- `State` table shape
- `callServer`
- `getCategory`
- `sortedSlots`
- `getSlot`
- `getCockpit`
- `getModule`
- `modulesForSlot`
- `slotDisplayName`
- theme read helpers
- paint channel resolution and colour application helpers

What stays in the main client:

- All screen rendering
- Preview build orchestration
- Driving handoff
- Init

Testing:

- Dealership opens.
- Cash/profile loads.
- Cockpit cards render.
- Stats render.
- Existing customisation still works.
- Vehicle spawn/driving still works.

Rollback:

- Leave old functions in place until the new modules pass parity.
- If switching use fails, main client can fall back to local functions.

### Phase B: Preview And Colour System Extraction

**Risk:** Medium  
**Status:** Installed and user-tested successfully  
**Purpose:** Move preview vehicle building, camera section logic, and colour picker rendering into dedicated controllers/modules.

Create or activate:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewVehicleController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.PreviewCameraController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ColourPickerController
```

What moves:

- `buildPreview`
- `clearPreviewModules`
- `setCameraSection`
- `updateCamera`
- `previewRoot`
- `getSlotMount`
- `pivotModuleToSlot`
- `moduleColors`
- `renderColourPicker`
- `makeSlider`
- `syncPicker`
- `pickerColor`
- `channelTitle`

What stays in the main client:

- Which screen calls the preview/colour controller
- Screen-specific button handlers
- Navigation
- Driving handoff

Testing:

- Cockpit preview appears.
- Module previews attach correctly.
- Camera rotates to module sections smoothly.
- Cockpit colours apply.
- Module colours apply.
- Neon and thrust colour previews remain correct.
- Going back/forward between screens does not leave stale preview modules.

Rollback:

- Keep local preview/colour functions until the active controllers pass testing.

### Phase C: Garage Screen Controllers

**Risk:** Medium-high  
**Status:** Installed and user-tested successfully  
**Purpose:** Move dealership, cockpit paint, module shop, and customisation rendering into separate screen controllers, but keep one existing bootstrap/live client orchestrating stage changes.

Activate/refine:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DealershipUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CockpitPaintUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.ModuleShopUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.CustomisationUIController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.NavigationController
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.StatsPanelController
```

What moves:

- `renderDealershipPanel`
- `renderCockpitShop`
- `renderCockpitPaint`
- `renderSlotSelection`
- `renderModuleOptions`
- `renderModuleShop`
- `renderCustomiseLeft`
- `renderCosmetics`
- `renderCustomise`
- most screen-specific layout logic

What stays in main/bootstrap:

- `showStage`
- stage navigation
- `updateNav`
- top-level UI root creation
- server response refresh flow
- spawn/close handoff

Testing:

- Full flow: dealership -> cockpit paint -> modules -> customisation -> spawn.
- Back/next works on every screen.
- Module buy/equip popups work.
- Upgrade preview/buy works.
- Cosmetics/neon options detect correctly.
- Mobile layout still fits.
- Desktop layout still fits.

Rollback:

- Main client keeps old render functions until screen controllers pass one by one.
- Screen controllers can be enabled individually.

### Phase D: Bootstrap And Driving Handoff Extraction

**Risk:** High  
**Status:** Installed and user-tested successfully  
**Purpose:** Replace the main live client owner with a new architecture-owned client while preserving the tested `HOVER_RACING_V2_Client` internals first. This avoids rewriting live garage UI and driving handoff in the same step.

Create/switch:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Important implementation note:

- Phase D is an owner-location switch, not a full internal rewrite.
- The staged Phase A-C modules remain available for later internal extraction.
- A future cleanup/refactor can rename the active bootstrap after Phase E audit passes.

What moves:

- `setupUI`
- `setupCameraInput`
- `init`
- `startDriving` orchestration only
- `closeGarage`
- input action binding for drift/boost/reset if still needed in the main client
- remaining jump-lock / spawn-handoff glue

What should not move/rewrite here:

- `DrivingControllerV47` internals
- Phase 16 mobile controls
- Phase 16 HUD suppressor
- Phase 16 cached VFX runtime
- Phase 20 thrust preview owner
- Server action layer

Testing:

- Fresh join opens dealership.
- Full garage flow works.
- Spawn vehicle and immediately drive.
- Camera releases correctly from garage to vehicle.
- Drift, boost, reset work.
- Mobile controls work.
- Desktop controls work.
- Exit/re-enter works.
- Respawn/rejoin test.

Rollback:

- Disable `NeoTokyoRacersClient_Bootstrap_Active`.
- Re-enable `HOVER_RACING_V2_Client`.

### Phase E: Cleanup And Documentation

**Risk:** Low  
**Status:** Prepared as read-only post-switch audit  
**Purpose:** Only after Phase D passes repeated tests, archive/rename old client pieces and update docs/source mirror.

What happens:

- Keep `HOVER_RACING_V2_Client` disabled, not deleted.
- Document new active client owners.
- Run active script audit.
- Export Studio scripts to GitHub mirror again.
- Commit.

Prepared audit:

```text
scripts/roblox_client_phaseE_post_switch_audit.lua
```

Expected active main client owner after Phase D:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

Do not:

- Delete old client until a later stable milestone.
- Mix gameplay feature changes into cleanup.

## Recommended Minimum Plan

If speed matters, use four active phases plus one cleanup phase:

```text
Phase A - Shared state/API/catalog/paint utilities
Phase B - Preview + colour picker
Phase C - Garage screen controllers
Phase D - Bootstrap + driving handoff switch
Phase E - Audit + docs + commit
```

This is the fewest phases I would recommend without making the main client extraction fragile.

## Main Doubts / Watch Points

- The current `State` table is shared across almost every UI function. Extracting screens before extracting state would be risky.
- Preview building and colour application are tightly connected; they should move together.
- The driving handoff is high-risk because previous patches broke camera/hover/driving when this area was touched.
- Mobile layout should be tested after every UI-controller phase.
- Do not remove local fallback functions until each extracted controller is proven.
- The current client still contains some old mobile/HUD helper functions even though Phase 16 moved active helper owners. Those should be neutralised only after confirming they are not still used by `startDriving`.

## Suggested Next Action

Start with Phase A only.

Phase A should be mostly module creation plus a small adapter in `HOVER_RACING_V2_Client`. It gives us cleaner boundaries without disturbing rendering or driving.

## Phase A Script

Prepared Studio script:

```text
scripts/roblox_client_phaseA_core_boundary_modules.lua
```

Phase A currently creates and validates the Core modules without editing `HOVER_RACING_V2_Client`. The adapter step should only happen after the modules load cleanly and normal Play testing still works.
