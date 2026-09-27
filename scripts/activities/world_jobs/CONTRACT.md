# World jobs: acceptance contract

Feature: GTA-style taxi fares and parcels in the world. It implements the "World jobs" section of [map-markers-contract](../../../docs/architecture/map-markers-contract.md) and builds on [activities-contract](../../../docs/architecture/activities-contract.md). Lane: **High-Risk** (Cash/XP, remote action, retirement of old actions and world pads). The first install (spec in git history, commit 9175015, before-capture `roblox/captures/activities-duels-after/capture.json`) is live. [spec.json](spec.json) now holds the **whole-map refinement (2026-09-27)**, a delta whose before-capture is `roblox/captures/refine2-before/capture.json`: offers and drops over the whole blockout, trips about 3× longer, replacements that relocate away from the taken job, no offers on map places, roadside spots where there is no pavement, and no JOBS panel entries.

## Goal

There are always 8 taxi fares and 6 parcels spread over the whole blockout (3–5 of them in the city), each beside a road — on the pavement where there is one, on flat ground just off the road where there is not — and shown on the map with an icon that never sits on a map place (garage, dealership, race start and so on).

1. The player drives up slowly. A prompt appears ("Give ride" or "Pick up parcel", key E).
2. The fare boards, or the parcel is loaded. The replacement offer appears in a different part of the map.
3. The player follows the pink route to a far drop, usually 5400–13500 road studs away, and stops there.
4. Pay is base + distance. Driving faster than the reference pace multiplies it (up to ×1.5, down to ×0.6). Each crash cuts it (−12% taxi / −15% courier, with a floor).
5. Nothing auto-starts afterwards. The player picks the next job off the map, which by then has fresh offers in new places.

## Owners

| Piece | Location | Owns |
|---|---|---|
| JobRules (pure, shared) | ReplicatedStorage.Modules.Game.Activities.JobRules (new) | All maths and decisions: board config bounds, polyline/kerb geometry, kerb detection from probe samples, pavement and roadside ground checks, spacing/freshness/map-place exclusion/relocation avoidance, zones (grid + city), zone edge tables, zone ranking and heat, Dijkstra road distances, destination scoring, expiry, accept/arrive tests, crash detection, anti-teleport step cap, plausibility, pay breakdown, projected pay, formatting. The client uses it only for the strip estimate. |
| JobBoard (server) | ServerStorage.Modules.Game.Activities.JobBoard (new) | Offers and their runtime folder `ReplicatedStorage.ActivityState.JobOffers`, spot/destination generation and world verification (including the runtime list of map places to keep clear), TTL/relocation/replenishment, the `JobAccept` action (it registers the pseudo-kind `Jobs`, which is never begun), the trip engine (driven distance, crashes, arrival, settlement) and the single payout per trip. |
| TaxiRules / CourierRules (pure) | ServerStorage.Modules.Game.Activities | Kind tunables (`ReadConfig`), taxi boarding helpers, parcel names. |
| TaxiJob (server) | ServerStorage.Modules.Game.Activities | Registers kind `Taxi` and the Taxi provider. Owns the fare NPC rigs: it spawns them only while a player is within StreamRadius, runs the hail animation, walks the fare to the car, seats it with `PassengerService.SeatNpc`, and at the drop calls `UnseatNpc` and walks the fare to the pavement before despawning it. A fare leaving the seat mid-trip fails the trip. |
| CourierJob (server) | ServerStorage.Modules.Game.Activities | Registers kind `Courier` and the Courier provider (parcel label, instant load). |
| JobClient (client, shared) | ReplicatedStorage.Modules.Game.Activities.JobClient (new) | Presentation and intents only. It mirrors offers into MapMarkers and builds local prompt anchors, beacons and props for streamed-in offers. It sends `JobAccept` and owns the trip strip text, the route source `Job` (priority 50), the `JobDestination` marker and beacon and the completion toast. It adds no JOBS panel entries (the panel is retired; ActivityClient keeps `ctx.Jobs` as no-ops). |
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

**Area and zones**

- The job area is `Jobs.BoundsMinX/MaxX/MinZ/MaxZ`: the playable blockout roads (X −5192..4310, Z −7161..10857) inset by 150. The road graph extends far beyond the blockout (coastline strokes in the map art), so every pickup and drop is clipped to the area.
- The area is cut into zones: a SectorColumns × SectorRows grid (4 × 7, cells about 2300 × 2530) and, inside the city (`Config.Activities.Core` District bounds), a CitySectorColumns × CitySectorRows grid (2 × 2) of its own. Without its own zones the city (about 20 % of the road length) would get only one or two offers.
- `JobRules.BuildZoneTables` cuts every usable edge stretch (IntersectionClearance kept from both nodes) into runs that lie in one zone, once per config/graph change. It gives one edge table per zone, a global table for drops, and the road length per zone.

**Pickup spot**

1. **Rank zones** (`JobRules.RankZones`, each relax pass). Each zone's score is −2 × its live offers − its heat + jitter.
   - Heat is +1 when an offer is published in the zone and +1 for the pickup and drop zones of a taken job, halving every ZoneHeatHalfLife (600 s). Recently used zones therefore rank last.
   - Zones with less than MinZoneRoad (1500) usable road are skipped.
   - City quota: city zones get +3 while fewer than CityMinOffers (3) offers are in the city, and are skipped once CityMaxOffers (5) are there (lifted on relax pass 2).
   - Relocation: zones holding an avoid point (below) are skipped on pass 0 and penalised on pass 1.
   The best ZonesPerPass (3) zones are tried in order.
2. **Pick candidates in the zone.** Up to SpotTries (80) samples on the zone's edges, weighted by length, each with a random side and a road direction smoothed over ±25 studs.
3. **Pre-filter** (`JobRules.SpotAllowed`) on the nominal kerb point (centre + KerbOffset 48):
   - inside the area;
   - at least PoiExclusionStuds (350) from every map place: `Config.UI.MapPois` Positions, the children of `Workspace.World.OwnedGarageExteriors` and every `Workspace.World.RaceRoutes.*.StartZones` child. The list is collected at runtime every PoiRefreshSeconds (30); missing folders are skipped. This rule is never relaxed;
   - at least MinOfferSpacing (700) from other offers, so icons stay apart on the full map;
   - at least MinPlayerSpacing (250) from players;
   - not within FreshnessRadius (500) of the last FreshnessMemory (24) pickup/drop spots;
   - at least RelocateAvoidStuds (2000) from the avoid points.
4. **Spread.** Up to 8 survivors are ranked by blue-noise spread: distance to the nearest other offer (capped at 4 × MinOfferSpacing), plus jitter. The farthest is verified first.
5. **World verification (server raycasts).** Runtime (cars, NPCs) and characters are excluded.
   - **Road surface.** A downward ray from RoadY + ProbeHeight finds the road surface at the centre and records its height, part and material.
   - **Kerb march.** Rays march outward from 26 to 76 studs in 4-stud steps. A sample counts as road when it is within KerbRise (0.3) of the road height and on the same part, on a part with the same material and name, or (when the road parts are known) on another road part. The kerb edge is the first non-road hit that rises or is followed by another non-road hit, so thin lane markings are skipped. A void rejects the candidate.
   - **Pavement spot.** The spot is PavementMargin (7) past the kerb edge (margins −5..+8 are tried). The ground there must be hit, not water, solid, level (normal Y ≥ 0.7), within GroundTolerance (12) of the road, PavementMinRise..PavementMaxRise (0.25..1.5) above it, and not foliage, a divider or the baseplate.
   - **Roadside spot.** Used only when no pavement spot passed, the march saw no pavement at all (`JobRules.HasPavement`: no non-road, non-foliage hit 0.25..1.5 above the road), the centre hit is one of the road parts, and `RoadsideSpots` is true. The spot is the road edge + RoadsideMargin (12), then +6 and +12 more. Its ground (`JobRules.RoadsideGroundOk`) must be hit, not water, solid, level, not foliage, RoadsideMinRise..RoadsideMaxRise (−4..+1.5) from the road, and off the road: not a road part, and not within RoadsideEdgePad (3) of any road part's footprint (exact test in each part's own space, not a bounding box). Baseplate and terrain are fine. Road parts are the descendants of `Jobs.RoadContainerPath` ("Test + WIP Assets/BLOCKOUT/Roads" under Workspace). If that folder is missing, anything at road level or looking like the road counts as road, and roadside spots need a centre hit of any kind.
   - **Overhead.** Nothing large may be overhead within ClearHeight (40). A roof, overpass or canopy of 30 studs or more fails the check. Thin lamp arms and signs are ignored.
   - **Standing box.** A 5×6.5×5 box standing on the spot must hold no collidable visible part (walls, bins, posts).
   - **Other roads.** The spot must be nearer its own road than any other (`RoadRouting.Snap` distance ≥ 0.8 × offset).
   The verified spot is pre-filtered again.
6. **Relax passes.**
   - Pass 1 shrinks the spacings to ×0.6 (avoid radius too) and only penalises avoided zones.
   - Pass 2 keeps offer spacing ×0.5 and the avoid radius ×0.4, ignores players, freshness, the city quota and avoided zones, and allows the KerbOffset fallback when no kerb is detected. Map places stay excluded.

**Relocation (requirement: a replacement appears somewhere else).** When a job is taken, its pickup, its drop and the taker's car position become avoid points for RelocateMemorySeconds (300), and the pickup and drop zones get heat. The replacement is generated right away, so it lands at least 2000 studs from all three and outside their zones (passes 0 and 1), in the emptiest, least recently used zone. On completion the drop is refreshed as an avoid point. Expired offers are replaced away from their spot through the freshness memory.

**Destination**

1. **Distances.** One Dijkstra run from the pickup's edge position gives the road distance to every node, so each candidate's distance is exact and costs O(1).
2. **Candidates.** DestinationCandidates (80) points from the global (whole-area) table are scored with `JobRules.ScoreDestination`:
   - the length must be inside the band [TripMinStuds 5400, TripMaxStuds 13500];
   - the drop must be at least PoiExclusionStuds from every map place;
   - it is scored by closeness to a random target length for this offer, which varies trip lengths;
   - a bearing within 40° of one of the recent 10 trips is penalised;
   - a drop within FreshnessRadius of a recent drop is penalised;
   - a drop in a zone with many recent drops is penalised;
   - a near-duplicate of a recent trip (both ends within DuplicateTripStuds 1000) is rejected.
3. **Choice.** The top 6 candidates are verified in turn (pavement or roadside, as for pickups), and the first one that passes is the drop. If the band can't be met, a second pass widens it to ×0.75 / ×1.3 (4050–17550).

On the real road graph (Python model of the same rules, without world probes) 14 offers land in 14 different zones, 3–4 in the city, at least ~1500 studs apart, and chosen trips average about 9300 road studs. From every pickup about 30–70 % of the drop candidates fall inside the band.

**Diagnostics.** A round that finds nothing warns `[JobBoard] no valid <Kind> spot this round (…)` with counts per reason: `Pre<reason>` (pre-filter), `Spot<reason>` (verified spot re-check), kerb/ground reasons, `Roadside<reason>`, `NotRoad`, `Drop<reason>` and `DropBand`. The JobOffers folder carries runtime attributes `PlacedPavement`, `PlacedRoadside`, `PlacedFallback` (offers placed since start) and `LastFailure`; each offer carries `SpotKind` (Kerb, Roadside or Fallback).

**Publish.** Each offer becomes a `Configuration` named by the offer id in `ReplicatedStorage.ActivityState.JobOffers`. Its attributes are:

- `Kind`
- `Position` (the pickup on the pavement)
- `Facing` (towards the road)
- `Distance` (road studs)
- `Estimate` (par pay)
- `ExpiresAt` (server time)
- `Label` (courier parcel name)
- `SpotKind` (diagnostics: Kerb, Roadside or Fallback)

The drop stays server-side.

**TTL.** Each offer lives a random 360–600 s. When it expires with a player within 250 studs, it is extended by 45 s, at most twice. Otherwise it is removed and replaced somewhere new. Offers above target, or of a disabled kind, are removed.

**Taxi rigs.** A rig is built only while any player is within StreamRadius (600). It is removed beyond 600 + 150. The rig is `Workspace.World.Runtime.ActivityNpcs.TaxiFare_<offerId>` (R15, random palette, root anchored, limbs massless and non-colliding, ModelStreamingMode Atomic). It faces the road and plays the hail animation every 4–7 s. The animation is `Taxi.HailAnimationId`; set it to "" to disable.

### Client offer display (JobClient, 5 Hz poll)

- **Map markers.** Each offer becomes marker `JobOffer_<id>` with Kind "Job", Icon `TaxiFare` or `CourierPickup`, Pulse, Priority 20 and a label like "TAXI FARE · 0.6 MI TRIP · ~$620". Markers are hidden during a job.
- **Streamed-in offers.** Offers within 600 studs get a local invisible anchor in `Workspace.ClientJobProps`, a beacon and, for couriers, a cardboard parcel stack with a neon band. The anchor carries a ProximityPrompt:
  - E, hold 0, MaxActivationDistance PromptDistance (45), RequiresLineOfSight false;
  - enabled only while the local player is in the DriverSeat of their own car, below 0.8 × AcceptMaxMph (about 14 mph), not on a job and not mid-accept.
- **No JOBS panel.** The JOBS button and panel are retired (ActivityClient keeps `ctx.Jobs.AddEntry/Refresh` as no-ops). Players find jobs on the map: the full map and minimap show every offer, and the player's own map waypoint (RouteGuide priority 10) can be set on one. JobClient no longer uses the `JobOffer` route source.

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
  - core `Cancel`: the **X** on the trip strip (ActivityClient `JobStrip.Cancel`, visible for the whole trip), which is now the only player cancel control;
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

Pay per stud is unchanged by the whole-map refinement; trips are about 3× longer, so pay per trip is about 3× higher.

**Example: a 9450-stud taxi trip (the band's mean; XP 104)**

| Result | Pay |
|---|---|
| Par (79.5 s) | $1,240 |
| ×1.5 (fast) | $1,859 |
| ×0.6 (slow) | $744 |
| 2 crashes at par | $942 |

**Hourly** (`JobRules.HourlyEstimate`, asserted in tests.lua). With 14 offers over the whole map the nearest one is typically ~2000 road studs away.

| Play | Model | Taxi | Courier |
|---|---|---|---|
| Focused | mean trip at 1.34× pace, 35 s per cycle to reach the next offer, pull up and stop (~38 jobs/h) | ≈ $59k/h | ≈ $53k/h |
| Casual | mean trip at par, 45 s overhead (~29 jobs/h) | ≈ $36k/h | ≈ $32k/h |

Before the refinement these were about $41k/$35k focused and $20–25k casual. Longer trips raise the hourly rate because a larger share of each cycle is paid driving. `Core.JobHourlyCashCeiling` (40,000), enforced by ActivityPayout and shown as "HOURLY JOB CAP REACHED", now binds for focused play after about 40–45 minutes; casual play stays under it. If focused play should stay near the ceiling without hitting it, lower TripPayPerStud to about 0.075 (taxi) / 0.07 (courier). That was not done, because the owner asked for pay per stud to stay the same.

**Time limits.** Abandon = ReferenceSeconds × AbandonFactor (4) + 120 s. That is about 556 s for a 13,500-stud trip and 676 s for the relaxed maximum of 17,550 studs, so the limits need no change. OfferTtl 360–600 s and the extension rules are unchanged.

## Config

**`ReplicatedStorage.Config.Activities.Jobs`** was created by the first install. Every value is bounded by `JobRules.ReadBoardConfig`. The whole-map refinement ([spec.json](spec.json)) changed the values marked "was" and added the rows marked "new".

| Attribute | Default | Meaning |
|---|---|---|
| Enabled | true | Board master switch |
| TaxiOffers / CourierOffers | 8 / 6 (was 6 / 5) | Live offers per kind |
| BoundsMinX / MaxX / MinZ / MaxZ (new) | −5040 / 4160 / −7010 / 10700 | Job area: the blockout roads inset by 150. Replaces the Core District as the area; the District is now the city |
| SectorColumns / SectorRows | 4 / 7 (was 3 / 4) | Zone grid over the area |
| CitySectorColumns / CitySectorRows (new) | 2 / 2 | Zone grid over the city |
| CityMinOffers / CityMaxOffers (new) | 3 / 5 | City quota (both kinds together) |
| MinZoneRoad (new) | 1500 | Usable road studs a zone needs |
| ZonesPerPass (new) | 3 | Best-ranked zones tried per pass |
| ZoneHeatHalfLife (new) | 600 | Zone heat half-life (s) |
| PoiExclusionStuds (new) | 350 | No pickup or drop this close to a map place |
| PoiRefreshSeconds (new) | 30 | Map place list refresh (s) |
| RelocateAvoidStuds / RelocateMemorySeconds (new) | 2000 / 300 | Replacements keep this far from a taken job's pickup, drop and taker, for this long |
| RoadsideSpots (new) | true | Allow roadside spots beside roads with no pavement |
| RoadsideMargin (new) | 12 | Studs past the road edge (+6 and +12 are also tried) |
| RoadsideMinRise / RoadsideMaxRise (new) | −4 / 1.5 | Roadside ground height relative to the road |
| RoadsideEdgePad (new) | 3 | Roadside spot clearance from every road part's footprint |
| RoadContainerPath (new) | "Test + WIP Assets/BLOCKOUT/Roads" | Road parts under Workspace ("/"-separated; "" = unknown) |
| KerbOffset | 48 | Fallback centre → spot distance when no kerb is detected (relax pass 2 only) |
| KerbSearchMin / Max / Step | 26 / 76 / 4 | Kerb march from the road centre |
| KerbRise | 0.3 | Height change that leaves the road surface |
| PavementMargin | 7 | Studs past the kerb edge |
| PavementMinRise / PavementMaxRise | 0.25 / 1.5 | Pavement height above the road |
| IntersectionClearance | 90 | Distance kept from graph nodes |
| MinOfferSpacing / MinPlayerSpacing | 700 (was 350) / 250 | Spacing; 700 keeps offer icons apart on the full map |
| FreshnessRadius / FreshnessMemory | 500 / 24 (was 300 / 16) | Do not reuse recent spots |
| OfferTtlMin / OfferTtlMax | 360 / 600 | Offer lifetime (s) |
| ExtendNearStuds / ExtendSeconds / MaxExtensions | 250 / 45 / 2 | Keep an offer a player is closing in on |
| TripMinStuds / TripMaxStuds | 5400 / 13500 (was 1800 / 4500) | Road-distance band |
| DestinationCandidates | 80 (was 40) | Drop candidates per offer |
| RecentTripMemory | 10 | Trips remembered for variety |
| DuplicateTripStuds | 1000 (was 500) | Near-duplicate threshold |
| DirectionSpreadDegrees | 40 | Bearing penalty window |
| SpotTries | 80 | Pickup samples per zone per pass |
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

**Whole-map refinement (current spec).** Run [spec.json](spec.json) alone through `scripts/feature_installer.py` with before-capture `roblox/captures/refine2-before/capture.json` (the AUDIT build was checked against it: 35 operations). Do not re-run spec-integration.json, which is already applied. The operations are:

- 3 source replacements: JobRules, JobClient and JobBoard. TaxiJob, CourierJob, the rules and the views are unchanged.
- 11 changed `Config.Activities.Jobs` attributes, each with its before value in the spec.
- 21 new `Config.Activities.Jobs` attributes.
- No Taxi or Courier attribute changes; pay per stud is unchanged.

Nothing outside this folder needs a code change. ActivityClient must keep the trip strip's X (`JobStrip.Cancel` → `Cancel`), because it is now the only player cancel control; `ctx.Jobs.AddEntry/Refresh` may stay as no-ops. JobClient no longer calls them. Check that `Workspace["Test + WIP Assets"].BLOCKOUT.Roads` exists on the server. If it moves, set `Jobs.RoadContainerPath`.

**First install (done; for recovery only).**

1. **Apply the first spec** (git history, commit 9175015) with before-capture `roblox/captures/activities-duels-after/capture.json`.
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
- the whole-map refinement:
  - area defaults and the zone spec (outskirts grid, city grid, outside = none);
  - zone edge tables (clipped to the area, samples in their zone);
  - zone ranking: occupied and hot zones last, thin zones skipped, city quota min/max, lifted on pass 2;
  - greedy sector spreading: 14 offers in 14 zones, with exactly CityMinOffers in the city;
  - heat decay;
  - relocation away (memory expiry, pickup/drop/taker avoided, radius relaxed but never zero, avoided zones skipped);
  - map-place exclusion for pickups and drops, never relaxed;
  - offer icon spacing, and drops preferring quiet zones;
  - blue-noise spread score;
  - roadside rules: pavement detection, offset, ground accept/reject, road footprint test, and the unchanged pavement rule;
- Dijkstra against RoadRouting.FindRoute;
- destination scoring (band, target length, direction variety, duplicate rejection, recent-drop penalty);
- expiry and extension;
- accept, arrive, crash, cap-step and plausibility;
- the pay breakdown (par, fast cap, slow floor, crashes, floor);
- projected pay, snapshot safety, formatting and ids;
- economy: the 3× trip band, par pay $1,240 at the mean, focused hourly above the $40k ceiling (the cap binds), casual under it, and the abandon time for the longest relaxed trip.

**Play checklist.** In Studio Play, spawn a car and use Output with the server view.

1. Within about 20 s, `ReplicatedStorage.ActivityState.JobOffers` holds 8 Taxi and 6 Courier Configurations with Position, Facing, Distance (mostly 5400–13500), Estimate, ExpiresAt and SpotKind. Output has no `[JobBoard]` warnings. If there are "no valid spot" warnings, read the reason counts and the folder's `LastFailure`; see Risks.
2. On the full map the pulsing TaxiFare and CourierPickup icons are spread over the whole blockout, 3–5 of them in the city. None overlaps the Dealership, My Garage, Customisation or race icons, or an owned-garage exterior, and no two job icons overlap.
3. Drive to an offer. Within about 600 studs a beacon appears. A taxi NPC stands facing the road and waves; a parcel stack stands beside the road. In the city (SpotKind Kerb) the spot is on the pavement. Outside the city (SpotKind Roadside) it is on flat ground about 12–24 studs off the road edge, not on any road part and not in foliage. In both cases it is not in a building and not under an overpass. The folder attributes `PlacedPavement` / `PlacedRoadside` show the mix.
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
   - no new job starts, and fresh offers are visible at new places. The replacement for the job just taken appears at least ~2000 studs from its pickup, its drop and where the player took it, in another zone of the map.
8. Compare a fast and a slow run of similar length. The fast one shows SPEED +$…, the slow one SPEED -$….
9. Cancel paths:
   - the X on the trip strip;
   - leave the car for more than 10 s;
   - enter a garage or race queue.

   Each gives `… CANCELLED`, clears the strip, route, marker and beacon, and pays nothing. The taxi fare leaves the car.
10. Anti-teleport: accept, then move the car to the drop in one step (Command Bar). The result is "Trip rejected: route not driven", with no Cash.
11. No JOBS entries: nothing calls `ctx.Jobs`. Jobs are found and routed to from the map (player waypoint).
12. Set `Taxi.Enabled = false`: the taxi offers disappear and the prompts disable. Set `Jobs.Enabled = false`: the board empties.
13. Two players: each has their own trip. An offer accepted by one disappears for the other ("That job was just taken." if both press together).
14. Leave an offer alone for more than 10 min: it relocates. Stand near an expiring offer: it survives up to +90 s.

## Risks

- **World probes are unverified in this place.** The kerb march assumes road surfaces differ from pavements by height, part or (material + name). If roads and pavements share one flat part and material, no kerb is detected. Only relax pass 2 then places spots at KerbOffset 48, which may be in the lane on 100-stud-wide roads. The same holds if RoadY 101 / ProbeHeight 60 do not bracket the road height. Tune `KerbOffset`, `KerbSearchMax`, `RoadY` or `KerbRise` with live evidence. The integrator should inspect several spots in Play.
- **Graph structure.** RoadGraphData and RoadRouting may change (Agent R). JobBoard uses `graph.Edges[i].{A, B, Length, Points, Cumulative}`, `graph.Adjacent` and `RoadRouting.Snap`. It skips edges without Points/Cumulative, but a structural change would stop offer generation. There is no crash, only a warning.
- **Prompt reach.** The prompt is measured from the character; the accept check is from the car root. A driver in the far lane of a wide road must pull over.
- **NPC rigs.** `CreateHumanoidModelFromDescription` yields and is called at most once per offer entering range. The hail animation id must be loadable; failure is silent.
- **Cadence and economy.** Economy numbers assume the cadence above and are unverified in play. Focused play now exceeds the $40k/h job ceiling, which caps it. If the owner wants focused play under the cap, lower TripPayPerStud (see Economy).
- **Roadside spots are unverified.** They assume the outskirts roads are parts under `Test + WIP Assets/BLOCKOUT/Roads`, that the ground beside them is Baseplate or terrain within −4..+1.5 of the road top, and that roads are narrower than KerbSearchMax (76) from the graph centreline. A wider road gives `NoKerb`, and a road missing from the folder gives `NotRoad`. The WIP folder path is fragile: if it moves, roadside spots stop (`NotRoad`) until `RoadContainerPath` is updated. City pavement spots are unaffected.
- **Graph vs blockout.** The graph comes from the minimap art. Graph edges without a blockout road under them fail the centre ray or `NotRoad` and cost only a candidate. Zones whose graph roads are mostly such strokes may fail repeatedly; if the `NotRoad` / `NoRoad` counts dominate, raise MinZoneRoad or trim the bounds.
- **Full map reach.** The full map's pan limits (FullMapUI `PanMinX..PanMaxZ`, defaults X −2750..5100, Z −6650..3050, in map units) may not cover the whole blockout. Offers in the far north or west could then sit outside the full map's pan area even though they show on the minimap. Check this with Agent F.
- **Density.** 14 offers over the whole map puts the nearest offer about 2000 road studs away. That is fine for driving, but a player looking for a job in one spot sees fewer nearby. TaxiOffers / CourierOffers can go up to 20 each; icon spacing (700) leaves room.
