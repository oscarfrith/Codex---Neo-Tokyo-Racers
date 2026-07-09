# Racing Phase 11I Idle Engine VFX Flush

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11i_idle_engine_vfx_flush.lua`

## Why

Phase 11H mostly fixed race/time-trial visibility leaks, but idle engine VFX could still remain visible while other VFX disappeared.

The likely root is that idle engine effects use `ParticleEmitter` particles with existing live particles. Setting `Enabled = false` stops new emission, but already-emitted particles can remain visible until their lifetime expires. Boost and drift effects appeared fixed because those particles are shorter-lived or less continuously emitted.

## What Changes

Phase 11I patches only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active
```

It adds:

- `ParticleEmitter:Clear()` while hidden;
- `Trail:Clear()` while hidden, guarded with `pcall`;
- an extra runtime VFX host part hide for parts marked `NTR_VFXRuntimeHost`.

This keeps the Phase 11H visibility ownership model and does not touch VFX templates, driving, rewards, route-guide config, matchmaking, or the main client bootstrap.

## Verification

After running in Edit mode and restarting Play:

1. Start a race or time trial with another client watching from free roam.
2. Confirm hidden race/time-trial vehicles show no idle engine flame.
3. Confirm boost/drift VFX remain hidden across the boundary.
4. Confirm visible same-race participants still show their normal VFX.
5. Finish/quit and confirm free-roam VFX returns normally for visible vehicles.

## Rollback

Use Roblox place version history or rerun Phase 11H to restore the previous isolated visibility client.
