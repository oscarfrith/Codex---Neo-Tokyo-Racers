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

## Mobile Driving UI

Known mobile driving UI:

- Accelerator button bottom right.
- Smaller brake pedal nearby.
- Left-side steering/drift controls.
- Boost button also acts as boost meter.
- MPH text shown above boost button.
- PC bottom-left drive HUD should be hidden on mobile.
