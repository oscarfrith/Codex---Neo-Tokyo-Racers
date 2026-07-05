# Customisation UI

## Visual Style

The UI direction is futuristic, compact, and readable. It uses:

- Michroma-style futuristic text where possible.
- Dark translucent panels.
- Light green borders/accent colour.
- Consistent button sizing.
- Responsive scaling for mobile and desktop.

Avoid oversized landing-page style UI. The garage/customisation UI should be functional and scan-friendly.

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

## Dealership Flow

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

Known mobile driving UI:

- Accelerator button bottom right.
- Smaller brake pedal nearby.
- A fixed horizontal steering thumbstick on the left replaces the four steering/drift arrow buttons after running `scripts/roblox_mobile_drive_thumbstick_install.lua`.
- Steering begins only when the player touches the visible thumbstick or its forgiving enlarged hit area.
- Run `scripts/roblox_mobile_drive_thumbstick_v2_visual_refinement.lua` after V1 to add a second outer drift ring. The border between the green regular-turn ring and outer drift ring matches the configured drift threshold.
- The outer drift ring has `1.8x` the inner radius with a darker translucent band. Its idle border and `DRIFT` text use the light-green HUD accent. When the pointer crosses into the outer band, the pointer, text, and outer border all turn red, and the pointer can travel to the usable outer edge.
- V2 raises the MPH/boost stack and sizes both pedals at `1.275x` while hiding their surrounding button frames.
- Boost button also acts as boost meter.
- MPH text shown above boost button.
- PC bottom-left drive HUD should be hidden on mobile.
