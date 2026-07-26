# Player Onboarding V1 Handoff

**Confirmed baseline:** V1.13  
**Confirmed:** 2026-07-25  
**Canonical recovery installer:** `scripts/roblox_player_onboarding_v1.lua`

## Result

The complete three-objective onboarding system is confirmed working on desktop and landscape mobile presentation, in a fresh four-client server test, through race exit and customisation re-entry, and across a later server session.

- Objective 1 introduces vehicle purchase/customisation and completes after purchase, driving and the My Vehicles acknowledgement.
- Objectives 2 and 3 then appear together for garage customisation and event entry.
- Menu explanations are first-view state independent of objective completion.
- Completed cards animate out and do not return.
- Existing menu, race, vehicle, garage, persistence and VFX owners remain authoritative.
- ProfileService owns saved `Onboarding`; generic garage/racing imports cannot replace it.
- Race vehicles cannot trigger the first-free-roam PC controls popup.
- One shared responsive overlay and one guide renderer own onboarding presentation.

## Confirmed Persistence Configuration

Set both attributes under `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.Onboarding_EditAttributes` to false:

- `StudioReplayEveryPlay=false`
- `StudioVehicleSandboxEveryPlay=false`

Replay creates fresh session-only tutorial state. The vehicle sandbox creates a clean in-memory vehicle profile and suppresses every profile save. Both remain useful for isolated iteration but are not release settings.

## Verification Evidence

- Fresh Player 4 completed the full onboarding sequence in a server-and-clients test.
- PC controls did not interrupt the race.
- Objective 1, shortcut prompts and already-seen customisation prompts did not return after race exit.
- With both Studio test overrides disabled, completion and seen-page state remained correct after closing and starting another server session.
- The user confirmed the final result works well.

## Remaining Work

- Closed on 2026-07-26: the refreshed `13:36:41` hierarchy contains installed V1.13 source and records `StudioReplayEveryPlay=false` plus `StudioVehicleSandboxEveryPlay=false`.
- The time-trial setup reward panel still shows the base reward instead of the selected tier-adjusted reward. This is a separate racing UI task.

Do not rerun older onboarding installers. Repair only the canonical V1.13 installer if recovery is ever needed.
