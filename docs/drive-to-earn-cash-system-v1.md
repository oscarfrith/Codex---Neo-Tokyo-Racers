# Drive-To-Earn Cash System V1

**Status:** V1.1 installed and fully mirrored on 2026-07-27; remaining High-Risk runtime matrix retained  
**Canonical installer:** `scripts/roblox_drive_to_earn_cash_system_v1.lua`  
**Revision:** `NTR_DRIVE_TO_EARN_CASH_V1_1`

## High-Risk System Contract

**System/change:** Server-authoritative passive Cash earned from accepted driving distance.

**Delivery lane and reason:** High-Risk. The feature creates persistent currency, adds a reward loop, crosses vehicle/race/session lifecycle boundaries, and must resist client-owned-physics abuse.

**Goal:** Keep the approved server-authoritative system and user-requested doubled distance rate, while retaining the hard `$35,000` rolling-hour drive-income ceiling and bounding visible reconciliation work.

**Current confirmed baseline:** The user confirmed the V1 install worked well. The complete `2026-07-27 11:08:34` Studio mirror has 191 mutually represented exported-script/source-manifest/checksum entries and contains the V1.1 ProfileService economy command, garage committed-Cash projection, runtime `OwnedVehicleId`, isolated service, telemetry client, and updated config. The supplied V1 controlled-drive telemetry recorded `21,117.8` accepted studs, `$1,050` granted, `$5.889` ungranted, `$23,125` current hourly and `$23,254` projected hourly with only `Stationary=0.1` rejected studs.

### Required changes

- Add one isolated server sampling/reward service.
- Add one versioned ProfileService economy command for validation and committed positive-Cash mutation.
- Route existing Race, Time Trial, and Studio debug positive grants through that command without changing their calculations.
- Project committed Cash back into the legacy garage table and existing `leaderstats.Cash`.
- Stamp every newly spawned owned runtime vehicle with its stable saved `OwnedVehicleId`.
- Add described designer tuning under `Config.Runtime.DriveToEarnCash_EditAttributes`.
- Add bounded Studio-only read-only telemetry.
- Provide one transactional installer with preflight, compilation, audit, idempotency, in-run rollback, and an explicit later `ROLLBACK` mode.

### Must preserve

- V74 confirmed camera behaviour and all current driving physics.
- Race and Time Trial participation, checkpoint, timing, result, PB, placement, and finish-reward calculations.
- Driving Cash remains active during a genuinely running Race or Time Trial and is additive to finish rewards.
- Existing vehicle ownership, spawn, reset/clone, destruction, rejoin, and ProfileService autosave behaviour.
- Existing leaderstats-driven Cash UI reconciliation.
- The register-limited client bootstrap and unrelated UI, VFX, world, audio, garage, and vehicle-performance owners.

### Explicit exclusions

- No vehicle-tier, price, upgrade, advertised maximum-speed, or multiplier-based passive earnings.
- No new client reward remote and no client-authored payable distance, speed, reward, multiplier, ownership, or cap state.
- No per-sample save, per-frame Workspace scan, whole-Workspace polling, race-reward formula edit, driving-physics edit, or bootstrap patch.
- No saved drive-stat schema in V1. Accepted/rejected distance telemetry resets per server session and is Studio-only.
- No retroactive rollback of Cash already legitimately committed and saved before the system is disabled or removed.

## Canonical owners

| Concern | Canonical owner |
|---|---|
| Payable distance, sample baseline, rejection reasons, fractional accumulator, batching, rolling drive cap | `DriveToEarnCashService_Active` |
| Saved-session validation and committed positive-Cash mutation | `ProfileServiceBindings.ExecuteEconomyCommand` in `ProfileService_Active` |
| Stable owned runtime vehicle creation/identity | Existing `GarageActionController_Shadow_Disabled`, adding only `OwnedVehicleId` at the shared build boundary |
| Race/Time Trial finish reward calculation and duplicate-claim rules | Existing `RaceRewardService_Active` |
| Cash presentation/reconciliation | Existing `leaderstats.Cash` consumers |
| Studio telemetry presentation | `DriveToEarnCashTelemetry_StudioOnly`; read-only and guarded by `RunService:IsStudio()` |
| Saved profile/autosave/session lifecycle | Existing `ProfileService_Active` |

The legacy garage profile remains a compatibility projection for existing garage transactions. Positive grants no longer originate there: the old `GarageProfileMutationBindings.GrantCash` signature delegates to ProfileService, and `EconomyCashCommitted` copies the committed absolute balance back into the compatibility table. Purchase/deduction migration is outside this feature scope and remains existing persistence debt; it must not be expanded as a second reward owner.

## Inputs, outputs, and dependencies

**Server-observed inputs**

- Current `Player`, `Character`, `Humanoid`, `Humanoid.SeatPart`, and `VehicleSeat.Occupant`.
- The exact direct child model under `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles`.
- Server-visible vehicle root position and lifecycle attributes.
- Server-owned ProfileService session ID/generation and saved `Vehicles[OwnedVehicleId]`.
- Server-authored Race/Time Trial run/frozen/readiness attributes.
- Server-authored garage and teleport transition attributes.
- Designer configuration attributes.

**Outputs**

- Accepted/rejected distance in bounded server state.
- Fractional ungranted Cash and whole-Cash batches.
- One dirty ProfileService session after a committed batch; normal autosave/rejoin owns persistence.
- Existing `leaderstats.Cash` update.
- Studio-only bounded telemetry attributes and overlay.

**Dependencies**

- `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles`
- `ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active`
- `GarageActionController_Shadow_Disabled` shared owned-vehicle build boundary
- Existing Race/Time Trial lifecycle attributes
- Existing leaderstats Cash consumers

## Entry, transitions, exit, and cleanup

1. A player becomes eligible only while occupying the driver seat of their current owned runtime vehicle.
2. The first eligible sample establishes a non-payable baseline.
3. Each later sample revalidates player, ProfileService session, vehicle instance, stable vehicle ID, ownership, driver/seat, lifecycle attributes, and transition gates.
4. Any vehicle/session/run identity change, spawn, reset clone, frozen/staging state, teleport, garage/loading transition, long sampling gap, vertical jump, or implausible segment rejects/reset-baselines before later movement can pay.
5. Unseating, parking, exit-coasting, vehicle destruction, respawn, vehicle change, disconnect, or shutdown releases or invalidates the baseline.
6. `PlayerRemoving` deletes the bounded per-player state. ProfileService performs its existing final save; the drive service never calls `SaveNow`.

Every `BindableFunction:Invoke` is treated as a yield boundary. The service resolves and compares the full player/character/seat/vehicle/root/vehicle-ID/profile-session/run context again after validation and grant calls before retaining a baseline.

## Client/server authority and threat model

| Threat case | Server response |
|---|---|
| Client sends distance/speed/reward/multiplier | No such remote or payload exists. |
| Client moves a network-owned vehicle | Server measures root displacement and applies absolute segment, vertical, lifecycle, ownership, and rolling-cap checks. |
| Client teleports within one sample | Segment is rejected by transition state or plausibility limit and baseline is reset. |
| Repeated checkpoint reset | Race reset replaces the vehicle; instance identity changes and the first post-reset sample is non-payable. |
| Small reset/respawn jump | Vehicle/session/run identity and baseline rules apply; an excessive remaining segment is rejected. |
| Exit while vehicle coasts | Seat/occupant and `NTR_ExitCoasting` checks reject it. |
| Preview/display vehicle | It is not the exact direct owned runtime vehicle and lacks the stable saved ownership contract. |
| Ownership/name spoof | ProfileService verifies `OwnerUserId`, `DriverUserId`, `OwnedVehicleId`, exact runtime parent, seat occupant, and `session.Profile.Vehicles[vehicleId]`. Names are not trusted. |
| Stale ProfileService session | Expected session ID and generation must match at command time. |
| Duplicate/busy command | Per-player ProfileService command lock rejects overlap; bounded per-session command IDs make retries duplicate-safe. Distance owner restores only a bounded sub-batch accumulator on failure. |
| Farm above intended rate | Rolling drive-only Cash cap hard-stops new batches and discards cap-blocked backlog above one batch. |
| Race reward double counting | Drive batches and finish rewards are separate. Existing finish claim keys remain unchanged. |

The plausibility ceiling is deliberately independent of vehicle tier, price, or raw maximum speed. It is a broad exploit ceiling, not a passive-income multiplier.

## Stable IDs, data/API version, and migration

- Economy command API: version `1`.
- Runtime ownership ID: saved vehicle dictionary key copied to `vehicle.OwnedVehicleId`.
- Profile schema: unchanged (`SchemaVersion = 1`); V1 adds no saved field.
- Existing Cash remains compatible and uses the existing numeric profile field.
- Existing positive-grant callers retain their binding signature and are delegated internally.
- Installation does not migrate stored profiles.
- Rollback removes the service, telemetry/config, vehicle-ID stamp, and command/delegation patches. Already committed Cash remains ordinary saved Cash.

## Scale and bounded performance budget

- Sampling default: `2 Hz`.
- Growth: `O(players)` with one direct player/seat/vehicle lookup per sample.
- Target lobby: 15 players = approximately 30 validation samples/second and at most 30 coalesced drive-Cash commands/second when every player is moving fast enough to cross a batch.
- No per-frame work, no `Workspace:GetDescendants()`, no whole-Workspace scan, no client request loop, and no reward remote.
- Per-player state is one record, a fixed rejection-reason dictionary, at most about 60 cap buckets, and at most about 60 projection buckets at defaults.
- Telemetry publishes at most once per two seconds per player in Studio only.
- Runtime audit prints at most once per 30 seconds in Studio by default.
- A `$1` batch is a visibility threshold, not one command per dollar. `MinimumGrantIntervalSeconds=0.5` coalesces all payable whole Cash into at most one ProfileService command per player per interval; runtime safety-clamps lower values back to `0.5`.
- At the 15-player default maximum this is at most 30 committed leaderstat/dirty reconciliations per second. Existing autosave cadence still owns saves; there is no `SaveNow` per command or sample.

## Mobile, input, accessibility, and streaming

- Calculation is server-owned and input-device agnostic; keyboard, controller, and touch use the same eligibility and rate.
- Production adds no UI surface. Existing responsive Cash presentation receives the same leaderstats event.
- The Studio telemetry overlay is read-only and viewport-bounded for desktop and mobile emulation.
- The server follows only the currently seated vehicle under the authoritative runtime folder. It does not depend on client streaming or distant city content.
- A streamed-out presentation object cannot authorize or invalidate saved Cash.

## Failure, retry, observability, and rollback

- Missing dependency, wrong class, stale source anchor, partial marker, or compilation error is an installer `BLOCKER`.
- Installer mutation is guarded; a failed install restores sources/attributes and destroys objects created by that run.
- A command rejection does not save and does not create a second grant route.
- Failed grant intent is restored only up to less than one batch; it cannot grow into an unbounded payout backlog.
- Rejection reasons are fixed and bounded.
- Studio telemetry shows accepted studs, rejected studs by reason, fractional ungranted Cash, granted Cash, current/projected hourly income, cap usage, last reason, and vehicle/session identity.
- Studio runtime audit exposes active state count, sample count, command count, tuning, and the no-remote contract.
- `ROLLBACK` removes the exact V1 implementation but intentionally cannot subtract already saved earned Cash.

## Designer configuration and safe defaults

Path: `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DriveToEarnCash_EditAttributes`

| Attribute | V1.1 default | Purpose |
|---|---:|---|
| `Enabled` | `true` | Master server switch |
| `CashPerAcceptedStud` | `0.10` | `$1` per 10 accepted studs |
| `VisibleGrantBatchCash` | `1` | Minimum visible threshold; payable dollars are coalesced |
| `SampleIntervalSeconds` | `0.5` | 2 Hz sampling |
| `MinimumGrantIntervalSeconds` | `0.5` | At most 2 ProfileService drive grants/second/player; lower values clamp to `0.5` |
| `MinimumAcceptedSegmentStuds` | `1` | Stationary/jitter filter |
| `MaximumAcceptedSpeedStudsPerSecond` | `540` | Broad absolute plausibility ceiling |
| `SegmentToleranceStuds` | `12` | Scheduler/network-owner tolerance |
| `MaximumVerticalDeltaStuds` | `30` | Single-sample vertical rejection |
| `MaximumVerticalToHorizontalRatio` | `1` | Mostly vertical movement rejection |
| `MaximumSampleGapSeconds` | `2` | Long-gap baseline reset |
| `HourlyCashCeiling` | `35000` | Rolling drive-only Cash cap |
| `CeilingWindowSeconds` | `3600` | One-hour cap window |
| `CeilingBucketSeconds` | `60` | Bounded rolling accounting |
| `MaximumDriveGrantPerCommand` | `1000` | Command defence-in-depth |
| `ProjectionWindowSeconds` | `600` | Ten-minute tuning projection |
| `ProjectionBucketSeconds` | `10` | Bounded projection buckets |
| `StudioTelemetryEnabled` | `true` | Studio-only read-only overlay |
| `TelemetryRefreshSeconds` | `2` | Bounded attribute publication |
| `RuntimeAuditIntervalSeconds` | `30` | Studio-only audit print |

Every attribute receives a `Descriptions` StringValue in the config folder.

## Balance derivation and tuning report

The confirmed V1 telemetry at `$0.05/stud` projected `$23,254/hour`, close to the original `$25,000/hour` target. V1.1 doubles the rate to `$0.10/stud`, so the same measured drive projects:

- approximately `$46,508/hour` before the ceiling;
- `$35,000/hour` granted once the rolling window is saturated;
- the original observed route/speed will therefore be cap-limited during a sustained run.

At `$0.10/stud`, the original `$25,000/hour` target corresponds to `250,000` accepted studs/hour, `69.44 studs/second`, or approximately `43.40 mph`. The `$35,000/hour` ceiling corresponds to `350,000` accepted studs/hour; a vehicle averaging above approximately `60.76 mph` will eventually be cap-limited.

Expected speed checks before measured Studio evidence:

| Controlled drive | Reference speed | Uncapped projection | Expected result |
|---|---:|---:|---|
| Low | 45 mph | `$25,920/hour` | Near the original target |
| Medium normal | 87 mph | `$50,112/hour` | Uncapped projection exceeds the ceiling |
| High normal | 180 mph | `$103,680/hour` | Uncapped telemetry is high; grants remain ceiling-bound |

Vehicle purchase pacing, before starting-Cash offsets and before finish rewards:

| Vehicle target | Original `$25k/hour` target | V1.1 measured-route projection (`$46,508/hour`, uncapped diagnostic) | Sustained `$35k/hour` ceiling |
|---:|---:|---:|---:|
| `$40,000` | 1.6 h | 0.86 h | 1.14 h |
| `$120,000` | 4.8 h | 2.58 h | 3.43 h |
| `$350,000` | 14 h | 7.53 h | 10 h |
| `$1.1M` | 44 h | 23.65 h | 31.43 h |
| `$3.5M` | 140 h | 75.26 h | 100 h |
| `$10M` | 400 h | 215.02 h | 285.71 h |

These figures are Neo Tokyo Racers time-to-purchase projections, not a competitor ratio. The `$46,508/hour` column is telemetry diagnosis only: the unchanged rolling ceiling prevents that rate being sustained indefinitely. The upper targets remain extremely long from passive driving alone; finish/placement rewards are additive and should be included in later whole-economy tuning.

**Measured V1 evidence:** `21,117.8` accepted studs, `$1,050` granted, `$5.889` ungranted, `$23,125` current hourly, `$23,254` projected hourly, `3%` cap usage, and only `Stationary=0.1` rejected studs. This validates the original target on the tested route. V1.1 needs a fresh controlled run because the requested doubling intentionally moves that route above the original target and into the retained safety ceiling.

## Complete verification matrix

### Static/install

- [ ] Run the canonical installer in Edit mode with `MODE="INSTALL"`.
- [ ] Require `[NTR Drive-To-Earn Cash V1.1] AUDIT PASS`.
- [ ] Require `[NTR Drive-To-Earn Cash V1.1] INSTALL PASS`.
- [ ] Confirm the config folder, descriptions, isolated server service, and Studio-only client exist once.
- [ ] Change only `MODE` to `AUDIT`; require the same owner/rate/batch/cap audit.
- [ ] Confirm no new RemoteEvent/RemoteFunction, bootstrap patch, driving-physics patch, or race-reward formula change.
- [ ] Restart Studio before Play so every modified/new source starts from committed state.

### Ten-minute controlled drives

Use the same owned vehicle, route, reset policy, and low/medium/high target-speed method for each run.

| Test | Expected |
|---|---|
| Low normal speed, 10 minutes | Projection materially below `$25k/hour`; no false segment rejections |
| Medium normal speed, 10 minutes | Record the uncapped projection; the previously observed route should be about `$46.5k/hour`, with grants bounded by the ceiling |
| High normal speed, 10 minutes | Uncapped projection may exceed `$35k/hour`; cap usage rises and no implausible normal segments are rejected |

For an accelerated cap proof, temporarily set `HourlyCashCeiling=5833` and `CeilingWindowSeconds=600`, retain the other defaults, drive at high normal speed for ten minutes, and confirm drive grants do not exceed about `$5,833`. Restore `35000/3600` immediately afterward and rerun `AUDIT`. The rolling buckets are conservative by at most one configured bucket at an expiry boundary; they must never grant above the configured window amount.

### Non-payable states

- [ ] Stationary while seated.
- [ ] Unseated beside the vehicle.
- [ ] Parked fixed vehicle.
- [ ] Fast exit-coasting vehicle after exit.
- [ ] Dealership/customisation/owned-garage preview or display vehicle.
- [ ] Race queue/staging/countdown while frozen.
- [ ] Time Trial staging/countdown while frozen.
- [ ] Dealership, race-browser, garage, initial-loading, and return transitions.
- [ ] Vehicle spawn placement and first sample after spawn.

Each must show no Cash grant, a relevant bounded rejection reason, and a fresh non-payable baseline before later driving.

### Free roam, Time Trial, and two-client Race

- [ ] Free-roam driving grants normal batches.
- [ ] Time Trial running state continues drive earnings.
- [ ] Time Trial finish reward remains separately calculated and both amounts reconcile once.
- [ ] Two clients stage without passive reward, then both earn during the running Race.
- [ ] Race placement rewards remain separately correct for both clients.
- [ ] One player’s cap/buckets/vehicle/session never affect the other.

### Exploit/lifecycle cleanup

- [ ] Repeated Reset to Last Checkpoint cannot add reset distance.
- [ ] Repeated race/garage/dealership teleports cannot add transition distance.
- [ ] Vehicle destruction clears the baseline.
- [ ] Character respawn clears the baseline.
- [ ] Changing owned vehicle clears the baseline and revalidates the new stable vehicle ID.
- [ ] Disconnect removes telemetry/server state.
- [ ] Rejoin begins with no stale baseline, cap table, or telemetry identity.
- [ ] Save/rejoin retains committed Cash exactly once.
- [ ] A forced command rejection does not create an unbounded pending payout.

### Scale, performance, mobile

- [x] 15-player static reasoning check: default 2 Hz means about 30 validation samples/second and at most 30 coalesced grant commands/second, with bounded tables and no per-frame/Workspace scan.
- [ ] Runtime command-count check: while continuously earning, `TotalGrantCommands` grows by no more than two per second per active player. `TotalProfileCommands` includes both validation and grant calls and grows by no more than four per second per active player; neither count scales with dollars in a coalesced grant.
- [ ] Two-client MicroProfiler/Output smoke shows no remote spam, save spam, or warning loop.
- [ ] Low-end mobile emulator can drive, earn, stage, reset, and exit with unchanged physics/input.
- [ ] Existing mobile Cash display reconciles the committed leaderstat.
- [ ] Studio telemetry stays viewport-bounded; published-server test creates no telemetry GUI or telemetry attributes.
- [ ] Repeated vehicle entry/exit and race cycles do not grow service instances, connections, or per-player records.

## Expected audit/runtime output

Edit-mode installer:

```text
[NTR Drive-To-Earn Cash V1.1] AUDIT PASS owner=DriveToEarnCashService_Active cashOwner=ProfileService.ExecuteEconomyCommand rate=0.1000 batch=1 cap=35000/3600s sample=0.50s grantMaxHz=2.00 telemetry=StudioOnly warnings=0
[NTR Drive-To-Earn Cash V1.1] INSTALL PASS. Restart Play. Require the runtime audit PASS and complete the High-Risk verification matrix before confirmation.
```

Studio Play runtime, approximately every 30 seconds:

```text
[NTR Drive-To-Earn Runtime Audit] PASS players=<n> samples=<n> commands=<n> grants=<n> rate=0.1000 batch=1 grantMaxHz=2.00 cap=35000/3600s noRemotes=true
```

## Readiness scorecard

| Area | V1.1 status before Studio confirmation | Evidence / remaining risk |
|---|---|---|
| Ownership | PASS (design/static) | Isolated distance owner and ProfileService positive-grant command |
| Security | DEFERRED runtime | Static no-client-input contract complete; exploit/reset matrix pending |
| Data | PASS (design/static) | No schema change; stable saved vehicle ID and command V1 |
| Lifecycle | DEFERRED runtime | Generation/reset rules implemented; repeated transitions pending |
| Performance | DEFERRED runtime | Bounded 2 Hz/15-player design; representative smoke pending |
| Mobile/input | DEFERRED runtime | Device-independent server path; low-end/mobile regression pending |
| Streaming | PASS (design/static) | Exact server runtime vehicle; no client/world presentation dependency |
| Failure handling | PASS (installer/static) | Transaction rollback, command rejection, bounded pending value |
| Observability | PASS V1 / DEFERRED V1.1 | V1 overlay produced coherent live evidence; confirm V1.1 values/cadence |
| Documentation | PASS | Contract, tuning, verification, rollback, baseline/issues/history updated |

Installed V1 is a confirmed baseline. V1.1 must not replace it as the confirmed tuning baseline until every `DEFERRED runtime` row passes and the full Studio mirror is refreshed.

## Risks and rollback

- Client network ownership can still produce plausible-looking cheated motion below the absolute server speed ceiling. V1 limits payout and rejects broad anomalies; it is not a full physics attestation system.
- The cap uses bounded time buckets. It is conservative around expiry boundaries by up to one bucket and never intentionally exceeds the configured cap.
- Existing garage purchase/deduction compatibility still uses the established legacy-to-ProfileService import bridge. Positive reward grants are consolidated here, but full deduction-command migration remains separate architecture work.
- The exact ProfileService and garage source patches are fragile. If either anchor differs, stop and refresh/inspect the live source; do not loosen or layer a repair script.
- `ROLLBACK` stops future drive earnings and restores the pre-V1 positive-grant bridge. It does not subtract Cash already committed and saved.
- Studio History before installation is the cleanest full rollback if no live earnings need preservation.

## Mirror status

The installed V1.1 and user-confirmed free-roam presentation continuation are fresh in the complete `2026-07-27 11:26:30` mirror; neither mirror area appears stale. It contains 191 matching source entries and the expected V1.1 sources/config. The configured `MinimumGrantIntervalSeconds=0.1` is safety-clamped to an effective `0.5` by the committed source.

Free-roam display smoothing remains a separate presentation owner documented in `docs/free-roam-cash-smoothing-v1.md`; it does not change this authority contract. No Studio command or mirror refresh is pending for ordinary use. Leave `docs/studio-full-export-paste.txt` unstaged when committing.
