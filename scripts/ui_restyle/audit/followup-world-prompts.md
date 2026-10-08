# Follow-up audit: world prompts (server side)

Group: `followup-world-prompts`
Date: 2026-10-09. Read-only. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.

## Coverage

All five listed scripts exist at the listed paths and were read completely.

| Script (all ModuleScript, under `ServerStorage.Modules.Game`) | Lines | Chars | Read |
|---|---:|---:|---|
| `Racing.TimeTrialServer` | 1,427 | 50,871 | 1-1427, all |
| `Vehicles.VehicleAccessServer` | 140 | 4,407 | all |
| `Garage.OwnedGarageManagement` | 415 | 88,342 | 1-415, all (very long lines; line 383 is 2,159 chars, read in full) |
| `Garage.OwnedGarageInterior` | 57 | 4,412 | all |
| `Garage.OwnedGarageFinish` | 96 | 12,705 | all |

Also read, because the findings depend on them: `ServerScriptService.ServerBase` (all), `Garage.OwnedGarageServer` (all),
`ServerStorage.Modules.Core.FeatureFlags` (all), `ReplicatedStorage...Racing.RaceLifecyclePresentationClient` (all, 309 lines),
and the prompt sites in `OwnedGarageBrowserUI` (112-134), `GarageEntranceClient` (120-200), `PassengerClientView` (55-95),
`JobClient` (176-225).

Line numbers below are script line numbers in live Studio.

## Headline findings

1. **None of the five scripts builds any GUI.** No ScreenGui, BillboardGui, SurfaceGui, TextLabel, UDim2, font or UI colour
   in any of them (pattern count: zero for all of these). Their whole player-facing surface is the engine-drawn
   ProximityPrompt, plus the text and numbers they send in remote payloads.
2. **Every world prompt in the game is `Style = Default`.** Ten prompt families exist (table below). No script uses
   `ProximityPromptService.PromptShown`, `PromptHidden` or `InputHoldBegin` (grep: no matches). There is no custom prompt
   renderer today, so the sheet's Start banner with a key cap is a new piece of UI, not a reskin.
3. **`Style` on the race-start prompt is re-asserted by the server every 3 seconds** (`TimeTrialServer` 1311, loop at
   1413-1418). A second server owner that sets `Custom` would be overwritten and would flip-flop. `Style` can only be
   changed inside `TimeTrialServer`, or locally on the client.
4. **A client-only route exists** and keeps all five scripts untouched: a new client module sets `Style = Custom` locally on
   known prompts when the new style is on and draws the banner from `PromptShown` / `PromptHidden`. With the style off it
   does nothing, so the old prompts are exactly as today. Two engine behaviours it relies on need a Play check (see
   "Unknowns").
5. **`TimeTrialServer` is a High-Risk module** (personal bests at 750-774, reward grant at 776, remote handler at 1330).
   Editing it for a one-line `Style` change means replacing the source of the module that writes PBs and grants Cash. The
   client-only route avoids that.
6. **The client cannot read `Core.FeatureFlags`.** It lives at `ServerStorage.Modules.Core.FeatureFlags` and every caller is
   a server script. The style switch needs a replicated value (already noted in `foundation-startup.md` section 7).
7. **The time-trial result payload has no XP field** (778-816). The sheet's results screen shows driver XP as a hero number
   "from the server result payload"; for time trials that figure is not in this payload.

## Every world prompt, live (Edit mode) and runtime

Live query found 6 ProximityPrompt instances in Edit mode. The rest are created at runtime.

| Prompt name | Created by | Parent | Action / Object text | Keys | Dist | Style | Notes |
|---|---|---|---|---|---:|---|---|
| `RaceEntryPrompt` | `TimeTrialServer` 1293-1314 (server, runtime) | each `Workspace.World.RaceRoutes.<Route>.StartZones.<Zone>` part (4 live zones, 34x12x34) | zone attr `PromptActionText` ("Join Race", "Start Time Trial") or "Open Race Menu" / "Race" or "Time Trial" | E, ButtonX, click | 24 | Default, set 1298 and re-set 1311 | Serves both Race and TimeTrial zones |
| `EnterVehiclePrompt` | `VehicleAccessServer` 88-106 (server, runtime) | the vehicle's `VehicleSeat` | "Enter" / "Vehicle" | E (pad and click left at engine default: ButtonX, clickable) | 12 | never set, so Default | Visible to every player; only the owner can use it (53) |
| `DriveOutPrompt` | `OwnedGarageManagement` 188-201 (server, runtime) | `DisplaySpaceMarkers.<SlotId>` in the interior | "Drive Out" / vehicle full name or "Empty Display Space" (211) | E, ButtonX, click | 12 | never set, so Default | attr `OwnedGarageAvailable` |
| `FootExitPrompt` | template `ServerStorage.Assets.Garage.Templates.StarterTwoBay.FootExitMarker` | cloned with the interior | "Exit Garage" / "Garage Door" | E, ButtonX, click | 10 | Default (instance) | Template Hold 0.10 forced to 0 at runtime (223, 145) |
| `ManageGaragePrompt` | template `...StarterTwoBay.ManagementDesk.DeskPromptAnchor` | cloned with the interior | "Manage Garage" / "Garage Desk" | E, ButtonX, click | 10 | Default (instance) | Template Hold 0.15 forced to 0 at runtime (237, 145) |
| `OwnedGarageDriveInEntryPrompt` | static instance in `Workspace.World.OwnedGarageExteriors.STARTER_TWO_BAY.DriveInEntrance` | - | "DRIVE INTO GARAGE" / "KANDA TWO-BAY" | E, ButtonX, click | 20 | Default (instance) | No server handler. Handled on the client by `OwnedGarageBrowserUI` 120-127 via attr `OwnedGarageEntryPrompt` |
| `OwnedGarageFootEntryPrompt` | static, `...STARTER_TWO_BAY.FootEntrance` | - | "OPEN GARAGE" / "KANDA TWO-BAY" | E, ButtonX, click | 12 | Default (instance) | Same |
| `Canonical<Mode>` (Dealership, Customisation, DriveIn) | `GarageEntranceClient` 152-163 (client, runtime) | entrance parts | "Enter" / per-entrance text | E, ButtonX, click | config `PromptDistance` or 14 | Default, set at 154 | Client-local |
| passenger "RIDE" | `PassengerClientView` 69-79 (client) | other players' seats | "RIDE" / owner display name | F, ButtonY | 14 | never set | `UIOffset (0,40)` so it "sits under the server's Enter prompt" (78) |
| `JobPrompt` | `JobClient` 195-211 (client) | local Attachment on the player's own car | per job kind / offer label | E | 30 | never set | `Exclusivity = AlwaysShow` |

Two archive copies of the template prompts also exist under `ServerStorage.Archive.ZZZ.StarterTwoBay` (disabled, not used).

`ProximityPromptService`: `Enabled = true`, `MaxPromptsVisible = 16`. `Workspace.StreamingEnabled = true`, so prompt
instances are destroyed and recreated on the client as their parents stream out and in.

Text casing is inconsistent across families: "Join Race", "Enter", "Drive Out", "Exit Garage" (title case) against
"DRIVE INTO GARAGE", "OPEN GARAGE", "RIDE" (capitals). The sheet wants capitals everywhere.

---

## 1. `ServerStorage.Modules.Game.Racing.TimeTrialServer` (1,427 lines)

### 1.1 Purpose and lifecycle
Staged time-trial service, and the owner of the race-start prompt for both Race and TimeTrial start zones.

- Started by the server composition root: `ServerScriptService.ServerBase` 69-75 registers it with dependencies
  GarageServer, RaceRewardsServer, PersonalBestServer, RaceAssetsServer; `Core.ServerLifecycle` calls `Service.start()` (4).
- Single-start guard and `xpcall` wrapper (5-7, 1422-1424). No stop or cleanup function.
- Connections held for the server's life: `RaceRequest.OnServerInvoke` (1330), `Players.PlayerRemoving` (1406), one
  `Touched` per gate part cached in `gateConnections` and never disconnected (948-966), one `Triggered` per prompt (1303).
- Loops: prompt refresh every 3 s forever (1413-1418); one staging thread per run polling at 0.05 s and 0.03 s
  (1136-1223).

### 1.2 Instance tree
No GUI. World instances only:

- `RaceEntryPrompt` on every start-zone part (1280-1315). The legacy `TimeTrialStartPrompt` is destroyed if found
  (1282-1285). At boot every prompt is destroyed and recreated once (`ensureAllPrompts(true)`, 1412).
- `Workspace.World.RaceInstances` folder (208-218) and one `<RunId>` folder per run with attributes EventId, RouteId,
  Mode, OwnerUserId and a `SessionAssets` child (322-352).

Prompt properties set: KeyboardKeyCode E, GamepadKeyCode ButtonX, ClickablePrompt true, Style Default, HoldDuration 0,
MaxActivationDistance 24, RequiresLineOfSight false (1295-1301, repeated 1308-1311), ActionText (1312), ObjectText (1313),
Enabled (1314). Not set: Exclusivity (engine default OnePerButton), UIOffset.

### 1.3 Scaling and layout
Not applicable. The prompt is drawn by the engine's core script; the game has no control over its size, font, colour or
position while `Style = Default`.

### 1.4 Config and attributes read
- `ReplicatedStorage.Config.Racing.FlowUI.CountdownSeconds` (110-112), read once at start (live value 5). The other
  FlowUI values (CountdownCardSize 260, CountdownTextSize 130, GoTextSize 96, QueueBanner sizes) are client layout values
  and are not read here.
- `ReplicatedStorage.Config.Racing.TimeTrialCatalog` children, attributes `RouteId`, `EventId` (977-990).
- Through `RaceConfigReader`: GetTimeTrialMedals, GetTimeTrialEvent, GetEventSummary, GetRouteForEvent. Through
  `RaceRouteDefinition`: GetRoutesRoot, GetGate, GetGateCount, GetFirstSpawnCFrame.
- Start-zone attributes: `EventId`, `Mode`, `PromptActionText`, `Enabled` (1229-1245, 1312, 1314). Live zones also carry
  `RouteId`.
- Vehicle attributes read: OwnerUserId, PerformanceTier, PerformanceIndex, PerformanceScore, DisplayName, CockpitId,
  RaceFinishedPendingExit, RaceGridSpawned, RaceRunId, RaceParticipant.
- Route `TeleportPoints` folder (434-447).

### 1.5 Remotes, bindables, state, API
- `ReplicatedStorage.Remotes.Racing.RaceRequest` (RemoteFunction), wrapped by `Core.Net.invoke` with an action allow-list
  (1330): AcknowledgeStagingReady, GetEntryDetails, GetTimeTrialPersonalBest, GetTimeTrialLeaderboard,
  StartStagedTimeTrial, StartTimeTrial, CancelTimeTrial, ExitFinishedTimeTrial, ResetActiveTimeTrial,
  ExitActiveTimeTrial, GetRouteSummary. Capacity 60, refill 20.
- `ReplicatedStorage.Remotes.Racing.RaceEvent` (RemoteEvent), server to client. Payload `Type` values fired here:
  OpenRaceEntry (1270), TimeTrialError (1147, 1171, 1264), TimeTrialStaged (1117), TimeTrialCountdownReveal (1152),
  TimeTrialCountdownScheduled (1177), TimeTrialStarted (1208), TimeTrialCheckpoint (901, 932), TimeTrialLapCompleted
  (873), TimeTrialReset (669), TimeTrialFinished (778), TimeTrialEnded (611, 628, 699, 744), and RaceVisibilityUpdate to
  all clients (298).
- Bindables under `ServerStorage.Runtime`: `Racing.RaceRewardBindings.GrantTimeTrialReward` (20-57),
  `Racing.RacePersonalBestBindings.RecordTimeTrialBest` and `GetTimeTrialBest` (58-104),
  `Racing.GlobalTimeTrialLeaderboardBindings.RecordTimeTrialBest` and `GetTimeTrialLeaderboard` (66-70, 81, 1365),
  `Racing.RaceSessionAssetBindings.SessionAssets` (306-320), `Garage.RaceVehicleSpawner` (997-1041),
  `Player.OnboardingProgress` (1200-1201).
- `RaceIntegrity` module: accepted (757), gate (857), begin (1204).
- Vehicle attributes written: RaceFrozen, DriveReady, ParkedShowcase, DriverUserId, RaceRunId, RaceParticipant, RaceMode,
  RaceFinishedPendingExit, EngineVFXActive.
- Public API: `Service.start()` only.

**Personal bests and rewards (must not be touched by a restyle).** `sendTimeTrialResult` (750-818): medal from config
(752-754); in-memory bucket `personalBests[userId]["<eventId>::<TIER>"]` (120, 182-188, 755-765); persistent PB through
`RecordTimeTrialBest` only when `RaceIntegrity.accepted(run)` (757, 767-774); Cash reward through `GrantTimeTrialReward`
(776); global leaderboard write (81).

**What the results screen can show from `TimeTrialFinished` (778-816):** Elapsed, Medal, MedalRank, Medals,
MedalTargetSeconds, NextMedalName, NextMedalSeconds, NextMedalDelta, PreviousBestSeconds, PersonalBestSeconds,
PersonalBestMedal, IsPersonalBest, Splits, LapTimes, BestLapSeconds, BestLapIndex, CompletedLapCount, CurrentLap,
LapTarget, RouteType, FinishReason, CanRetry, RewardGranted, RewardAmount, RewardCash, RewardMessage, IntegrityRejected,
Message, plus EventId, RouteId, DisplayName, RunId, GateCount, VehicleTier, VehicleIndex, SelectedVehicleId.
There is **no XP or driver-rank field**.

**Client consumers of these event types** (grep): PresentationAudioClient, VehicleVFXClient,
RaceCountdownPresentationClient, RaceEntryMenuClient, RaceLifecyclePresentationClient, RaceParticipantVisibilityClient,
RaceRouteGuideClient, RaceSessionAssetsClient, RaceSessionPresentationClient, RaceTimeTrialResultCoachClient,
RaceTransitionClient. `RewardAmount` is drawn by RaceTimeTrialResultCoachClient 132 and 163.

### 1.6 Input
Prompt only: keyboard E, gamepad ButtonX, click or tap (`ClickablePrompt = true`). `Triggered` (1303-1306) calls
`sendEntryMenu`, which fires `OpenRaceEntry` to that player. No ContextActionService.

### 1.7 Per-frame, polling and rebuild
- 3 s loop over every start zone (4 today): 7 property writes per zone (1308-1314). Writes of an unchanged value do not
  replicate, so network cost is zero in steady state.
- Staging thread: 20 Hz then 33 Hz polling for one player for up to 18 s + 8 s + countdown (1137-1190).
- Each gate `Touched` handler loops all active runs (954-963).
- Reset during a run clones the whole vehicle and destroys the original (479-536).

### 1.8 Mobile and touch
Nothing device-specific. Touch users get the default prompt's tap target only because `ClickablePrompt` is true.

### 1.9 Hard-coded colours, fonts, sizes
No colours or fonts. Player-facing strings and numbers: "Open Race Menu" fallback (1312), "Race" / "Time Trial" (1313),
activation distance 24 (1300), refresh 3 s (1416), fallback event id `shifted_canal_sprint_tt` in 7 places, and about 32
message literals returned to the client (pattern count: 21 `Message = "..."`, 11 error returns; for example 258-270,
645-651, 1266, 1276).

### 1.10 Defects that affect the restyle
- **1311:** `Style = Default` re-asserted every 3 s. Blocks any other server owner; see Headline 3.
- **1314 against RaceLifecyclePresentationClient 118-127 and 160-163:** two writers for `Enabled` on the same prompt. The
  server writes the zone's `Enabled` attribute; the client masks it locally while a menu, queue, loading screen or session
  is active, and re-applies itself on every change. It works, but a new view must never add a third writer.
- **815:** the server builds a money string, `"Best session result!  $" .. Amount .. " earned"`, bypassing the client's
  compact money formatter the sheet requires. A new results view should draw `RewardAmount`, not `Message`.
- **778-816:** no XP in the payload (Headline 7).
- **1247-1269:** the prompt is offered whenever the character is within 24 studs of the zone centre, but the server
  refuses with "Move the vehicle into the start zone." if the car is outside the zone box. The banner can therefore
  invite an action that fails. Nothing replicated tells the client the car is eligible; the client would have to test the
  zone box itself.
- **1312-1313:** mixed-case text; see the casing note above.
- **489 with VehicleAccessServer 88-106 (from source, not verified in Play):** a reset clones the vehicle together with its
  `EnterVehiclePrompt`. `VehicleAccessServer` connects `Triggered` only when it creates the prompt, so the clone's prompt
  has no handler. After a reset and a finish, an "Enter Vehicle" prompt that does nothing can show beside the car.
  `MatchmakingServer` near 452 uses the same clone pattern (not read in full).
- **832-840 with VehicleAccessServer 51-59 (from source, not verified in Play):** a finished time-trial car is frozen and
  the player unseated, which enables the Enter prompt. `canEnter` does not check `RaceFinishedPendingExit` or
  `RaceFrozen`, so on a car that was not reset, pressing E during the results screen would unanchor it and re-seat the
  player. Either way a world prompt can sit over the results screen.

### 1.11 Seam
All logic, no view. See "Seam for the whole group" below. For the event card and Start banner the client already has what
it needs without a server edit: zone attributes `EventId`, `Mode`, `RouteId`, `PromptActionText`, `Enabled` replicate with
the zone part, and `RaceRequest` already offers `GetEntryDetails` (1345-1352) and `GetTimeTrialPersonalBest` (1353-1363).

---

## 2. `ServerStorage.Modules.Game.Vehicles.VehicleAccessServer` (140 lines)

### 2.1 Purpose and lifecycle
Owner of the "Enter Vehicle" prompt on every player vehicle, and of the server-side enter action.

- Started by `ServerBase` 87-90 (dependency GarageServer). Same single-start guard and `xpcall` wrapper (5-7, 135-137).
  No stop or cleanup.
- Connections: `ChildAdded` on `Workspace.World.Runtime.PlayerVehicles`, only if that folder exists at start (119-126);
  one `Triggered` per prompt it creates (99-105).
- Loop: `refreshAll()` every 0.35 s forever (128-133).

### 2.2 Instance tree
One `ProximityPrompt` named `EnterVehiclePrompt` under each vehicle's `VehicleSeat` (84-109): ActionText "Enter",
ObjectText "Vehicle", KeyboardKeyCode E, HoldDuration 0, MaxActivationDistance 12, RequiresLineOfSight false. `Style`,
`GamepadKeyCode`, `ClickablePrompt`, `Exclusivity` and `UIOffset` are never set, so they are engine defaults (Default,
ButtonX, true, OnePerButton, 0,0). `Enabled = seat.Occupant == nil and not ExitCoasting` (107), rewritten every pass.

### 2.3 Scaling and layout
Not applicable (engine-drawn prompt).

### 2.4 Config
None. Constants only: `PROMPT_NAME` (11), `PROMPT_DISTANCE = 12` (12), `REFRESH_SECONDS = 0.35` (13).

### 2.5 Dependencies and API
- Reads vehicle attributes `OwnerUserId` (24, 53), `ExitCoasting` (54, 107). Writes `ParkedFixed`, `ParkedShowcase`,
  `DriveReady`, `DriverUserId` (72-75), sets network ownership (76), moves and seats the character (77-80).
- No remote. The only client input is the engine's `Triggered`, checked by `canEnter` (51-59): owner, not coasting, seat
  empty, alive.
- Public API: `Service.start()` only.
- No other script references the name `EnterVehiclePrompt` (grep). `PassengerClientView` 78 depends on its on-screen
  position through `UIOffset (0,40)`.

### 2.6 Input
E, gamepad ButtonX and tap, all through the default prompt.

### 2.7 Polling and rebuild
Every 0.35 s, for every vehicle in `PlayerVehicles`: a recursive `FindFirstChild("DriverSeat", true)` (33), falling back
to a full `GetDescendants()` scan if no part has that name (38-42), then one `Enabled` write. Cost grows with vehicles
times parts, about three times a second, to track two facts (`Occupant`, `ExitCoasting`) that both have change signals.
This is server CPU, not UI, and is outside a client-only restyle.

### 2.8 Mobile
None.

### 2.9 Hard-coded
Strings "Enter" and "Vehicle" (92-93). Distance 12. No colours or fonts.

### 2.10 Defects that affect the restyle
- **88-98:** `Style` never set. To make this prompt Custom on the server, a line must be added here.
- **53 with 107:** the prompt is enabled for, and replicated to, every player, but only the owner can use it. A non-owner
  walking past any parked car sees "Enter Vehicle" and nothing happens when they press E. A client view can hide the
  banner when the vehicle's `OwnerUserId` attribute is not the local player's.
- **51-59:** no check for `RaceFinishedPendingExit` or `RaceFrozen` (see 1.10).
- **88-106:** `Triggered` is connected only on creation, so a cloned vehicle's prompt is dead (see 1.10).
- **92-93:** mixed case, and the object text "Vehicle" is generic where the garage prompt shows the car's real name.
- **119-126:** if `PlayerVehicles` does not exist yet at start, `ChildAdded` is never connected; the loop hides this.

### 2.11 Seam
All logic. See the group seam.

---

## 3. `ServerStorage.Modules.Game.Garage.OwnedGarageManagement` (415 lines, 88 k chars)

### 3.1 Purpose and lifecycle
Server runtime for owned garages: interior sessions, enter and exit, drive in and out, display-car assignment, structure,
decoration and lighting previews and commits, access and invitations, same-server visits. It owns the Drive Out, Exit
Garage and Manage Garage prompts at runtime.

- `Runtime.Start()` (15) is called by `Garage.OwnedGarageServer.start()` (OwnedGarageServer 8-9), which `ServerBase` 24-27
  registers (dependency GarageServer). `started` guard (16, 412). No stop.
- Connections: `OwnedGarageEvent.OnServerEvent` through `Net.event` (38), `OwnedGarageInvoke.OnServerInvoke` through
  `Net.invoke` (369), `PlayerAdded` / `CharacterAdded` / `Humanoid.Died` (409-410), `PlayerRemoving` (411).
- Per-interior prompt connections are kept in `promptConnections` (76-90), replaced on rebind (86-88), disconnected when
  the interior unloads (93) and when the owner leaves (411).

### 3.2 Instance tree
No GUI.

- `Workspace.World.Interiors.OwnedGarageInstances` (20), attribute `OwnedGarageRuntimePool`.
- Interiors `OwnedGarage_<userId>_<propertyId>`, cloned by `OwnedGarageInterior.Create` (249), with runtime folders
  `StructureRuntime` (160), `DecorationRuntime` (167), `LightingRuntime` (175) and display cars from `OwnedGarageDisplay`.
- Prompts:
  - `DriveOutPrompt` per display space, created if the marker has none (188-201). The template markers have none, so it
    is always created at runtime. ObjectText is the car's full name or "Empty Display Space" (211).
  - `FootExitPrompt` and `ManageGaragePrompt` come from the template. This script only forces `HoldDuration = 0`, sets
    attribute `OwnedGarageAvailable = true` and binds `Triggered` (221-244). Their texts, distance and `Style` are the
    template instance's.
  - `applyPromptPolicy` (143-146) is the single enable rule for all three:
    `Enabled = not (ManagementOpen or Transition) and OwnedGarageAvailable ~= false`.

### 3.3 Scaling and layout
Not applicable. (`Config.Garage.Interior` also holds client layout values such as `InteriorHud*`, `BrowserReference*`,
`MinimumTouchTargetPixels = 44`; this script reads none of them.)

### 3.4 Config and attributes read
`ReplicatedStorage.Config.Garage.Interior` attributes: GarageStreamTimeoutSeconds (28), TesterResetToken and
TesterResetUserId (45), GarageTeleportAttempts and GarageTeleportVerifyDistanceStuds (65), InteriorUnloadDelaySeconds
(93), EnableVisitors (102), `Enable<Capability>` for DisplayCars, Structure, Decorations, Lighting, Access, Invitations
(141-142), ReadRequestsPerSecond and MutationRequestsPerSecond (148), MaxActiveInteriorsPerServer (249),
DriveInSpeedGateEnabled and DriveInMaxSpeedMph (272), GarageSeatDetachTimeoutSeconds (278, 310),
GarageDriveOutVerifySeconds and GarageDriveOutVerifyDistanceStuds (287-288), TransitionCooldownSeconds (370),
MaxGarageInvitations (403).

`ReplicatedStorage.Config.Activities.Visits` attributes: Enabled, MaxVisitorsPerGarage, FriendCacheSeconds (101-105).
`Core.FeatureFlags` key `EnableGarageVisits` (102).

Catalog modules: OwnedGaragePropertyCatalog, OwnedGarageInteriorStyleCatalog, OwnedGarageDecorationCatalog,
OwnedGarageLightingCatalog, VehicleDisplayNames (17). Server modules: OwnedGarageProfile, OwnedGarageFinish,
OwnedGarageDisplayAssignment, OwnedGarageInterior, OwnedGarageDisplay, GarageVisitRules (18, 100).

### 3.5 Remotes, bindables, state, API
- `Remotes.Garage.OwnedGarageInvoke` (RemoteFunction) through `Net.invoke` (369), 32 actions: GetState,
  GetManagementState, SetManagementOpen, PreviewDisplay, CancelDisplayPreview, PreviewStructure, PreviewStructureFinish,
  PreviewStructureFinishAll, CancelStructurePreview, PreviewDecoration, PreviewDecorationFinish,
  PreviewDecorationFinishAll, CancelDecorationPreview, PreviewLighting, CancelLightingPreview, CancelAllPreviews,
  EnterSelectedGarage, EnterOnFoot, EnterWithVehicle, ExitOnFoot, DriveOut, AssignDisplay, ClearDisplay,
  SetInteriorStyle, ConfigureStructure, ConfigureDecoration, ConfigureLighting, SetInvitation, SetAccessMode,
  GetVisitableGarages, VisitGarage, LeaveVisit. Net capacity 60, refill 30.
- Three more gates on every call (370-371, 407), all of which a new view has to respect:
  - a one-second window: 20 calls if the action is GetState or GetManagementState, otherwise 12, counted together
    (147-149). Reply: "Garage requests are arriving too quickly." with `RateLimited = true`;
  - a per-player lock: a second call while one is running gets "Garage transition already in progress.";
  - a cooldown (`TransitionCooldownSeconds`, live 1 s) on non-control actions.
- `Remotes.Garage.OwnedGarageEvent` (RemoteEvent). Client to server: `OwnedGarageStreamReady` (38-42). Server to client
  `Type` values: OwnedGarageStreamRequest (30), VisitEnded (114), DriveOutResult (205), FootExitResult (228, 231),
  OpenManagement (241), DriveOut (336), ManagementUpdated (343).
  Client listeners: OwnedGarageBrowserUI 137-143, OwnedGarageWorkspaceUI 178-184, GarageInteriorModeUI 277.
- Bindables under `ServerStorage.Runtime`: `Player.ProfileServiceBindings.GetProfile`, `ExecuteOwnedGarageCommand`,
  `SaveNow` (19); `Garage.OwnedGarageVehicleLifecycleBridge` (18) with actions GetDrivenVehicle, DespawnForGarage,
  SpawnFromGarage, GetOwnedGarageVehicleCards; `Player.OnboardingProgress` (378).
- Player attributes written: OwnedGarageInside, OwnedGaragePropertyId, OwnedGarageOwnerUserId (96), OwnedGarageVisitor
  (108-109), OwnedGarageStreamState, OwnedGarageStreamToken, OwnedGarageLastStreamError, OwnedGarageLastStreamSeconds
  (29, 35). Read: RaceQueueActive, RaceBrowserTeleporting, GarageSessionActive, ActivityKind (107, 131).
- Saved data changes only through `ExecuteOwnedGarageCommand` (Ensure, Assign, Clear, Restore, SetSurfaceStyle,
  ConfigureStructure, ConfigureDecoration, ConfigureLighting, SetAccessMode, SetInvitation) with RequestId and
  BaseRevision (50-55). High-Risk boundary.
- Public API: `Runtime.ChooseSlot` (9-14, pure) and `Runtime.Start` (15).

**State the garage UI draws (`stateFor`, 358-368):** ApiVersion, DefinitionVersion, Revision, Properties[] (PropertyId,
DisplayName, District, Description, Image, TemplateId, Capacity, Filled, Capabilities, UI, Definition), ActiveGarageId,
InGarage, CurrentPropertyId, Slots[], Vehicles[] (cards from the lifecycle bridge, with UsedInOtherGarage and
DisplayedGarageName added at 364), SurfaceStyles, InteriorStyles, AccessModes, DecorationCategories, Decorations,
Lighting, Structure, Capabilities, AccessMode, InvitationRows, InvitationsEnabled, VisitorsEnabled, Cash, CacheHit; plus
Visiting and VisitsEnabled added at 374. Cached per player by revision, property, vehicle signature, player list and
Cash (359-360, 367).

### 3.6 Input
Prompts only: E, ButtonX, tap. `Triggered` handlers: Drive Out (202-207), Exit Garage for the owner or a visitor
(225-233), Manage Garage (239-243, sends `OpenManagement`).

### 3.7 Polling and rebuild
- No periodic loop. Two bounded waits: `streamDestination` polls at 0.05 s until the client acknowledges or the timeout
  passes (32); `verifyDriveOutVehicle` polls at 0.05 s for up to 2.5 s (290-305).
- `renderDisplays` (178-219) clears and rebuilds every display car on each call: on enter, assign, clear, preview cancel
  and drive-in or drive-out recovery.
- Structure, decoration and lighting models are reused when the style id is unchanged and swapped otherwise (153-155,
  162, 168, 175-176).
- `applyDecorations` runs `session.Interior:GetDescendants()` inside a per-slot loop, twice (165, 166). It runs on every
  decoration preview, so a colour slider drives a full interior scan per slot per request.
- `applyPromptPolicy` scans the whole interior for three prompts on every transition and management toggle (145).

### 3.8 Mobile
None in this script.

### 3.9 Hard-coded
No colours or fonts (colour handling here is finish data, not UI). Strings: "Drive Out" (195), "Empty Display Space"
(211, 363), about 84 result message literals (pattern count: 62 `Message="..."`, 22 error returns). Numbers: prompt
distance 12 (199).

### 3.10 Defects that affect the restyle
- **188-201:** `DriveOutPrompt.Style` never set. Prompt presentation for the garage is spread over three places: this
  script (Drive Out), the template instances (Exit Garage, Manage Garage) and static Workspace instances (the two
  exterior prompts). A server-side change to Custom has to touch all three.
- **203 and 240:** Drive Out and Manage Garage prompts replicate to visitors, who can trigger them and get no response.
  A client view should hide them when the local player has `OwnedGarageVisitor = true` (OwnedGarageBrowserUI 124 already
  special-cases this for its loading screen).
- **147-149 and 370:** previews share the 12-per-second bucket and the per-player lock. A slider that sends one preview
  per input change will be rejected intermittently and the preview will stutter. A new finish panel has to send one
  request at a time and keep only the latest pending value.
- **366 against 374:** `VisitorsEnabled = false` is hard-coded in the state while the live value is `VisitsEnabled`. Two
  near-identical names, one of them dead.
- **359 and 366:** the state carries its own `Cash`. If the garage screens draw their cash chip from this while the HUD
  draws it elsewhere, the sheet's single cash chip has two sources.
- **223, 237, 145:** template `HoldDuration` (0.10, 0.15) is overridden to 0 at runtime; the template values are dead.
- **195, 211:** mixed case.

### 3.11 Seam
All logic. A new garage view can call the same 32 actions and listen to the same seven event types; nothing here needs
to change for a restyle. Must stay single-owner: `sessions`, `visitors`, `locks`, prompt `Enabled` (145), prompt
`Triggered` bindings (82-90), every profile command.

---

## 4. `ServerStorage.Modules.Game.Garage.OwnedGarageInterior` (57 lines)

- **Purpose:** pure helper for interior instances. Required by `OwnedGarageManagement` (18). Not started by anything; no
  state, connections or loops.
- **API:** `AuditTemplate(template)` (13-27), `SlotCFrame(slotIndex)` (28-35), `InstanceName(ownerUserId, propertyId)`
  (36-38), `Create(parent, ownerUserId, propertyId, templateId, slotIndex)` (39-51), `Destroy(parent, ownerUserId,
  propertyId)` (52-55).
- **Instances:** clones `ServerStorage.Assets.Garage.Templates.<TemplateId>` (one template live: `StarterTwoBay`,
  version 2), names it `OwnedGarage_<userId>_<propertyId>`, sets attributes OwnerUserId, PropertyId, RuntimeSlotIndex
  (47), **disables every ProximityPrompt in the clone** (48), pivots it to a grid cell and parents it to the pool (49).
- **Config:** `Config.Garage.Interior` attributes GridColumns (live 4), InteriorBasePosition (live 7000, 3200, 0),
  GridSpacingX and GridSpacingZ (live 512), MaxActiveInteriorsPerServer (live 24). Template attributes
  OwnedGarageTemplateId, CollisionContractVersion, DisplaySpaceId.
- **Template contract (5-6, 13-27):** markers CharacterSpawn, DeskPromptAnchor, FootExitMarker, DriveInMarker,
  DriveOutMarker; display spaces Space01, Space02; a CollisionShell model. The live template has no BillboardGui or
  SurfaceGui.
- **UI relevance:** none directly. Line 48 is where template prompts start disabled; `OwnedGarageManagement` 145 enables
  them. Line 48 writes only `Enabled`.
- **Defects:** the interior limit is checked twice with different counts: Models only (43-45) against all pool children
  (`OwnedGarageManagement` 249). `Destroy` is not used by `OwnedGarageManagement`, which destroys interiors itself
  (93, 411).
- **Seam:** if the owner chooses the server-side route, the template prompts' `Style` belongs on the template instances
  (an asset edit), not in this script. Adding a `Style` write at line 48 would create a second owner of prompt
  presentation.

---

## 5. `ServerStorage.Modules.Game.Garage.OwnedGarageFinish` (96 lines)

- **Purpose:** pure helper for garage finish assets: which colour and material channels an asset supports, validation,
  and applying colours and materials to a cloned model. Required by `OwnedGarageManagement` (18). No state beyond caches
  (6); no connections or loops.
- **API:** StructureAsset, DecorationAsset, LightingAsset (70-72); LightingCapabilities, IsLightingAvailable,
  ValidateLightingFinish (73-75); MaterialCapabilities, StructureCapabilities, DecorationCapabilities,
  IsDecorationAvailable (76-80); ValidateStructureFinish, ValidateDecorationFinish (82-83); Apply (84-90); CloneAt (91);
  Inspect, ResolveMaterial, ClearCache (92-94). Fields: `Version = 2`, `ColourChannels = {Primary, Secondary, Detail,
  Neon}`, `MaterialChannels = {Primary, Secondary, Detail}` (5).
- **Assets:** `ServerStorage.Assets.Garage.StructureAssets`, `DecorationAssets`, `LightingAssets`, each by template id.
  `MaterialService` variants (25-27). Part attributes GarageColourChannel, StructureChannel, GarageMaterialLocked,
  FollowNeonColor, Available.
- **Prompts:** `CloneAt` (91) destroys scripts, ProximityPrompts and seats in display copies, so finish and decoration
  models never carry prompts.
- **Colours:** one `Color3.fromRGB` (10), decoding saved finish data. Not a UI colour.
- **UI relevance:**
  - the channel names Primary, Secondary, Detail, Neon are the same four the sheet's paint panel uses for its channel
    switch. The vehicle paint shop and the garage finish panel can share one channel-switch component, fed from the
    per-asset `ColourChannels` and `MaterialChannels` capability lists that reach the client inside `Structure`,
    `Decorations` and `Lighting` state, rather than a hard-coded list of four;
  - colours travel as `{r, g, b}` integer arrays 0-255, and a Color3 is also accepted (9). A shared swatch or slider
    component should emit one of those two shapes.
- **Defects:** none that affect UI. `inspect` results are cached per asset with weak keys (6, 35, 66).
- **Seam:** nothing to change.

---

## 6. Seam for the whole group

### 6.1 What is logic and what is view
All five scripts are state and logic. The only "view" is the engine's default prompt UI, selected by `Style = Default`.
A new presentation is therefore one new client module plus one shared component, not a change to any of these scripts.

### 6.2 Option C: client only (recommended)
A new client module, for example `ReplicatedStorage.Modules.Game.UI.WorldPromptView`, registered in ClientBase like any
other UI owner:

1. When the new style is on, set `Style = Enum.ProximityPromptStyle.Custom` **locally** on known prompts as they appear
   on the client. When it is off, do nothing at all. The old prompts then stay byte-for-byte as they are, which is the
   backup the owner asked for.
2. Draw a shared `PromptBanner` component (key cap, action text, object text, built from the Style tokens) on
   `ProximityPromptService.PromptShown` and remove it on `PromptHidden`. No per-frame work.
3. Never write `Enabled`, never connect a second `Triggered` handler, never call a remote for the action. Keyboard and
   gamepad triggering stay with the engine. For touch, the banner is a button of at least 48 px that calls
   `prompt:InputHoldBegin()` and `prompt:InputHoldEnd()`, so the engine fires the same `Triggered` the server already
   handles.
4. Client-side filtering the default UI cannot do: hide the Enter banner on cars the player does not own (`OwnerUserId`
   attribute), hide Drive Out and Manage Garage for visitors (`OwnedGarageVisitor`), and hide every banner while a major
   menu or the results screen is open.
5. Lay out simultaneous banners with a list layout, not `UIOffset`. `PassengerClientView` 78 uses `UIOffset (0,40)` to
   sit under the default Enter prompt, which only makes sense for the default UI.
6. Find prompts through scoped listeners on the three known roots (`World.Runtime.PlayerVehicles`,
   `World.Interiors.OwnedGarageInstances`, `World.RaceRoutes`) and the two static exterior prompts, rather than a second
   `Workspace.DescendantAdded` (RaceLifecyclePresentationClient 200 already has one). Re-apply on every stream-in,
   because streaming recreates the instances with the server's Default.

Why this is safe against the server owners: the server only ever writes `Style = Default` to the race prompt (1298,
1311) and never writes `Style` on the others. Writing an unchanged value does not replicate, so the local Custom is not
overwritten. This is the same local-mask technique `RaceLifecyclePresentationClient` already uses for `Enabled`.

Start banner and event card data, without a server edit: zone attributes on the prompt's parent (`EventId`, `Mode`,
`RouteId`, `PromptActionText`), then `RaceRequest:InvokeServer("GetEntryDetails", {EventId, Mode})` and
`"GetTimeTrialPersonalBest"`, once per `PromptShown`, cached per event. Both actions exist and are rate-limited by Net.

### 6.3 Option S: server-side `Style` (not recommended)
Sites that would change:

- `TimeTrialServer` 1298 and 1311;
- `VehicleAccessServer` after 97;
- `OwnedGarageManagement` after 201 (Drive Out);
- the two prompts in template `ServerStorage.Assets.Garage.Templates.StarterTwoBay`;
- the two static prompts under `Workspace.World.OwnedGarageExteriors.STARTER_TWO_BAY`;
- client: `GarageEntranceClient` 154, `PassengerClientView` 69-79, `JobClient` 198-206.

Costs: it breaks the sheet's "client presentation only" contract; it puts a High-Risk module (`TimeTrialServer`) and a
saved-data module (`OwnedGarageManagement`) through whole-source replacement for a cosmetic line; and with Custom set on
the server the old look has no prompt UI unless the server also reads the switch. The server can read
`Core.FeatureFlags`, but its first read at boot returns the default until the ConfigService snapshot arrives
(FeatureFlags 19-35), and `VehicleAccessServer` sets properties only at creation.

### 6.4 Must stay single-owner
- `Enabled`: `TimeTrialServer` 1314, `VehicleAccessServer` 107, `OwnedGarageManagement` 145, `OwnedGarageInterior` 48,
  plus the existing client mask in `RaceLifecyclePresentationClient` 118-127. No new writer.
- `Style`: today `TimeTrialServer` 1298/1311 (server) and `GarageEntranceClient` 154 (client, at creation). The new view
  would be the only client-side writer.
- `Triggered` handling: the server connections in these scripts, and `OwnedGarageBrowserUI` 120-127 on the client.
- Prompt creation and naming.

### 6.5 Names other scripts depend on
- `RaceEntryPrompt`: RaceLifecyclePresentationClient 46.
- `FootExitPrompt`, `DriveOutPrompt`: OwnedGarageBrowserUI 124.
- Attributes `OwnedGarageEntryPrompt`, `OwnedGaragePropertyId` on the exterior prompts: OwnedGarageBrowserUI 125-126.
- `StartZones` folder name and zone `Mode`: RaceLifecyclePresentationClient 148-150, RaceRouteDefinition 66, JobBoard 122.
- `PromptActionText`: RaceRouteDefinition 75.
- `EnterVehiclePrompt`, `ManageGaragePrompt`: no outside references.

## 7. Unknowns to settle in Play

1. That a client-local `Style = Custom` on a server-created prompt survives the server's 3 s re-assert of Default
   (expected: yes, unchanged values do not replicate).
2. That the engine's default prompt UI reads `Style` when the prompt is shown, so that setting Custom before the first
   show fully suppresses it, and what happens if `Style` is changed while a prompt is already showing.
3. Whether `PromptShown` holds steady for the start zone while the player is seated in a car inside the 34-stud zone and
   the zone centre is off screen. `JobClient` 179-181 records that prompts only show while their anchor is on screen and
   moved its prompt onto the car for that reason. If it flickers, the Start banner needs its own zone-box test.
4. Whether the "Enter Vehicle" prompt really shows beside a finished time-trial car during the results screen, and
   whether pressing E re-seats the player (1.10).
5. Whether `GetEventSummary` returns a prize and an entry requirement for the event card's "YOU against ENTRY" split.
   `RaceConfigReader` was not in this group.
6. Where time-trial XP reaches the client, since it is not in `TimeTrialFinished`.
7. How the key cap should look for touch (no key) and for gamepad (`ButtonX` glyph, or `ButtonY` for RIDE).
