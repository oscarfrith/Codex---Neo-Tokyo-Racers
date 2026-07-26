# Customisation UI

## Shared Responsive UI Foundation V1.1 confirmed and handed off (2026-07-26)

The generated `scripts/roblox_shared_responsive_ui_foundation_v1.lua` extends the existing `RacingUIComponents` -> `GarageReplacementComponents` -> canonical workspace/browser chain. It does not create page-specific dealership, Customisation or owned-garage visuals.

`ResponsiveUIFoundation` owns semantic corner scaling (`0.70` desktop, `0.50` touch/mobile), compact money, bold Cash/Garage Spaces styling, response projection, replicated Cash binding, shared confirmation lifecycle and top-notification layout. `ModuleShopUIController.Adapter` still consumes the complete authoritative `Profile` returned by each garage action; owned-garage management still consumes the authoritative returned `ManagementState` and revision pushes. The new projection is presentation-only and creates no purchase, economy or persistence authority.

V1.1 is user-confirmed and represented in the complete `21:28:23` mirror. It adds shared device-aware structural/emphasis/glow widths and one bevel applicator to the enabled shared garage components. The same semantics flow through dealership, Customisation and owned-garage renderers.

The optional new Theme tuning nodes did not persist after Studio's mixed source/hierarchy command, but the identical V1.1 defaults are present in `ResponsiveUIFoundation` and drive the confirmed runtime. Existing garage UI geometry, state and actions are unchanged.

`GarageExperienceController_Active` remains intentionally disabled with `SupersededBy=NTR_GARAGE_REPLACEMENT_BROWSER_V1_4`. V1.1 neither enables nor rewrites that retired competing geometry owner.

Free-roam and racing vehicle-picker geometry, state, cards and actions are deliberately not migrated in this scope. Their existing surfaces may consume the foundational tokens without becoming a new composition owner. The full acceptance contract, owner inventory, exception audit and cross-device verification matrix are in `docs/shared-responsive-ui-foundation-v1.md`.

## Access refinement V1.1 correction (confirmed and handed off 2026-07-26)

V1.1 repairs the installed V1 owned-access nil call by removing an unused early reference to the later client-profile serializer. Both the native entrance and shared UI funnel now resolve access before starting their loading transition. Exact zero-vehicle denial uses the existing `UI.PurchaseRejected` semantic cue plus the shared top notification and does not flash a loading screen. Studio sandbox remains a start-of-session/reset and no-save tool, not an access exception.

## Access and full-session onboarding visibility V1 (generated 2026-07-26)

Customisation and Drive-In Customisation now have one intended access contract: the authoritative server refuses only when `profile.Vehicles` contains zero valid vehicle records. Missing or stale `CurrentVehicleId` is repaired through the existing vehicle selection owner and does not block an owner.

Native world prompts continue to cover keyboard `E`, controller `ButtonX`, and clickable touch activation. The server session gate protects world/drive-in routes before character presentation changes; `ModuleShopUIController.open` protects direct shortcut and bindable-event routes at their shared funnel. Both publish the exact zero-vehicle copy through one `ShowTopNotification` event and one `SharedTopNotificationController_Active`.

Objective-card visibility follows `NTR_GarageSessionActive` for Customisation and Drive-In, so transient Browser/Workspace/loading visibility cannot expose objectives between pages. Dealership and first-view page tutorials retain their prior rules. The confirmed three-workshop renderers and shared components are unchanged.

See `docs/customisation-access-onboarding-physical-colours-v1.md`. V1.1 is user-confirmed and fully represented in the `20:46:20` mirror.

## Presentation Audio V1 boundary (2026-07-26)

The generated `scripts/roblox_presentation_audio_ui_preview_race_v1.lua` adds audio without creating a second UI or preview owner. One event-driven binder covers existing/future `GuiButton` instances through `Activated`, with mouse hover and controller-focus additions. Existing shared card/render/layout components remain unchanged.

Dealership/customisation Idle and thrust-colour Boost preview Sounds are session-owned under SoundService, not parented to the preview car. `PreviewVehicleController` publishes only the selected audio-profile identity; the existing preview root remains VFX/state owner. Car/module/paint/slider rebuilds therefore keep the same loop, while a genuinely different future whole-vehicle sound profile crossfades.

Purchase, rejection and module-equip cues are emitted after the current central server result returns. No button text, toast copy or optimistic local state becomes authority. See `docs/presentation-audio-ui-preview-race-v1.md`.

Presentation Audio V1.1 treats successful module purchase as the same feedback class as successful module equip, because the purchase flow immediately adds that module to the player's usable module inventory. Failed module purchase remains a purchase rejection. The distinction is selected only after the existing authoritative result and does not change the buy/equip transaction.

Presentation Audio V1.2 gives successful dealership `BuyCockpitInstance` its own `UI.VehiclePurchaseSuccess` cue. Rejected vehicle purchases retain the shared purchase-rejection cue, while neon/cosmetic/property purchases keep the generic purchase-success cue. Existing purchase authority, prices, capacity, ownership and onboarding completion remain unchanged.

Presentation Audio V1.3 extends the same confirmed-result bridge to owned-garage assets. Decoration purchase, decoration equip/place, structure purchase and structure equip each have an independent described cue. A purchase already places/equips in the authoritative transaction and therefore emits only its purchase cue. Successful `AssignDisplay` reuses `UI.VehiclePurchaseSuccess`; a failed assignment remains a generic action rejection. No owned-garage UI renderer, transaction, price, persistence or preview owner changes.

## Vehicle customisation three-workshop flow V1

The approved root becomes `Add Modules`, `Upgrade Modules` and `Paint Shop` while retaining the confirmed `GarageWorkspaceController` layout and `GarageReplacementComponents` renderers. No page-specific copy of the rail, cards, action popup, upgrade budget or colour sliders is introduced.

Add Modules is the renamed current Build flow and preserves slot selection, Owned/Buy choice, module-instance cards, preview, purchase, move confirmation and auto-equip. Its left rail uses the same shared module-category card renderer for the three workshop routes.

Upgrade Modules uses one contextual rail containing only fixed module locations; it never exposes All, Cockpit, Thrust, paint, cosmetics or neon. Selecting a location immediately renders its current upgrade paths and shared upgrade-point budget. Empty locations and modules with no upgrade catalogue remain explicit bounded states. The performance summary stays visible because it is the existing upgrade-preview result, not a navigation action.

Paint Shop uses All, Cockpit, Thrust, Underglow and fixed module locations. Normal module locations show Paint left and Neon Lights right. Paint opens the existing sliders and exposes Primary/Secondary/Detail plus Neon only when that installed module instance owns Neon. Neon Lights uses the shared selected-card popup for BUY or CUSTOMISE; a successful purchase enters the Neon sliders directly. Paint Shop hides performance and upgrade-budget presentation.

The later confirmed Vehicle Cosmetics V1.2 extends this composition with a true buyable per-vehicle Underglow cosmetic and buyable Thrust Colour. An unowned cosmetic uses the shared purchase card; purchase opens its colour sliders, and later visits open sliders directly. Underglow availability is derived from attributed authored `SurfaceLight` objects on the cockpit. All Neon changes owned supported neon, including owned cosmetics, while front/rear vehicle lights remain protected. See `docs/customisation-three-workshop-flow-v1.md` and `docs/customisation-vehicle-cosmetics-empty-routes-v1.md`.

## Owned garage direct Decoration Style and Lighting channel contract V1

Decoration Style retains the same shared colour-slider renderer, tabs and Save/Back actions but removes its one-card Colour intermediary. Entering Style > Decorations defaults to All Decorations and opens sliders immediately when compatible equipped content exists. Selecting another equipped location in the left rail reinitialises that location's sparse draft and stays in the slider composition. Empty locations retain the shared Install Asset route; content with no colour capability retains the shared unavailable state. Back returns directly to the Style family page.

Lighting tabs remain server-capability-driven. Descendant names do not matter: BaseParts and attached `PointLight`, `SpotLight` and `SurfaceLight` objects inherit Primary or Secondary from their nearest canonical authoring folder. Empty channels do not render. The Lighting Save action now consumes `OwnedGarageIcons.Navigation.Save`, matching Structure and Decoration.

Physical garage prompts are outside the workspace renderer but share its transition presentation. ClearNight V1.2 makes their server callbacks session-safe: existing Drive Out, foot-exit and management-desk prompts are rebound exactly once whenever a cached interior is reused or its displays rerender. This prevents a visible prompt from opening loading UI without producing its corresponding server result, while retaining the existing management-open prompt suppression policy.

## Owned garage central icon configuration V1.1

Owned-garage-specific images now have one planned config authority at `Config.UI.GarageReplacement.OwnedGarageIcons`. Nested attribute folders separate root Modes, asset Families, six Structure locations, six Decoration locations, navigation, Access/Invite, browser actions, capacity and the empty-Style `InstallAsset` route.

The owned controller resolves stable section/slot IDs rather than display text. Location values fall back to the matching family icon, while shared navigation, glyph and capacity artwork remain compatibility fallbacks. This preserves current presentation while allowing each icon to be replaced independently.

`OwnedGarageIcons.Sizing.StructureLocationImageZoom` and `DecorationLocationImageZoom` independently control the two location-card families. Both default to `1.0`, twice the shared navigation default of `0.5`, and are clamped to `0.2–1.5`. Root Mode/Family cards and specialised vehicle/finish cards continue using their existing shared owners. See `docs/owned-garage-icon-configuration.md`.

## Owned garage mobile access dropdown contract

The interior access HUD is a compact overlay rather than a full 1600-by-900 workspace. On touch devices its `AccessControls` root receives one configurable `UIScale`, and the shared anchored dropdown is given that exact scale so anchor positions, panel width, row height, icons and labels remain in the same coordinate space. Tune `InteriorHudTouchReferenceWidth`, `InteriorHudTouchReferenceHeight`, `InteriorHudTouchMinimumScale` and `InteriorHudTouchMaximumScale` on `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.OwnedGarage_EditAttributes`; do not resize the dropdown rows independently of their Private/Invite anchors.

## Owned garage Phase 14 V2.2 responsive navigation closure (confirmed)

Structure and Decoration location rails now provide stable family-level `CategoryScrollKey` values to the existing shared scroll-memory owner. Moving between option, colour and material pages no longer creates a new page-specific memory bucket, so a long mobile rail stays near the user's selected location.

When a selected Style Garage decoration location is empty, the bottom carousel shows one normal shared category card that opens Build Garage on the same location. The card is navigation only: purchase/equip remains in Build, styling remains in Style and equipped assets without supported colour channels do not show a false editor.

The user confirmed this composition working and refreshed the full mirror. Treat the shared card, rail, listing, channel-tab, paint and material renderers as the locked submission baseline; future visual changes should extend those shared contracts rather than reopen Phase 14 page-specific text patches.

## Owned garage Phase 14 V2.1 shared navigation-card image scale (confirmed)

Bottom root/family navigation and sidebar mode/location navigation already share `ModuleCategoryCard`. V2.1 removes their only remaining divergence by routing both through `OwnedGarageCategoryCardImageZoom` (`0.5` default, bounded `0.2–1.2`). The owned controller applies it only to image-backed category navigation rows without a specialised `CardKind`; dealership-style vehicle/listing cards and finish controls are unaffected.

## Owned garage Phase 14 V2 shared Build/Style composition

The generated V2 composition reuses the existing shared workspace instead of adding a new page owner. The root shows Display Cars, Build Garage and Style Garage as `ModuleCategoryCard` instances. Mode/family pages use the same scroll-backed left rail; Structure and Decorations swap its data to locations at target depth. Lighting retains the mode rail because it is a whole-garage option.

Build uses shared listing cards and selected-card popups for preview plus BUY/EQUIP only. Style uses shared category cards, channel tabs, paint controls and material cards for the equipped option only. Root has no rail, no page creates two rails, and all actions continue through `Activated` and the scaled `1200 x 720` host.

## Owned garage Phase 14 V1 lighting and editor-state foundation

Phase 14 V1 keeps the existing workspace composition while establishing the approved future navigation's state contract. Whole-garage Lighting now uses the shared listing cards, shared Primary/Secondary channel tabs and shared H/S/B picker. Option availability and authored default colours come from populated ServerStorage folders; the client does not maintain lighting-channel lists.

Structure, Decoration and Lighting editors retain one complete draft across channel switches. Physical preview commits submit the complete populated draft and the active server session also merges same-target previews defensively. SAVE updates authoritative revisioned state but deliberately retains the active editor route. Back/Exit remains the cancellation owner. See `docs/owned-garage-phase14-lighting-and-flow.md`.

After V1 confirmation, the same canonical installer advances to `DISPLAY CARS`, `BUILD GARAGE` and `STYLE GARAGE`, reusing `ModuleCategoryCard`, the shared scroll-backed left rail, listing/action cards, channel tabs, paint renderer and responsive workspace. Only one rail is visible: mode cards at family level or location cards at target level.

## Owned garage shared material-channel contract (Phase 13 V1.3 generated)

- Structure Material opens directly to material cards. The same `GarageWorkspaceController:RenderChannelTabs` component renders Primary/Secondary/Detail for both Colour and Material; the owned page does not copy tab dimensions or colours.
- Tabs sit directly above the material carousel, show only server-projected populated material channels, preserve pending selections while switching and fit as one responsive row on mobile. Neon remains colour-only.
- Material cards consume `{Id, DisplayName}` definitions. Stable IDs are saved and submitted; player-facing labels may change without migrating profile data.
- Selecting a card previews only the active channel. SAVE submits all pending populated material channels in one revisioned command. Back/Exit uses the existing preview cancellation owner.
- Matching authored materials receive the normal selected-card highlight. There is no `Original` label and no false selection when an authored material is outside the approved registry.

## Owned Garage Phase 13 Dynamic Finish Controls

The generated Phase 13 installer extends the existing owned-garage workspace rather than copying the dealership/customisation UI. Structure and Decorations continue to call the shared H/S/B paint renderer. The management response supplies `ColourChannels` and `MaterialChannels` derived from populated ServerStorage folders, so page code does not maintain per-asset button lists.

All assets expose Primary, Secondary, Detail and Neon authoring folders, but only non-empty folders render controls. Decoration customisation is colour-only. Structure exposes material selection only for populated Primary/Secondary/Detail folders; Neon never receives a material. `Fixed` and `Technical` descendants stay authored, and `GarageMaterialLocked=true` protects exceptional structure parts inside a colour folder.

Slider UI updates continuously while physical preview is requested only on committed input. SAVE performs one revisioned authoritative mutation; Back/Exit use the existing preview cancellation owner. The same responsive `1200 x 720` host, shared cards/actions, `Activated` input and touch scaling remain in force. See `docs/owned-garage-phase13-typed-finishes.md`.

Phase 13 V1.1 adds a sixth optional `DisplayPlatforms` decoration zone without creating a new UI composition. Three paired-platform option containers use the same listing cards and shared colour renderer, remain hidden while empty/`Available=false`, and appear only after a populated authoritative ServerStorage option is enabled. Each option contains both display platforms at template-relative positions; vehicle display markers and display assignment state remain separate. Existing decoration/structure assets stay slot-local under the no-move repair, while new paired platform assets use `GaragePlacementMode=TemplateOrigin`.

When geometry is added to a previously empty option, folder placement is the authoring source of truth: parts beneath `ColourSlots/Primary|Secondary|Detail|Neon` receive that matching channel attribute, while parts outside those folders are finish-protected. The canonical V1.3 installer now reapplies this metadata to both ServerStorage and ZZZ `PlatformOption01` copies without changing their hierarchy or transforms.

Phase 13 V1.2 does not change the management UI composition. The browser continues to own garage entry interaction and the shared loading runtime continues to own full-screen presentation. A bounded streaming handler now keeps that presentation active until the named destination marker is locally replicated, then acknowledges only the server-issued token. `CollisionShell` is template technical geometry and never appears in Structure/Decoration cards, paint channels, material controls, preview state or saved customisation.

## Shared Loading Presentation Phases 1-5

`scripts/roblox_ui_loading_and_start_screen_system.lua` is the canonical phased installer for major experience transitions and the initial Play/Shop start screen. Phases 1-4 and the readiness gate are confirmed; the user confirmed Phase 5 V1 working well. V1.1 refines only its isolated early client under `ReplicatedFirst.NTRLoading`.

The loading owner suppresses the existing free-roam HUD through `FreeRoamHudPresentationMode`; it does not scan or recreate the HUD. V1.3 retains the six tiled ImageLabels under the same artwork owner and tunes that common parent's motion to a five-second `Sine Out`, `1.06→1.10` zoom and `1.2%` pan. Phase 2 keeps dealership/customisation navigation with its confirmed owners. Phase 3 keeps `OwnedGarageBrowserController` as the owned client transition owner and uses the existing management result push for physical prompt completion.

Future UI owners observe retained `LoadingPresentationState` plus `LoadingPresentationChanged` rather than relying on an event they may miss during startup. Phase 5 V1.1 mounts only shared `RacingUIComponents.Button` actions inside the safe-content root; artwork remains full bleed and supplies all branding. Optional icon IDs come from `LoadingSystem.StartScreenPlayIconAssetId` and `StartScreenShopIconAssetId`. Desktop/tablet and phone portrait/landscape layouts share the same two buttons, with touch short-side detection preventing a landscape phone from using desktop metrics. PLAY releases the runtime; SHOP calls the existing dealership teleport. Camera, spawn and dealership geometry remain with their current owners.

The refreshed `2026-07-21 10:48:31` mirror confirms V1.4 Grid3x2 and user-confirmed Phase 5 V1.3 button placement. V1.3 changes only the isolated initial/start client and uses three config Y-scales for desktop, landscape phone and portrait placement. Every branch calls the same safe-root clamping helper, retaining an eight-pixel bottom inset after device scaling rather than maintaining unrelated hard-coded positions. The user reports Phase 6 audit/manual behaviour working as expected, so this captured composition is handed off as the complete shared loading UI baseline; see `docs/loading-system-phase6-closure-handoff-2026-07-21.md`.

## Owned Garage Browser Contract

Owned Garage Phase 3 stages one inactive `OwnedGarageBrowserController`. It uses the real `RacingUIComponents`, `RacingMobileScaledDesktopLayout` and `GarageReplacementComponents` modules to build the Race Browser-sized `1200 x 720` My Garages shell. Property cards and detail presentation support image, title, district, description and display capacity; full drive-in replacement uses shared action buttons and explicitly states that the replaced display vehicle remains owned. All actions use `Activated`, and the single desktop composition is scaled for touch rather than duplicated into a separate mobile UI tree. The controller is a ModuleScript only and is not started at this checkpoint.

Phase 4 stages one inactive `OwnedGarageWorkspaceController` for the interior desk. It directly constructs the existing `GarageWorkspaceController`, so Display Cars, Interior and Access use the same canonical host, layout function, cards, carousel, selected-card popup and responsive behavior as dealership/customisation. Display Cars is space-first and operates on saved vehicle IDs; Interior presents catalogue-driven surface presets; Access saves a future visitor policy while admission stays disabled. No page-specific copy of the shared workspace was introduced.

Phase 4 recovery passed `18/0` and the refreshed `2026-07-19 12:04:54` mirror contains the style catalogue, workspace controller and open event. Phase 5 is `scripts/roblox_owned_garage_phase5_mobile_safety_hardening.lua`. It keeps the same browser/workspace composition, adds explicit `Close`/`IsOpen` contracts for transition cleanup, preserves `Activated`, and derives touch-button logical height from the live shared scale so the owned UI targets a configurable 44 physical pixels without creating a second mobile tree. The staged transition controller closes owned surfaces when another major presentation takes ownership; it contains no frame loop.

Phase 5 passed in the refreshed `2026-07-19 12:14:59` mirror. Phase 6 starts the browser/workspace/mode/transition modules exactly once through one small client starter and replaces only the desktop/mobile HOME callbacks with `OpenOwnedGarageBrowser`. It disables the legacy physical-garage access/interior clients, but does not alter the confirmed dealership/customisation application, shared renderer, preview, camera or VFX owners.

Phase 8 V1.5 removes the owned-garage-specific compact category geometry. The management rail now calls the same `ModuleCategoryCard`, `LeftSharedCardSize` and `LeftAlignCarouselBottom` contracts used by Build Modules; it does not copy that page's coordinates. `LeftFitContent` is intentionally absent because the shared workspace currently calculates that mode from normal text-button height rather than image-card height, which clipped the four owned-garage categories. Desktop and touch continue to use the one scaled shared composition.

Management-state presentation has one refresh owner during mutations. A `ManagementUpdated` revision received while an assignment or state read is active is coalesced into that read instead of spawning a competing request. Temporary refresh failure displays status while preserving the visible page; only a successful authoritative response that says the player is no longer in a garage may close the workspace.

Phase 8 V1.6 adds a reusable `CardKind="Vehicle"` route to `GarageWorkspaceController`. It calls the exact `GarageReplacementComponents.Card` used by dealership Choose Vehicle and consumes the same `CardWidth`, `CardHeight`, `CardImageHeight`, name overlay, rating badge and artwork fit. Module/category/listing routes remain unchanged. Both vehicle choices and occupied display spaces use this route; empty spaces add the existing shared plus treatment. Carousel button stepping derives from the rendered card width so mixed future card kinds do not inherit a module-only constant.

Vehicle selection and assignment are separate visible states. A card becomes selected and receives the shared `DISPLAY` popup only after `PreviewDisplay` succeeds. `DISPLAY` sends the revisioned mutation, and the client verifies the returned authoritative garage snapshot contains the requested `VehicleId` in the requested slot before it reports success or returns to Display Spaces. Back/Exit may cancel an unsaved preview; they must rebuild and preserve committed displays. The free-roam desktop/mobile HUD owners suppress themselves while the existing management-open attribute is true, while the workspace's own capacity/cash cards remain visible.

## Canonical Garage Confirmed Baseline — 2026-07-18

The dealership, owned customisation and drive-in flows are user-confirmed working in the refreshed `2026-07-18 23:14:48` mirror. Browser and Workspace share the approved shell, cards, stats, economy, action popups, responsive scaling and navigation contracts. Physical module instances retain their saved colours, neon and upgrades; temporary module/neon/colour previews clear on page transitions without mutating persistence.

The final presentation uses the shared preview pad, orbit/zoom camera, category-relative camera views, hover wobble, 8 PM garage lighting and a single preview VFX owner. Start future work from `docs/garage-canonical-handoff-2026-07-18.md`. Sections below describing older phases as “next”, “prepared” or “awaiting verification” are retained as implementation history and do not override the handoff.

## Shared Physical-Module Cards And Modal (Generated, Awaiting Studio Verification)

`scripts/roblox_ui_garage_module_shared_cards_modal.lua` is generated against the user-confirmed atomic transaction mirror. The audit found that the catalogue and shared listing-card component already held the correct vehicle display name, price, semantic colours and physical ownership state; `GarageWorkspaceController` dropped those fields when building the shared card props. The installer forwards that existing contract rather than adding another card implementation.

The same bounded client phase canonically replaces the small `GarageModuleCardViewModel` so Owned cards sort `Equipped -> Available -> In Use`, then highest rating first inside each group. `ModuleShopUIController` now consumes `SourceCockpitDisplayName` before fallback lookup and makes its existing shared modal fill the scaled canonical canvas, block background input and audit both full coverage and exact centring at runtime. No server, persistence, transaction, preview, bootstrap or gameplay source is changed.

## Atomic Physical Module Transactions (Generated, Awaiting Studio Verification)

`scripts/roblox_ui_garage_module_atomic_transactions.lua` is the next approved Studio installer. It adds an isolated `GarageModuleTransactionRuntime` and replaces only the existing physical-copy buy/equip functions plus the canonical Buy callback. Buy now creates exactly one fresh module copy and equips it immediately. Equip/reassignment snapshots the complete profile, treats vehicle slot references as canonical, preserves the selected copy's saved colours/neon/upgrades, and rolls back cash, inventory and references together on any fit or invariant failure.

When a copy moves from another vehicle, the old slot receives the lowest-rated compatible available physical copy. Explicit rating fields win; the current source-vehicle/variant order is a deterministic fallback until the dedicated module-rating phase. If no replacement exists, a required Engine/Stabilisers/Boost configuration rejects and rolls back the move; an optional cosmetic slot may remain empty and is reported explicitly. Do not patch these rules back into the large controller after installation—the isolated transaction runtime is the shared authority.

## Canonical Garage Phase 1 V3 Refinement (Awaiting Studio Verification)

The current next Studio run is V3 of `scripts/roblox_ui_garage_phase1_transactional_canonical_application.lua`, documented in `docs/garage-phase1-transactional-canonical-application-2026-07-15.md`. It preserves the substantially improved V2 ownership bridge and existing-instance host. It moves previews to the authoritative GaragePreviewPad, adds isolated orbit/zoom/configurable fade behavior, shares image category cards between Build and Customise, and adds image-free grouped Owned/Shop listing cards with pink unselected and cyan selected outlines. Do not rerun the older remaining-menu or visual-repair installer ladder.

## Superseded Canonical Garage Replacement V2

The current path is `scripts/roblox_ui_garage_replacement_foundation_browser.lua` followed by the same consolidated `scripts/roblox_ui_garage_workspace_remaining_menus.lua`. V2 upgrades the installed workspace in place: vehicle selection, Paint, Build Modules and Customise use one shared shell layout and performance renderer; the module-slot page has no left rail; post-selection Exit is removed; Paint cannot go Back; module names are larger/bold; and the equipment badges and core progression gate resolve the same current-vehicle module instances. Do not return to the superseded canonical-experience/V3 visual repair ladder.

## Canonical Dealership And Customisation Experience (Correction Awaiting Rerun)

The approved consolidated replacement is `scripts/roblox_ui_garage_canonical_experience.lua`. Initial V1 is present in the refreshed `2026-07-14 20:05:44` mirror; its stats worked, but the legacy bootstrap layout and delayed camera still won at runtime. The same installer now owns the bottom-only carousel, activates the existing garage camera immediately, sorts rated vehicles lowest-to-highest from left to right, previews the leftmost vehicle on entry/category change, and keeps unrated entries last. It retains shared `E`/tap/controller prompts, server-visible hide/freeze/return, image/name/rating cards, selected-card-centred BUY/CUSTOMISE popup, four-column stats, `ALL` plus alphabetical categories, duplicate ownership text, category module diagrams, and Cockpit Colour-first flows. Existing garage API, persistence, inventory, Phase AO upgrades and spawn behavior remain authoritative.

The latest refinement in that same installer replaces the generic preview-marker entry orbit with the exact Cockpit Colour framing, scales nested vehicle images to the full card image region, makes selected card state authoritative for BUY/CUSTOMISE popup visibility, and replaces the flat repaint pass with the approved `DesktopFreeRoamHud` colour/effect tokens, gradients, semantic strokes, restrained glow and hover states.

The installer contains guarded exact-source bridges in the active bootstrap and garage server. Treat it as fragile and stop on any preflight/anchor failure. Repair the same canonical installer rather than creating additional phases without approval.

## Visual Style

The UI direction is futuristic, compact, and readable. It uses:

- Michroma-style futuristic text where possible.
- Dark translucent panels.
- Light green borders/accent colour.
- Consistent button sizing.
- Responsive scaling for mobile and desktop.

Avoid oversized landing-page style UI. The garage/customisation UI should be functional and scan-friendly.

## Approved PC Free-Roam UI Design Baseline

On 2026-07-10 the user approved a six-screen PC free-roam visual family covering the main HUD, car menu, dealership teleport confirmation, controls, cash store, and settings. The concepts and authoritative colour/component rules are documented in:

```text
docs/ui-free-roam-pc-design-system-2026-07-10.md
assets/ui/mockups/free_roam_pc/
```

This remains the approved design target. Phase 1 has now been installed as a first working shell, but its first screenshot review did not accept the implementation as the final visual baseline. Future implementation must use the shared token rules from that document, preserve the existing E-S vehicle tier colours, keep presentation in isolated controllers/modules, and avoid adding UI construction helpers to the register-limited client bootstrap.

Before generating the visual-shell installer, run the read-only audit:

```text
scripts/roblox_ui_freeroam_pc_phase0_audit.lua
```

Phase 0 passed in Studio Edit mode on 2026-07-10 with `pass=35 warn=2 fail=0`. The two warnings were expected missing setup objects. Phase 1 was installed from `scripts/roblox_ui_freeroam_pc_phase1_visual_shell.lua` and is documented in `docs/ui-free-roam-pc-phase1-visual-shell-2026-07-10.md`. It installs the isolated configurable PC presentation and real existing free-roam actions without patching the register-limited bootstrap. Moving minimap, final boost telemetry, server dealership teleport, cash receipts, and persisted settings remain later phases.

The Phase 1 screenshot review found structural layout issues rather than isolated colour tweaks. Phase 2 established the responsive visual system and live boost telemetry. Phase 3D's north-up 2D map with transparent image-only markers and Phase 4A's shared dealership-confirmation/teleport flow were installed and confirmed working. Phase 4A is the current PC free-roam UI baseline in the refreshed Studio mirror. Later free-roam phases are intentionally deferred; preserve the shared theme/config and isolated-controller approach when race/time-trial UI adopts the same design language.

## Mobile Free-Roam UI Phase 1

The first canonical mobile free-roam redesign is generated in:

```text
scripts/roblox_ui_freeroam_mobile_phase0_audit.lua
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
docs/ui-free-roam-mobile-phase1-canonical-hud-controls-2026-07-13.md
```

It replaces the retired Phase 16E compatibility loaders with isolated touch-only
HUD and control owners, reuses the Phase 4A map/theme/action contracts, and puts
`Arrows | Thumbstick | Tilt` at the top of mobile Settings. Arrows are the
default; Tilt is gyroscope-gated and includes held Drift plus Recenter. The four
upload-ready transparent control images live under
`assets/ui/icons/mobile_controls/`. Phase 1 is not the confirmed baseline until
the audit, Device Emulator checks, real-device Tilt test, and mirror refresh pass.

Phase 1 was installed and mirrored at `2026-07-13 14:58:02`. Screenshot review
then identified five concrete parity issues: incorrect map transform/missing
fades, vertical navigation, approximate telemetry, undersized controls, and the
bootstrap-created legacy DriveHUD remaining visible. Phase 1B upgrades the same
canonical installer with exact Phase 4A component contracts and exact-child
legacy HUD suppression while preserving the ScreenGui driving-state signal. Use
`docs/ui-free-roam-mobile-phase1b-pc-component-parity-2026-07-13.md` for the next
Studio rerun and verification.

Phase 1C supersedes Phase 1B as the next rerun. It keeps the same canonical
owners and contracts, aligns the action row left of the top-right map, moves cash
directly below the map, widens arrows `1.5x`, moves the real lightning boost
target above the steering cluster, and rebuilds bottom telemetry around a shallow
overhead speed arc and vertical boost meter. Use
`docs/ui-free-roam-mobile-phase1c-layout-refinement-2026-07-13.md`.

Phase 1C was user-approved and mirrored at `15:33:06`. Phase 1D adds the mobile
car menu inside the same canonical HUD owner. It scales the PC two-column menu
onto the left beneath Roblox controls and reuses PC profile/category/sort/card,
tier, selection, Buy More, spawn, and Despawn contracts. The world is not
darkened; a transparent outside-tap layer leaves the top HUD visible but blocks
its actions and closes the menu. See
`docs/ui-free-roam-mobile-phase1d-pc-parity-car-menu-2026-07-13.md`.

Phase 1D worked overall, but its cards were sized only from horizontal width and
could be clipped by the grid/footer boundary. Phase 1E uses the available grid
height to fit three complete rows while preserving the PC card aspect ratio and
adds the PC stroke/top/bottom safety-padding system. It also ports the PC
effects-driven panel/card/button gradients and replaces pink-outlined expanded
dropdown options with the PC borderless neutral surface. See
`docs/ui-free-roam-mobile-phase1e-responsive-car-menu-parity-2026-07-13.md`.

Phase 1E dropdown styling was approved, but three complete rows made cards too
small. Phase 1F targets two complete rows and derives the entire panel width from
two larger cards plus one compact gap and side padding. It also compacts the
title, dropdowns, Despawn, footer, internal card spacing, and screen-edge margins.
The open dropdown now closes when its own field is tapped again. See
`docs/ui-free-roam-mobile-phase1f-fitted-car-menu-layout-2026-07-13.md`.

Launched-phone testing of Phase 1F confirmed the overall menu but exposed clipped
long vehicle names and excess chrome. Phase 1G keeps each name complete on one
self-fitting line, reduces target cards to `160 px`, removes the menu title and
field captions, moves shorter dropdowns to the top, shortens Despawn, and removes
the outer-panel/Despawn borders and glow while retaining the approved gradients,
card borders, and dropdown toggle. See
`docs/ui-free-roam-mobile-phase1g-compact-borderless-car-menu-2026-07-13.md`.

Phase 1G looked better in follow-up testing, but its cards still occupied too
much space and long cash balances could escape the card. Phase 1H reduces target
cards to `108 x 95`, scales the badge, rating, vehicle name, fallback, stroke, and
Buy More content with them, and constrains cash to a self-scaling region left of
the Plus button with card clipping as a final guard. See
`docs/ui-free-roam-mobile-phase1h-smaller-cards-cash-fit-2026-07-13.md`.

Phase 1H screenshot review showed that smaller target dimensions alone were not
enough: the height solver still reserved only two rows. Phase 1I explicitly sets
`CarMenuVisibleRows = 3`, targets `92 x 80` cards, and lets short screens reduce
them further so three complete rows fit above Despawn. See
`docs/ui-free-roam-mobile-phase1i-guaranteed-three-card-rows-2026-07-13.md`.

Phase 1I's three-row layout was user-confirmed looking great. Phase 1J moves only
the vehicle artwork slightly lower within each card and strengthens the existing
background-only Despawn gradient while keeping its border and glow removed. Both
values are editable config attributes. See
`docs/ui-free-roam-mobile-phase1j-card-art-despawn-gradient-2026-07-13.md`.

Phase 1J was user-confirmed good. Phase 1K keeps the Boost hit target unchanged,
reduces only the visible lightning icon, adds a circular blue-to-cyan plate that
matches the boost bar, and dynamically aligns Exit's bottom with the lower
turning buttons. See
`docs/ui-free-roam-mobile-phase1k-boost-plate-exit-alignment-2026-07-13.md`.

## Shared UI Theme

The current editable UI colour source is:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme
```

The mirrored shared helper path is kept for compatibility:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Config.UI.Theme
```

Use `scripts/roblox_ui_shared_theme_back_exit_and_intro.lua` to add dedicated `Back` and `Exit` `Color3Value`s to both theme folders and patch the active UI scripts to read them. After that script is installed, `ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme` is the practical place to edit colours for the live UI and the shared UI helper prefers it first.

After the patch:

- dealership Back buttons use `Theme.Back`;
- Exit and close buttons use `Theme.Exit`;
- the dealership intro objective UI reads the same shared panel, text, accent, transparency, corner, and font values as the dealership UI.

The installer is a guarded exact-source patch against the active dealership bootstrap, the isolated intro client, and shared UI theme modules. If it cannot find the expected source shape, stop and refresh the Studio mirror before attempting another UI patch.

## Free Roam Left Navigation

Phase 1 is generated as `scripts/roblox_freeroam_left_nav_phase1.lua` and documented in `docs/freeroam-left-nav-phase1-2026-07-03.md`.

Phase 2 is generated as `scripts/roblox_freeroam_map_stack_phase2.lua` and documented in `docs/freeroam-map-stack-phase2-2026-07-03.md`. It supersedes the left rail layout with a top-right map stack based on the user's sketch:

```text
MAP
CAR
SHOP | RACE
HOME | SETTINGS
```

The goal is a themed top-right free-roam/driving stack with five icon buttons:

- Car
- Race
- Garage/Home
- Settings
- Dealership

The implementation is intentionally isolated in `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active` and reads config from `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav`. It does not patch the large dealership bootstrap.

Phase 2's map area is only a placeholder. The actual Illustrator map image, world-bounds calibration, player-position panning, and heading rotation should be handled in a later minimap phase.

The stack suppresses the old free-roam `DriveMenu` exit panel and the old right-side `NTR_GarageAccessUI` toggle, while preserving the speed/boost HUD and mobile driving controls. Phase 2.11 shows the stack during normal on-foot and driving free roam, hides it while dealership/customisation UI is open, makes the desktop/laptop stack about 20% smaller, keeps the car button height/icon scale consistent with the grid buttons, gives action pop-outs the same height as the full stack, layers stack buttons as dark base plus visible pink outline plus inset configurable gradient plus hover overlay plus icon, keeps pop-out action buttons as solid fills without gradients, and adds local text-glow controls for free-roam pop-out labels/action buttons. The installer also repairs the mobile desktop-HUD helper block if the earlier Phase 2.4 anchor removed it and now preserves existing `FreeRoamNav` Bool/Number/Color tuning values on rerun.

The glow around `ENTER GARAGE` / `RETURN CITY` text would be a good shared UI theme improvement for dealership and customisation too, but should be handled as its own guarded phase because it touches the larger dealership/customisation UI scripts rather than only this isolated free-roam controller.

Preferred plain white overlay icon PNGs are stored under `assets/ui/icons/freeroam_nav_plain/`. Upload the five `freeroam_plain_*.png` icons to Roblox and paste the resulting `rbxassetid://...` values into the matching `*Icon` StringValues under `FreeRoamNav`; until then the UI uses compact text fallbacks. These icons are transparent and should sit on top of Roblox-made dark grey/pink beveled UI frames.

Free Roam Car Menu Phase 3 is prepared as `scripts/roblox_freeroam_car_menu_phase3_owned_cockpit_cards.lua` and documented in `docs/freeroam-car-menu-phase3-owned-cockpit-cards-2026-07-05.md`. It keeps the isolated free-roam nav controller but changes the `Car` pop-out to use owned cockpit image cards with per-vehicle tier/rating badges, 2 columns on desktop/laptop, 1 column on mobile, and a fixed bottom `Despawn` button. It removes the old vehicle-id text, `Exit Vehicle`, and `Customise` buttons from that pop-out.

Free Roam Car Menu Phase 4 is prepared as `scripts/roblox_freeroam_car_menu_phase4_card_scaling_sort_future_spawn.lua` and documented in `docs/freeroam-car-menu-phase4-card-scaling-sort-future-spawn-2026-07-05.md`. It enlarges cockpit images, changes the car pop-out to 3 columns on desktop/laptop and 2 on mobile, removes badge text glow, uses the normal pink card outline instead of tier-coloured/cyan selected outlines, sorts by rating descending, and adds `VehicleId` / `CockpitId` card attributes for the next spawn/select phase.

Free Roam Car Menu Phase 5 is prepared as `scripts/roblox_freeroam_car_menu_phase5_image_fit_border_padding.lua` and documented in `docs/freeroam-car-menu-phase5-image-fit-border-padding-2026-07-05.md`. It replaces the Phase 4 image zoom/crop-style approach with `Fit` plus a fixed inner padding, makes image-box/card outlines match the pink free-roam frame border style, and moves the `Despawn` layout down so bottom padding matches the side padding.

Free Roam Car Menu Phase 6 is prepared as `scripts/roblox_freeroam_car_menu_phase6_card_surface_root_fix.lua` and documented in `docs/freeroam-car-menu-phase6-card-surface-root-fix-2026-07-05.md`. It addresses the clipped/weird cockpit-card border at the root by making the grid click cell transparent and moving the visible background/border onto an inner `CardSurface`. The card surface wraps the image and text, desktop keeps the liked larger image size, mobile image max size is reduced, and future spawn/select card attributes are preserved.

Free Roam Car Menu Phase 7 is prepared as `scripts/roblox_freeroam_car_menu_phase7_borderless_card_frames_compact_width.lua` and documented in `docs/freeroam-car-menu-phase7-borderless-card-frames-2026-07-05.md`. It removes `UIStroke` from the free-roam cockpit cards and image boxes entirely, replacing those borders with normal filled frame layers to avoid clipping inside the scroll/grid layout. It also narrows the default car pop-out to fit 3 compact desktop cards or 2 mobile cards.

Free Roam Vehicle Spawn Phase 1 is prepared as `scripts/roblox_freeroam_vehicle_spawn_phase1_audit.lua` and documented in `docs/freeroam-vehicle-spawn-phase1-audit-2026-07-05.md`. It is read-only and should be run before implementing cockpit-card click-to-spawn. The intended next behavior is for each owned cockpit card to spawn/swap that vehicle, with the server enforcing ownership, a `10 mph` speed limit, current-vehicle despawn, nearest-road placement, and automatic seating.

Free Roam Vehicle Spawn Phase 2 is prepared as `scripts/roblox_freeroam_vehicle_spawn_phase2_road_spawn_markers.lua` and documented in `docs/freeroam-vehicle-spawn-phase2-road-markers-2026-07-05.md`. It creates explicit invisible `NTR_RoadSpawnPoint` markers from safer exact road/asphalt parts and seeds `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamVehicleSpawn`. Phase 3 should use those tagged markers rather than broad road-edge meshes.

Preferred Phase 2 first pass: `scripts/roblox_freeroam_vehicle_spawn_phase2_blockout_road_markers.lua`, documented in `docs/freeroam-vehicle-spawn-phase2-blockout-road-markers-2026-07-05.md`. It uses the curated `Workspace.Test + WIP Assets.Blockout.Roads` folder and creates one lightweight invisible marker above each `Road` part centre only when the part colour is `RGB(95, 95, 95)` / `#5f5f5f`. This is safer than scanning the whole city because the source folder already represents intended road surfaces and differently coloured wall pieces are skipped.

Free Roam Vehicle Spawn Phase 3 is prepared as `scripts/roblox_freeroam_vehicle_spawn_phase3_click_spawn.lua` and documented in `docs/freeroam-vehicle-spawn-phase3-click-spawn-2026-07-05.md`. It adds the guarded server action `SpawnOwnedVehicleFromFreeRoam` and wires owned cockpit cards to spawn/swap into that vehicle at the nearest clear `NTR_RoadSpawnPoint`, with a server-side speed gate defaulting to `10 MPH`.

## Dealership Flow

### Studio cash testing helper

`scripts/roblox_studio_cash_grant_hotkey.lua` installs an isolated Studio-only test helper for dealership/economy balancing. The `LucidityStudios` player can press `=` to add `$100,000` through the existing authoritative garage cash/persistence bridge. Amount, key, account name, enabled state, and cooldown are attributes under `Config.Runtime.StudioCashGrant`. The server contains a non-configurable `RunService:IsStudio()` guard, so the remote cannot grant cash in published servers. See `docs/studio-cash-grant-hotkey-2026-07-13.md`.

Known dealership structure:

- Category menu on the left.
- Cockpit grid in the centre.
- Vehicle stats panel on the right.
- Available cash panel near the lower left.

2026-06-03 dealership intro phases 1-7:

- `Workspace.NeoTokyoRacersWorld.Dealership.Intro` is the planned marker root for spawn, desk trigger, camera, preview, and path nodes.
- Phase 1 marker setup is world/layout only; it does not change auto-open, preview camera, garage UI, or purchase behavior.
- Runtime reads `Intro` attributes and keeps camera/objective/garage UI state per player where practical.
- Phase 2 installs `DealershipIntroClient_Active` for local objective text, local path arrows, and desk distance detection.
- Phase 3 gates the full garage menu so it should open from the desk intro hook instead of immediately on spawn.
- Phase 4 delays the local vehicle preview until a cockpit purchase/select succeeds, then places it at `Intro.Preview.VehiclePreviewPoint` and uses `Intro.Camera.GaragePreviewCameraPoint`.
- Phase 5 restores the existing garage orbit camera behavior after preview creation; the marker sets the first view, then players can rotate around the vehicle centre and module selection can rotate to slot areas.
- Phase 6 adds `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` for the final server-created drivable vehicle after customisation. This is separate from the client-only preview marker.
- Phase 7 adds an Exit button to the first cockpit-buy menu. It should sit in the bottom-right right column, aligned with the vehicle stats panel right edge and the Available Cash panel bottom edge, and reopen only after the player leaves and re-enters the desk zone.
- VFX Phase AJ keeps thrust VFX preview attached to the Phase 4 local-only preview root: `Workspace._NTR_ClientOnly.VehiclePreview`.
- Vehicle Phase AK makes dealership cockpit stats include the selected cockpit's standard engine pair, standard stabilisers, and standard boost so the bars reflect what the cockpit includes when purchased.
- `scripts/roblox_dealership_remove_cockpit_module_slots_text.lua` removes the extra cockpit module-slot count text from the selected cockpit stats panel because it can overlap other dealership UI. The stats still include default modules, and the later Build Modules flow is unchanged.
- The user confirmed Phase 1-7 working on 2026-06-03.

Dealership / Customisation Split Phase 1 was run by the user and reported working on 2026-07-04. `scripts/roblox_dealership_customisation_split_phase1_buy_only.lua` makes the dealership buy-only: unowned cockpits show `Buy`, owned cockpits show `Buy Another`, and the old dealership `Select` button is removed. It also sets the starter Bruiser cockpit to `$15000` and stops fresh session profiles from owning `bruiser_01` for free. Existing saved/test players who already own the starter cockpit keep that ownership.

Dealership / Customisation Split Phase 2 was run by the user and reported working as intended on 2026-07-04. `scripts/roblox_dealership_customisation_split_phase2_owned_customisation_zone.lua` adds a separate customisation trigger zone, an isolated zone client, a `SelectVehicleInstance` server action, and a customisation-mode cockpit grid that reuses the dealership look while showing owned cockpits.

Dealership / Customisation Split Phase 3 is prepared as `scripts/roblox_dealership_customisation_split_phase3_instance_cards.lua` and documented in `docs/dealership-customisation-split-phase3-2026-07-04.md`. It refines the customisation grid to show one card per owned vehicle instance, removes the aggregated `Owned xN` text, displays per-vehicle tier/index labels such as `A 920`, and passes `VehicleId` into `SelectVehicleInstance` so duplicate cockpits are distinct.

Dealership / Customisation Split Phase 4 is prepared as `scripts/roblox_dealership_customisation_split_phase4_rating_badge_build_modules.lua` and documented in `docs/dealership-customisation-split-phase4-2026-07-04.md`. It corrects the per-instance rating fallback, adds a colour-coded tier badge to each owned vehicle card, and changes the customisation-zone action to open the Build Modules menu instead of the final colour/customise screen.

Dealership / Customisation Split Phase 5 is prepared as `scripts/roblox_dealership_customisation_split_phase5_cockpit_menu_images.lua` and documented in `docs/dealership-customisation-split-phase5-2026-07-04.md`. It keeps the customisation-zone destination as `ModuleShop` but changes the selected cockpit button text to `Customise`. It also adds a shared cockpit thumbnail source:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.BRUISER.COCKPITS_ReplaceAssetsHere.COCKPIT_BRUISER_01.MenuImage
```

Set the `MenuImage` attribute on each cockpit model to a Roblox image asset such as `rbxassetid://123456789`. Dealership cards, customisation duplicate-owned cards, and the free-roam car button should all read this same cockpit attribute. If the attribute is empty, dealership/customisation cards fall back to the simple car shape and free roam falls back to `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.CarIcon`.

Dealership / Customisation Split Phase 6 is prepared as `scripts/roblox_dealership_customisation_split_phase6_square_images.lua` and documented in `docs/dealership-customisation-split-phase6-2026-07-04.md`. It repairs the image path if the UI still shows the fallback pink bar by reading the actual cockpit model as well as the catalogue row. It accepts cockpit image attributes, matching child `StringValue`s, and matching `Decal` / `Texture` / `ImageLabel` objects. It also changes cockpit cards to use a configurable square thumbnail box and removes the duplicate selected-cockpit rating above the right-panel `Customise` button.

If Play reports `Out of local registers when trying to allocate init` after installing Phase 6, run `scripts/roblox_dealership_customisation_split_phase6_register_limit_repair.lua` in Edit mode. The first Phase 6 helper block used top-level local functions inside the already-large client bootstrap; the repair keeps the same UI behavior while reducing local-register pressure.

Dealership / Customisation Split Phase 7 is prepared as `scripts/roblox_dealership_customisation_split_phase7_responsive_cockpit_grid.lua` and documented in `docs/dealership-customisation-split-phase7-2026-07-04.md`. It keeps the Phase 6 square-image card style but makes the grid responsive: desktop/laptop defaults to 4 cards across, mobile defaults to 3 cards across, and additional cards scroll vertically. It also scales image boxes, text positions, tier badges, and rating labels from the calculated card width.

Dealership / Customisation Split Phase 8 is prepared as `scripts/roblox_dealership_customisation_split_phase8_compact_card_polish.lua` and documented in `docs/dealership-customisation-split-phase8-2026-07-04.md`. It supersedes Phase 7's tall card-height ratio by calculating card height from content, making the image box fill the card width with even padding, and adding base cockpit tier/rating on the right of the dealership card title row. Owned/customisation cards keep per-vehicle tier/rating on the same title row.

Dealership / Customisation Split Phase 9 is prepared as `scripts/roblox_dealership_customisation_split_phase9_badge_overlay_tight_cards.lua` and documented in `docs/dealership-customisation-split-phase9-2026-07-05.md`. It moves tier/rating into one wider coloured badge over the top-right of the cockpit image, tightens the image/name/price/card-bottom gaps, uses the dealership included-default-module stat path for buyable cockpit ratings, and restores the free-roam car button to the configured plain `FreeRoamNav.CarIcon` by default.

Dealership / Customisation Split Phase 10 is prepared as `scripts/roblox_dealership_customisation_split_phase10_responsive_layout_polish.lua` and documented in `docs/dealership-customisation-split-phase10-2026-07-05.md`. It narrows the mobile stats panel, gives the centre cockpit grid more width, shortens the bottom-right Exit frame, removes the `Categories` heading, moves the right-panel action button down slightly, makes desktop cockpit-card text larger without changing the liked mobile scale much, places stat values on the left inside bars in dark text, and matches the free-roam car icon size to the other free-roam icons.

Dealership / Customisation Split Phase 11 is prepared as `scripts/roblox_dealership_customisation_split_phase11_sorted_cockpit_cards.lua` and documented in `docs/dealership-customisation-split-phase11-2026-07-05.md`. It sorts dealership cockpit cards by price from lowest to highest, sorts owned customisation cards by per-vehicle rating from highest to lowest, and sorts category buttons alphabetically. The grid fills left-to-right, then top-to-bottom.

Cockpit menu image/card tuning lives at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Key values:

- `CardWidth`
- `CardHeight`
- `ImageBoxSize`
- `ImageInnerPadding`
- `ImageScaleType`
- `NameY`
- `PriceY`
- `TierBadgeY`
- `RatingY`
- `FreeRoamCarIconScale`
- `DesktopColumns`
- `MobileColumns`
- `DesktopMinCardWidth`
- `DesktopMaxCardWidth`
- `MobileMinCardWidth`
- `MobileMaxCardWidth`
- `ResponsiveCardScaleEnabled`
- `CardOuterPadding`
- `ImageZoom`
- `ImageToTextGap`
- `PriceLineGap`
- `CardBottomPadding`
- `RatingTotalWidth`
- `RatingBadgeWidth`
- `RatingBadgeHeight`
- `RatingBadgeTopInset`
- `RatingBadgeRightInset`
- `RatingGap`
- `RatingTextSize`
- `BadgeCornerRadius`
- `FreeRoamUsesCockpitMenuImage`
- `DesktopNameTextSize`
- `MobileNameTextSize`
- `DesktopNameHeight`
- `MobileNameHeight`
- `DesktopCardScaleMax`
- `MobileCardScaleMax`
- `DesktopStatsPanelWidth`
- `MobileStatsPanelWidth`
- `ExitPanelVerticalPadding`
- `PanelActionBottomPadding`
- Free roam car menu values under `Config.UI.FreeRoamNav`: `CarPanelWidthDesktop`, `CarPanelWidthTouch`, `CarPanelCardGap`, `CarPanelPadding`, `CarPanelDespawnHeight`, `CarPanelDesktopColumns`, `CarPanelMobileColumns`, `CarPanelDesktopImageMaxSize`, `CarPanelMobileImageMaxSize`, `CarPanelBorderThickness`, `CarPanelImageZoom`, `CarPanelImageFitScale`, `CarPanelImageInnerPadding`, and `CarPanelClickAction`

For mobile:

- Cockpit cards should scale to fit 3 columns where possible.
- Left/category UI should not overlap the cash UI.
- Right stats panel should remain readable and aligned with the rest of the layout.
- The selected cockpit panel should not show the old module-slot count list under the stats.

## Paint Cockpit

Known cockpit paint channels:

- Primary
- Secondary
- Detail

After running Phase AK per-cockpit defaults, default cockpit colours are editable directly on each cockpit model, for example:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.BRUISER.COCKPITS_ReplaceAssetsHere.COCKPIT_BRUISER_01
```

Attributes:

- `MenuImage`
- `DefaultPrimaryColor`
- `DefaultSecondaryColor`
- `DefaultDetailColor`
- `DefaultNeonColor`
- `DefaultFrontLightsColor`
- `DefaultRearLightsColor`

Cockpit front/rear cosmetic neon defaults were requested:

- Front: `252, 250, 255`
- Rear: `255, 116, 116`

Front/rear cockpit neon should not be editable during initial cockpit paint, but can be revisited later in module/customisation menus. Long-range cockpit driving lights are currently deferred after Phase AI removed the S-AH light experiments.

After a cockpit is bought or selected, the Paint Cockpit step should not allow returning to the dealership cockpit list. Hide the Back button on Paint Cockpit only, while keeping the Next button visible so the player can continue to Build Modules and then spawn.

## Build Modules

Known module selection slots:

- Front engine
- Rear engine
- Stabilisers
- Boost
- Front bumper
- Rear bumper
- Rear spoiler
- Side pods

Earlier labels `Engine 1` and `Engine 2` were renamed conceptually to:

- Front engine
- Rear engine

When selecting modules:

- Selecting a slot should show options for that slot.
- Engine A/B assets should not be interchangeable between front/rear unless the folder/slot rules explicitly allow it.
- Buy/equip should install the module and return to the slot menu.
- Phase AK gates the Customise Modules button until at least one engine, stabilisers, and boost are equipped. If not, the UI shows a centered popup in the existing menu style.
- Persistence Phase 16 sorts module option cards by player usefulness: owned/free compatible copies first, unlocked buyable modules next, and source-cockpit-locked modules last on the right.
- Owned compatible modules from other cockpit families should still appear for the selected slot. For example, owned Bruiser B engine modules should appear while editing a compatible Bruiser A engine slot.
- Locked module cards should remain visible with a clear cockpit requirement, rather than disappearing from the carousel.
- Persistence Phase 17 separates the bottom module picker into `OWNED MODULES` and `BUY MODULES`. Owned module cards represent individual module instances/copies so future upgrades, colours, and decorations can belong to a specific copy.
- `BUY MODULES` should use a simple `BUY` action that purchases a new module instance and auto-equips it. `OWNED MODULES` should use a BUY-coloured `EQUIP` action.
- Front engine slots should show only front engines. Rear engine slots should show only rear engines.
- Front/rear engine filtering should prefer the explicit `EnginePosition` catalog field and only fall back to folder/name checks for older templates.
- Clicking any module card, including locked buy-module cards, should preview it on the vehicle.
- Module option cards should show the source cockpit family and variant on the top line, for example `Bruiser Origin / Standard`, the module price in green on the middle line, and `Owned xN` on the bottom line. Owned module cards still represent individual copies, but the count line shows the total copies of that module template.
- Module option cards need enough vertical room for all three lines; avoid clipping the bottom `Owned xN` / `Locked` line. The first `OWNED MODULES` / `BUY MODULES` tab buttons should use the same 72px-tall compact button feel as the Customise section controls, with one vertically centred label and no owned-count sublabel.
- In the `BUY MODULES` view, buyable cards should use the lighter normal card colour and locked cards should use the darker disabled colour. Locked cards should keep the green price visible but show `Locked` on the bottom line in the muted owned-text colour.
- The live theme currently makes `Theme.Disabled` lighter than `Theme.Card`, so the buy-module UI intentionally uses the lighter disabled swatch for buyable cards and the darker card swatch for locked cards. Locked cards should mute the title and use a darker green price.
- BUY/LOCKED/EQUIP should appear directly above the selected module card, not centred above the full module-options frame. Keep the module carousel clipped so cards cannot spill into the cash/customise/back panels. The action-rail workaround in `scripts/roblox_persistence_phase17_module_popup_action_rail_repair.lua` was rejected by the user because it centred the action button in the frame instead of above the clicked card. The anchor-target repair creates a clipped carousel plus a visible popup on an overlay positioned from an invisible top-centre `ModulePopupAnchor` inside the selected card. If the target anchor is correct but the visible popup is still offset by overlay scaling/transform, use `scripts/roblox_persistence_phase17_module_popup_absolute_correction_repair.lua` to probe the live UI scale and nudge the popup's actual absolute centre/bottom onto the anchor. Screen-size-dependent drift means this is likely a responsive scaling mismatch, not a card-selection problem.
- Sprint/Shift camera FOV should be blocked while any garage/customisation menu is open.

## Customise Modules

Known customisation options:

- Customise all colours.
- Cockpit.
- Bought/installed modules.
- Brakes.
- Converter.
- Fuel system.
- Thrust colour.

Colour channels should be detected from the actual module contents where possible:

- Primary
- Secondary
- Detail
- Neon/optional neon
- Thrust colour for engine/boost/stabiliser systems

Upgrade buttons should preview stat changes first, then commit on buy.

Phase AN prepares the live module-specific purchase/effect layer. Upgrade levels belong to each module ID, so an upgraded module keeps its progression when equipped on another compatible cockpit. The existing Brakes, Converter, Fuel System, and generic Upgrade UI remain visible until the Phase AO UI cutover.

Phase AO should consume:

- Module `Upgrades` from the catalogue response.
- `Profile.ModuleUpgradeLevels`.
- `Profile.Performance`.
- The server `UpgradeModule` action.

Phase AN is confirmed end to end. Phase AO can now replace the old controls without changing the server purchase/effect behavior.

Phase AO is prepared for Studio install. It replaces the visible legacy upgrade controls with a `Performance` screen on each installed module. Upgrade cards show level, next price, and detailed effects; selecting a card previews one additional level before purchase.

The Phase AO right-hand stats panel always shows the E-S tier and performance index at the top. General screens show the six headline stats. Selecting a module switches the panel to the most relevant headline stats and the detailed variables affected by that module's upgrades.

The module upgrade list is horizontally scrollable for mobile. The existing left module list remains vertically scrollable.

## Garage Interior Customisation

The physical owned-garage MVP is now approved for clean replacement rather than visual repair. Phase 0 and inactive Phase 1 passed; Phase 2 now stages the editable two-bay template and server-only runtime modules without adding UI or activating the desk prompt. The later management workspace must reuse the actual dealership/racing components for a `1200 x 720` My Garages browser plus Display Cars, Interior and Access pages. Display slots persist only stable `VehicleId` references; replacing a display never deletes an owned vehicle. See `docs/owned-garage-canonical-replacement-plan.md`.

Persistence Phase 24 prepares the backend/runtime layer only. It installs `GarageInteriorCustomizationInvoke` and `GarageInteriorCustomizationService_Active` so garage interiors can store/apply simple floor/wall surface colours/materials and decoration anchors under `Garage.Customisation`.

Persistence Phase 25 prepares the first player-facing control surface for that backend: an owner-only in-garage panel installed as `GarageInteriorCustomizationClient_Active`. It stays separate from the dealership/customisation bootstrap and calls the Phase 24 remote directly.

Persistence Phase 27 prepares a separate same-server garage access panel installed as `GarageAccessClient_Active`. It handles entering the owner's garage, setting public/private access, visiting a typed same-server owner user ID, and returning to the city. It does not replace the dealership menu or the Phase 25 customization panel.

## Mobile Driving UI

Current mobile driving UI:

- Arrows are the default mode; Thumbstick and Tilt remain selectable at the top of mobile Settings.
- Steering/drift, boost, equal square Accelerator/Brake images, speed and boost telemetry are independently owned but share explicit menu-block state.
- The old `roblox_mobile_drive_thumbstick_install.lua` / V2 visual-refinement ladder is historical and must not be run over the confirmed Phase 1M/1N/1O owners.
- PC-only driving HUD and legacy mobile controls remain suppressed.
- Use `docs/mobile-ui-racing-flow-handoff-2026-07-14.md` for the complete current owner/config/installer contract.

Mobile Free-Roam UI Phase 1L is installed and confirmed for the central popup family. Settings keeps Mobile Controls first and uses a fixed `720 x 420` reference; Get Cash ports the PC `840 x 650` balance/four-card composition; Dealership confirmation uses `650 x 270`. Each shell scales and centres inside the same `72/10/10 px` top/bottom/side safe area approved for mobile racing menus. Cash buttons remain visual-only and must not invoke a purchase. See `docs/ui-free-roam-mobile-phase1l-modal-safe-area-pc-cash-2026-07-13.md`.

Mobile Free-Roam UI Phase 1M is installed as the confirmed visual controls refinement. All four turn/drift arrow cards use borderless gradient surfaces with `ArrowCardOpacity` and `ArrowImageOpacity`; Accelerator/Brake cards use `PedalCardOpacity = 0` by default so only artwork remains, with `PedalImageOpacity` available for tuning. Opacity is `0 = invisible`, `1 = opaque`. Hitboxes, layout and input behavior remain unchanged.

Mobile Free-Roam UI Phase 1N is installed and confirmed: Accelerator and Brake are equal `PedalSize x PedalSize` image slots. Both share `PedalBottomOffset`; Accelerator is `PedalRightOffset` from the right edge and Brake is separated to its left by `PedalGap`. The image asset values and Phase 1M card/image opacity attributes are unchanged.

Mobile Free-Roam UI Phase 1O gives major mobile menus one shared suppression boundary. Settings, Get Cash and the dealership confirmation keep their modal/shade visible while hiding navigation, map, cash, toast, telemetry, Exit and all vehicle controls. The separate control owner reads `NTRMobileMajorMenuOpen`, and also treats its `ScreenGui.Enabled=false` state as blocked so Race Browser/Entry suppression releases held inputs. Closing the final popup restores the correct on-foot/driving presentation automatically. Car-menu behaviour and PC UI are unchanged.

Phase 1O was installed and user-confirmed working. The consolidated current handoff is `docs/mobile-ui-racing-flow-handoff-2026-07-14.md`; future mobile UI work should begin from that isolated-owner baseline rather than the earlier thumbstick/free-roam repair ladder.

## Free Roam Vehicle Menu

Free Roam Vehicle Spawn Phase 4 separates three vehicle states:

- Clicking an owned cockpit card in the free-roam car menu should spawn/swap into that vehicle and auto-seat the player.
- The car-menu `DESPAWN` button should destroy the currently spawned vehicle after safely unseating/moving the player.
- The driving-only `EXIT VEHICLE` button should park the player 10 studs left of the driver seat and leave the car spawned for meet-ups/showcase.

Parked vehicles should be re-entered through a server-validated owner `ProximityPrompt` (`E` on keyboard, touch prompt on mobile), not by automatic seat touch. Phase 4 sets driver-seat `CanTouch=false` so the hidden seat should not auto-enter when bumped. Phase 4B also disables the older bootstrap distance-based `ReEnterVehicle` loop, so prompt entry is the only walk-up entry path.

Phase 4B adds an explicit `FreeRoamVehicleSpawned` bindable handoff from the free-roam cockpit-card UI into the existing `startDriving()` path. This replaces relying on the old auto re-entry fallback and should make the first cockpit-card spawn immediately hover/drive. Parked vehicles set `DriveReady=true` and `ParkedShowcase=true`; if Play testing shows hover/VFX still stop while unoccupied, add a small isolated parked-hover/VFX keeper service rather than changing the free-roam cockpit card UI again.

Phase 4C adds that first parked-hover keeper as `FreeRoamParkedHoverController_Active`. Exiting now fires `FreeRoamVehicleExited`, the main bootstrap calls `stopDriving()` to remove controls/HUD and restore camera to the humanoid, and the parked-hover keeper applies only hover/alignment forces while `ParkedShowcase=true` and `DriverUserId=nil`. It should not apply throttle, steering, drift, boost, or braking. Prompt re-entry detects the player being seated again and fires the same `FreeRoamVehicleSpawned` drive handoff as cockpit-card spawning. Phase 4C also hides the free-roam car pop-out after a successful cockpit-card spawn.

Phase 4D keeps parked/despawn behaviour player-centred: `DespawnVehicle` only moves the player if they are currently seated in the vehicle being despawned, and the `10 MPH` spawn gate plus vehicle-position spawn anchor apply only while actively seated/driving. If the player has exited and is on foot, spawning/despawning should use the player's position/state rather than the parked car. Phase 4D also narrows the desktop car pop-out to three compact cards and removes the pink outline layers from free-roam cockpit card/image boxes while preserving the selected magenta fill.

## Race Entry Menu

Mobile Racing UI Phase 1 was installed and user-confirmed working as a shared scaled-desktop system. Instead of rebuilding Browser, race/time-trial setup, placement prizes, records, vehicle selection, and unified Results, touch devices select the existing approved PC composition and fit its fixed `1200 x 720` shell into a configurable safe area. Phase 1B tightens the gap beneath Roblox's built-in controls by changing only `SafeTop` from `84` to `72`. The isolated helper is `RacingMobileScaledDesktopLayout`; tuning lives at `Config.UI.Racing.MobileScaledDesktop`. The in-race HUD and all racing gameplay/data owners remain outside this phase.

Unified Race Flow is generated as `scripts/roblox_racing_flow_countdown_queue_exit_ownership.lua`. It keeps the confirmed scaled Browser/Entry/Results compositions, removes their header X exits, makes footer actions the only exit path, and relies on the existing presentation-owner bridge to close car/settings/modal UI and hide free-roam UI underneath. Its responsive queue banner is the only queue presentation; the retired Phase 8 queue panel no longer doubles as an in-race or post-race menu. Race and Time Trial share a large configurable `5, 4, 3, 2, 1, GO!` overlay with a borderless racing-palette gradient and fully centred countdown text. Route-guide checkpoint presentation stays hidden until GO. The server owns `NTR_RaceQueueActive` and rejects vehicle changes until the player leaves the queue or staging begins. Time Trial RESET repositions the vehicle without restarting the shared PC/mobile lap display clock.

The amended racing plan makes the next race UI a themed entry flow instead of an instant prompt start. Pressing `E` / touch on a race zone should open an isolated `Controllers.Racing` menu with:

- track image and track map;
- route/event details, tier eligibility, rewards, and medal/placement preview;
- bottom buttons `START RACE`, `START TIME TRIAL`, and `EXIT`;
- owned vehicle selection using the dealership/customisation cockpit-card style with image, name, tier/rating badge, and selected state.

This should read from `ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme` and the existing cockpit/card config where practical, but the implementation should live in isolated racing controllers such as `RaceEntryMenuClient_Active` and `RaceVehicleSelectClient_Active`. Do not add a large race menu block to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

Racing Phase 3 is generated as `scripts/roblox_racing_phase3_entry_menu_staging_session.lua`. It installs the first version of this menu as `RaceEntryMenuClient_Active`, with owned vehicle cards read from the existing garage profile and selected vehicle spawning handled through existing garage actions before the Racing service stages the vehicle at the start line.

If Phase 3/3B server Output shows the start-zone prompt is firing but the menu does not appear, use `scripts/roblox_racing_phase3c_client_event_repair.lua`. It patches only the isolated race menu client so event listening starts before garage vehicle data is needed, and it installs a tiny client probe to show whether `OpenRaceEntry` reaches the player.

If `START TIME TRIAL` from `RaceStartZone` spawns the selected vehicle into free roam/customisation instead of the race start grid, use `scripts/roblox_racing_phase3d_time_trial_event_pairing_repair.lua`. It resolves the paired time-trial event before the garage spawn and makes the server tolerant of race event ids on the solo time-trial path.

If the time-trial countdown completes but the vehicle is not drivable or nearby world assets stream/flicker, use `scripts/roblox_racing_phase3e_release_drive_handoff_repair.lua`. It repairs the post-`GO` handoff by preparing the vehicle for driving, restoring client streaming focus around the route, and re-firing the existing free-roam driving handoff after Racing releases the car.

## Drive-In Customisation

Drive-In Customisation Phase 1 is prepared as `scripts/roblox_drive_in_customisation_phase1.lua`. It creates a movable invisible trigger at:

```text
Workspace.NeoTokyoRacersWorld.Dealership.Customisation.DriveInCustomisationTrigger
```

The trigger is tagged `NTR_DriveCustomisationZone`. The visible bay marker is client-only and appears only while the local player is driving their own vehicle. Entering the zone starts a local countdown UI, defaulting to `ENTERING CUSTOMISATION IN 3`, then `2`, then `1`. Leaving the zone, exiting the vehicle, despawning, or opening another menu cancels the countdown.

On completion, the bootstrap handoff despawns the live driven vehicle, stops driving state, and opens the existing garage UI directly to `Build Modules` / `ModuleShop` for the current driven vehicle instance. This avoids editing modules while a duplicate live version of the same vehicle remains outside.

If Play reports `Out of local registers when trying to allocate okController`, run `scripts/roblox_drive_in_customisation_phase1_register_limit_repair.lua` in Edit mode, restart Play, and retest. The first Phase 1 handoff added too many top-level local helpers to the already register-limited client bootstrap; future customisation work should keep new behavior in isolated controllers/modules and use only tiny table-backed bootstrap bridges when unavoidable.

Config lives at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DriveInCustomisation
ReplicatedStorage.NeoTokyoRacers.Config.UI.DriveInCustomisation
```

Important values include `CountdownSeconds`, `PollSeconds`, `CooldownSeconds`, `PromptPrefix`, `PanelColor`, `TextColor`, `AccentColor`, `ZoneColor`, and `ZoneTransparency`.

Drive-In Customisation Phase 2 is prepared as `scripts/roblox_drive_in_customisation_phase2_garage_entry_world_prompt.lua`. It supersedes Phase 1's screen countdown with a local `BillboardGui` world prompt on `DriveInCustomisationTrigger`, so the countdown appears like an in-world interaction prompt. It also toggles attached trigger VFX locally while the player is driving, instead of changing the trigger part transparency.

Phase 2 installs `DriveInCustomisationSessionService_Active` and a hidden `DriveInCustomisationPlayerHoldPoint`. When the countdown completes, the live vehicle is despawned, the player is hidden/frozen at the hold point while the garage UI is open, and the existing garage preview camera/preview vehicle are restored before opening Build Modules.

Drive-In Customisation Phase 3/3B was installed and confirmed working on 2026-07-06. It replaces the isolated prompt client again so the world prompt is countdown-only and appears only once the driven vehicle is actually inside the trigger. It also patches the existing garage `Start Driving` path to set `NTR_DriveInCustomisationActive` false before calling `SpawnVehicle`, because the Phase 2 hold lock can otherwise keep the character anchored/frozen during the spawn/seat handoff. This bootstrap patch is intentionally tiny and does not add top-level locals to the register-limited client bootstrap.

The first Phase 3 script installed the prompt client but failed to patch the bootstrap because it used Lua pattern-based `string.gsub` for a multi-line source block. `scripts/roblox_drive_in_customisation_phase3b_spawn_unlock_anchor_repair.lua` fixed the partial install by using plain source matching around the current `Customise -> SpawnVehicle` branch. Use plain matching or line-window insertion for future source text repairs where punctuation-heavy Lua source is the anchor.

## Canonical Module Instance Cards

`scripts/roblox_ui_garage_module_instance_cards_and_actions.lua` is the next generated canonical garage phase. It installs an isolated `GarageModuleCardViewModel`, makes Owned Modules render every physical module instance as a separate card, and makes Owned and Buy use the same semantic card renderer.

The interaction contract is explicit: `BuyModuleInstance` purchases an available copy and never calls Equip; the player then selects that copy under Owned Modules and uses the existing card-centred `EQUIP` popup. Moving a copy from another vehicle requires a central Yes/No confirmation, after which the server removes the old vehicle reference before assigning the new one. Equipped, available, in-use, locked and selected states keep distinct shared colours. Optional module rating fields are supported without requiring the rating system yet, and `GarageReplacement.ModuleLockIcon` is the transparent lock-art configuration value.

This installer uses hard-preflighted plain source windows in the isolated garage application/shared renderer and one small server reassignment guard. It is generated but not yet confirmed in Play. Verify purchase-without-equip, individual copy cards, available equip, cross-vehicle confirmation, locked preview without Buy, card sorting and the centred popup before treating it as the baseline.

### Revised module-instance implementation order

Play verification of V1 exposed that `GarageWorkspaceController.RenderCards` does not forward the new `VehicleName`, `Price`, `SemanticState`, `Variant`, `Locked` and `LockImage` properties into the shared listing-card renderer. The card renderer therefore falls back to `UNIVERSAL`, cannot draw the green price, and cannot apply equipped/in-use colours. This is a property-forwarding defect, not a new visual-design phase.

The remaining module work must proceed in this order:

1. Make each `OwnedModuleInstances` record the authoritative owner of its colours, neon ownership and upgrade allocation. Colour/neon/upgrade mutations must resolve the installed instance ID and write that instance before compatibility slot tables are refreshed. Equipping must hydrate the current slot view from that instance. V2 upgrades already target physical instances; legacy compatibility paths still need an explicit audit and bridge.
2. Replace multi-call purchase/equip and reassignment with one atomic server transaction. Buying should purchase and equip by default. Moving an in-use module should detach no references until validation succeeds, equip the requested copy, and backfill the previous vehicle with the lowest-rated compatible available copy. The displaced target-vehicle module is eligible for that backfill. The transaction must never manufacture a replacement; if no compatible copy exists, it must fail or leave an explicitly reported empty optional slot. Core slots should fail safely. Add post-transaction invariants for one reference per instance and matching `EquippedVehicleId`.
3. Repair the shared card property contract and lineage resolution. Prefer the catalogue's `SourceCockpitDisplayName`, then resolve `SourceCockpitId`, and only use `UNIVERSAL` for genuinely universal modules. Forward price/state/lock/rating fields, sort Equipped then Available then In Use, and sort by rating within each state. Preserve pink equipped fill, pink available outline, grey in-use/locked outline and blue selected outline.
4. Replace the fixed `1600x900` modal shade with the canonical host's full scaled canvas bounds and centre its panel through the same responsive shell contract. Reuse this modal for cross-vehicle reassignment and other garage confirmations.
5. After the instance transaction passes save/rejoin tests, complete the already-approved presentation backlog: brighter true-colour sliders, content-fitted Owned/Buy rail, shared icon configuration, working performance cards, shorter Customise category cards, `Thrust` copy, and larger stats/economy/header typography.
6. Author the dedicated module rating formula/data only after physical-instance persistence is stable. The current view model accepts an optional rating and can use deterministic fallback order until that system is calibrated.

The first step is now generated as `scripts/roblox_ui_garage_module_instance_customisation_authority.lua`. It installs the isolated server-only `GarageModuleInstanceCustomizationRuntime` and small action-controller bridges. Colour, neon, thrust-colour compatibility and upgrade actions capture into the installed physical instance; vehicle selection/equip hydrates legacy slot views from that instance; and every successful garage mutation validates unique references plus `EquippedVehicleId` before persistence. It does not change card layout, auto-equip policy or reassignment/backfill behavior. The user confirmed this authority phase working well on 2026-07-16.

The same authority installer now also reconciles the derived `EquippedVehicleId` field from canonical `Vehicles[*].InstalledModules` references before processing a garage request. This repairs stale owner flags left by an earlier equip/reassignment path without deleting, creating, moving or equipping any module. Missing instances and duplicate slot references remain hard failures. This was added after `SelectVehicleInstance` correctly detected `module_d93425e6b4a3` as equipped-but-unreferenced and blocked customisation.

Before atomic buy/equip/backfill, add one isolated read-only selected-instance preview adapter. Module-card selection already records `SelectedModuleInstanceId`; the adapter should resolve that copy's saved colours, neon and upgrade allocation and apply them only to the local preview clone and preview-stat calculation. It must not copy preview data into current slot compatibility tables, invoke a garage mutation, change vehicle references or persist anything. Colour and neon are direct presentation data; performance upgrades should be represented by the preview stats/deltas unless an upgrade explicitly has authored visual geometry or VFX. Clear the selected preview instance when the slot, category, mode or screen changes, and audit a profile snapshot before/after repeated preview clicks to prove selection is mutation-free.

That phase is now generated as `scripts/roblox_ui_garage_module_instance_readonly_preview.lua`. It installs `Controllers.Preview.GarageModuleInstancePreviewAdapter`, makes the existing preview clone use the selected physical copy's `Colors`, `NeonOwned` and upgrade allocation, and makes the existing performance panel compare the selected upgraded copy against the currently installed upgraded copy. The clone also receives the resolved upgraded raw attributes for future authored preview VFX/geometry readers. The adapter has no remote or mutation path, and each preview build fingerprints the client profile before and after to enforce that contract. The installer transactionally compiles and patches only `PreviewVehicleController` and `ModuleShopUIController` through exact known source anchors; Studio install and Play verification remain pending.

The physical-instance authority, read-only preview, atomic purchase/equip/backfill, and shared card/modal stages were subsequently confirmed working by the user. The approved presentation stage is now generated as `scripts/roblox_ui_garage_module_presentation_refinement.lua`. It reuses the canonical garage shell and shared performance renderer to add bright dynamic HSV tracks, content-fitted Build navigation, a Customise rail aligned to the carousel bottom, shorter artwork cards, `Thrust` copy, larger shared typography, and configurable `ModuleColourIcon`, `ModuleCosmeticsIcon`, `ModulePerformanceIcon`, and `ModuleNeonIcon` attributes. It also makes Standard modules explicitly non-upgradeable while continuing to consume the existing Lightweight/Power V2 upgrade catalogues. This phase is client presentation/config only and deliberately does not alter module ownership, persistence, rating, prices, or server transactions.

The presentation stage was user-confirmed substantially improved. Its Play test exposed two older state-ownership defects rather than presentation defects: browser card selection changed only selected IDs while preview construction kept reading the current profile, and `SetCockpitColor` copied whole-vehicle paint into legacy module tables without capturing the physical instances. The approved canonical repair is generated as `scripts/roblox_ui_garage_vehicle_preview_and_paint_scope.lua`. It adds one pure `GarageVehiclePreviewProfile` projection: Dealership cards use cockpit defaults plus the same four Standard core modules granted on purchase, while Customisation cards resolve the selected vehicle's cockpit state and physical module-instance colours, neon and upgrades without selecting that vehicle on the server. The same phase gives paint explicit `WholeVehicle`, `CockpitOnly`, `ALL`, thrust and single-slot scopes. Whole-vehicle commits update the vehicle cockpit state and capture every installed physical instance atomically; cockpit-only commits never touch modules; committed colour actions can return the authoritative refreshed profile. The initial page is renamed `Paint Vehicle` to describe its full-vehicle scope.

## Owned Garage Phase 7 Reusable UI Data Contract

`scripts/roblox_owned_garage_phase7_reusable_property_framework.lua` is the generated foundation for the approved owned-garage UI overhaul. It deliberately preserves the current Phase 6 visuals while removing future pages' dependence on a hard-coded two-space garage.

The server response now owns `ApiVersion`, `DefinitionVersion`, `Revision`, property `Capabilities`, dynamic display-space definitions, access modes and decoration categories. Future Browser/Workspace pages must render from that response and continue to call the confirmed `GarageWorkspaceController`, `GarageReplacementComponents`, `RacingUIComponents` and scaled desktop layout; copying their appearance into an owned-garage-only renderer is not reuse.

Every management mutation must send a unique `RequestId` plus the last rendered `BaseRevision`. A conflict means the client refreshes and rerenders before offering the action again; it must never silently retry an old action against a newer garage. Read responses may be cached by the server, so UI code must treat response tables as immutable and replace its local state reference after refresh rather than mutating catalogue/definition fields.

## Owned Garage Phase 8 Canonical Display Cars Contract

`scripts/roblox_owned_garage_phase8_canonical_vertical_slice.lua` replaces the owned-garage-only vehicle scan with the same authoritative server summary inputs used by dealership/customisation. Display-space and vehicle rows still render through `GarageWorkspaceController`, `GarageReplacementComponents`, `RacingUIComponents` and the shared scaled composition; Phase 8 extends those shared contracts with muted cards, empty-space plus treatment, confirmation modal support and incremental card refresh rather than copying the visual system.

Vehicle cards show the saved vehicle identity, cockpit menu image, performance tier/rating and cross-garage display state. Available vehicles sort by descending rating; vehicles used in another garage sort after available vehicles, use a grey outline and require confirmation before the existing assignment transaction moves the single saved reference. Selecting previews locally in the runtime interior; only the explicit Display action persists and increments the canonical revision.

The V1.7 interaction boundary makes that explicit action a first-class shared-workspace `SelectedAction`, rather than inferring it from a selected row's callback. `GarageWorkspaceController` still mounts the existing shared dealership popup and retains the legacy row-action fallback for established customisation pages. Successful owned-garage mutations return the complete immutable management projection in the same response so the client can validate and render the committed slot without a second read race.

V1.8 establishes the persistence boundary beneath that UI. `GetProfile` results are read-only presentation snapshots because Roblox copies tables returned through a `BindableFunction`; no owned-garage client-facing service may mutate one and then merely mark it dirty. `ProfileService_Active` owns `ExecuteOwnedGarageCommand` and invokes `OwnedGarageAuthoritativeCommandRuntime` directly against its live session profile. The command runtime delegates validation, revision conflicts, idempotency and duplicate-safe moves to the existing profile/assignment modules. This seam can move behind a reorganised service or repository later without changing the workspace, saved schema or garage-definition contracts.

Browser/management opening is asynchronous and warmed by the last immutable state. Open/close requests are sequenced so prompt policy, preview cleanup and state refresh cannot race each other. Production presentation/geometry audits are disabled by config and no empty retired-surface owner creates a RenderStepped loop. `DebugTimingEnabled` can temporarily expose remote/render timings without changing ownership.

Inside a garage, desktop/mobile free-roam HUD owners show only settings and cash, while the existing `GarageInteriorModeController` owns the persistent access/invite strip and interior-mode attribute. That strip hides during management. Do not reintroduce a separate `GarageInteriorHudController`; the V1.3 new module did not persist and duplicated the intended owner boundary. Native prompts use tap activation and are server-disabled during management or transitions. Phase 8 intentionally renders later Structure/Decorations/Lighting pages as gated placeholders; those phases must consume the same definition/capability/component contracts.

## Owned Garage Phase 9 Structure Contract

Phase 9 must not surface the old `SurfaceGroup="Walls"` implementation as the new Structure UI because it cannot distinguish individual walls. The approved Structure slice is section-addressed (`FrontWall`, `LeftWall`, `RightWall`, `BackWall`, `Floor`, `Ceiling`), catalogue-driven and persisted only through the ProfileService-owned command seam. Temporary preview belongs to the active interior session and is restored on cancellation or transition.

The page reuses shared Build/Upgrade/Cosmetics composition: six section cards, four priced style cards per section, the existing BUY/CUSTOMISE selected-action popup, and shared colour controls. Material and Colour both expose Primary/Secondary/Detail, with template parts targeted by `StructureSection` and `StructureChannel` attributes. Additional garage templates extend catalogue and attributed geometry without adding page-specific runtime branches.

The generated V1 installer uses `GarageWorkspaceController.RenderPaint` directly for the H/S/B colour panel. Slider movement updates the local control continuously but sends one authoritative mutation only when input ends, preventing touch-drag remote spam. Style preview is stored only on the current server interior session and cancellation restores committed state. Material selection uses the same shared card canvas; no separate owned-garage GUI is created.

Phase 9 V1.1 changes physical presentation from recolouring the fixed shell to swapping one data-selected section asset. The editable authoring path is `ServerStorage.NeoTokyoRacers.OwnedGarage.StructureAssets.<TemplateId>.<SectionId>.<AssetOption>`, positioned by the matching `StructureSlots.<SectionId>` part in the garage template. Style cards receive the section as their shared listing-card lineage instead of displaying `UNIVERSAL`. Disabled later-category cards remain visible but cannot navigate until their server capability is enabled.

Part CFrames inside each option model are interpreted as slot-local transforms. The generated templates therefore sit around the local origin in ServerStorage; edit or replace geometry in that local space rather than moving it to the garage's world coordinates. Runtime multiplies each authored local CFrame by the active interior's matching slot CFrame. Keep scripts, prompts, seats and gameplay markers out of option models; the runtime strips them defensively from clones.

## Owned Garage Phase 10 Decorations Contract

Phase 10 reuses the same workspace, shared cards and selected-action popup. The flow is category, display position, then item: six cosmetics-style category cards lead to the garage definition's stable anchors, and item options use shared listing cards with `LOCKED`, `OWNED` and `CURRENT` semantics. Selection previews without writing; the selected action performs `BUY`, `PLACE` or `REMOVE` through the authoritative command seam.

Saved data is an unlock map plus one `ItemId` per `AnchorId`, scoped to each owned property. It stores no world CFrame. Runtime presentation clones script/prompt/seat-free models from `ServerStorage.NeoTokyoRacers.OwnedGarage.DecorationAssets.<CategoryId>.<AssetName>` into `DecorationRuntime` at the matching template anchor. This keeps the first mobile implementation bounded and makes another garage replicable through catalogue data, anchors and authored assets. A later placement-editor phase may add constrained offsets/rotation without changing item identity or purchase ownership.

## Owned Garage Phase 11 Lighting Contract

The main Lighting page owns garage-local room illumination, not the game's shared environmental Lighting service. Its root offers Presets and Intensity through the same cosmetics-style composition. Four preset cards reuse the listing-card price/owned/current states and selected-action popup; three intensity cards provide Low, Balanced and High. Selection previews into the active session only, while Buy, Apply and Save use the authoritative ProfileService command.

Each garage definition supplies stable `LightingSlotIds`. The matching template contains `LightingSlots`, while editable fixture geometry lives at `ServerStorage.NeoTokyoRacers.OwnedGarage.LightingAssets.<TemplateId>.<AssetName>`. Runtime clones one sanitised fixture per slot into `LightingRuntime`, applies catalogue colour/brightness/range, disables collision/query/touch/shadows and never writes Roblox `Lighting`. Future garage templates can use different slot counts or fixture assets without changing the UI or saved preset identity.

## Owned Garage Phase 12 Access and Invitations Contract

The existing persistent top-left interior HUD remains the only access/invite presentation owner and stays hidden during management. Phase 12 V1 proved the saved commands through shared management pages; V1.1 keeps those server contracts but makes the HUD interaction lightweight. Access opens an anchored four-option dropdown for Private, Friends Only, Invite Only and Public. Invite opens an anchored, bounded list of current-server candidates and persisted invited IDs. Neither action opens the garage-management workspace.

`GarageReplacementComponents.AnchoredDropdown` owns the shared surface, row, selected-state, scrolling, outside-dismissal and `Activated` behaviour; the interior controller owns state projection, direct mutation, conflict refresh and responsive placement. Cash and Settings stay visible because the dropdown never claims management mode. Desktop and mobile use the same component with configurable widths, row heights and row caps; touch buttons retain a minimum 44-pixel target without a RenderStepped layout loop.

V1.2 uses the whole two-button HUD width for either dropdown. The container is transparent and borderless; each choice is one standalone neutral/selected gradient row with no stroke, the exact current top-button height, a left icon and a right state/action label. Both top buttons reuse a shared right-side chevron which rotates while its menu is open. Access-mode and Invite icon asset IDs are optional `OwnedGarage_EditAttributes`; distinct Unicode glyphs remain visible until final uploaded icon assets are assigned. Width and row height are derived from the live responsive controls, so future tuning cannot separate the dropdown from its anchors.

Saved `AccessMode` and the deduplicated, sorted `InvitedUserIds` list remain property-scoped. Set/revoke commands use the same revisioned ProfileService-owned mutation boundary as displays and customisation, with self-invites rejected and a configurable bounded invitation count. This phase does not add another remote, player-search request or visitor lifecycle owner. `EnableVisitors` remains false until the legacy visit/teleport path can be replaced explicitly.

## Owned Garage Style UX V1 Contract

The Style rail prepends virtual `All Structure` and `All Decorations` targets. These are UI/command concepts only and never become saved section or slot IDs. All Structure exposes Colour and Material; All Decorations exposes Colour only. Bulk saves are server-derived and atomic, while mixed channels use sparse drafts so untouched values are preserved.

Build listing cards reserve `Locked` for a genuinely unavailable capability. Unowned purchasable options use the shared available module-card state, show their price and use the configured unaffordable colour when cash is insufficient; owned options omit price. Style action and material cards resolve through the central owned-garage icon config.

The shared shell places Exit below economy for owned-garage management and keeps Back/Save at the lower right. Material pages shorten only the location rail above the shared Primary/Secondary/Detail tabs. The physical presentation owner updates compatible runtime models in place and stages replacements before removing the old model, rather than clearing the whole room between UI actions.

Material option artwork has an isolated `OwnedGarageIcons.Sizing.MaterialImageZoom` scale. It is applied through the existing shared card `ImageZoom` input, so increasing artwork size does not change the card, carousel, tab or mobile layout contract. It defaults to `1.0` and is bounded to `0.2–1.5`.

## Vehicle Cosmetics And Empty Module Routes V1

The generated canonical installer is `scripts/roblox_customisation_vehicle_cosmetics_and_empty_routes_v1.lua`. It extends the confirmed Add Modules / Upgrade Modules / Paint Shop baseline without creating a fourth workshop or a new workspace renderer.

Thrust Colour and true SurfaceLight Underglow are per-vehicle purchases. Before purchase they reuse the shared priced listing/action card; after purchase they open the shared colour sliders directly. All and Cockpit also open sliders directly. All adds a Neon channel whose authoritative save atomically updates cockpit neon, owned physical-module neon, and owned underglow without touching front/rear lights.

An uninstalled physical slot in Paint or Upgrade renders one shared `EmptyPlus` card with the short mobile-safe copy `BUY TO UNLOCK` or `EQUIP TO UNLOCK`. The card routes to that exact Add Modules source page and returns to the originating workshop after a successful transaction. It never fabricates a module, changes server ownership from the client, or creates a second navigation owner.

## Player Onboarding V1 Design

The approved onboarding design and generated implementation contract are recorded in `docs/onboarding-system-v1-design.md`; the canonical installer is `scripts/roblox_player_onboarding_v1.lua`. It adds no page-specific replacement UI: one shared overlay controller resolves existing dealership, Add Modules, Upgrade Modules, Paint Shop and owned-garage targets from their live responsive objects. Objective completion and first-view explanations are independent, so a player who starts driving before visiting Upgrade Modules still receives that page's `L1`/`L2` explanation the first time it is opened.

The tutorial copy uses the confirmed three-workshop and owned-garage semantics. Existing workspace renderers, cards, preview, colour controls, module-instance ownership and authoritative mutations remain the owners; onboarding may point to those controls but must not reproduce them or infer targets from coordinates. A small set of generated root cards currently uses exact canonical-label fallback until the shared renderer exposes semantic target attributes; this is an explicit Play-test risk, not a second renderer.

During onboarding iteration, `Config.Runtime.Onboarding_EditAttributes.StudioReplayEveryPlay=true` supplies fresh session-only objective and seen-page state for each Test Play. It does not alter saved vehicle/customisation/garage data or saved production onboarding state. Set it false for the final persistence/rejoin matrix.

V1.4 keeps the existing dealership/customisation renderers authoritative and repairs V1.3's compressed-line semantic marker to a block comment, restoring the remainder of the shared selected/action-card logic. Tutorial discovery scans visible `CanonicalGarageWorkspace` roots for the requested `TutorialPageId`; card targeting remains scoped to that matching live root.

The loading/start presentation has explicit priority and disables onboarding until it finishes. Tutorial body, Next and objective metrics follow the nearest shared UI scale, while all layout bounds use the onboarding overlay's own absolute coordinate space. B2/B4/B3 are explanatory shortcut introductions and do not navigate; N6/X3 remain real actions. The objective yields to car menus and management UI but anchors beneath the existing garage Access controls while the player walks inside.

V1.5 replaces the remaining root-name and card-union assumptions with shared semantic targets. Every `GarageWorkspaceController` root publishes `TutorialWorkspace=true`, every render publishes `TutorialPageId`, and its bottom row publishes `TutorialCardScroller`/`TutorialTargetId=CardScroller`. This allows both customisation and the renamed `OwnedGarageCanonicalWorkspace` to resolve without another page-specific renderer. K1 targets the bottom module row directly. The objective card now has number, title, contextual hint and `N / 3`, with the authoritative order Vehicle, Garage, Race and shortcut introductions B2, B3, B4.

V1.6 keeps those shared semantics but no longer outlines a scroller's complete responsive width. G2, K1 and AA1 collect only visible `CanonicalGarageCard` buttons inside their named scroller, so the tutorial border fits the cards currently on screen and AA1 cannot absorb the left navigation rail. Objective cards have their own state-driven lifecycle: completed cards animate out and are destroyed, while remaining cards reflow without the periodic layout poll restarting motion.

V1.7 keeps that lifecycle and changes Objective 1's title to `BUY AND CUSTOMISE A CAR`. Objective typography now uses explicit onboarding sizes rather than the shared large page-heading token, reserves two title lines and disables truncation for `N/3`. Each shared panel is inset inside a padded CanvasGroup animation shell with clipping disabled, matching the safe-glow principle used by the car-menu buttons while retaining one slide/fade owner.

V1.8 keeps all V1.7 state and page targeting. Desktop objective text is multiplied by 1.5 without resizing the cards. Landscape-phone objectives keep their existing readable text sizes but use shorter cards, tighter gaps and a top position derived directly from the Roblox inset, with a live Boost-button overlap check. Tutorial callouts separately preserve physical screen edges without reserving the top-bar height across the whole phone display, allowing the stats explanation to stay centred beside the stats and shortcut explanations to sit close beneath their icons.

V1.9 replaces only the phone objective's remaining Roblox-inset anchor after the device emulator reported an excessively tall value. The objective stack now follows the actual live free-roam shortcut row plus a small tunable clearance, which keeps it visually adjacent to the Roblox controls across responsive HUD scaling. Mobile label, title and description bounds are sequential and compact; the description owns the remaining lower card area so its second line cannot be cut by the card bottom.

V1.10 retains that confirmed anchor and sizes the phone card for two description lines rather than retaining empty lower space. The description and progress bottoms share the same calculated second-line baseline, with one common three-pixel panel margin. Desktop card metrics remain unchanged.

For repeated purchase tests, `StudioVehicleSandboxEveryPlay=true` supplies a clean session-only vehicle inventory and test cash. This mode does not replace the customisation/profile owner: ProfileService remains authoritative, garage properties and their customisation are preserved, and all saves are suppressed only in Studio.

V1.13 strengthens that ownership boundary. Generic garage/racing profile snapshots do not own `Onboarding`, so ProfileService retains its current authoritative onboarding table before reconciling any such snapshot. Customisation purchases and page transitions therefore cannot erase `SeenPages` or revive completed objectives; no customisation renderer, mutation owner or saved schema field changes.
