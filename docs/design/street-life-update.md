# Street Life update: progression, city jobs, style and monetisation

**Status: Design - not approved.** Written 2026-09-26 from the repository, capture `arch-p9-after` and a read-only Studio check (Space Racers v1, Edit). Nothing has been changed in the game.

## 1. Why this update

Space Racers already plays well moment to moment: the driving feel is confirmed (DRIVE-01), and races, time trials, customisation and the owned garage all work. What is missing is the layer that makes players come back and tell their friends. Today:

- **One reward loop.** You earn Cash, you buy parts. Drive-to-earn pays about $25k an hour (live `HourlyCashCeiling` 60,000, `BalanceTargetCashPerHour` 25,000). Races pay $20k base (live `Racing.Rewards.Race.BaseRewardDefault`; the docs say 750, but the live value wins). The top cockpit, Zenith, costs $10M, which is roughly 200+ hours of play with no milestones in between.
- **No identity or progression outside the car.** There is no XP, rank, achievements, daily reason to log in or season.
- **No player-to-player interaction.** There are no horns, duels, passengers or garage visits. Visitor admission exists in the save data but is disabled.
- **No roleplay activities.** The city is a backdrop, not a place with things to do.
- **No live monetisation.** `ReceiptProcessor` is an inert template, and the Cash Store modal is visual only.

The goal is to turn the city into a place with jobs, rivals and status, add a stream of small wins between the big purchases, and open fair, cosmetic-leaning ways to spend Robux. Everything must stay inside the neon hovercar-city theme and reuse the systems that already exist.

## 2. Option catalogue

Scores run from 1 to 5. **Fit** means fit with the theme and current systems. **Cost** is inverted, so 5 means cheap to build. **Risk** is inverted, so 5 means low risk.

| # | Option | What it is | RP | Dopamine | Money | Retention | Fit | Cost | Risk | Total |
|---|---|---|---|---|---|---|---|---|---|---|
| A | **Driver Rank (XP and levels)** | XP from every activity; rank-up fanfare; ranks unlock paints, underglow and job tiers | 2 | 5 | 3 | 5 | 5 | 4 | 4 | **28** |
| B | **Daily Dispatch** | Login streak (7-day ladder) plus 3 daily and 1 weekly contracts ("Drift 2,000 m", "Finish 2 races") | 2 | 4 | 3 | 5 | 5 | 4 | 4 | **27** |
| C | **Style Meter** | Free-roam combo meter for drifts, near-misses, airtime, top speed and boost chains; banks a Cash/XP bonus | 1 | 5 | 2 | 4 | 5 | 3 | 4 | **24** |
| D | **Speed Cameras and Drift Zones** | Tagged world gates that record your best speed or drift score; per-camera server leaderboards; "beat your friend" toast | 2 | 5 | 1 | 4 | 5 | 4 | 4 | **25** |
| E | **Street Jobs: Courier** | Take a parcel at a hub pad and deliver it across the city against a timer; fragile or hot cargo variants | 5 | 4 | 2 | 4 | 5 | 3 | 4 | **27** |
| F | **Street Jobs: Sky Taxi and passenger seats** | Friends ride in your car; with the job on, players and NPC fares pay per trip with a star rating | 5 | 3 | 3 | 4 | 5 | 2 | 3 | **25** |
| G | **Street Duels** | Pull up to another player, flash lights, send a challenge, then a 1v1 sprint to a random landmark using the race systems | 4 | 5 | 1 | 4 | 5 | 3 | 3 | **25** |
| H | **Neon Patrol vs Runners** | Cops-and-robbers mode: patrol cars chase players with "heat" | 5 | 4 | 3 | 4 | 4 | 1 | 2 | **23** |
| I | **Night Rush events** | Server events tied to the 720-second day/night cycle: at night, double style pay, a pop-up drift zone and a supply pod drop | 2 | 4 | 1 | 4 | 5 | 3 | 4 | **23** |
| J | **Supply Pod drops** | A timed pod lands in the city; the first to reach it wins Cash or a cosmetic; everyone sees it on the minimap | 2 | 5 | 1 | 3 | 5 | 4 | 4 | **24** |
| K | **Car Meets and garage visits** | Enable visitor admission; meet-spot plazas; "Rate my ride" votes; featured car of the hour | 5 | 3 | 2 | 3 | 5 | 2 | 3 | **23** |
| L | **Horns, light flash and emotes** | Horn packs, a headlight-flash key and hover "hop" emotes | 4 | 3 | 4 | 2 | 5 | 4 | 5 | **27** |
| M | **Gamepasses and Cash packs** | VIP, 2x Drive Cash, +1 Garage Bay, Horn Pack; activate the existing Cash Store | 1 | 2 | 5 | 2 | 5 | 4 | 3 | **22** |
| N | **Circuit Pass (season)** | 30-tier free and premium track fed by XP and contracts; exclusive wraps, neon and a season cockpit variant | 2 | 5 | 5 | 5 | 5 | 2 | 3 | **27** |
| O | **Wraps and decals (liveries)** | Pattern layer in the Paint Shop; some earnable, some Robux or Pass | 3 | 3 | 5 | 3 | 5 | 2 | 4 | **25** |
| P | **Crews** | Saved clubs with tags, a crew colour and a shared garage | 5 | 2 | 2 | 4 | 4 | 1 | 2 | **20** |
| Q | **Roblox badges and Achievements** | Collection goals such as "Own every engine" or "Platinum all trials" | 1 | 3 | 1 | 3 | 5 | 5 | 5 | **23** |
| R | **Photo mode** | Freeze, orbit and filter shots of your car; share to screenshots | 3 | 3 | 1 | 2 | 5 | 3 | 3 | **20** |
| S | **Robux loot crates** | Paid random cosmetics | 0 | 5 | 5 | 3 | 3 | 3 | 1 | Rejected: needs odds disclosure and is regionally restricted; bad for trust. Earnable Cash-only reward pods are fine. |

## 3. Recommendation

Build **Street Life** as one update in four delivery steps. Each step is shippable on its own and sits behind a FeatureFlag. The order puts the foundation (rank, dailies) first, because every later feature feeds it XP and gives players a reason to care.

| Step | Contents | Why it comes here |
|---|---|---|
| **1. Progression core** | A Driver Rank, B Daily Dispatch, Q Badges (light) | Every activity now pays two currencies of meaning (Cash and XP). Cheap. It is the spine the other steps plug into. |
| **2. Drive feel** | C Style Meter, D Speed Cameras and Drift Zones, L Horn and light flash (free default horn) | Improves the gameplay players already do most (free roam) with constant micro-rewards. No new modes needed. |
| **3. City life (RP)** | E Courier, F Passenger seats and Sky Taxi, G Street Duels, J Supply Pods on the Night Rush schedule (I) | New gameplay loops and roleplay. Duels and passengers are the first player-to-player features. |
| **4. Monetisation** | M VIP, 2x Drive Cash, +1 Garage Bay, Horn Pack, Cash packs; N Circuit Pass Season 1; O Wraps | Ships after DATA-01/02 and ECON-01 are closed, and after steps 1–3 give people something to spend on and show off. |

**Deferred:** H (Neon Patrol), K (car meets), P (Crews) and R (photo mode). Each is a good idea but needs social moderation, garage visitor streaming or much more build time. Revisit after Step 3 metrics. K is the natural Step 5, because the saved `AccessMode`/`InvitedUserIds` fields already exist.

### The core loop after this update

```
 Log in ─▶ Daily Dispatch (streak reward, 3 contracts)
   │
   ▼
 Free roam ─ Style Meter combos ─ Speed cams ─ Supply pods ─ Duels
   │                 │ Cash + XP │
   ▼                 ▼
 Jobs (Courier / Taxi)   Races / Time Trials
   │                 │
   └─────▶ XP ─▶ Rank up (fanfare + unlock) ─▶ Circuit Pass tier
               Cash ─▶ Garage parts / cockpits / wraps
```

## 4. Feature designs

### 4.1 Driver Rank

- **Player goal:** always be close to the next rank. A rank-up is a celebration with something new unlocked.
- **XP sources** (server-authoritative, all tunable):
  - Drive-to-earn: 1 XP per 100 accepted studs, hooked into the DriveRewardsServer grant path.
  - Race finish: 40 / 30 / 25 for 1st / 2nd / 3rd, 10 for finishing.
  - Time trial medal: Platinum 50, Gold 35, Silver 20, Bronze 10, with the existing ×0.35 repeat factor.
  - Style bank: score ÷ 100.
  - Contracts: fixed per contract.
  - Jobs: per delivery or fare.
  - Duel win: 30.
- **Curve:** `XpForRank(n) = round(Base * n^Exponent)`, with Base 250 and Exponent 1.35, up to a cap of rank 100. Ranks 1–10 should come quickly (about 5–8 minutes each) to hook new players.
- **Unlocks:**
  - Every rank pays a Cash bonus of `RankCashBonus * n`.
  - Every 5 ranks: a paint preset, neon colour or underglow pattern.
  - Rank 5 unlocks Courier, rank 10 Sky Taxi, rank 15 Duels wagering (Cash stakes).
  - Rank badge (tier colour E→S by rank band) next to the display name on the race UI and overhead.
- **Presentation:**
  - An XP bar sits under the Cash chip (bottom left), cyan `Telemetry` fill on `PanelDeep`.
  - Each XP gain shows a "+35 XP" float.
  - Rank-up: a centre-screen card (Panel + pink `Outline` bevel, Michroma "RANK 12") with the unlock reward, a burst VFX on the car and a sound. It auto-dismisses after 3.5 s or on any input, and is suppressed during a race countdown or active race until the results screen.

### 4.2 Daily Dispatch

- **Streak ladder** (7 days, repeating, UTC day):
  - Day 1: $5k. Day 2: 100 XP. Day 3: $10k. Day 4: paint chip.
  - Day 5: $20k. Day 6: 250 XP. Day 7: a Supply Crate (a Cash-only random cosmetic from an earnable pool).
  - Missing a day resets to Day 1. VIP gets one free "streak save" a week.
- **Contracts:**
  - 3 daily and 1 weekly, from a server-side pool.
  - Examples: "Drive 15 km", "Chain a 5,000 style combo", "Win a duel", "Deliver 3 parcels", "Hit 250 mph on a speed cam", "Finish a race in the top 3", "Paint a car".
  - One free reroll a day.
  - Progress events come from existing owners (race results, drive rewards, garage paint commit), never from client claims.
- **UI:**
  - A new **Dispatch** button in the top-right HUD button row, with a pink notification dot when something is claimable.
  - It opens the shared modal shell: the streak strip (7 cards) at the top, then 4 contract cards (Card + progress bar + CLAIM ActionButton).
  - A claim plays a count-up on the Cash chip and XP bar.
  - A top notification toast (`SharedTopNotificationUI`) fires when a contract completes mid-drive.

### 4.3 Style Meter

- **Scoring** (while seated in your own vehicle in free roam; off during races and jobs with timers):
  - **Drift:** the existing drift state; points = angle × speed × time.
  - **Near-miss:** passing within `NearMissStuds` of another player's vehicle or a tagged world prop above `NearMissMinSpeed`.
  - **Airtime:** grounded-sensor loss of at least 0.6 s.
  - **Top speed** above 85% of the car's cap.
  - **Boost chain:** a boost within 1 s of a drift exit.
- **Combo:** a multiplier from ×1 to ×5 that climbs with consecutive tricks inside a `ComboWindowSeconds` of 2.5 s. Hitting anything (a hard impact) or a reset drops the combo; the combo simply fading out banks it.
- **Payout:** the banked score converts to Cash (`StyleCashPerPoint`) and XP under its own hourly ceiling, added to the same accounting as drive-to-earn so total free-roam income stays bounded.
- **Authority:** the client displays the meter optimistically. The server recomputes a plausibility bound: banked score must be ≤ f(elapsed time, sampled speeds from DriveRewardsServer), capped per bank. Unverifiable events (near-miss) are capped at a small share of the score.
- **UI:**
  - The meter sits above the speed gauge (bottom right), in the same curved language.
  - The trick name ("DRIFT", "NEAR MISS", "AIRTIME") appears in `HighSpeed` pink, with the score in `Telemetry` cyan and the multiplier chip in `ElectricBlue`.
  - Banking shows "+$1,240 / +12 XP" and a soft chime.
  - Mobile uses a compact single-line version.

### 4.4 Speed Cameras and Drift Zones

- **World objects:** Parts tagged `SpeedCamera` and `DriftZone` under `Workspace.World`, found through `Core.Tags`. The first build places 6 cameras and 3 zones inside the ~20-block playable district (MAP-01).
- **Speed camera:** passing the gate records the server-sampled speed. A holo-sign above the gate shows the server best ("CAM 03 · 312 MPH · PlayerName"). A personal best triggers a flash VFX and a "NEW PB" toast; beating someone in the server triggers "You beat X!".
- **Drift zone:** a marked area. The Style Meter drift score inside it becomes a zone score, with a medal (Bronze/Silver/Gold) against config thresholds. First Gold per zone pays a one-time bonus.
- **Storage:** Step 2 uses per-server bests only. Global per-camera ordered stores are deferred until PB-01 is fixed and the leaderboard infrastructure (currently disabled) is revisited.
- **Minimap:** icons for cameras and zones, using image-only markers like the existing map-marker approach.

### 4.5 Horn and light flash

- **Controls:** H for horn, L for light flash. The touch HUD gets a small horn button next to boost. Controller: horn on DPad-Down, flash on DPad-Right.
- **Sound:** 3D sound on the vehicle, with a per-player rate limit of 1 per 0.6 s on the server.
- **Unlocks:** the default horn is free; Horn Pack (gamepass) adds 6 sci-fi horns selectable in the Paint Shop "Sound" tab.
- **Light flash:** the flash is also the duel handshake (4.8).

### 4.6 Courier job

- **Entry:** 3 **Dispatch Hubs**, tagged `JobHub`, placed at landmark kerbs with a holo-pad and a ProximityPrompt-style HUD prompt when you drive onto them in a vehicle. Requires rank 5.
- **Flow:**
  1. On the pad, "START COURIER RUN" is offered.
  2. The server picks a drop from tagged `JobDrop` markers at a `MinDistance`–`MaxDistance` range.
  3. The existing route-guide pill/arrow system points the way, and a timer runs.
  4. The optional **Fragile** variant loses payout on hard impacts. The **Hot** variant has a shorter timer and a higher payout.
  5. On delivery: payout, XP, star grade (1–3 by time left) and a "Next run?" chain bonus (×1.1 per consecutive run, up to ×1.5).
- **Exit:** cancel from the HUD (no penalty beyond losing the chain). Leaving the vehicle for more than 10 s, despawning or starting a race cancels the run.
- **Authority:** the server owns the job state, start time and drop. Delivery is validated by server-side proximity to the drop and a minimum plausible time (the same approach as RACE-01).
- **Pay target:** about 1.5× drive-to-earn per hour for focused play, under its own ceiling.

### 4.7 Passenger seats and Sky Taxi

- **Passenger seats:** the cockpit gets 1 passenger seat (an authored `PassengerSeat` attachment per cockpit).
  - Friends or any player can enter when the owner's `PassengerAccess` is Friends (default) / Anyone / Nobody.
  - The passenger camera follows the car and can orbit.
  - This alone is a large RP feature: cruising together, taxi roleplay and showing off a car.
- **Sky Taxi job** (rank 10):
  - Toggle "On duty" from the Dispatch modal.
  - NPC fares appear as holo-beacons at kerb markers. A fare boards (a simple rig in the passenger seat) and gives a destination.
  - Payout is by distance and time. The fare's star rating drops on hard impacts and drift-spins, and rises with style.
  - **Real players** can request a taxi from their HUD (Dispatch → "Call a taxi"). It pings on-duty drivers' minimaps; a driver accepts, picks up and drops off, and the driver earns a fare bonus paid by the game (never deducted from the passenger).
- **Server limits:** NPC fares are client-visual only for the rider, and the server holds the fare record. One active fare per driver.

### 4.8 Street Duels

- **Challenge flow:**
  1. Flash lights (L) while within 40 studs and behind or alongside another player's car (both in free roam, both rank ≥ 3).
  2. They get a top toast, "PlayerX challenges you — Accept (L) / Decline", with a 10 s timeout.
  3. Both rate-limited: 1 challenge per 20 s, auto-decline after 3 ignored challenges.
- **The race:**
  1. The server picks a random landmark finish 800–1,500 studs away, using the `JobDrop` markers.
  2. A 3-2-1 countdown runs in place, reusing the race countdown presentation.
  3. It is a point-to-point sprint with a route-guide arrow to the finish. The first to enter the finish radius wins.
- **Stakes:** XP only by default. At rank 15+ an optional Cash stake of $1k / $5k / $10k is offered. Both players are debited through `MoneyService.Debit` **only after both accept and the server validates**, and the pot is granted through EconomyServer with a unique CommandId. This is High-Risk and needs ECON-01's validate-before-debit rule.
- **Integrity:** the same plausibility checks as RACE-01. A disconnect or leaving the vehicle forfeits. A no-finish after 120 s is a draw with refunds, granted through EconomyServer commands, not a reversal.

### 4.9 Supply Pods and Night Rush

- **Night Rush:** during the night band of the existing 720-second cycle (read from LightingCycle state, never a new clock), Night Rush runs. Style pay is ×1.5, one drift zone gets a neon "RUSH" overlay, and one **Supply Pod** drops.
- **Supply Pods:**
  - A pod falls at a random `PodDrop` marker, with a sky beam visible from the whole district and a minimap icon.
  - The first player to reach it in a vehicle claims it: Cash (weighted $2k–$15k), XP and a small chance of a pod-exclusive neon colour. Everyone else sees "X claimed the pod".
  - The pod pool is earnable-only: no Robux, no paid rolls, odds listed in the pod info panel.
- **Extra pods:** pods also appear once per daytime band at a lower value, so daytime players are not excluded.

### 4.10 Monetisation (Step 4)

This step is only live after DATA-01, DATA-02 and ECON-01 are closed. Everything purchasable is either cosmetic, convenience or time-saving, and **never exclusive race performance**.

| Product | Type | Suggested price | Contents |
|---|---|---|---|
| **VIP** | Gamepass | 399 R$ | +20% Cash from driving, style and jobs; weekly streak save; gold VIP rank frame; VIP-only chrome underglow; 1 extra daily contract reroll |
| **2x Drive Cash** | Gamepass | 499 R$ | Doubles drive-to-earn (and raises its hourly ceiling proportionally) |
| **+1 Garage Bay** | Gamepass | 249 R$ | Garage capacity 2 → 3 (saved `Garage.Capacity` already exists) |
| **Horn Pack** | Gamepass | 99 R$ | 6 horns |
| **Cash packs** | Dev products | 4 packs (existing Cash Store UI) | Suggested $50k / $150k (+10%) / $400k (+20%) / $1.2M (+30%, "Best Value"). Prices need an economy review against the $10M ceiling. |
| **Circuit Pass S1** | Dev product (per season) | 499 R$ | Premium track: 30 tiers of exclusive wraps, neon and a season cockpit variant (same stats as its base cockpit), plus 2 extra contracts a day |
| **Wraps** | Dev product / Cash / Pass | 49–149 R$, some for Cash | Pattern layer in the Paint Shop |

- **Receipts:** all grants go through `ReceiptProcessor` with the `PurchaseHistory` schema addition, save-before-grant, and a bounded history.
- **Offer moments:** show offers at natural moments only, never as a pop-up in the middle of a drive:
  - The Cash Store opens from the Cash chip.
  - The pass preview shows on rank-up.
  - A garage-full prompt offers +1 Bay.

## 5. Contract (docs/15 headings)

```text
System/change: Street Life update: Driver Rank, Daily Dispatch, Style Meter, Speed Cams/Drift Zones, Horn/Flash, Courier, Passengers/Sky Taxi, Street Duels, Supply Pods/Night Rush, Monetisation.
Delivery lane and reason: High-Risk overall (new saved fields, new remotes/actions, economy grants, Robux receipts). Each step is delivered separately. Steps 1 and 2 are Standard except their saved-data and economy parts; Duel stakes and Step 4 are High-Risk and go to delivery-reviewer.
Goal: Short-term reward loops, daily return reasons, roleplay jobs and the first player-to-player interactions, then fair monetisation, all inside the neon hovercar city.
Current confirmed baseline: Architecture programme P1-P9 (2026-09-26), lighting continuous 720 s, DRIVE-01 steering, drive-to-earn live (target 25k/h, ceiling 60k/h), races/TT with rewards, owned Kanda Two-Bay garage, no monetisation live.

Required changes:
- A server ProgressionService (XP, rank, contracts, streak) owned under SS.Modules.Game.Player, next to EconomyServer.
- Event hooks from existing owners (DriveRewardsServer, RaceRewardsServer, TimeTrialServer results, garage paint/purchase commit) into ProgressionService through a server-side Signal. No client-reported progress.
- Style: a client meter module under the existing DriveSessionClient ownership, and a server bank action with plausibility bounds.
- Jobs: a JobService (Courier, Taxi) that reuses the race route-guide presentation; Duels via a DuelService that reuses race countdown/integrity pieces.
- World: tagged markers (SpeedCamera, DriftZone, JobHub, JobDrop, PodDrop, TaxiKerb) inside Workspace.World, authored as physical assets with explicit approval.
- UI: HUD XP bar, Dispatch button and modal, Style Meter, rank-up card, job HUD strip, duel toasts, horn button on touch.
- Monetisation: bind ReceiptProcessor, add gamepass checks behind FeatureFlags.

Must preserve: Drive-to-earn accounting and ceilings; race/TT reward formulas and run-id duplicate protection; saved IDs/schema keys; ClientBase -> GarageUI startup; DriveSessionClient owning vehicle callbacks; CameraService as the only FOV/zoom writer; LandscapeSensor; Core.Net on all remotes; RACE-01 behaviour.
Explicit exclusions: No performance items for Robux. No paid random loot. No Neon Patrol, Crews, Car Meets or photo mode in this update. No global leaderboards for cams until PB-01 is fixed. No change to vehicle handling or catalogue prices (except as a separate approved economy pass). No portrait layouts.

Canonical owners:
- State: ProgressionService (XP/rank/streak/contracts), JobService (active job/fare), DuelService (duel lifecycle), StyleService (server bank validation). Client mirrors are read-only views fed by replicated attributes on the Player (Rank, Xp, XpToNext) and by events.
- Geometry/visibility: DesktopFreeRoamHudUI / MobileFreeRoamHudUI own HUD placement (XP bar, Style Meter, Dispatch button, horn button). The Dispatch modal uses the shared modal shell. Toasts go through SharedTopNotificationUI. The rank-up card is a single new overlay owned by the HUD owner (documented exception, section 6).
- Preview/runtime attachment: vehicle horn Sound and rank-up VFX attach to the player's runtime vehicle under Workspace.World.Runtime.PlayerVehicles via the existing vehicle VFX path. The passenger seat is part of cockpit authoring (Config.Vehicles.Authoring).
- Persistence/authoritative mutation: ProfileServer/PlayerProfileSchema; Cash only via MoneyService.Debit / EconomyServer commands (new reasons: RankReward, ContractReward, StreakReward, StyleBank, JobPayout, DuelPot, DuelRefund, PodReward, ProductGrant).

Inputs, outputs and dependencies: Depends on DriveRewardsServer samples, RaceRewardsServer/TimeTrialServer results, RaceIntegrity checks, route-guide presentation, LightingCycle phase, Core.Tags, Core.Net, FeatureFlags, AnalyticsServer, ReceiptProcessor. Outputs: profile fields, replicated Player attributes, client events for toasts/meters.
Entry, transitions, exit and cleanup:
- Rank/Dispatch: always on when flagged; the modal opens and closes from the HUD. Hidden during race staging/active race (reuses major-menu suppression).
- Style: active only while seated in own vehicle in free roam with no timed job; banked on combo expiry, exit or despawn (pending score discarded on reset/despawn).
- Job: Idle -> Offered (on hub) -> Active -> Delivered | Cancelled | Failed(timeout). Cleanup on exit >10 s, despawn, race join, teleport or leave.
- Duel: Idle -> Challenged (10 s) -> Countdown -> Racing -> Finished | Forfeit | Draw. Cleanup on either player leaving, exiting the vehicle or starting another activity. Stakes are debited only at Countdown.
- Pod: Scheduled -> Falling -> Claimable -> Claimed | Expired (90 s).
Client/server authority and remote validation: The server computes all XP, Cash, contract progress, speed readings (from its own samples), delivery/duel finishes and pod claims. Clients send intents only: OpenDispatch, ClaimContract(id), Reroll(id), BankStyle(summary: bounded), StartJob(hubId), CancelJob, ChallengeDuel(targetUserId), RespondDuel(bool), Horn, SetPassengerAccess(enum), RequestTaxi. Prefer actions on an existing remote; any new remote is wrapped with Net.invoke/Net.event (allowlist, payload sanity, rate limits).
Stable IDs, saved schema/API version and migration impact: Additive fields with safe defaults in PlayerProfileSchema/ProfileCompatibility, SchemaVersion stays 1 unless the persistence owner requires a bump:
  Progression = { Xp = 0, Rank = 1, LifetimeXp = 0 }
  Daily = { StreakDay = 0, LastClaimUtcDay = 0, StreakSavesUsedWeek = 0, Contracts = {}, ContractsUtcDay = 0, WeeklyContract = nil, RerollsUsed = 0 }
  Stats = { StyleBest = 0, CourierRuns = 0, TaxiFares = 0, DuelWins = 0, DuelLosses = 0, PodsClaimed = 0, CamBests = {} (bounded, <= 32 keys) }
  Unlocks = { Horns = {}, Wraps = {}, RankRewardsClaimed = <int high-water mark> }
  Settings.PassengerAccess = "Friends"
  PurchaseHistory = {} (bounded, oldest trimmed after 200, Saved flag) and Pass = { SeasonId = "", Premium = false, Tier = 0, ClaimedFree = 0, ClaimedPremium = 0 }
Contract IDs and product IDs are stable strings/ints in config; never repurposed.
Expected scale and bounded performance budget: 15-player servers. The style meter runs client-side at Heartbeat with no per-frame allocations. Server banks are ≤ 1 per 2 s per player. Speed cams use the server's existing drive samples (no new per-frame loops). One active pod. Up to 15 jobs. Tag lookups are cached. HUD additions stay inside the PERF-06 budget; the rank-up VFX is pooled.
Mobile, touch, controller and accessibility coverage:
- PC: H horn, L flash/accept duel, J Dispatch, X cancel job; the existing E enter/exit is unchanged.
- Touch (LandscapeSensor): Dispatch in the HUD button row (44-48 px targets); horn button left of boost; duel Accept/Decline as large toast buttons; the style meter is compact single-line; the XP bar sits under the cash chip within the safe area.
- Controller: DPad-Up Dispatch, DPad-Down horn, DPad-Right flash/accept, B cancel/close. All modals are navigable with the gamepad selection.
- Accessibility: never colour alone (icons and text on all states); a reduce-flash setting stops screen flashes (settings are not yet persisted, so it is a session setting until settings persistence lands).
Streaming/open-world behaviour: All markers are found via Core.Tags and tolerate streaming-out. Job drops, pods and duel finishes are chosen server-side from marker CFrames cached at startup (server has full world). The client guide uses positions, not instances. The pod beam is a client effect created from a replicated position.
Failure, cancellation, retry and observability: Grants are idempotent by CommandId (e.g. contract:<userId>:<utcDay>:<id>). A claim failure leaves the contract claimable. Duel stake debit happens after all validation (ECON-01 rule); a failure after debit refunds through an EconomyServer command keyed to the duel id (reviewed High-Risk). AnalyticsServer events: RankUp, ContractClaimed, StreakClaimed, StyleBanked, JobCompleted/Cancelled, DuelResult, PodClaimed, StoreOpened, ProductPurchased; economy source/sink events for each new Cash reason.

Shared components/contracts to reuse: ResponsiveUIFoundation (CreateCashDisplayPresenter, CreateTopNotificationController, StyleMetric, ApplyBevel, IsMobile, Format*Money); GarageComponents (Card, Panel, Popup, ConfirmationModal, ActionButton, MetricCard); shared modal shell (teleport/controls/cash/settings); SharedTopNotificationUI; RacingUIComponents countdown and route-guide pill/arrows; UITheme tokens; tier colours for rank bands; FreeRoam minimap image markers.
Implementation/installer and rollback approach: One canonical installer per step (street_life_step1..4), AUDIT/APPLY/ROLLBACK through scripts/studio_delivery.py or a single migration installer where new scripts are created. Each step behind FeatureFlags (EnableDriverRank, EnableDailyDispatch, EnableStyleMeter, EnableSpeedCams, EnableHornFlash, EnableCourier, EnablePassengers, EnableSkyTaxi, EnableDuels, EnableDuelStakes, EnableSupplyPods, EnableNightRush, EnableMonetisation, EnableCircuitPass). Rollback = flag off plus installer ROLLBACK; saved fields are additive and ignored by old code.

Verification matrix:
- Static/install: pure tests for the XP curve, contract generation (deterministic per UTC day and seed), style plausibility bound, courier pay calculation, duel state machine, pod weights (sum = 1 and published odds).
- Runtime transitions and cleanup: rendered Play, keyboard-driven: rank-up during free roam and suppression during race; contract progress from real race/drive/paint; courier full run, cancel, exit-vehicle cancel; style bank, reset drop; pod claim.
- Multi-client/security: two-client duel (accept, decline, timeout, forfeit on leave, stake debit/grant); passenger enter/exit with each access mode; taxi request/accept; spoofed BankStyle/ClaimContract payloads rejected; rate limits.
- Save/rejoin/migration: legacy profile loads with defaults; streak across a UTC day boundary (simulated clock); purchase receipt replay does not double-grant (DATA-01 published test required before Step 4).
- Device/performance/streaming: iPhone-class device HUD layout (touch targets, safe area); HUD frame cost with style meter; streaming-out of hubs/cams during jobs.

Readiness scorecard exceptions or deferred risks: Step 4 is blocked on DATA-01, DATA-02 and ECON-01. Global cam leaderboards are blocked on PB-01. The NET-01 per-handler audit should include each new handler. Settings persistence (for PassengerAccess and reduce-flash) needs a small Settings schema addition. Cash inflow rises with Step 1–3; an economy pass is required (target total ≤ ~45k/h for an engaged free-to-play player, so Zenith stays aspirational).
Done when: each step is installed behind its flag, Studio-verified per the matrix, user-confirmed in play, economy numbers reviewed, and docs 00/06 updated; Step 4 additionally passes a published-place purchase and save/rejoin test.
```

## 6. Documented UI exceptions

- **Rank-up card.** This is a new centre-screen overlay, not a modal. It is built from Panel + ApplyBevel + ActionButton with tokens only. It is an exception because no existing component is a transient celebration. The HUD owner owns it, so there is no new ScreenGui owner.
- **Style Meter.** It uses the gauge visual language, but it is a new widget. Its geometry is defined in `Config.UI.DesktopFreeRoamHud` / `MobileFreeRoamHud` alongside the gauge, not with copied coordinates.

## 7. New configuration (tuning)

Values are attributes read with ConfigReader (finite and bounded). Server-only values live under `ServerStorage.Config`.

- `RS.Config.Progression`:
  - `XpBase` 250, `XpExponent` 1.35, `MaxRank` 100, `RankCashBonus` 500.
  - `XpPerDriveStuds` 100, `XpRaceFirst/Second/Third/Finish`, `XpTT<Medal>`, `XpDuelWin`, `XpStyleDivisor` 100.
  - `UnlockEveryRanks` 5, `CourierRank` 5, `TaxiRank` 10, `DuelRank` 3, `DuelStakeRank` 15.
- `RS.Config.Daily`:
  - `StreakRewards` (child folder, per day: Cash/Xp/Item).
  - `DailyContractCount` 3, `WeeklyContractCount` 1, `FreeRerolls` 1, `VipRerolls` 1.
  - `SS.Config.Daily.ContractPool` (the server-only pool).
- `RS.Config.Style`:
  - `ComboWindowSeconds` 2.5, `MaxMultiplier` 5, `NearMissStuds` 8, `NearMissMinSpeed` 90.
  - `AirtimeMinSeconds` 0.6, `TopSpeedFraction` 0.85.
  - `StyleCashPerPoint` 0.05, `StyleHourlyCashCeiling` 15000, `MaxBankPoints` 50000.
- `RS.Config.World.SpeedCams`: `CooldownSeconds` 10, `DriftGold/Silver/Bronze`, `FirstGoldBonus`.
- `RS.Config.Jobs`:
  - `Courier.MinDistance` 600, `Courier.MaxDistance` 2000, `Courier.BasePay`, `Courier.PayPerStud`.
  - `Courier.ChainStep` 0.1, `Courier.ChainMax` 1.5, `Courier.FragileImpactThreshold`.
  - `Taxi.FareBase`, `Taxi.FarePerStud`, `Taxi.StarLossPerImpact`.
  - `JobHourlyCashCeiling` 40000.
- `RS.Config.Duels`: `ChallengeRange` 40, `ChallengeTimeout` 10, `ChallengeCooldown` 20, `MinFinish` 800, `MaxFinish` 1500, `TimeoutSeconds` 120, `Stakes` {1000,5000,10000}.
- `RS.Config.Events`:
  - `NightRushStylePay` 1.5, `PodClaimRadius` 20, `PodExpireSeconds` 90, `DaytimePodsPerCycle` 1.
  - `SS.Config.Events.PodTable` (the server-only weighted pool, with odds mirrored to RS for display).
- `SS.Config.Monetisation`: gamepass and product IDs, `VipCashMultiplier` 1.2, `DoubleDriveCashMultiplier` 2, Cash pack amounts.

## 8. Economy impact summary

| Source | Current | After (engaged F2P) | Notes |
|---|---|---|---|
| Drive-to-earn | ~25k/h target | ~20k/h (rebalanced) | Lower slightly, because style and jobs add income |
| Style bank | – | ≤15k/h ceiling | Shares the free-roam budget |
| Jobs | – | ~30–40k/h while working | Focused, active play pays most |
| Races | 20k base | unchanged | Consider daily first-win ×2 (the "2X" label is already in the UI) |
| Rank / streak / contracts | – | ~10–20k per day | Front-loaded in early ranks |

New Cash sinks: duel stakes (zero-sum), wraps for Cash, horns for Cash (some), and Circuit Pass cosmetics do not add to Cash inflow. A proper sink pass (for example repaint fees or garage decor tiers) should accompany Step 3.

## 9. Design decisions (Oscar, 2026-09-26)

1. **Robux for Cash: yes.** Cash packs work like GTA Shark Cards. They use the existing Cash Store modal with four tiers, which could be themed as "Cred Chips". Pack sizes are set in the Step 4 economy review.
2. **Sky Taxi uses computer-controlled (NPC) fares,** plus player requests.
3. **Street Duels allow Cash bets.** The duel is built as a validate-then-debit transaction from the start, so it does not inherit the ECON-01 problem.

## 10. Prototype priority (2026-09-26)

The game is a prototype, so live-ops (Daily Dispatch, the Circuit Pass and dashboard tuning) waits. Future-proofing means building a shared **activity core** once, with every job, duel or event plugged into it:

- a server state machine (Idle → Offered → Active → Complete / Cancelled / Failed) with cleanup on exit, despawn, race join, teleport and leave;
- payouts through EconomyServer commands with activity-scoped CommandIds;
- an XP hook into Driver Rank;
- world markers found by tag;
- the existing route-guide presentation;
- one job HUD strip.

Each job then only adds its own rules.

**Build order** (revised 2026-09-26: Oscar declined the horn/flash/Driver Tag item and asked for a GTA-style route guide and a rotating minimap):

| Order | Item | Why now |
|---|---|---|
| 1 | **Rotating minimap** (section 10.1) | Client-only, low risk, improves play immediately. Its clipping change is also required for route lines. |
| 2 | **Route guide / GPS** (section 10.2) | Improves free roam now (dealership, garage, events). Courier, Taxi and Duels all need "drive to X across the city". |
| 3 | Fix ECON-01 (validate-before-debit) and PB-01 | Duel bets and Cash packs rely on the transaction rule. PB-01 is a quick win. |
| 4 | Activity core + Driver Rank (XP, rank, XP bar, rank-up card) | The foundation every RP activity pays into. |
| 5 | **Courier** | The first activity on the core. Uses hubs, drops and the GPS. |
| 6 | **Passenger seats + Sky Taxi (NPC fares)** | The biggest RP feature. |
| 7 | **Street Duels with Cash bets** | High-Risk: goes to delivery-reviewer. The challenge is a context button that appears when you are close behind or alongside another free-roam car (PC key prompt, touch HUD button, controller face button), replacing the declined light-flash handshake. |
| 8 | **Garage visits** | Enables the saved AccessMode/InvitedUserIds. |
| Later | Style Meter, Speed Cams, Supply Pods/Night Rush, Cash packs ("Shark Card" style; after DATA-01/02), gamepasses, Daily Dispatch, Circuit Pass | Gameplay polish and live-ops once the prototype stabilises. |

**Declined:** horn, light flash and the overhead Driver Tag. The on-duty and job state appears only in the local job HUD strip and on the minimap.

**UI fit rule:** all new UI uses UITheme tokens, the shared modal shell, SharedTopNotificationUI, GarageComponents/ResponsiveUIFoundation and the existing HUD button row. The only new widgets are the XP bar, the rank-up card, the job HUD strip and the route distance chip. Mock each one against the approved free-roam concept before building it.

### 10.1 Rotating minimap

**Status: installed on Space Racers v2 on 2026-09-26, agent-verified on desktop, not yet user-confirmed** ([verification](../../scripts/minimap_rotation/verification.json), MAP-02). As built:

- The desktop Settings MINIMAP control (previously display-only) sets a session `MinimapMode` Player attribute.
- The shared rotation helpers live in `FreeRoamMapPlayerMarkers`.
- The unused `Defaults.Minimap` StringValue ("NORTH") is not read; the default is `MapRotationMode`.

**Current build** (exported `DesktopFreeRoamHudUI` ~l.838-1110, `MobileFreeRoamHudUI` ~l.76/378):

- `Minimap` is a Frame with `ClipsDescendants` and `UICorner` 9.
- `MapPanCarrier` holds a 4× sub-pixel carrier with a UIScale, then `MapCanvas`, which contains 4 tile ImageLabels.
- The canvas pans under a fixed centre `PlayerMarker` that rotates with the subject heading. `mapCanvas.Rotation` is forced to 0.
- On top: the other-player markers (`FreeRoamMapPlayerMarkers`, container = minimap), a `NorthArrow` bottom-right, and four gradient edge fades.
- Phase 3C deliberately never rotated the map, **because Roblox `ClipsDescendants` does not clip rotated GUI descendants**. A rotated canvas would draw outside the box. The same applies to rounded corners: ClipsDescendants clips to the rectangle, not the UICorner.

**Design:**

- **Clip:** the `Minimap` container becomes a **CanvasGroup**. It keeps the same name, size, position, background, UICorner and ZIndex. A CanvasGroup renders its descendants into one texture, so rotated content is clipped to the box and to the rounded corners.
- **Rotation:** a new `MapRotator` Frame (map size, centred, transparent) sits between `Minimap` and `MapPanCarrier`.
  - Its `Rotation = -displayedMapHeading`. GUI rotation pivots on the frame centre, which is exactly where the player is, so the map turns around the player.
  - The existing pan maths stays unchanged.
  - The canvas is the full map size, so rotated corners stay filled (apart from the existing world-edge limits).
- **Heading source:** `Defaults.MapRotationMode`:
  - `"Camera"` (default, as in GTA): the camera yaw. It stays stable on foot, and while driving the vehicle camera follows the car.
  - `"Subject"`: the vehicle/character look direction, as now.
  - `"NorthUp"`: the current behaviour, kept as a fallback and a future player setting.
  - The heading reuses the existing exponential smoothing and shortest-angle wrap, with its own `Layout.MapRotationResponse`.
- **Markers:**
  - The player arrow shows `subjectHeading - mapHeading`: straight up when driving with the camera behind, turning when you look around.
  - Other-player circles are rotated by the map heading: pass `MapRotationRadians` to `FreeRoamMapPlayerMarkers:Step`, or parent its overlay under `MapRotator`. Circles are rotation-invariant, so either works. The module keeps its bounded 14-marker, no-new-loop contract.
  - The north arrow rotates by `-mapHeading` and orbits the map rim (`Layout.MapNorthOrbitInset`), as in GTA. Setting `MapNorthArrowMode="Corner"` keeps today's corner placement.
- **Fades:** the edge fades stay unrotated overlays inside the CanvasGroup, so the box edge still reads the same.
- **Owners:** the desktop and mobile HUD controllers remain the geometry, visibility and render owners, in the same render callbacks with no new loops. This is client-only: no remotes, no saves.
- **Risks to verify:**
  - CanvasGroup texture quality and memory on low-end mobile (PERF-01 / iPhone-class). The group is small, about 245×245 px, re-rendered each frame while panning.
  - The 4× sub-pixel carrier inside a CanvasGroup must not blur.
  - Toggling the map during garage, race and menu suppression.
- **Verify:**
  - Turn 360° on foot and driving: no map pixels outside the box or rounded corners.
  - The north arrow is correct after the `MapCoordinateRotationDegrees`=90 calibration; the player position matches the world.
  - Other-player circles line up with the rotated map.
  - `"NorthUp"` mode reproduces today exactly.
  - Frame time on the mobile HUD is not meaningfully worse.
- **Effort:** small–medium. One Standard delivery touching two HUD modules and, optionally, the markers module.

### 10.2 Route guide (GPS)

- **Player goal:** set or receive a destination, then see the shortest road route drawn on the minimap, like GTA. The route re-plans when you leave it and clears on arrival.
- **Road graph (the main work):**
  - The 662 `RoadSpawnMarkers` (tag `NTR_RoadSpawnPoint`) sit at the centres of the curated blockout road parts (`Workspace.Test + WIP Assets.Blockout.Roads`, parts named `Road`, colour #5F5F5F). They record their source road.
  - An **Edit-time generator** builds nodes from those road parts, and edges where two road parts overlap or touch in plan view (OBB overlap with tolerance). It then writes a compact data ModuleScript: `ReplicatedStorage.Config.World.RoadGraph`, with node ids, XZ positions, adjacency and optional one-way/blocked flags.
  - The graph is data, not world instances, so it is streaming-safe and has no Workspace cost. Expected size is under ~1k nodes and ~20 KB.
  - A **debug overlay** (an opt-in `ClientTools` attribute, off by default) draws nodes and edges for manual review. Bad links are fixed by attributes on the source road parts (`RoadGraphExclude`, `RoadGraphLinkTo`) and the graph is regenerated. The graph is never hand-edited.
  - Scope is the ~20-block playable district (MAP-01) first.
- **Pathfinding:** client-side A* over the graph (under 1 ms at this size).
  - Start is the nearest node ahead of the car's direction; the goal is the nearest node to the destination.
  - Re-plan when more than `OffRouteStuds` (40) from the path for 1 s. Throttled to at most 2 per second.
  - PathfindingService is not used: it is character navmesh and wrong for hovercars at city scale.
- **Owner:** one new client module, `RouteGuideClient`, which owns the destination and the route.
  - API: `SetDestination(sourceId, worldPosition, {Priority, Label, Colour})` and `Clear(sourceId)`. The highest priority wins, in the order activity (job/duel) > quick destination > custom waypoint.
  - Activities call it from their client views. The server only supplies destinations (e.g. the courier drop) through the activity state.
  - It is suppressed while a race or time trial is active, because the race route guide owns guidance there.
- **Presentation:**
  - **Minimap route:** a polyline of pooled thin Frames inside `MapCanvas`, so it pans and rotates with the map and is clipped by the CanvasGroup from 10.1. It is rebuilt only on re-plan. Colour is `Telemetry` cyan for free-roam destinations and `HighSpeed` pink for activity targets, 3–4 px wide, with a 1 px `PanelDeep` outline for contrast.
  - **Destination blip:** an image marker at the goal. When the goal is off the map, it is clamped to the rim with an edge arrow.
  - **Distance chip:** a small Panel chip under the minimap showing the label and distance, e.g. "DEALERSHIP · 0.8 mi", in the same units setting as the speedo. It uses StyleMetric and Michroma.
  - **Optional in-world guide:** reuse the racing route-guide chevrons at upcoming turns only (`EnableWorldChevrons`, default off).
- **Setting a destination (prototype):**
  - A "Set route" row in the existing teleport modal (the shared modal shell), with Dealership, My Garage and each race/time-trial start. It reuses the list and cards already in that modal.
  - A full-screen map with tap-to-waypoint is **deferred**. It is a larger new UI and needs its own mockup.
- **Config:**
  - `RS.Config.UI.RouteGuide`: `LineWidth`, `ColourFreeRoam`, `ColourActivity`, `OffRouteStuds` 40, `ReplanMinSeconds` 0.5, `ArriveStuds` 30, `EnableWorldChevrons` false.
  - `RS.Config.World.RoadGraph` (generated data plus `GeneratorVersion`).
- **Authority, persistence, security:** client-only. No remotes, no saved data. Activity destinations are server-owned and only drawn by the client.
- **Verify:**
  - Generator: node/edge counts, a connectivity report (a single connected component in the playable district), and the debug overlay reviewed.
  - Routes to every quick destination from 5 start points; re-plan after deliberately going wrong; arrival clears the route.
  - Routes are hidden during races.
  - Minimap line clipping while rotating.
  - Mobile HUD frame time.
- **Effort:** medium. Graph generation and review is roughly half the work; A*, the line renderer and the chip are straightforward.

## 11. Mockups

None have been accepted yet. Suggested first mockups, to be iterated in the Claude app and saved under `assets/ui/mockups/street_life/` once accepted:

- The HUD with the XP bar, Style Meter and Dispatch button (PC and mobile).
- The Dispatch modal.
- The rank-up card.
