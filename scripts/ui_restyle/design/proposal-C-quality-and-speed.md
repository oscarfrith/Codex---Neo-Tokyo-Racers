# Proposal C: Pulse UI rebuild, quality and speed first

Date: 2026-10-09. Status: proposal only. Nothing here is installed, uploaded or approved.
Place: Space Racers v3 (93959280828322). Player-facing title: Pulse Racers.
Inputs: `docs/design/pulse-racers-ui-style-sheet.md`, mockups 01, 02, 04, 05, the sixteen audit notes in `ui_restyle_audit/`.

Priority of this proposal: the best-looking, sharpest and best-performing result on PC and phone landscape, by the
shortest safe path. That means: settle the rendering unknowns first in a throwaway spike, prove the whole pipeline on
one small screen, then deliver families in the order players see them most.

Checked against live Studio today (Edit, read-only), not only the notes:
`ClientBase` 5, 104 to 112; `Core.ClientLifecycle` 20 to 47; `LoadingTransitionRuntime` 8, 33 to 47;
`InitialLoadingAndStartScreenClient` 13 to 53; `SharedTopNotificationUI` 17; `OwnedGarageClient` 8 to 9;
`OwnedGarageWorkspaceUI` 12 to 13, 30, 79; `GarageInteriorTransitionUI` 6; `GarageComponents` 294 to 311 (the canonical
host re-uses any ScreenGui named `CanonicalGarageGui`); `FullMapUI` 464 to 478; `OnboardingClient` 119 to 122,
189 to 222, 235 to 246, 459 to 463, 666 to 671; `RouteGuide` 34 to 39, 89 to 91; `ProfileServer` 179 to 226, 252;
`Config.UI` has no attributes and no `Style` child; `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay = false`,
`@StudioReplayEveryPlay = false`; `scripts/lighting_realism/step2/install.lua` has a `create` op (lines 61, 102 to 108);
`GuiService.PreferredTextSize`, `GuiService.ViewportDisplaySize` and `UserInputService.PreferredInput` are readable;
`ChatWindowConfiguration` exposes `Enabled`, alignment and `AbsoluteSize`.

---

## 0. Recommendations first

1. **Do not restyle the old UI in place. Build a second UI beside it and choose between them once, at start-up.**
   The old owners are single closures with no off switch, and the shared modules (`RacingUIComponents`, 19 users;
   `GarageComponents`, 9 users; `ResponsiveUIFoundation`) are what the backup is made of. Editing them changes the backup.
   Under this proposal four existing scripts get a small edit; every other script stays byte-identical.
2. **Run a rendering spike before any install.** Font, text above TextSize 100, hairline rasterising, glow method, gauge
   arcs, safe-area numbers and the Roblox core UI overlap are all unverified. Each one changes the kit. The spike is
   Play-only, creates throwaway client instances, saves nothing and uploads nothing.
3. **Drop UIScale for the new UI.** Every size is `round(design value x scale)` in whole pixels. This is what keeps 2 px
   hairlines, tile edges and text crisp at 720p, 1440p and on phones, and it removes the known UIScale defects (text
   flicker, scrolling canvas size).
4. **Specify text by cap height, not by TextSize.** The sheet's numbers are CSS sizes. Draw the big numbers (speed,
   results, race position) as a digit sprite sheet rendered offline from Barlow Condensed ExtraBold Italic, the mockup
   face. That beats the TextSize cap of 100, gives fixed-width digits and stays sharp at 4K.
5. **Phones get their own compositions, never a shrunken desktop canvas.** One form-factor rule replaces the four
   "is mobile" tests. Every family ships PC, phone and controller together.
6. **Set budgets and measure them at every gate**: instances, per-frame writes, frame time against today's baseline,
   minimum text size, 48 dp targets, whole-pixel geometry. Section 5 lists them.
7. **Pilot on the race menu, then go straight to the free-roam HUD.** The race menu is one owner, one remote, no
   per-frame work and has a real-capture mockup. The HUD is the highest value but is three owners with a frame loop;
   it should not be the first thing the new pipeline ever installs.
8. **Add a Studio-only gallery tool** that mounts any new view with fixture data. It lets every state be checked at every
   resolution with no server call and no profile change, and it is how parallel agents' work gets reviewed quickly.
9. **Turn the Studio no-save sandbox on for agent Play sessions** (it exists, it is off). Fix PB-01 before time-trial
   finishes are tested.
10. **Switch with a replicated config attribute, not Core.FeatureFlags.** It is deterministic for the first joiner on a
    fresh server. A dashboard kill switch can be added at the default flip if wanted.

---

## 1. Switch model

### 1.1 Where the value lives

`ReplicatedStorage.Config.UI.Style` (new Folder, authored in the place, so it replicates with the place like every
other config folder):

| Attribute | Type | Default | Meaning |
|---|---|---|---|
| `Active` | string | `"Classic"` | `"Classic"` or `"Pulse"` for everyone |
| `PulseUserIds` | string | `""` | comma list of user ids that get Pulse while `Active` is Classic (owner preview in the live game) |
| `Families` | string | `"*"` | diagnostic: limit Pulse to a prefix of delivered families, for example `"Shell,RaceMenu"` |
| `KillSwitch` | bool | absent | optional, Phase 9: forces Classic when true (written by a server projection of a dashboard flag) |

This is a recorded exception to "live-tunable behaviour reads Core.FeatureFlags", for the same reason as FEEL-01:
`FeatureFlags` is `ServerStorage.Modules.Core.FeatureFlags` and clients cannot read it.

### 1.2 Who reads it and when

New module `ReplicatedStorage.Modules.Core.UiStyle` (about 80 lines, no gameplay dependencies):

- `UiStyle.Get()` decides once and latches for the session. Order: Style folder missing or unreadable gives Classic;
  `KillSwitch == true` gives Classic; `Active == "Pulse"` gives Pulse; local user id in `PulseUserIds` gives Pulse;
  otherwise Classic. All bool reads use `value == true` or `value == false` tests (several existing readers return the
  fallback for a configured false).
- The first caller is whichever client script needs it first (from Phase 7 that is the ReplicatedFirst loading runtime;
  before that, ClientBase). The require cache makes it one answer for every client script.
- A later attribute change is ignored until the next join. That matches today's "theme edits take effect on the next
  Play start" and is the only safe behaviour, because no client owner can be stopped.
- `UiStyle.Compose(entries, stateFolder)` returns the ClientBase entry list with paths swapped for the families that
  are both delivered and active, plus any Pulse-only entries. In Classic it returns the same table untouched.
- `UiStyle.PathFor(entryName)` lets a Pulse owner find the active implementation of another owner (for example the
  HUD opening the full map) without naming a module.
- It writes `ClientBase.StartupState@UiStyle` and `@UiStyleReason` for evidence.

Routes live in a new module, `ReplicatedStorage.Modules.Game.UIPulse.Routes`: a table of families, each a list of
`entry name -> Pulse module path`, and a list of Pulse-only entries. Each family delivery edits `Routes` only, so
**ClientBase is edited once, in Phase 1, and never again.**

Entry names and dependencies never change, so no entry is ever `skipped` and no dependant is ever `blocked`. Where two
old entries become one new owner (the desktop and mobile HUDs), `DesktopFreeRoamHudUI` routes to the new HUD owner,
`MobileFreeRoamHudUI` routes to `UIPulse.Shell.Noop` (a module whose `start()` returns, as
`FreeRoamVehicleExitButtonClient` already does), and `MobileDriveControlsClient` routes to the Pulse touch controls.

### 1.3 First joiner on a fresh server

The attribute is part of the place file. It arrives with `Config.UI`, which the loading script already waits for
(`InitialLoadingAndStartScreenClient` line 13). There is no ConfigService snapshot to race, so the first joiner gets
exactly what was published. `UiStyle` waits for the `Style` folder with a bounded `WaitForChild(…, 10)` and falls back
to Classic with one warning.

If the optional dashboard kill switch is added (Phase 9): it can only force Classic, never Pulse. The one early joiner
who latches before the server's first flag snapshot gets the published default for that session. That exposure can be
closed with a wait of at most 2 seconds on a `ServerChecked` marker, applied only when `Active` is Pulse.

### 1.4 How the owner switches back

- In Studio: set `Config.UI.Style@Active` to `"Classic"`, press Play.
- Live game: publish with `Active = "Classic"` and restart servers, as for any other change. Or, if the Phase 9 kill
  switch exists, set the dashboard flag and new joiners get Classic within about a minute, with no publish.
- One family only: set `Families` to the prefix that should stay Pulse.
- Whole programme: each phase has AUDIT / APPLY / ROLLBACK built from repo before-sources.
- The old scripts are never removed by this plan. Removal is a separate High-Risk retirement, only on the owner's say.

### 1.5 Guarantees that old and new never both run

1. One latch per session (1.2).
2. Selection is a path swap under the same entry name. `ClientLifecycle.validate` asserts unique names and
   `ClientBase` 105 to 109 requires exactly one module per entry, so only one of each pair is ever `require`d. The
   unrequired one runs no line, builds no ScreenGui and binds nothing.
3. A family swaps atomically: `Compose` checks that every Pulse module of the family exists (a `FindFirstChild` walk,
   no require). If one is missing the whole family stays Classic and one warning is printed. There is no run-time
   fallback after a failed start, because a half-started owner has already connected bindables.
4. Every Pulse owner calls `UiStyle.Claim("<owner key>")` first; a second claim errors. Every Pulse owner asserts
   `UiStyle.Get() == "Pulse"`.
5. Where an old script destroys a same-named ScreenGui at start (`DesktopFreeRoamHud`, `RaceBrowser`,
   `RaceEntryPresentation`, `SharedTopNotification`, `SharedConfirmationOverlay`), Pulse reuses the name, so even a
   mistake cannot leave two on screen.
6. Every Pulse ScreenGui carries attribute `UiKit = "Pulse"`. The gate check in Play: in Classic none exist; in Pulse
   each delivered family has its Pulse ScreenGuis and no duplicate names; `StartupState` shows every entry `ready`.
7. AUDIT greps that no Classic script names a `UIPulse` path and no Pulse module requires a Classic owner.

### 1.6 Existing scripts that are edited, and why

| # | Script | Phase | Edit | Why nothing smaller works |
|---|---|---|---|---|
| 1 | `game.StarterPlayer.StarterPlayerScripts.ClientBase` | 1 | Two lines inserted between 104 and 105: protected require of `Core.UiStyle`, then `entries = UiStyle.Compose(entries, state)`. Resolver 105 to 109 untouched | It is the only code that turns an entry into a module. Old owners cannot be switched off from config (`readValue` returns the fallback for false) |
| 2 | `game.ReplicatedStorage.Modules.Game.UI.RouteGuide` | 3 | One additive read-only function after line 91: `GetRouteState()` returning `route`, `progress`, `active` | `route` and `progress` are private (36 to 38). Without a getter the new minimap must use the old renderer's fixed 10 px rounded chip and square pip, or plan a second route. No behaviour change for Classic |
| 3 | `game.ReplicatedFirst.Loading.LoadingTransitionRuntime` | 7 | Line 8 only: choose `LoadingScreenViewPulse` or `LoadingScreenView` through a protected `UiStyle` read | The view is hard-wired at require time and the runtime must stay the one singleton (input gate, audio duck, presentation state) |
| 4 | `game.ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` | 7 | One guard after line 13: in Pulse hand over to `ReplicatedFirst.Loading.StartScreenPulse.run()` and return | It auto-runs outside ClientBase. Exactly one start-screen flow may call `Begin` and set `StartScreenActive` |
| 5 (optional) | `game.ServerScriptService.ServerBase` | 9 | One entry for a new `UiStyleProjectionServer` | Only if the owner wants a no-publish kill switch |

Everything else stays byte-identical, including `RacingUIComponents`, `GarageComponents`, `ResponsiveUIFoundation`,
`UITheme`, all four colour folders, `Config.UI.Theme`, and every owner. No existing hash chain (GarageUI,
GarageWorkspaceUI, GarageModuleCardViewModel, DesktopFreeRoamHudUI) gets a new link.

Old owners that keep running under both styles, unchanged: `RaceTransitionClient`, `RaceLifecyclePresentationClient`,
`RaceEntryMenuClient`, `LoadingTransitionUI`, `DealershipIntroClient` (its pill is off in v3),
`GaragePreviewPresentationClient`, `PresentationAudioClient`, `DrivingCameraClient`, the map data modules
(`MapMarkers`, `MapMath`, `MapTileSet`, `FreeRoamMapPlayerMarkers`), `GarageModuleCardViewModel`, the five activity
view scripts, and the dev tools.

Cost stated plainly: controller logic is copied into the Pulse owners (about 450 lines for the HUD, similar for the
garage). Classic is declared frozen for a family once its Pulse version is confirmed.

---

## 2. Surfaces that today only restyle through shared modules

No shared module is made style-aware. Each surface gets one of three treatments: a Pulse owner under the same entry
name, a mechanical fork (a copy whose diff is only its require targets, proven by diff), or left as it is.

| Surface | Treatment | Detail |
|---|---|---|
| Toasts | Pulse owner, Phase 1 | Entry `SharedTopNotificationUI` routes to `UIPulse.Shell.ToastHost`. Same bindable, same `(message, duration)`, same ScreenGui name and DisplayOrder 1100, one listener. Adds scale, safe area, enter and exit fade, de-duplication of an identical live message, correct measurement |
| Confirmations | Kit function, Phase 1 | `Kit.Confirm(options)` takes the same options and returns the same `{Root, Cancel, Confirm, Relayout}` as `Foundation.Confirmation`. Behaviour copied exactly from Foundation 315 to 441: focus save and restore, Escape and ButtonB sunk at priority 10000, NO left and YES right, NO focused for keyboard and gamepad, once-only close, overlay name `SharedConfirmationOverlay`, DisplayOrder 1250. Fixes: 48 dp buttons, body auto-height, closing an older confirmation calls its cancel. Classic owners keep calling the old one |
| ActivityClient and its four views, JobClient | Pulse owner, Phase 8 | Entry `ActivityClient` routes to `UIPulse.Activity.ActivityHudClient`. It carries the non-view half (event forwarding, mount order) and builds `ctx` from the kit. The five view scripts are shared logic and stay untouched. `ctx.UI.Button` returns a TextButton root and accepts Color, StrokeColor, TextColor; `ctx.Theme` keeps all 13 names as Color3. Meaning is mapped by value inside the new ctx: accent equal to `HighSpeed` gives the Buy button, equal to `Telemetry` gives the main button, strip colour `HighSpeed` gives the alert strip. `Strip.Set` compares before writing |
| OnboardingClient | Runs unchanged until Phase 8, then Pulse owner | Until then Pulse screens satisfy its name lookups (section 3.4). In Phase 8 entry `OnboardingClient` routes to `UIPulse.Onboarding.OnboardingClient`: same pages, same saved page ids, same remotes, targets found through a registry, no PlayerGui walks on a timer, a controller route to advance, measurement with the real face |
| Owned-garage desk | Mechanical fork plus adapter, Phase 7 | Entry `OwnedGarageClient` routes to a Pulse starter. `OwnedGarageWorkspaceUI` is copied with two require targets on line 12 changed: `GarageWorkspaceUI` becomes the Pulse view, and `GarageComponents` becomes a two-function shim (`ProjectEconomy` and `ConfirmationModal`, the only members it calls, lines 30 and 79). Everything else, including every purchase call with `BaseRevision` and `RequestId`, is identical and proven by diff. The view is `UIPulse.Garage.WorkspaceView`, which accepts the existing context table and draws it with the garage screen components. The interior HUD, browser and transition modules are swapped in the same family, with the touch camera guard moved unchanged into its own module so one render-step name has one owner |
| Loading and start screens | New view plus two small edits, Phase 7 | `LoadingScreenViewPulse` has the same method list and the same instance names (`LoadingSafeContent`, `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`). `StartScreenPulse` builds Play and Shop from the kit, gives them default focus and a 48 dp height, and uses "LOADING PULSE RACERS". Artwork pipeline unchanged |
| Proximity prompts | Pulse-only client owner, Phase 5 | `UIPulse.World.WorldPromptView` (section 7.2). No server script is edited |
| Speed lines (`DrivingSpeedEffect`) | Left as it is | A driving effect at DisplayOrder -10, excluded by the sheet. Its full-screen CanvasGroup redraw is noted for a separate driving task |
| Race fade label, dealership intro pill, entrance status label | Left, left, mechanical fork | The race fade label keeps its old face for the short "RESETTING" hold (the module owns staging and camera; it is not forked). The intro pill is off in v3. `GarageEntranceClient` is forked in Phase 6 so its messages go to the toast |
| Dev panels | Excluded | Named as exclusions in sheet v2 |

---

## 3. The shared kit

### 3.1 Modules

All under a new folder `ReplicatedStorage.Modules.Game.UIPulse`. The kit is ten ModuleScripts under `UIPulse.Kit`.
Nothing in the kit requires a Classic UI module except `ResponsiveUIFoundation` for the look-free logic (money
formatters, cash presenter, `ProjectEconomy`, `BindReplicatedCash`), so there is still one money formatter.

| Module | Holds |
|---|---|
| `Kit.Tokens` | Reads `Config.UI.Style` once through `Core.ConfigReader`; frozen table; code defaults identical to config |
| `Kit.Scale` | The one scale, safe-area and form-factor service (section 4) |
| `Kit.Layers` | ScreenGui factory, DisplayOrder ladder, reserved and forbidden names, static and live layers |
| `Kit.Text` | `Text`, `BigNumber`, `Display`, measurement cache |
| `Kit.Surface` | `Panel`, `Hairline`, `Scrim`, `Glow`, `Icon` |
| `Kit.Controls` | `Button` variants, `ButtonRow`, `Tabs`, `Switch`, `Stepper`, `Dropdown`, `Slider` |
| `Kit.Collections` | `Tile`, `Chip`, `TierBadge`, `Rail`, `ListRow`, `Pool` |
| `Kit.Data` | `StatusCluster`, `CashChip`, `StatPanel`, `SegmentedBar`, `FactList` |
| `Kit.Overlay` | `Modal`, `Confirm`, `Toast`, `PromptBanner` |
| `Kit.Input` | Focus groups, back binding, bumper and trigger binding, tutorial marks, audio attributes |

Owners follow one shape: a headless `Model` (state, remotes, reducers; testable with fakes), a `View` that only draws
with the kit, and a thin `Client.start()` that wires them and owns its layers.

### 3.2 Component API, one line each

Every constructor is `Kit.X(parent, props, scope)` and returns a handle `{Instance, Set(patch), Destroy()}`. `scope` is
a `Core.ConnectionScope`. `Set` writes only properties whose value changed.

| Component | Props |
|---|---|
| `Panel` | `{Name, Size, Position, Anchor, Padding = 22, Fill = "Slate" or "Ink" or "None", Hairlines = "Both" or "Top" or "None", Active = true}` |
| `Tile` | `{Id, Name, Title, Sub, Corner = index or variant text, Status = {Kind = "Fitted" or "Owned" or "Price" or "Locked", Text, Affordable}, Image or Icon, Selected, Locked, Tutorial, OnActivate}` |
| `Rail` | `{Name, Heading, Count, TileSize, Gap = 10, Items, KeyOf, Bind = function(tile, item), Selected, OnSelect}` with `SetItems`, `Select`, `ScrollTo`; pooled |
| `Button` | `{Name, Text, Icon, Variant = "Default" or "Main" or "Buy" or "Danger" or "Icon", Price, Disabled, OnActivate, Audio}` with `SetDisabled`, `SetBusy` |
| `ButtonRow` | `{Align = "Right" or "Center", Buttons}`; order is always back or exit, secondary, main |
| `Tabs` | `{Name, Items = {{Id, Text, Icon, Locked, Tutorial}}, Selected, OnSelect, Bumpers = true}`; `Switch` is the two-option form bound to triggers |
| `StatusCluster` | `{Mode = "Drive" or "Garage", Car = {Tier, Rating}, Spaces = {Used, Capacity}, Rank, OnCashPlus, OnSpacesPlus}` |
| `CashChip` | `{Format = "Free" or "Compact", OnPlus}`; binds `leaderstats.Cash` through the Foundation presenter; lives on a live layer |
| `StatPanel` | `{Name, Width = 480}` with `Set({Title, Tier, Rating, Lines, Stats = {{Label, Value, Preview}}})`; rows updated in place |
| `SegmentedBar` | `{Segments = 20}` with `Set(value01, preview01)`; three tiled image strips, not twenty frames |
| `FactList` | `{Rows = {{Icon, Label, Value, Chip = "Cash"}}}` with `Set(rows)` |
| `Modal` | `Modal.Open({Name, Title, Size, Build = function(body, scope), OnClose, Dismissable})`; built on first open |
| `Confirm` | `Confirm({Title, Body, ConfirmText, CancelText, Variant = "Main" or "Buy" or "Danger", OnConfirm, OnCancel})` |
| `Toast` | `Toast.CreateController(playerGui)` returns `{Gui, Show(message, duration, kind), Relayout(), Count()}` |
| `PromptBanner` | `{Action, Object, Key = {Keyboard, Gamepad}, OnTouch}`; a real button of at least 48 dp on touch |
| `Icon` | `{Name, Size = 24, Colour = token}`; a rect on the icon sheet, tinted |
| `Glow` | `Glow(target, {Kind = "Tile" or "Button" or "Ring", Colour, Opacity})`; UIShadow or 9-slice by token |
| `BigNumber` | `{Role = "Speed" or "Hero" or "Position", Cells, Colour, Align}` with `Set(text)`; digit sprites, fixed cells, only changed cells written |
| `Text` | `{Role, Text, Colour, Align, Wrap}`; `Display` is the same for title roles and may use the caps atlas |

### 3.3 Token source and reader

`ReplicatedStorage.Config.UI.Style` with child folders holding typed attributes (fewer instances than Value objects):
`Colours` (Slate, White, Ink, Pink, Violet, Cyan, Yellow, TextSecondary, TextMuted, Danger, scrim colours), `Type`
(FontFamily, weights, `CapRatio`, `BaselineShift`, one cap height per role for desktop and for phone), `Shape`
(panel transparency, hairline values, margins, spacing scale 4, 8, 12, 16, 22, 32, 58, 100), `Glow` (Mode, radii,
opacities), `Assets` (sheet and ring ids), `Motion` (durations), `MapMarkers` (the 22 attributes
`FreeRoamMapPlayerMarkers` needs, with Pulse values).

`Kit.Tokens` reads once at first require, warns once per missing key and uses the code default, which matches the
sheet's failure rule. Tuning a token is a Fast-lane attribute edit that takes effect on the next Play. Old folders
(`Theme`, `Racing`, `DesktopFreeRoamHud`, `GarageExperience`, `GarageReplacement`) are not read for look and are not
changed. Colour roles are enforced: the kit takes role names, not Color3 values, except for paint swatches and medal
diamonds.

### 3.4 Contracts every component obeys

- **Onboarding names.** One table, `Kit.Input.TutorialContract`, holds every name, attribute and literal text the old
  `OnboardingClient` resolves (its lines 189 to 222): `Car`, `Garage`, `Race`, `CarPanel`, `ModalLayer`, `Controls`,
  `CardContent`, `TeleportToStart`, `TierE` to `TierS`, `PrizeSummary`, `MedalTargets`, `LapSelector`, `RaceFormat`,
  `GarageList`, `Enter`, `Categories`, `Stats`, `Capacity`, `UpgradeBudget`, `VehicleScroller`, `TutorialCardScroller`,
  the texts `DEALERSHIP`, `TIME TRIAL`, `RACE`, and the `TutorialWorkspace`, `TutorialPageId`, `CanonicalGarageCard`,
  `CanonicalGarageCardId` attributes. Views call `Kit.Input.Mark(instance, key)`, which applies the legacy name or
  attributes and registers the instance for the Phase 8 onboarding. Views never type these names. A lint fails if any
  other Pulse instance is named `Car`, `Race` or `Garage`, because `applyLocks` (666 to 671) disables every button
  with those names. `Button` shows a locked look when something sets `Active = false`.
- **Audio attributes** (`PresentationAudioClient`). The GuiButton is the visible root, or its labels are descendants.
  Disabled, locked and unaffordable set `Active = false`. Hover and press change an inner frame, never the hit box.
  Scrims and decorative buttons set `UIAudioHoverCue = ""` and `UIAudioSuppressClick = true`. Drive controls set
  `UIAudioSuppressClick`. A whole surface can set `UIAudioSilent`. Success and reject sounds stay with the one state
  owner that calls the audio bridge.
- **Gamepad focus.** Every control is a real `GuiButton`. `Kit.Input.FocusGroup(root, {Default, OnBack, OnBumper,
  OnTrigger})` sets a selection group that stops at its edges, selects the default only when the preferred input is
  gamepad or keyboard navigation, restores the previous selection on close, and binds back through
  ContextActionService. Focus uses the selected look. `PlayerGui.SelectionImageObject` is set once, in Pulse only.
  Pooled lists keep the selected instance alive, so focus is not lost on refresh.
- **Trailer mode.** Every ScreenGui is a direct child of PlayerGui, created at owner start by `Kit.Layers`.
  Content is shown with a root frame's `Visible`. `ScreenGui.Enabled` is written only on a state change, never per
  frame.
- **Reserved ScreenGui names.** Kept because other scripts look them up: `DesktopFreeRoamHud` (with `DesignRoot`,
  `ModalLayer`, `Controls` and a visible descendant `Minimap`), `RaceBrowser`, `RaceEntryPresentation`,
  `OwnedGarageBrowser`, `SharedTopNotification`, `SharedConfirmationOverlay`, `LoadingBackground`,
  `LoadingSafeContent`. Forbidden: the legacy kill list in `RaceLifecyclePresentationClient` 23 to 35 (`RaceHud`,
  `RaceEntry`, `RaceQueue_Phase8` and the rest), `DriveHUD` (it would switch on dormant code in `VehicleVFXClient`
  1053 and `ThrustPreviewClient` 29), `GarageUI`, `TouchGui`, `CanonicalGarageGui` (the old host adopts any gui of
  that name), and the roots `GarageRoot`, `DealershipRoot`, `CustomisationRoot`. `Kit.Layers` refuses a forbidden name.
- **Layer properties.** `ZIndexBehavior = Sibling`, `ResetOnSpawn = false`, `ScreenInsets = None` with layout inside
  the safe rectangle from `Kit.Scale`, attribute `UiKit = "Pulse"`.
- **Input sinks.** Full menus and modals use an active scrim so clicks do not reach the world. Garage scrims are not
  active and garage panels are, because `PreviewCameraClient` blocks orbit under any active object.
- **Single owners kept.** `RouteGuide.Update` has one caller per frame. Owner keys and `KeepTelemetry` values on
  `FreeRoamHudPresentationMode` are unchanged. `CountdownPresentationReady` is still set. Remote action names and
  payload keys are copied from the audit tables and reviewed against them.

---

## 4. Scaling, alignment and sharpness

### 4.1 One service

`Kit.Scale` holds one viewport listener for the whole new UI (rebinding on camera change), plus listeners for safe
insets, top bar inset, preferred input and preferred text size. It publishes one `Changed` signal, coalesced to once a
frame.

`Scale.Get()` returns `{Scale, Safe, Viewport, TopBarBottom, FormFactor, Input, TextFactor, Width = "Narrow" or
"Regular" or "Wide"}`. Helpers: `px(n)` (whole pixels), `hair(n)` (whole pixels, at least 1), `text(role)` (TextSize),
`Frame("Hud" or "Scene" or "Menu")` (the rectangle a composition lays out in).

### 4.2 Reference and clamps

- Safe rectangle: `GuiService:GetInsetArea(DeviceSafeInsets)` against the full screen, the pattern already used in
  Foundation 396 to 409 and `RaceSessionPresentationClient` 83 to 116. Top clusters also stay below the top bar:
  `top = max(px(margin), TopBarBottom + px(6))`.
- **Desktop composition**: design values are pixels at 1920 x 1080. `scale = clamp(min(safeW / 1920, safeH / 1080),
  0.667, 2.5)`. The floor is where a 72 px button is 48 px and Label text is 17; it is reached exactly at 1280 x 720.
  There is no ceiling short of 2.5, so the UI is the same share of the screen at 1440p and 4K (today it is 84% and
  56% for the HUD and a fixed island for menus).
- Below the floor the logical canvas gets narrower instead of the UI getting smaller. Compositions handle three
  logical widths: Narrow under 1600, Regular, Wide over 2300.
- **Phone composition**: design values are dp at a 390 dp tall reference. `scale = clamp(safeH / 390, 0.9, 1.35)`.
  A 360 dp phone gets 0.92, 390 gets 1.0, 430 gets 1.10. Nothing on a phone is ever multiplied by 0.43 again.

### 4.3 Form-factor rule (replaces the four "is mobile" tests)

- Composition: **Phone when the safe short side is under 600 dp, Desktop otherwise**, with hysteresis (leave Phone at
  640). Tablets get the Desktop composition at 0.667 and above.
- Touch affordances (48 dp minimum hit boxes, on-screen drive controls): `UserInputService.PreferredInput == Touch`,
  followed live.
- Gamepad affordances: preferred input is gamepad.
- One HUD owner picks the composition. A touch laptop gets the desktop HUD and sees drive controls only while touch
  is the preferred input. The double-HUD case cannot occur.

### 4.4 Crisp hairlines and edges

No `UIScale` anywhere in the new UI. Positions and sizes are `px()` values, so every edge is on a whole logical pixel,
and a logical pixel is a whole number of device pixels. `hair(2)` gives 1 px at 720p, 2 at 1080p, 3 at 1440p, 4 at 4K.
The 4 px tab underline and 6 px base line use the same rule. Compositions re-run their `layout()` on `Scale.Changed`;
on a phone that never happens in play, on PC it happens on a window resize. The spike confirms this against a UIScale
build and an inner UIStroke with zoomed captures.

Consequences that are improvements: `ScrollingFrame` canvas sizing is not affected by an ancestor scale; text is never
under an animated scale, so it cannot flicker; pressed and selected states move or resize frames by whole pixels and
never scale text.

### 4.5 Text

- Roles are cap heights at 1080 (sheet size x 0.70): ScreenTitle 56, SectionHead 38, HeroNumber 140, SpeedNumber 95,
  ButtonMain 31, Button and TileName 27 (21 on a rail of seven), Status 24, Tab 20, Value 18, Label 15. The phone set
  is its own list (Label 8.5, Value 10, Button 12, Title 24 dp).
- `TextSize = round(cap x scale / CapRatio)`, with `CapRatio` a font token (Barlow 0.583, Roboto Condensed 0.607,
  Titillium Web 0.447). Changing the face is a token edit. The floor is TextSize 14 on every device.
- `BaselineShift` centres capitals optically (Barlow sits 4.2% low). Italic labels get right padding of 0.2 x cap.
- At most twelve distinct text sizes exist at a time, which keeps the glyph atlas small.
- No `TextScaled`. `AutomaticSize` only on static text. Widths come from one cached measurement per string and role.

### 4.6 Numbers above TextSize 100

- **Digits**: `BigNumber` draws sprites from a digit sheet (0 to 9 and `, . : $ % + - /`) rendered offline from Barlow
  Condensed ExtraBold Italic at about 300 px cap height. Fixed cell width, so nothing jitters. Sharp to 4K for the
  results numbers. Used for speed, results cash and XP, race position and the countdown.
- **Titles**: at 1080p ScreenTitle is TextSize 96 in Barlow and fits. Above about 1100 px of height it would pass 100.
  The spike compares two routes on a zoomed capture: TextSize 100 with a static scale on that one label, and a caps
  sprite sheet (A to Z, digits, punctuation, with a kerning table) used by `Kit.Display`. If the first is soft, the
  caps sheet is used for ScreenTitle and SectionHead; it is also the only way to show the exact mockup face. `Display`
  falls back to a TextLabel for any character the sheet lacks.

### 4.7 Compositions

- **HUD** (`Frame("Hud")`): four corner clusters and one bottom-centre cluster anchored to the safe rectangle, up to
  21:9. Wider than that, clusters stay inside a centred 21:9 box.
- **Garage screens** (`Frame("Scene")`): same edges as the HUD. The rail spans the width and shows more tiles on wide
  screens.
- **Full menus** (`Frame("Menu")`): a centred block no wider than 2:1, so list and detail stay together on ultrawide.
  The tint is full-bleed.
- **Phone**: each screen has a real phone composition in its contract, drawn against 844 x 390 and 640 x 360. Fixed
  rules: 16 dp margins plus safe insets; one row of tiles, fewer and larger; the stat panel collapses to name, tier
  and changed stats; the button row sits bottom-right above the safe area; minimap top-right (steering holds
  bottom-left); gauge bottom-centre in a compact form; the on-foot thumbstick and jump zones are kept clear.

### 4.8 Player Text Size setting

Small roles (Label, Value, body) follow `GuiService.PreferredTextSize`; containers for them are sized for the largest
setting. Display roles and text in fixed chips (price, tier, tab) are capped with a `UITextSizeConstraint` so they do
not overflow. Every family is checked at the largest setting. The exact multipliers are a spike item.

The dead "UI SCALE", Graphics, Lighting and similar rows of the old settings modal are not rebuilt. Only settings that
do something appear (passenger access, minimap mode, control mode on touch).

---

## 5. Performance

### 5.1 Rules

1. **Static and live layers.** A ScreenGui re-renders whole when any descendant changes. Each family has a static
   layer (written only on interaction or state change) and, if needed, a live layer for anything that changes at
   1 Hz or more: gauge, minimap canvas, timers, cash count-up, progress bars. For the HUD: `DesktopFreeRoamHud`
   (static, DisplayOrder 85) and `PulseHudLive` (83). The minimap ring, district label and click target are a static
   frame named `Minimap`, which also satisfies `FullMapUI` 464 to 478.
2. **Pooling.** Rails, lists, leaderboards and live-order rows are keyed pools. A selection or data change creates and
   destroys no instances. Unused items are hidden, not reparented, so the z-order list is not rebuilt.
3. **Lazy modals and pages.** Built on first open. The 420 hidden modal instances of today's HUD are not built at
   start. The garage stat panel persists across pages.
4. **Per-frame code** may not call `FindFirstChild`, `WaitForChild`, `GetAttribute`, `GetDescendants` or
   `Instance.new`. Config is cached at start with change signals.
5. **Write on change.** Each live component keeps what it last wrote. Gauge angle is quantised to 0.5 degrees, speed
   digits change with the integer, minimap rotation to 0.25 degrees.
6. **Frame loops run only while their layer is shown.** They are disconnected when hidden, not early-returned.
7. **No polling for presence.** Menus opening and closing are followed through the attributes and bindables that
   already exist (`GarageSessionActive`, `FreeRoamHudPresentationMode`, `FullMapOpen`, `OwnedGarageManagementOpen`).
   No timer walks PlayerGui or Workspace.
8. **Element cost.** Button at most 4 instances (7 today), Panel at most 3 (4 to 9 today), segmented bar 4. No
   structural UIStroke, no bevel, UICorner only on the minimap. One CanvasGroup (the minimap, as today).
9. **Gauge.** Two ring images masked by rotating linear gradients, about 16 instances (32 today), at most four writes
   on a frame where the value moved. Radial gradients are Studio Beta only and are not used.
10. **Fetch first, then draw; one render token per screen.** A late reply cannot draw into a newer page. This removes
    the race-entry stale-page and duplicate-footer defects.
11. **Preview rebuilds only when the preview input changed** (today every upgrade-card select rebuilds the 3D car).

### 5.2 Budgets

Classic figures are the audit's estimates from source; the spike measures them in Play and they become the baseline.

| Surface | Classic | Pulse budget |
|---|---|---|
| Free-roam HUD at start, PC | about 610 instances | at most 260, modals 0 until opened |
| Free-roam HUD, phone | about 170 plus tiles | at most 220 |
| A HUD modal | 100 to 210, prebuilt | at most 120, built on first open |
| Garage page | 300 to 330 rebuilt on every click | at most 240 live; 0 created or destroyed on a selection |
| Race menu | 37 plus about 70 rebuilt per row click | at most 150; 0 per click |
| Race entry page | 97 to 250 rebuilt per click | at most 220; 0 per click |
| In-race HUD | 66 plus 42 rebuilt per event | at most 140; 0 per event |
| Results | 105 to 145 rebuilt per update | at most 150; rows pooled |
| Minimap route layer | 400 to 1,200 (4 per segment) | at most 64 pooled segments |
| Property writes per frame, standing still | about 14 unconditional | 0 |
| Property writes per frame, driving (HUD owner, shared map modules excluded) | 32 gauge writes plus about 14 | median at most 12 |
| Config lookups per frame | about 45 while driving | 0 |
| HUD owner script time per frame, driving, dev PC | measured in the spike | at most 0.2 ms average, 0.5 ms 99th percentile, and not above Classic |
| Frame time, same spot and same drive, 20 s | measured in the spike | Pulse not above Classic in any sample pair |
| New UI texture memory | none | at most 25 MB (sheets at 1024 or smaller) |
| UIShadow on screen | none | at most 12 (engine guidance 100) |

Legibility and alignment budgets:

| Item | Budget |
|---|---|
| Smallest text | TextSize 14 (cap height 8 px) on every device; Label 17 or more at 720p; 26 at 1080p |
| Touch targets | every active GuiButton at least 48 x 48 dp when touch is the preferred input; 8 dp between targets |
| Contrast | at least 4.5:1, or 3:1 for caps 18 px and taller. Worked from the sheet's tokens: White on Slate at 0.86 over a pure white scene is about 11.8:1; TextMuted about 6.6:1; Ink on Yellow about 15.8:1; White on the Pink to Violet button 3.1 to 4.2:1 (passes for large text only, which that label is) |
| Text over the scene | always on a scrim or with the dark shadow; checked on the brightest daytime capture |
| Truncation | `TextFits` true for every label with the longest fixture strings and the largest text setting |
| Geometry | every `AbsolutePosition` and `AbsoluteSize` in a Pulse layer is a whole number; hairlines are whole pixels |
| Alignment | cluster edges sit exactly on the margin tokens; gaps use the spacing scale only |
| HUD cover | free-roam HUD panels cover at most 12% of the screen at 1080p and 18% on a phone, touch controls excluded |

### 5.3 How they are measured

All by the integrator in Play, through read-only client probes run with `execute_luau`; no gameplay module is required.

- `tools/instance_census.lua`: descendants per ScreenGui, by class, plus counts of UIStroke, UIGradient, UICorner,
  UIShadow, CanvasGroup. Run in Classic and Pulse at the same moment of a session.
- `tools/churn_probe.lua`: counts `DescendantAdded` and `DescendantRemoving` under a layer across a scripted
  interaction (select five tiles, change tab, open and close a modal).
- `tools/static_probe.lua`: connects `Changed` on every instance of a static layer for 10 seconds of driving and
  reports any write.
- `tools/perf_sample.lua`: 20 second samples of frame time and render CPU time from `Stats`, standing and on a fixed
  drive, Classic then Pulse. `Kit.Perf` (dev attribute, off by default) adds `debug.profilebegin` labels and an
  `os.clock` accumulator around each Pulse frame step for the MicroProfiler.
- `tools/layout_lint.lua`: whole-pixel geometry, hairline thickness, minimum TextSize, `TextFits`, 48 dp targets,
  margin equality, panel overlap, HUD cover, forbidden and reserved names, missing `UiKit` attribute.
- Capture matrix per family: 1280 x 720, 1366 x 768, 1920 x 1080, 2560 x 1440, 3440 x 1440, 3840 x 2160, phone
  844 x 390 with a notch, 640 x 360, 932 x 430, tablet 1180 x 820, then gamepad.
- The emulator proves layout, not device speed. Real-phone frame time is owner-confirmed before the default flip.

---

## 6. Fonts and assets

### 6.1 Typeface route

1. Spike capture, three faces on the densest screen (Customise) at three desktop sizes and one phone: Barlow
   ExtraBold Italic with SemiBold Italic labels (`rbxassetid://12187372847`, the mockup's own design at normal
   width, 18 faces), Roboto Condensed Bold Italic (narrowest real italic, tabular digits, no weight above Bold),
   Titillium Web Bold Italic (no italic above Bold, small caps for its line height, every role from sheet size 64 up
   passes TextSize 100).
2. Recommended: **Barlow for all text, Barlow Condensed sprites for big numbers, and for titles if the spike shows
   they need it.** Barlow and Barlow Condensed are one family, so they sit together.
3. Barlow has proportional digits. Changing numbers that are not sprites (cash chip, timers, stat values) sit in
   fixed-width digit cells in `Kit.Text`. The spike also tests `OpenTypeFeatures = "tnum"`; it is not relied on.
4. The family, weights, `CapRatio` and `BaselineShift` are tokens. If Roblox adds Barlow Condensed later the swap is
   one edit. A family that fails to load is detected with a protected measurement and falls back to Roboto Condensed
   with one warning.

### 6.2 Preload

Every italic face is a cloud asset, shipped families included. The faces and sheets are preloaded with
`ContentProvider:PreloadAsync` during the first load: from Phase 7 inside the Pulse loading view, before that by the
first Pulse owner. A Pulse screen's first show waits for `Kit.Text.Ready` or 2 seconds, so no screen appears in a
fallback face and then jumps.

### 6.3 Icon sheet

One 1024 px sheet, 128 px cells with a clear gutter, every glyph drawn to the same 96 px ink box, pure white with
alpha bleed. It re-uses the existing white glyphs (exported through the existing EditableImage route and re-centred;
their padding varies from 75% to 100% today) and adds the missing or baked-colour ones: pin, set route, tick, loop,
gamepad, upgrade arrow, coin, lock, boost, trophy, route, laps, checkpoints, players, chevrons, plus, close, north
marker. Drawn with Pillow like the existing map icons. Old asset ids and folders stay where they are.

### 6.4 Glow route

`Kit.Glow` supports two modes behind `Style.Glow@Mode`. `Shadow` uses the native UIShadow (coloured, no upload,
reported fully released 2026-06-23, limit 100 on screen). `Slice` uses a 9-slice image behind the element. The spike
checks UIShadow in Studio Play, including inside a scrolling rail. UIShadow is the default if it passes; the owner
confirms it on a real device after the first publish that contains Pulse, while only the owner can see Pulse. The
three slice images are uploaded in the same batch regardless, so falling back is a token edit.

### 6.5 What must be uploaded and approved

One batch, from one contact sheet, each image needing the owner's yes. Ids recorded in
`scripts/ui_pulse/assets/uploaded_assets.json` and in `Style.Assets`.

1. Icon sheet. 2. Chrome sheet (title mark, bar segment, chequered corner, key cap, three glow slices).
3. Digit sheet. 4. Caps sheet (only if titles need it). 5 to 7. Gauge outer arc, inner arc, tick ring.
8 and 9. Minimap ring and vignette. 10 to 13. Four touch-control images redrawn white and tintable (today's are baked
teal).

Also needed: approval to download the Barlow Condensed font files (Open Font License) for offline rendering only.
Uploads go early, at the end of the spike, so moderation is finished before Phase 1 needs them. The spike itself draws
test images into in-memory EditableImages in Studio where it can, so nothing is uploaded before approval.

---

## 7. Roblox core UI and world prompts

### 7.1 Core UI policy

One Pulse-only owner, `UIPulse.Shell.CoreUiPolicy`, added by `Routes` in Phase 3. In Classic nothing changes.

| Core element | Policy in Pulse | Reason |
|---|---|---|
| Player list (top-right, shows Cash through `leaderstats`) | Disabled with `SetCoreGuiEnabled`. `leaderstats` stays; the cash binding needs it | It sits exactly where the status cluster and action bar go. Cash and rank are in the cluster; other racers are in the live order |
| Chat (top-left, enabled) | Kept. Hidden while a full menu, garage screen or results screen is open and restored after. The HUD's event card docks under the chat window, using `ChatWindowConfiguration.AbsoluteSize` | Titles and the event card are top-left |
| Top bar | All layers are full-bleed and lay out inside the safe rectangle; top clusters start below the top bar bottom | At 720p the scaled margin is smaller than the bar |
| Selection image | `PlayerGui.SelectionImageObject` set to the kit focus frame | The default blue box never shows |
| On-foot touch controls | Roblox defaults kept. Phone HUD keeps bottom-left and bottom-right clear on foot | Familiar, and `GarageInteriorModeUI` reads the thumbstick by name |
| Name tags, health | Unchanged | `RaceParticipantVisibilityClient` already manages them in races |
| Backpack, emotes, core notifications | Unchanged | Not on the screen in normal play; the Studio cash-grant toast is a dev tool |

### 7.2 World prompts

Client only, as the world-prompt note recommends (its option C). No server script is edited, which matters because
`TimeTrialServer` writes personal bests and grants rewards.

- `UIPulse.World.WorldPromptView` sets `Style = Custom` locally on known prompts as they stream in, found through
  scoped listeners on the three known roots and the two static exterior prompts. In Classic the module is never
  required, so the default prompts are exactly as today.
- It draws `Kit.PromptBanner` on `PromptShown` and removes it on `PromptHidden`. It never writes `Enabled`, never
  connects `Triggered`, never calls a remote. On touch the banner is a button that calls `InputHoldBegin` and
  `InputHoldEnd`, so the server sees the same trigger.
- Banners are **screen-anchored** in a stack in the lower-middle of the screen, not floating over the world. That
  costs nothing per frame, reads at speed, is a proper touch target and is hidden by trailer mode.
- Filtering the default prompt cannot do: no Enter banner on cars the player does not own, no desk or drive-out
  banners for visitors, none while a major menu is open.
- The event card at a race start uses the zone attributes and two existing rate-limited requests, once per show,
  cached per event.
- Three engine behaviours are settled in the spike: a local Custom survives the server's 3 second re-assert of
  Default; setting Custom before first show suppresses the default UI; `PromptShown` is steady while seated in the
  start zone. If the last fails, the Start banner uses its own zone test.
- All ten prompt families are covered, text in capitals. The only key cap in the UI is on these banners, with a
  gamepad glyph when a gamepad is the preferred input and none on touch.

---

## 8. Navigation changes

| Change in the sheet | In or out | How |
|---|---|---|
| Customise hub becomes three tabs (Parts, Upgrades, Paint) | **In**, in the garage phase, with its own contract and acceptance before the controller is written | The garage controller is new code either way; building the hub again would be wasted. Classic keeps the hub as the fallback |
| Owned and Buy become a Shop / Owned switch | **In**, same step | A view-level filter over the two row lists `GarageModuleCardViewModel` already builds |
| Race entry: Exit, View records, Choose vehicle on one screen | **In as a shortcut only** | Pages and their order stay; Choose vehicle is also offered on Setup. No page is removed |
| In-race: race timer, checkpoint pips | **In** | `StartServerTime`, `NextGateIndex`, `GateCount` are already in the payloads |
| In-race: delta chip | **Lap against best lap only** | Per-checkpoint personal-best splits are not sent |
| In-race: free-roam minimap | **Out** | No minimap runs in a race today and the map is paused on purpose. The restyled route map stays (desktop) |
| Results: driver XP hero number | **In, from replicated attributes** | Not in either payload. Shown as the change in `XpIntoRank` and `Rank` observed after the result; hidden if none arrives within 2 seconds |
| Phone minimap bottom-left | **Out** | Stays top-right |

Things the acceptance contract for the garage must restate, because they are behaviour and not look: the empty-slot
detour from Upgrades or Paint to Parts and back (`GarageUI` 274 to 282); preview clearing on tab change; Drive needing
engine, stabilisers and boost; where Back goes (to the vehicle browser when the session came from it, hidden for
drive-in); where errors go (a toast and an inline line, not the old subtitle); the Cash and Spaces plus buttons
(on the status cluster).

How onboarding survives:

- Page ids are saved, server allow-listed state and do not change.
- `CustomisationHome`: the three tabs carry the J1, J2, J3 marks (card ids `AddModules`, `UpgradeModules`,
  `PaintShop`), and the page is signalled when Customise first opens. The callout copy still makes sense pointing at
  tabs.
- `AddModules`, `UpgradeModules`, `PaintShop` pages are signalled by the matching tab being shown; their targets
  (`Categories`, `UpgradeBudget`, `TutorialCardScroller`) are marked on the rail, budget strip and slot rail.
- HUD and race screens keep the legacy names from Phase 2 onward, so the old `OnboardingClient` keeps working on them.
- The Pulse garage uses its own ScreenGui (the old canonical host would adopt a gui with its name), so the old
  onboarding cannot see garage pages between Phase 6 and Phase 8. Only preview users are in Pulse in that window, and
  the default is not flipped until the Phase 8 onboarding has passed a full replay on a fresh sandbox profile
  (`StudioReplayEveryPlay`).
- Tutorial highlight colour: white border and pink connector in Pulse, so gold is not confused with cash yellow.

---

## 9. Phases

Delivery in v3 (all phases):

- One folder, `scripts/ui_pulse/`, with a programme `CONTRACT.md`, the kit contract, one installer engine, and a
  sub-folder per phase. `studio_delivery.py`, `feature_installer.py` and `studio_capture.py` refuse v3 and are not
  used; the capture place guard is not changed.
- The engine is the `lighting_realism/step2` engine (ops `source`, `tree`, `attribute`, `property`, `create`) with
  the `hover_feel` hash guards: asserts the place id and Edit; every existing script must match its before, after or
  prior hash; sources are fetched from `serve.py` on 127.0.0.1, hash-checked and compiled with `loadstring` before
  any write; nothing is written if anything blocks.
- **New ModuleScripts** use the `create` op, which v3 has never exercised. Phase 1 starts by creating one dummy
  module, rolling it back and creating it again. Created instances carry a `PulseInstalled` marker; ROLLBACK removes
  only marked instances whose hash matches.
- **Config** uses the `tree` op with typed attributes. Hierarchy and config are written in one command and source
  edits in a second, because a mixed command once lost new config values. After the owner saves the place, AUDIT is
  re-run at the next session start to confirm the config and modules persisted. Code defaults equal config values.
- Each phase is AUDIT, review, APPLY, ROLLBACK, APPLY, Play verification, `verification.json`, docs, commit.
- **Play without touching the saved profile.** Agent-run sessions use the existing Studio sandbox:
  `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay = true` makes the session no-save with an empty garage and
  1,000,000 test Cash (`ProfileServer` 179 to 226, 252). It is flipped by a small guarded toggle that records the
  previous value and is restored and checked before the owner saves. Purchases, paint, garage property and race
  rewards are then safe to exercise. Personal bests are the exception (PB-01: they are written even in the sandbox),
  so no agent session crosses a time-trial finish line until PB-01 is fixed or the owner allows it; results views are
  verified from gallery fixtures and a quit result. Multi-player race checks use a two-player local test, which uses
  test accounts. Real-profile runs are the owner's confirmation only.
- The gallery (`UIPulse.Dev.Gallery`, Studio-only, behind a new `ClientTools@PulseGalleryEnabled`) mounts any view
  with fixtures in its own ScreenGui. No remotes, no profile.
- Parallel agents never touch Studio or git and get one folder each. The integrator writes the contract first, owns
  Studio, the installer runs, captures, uploads, Play tests and git.

| # | Phase | Scope | New modules and config | Lane | Agents and integrator | Gate that ends it |
|---|---|---|---|---|---|---|
| 0 | Spike and sheet v2 | Play-only throwaway harness; no install, no upload. Font three-way; text over 100; hairlines; UIShadow against slice; gauge arcs; round minimap; safe-area and top bar numbers on an emulated notched phone; player list and chat rectangles; text-size setting; prompt checks; Classic baselines; captures of the screens the sheet never captured | None in the place. `scripts/ui_pulse/p0_spike/` holds the harness, captures, `baseline.json`, asset generators and the contact sheet | Fast (read-only plus transient client instances) | Agents: asset generators, sheet v2 draft, fixture lists. Integrator: every Studio step | Owner picks the face and approves sheet v2 (cap heights, corrected errors, phone metrics, budgets), the asset batch, the phase list and the decisions in section 10 |
| 1 | Foundation and switch | `Core.UiStyle`, `UIPulse.Routes`, `Config.UI.Style`, the ten kit modules, `ToastHost`, `Kit.Confirm`, gallery, probes. ClientBase edit | As listed | High-Risk | Agents: one per kit module group, installer engine with mock tests, gallery fixtures. Integrator: contract, UiStyle, Routes, ClientBase edit, install | Create-op proof; APPLY, ROLLBACK, APPLY; reviewer; Classic: hashes of all other scripts unchanged, captures match baseline, all entries ready; Pulse: toast and a gallery confirmation pass lint at every size; persisted after save |
| 2 | Pilot: race menu | `RaceBrowser` on PC, phone and gamepad, against mockup 02 | `UIPulse.Racing.RaceMenu{Model,View,Client}` | Standard | Agents: model, desktop view, phone view. Integrator: install, Play | Lint and budgets pass on the matrix; 0 instances churned per row click; old onboarding still finds `CardContent` and `TeleportToStart`; teleport and set-route sequences unchanged; switch off and on; owner confirms |
| 3 | Free-roam HUD | One HUD owner with desktop and phone compositions, gauge, round minimap, status cluster, action bar, car panel, lazy Controls, Settings and Cash modals, touch drive controls, core UI policy. `RouteGuide` getter | `UIPulse.Hud.*`, `UIPulse.Map.{MinimapView, IconLayer, RouteLayer, MapMathEx}`, `UIPulse.Shell.CoreUiPolicy` | Standard, with High-Risk checks on spawn, despawn, exit, teleport | Agents: model, gauge, minimap, car panel and modals, phone composition, touch controls. Integrator: RouteGuide edit, install, Play | All section 5 HUD budgets against baseline; first-drive controls flow; full map opens by M and Select; old onboarding locks and callouts work; no double HUD on a touch-plus-keyboard emulation; reviewer on the RouteGuide edit; owner confirms on PC and phone |
| 4 | Race session | In-race HUD (position, lap, timer, pips, live order, route map, wrong-way), countdown, queue banner, results, route-guide pill | `UIPulse.Racing.{RaceSessionModel, RaceHud, Countdown, Queue, Results, RouteGuidePrompt}` | Standard, with a High-Risk check that results are a projection of the payload | Agents: session model with payload fixtures, HUD view, results view, small owners | `CountdownPresentationReady` still set and staging not degraded; owner keys and `KeepTelemetry` unchanged; HUD does not return after finish or exit; exit confirmation uses `Kit.Confirm`; fixtures cover every result state; two-player check; no PB written by an agent |
| 5 | Race entry and world prompts | Entry tabs, tier rail, records, vehicle choice; prompt banners for all ten families; event card | `UIPulse.Racing.RaceEntry*`, `UIPulse.World.WorldPromptView` | Standard | Agents: entry model, views, prompt view | Old onboarding pages EventMode, TimeTrialSetup, RaceSetup resolve; no stale page or duplicate footer under rapid clicks; `StartSelectedVehicle` payload identical; prompts trigger by key, pad and touch; Classic prompts untouched |
| 6 | Garage | Dealership, Customise with tabs, module shop with Shop / Owned, upgrades, paint, post-purchase paint, the three garage modals, entrance client fork | `UIPulse.Garage.{GarageModel, GarageApp, GarageScreen, PaintPanel, Modals}`, entrance fork | Standard for look; High-Risk for the navigation change and every purchase path | Agents: model, screen, paint, phone composition, fixtures. Integrator: navigation contract first, accepted in the gallery before the controller is built | Navigation acceptance signed; action names, payloads and busy guard reviewed against the audit table; affordability is the server projection; orbit works under scrims; 0 churn on selection; preview rebuilt only on change; sandbox purchase matrix; reviewer; owner confirms a real purchase |
| 7 | Loading, start screen, owned garage | Pulse loading view and start screen (two ReplicatedFirst edits); owned-garage browser, desk through the adapter, interior HUD, transition | `LoadingScreenViewPulse`, `StartScreenPulse`, `UIPulse.OwnedGarage.*`, `UIPulse.Garage.WorkspaceView` | High-Risk (start-up path; desk purchases) | Agents: views, adapter, browser model. Integrator: forks by diff, ReplicatedFirst edits | Rendering check first; start flow completes in both styles; Play reachable by pad and keyboard; fork diffs are only the require targets; one camera-guard owner; desk purchases in sandbox; reviewer |
| 8 | Full map, activity HUD, onboarding | Pulse full map; activity `ctx` from the kit; registry-based onboarding | `UIPulse.Map.FullMap*`, `UIPulse.Activity.ActivityHudClient`, `UIPulse.Onboarding.*` | Standard; onboarding High-Risk (saved page state) | Agents: map controller and view, activity ctx, onboarding model and view | Full onboarding replay on a fresh sandbox profile, PC and phone, every page marks seen once; no timer walks PlayerGui; five activity views work untouched; full map by mouse, touch and pad |
| 9 | Default flip | `Active = "Pulse"`; optional dashboard kill switch (ServerBase entry); docs; superseded design docs marked | Optional `UiStyleProjectionServer` | High-Risk | Integrator only | Whole-game pass in both styles; real-phone frame time confirmed by the owner; switch back proven after the flip; Classic recorded as frozen backup. Removing Classic is not in this plan |

---

## 10. Owner decisions and top risks

### 10.1 Decisions, each with a recommended default

1. **Switch carrier.** Default: the replicated attribute in 1.1 with an owner preview list, recorded as an exception
   to the FeatureFlags rule. Add the dashboard kill switch at the flip only if a no-publish rollback is wanted.
2. **Typeface.** Default: Barlow for text and Barlow Condensed sprites for big numbers, final after the spike capture.
   Approve downloading the Open Font License files for offline rendering.
3. **Assets and glow.** Default: approve one batch of about thirteen images from one contact sheet; UIShadow glow if
   the spike passes, slice images uploaded anyway as the fallback; no whole-screen blur.
4. **Sheet reversals.** Default: as the accepted mockups. Cash yellow, white selection, white tier badges, muted
   unaffordable price, no structural pink outlines, square corners, tutorial highlight white and pink.
5. **Navigation.** Default: section 8. Tabs and the Shop / Owned switch in, with their own acceptance; race entry
   keeps its pages; no free-roam minimap in races; results XP from attributes.
6. **Roblox core UI.** Default: hide the player list in Pulse; keep chat and hide it during full menus; event card
   docks under chat.
7. **World prompts.** Default: client-only custom banners for all ten families, screen-anchored, in Phase 5.
8. **Test mode.** Default: Studio sandbox on for agent sessions through a guarded toggle; approve a separate small
   fix for PB-01 before Phase 4, otherwise no agent crosses a time-trial finish.
9. **Delivery route and backup policy.** Default: the dedicated `scripts/ui_pulse` installer; capture place guard
   unchanged; the ten phases approved as listed; Classic frozen per family once its Pulse version is confirmed.
10. **Settings and small scope items.** Default: only working settings are shown; the player's Roblox text-size
    setting is honoured; the full map keeps an input hint strip as the one exception to "no key hints"; dev panels,
    speed lines and the race fade label are excluded.

### 10.2 Top risks and how each is contained

1. **Copied controller logic drifts or diverges from the old behaviour.** Models are headless and tested with payload
   fixtures; forks that only change requires are proven by diff; remote actions and payload keys are reviewed against
   the audit tables; Classic is frozen, not maintained in parallel.
2. **Old and new both live, or a mixed set that does not fit together.** One latch, name-keyed routes, atomic
   families, owner claims, reused ScreenGui names, the `UiKit` census at every gate, and a delivery order in which a
   newer Pulse family only ever meets older Classic families.
3. **A rendering assumption is wrong** (text above 100, UIShadow on live clients, hairlines, CanvasGroup on weak
   phones). The spike decides with captures before anything is built; glow mode, face and big-number route are tokens
   or isolated functions; the owner checks a real device while only he can see Pulse.
4. **Onboarding breaks silently.** One contract table applied by the kit, a lint for reserved names, the old client
   left running until its replacement exists, page ids untouched, a full replay on a fresh sandbox profile before the
   flip.
5. **Testing or a new controller changes real Cash, purchases or personal bests.** Sandbox no-save sessions, the PB-01
   rule, gallery fixtures for result states, High-Risk review of every purchase path, owner confirmation of one real
   purchase per family.
6. **The v3 install route fails for new modules or loses config.** Dummy create proof first, hierarchy and source in
   separate commands, save and re-audit, code defaults equal to config, ROLLBACK rebuilt from repo before-sources.
7. **The garage phase grows.** Navigation is accepted in the gallery before the controller is written; the phase has
   one contract and one installer; Classic remains the working fallback throughout; phases are approved up front and
   not split without asking.
8. **Roblox core UI or moderation gets in the way.** One Pulse-only core UI owner with reserved rectangles; uploads
   made at the end of the spike so moderation is done before use; ids in config; an icon that fails to load falls
   back to a text label.

### 10.3 Corrections to carry into sheet v2

Font assumption (Barlow is available, Barlow Condensed is not); sizes are cap heights, not CSS sizes; nothing above
TextSize 100 except as sprites; the switch is a replicated attribute, not Core.FeatureFlags; there is no
`GarageReplacementComponents` (the old card is `GarageComponents.VehicleCard`, the new one is `Kit.Tile`); the route is
`scripts/ui_pulse`, not `studio_delivery.py`; the foundation step is High-Risk; "within 10% of today" is replaced by
the budgets in 5.2; the phone minimap is top-right; results XP is not in the payload; phone and controller ship with
each family; dev panels, speed lines and the dealership intro pill are named exclusions.

### 10.4 Not verified

Nothing was run in Play for this proposal. Every Classic instance count and pixel size comes from the audit's source
reading. UIShadow, text above 100 px, fractional rasterising, the text-size multipliers, the chat window rectangle
(it reads 0, 0 in Edit) and the three prompt behaviours are spike items. Real-device speed is unknown until the owner
tests a phone.
