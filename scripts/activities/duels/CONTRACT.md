# Street Duels: acceptance contract (Agent C)

Lane: **High-Risk** (economy: Cash stakes, escrow, grants). Run `delivery-reviewer` on this contract, `spec.json` and the three sources before APPLY. Binding upstream contract: [activities-contract.md](../../../docs/architecture/activities-contract.md). Design: [street-life-update.md §4.8](../../../docs/design/street-life-update.md). The task brief overrides the design doc where they differ: 60-stud range, 12 s challenge timeout, 150 s race timeout, Free/$5k/$25k/$100k stakes, stake rank 3, and a CHALLENGE button instead of the light flash.

## Goal

Two players, each driving their own car within 60 studs of each other in free roam, can challenge each other. The race is a point-to-point sprint to a random road finish 800–1,500 studs away. The prize is XP, plus an optional Cash stake of Free, $5,000, $25,000 or $100,000. The winner takes the pot, which is twice the stake. A draw refunds both stakes. A forfeit gives the pot to the opponent.

## Owners

| Concern | Owner |
|---|---|
| Duel state, escrow, settlement, countdown, finish detection, integrity | `ServerStorage.Modules.Game.Activities.DuelService` (this delivery) |
| Decisions (validation, stakes, transitions, payouts, CommandIds, finish fairness, plausibility inputs) | `DuelRules` (pure, this delivery) |
| Presentation and intents | `ReplicatedStorage.Modules.Game.Activities.DuelClientView` (this delivery) |
| Activity lifecycle, busy checks, vehicle lookups, road points, pushes | ActivityService (foundation) |
| Cash grants and XP | ActivityPayout.Pay → EconomyServer `GrantCash` and ProgressionService.AddXp (foundation) |
| Cash debits | ActivityPayout.Debit → MoneyService.Debit (foundation) |
| Integrity mode and speed limit | RaceIntegrity.mode() / limitMph() (read only; not modified) |
| Countdown, offer, beacon and strip widgets | ActivityClient `ctx.UI` (foundation) |
| Route line | RouteGuide, source id `"Duel"`, Priority 60, Kind Activity |

Nothing else is modified. There are no new remotes: `DuelChallenge` and `DuelRespond` are predeclared in the ActivityInvoke allowlist. There are no HUD source edits and no world instances. There is one new **saved** field: `profile.DuelEscrow[duelId] = { Owed, Stake, At }`, an additive unknown key that ProfileServer preserves; SchemaVersion is unchanged. There is also one **DataStore**, `NTR_DuelLostStakes_v1` (key `<duelId>:<userId>`, value `"Lost"`, durable, no expiry). The countdown uses the existing `ServerStorage.Runtime.Player.ProfileServiceBindings.SaveNow` binding. Duel ids are `duel_<n>-<12 chars of JobId>`, unique across servers. Vehicle attribute written: `DuelFrozen` (true while frozen, otherwise nil). `DriveReady` is written only while the duel owns the freeze.

## State machine (DuelRules.Transitions)

```
Challenged -> Accepted | Expired | Declined
Accepted   -> Countdown | Forfeit | Draw
Countdown  -> Racing | Forfeit | Draw
Racing     -> Finished | Forfeit | Draw
Finished, Forfeit, Draw, Expired, Declined: terminal
```

- Money is escrowed only in Accepted, Countdown and Racing.
- Expired and Declined are reachable only from Challenged, so they never move Cash.
- A duel that fails validation at accept time closes as Expired, and the message is shown from each player's own point of view.

## Flow

1. **CHALLENGE button.** The client shows it when you are driving your own car and another player driving their own car is within `ChallengeRange`.
   - Tapping it calls `DuelChallenge {TargetUserId, Preview = true}`. The server returns the stakes both players may use: Free always, plus Cash stakes only when rank, flag and both wallets allow.
   - The chosen stake is sent as `DuelChallenge {TargetUserId, Stake}`.
2. **Server challenge validation** (DuelRules.validateChallenge):
   - Enabled (config + `EnableDuels`, default on).
   - Not self; the target is present.
   - Both are driving their own car (`GetDrivenVehicle`); neither is busy (`IsBusy`).
   - Neither has a pending or live duel.
   - The pair is in range (flat distance between roots).
   - The server is not closing (R6).
   - Challenger cooldown of 20 s, and the pair is not muted.
   - The stake is listed.
   - For stake > 0: `StakesEnabled` config **and** the `EnableDuelStakes` flag (default **off**), both ranks ≥ `StakeMinRank`, fewer than `PairStakeLimitPerHour` (3) staked duels between this pair in the last hour (R4, unordered pair), and both players `CanAfford`.
   - On success the server pushes `Duel:Challenge {DuelId, FromUserId, FromName, Stake, ExpiresAt}` to the target. ExpiresAt is in server time, 12 s ahead.
3. **Expiry or decline** closes the challenge with `Duel:Closed` to both players and counts as a rejection. After 3 rejections in a row the challenger → target direction is muted for 5 min. An accept resets the count.
4. **Accept** (`DuelRespond {DuelId, Accept = true}`, target only):
   1. Re-validate everything, without the limiter or the pending check.
   2. Choose the finish. This may yield on the first road-graph load; nothing is committed yet, and `Accepting` blocks double taps and expiry.
   3. Re-validate again, because the world may have changed during the yield.
   4. **Commit block, same tick, no yield:**
      - `Begin(challenger)`, then `Begin(target)`.
      - `Debit(challenger)`, then write `profile.DuelEscrow[id] = {Owed = 0, Stake}` for the challenger.
      - `Debit(target)`, then write the target's entry.
      - Both profiles are checked to be live before `Begin`, so the ledger writes cannot fail.
      - Record the pair stake, then transition to Accepted.
   5. Freeze both cars (anchor the root, `DuelFrozen = true`, `DriveReady = false`), record each car's `FrozenAt` position, then transition to Countdown.
   6. **Staked duels force-save both profiles during the countdown (B1a).** This calls `SaveNow:Invoke(player)`, retried on Busy or failure until just before GO. Studio's no-save sandbox counts as saved.
   7. Push `Duel:Countdown {DuelId, GoAtServerTime = now + 3, Finish, OpponentUserId, OpponentName, Stake, Pot, FinishRadius}`.
5. **Go.** At `GoAtServerTime` the server checks, in order:
   - For a staked duel, both force-saves must have succeeded. Otherwise the duel is a **Draw** (refunds) and nobody races.
   - Each car must still be validly frozen (B2): the owner is driving it, `DuelFrozen == true`, the root is anchored, and the root is within 5 studs (flat) of `FrozenAt`. This catches `VehicleLifecycleService.reEnterVehicle` unanchoring and moving a car during the countdown.
   - One broken racer forfeits. If both are broken, the duel is a Draw (`DuelRules.faultOutcome`), so iteration order never picks a winner.
   - Then each car is released, the path is measured from `FrozenAt`, the duel transitions to Racing and `Duel:Go` is pushed.
   - Release only unanchors a car when `ParkedFixed` is unset and the owner is driving it (R1). An abandoned or parked car only loses `DuelFrozen`.
6. **Race loop (10 Hz, one Heartbeat scheduler for all duels):**
   - Timeout after 150 s → Draw.
   - A car that is gone or replaced → that racer forfeits. Both in the same tick → Draw.
   - **Integrity (B2/R3).** Each tick adds the flat chord from the last sample to the racer's path length. `DuelRules.pathAllowed(path, elapsed, limit, jitter, tolerance)` must hold. Jitter and tolerance are added **once per run**, so repeated sub-threshold hops add up and get caught. The limit is `RaceIntegrity.limitMph()`.
     - Staked duels are **always checked and enforced**, whatever `RaceIntegrity.mode()` says.
     - Free duels follow the mode: Off has no checks, Log warns only, Enforce enforces.
     - An enforced flag makes that racer **forfeit to the opponent**. If both are flagged, the duel is a Draw.
     - The path check covers the start-to-finish check, because the path is at least the straight line.
   - A root within 40 studs (flat XZ) of the finish is an arrival. `DuelRules.resolveArrivals` picks the result: the closest arrival wins, and an exact tie is a Draw.
7. **Settle** (at most once per duel):
   1. **Synchronous part.** Mark the duel settled and hand the escrow to the payout list and the saved ledger (`DuelRules.ledgerPlan`):
      - each recipient's `Owed` is set, except that while any loser exists the winner's `Owed` is only their own stake;
      - losers' entries are **not** touched yet;
      - the duel is forgotten, cars are released and activity records are ended.
   2. **Every loser gets a durable Lost marker before any pot is paid (B1b).** This is a DataStore `UpdateAsync` with 3 tries. It applies whether or not the loser's entry could have been deleted, because the loser's saved profile may still hold it.
   3. If all markers are written, the winner's `Owed` is raised to the pot, which needs the winner's live profile. Only then are the losers' entries deleted where their profiles are live; for offline losers the marker covers it.
   4. If any marker fails, or the winner is gone: the written markers are removed, and the duel **settles as refunds**. Each player is owed and paid their own stake. If a marker can't be removed, that loser's stake is burned and `BURNED` is logged.
   5. Pay Cash alone (GrantCash does not yield), then delete that entry in the same thread. Pay XP afterwards with CommandId `<id>:xp`.
   6. Push `Duel:Result {DuelId, Outcome, Reason, WinnerUserId, Cash, Xp, Stake}`.
   - All ledger and pay steps resolve players with `Players:GetPlayerByUserId`, never a stored Player object, so a same-server rejoin is handled (R3).

## Payouts (DuelRules.settlement)

| Outcome | Winner | Loser | Each player |
|---|---|---|---|
| Finished | Cash = pot (the whole escrow), `DuelPot:<id>`; Xp = WinXp (30) if the race lasted ≥ `MinXpRaceSeconds` (15) | Xp = LoseXp (10) under the same gate, `DuelXp:<id>:<userId>` | – |
| Forfeit (leave, exit, OnCancel, car lost, freeze broken or not driving at GO, integrity flag) | Cash = pot, `DuelPot:<id>`, **no XP** (R4) | nothing | – |
| Draw (timeout, same-tick tie, both at fault, save failed at GO, no finish, error, server closing, marker failure) | – | – | Cash = own escrow, `DuelRefund:<id>:<userId>`; Xp = DrawXp (0) under the time gate |
| Recovery on join | – | – | `Owed`, or `Stake` if unsettled, at least 10 min old and unmarked; `DuelRecover:<id>:<userId>` (Reason DuelRefund) |
| Expired / Declined | – | – | nothing (no debit happened) |

- Free duels pay XP only. Entries with 0 Cash and 0 XP are skipped.
- **Invariant:** the Cash paid out always equals the escrow collected. This holds for every outcome and is covered by the tests.
- `JobCeiling = false` for every duel payout.

## Economy safety argument

1. **Validate, then debit (ECON-01).** No debit happens until every check has passed three times: once at the challenge and twice at the accept, the last time after the last possible yield. The profile check, Begin, Debit and ledger writes sit in one run of Luau with no yields. No other script can run between the last check and the debits.
2. **Begin before debit.** Activity records are claimed first. A Begin failure therefore aborts with no Cash moved.
3. **Second debit failure.** This should be impossible. The challenger's entry becomes `Owed = stake`, and the challenger is refunded with `DuelRefund:<id>:<challengerId>`. The entry is deleted after the grant, or recovered on their next join.
4. **Persisted escrow (B1).** Every debit writes `profile.DuelEscrow[id]` in the same tick, so any saved profile holding the debit also holds the entry. A staked duel only races after **both** profiles have been force-saved with their debit and entry. If a later save diverges (a session is lost, or a save fails), the durable copy still carries the entry, and recovery treats it by the rules below. A successful grant deletes the entry in the same thread straight after GrantCash returns.
5. **Recovery on join**, and again via `task.delay` for deferred entries (R1). The server resolves the player by userId each step and waits up to 60 s for the profile. For each entry:
   - it skips duels that are still live or settling on this server;
   - it pays `Owed` if it is above 0;
   - for `Owed = 0`, `Stake > 0`: an entry younger than `max(600 s, countdown + timeout + 120 s)` is **deferred**, because its settlement may still be writing markers on another server. After that, a Lost marker clears the entry, a failed marker read is retried on a later join, and otherwise `Stake` is refunded. There is no expiry rule, because markers are durable.
   - Each recovery uses `DuelRecover:<id>:<userId>` and deletes the entry after the grant.
6. **No Cash is ever created.** A stake reaches someone else only after that player's Lost marker is durable. Every saved copy of the loser's entry then clears on recovery instead of refunding. Until the marker exists, the winner's saved claim is only their own stake. If the marker can't be written, or the winner's claim can't be raised, both players are refunded.
7. **Idempotent grants.** The CommandIds are deterministic and globally unique, because the id carries the server tag. `payWithRetry` retries with the same id; EconomyServer returns `AlreadyCommitted` and ActivityPayout caches results.
8. **Integrity (B2).** Staked duels always enforce. A cheater forfeits their own stake to the opponent and never takes a pot. Checks run on cumulative path length with jitter and tolerance counted once per run.
9. **Collusion (R4).** A pair can play at most `PairStakeLimitPerHour` staked duels per hour. This limit is **per server** (in memory, R5): a colluding pair can reset it by moving to a new server. It is accepted because the transfer is zero-sum and XP is gated. XP needs a race of at least `MinXpRaceSeconds`, and forfeits pay no XP, so exit-farming and instant-finish farming earn nothing.
10. **No client authority.** The client sends only a target, a stake amount and accept or decline.
11. **Loud failures.** The logs are `[DUEL] PAYOUT FAILED`, `UNPAID ... (left in saved escrow for recovery)`, `RECOVERED`, `CLEARED`, `BURNED`, `force-save ... failed`, `lost-marker write/read/undo failed` and `pot not released; settled as refunds`.
12. **Concurrent Pay.** A second Pay with the same CommandId must wait for the in-flight result rather than returning Ok early. This is the integrator's ActivityPayout fix (R4); DuelService relies on it and does not work around it.

### BindToClose and the residual windows (documented)

`onClose` still settles live duels as Draws synchronously, but this is **best effort only**. ProfileServer's `PlayerRemoving` and `BindToClose` are registered first and set `session.Closing` at once, so these refunds normally fail. The saved entries (`Owed = 0`, no marker) are refunded on each player's next join, after the deferral window. Forfeits during shutdown become Draws, so no markers are written.

Remaining windows:

- **(a) A save lands between a cash grant and its entry delete.** Only a Busy lock inside GrantCash could cause this, because XP is granted separately afterwards. The result is one duplicated payout on recovery.
- **(b) A marker write succeeded but reported failure, and the undo also failed.** The loser's stake is burned (`BURNED` is logged). This fails closed.
- **(c) A server crash during the countdown, before the forced saves finish.** The earlier save state applies to both players consistently: a debit that was saved has its entry and is refunded.
- **(d) A player with an `Owed = 0` entry rejoins within the deferral window.** Recovery waits (`task.delay`). If they leave again first, the next join retries.
- **(e) Studio without DataStore access** (unpublished place or API access off). Marker writes fail, so every staked Finished or Forfeit **settles as refunds**. Marker reads fail, so old unsettled entries are retried rather than refunded. Test the pot path in a published place with Studio API access on.
- **(f) A force-save takes longer than the countdown** (DataStore throttling). The duel is a Draw (refunds) instead of a race. This is visible as `force-save ... failed` or `SaveFailed`.

## Configuration (`ReplicatedStorage.Config.Activities.Duels`)

| Attribute | Default | Bounds | Owner |
|---|---|---|---|
| Enabled | true | bool | foundation |
| StakesEnabled | true | bool (AND server flag `EnableDuelStakes`, default off) | foundation |
| Stakes | "0,5000,25000,100000" | whole, 0–1,000,000, 0 always added | foundation |
| StakeMinRank | 3 | 1–100 | foundation |
| ChallengeRange | 60 | 10–300 | this delivery |
| ChallengeTimeout | 12 s | 5–60 | this delivery |
| ChallengeCooldown | 20 s | 0–600 | this delivery |
| MuteAfter | 3 | 1–20 | this delivery |
| MuteSeconds | 300 | 0–3600 | this delivery |
| CountdownSeconds | 3 | 1–10 | this delivery |
| FinishRadius | 40 | 10–200 | this delivery |
| MinFinish / MaxFinish | 800 / 1500 | 200–5000 / 300–8000 | this delivery |
| FinishMaxGap | 40 | 0–400 (straight-line fairness between the two starts) | this delivery |
| TimeoutSeconds | 150 | 30–900 | this delivery |
| PairStakeLimitPerHour | 3 | 0–100 (0 disables Cash stakes) | this delivery |
| MinXpRaceSeconds | 15 | 0–300 | this delivery |
| WinXp / LoseXp / DrawXp | 30 / 10 / 0 | 0–10000 | this delivery |
| IntegrityJitterSeconds | 0.35 | 0–3 | this delivery |
| IntegrityToleranceStuds | 24 | 0–500 | this delivery |

**Flags:**

- `EnableDuels` defaults to true, because config `Enabled` also gates it.
- `EnableDuelStakes` defaults to **false**: Cash stakes need an explicit dashboard opt-in.
- In Studio, set the `ServerStorage.Config` attribute `Flag_EnableDuelStakes = true`.

Integrity mode and the speed limit come from RaceIntegrity (`ServerStorage.Config.Racing` or the dashboard `RaceIntegrityMode`).

- Staked duels ignore the mode and always enforce.
- Free duels: Off has no checks, Log gives a `[RACE-01]` warning, Enforce means the flagged racer forfeits.

## Client (DuelClientView)

- **CHALLENGE <NAME> button.** Bottom centre of `ctx.Root`, 84 px above the bottom edge (120 px on mobile, 52 px tall), so it sits above the CONTROLS / EXIT VEHICLE row. It uses theme tokens only.
  - Hidden while the player is in an activity, race queue or garage, or has a pending or live duel.
  - Hidden when the other car is in a race.
  - The scan runs at 4 Hz.
- **Stake menu.** `ctx.UI.Offer` with the server-approved stakes (FREE always) and CANCEL.
- **Incoming challenge.** `ctx.UI.Offer` with ACCEPT and DECLINE, timing out at `ExpiresAt`.
- **Countdown.** `ctx.UI.Countdown(goAt, "DUEL")` plus a route to the finish (`"Duel"`, Priority 60) and a beacon in `Theme.HighSpeed`. The strip reads `DUEL vs <name> · $<pot>` (or `· XP`).
- **Result.** A toast, and the route, beacon and strip are cleared.
- Placement offsets are an integration tunable. Adjust them against the live HUD at integration if the button overlaps.

## Tests

### Pure (`tests.lua`, Edit, loopback 8767)

These cover:

- every legal and illegal transition, terminal states and escrow states;
- stake parsing (junk, dupes, fallback, Free added) and validation (every rejection code), and available stakes against both wallets and ranks;
- challenge validation codes, range edge, cooldown (per challenger, skipped on revalidation), mute after 3 (directional, reset on accept, expires after 5 min) and prune;
- settlement for Finished, Forfeit, Draw (including half escrow), Free, Expired and Declined, with cash conservation, the XP time gate and no XP on forfeits;
- CommandIds that are deterministic, unique and ≤ 240 chars;
- finish fairness and fallback;
- arrival resolution (single, same-tick, tie);
- integrity policy for each mode × staked/free; a flagged racer forfeits and a flagged winner never takes the pot; both flagged is a draw;
- the cumulative path check, including repeated sub-threshold hops;
- the pair stake cap (unordered, rolling hour, prune) and the closing gate;
- the ledger plan and every recovery branch (owed, young → defer, old unsettled refund, Lost, lookup failed, no expiry, live, junk, clamp, `needsMarker`);
- the freeze check at GO (`frozenIntact`: moved, unanchored, lost claim) and `faultOutcome`, where both at fault is a draw;
- end-to-end conservation scenarios: pot with the marker and the loser entry left or deleted, marker failure leading to refunds, a shutdown draw, and the winner's provisional claim.

The test returns `{failures, results}`.

### Synthetic server harness (Test → Local Server, 2 players, server Output)

Duels need two real seated drivers (`GetDrivenVehicle` reads `Humanoid.SeatPart`), so the harness drives the real ActivityInvoke path from both clients. It does not require gameplay modules through MCP, because that would create a second module cache and duplicate owners.

1. **Setup.**
   - Seed Cash on both test accounts (≥ $25,000) and set rank ≥ 3.
   - Set `ServerStorage.Config` attribute `Flag_EnableDuelStakes = true` and `ServerStorage.Config.Racing.RaceIntegrityMode = "Log"`.
   - Set `Duels.TimeoutSeconds = 30` so the timeout case is quick.
2. **Drive the cases.** Seat both players in their cars side by side. For each case, call `ActivityInvoke:InvokeServer("DuelChallenge", {TargetUserId, Stake = 5000})` from client 1 and `("DuelRespond", {DuelId, Accept})` from client 2 in the client Command Bars. The cases are:
   - win;
   - loss;
   - forfeit by exiting the car (wait out the 10 s grace);
   - forfeit by leaving the game;
   - timeout draw;
   - a server-side `PivotTo` of one car onto the finish in a staked duel with `RaceIntegrityMode = Log` (the cheater forfeits to the opponent);
   - decline;
   - ignore until expiry;
   - server close (stop the local server mid-race), then rejoin: after the deferral, which you can shorten for the test by temporarily setting `DuelRules.MIN_RECOVER_AGE` and `TimeoutSeconds` low, each player's stake comes back once through `DuelRecover` and the `DuelEscrow` entries are gone;
   - a leave-forfeit, then the leaver rejoins: no refund, and `CLEARED ... marker=Lost` is logged. This needs a published place with DataStore access; without it, expect refunds for both players and `pot not released; settled as refunds`;
   - re-enter the car during the countdown (exit, then re-enter, which unanchors it): that racer forfeits at GO with `NotReadyAtGo`; both do it → Draw;
   - a force-save failure (simulate by disabling DataStore access in a published test place): Draw at GO with `SaveFailed`;
   - a 4th staked duel between the same pair within an hour is refused, while a free duel is still allowed;
   - a win in under 15 s pays the pot but no XP.
3. **Evidence.** For each case, record `leaderstats.Cash` for both players before, after the accept and after the result, plus `LastEconomyGrantReason` and the `[DUEL]` and `[RACE-01]` Output lines.
4. **Acceptance:**
   - For staked outcomes, the challenger delta plus the target delta equals 0.
   - Win or forfeit: the winner gets +stake and the loser −stake. Draw: 0 and 0. Expired or Declined: 0 and 0, with no debit at all.
   - Recovery is net zero or better for each player, and never pays out more than was staked.
   - `profile.DuelEscrow` is empty after every settled case: check it via the ProfileServer runtime marker or a temporary server print, not by requiring modules through MCP.
   - Nothing logs `[DUEL] PAYOUT FAILED` or `UNPAID` (except the documented shutdown race).
   - `DuelFrozen` is nil on both cars afterwards.
   - `ActivityKind` is "" on both players afterwards.

### 2-player Studio checklist (Test → Local Server, 2 players)

- [ ] The CHALLENGE button shows only when both players are driving their own cars within 60 studs. It hides on foot, in a garage, in a race queue, during a duel, or beyond 60 studs.
- [ ] The stake menu shows FREE only below rank 3 or with the flag off. With the flag on and rank ≥ 3 it shows the stakes both players can afford.
- [ ] The incoming offer times out after 12 s, and the challenger sees "Challenge expired." A second challenge within 20 s gets the cooldown message.
- [ ] After 3 declines the pair is muted for 5 min, while the other direction still works.
- [ ] On accept, both cars freeze, the countdown shows DUEL 3-2-1, both players see the route line and beacon, the strip shows the pot, and both balances drop by the stake at once.
- [ ] At GO both cars drive with no NaN or camera errors (CAM-02), and the network owner is correct.
- [ ] The first player into the 40-stud radius wins. Winner +pot/+30 XP and loser +10 XP, shown in the toasts and on the rank strip.
- [ ] Exiting the car during the race: after the 10 s grace the exiter forfeits and the opponent gets the pot.
- [ ] Leaving the game forfeits in the same way.
- [ ] No finish within 150 s gives a draw, and both stakes are refunded.
- [ ] In a staked duel, a teleport to the finish (Command Bar) makes the teleporter forfeit and logs a `[RACE-01]` warning, even with RaceIntegrity set to Log.
- [ ] In a free duel with RaceIntegrity at Log, the same teleport only warns.
- [ ] Exiting the car during the countdown forfeits at GO, and the exited car stays anchored with no unanchor from the duel.
- [ ] Re-entering the car during the countdown (so it is unanchored or moved) forfeits at GO.
- [ ] A free duel moves only XP and never Cash.
- [ ] There are no errors in the server or client Output. `DuelFrozen` is nil on both cars afterwards.

## Rollback

- Turn off `EnableDuels` (or set config `Enabled = false`); this stops new challenges.
- Turn off `EnableDuelStakes` to stop Cash stakes only.
- Duels already in progress still settle normally.
- **Do not remove DuelService while `DuelEscrow` entries may exist (R6).** Recovery runs on join through `DuelService.start` even when both flags are off, so flag rollback is safe.
- Replacing DuelService with the inert stub strands any saved entries until a real DuelService is installed again. Their Cash is not lost: entries are recovered whenever DuelService next runs. They are not recovered while the stub is installed.
- Before any source rollback, leave the flags off for longer than the deferral window (10 min) on every server. Then check that no recent `UNPAID` or `force-save` warnings remain.
- Source rollback: reinstall the foundation stubs over the three module paths. The DataStore `NTR_DuelLostStakes_v1` can stay; it is inert without DuelService.
