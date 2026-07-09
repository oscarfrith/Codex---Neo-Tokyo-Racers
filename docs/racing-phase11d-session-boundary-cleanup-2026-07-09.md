# Racing Phase 11D - Session Boundary Cleanup

**Created:** 2026-07-09  
**Script:** `scripts/roblox_racing_phase11d_session_boundary_cleanup.lua`

## Purpose

Phase 11C made multiplayer races load with server-spawned grid vehicles, but testing showed the end-of-race boundary was leaking state:

- arrow collision could be inactive during the race and then active after finishing;
- some arrow visuals could remain after the player finished;
- free-roam players could still see hover vehicle VFX from players inside races/time trials;
- finishing a race left the vehicle/camera/UI transition too loose.

Phase 11D treats this as one session-boundary problem rather than separate visual patches.

## What It Changes

- Race finish immediately removes the finished player from active race visibility/collision participation.
- Finished race vehicles are despawned shortly after the finish event, while the client is fading to black.
- The race result panel stays visible above the black fade and the button becomes `EXIT`.
- Pressing `EXIT` teleports the player back to the route race teleport/start location and restores the camera/HUD.
- Race arrow visibility now clears on `RaceFinished`.
- The server reapplies session-asset participant collision after grid vehicles are fully staged.
- A new isolated `RaceParticipantVisibilityClient_Active` hides participant bodies and VFX, including particles, beams, trails, lights, decals/textures, and surface/billboard UI from nonparticipants.

## Deliberate Non-Changes

- Does not edit reward config.
- Does not edit route-guide config.
- Does not edit arrow folder layout or route attributes.
- Does not touch the register-limited main client bootstrap.
- Does not change Phase 8H reset architecture.
- Does not change the core VFX runtime; visibility isolation is layered outside it.

## Verification

1. Run the script in Studio Edit mode.
2. Restart Play.
3. Start a 2-player local server race.
4. Confirm arrow barriers collide during the race.
5. Finish with one player while the other keeps racing.
6. Confirm the finished player fades to black, sees only the race result UI, and no longer sees/collides with race arrows.
7. Confirm the still-racing player continues to see/collide with the correct nearby arrow segments.
8. From a free-roam player, confirm active race/time-trial vehicle VFX are hidden.
9. Press `EXIT` on the finish UI and confirm the player returns to the race teleport/start point, camera restores, and free-roam HUD returns cleanly.

## Risks

This is a guarded source patch against isolated Racing scripts. If it reports a missing source anchor, refresh the Studio mirror before another repair. The intended fix is still a single session-boundary phase, not a chain of separate arrow/VFX/UI patches.

The same-server visibility system is still presentation-level isolation. Competitive release races may later move to reserved servers or route pockets for stronger physical/world isolation.

## Installer Repair

The first generated installer could fail with:

```text
Could not find source anchor: exitRacePlayer clean finished exit
```

Root cause: the `exitRacePlayer` anchor was too exact after the finished-return edge case was added. The installer now replaces that function by the boundary before `callRaceRewardService`, while remaining guarded and safe to rerun after the earlier partial install.

A second generated installer could fail with:

```text
Could not find source anchor: RaceQueue reset on queue update
```

Root cause: the isolated race queue UI client had drifted enough that patching individual event branches was too brittle. The installer now replaces the queue client's state block, leave button handler, and queue event handler by stable block boundaries.
