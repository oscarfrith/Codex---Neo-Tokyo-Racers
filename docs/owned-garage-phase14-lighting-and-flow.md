# Owned Garage Phase 14 Lighting And Management Flow

**Status:** V1 through V2.2 user-confirmed and mirrored; Phase 14 complete  
**Canonical installer:** `scripts/roblox_owned_garage_phase14_lighting_and_flow.lua`  
**Committed-state audit:** `scripts/roblox_owned_garage_phase14_committed_state_audit.lua`  
**Current revision:** `NTR_OWNED_GARAGE_PHASE14_V2_2_RESPONSIVE_NAVIGATION_CLOSURE`

## V2.2 Responsive Navigation Closure (confirmed)

V2.1 is user-confirmed and present in both refreshed mirror areas. V2.2 is the final approved responsive-flow refinement and changes only `OwnedGarageWorkspaceController`. Structure and Decoration rails now use stable family keys instead of page-specific keys, so the shared scroll-memory owner retains the user's rail position while moving between option, colour and material pages.

An empty Decoration location in Style Garage now renders one normal shared category card labelled `INSTALL ASSET`. It routes to that same location in Build Garage; it does not purchase, equip or bypass the authoritative Build action. Equipped assets with no editable colour channels continue to report that capability without offering a false editor.

The user confirmed the complete V2.2 flow working and refreshed the full Studio mirror. The `21:37:10/11` export contains the V2.2 source/config revisions in exported source, manifest, source manifest and hierarchy, with current checksums. Phase 14 is closed; do not rerun its installer unless recovering this exact baseline.

## V2.1 Shared Category-Card Parity (confirmed)

V2 is user-confirmed and freshly mirrored. Screenshot review shows that bottom root/family cards and sidebar cards already use the same `Shared.ModuleCategoryCard`; the remaining visual mismatch is image scale. Sidebar rows explicitly pass `ImageZoom=.5`, while bottom navigation cards fall back to the component's larger default.

V2.1 changes only the existing owned workspace controller and one tuning attribute. `OwnedGarageCategoryCardImageZoom=.5` becomes the single bounded source used by both sidebar mode/location cards and every bottom navigation card that has an image and no specialised `CardKind`. Vehicle/listing, material, colour and empty cards remain unchanged. The value may be tuned from `0.2` to `1.2` without another source edit.

Run the canonical installer, require `Phase 14 V2.1 PASS ... bottomSidebarParity=true`, restart and run the updated audit. Compare root and Build/Style family cards against the location rail on desktop and phone, then regress navigation and refresh the mirror.

## V2 Shared Management Composition (confirmed)

V1's whole-garage lighting, atomic drafts, SAVE-stay behaviour and asset hierarchy are user-confirmed and present in the refreshed mirror. V2 changes only `OwnedGarageWorkspaceController`; it does not rewrite the V1 catalog, finish/profile/management runtimes or ServerStorage options.

The management root now contains shared `DISPLAY CARS`, `BUILD GARAGE` and `STYLE GARAGE` cards. Entering a mode shows the same three cards in the existing shared left rail. Build and Style show Structure, Decorations and Lighting as shared bottom category cards. Structure/Decoration target pages swap that single rail to server-projected locations; Back returns to the family page. Lighting has no location rail and retains the mode rail.

Build contains preview plus BUY/EQUIP only. Purchase auto-equips through the existing authoritative command. A currently equipped option is read-only `CURRENT`. Style exposes only the equipped Structure Colour/Material, Decoration Colour and Lighting Primary/Secondary finish controls. It contains no asset purchase/equip action. Empty Decoration locations remain in the rail and report that an asset must be installed before styling.

V2 uses existing `ModuleCategoryCard`, listing cards, selected-card action popup, `RenderChannelTabs`, shared paint renderer, responsive carousel and `Activated` input. No coordinates, gradients or card implementations are copied into the owned controller.

Run the canonical installer in Edit mode and require `Phase 14 V2 PASS ... modes=DisplayCars/BuildGarage/StyleGarage singleRail=true`. Restart Studio and run the updated audit; require `Phase 14 V2 Audit COMMITTED STATE PASS`. Verify the full navigation/Back matrix, Build purchase/equip, Style SAVE/Back, display cars and desktop/mobile rail scrolling, then refresh the complete mirror.

## Acceptance Contract

System/change: whole-garage lighting finishes plus the foundation for Display Cars / Build Garage / Style Garage navigation.  
Delivery lane and reason: High-Risk because saved appearance, economy-backed purchase/equip, preview lifecycle, authoritative remotes and responsive UI meet in one flow.  
Goal: replace modular repeated lighting fixtures with editable full-garage options, eliminate cross-channel preview loss, keep SAVE in the active editor and prepare the existing workspace for the approved navigation.  
Current confirmed baseline: Phase 13 V1.4 is user-confirmed; ServerStorage is production asset authority, ProfileService is persistence authority and the shared Garage workspace owns presentation.

Required changes: one template-relative lighting Model per option; Primary/Secondary/Fixed/Technical authoring; per-option saved colours; complete-draft previews; non-navigating SAVE; capability-projected controls.  
Must preserve: display assignments, structure/decoration data, cash authority, purchase conflict protection, transition/streaming handshakes, authored structure/decoration shadows and the shared workspace/card/paint components.  
Explicit exclusions in V1: the final three-mode navigation composition, lighting material editing, placeable lighting, dynamic light shadows, ZZZ runtime authority and arbitrary world-CFrame persistence.

Canonical owners:

- State: `OwnedGarageWorkspaceController` holds the active draft and selected channel.
- Geometry/visibility: `OwnedGarageManagementRuntime` owns the single `LightingRuntime` clone.
- Preview/runtime attachment: the active owned-garage session owns one `LightingPreview` and clears it on Back, Exit or management close.
- Persistence/authoritative mutation: `OwnedGarageProfileRuntime.ConfigureLighting`, invoked through the existing revisioned ProfileService command boundary.

Stable preset IDs are retained. `Lighting.Finishes[PresetId].Colors.Primary|Secondary` is added by normalisation without resetting the owned-garage schema. Empty overrides preserve authored asset colours. Purchase still auto-equips; owned options require Equip. Dynamic light brightness remains bounded by the catalog and ranges remain capped at 36 studs. Dynamic shadows stay off for mobile cost control.

The first option templates are baked from the three confirmed `StandardFixture` placements so V1 retains the existing visible coverage while moving to a single TemplateOrigin model. `LightingOption01` through `LightingOption04` receive the same folder contract and different authored palette defaults. `StandardFixture` is retained as legacy source material and is not deleted. Future art may replace the contents of each option without changing saved IDs or runtime code.

## V1 Authoring Contract

```text
ServerStorage.NeoTokyoRacers.OwnedGarage.LightingAssets.<TemplateId>.<LightingOption>
  ColourSlots
    Primary
    Secondary
  Fixed
  Technical
```

BaseParts and descendant `SurfaceLight`, `PointLight` and `SpotLight` instances inherit the nearest populated colour folder. Fixed preserves authored appearance. Technical is implementation-only. Only populated channels reach the client. The complete option is authored relative to `Templates.<TemplateId>.TemplateOrigin` and cloned once per active interior.

## Preview And SAVE Invariants

The previous finish preview rebuilt each request from committed data while the client sent only the changed channel. A Secondary request could therefore discard an unsaved Primary preview. V1 sends the complete current draft and also makes the server merge with an existing preview for the same target. Structure, Decorations and Lighting use this invariant.

SAVE submits one complete revisioned draft, clears the preview through the existing mutation owner, updates from returned authoritative state and keeps the current editor page open. Back still cancels and restores committed appearance.

## Approved Composition (implemented in V2)

V2 implements the approved `DISPLAY CARS`, `BUILD GARAGE` and `STYLE GARAGE` modes with one sidebar owner: mode cards at family level and location cards at target level, never two simultaneous rails. Build buys/equips only; Style edits only the currently equipped option.

## Historical V1 Install And Verification

1. In Edit mode, run `scripts/roblox_owned_garage_phase14_lighting_and_flow.lua`. Require `PASS sourceWrites=5 lightingOptions=4 ... previewDraft=atomic saveNavigation=stay`.
2. Fully restart Studio and run `scripts/roblox_owned_garage_phase14_committed_state_audit.lua`. Require `COMMITTED STATE PASS`.
3. Enter the starter garage. Confirm exactly one `LightingRuntime.WholeGarageLighting` model covers all three former fixture positions.
4. Open Lighting Colours. Change Primary, then Secondary. Primary must not revert. Switch tabs repeatedly and verify the draft remains stable.
5. Press SAVE. The colour editor must remain open and show a saved confirmation. Close/reopen and rejoin; both colours must persist.
6. Preview a colour and press Back. The last saved colours must return.
7. Buy another lighting option; it must charge once and auto-equip. Equip an owned option and confirm its own saved colours return.
8. Repeat Structure and Decoration two-channel previews and SAVE. Neither may revert the other channel or navigate away on SAVE.
9. Repeat on desktop and a phone viewport. Verify Back/Exit, foot/vehicle entry and exit, display cars and cash remain unchanged.
10. Refresh the complete Studio mirror before advancing the canonical Phase 14 installer to the navigation stage.

## Rollback

Before assignment, all five projected sources compile. A failed installer restores all five exact source snapshots, destroys only lighting option models created by that run and restores tracked attributes. Rerunning the unchanged installer repairs a source/hierarchy persistence split. Behaviour rollback after a successful commit is the Phase 13 V1.4 Studio history point; do not run an older lighting patch over Phase 14.
