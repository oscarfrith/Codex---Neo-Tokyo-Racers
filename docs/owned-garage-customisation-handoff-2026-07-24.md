# Owned Garage, Customisation And Hover Handoff

**Date:** 2026-07-24  
**Status:** User-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror.

## Start Here

This document supersedes the generated/pending wording in the earlier Phase 14 and 2026-07-23 feature notes. No Studio installer is currently required for this baseline. Do not rerun old installers for ordinary use.

Future work should begin by reading:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- this handoff
- the relevant topic document

## Confirmed Baseline

### Owned garage

- The starter two-bay property supports persistent two-slot display assignments without duplicate vehicle assignment.
- Display vehicles remain present after leaving management and after leaving/re-entering the garage.
- Foot entry, drive-in entry, foot exit and verified vehicle drive-out use the existing authoritative transition owner.
- Immediate cached-interior re-entry retains working desk, foot-exit and vehicle prompts without adding a cooldown.
- The garage uses the bounded local ClearNight environment and restores the latest city lighting stage on exit.
- Garage management uses the shared Display Cars, Build Garage and Style Garage composition.
- Structure, decoration and whole-garage lighting assets use the authoritative ServerStorage catalogues and fixed authoring slots.
- Style supports individual and bulk structure/decoration editing, shared colour sliders, structure materials and capability-aware channels.
- Private/Invite controls and dropdowns use the compact responsive HUD; the latest mirror includes movable `FootEntrance` and `DriveInEntrance` property markers.
- Icon IDs and image zoom values are centralised beneath `ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.OwnedGarageIcons`.

### Vehicle customisation

- The workspace is organised into Add Modules, Upgrade Modules and Paint Shop while retaining the existing authoritative module/economy/profile owners.
- Missing-module routes return to Add Modules through the shared short `BUY TO UNLOCK` presentation.
- Buyable module Neon, Thrust Colour and physical per-vehicle Underglow use the shared purchase/customise flow.
- Owned cosmetics open their colour sliders directly on later visits.
- All Neon excludes protected front/rear vehicle lights.
- Underglow supports attributed `SurfaceLight` objects beneath `UNDERGLOW_EMITTERS_DoNotRename` and the legacy `UNDERGLOW_MOUNT_DoNotRename` ancestry.
- Underglow runtime owns only saved `Color` and purchased `Enabled`. Brightness, Range, Angle, Face, Shadows and emitter count remain authored independently on each cockpit in Studio.

### Driving

- `ReplicatedStorage.NeoTokyoRacers.Config.Editable.01_GAME_BALANCE_Editable.Driving.HoverHeightStuds` is the shared hover-height setting.
- Driven, fallback and parked hover controllers read the same value when they start.
- The server-created vehicle's `HoverHeight` attribute reports the same setting for diagnostics and is not another physics owner.
- Supported metadata range is `0.5-8` studs; begin normal tuning around `2.5-4.5` and start a fresh Play session after editing.
- Spring, damping, ground sensors, alignment, handling, camera and VFX remain unchanged by the bridge.

## Mirror Evidence

The full mirror was generated at `2026-07-23 22:22:32/33`. Exported source and hierarchy contain:

- `NTR_OWNED_GARAGE_PHASE14_V2_2_RESPONSIVE_NAVIGATION_CLOSURE`
- `NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW`
- `NTR_OWNED_GARAGE_ICON_CONFIG_V1_1_LOCATION_SCALE`
- `NTR_OWNED_GARAGE_LIGHTING_CHANNELS_DECORATION_FLOW_V1`
- `NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1_2_PROMPT_LIFECYCLE`
- `NTR_OWNED_GARAGE_MOBILE_ACCESS_WORLD_ENTRIES_V1`
- `NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1`
- `NTR_CUSTOMISATION_VEHICLE_COSMETIC_CATALOG_V1_2_AUTHORED_LIGHT_PROPERTIES`
- `NTR_DRIVING_HOVER_HEIGHT_CONFIG_BRIDGE_V1`

The hierarchy also contains the hover configuration attributes, material/icon sizing configuration, owned-garage entry markers and underglow authoring folders. Neither mirror area appears stale for this handoff.

## Current Risks And Deferred Work

- Visitor admission remains disabled. Do not enable the legacy in-memory visitor path; a future visitor feature needs one explicit admission/session/teleport/return owner.
- The broad service and folder architecture reorganisation remains post-submission work. Preserve ProfileService authority, stable catalogue IDs and command boundaries so the confirmed systems can be moved without redesigning player data.
- Arbitrary decoration placement, catalogue virtualisation, richer offline invites and additional property templates remain deferred. The fixed-slot starter garage is the submission baseline.
- New garages must provide their own property definition, exterior entry/exit markers, collision shell, interior template and authored asset catalogues. Do not infer another garage from `STARTER_TWO_BAY`.
- Keep `ReplicatedStorage.ZZZ` authoring copies outside all runtime contracts.
- A full Gamefam submission regression across desktop, controller, phone portrait/landscape, two players and save/rejoin is still a release task even though the focused feature checks are user-confirmed.

## Recommended Release Smoke

From a fresh Studio session:

1. Spawn two different vehicles and confirm drive, exit/re-entry, reset and parked/driven hover parity.
2. Enter the starter garage on foot and by vehicle.
3. Assign different vehicles to both display slots, leave management, exit and re-enter.
4. Leave in vehicle A, immediately re-enter, then leave in vehicle B.
5. Open Build and Style, preview one asset, save one colour/material and confirm no whole-room flicker.
6. Buy/use Thrust Colour or Underglow, verify front/rear lights remain protected and rejoin once.
7. Check Private/Invite dropdown scaling on a narrow phone emulator.

Record any failure as a new bounded task against this baseline. Do not repair it by extending the old Phase 14 patch chain.

## Canonical Recovery Installers

These scripts are retained for recovery/audit of their exact scopes, not routine reruns:

- `scripts/roblox_owned_garage_phase14_lighting_and_flow.lua`
- `scripts/roblox_owned_garage_style_ux_v1.lua`
- `scripts/roblox_owned_garage_icon_config_v1.lua`
- `scripts/roblox_owned_garage_lighting_channels_and_decoration_flow_v1.lua`
- `scripts/roblox_owned_garage_clear_night_environment_v1.lua`
- `scripts/roblox_owned_garage_mobile_access_and_world_entries_v1.lua`
- `scripts/roblox_customisation_three_workshop_flow_v1.lua`
- `scripts/roblox_customisation_vehicle_cosmetics_and_empty_routes_v1.lua`
- `scripts/roblox_driving_hover_height_config_bridge_v1.lua`

## Git Close-Out

Commit the generated scripts, documentation and both Studio mirror areas together. Do not commit `docs/studio-full-export-paste.txt`.

Suggested GitHub Desktop title:

`Complete owned garage and customisation handoff`

Suggested description:

`Lock the confirmed owned-garage, customisation, authored underglow and shared hover-height baseline; include the refreshed Studio mirror, recovery installers, verification contracts and post-submission risks.`
