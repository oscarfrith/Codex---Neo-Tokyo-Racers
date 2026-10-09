# RaceSession family: acceptance contract

Status: **generated, not installed.** Under `../../CONTRACT.md` (wave) and `../../API2.md` 5.5 and section 6. Lane: High-Risk (second owner per surface; queue, reset and exit call sites; one edit to an existing script).

## Owners, before and after

| Surface | Classic owner (unchanged, still the owner with `UIStyle` Classic) | Pulse owner (`UIPulse.RaceSession.*`) | Route |
|---|---|---|---|
| In-race HUD, reset, exit | `Racing.RaceSessionPresentationClient` | `RaceHudClient` + `RaceHudModel` + `RaceHudView` | new owner |
| Countdown, `CountdownPresentationReady` | `Racing.RaceCountdownPresentationClient` | `CountdownClient` | new owner (one module) |
| Queue join and leave, banner | `Racing.RaceQueueClient` | `QueueClient` | new owner (one module) |
| Results, again, exit to start | `Racing.RaceTimeTrialResultCoachClient` | `ResultsClient` + `ResultsModel` + `ResultsView` | new owner |
| 3D gate guide, wrong-way prompt | `Racing.RaceRouteGuideClient` | `RouteGuideClient` | fork, one span (271-300) |
| Race fade label | `Racing.RaceTransitionClient` | same module, four inserted lines | edited (seam) |
| Gallery items | none | `Dev.Fixtures.RaceSession` | new |

State owner: the two models and the two single-module controllers. Geometry: `Kit.Metrics` and `Kit.Layers` slots only. Visibility: `layer.SetVisible`; no `ScreenGui.Enabled` write. Persistence, economy, authority: none added; no server change. `RaceLifecyclePresentationClient` is untouched and none of its kill-list names is created.

## ScreenGuis and reserved names (all from `Layers.Create`)

`SharedInRaceHUD` 155 and `SharedInRaceHUDLive` 156 (Hud); `RaceCountdown` 205; `RaceQueueBanner` 190; `RaceRouteGuide_Phase5` 78; `UnifiedRaceResults` 220 with `UnifiedRaceResultsScrim` 219 (Menu).

Child names assigned by this contract (API1 rule 10): `SessionControls` (the reset and exit holder) and `PlayerMarker` (the route-map marker) are reserved names and are used exactly where Classic uses them. Kept Classic names that nothing else reads: `LapProgress`, `PrimaryMetric`, `SessionBoard`, `RaceMap`, `SimplifiedRaceMap`, `CountdownCard`, `QueueBanner`, `WrongWayPrompt`, `RaceResults`, `SessionLaps`.

## Must preserve

1. Remote call sites, copied: `RaceRequest` `GetTimeTrialPersonalBest {EventId, VehicleTier}`, `ResetActiveTimeTrial` / `ExitActiveTimeTrial {RunId, EventId}`, `GetTimeTrialLeaderboard {EventId, VehicleTier, Limit = 20}`, `ExitFinishedTimeTrial {}`, `StartStagedTimeTrial {EventId, VehicleId, LapCount}`; `RaceQueueRequest` `ResetToLastCheckpoint` / `ExitRaceToStart {RunId, EventId}` (HUD), `ExitRaceToStart {}` (results), `JoinQueue {EventId, VehicleId}`, `LeaveQueue {}`. No call is retried. The parity check (`tools/parity_check.py race_session`) reports 0 open.
2. `Runtime.Racing:SetAttribute("CountdownPresentationReady", true)` once, as the last statement of the countdown start, after connecting.
3. `FreeRoamHudPresentationMode` owner keys and `KeepTelemetry`: `RaceSession` true, `RaceQueue` true, `RaceResults` false.
4. One listener of `StartRaceQueueRequest` (`QueueClient`). Results only fires it.
5. Player attributes `LastRacingEventId` and `LastRacingVehicleId` written before `JoinQueue`; read by RACE AGAIN.
6. `RaceTransitionRequest` step names and payloads: `FadeOut {Reason, Label}`, 0.25 s, `RestoreCamera {Reason}`, `FadeIn {Reason, Delay, Success}`; `BeginLoading {Destination, Status}`, `CompleteLoading {Status}`, `FailLoading {Status, Reason}`.
7. Results are a projection: every value is a payload field, a leaderboard reply field or a replicated attribute. The only arithmetic is the driver XP change (attribute after minus attribute at the result).
8. The HUD does not return after finish or exit (model rule, tested).
9. Exactly the `RaceEvent` and `RaceQueueEvent` kinds each Classic owner handles.
10. `RaceTransitionClient`: every Classic statement stays and runs first; the edit is four inserted lines (`seam.diff`: 0 removed, 4 added; `before/` is a byte copy of `classic/sources`).
11. The fork keeps every Classic line outside 271-300, including its `ResponsiveUIFoundation` require, the 3D guide and the wrong-way logic.

## Exclusions

The 3D gate guide, arrows and billboards (world art); a free-roam minimap in races; per-checkpoint personal-best deltas; gap times in the live order (the payload has none); the gauge (FreeRoam family, through `KeepTelemetry`); medal and avatar images; fixing Classic.

## Tests and gates

- Pure tests (`tests/`, nine files): both models replay payload fixtures (position, laps, timer, pips, delta, every result state, the exit confirmation, every call as remote + action + keys); countdown and queue controllers; both views and every fixture state mounted at R1080 and C844.
- Static: `tools/lint_phase2.py race_session` (findings only in kept fork lines until the fork is built); `tools/parity_check.py race_session`.
- Play (integrator): `NOTES.md`, section "Check in Play". No agent crosses a time-trial finish: results are checked from the gallery and the Quit path.

Done when: the wave contract's steps 1 to 12 pass for install 4.
