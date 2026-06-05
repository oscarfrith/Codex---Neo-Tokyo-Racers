# Compressed Architecture Roadmap

**Document status:** Active roadmap  
**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Phase 15 switched and tested  

## Goal

Now that the safe scaffold phases are working, the remaining architecture work should move in larger bundles. The goal is to finish the reorganisation in roughly six more phases, while still avoiding large risky rewrites of the current working client and server scripts.

## Recommended Remaining Phases

### Phase 6: World Services Migration

Move the smallest world systems first.

Included:

- Switch traffic lights from `ServerScriptService.Traffic Lights` to `ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService`.
- Stage lighting as a disabled shadow service.
- Stage LOD as a disabled shadow client controller.

Why first:

- Traffic lights are small, centralised, and do not depend on vehicle/customisation logic.
- Lighting and LOD are safer to stage first before switching.

### Phase 7: Shared Modules And UI Helpers

Promote the staged shadow UI/config helpers into final named modules.

Included:

- `UITheme`
- `UIPool`
- `UIFactory`
- Future shared UI widget modules
- Config references under `NeoTokyoRacers.Shared.Config`

Do not switch the full UI yet.

Status: prepared by `scripts/roblox_hierarchy_phase7_shared_ui_helpers_promote.lua`.

### Phase 8: Client UI Controller Split

Move the garage/dealership/customisation UI out of the giant client script in chunks.

Included:

- Dealership controller
- Colour picker module
- Module shop controller
- Customisation controller
- Preview vehicle controller

Do not touch driving during this phase.

Status: scaffold prepared by `scripts/roblox_hierarchy_phase8_client_ui_controller_scaffold.lua`.

### Phase 9: Server Garage And Vehicle Services

Move the current V56 server action layer into clean services.

Included:

- Garage service
- Vehicle build service
- Vehicle spawn service
- Profile/economy service

The older unused top-level server action code should only be removed after the new services are tested.

Status: scaffold prepared by `scripts/roblox_hierarchy_phase9_server_services_scaffold.lua`.

### Phase 10: Runtime Controller Consolidation

Clean up the active runtime controllers.

Included:

- Driving bootstrap
- Mobile controls
- Desktop/mobile HUD ownership
- VFX runtime ownership
- Re-entry and exit vehicle handling

Goal:

- Remove patch-style suppressor layers once a single HUD/mobile owner exists.

Status: scaffold prepared by `scripts/roblox_hierarchy_phase10_runtime_controller_scaffold.lua`.

### Phase 11: Final Naming And Legacy Cleanup

After all live systems have moved:

- Remove or archive unused compatibility layers.
- Rename remaining `HOVER_RACING_V2_*` live objects where safe.
- Update docs and source mirror.
- Run active script audit again.
- Keep `Workspace.Test + WIP Assets` excluded until separately requested.

Current status: readiness audit prepared by `scripts/roblox_hierarchy_phase11_architecture_readiness_audit.lua`.

Important note:

- Do not rename or delete current live `HOVER_RACING` scripts yet. Phases 8-10 created the target architecture, but the live UI/server/runtime owners still need extraction and testing before destructive cleanup.

### Phase 12: Server Action Snapshot

Capture the current V56 server action layer as a non-live parity reference before extracting server services.

Included:

- Capture V56 begin/end block from `HOVER_RACING_V2_Server`.
- Record line range, hash, action names, and function names.
- Store snapshot under the staged garage service.
- Store extraction plan under shared data modules.

Status: prepared by `scripts/roblox_hierarchy_phase12_server_action_snapshot.lua`.

### Phase 13: Server Parity Harness

Verify the current live V56 server action layer still matches the Phase 12 snapshot before any service extraction.

Included:

- Compare current V56 hash with snapshot hash.
- Verify V56 begin/end markers still exist.
- In Play mode, call only the non-mutating `GetInitial` action to check response shape.

Status: prepared by `scripts/roblox_hierarchy_phase13_server_parity_harness.lua`.

### Phase 14: Server Shadow Action Controller

Create a disabled shadow server action controller in the new architecture using the verified V56 action block.

Included:

- Verify current V56 hash against Phase 12 snapshot.
- Write `GarageActionController_Shadow_Disabled`.
- Keep legacy server action owner live.

Status: prepared by `scripts/roblox_hierarchy_phase14_server_shadow_action_controller.lua`.

### Phase 15: Server Action Owner Switch

Switch the server action owner from the legacy server script to the new architecture shadow controller.

Included:

- `SWITCH` mode disables `HOVER_RACING_V2_Server` and enables `GarageActionController_Shadow_Disabled`.
- `ROLLBACK` mode restores the old owner.
- No source edits, deletes, renames, or unrelated system changes.

Status: switched and tested. Output confirmed the active V56 controller now runs from `GarageActionController_Shadow_Disabled`; Phase 13 and Phase 13B passed after the switch.

Post-switch verification:

- `GarageActionController_Shadow_Disabled` is active.
- `HOVER_RACING_V2_Server` is no longer the live action owner.
- V56 hash remained `3be69270`.
- `GetInitial` response shape passed from the client.
- User confirmed cash, dealership, purchases, customisation, spawn, driving, and exit/re-enter worked after the switch.

## Safety Rule

Each phase may be larger than earlier phases, but each phase must still have one clear purpose. Do not combine client UI extraction, server service extraction, and driving changes in the same script.

## Current Phase

Current latest completed script:

```text
scripts/roblox_hierarchy_phase21_post_switch_audit.lua
```

Confirmed result:

- Post-switch architecture audit passed cleanly.
- Expected active owners enabled: 11 / 11.
- Unexpected active scripts: 0.
- Active scripts inside excluded `Test + WIP Assets`: 0.
- The only active legacy-named `HOVER_RACING` script is the expected `HOVER_RACING_V2_Client`.

Recommended next phase:

- Commit this checkpoint before attempting the large main client extraction.

Latest script:

```text
scripts/roblox_hierarchy_phase21_post_switch_audit.lua
```

Remaining architecture note:

- After Phase 20, the only major live legacy owner expected to remain is the large `HOVER_RACING_V2_Client`. Treat that as a separate extraction project, not a quick owner switch, because it owns garage UI, customisation flow, and driving handoff logic.
- The Phase 16-21 owner-switch batch is complete. Do not continue with more quick ownership phases in this batch.
- Next architecture work should be a separate main client extraction plan, focused on `HOVER_RACING_V2_Client` only after this checkpoint is committed.
- Main client extraction plan created: `docs/main-client-extraction-plan-2026-05-29.md`.
