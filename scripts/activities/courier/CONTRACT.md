# Courier job: acceptance contract

Feature: Street Life design 4.6, built on [activities-contract](../../../docs/architecture/activities-contract.md). Lane: **High-Risk** (it grants Cash and XP). Installer spec: [spec.json](spec.json).

## Goal

A player drives their own car onto one of three Dispatch Hub pads, picks STANDARD, HOT or FRAGILE, follows the pink activity route to a drop on the road network 600–2000 studs away, stops within 40 studs of it, and is paid Cash and XP with a star grade. Runs completed back to back within 90 s build a chain multiplier.

## Owners

| Piece | Location | Owns |
|---|---|---|
| CourierRules (pure) | ServerStorage.Modules.Game.Activities | All maths: config bounds, variants, trip distance, time limit, pay, XP, stars, chain, delivery test, plausibility, teleport segment check, Fragile impact detection, settlement. |
| CourierJob (server) | ServerStorage.Modules.Game.Activities | Registers kind `Courier` with ActivityService. Owns run state, the drop, the timer, impacts, delivery, chain and the payout call. One Heartbeat loop (TickHz, default 10 Hz) for all runs, connected only while runs exist. |
| CourierClientView (client) | ReplicatedStorage.Modules.Game.Activities | Presentation only: the COURIER Jobs entry, the offer card, the job strip text, hub/drop beacons and the RouteGuide sources `Courier` (drop, priority 50) and `CourierHub` (hub, priority 40). |
| Hub pads | Workspace.World.Jobs.CourierHubs | Three Neon Parts tagged `CourierHub` with `HubId` and `DisplayName`. Placed on the nearest road-graph node to each landmark. |
| Config | ReplicatedStorage.Config.Activities.Courier | Tunables below. |

Existing owners it uses without changing: ActivityService (busy state, begin/end/cancel, vehicle lookup, random road point, pushes), ActivityPayout (the only Cash/XP grant), ProgressionService (rank, only when MinRank > 1), FeatureFlags (`EnableCourier`), RoadRouting and the cached road graph, RouteGuide, the ActivityClient ctx UI helpers. No remotes, saved fields, HUD sources or other features change.

## Flow

1. **Find a hub.** Jobs panel → COURIER → **GO TO HUB**. `CourierGoToHub` returns the nearest hub `{HubId, DisplayName, Position}` to the player's car (or character). The client sets a hub route and a hub beacon.
2. **Offer.** When the local player drives their own car onto a streamed-in pad (flat distance ≤ HubRadius), the offer card opens with STANDARD / HOT / FRAGILE (15 s timeout). Leaving the pad closes it; it re-opens the next time the player drives on. The Jobs **START** button opens the same card when on a pad, otherwise routes to the nearest hub.
3. **Start** (`CourierStart {HubId, Variant}`). The server checks, in order: config `Enabled` and flag `EnableCourier` (default on); valid args and variant; known hub; no local run; rank ≥ MinRank; `GetDrivenVehicle` returns the player's car; the car root is on the pad (flat ≤ HubRadius, |ΔY| ≤ HubHeightTolerance); `IsBusy` is false. It then picks the drop with `RandomRoadPoint(hub, MinDistance, MaxDistance)`, measures the road route (RoadRouting.FindRoute, falling back to straight × RoadDistanceFactor, clamped to [straight, 4 × straight]), computes the time limit and chain, and calls `ActivityService.Begin` last. It pushes `Courier:Started {RunId, HubId, DropPosition, TimeLimit, Variant, Distance, Chain, ServerStartTime}`.
4. **Run** (server loop, 10 Hz): out of time → `Failed "Out of time"`. Every SegmentSeconds the car's flat displacement is checked against the run's speed limit × elapsed + SegmentToleranceStuds; a violation marks the run invalid. The speed limit is snapshotted at start from `RaceIntegrity.limitMph()` (race limit, at least 1.25× the highest vehicle cap), falling back to MaxPlausibleMph when RaceIntegrity is unavailable. Fragile: a speed drop of more than FragileImpactMph within ImpactWindowSeconds counts as an impact (ImpactCooldownSeconds between counts) and pushes `Courier:Impact {Impacts}`.
5. **Deliver:** car root within DeliverRadius (flat) of the drop, speed below DeliverMaxMph, player driving their own car. `CourierRules.Settle` rejects invalid runs and runs that cover the routed trip distance faster than the speed limit (`Failed "Delivery rejected: …"`, no pay). Otherwise the server ends the record `Complete`, then calls `ActivityPayout.Pay {Cash, Xp, Reason="JobPayout", CommandId="Courier:<runId>:<userId>", JobCeiling=true}` (one retry after 3 s with the same CommandId if it fails; after that, `Courier:Failed` with the payout message) and pushes `Courier:Completed {Cash, Xp, Stars, Chain, Capped, Impacts, Variant}` with the amounts actually granted. The client toasts the result and routes to the nearest hub for the next run.
6. **Cancel:** the core `Cancel` action (Jobs → CANCEL RUN), leaving the car beyond ExitGraceSeconds, despawn, race/garage entry, or leaving the game go through ActivityService → `OnCancel`, which clears the run and chain and pushes `Courier:Cancelled {Reason}`. No pay.

## Pay and grading (defaults)

- Cash = (BasePay + PayPerStud × road distance) × (1 + MaxTimeBonus × remaining/limit) × variant × chain.
- Variant: Standard ×1; Hot ×1.4; Fragile ×1.25 × max(0.4, 1 − 0.15 × impacts).
- Time limit = (road distance / AvgSpeedMph in studs/s + GraceSeconds) × (Hot 0.75), clamped to [MinTimeLimit, MaxTimeLimit], whole seconds.
- Stars: 3 when ≥ 50% of the time is left, 2 when ≥ 25%, otherwise 1.
- XP = XpBase + distance / XpPerStuds.
- Chain: a run started within ChainWindowSeconds of the last completed run gets the previous chain + ChainStep, up to ChainMax. Failure or cancellation resets it to ×1.0.
- The hourly job ceiling (Core.JobHourlyCashCeiling) is enforced by ActivityPayout (`JobCeiling=true`); `Capped` is shown in the toast.

## Config (ReplicatedStorage.Config.Activities.Courier)

Every value is read through `CourierRules.ReadConfig`, which falls back to the default when a value is missing or not finite, and clamps it to the range. The server snapshots config at run start.

| Attribute | Default | Range | Meaning |
|---|---|---|---|
| Enabled | true | bool | Master switch (foundation attribute) |
| MinRank | 1 | 1–100 | Rank needed (design says 5; 1 while prototyping) |
| HubRadius | 30 | 5–200 | Flat studs from pad centre that count as on the pad |
| HubHeightTolerance | 25 | 5–200 | Max vertical offset from the pad |
| MinDistance / MaxDistance | 600 / 2000 | 100–20000 | Drop distance from the hub |
| RoadDistanceFactor | 1.3 | 1–4 | Straight → road distance when routing fails |
| BasePay | 1500 | 0–1e6 | Base Cash |
| PayPerStud | 0.6 | 0–100 | Cash per road stud |
| MaxTimeBonus | 0.3 | 0–5 | Bonus fraction at full time remaining |
| HotPayMultiplier / HotTimeFactor | 1.4 / 0.75 | | Hot variant |
| FragilePayMultiplier | 1.25 | 1–10 | Fragile variant |
| FragileImpactPenalty / FragileFloor | 0.15 / 0.4 | 0–1 | Loss per impact, minimum kept |
| FragileImpactMph | 45 | 5–1000 | Speed drop that counts as an impact |
| ImpactWindowSeconds / ImpactCooldownSeconds | 0.2 / 0.75 | | Impact detection window, gap between counted impacts |
| AvgSpeedMph / GraceSeconds | 70 / 25 | | Timer model |
| MinTimeLimit / MaxTimeLimit | 30 / 300 | 5–3600 | Timer bounds (s) |
| DeliverRadius / DeliverMaxMph | 40 / 25 | | Delivery test |
| MaxPlausibleMph | 400 | 50–5000 | Fallback speed limit for minimum-time and teleport checks when RaceIntegrity.limitMph is unavailable |
| SegmentSeconds / SegmentToleranceStuds | 1 / 30 | | Teleport check window and slack |
| Star3Fraction / Star2Fraction | 0.5 / 0.25 | 0–1 | Star thresholds (time left / limit) |
| XpBase / XpPerStuds | 20 / 100 | | XP |
| ChainStep / ChainMax / ChainWindowSeconds | 0.1 / 1.5 / 90 | | Chain |
| TickHz | 10 | 1–60 | Server loop rate |

Server flag: `FeatureFlags.IsEnabled("EnableCourier", true)`. In Studio set `ServerStorage.Config` attribute `Flag_EnableCourier = false` to test the closed path.

## Hub pads

| HubId | DisplayName | Position (road node) | Landmark |
|---|---|---|---|
| Dealership | Dealership Depot | 598.9, 100.6, -1755.4 | Dealership (~731, -1747), 132 studs |
| Kanda | Kanda Garage Depot | 1548.9, 100.6, -1893.1 | Kanda garage drive-in (~1580, -1841), 61 studs |
| ShowroomLoop | Showroom Loop Depot | 1314.9, 100.6, -1321.7 | Showroom Loop start (~1380, -1229), 113 studs |

36 × 0.4 × 36 Neon, colour (43, 225, 218), transparency 0.4, anchored, CanCollide/CanQuery/CanTouch off, tag `CourierHub`.

## Preserved

Races, garages, the queue and other activities are protected by ActivityService busy checks. Cash moves only through ActivityPayout.Pay. No saved-data or schema change. The RouteGuide player destination (priority 10) is restored automatically when the Courier sources clear.

## Tests

**Pure** (Studio Edit, serve `scripts/` on 127.0.0.1:8767): run [tests.lua](tests.lua) and expect `failures = 0`. It covers config bounds, variants, hubs, trip distance, time limits, pay for each variant, fragile floor, chain, stars, XP, delivery, speed-limit selection, plausibility on routed distance, teleport segments, impact detection and settlement.

**Play checklist** (Studio Play, spawn a car):

1. Jobs → COURIER → GO TO HUB: a pink route and a cyan beacon lead to the nearest pad.
2. Drive onto the pad: the route clears and the offer card opens. Drive off: it closes. Drive on again: it re-opens.
3. On foot, or in someone else's car, on the pad: START is refused with "Drive your own car onto the hub pad."
4. STANDARD: the strip shows `COURIER  m:ss · x.x MI`, there is a drop beacon, and the route points to the drop. Stop near the drop: the toast shows `DELIVERED $… +… XP 2/3 STARS`, and Cash and the XP bar rise once. The server log shows one JobPayout grant with CommandId `Courier:<runId>:<userId>`.
5. Start another run within 90 s: the strip shows ×1.1 and the payout reflects it. Let a run time out: `DELIVERY FAILED: Out of time`, and the next run is back to ×1.0.
6. HOT: the timer is shorter (never below 30 s) and pay is about ×1.4. FRAGILE: hit a wall hard; the `FRAGILE CARGO HIT` toast appears, the strip shows HITS n, and pay drops FragileImpactPenalty (15%) per hit (floor 40%); the offer card text reads the penalty from config.
7. Jobs → CANCEL RUN, and separately leave the car for more than 10 s: `DELIVERY CANCELLED`, the strip, route and beacon clear, no pay.
8. Join a race queue or garage during a run: it is cancelled. Starting a courier run while queued or in a garage is refused.
9. Set Courier `Enabled = false`: the Jobs buttons disable and the actions return "Courier jobs are closed right now."
10. Console: no errors from CourierJob or CourierClientView. Two players can run at once, each with their own strip.
