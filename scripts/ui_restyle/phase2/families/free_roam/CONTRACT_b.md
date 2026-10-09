# FreeRoam family, B half: acceptance contract

Under `../../CONTRACT.md` (wave) and `../../API2.md` 5.3 and 6. Lane: High-Risk (second owners; driving input; one edit to a shared script). Generated only; nothing installed.

## Owners, before and after

| Surface | Classic (unchanged, never required under Pulse) | Pulse | Route |
|---|---|---|---|
| Touch drive controls, `MobileDriveControls_Phase1` | `Vehicles.MobileDriveControlsClient` | `FreeRoam.TouchControlsClient` + `FreeRoam.TouchControlsView` | fork: Classic 22-103 and 176-192 replaced |
| Activity HUD host, `ActivityHud` | `Activities.ActivityClient` | `FreeRoam.ActivityHudClient` (model inside) + `FreeRoam.ActivityHudView`; adds `ActivityHudLive` | new owner; the five views stay shared |
| Roblox core UI | none | `Shell.CoreUiPolicy` (entry `PulseCoreUiPolicy`) | Pulse-only |
| Route state read | `UI.RouteGuide` | same module + `GetRouteState()` | edited: three lines after 91 |

State owner of driving input stays `Vehicles.MobileDriveInputState`; the fork's kept code is its only touch writer. Geometry: `Kit.Layers` / `Kit.Metrics`. Visibility: root `Visible` only. Persistence, remotes, economy: none added.

## Must preserve

1. Every `MobileDriveInputState` write, every player attribute read and write, the gate at line 12 and the visibility rule at 197 of the touch client: byte-identical kept lines.
2. Names `MobileDriveControls_Phase1`, `DriftLeft`, `DriftRight`, `Boost`, `TurnLeft`, `TurnRight`, `Accelerator`, `Brake`, `ThumbstickHit`, `TiltDrift`, `TiltRecenter`, `TiltStatus`; `ActivityHud`, `DesignRoot`, `JobStrip`, `Offer`, `Countdown`, `RankUp`.
3. Activity: one `ActivityEvent` listener; one `ActivityInvoke` call site, `(action, args or {})`, never retried, reply normalised as Classic 65-67; `Cancel {}` then the "JOB CANCELLED" toast; `OpenJobs` created only if absent; the context fields of Classic 270-288; mount order Courier, Passenger, Taxi, Duel; the five view scripts not edited.
4. No Cash arithmetic: the rank-up reward is the payload value through `Data.Money`.
5. Core UI: nothing polled; chat is never turned on by the policy if it was off at start; Classic never requires the module.
6. `RouteGuide`: nothing but the added read-only function; it returns a new table and a clone of the points.

## Tests

- Offline: `py -3 forks/assemble_touch_fork.py --check` (kept lines in order; state and attribute lines of the kept part equal Classic's; review copy equals the assembled fork). `diff before/…RouteGuide.lua after/…RouteGuide.lua` = `91a92,94`.
- Pure (Edit harness): the four files in `tests/`: placement and names of the touch view; the activity model (strip, offer, countdown, rank-up, invoke, toast) over fake deps; the activity view mounted at R1080 and C844 over a fake model; the policy over fake services.
- Play: `NOTES_b.md`, "What the integrator must check in Play", items 1 to 15. Item 1 (input-state trace Classic against Pulse) is the family gate for this half.

## Done when

Fork diff equals the two listed spans; parity check has no difference outside `contract_b.json` `dropped` / `added`; pure tests pass; reviewer has read the fork, the RouteGuide edit and the activity call site; Play items pass in the TouchDrive emulator; Classic Play record unchanged.
