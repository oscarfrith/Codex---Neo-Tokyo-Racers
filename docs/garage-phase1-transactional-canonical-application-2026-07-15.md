# Garage Phase 1 Transactional Canonical Application

**Date:** 2026-07-15  
**Status:** V2 ownership approach confirmed substantially improved; V3 preview/camera/module-card refinement prepared  
**Installer:** `scripts/roblox_ui_garage_phase1_transactional_canonical_application.lua`

## Outcome

The original installation printed PASS, but the fresh mirror proved Studio later removed every newly created script, the activation attribute, and all eleven new artwork folders. Existing Source edits survived. V2 filled that dependency and ownership gap without requiring new runtime instances, and the user confirmed this approach worked much better. V3 preserves that ownership bridge and refines only isolated existing controllers.

V3 additionally:

- places every local preview at `Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad` through the existing `PathResolver`, preserving pad orientation and focusing on the completed vehicle bounds;
- adds right-drag desktop orbit, unobstructed touch orbit, wheel/pinch zoom and configurable automatic-angle fades;
- makes Build and Customise use one shared image-first module-category card, including a vertically scrolling Customise artwork rail;
- gives Owned and Shop pages a separate image-free listing card with category/cockpit lineage, bold module name, module type and price/ownership status;
- groups identical owned modules and equips an available instance;
- matches Select Vehicle cards: pink outline when unselected, cyan/blue outline when selected, with no state-coloured solid fill.

It retains and reuses:

- `GarageBrowserController`;
- `GarageWorkspaceController`;
- `GarageReplacementComponents`;
- the existing preview vehicle and preview camera modules;
- the authoritative garage action controller and garage session service.

It reuses existing instances for:

- `ModuleShopUIController` as the application, action and routing host across Browser, Paint, Build Modules and Customise;
- `GarageWorkspaceController` as the folder-first artwork resolver with an embedded fallback;
- entry, close and Start Driving handoffs.

The bootstrap receives unconditional source gates plus one small deferred `require` bridge to the existing application host. It no longer depends on `CanonicalGarageApplicationActive`. No new top-level bootstrap helpers or feature blocks are added. Active HUD, sprint and thrust observers use `NTR_GarageSessionActive`.

`ModuleArtwork` folders remain the preferred editable image source. If Studio removes them again, Workspace logs `FALLBACK ACTIVE` and continues with the same eleven definitions and blank optional images. Missing artwork can no longer block Paint, Build or Customise.

## Transaction Rule

The installer performs all preflight work before changing live ownership:

1. validates the refreshed hierarchy and exact source anchors;
2. compiles the preview vehicle, preview camera, shared components, Workspace, application, bootstrap and companion sources;
3. checks source sizes;
4. writes and reads back the existing Workspace and ModuleShop sources;
5. writes and reads back the companion observer sources;
6. writes the unconditional bootstrap ownership gate and startup bridge last.

If the installation throws before completion, every changed Source is restored. It does not create Studio backup folders or backup scripts.

## Studio Run

1. Stop Play and remain in Edit mode.
2. Paste and run the complete installer once in the Command Bar.
3. Require this final line before saving:

```text
[NTR Garage Phase 1 V3] INSTALL PASS - preview pad, orbit/fade camera and shared module cards installed
```

4. Restart Play from a fresh session.
5. Enter Dealership, then complete `select/buy -> Paint -> Build Modules -> Customise -> Start Driving`.
6. Repeat entry through owned Customisation and Drive-In Customisation.

Expected runtime evidence:

```text
[NTR Canonical Garage] DEPENDENCY PASS
[NTR Canonical Garage] STARTUP PASS existing ModuleShopUIController host
[NTR Garage Preview] PAD PASS Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad
[NTR Garage Phase 1 Runtime] OWNERSHIP PASS <mode>
[NTR Garage Presentation Owner] PASS Browser
[NTR Garage Presentation Owner] PASS Workspace
[NTR Garage Replacement Runtime] GEOMETRY PASS ...
[NTR Garage Workspace Runtime] GEOMETRY PASS ...
```

There must be no `showCashShop` connection error, no `GarageModuleArtworkRegistry` infinite yield, no enabled `HOVER_RACING_V2_GarageUI`, and no source-length error. `ATTRIBUTE FOLDERS PASS` is preferred; `FALLBACK ACTIVE` is acceptable and must not remove buttons or stop navigation.

Camera and rail tuning uses optional attributes on the existing `Config.UI.GarageReplacement` folder. Defaults are installed only when missing: `PreviewPadYOffset`, fade enable/opacity/timing, camera interpolation speed, orbit sensitivities, pitch limits, distance limits, wheel/pinch zoom and `ModuleCategoryRailWidth`. Every controller also contains matching safe defaults.

## Acceptance Boundary

Do not retire or delete the legacy renderer source in this phase. Phase 1 proves the isolated replacement can own all live garage routes first. Permanent source removal is allowed only after the fresh-Play flow above passes and a refreshed mirror confirms that no active companion still depends on the legacy presentation.
