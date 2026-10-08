# Proposal A: Pulse Racers UI rebuild, safest backup first

Date: 2026-10-09. Status: proposal only. Nothing here is installed, and nothing in Studio or the repo was changed to write it.
Place: Space Racers v3 (93959280828322). Priority of this proposal: the old UI stays provably the same when switched back, the
switch is one value, every step can be undone, and as few existing scripts as possible are edited.

Names used below: **Classic** = today's UI. **Pulse** = the new UI.

## 0. Summary

- The game picks Classic or Pulse **once per client session**, from one replicated attribute saved in the place. Default: Classic.
- Pulse is a **second set of modules in a new folder**. ClientBase starts one module per entry name, never both.
- **Three existing scripts are edited in the whole programme** (one in Phase 1, two in Phase 7). Every other existing script,
  and every existing config folder, stays byte-identical, and each installer run checks that against a hash list.
- Shared modules (RacingUIComponents, GarageComponents, ResponsiveUIFoundation, the map renderers) are **not** made style-aware.
  That removes the contradiction the critic found.
- Surfaces that only restyle through shared modules get a Pulse owner under the same entry name. Where the owner spends Cash or
  holds saved ids, the Pulse copy is **generated from the Classic source** with a listed set of replacements, so its server calls
  are the same text.
- Navigation changes (hub into tabs, Shop/Owned switch) are a separate late phase. The first garage delivery keeps today's pages.
- The default flips to Pulse only after every group has passed, and Classic is removed only on Oscar's say, in a later scope.

### Checked live for this proposal (Edit mode, read-only)

| Fact | Result |
|---|---|
| ClientBase resolver | Lines 105-109, as the audit says. 46 entries. `StartupState` folder at line 104 |
| ClientLifecycle | 49 lines. A skipped or failed dependency blocks dependants (line 36). No change needed |
| LoadingTransitionRuntime | View is required at line 8, colours folder at line 40, `View.Create` at line 47 |
| InitialLoadingAndStartScreenClient | Early return at lines 15-18; requires the runtime at 21 and RacingUIComponents at 22 |
| OwnedGarageClient | 18 lines; starts four modules by name at lines 8-9 |
| SharedTopNotificationUI | 27 lines; builds the controller at line 17 |
| Who requires an owner module by name | FullMapUI by both HUDs (Desktop 960, Mobile 260). OwnedGarageBrowserUI and OwnedGarageWorkspaceUI by GarageInteriorTransitionUI, GarageInteriorModeUI, OwnedGarageClient. GarageWorkspaceUI by GarageUI and OwnedGarageWorkspaceUI. ActivityClient only by ClientBase |
| RacingUIComponents / GarageComponents requirers | 19 and 9 |
| `ReplicatedStorage.Config.UI` | No attributes today. 17 child folders. No `Style` or `Pulse` folder |
| RouteGuide | `GetActive()` is public (line 89). `route` and `progress` are private (36-38). The renderer puts its chip and pip in `options.Container` (219, 237) |
| MapIconLayer | Host can pass `Project` and `Size` (274-275). A NaN result hides the icon (304) |
| Studio no-save sandbox | `ProfileServer` 178-185: Studio only, `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay`. Live value is `false` |
| `SetCoreGuiEnabled` | Only in the tool-gated TrailerModeClient |

---

## 1. Switch model

### 1.1 Where the value lives

Three string attributes on the existing folder `ReplicatedStorage.Config.UI` (attributes arrive with the instance, and every UI
owner already waits for that folder):

| Attribute | Values | Meaning |
|---|---|---|
| `UIStyle` | absent, `"Classic"`, `"Pulse"` | The style for everyone. Anything other than exactly `"Pulse"` means Classic |
| `UIStyleClassicGroups` | comma list of group names, default empty | Groups forced back to Classic while `UIStyle` is Pulse (emergency partial switch-back) |
| `UIStylePreviewUserIds` | comma list of user ids, default empty | These players get Pulse while `UIStyle` is Classic (owner preview in a live server) |

No server code, no remote, no dashboard flag. This follows the FEEL-01 precedent (client switches as replicated config,
recorded as an exception to "live-tunable behaviour reads Core.FeatureFlags", because that module is in ServerStorage).
An optional dashboard kill switch is described in 1.7; it is not part of the default build.

### 1.2 Who reads it, and when

One new module, the **latch**: `game.ReplicatedFirst.UIStyleSwitch` (ModuleScript, about 80 lines, no dependencies).

- It lives in ReplicatedFirst so the loading script and ClientBase get the same module instance and the same answer.
- First call reads the three attributes once, after `ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI")` (the same wait
  the loading script already makes at its line 13, so no new way to hang). The result is stored in a local and never read again.
  A later attribute change is ignored for the session and warns once ("takes effect on the next join").
- Classic path cost: one `GetAttribute`, one string compare. No Pulse module is required.

```text
UIStyleSwitch.Style            "Classic" | "Pulse"      latched
UIStyleSwitch.Active(group)    boolean                  latched per group on first ask
UIStyleSwitch.Routes()         nil when Classic, else { Paths = {[entryName] = path}, ExtraEntries = {...} }
UIStyleSwitch.ModulePath(name) path of the active module for an entry name (used by Pulse owners that open another owner)
UIStyleSwitch.Report()         table for evidence
```

Groups are sets of entries that must switch together. A group is Pulse only if all of these hold, checked **before any owner
starts**: the latch says Pulse, the group is not in `UIStyleClassicGroups`, every module path in the group exists (bounded wait,
5 s per path), the kit preflight passes (tokens readable, asset ids present, font request issued), and every Pulse entry module
of the group `require`s without error. Otherwise the whole group is Classic for the session and one warning is printed. This is
the sheet's "fall back to the current look and warn once", moved to the only moment it is safe.

After an owner's `start()` has begun there is no automatic fallback. A Pulse owner that fails shows as `failed` in
`ClientBase.StartupState`, exactly as a Classic owner does today. Starting the Classic owner after a half-started Pulse one
would risk two owners.

### 1.3 Groups and routes

Route table: new module `game.ReplicatedStorage.Modules.Game.UI.Pulse.Routes` (data only). Entry names and dependencies in
ClientBase do not change; only the path does.

| Group | ClientBase entry name (unchanged) | Pulse path under `ReplicatedStorage.Modules.Game.UI.Pulse` | Phase |
|---|---|---|---|
| Common | SharedTopNotificationUI | `Shell.TopNotification` | 1 |
| FreeRoam | DesktopFreeRoamHudUI | `FreeRoam.HudDesktop` | 2 |
| FreeRoam | MobileFreeRoamHudUI | `FreeRoam.HudTouch` | 2 |
| FreeRoam | MobileDriveControlsClient | `FreeRoam.DriveControlsTouch` | 2 |
| FreeRoam | ActivityClient | `Activities.ActivityClient` | 2 |
| FreeRoam | FullMapUI | `Map.FullMap` | 6 |
| FreeRoam | (extra entry) PulseCoreUiPolicy | `Shell.CoreUiPolicy` | 2 |
| Race | RaceSessionPresentationClient, RaceCountdownPresentationClient, RaceQueueClient, RaceRouteGuideClient, RaceTimeTrialResultCoachClient | `Race.SessionHud`, `Race.Countdown`, `Race.QueueBanner`, `Race.RouteGuide`, `Race.Results` | 3 |
| Race | RaceBrowserClient, RaceEntryPresentationClient | `Race.Browser`, `Race.Entry` | 4 |
| Garage | GarageUI | `Garage.GarageUI` (generated) | 5 |
| Garage | OwnedGarageClient | `Garage.OwnedGarageClient` (starts the four Pulse owned-garage modules) | 5 |
| Garage | GarageEntranceClient | `Garage.GarageEntranceClient` (generated) | 5 |
| World | (extra entry) PulseWorldPromptView | `World.PromptView` | 6 |
| Shell | OnboardingClient | `Shell.OnboardingClient` (generated) | 7 |
| Shell | (ReplicatedFirst, not a ClientBase entry) loading view and start screen | `ReplicatedFirst.Loading.PulseLoadingScreenView`, `ReplicatedFirst.Loading.PulseInitialLoading` | 7 |

Never routed, one copy under both styles: LoadingTransitionUI, RaceTransitionClient, RaceLifecyclePresentationClient,
RaceEntryMenuClient, RaceParticipantVisibilityClient, RaceSessionAssetsClient, DriveSessionClient, the audio runtimes,
GaragePreviewPresentationClient, ThrustPreviewClient, RuntimeVFXClient, DealershipIntroClient (its UI is off by config in v3),
FreeRoamVehicleExitButtonClient (a no-op), the Development tools, DrivingCameraClient's speed lines.

Group rules that come from direct requires:

- A Pulse HUD opens the full map through `UIStyleSwitch.ModulePath("FullMapUI")`, so it works with the Classic map (Phases 2 to 5)
  and the Pulse map (Phase 6). The Classic HUDs can only open the Classic map, which is why the map is in the FreeRoam group.
- The four owned-garage modules reference each other by module name, so they switch as one unit through the single
  `OwnedGarageClient` entry.

Every mix of groups must **work**. Only all-Classic and all-Pulse must look finished. Mixed looks are a development and
emergency state.

### 1.4 First joiner on a fresh server

They get whatever is saved in the published place, with no waiting and no race: the attribute replicates with `Config.UI`.
Until Phase 9 that is Classic. There is no ConfigService snapshot to wait for, so early and late joiners always agree.

### 1.5 How Oscar switches back

1. Studio: select `ReplicatedStorage > Config > UI`, set attribute `UIStyle` to `Classic` (or delete it). Press Play, or publish.
   One attribute. Two guarded one-line scripts (`out_switch_classic.lua`, `out_switch_pulse.lua`) do the same from the repo.
2. Live game: publish, then restart servers for updates. Each client keeps its style until it rejoins.
3. One screen family only: put its group in `UIStyleClassicGroups`, for example `Garage`.
4. Remove Pulse completely: run each phase's ROLLBACK in reverse order. That deletes the Pulse folders and the new attributes
   and restores the three edited scripts to their exact earlier source. The Classic check (1.8) then reports the place as equal
   to the Phase 0 record. A Roblox version-history restore to the recorded Phase 0 version is the cleaner route if several
   unrelated things have gone wrong; the handoff will say so if that applies.

### 1.6 How old and new are kept from both running

1. One latch, read once, shared by ReplicatedFirst and ClientBase.
2. One entry name, one path. `ClientLifecycle.validate` already asserts unique names; the resolver picks one path.
3. Group decision is made before any `start()`, all-or-nothing per group.
4. Pulse owners keep the Classic ScreenGui names for surfaces other scripts look up, and each Pulse `start()` first asserts that
   no ScreenGui of its name already exists. If one does, it fails loudly and builds nothing (it does not destroy it).
5. Every Pulse ScreenGui carries attribute `UIStyle = "Pulse"`. A Pulse-only start-up audit checks, once all entries are ready,
   that each reserved name exists at most once and carries the right mark for its group.
6. Build-time lint (in `build.py`, fails the build): no Pulse module requires a Classic owner module or GarageComponents (which
   holds singletons); no Pulse module creates a ScreenGui with a trap name (section 3.4); no Classic script names a Pulse module
   (they cannot, they are frozen).
7. Classic owners need no guard: they are simply never required for a routed name.

### 1.7 Optional: dashboard kill switch (not in the default build)

If Oscar wants to force Classic on live servers without a publish after the default flip: one new server module that reads
`FeatureFlags.Get("UiForceClassic", false)` and mirrors it to a fourth attribute, plus one new entry in ServerBase. That is a
fourth edited script and a new server writer, so it is offered at Phase 9 only. A fresh server would still serve the first
joiner from the saved attribute until the first snapshot arrives.

### 1.8 Existing scripts that must be edited

| Script | Phase | Edit | Why it cannot be avoided |
|---|---|---|---|
| `game.StarterPlayer.StarterPlayerScripts.ClientBase` | 1 | About 5 lines at 104-108: `pcall(require, UIStyleSwitch)`; append `ExtraEntries` when Pulse; in the resolver use `routes.Paths[entry.name] or entry.path`; write `UIStyle` to `StartupState` | It is the only code that turns an entry into a module. Any other selector would be a second start-up owner. Edited **once**; later phases add routes in the new Routes module |
| `game.ReplicatedFirst.Loading.LoadingTransitionRuntime` | 7 | Line 8: choose `PulseLoadingScreenView` when `UIStyleSwitch.Active("Shell")`, else `LoadingScreenView` | The runtime is a singleton that owns the input lock, audio duck and presentation state; it must stay one copy, and its view is hard-wired |
| `game.ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` | 7 | Two lines after line 18: when `Active("Shell")`, run `PulseInitialLoading` and return | It auto-runs. Exactly one start-screen script may call `Begin` and set `StartScreenActive` |

With `UIStyle` Classic each edited script runs the same statements as today plus one protected require of the latch.
If Oscar prefers to leave the loading bar and the two start buttons in the Classic look, Phase 7 edits nothing and the total is
one script.

Not edited, although the audit suggested additive changes: RacingUIComponents, GarageComponents, ResponsiveUIFoundation,
GarageWorkspaceUI, OwnedGarageWorkspaceUI, OwnedGarageClient, SharedTopNotificationUI, ActivityClient and its five view files,
OnboardingClient, RouteGuide, MapIconLayer, MapMath, FreeRoamMapPlayerMarkers, TimeTrialServer and every other server script.

### 1.9 Proof that Classic is unchanged

| Proof | What | When |
|---|---|---|
| Source list | `scripts/ui_restyle/classic/manifest.json`: path, class, length and two hashes for all 221 scripts, with exact source copies in `classic/before/` | Recorded in Phase 0 |
| Config record | Full typed dump of `ReplicatedStorage.Config.UI` and the UI-related service settings | Phase 0 |
| `out_verify_classic.lua` | Read-only Edit script. Recomputes both and prints one line per difference. The three declared edits must match their recorded after-hash | Inside every installer AUDIT, and on demand |
| Play record | Client-side read-only snapshot at 14 fixed points (start screen, on foot, in car, car panel, settings, race menu, race entry, dealership, customise hub, add modules, paint, full map, garage browser, garage desk): per ScreenGui name, DisplayOrder, instance count and a hash of class, name, size, position, colour, text, font and image. Cash, timers and ids are normalised. Taken twice in Phase 0 to find unstable fields | Full run after Phases 1, 7 and 9 (the phases that edit existing scripts). Short run (first four points) after every other phase |
| Start-up state | `ClientBase.StartupState` statuses and the set of console errors | Every phase, both styles |

New config goes only in a new folder (`Config.UI.Pulse`). No value in Theme, Racing, DesktopFreeRoamHud, MobileFreeRoamHud,
GarageExperience, GarageReplacement, LoadingSystem or the map folders is changed.

Classic is **frozen** for the programme. If something else has to change a Classic UI script (for example a new vehicle
category), the generated Pulse copies stop building on a hash mismatch, which forces a deliberate rebuild, and the Classic record
is re-taken.

---

## 2. Surfaces that only restyle through shared modules

| Surface | Today | Pulse route | Classic files touched |
|---|---|---|---|
| ActivityClient and JobClient, Duel, Passenger, Courier, Taxi views | ActivityClient builds `ctx.UI` inline from RacingUIComponents; the five view files only see `ctx` | New `Pulse.Activities.ActivityClient` under the same entry name. It mounts the **same five view modules, unchanged**, with a Pulse-built `ctx` that keeps the contract: `Button` returns a TextButton root; `Theme` keeps all 13 names as Color3; `Strip.Set` compares before writing; `Offer` stays one-at-a-time with an idempotent close; `ctx.Root` is a design-pixel frame so Duel's hard-coded button offsets still land (the frame is shifted to clear the Pulse bottom row). Colours passed as meaning are mapped by value: `HighSpeed` accent on a stake button draws the Buy variant, `Telemetry` accent draws the main variant | None |
| OnboardingClient | 760-line closure, saved page ids, finds targets by name, text and attribute | Phases 2 to 6: the Classic module keeps running and keeps working, because Pulse screens keep the names it looks for (3.4). Phase 7: `Pulse.Shell.OnboardingClient`, **generated** from the Classic source with about ten listed replacements (kit facade instead of RacingUIComponents, text measured in the Pulse face, three colour literals, and one stop-polling-when-complete change that is reviewed on its own). Page tables, resolvers, `MarkSeen` calls unchanged | None |
| Owned-garage desk | OwnedGarageWorkspaceUI has no view code; it draws through `GarageWorkspaceUI.new()` | `Pulse.Garage.OwnedGarageWorkspaceUI`, generated: the only replacement is the view require, pointing at `Pulse.Garage.WorkspaceView`, which implements the same view contract (`new`, `Show`, `RefreshCards`, `Message`, `Hide`, `IsTouchBlocked`, `.Root`, `.TouchMapEnabled`). The revision and request-id sequence is the same text | None |
| Toasts | Foundation controller, started by SharedTopNotificationUI | `Pulse.Shell.TopNotification` under the entry name `SharedTopNotificationUI`. Same bindable, same `(message, duration)`, same ScreenGui name and DisplayOrder 1100. Classic callers fire the bindable as before. Phase 1, because it is the smallest real proof of the switch | None |
| Confirmations | `Foundation.Confirmation(root, options, components)` | `Kit.Modal.Confirm(options)`: same options, same return table, same overlay name `SharedConfirmationOverlay`, DisplayOrder 1250, and the behaviour list from the audit copied exactly (focus save and restore, Escape and ButtonB sink at priority 10000, NO left, YES right, once-only close). Pulse owners call it; Classic owners keep calling the Foundation one. Fixes carried by the Pulse one only: a size floor on phones, and clean-up when replaced | None |
| Loading and start screens | ReplicatedFirst; view hard-wired | Phase 7. `PulseLoadingScreenView` has the same method list and the same five instance names (`LoadingSafeContent`, `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`). `PulseInitialLoading` is generated from the Classic LocalScript body with the menu builder replaced. Artwork pipeline untouched | Two (table 1.8) |
| Proximity prompts | Ten families, all engine-drawn, Style Default; the race-start prompt's Style is re-asserted by the server every 3 s | `Pulse.World.PromptView`, client only, started only under Pulse: sets `Style = Custom` **locally** on known prompts and draws `Kit.PromptBanner` on `PromptShown`. Never writes `Enabled`, never adds a `Triggered` handler. Under Classic the module is not started and prompts are exactly as today. Two engine behaviours are checked in Phase 0; if either fails, prompts stay engine-drawn under Pulse and that is recorded | None |
| Speed lines (`DrivingSpeedEffect`) | DrivingCameraClient, DisplayOrder -10, white | Left alone under both styles. It is a driving effect and style-neutral. Pulse HUD ScreenGuis keep a positive DisplayOrder | None |
| GarageEntrance status label | Private 420x42 label | Generated `Pulse.Garage.GarageEntranceClient`: the label and `flash` are replaced by the shared toast. Prompt ownership and session calls unchanged | None |
| Dealership intro objective | Off by config in v3 | Classic module runs under both styles, unchanged. If the objective returns it gets a Pulse owner then | None |
| Dev panels | Studio only | Excluded | None |

### 2.1 Generated copies: the rule

`build.py` reads the Classic source captured in `classic/before/`, checks its hash, applies a `fork_spec.json` list of
`(old text, new text, expected count)` and writes the Pulse module. Three checks run on every build:

1. The diff between Classic and Pulse is exactly the listed spans.
2. **Remote parity**: every `InvokeServer(`, `FireServer(`, `Adapter:Call(` and `request(` statement is extracted from both
   sources and the two lists must be identical.
3. Bindable fires and attribute writes are listed the same way and must match.

Generated: `Garage.GarageUI`, `Garage.OwnedGarageWorkspaceUI`, `Garage.GarageInteriorTransitionUI`,
`Garage.GarageEntranceClient`, `Shell.OnboardingClient`, `ReplicatedFirst.Loading.PulseInitialLoading`. Hand-written, with a
controller and view split and a hand-checked remote parity table: both HUDs, the race owners, the full map, the owned-garage
browser, the interior HUD.

### 2.2 Round minimap without editing the map modules

The audit proposed additive options in RouteGuide, MapIconLayer and MapMath. This proposal avoids them:

- **Clip.** The existing technique: a CanvasGroup with a UICorner of 0.5. Ring and glow are siblings above it.
- **Route line and destination blip.** `RouteGuide.newMapRenderer` unchanged, drawing into the map canvas inside the clip.
- **Edge pip and distance chip.** The renderer puts both in the `Container` it is given (lines 219 and 237). Pulse gives it a
  hidden Pulse-owned frame, so the square-clamped pip and the rounded chip never show. Pulse draws its own rim pip from
  `RouteGuide.GetActive().Position`, and its own label whose text mirrors the hidden chip's text, the only place the remaining
  route distance is exposed. That mirror is a bridge and is named as one in the contract.
- **Icons.** `MapIconLayer` in its host-projection mode (`Project` and `Size`, lines 274-275). The Pulse projection returns NaN
  outside the circle, which the layer treats as hidden (line 304). Markers flagged `EdgeClamp` are drawn on the rim by a small
  pooled Pulse layer built from `MapMarkers.All()` and `MapIconLayer.CreateIcon`.
- **Other players.** `FreeRoamMapPlayerMarkers` unchanged, given the Pulse copy of its config folder.

Cleaner later option, needing its own approval because it edits a shared script: one read-only getter in RouteGuide for the
route state. It would replace the mirror and make RouteGuide a fourth edited script.

---

## 3. The shared kit

All new. Folder `game.ReplicatedStorage.Modules.Game.UI.Pulse.Kit`. Kit modules create nothing and yield nothing when required.

### 3.1 Modules and one-line APIs

| Module | API |
|---|---|
| `Tokens` | `Colour(role) -> Color3` · `Type(role) -> {Face, CapPx, MinTextSize}` · `Num(name) -> number` · `Asset(name) -> {Image, RectOffset?, RectSize?}` · `Preflight() -> ok, reason` |
| `Metrics` | `Get() -> {Scale, Form, Input, Safe: Rect, Core: Rect, Full: Vector2}` · `Changed` · `px(n) -> integer` · `hair(n) -> integer` · `Text(role) -> textSize, uiScaleOrNil` |
| `Screen` | `Screen.new{Name, Order, Insets = "Core"\|"Device"\|"None", Live = false} -> ScreenGui` (Sibling ZIndex, ResetOnSpawn false, parent PlayerGui, mark `UIStyle = "Pulse"`, refuses trap names) |
| `Text` | `Text.new(parent, {Role, Text, Colour, Align, Wrap, Digits}) -> TextLabel` · `Text.Measure(role, text) -> Vector2` |
| `BigNumber` | `BigNumber.new(parent, {Role = "Speed"\|"Hero"\|"Position", Colour, Cells}) -> {Root, Set(text)}` |
| `Icon` | `Icon.new(parent, {Name, Size = 24, Colour}) -> ImageLabel` |
| `Glow` | `Glow.attach(target, {Kind = "Tile"\|"Button"\|"Ring", Colour}) -> {SetVisible(bool)}` |
| `Panel` | `Panel.new(parent, {Name, Size, Position, Padding = 22, Hairlines = "Both"\|"Top"\|"None"}) -> Frame` with a `Content` child |
| `Button` | `Button.new(parent, {Name, Variant = "Default"\|"Main"\|"Buy"\|"Danger"\|"Icon", Text, Icon, Enabled, Selected, OnActivated, Tutorial, Audio}) -> {Root: TextButton, Set(props), Destroy()}` |
| `Tabs` | `Tabs.new(parent, {Name, Items = {{Id, Text, Icon, Locked, Tutorial}}, Selected, OnSelect}) -> {Root, Select(id), SetItems(list)}` |
| `Tile` | `Tile.new(parent, {Name, Kind = "Part"\|"Vehicle"\|"Event"\|"Listing", Title, Sub, Image, ChipLeft, ChipRight, State, OnActivated, Tutorial}) -> {Root: TextButton, Set(props)}`; `State` is Default, Selected, Owned, Locked or Unaffordable |
| `Rail` | `Rail.new(parent, {Name, Heading, TileKind, OnSelect}) -> {Root, SetItems(listKeyedById), Select(id), ScrollTo(id)}` (pooled; no rebuild on selection) |
| `Chips` | `CashChip.new(parent) -> {Root, SetTarget(value, snap)}` · `PriceChip.new(parent, {Price, Affordable})` · `TierBadge.new(parent, {Tier, OnSelected})` · `StatusChip.new(parent, {Text})` |
| `StatusCluster` | `StatusCluster.new(parent, {Mode = "Car"\|"Garage"}) -> {Root, SetCar{Tier, Rating}, SetGarage{Used, Capacity}, SetRank(rank, progress), Cash}` |
| `SegmentedBar` | `SegmentedBar.new(parent, {Segments}) -> {Root, Set(value01, preview01)}` |
| `StatPanel` | `StatPanel.new(parent, {Name}) -> {Root, Set{Title, Tier, Rating, Lines, Rows = {{Label, Value, Bar, Delta}}}}` (rows updated in place) |
| `FactList` | `FactList.new(parent, {Name}) -> {Root, Set({{Icon, Label, Value, Chip}})}` |
| `Modal` | `Modal.open{Name, Title, Build, Buttons, OnClose, Dismissable} -> {Root, Close()}` · `Modal.Confirm{Title, Body, ConfirmText, CancelText, OnConfirm, OnCancel} -> {Root, Cancel(), Confirm(), Relayout()}` |
| `Toast` | `Toast.controller(playerGui) -> {Gui, Show(message, duration), Relayout(), Count()}` (same shape as the Foundation one) |
| `PromptBanner` | `PromptBanner.new(parent) -> {Root, Show{Action, Object, KeyCode, GamepadKeyCode, OnTap}, Hide()}` |
| `Focus` | `Focus.group(root, {Default, OnBack})` · `Focus.restore()` (controller selection, per-component selection image) |
| `Pool` | `Pool.new(factory, reset) -> {Take(key), Release(key), ReleaseAll()}` (pooled items keep their parent) |
| `Frame` | `Frame.bind(name, fn)` · `Frame.unbind(name)` · per-binding time and write counters |
| `Contracts` | Constants: DisplayOrder ladder, reserved and trap names, onboarding name table, audio attribute helpers |
| `RacingCompat` | The 20 public members of RacingUIComponents, drawn with Pulse tokens. Used only by generated copies |

Reused unchanged from Classic, because they carry no look: `ResponsiveUIFoundation.FormatNumber`, `FormatCompactMoney`,
`FormatFullMoney`, `FormatFreeRoamMoney`, `CreateCashDisplayPresenter`, `ProjectEconomy`, `BindReplicatedCash`;
`GarageModuleCardViewModel`; `GarageCatalogClient`; `MapMarkers`, `MapMath`, `MapTileSet`, `MapIconLayer`, `RouteGuide`,
`FreeRoamMapPlayerMarkers`; `Core.ConfigReader`, `Core.ConnectionScope`. One money formatter stays one money formatter.

### 3.2 Token source and reader

- Source: new folder `ReplicatedStorage.Config.UI.Pulse` with children `Colours` (Color3Value per role in the sheet),
  `Typography` (family URI, weights, `CapHeightRatio`, `BaselineShift`, cap height per role for Desktop and for Phone),
  `Shape` (hairline pixels and opacities, panel opacity, margins, `MaxAspect`), `Assets` (image ids, sheet cell size),
  `Glow` (method and opacities), `MapPlayerMarkers` (the 22 attributes the shared marker module needs, so the Classic folder is
  not touched).
- Reader: `Kit.Tokens`, built on `Core.ConfigReader` (typed, warn once). Read **once** when the kit loads; never per frame.
  Code defaults equal the config values, so a value dropped by Studio (the Foundation V1.1 lesson) changes nothing.
- The Classic colour folders and `Config.UI.Theme` are not read by Pulse and not edited.

### 3.3 Contracts every component obeys

| Contract | Rule in the kit |
|---|---|
| Onboarding names | The kit never invents a name. Callers pass `Name`, and `Tutorial = {PageId, CardId}` sets `TutorialWorkspace`, `TutorialPageId`, `CanonicalGarageCard`, `CanonicalGarageCardId`. Only the two HUD action bars may name a button `Car`, `Race` or `Garage` (lint); a tab is named `Tab_<Id>`. The three literal texts `DEALERSHIP`, `TIME TRIAL`, `RACE` are kept where onboarding matches by text. Each screen contract carries the name table from the audit |
| Audio attributes | The GuiButton is the root of every Button, Tile, Tab and row, with its label and image as descendants. Disabled, locked and unaffordable set `Active = false`. Hover and press effects change an inner frame, never the hit box. Scrims and decorative buttons set `UIAudioHoverCue = ""` and `UIAudioSuppressClick = true`. Success and reject sounds stay with the owner that already calls `PresentationAudioBridge` |
| Gamepad focus | Every interactive is Selectable; focus draws the selected state. The selection image is set **per component**, not on PlayerGui, so Classic screens keep the default box. Modals trap selection and restore the previous `SelectedObject`. Bumpers switch tabs. No key caps except on the prompt banner |
| Trailer mode | Every ScreenGui is a direct child of PlayerGui and is created when its owner starts. Content is shown and hidden with a root `Visible`. `ScreenGui.Enabled` is written only on a state change, never per frame |
| Reserved names | Kept, because other scripts look them up and only one owner runs: `DesktopFreeRoamHud` (with `DesignRoot`, `ModalLayer`, `Controls`, `CarPanel`, `Car`, `Garage`, `Race`, a showing `Minimap`), `MobileFreeRoamHud_Phase1`, `MobileDriveControls_Phase1` (`DriftLeft`, `DriftRight`, `Boost`), `ActivityHud`, `RaceBrowser` (`CardContent`, `TeleportToStart`), `RaceEntryPresentation` (`TierE`..`TierS`, `LapSelector`, `PrizeSummary`, `MedalTargets`, `RaceFormat`), `CanonicalGarageGui` > `CanonicalCanvas` > `CanonicalGarageBrowser` / `CanonicalGarageWorkspace` (`Categories`, `Stats`, `Capacity`, `UpgradeBudget`, `VehicleScroller`, `TutorialCardScroller`), `OwnedGarageBrowser` (`GarageList`, `Enter`), `SharedTopNotification`, `SharedConfirmationOverlay`, `LoadingSafeContent` and its four children |
| Trap names | Refused by `Screen.new` and by lint: `DriveHUD`, `TouchGui`, `DrivingSpeedEffect`, `RaceHud`, `RaceHud_Phase3`, `RaceCheckpointBadge_Phase5D`, `RaceQueue_Phase8`, `RaceSessionControls_Phase8C`, `RaceSessionControls_Phase8D`, `RaceResults_Phase4`, `TimeTrialResultCoach`, `RaceEntry`, `RaceEntryProbe`, `TimeTrialPersonalBestBoard`; and descendants named `GarageRoot`, `DealershipRoot`, `CustomisationRoot`, `CustomizationRoot` |
| Other fixed points | DisplayOrder numbers reused from today's ladder. `GarageSessionActive` stays the only garage-open signal. Bindables stay under `PlayerScripts.Runtime`; Pulse adds none to the authored folder. Camera orbit rule: full-screen tints are `Active = false`, panels `Active = true`. Player attributes written by the touch HUD today (`MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`, `MobileControlMode`) keep one writer |

---

## 4. Scaling, alignment and sharpness

### 4.1 One service

`Kit.Metrics` is the only code that listens to the viewport, the camera, the device safe area and `GuiService.TopbarInset`
(one set of connections, re-bound on camera change, at most one update per frame).

| Value | Rule |
|---|---|
| `Safe` | Device-safe rectangle, from `GuiService:GetInsetArea` (the method the shared confirmation already uses) |
| `Core` | `Safe` less the Roblox top bar. HUD top clusters and menu titles anchor to this |
| `Form` | `Phone`: touch is the preferred input and the safe short side is under 600 units. `Tablet`: touch preferred, 600 or more. `Desktop`: everything else. One definition, from `UserInputService.PreferredInput` (released 2025), replacing the four tests. Decided at start. A touch laptop is Desktop and gets exactly one HUD |
| `Input` | Mouse, Touch or Gamepad, live. Changes hints and whether the touch drive controls show, never the layout family |
| `Scale` (Desktop, Tablet) | `min(safeHeight / 1080, safeWidth / 1600)`, clamped 0.60 to 2.25. 1280x720 gives 0.667, 1080p 1.0, 1440p 1.333, 4K 2.0. No 1.02, 1.12 or 1.15 ceiling |
| `Scale` (Phone) | `safeHeight / 400`, clamped 0.90 to 1.30, with the Phone token set |

### 4.2 Sharpness and alignment

- **No UIScale over chrome.** Every size and position is `px(n) = round(n * Scale)`, so all edges sit on whole pixels.
  Hairlines are `hair(n) = max(1, round(n * Scale))`. Components keep their design numbers and re-apply them when `Scale`
  changes (a desktop window resize; never on a phone).
- UIScale is used in two places only, never animated: a text-only holder for text above TextSize 100, and the design-pixel
  frame handed to the unchanged activity views.
- Alignment comes from one grid: screen margin, panel padding, gaps and tile sizes are tokens; screens place components in
  rows and columns and never type coordinates. Icons share one ink box, so they line up without per-icon offsets.
- This choice is confirmed by a Phase 0 capture test against a UIScale version, because the engine's rounding of fractional
  rectangles is not documented. Default if the test is inconclusive: integer metrics.

### 4.3 Text

- Sizes are specified as **cap height** at 1080p (sheet size x 0.70): ScreenTitle 56, SectionHead 38, ButtonMain 31,
  Button and TileName 27 (21 on a rail of seven), Status 24, Tab 20, Value 18, Label 15, SpeedNumber 95, HeroNumber 140.
  `TextSize = round(cap * Scale / CapHeightRatio)`, with `CapHeightRatio` per font (Barlow 0.583, Roboto Condensed 0.607,
  Titillium Web 0.447). Minimum TextSize 13.
- Optical centring: `BaselineShift` per font. Italic labels get right padding of 0.2 x cap so the last letter is not cut.
- **Above TextSize 100.** With Barlow, ScreenTitle reaches 100 at Scale 1.04 and SectionHead at 1.53, so this affects titles
  on 1440p and above, not only numbers. Titles: TextSize 100 in a holder with a fixed UIScale. If the Phase 0 capture shows
  softness, titles stop growing at TextSize 100 above 1080p instead. Speed, hero cash and XP, and race position use
  `Kit.BigNumber`: a digit sprite sheet (0-9 and `, . : $ % + -`), fixed-width cells, tinted, sharp at any size.
- Changing numbers (cash, timer, stat values) use fixed-width digit cells when the font's digits are proportional (Barlow).
- **Player Text Size setting.** Readable roles (Label, Value, sentences, toasts, modal body, prompt banner) follow it, and
  their containers allow growth or a second line. Display roles and fixed cells are capped with a `UITextSizeConstraint`.
  Every screen gate includes a pass at Largest.

### 4.4 Phone landscape is a layout, not a shrunk canvas

Each screen ships a Desktop layout and a Phone layout in the **same phase**, both driven by one controller. Phone rules:
buttons and tiles at least 48 px on the short side, Label at least TextSize 13, 16 px margins inside the safe area, the rail
shows fewer tiles and scrolls, the stat panel collapses to name, tier and changed rows, full menus use the whole safe area.
Minimap is **top-right** on phones (steering holds bottom-left). On-foot, the bottom corners stay clear for Roblox's own touch
controls. Tablet uses the Desktop token set with touch target floors and the touch HUD arrangement.

### 4.5 Ultrawide

Corner clusters anchor to the corners of a frame capped at aspect 2.4:1 and centred, so 21:9 uses the full width and 32:9
does not push the gauge out of view. Tints and scrims always cover the whole screen from a separate full-bleed ScreenGui.

---

## 5. Performance

Quality is not traded: these are rules about wasted work, not about removing visuals.

| Topic | Rule |
|---|---|
| Static and dynamic split | Each surface has a static ScreenGui (chrome) and, where something changes every frame, a second `<Name>Live` ScreenGui: gauge and minimap content for the HUD, timer digits for the race HUD. Menus are static only. The reserved names stay on the static one |
| Pooling | Rails, lists, live-order rows, result rows and toast cards are pooled and keyed. A selection change restyles two tiles. Page changes re-bind the pool. The stat panel is built once |
| Lazy modals | Controls, Get Cash, Settings, garage modals: built on first open inside an existing ScreenGui, then kept hidden |
| Per-frame writes | No token or config lookup per frame. A property is written only when its shown value changes (whole mph, whole boost percent, arc quantised to 1 degree). No `Enabled` writes, no instance creation, no recursive search on a timer: menu state comes from the attributes and bindables that already exist. Tweens only on transitions; never tween UIScale over text or TextSize |
| Effects | Glow on at most six elements on screen. One CanvasGroup (the minimap clip, fixed size). No UIStroke for structure |

Budgets (absolute, replacing the sheet's "within 10%"; Classic is measured the same way in Phase 0 for comparison):

| Measure | Budget | Classic today (from the audit) |
|---|---|---|
| Desktop HUD instances at start | 260 or fewer | about 610 |
| One lazy modal | 120 or fewer | about 100 to 210, all built at start |
| Garage page, instances created or destroyed per click after first render | 20 or fewer | about 300 |
| Race entry, rebuild on tier or card click | none | whole page |
| HUD script time while driving | 0.25 ms per frame median on the dev PC | not measured |
| HUD property writes per frame at steady speed | 12 or fewer; none when parked | about 45 lookups and 32 gauge writes |
| UIStrokes on screen | 12 or fewer | about 40 on race entry |

How measured: `scripts/ui_restyle/tools/measure_client.lua`, pasted through `execute_luau` on the Client during Play. It counts
instances per ScreenGui by class, counts GuiButtons, strokes, gradients and CanvasGroups, records instance churn over a fixed
click sequence, and reads the `Kit.Frame` counters. Oscar can add a MicroProfiler capture; that is optional evidence.

---

## 6. Fonts and assets

- **Typeface route.** Phase 0: one real screen (Customise, the densest) drawn in a throwaway Play-only ScreenGui in Barlow
  ExtraBold Italic with SemiBold Italic (`rbxassetid://12187372847`), Roboto Condensed Bold Italic, and Titillium Web Bold
  Italic, at 1280x720, 1920x1080, 3440x1440 and phone size. Oscar picks from the capture sheet. Recommended: **Barlow** (the
  mockup's own letterforms at normal width, real 800 and 900 italics, ScreenTitle fits under 100 at 1080p). Its cost is about
  22% more width than the mockups, handled by two-line tile names, and proportional digits, handled in 4.3. The family is one
  token, so Barlow Condensed is a one-value change if Roblox adds it.
- **Preload.** `ContentProvider:PreloadAsync` for the two faces, the icon sheet and the glow images: started by the kit at
  ClientBase time from Phase 1 (the start screen covers the wait), and moved into the Pulse loading view in Phase 7. A family
  that fails to load is detected with a protected text-bounds call and replaced by the `FallbackFamily` token, warn once.
- **Icon sheet.** One 1024 px sheet, 128 px cells, every glyph pure white in the same ink box, alpha-bled. Existing white
  glyphs are exported and re-centred; missing ones are drawn (pin, set route, tick, loop, gamepad, upgrade arrow, coin, lock,
  boost, trophy, route, laps, checkpoints, players, chevrons). `Kit.Icon` tints to the text colour.
- **Glow route.** `Kit.Glow` hides the method behind a token. Default: three static 9-slice images (works on every client).
  UIShadow becomes the default only after it is seen working on a live phone and PC client.
- **Gauge.** Not built on radial gradients (Studio beta). Two half-ring images revealed by a rotating linear gradient; a
  48-segment frame arc is the fallback if the capture shows a seam.
- **Uploads, each needing Oscar's approval, in one batch from a contact sheet:** icon sheet; three glow 9-slices; gauge ring
  and tick ring; minimap ring and vignette; title mark; digit sheet (drawn from Barlow Condensed ExtraBold Italic, which its
  licence allows as an image); four restyled touch-control images. About 13 files. Ids go to `Config.UI.Pulse.Assets` and to
  `scripts/ui_restyle/assets/uploaded_assets.json`. No existing asset id is changed.

---

## 7. Roblox core UI and world prompts

One Pulse-only owner, `Shell.CoreUiPolicy`, is the single place Pulse touches core UI. Under Classic nothing changes.

| Item | Policy under Pulse |
|---|---|
| Player list (top-right, shows Cash) | Off. It sits on the status cluster and repeats the cash chip. Owner decision 6 |
| Chat (top-left) | Left on in play. The event card moves below the chat window while the window is showing. Hidden while a full menu, results or the full map is open, restored on close |
| Top bar | HUD top clusters and menu titles start below it (`Core` rectangle). Tints bleed under it |
| Gamepad selection box | Replaced per Pulse component only |
| On-foot touch controls | Engine-owned and unchanged. Phone on-foot layout keeps both bottom corners clear. Nothing is named `TouchGui` or `DriveHUD` |
| Name tags and health bars | Unchanged in both styles. Restyling them is new world UI and is out of scope |
| Core notifications | Studio tool only. Excluded |
| World prompts | `World.PromptView` (section 2). One banner component for all ten families, capitals, key cap for keyboard, button glyph for gamepad, a 48 px tap target for touch that calls `InputHoldBegin` and `InputHoldEnd`. Drawn in a ScreenGui from the prompt's world position so trailer mode hides it. Event card and Start banner read zone attributes and two existing rate-limited race requests, cached per event |

---

## 8. Navigation changes

- **Hub into tabs, and the Shop/Owned switch: out of the first garage delivery, in the programme as Phase 8.** Phase 5 keeps
  today's page graph exactly, which is what lets the garage controller be a generated copy with identical purchase calls.
  The look still reaches most of the mockup: the Add Modules pages already carry a three-item workshop rail, which the Pulse
  view draws as the Parts / Upgrades / Paint tabs; the hub's three cards become three tiles.
- Phase 8 is its own contract and acceptance: a hand-written controller change, reviewed as High-Risk, after Oscar has
  confirmed the like-for-like garage.
- **Onboarding survives without an edit.** `CustomisationHome` is a saved, server-checked page id and stays. In Phase 8 the
  tab bar carries `TutorialWorkspace` and `TutorialPageId = "CustomisationHome"`, and the three tabs carry
  `CanonicalGarageCard` with ids `AddModules`, `UpgradeModules`, `PaintShop`, so steps J1 to J3 point at the tabs. The page
  root reports the current tab's page id for the later pages. Verified with a replayed fresh profile.
- Race entry keeps today's Setup, Records, Vehicles order. Putting all three buttons on one screen is a navigation change and
  waits for the same kind of separate approval.

Not in this programme unless asked: a live minimap during races (none runs today), a per-checkpoint delta against the saved
best (the server does not send it), race-menu filter tabs, a working UI SCALE setting, cash packs.

---

## 9. Phases

All work lives in `scripts/ui_restyle/`, one sub-folder per phase, each with `CONTRACT.md` first.

### 9.1 How installs are done in v3

- **One canonical installer for the programme**: `scripts/ui_restyle/engine/installer_engine.lua`, built from the hover_feel
  engine plus the unused `create` operation from lighting_realism step 2. Operations: `source` (existing script, before and
  after hash), `create` (new ModuleScript or Folder; refuses if the path exists without the install mark), `config` (typed tree
  and typed attributes: Color3, Vector2, UDim2), `attribute` (checked against the captured earlier value). Modes AUDIT, APPLY,
  ROLLBACK. Asserts the v3 place id and Edit mode, fetches sources from `serve.py` on 127.0.0.1, checks hash and length,
  compiles every source, writes nothing if anything is unknown, restores on failure, uses ChangeHistory waypoints.
- **Two transactions per phase**: first hierarchy and config (folders, empty modules, values, attributes), verify; then sources.
  This avoids the mixed command that lost config values in Foundation V1.1. After APPLY the place is saved and reopened once,
  and AUDIT must still report "after" for every item.
- `build.py` fails if any source exceeds 150,000 characters (limit 200,000), if lint fails, or if a generated copy's checks fail.
- Every AUDIT runs the Classic check (1.9). Order of a delivery: capture, build, AUDIT, delivery-reviewer, APPLY, ROLLBACK,
  APPLY, save, Play tests, `verification.json`, docs (00, 06, one 07 entry), commit and push.
- Pulse modules are new files, so Phases 2 to 6 and 8 touch no Classic script and join none of the existing hash chains
  (GarageUI, GarageWorkspaceUI, DesktopFreeRoamHudUI).

### 9.2 Play testing without changing Oscar's profile

- **Test window.** Agent Play sessions run with the Studio no-save sandbox on
  (`Config.Player.Onboarding@StudioVehicleSandboxEveryPlay = true`; Studio only, in-memory profile, 1,000,000 cash, saves
  suppressed). A guarded script opens the window, records the earlier values, and closes it; an installer APPLY and a handoff
  both refuse while it is open. `StudioReplayEveryPlay` is turned on only for onboarding tests. Oscar set both off on purpose
  (TEST-01), so this needs his yes (decision 9).
- Phase 0 reads the save guard's full extent (owned-garage purchases in particular) before any purchase is tested. Until then
  garage-desk tests stop at preview and cancel.
- **Time trials.** Personal bests are written even in the sandbox (PB-01). Agents do not finish time trials. The results screen
  is checked by replaying recorded payload tables into the Pulse view through a Studio-only hook, and by the Quit path.
  A real finish is Oscar's own confirmation run.
- Purchases, spawns and upgrades are driven through the normal UI in the sandbox. API-driven results are labelled as such.
- Rendering is checked first in every session (RenderStepped count), as the playbook requires.

### 9.3 The phases

| # | Phase | Scope | New modules | Lane | Parallel agents (one folder each, never Studio or git) | Integrator | Gate |
|---|---|---|---|---|---|---|---|
| 0 | Lock and prove | Remaining Classic captures; Classic record (1.9); perf baseline; capture tests (three fonts, integer pixels against UIScale, text above 100, glow method, gauge arc, local prompt Style, Text Size setting, notch emulation); installer pilot with one inert module; corrected style sheet; decisions | None kept (pilot module is rolled back) | Standard; the engine itself gets a reviewer pass | Sheet rewrite; asset drawing and contact sheet; engine and its mock tests; record and measure tools; per-screen layout specs | All Studio captures and tests; pilot APPLY, ROLLBACK, APPLY, save and reopen | Oscar approves the corrected sheet and the decisions; Classic record taken twice and stable; pilot proves creating and removing a module in v3 |
| 1 | Foundation and switch | Latch, routes, tokens, the whole kit, Pulse toasts, confirm, a Studio-only component gallery | `ReplicatedFirst.UIStyleSwitch`; `Pulse.Routes`; `Pulse.Kit.*`; `Pulse.Shell.TopNotification`; `Pulse.Dev.Gallery`; `Config.UI.Pulse`; three attributes on `Config.UI`. Edits ClientBase | High-Risk | Tokens and Metrics; Text, Icon, Glow, BigNumber; Button, Tabs, Tile, Rail; Panel, chips, StatusCluster, StatPanel, FactList; Modal, Toast, Focus; latch, routes, ClientBase diff and tests; gallery | Install; pure tests through loadstring with fakes; Play in both styles | Classic: full Play record identical. Pulse: only toasts differ. Forced failure of a Pulse path falls back with one warning. Reviewer passed. Oscar accepts the gallery at four sizes |
| 2 | Free-roam HUD | Desktop, tablet and phone HUD; car panel; Controls, Get Cash, Settings; touch drive controls; activity HUD; core UI policy | `FreeRoam.HudController`, `HudDesktop`, `HudTouch`, `Minimap`, `Gauge`, `CarPanel`, `Modals`, `DriveControlsTouch`; `Activities.ActivityClient`; `Shell.CoreUiPolicy` | Standard, with High-Risk gates on spawn, despawn, exit, teleport | Controller and parity table; desktop layout; phone and tablet layout; minimap and gauge; car panel and modals; drive controls; activity context | Install; Play on desktop, phone and tablet emulation, gamepad | Remote parity table matches; single-owner list from the audit ticked; Classic map and Classic onboarding still work against it; budgets met; short Classic record; Oscar confirms in Play |
| 3 | Race session and results | In-race HUD, countdown, queue banner, wrong-way prompt, results | `Race.SessionState`, `SessionHud`, `Countdown`, `QueueBanner`, `RouteGuide`, `Results` | Standard; locked race boundaries; results only from the payload | State reducer; HUD layouts; results; countdown and queue | Install; two-client race; payload replay; Quit path | Owner keys and `KeepTelemetry` values unchanged; XP shown from the Rank attributes, not invented; budgets; Oscar confirms |
| 4 | Race menu and entry | Race browser; race entry (setup, records, vehicles) with the shared vehicle tile | `Race.BrowserModel`, `Browser`, `EntryModel`, `Entry` | Standard, gates on teleport, queue, vehicle start | Models; browser view; entry views; phone layouts | Install; Play; onboarding replay for the race pages | Names and the two literal texts kept; one render token so a late reply cannot draw into a newer page; prize preview equals the Classic rule; Oscar confirms |
| 5 | Garage, like for like | Dealership, hub, add, upgrade, paint, garage modals; owned-garage browser, desk, interior HUD, transition; entrance status | `Garage.Host`, `BrowserView`, `WorkspaceView`, `Modals`; generated `GarageUI`, `OwnedGarageWorkspaceUI`, `GarageInteriorTransitionUI`, `GarageEntranceClient`; `OwnedGarageClient`, `OwnedGarageBrowserUI`, `GarageInteriorModeUI` | High-Risk (purchases) | Views against the two context contracts; fork specs and checks; owned-garage browser; interior HUD; phone layouts | Install; sandbox purchase matrix; golden reply comparison Classic against Pulse for a fixed action sequence | Generated-copy checks pass; reply hashes equal; garage matrix from docs/13 and vehicle card V1.2; onboarding replay for garage pages; preview orbit works; reviewer passed; Oscar confirms |
| 6 | Map and world | Full map; world prompt banner; event card and Start banner | `Map.FullMapController`, `Map.FullMap`; `World.PromptView`, `World.EventCard` | Standard | Map controller; map view and legend; prompt view; event card | Install; Play with keyboard, touch, gamepad; streaming in and out | Single-owner list for the map ticked; prompts trigger the same server handlers; Classic prompts untouched under Classic; Oscar confirms |
| 7 | Shell | Loading view, start screen, onboarding copy; whole-game controller pass and Largest text pass | `ReplicatedFirst.Loading.PulseLoadingScreenView`, `PulseInitialLoading`; `Shell.OnboardingClient`. Edits the two ReplicatedFirst scripts | High-Risk (start-up, saved page ids) | Loading view; start screen fork spec; onboarding fork spec; checklists | Install; cold-start tests in both styles; full onboarding replay | Classic: full Play record identical. Pulse: start screen reachable by gamepad; every onboarding page begins and completes; reviewer passed; Oscar confirms |
| 8 | Garage navigation | Tabs replace the hub; Shop/Owned switch | Changes inside `Pulse.Garage.*` only | High-Risk, own contract | Controller change; view change; onboarding mapping | Install; sandbox matrix again; onboarding replay | Same purchase calls as Phase 5; `CustomisationHome` still completes; Oscar accepts the new flow. Can be declined without affecting anything else |
| 9 | Default flip | Whole-game matrix in Pulse; each single-group fallback smoke-tested; owner preview on a live server through the preview list; then `UIStyle = "Pulse"` | None (optional kill switch, 1.7) | High-Risk | Checklists and evidence collation | Matrix; flip; full Classic record once more | Oscar says flip. Classic stays installed and switchable. Removing Classic is a later, separate, High-Risk scope, only on his say |

Phones and controllers are designed and verified inside each phase, not at the end. A physical-device check is Oscar's, per
phase, and can lag the emulator evidence.

---

## 10. Decisions for Oscar, and risks

### 10.1 Decisions (recommended default first)

1. **Form of the backup.** Recommended: parallel Pulse modules chosen in ClientBase; Classic frozen and hash-checked; three
   scripts edited. This is the explicit request that lifts the "no in-game backup" rule, and it should be recorded as such.
   Alternative: style branches inside the existing scripts (fewer modules, but every Classic script changes and the backup
   cannot be proven identical).
2. **Where the switch lives.** Recommended: the `UIStyle` attribute on `Config.UI`, with the preview list and the group
   fallback. No dashboard flag in the first build; a kill switch can be added at the flip.
3. **Typeface.** Recommended: Barlow from the Creator Store, confirmed by the three-way capture.
4. **Sharpness method.** Recommended: whole-pixel metrics with no UIScale over chrome, confirmed by the capture test.
5. **Uploads.** Recommended: approve one batch of about 13 images from a contact sheet, including the digit sheet and 9-slice
   glows. Without the digit sheet, large numbers use text at 100 in a scaled holder and may look soft above 1080p.
6. **Roblox player list and chat.** Recommended: player list off under Pulse; chat stays in play and hides in full menus.
7. **World prompts.** Recommended: client-only Pulse banner if the two Phase 0 checks pass; otherwise prompts stay engine-drawn.
8. **Navigation.** Recommended: like-for-like garage first; tabs and the Shop/Owned switch as Phase 8 with their own sign-off.
9. **Test sessions.** Recommended: allow the Studio no-save sandbox during agent Play tests, restored afterwards; agents never
   finish time trials; Oscar does the real time-trial confirmation.
10. **Sheet reversals and gaps to confirm.** Cash becomes yellow; selection becomes a white fill; tier badges go white;
    unaffordable prices go muted; tutorial highlight becomes white with a pink connector so gold is not confused with cash;
    job markers share cyan and rely on their icons; results show XP from the rank attributes; the loading text says Pulse
    Racers. Recommended: confirm all, as the corrected sheet in Phase 0.

### 10.2 Top risks and containment

| Risk | Containment |
|---|---|
| Two copies of logic drift apart, worst where Cash is spent | Controllers that spend Cash are generated from Classic with remote parity checked on every build; hand-written controllers have a parity table and a single-owner checklist from the audit; golden reply comparison in Phase 5; Classic frozen |
| Old and new both run, or a group starts half and half | One latch; one path per entry name; group decision before any start; name assertion in every Pulse owner; start-up audit; lint. No fallback after a start has begun |
| Classic changes without anyone noticing | Hash list of all 221 scripts and a typed config record, checked in every AUDIT; new config only in a new folder; Play record compared after every phase that edits an existing script |
| Onboarding breaks through a renamed target or a lost page | Name table in each screen contract; kit sets tutorial attributes; lint on `Car`, `Race`, `Garage`; onboarding replay on a fresh profile in every screen phase; saved page ids never renamed |
| Engine unknowns: text above 100, fractional hairlines, UIShadow on live clients, local prompt Style, font loading | Phase 0 capture tests with the fallback chosen in advance for each; method behind a token so a change is one value |
| Test play alters Oscar's saved profile or personal bests | Sandbox test window with a guard and restore; no time-trial finishes by agents; payload replay; save guard read before purchase tests |
| v3 install tooling: new modules unproven, config values lost, source size | Pilot in Phase 0; hierarchy and sources in separate transactions; save and reopen check; 150,000 character build limit; ROLLBACK refuses to remove anything edited since install |
| Programme length: mixed looks for weeks, phone layouts doubling the work, Classic needing a change mid-way | Default stays Classic until Phase 9; shared controllers with two layouts; generated copies rebuild from a changed Classic source; any phase can stop and leave a working game in either style |

## 11. Not verified

- Nothing was run in Play for this proposal. The local prompt Style, text above 100, hairline rounding, UIShadow on a live
  client, the Text Size multipliers and font loading time are all Phase 0 tests.
- That `require` of every Pulse entry module is free of side effects is a rule this proposal sets, not a fact yet.
- The extent of the sandbox's no-save guard beyond the profile (owned-garage data) was not read.
- `PreferredInput` and `ViewportDisplaySize` are taken from the platform note; their values on a touch laptop need one check.
