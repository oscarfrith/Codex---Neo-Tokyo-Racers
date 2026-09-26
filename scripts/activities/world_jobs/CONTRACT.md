# World jobs: acceptance contract

Feature: GTA-style taxi fares and parcels in the world. It implements the "World jobs" section of [map-markers-contract](../../../docs/architecture/map-markers-contract.md) and builds on [activities-contract](../../../docs/architecture/activities-contract.md). Lane: **High-Risk** (Cash/XP, remote action, retirement of old actions and world pads). Installer spec: [spec.json](spec.json), whose before-capture is `roblox/captures/activities-duels-after/capture.json`.

## Goal

There are always 6 taxi fares and 5 parcels dotted around the Core District, each on the pavement beside a road and shown on the map with an icon.

1. The player drives up slowly. A prompt appears ("Give ride" or "Pick up parcel", key E).
2. The fare boards, or the parcel is loaded.
3. The player follows the pink route to a far kerb drop, usually 1800–4500 road studs away, and stops there.
4. Pay is base + distance. Driving faster than the reference pace multiplies it (up to ×1.5, down to ×0.6). Each crash cuts it (−12% taxi / −15% courier, with a floor).
5. Nothing auto-starts afterwards. The player picks the next job off the map, which by then has fresh offers in new places.

## Owners

| Piece | Location | Owns |
|---|---|---|
| JobRules (pure, shared) | ReplicatedStorage.Modules.Game.Activities.JobRules (new) | All maths and decisions: board config bounds, polyline/kerb geometry, kerb detection from probe samples, ground checks, spacing/freshness, sectors, Dijkstra road distances, destination scoring, expiry, accept/arrive tests, crash detection, anti-teleport step cap, plausibility, pay breakdown, projected pay, formatting. The client uses it only for the strip estimate. |
| JobBoard (server) | ServerStorage.Modules.Game.Activities.JobBoard (new) | Offers and their runtime folder `ReplicatedStorage.ActivityState.JobOffers`, spot/destination generation and world verification, TTL/relocation/replenishment, the `JobAccept` action (it registers the pseudo-kind `Jobs`, which is never begun), the trip engine (driven distance, crashes, arrival, settlement) and the single payout per trip. |
| TaxiRules / CourierRules (pure) | ServerStorage.Modules.Game.Activities | Kind tunables (`ReadConfig`), taxi boarding helpers, parcel names. |
| TaxiJob (server) | ServerStorage.Modules.Game.Activities | Registers kind `Taxi` and the Taxi provider. Owns the fare NPC rigs: it spawns them only while a player is within StreamRadius, runs the hail animation, walks the fare to the car, seats it with `PassengerService.SeatNpc`, and at the drop calls `UnseatNpc` and walks the fare to the pavement before despawning it. A fare leaving the seat mid-trip fails the trip. |
| CourierJob (server) | ServerStorage.Modules.Game.Activities | Registers kind `Courier` and the Courier provider (parcel label, instant load). |
| JobClient (client, shared) | ReplicatedStorage.Modules.Game.Activities.JobClient (new) | Presentation and intents only. It mirrors offers into MapMarkers and builds local prompt anchors, beacons and props for streamed-in offers. It sends `JobAccept` and owns the trip strip, the route sources `Job` (priority 50) and `JobOffer` (priority 45), the `JobDestination` marker and beacon, the completion toast and the JOBS entries. |
| TaxiClientView / CourierClientView | ReplicatedStorage.Modules.Game.Activities | Register their kind with JobClient and forward `Taxi:*` / `Courier:*` events. The courier view builds the client-only parcel crate. |

Existing owners used without changes:

- ActivityService: busy state, Begin/End/Cancel, vehicles, config, road graph, pushes.
- ActivityPayout: the only Cash/XP grant.
- ProgressionService: rank, used only when MinRank > 1.
- PassengerService: SeatNpc, UnseatNpc, GetOccupant, OccupantChanged.
- FeatureFlags: `EnableSkyTaxi`, `EnableCourier`.
- RaceIntegrity.limitMph, which is optional.
- RoadRouting (Snap) and RouteGuide.
- MapMarkers, owned by Agent F: required lazily and pcall-guarded. Nothing breaks if it is missing, and markers sync once it appears.

Removed:

- Courier: variants (Standard/Hot/Fragile), hubs, chains and the timer.
- Taxi: on-duty mode, NPC chaining and the player "CALL A TAXI" requests. Requests were dropped because they did not fit cleanly: they need a second offer type fed by player state. They can return later as a `TaxiFare` offer published by JobBoard.

## Flows

### Offers (JobBoard, 1 Hz board tick, generation on its own thread)

Offers are replenished whenever a kind is below its target (TaxiOffers / CourierOffers). One offer is generated at a time, yielding between candidates. After a round that finds nothing, generation backs off for 10 s.

**Pickup spot**

1. **Pick candidates.** Candidate points are sampled on road-graph **edges**, weighted by usable length. The IntersectionClearance of 90 studs is kept from both nodes, so spots never sit in a junction. Each candidate gets a random side and uses a road direction smoothed over ±25 studs. The edges must lie inside the Core District bounds.
2. **Pre-filter.** A quick check runs on the nominal kerb point (centre + KerbOffset 48):
   - it must be inside the district;
   - it must be at least MinOfferSpacing (350) from other offers;
   - it must be at least MinPlayerSpacing (250) from players;
   - it must not be within FreshnessRadius (300) of the last FreshnessMemory (16) pickup/drop spots.
3. **Rank.** Up to 8 candidates are ranked by sector crowding (a 3×4 grid, fewer active offers is better) plus jitter.
4. **World verification (server raycasts).** Runtime (cars, NPCs) and characters are excluded.
   - **Road surface.** A downward ray from RoadY + ProbeHeight finds the road surface at the centre and records its height, part and material.
   - **Kerb march.** Rays march outward from 26 to 76 studs in 4-stud steps. A sample counts as road when it is within KerbRise (0.3) of the road height and on the same part, or on a part with the same material and name. The kerb edge is the first non-road hit that rises or is followed by another non-road hit, so thin lane markings are skipped. A void rejects the candidate.
   - **Spot.** The spot is PavementMargin (7) past the kerb edge.
   - **Ground.** The ground there must be hit, not water, solid, level (normal Y ≥ 0.7) and within GroundTolerance (12) of the road height.
   - **Overhead.** Nothing large may be overhead within ClearHeight (40). A roof, overpass or canopy of 30 studs or more fails the check. Thin lamp arms and signs are ignored.
   - **Standing box.** A 5×6.5×5 box standing on the spot must hold no collidable visible part (walls, bins, posts).
   - **Other roads.** The spot must be nearer its own road than any other (`RoadRouting.Snap` distance ≥ 0.8 × offset).
5. **Relax passes.**
   - Pass 1 shrinks the spacings to ×0.6.
   - Pass 2 keeps only offer spacing ×0.5 and allows the KerbOffset fallback when no kerb is detected.

**Destination**

1. **Distances.** One Dijkstra run from the pickup's edge position gives the road distance to every node, so each candidate's distance is exact and costs O(1).
2. **Candidates.** DestinationCandidates (40) edge points are scored with `JobRules.ScoreDestination`:
   - the length must be inside the band [TripMinStuds 1800, TripMaxStuds 4500];
   - it is scored by closeness to a random target length for this offer, which varies trip lengths;
   - a bearing within 40° of one of the recent 10 trips is penalised;
   - a drop within FreshnessRadius of a recent drop is penalised;
   - a drop in a sector with many recent drops is penalised;
   - a near-duplicate of a recent trip (both ends within 500 studs) is rejected.
3. **Choice.** The top 6 candidates are kerb-verified in turn, and the first one that passes is the drop. If the band can't be met, a second pass widens it to ×0.75 / ×1.3.

**Publish.** Each offer becomes a `Configuration` named by the offer id in `ReplicatedStorage.ActivityState.JobOffers`. Its attributes are:

- `Kind`
- `Position` (the pickup on the pavement)
- `Facing` (towards the road)
- `Distance` (road studs)
- `Estimate` (par pay)
- `ExpiresAt` (server time)
- `Label` (courier parcel name)

The drop stays server-side.

**TTL.** Each offer lives a random 360–600 s. When it expires with a player within 250 studs, it is extended by 45 s, at most twice. Otherwise it is removed and replaced somewhere new. Offers above target, or of a disabled kind, are removed.

**Taxi rigs.** A rig is built only while any player is within StreamRadius (600). It is removed beyond 600 + 150. The rig is `Workspace.World.Runtime.ActivityNpcs.TaxiFare_<offerId>` (R15, random palette, root anchored, limbs massless and non-colliding, ModelStreamingMode Atomic). It faces the road and plays the hail animation every 4–7 s. The animation is `Taxi.HailAnimationId`; set it to "" to disable.

### Client offer display (JobClient, 5 Hz poll)

- **Map markers.** Each offer becomes marker `JobOffer_<id>` with Kind "Job", Icon `TaxiFare` or `CourierPickup`, Pulse, Priority 20 and a label like "TAXI FARE · 0.6 MI TRIP · ~$620". Markers are hidden during a job.
- **Streamed-in offers.** Offers within 600 studs get a local invisible anchor in `Workspace.ClientJobProps`, a beacon and, for couriers, a cardboard parcel stack with a neon band. The anchor carries a ProximityPrompt:
  - E, hold 0, MaxActivationDistance PromptDistance (45), RequiresLineOfSight false;
  - enabled only while the local player is in the DriverSeat of their own car, below 0.8 × AcceptMaxMph (about 14 mph), not on a job and not mid-accept.
- **JOBS panel.** The panel shows "NEAREST PARCEL" and "NEAREST TAXI FARE": the distance away, the trip length and the estimate. **SET ROUTE** routes (source `JobOffer`) to the nearest offer of that kind. If that offer disappears, the route clears and a toast explains. During a job the panel shows **CANCEL JOB** instead.

### Accept (`JobAccept {OfferId}`, server)

The server checks these in order:

1. Jobs `Enabled`.
2. The offer id is valid and the offer is live.
3. The kind is enabled (config `Enabled` and the flag).
4. Rank ≥ MinRank.
5. The player has no trip and `IsBusy` is false.
6. The player is driving their own car (`GetDrivenVehicle`).
7. The car root is within AcceptRadius (60) flat and AcceptHeight (30) of the pickup.
8. Horizontal speed ≤ AcceptMaxMph (18).
9. Provider check. Taxi: a PassengerSeat exists and is free.
10. The offer is re-checked, then `ActivityService.Begin(kind)` runs.

After that:

- The offer is removed (it disappears for everyone) and replenishment is requested.
- The server pushes `<Kind>:Started {TripId, OfferId, Pickup, Destination, Distance, ReferenceSeconds, Estimate, Pay (tunables snapshot), Boarding, Label}`.
- **Taxi.** The rig stops hailing, unanchors, walks to the kerb side of the passenger seat (≤ BoardSeconds 2.5 s or within 8 studs) and is seated with SeatNpc. If seating fails, the result is `Taxi:Failed "Your fare couldn't get in."`.
- **Courier.** The parcel loads at once.
- `JobBoard.StartDriving` starts the pay clock and driven-distance counting and pushes `<Kind>:Driving {ServerStartTime}`.

The client clears the offer route and hides offer markers and props. It sets the `Job` route (DROP-OFF / DELIVERY), the `JobDestination` marker (Icon `TaxiDrop` / `CourierDrop`, Kind "Activity", EdgeClamp) and a pink beacon.

### Trip (server, TripTickHz 10)

- **Driven distance.** It is accumulated with `CapStep`, per tick min(moved, limit × dt + 2). The limit is `RaceIntegrity.limitMph()` or LimitFallbackMph 400. A teleport adds at most one capped step.
- **Crash.** A crash is a horizontal-speed drop greater than CrashImpactMph (35) within ImpactWindowSeconds, with ImpactCooldownSeconds between counts. It pushes `<Kind>:Crash {Crashes, DamageFactor}` and the client toasts "CRASH! PAY NOW x0.88".
- **Abandon.** After ReferenceSeconds × 4 + 120 s the trip fails ("Your fare gave up and got out." / "The delivery took too long.").
- **Arrive.** The car root must be within DropRadius (60) flat of the kerb drop, below DropMaxMph (15), with the player in their own DriverSeat.
- **Settle.** `JobRules.Settle` rejects a trip when:
  - driven < DrivenMinFraction (0.6) × max(road, straight), giving `Failed "Trip rejected: route not driven"`;
  - or elapsed < road ÷ limit, giving `"Trip rejected: implausible time"`.

  Otherwise the trip closes, `End(Complete)` runs, and then `OnEnd`: the taxi fare is unseated, stands on the kerb side and walks to the drop spot on the pavement before despawning after 5 s. Then payout.
- **Payout.** `ActivityPayout.Pay {Cash, Xp, Reason = TaxiFare | JobPayout, CommandId = "<Kind>:<TripId>:<UserId>", JobCeiling = true}`. If it fails, it retries once after 3 s with the same CommandId. The server then pushes `<Kind>:Completed {Cash, Xp, Capped, Total, Base, SpeedBonus, SpeedMultiplier, CrashPenalty, Crashes, Seconds, Distance}`. The client toast reads, for example, "FARE COMPLETE +$662 · BASE $530 · SPEED +$130 · +50 XP", adding "2 CRASHES -$…" and "HOURLY JOB CAP REACHED" when they apply.
- **No auto-next.** Offer markers return and the player chooses the next job.
- **Cancel.** These go through ActivityService → `OnCancel` → `JobBoard.HandleCancel`, which pushes `<Kind>:Cancelled {Reason}` with no pay:
  - core `Cancel` (JOBS → CANCEL JOB, or the strip's X);
  - exit > ExitGraceSeconds, despawn or death;
  - entering a race, garage or queue;
  - leaving the game.

  The taxi fare is unseated and walks off. A fare knocked out of the seat mid-trip gives `Taxi:Failed "Your fare got out."`.

**Strip.** For example, `TAXI  0:23  ·  0.4 MI  ·  $612  ·  1 CRASH`. The estimate is `JobRules.ProjectedPay`: elapsed plus the remaining straight distance × RoadFactor at reference pace, using the server's pay snapshot. The strip turns HighSpeed pink after a crash. While boarding it reads "TAXI · YOUR FARE IS GETTING IN...".

## Economy (defaults)

**Pay formula**

- Base = TripBasePay + TripPayPerStud × road studs.
  - Taxi: 200 + 0.11/stud.
  - Courier: 150 + 0.10/stud.
- ReferenceSeconds = road ÷ (ReferenceMph 85 → 136 studs/s) + TripGraceSeconds (taxi 10, courier 8).
- Speed multiplier = clamp(1 + 0.75 × (reference ÷ elapsed − 1), 0.6, 1.5).
- Damage factor = max(CrashFloor, 1 − CrashPenalty × crashes).
  - Taxi: 0.12 per crash, floor 0.4.
  - Courier: 0.15 per crash, floor 0.35.
- XP (not reduced by crashes):
  - Taxi: 25 + road ÷ 120.
  - Courier: 20 + road ÷ 150.

**Example: a 3000-stud taxi trip**

| Result | Pay |
|---|---|
| Par | $530 |
| ×1.5 (fast) | $795 |
| ×0.6 (slow) | $318 |
| 2 crashes at par | $403 |

**Hourly.** A focused cycle is about 60 s: roughly 700 studs to the nearest offer, then pickup, then a 3150-stud average trip at about 1.25–1.35× pace, which comes to about 60 jobs an hour.

| Kind | Per hour |
|---|---|
| Taxi | ≈ $41k |
| Courier | ≈ $35k |

Casual play (about 40 jobs an hour at par) comes to about $20–25k an hour. `Core.JobHourlyCashCeiling` (40,000) is enforced by ActivityPayout and shown as "HOURLY JOB CAP REACHED". tests.lua asserts the focused figures are within $30–45k an hour.

## Config

**`ReplicatedStorage.Config.Activities.Jobs`** is a new folder created by the spec. Every value is bounded by `JobRules.ReadBoardConfig`.

| Attribute | Default | Meaning |
|---|---|---|
| Enabled | true | Board master switch |
| TaxiOffers / CourierOffers | 6 / 5 | Live offers per kind |
| KerbOffset | 48 | Fallback centre → spot distance when no kerb is detected (relax pass 2 only) |
| KerbSearchMin / Max / Step | 26 / 76 / 4 | Kerb march from the road centre |
| KerbRise | 0.3 | Height change that leaves the road surface |
| PavementMargin | 7 | Studs past the kerb edge |
| IntersectionClearance | 90 | Distance kept from graph nodes |
| MinOfferSpacing / MinPlayerSpacing | 350 / 250 | Spacing |
| FreshnessRadius / FreshnessMemory | 300 / 16 | Do not reuse recent spots |
| OfferTtlMin / OfferTtlMax | 360 / 600 | Offer lifetime (s) |
| ExtendNearStuds / ExtendSeconds / MaxExtensions | 250 / 45 / 2 | Keep an offer a player is closing in on |
| TripMinStuds / TripMaxStuds | 1800 / 4500 | Road-distance band |
| DestinationCandidates | 40 | Candidates per offer |
| RecentTripMemory | 10 | Trips remembered for variety |
| DuplicateTripStuds | 500 | Near-duplicate threshold |
| DirectionSpreadDegrees | 40 | Bearing penalty window |
| SectorColumns / SectorRows | 3 / 4 | District grid for spreading offers and drops |
| SpotTries | 40 | Pickup samples per pass |
| StreamRadius / StreamHysteresis | 600 / 150 | NPC rigs and client props |
| PromptDistance | 45 | Prompt MaxActivationDistance |
| AcceptRadius / AcceptHeight / AcceptMaxMph | 60 / 30 / 18 | Server accept checks (the client prompt uses 0.8 × AcceptMaxMph) |
| GroundTolerance / ClearHeight / ProbeHeight / RoadY | 12 / 40 / 60 / 101 | World probes |
| TripTickHz | 10 | Trip loop rate |
| AbandonFactor / AbandonGraceSeconds | 4 / 120 | Trip give-up time |
| RoadFactor | 1.25 | Client estimate straight → road |

**`Config.Activities.Taxi`** new attributes:

- TripBasePay 200, TripPayPerStud 0.11, TripXpBase 25, TripXpPerStuds 120
- ReferenceMph 85, TripGraceSeconds 10
- SpeedSensitivity 0.75, SpeedMultiplierMin 0.6, SpeedMultiplierMax 1.5
- CrashPenalty 0.12, CrashFloor 0.4, CrashImpactMph 35
- DropRadius 60, DropMaxMph 15
- DrivenMinFraction 0.6, LimitFallbackMph 400
- BoardSeconds 2.5, BoardWalkStuds 8, ExitWalkSeconds 5
- HailAnimationId "rbxassetid://507770239" (the Roblox R15 wave; "" disables it)

Reused: `Enabled`, `MinRank`, `ImpactWindowSeconds` (0.2) and `ImpactCooldownSeconds` (1).

**`Config.Activities.Courier`** new attributes:

- TripBasePay 150, TripPayPerStud 0.1, TripXpBase 20, TripXpPerStuds 150
- ReferenceMph 85, TripGraceSeconds 8
- SpeedSensitivity 0.75, SpeedMultiplierMin 0.6, SpeedMultiplierMax 1.5
- CrashPenalty 0.15, CrashFloor 0.35, CrashImpactMph 35
- DropRadius 60, DropMaxMph 15
- DrivenMinFraction 0.6, LimitFallbackMph 400

Reused: `Enabled`, `MinRank`, `ImpactWindowSeconds` (0.2) and `ImpactCooldownSeconds` (0.75).

**Now unused.** These attributes are left in place and can be deleted in a later cleanup.

- Courier:
  - AvgSpeedMph, BasePay, PayPerStud, MaxTimeBonus
  - ChainMax, ChainStep, ChainWindowSeconds
  - DeliverMaxMph, DeliverRadius
  - FragileFloor, FragileImpactMph, FragileImpactPenalty, FragilePayMultiplier, HotPayMultiplier, HotTimeFactor
  - GraceSeconds, MinTimeLimit, MaxTimeLimit
  - HubHeightTolerance, HubRadius
  - MinDistance, MaxDistance, RoadDistanceFactor
  - MaxPlausibleMph, SegmentSeconds, SegmentToleranceStuds
  - Star2Fraction, Star3Fraction
  - TickHz, XpBase, XpPerStuds
- Taxi:
  - AcceptWindowSeconds, ArriveRadius, StopMph, PickupRadius
  - DestMinStuds, DestMaxStuds, NpcMinStuds, NpcMaxStuds
  - EstimateBaseSeconds, EstimateStudsPerSecond
  - FallbackLimitMph, MinDrivenFraction
  - FareBase, FarePerStud, XpBase, XpPerStud
  - FareTimeoutSeconds, NextFareSeconds
  - ImpactMph, StarLossPerImpact, SlowFactor, VerySlowFactor
  - PairCooldownSeconds, RequestCooldownSeconds, RequestTimeoutSeconds
  - PlayerFareBase, PlayerFareMaxStuds, PlayerFarePerStud, PlayerMinRideStuds

Flags: `EnableSkyTaxi` (Taxi) and `EnableCourier` (Courier), both defaulting on.

## Integration steps (integrator; outside this folder)

1. **Apply the spec.** Run [spec.json](spec.json) through `scripts/feature_installer.py` with before-capture `roblox/captures/activities-duels-after/capture.json`. It has 46 operations:
   - 3 new modules: JobRules, JobClient, JobBoard;
   - 6 source replacements;
   - the Jobs folder;
   - 36 new attributes.
2. **ActivityService `ACTIONS`.**
   - Add `JobAccept = true`.
   - Remove `CourierGoToHub`, `CourierStart`, `TaxiSetDuty`, `TaxiRequest`, `TaxiCancelRequest` and `TaxiAcceptRequest`.

   Keep `GetState`, `Cancel`, `SetPassengerAccess`, `Ride`, `LeaveRide` and the Duel actions. Without `JobAccept`, `JobBoard.start` asserts in `Register`.
3. **ServerBase entries.**
   - Add `{name = "JobBoard", path = "ServerStorage.Modules.Game.Activities.JobBoard", dependencies = {"ActivityService", "ProgressionService"}}`.
   - Add `JobBoard` to the dependencies of `CourierJob` and `TaxiJob`. Both register with it; RegisterProvider works before or after JobBoard.start.
4. **Delete the hub pads.** Delete `Workspace.World.Jobs`, which holds the courier hub pads `CourierHubs/Hub_Dealership`, `Hub_Kanda` and `Hub_ShowroomLoop`, tagged `CourierHub`. feature_installer has no delete op, so do this with a guarded Command Bar step that checks the path, class and tag and records the removal in the after-capture. Nothing reads the `CourierHub` tag any more.
5. **MapMarkers dependency.** Install `ReplicatedStorage.Modules.Game.UI.MapMarkers` (Agent F) and fill the `Config.UI.MapIcons` keys `TaxiFare`, `CourierPickup`, `TaxiDrop` and `CourierDrop` (Agent M art). JobClient works without either; markers appear once the module exists.
6. **Update docs.** `docs/architecture/activities-contract.md` still lists the old actions and hub pads. `scripts/activities/courier/CONTRACT.md` and `scripts/activities/passengers_taxi/CONTRACT.md` describe the retired flows.

## Preserved

- Races, garages and the queue are protected by ActivityService busy checks.
- Cash moves only through ActivityPayout.Pay, with one CommandId per trip.
- There is no saved-data or schema change and no new remote. `JobAccept` is an action on the existing ActivityInvoke.
- PassengerService player rides (Ride/LeaveRide) are unchanged.
- The RouteGuide player waypoint (priority 10) returns when the job sources clear.

## Tests

**Pure tests.** In Studio Edit, serve `scripts/` on 127.0.0.1:8767 and run [tests.lua](tests.lua); expect `failures = 0`. The tests load `route_guide/RoadRouting.lua` for a synthetic 3×3 grid graph. They cover:

- config bounds;
- polyline/tangent/kerb geometry;
- edge sampling;
- kerb detection (lane-marking skip, void, fallback);
- ground checks;
- spacing, freshness and sectors;
- Dijkstra against RoadRouting.FindRoute;
- destination scoring (band, target length, direction variety, duplicate rejection, recent-drop penalty);
- expiry and extension;
- accept, arrive, crash, cap-step and plausibility;
- the pay breakdown (par, fast cap, slow floor, crashes, floor);
- projected pay, snapshot safety, the hourly target band, formatting and ids.

**Play checklist.** In Studio Play, spawn a car and use Output with the server view.

1. Within a few seconds, `ReplicatedStorage.ActivityState.JobOffers` holds 6 Taxi and 5 Courier Configurations with Position, Facing, Distance (1800–4500), Estimate and ExpiresAt. Output has no `[JobBoard]` warnings. If there are "no valid spot" warnings, inspect the kerb probe; see Risks.
2. The map shows pulsing TaxiFare and CourierPickup icons spread over the district.
3. Drive to an offer. Within about 600 studs a beacon appears. A taxi NPC stands on the pavement facing the road and waves; a parcel stack stands on the pavement. The spot is not in the road, not in a building and not under an overpass.
4. Approach at speed and no prompt shows. Slow below about 14 mph within about 45 studs and the prompt appears ("Give ride" / "Pick up parcel", E). On foot, no prompt shows.
5. Press E:
   - the offer vanishes from the map for everyone;
   - a taxi fare walks to the car and gets in;
   - the strip shows time, miles, a live $ estimate and crashes;
   - the pink route and the DROP-OFF / DELIVERY marker and beacon appear.
6. Hit a wall hard. "CRASH! PAY NOW x0.88" appears, the strip shows 1 CRASH and the estimate drops.
7. Stop at the drop within about 60 studs, below 15 mph:
   - the fare gets out on the kerb side and walks onto the pavement, then despawns;
   - the toast shows the pay breakdown;
   - Cash and XP rise once, and the server log shows one grant with CommandId `<Kind>:<TripId>:<UserId>`;
   - no new job starts, and fresh offers are visible at new places.
8. Compare a fast and a slow run of similar length. The fast one shows SPEED +$…, the slow one SPEED -$….
9. Cancel paths:
   - JOBS → CANCEL JOB;
   - leave the car for more than 10 s;
   - enter a garage or race queue.

   Each gives `… CANCELLED`, clears the strip, route, marker and beacon, and pays nothing. The taxi fare leaves the car.
10. Anti-teleport: accept, then move the car to the drop in one step (Command Bar). The result is "Trip rejected: route not driven", with no Cash.
11. JOBS panel: "NEAREST TAXI FARE" / "NEAREST PARCEL" show the distance, trip and estimate. SET ROUTE routes to the nearest offer. If that offer is taken or expires, the route clears with a toast.
12. Set `Taxi.Enabled = false`: the taxi offers disappear, and the prompts and SET ROUTE disable. Set `Jobs.Enabled = false`: the board empties.
13. Two players: each has their own trip. An offer accepted by one disappears for the other ("That job was just taken." if both press together).
14. Leave an offer alone for more than 10 min: it relocates. Stand near an expiring offer: it survives up to +90 s.

## Risks

- **World probes are unverified in this place.** The kerb march assumes road surfaces differ from pavements by height, part or (material + name). If roads and pavements share one flat part and material, no kerb is detected. Only relax pass 2 then places spots at KerbOffset 48, which may be in the lane on 100-stud-wide roads. The same holds if RoadY 101 / ProbeHeight 60 do not bracket the road height. Tune `KerbOffset`, `KerbSearchMax`, `RoadY` or `KerbRise` with live evidence. The integrator should inspect several spots in Play.
- **Graph structure.** RoadGraphData and RoadRouting may change (Agent R). JobBoard uses `graph.Edges[i].{A, B, Length, Points, Cumulative}`, `graph.Adjacent` and `RoadRouting.Snap`. It skips edges without Points/Cumulative, but a structural change would stop offer generation. There is no crash, only a warning.
- **Prompt reach.** The prompt is measured from the character; the accept check is from the car root. A driver in the far lane of a wide road must pull over.
- **NPC rigs.** `CreateHumanoidModelFromDescription` yields and is called at most once per offer entering range. The hail animation id must be loadable; failure is silent.
- **Cadence.** Economy numbers assume the cadence above and are unverified in play. `JobHourlyCashCeiling` caps any excess.
