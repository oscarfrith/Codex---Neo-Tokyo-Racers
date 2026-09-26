# Passenger seats + Sky Taxi: acceptance contract (Agent B)

Status: generated; compiled and 44/44 pure tests passed in Studio (integrator); pre-APPLY review fixes applied (2026-09-26); not installed or play-verified. Binding contract: [activities contract](../../../docs/architecture/activities-contract.md). Design: [Street Life 4.7 and 10](../../../docs/design/street-life-update.md).

## Goal and lane

Players ride in each other's hovercars (one passenger seat, owner-controlled access), and drivers can work Sky Taxi: NPC fares one at a time, plus real players who call a taxi. Lane: **High-Risk** (economy grants from server-judged trips): `delivery-reviewer` runs on the spec and diff before APPLY. TaxiFare grants go through `ActivityPayout.Pay` with a unique `CommandId` and `JobCeiling`, and one deferred retry reuses the same `CommandId`. NPC fares pay only for trips the server could verify as actually driven. Riders are never charged; there is no `Debit`. One existing source changes: `VehicleBuildService` gains `addPassengerSeat` only.

## Files

| File | Roblox path | Kind |
|---|---|---|
| VehicleBuildService.lua | ServerStorage.Modules.Game.Garage.VehicleBuildService | existing source, +addPassengerSeat |
| PassengerService.lua | ServerStorage.Modules.Game.Activities.PassengerService | server (stub body) |
| TaxiRules.lua | ServerStorage.Modules.Game.Activities.TaxiRules | pure rules (stub body) |
| TaxiJob.lua | ServerStorage.Modules.Game.Activities.TaxiJob | server (stub body) |
| PassengerClientView.lua | ReplicatedStorage.Modules.Game.Activities.PassengerClientView | client view (stub body) |
| TaxiClientView.lua | ReplicatedStorage.Modules.Game.Activities.TaxiClientView | client view (stub body) |
| tests.lua | (Edit, loopback) | pure tests for TaxiRules |
| spec.json | feature_installer spec | 6 source ops + Passengers/Taxi attributes |

## Owners

- **Seat geometry:** `VehicleBuildService.addPassengerSeat`. A plain `Seat` named `PassengerSeat`, never a `VehicleSeat`, so every driving client (keyed on `SeatPart:IsA("VehicleSeat")` + `OwnerUserId`) ignores the passenger. It is invisible, massless, and has CanCollide, CanQuery and CanTouch off, so nobody sits by touch. It is placed at `root.CFrame * (SeatOffsetX, SeatOffsetY, SeatOffsetZ)` (defaults 0, 1.45, 11: 4 studs behind the driver seat at Z 7) and welded to the root with `PassengerSeatWeld`, which `weldVehicle` detects as an existing root weld. `DriverSeatServer` still touches only `DriverSeat`.
- **Who sits, and every ejection:** `PassengerService` (server) is the only code that calls `PassengerSeat:Sit`.
- **Rider mass override:** `PassengerService`, applied before sitting and restored on every release path. Seated rider parts are set Massless (`DrivingClient` scales forces by `root.AssemblyMass`), and the original values are recorded per part.
- **Collision groups:** `VehicleCollisionServer` only. This feature never writes `CollisionGroup` on characters or rigs.
- **Taxi state:** `TaxiJob` holds duty, the fare (one per driver) and requests. The Player attribute `ActivityKind` = "Taxi" / "Passenger" comes from the `ActivityService` record.
- **Money:** `ActivityPayout.Pay` only (Reason `TaxiFare`, `JobCeiling = true`). `CommandId` = `Taxi:<fareId>:<driverUserId>`. The fareId is `NewId` plus an 8-character GUID suffix, so ids are unique across servers.
- **Client:** views are read-only mirrors. The RIDE prompt is client-local, and the server re-checks every condition.

## Flows

**Ride** (`Ride {OwnerUserId}`), validated in this order:

1. `EnablePassengers` and `Passengers.Enabled`.
2. The owner exists and is not the rider.
3. The owner's car and its `PassengerSeat` exist.
4. The car is not racing (`RaceParticipant`/`RaceRunId`) and the owner is not in a garage.
5. The seat is free.
6. The rider is alive, on foot, not already riding, within `RideRangeStuds` of the seat, and the car is at or below `BoardMaxMph`.
7. `ActivityService.IsBusy(rider)` is false.
8. Access: the owner's `PassengerAccess` attribute (Friends → `IsFriendsWith`, pcall and cached for `FriendCacheSeconds`; Anyone; Nobody), or an active taxi allowance.

After the friends lookup yields, everything is validated again. Then `Begin(rider, "Passenger")`, apply the physics overrides, pivot the rider to the seat, `Sit`, and wait up to 1 s for `Occupant`.

**Release** (a single path) happens on any of these:

- the rider jumps (the Seat's `Occupant` changes);
- `LeaveRide`;
- the core `Cancel`;
- the rider dies, respawns or leaves;
- the car is destroyed or leaves Workspace;
- `RaceParticipant`/`RaceRunId` is set;
- the owner's `GarageSessionActive`/`OwnedGarageInside`/`RaceQueueActive` is set (these also block boarding and hide the prompt);
- a taxi allowance is revoked (ride closed, cancelled, or the driver went off duty) and the owner's `PassengerAccess` would not admit the rider;
- the owner leaves the game.

Release unsits the rider and restores physics. Living riders are placed `ExitSideStuds` to the seat's -X side (the driver exits on +X) with their velocity zeroed. It then ends the activity (`Complete`; skipped for a core cancel) and fires `OccupantChanged(vehicle, nil, previous, reason)`.

**NPC fare** (on duty):

1. `TaxiSetDuty {OnDuty=true}` requires `EnableSkyTaxi` + `Taxi.Enabled`, rank ≥ `MinRank` (skipped if `ProgressionService` is missing) and driving your own car. It then calls `Begin("Taxi")` and removes any open request of your own.
2. After `NextFareSeconds`: spot = `RandomRoadPoint(driver, NpcMinStuds, NpcMaxStuds)`. An R15 rig from a random body palette stands anchored at the spot as `Workspace.World.Runtime.ActivityNpcs.TaxiFare_<id>` (massless, no collide/query/touch). The server pushes `Taxi:Fare`.
3. Pickup: the car root is within `PickupRadius` and under `StopMph`, and the seat is free (otherwise a "seat taken" notice every 5 s). Then `SeatNpc`; if seating fails, the rig is re-anchored at its standing pivot and the fare stays Waiting. Then destination = `RandomRoadPoint(car, DestMinStuds, DestMaxStuds)`, distance = road route length (straight line × 1.3 as a fallback), and estimate = `EstimateBaseSeconds + distance / EstimateStudsPerSecond`. The server pushes `Taxi:PickedUp`.
4. Riding: 10 Hz server samples. Driven distance counts the root's flat movement per tick, capped at `limit × dt + 2` studs, where limit = `RaceIntegrity.limitMph()` (or `FallbackLimitMph`) converted to studs/s. A teleport therefore adds at most one capped step. An impact is a drop of more than `ImpactMph` from the peak within `ImpactWindowSeconds`, at most one per `ImpactCooldownSeconds`. Each impact pushes `Taxi:Impact {Stars}`.
5. Arrival: within `ArriveRadius` and under `StopMph`. The trip must also be plausible: driven ≥ `MinDrivenFraction` (0.7) × route, and elapsed ≥ route / limit. If not, the result is `Taxi:FareLost` ("could not be verified") with no pay. Otherwise `UnseatNpc`; the rig is placed beside the car, walks 10 studs away and is destroyed after 3 s. Pay: stars (5 − impacts × `StarLossPerImpact`, −1 over estimate × `SlowFactor`, −2 over `VerySlowFactor`, clamped 1..5), then cash = (`FareBase` + `FarePerStud` × distance) × star multiplier (0.5/0.7/0.85/1.0/1.15), and XP likewise. Pay is attempted once, then retried once after 2 s with the same `CommandId` if it did not return `Ok`. The server pushes `Taxi:Delivered {Cash, Xp, Stars, Capped, Ok}`, and the next fare follows.
6. The fare is lost if it is not picked up within `FareTimeoutSeconds`, if the rig is unseated by anything else, or if a destination can't be found. The server pushes `Taxi:FareLost`, with no pay.
7. Off duty, a core cancel (exit grace, despawn, race, leave) or the player leaving: remove the rig (unseating it if needed), clear state, push `Taxi:Duty {OnDuty=false}`, and send no pay.

**Player taxi:**

1. `TaxiRequest` (on foot, not busy, not on duty, one open request, `RequestCooldownSeconds` between calls): the request is stored at the requester's position. The server pushes `Taxi:Request` to every on-duty driver (and to drivers who come on duty later) and `Taxi:RequestOpen` to the requester.
2. `TaxiAcceptRequest {RequesterUserId}`: the driver must be on duty, have no player ride and no boarding/riding NPC (a waiting NPC fare is released), and a free seat. The first accept wins. Then `PassengerService.AllowRide(driver, requester, AcceptWindowSeconds)`. The server pushes `Taxi:RequestAccepted` to both sides (the rider's copy carries `DriverUserId` + `Seconds`) and `Taxi:RequestClosed` to the other drivers. NPC fares pause.
3. The requester boards with RIDE (F), and the allowance bypasses `PassengerAccess`. The server pushes `Taxi:RideStarted` and accumulates the car root's flat distance at 10 Hz (the same per-tick cap as NPC fares, so teleports don't count).
4. The requester leaves the seat. If ridden ≥ `PlayerMinRideStuds` and the driver-rider pair is outside `PairCooldownSeconds`, the driver is paid `PlayerFareBase + PlayerFarePerStud × min(ridden, PlayerFareMaxStuds)` (TaxiFare, JobCeiling; the rider pays nothing). Otherwise the ride ends without a bonus and the driver is told why. `RevokeRide` follows.
5. Endings:
   - Open requests expire after `RequestTimeoutSeconds`.
   - Accepted requests expire after `AcceptWindowSeconds` if the requester has not boarded.
   - `TaxiCancelRequest` works for the requester (not while riding) or the accepting driver (passing `RequesterUserId`).
   - Going off duty or leaving closes the request. A requester still seated is ejected unless the owner's `PassengerAccess` admits them.

## Physics risk with passengers

- **Mass.** A seated character joins the car assembly. Without the override, around 10 to 15 mass units would add to `root.AssemblyMass` and change the handling that `DrivingClient` computes. The override sets every character BasePart (including accessories added later) Massless before `Sit` and restores it on every release path. NPC rigs are built massless. Residual risk: a part whose Massless is changed by another script while seated.
- **Collision.** Unchanged: the seated character keeps whatever group `VehicleCollisionServer` gave it (`Character`), and this feature does not compete with that owner. Risk: at speed, a seated rider's parts (Character group) can collide with other players standing in the road (Character↔Character collides) and with world geometry above the root. Watch for this in play. If it is a problem, the fix belongs in `VehicleCollisionServer` (for example, treating seated passengers like the vehicle's group).
- **Network ownership.** The welded passenger joins the car assembly that the driver's client owns (`SetNetworkOwner(owner)`). The rider's jump still unseats them (standard Seat behaviour), and the server re-places them beside the car.
- **Exit and park.** When the owner exits, the car coasts or anchors (`ParkedFixed`). The passenger stays seated in a parked car until they jump. This is intended (showing off a car).
- **Ejection at speed.** Jumping from a fast car re-places the rider beside the car with zero velocity, so no slingshot.

## Config (attributes; code clamps every value)

`ReplicatedStorage.Config.Activities.Passengers` (foundation: `Enabled`, `DefaultAccess`, `SeatOffsetX/Y/Z`; added here):

| Key | Default | Bounds |
|---|---|---|
| RideRangeStuds | 18 | 6–40 |
| BoardMaxMph | 12 | 1–60 |
| ExitSideStuds | 6 | 3–12 |
| FriendCacheSeconds | 120 | 10–3600 |

`ReplicatedStorage.Config.Activities.Taxi` (foundation: `Enabled`; added here; bounds in `TaxiRules.Defaults`):

| Key | Default | Key | Default |
|---|---|---|---|
| MinRank | 1 (design says 10; raise after testing) | FareBase | 1000 |
| FarePerStud | 0.5 | XpBase / XpPerStud | 50 / 0.04 |
| NpcMinStuds / NpcMaxStuds | 300 / 900 | DestMinStuds / DestMaxStuds | 800 / 2500 |
| PickupRadius / ArriveRadius | 25 / 35 | StopMph | 10 |
| ImpactMph / ImpactWindowSeconds / ImpactCooldownSeconds | 25 / 0.2 / 1 | StarLossPerImpact | 1 |
| SlowFactor / VerySlowFactor | 1.25 / 1.75 | EstimateStudsPerSecond / EstimateBaseSeconds | 80 / 20 |
| FareTimeoutSeconds / NextFareSeconds | 240 / 4 | RequestTimeoutSeconds / AcceptWindowSeconds | 180 / 120 |
| RequestCooldownSeconds / PairCooldownSeconds | 20 / 300 | PlayerMinRideStuds | 300 |
| PlayerFareBase / PlayerFarePerStud / PlayerFareMaxStuds | 1000 / 0.5 / 3000 | MinDrivenFraction / FallbackLimitMph | 0.7 / 400 |

Economy: an NPC fare over 800–2500 studs pays about $1.4k–2.25k at 4 stars. At roughly one fare every 1.5–2 min that is about $45–80k/h before the shared `JobHourlyCashCeiling` (40k/h) caps it. Player rides cap at $2.5k each, with a 5-minute cooldown per pair.

## Events (ActivityEvent payload `Type`)

- **Passenger:** `Passenger:Seated`, `Passenger:Joined`, `Passenger:Left`, `Passenger:Allowed`, `Passenger:Revoked`.
- **Taxi duty and fares:** `Taxi:Duty`, `Taxi:Fare`, `Taxi:PickedUp`, `Taxi:Impact`, `Taxi:Delivered`, `Taxi:FareLost`, `Taxi:Notice`.
- **Taxi requests:** `Taxi:Request`, `Taxi:RequestOpen`, `Taxi:RequestAccepted`, `Taxi:RequestClosed`, `Taxi:RideStarted`, `Taxi:RideComplete`, `Taxi:RequestEnded`.

Both views ignore types they do not handle, so they work whether `ActivityClient` sends every payload to every view or routes by prefix. If it routes by prefix, the rider's taxi allowance still arrives as `Passenger:Allowed`.

## Verification checklist

**Static:**

- [ ] `tests.lua` passes: all `TaxiRules` checks (config clamping, units, stops, impacts, stars, fares, player fares, cooldowns, validation).

**Single client** (Play, keyboard):

- [ ] Spawn a car. `PassengerSeat` exists (a Seat, Transparency 1, Massless, CanCollide/CanQuery/CanTouch off, welded). `DriverSeat` is unchanged, and handling and top speed match before the change.
- [ ] Go on duty from JOBS → SKY TAXI. The strip shows ON DUTY, a fare beacon and route appear, and a `TaxiFare_*` rig stands at a road point 300–900 studs away.
- [ ] Driving past the fare fast does nothing. Stopping within 25 studs seats the rig. Route and beacon switch to the destination, and the strip shows ETA and stars.
- [ ] A hard crash drops a star (toast). Stopping at the destination unseats the rig, which walks off and disappears. The cash and XP toast appears, and the next fare follows.
- [ ] Exit the car more than `ExitGraceSeconds` with a fare aboard: duty is cancelled, the rig is removed, and there is no pay.
- [ ] GO OFF DUTY with a waiting fare removes the rig and clears the route and beacon.
- [ ] Anti-teleport: pick up a fare, then teleport the car root to the destination (Command Bar) and stop. The result is FareLost "could not be verified" with no Cash change.
- [ ] Payout retry: with `ActivityPayout.Pay` failing once (test stub), the second attempt uses the same CommandId and pays once.
- [ ] Stars read as plain text (for example "4/5 STARS"); no glyphs.
- [ ] Console: no errors from PassengerService, TaxiJob or the views.

**Two clients** (A = owner/driver, B = rider):

- [ ] A access **Nobody**: B sees no RIDE prompt, and a spoofed `Ride` is refused.
- [ ] A access **Anyone**: B sees RIDE (F) on A's car, boards, and the strip says RIDING WITH A · JUMP TO EXIT. A's handling is unchanged with B aboard (mass). B's parts are Massless while seated and restored after; their CollisionGroup is never changed by this feature.
- [ ] A access **Friends**: non-friend B gets no prompt and a refusal; a friend gets in.
- [ ] B jumps at speed and is placed beside the car. A enters the garage, or A's car despawns: B is ejected beside the car. A joins a race: B is ejected.
- [ ] B leaves the game while seated, or A leaves the game: there are no errors and the other side is cleaned up.
- [ ] Taxi: A on duty, B → CALL A TAXI. A gets an offer card and ACCEPTs. B's toast names A, and B gets RIDE even on Nobody access. B boards (RideStarted), and A drives ≥ 300 studs. B jumps out: A is paid (TaxiFare), B's cash is unchanged. Repeat within 5 minutes: no bonus, and A is told why.
- [ ] Two requesters (B, C) while A is on duty: A sees one offer card at a time with ACCEPT rendered (Color3 accent). After ignoring or accepting B, C's card appears. An offer displaced by another card re-appears once after its timeout.
- [ ] A accepts B (A's access Nobody), B boards, then A goes off duty: B is ejected beside the car. The same with A on Anyone: B stays seated.
- [ ] A joins a race queue (RaceQueueActive) with B aboard: B is ejected, and B's RIDE prompt is hidden.
- [ ] A request not accepted expires at 180 s. B cancels while open. A cancels after accepting. A goes off duty after accepting: B is told.

## Foundation dependencies beyond the contract text

- `ActivityService.Register` must accept `RequiresVehicle = false` for "Passenger". `OnCancel` must run on player leave and on the core `Cancel` action for both kinds.
- `ActivityService.IsBusy` must return false for a player who only has an open taxi request (requests are not activities).
- `ctx.Jobs.AddEntry` must replace an entry with the same `Id` (the views re-add entries to update button text). `ctx.UI.Offer` must return a callable `close()` that is safe to call twice.
- `ctx.UI.Strip` is keyed by kind. The views use "Passenger" and "Taxi" and never show both at once for the same player.
- `ProgressionService.GetRank` is optional. If it is missing, the rank gate is skipped.
