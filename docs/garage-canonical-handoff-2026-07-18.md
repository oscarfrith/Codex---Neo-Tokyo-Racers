# Canonical Garage Experience Handoff

**Status:** User-confirmed working  
**Mirror:** Refreshed 2026-07-18 23:14:48  
**Scope:** Dealership, owned/drive-in customisation, modules, upgrades, responsive presentation, previews, cameras, lighting and preview VFX

## Locked Baseline

The current garage experience is the starting point for future work. Do not rebuild it from older legacy installers or reintroduce retired UI owners.

Confirmed behaviour includes:

- PC uses E and touch uses the matching native tap prompt to enter Dealership or Customisation.
- Dealership and owned Customisation enter the shared garage Browser/Workspace experience with the approved distinct routing.
- Vehicle cards preview factory configuration in Dealership and the exact saved owned configuration in Customisation.
- The shared desktop composition uniformly scales for tablet/phone and observes the established Roblox top-left safe area.
- Browser, Paint, Hub, Build Modules, Owned/Buy, Edit & Upgrade, colour, cosmetics, neon and performance pages use the shared visual/component contracts.
- Cash, spaces, stats, headers, action buttons, card-relative Buy/Equip/Customise actions and full-screen confirmations use the canonical shared renderers.
- Physical module copies preserve instance-specific colour, neon and upgrade data. Purchase/equip/reassignment and fallback module rules are server-authoritative and atomic.
- Temporary vehicle/module/colour/neon previews are read-only and clear when changing page, backing out or driving.
- Horizontal car/module positions and vertical category positions survive card selection rerenders.
- Garage preview uses the authoritative preview pad, orbit/zoom, category views, hover wobble and authored 8 PM lighting.
- Normal preview VFX show engine idle plus hover only. Acceleration, boost and stabiliser effects appear only while editing Thrust Colour.

## Canonical Owners

| Concern | Owner |
|---|---|
| Garage flow/state | `ModuleShopUIController` |
| Shared presentation/components | `GarageReplacementComponents` |
| Vehicle Browser | `GarageBrowserController` |
| Workspace pages | `GarageWorkspaceController` |
| Preview construction | `PreviewVehicleController` plus the instance preview adapters |
| Preview camera | `PreviewCameraController` |
| Garage hover/wobble/lighting presentation | `GaragePreviewPresentationController_Active` |
| Preview VFX attachment and enabled state | `CachedThrustVisualRuntime` |
| Preview thrust colour/input bridge | `ThrustPreviewController_Active`—colour/input only, never template attachment |
| Physical module transactions/customisation | Isolated garage module instance runtimes and `GarageActionController_Shadow_Disabled` bridges |

No future fix should create a second owner for any row above. Extend or replace the canonical owner instead.

## Final Preview VFX Contract

The root preview folder publishes `PreviewVFXMode`:

- `Idle`: `Driving=true`, acceleration/boost/drift false; template controller renders engine idle plus hover.
- `ThrustColour`: acceleration/boost/left+right stabiliser true for colour inspection.

`ForceThrustPreview` is legacy compatibility only for garage previews. `GaragePreviewPresentationController_Active` keeps it false. The final installer removes the preview bridge's duplicate `VehicleVFXController.Attach` and `Update` paths.

Final repair:

- `scripts/roblox_ui_garage_preview_vfx_single_owner_installer.lua`

Superseded as VFX ownership fixes:

- `scripts/roblox_ui_garage_camera_vfx_scroll_refinement_v1_installer.lua`
- `scripts/roblox_ui_garage_camera_vfx_refinement_v1_1_installer.lua`

Their camera/scroll source changes remain part of the confirmed live baseline; do not rerun them to repair VFX.

## Camera And Presentation Configuration

Current mirrored camera values under `Config.UI.GarageReplacement` include:

- `PreviewCameraYawOffsetDegrees = 45`
- `PreviewCameraFront45YawDegrees = 135`
- `PreviewCameraSideYawDegrees = 90`
- `PreviewCameraRear45YawDegrees = 45`
- `PreviewCameraRearYawDegrees = 0`
- `PreviewCameraFrontYawDegrees` controls the direct-front view (with a mirrored fallback of `180`)

The shared mapping is:

- All, Cockpit, Thrust and Front Engine: Front45
- Front Bumper: Front
- Stabilisers and Side Pods: Side
- Rear Engine and Spoiler: Rear45
- Boost and Rear Bumper: Rear

Use the config attributes for tuning. Do not add page-specific camera writers.

## Relevant Confirmed Installer History

These scripts explain the current live source but are not a chain to rerun casually:

- `scripts/roblox_ui_garage_responsive_scaled_touch_installer.lua`
- `scripts/roblox_ui_garage_native_entrance_prompts_installer.lua`
- `scripts/roblox_ui_garage_flow_navigation_colour_palette_installer.lua`
- `scripts/roblox_ui_garage_flow_refinement_v2_installer.lua`
- `scripts/roblox_ui_garage_flow_refinement_v2_1_installer.lua`
- `scripts/roblox_ui_garage_customise_compact_rail_v2_2_installer.lua`
- `scripts/roblox_ui_garage_navigation_scroll_economy_phase_installer.lua`
- `scripts/roblox_ui_garage_preview_presentation_v1_installer.lua`
- `scripts/roblox_ui_garage_category_camera_angles_v1_installer.lua`
- `scripts/roblox_ui_garage_camera_vfx_scroll_refinement_v1_installer.lua`
- `scripts/roblox_ui_garage_camera_vfx_refinement_v1_1_installer.lua`
- `scripts/roblox_ui_garage_preview_vfx_single_owner_installer.lua`

Future work must target the refreshed mirror rather than assuming an earlier installer source shape.

## Remaining Optional Release Checks

There is no current functional blocker. Before a public release build, a fresh chat may run a read-only regression pass covering:

1. repeated PC and real-device/touch entry, page changes, Back/Drive/Exit and re-entry;
2. normal versus Thrust Colour VFX state and stable runtime-host/instance counts over 60-120 seconds;
3. module purchase, cross-vehicle equip, preview cancellation and save/rejoin;
4. one low-end mobile performance pass.

These are release confidence checks, not permission to reopen confirmed presentation work without evidence.

## Future Workflow

Read `docs/13_efficient_feature_delivery_protocol.md` and use its proportional lane:

- Fast Lane for isolated text/icon/config tuning.
- Standard Lane for connected garage presentation or navigation.
- High-Risk Lane for persistence, inventory, economy, VFX ownership or legacy retirement.

Use `continue:` only for the next uncompleted step of an approved plan. Use `audit:` for read-only release verification and `handoff:` at the next confirmed milestone.
