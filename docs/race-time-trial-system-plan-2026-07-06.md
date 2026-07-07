# Race And Time Trial System Plan

**Created:** 2026-07-06
**Status:** Phase 4 user-confirmed working / Phase 5F visual baseline / Phase 6 rewards generated for testing
**Scope:** Race entry, matchmaking, checkpoints, timing, rewards, UI, anti-cheat, and future progression.

## Context Read

This plan is based on the current repo docs and Studio mirror. The attached GDD PDF at `H:\My Drive\Roblox\Neo Tokyo Racers\Documents\Gamefam Application\IND - GDD v1.pdf` could not be read from the local command runner because Windows returned access denied, so this plan uses the user's race/time-trial summary plus the repo's current project database.

Relevant current facts:

- The active driving baseline is V74 confirmed, with later driving improvements confirmed; V75 remains generated but not explicitly confirmed.
- The main client bootstrap is register-limited and should not receive a large race UI or race logic block.
- The current free-roam map stack already has a `Race` button and placeholder Race panel inside the isolated `FreeRoamNavController_Active`.
- `ShiftedCanalSprint` now exists under `Workspace.NeoTokyoRacersWorld.RaceRoutes` with 14 moved checkpoints, start zones, a spawn grid, and a finish line from the refreshed mirror.
- Road spawn markers exist under `Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers`.
- Spawned vehicles receive server-written `PerformanceTier`, `PerformanceIndex`, `PerformanceScore`, and detailed performance folders from `VehiclePerformanceRuntimeService_Active`.
- Profile/cash persistence is still bridged through the garage/profile services, with the legacy garage profile remaining important.
- Racing Phase 2's instant prompt start is working, but it should be superseded by a themed entry menu and staged start flow before rewards/multiplayer are added.

## Design Goals

- Make joining a race or time trial feel frictionless: drive into a glowing zone, press `E` or tap the mobile prompt, review the event menu, choose an owned vehicle, stage at the line, countdown, go.
- Keep timing and rewards server-authoritative so players cannot win by spoofing client UI.
- Keep content data editable in Studio through folders and attributes rather than hardcoded source.
- Keep runtime logic isolated in new race services/controllers, not in driving, VFX, garage, or the bootstrap.
- Support solo time trials first, then multiplayer matchmaking once checkpoints and timing are reliable.
- Let vehicle tier shape available events and reward scale without forcing every track to duplicate logic.
- Keep route data source-agnostic so official Studio-authored races and future player-created races can use the same runtime validator, checkpoint logic, HUD, arrows, results, and rewards.
- Keep race/time-trial sessions visually and physically separate from free roam. Non-participants should not see active racers or participant-only race assets, and racers should not collide with unrelated free-roam players.

## Recommended Studio Structure

```text
Workspace
  NeoTokyoRacersWorld
    RaceRoutes
      <RouteId>
        ArrowMarkers
          Arrow_001
          Arrow_002
          ...
        StartZones
          TimeTrialStartZone
          RaceStartZone
        SpawnGrid
          Grid_01
          Grid_02
          ...
        Media
          TrackImage
          MapImage
          PreviewCamera
        Checkpoints
          Checkpoint_001
          Checkpoint_002
          ...
        FinishLine
    RaceInstances
      <RunId>
        Route
        Vehicles
        SessionAssets
```

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      Racing
        RaceCatalog
          <EventId>
        TimeTrialCatalog
          <EventId>
        Rewards
        TierRules
    Shared
      Remotes
        Racing
          RaceRequest
          RaceEvent
      Modules
        Racing
          RaceConfigReader
          RaceRouteDefinition
        RaceResultShared
          RaceSessionShared
```

```text
ServerScriptService
  NeoTokyoRacers
    Services
      Racing
        RaceService_Active
        TimeTrialService_Active
        RaceEntryService_Active
        RaceSessionService_Active
        RaceInstanceService_Active
        RaceVisibilityService_Active
        RaceMatchmakingService_Active
        RaceRewardService_Active
        RaceCheckpointService_Active
```

```text
StarterPlayer
  StarterPlayerScripts
    NeoTokyoRacersClient
      Controllers
        Racing
          RaceEntryMenuClient_Active
          RaceVehicleSelectClient_Active
          RaceHudClient_Active
          RaceRouteGuideClient_Active
          RaceVisibilityClient_Active
```

## Config Model

Each event should be a Folder or ModuleScript-backed folder with attributes:

```text
EventId = "shibuya_sprint_tt"
DisplayName = "Shibuya Sprint"
Mode = "TimeTrial" | "Race"
RouteId = "shibuya_sprint"
TrackImage = "rbxassetid://..."
MapImage = "rbxassetid://..."
MapBoundsMin = "-500,-500"
MapBoundsMax = "500,500"
PreviewCameraCFrame = "..."
AllowedVehicleTiers = "E,D,C" or "All" -- time trials / special events only
RecommendedTier = "D" -- display guidance, not a race matchmaking bracket
MinPlayers = 2
MaxPlayers = 6
Laps = 1
EntryFee = 0
BaseReward = 500
DailyFirstWinMultiplier = 2.00
```

Reward multipliers should be global across tracks:

```text
Config.Racing.Rewards.TimeTrial
  RewardRoundToNearest = 250
  BronzeRewardMultiplier = 0.55
  SilverRewardMultiplier = 0.75
  GoldRewardMultiplier = 1.00
  PlatinumRewardMultiplier = 1.30
  RepeatRewardMultiplier = 0.35
  TierMultiplier_E = 1.00
  TierMultiplier_D = 1.15
  TierMultiplier_C = 1.35
  TierMultiplier_B = 1.60
  TierMultiplier_A = 1.90
  TierMultiplier_S = 2.25
```

Time trial medal attributes should live per event and per vehicle tier:

```text
E_BronzeSeconds = 95.0
E_SilverSeconds = 82.5
E_GoldSeconds = 72.0
E_PlatinumSeconds = 66.0
D_BronzeSeconds = 86.0
D_SilverSeconds = 74.0
D_GoldSeconds = 65.0
D_PlatinumSeconds = 60.0
```

Race placement reward attributes should also be global:

```text
Config.Racing.Rewards.Race
RewardRoundToNearest = 250
BronzePlaceMax = 3
SilverPlaceMax = 2
GoldPlaceMax = 1
BronzeRewardMultiplier = 0.65
SilverRewardMultiplier = 0.85
GoldRewardMultiplier = 1.00
DNFRewardMultiplier = 0
```

This keeps balancing editable without patching source: each track gets a `BaseReward`, while the medal/tier/placement/repeat multipliers stay consistent globally. If the event attribute list gets too large, move event definitions to `RaceCatalog` ModuleScripts and keep only route object placement in Workspace.

Track and map media should be optional at first. If `TrackImage` or `MapImage` is empty, the race entry menu should show a themed placeholder rather than blocking the event.

## Route Definition Contract

The runtime should not care whether a route came from a Studio folder or a future player-created race. Add a shared route normalization layer before gameplay services:

```text
RaceRouteDefinition = {
  RouteId,
  DisplayName,
  SourceType = "Official" | "PlayerCreated" | "PrivateDraft",
  CreatorUserId,
  Version,
  StartZones,
  SpawnGrid,
  Checkpoints,
  FinishLine,
  ArrowMarkers,
  Media,
  SessionAssetTemplates,
  Bounds,
  ValidationSummary,
}
```

Official routes can be read from:

```text
Workspace.NeoTokyoRacersWorld.RaceRoutes.<RouteId>
```

Future player-created routes should be stored as serialized data, not permanent hand-made Workspace folders:

```text
Profile.Racing.CreatedRoutes.<LocalDraftId>
DataStore/MemoryStore published route records later
Workspace.NeoTokyoRacersWorld.RaceRoutes.RuntimePlayerRoutes.<RunId> only while active
```

This means the early official-route system should call `RaceConfigReader.GetRouteDefinition(routeId)` instead of reaching directly into Workspace from every service. That one abstraction keeps the six-month player-created-race update from needing a rewrite of checkpoints, HUD, matchmaking, rewards, or results.

Player-created race data should include only safe, serializable fields:

```text
Name
CreatorUserId
CreatedAt
UpdatedAt
StartCFrame
SpawnGridCFrames
CheckpointCFrames
CheckpointSizes
FinishCFrame
ArrowHintCFrames
MapImageId
TrackImageId
SessionAssetPlacements
AllowedModes
AllowedVehicleTiers -- optional for creator rules; official multiplayer races should default to open
Laps
```

Validation before publishing should check:

- minimum and maximum checkpoint count;
- no checkpoint inside blocked/private geometry;
- route stays within allowed world bounds;
- segment distance is not absurdly short or absurdly long;
- finish follows all checkpoints;
- route can be completed by a normal vehicle tier;
- participant-only race assets are from an approved asset whitelist;
- no offensive route name text;
- creator cooldowns and per-player route limits.

Player-created races should initially be private/friends-only or invite-code based. Public discovery, featured player races, and rewards for public races should come after moderation and exploit testing.

## Route Arrows And Guidance Assets

Arrow guidance should be planned as route content from the start. The recommended route folder has an optional `ArrowMarkers` child:

```text
RaceRoutes
  <RouteId>
    ArrowMarkers
      Arrow_001
      Arrow_002
      ...
```

Each arrow marker should be an anchored invisible or visible authoring part with attributes:

```text
ArrowIndex = 1
RouteId = "ShiftedCanalSprint"
TargetCheckpointIndex = 2
DisplayMode = "Always" | "WhenNext" | "WrongWayAssist"
ArrowStyle = "Chevron" | "TurnLeft" | "TurnRight" | "Up"
ArrowAssetId = "rbxassetid://..."
Scale = 1.0
ColorRole = "Accent" | "Warning" | "Checkpoint"
```

Runtime behavior:

- server does not need to replicate arrow state every frame;
- `RaceRouteGuideClient_Active` reads the current route definition and shows only the relevant local arrow assets;
- arrows can be billboard/image, beam, mesh, or neon part assets depending on style;
- checkpoint rings remain the main "go here" signal, while arrows handle confusing corners, forks, and verticality;
- future player-created route tools should let players place arrow hints separately from mandatory checkpoints.

This should be included in the first route-guide/HUD phase, before multiplayer matchmaking, because good navigation is core to whether racing feels fair and fun.

Participant-only ramps, jump pads, gates, neon barriers, boost strips, warning signs, and decorative route props should be treated as a separate route asset layer:

```text
RaceRoutes
  <RouteId>
    SessionAssetTemplates
      Jump_001
      Barrier_001
      BoostStrip_001
```

Decorative guidance can be client-rendered locally. Anything that must collide or affect movement should be spawned inside the active race instance, not left collidable in free roam.

## Vehicle Tier Rules

Use the spawned vehicle's server-written attributes as the source of truth:

- `PerformanceTier`
- `PerformanceIndex`
- `OwnerUserId`
- `DriverUserId`
- current seated driver

Entry rules:

- A player must be driving their own vehicle.
- The vehicle must have a valid `PerformanceTier`.
- Time trials may require or score against a specific vehicle tier.
- Multiplayer races should be open-category at launch; do not split queues by vehicle tier.
- Special future events may use a restricted/loaner/spec category, but that should be opt-in content rather than the default race queue.
- Do not trust a client-sent tier; the server should read the actual runtime vehicle.

Recommended first balancing:

- Time trials are tier-bracketed, so E/D/C/B/A/S each have their own medal targets on the same route.
- Multiplayer races use one open queue/category per race event so matchmaking does not spread the playerbase too thin.
- Race rewards should be based on event difficulty and finishing position, not on a tier-bracketed race category.
- The menu can still show a recommended tier/performance band so players understand the challenge before joining.

## Entry Flow

Primary flow:

1. Player drives into a `StartZone` in their vehicle.
2. Client shows an in-world prompt: `E RACE MENU` / touch prompt.
3. Pressing the prompt opens a themed race entry menu instead of immediately starting.
4. Menu shows track image, track map, route name, recommended performance, rewards, time-trial medal targets or open-category race placement rewards, and bottom buttons: `START RACE`, `START TIME TRIAL`, `EXIT`.
5. Choosing race or time trial opens an owned-vehicle selector using the dealership/customisation cockpit-card style.
6. Client sends `RaceRequest` with intent only: event id, requested mode, and selected `VehicleId`.
7. Server validates ownership, vehicle build, time-trial tier rules where relevant, cooldown, route, and current race state. The client-selected vehicle is never trusted by itself.
8. Server creates or joins a race session, despawns/freezes the free-roam vehicle as needed, spawns the selected vehicle at the start grid/start line, seats the player, and locks movement.
9. Client shows staged countdown on screen.
10. Server releases racers and starts timing at countdown completion, not when the client says it started.

For mobile, use Roblox `ProximityPrompt` interaction where possible because it gives keyboard and touch support for free. Custom mobile buttons can come later if the prompt looks wrong.

The free-roam `Race` panel should become a browse surface:

- nearby events;
- daily featured race;
- current personal bests;
- queue status;
- track selected race route;
- fast "set waypoint" to start zone.

Do not make the free-roam Race panel the only entry method. Physical zones are clearer and more immersive.

### Race Entry Menu And Vehicle Selection

The menu should feel like part of the existing dealership/customisation family:

- read colours, fonts, corner radius, transparency, accent, disabled, back, and exit colours from `ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme`;
- reuse the cockpit card language from the customisation/free-roam car menus: image area, name, tier/rating badge, compact details, clear selected state;
- keep the bottom action rail simple with `START RACE`, `START TIME TRIAL`, and `EXIT`;
- avoid patching `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`; install isolated controllers under `Controllers.Racing`;
- support keyboard/mouse and touch from the first pass.

Recommended screen flow:

```text
NearbyStartZone
  -> RaceEntryMenu
  -> VehicleSelect
  -> QueueOrCreateSession
  -> Staging
  -> Countdown
  -> Running
  -> Finished
  -> ReturnToFreeRoam
```

Owned vehicle selection should call the existing garage/profile data path where practical, but the race server must re-check:

- selected `VehicleId` belongs to the player;
- selected cockpit and modules exist;
- performance tier/index can be recalculated or read from a server-generated build summary;
- vehicle is eligible for the selected event;
- the player is not already in a race/customisation/garage session.

For Phase 3, it is acceptable to show the same owned vehicle cards used by customisation and spawn the selected vehicle directly into the race session. Later, the free-roam vehicle the player drove into the zone can be preselected in the menu if it is eligible.

### Staging And Countdown

After vehicle selection:

- time trials use the first solo start point or `Grid_01`;
- multiplayer races use `SpawnGrid` positions by joined order or seeded qualifying order later;
- the server moves/spawns the selected vehicle to the staging point and seats the player;
- controls are disabled or the vehicle is anchored/held until `GO`;
- VFX/audio can pulse on `3`, `2`, `1`, `GO`;
- start timing and checkpoint acceptance begin only at server `GO`.

Freezing should be handled by the race session service, not by adding another bulky handoff in the main client bootstrap. If the existing driving controller needs a local input lock, expose a tiny BindableEvent/attribute bridge and keep the race logic in the isolated controller.

### Session Separation From Free Roam

Roblox does not give true per-player physics/world isolation inside the same Workspace automatically. For this project, use a layered approach:

1. **MVP same-server race instances:** create `Workspace.NeoTokyoRacersWorld.RaceInstances.<RunId>` and place/spawn racers plus collidable session assets there, ideally in a separated race pocket or cloned route space. This prevents free-roam players from physically touching race-only jumps/barriers because those objects are not in the free-roam route.
2. **Participant visibility filtering:** `RaceVisibilityClient_Active` locally hides non-participant characters/vehicles from active racers and hides active racers from non-participants where practical. Server state still decides participants; the client only handles presentation.
3. **Collision groups:** use collision groups to stop race participants, free-roam players, and session assets from interfering. Avoid creating unbounded per-run collision groups; prefer a small fixed set plus separated instance placement.
4. **Reserved-server option later:** for public competitive races, championships, or high-stakes leaderboards, consider TeleportService reserved servers. This is cleaner isolation but heavier UX, so it is not the first MVP path.

Time trials are simply sessions with one participant. Races are sessions with multiple participants who share the same instance and can see/collide with each other according to event rules.

Participant-only race assets:

- arrows, rings, route signs, and wrong-way indicators should render locally only for the active participant/session;
- collidable jumps, barriers, ramps, and boost pads should be created inside `RaceInstances.<RunId>.SessionAssets`;
- free-roam versions of those objects should be invisible/non-collidable or absent;
- future player-created races should only allow approved whitelisted asset templates.

The recommended next implementation should replace Phase 2's instant-start behavior with this menu/session flow before adding money rewards. It is a better foundation than paying rewards on top of a flow that will immediately be replaced.

## Checkpoint And Timing Rules

Server owns:

- race state;
- start time;
- checkpoint index;
- lap count;
- finish time;
- medal/placement calculation;
- reward grant.

Client owns:

- HUD timer display;
- checkpoint arrows/rings;
- countdown visuals;
- wrong-way warning display;
- split-time presentation.

Checkpoint validation:

- Checkpoints are ordered by `CheckpointIndex`.
- Player must hit the next expected checkpoint.
- Checkpoint parts should be generous invisible volumes, with visible client-only rings/arrows.
- Server should ignore repeated touches for the same checkpoint within a short debounce.
- Server should reject impossible jumps based on checkpoint order and minimum plausible travel time.
- Missing checkpoints means no finish, even if the player touches the finish line.

Lag handling:

- The server can use `os.clock()` for authoritative elapsed time.
- For fairness, starts should be synchronized by server countdown rather than first movement.
- Avoid per-frame server distance checks for every player. Use checkpoint touch/overlap events plus small validation checks.

## Time Trials

Time trials should ship first because they prove the whole route loop without matchmaking risk.

Core loop:

- Solo session only.
- Ghosts are deferred; start with personal best and medal targets.
- Restart prompt at finish and optional "Retry" shortcut.
- Medal result: bronze, silver, gold, platinum.
- Rewards scale by medal and vehicle tier.
- Store personal best per `EventId + VehicleTier`, and later optionally per vehicle instance/build.
- Hide/free-roam-separate the run so the player sees only their own active time-trial session, session arrows, and session assets.

Recommended reward shape:

```text
Bronze = 0.55x
Silver = 0.75x
Gold = 1.00x
Platinum = 1.30x
FirstPlatinumBonus = one-time extra
RepeatReward = reduced after best medal claimed
```

Fun additions:

- split deltas at each checkpoint;
- "next medal target" live delta;
- route mastery stars;
- daily time trial with boosted payout;
- clean run bonus for no reset/no missed checkpoint warnings.

## Multiplayer Races

Races should come after time-trial checkpoints are stable.

Recommended MVP matchmaking:

- Queue by `EventId` only.
- Use one open race category per multiplayer race event at launch.
- Min 2 players, max 6 players.
- Timeout after 20-30 seconds can offer "race with current players" if at least 2 are queued.
- Spawn players on route `SpawnGrid` points, freeze for countdown, then release.
- During a race, disable re-entry into other race zones for participants.
- Race participants move into the same race instance so they see each other but not unrelated free-roam players.
- Show recommended tier/performance on the entry menu, but do not use it to split the queue.

Placement:

- `Gold` = 1st.
- `Silver` = 2nd.
- `Bronze` = 3rd or configured `BronzePlaceMax`.
- DNF after timeout gets no or tiny consolation reward.

Fairness:

- Keep launch races open-category to protect queue health and reduce wait times.
- Use track design, recommended performance labels, rubber-band-light catch-up tuning, and event difficulty to keep races readable without hiding players from each other.
- If high-tier dominance becomes a real issue, add optional spec/loaner/ranked events later; do not make them the default queue until player population supports it.

## Anti-Cheat And Robustness

High-priority server validations:

- Player is seated in a `VehicleSeat` inside a runtime vehicle.
- Runtime vehicle `OwnerUserId` matches the player, unless future party/team races allow loaners.
- Vehicle is under `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles`.
- Vehicle has current `PerformanceTier` written by `VehiclePerformanceRuntimeService_Active`.
- Start zone entry is near the event start part on the server.
- Checkpoints arrive in sequence.
- Segment times are not physically impossible for the route and tier.
- Reward grants are idempotent by `RaceRunId`.

Avoid:

- client-submitted finish times;
- client-submitted checkpoint counts;
- client-submitted rewards;
- large client-side race state that the server trusts;
- scanning every route part every frame on the server.

## UI / UX

During entry:

- In-world prompt over the start zone.
- Themed menu with track image, map image, event name, route stats, recommended performance, medal/placement rewards, and bottom `START RACE`, `START TIME TRIAL`, `EXIT` buttons.
- Owned-vehicle picker using dealership/customisation cockpit cards and tier/rating badges.
- Clear error messages: wrong time-trial tier, not in vehicle, already queued, race full.

During run:

- timer;
- current lap/checkpoint;
- next checkpoint arrow;
- route arrow assets from `ArrowMarkers`;
- speed/boost HUD remains visible;
- compact medal target display for time trials;
- position list for races;
- wrong-way/missed checkpoint prompt.

At finish:

- result medal or placement;
- time and best time;
- reward breakdown;
- retry button for time trials;
- requeue / return to free roam for races.

Keep race HUD isolated under `Controllers.Racing.RaceHudClient_Active`; do not add it to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

## Persistence And Economy

First phase can grant current-session cash through the existing garage/profile bridge, but the clean target is a small `RaceRewardService_Active` that owns race reward writes and mirrors through `ProfileService_Active`.

Data to persist later:

```text
Profile.Racing.TimeTrialBest[eventId][tier] = {
  BestSeconds,
  BestMedal,
  BestVehicleId,
  UpdatedAt,
}

Profile.Racing.RaceStats[eventId] = {
  Starts,
  Finishes,
  Wins,
  Podiums,
}

Profile.Racing.ClaimedOneTimeBonuses[bonusId] = true
```

Do not store every run forever. Store bests, aggregate stats, and recent daily/weekly state.

## Suggested Implementation Phases

### Phase 1 - Race Route And Config Audit

Read-only script:

- inspect `Workspace.NeoTokyoRacersWorld.RaceRoutes`;
- list route/checkpoint/start zone candidates;
- inspect free-roam Race panel state;
- inspect performance tier attributes on spawned vehicles;
- inspect profile reward write options.

Generated as:

```text
scripts/roblox_racing_phase1_audit_and_sample_route_setup.lua
```

The same script also includes a compressed optional `SETUP_SAMPLE` mode for the safe, non-gameplay part of Phase 2.

### Phase 2 - Time Trial Route Authoring Tools

Command-bar setup script:

- create a sample `RaceRoutes.ShiftedCanalSprint`;
- create editable start zone, finish line, and checkpoint placeholders;
- create `Config.Racing.TimeTrialCatalog.ShiftedCanalSprint`;
- add medal time attributes for E-S tiers;
- add no gameplay logic yet.

The route/config scaffold portion is included in the Phase 1 script behind `MODE = "SETUP_SAMPLE"`. Keep gameplay services for a later phase after the audit and route placement are confirmed.

### Phase 3 - Race Entry Menu, Vehicle Selection, Staging, And Isolation

Supersede Phase 2's instant-start prompt with the real entry flow before adding rewards:

- `RaceEntryMenuClient_Active` opens from the existing start-zone prompt;
- menu shows `TrackImage`, `MapImage`, route info, recommended performance, time-trial tier/medal previews or open-category race placement previews, and `START RACE` / `START TIME TRIAL` / `EXIT`;
- `RaceVehicleSelectClient_Active` shows owned vehicle cards using the dealership/customisation theme and cockpit-card style;
- `RaceEntryService_Active` validates selected vehicle ownership, runtime performance attributes, time-trial tier rules where relevant, and event eligibility;
- `RaceSessionService_Active` creates a session, moves/spawns the selected vehicle to the start line/grid, seats the player, locks movement, runs countdown, then releases;
- `RaceInstanceService_Active` creates a lightweight session container and begins the separation path for time trials and races;
- `RaceVisibilityClient_Active` hides non-participant players/vehicles and shows only participant/session route assets where practical;
- route guide starts reading `ArrowMarkers` and future `SessionAssetTemplates`.

Verify:

- pressing `E`/touch opens the menu instead of starting immediately;
- `EXIT` cleanly returns to free roam;
- owned vehicle cards match the current customisation/dealership visual style;
- selecting an eligible vehicle teleports/spawns it to the start line;
- player and vehicle cannot move until countdown reaches `GO`;
- time-trial still records ordered checkpoints and finish time after release;
- non-participants do not see active session-only arrows/assets, and racers do not see unrelated free-roam players where the same-server visibility filter supports it.

This phase can safely compress the UI menu, vehicle selection, staging, and the first same-server session container because they are all part of replacing the entry flow. Do not also add cash rewards or multiplayer matchmaking in this phase.

Generated as:

```text
scripts/roblox_racing_phase3_entry_menu_staging_session.lua
```

The generated script implements the menu, owned-vehicle picker, selected-vehicle spawn through existing garage actions, start-grid teleport/freeze/countdown, server timing after `GO`, lightweight `RaceInstances.<RunId>`, and first local participant visibility filtering. It does not yet clone the route into a separate race pocket, so collidable race-only jumps/barriers should wait for a later session-asset phase.

### Phase 4 - Time Trial Results Pack

Phase 2 already installed the first working solo time-trial runtime and route-definition abstraction through:

```text
scripts/roblox_racing_phase2_solo_time_trial_mvp.lua
```

Phase 4 should build on the confirmed Phase 3 menu/session flow, then add the complete non-economy time-trial finish loop:

Install:

- server-authoritative bronze/silver/gold/platinum medal calculation from per-route, per-tier config;
- finish/results UI with medal, final time, split deltas, next-medal target, `RETRY`, and `EXIT`;
- in-session personal best tracking;
- persisted personal-best scaffolding only if the existing profile bridge is clean to use without fragile garage-source edits.

Verify:

- medal changes when the selected vehicle tier changes;
- personal best updates only when time improves;
- `RETRY` restages the same route without returning to free roam;
- `EXIT` restores free roam visibility/control cleanly.

This safely combines medals, result UI, retry/exit, and best-time display because they all sit on the same finish-state flow. Do not add cash rewards in this phase unless the profile write path is already verified and idempotent.

Generated as:

```text
scripts/roblox_racing_phase4_time_trial_results_pack.lua
```

The generated script patches only `TimeTrialService_Active` and `RaceEntryMenuClient_Active`. It keeps personal bests session-only and leaves economy/profile writes for the guarded Rewards Pack.

### Phase 5 - Route Guidance And Session Asset Pack

Add the navigation layer before multiplayer so the route feels fair:

- local checkpoint rings and checkpoint-number clarity;
- `ArrowMarkers` rendering through `RaceRouteGuideClient_Active`;
- wrong-way/missed-checkpoint prompts;
- participant-only decorative route props;
- isolated spawning for collidable race-only ramps, jumps, gates, barriers, and boost strips under `RaceInstances` or a separated race pocket.

Verify that free-roam players do not see or collide with race-only assets, and racers do not see unrelated free-roam players/assets where the same-server visibility filter supports it.

Generated as:

```text
scripts/roblox_racing_phase5_route_guidance_session_assets.lua
```

The generated Phase 5 keeps the first pass visual/local only: checkpoint/finish frames, dynamic next-gate chevrons, authored `ArrowMarkers`, wrong-way prompt, route-guide config attributes, and authoring folders. Phase 5B then disables the older Phase 3/4 checkpoint marker so the new route guide is the single visual owner. Phase 5F is now the preferred visual direction: checkpoint text appears above the physical checkpoint with a small configurable transparent black pill behind only the text, generated checkpoint frames are off by default, dynamic arrows remain active, and `WRONG WAY` appears only after `3` seconds of sustained wrong-way driving. Collidable ramps, jump pads, boost strips, gates, and barriers are intentionally deferred until the race-pocket/collision-group layer is stronger.

### Phase 6 - Rewards Pack

Install rewards after result-state idempotency is proven:

- `RaceRewardService_Active`;
- server cash/profile grant path;
- first-time medal bonuses for time trials;
- reduced repeat rewards;
- placement rewards for multiplayer races once Phase 8 lands.

Verify reward cannot be double-claimed by touching finish repeatedly, retrying quickly, rejoining, or sending repeated client events.

Generated as:

```text
scripts/roblox_racing_phase6_time_trial_rewards_pack.lua
```

The generated Phase 6 installs a guarded time-trial reward service, creates `Config.Racing.Rewards`, adds a tiny server-only garage cash bridge so rewards update the usable garage cash profile, patches Phase 4 finish payloads with reward fields, and adds a payout line to the result panel. Phase 6B (`scripts/roblox_racing_phase6b_global_reward_config_rounding.lua`) is the preferred balancing follow-up: it rounds prizes to the nearest `$250`, moves multipliers into `Config.Racing.Rewards.TimeTrial` and `Config.Racing.Rewards.Race`, removes old per-track multiplier attributes, and leaves event folders with track-specific `BaseReward`.

### Phase 7 - Free-Roam Race Panel Integration

Replace only the isolated Race placeholder in `FreeRoamNavController_Active` or, better, extract a new `RaceMenuController`.

Features:

- list nearby/featured events;
- show recommended tier/performance;
- track route/start zone;
- show personal bests.

This is a UI phase and should not change checkpoint timing.

### Phase 8 - Open-Category Multiplayer Race MVP

Install:

- `RaceMatchmakingService_Active`;
- one queue per race `EventId`, with no launch tier brackets;
- queue UI showing open category, recommended performance, min/max players, and timeout;
- grid spawn/freeze/release;
- placement scoring;
- race result rewards.

Verify in local server with 2-4 players.

### Phase 9 - Competitive Features

Add after MVP stability:

- daily/weekly time trial;
- friends/global leaderboard through OrderedDataStore;
- ghost data if performance allows;
- seasonal race events;
- party/private race queue;
- optional spec/loaner/ranked race variants if open-category fairness or late-game dominance becomes a real issue;
- route difficulty labels and recommended tier.

### Phase 10 - Player-Created Race Foundation

Add after official races, rewards, and multiplayer are stable:

- route creator/edit mode for placing start, checkpoints, finish, spawn grid, and arrow hints;
- route validation service;
- private draft storage in the player's profile;
- private/friends test lobbies using the same `RaceRouteDefinition` contract;
- publishing/moderation workflow later, before public discovery or full rewards.

## Performance Notes

- Keep checkpoints as simple anchored invisible parts.
- Use `Touched` or `GetPartsInPart` only around active checkpoint volumes, not all route geometry.
- Only replicate race state for active racers.
- Render checkpoint rings/arrows locally.
- Render decorative route arrows locally from normalized `ArrowMarkers`; do not make them server physics objects during races.
- Keep collidable race-only assets in session instances/pockets, not in the shared free-roam route.
- Avoid per-frame visibility work over every descendant. Cache participant vehicles/characters and update on session membership changes, character spawn, vehicle spawn, and a modest heartbeat if needed.
- Do not create/destroy lots of UI every frame; update labels and reuse frames.
- Avoid unbounded race logs in memory.
- Cap active races per server if matchmaking later supports many routes.

## Worries / Doubts

- The user moved the first route zones/checkpoints in Studio after Phase 1 and refreshed the repo mirror before Phase 2 was generated. The mirror now shows `ShiftedCanalSprint` with 14 checkpoints, start zones, spawn grid, and finish line.
- The user confirmed Phase 4's time-trial medal/results/retry flow is working well. Phase 5 added route guidance and local-only session visuals; Phase 5B fixed duplicate old/new checkpoint markers, Phase 5C was not enough to solve visual obstruction, Phase 5D's fixed badge lost the spatial cue, Phase 5E restored world-space text, and Phase 5F is the preferred configurable small pill label. Phase 6 was reported working well, and Phase 6B is generated to move reward multipliers into global `Rewards.TimeTrial` / `Rewards.Race` folders and round prizes to the nearest `$250`.
- The GDD PDF could not be read from this environment, so exact design requirements from that document still need confirmation.
- Player-created races are future-proofed at the data-contract level only. The actual creator UI, validation, moderation, and published-route storage are intentionally deferred until after official races prove the loop.
- Arrow assets are planned as both route hints and participant-only session visuals, but actual art style and asset IDs still need choosing/uploading before the route-guide phase.
- True per-player physical isolation in the same exact world location is limited in Roblox. Same-server sessions should use separated race instances/pockets plus visibility filtering and collision groups. Fully isolated competitive races may eventually deserve reserved servers.
- Selecting an owned vehicle for a race should avoid another large fragile patch against `GarageActionController_Shadow_Disabled`; prefer a small racing profile/vehicle bridge or existing safe garage actions where possible.
- Cash/profile writes are currently tied to a large legacy garage action layer plus ProfileService bridge. Rewards should avoid another fragile patch ladder against `GarageActionController_Shadow_Disabled`.
- Multiplayer race fairness depends on Roblox networking and vehicle physics authority. Server timing/checkpoints can be authoritative, but moment-to-moment vehicle movement remains client/network-owner sensitive.
- Multiplayer races are now intentionally open-category at launch, so the main fairness risk is high-tier vehicles dominating open races. Watch live/local-server testing before adding spec, loaner, ranked, or restricted events; avoid tier brackets until the player population can support extra queues.
- Checkpoint volumes must be forgiving enough for hovercar speed, especially mobile steering, but not so huge that shortcuts become normal.

## Rollback Strategy

Race work should be removable by disabling/deleting only:

- `ServerScriptService.NeoTokyoRacers.Services.Racing`;
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing`;
- `ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Racing`;
- `ReplicatedStorage.NeoTokyoRacers.Config.Racing`;
- route folders under `Workspace.NeoTokyoRacersWorld.RaceRoutes`.

Do not patch driving physics, VFX, dealership, garage customisation, or the main client bootstrap for the first race phases.
