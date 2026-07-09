# Racing Phase 11H Visibility, VFX, And Name Tag Gate

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11h_visibility_vfx_nametag_gate.lua`

## Why

After Phase 11G fixed multiplayer arrow/barrier collision, the remaining isolation problem was presentation leakage:

- free-roam players could still see race/time-trial vehicle VFX;
- race/time-trial players could still see unrelated free-roam session effects;
- player name tags could remain visible across the race/free-roam boundary.

Phase 11D's visibility client hid parts and some VFX on a heartbeat, but the active VFX runtime can re-enable effects during `RenderStepped`. Name tags also need humanoid display-distance handling, not only part/gui hiding.

## What Changes

Phase 11H canonically replaces only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active
```

The new client:

- listens to existing `RaceVisibilityUpdate` payloads;
- hides active race/time-trial participants from nonparticipants;
- hides nonparticipants from active race/time-trial players;
- keeps racers in the same race visible to each other;
- hides character parts, vehicle parts, decals/textures, BillboardGuis, SurfaceGuis, highlights, particles, beams, trails, lights, fire/smoke/sparkles;
- hides Roblox humanoid name/health display by setting local display distances to zero while hidden;
- runs as a late-frame gate while active so VFX re-enabled by the VFX runtime are forced off before the frame is presented.

It does not edit rewards, route-guide config, arrow folders, matchmaking, reset logic, driving physics, or the main client bootstrap.

## Verification

Run in Edit mode, restart Play, then test:

1. Start a 2-player local race.
2. From a free-roam client, confirm race players, race vehicles, race VFX, and race player name tags are not visible.
3. From a race client, confirm unrelated free-roam players, vehicles, VFX, and name tags are not visible.
4. Confirm racers in the same multiplayer race can still see each other.
5. Start a solo time trial and confirm free-roam clients cannot see that player/vehicle/VFX/name tag.
6. Finish or quit and confirm normal free-roam visibility returns.

## Risk / Rollback

Risk is local presentation only. If it over-hides a visible participant, use Roblox place version history or rerun the previous Phase 11D visibility client from the mirror. The script changes one isolated LocalScript and creates no backup instances.
