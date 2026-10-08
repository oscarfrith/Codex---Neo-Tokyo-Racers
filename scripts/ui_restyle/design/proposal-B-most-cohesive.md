# Proposal B: one kit, one switch, every surface

**Date:** 2026-10-09
**Status:** Proposal for Oscar's decision. Nothing here is installed. Written read-only against live Studio "Space Racers v3" (93959280828322, Edit) and the sixteen audit notes.
**Priority of this proposal:** the most cohesive, consistent and maintainable end state. One source of truth for tokens, scale, safe area, form factor and components. Every surface on the same kit. As little logic as possible existing twice.

## 0. Summary

- **One new kit** (`ReplicatedStorage.Modules.UIKit`) holds every token, the one scale and safe-area service, and every component. Nothing in the new UI sets a colour, font, size or margin of its own.
- **One switch**, one string attribute, read once per session by one module. It chooses the whole UI set at the composition root, before any UI module is required.
- **The old UI stays in the place as the backup.** All old view code is untouched. Old owners whose logic and view are fused in one closure are never edited; the new UI gets new owner modules built as a headless model plus a view.
- **Nine existing scripts get a small seam edit** (section 1.5). This is the honest cost: the backup is not byte-identical everywhere. Each edit has an exact Classic branch, and the other 212 of 221 scripts in the place stay byte-identical.
- **Every surface moves to the kit**, including the ones the style sheet did not reach: activity HUD, onboarding, owned-garage desk, toasts, confirmations, loading and start screens, world prompts.
- **Phone landscape gets real layouts**, not the desktop canvas shrunk to 0.43.
- **Ten phases**, each behind the switch, default Classic until Oscar flips it.

Terms used below: **Classic** = today's UI. **Pulse** = the new UI. **dp** = a design pixel at the 1920x1080 reference.

### What I verified live for this proposal

| Fact | Source |
|---|---|
| ClientBase resolves every entry in one callback | `ClientBase` L105-108; lifecycle requires one module per entry, `Core.ClientLifecycle` L38-44 |
| A skipped dependency blocks its dependants | `ClientLifecycle` L29, L36 |
| `Config.UI` has no attributes and no `Style` child today | Edit probe |
| `ReplicatedStorage.Modules.Core` holds ClientLifecycle, ConnectionScope, ConfigReader, PathResolver, Signal, Tags, CameraService; no flag reader | Edit probe |
| Loading view is hard-wired | `LoadingTransitionRuntime` L8 (`require ... LoadingScreenView`), L40 (colours folder), L47 (`View.Create`) |
| Start screen auto-runs, waits for `Config.UI.LoadingSystem`, requires RacingUIComponents | `InitialLoadingAndStartScreenClient` L13, L15-18, L22-23, L38, L78-88 |
| Toast controller is chosen in one line | `SharedTopNotificationUI` L17 |
| Owned-garage sub-modules are started from one order table | `OwnedGarageClient` L8-9 |
| The desk controller requires its view and component library on one line and uses only `ProjectEconomy`, `ConfirmationModal`, `UI.Asset` from them | `OwnedGarageWorkspaceUI` L12-13, L30, L79 |
| Activity views are found by name and get a `ctx` | `ActivityClient` L23-43, L71-88, L293 |
| Both HUDs find the full map by module name | `DesktopFreeRoamHudUI` L960, `MobileFreeRoamHudUI` L260 |
| Private status label with a Michroma literal | `GarageEntranceClient` L70-106; `RaceTransitionClient` L57-72 |
| Requirer counts: RacingUIComponents 19, GarageComponents 9, ResponsiveUIFoundation 8 | Edit probe |
| `GuiService.ViewportDisplaySize`, `UserInputService.PreferredInput`, `GuiService.PreferredTextSize`, `UIShadow`, flex on `UIListLayout` all exist in this Studio build | Edit probe (unparented temporaries, destroyed) |

Not verified by me: anything that needs Play. Those items are listed as spike work in Phase 0.

---

## 1. Switch model

### 1.1 Where the value lives

Two attributes on the existing folder `ReplicatedStorage.Config.UI`:

| Attribute | Type | Meaning |
|---|---|---|
| `UIStyle` | string | `"Classic"` or `"Pulse"`. Absent or any other value means Classic. |
| `UIStylePreviewUserIds` | string | Comma-separated user ids that get Pulse whatever `UIStyle` says. Lets Oscar see Pulse in the live game while everyone else stays on Classic. |

Why here and not `Core.FeatureFlags`:

- FeatureFlags is `ServerStorage.Modules.Core.FeatureFlags`. Clients cannot read it.
- The loading script already waits for `Config.UI.LoadingSystem` (L13). Attributes arrive with their instance, so `Config.UI` attributes are present before the first UI line runs, in ReplicatedFirst and in ClientBase. No new wait, no race.
- It is a string compared with `==`. The "configured false returns the fallback" defect in several existing readers cannot occur.
- A plain replicated config value for a client switch has a recorded precedent (FEEL-01, hover_feel).

This is a recorded exception to "live-tunable behaviour reads FeatureFlags". See decision D2 for the optional server projection at the default flip.

### 1.2 Who reads it and when

One new module, `ReplicatedStorage.Modules.Core.UIStyle` (about 70 lines, no kit dependency):

```text
UIStyle.Name            "Classic" | "Pulse"      latched at first require, never re-read
UIStyle.IsPulse         boolean
UIStyle.PathFor(entryName, classicPath) -> path  for ClientBase entries
UIStyle.ModuleFor(key, classicModule) -> ModuleScript   for the three non-entry seams
UIStyle.Claim(surface)  asserts IsPulse and that nobody claimed this surface yet
UIStyle.Resolved()      table of what each entry and key resolved to (diagnostics)
```

- The require cache gives ClientBase, the loading runtime and the start screen the same latched value.
- The Pulse paths are data in `ReplicatedStorage.Modules.Core.UIStyleManifest`. In Classic the manifest is never consulted, so a manifest mistake cannot break Classic.
- Each phase adds its lines to the manifest. An entry with no manifest line keeps its Classic path. So during the build "Pulse" means "every surface converted so far"; the rest stay Classic.
- Missing Pulse module: `PathFor` checks with a non-yielding `FindFirstChild` walk, warns once and returns the Classic path. **There is no fallback after a require or start failure.** A Pulse owner that fails half-built leaves its entry `failed` in `ClientBase.StartupState`; starting the Classic owner on top of it would be two owners.

### 1.3 What a first joiner on a fresh server gets

The value saved in the place. It replicates with `Config.UI`. There is no server boot timing, no ConfigService snapshot and no default-until-ready window. Every joiner on every server gets the same answer.

### 1.4 How Oscar switches back

1. **Switch (seconds).** In Studio: select `ReplicatedStorage.Config.UI`, set `UIStyle` to `Classic`, Play. In the live game: publish with that value. The whole set changes on the next join. A style cannot change mid-session, because no owner has a stop.
2. **Phase rollback (minutes).** Every phase has AUDIT / APPLY / ROLLBACK. ROLLBACK restores the seam-edited scripts byte-exact from repo before-sources and removes the modules and config that phase created.
3. **Place baseline.** Before Phase 1: the Roblox place version is recorded in `docs/00_START_HERE.md`, a local copy of the place is saved outside git, and every client script source is captured to the repo with hashes.

### 1.5 Existing scripts that must be edited

Everything not in this table stays byte-identical. The rule for what may be edited:

- **a composition or selection point** (the three start-up scripts);
- **a single-owner logic script whose own view is already separate or very small** (one label, or art ids and margins), where forking would duplicate purchase, session, race-staging or driving-input logic;
- **a shared renderer both styles use**, extended with options that are off by default.

Owners with logic and view fused in one closure are never edited. They are replaced by new modules chosen by path.

| # | Script | Edit | Why it cannot be avoided | Phase |
|---|---|---|---|---|
| 1 | `game.StarterPlayer.StarterPlayerScripts.ClientBase` | L105-108: walk `UIStyle.PathFor(entry.name, entry.path)` instead of `entry.path`. Three new entries: `WorldPromptClient`, `CoreUiPolicyClient` (Classic path is the inert `Core.UIStyleInactive`), and the Studio tool `UIKitGalleryClient`. One `StartupState` attribute `UIStyle`. About 8 lines. | It is the only code that turns an entry into a module. Skipping entries blocks dependants. | 1 |
| 2 | `game.ReplicatedFirst.Loading.LoadingTransitionRuntime` | L8: `View = require(UIStyle.ModuleFor("LoadingView", LoadingScreenView))`. One line. | The runtime is the singleton that owns the input gate, audio duck and presentation state. It must not be forked. | 2 |
| 3 | `game.ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient` | After L13: if Pulse, `require(UIStyle.ModuleFor("StartScreen")).run()` and return. Three lines. | A LocalScript auto-runs. Exactly one start screen may call `Begin` and set `StartScreenActive`. | 2 |
| 4 | `game.ReplicatedStorage.Modules.Game.UI.OwnedGarageWorkspaceUI` | L12: the `WorkspaceUI` and `Shared` requires go through `UIStyle.ModuleFor`. One line, two tokens. | It is a pure controller (no `Instance.new`) that sends every owned-garage purchase with `BaseRevision` and `RequestId`. One purchase controller for both styles is safer than two. | 6 |
| 5 | `game.ReplicatedStorage.Modules.Game.UI.MapIconLayer` | Additive, default-off options: circular inside test and edge clamp, optional tint, icon scale. About 25 lines. | Shared pooled renderer for both minimaps and the full map. A round minimap cuts rim icons with today's rectangular clamp. | 3 |
| 6 | `game.ReplicatedStorage.Modules.Game.UI.RouteGuide` | Additive: renderer options (circular edge-pip clamp, chip style and scale) and a read-only route getter. About 30 lines. | Singleton route state shared by both styles. Its renderer hard-codes a square clamp and a fixed chip. | 3 |
| 7 | `game.ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient` | L64-71: label font and colour from `UIKit.Tokens` when Pulse. About 4 lines. | It owns the staging acknowledgement, the camera and the loading generation. It must not be forked; its one label carries a Michroma literal. | 4 |
| 8 | `game.ReplicatedStorage.Modules.Game.Dealership.GarageEntranceClient` | L70-106: when Pulse, do not build the private status label; `flash` fires `ShowTopNotification`. About 6 lines. | It owns the three entrance prompts and the garage session request. Its only UI is one fixed-pixel label. | 6 |
| 9 | `game.ReplicatedStorage.Modules.Game.Vehicles.MobileDriveControlsClient` | When Pulse: art ids and tints from tokens, margins from the shared safe-area service. About 20 lines. | It is the sole writer of `MobileDriveInputState`. Forking it would duplicate driving input. | 7 |

No server script is edited. No remote, payload, saved field or economy value changes.

Config changes: the two attributes above, one new folder `Config.UI.Style`, and one tool flag `Config.Development.ClientTools@UIKitGalleryEnabled`. `Config.UI.Theme`, `Racing`, `DesktopFreeRoamHud`, `MobileFreeRoamHud`, `GarageReplacement`, `GarageExperience` and `LoadingSystem` are not edited. Pulse reads their **behaviour** values (map calibration, `SpeedGaugeMaxMph`, cash count-up, loading timings) so those stay single-sourced, and takes every **look** value from the kit.

### 1.6 Which entries change path under Pulse

| ClientBase entry (name unchanged) | Classic module (frozen) | Pulse module |
|---|---|---|
| `SharedTopNotificationUI` | `UI.SharedTopNotificationUI` | `Screens.System.ToastOwner` |
| `ActivityClient` | `Activities.ActivityClient` | `Screens.Activities.ActivityHud` |
| `DesktopFreeRoamHudUI` | `UI.DesktopFreeRoamHudUI` | `Screens.Hud.FreeRoamHud` (one owner for every form factor) |
| `MobileFreeRoamHudUI` | `UI.MobileFreeRoamHudUI` | `Core.UIStyleInactive` |
| `FullMapUI` | `UI.FullMapUI` | `Screens.Map.FullMap` |
| `RaceBrowserClient`, `RaceEntryPresentationClient` | same names in `Racing` | `Screens.Racing.RaceBrowser`, `Screens.Racing.RaceEntry` |
| `RaceSessionPresentationClient`, `RaceCountdownPresentationClient`, `RaceQueueClient`, `RaceTimeTrialResultCoachClient`, `RaceRouteGuideClient` | same names in `Racing` | `Screens.Racing.RaceHud`, `RaceCountdown`, `RaceQueue`, `RaceResults`, `RaceRouteGuide` |
| `GarageUI` | `Garage.GarageUI` (+ GarageBrowserUI, GarageWorkspaceUI, GarageComponents) | `Screens.Garage.GarageApp` |
| `OwnedGarageClient` | `UI.OwnedGarageClient` | `Screens.Garage.OwnedGarageClient` (starts the Pulse browser, the shared desk controller, the Pulse interior HUD and transition) |
| `OnboardingClient` | `UI.OnboardingClient` | `Screens.System.Onboarding` (Phase 7) |
| `WorldPromptClient`, `CoreUiPolicyClient` (new) | inert | `Screens.System.WorldPromptClient`, `Screens.System.CoreUiPolicyClient` |

Unchanged and shared by both styles: `RaceTransitionClient`, `RaceLifecyclePresentationClient`, `RaceEntryMenuClient`, `RaceParticipantVisibilityClient`, `RaceSessionAssetsClient`, `LoadingTransitionUI`, `DriveSessionClient`, the audio runtimes, `GaragePreviewPresentationClient`, `ThrustPreviewClient`, `RuntimeVFXClient`, `DealershipIntroClient`, the five activity views, `MapMarkers`, `MapMath`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `GarageModuleCardViewModel`, `GarageCatalogClient`, the preview and camera modules, and the dev tools.

### 1.7 How old and new are guaranteed never to run together

1. **One latch.** The value is read once and cannot change in a session.
2. **One resolver.** Each entry name resolves to exactly one path, and `ClientLifecycle` requires exactly one module per entry. The other module of a pair is never required, so it creates no ScreenGui, binds no bindable and calls no remote.
3. **Claim.** Every Pulse owner calls `UIStyle.Claim("<surface>")` first. It asserts Pulse is active and the surface is unclaimed. A manifest mistake fails loudly at start instead of running two owners.
4. **Same names where a second copy would collide.** Pulse reuses the ScreenGui names that Classic owners destroy on start and that other scripts look up (`DesktopFreeRoamHud`, `RaceBrowser`, `RaceEntryPresentation`, `OwnedGarageBrowser`, `SharedTopNotification`, `SharedConfirmationOverlay`, `ActivityHud`, `LoadingSafeContent`). Two can never coexist silently.
5. **Parity audit at every phase gate.** A read-only script run in the Client datamodel during Play lists every ScreenGui under PlayerGui. Every Pulse ScreenGui carries the attribute `UIStyle = "Pulse"`. In Classic there must be none. In Pulse, every game ScreenGui must either carry it or be on the short shared list (touch drive controls, speed lines, race fade, dev panels, Roblox's own).

### 1.8 What this costs the backup, plainly

- **Nine scripts are not byte-identical.** About 100 changed lines in total, each with an exact Classic branch.
- **Classic is frozen at the baseline.** Bug fixes and features after Phase 1 land in Pulse only. The backup is "the UI as it was on the baseline date", guaranteed to run for as long as server payloads stay as they are. This plan changes no payload. Any later server change must either keep Classic working or Oscar ends the backup.
- **Logic exists twice while the backup exists.** Rough count of controller logic copied once into headless Pulse models: free-roam HUD 450 lines, garage 500, race menus 500, race session and results 350, route guide 300, full map 400, onboarding 450, interior camera guard 200, start screen 110, activity glue 90, owned-garage browser 80. About 3,400 lines. Against that, the desktop and phone HUD owners (two copies of the same logic today) become one model, and five copies of the minimap maths become one.
- **Two shared renderers gain options** (`MapIconLayer`, `RouteGuide`). Defaults reproduce today's output; the risk to Classic is small but not zero.

The alternative that removes the duplication (edit every old owner so both styles share one controller) would rewrite the code the backup is supposed to preserve. I do not recommend it. The alternative that keeps all 221 scripts byte-identical leaves the owned-garage desk, the race fade label, the entrance label and the touch controls in the old look, or forks purchase and driving-input logic. I do not recommend that either.

How the backup is kept anyway: the switch, the untouched Classic tree, a ROLLBACK per phase, the place baseline, and a Classic parity check at every gate (untouched-script hashes equal baseline, all `StartupState` entries `ready`, a fixed set of Classic screenshots compared against baseline captures).

---

## 2. Surfaces that only restyle through shared modules today

Making `RacingUIComponents`, `GarageComponents` or `ResponsiveUIFoundation` style-aware in place would change Classic. None of the three is edited. Each dependent surface gets its own answer:

| Surface | Today | Under Pulse | Logic duplicated |
|---|---|---|---|
| Activity HUD and its five views | `ActivityClient` builds `ctx.UI` from RacingUIComponents (L33-233) | New owner `Screens.Activities.ActivityHud` at the same entry. It provides the identical `ctx` contract on the kit. `JobClient`, `DuelClientView`, `PassengerClientView`, `CourierClientView`, `TaxiClientView` are untouched and shared. | About 90 lines of glue |
| Onboarding | `OnboardingClient` draws through RacingUIComponents and finds targets by name and text | Phases 3 to 6: Classic `OnboardingClient` keeps working against Pulse screens because Pulse keeps every name it looks up (section 3.4). Its bubble keeps the Classic look in that interim. Phase 7: `Screens.System.Onboarding`, a model plus a kit view, finding targets through tutorial anchors. Same saved page ids, same `MarkSeen` calls. | About 450 lines |
| Owned-garage desk | `OwnedGarageWorkspaceUI` drives `GarageWorkspaceUI` | Same controller (seam edit 4) drives `Screens.Garage.GarageWorkspaceView`. The Pulse garage uses the same view, so desk, dealership and customise are one look. | None |
| Toasts | `Foundation.CreateTopNotificationController` | `UIKit.Toast` controller with the same return shape, started by `Screens.System.ToastOwner`. One listener on `ShowTopNotification`. The three private toasts (interior HUD, entrance status, garage browser status) route to it. | 10 lines |
| Confirmations | `Foundation.Confirmation`; three hand-built modals in GarageUI; a hand-built exit confirm in the race HUD | `UIKit.Confirm` everywhere. Same options, same return table, same overlay name, DisplayOrder 1250, same focus and cancel behaviour, plus a phone floor and close-before-replace. | None (behaviour copied once) |
| Loading screen | `LoadingScreenView`, hard-wired | `ReplicatedFirst.Loading.LoadingScreenViewPulse`: same method list, same instance names (`LoadingSafeContent`, `SafeRoot`, `Status`, `ProgressTrack`, `ProgressFill`). Artwork pipeline unchanged. | None |
| Start screen | Built inline in the LocalScript | `ReplicatedFirst.Loading.StartScreenPulse`: kit buttons of at least 48 px, default gamepad focus on Play, shared scale, the string "LOADING PULSE RACERS". Classic keeps its literal. | About 110 lines |
| Proximity prompts | Ten families, engine-drawn, Style Default | `Screens.System.WorldPromptClient` draws `UIKit.PromptBanner` (section 7.2). Inert in Classic, so Classic prompts are exactly as today. | None |
| Race fade label | Michroma literal in `RaceTransitionClient` | Token seam (edit 7) | None |
| Entrance status label | Private label in `GarageEntranceClient` | Routed to the toast (edit 8) | None |
| Interior HUD | `GarageInteriorModeUI` (HUD plus a touch camera guard) | `Screens.Garage.GarageInteriorHud` on the kit, with the guard copied once into `GarageInteriorTouchCameraGuard`. The Classic module is not required under Pulse, so there is one guard. | About 200 lines |
| Touch drive controls | Baked teal art, own layout | Same module, token seam (edit 9), new tintable art | None |
| Speed lines | `DrivingCameraClient` overlay at DisplayOrder -10 | **Excluded.** It is a driving effect. If gauge contrast fails at speed, tune `ChaseSpeedLine*` config as a separate driving change. | - |
| Dealership intro pill | Off in v3 by config | Untouched. If it is ever switched on it should be rebuilt on the kit first. | - |
| Dev panels | Studio only | Excluded. Any literal sweep skips `Game.Development.*`. | - |

---

## 3. The shared kit

### 3.1 Modules

```text
ReplicatedStorage.Modules.Core
  UIStyle, UIStyleManifest, UIStyleInactive
ReplicatedStorage.Modules.UIKit                 no gameplay knowledge, no remotes
  Tokens      code defaults for every colour, size, space, opacity, layer, asset; read once
  Type        font family, weights, cap-height sizing, preload, fallback
  Screen      the one scale, safe-area, form-factor, input and text-setting service
  Layers      DisplayOrder ladder, ScreenGui factory, anchored slots, major-menu state
  Names       required names, reserved names, tutorial anchors
  Draw        primitives: frame, hairline, text, text row, image, gradient
  Focus       gamepad and keyboard selection, back binding, bumpers and triggers
  Money       re-exports ResponsiveUIFoundation's formatters, cash presenter, ProjectEconomy, BindReplicatedCash
  Assets      icon sheet cell map, digit sheet map
  Pool        keyed instance pool
  Components  Panel, ScreenTitle, Scrim, Tile, Rail, Button, ButtonRow, Tabs, Segmented, Slider,
              Dropdown, Chip, CashChip, StatusCluster, StatPanel, SegmentedBar, FactList, ListRow,
              BigNumber, Gauge, MinimapFrame, Modal, Confirm, Toast, PromptBanner, Icon, Glow
ReplicatedStorage.Modules.Game.Screens          owners: a headless model plus a view each
  Hud, Activities, Racing, Map, Garage, System
ReplicatedFirst.Loading
  LoadingScreenViewPulse, StartScreenPulse
```

About 30 kit modules and 45 screen modules, each well under the 200,000 character limit.

`UIKit.Money` requires `ResponsiveUIFoundation` for its style-free functions, so there is still one money formatter and one cash count-up. At retirement those functions move into the kit.

### 3.2 Token source and reader

- **Source of truth:** `UIKit.Tokens`, a Luau table in git. It holds the sheet's colour roles, the type table as cap heights, spacing on a 4 dp grid (4, 8, 12, 16, 22, 34, 58, 100), opacities, hairline weights, the DisplayOrder ladder, glow settings and asset ids.
- **Tuning:** `ReplicatedStorage.Config.UI.Style` holds the same values as attributes on five child folders (`Colours`, `Type`, `Shape`, `Scale`, `Assets`). The reader is built on `Core.ConfigReader` (typed, warn once). Code defaults equal the config values, so a missing or dropped config value changes nothing. That matters: Studio once dropped eight newly created Theme values after a mixed install.
- **Read once at kit load.** A token edit takes effect on the next Play, as theme edits do today. No frame loop ever reads a token from the DataModel.
- **Roles, not colours.** Components take role names (`Surface`, `TextPrimary`, `Accent`, `Live`, `Cash`, `Danger`). A screen cannot pass a `Color3`. The only raw-colour paths are named exceptions: paint swatches, medal markers, and the activity theme (which must stay `Color3` because views assign it to parts and lights).

### 3.3 Components, one line each

All constructors are `Component.new(parent, props) -> handle`. Sizes are in dp. A handle has `Instance`, `Set(props)` and `Destroy()`. `Set` writes only what changed.

| Component | API | Notes |
|---|---|---|
| Panel | `Panel.new(parent, {Name, Size, Position, Anchor, Padding, Hairlines})` | Slate 0.86, top hairline 0.85, bottom 0.22, square. 3 instances. `Active` so it blocks camera drag. |
| Tile | `Tile.new(parent, {Id, Title, SubLine, Corner, Status, Image, ImageMode, State, OnActivated, AnchorId})` | A real TextButton. Selected: white fill, ink text, pink base line, glow, inner visual 10% larger. Diagram images turn ink on white. Designed no-image state. |
| Rail | `Rail.new(parent, {Heading, CellSize, Gap}) -> {SetItems(list), Select(id), ScrollTo(id)}` | Horizontal, fixed cells, pooled tiles rebound by key, padding for glow and growth, selection group. |
| Button | `Button.new(parent, {Text, Icon, Variant, Price, Enabled, Selected, OnActivated, AnchorId})` | Variants `Default`, `Main`, `Buy`, `Destructive`, `IconTile`. Label is the TextButton's own text. Disabled sets `Active = false`. Never under 48 px on touch. 2 to 5 instances. |
| ButtonRow | `ButtonRow.new(parent, {Align, Items})` | Flex row. Order: back or exit, secondary, main. |
| Tabs | `Tabs.new(parent, {Items, Selected, OnChanged}) -> {Select(id)}` | White with pink underline when active. Bumpers switch tabs. |
| Segmented | `Segmented.new(parent, {Items, Selected, OnChanged})` | Shop / Owned, paint channels, settings. Triggers switch. |
| StatusCluster | `StatusCluster.new(parent, {Mode}) -> {SetVehicle, SetRank, SetSpaces, Cash}` | One strip, top-right, same slot on every screen. |
| CashChip | `CashChip.new(parent, {OnPlus}) -> {SetTarget(value, snap)}` | Yellow fill, ink text. Wraps the existing cash presenter. Width fixed during a count so it does not jitter. |
| Chip | `Chip.new(parent, {Kind, Text, Affordable})` | Price, tier badge, fitted, variant, gain and loss. |
| StatPanel | `StatPanel.new(parent, {}) -> {SetHeader(info), SetStats(rows)}` | Six pooled rows. Preview gain in cyan with an arrow. |
| SegmentedBar | `SegmentedBar.new(parent, {Segments}) -> {Set(value, preview)}` | A tiled segment image clipped to whole segments. 3 instances, not 20. |
| FactList | `FactList.new(parent, {}) -> {Set(rows)}` | Icon and label left, value right, hairline between. Cash values end in a yellow chip. |
| Modal | `Modal.open({Title, Width, Build, OnClose}) -> {Close()}` | Content built on first open. Scrim, focus trap, Escape and ButtonB close, focus restored. |
| Confirm | `Confirm.open({Title, Body, ConfirmText, CancelText, Variant, OnConfirm, OnCancel}) -> {Root, Cancel(), Confirm(), Relayout()}` | Same contract as `Foundation.Confirmation`. Cancel left, confirm right, default focus on cancel. |
| Toast | `Toast.createController(playerGui) -> {Gui, Show(message, duration, kind), Relayout(), Count()}` | Three pooled cards, measured with the real font, duplicate suppression, sits below the race timer. |
| PromptBanner | `PromptBanner.new(parent, {ActionText, ObjectText, Key, OnPress})` | Key cap follows the active input. On touch it is a button of at least 48 px with no key cap. |
| Icon | `Icon.new(parent, {Id, Size, Role})` | One sprite sheet, tinted, inherits the text role. |
| Glow | `Glow.attach(target, {Role})` | One component, backend chosen once (`UIShadow` or 9-slice). Never animated. |
| BigNumber | `BigNumber.new(parent, {CapHeight, Role, Digits, Suffix}) -> {Set(text)}` | Digit sprites in fixed cells. Writes only the digits that changed. No 100 limit. |
| Gauge | `Gauge.new(parent, {Diameter}) -> {SetSpeed(mph, max), SetBoost(pct)}` | Image arcs behind a small interface. Writes only when the quantised value changes. |
| MinimapFrame | `MinimapFrame.new(parent, {Diameter, Shape}) -> {Canvas, SetCaption}` | CanvasGroup with a round clip and ring. Square fallback by config. |

### 3.4 Contracts every component obeys

**Names.** `UIKit.Names` holds three lists and the kit refuses to break them.

- *Required* (looked up by scripts that are shared or still Classic during the build): ScreenGui `DesktopFreeRoamHud` with `DesignRoot`, `ModalLayer > Controls`, `CarPanel`, `Minimap`, and buttons named `Car`, `Garage`, `Race`; `RaceBrowser` with `CardContent`, `TeleportToStart`; `RaceEntryPresentation` with `TierE`..`TierS`, `LapSelector`, `PrizeSummary`, `MedalTargets`, `RaceFormat` and buttons whose text is `TIME TRIAL` and `RACE`; `OwnedGarageBrowser` with `GarageList`, `Enter`; `CanonicalGarageGui > CanonicalCanvas > CanonicalGarageBrowser / CanonicalGarageWorkspace` with `TutorialWorkspace`, `TutorialPageId`, `CanonicalGarageCard`, `CanonicalGarageCardId`, `Categories`, `Stats`, `Capacity`, `UpgradeBudget`, `VehicleScroller`, `TutorialCardScroller` and the text `DEALERSHIP`; `AccessControls`; the five loading names; `ActivityHud > DesignRoot`.
- *Reserved* (never create): `DriveHUD`, `TouchGui`, `DrivingSpeedEffect`, `RaceHud`, `RaceHud_Phase3`, `RaceCheckpointBadge_Phase5D`, `RaceQueue_Phase8`, `RaceSessionControls_Phase8C`, `RaceSessionControls_Phase8D`, `RaceResults_Phase4`, `TimeTrialResultCoach`, `RaceEntry`, `RaceEntryProbe`, `TimeTrialPersonalBestBoard`, and descendants named `GarageRoot`, `DealershipRoot`, `CustomisationRoot`, `CustomizationRoot`. `Car`, `Race` and `Garage` are allowed only on the three action-bar tiles, because onboarding locks every button with those names.
- *Tutorial anchors:* any component given `AnchorId` sets the attribute `TutorialTargetId` (an attribute `GarageWorkspaceUI` L165 already writes and nothing reads). Pulse onboarding finds targets by anchor. Names are kept as well, so Classic onboarding works until Phase 7.

`Layers.newScreenGui` asserts against the reserved list. A unit test asserts the required list for each screen.

**Audio** (`PresentationAudioClient` plays hover and click on every visible GuiButton).

- The GuiButton is the visible root; text and images are its own or its descendants. No transparent hit overlay beside a visual.
- Disabled, locked and unaffordable set `Active = false`.
- Hover, pressed and selected scaling apply to an inner visual, never the hit box.
- Scrims and decorative buttons set `UIAudioHoverCue = ""` and `UIAudioSuppressClick = true`. A `Silent` prop sets `UIAudioSilent` on a root.
- Pooled buttons stay parented, so the five audio connections per button are made once.
- Views never call `PresentationAudioBridge`. Only the state owner reports a result, once.

**Gamepad and keyboard focus.**

- Every interactive component is selectable. Focus is the selected look (white fill), driven by `SelectionGained` and `SelectionLost`.
- Rails and modals are selection groups. A modal traps focus.
- `Focus.enter(screen, default)` selects a default on open when the active input is gamepad or keyboard navigation. `Focus.bindBack` gives every screen one back action (ButtonB, Escape).
- When a selected pooled tile is rebound, selection moves with it.
- Under Pulse the default Roblox selection box is replaced by an invisible image (section 7.1).

**Trailer mode** (`TrailerModeClient` disables ScreenGuis directly under PlayerGui in one pass).

- Every ScreenGui is created at owner start, directly under PlayerGui. Contents are lazy; the ScreenGui is not.
- No owner writes `ScreenGui.Enabled` in a frame loop. Visibility goes through `Layers.setVisible(surface, reason, state)`, which writes only on change.

**ScreenGuis.** Created only through `Layers`. Always `ZIndexBehavior.Sibling`, `ResetOnSpawn = false`, an explicit `ScreenInsets`, the attribute `UIStyle = "Pulse"`, and a DisplayOrder from the one ladder (today's numbers are reused: 84 activity, 85 HUD, 155 in-race, 170 race menu, 171 garage browser, 180 race entry, 190 queue, 205 countdown, 220 results, 990 onboarding, 1000 and 1001 loading, 1100 toasts, 1250 confirm).

**Other owners' rules the kit respects.**

- Full-screen scrims are `Active = false` and panels are `Active = true`, or garage camera orbit breaks (`PreviewCameraClient`).
- On phones, non-interactive panels in the top 58% of the screen are not `Active`, so they do not block camera look.
- `GarageSessionActive` stays the only "garage open" signal. The HUD keeps `FreeRoamHudPresentationMode` with `KeepTelemetry`, and keeps writing `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen` and `MobileControlMode`.
- The activity `ctx` contract: `ctx.UI.Button` returns a TextButton the view can move and rename; `Strip.Set` compares before writing (it is called five times a second with unchanged text); `Offer` keeps one-at-a-time and an idempotent close; theme values stay `Color3` with all 13 names.

---

## 4. Scaling, alignment and sharpness

### 4.1 One service

`UIKit.Screen` is the only code that reads the viewport, insets, form factor, input type and text setting. It replaces the clamps 0.72 to 1.12 (HUD), 1.02 (garage), 1.15 (race shell), the 0.25 to 0.55 phone floors, four "is mobile" tests and three safe-area methods.

```text
Screen.safeSize          size of the device-safe area, from the engine
Screen.topbar            GuiService.TopbarInset, live
Screen.class             "Regular" | "Compact"
Screen.arrangement       "Standard" | "TouchDrive"
Screen.input             "Mouse" | "Touch" | "Gamepad", live from UserInputService.PreferredInput
Screen.scale             number
Screen.px(dp) -> int     round(dp * scale)
Screen.hair(dp) -> int   max(1, round(dp * scale))
Screen.textSize(role) -> int
Screen.Changed           one signal, fired once per settled resize
```

### 4.2 Reference and clamps

| Class | When | Reference | Scale |
|---|---|---|---|
| Regular | safe height at least 600 and safe width at least 1000 | 1920x1080 | `clamp(min(w/1920, h/1080), 0.667, 2.0)` |
| Compact | otherwise (every phone in landscape) | 844x390 | `clamp(h/390, 0.85, 1.2)` |

- 1280x720 gives 0.667, 1920x1080 gives 1.0, 2560x1440 and 3440x1440 give 1.333, 3840x2160 gives 2.0. The UI stays the same relative size from 720p to 4K, which none of today's owners do.
- Scale is snapped to steps of 1/24 and relayout waits for the resize to settle. That keeps the set of text sizes small. Many sizes fill Roblox's glyph atlas and cause flicker on phones.
- Below the floor the layout reflows (fewer tiles, collapsed stat panel). It does not shrink further.

### 4.3 The form-factor rule

Two independent answers, each from one place:

- **Class** is geometry only (table above). A narrow desktop window gets Compact because that is what fits.
- **Arrangement** is `TouchDrive` when `UserInputService.TouchEnabled`, which is exactly the gate `MobileDriveControlsClient` uses (L12). On-screen steering and pedals hold the bottom corners, so the minimap goes top-right under the status cluster and the gauge goes bottom-centre. Otherwise `Standard`: minimap bottom-left, gauge bottom-right, as in the mockup.
- **Input** changes live and only affects key caps, focus and touch-target minimums. It never rebuilds a screen.

There is one HUD owner. A touch laptop gets one HUD (Regular, TouchDrive), not two.

### 4.4 Real phone layouts, not scaled canvases

Each screen view has two layout functions, `layoutRegular` and `layoutCompact`. They place the same components and read the same model. Compact uses its own metric set from `Tokens.Compact`:

- touch targets at least 48 px on the short side; buttons 48 tall; tiles about 150 x 116;
- `Label` never below an 11 px CSS-equivalent size;
- menu margin 16, HUD margin 12, plus the safe area;
- the rail shows three or four tiles and scrolls; the stat panel collapses to name, tier and changed stats; the race menu becomes list then detail instead of two panes.

Phone layouts are built and verified in the same phase as the desktop layout of that screen. There is no late phone pass.

### 4.5 Safe area

- Content ScreenGuis use `ScreenInsets = DeviceSafeInsets`. The engine removes notches and rounded corners, so content anchors with plain scale positions and no inset maths.
- Scrims and backgrounds sit in a sibling ScreenGui with `ScreenInsets = None` and bleed to the edges.
- The top bar is handled once: `Layers` slots at the top start below `Screen.topbar`. On desktop the top bar is about as tall as the 58 dp HUD margin, so little should move there; the spike confirms the real numbers.

### 4.6 Hairlines and alignment

- **No `UIScale` above normal content.** Every size and offset is `Screen.px(dp)`, an integer. A 2 dp hairline is `Screen.hair(2)`: 1 px at 720p, 2 at 1080p, 3 at 1440p, 4 at 4K. Always whole pixels, always even between panels. The 4 dp tab underline and 6 dp base line use the same function.
- The cost is a relayout on resize. Resize is rare, and `Draw` keeps each instance's dp spec so `Relayout` is one pass.
- Layout is anchored slots (`TopLeft` title, `TopRight` status, `RightColumn`, `BottomRail`, `BottomRight` buttons, `BottomCentre`, `TopCentre`, `PromptStack`) with fixed-offset content inside, which is the structure Roblox staff recommend. Rows use flex list layouts. No screen holds coordinates.
- `Draw.textRow` aligns an icon and a label by cap box, using the font's baseline shift. This replaces the hand-tuned per-icon offsets in `RaceBrowserClient.ICON_CELLS`.
- The Phase 0 spike compares this route against a per-cluster `UIScale` on real captures before the kit is fixed.

### 4.7 Text sizes

- **Roles are specified as cap height in dp**, not TextSize. Roblox TextSize is line height and differs per font. The sheet's sizes are CSS sizes; multiplied by 0.70 they give: ScreenTitle 56, SectionHead 38, ButtonMain 31, Button and TileName 27 (21 on a rail of seven), Status 24, Tab 20, Value 18, Label 15, SpeedNumber 95, HeroNumber 140.
- `Screen.textSize(role) = round(cap * scale / CapHeightRatio)`, an integer. The ratio is a token per font (Barlow 0.583, Roboto Condensed 0.607, Titillium Web 0.447).
- Italic labels get right padding of 0.2 x cap so the last letter is not clipped.
- No `TextScaled` on dense panels. `TextSize` and any scale above text are never tweened.

### 4.8 Numbers and words above TextSize 100

- **Numbers** (speed, race position, timer, results cash and XP) use `BigNumber`: digit sprites in fixed cells, tinted by role. No 100 limit, no digit jitter, sharp at 4K, and only changed digits are written.
- **Words** above 100 (a ScreenTitle at 1440p and above needs about 128 in Barlow) use TextSize 100 inside a holder with a static `UIScale`. Whether that stays sharp is disputed and unverified; the spike decides. If it is soft, titles stop growing at TextSize 100 and the title cap is re-set for large screens.

### 4.9 Ultrawide

Scale follows height. Menu scrims bleed full width; menu content keeps the 100 dp margins from the real edges, and the rail simply shows more tiles. HUD corner clusters follow the screen edges up to 21:9; beyond that (32:9) they stay at the 21:9 positions so the gauge and map remain in view. See decision D9.

### 4.10 The player's Text Size setting

- `Screen` reads `GuiService.PreferredTextSize` and applies one bounded multiplier (1.0 up to about 1.2) to body roles only: Label, Value, sentences, toasts, prompt banners, modal bodies. Their containers size to content.
- Display roles (titles, tile names, chips, numbers) are capped.
- Verification at Largest is a gate row in every phase. Whether the engine also scales unconstrained labels by itself must be seen in the spike; if it does, kit labels carry a size constraint so there is one owner of text scale.

---

## 5. Performance

Quality is not traded away here. The savings come from not doing wasted work.

### 5.1 Static and dynamic split

A ScreenGui is redrawn whole when any descendant changes. Each surface is split:

| Surface | Static ScreenGui (changes on events) | Live ScreenGui (changes while driving) |
|---|---|---|
| Free-roam HUD | `DesktopFreeRoamHud`: status cluster, action bar, buttons, captions, car panel | `FreeRoamHudLive`: gauge, speed digits, boost, minimap canvas |
| In-race HUD | `SharedInRaceHUD`: position, lap, order rows, controls | `InRaceLive`: timer digits, delta chip, checkpoint pips |
| Menus and garage | one content ScreenGui plus one scrim ScreenGui | none |

ScreenGuis that are not showing are disabled, through `Layers` only.

### 5.2 Pooling and lazy building

- **Pooled, rebound by key, kept parented:** rail tiles, event rows, live-order rows, leaderboard and lap rows, legend rows, stat rows, fact rows, toasts, prompt banners.
- **Lazy:** every modal's content (Controls, Settings, cash store), the car panel grid, records and vehicle pages, map legend. Built on first open, kept afterwards.
- **No page rebuilds.** A garage click updates the bound tiles and the changed stat rows. Today it destroys and recreates about 300 instances.

### 5.3 Per-frame rules

1. No config, attribute or `FindFirstChild` lookups in a frame loop. Tokens and behaviour config are cached at start.
2. Write a property only when the shown value changes. Speed is whole mph, gauge angle in half degrees, boost in whole percent.
3. At most one render-step binding per surface, bound only while that surface is visible.
4. No walks of PlayerGui or Workspace on timers. State comes from the attributes and bindables that already exist, plus `Layers` for "a major menu is open".
5. No `ScreenGui.Enabled` writes per frame. No attribute or value writes under a ScreenGui per frame.
6. No instance creation in a frame loop.
7. Tween only transparency or position of text-free layers. Pressed and selected states snap.

### 5.4 Budgets

Initial targets. Phase 0 replaces the "Classic today" column with measured numbers; the sheet's "within 10% of today" test is dropped, because pooling and lazy modals change the counts on purpose.

| Measure | Classic today (from source) | Pulse budget |
|---|---:|---:|
| Desktop HUD instances at start | about 610 | 230 |
| Phone HUD instances at start | about 170 plus modals | 200 |
| Garage page, instances created per click | 300 to 330 | 0 after first visit |
| In-race HUD, instances created per race event | up to 42 | 0 |
| Results screen instances | 105 to 145 | 140 |
| Instances per button / panel / vehicle card or tile | 7 / 4 to 9 / about 17 | 4 (5 for the main button) / 3 / 12 |
| Instances per segmented bar | none today (the HUD gauge uses 32) | 3 |
| HUD property writes per frame while driving | 32 gauge writes plus about 45 lookups | 12 writes, 0 lookups |
| Glows on screen | - | 12 |
| Translucent full-screen layers on a phone | - | 2 |
| UI script time per frame, desktop / phone | not measured | 0.3 ms / 0.6 ms |

### 5.5 How they are measured

- A read-only counter run through `execute_luau` in the **Client** datamodel during Play. It requires no gameplay module. It counts descendants and classes per ScreenGui and counts `DescendantAdded` and `DescendantRemoving` on PlayerGui across a scripted interaction.
- `debug.profilebegin` labels around every kit frame step, read in the MicroProfiler.
- With `Config.UI.Style@DebugStats` true in Studio, kit steps publish their time and write counts as attributes on a client-only folder, readable without a require.
- The same script is run on Classic in Phase 0 for the baseline, and on Pulse at every phase gate. A phase that misses its budget does not close.

---

## 6. Fonts and assets

### 6.1 Typeface decision route

Barlow Condensed (the mockup face) is not in Roblox and fonts cannot be uploaded. The choice is made on captures, not on paper:

1. Phase 0 renders the Customise screen in three faces at 1280x720, 1920x1080, 3440x1440 and a phone: **Barlow** ExtraBold Italic with SemiBold Italic (`rbxassetid://12187372847`), **Roboto Condensed** Bold Italic, **Titillium Web** Bold Italic.
2. Oscar picks.

My recommendation is Barlow: it is the mockup's own design at normal width, it has the heavy italics, and its caps are tall for its line height, so more roles fit under TextSize 100. It is about 22% wider than the condensed cut, and its digits are not fixed-width. The kit absorbs both: sizes are cap heights, and changing numbers use `BigNumber` or fixed-width chips.

The font is tokens (`FontFamily`, `DisplayWeight`, `LabelWeight`, `CapHeightRatio`, `BaselineShift`, `FallbackFamily`). If Roblox adds Barlow Condensed later, the swap is one edit.

### 6.2 Preload

Every italic face is a cloud asset, shipped families included. `UIKit.Type.preload()` runs from the loading view before Roblox's default loading screen is removed (`InitialLoadingAndStartScreenClient` L53), with a 2 second bound. It preloads the faces, the icon sheet and the digit sheet. If the family fails to load it falls back to Roboto Condensed and warns once.

### 6.3 Icons

One 1024 px sheet of white glyphs in 128 px cells, every glyph drawn to the same ink box, alpha-bled. Existing white icons are exported and re-centred; missing ones are drawn (pin, set route, tick, loop, gamepad, upgrade arrow, coin, lock, boost, trophy, route, laps, checkpoints, players, chevrons, key caps and gamepad glyphs). The thin-outline racing atlas is not reused; it reads as a different product beside solid glyphs. Made with the existing Pillow route in `scripts/ui_restyle/art/`.

### 6.4 Glow

`Glow` has two backends. `UIShadow` gives a coloured glow with no upload and is reported faster than 9-slice images, but its release on live clients is not confirmed here. Phase 0 checks it in a published build on a real device. If it holds, no glow images are uploaded. If not, three 9-slice images are.

### 6.5 Uploads needing Oscar's approval

Shown first as one contact sheet, uploaded once, ids recorded in `scripts/ui_restyle/uploaded_assets.json` and `Config.UI.Style.Assets`. Old asset ids are not touched, so switching back needs no asset work.

| Asset | Files | Note |
|---|---:|---|
| Icon sheet | 1 | |
| Digit sheet for `BigNumber` | 1 or 2 | Needs approval to fetch the Barlow font file (Open Font Licence) to render offline |
| Gauge arcs and tick ring | 2 or 3 | |
| Minimap ring and vignette | 1 or 2 | Fewer if a stroke with a gradient passes the spike |
| Title mark, chequered corner, medal diamonds | 1 to 3 | |
| White map player arrow | 1 | The current one is baked pink |
| Touch control art | 4 | The current art is baked teal |
| Glow 9-slices | 0 or 3 | Only if `UIShadow` fails on a live client |

About 11 to 17 files. Each upload is moderated and cannot be edited afterwards.

---

## 7. Roblox core UI and world prompts

### 7.1 Core UI policy

One new owner, `Screens.System.CoreUiPolicyClient`. Inert in Classic, so Classic keeps today's behaviour. Under Pulse it is the only caller of `SetCoreGuiEnabled` in normal play.

| Core UI | Today | Pulse policy (recommended) |
|---|---|---|
| Player list | On, top-right, shows Cash from leaderstats | **Off.** The status cluster owns top-right and already shows Cash. |
| Health bar, backpack | On | **Off.** Nothing uses them. |
| Emotes menu, Esc menu, purchase prompts, core notifications | Roblox style | Left as they are. They cannot be styled. |
| Chat window | On, top-left, where titles, the event card and race position go | Restyled at run time (slate, kit font). **Hidden while a full menu, the garage or a race is on screen**, restored after. In free roam the top-left slot starts below the chat window when it is open. |
| Bubble chat | White, BuilderSans | Slate with white text and the kit font, set at run time. |
| Top bar | Every ScreenGui ignores it | One rule in `Layers`: top slots start below `GuiService.TopbarInset`. |
| Gamepad selection box | Roblox default | `PlayerGui.SelectionImageObject` set to an invisible image. Focus is the white selected state. |
| On-foot touch controls | Thumbstick and jump in the bottom corners | Not touched. The `TouchDrive` arrangement keeps the bottom corners clear. |
| Name tags and health above characters | Default within 100 studs | **Left alone.** `RaceParticipantVisibilityClient` saves and restores those values; a second writer would fight it. Styled name tags are a later, separate feature. |

Play screenshots omit CoreGui, so overlap with Roblox's own UI needs Oscar's eyes or a desktop screenshot.

### 7.2 World prompts

`Screens.System.WorldPromptClient`, client only, no server edit:

- Under Pulse it sets `Style = Custom` **locally** on known prompts as they appear, and re-applies on every stream-in. It listens on the three known roots (`World.Runtime.PlayerVehicles`, `World.Interiors.OwnedGarageInstances`, `World.RaceRoutes`), the two static garage exterior prompts, and the three client-created families.
- It draws `PromptBanner` on `ProximityPromptService.PromptShown` and removes it on `PromptHidden`. Banners stack in one slot. Text is upper-cased at draw, which fixes the mixed casing without touching any source string.
- It never writes `Enabled`, adds no `Triggered` handler and calls no remote for the action. Keyboard and gamepad triggering stay with the engine. On touch the banner is the button and calls `InputHoldBegin` / `InputHoldEnd`, so the server sees the same `Triggered` as today.
- It hides banners the default UI shows wrongly: Enter on cars the player does not own, Drive Out and Manage Garage for visitors, everything while a major menu or results are open.
- The race Start banner and the event card read the zone's attributes and the existing `GetEntryDetails` action, once per prompt shown, cached per event.

This rests on three engine behaviours not yet seen in Play: a local `Style` surviving `TimeTrialServer`'s 3 second re-assert of Default, the default prompt reading `Style` at show time, and `PromptShown` holding steady while seated in a start zone. The spike checks all three. If any fails, prompts stay Roblox default under Pulse as a recorded exception; no server script is edited to force it.

---

## 8. Navigation changes in the sheet

**In, but separately switchable and in their own phase.**

- `Screens.Garage.GarageApp` drives pages from a route table. Two tables exist: `Hub` (today's flow: hub, three workshops, Owned and Buy as pages) and `Tabs` (the sheet: Parts, Upgrades, Paint as tabs; Shop / Owned as a switch).
- `Config.UI.Style@GarageNavigation` selects one. Default `Hub`.
- Phase 6 ships the Pulse garage with `Hub`. Purchases, equips and paint can then be compared flow for flow against Classic. Phase 7 adds `Tabs` under its own contract and acceptance.
- The race menu's filter tabs are a client-side filter of the same list and ship with the race menu. The race entry keeps its approved step order.

**How onboarding survives:**

- Page ids are saved, allow-listed server state. Neither style renames, adds or drops one.
- Phases 3 to 6: Classic `OnboardingClient` runs against Pulse screens through the required names in 3.4. With `Hub` navigation the three hub cards still exist with their `CanonicalGarageCardId` values.
- Phase 7: Pulse onboarding uses anchors. Under `Tabs`, the page `CustomisationHome` highlights the three tabs, which carry the anchor ids `AddModules`, `UpgradeModules`, `PaintShop`. The page still plays once and still sends the same `MarkSeen`.
- Because the ids match, a player who saw a page under one style is not shown it again under the other. Switching back is safe.
- The Pulse action-bar tiles show a locked state when onboarding sets `Active = false` on them, which Classic never did.
- A full fresh-profile tutorial run is a Phase 7 gate, in the sandbox (section 9.3).

---

## 9. Phases

The request is a `suggest:`. Nothing below starts until Oscar approves the phase list; each phase is then one approved scope with one installer. The delivery-reviewer runs before APPLY on every High-Risk phase and on every seam edit inside a Standard phase.

### 9.1 How installs are done in v3

`studio_delivery.py`, `feature_installer.py` and `studio_capture.py` refuse the v3 place. The restyle uses the route every v3 delivery has used, with one shared engine:

- `scripts/ui_restyle/engine/installer_engine.lua`: the lighting_realism step2 engine (ops `source`, `tree`, `attribute`, `property`, `create`) with the hover_feel hash guards. It asserts the place id and Edit mode, checks every script is in a known state, fetches sources over localhost, checks hashes, compiles with `loadstring`, writes nothing if anything blocks, and restores on failure.
- One folder per phase, `scripts/ui_restyle/pN_<name>/`, with `CONTRACT.md`, `before/`, `after/`, `build.py`, and `out_audit.lua`, `out_apply.lua`, `out_rollback.lua`. Run through `execute_luau` in Edit: AUDIT, delivery-reviewer, APPLY, ROLLBACK, APPLY, then Play.
- **New ModuleScripts** use the `create` op, which v3 has not exercised yet. Phase 1 proves it first on the inert `Core.UIStyleInactive`: APPLY, save the place, re-read, ROLLBACK, confirm it is gone, APPLY again.
- **Creation and source edits never share one call.** Created instances go first, in their own call and waypoint, and are verified before any source is edited. This is the lesson from the dropped Theme values.
- Created instances carry a marker attribute. ROLLBACK removes only what the phase created and refuses if a created item has children it did not create.
- Seam edits are anchored edits `(old, new, expected count)` against exact before-sources. Fragile anchors are announced. The minified `OwnedGarageWorkspaceUI` is replaced whole, with one line changed and a hash check.
- Existing hash chains are respected. `GarageUI`, `GarageWorkspaceUI`, `GarageModuleCardViewModel` and `DesktopFreeRoamHudUI` are frozen, so their earlier rollbacks stay valid.
- The Exotic content ROLLBACK is never run in v3.

### 9.2 Parallel agents and the integrator

- **Agents:** one folder each, contract first, never Studio and never git. They write Luau sources, offline art (Pillow), contract tables extracted from Classic sources, and test cases.
- **Integrator (Claude in the main session):** Studio, uploads, installs, the kit gallery, captures, Play tests, measurements, commits. Agents cannot run Luau, so the integrator runs their tests in Edit through `loadstring` with fakes and sends captures back.
- **The kit gallery** (`UIKitGalleryClient`, a Studio-only tool entry) renders every component in every state at any viewport. It is how components are reviewed and captured without playing the game.

### 9.3 How Play testing avoids changing Oscar's saved profile

v3 Play loads and saves the real profile. Purchases spend real in-game Cash and time-trial finishes write personal bests. Three layers:

1. **A sandbox experience (recommended).** Oscar saves a copy of v3 as a new experience. A different experience has different DataStores, so its profile is disposable and starts fresh, which also lets the tutorial be tested from zero (onboarding replay is off in v3). It can be published privately, which gives real phones and a live client for the engine checks. The installer's place guard is extended to that one place id with Oscar's approval. Each phase is applied and fully tested there first, then applied to v3.
2. **A no-commit protocol in v3.** v3 Play is used for looking, measuring and non-mutating flows. Purchases stop at the confirmation and are cancelled. Time trials are exited before the line. A profile fingerprint (Cash, owned vehicle ids, module counts, personal bests, read through existing read-only actions) is taken before and after each session and compared; any unexpected change is reported.
3. **To check in Phase 0:** a Studio local server test with one player uses a test account with a negative user id, not Oscar's. If the Studio MCP can drive that mode, mutating tests in v3 itself also stop touching the real profile.

### 9.4 The phases

Default stays Classic until Phase 8. Every phase ends with Oscar confirming the screens in Play with the switch on, and a Classic parity check with it off.

| # | Phase | Scope | New modules | Lane | Agents | Gate |
|---|---|---|---|---|---|---|
| 0 | Decide and prove | Oscar's decisions. Baseline: place version, source hashes, Classic captures, measured budgets. Sandbox experience. Throwaway spike (nothing installed): three typefaces, hairline snap against UIScale, text above 100, UIShadow on a live client, round minimap on a phone, local prompt Style, CoreGui overlap, Text Size at Largest. Style sheet v2 with corrected errors. | None | Fast (read-only) | Sheet v2, contract tables from Classic sources, spike scenes | Sheet v2 approved; typeface, glow, big-number and prompt routes fixed |
| 1 | Foundation | Switch, manifest, kit, tokens and config, gallery, installer engine, asset batch | `Core.UIStyle*`, all of `UIKit`, `UIKitGalleryClient`. Edit: ClientBase | **High-Risk** | Tokens and type; Screen and tests; components in four folders; art; installer engine and mock tests | Create op proven with save and re-read; APPLY, ROLLBACK, APPLY; Classic parity; gallery captures at five viewports and phone approved |
| 2 | System surfaces | Toasts, confirm, loading and start screens, world prompts, core UI policy | `ToastOwner`, `LoadingScreenViewPulse`, `StartScreenPulse`, `WorldPromptClient`, `CoreUiPolicyClient`. Edits: LoadingTransitionRuntime, InitialLoading | **High-Risk** (start-up path) | One per surface | Cold start to Play on mouse, pad and touch; every prompt family; one toast listener; Classic start screen unchanged |
| 3 | Free-roam HUD | HUD for desktop, phone and pad: status, action bar, minimap, gauge, car panel, settings, controls, cash modals; activity HUD | `Screens.Hud.*`, `MinimapController`, `Screens.Activities.ActivityHud`. Edits: MapIconLayer, RouteGuide | Standard, High-Risk gates on spawn, despawn, teleport | HUD model; desktop view; phone view; minimap; car panel and modals; activity HUD | Spawn, despawn, exit, teleport, first-drive controls; Classic map, race and onboarding still work beside it; HUD budgets met |
| 4 | Race session | In-race HUD, countdown, queue banner, results, wrong-way, gate pill | `Screens.Racing.RaceHud`, `RaceCountdown`, `RaceQueue`, `RaceResults`, `RaceRouteGuide`. Edit: RaceTransitionClient | Standard, High-Risk gates on queue and results | Session model; HUD view; results; queue and countdown; route guide | Time trial and race start to finish in the sandbox; one `JoinQueue`; `CountdownPresentationReady` set; two-client order and visibility |
| 5 | Race menus and map | Race menu, race entry (setup, records, vehicles), full map | `Screens.Racing.RaceBrowser`, `RaceEntry`, `Screens.Map.FullMap` | Standard, High-Risk gates on teleport and vehicle lock | Browser; entry; map | Teleport, set route, queue start; prize preview equals server payout; map by mouse, touch and pad |
| 6 | Garage | Dealership, customise with `Hub` navigation, module shop, paint, three modals; owned-garage desk, browser and interior HUD | `Screens.Garage.*`. Edits: OwnedGarageWorkspaceUI, GarageEntranceClient | **High-Risk** (purchases, Cash, saved garage data) | GarageApp model; workspace view; browser view; paint panel; owned-garage screens | In the sandbox: buy, equip, upgrade, paint and garage purchases give the same Cash and ownership results as Classic; remote actions match the contract tables; zero instances created per click |
| 7 | Navigation, onboarding, touch art | `Tabs` navigation; Pulse onboarding with anchors; touch control art | `GarageRoutes.Tabs`, `Screens.System.Onboarding`. Edit: MobileDriveControlsClient | **High-Risk** (saved tutorial state, driving input) | Routes; onboarding model; onboarding view; touch art | Fresh-profile tutorial start to finish in both navigations and both styles; steering and pedals unchanged in behaviour |
| 8 | Hardening and flip | Full matrix: six desktop sizes, two phones with notch, pad-only run, Text Size Largest, two clients, budgets, parity audit. Docs. Then the default flip. | None | Standard; the flip is **High-Risk** | Test matrices, docs | Every row passes; Oscar says flip; superseded design docs updated |
| 9 | Retire Classic | Remove Classic owners, the three old component libraries' view code, old colour and font config, the seam branches | None | **High-Risk** (retirement) | Removal plan | Only on Oscar's say, after an agreed period on Pulse |

---

## 10. Decisions for Oscar, and risks

### 10.1 Decisions, each with my recommended default

| # | Decision | Recommended default |
|---|---|---|
| D1 | **What "backup" means.** Frozen Classic tree chosen at start-up, with nine named seam edits, against all-byte-identical or all-in-place. | This proposal: frozen Classic, nine edits. |
| D2 | **Where the switch lives.** Place attribute now. At the flip, optionally add a server projection of a FeatureFlags flag so the live game can be switched without publishing (first joiners on a fresh server would then get the place value for the first seconds). | Place attribute plus the preview user list. Decide the projection at Phase 8. |
| D3 | **Typeface.** Barlow, Roboto Condensed or Titillium Web, after the three-way capture. | Barlow. |
| D4 | **Big numbers and glow.** Digit sprite sheets (a font file fetch and an upload) against scaled text; UIShadow against uploaded glow images. | Sprites. UIShadow if confirmed on a live client. |
| D5 | **Navigation changes** (hub to tabs, Shop / Owned). | In, as a separate switch, default `Hub` until you accept `Tabs` in Phase 7. |
| D6 | **Core UI.** Player list, health and backpack off; chat restyled and hidden in menus and races; invisible selection box; name tags left alone. | As listed in 7.1. |
| D7 | **World prompts.** Client-only custom banner for all ten families, subject to the spike. | In. Default prompts stay if the spike fails. |
| D8 | **Colour rule changes and exceptions.** Confirm: cash yellow, white selection, no structural outlines, white tier badges, muted unaffordable price, square corners, no bevels. Rule on: tutorial gold beside cash yellow, checkpoint mint and finish yellow, activity colours, baked-colour map icons. | Confirm the sheet's list. Tutorial uses white and pink. World guidance and map icons are declared world art and keep their colours for now. |
| D9 | **Scaling policy.** Proportional from 0.667 to 2.0; Compact layouts under 600 safe height; HUD corners follow the edges up to 21:9; Text Size setting applied to body text only. | As written in section 4. |
| D10 | **Test environment.** A sandbox experience and one extra place id in the installer guard. | Yes. |
| D11 | **Results XP.** Not in the result payload. Derive it on the client from the `Rank` and `XpIntoRank` attributes, or add a server field. | Client derivation. No server edit. |
| D12 | **In-race map.** A live round minimap is new frame cost; today desktop has a route image and phones have nothing. | Route image and marker inside the round frame on desktop; none on phones; revisit after measuring. |
| D13 | **Results content.** The mockup omits medals, leaderboard, lap list and finishing order. | Keep them, below the hero numbers. |
| D14 | **Settings rows that do nothing** (UI scale, graphics, speed unit, sliders, reset). | Hide them under Pulse. Show only settings that work. |
| D15 | **Backup lifetime.** How long Classic is kept after the flip. | Decide at Phase 8; until then nothing is removed. |

### 10.2 Top risks and how each is contained

| # | Risk | Containment |
|---|---|---|
| R1 | A Pulse controller sends a different purchase, spawn or queue request than Classic, or the two drift. | Contract tables of every remote action and payload key, extracted from Classic sources before coding. delivery-reviewer checks each model against them. Sandbox runs compare Cash and ownership results flow for flow. Classic is frozen and hash-audited. |
| R2 | Old and new owners run together, or a half-converted set misbehaves. | One latch, one resolver, `Claim`, no fallback after a partial start, shared ScreenGui names, and the parity audit at every gate. |
| R3 | New ModuleScripts or config do not persist, or the installer fails in v3. | Create op proven on an inert module with save and re-read. Creation separated from source edits. Code defaults equal config. APPLY, ROLLBACK, APPLY on every phase. |
| R4 | Engine unknowns: text above 100, fractional hairlines, UIShadow on live clients, CanvasGroup on weak phones, local prompt Style. | All five are spike items in Phase 0, before any component is fixed. Each has a fallback built into the kit (capped titles, integer pixels, 9-slice, square minimap, default prompts). |
| R5 | Onboarding breaks silently: a renamed target, a changed button text, the hub removal, a saved page id. | Required-name list asserted by tests. Same page ids in both styles. Anchors under Pulse. A fresh-profile run as a gate. |
| R6 | Testing changes Oscar's real profile. | Sandbox experience for every mutating test. No-commit protocol and fingerprint comparison in v3. |
| R7 | A seam edit damages Classic. | Nine edits, about 100 lines, each with an exact Classic branch, hash-guarded and compiled before writing. Classic parity captures after every APPLY. Per-phase ROLLBACK and the place baseline. |
| R8 | Size. Ten phases, about 75 new modules, 3,400 lines of logic copied. | Every phase is useful on its own behind the switch, and the default stays Classic. Parallel agents per phase. Classic stays the live UI until Oscar is satisfied, so there is no deadline pressure on quality. |

### 10.3 Things this proposal does not do

- No new remote, payload, saved field, economy value or purchase owner.
- No change to driving, VFX, audio, world art or the start screen artwork.
- No portrait layout.
- It does not fix Classic's defects. The duel stake-menu bug, the race HUD reappearing after a finish, and the route guide not clearing on exit are logic defects found by the audit; the Pulse models are written without them, and fixing them in the shared views or in Classic is separate work.
- The six dealership wayfinding signs (American spelling, Gotham) are world art and are not touched.
