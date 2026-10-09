# Spike 13 notes: MicroProfiler labels and Classic frame steps (from source)

Source: `scripts/ui_restyle/classic/sources/` (byte-exact dump of v3). Nothing here was run. The Play half is
`13_profiler_labels.lua`.

## Labels Classic sets itself

One. `ReplicatedStorage.Modules.Game.World.LODClient` line 44:
`debug.profilebegin(".WorldLOD.Step") ... debug.profileend()`. No UI script calls `debug.profilebegin` or
`debug.setmemorycategory`.

## Named render-step bindings (`RunService:BindToRenderStep`)

| Name | Priority | Script and line | What it is |
|---|---|---|---|
| `PCFreeRoamHudPhase4A` | 3000 | `Game.UI.DesktopFreeRoamHudUI` 1368 (calls `updateRuntime(dt)`) | **The Classic desktop HUD frame step.** Lines 1355 to 1367 first unbind thirteen older names (`PCFreeRoamHudPhase1`, `Phase2B` to `Phase2I`, `Phase3A` to `Phase3D`) |
| `FullMapUI` | `Last + 10` | `Game.UI.FullMapUI` 533 (unbound at 486) | Full map, only while open |
| `OwnedGarageTouchCameraGuard` | `Camera + 1` | `Game.UI.GarageInteriorModeUI` 170 (name at 53, unbound at 71) | Touch camera guard in the owned garage |
| `VehicleCamera` | `Camera + 1` or `+ 2` | `Game.Vehicles.DrivingCameraClient` 748 and 753 (name at 17) | Driving camera, not UI |
| `VehicleCameraInitialFraming` | `Camera - 1` | `DrivingCameraClient` 752 (name at 18) | Not UI |
| `DrivingCameraAssist` | - | `Game.Vehicles.DrivingClient` (name at 22) | Not UI |

## Unnamed per-frame connections in UI scripts

These are `RunService.RenderStepped:Connect` or `Heartbeat:Connect` with an anonymous function, so they carry no
name of their own.

| Script and line | Signal | What it is |
|---|---|---|
| `Game.UI.MobileFreeRoamHudUI` 391 | RenderStepped | **The Classic mobile HUD frame step** |
| `Game.UI.OnboardingClient` 757 | RenderStepped | Throttled to 0.2 s: locks, objective, guide trail, page poll |
| `Game.UI.OnboardingGuideTrailRenderer` 67 | RenderStepped | Guide trail update |
| `Game.UI.GarageComponents` 170 and 187 | RenderStepped | Garage shell |
| `Game.Garage.GarageUI` 131 | RenderStepped | Garage |
| `Game.Racing.RaceSessionPresentationClient` 317 | RenderStepped | In-race HUD |
| `Game.Racing.RaceRouteGuideClient` 432 | Heartbeat | Route guide |
| `Game.Activities.ActivityClient` 201 | RenderStepped | Activity HUD |
| `Game.Activities.DuelClientView` 273, `JobClient` 417 | Heartbeat | Activity views |
| `Game.Vehicles.MobileDriveControlsClient` 196 | RenderStepped | Touch controls |
| `Game.Dealership.DealershipIntroClient` 420 | RenderStepped | Intro pill (off in v3) |

## What this means for the Classic comparison (plan 5.3)

- Every client module is required from one LocalScript, `StarterPlayerScripts.ClientBase` (lines 105 to 109), and
  `ClientLifecycle` starts each entry in its own `task.spawn` (line 28). If the MicroProfiler names script work after
  the script that owns the thread, all of the rows above may appear under the single label `ClientBase`. In that
  case the unnamed connections cannot be told apart and the mobile HUD step cannot be isolated at all.
- The desktop HUD step is the best candidate: it is a `BindToRenderStep` callback with a unique name. Whether the
  profiler shows the binding name as a bar is what the capture in `13_profiler_labels.lua` settles (its own
  `PulseSpike13_Bound` binding is the test case, and `PCFreeRoamHudPhase4A` is the bar to look for).
- Expected result: partial. Desktop HUD isolated by binding name if binding names show; mobile HUD and every other
  Classic UI step not isolated. No Classic script is edited to add labels (Classic is frozen, plan 1.8).

## Pre-chosen methods

| Result | Method |
|---|---|
| `debug.profilebegin` works and the bars show | `Kit.Perf` labels every Pulse frame step (`Pulse.<Surface>.<Step>`); script time reported for Pulse |
| `PCFreeRoamHudPhase4A` shows as its own bar | Classic desktop HUD script time is read from the capture and compared with the Pulse HUD step, three captures each |
| It does not show, or only `ClientBase` shows | Script time is reported for Pulse alone. Classic is compared on frame time (`perf_sample`) and on write counts (`write_probe`), which are measured from outside the code |
| `debug.profilebegin` errors on the client | No labels. `Kit.Perf` keeps its own `os.clock()` accumulators behind the Studio debug attribute |
