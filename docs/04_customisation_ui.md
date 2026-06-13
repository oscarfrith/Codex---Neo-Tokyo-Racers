# Customisation UI

## Visual Style

The UI direction is futuristic, compact, and readable. It uses:

- Michroma-style futuristic text where possible.
- Dark translucent panels.
- Light green borders/accent colour.
- Consistent button sizing.
- Responsive scaling for mobile and desktop.

Avoid oversized landing-page style UI. The garage/customisation UI should be functional and scan-friendly.

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
- The user confirmed Phase 1-7 working on 2026-06-03.

For mobile:

- Cockpit cards should scale to fit a `3x3` style grid where possible.
- Left/category UI should not overlap the cash UI.
- Right stats panel should remain readable and aligned with the rest of the layout.

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
