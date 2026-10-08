# UI restyle audit: group "followup-ui-coupled-runtime"

Read-only audit, 2026-10-09. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.
All six scripts were read completely with `script_read`. Line numbers are the live Studio line numbers.
Nothing was changed in Studio or the repository. No Play session was run, so every runtime statement below is
from source reading, not from observed behaviour.

| Script (all ModuleScripts under `ReplicatedStorage.Modules.Game`) | Lines | Draws UI? | `Color3.fromRGB` | `Color3.new` | `Instance.new` | Font refs |
|---|---:|---|---:|---:|---:|---:|
| `Audio.PresentationAudioClient` | 415 | No (sounds only) | 0 | 0 | 3 (Sound, Sound, Folder) | 0 |
| `Racing.RaceParticipantVisibilityClient` | 78 (very long lines, 6.3 KB) | No | 0 | 0 | 0 | 0 |
| `Racing.RaceSessionAssetsClient` | 287 | No | 0 | 0 | 0 | 0 |
| `Vehicles.VehicleVFXClient` | 1189 | No | 1 | 0 | 0 | 0 |
| `Garage.ThrustPreviewClient` | 82 (very long lines, 8.2 KB) | No | 0 | 3 | 0 | 0 |
| `Vehicles.DrivingCameraClient` | 787 | Yes: one decorative ScreenGui (speed lines) | 0 | 1 | 4 | 0 |

All six listed paths exist as given. None was missing.

## Headline findings

1. **None of the six scripts holds restyle debt.** Between them there are 2 colour literals that reach the screen
   (white speed streaks, white default thrust colour), no fonts, no text, no layout numbers. They do not need a
   "new view". They should stay single-owner and untouched; the restyle has to respect the contracts they impose.
2. **`PlayerGui.DriveHUD` does not exist.** A scan of every script in ReplicatedStorage, StarterPlayer,
   ReplicatedFirst, StarterGui and ServerScriptService finds the string in exactly two places, both readers:
   `VehicleVFXClient:1053` and `ThrustPreviewClient:29`. No script creates a ScreenGui with that name (the live
   names are `DesktopFreeRoamHud`, `MobileFreeRoamHud_Phase1`, `MobileDriveControls_Phase1`, `SharedInRaceHUD`,
   and so on). So `driveOpen()` is permanently false in both scripts. Consequence for the restyle: **the name
   `DriveHUD` is a trap.** A new ScreenGui given that name would switch on dormant code (details under
   ThrustPreviewClient and VehicleVFXClient).
3. **PresentationAudioClient defines what counts as a "button" for sound.** The new shared Button, Tile, Tab and
   list-row components get hover and click sound for free, provided they follow four rules (listed under that
   script). The most likely way to break it is a transparent hit-area button laid over a separate visual frame.
4. **`Core.FeatureFlags` is server-only.** It lives at `ServerStorage.Modules.Core.FeatureFlags` (ConfigService
   snapshot plus a Studio override attribute on `ServerStorage.Config`). `ReplicatedStorage.Modules.Core` holds
   only CameraService, ClientLifecycle, ConfigReader, ConnectionScope, PathResolver, Signal and Tags. No script
   projects a flag to clients. The style sheet's "the switch is one Core.FeatureFlags flag" therefore needs a
   replicated value the client UI can read. This is outside this group, but it was found here.
5. **`Config.Vehicles.Camera.DebugEnabled` is `true` in the live place**, so DrivingCameraClient writes six
   attributes onto the Camera every rendered frame while driving (lines 113-126, called at 613 and 714).

---

## 1. `Audio.PresentationAudioClient` (415 lines)

### 1.1 Purpose and lifecycle
- One-shot and looped presentation sounds: UI hover and click on every GuiButton, semantic UI results
  (purchase, equip, reject), race cues (countdown tick, go, checkpoint, lap, finish), and garage preview engine
  loops.
- Started by `Audio.PresentationAudioRuntimeClient.start()` (26-line wrapper, lines 10-15), which is a ClientBase
  composition-root entry with no dependencies (`StarterPlayerScripts.ClientBase` lines 15-16). ClientLifecycle
  starts every entry in its own `task.spawn` (ClientLifecycle 28-45), so this starts in parallel with the UI
  owners, in no guaranteed order.
- Module body yields at require time: `PlayerGui` (12), the catalog and bridge modules (15-16),
  `Remotes.Racing.RaceEvent` (17), `Config.Audio.VehicleProfiles` (18).
- `Controller.Start()` (368-389), idempotent through `started`. It destroys any old
  `SoundService.PresentationAudioRuntime_Local` folder and makes a new one (371-375), warms one-shot assets (376),
  binds every existing PlayerGui descendant (377), then keeps: `playerGui.DescendantAdded` (378),
  `raceEvent.OnClientEvent` (379), the bridge subscription (380), and a preview poll thread (381-386).
- `Controller.Stop()` (391-405) disconnects everything and destroys the sound folder. **Nothing calls it.**
- `Controller.Counts()` (407-412) returns `{Buttons, OneShots, PlayingOneShots}`. Useful as an instance-budget
  check, but it can only be read from inside the game (project rule: no gameplay `require` through MCP).

### 1.2 Instance tree
No GUI. Builds `SoundService.PresentationAudioRuntime_Local` (Folder) holding up to `MaximumOneShotVoices`
(config 8) pooled `Sound` objects named `OneShot_N` (85-90), temporary `Warm_*` sounds during preload (132-146),
and `Loop_PreviewIdle` / `Loop_PreviewBoost` sounds (178).

### 1.3 Scaling and layout
None. It has no layout. It is indifferent to resolution, safe area and viewport change.

### 1.4 Config read
- `ReplicatedStorage.Config.Audio.Global` attribute `AudioSystemEnabled` (through `PresentationAudioCatalog:43`).
- `ReplicatedStorage.Config.Audio.Presentation.Global` attributes (16 present): `PresentationAudioEnabled`,
  `UIAudioEnabled`, `PreviewAudioEnabled`, `ObjectiveAudioEnabled`, `RaceAudioEnabled`, `UIMasterGain`,
  `PreviewMasterGain`, `ObjectiveMasterGain`, `RaceMasterGain`, `MouseHoverEnabled` (true),
  `ControllerFocusHoverEnabled` (true), `MaximumOneShotVoices` (8), `PreloadOneShotsEnabled` (true),
  `PreloadOneShotAssetLimit` (24), `PreviewPollHz` (5), `DebugPresentationAudio` (false).
- Cue folders under `Config.Audio.Presentation.<Section>.<Cue>` with attributes `Enabled`, `AssetId`, `Gain`,
  `Pitch`, `CooldownSeconds`, `MaximumVoices`, `Bus`, `ProfileLayer`, `FadeInSeconds`, `FadeOutSeconds`,
  `CrossfadeSeconds`, `MissingPreviewGraceSeconds` (catalog 57-75).
  - `UI` has 15 cues. `Hover` (cooldown 0.07 s, 1 voice) and `Click` (0.04 s, 3 voices) have assets.
    **`Back` and `SaveSuccess` have no asset**, and no script refers to `UI.Back`, so Back and Exit buttons play
    `UI.Click` today.
  - `Racing` has 8 cues; `RaceDNF`, `WrongWayWarning`, `MatchFound` have no asset.
  - `Preview.IdleLoop` and `Preview.BoostLoop` have no asset of their own (they can fall back to a vehicle
    profile layer, line 215). `Objective.Complete` has no asset.
- `Config.Audio.VehicleProfiles.<profileId>` attributes `<Layer>AssetId`, `<Layer>Gain`, `<Layer>Pitch`,
  `ProfileMasterGain` (211-219).
- `SoundService` SoundGroups `UI`, `Vehicle`, `GameplaySFX` (20-24, 53-56). All three exist.

### 1.5 Dependencies and public API
- **The four UI attributes** (the only UI-facing contract):
  | Attribute | Read at | Where it may sit | Effect | Set today by |
  |---|---|---|---|---|
  | `UIAudioSilent` (true) | 275 | The button or **any ancestor** up to PlayerGui, including the ScreenGui | No hover, no click | Nobody |
  | `UIAudioHoverCue` (string) | 293, 298 | The button only | Replaces `UI.Hover`. An empty string silences hover | `OnboardingClient` 87, 88, 93 (empty string) |
  | `UIAudioClickCue` (string) | 303 | The button only | Replaces `UI.Click` | Nobody |
  | `UIAudioSuppressClick` (true) | 302 | The button only (not inherited) | No click sound; hover still plays | `MobileDriveControlsClient` 54, 95 |
- Remote: `Remotes.Racing.RaceEvent.OnClientEvent` (338-366). Payload types handled: `TimeTrialCountdownScheduled`,
  `RaceCountdownScheduled`, `TimeTrialCountdown`, `RaceCountdown`, `TimeTrialStarted`, `RaceStarted`,
  `TimeTrialCheckpoint`, `RaceCheckpoint`, `TimeTrialLapCompleted`, `RaceLapCompleted`, `TimeTrialFinished`,
  `RaceFinished`, `RaceDNF`, `RaceStaged`, and five end/error types that only cancel the countdown.
- `PresentationAudioBridge` (58 lines): `Subscribe(callback)`, `Emit(cueId, payload)`,
  `Result(kind, result, payload)`. `Result` maps a kind to `UI.<Kind>Success`, or to `UI.PurchaseRejected` /
  `UI.ActionRejected` on failure. Callers today: `GarageUI` 23, 25, 32 (`Result`) and 683 (`Emit`),
  `OwnedGarageWorkspaceUI` 56 (`Result`), `OnboardingClient` 608 (`Emit`), `GarageEntranceClient` 182 (`Emit`).
- World state read by polling: `Workspace.ClientOnly.VehiclePreview` or `Workspace.LocalVehiclePreview`
  (195-203) and its attributes `PreviewAudioProfileId` (208) and `PreviewVFXMode` (246); the preview vehicle's
  `ResolvedAudioProfileId` / `StandardAudioProfileId` (209).

### 1.6 Input
No ContextActionService, no key handling. Per GuiButton it connects (291-313):
- `MouseEnter` -> hover, only if `UserInputService.MouseEnabled` and `MouseHoverEnabled`.
- `SelectionGained` -> hover, only if `UserInputService.GamepadEnabled` and `ControllerFocusHoverEnabled`.
- `Activated` -> click (mouse, touch and gamepad all raise `Activated`).
- `Destroying` and `AncestryChanged` -> release.

### 1.7 Per-frame, polling and rebuild
- No per-frame work. A 5 Hz thread (`PreviewPollHz`) runs `updatePreview` (235-256): two `FindFirstChild`
  calls, and when a preview vehicle exists two `Catalog.Get` calls of about 13 `GetAttribute` reads each.
- During a countdown one thread polls at about 33 Hz (`task.wait(0.03)`, 325-334).
- Volume fades run one Heartbeat-waiting thread per fade (150-165).
- **`playerGui.DescendantAdded` fires for every instance any UI owner creates** (378). Non-buttons exit after one
  `IsA` check (288). Each GuiButton costs five connections and a table. A screen that destroys and rebuilds its
  tiles on every state change pays that again on each rebuild. A button taken out with `Parent = nil` is released
  and re-bound when it returns (309-313).
- Button count at runtime could not be measured in Edit mode. Source has 30 literal `"TextButton"` /
  `"ImageButton"` creation sites in 13 scripts, but most buttons come from factories (`Racing.Button`, the
  garage card), so the live count is much higher.

### 1.8 Mobile and touch
On a phone `MouseEnabled` is false, so there is no hover sound. Click plays through `Activated`. Mobile drive
controls suppress click (they would otherwise click on every steering press).

### 1.9 Hard-coded style
None. No colours, fonts or sizes.

### 1.10 Defects visible in source
- **A transparent hit-area button is treated as invisible** (258-270). `hasVisibleContent` accepts: a TextButton
  with non-blank `Text`; an ImageButton with an `Image`; `BackgroundTransparency < 0.98`; or a **TextLabel /
  ImageLabel descendant** with content. A text-less, transparent GuiButton whose label and image are *siblings*
  gets no hover and no click sound. `MobileDriveControlsClient`'s `ThumbstickHit` depends on this.
- **A button that looks disabled but is still `Active` plays the click** (270, 301-305). The style sheet's
  disabled state is "0.4 opacity, no hairline", and the unaffordable Buy button is "disabled style, label
  unchanged". If those keep `Active = true`, they click, and a rejected purchase can also play
  `UI.PurchaseRejected` on top.
- **`CanvasGroup.GroupTransparency` is not considered** (269-279 checks only `Visible`, `Enabled`,
  `UIAudioSilent`). Buttons inside a group faded to fully transparent still play hover. `DesktopFreeRoamHudUI`
  (929-931), `MobileFreeRoamHudUI` (80-81), `GarageWorkspaceUI` (59) and `OnboardingClient` (506) use
  CanvasGroups.
- **Hover has no leave tracking** (291-295). It plays on every `MouseEnter`. A button whose own size changes
  under the cursor (the sheet's "selected tile 10% larger", "pressed 96% scale") can leave and re-enter at its
  edge. Only the 0.07 s cooldown and the 1-voice cap mask this.
- `hasVisibleContent` calls `GetDescendants()` on each hover and click for a button with no own text, image or
  background (262). Small cost, but it scales with the tile's subtree.
- Setting keyboard-or-gamepad focus from script on screen open (ResponsiveUIFoundation 322, 390, 438) raises
  `SelectionGained`, so a hover sound plays as a confirmation opens when a gamepad is connected. Existing
  behaviour, not new.

### 1.11 Seam for a switchable presentation
- All of it is logic. There is no view to replace. **Leave the script untouched.**
- A new view module needs no API call to get button sound. It must create real `GuiButton` instances inside
  PlayerGui. For success and reject sounds it must keep going through the same state owner that already calls
  `AudioBridge.Result` (GarageUI, OwnedGarageWorkspaceUI); if a new view called the bridge as well as the old
  owner, the sound would be requested twice (the 0.1-0.2 s cue cooldowns would hide most, not all, of it).
- **Rules for the shared component factory** (put them in one place, not per screen):
  1. The `GuiButton` is the visible root of a Button, Tile, Tab or row, or the labels and images are its
     descendants. Never a transparent overlay beside the visual.
  2. Disabled, locked and unaffordable states set `Active = false` (Roblox does not raise `Activated` on an
     inactive GuiButton), or set `UIAudioSuppressClick`.
  3. Hover and pressed scaling is applied to an inner visual, not to the button's own hit box.
  4. Purely decorative or modal-shade buttons set `UIAudioHoverCue = ""` and `UIAudioSuppressClick = true`.
     A whole surface can be silenced with `UIAudioSilent = true` on its root frame or ScreenGui.
- **Old and new together:** if both the old and the new view of a screen are built and one is hidden, the hidden
  one makes no sound (its ScreenGui is disabled or its frames invisible), but every one of its buttons still
  holds five connections. Build only the selected view at start. That matches the sheet's "switching style takes
  effect on the next Play start".
- Single-owner: the `PresentationAudioRuntime_Local` folder (only this script names it), the voice pool, and the
  `PlayerGui.DescendantAdded` binding.

---

## 2. `Racing.RaceParticipantVisibilityClient` (78 lines)

### 2.1 Purpose and lifecycle
- Hides other players' characters and vehicles according to race membership. A racer sees only people in the
  same run. A free-roam player does not see anyone who is in a run (44-50).
- ClientBase entry, no dependencies (ClientBase 43-44). `Client.start()` runs once (state guard, 4-6).
- **No stop.** Connections kept for the session: `Players.PlayerAdded` (58), one `CharacterAdded` per player
  (57), `PlayerVehicles.ChildAdded` (62), `Workspace.DescendantAdded` (65), `RaceEvent.OnClientEvent` (66), and
  one `DescendantAdded` per model that has ever been hidden (38).

### 2.2 to 2.3 Instance tree, scaling
Builds nothing. No GUI, no layout.

### 2.4 Config
None.

### 2.5 Dependencies
- Remote `Remotes.Racing.RaceEvent`: `RaceVisibilityUpdate` `{RunId, Participants, Active}` (68) and the end types
  `RaceFinished`, `RaceDNF`, `RaceExitedToStart`, `RaceEnded`, `TimeTrialFinished`, `TimeTrialEnded`,
  `TimeTrialError` (69). Server senders: `MatchmakingServer` 143, 536 and `TimeTrialServer` 299.
- World: `Workspace.World.Runtime.PlayerVehicles.<vehicle>` with attributes `OwnerUserId` and `RaceRunId` (54);
  each player's `Character`.
- No public API beyond `start`.

### 2.6 What it does to UI-like objects (line 30-31)
For every descendant of a hidden model it sets, and later restores from a first-seen value:
- `BasePart.LocalTransparencyModifier` (27), `Decal` / `Texture` `Transparency` (28).
- `Enabled` on ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles and lights (29).
- **`Enabled` on `BillboardGui`, `SurfaceGui`, `Highlight`, `SelectionBox`** (30).
- **`Humanoid.DisplayDistanceType = None`, `NameDisplayDistance = 0`, `HealthDisplayDistance = 0`** (31). Name
  tags today are Roblox's built-in humanoid names (`StarterPlayer.NameDisplayDistance = 100`).

Facts checked: there are 0 BillboardGui, SurfaceGui, Highlight or SelectionBox instances in ReplicatedStorage and
ServerStorage, so no vehicle template carries one today. The only script that creates a BillboardGui is
`RaceRouteGuideClient:137`, and it parents to its own render root (144), not to a vehicle. So the GUI branch at
line 30 has nothing to act on at present. It matters only for what the restyle adds.

### 2.7 Per-frame and rebuild
Event-driven, as the comment at line 8 says. `GetDescendants()` runs on a model only when its hidden state
changes (34-37). `task.defer(apply)` on each vehicle or character added. One global listener:
`Workspace.DescendantAdded` compares the name of every instance added to Workspace (65).

### 2.8 Mobile
No difference.

### 2.9 Hard-coded style
None.

### 2.10 Defects
- Restoration uses the first value ever seen (23-24). If another owner changes `Enabled` on a BillboardGui or
  Highlight while the model is hidden, the restore puts back the stale first value. Nothing re-hides an object
  that another owner re-enables while hidden.
- `PlayerVehicles.ChildAdded` is connected again if the folder is replaced, and the old connection is not
  dropped (60-63). Rare.
- Three scripts each keep their own copy of race membership from the same `RaceVisibilityUpdate` event (this
  one, RaceSessionAssetsClient 167-171, VehicleVFXClient 1104-1112), with different rules (see 4.10).

### 2.11 Seam
Pure logic. Leave untouched. Restyle rule: **any new world-space UI (the Start banner over a start zone, an
event marker, a name plate) must not be parented under a player character or under a
`World.Runtime.PlayerVehicles` model**, or this script will switch it off for some viewers and may restore it to
a stale state. Parent it to a client render root, as RaceRouteGuideClient does.

---

## 3. `Racing.RaceSessionAssetsClient` (287 lines)

### 3.1 Purpose and lifecycle
- Shows only the authored route arrow markers near the local racer: a window of segments behind and ahead of
  the current one. These are world parts, not GUI.
- ClientBase entry, no dependencies (ClientBase 49-50). Runs once. **No stop.** Keeps: `RaceEvent.OnClientEvent`
  (233), a poll thread (245-251), `Workspace.DescendantAdded` (264), one attribute-changed connection (274), and
  per route `ArrowMarkers.ChildAdded` / `ChildRemoved` (102-109) plus one `DescendantAdded` per segment folder
  (75).

### 3.2 to 3.3 Instance tree, scaling
Builds nothing. No GUI.

### 3.4 Config
- `Config.Racing.RouteGuide` attribute `ShowRouteArrowMarkers` (17; live value true). The folder has 43
  attributes; this script reads only that one.
- `Config.Racing.PresentationPerformance.ArrowProxyPollSeconds` (NumberValue, live 0.2) (28-31, 247).
- On `Workspace.World.RaceRoutes.<route>.ArrowMarkers`: attributes `SegmentWindowBehind`, `SegmentWindowAhead`
  (92). On segment folders: `SegmentFrom`, `SegmentTo`, `SegmentKey`, `Enabled` (38-40, 95), or the name pattern
  `CheckpointA-B` / `CheckpointA-Finish` (42-45). On parts: `ArrowOriginalTransparency` (65).
- `Workspace.World.RaceInstances.<runId>.SessionAssets.ArrowBarrierProxies` attribute `ParticipantSegments`,
  a `userId:segment,` list (180-193).

### 3.5 Dependencies
`RaceEvent` types `RaceVisibilityUpdate`, the staged / started / checkpoint / lap / reset types (237-239) reading
`RunId`, `RouteId`, `NextGateIndex`, and the end types (240). No public API beyond `start`.

### 3.6 Input
None.

### 3.7 Per-frame and polling
A forever thread wakes every `min(interval, 0.2)` s and does work only while the local player is in a run
(245-251). `apply` is signature-guarded (210-211), so an unchanged segment costs one attribute read and a string
build. `Workspace.DescendantAdded` returns at once unless arrows are disabled and the instance is a BasePart
(265).

### 3.8 to 3.9 Mobile, style
No mobile difference. No colours, fonts or sizes. (The arrow colour, `RouteGuide.ArrowColor`, pink
255, 68, 196, is read elsewhere, not here.)

### 3.10 Defects
None that affects UI scaling, alignment or consistency. The thread keeps waking five times a second for the
whole session even with arrows disabled.

### 3.11 Seam
Not part of the restyle. The sheet excludes world changes. The style sheet's "route lines are Cyan" applies to
the UI route map, not to these world arrows. Leave untouched.

---

## 4. `Vehicles.VehicleVFXClient` (1189 lines)

### 4.1 Purpose and lifecycle
- The single owner of thrust visuals for every vehicle the client can see, and for garage preview vehicles:
  thrust colour, engine / boost / stabiliser effect toggles, "feel" bursts, the race visibility gate for effects.
  Its own comments call it `CachedThrustVisualRuntime`.
- Started by `Vehicles.RuntimeVFXClient.start()` (25-line wrapper, 8-13), a ClientBase entry with no
  dependencies (ClientBase 63-64). `Runtime.Start()` (1125-1157) is idempotent through `connection`.
- `Runtime.Stop()` (1159-1168) and `Runtime.DebugCounts()` (1170-1185) exist. Nothing calls `Stop`.
- Per tracked vehicle it keeps `DescendantAdded`, `DescendantRemoving`, `Destroying` and about 12 attribute
  signals (945-986), dropped in `destroyCache` (902-916).

### 4.2 to 4.3 Instance tree, scaling
Builds no GUI and no instances of its own. No layout.

### 4.4 Config
- `Config.Vehicles.StabiliserVFX`: 34 `Feel*` attributes plus `ExoticV2PreviewLightMax` (45-81, refreshed every
  0.5 s at 97-109). All 35 are present in the live folder.
- `ReplicatedStorage.Assets.VFX.VehicleTemplates` (36).
- Fixed in code: `VISUAL_RATE = 1/30`, `SCAN_RATE = 0.5`, `UI_RATE = 0.2` (13-15).

### 4.5 Dependencies and API
- Requires `Vehicles.VehicleCosmeticCatalog` (35) and `Vehicles.VehiclePreviewVFXClient` (39), whose `Attach`
  receives `UserInputService.TouchEnabled` as a quality hint (545).
- Remote `Remotes.Racing.RaceEvent`: `RaceVisibilityUpdate` and five end types (1104-1122).
- Vehicle attributes read: `OwnerUserId`, `RaceParticipant`, `RaceRunId`, `ThrustColor`, `ForceThrustPreview`,
  `DriveReady`, `Accelerating`, `Boosting`, `DriftingLeft`, `DriftingRight`, `Braking`, `AudioIgnition`,
  `AudioDrive`, `AudioBoost`, `AudioDrift`, and the `Feel*` family.
- **Preview root contract** (`Workspace.ClientOnly.VehiclePreview` or `Workspace.LocalVehiclePreview`, 288-295):
  attributes `ThrustColor`, `ForceThrustPreview`, `PreviewVFXMode` (`"Idle"` or `"ThrustColour"`, 344-346,
  969-977). Written by `GarageUI` (106, 110, 178, 191, 625) and `GaragePreviewPresentationClient` (252).
- **UI-coupled state:** `LocalPlayer:GetAttribute("GarageSessionActive")` (1049), written only by the server
  (`ServerStorage...GarageSessionServer` 76, 101). `PlayerGui.DriveHUD.Enabled` (1053), which never exists.
  `PlayerGui.TouchGui.Enabled` (1059-1061) and `PlayerModule:GetControls()` `Enable` / `Disable` (1063-1071,
  1084-1094).
- Public: `Start`, `Stop`, `DebugCounts`.

### 4.6 Input
None directly. On touch devices it switches Roblox's own touch controls on and off (see 4.8).

### 4.7 Per-frame and polling
One `RenderStepped` connection (1130-1156) with three accumulators:
- 30 Hz: `updateCache` for every tracked vehicle (1140-1148): roughly 10 to 25 attribute reads per vehicle and one
  guarded controller update.
- 2 Hz: `scanCandidates` (1135-1138): 35 config attribute reads, a sweep of the tracked sets.
- 5 Hz: `updateCameraAndTouchControls` (1150-1153), touch devices only.

### 4.8 Mobile and touch
`setRobloxTouchControls(not garageOpen() and not driveOpen())` every 0.2 s on any `TouchEnabled` device
(1078-1080). Because `DriveHUD` never exists, this is in effect `TouchGui.Enabled = not GarageSessionActive`.

### 4.9 Hard-coded style
One literal: `DEFAULT_THRUST = Color3.fromRGB(255, 255, 255)` (12), a vehicle effect colour, not UI.

### 4.10 Defects
- **Dead lookup:** `driveOpen()` (1052-1055) can never be true.
- **Second owner of the same job:** ThrustPreviewClient does the same TouchGui and controls toggling every frame
  (see 5). Each keeps its own `controlsDisabled` flag (32). A third owner, `Vehicles.GameplayInputGate`, also
  calls `controls:Disable()` / `Enable()` with tokens (used by `DesktopFreeRoamHudUI:991`, `FullMapUI:521`,
  `LoadingTransitionRuntime:87`). When the garage closes, this script calls `controls:Enable()` without asking
  the gate, so it can re-enable movement while a gate token is still held.
- **Race gate keeps one list, not one per run** (1107-1109): any `RaceVisibilityUpdate` overwrites the
  participant list and the active flag, so an "inactive" update for someone else's run switches the effect gate
  off for all. The two other consumers keep a map per run.
- Device test here is `TouchEnabled` alone (545, 1078); DrivingCameraClient uses "touch and no keyboard" (381).

### 4.11 Seam
Pure logic. Leave untouched. For the restyle:
- **Never name a ScreenGui `DriveHUD`.** On a touch device, an enabled ScreenGui of that name would make this
  script disable `TouchGui` and call `controls:Disable()`.
- The new garage, customise and paint views must keep writing the preview root attributes through the existing
  owner (GarageUI state), not from a second place.
- `GarageSessionActive` stays the only "garage is open" signal. A new view must not invent a client-side one.

---

## 5. `Garage.ThrustPreviewClient` (82 lines)

### 5.1 Purpose and lifecycle
- Once the preview VFX controller here; now a bridge that (a) recolours thrust-channel parts and effects on the
  garage preview vehicle when the preview attributes change, and (b) toggles Roblox touch controls. The comment
  at 62-63 says the template effects moved to CachedThrustVisualRuntime (VehicleVFXClient).
- ClientBase entry, no dependencies (ClientBase 30-31). Runs once. **No stop; the `RenderStepped` connection at
  line 70 is never disconnected.**

### 5.2 to 5.3 Instance tree, scaling
Builds nothing. No layout.

### 5.4 Config
`Config.UI.GarageReplacement` attribute `ThrustTargetPollSeconds` (live 0.25), read **every frame** (73, through
`number` at 26). This is the 105-attribute garage layout folder; this script reads only this one value. The
folder also holds four `PreviewThrust*Intensity` attributes that this script does not read.

### 5.5 Dependencies
- Requires `VehicleCosmeticCatalog` (16) and, guarded, `VehiclePreviewVFXClient` (20, then unused).
- `ReplicatedStorage.Assets.VFX.VehicleTemplates` (17, unused).
- `LocalPlayer` attribute `GarageSessionActive` (28). `PlayerGui.DriveHUD.Enabled` (29, never exists).
  `PlayerGui.TouchGui.Enabled` and `PlayerModule:GetControls()` (27, 30).
- Preview root attributes `ThrustColor`, `ForceThrustPreview`, `PreviewVFXMode` (60). Player vehicle
  `OwnerUserId`, `ThrustColor` (31, 66). Camera attribute `DrivingCameraManaged` (68).
- No public API beyond `start`.

### 5.6 Input
None directly.

### 5.7 Per-frame and polling
Every rendered frame, forever (70-75):
- on touch devices, `setRobloxTouchControls(...)`: one attribute read, two `FindFirstChild` calls, one property
  write;
- `forceDriveCamera()`: one more `FindFirstChild("DriveHUD")`, which always returns early;
- one `GetAttribute` for the poll interval.
Every 0.25 s `refreshTargets` (59-67); when the preview root, vehicle, colour, force flag or mode changes it
walks the whole preview with `GetDescendants()` and an ancestor climb per object (51-57).

### 5.8 Mobile and touch
The same rule as VehicleVFXClient, at frame rate: `TouchGui.Enabled = not GarageSessionActive`.

### 5.9 Hard-coded style
Three `Color3.new(1, 1, 1)` fallbacks for thrust colour (60, 61, 66). Not UI.

### 5.10 Defects
- `forceDriveCamera` (68) is dead code today, and it is dangerous if revived: with a `DriveHUD` present and the
  camera not marked `DrivingCameraManaged`, it would set `CameraType = Custom` and `CameraSubject` to the seat
  every frame.
- Vestigial state: `previewController` is always nil (21, 64); `controllerModule`, `templates`, `previewVehicle`,
  `cachedPlayerVehicle`, `cachedPlayerColor` are assigned and never used; `full` is unused and line 55 ends in an
  empty `do end`.
- Duplicate owner of TouchGui and controls (see 4.10).
- Per-frame instance lookups that never change result.

### 5.11 Seam
Pure logic, mostly retired. Leave untouched during the restyle (retiring it is a separate, approved-scope job).
Same two rules as VehicleVFXClient: reserve the name `DriveHUD`; keep the preview root attributes single-owner.

---

## 6. `Vehicles.DrivingCameraClient` (787 lines)

### 6.1 Purpose and lifecycle
- The driving camera. Two modes chosen by `Config.Vehicles.Camera.ScriptedChaseEnabled` (2-8): scripted chase
  (owns `Camera.CFrame`) or the V6.1 mode (Roblox owns the camera; this sets distance and field of view).
- It also owns the **speed-line overlay**, the only GUI in this group.
- **Not a ClientBase entry.** `Vehicles.DrivingClient` loads it lazily (493-507) and calls
  `Controller.Start({Vehicle, GetCamera, GetCharacter, IsAccelerating, IsBoosting})` when a drive begins
  (509-520) and `Controller.Stop()` when it ends (522-523).
- `Start` (717-755) calls `Stop` first, so a restart is clean. `Stop` (757-784) unbinds the render steps,
  disconnects every connection, restores zoom, releases the mouse, **destroys the speed-line ScreenGui** (766),
  clears field of view and hands the camera back.
- `suspend` / `resume` (618-646) hide the overlay and release the camera for the Studio trailer tools.

### 6.2 Instance tree (speed lines, 344-401)
```
ScreenGui "DrivingSpeedEffect"   IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = -10,
                                 Enabled = false at build, ZIndexBehavior not set          (366-371)
  CanvasGroup "Lines"            Size 1,1 scale, BackgroundTransparency 1, GroupTransparency 1,
                                 Active = false, Interactable = false                      (372-379)
    Frame "Line" x N             AnchorPoint .5,.5, BorderSizePixel 0, white               (386-390)
      UIGradient                 Transparency keypoints (0, 1) (0.7, 0.35) (1, 0.15)       (391-394)
```
- `N = floor(ChaseSpeedLineCount)` clamped 0 to 120, live value 64; halved when `TouchEnabled and not
  KeyboardEnabled` (380-381).
- Instance count: `2 + 2N` = **130 on desktop, 66 on a phone**, 242 at the clamp.
- Built and parented once per drive start (399, 747). Destroyed on stop.
- `DisplayOrder = -10` is below every other ScreenGui in the game (the next lowest literal is 18,
  DealershipIntroClient; the HUDs are 84 to 96; in-race HUD 155). Only this script names `DrivingSpeedEffect`.

### 6.3 Scaling and layout of the overlay
- No reference canvas, no UIScale, no constraints. Geometry is computed in pixels from the live
  `Camera.ViewportSize` (fallback 1920 x 1080) at 383 and 422-423.
- `placeSpeedLine` (352-360): `half` = half the viewport diagonal; a random angle; `length` = 14% to 40% of
  `half`; `radius` = 50% to 95% of `half`; `Rotation` = the angle; `Size` in **offset** pixels; `Position` =
  screen centre (scale 0.5) plus a pixel offset.
- **Thickness is a fixed 2 to 4.5 px** (358). It does not scale with resolution: thin at 3440 x 1440, heavy on
  a phone-sized viewport.
- **Placement is circular, not shaped to the screen.** At 1920 x 1080 `half` is about 1101 px, so radii run 550
  to 1046 px while the screen is only 540 px tall from centre: streaks near vertical are largely off-screen. At
  3440 x 1440 (`half` about 1865, radii 932 to 1771, 720 px to the top edge) more of them are off-screen and
  the visible ones crowd the left and right ends. Off-screen streaks still exist and still get re-placed.
- Safe area: none, by design (full bleed, `IgnoreGuiInset = true`).
- Text: none.
- Viewport change: no listener. While visible, 6 streaks are re-placed every 0.04 s against the current
  viewport (419-428), so the whole field adopts a new size in about 0.43 s (0.24 s on a phone). While hidden
  nothing updates; it catches up when next shown.

### 6.4 Config
`Config.Vehicles.Camera` (126 attributes in total, read as one table by `GetAttributes()` every
`ConfigRefreshSeconds`, live 0.25 s; 41-49). Overlay keys: `ChaseSpeedLinesEnabled` (true),
`ChaseSpeedLineCount` (64, read at drive start), `ChaseSpeedLineStartMph` (110), `ChaseSpeedLineFullMph` (230),
`ChaseSpeedLineOpacity` (0.7). Switches: `Enabled`, `ScriptedChaseEnabled` (true), `DebugEnabled` (**true**),
`LockPlayerZoom`, `RespectTrailerCameraKeys`, `ApplyInitialLookAngle`. About 60 further camera tuning keys
(`Chase*`, `Default*`, `HighSpeed*`, `Boost*`, `Acceleration*`, smoothing values).
`Config.Development.ClientTools.TrailerVehicleCameraEnabled` (649-654; live false).

### 6.5 Dependencies and API
- `Core.CameraService`: `SetFieldOfView("DrivingCamera", fov, 100)`, `ClearFieldOfView`,
  `SetZoomLimits("DrivingCamera", d, d, 100)`, `ClearZoomLimits` (102-105, 554, 624, 712, 767).
- Camera attributes it writes: `DrivingCameraManaged`, `DrivingCameraOwner` (166-167, 200-201), and six debug
  attributes (109-125). `DrivingCameraManaged` is read by `DrivingClient:808` and `ThrustPreviewClient:68`.
- Vehicle attributes read: `FeelImpactRevision`, `FeelImpactStrength`, `FeelLandRevision`, `FeelLandStrength`
  (232-233, 433-449).
- Render steps: `"VehicleCamera"` at Camera priority +1 (chase) or +2 (V6.1), `"VehicleCameraInitialFraming"`
  at Camera -1 (748-753).
- Public: `Start(context)`, `Stop()`.

### 6.6 Input (294-343, 655-664)
- **Mouse:** right button held = orbit; sets `UserInputService.MouseBehavior = LockCurrentPosition` (300) and
  back to `Default` on release (208-213). This is the only script that writes `MouseBehavior`. The press is
  ignored when the engine reports it as processed by GUI (296).
- **Touch:** a touch that begins in the **top 58% of the viewport** and is not processed by GUI becomes the
  camera-look touch (302-308). Drags then orbit (329-330).
- **Gamepad:** right stick (`Thumbstick2`) orbits, dead zone 0.18 (331-340). This `InputChanged` handler has no
  "processed" test, so the right stick still moves the camera while a menu is open over a drive.
- **Keyboard:** P, C, V suspend and B resumes (659-663). In chase mode this only applies when the Studio trailer
  tool is on (658).
- No ContextActionService, no GuiService selection.

### 6.7 Per-frame work
- `updateChase` every frame (462-614): about 60 lookups into the cached config table, up to three spherecasts
  (259-272), spring maths, one `Camera.CFrame` write, then `updateSpeedLines` and `publishDebug`.
- `updateSpeedLines` (402-430): below 2% strength it disables the ScreenGui once and returns (406-412). Above
  that it writes `GroupTransparency` when the strength moves by more than 0.01 (414-417), and every 0.04 s
  re-places 6 streaks, 3 property writes each (419-428).
- The comment at 344-345 says a CanvasGroup carries the fade "so only one property changes per frame". In
  practice the re-placement dirties the full-screen CanvasGroup about 25 times a second while streaks show, so
  the group's off-screen texture (viewport-sized) is redrawn at that rate.
- The config table is rebuilt from 126 attributes four times a second (45).

### 6.8 Mobile and touch
Half the streak count (381); touch look zone as above; separate touch sensitivity
(`ChaseLookTouchRadiansPerPixel`). The mobile test here ("touch and no keyboard") is not the one the other
scripts in this group use ("touch").

### 6.9 Hard-coded style
- `Color3.new(1, 1, 1)` streak colour (390). Close to, not equal to, the sheet's `White` (243, 240, 255).
- Gradient keypoints 1 / 0.35 / 0.15 (393); thickness 2 to 4.5 px (358); length and radius fractions (355-356);
  re-place cadence 0.04 s and 6 per tick (420, 425); speed-versus-boost weighting 0.6 / 0.4 (404);
  `DisplayOrder = -10` (370). No fonts.

### 6.10 Defects
- **`flag()` cannot honour a configured `false` when its fallback is `true`** (56-59: `typeof(value) ==
  "boolean" and value or fallback`). So `Enabled`, `ApplyInitialLookAngle`, `RespectTrailerCameraKeys` and
  `LockPlayerZoom` cannot be turned off from config. The author noticed and added `switch()` (60-65) for the two
  newer keys only.
- **`DebugEnabled = true` in the live config** costs six `SetAttribute` calls on the Camera per frame while
  driving (120-125).
- Streak thickness is not resolution-aware (358); streak placement wastes instances off-screen, more so on
  ultrawide (353-359).
- Full-screen CanvasGroup redrawn about 25 Hz while visible (419-428). Not measured; likely to matter most on
  low-end phones, which is where the count is already halved.
- The right-stick handler ignores whether GUI has focus (325-342).
- The whole overlay (up to 130 instances) is destroyed and rebuilt at every drive start and every camera-mode
  restart (362, 747).

### 6.11 Seam
- State and logic: everything except `buildSpeedLines`, `placeSpeedLine` and `updateSpeedLines` (346-430), which
  are view construction with a three-call surface (`build`, `update(dt, speed, boostAmount)`, `destroy`) and one
  hide in `suspend` (623).
- **Recommendation: do not include the overlay in the restyle.** The style sheet excludes driving and VFX
  changes, the overlay has no text, panel or font, and its look is already tunable from
  `Config.Vehicles.Camera` (`ChaseSpeedLineOpacity`, `Count`, `StartMph`, `FullMph`, `Enabled`). If it is ever
  moved to a static streak image (which would fit the sheet's "static images, never per-frame effects" budget),
  that is a camera delivery of its own.
- What the restyle must respect:
  - The overlay sits **behind** all HUD (`DisplayOrder -10`) and its streaks occupy the outer half of the
    screen, which is exactly where the sheet puts the corner clusters. Slate panels at 0.86 opacity will let
    14% of a white streak through; the panel-less speed gauge arcs and minimap ring will have white streaks
    directly behind white and cyan arcs at high speed and during boost. Check legibility at 230 mph with boost
    in step 3 of the build order, and tune the config values if needed.
  - Keep every HUD `DisplayOrder` above -10 and do not reuse the name `DrivingSpeedEffect`.
  - **Phone HUD layout:** a touch in the top 58% that lands on something that is not `Active` turns into camera
    look. Decorative panels there (event card, position and lap, status cluster background) pass touches
    through; interactive ones must be real buttons. A wide `Active` strip across the top would block camera
    look.
  - Right-mouse orbit locks the cursor, so hover states freeze while it is held.
- Single-owner: `Camera.CFrame`, `CameraType`, `MouseBehavior`, the `DrivingCamera` field-of-view and zoom
  owner key in CameraService, and the two render-step names.

---

## Cross-cutting notes for the restyle plan

### Names and values other scripts depend on
| Name | Who depends on it | Rule |
|---|---|---|
| `PlayerGui.DriveHUD` | VehicleVFXClient 1053, ThrustPreviewClient 29 | Does not exist. **Never create it.** |
| `PlayerGui.TouchGui` (Roblox's) | VehicleVFXClient 1059, ThrustPreviewClient 30, GarageInteriorModeUI 115 | Do not create a ScreenGui with this name. |
| `PlayerGui.DrivingSpeedEffect` | DrivingCameraClient 367 only | Do not reuse. Keep HUD DisplayOrder above -10. |
| `SoundService.PresentationAudioRuntime_Local` | PresentationAudioClient 371-375 only | Leave. |
| Player attribute `GarageSessionActive` | 15 client scripts; server-written (GarageSessionServer 76, 101) | Stays the only "garage open" signal. |
| Preview root attributes `ThrustColor`, `ForceThrustPreview`, `PreviewVFXMode`, `PreviewAudioProfileId` | PresentationAudioClient, ThrustPreviewClient, VehicleVFXClient | Written by GarageUI and GaragePreviewPresentationClient. Keep one writer. |
| Camera attribute `DrivingCameraManaged` | DrivingClient 808, ThrustPreviewClient 68 | Leave. |
| `UIAudioSilent`, `UIAudioHoverCue`, `UIAudioClickCue`, `UIAudioSuppressClick` | PresentationAudioClient | Set centrally in the shared component factory. |
| Remote payload type `RaceVisibilityUpdate` | RaceParticipantVisibilityClient, RaceSessionAssetsClient, VehicleVFXClient | Not a UI concern; three separate copies of the state. |

### How the "old UI as backup" requirement interacts with this group
- These six scripts need no backup copy and no switch. They work the same under either style.
- The switch should choose **which view module is constructed** when a screen is built. Constructing both and
  hiding one doubles PresentationAudioClient's per-button connections and every `DescendantAdded` callback.
- A whole old or new surface can be made silent with `UIAudioSilent = true` on its root if a transition ever
  needs both on screen briefly.

### Things that are outside this group but were found here
- `Core.FeatureFlags` is server-only (`ServerStorage.Modules.Core.FeatureFlags`: ConfigService snapshot, Studio
  override `ServerStorage.Config` attribute `Flag_<Key>`). 9 server modules use it. There is no client module
  and no replicated projection. The style switch needs one (for example a server-written attribute on the
  planned `ReplicatedStorage.Config.UI.Style` folder), or it should be a plain replicated config value.
- Three different "is this a phone" tests are in use across the client: `TouchEnabled` (VehicleVFXClient,
  ThrustPreviewClient, MobileDriveControlsClient 12), `TouchEnabled and not KeyboardEnabled` (DrivingCameraClient
  381, and one use each in ActivityClient, DesktopFreeRoamHudUI, FullMapUI), and last-input-type
  (ResponsiveUIFoundation, FullMapUI). A touch laptop gets mobile drive controls and TouchGui toggling but the
  desktop streak count. New shared components should take one form-factor answer from one place.
- Three owners call `PlayerModule` controls `Enable` / `Disable` on touch devices: GameplayInputGate (token
  based), VehicleVFXClient and ThrustPreviewClient (each with a private flag).

## Not verified
- No Play session: nothing here was observed running. In particular, whether Roblox's TouchGui is visible
  during a drive on a phone, and whether the two TouchGui writers cause any visible flicker, is unknown.
- Runtime GuiButton count and `Controller.Counts()` were not read (no gameplay `require` through MCP).
- CanvasGroup redraw cost of the speed lines was reasoned from source, not profiled.
- Whether `MouseEnter` re-fires when a button's own scale changes under a still cursor was not tested; it is a
  known Roblox behaviour at edges, flagged as a risk rather than a confirmed defect.
- `Preview.IdleLoop` / `Preview.BoostLoop` have no asset on the cue; whether a vehicle profile layer supplies one
  (so the garage has engine sound) was not traced.
