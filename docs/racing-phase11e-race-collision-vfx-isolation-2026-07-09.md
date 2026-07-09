# Racing Phase 11E - Race Collision And VFX Isolation

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11e_race_collision_vfx_isolation.lua`

## Purpose

Phase 11D improved race exit cleanup: after exiting, arrow/barrier collisions turn off correctly and teleporting back to the route start works. Testing then showed three remaining multiplayer race issues:

- arrow/barrier collision only worked for the initially visible start-window arrows, while later race segments did not collide;
- race/time-trial vehicle VFX still leaked between free roam and active sessions;
- race vehicles could collide with each other.

Time trials already handled arrow/barrier segment collision correctly, so Phase 11E focuses on multiplayer race-specific repair plus VFX runtime gating.

## What It Changes

- Reapplies race participant collision groups on each multiplayer race checkpoint before updating the participant segment.
- Adds debug attributes to `RaceInstances.<RunId>.SessionAssets.ArrowBarrierProxies`:
  - `ActiveProxyCount`
  - `ActiveSegmentCount`
  - `ParticipantSegments`
  - `LastRebuiltClock`
- Sets the race participant collision group to not collide with itself, so active race participants/vehicles should not physically hit each other.
- Adds a race visibility gate inside `CachedThrustVisualRuntime` so the VFX owner stops re-enabling VFX that should be hidden by race/session state.

## Deliberate Non-Changes

- Does not edit reward config.
- Does not edit route-guide config.
- Does not edit arrow folder layout.
- Does not touch the register-limited main client bootstrap.
- Does not add continuous VFX rescans/rebuilds.
- Does not globally retag all free-roam vehicles into a new vehicle collision group yet.

## Verification

1. Run the script in Studio Edit mode.
2. Restart Play.
3. Start a 2-player local server race.
4. Drive past checkpoint 2 and later checkpoints.
5. Confirm the visible arrow/barrier segments also collide after checkpoint 2.
6. Inspect `RaceInstances.<RunId>.SessionAssets.ArrowBarrierProxies` while racing and confirm `ParticipantSegments` changes as racers progress.
7. Confirm race vehicles do not physically collide with each other.
8. From a free-roam player, confirm race/time-trial vehicle VFX are not visible.
9. From a race player, confirm free-roam vehicle VFX are not visible while racing.
10. Confirm normal free-roam vehicle VFX still work after exiting the race.

## Risks

The VFX repair patches the cached VFX runtime, which is a sensitive confirmed baseline. The patch is intentionally narrow: it gates existing enable/update decisions using race visibility state and does not add rescans, rebuild loops, or new attachment ownership.

The participant collision policy currently affects race/session participants. A later global “all player vehicles never collide” system should be handled as a separate vehicle/runtime collision phase so free-roam vehicle behavior is changed deliberately.
