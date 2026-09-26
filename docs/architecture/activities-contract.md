# Activities contract (Street Life RP features)

Status: **contract for parallel implementation**, 2026-09-26. Plan: Street Life RP build (Step 1 foundation → Step 2 feature agents → Step 3 serial integration). Step 1 installs everything in "Foundation (Step 1)" below, including inert stubs at every feature path. Feature agents replace only the bodies of the modules they own. Where this contract and the code disagree, the contract wins: raise any needed change with the integrator instead of editing shared files.

Target place: Space Racers v2 (71491191583884). Rules: AGENTS.md, docs/13, docs/architecture/architecture-programme.md (new feature checklist).

## Conventions

- **Server module shape** (started by `ServerScriptService.ServerBase` entries, never self-starting):
  ```lua
  local Service = {}
  local state = "idle"
  function Service.start()
      if state ~= "idle" then return end
      state = "starting"
      local ok, message = xpcall(function() --[[ connect, register ]] end, debug.traceback)
      state = ok and "ready" or "failed"
      assert(ok, message)
  end
  return Service
  ```
- **Client view shape** (mounted by `ActivityClient`, which is started by `ClientBase`): `return { Mount = function(ctx) end, OnEvent = function(payload) end }`.
- **Pure rules modules** hold all maths and decision logic (pay, grading, eligibility, state transitions). They take no game services, no instances and no `require` of game modules, so tests can `loadstring` them. Tests follow `scripts/route_guide/tests.lua`: sources are fetched from `http://127.0.0.1:8767/...` and the test returns `{failures, results}`.
- **Server authority.** Cash, XP, results and positions are decided on the server. Clients send intents only. Never trust client distances, times or prices.
- **Cash.**
  - Grants: only through `ActivityPayout.Pay`, which uses EconomyServer `GrantCash` with a unique `CommandId`.
  - Spends: only through `ActivityPayout.Debit`, which uses `MoneyService.Debit` after all validation.
  - No other Cash writes.
- **Config.** Tunables are attributes on `ReplicatedStorage.Config.Activities.<Feature>`. Read them with bounded, finite defaults in code (`tonumber(attr) or default`, clamped).
- **World lookups.** Find world objects by CollectionService tag. Streaming is on, so the server may read the world freely, but clients must tolerate streamed-out parts.
- **UI.** Only the theme tokens (`ctx.Theme`), `RacingUIComponents` (`ctx.UI.Button`, `ctx.UI.Label`), `ResponsiveUIFoundation` and `ctx.UI` helpers. No new colours or fonts. Touch targets are at least 44 px when `ctx.IsMobile`.
- **Vehicles.**
  - A player's car is in `Workspace.World.Runtime.PlayerVehicles` with attribute `OwnerUserId`. `PrimaryPart` is `CockpitRoot_DoNotRename` and carries all the mass (other parts are massless). `DriverSeat` is a `VehicleSeat`.
  - Driving is keyed to `OwnerUserId`, so a non-owner in another seat never drives.
  - Forces scale with `root.AssemblyMass`, so anything welded or seated (passengers, NPC rigs) must be made massless.
  - Vehicles never collide with each other.
- **Races and garages.** Never start or continue an activity while `RaceParticipant`/`RaceRunId` (vehicle), `RaceQueueActive`, `GarageSessionActive` or `OwnedGarageInside` (player) is set.

## Foundation (Step 1, integrator)

### Instances

**Remotes:**

- `ReplicatedStorage.Remotes.Activities.ActivityInvoke`: RemoteFunction. The client calls `ActivityInvoke:InvokeServer(action, args)`; the reply is a table with `Ok`, `Message` and feature fields.
- `ReplicatedStorage.Remotes.Activities.ActivityEvent`: RemoteEvent, server → client only. The payload is `{Type = "<Kind>:<Event>", ...}`.

**Server modules** (`ServerStorage.Modules.Game.Activities`):

| Module | Owner |
|---|---|
| ActivityService, ActivityPayout, ProgressionService, ProgressionRules (pure) | foundation |
| CourierJob (stub), CourierRules (stub, pure) | Agent A |
| PassengerService (stub), TaxiJob (stub), TaxiRules (stub, pure) | Agent B |
| DuelService (stub), DuelRules (stub, pure) | Agent C |

**Client modules** (`ReplicatedStorage.Modules.Game.Activities`):

| Module | Owner |
|---|---|
| ActivityClient | foundation |
| CourierClientView (stub) | Agent A |
| PassengerClientView (stub), TaxiClientView (stub) | Agent B |
| DuelClientView (stub) | Agent C |

**Config folders** (`ReplicatedStorage.Config.Activities`), created with the attributes below. Agents may add attributes to their own folder.

- **Progression:** XpBase 250, XpExponent 1.35, MaxRank 100, RankCashPerRank 500, DriveXpPerCash 0.1, RaceXpDivisor 500, RaceXpMin 10.
- **Core:** JobHourlyCashCeiling 40000, ExitGraceSeconds 10, DistrictMinX -250, DistrictMaxX 2600, DistrictMinZ -4150, DistrictMaxZ 550.
- **Courier:** Enabled true. Agent A adds the rest.
- **Taxi:** Enabled true.
- **Passengers:** Enabled true, DefaultAccess "Friends", SeatOffsetX 0, SeatOffsetY 1.45, SeatOffsetZ 11.
- **Duels:** Enabled true, StakesEnabled true, Stakes "0,5000,25000,100000", StakeMinRank 3.
- **Visits:** Enabled true, MaxVisitorsPerGarage 8.

**Feature flags** (server, `Core.FeatureFlags.IsEnabled(key, default)`): `EnableDriverRank`, `EnableCourier`, `EnableSkyTaxi`, `EnablePassengers`, `EnableDuels`, `EnableDuelStakes`, `EnableGarageVisits`. Features must check their flag and their config `Enabled`.

**Economy reasons** added to EconomyServer `GENERIC_GRANT_REASONS`: `JobPayout`, `TaxiFare`, `DuelPot`, `DuelRefund`, `RankReward`.

**Saved profile fields** (PlayerProfileSchema defaults and Normalize; SchemaVersion stays 1):

- `Progression = { Xp = 0, Rank = 1, LifetimeXp = 0 }`
- `Settings = { PassengerAccess = "Friends" }`, with valid values Friends / Anyone / Nobody.

**Player attributes** (server-set, replicated): `Rank`, `XpIntoRank`, `XpForNext`, `PassengerAccess`, `ActivityKind` ("" when idle), `ActivityId`.

### ActivityInvoke action allowlist (predeclared; features implement theirs)

| Owner | Actions |
|---|---|
| Core | `GetState`, `Cancel`, `SetPassengerAccess {Access}` |
| Courier | `CourierGoToHub`, `CourierStart {HubId, Variant = "Standard" \| "Hot" \| "Fragile"}` |
| Passengers | `Ride {OwnerUserId}`, `LeaveRide` |
| Taxi | `TaxiSetDuty {OnDuty}`, `TaxiRequest`, `TaxiCancelRequest`, `TaxiAcceptRequest {RequesterUserId}` |
| Duels | `DuelChallenge {TargetUserId, Stake}`, `DuelRespond {DuelId, Accept}` |

Garage visits use `OwnedGarageInvoke` (new actions `VisitGarage {OwnerUserId}`, `LeaveVisit`, `GetVisitableGarages`), all owned by Agent D.

### Server API

```lua
-- ActivityService (ServerStorage.Modules.Game.Activities.ActivityService)
ActivityService.Register(kind: string, handlers: {
    Actions: { [actionName]: (player, args) -> { Ok: boolean, Message: string?, ... } },
    OnCancel: ((player, record, reason: string) -> ())?,  -- called by core cleanup; must clean up and not pay
    RequiresVehicle: boolean?,                              -- default true: exit > ExitGraceSeconds / despawn cancels
})
ActivityService.Begin(player, kind, data: table?) -> (record?, err: string?)
    -- fails with a player-facing message if busy (another activity, race, garage, queue)
    -- record = { Id = "<kind>_<n>", Kind, StartedAt = os.clock(), Data = data }
ActivityService.Current(player) -> record?
ActivityService.End(player, recordId, outcome: "Complete" | "Cancelled" | "Failed")  -- no OnCancel call
ActivityService.Cancel(player, reason: string)                                        -- calls OnCancel
ActivityService.IsBusy(player) -> (boolean, reason: string?)   -- includes races, garages, queue
ActivityService.Push(player, payload)                          -- ActivityEvent:FireClient
ActivityService.PushAll(payload)
ActivityService.GetDrivenVehicle(player) -> Model?  -- player seated in the DriverSeat of their own car
ActivityService.GetVehicle(player) -> Model?        -- their spawned car, seated or not
ActivityService.Config(name: string) -> Folder      -- ReplicatedStorage.Config.Activities[name]
ActivityService.Number(folder, key, default, min, max) -> number
ActivityService.RoadGraph() -> graph                -- RoadRouting.LoadGraph(RoadGraphData), cached
ActivityService.RandomRoadPoint(from: Vector3, minStuds, maxStuds, rng: Random?) -> Vector3?
    -- a road-graph node inside the Core District* bounds, [min, max] studs from `from`; Y = 101
ActivityService.NewId(prefix: string) -> string     -- unique per server
ActivityService.Signals.Ended  -- Core.Signal (player, record, outcome)
-- OnCancel runs after the record is cleared and Ended has fired; handlers must clean up only and must not call Begin.

-- ActivityPayout
ActivityPayout.Pay(player, {
    Cash: number?, Xp: number?, Reason: "JobPayout" | "TaxiFare" | "DuelPot" | "DuelRefund",
    CommandId: string, Label: string?, JobCeiling: boolean?,  -- JobCeiling=true for JobPayout/TaxiFare
}) -> { Ok: boolean, Cash: number, Xp: number, Capped: boolean, Message: string? }
ActivityPayout.CanAfford(player, amount) -> boolean
ActivityPayout.Debit(player, amount, reason: string) -> (ok: boolean, message: string?)
    -- MoneyService.Debit on the live profile + MarkDirty; no yield; call only after all validation

-- ProgressionService
ProgressionService.AddXp(player, amount, reason: string, commandId: string) -> { Xp, Rank, RankedUp: boolean }
ProgressionService.GetRank(player) -> number
ProgressionService.RankChanged  -- Core.Signal (player, newRank, oldRank)
```

### Client API

```lua
-- ActivityClient mounts views in a fixed order: Courier, Passenger, Taxi, Duel.
ctx = {
    Player = LocalPlayer,
    Invoke = function(action, args) -> reply,        -- pcall-wrapped ActivityInvoke
    Gui = ScreenGui "ActivityHud",                    -- DisplayOrder 84, IgnoreGuiInset, ResetOnSpawn false
    Root = Frame,                                     -- scaled design root inside Gui
    IsMobile = boolean,
    Theme = { Panel, PanelDeep, PanelSoft, PanelBlue, Outline, OutlineSoft, Telemetry, ElectricBlue,
              HighSpeed, Danger, Text, Muted, Disabled, Font },
    RouteGuide = RouteGuide,                          -- ReplicatedStorage.Modules.Game.UI.RouteGuide
    Toast = function(text, seconds?),                 -- ShowTopNotification
    UI = {
        Button = function(parent, props) -> TextButton,     -- RacingUIComponents.Button
        Label = function(parent, props) -> TextLabel,
        Strip = { Set = function(kind, text, colour?), Clear = function(kind) },  -- top-centre job strip
        Offer = function({ Title, Body, Buttons = { { Text, Accent?, OnClick } }, Timeout? }) -> close(),
        Countdown = function(goAtServerTime: number, label: string?),
        Beacon = function(id, position: Vector3, colour) -> remove(),        -- world light pillar (client-only)
    },
    Jobs = { AddEntry = function({ Id, Title, Subtitle, Order, Buttons = { { Text, OnClick, Enabled? } } }),
             Refresh = function() },                  -- JOBS panel opened by the HUD JOBS button
}
```

### HUD (foundation)

- **Desktop/mobile free-roam HUDs:**
  - A rank strip above the cash chip.
  - A rank-up card.
  - A JOBS action button that fires `PlayerScripts.Runtime.UI.OpenJobs` (BindableEvent).
  - A Settings **PASSENGERS** segmented control (FRIENDS / ANYONE / NOBODY) that calls `SetPassengerAccess`.
- **The job strip** is shown by `ActivityClient` in `ActivityHud`, top centre, below the onboarding objectives area.

## Feature ownership (Step 2 agents)

Each agent writes only inside `scripts/activities/<feature>/`:

- after-sources, named after the Roblox module;
- `tests.lua`;
- `spec.json` (feature_installer format below);
- `CONTRACT.md` (acceptance contract and test checklist).

Agents never write to Studio. Existing sources an agent may modify start from the captured blob in `roblox/captures/route-smooth-after/capture.json`: copy the file from `roblox/source_store`, then edit it.

| Agent | New/stub modules it fills | Existing sources it may modify | World/config it may add |
|---|---|---|---|
| A Courier | CourierJob, CourierRules, CourierClientView | none | 3 hub pads under `Workspace.World.Jobs.CourierHubs` (tag `CourierHub`), Courier config attributes |
| B Passengers + Taxi | PassengerService, TaxiJob, TaxiRules, PassengerClientView, TaxiClientView | `ServerStorage.Modules.Game.Garage.VehicleBuildService` (add PassengerSeat) | Passengers/Taxi config attributes |
| C Duels | DuelService, DuelRules, DuelClientView | none | Duels config attributes |
| D Garage visits | (new pure `ServerStorage.Modules.Game.Garage.GarageVisitRules`) | `OwnedGarageManagement`, `OwnedGarageBrowserUI` (+ `GarageInteriorModeUI` only if unavoidable) | Visits config attributes; `Config.Garage.Interior.EnableVisitors = true` |

### feature_installer spec format

```json
{ "task": "...", "lane": "Standard|High-Risk", "contract": "...", "verification": "...",
  "operations": [
    { "kind": "source", "path": ["ServerStorage","Modules","Game","Activities","CourierJob"], "file": "scripts/activities/courier/CourierJob.lua" },
    { "kind": "module", "parent": ["ServerStorage","Modules","Game","Garage"], "name": "GarageVisitRules", "file": "..." },
    { "kind": "attribute", "path": ["ReplicatedStorage","Config","Activities","Courier"], "key": "BasePay", "value": 1500 },
    { "kind": "instance", "parent": ["Workspace","World","Jobs","CourierHubs"], "name": "Hub_Dealership", "class": "Part",
      "properties": { "Anchored": true, "CanCollide": false, "Size": {"type":"Vector3","value":[40,1,40]},
                      "Position": {"type":"Vector3","value":[x,y,z]}, "Material": {"type":"Enum","value":"Neon"},
                      "Color": {"type":"Color3","value":[0.169,0.882,0.855]}, "Transparency": 0.35 },
      "attributes": { "HubId": "Dealership", "DisplayName": "Dealership Depot" }, "tags": ["CourierHub"] }
  ] }
```

The source operations for stub modules replace the installed stub bodies.
