# Customisation UI

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
