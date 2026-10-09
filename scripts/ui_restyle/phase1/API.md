# Pulse Phase 1: binding API

Every Phase 1 module is written against this file. If a signature here is wrong, stop and tell the integrator; the file is amended first, then the code. Reviewed after the pilot, frozen after Phase 3 (programme contract, "PC", 2.2). Paths: `UIP` = `ReplicatedStorage.Modules.Game.UIPulse`, `Kit` = `UIP.Kit`.

## 1. Dependencies (no cycles; a module may require only what its row lists)

| Module | May require |
|---|---|
| `ReplicatedFirst.UIStyleSwitch` | nothing |
| `UIP.Routes` | nothing at load; the latch lazily inside `Resolve` and `StartWatch` |
| `Kit.Tokens`, `Kit.Contracts`, `Kit.Perf` | nothing |
| `Kit.Metrics` | Tokens |
| `Kit.Layers` | Tokens, Metrics, Contracts; the latch lazily through `Layers.Switch()` |
| `Kit.Text` | Tokens, Metrics |
| `Kit.Surface` | Tokens, Metrics |
| `Kit.Input` | Tokens, Metrics, Contracts |
| `Kit.Controls` | Tokens, Metrics, Text, Surface, Input |
| `Kit.Collections` | Tokens, Metrics, Text, Surface, Input |
| `Kit.Overlay` | Tokens, Metrics, Layers, Text, Surface, Input, Controls |
| `UIP.Toasts.ToastClient` | Layers, Text, Overlay, Routes |
| `UIP.Dev.Fixtures.*` | any Kit module |
| `UIP.Dev.Gallery` | any Kit module; `Dev.Fixtures` children |

Kit modules reach each other only as `require(script.Parent.<Name>)` in one header block. `Core.ConnectionScope` and `Core.ConfigReader` may be required by owners and the gallery (`ReplicatedStorage.Modules.Core`). Requiring any module creates no instance and never yields, except the latch's first require.

## 2. Shared types

```lua
type Scope = { connect: (Scope, RBXScriptSignal, (...any) -> ()) -> RBXScriptConnection,
             add: (Scope, any) -> any, task: (Scope, (...any) -> (), ...any) -> thread, destroy: (Scope) -> () }
             -- Core.ConnectionScope. Owners create it; the kit never does.
type Component = { Instance: GuiObject, Set: (patch: {[string]: any}) -> (), Destroy: () -> () }
type ColourRole = "Slate"|"White"|"Ink"|"Pink"|"Violet"|"Cyan"|"Yellow"|"TextSecondary"|"TextMuted"|"Danger"
type Tier = "E"|"D"|"C"|"B"|"A"|"S"
type TextRole = "ScreenTitle"|"SectionHead"|"ButtonMain"|"Button"|"MenuButtonMain"|"MenuButton"|"TileName"
            |"TileNameSmall"|"Status"|"Tab"|"Value"|"Label"|"Body"
type IconName = string   -- a key of Tokens.Icons
```

**Constructor convention.** `Kit.X(parent: GuiObject, props: {[string]: any}, scope: Scope): Component`.

- Never yields. Works on a detached `parent`. Reads `Metrics.Of(parent)` once and relays out on that context's `Changed` through `scope`.
- `props.Name` names the root (default: the component name). `props.LayoutOrder`, `props.Visible` are accepted by every component.
- Sizes in props are **design values** (px at 1080 for Regular, dp at 844x390 for Compact); the kit converts with `ctx.Px`. A screen cannot pass a `Color3`, `UDim2`, `Font` or TextSize.
- `Set(patch)` takes the same keys as props, writes only what changed, errors on an unknown key.
- `Destroy()` destroys the root and disconnects everything the component added to `scope`. Repeat-safe.
- Callbacks (`OnActivated` and the like) are plain functions in props, replaceable through `Set`.

## 3. `Kit.Tokens`

```lua
Tokens.Colour: {[ColourRole | "ScrimTop" | "ScrimBottom" | "Black"]: Color3}
Tokens.Tier: {[Tier]: Color3}
Tokens.Opacity: {[string]: number}      -- opacity; BackgroundTransparency = 1 - value
Tokens.Space: {[string]: number}
Tokens.Cap: {Regular: {[TextRole]: number}, Compact: {[TextRole]: number}}
Tokens.Type: {[string]: any}
Tokens.Scale: {[string]: number}
Tokens.Assets: {[string]: string}       -- "" until uploaded
Tokens.Slices: {[string]: {Center: Rect, Inset: number}}
Tokens.Icons: {Cell: number, Glyphs: {[IconName]: {number}}}   -- {column, row}; copied from assets/out/icons.json
Tokens.Defaults                          -- frozen deep copy of the code defaults, before config is applied
Tokens.Flatten(t: any): {[string]: boolean | number | string | Color3}   -- pure; flat name -> value
Tokens.Asset(key: string): string?      -- nil when "" (callers then draw the flat state)
```

On require it looks for `ReplicatedStorage.Config.UI.Pulse` (and `.Assets`) with `FindFirstChild` only, and applies each attribute whose flat name and type match; a wrong type warns once and keeps the default. Read once. Flat name = group prefix + key, as listed below; these are also the attribute names.

### 3.1 Colour (`Colour<Key>`, `Tier<Key>`; Color3 from RGB)

```text
ColourSlate 14,13,26        ColourWhite 243,240,255     ColourInk 7,6,13          ColourPink 255,45,149
ColourViolet 154,61,255     ColourCyan 34,228,255       ColourYellow 255,228,51   ColourTextSecondary 217,211,245
ColourTextMuted 185,179,214 ColourDanger 196,57,75      ColourScrimTop 8,6,24     ColourScrimBottom 34,14,72
ColourBlack 0,0,0
TierE 132,142,145 (#848E91)  TierD 105,190,129 (#69BE81)  TierC 74,204,211 (#4ACCD3)
TierB 82,137,235 (#5289EB)   TierA 244,188,65 (#F4BC41)   TierS 236,92,168 (#EC5CA8)
```

Tier colour appears only on `TierBadge` (and, later, tier buttons). It never marks state.

### 3.2 Opacity (`Opacity<Key>`; number)

```text
Panel 0.86   HairTop 0.85   HairBottom 0.22   Disabled 0.40   Locked 0.60   TabLocked 0.45
ChipNeutral 0.16   SegmentEmpty 0.20   RankTrack 0.30   GlowTile 0.55   GlowButton 0.60   GlowRing 0.45
ScrimTop 0.94   ScrimBottom 0.85   ConfirmScrim 0.66
```

### 3.3 Space (`Space<Key>`; number; design px at 1080 unless marked)

```text
Hairline 2         Pad 22             Gap 10             TabGap 34          TabUnderline 4
MenuMargin 68      MenuBottom 30      HudMargin 40       HudBottom 28       TopRightTop 40 (provisional, set by the pilot)
TopBarGap 12 (real px, never scaled)  ToastTopGap 10
ButtonHeight 64 (every menu row)      ButtonHeightLarge 88 (reserved; unused in Phase 1)
ButtonMainMinWidth 250                ButtonPadX 22      IconButton 64
TileWidth 315      TileHeight 242     TileBaseLine 6     TileSelectedGrow 1.10
ListWidth 480      StatPanelWidth 480 ListRowHeight 96 (provisional)
BadgeLarge 46      BadgeMedium 38     BadgeSmall 34
GlowTileRadius 46  GlowButtonRadius 42 GlowRingRadius 10
ConfirmWidth 650   ToastMaxWidth 820  ToastMaxCards 3    ToastGap 6
TouchMin 48 (dp)   TouchGap 8 (dp)    CompactButtonDrawn 36 (dp)   CompactTileMinWidth 88 (dp)
CompactMargin 12 (dp)                 CompactToastMaxWidth 280 (dp)
```

### 3.4 Type (`Type<Key>`, `Cap<Role>`, `CompactCap<Role>`)

```text
TypeFamily "rbxassetid://12187372847" (Barlow)      TypeFallbackFamily "rbxasset://fonts/families/RobotoCondensed.json"
TypeCapRatio 0.583     TypeFallbackCapRatio 0.607   TypeBaselineShift 0.04   TypeItalicPad 0.2
TypeMinTextSize 14     TypeMaxTextSize 100          TypeReadyTimeout 2

Regular caps:  ScreenTitle 56  SectionHead 38  ButtonMain 31  Button 27  MenuButtonMain 24  MenuButton 20
             TileName 27  TileNameSmall 21  Status 24  Tab 20  Value 18  Label 15  Body 15
Compact caps:  ScreenTitle 15.4  SectionHead 12.6  ButtonMain 11.6  Button 10.5  MenuButtonMain 11.6  MenuButton 10.5
             TileName 10.5  TileNameSmall 9.7  Status 10.5  Tab 10.5  Value 10.5  Label 9.7  Body 9.7
```

Faces (not config): display roles ExtraBold Italic; `Label` SemiBold Italic; `Body` Medium, upright, sentence case. Display roles are upper-cased by `Text.Label` unless `Upper = false`. Holder roles (may exceed 100): `ScreenTitle`, `SectionHead`. Every other role stops at 100.

**TextSize rule (pure, `Text.SizeFor`).** `raw = round(cap x scale / CapRatio)`. `textSize = clamp(raw, 14, 100)`. `holderScale = raw / 100` when `raw > 100` and the role is a holder role, else 1. Check values for Barlow: ScreenTitle 64 at 16/24, 96 at 1.0; Label 17 and 26; Compact Label 14 at 0.85.

### 3.5 Scale (`Scale<Key>`; number)

```text
RegularRefHeight 1080   RegularRefWidth 1600   RegularMin 0.6666667 (exactly 16/24)   RegularMax 2.0   RegularSteps 24
CompactRefHeight 390    CompactMin 0.85        CompactMax 1.10                        CompactSteps 20
CompactEnterHeight 600  CompactEnterWidth 1000 CompactLeaveHeight 640
NarrowBelow 1600        WideAbove 2300         HudMaxAspect 2.3333333 (21:9)          MenuMaxAspect 2.0
ResizeSettle 0.25 (s)
```

### 3.6 Assets (attributes on `Config.UI.Pulse.Assets`; names equal the last part of `config_key` in `assets/upload_manifest.json`)

```text
IconSheet  MapIconSheet  GlowSoft  GlowTight  GlowLine  Digits256  Digits128  DigitsPunct  GaugeRing  GaugeTicks
MinimapRing  MinimapVignette  MapPlayerArrow  SegmentStrip  ChequerCorner  TitleMark  KeyCap  MinimapRankRing
TouchControls  TouchControls2
```

20 keys; `ChequerCorner` has two candidate files and one key. `Tokens.Slices`: `GlowSoft` (62,62,66,66) inset 44; `GlowTight` (30,30,34,34) inset 20; `GlowLine` (30,0,34,64) inset 20; `KeyCap` (20,20,44,44) inset 0.

**Empty-asset rule.** With `Tokens.Asset(key) == nil`: `Icon` draws nothing and keeps its box; `Glow` creates no instance; the title mark is a `Pink` block; the main button keeps its `UIGradient`. No component errors, warns or changes size.

## 4. `ReplicatedFirst.UIStyleSwitch` (latch; integrator)

```lua
Switch.Style: "Classic" | "Pulse"        -- read at use; changes only through Downgrade
Switch.Reason: string                    -- "attribute:Pulse" | "attribute:Classic" | "attribute:absent"
                                       -- | "attribute:invalid" | "downgraded:<reason>"
Switch.Active(family: string): boolean   -- Pulse, and in the dev list if one is set, and (after Commit) committed
Switch.Commit(report: {Families: {string}}): ()     -- called once, by Routes.Compose only
Switch.Claim(surface: string): ()        -- errors unless Pulse, committed, and surface unclaimed
Switch.Downgrade(reason: string): ()     -- one-way; errors after the first Claim
Switch.Report(): {Style: string, Reason: string, Committed: boolean, Families: {string}, Claims: {string},
                DevFamilies: {string}?}
Switch._resolve(raw: any, devRaw: any, isStudio: boolean): (string, string, {string}?)   -- pure, for tests
```

- First require yields: `ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI")`, then reads `UIStyle` and `UIStyleDevFamilies` once. Later changes are ignored.
- `UIStyleDevFamilies`: comma-separated family names, honoured in Studio only; `""` means no limit.
- Writes on its own ModuleScript: `UIStyleResolved`, `UIStyleReason`, `UIStyleCommitted`, `UIStyleClaims` (comma list), `UIStyleRawAtRead` (`tostring` of the raw attribute), `UIStyleLoadedAtRead` (`game:IsLoaded()`). Nothing else anywhere.
- Never cache `Active()` or `Style` in another module.

## 5. `UIP.Routes` (integrator)

```lua
type Entry = {name: string, path: string, dependencies: {string}, tool: string?}
Routes.Families: {string}                                   -- delivery order. Phase 1: {"Toasts"}
Routes.Swap: {[string]: {Family: string, Path: string}}     -- entry name -> Pulse path
Routes.Add: {Entry & {Family: string?}}                     -- Pulse-only entries; Family nil = whenever Pulse
Routes.Compose(entries: {Entry}, switch: Switch): {Entry}   -- pure apart from switch.Commit; never yields
Routes.Resolve(entryName: string): any                      -- may yield; the module ClientBase starts for that name
Routes.StartWatch(): ()                                     -- idempotent; spawns the 15 s not-ready report
```

Phase 1 data:

```lua
Routes.Swap = { SharedTopNotificationUI = {Family = "Toasts", Path = "ReplicatedStorage.Modules.Game.UIPulse.Toasts.ToastClient"} }
Routes.Add = { {name = "PulseGallery", path = "ReplicatedStorage.Modules.Game.UIPulse.Dev.Gallery", dependencies = {},
              tool = "PulseGalleryEnabled"} }
```

`Compose`: (1) active families = `Families` filtered by `switch.Active`; they must be a prefix of `Families`, else error; (2) returns a **new** list of shallow-copied entries in the same order, with `path` replaced for each swap whose family is active (a swap whose entry name is absent errors), then the active `Add` entries; the input is never mutated; (3) validates: `name` and `path` strings, path matches `^[%w_]+(%.[%w_]+)+$`, swapped and added paths start with `ReplicatedStorage.Modules.Game.UIPulse.`, no duplicate name, no missing dependency, no cycle (messages as `ClientLifecycle` 5 to 8); (4) stores name to path for `Resolve`; (5) calls `switch.Commit({Families = active})` as its last statement.

`Resolve` errors if `Compose` has not succeeded. It walks the stored path with `WaitForChild`, as ClientBase 106 to 108, and `require`s it (same module cache as ClientBase). A Pulse module never names a Classic path; it calls `Resolve`.

`StartWatch` reads `PlayerScripts.ClientBase.StartupState` attributes once, 15 s after the call, and warns once listing swapped or added entries that are not `ready` or `skipped`.

## 6. `Kit.Metrics`

```lua
type Context = {
Class: "Regular" | "Compact", Band: "Narrow" | "Normal" | "Wide",
Arrangement: "Standard" | "TouchDrive", Input: "KeyboardAndMouse" | "Gamepad" | "Touch",
Scale: number,
Size: Vector2,            -- safe-area size in pixels
Origin: Vector2,          -- safe-area top-left in ScreenInsets.None space
TopBarHeight: number,     -- real px; 58 in Studio
TopBarKeepOut: Vector2,   -- real px corner nothing of ours enters; (208, 58) in Studio
Px: (design: number) -> number,       -- round(design x Scale); 0 stays 0, otherwise at least 1
Hair: (design: number) -> number,     -- max(1, round(design x Scale))
Touch: (drawn: number) -> number,     -- hit-box size: max(Px(drawn), TouchMin real px) when Input is Touch or Class is Compact
Changed: RBXScriptSignal,             -- fires ({Layout: boolean, Input: boolean}) once after a resize settles
}
Metrics.Compute(input: {SafeSize: Vector2, TouchEnabled: boolean, PreferredInput: string, WasCompact: boolean?}):
{Class: string, Band: string, Arrangement: string, Input: string, Scale: number}       -- pure
Metrics.Screen(): Context                                   -- the real viewport; created on first call
Metrics.AttachSafeArea(gui: ScreenGui): ()                  -- called by Kit.Layers only, once
Metrics.Fixed(spec: {Size: Vector2, TouchEnabled: boolean?, Input: string?, TopBarHeight: number?,
                   TopBarKeepOut: Vector2?}): Context     -- test hook; never changes; Origin = 0,0
Metrics.Bind(root: GuiObject, ctx: Context): ()             -- weak; descendants of root resolve to ctx
Metrics.Of(instance: Instance): Context                     -- nearest bound ancestor, else Screen(). Build time only
```

Rules (PC 3):

- **Class.** Compact when safe height < 600 or safe width < 1000. Once Compact, stays until height >= 640 and width >= 1000. Geometry only.
- **Band.** Narrow when safe width < 1600, Wide when > 2300, else Normal.
- **Arrangement.** `TouchDrive` when `UserInputService.TouchEnabled`, else `Standard`.
- **Input.** `UserInputService.PreferredInput`, live (`MicroGamepad` maps to `Gamepad`). An input change fires `Changed` with `Layout = false` and never rebuilds a screen.
- **Scale.** Regular: `floor(clamp(min(h / 1080, w / 1600), 16/24, 2.0) x 24 + 1e-6) / 24`. Compact: `floor(clamp(h / 390, 0.85, 1.10) x 20 + 1e-6) / 20`. Check values: 1280x720 gives 16/24; 1920x1080 gives 1; 2560x1440 gives 32/24; 2065x1152 gives 25/24; 844x390 gives 1; 568x320 gives 0.85.
- **Safe area.** `Screen()` takes `Size` and `Origin` from the ScreenGui passed to `AttachSafeArea` (`ScreenInsets = DeviceSafeInsets`): its `AbsoluteSize` and `AbsolutePosition`. Before attachment it uses the camera `ViewportSize`. Never `GetInsetArea`.
- **Top bar.** `GuiService.TopbarInset` is the free strip: `TopBarHeight = inset.Height`, `TopBarKeepOut = (inset.Min.X, inset.Height)`. Real pixels, never scaled.
- **Listeners.** This module is the only code that connects to the camera, viewport, `TopbarInset`, `PreferredInput` and `PreferredTextSize`. It adds no text multiplier of its own.

## 7. Components

Budgets are descendants including the root, excluding a `Glow` and a `UITextSizeConstraint`. Required child names are listed; anything else is the author's choice within the budget.

### 7.1 `Kit.Text`

```lua
Text.Ready: boolean
Text.ReadyChanged: RBXScriptSignal
Text.Preload(): ()                                 -- non-blocking, idempotent; GetTextBoundsAsync per face in its own task;
                                                 -- on failure switches to the fallback family and CapRatio, warns once
Text.WaitReady(timeout: number?): boolean          -- YIELDS up to timeout (default 2 s)
Text.Font(role: TextRole): Font
Text.SizeFor(role: TextRole, ctx: Context): (number, number)        -- pure: textSize, holderScale
Text.Measure(text: string, role: TextRole, ctx: Context, maxWidth: number?): Vector2   -- YIELDS up to TypeReadyTimeout
                                                 -- (2 s); cached; real px. After the limit, or on failure, an estimate from
                                                 -- the glyph ratio; it starts Preload, so ReadyChanged tells the caller to
                                                 -- measure again when the face arrives
Text.Label(parent, props, scope): Component
```

`Label` props: `Text: string`, `Role: TextRole`, `Colour: ColourRole` (default White), `Align: "Left" | "Centre" | "Right"`, `Wrap: boolean?`, `MaxWidth: number?`, `Upper: boolean?`, `Shadow: boolean?`, `Fixed: boolean?` (adds a `UITextSizeConstraint`; default true for display roles). Root is a Frame holder; child `Label` (TextLabel). The holder carries a static `UIScale` only when `holderScale > 1`. Italic right padding 0.2 x cap; baseline shift applied as an offset. No `TextScaled`. Relays out when the face arrives. Budget 2 (3 with shadow). `BigNumber` is reserved and not built in Phase 1.

### 7.2 `Kit.Surface`

| Constructor | Props | Notes |
|---|---|---|
| `Panel` | `Pad: number?` (default 22), `Hairlines: boolean?` (default true), `Width`, `Height: number?` | Slate at 0.86, `Active = true`, square. Children `HairTop`, `HairBottom`, `Content`. Budget 4. Screens parent into `component.Content` |
| `Hairline` | `Edge: "Top" | "Bottom"`, `Colour: ColourRole?`, `Opacity: number?` | One Frame, thickness `ctx.Hair(2)` |
| `Scrim` | `Kind: "Menu" | "Confirm" | "Garage"` | Full-size, `Active = false`. Menu: one Frame with a vertical `UIGradient` ScrimTop to ScrimBottom. Budget 2 |
| `Glow` | `Kind: "Tile" | "Button" | "Line" | "Ring"`, `Colour: ColourRole` | 9-slice ImageLabel behind the parent, `ZIndex` below it. Returns a component whose `Instance` is a zero-size Frame when the asset is empty |
| `Icon` | `Icon: IconName`, `Colour: ColourRole`, `Size: number` | ImageLabel with `ImageRectOffset` from `Tokens.Icons`. Unknown name errors |

### 7.3 `Kit.Controls`

| Constructor | Props | Notes |
|---|---|---|
| `Button` | `Variant: "Default" | "Main" | "Buy" | "Danger" | "Icon"`, `Text: string?`, `Icon: IconName?`, `Disabled: boolean?`, `Locked: boolean?`, `Size: "Menu" | "Large"` (default Menu), `MinWidth: number?`, `MarkKey: string?`, `OnActivated: () -> ()` | Root is the GuiButton. Child `Fill` takes hover, press and focus (White fill, Ink text); the hit box and text never scale. Disabled or Locked sets `Active = false` and the look, not `Visible`. Main: Pink to Violet `UIGradient`, glow, min width 250. Buy: Yellow, Ink text. Hit box `ctx.Touch(height)`. Budget 4 (5 Main) |
| `ButtonRow` | `Buttons: {{Id: string, Variant, Text, Icon, Disabled, OnActivated}}`, `Align: "Right" | "Centre"` | Order as given: back or exit, secondary, main. Fixed gap 10, no flex. `row.Button(id): Component`. Registers a focus group |
| `Tabs` | `Tabs: {{Id: string, Text: string, Icon: IconName?, Locked: boolean?, MarkKey: string?}}`, `Selected: string`, `Bumpers: boolean?`, `OnSelected: (id: string) -> ()` | Active: White with a 4 px Pink underline. Inactive: TextMuted. Locked: 0.45. Bumpers switch tabs while the row is shown. `tabs.Select(id)`. Budget 3 per tab plus 1 |

### 7.4 `Kit.Collections`

| Constructor | Props | Notes |
|---|---|---|
| `Tile` | `Title: string`, `Sub: string?`, `State: "Default" | "Selected"`, `Status: "None" | "Owned" | "Fitted" | "Locked" | "Unaffordable"`, `ChipLeft: string?`, `ChipRight: string?`, `Price: string?`, `Image: string?`, `Icon: IconName?`, `Tier: Tier?`, `Rating: number?`, `Compact7: boolean?`, `MarkKey: string?`, `OnActivated` | Root TextButton. Selected: White fill, Ink text, 6 px Pink base line, glow, child `Visual` 10% larger. Empty `Image`: the designed no-image state (icon or plain slate). `Price` is a formatted string from the shared money formatter; the kit never formats money. Budget 12 |
| `Rail` | `Heading: string?`, `Count: string?`, `CellWidth: number?`, `OnSelected: (key: string) -> ()` | Methods `SetItems(items: {{Key: string} & TileProps})`, `Select(key)`, `ScrollTo(key)`, `Tile(key): Component?`. Keyed pool: a data or selection change creates and destroys nothing once the pool has grown. Padding reserved for glow and growth. Children `Heading`, `Scroller` |
| `ListRow` | `Title`, `Sub: string?`, `Image: string?`, `Right: string?`, `Tier: Tier?`, `State: "Default" | "Selected"`, `Locked: boolean?`, `MarkKey: string?`, `OnActivated` | Selected as Tile. Budget 10 |
| `Chip` | `Text: string`, `Kind: "Neutral" | "Price" | "Cyan" | "Pink" | "Yellow"`, `Muted: boolean?` | Price: Ink fill, Yellow text (TextMuted when Muted). Budget 2 |
| `TierBadge` | `Tier: Tier`, `Rating: number?`, `Size: "Large" | "Medium" | "Small"`, `OnLight: boolean?`, `Dim: boolean?` | Letter cell in the tier colour with an Ink letter; rating on a White cell with Ink text (`OnLight`: Ink cell, White text). Budget 4 |

### 7.5 `Kit.Overlay`

```lua
Overlay.Toast(parent, props, scope): Component & {Show: (message: any, duration: number?) -> (),
                                                Count: () -> number, Relayout: () -> ()}
Overlay.Confirm(root: GuiObject, options: {Title: string?, Body: string?, CancelText: string?, ConfirmText: string?,
              OnConfirm: (() -> ())?, OnCancel: (() -> ())?, Host: GuiObject?}):
              {Root: Instance, Cancel: () -> (), Confirm: () -> (), Relayout: () -> ()}
Overlay.Modal(parent, props, scope): Component & {Open: () -> (), Close: () -> (), IsOpen: () -> boolean, Content: Frame?}
```

- **Toast.** `parent` is the layer root; the component builds `Stack` and a pool of `ToastMaxCards` cards named `Card1`..`CardN`. `Show` never yields the caller (it measures in its own thread): upper-cases, ignores empty, clamps duration 0.5 to 10 (default 2.5), restarts the timer of a showing card with the same text, else reuses the oldest. A card's display timer starts when the card becomes visible, never before its measure; the measure is bounded by `Text.Measure` and the stack lays out again on `Text.ReadyChanged`. A hidden card has `Visible = false` and empty `Text`. Role `Body`, sized for the Largest text setting. Fade by transparency only. Props: `MaxCards: number?`.
- **Confirm.** Same options and return table as `Foundation.Confirmation` (the `components` argument is gone). Kept exactly: saves `GuiService.SelectedObject` and restores it if NO or YES holds focus at close; Escape and ButtonB bound with `BindActionAtPriority` 10000, sink, Begin cancels; NO left and YES right with `NextSelection` links; NO focused, deferred, only when the last input was keyboard or gamepad; close runs once; an existing `SharedConfirmationOverlay` is destroyed first; ScreenGui `SharedConfirmationOverlay` at 1250 from `Layers.Create`. Added: 48 dp buttons, body auto-height, and if the overlay is destroyed by someone else (a Classic confirmation replacing it by name) it cancels once, cleanly. `root` must be under PlayerGui unless `Host` is given; with `Host` (gallery only) it builds inside that frame and creates no ScreenGui.
- **Modal.** Props `Title: string`, `Width: number`, `Height: number?`, `Build: (content: Frame, scope: Scope) -> ()`, `OnClose: (() -> ())?`. Nothing is built until the first `Open`. Scrim plus Panel inside `parent`; traps focus, restores the previous selection, binds back through `Input.BindBack`.

## 8. `Kit.Layers`

```lua
type Frame3 = "Hud" | "Menu" | "Scene" | "Bare"
type SlotName = "TopLeft" | "TopRight" | "TopCentre" | "RightColumn" | "BottomRail" | "BottomRight" | "BottomCentre" | "PromptStack"
type Layer = { Gui: ScreenGui?, Root: Frame, ScrimGui: ScreenGui?, ScrimRoot: Frame?, Metrics: Context,
             Slot: (name: SlotName) -> Frame, SetVisible: (visible: boolean) -> (), Destroy: () -> () }
Layers.Order: {[string]: number}
Layers.Check(name: string): (boolean, string?)          -- pure: in Order, not a trap name
Layers.Create(name: string, opts: {Frame: Frame3?, Scrim: boolean?, Live: boolean?}?): Layer
Layers.Stage(parent: GuiObject, ctx: Context, frame: Frame3): Layer      -- no ScreenGui; gallery and tests
Layers.Switch(): Switch                                  -- lazy require of the latch, cached
```

- `Create` is the only code that makes a ScreenGui. It asserts `Switch().Style == "Pulse"`, `Check(name)`, and that PlayerGui has no child of that name (an existing one with `UIStyle = "Pulse"` is an error; one without is destroyed only for `SharedTopNotification` and `SharedConfirmationOverlay`, as Classic does).
- Properties set explicitly: parent PlayerGui, `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, `IgnoreGuiInset = true`, `ScreenInsets = DeviceSafeInsets`, `DisplayOrder = Order[name]`, attributes `UIStyle = "Pulse"` and `PulseLayer = name`. **`Enabled` is never written.**
- `Scrim = true` adds a sibling `<name>Scrim` (`ScreenInsets = None`, DisplayOrder one lower, child `Root`). `Live = true` names the gui `<name>Live` one higher; where the ladder would collide the numbers are set as rows of `Order` by the phase that needs them.
- The first `Create` calls `Metrics.AttachSafeArea(gui)`.
- `Root` is named `Root`. `SetVisible` writes `Root.Visible` (and `ScrimRoot.Visible`).
- **Frames.** `Hud`: the safe area, limited to a centred 21:9 box. `Menu`: a centred block no wider than 2:1. `Scene`: the whole safe area. `Bare`: the whole safe area, no slots.
- **Slots** are zero-size anchor Frames named `Slot<Name>`, repositioned on `Changed`. A child sets its `AnchorPoint` to the slot's anchor and `Position` to zero; screens hold no coordinates. `M` = `Px(MenuMargin)` or `Px(HudMargin)`, `B` = `Px(MenuBottom)` or `Px(HudBottom)`, `W`, `H` = root size:

| Slot | Anchor | Position |
|---|---|---|
| `TopLeft` | 0, 0 | `(M, TopBarHeight + TopBarGap)` real px for the vertical part |
| `TopRight` | 1, 0 | `(W - M, Px(TopRightTop))` |
| `TopCentre` | 0.5, 0 | `(W / 2, TopBarHeight + Px(ToastTopGap))` |
| `BottomRight` | 1, 1 | `(W - M, H - B)` |
| `BottomCentre` | 0.5, 1 | `(W / 2, H - B)` |
| `BottomRail` | 0, 1 | `(M, H - B)`; the rail runs to the right edge |
| `RightColumn`, `PromptStack` | 1, 0 and 0.5, 1 | created; geometry fixed in Phases 2 to 4 |

**Ladder (`Layers.Order`; today's numbers).** Phase 1 creates only the three marked rows.

```text
CanonicalGarageGui 40      OwnedGarageInteriorHUD 58   RaceRouteGuide_Phase5 78   ActivityHud 84
DesktopFreeRoamHud 85      FullMap 90                  MobileDriveControls_Phase1 96
SharedInRaceHUD 155        RaceBrowser 170             OwnedGarageBrowser 171     RaceEntryPresentation 180
RaceQueueBanner 190        RaceCountdown 205           UnifiedRaceResults 220     Onboarding 990
SharedTopNotification 1100 (Phase 1)   SharedConfirmationOverlay 1250 (Phase 1)   PulseGallery 1400 (Phase 1)
```

## 9. `Kit.Input`, `Kit.Contracts`, `Kit.Perf`

```lua
Input.Focusable(button: GuiButton, opts: {OnFocus: ((focused: boolean) -> ())?, Decorative: boolean?}?): ()
Input.FocusGroup(scope: Scope, opts: {Trap: boolean?}?): {Add: (button: GuiButton, order: number?) -> (),
               Enter: (preferred: GuiButton?) -> (), Leave: () -> (), Destroy: () -> ()}
Input.ShouldEnterFocus(ctx: Context): boolean            -- Input is Gamepad, or the last input was keyboard navigation
Input.BindBack(scope: Scope, handler: () -> (), priority: number?): ()       -- Escape and ButtonB
Input.BindBumpers(scope: Scope, onPrev: () -> (), onNext: () -> ()): ()      -- ButtonL1, ButtonR1
Input.BindTriggers(scope: Scope, onPrev: () -> (), onNext: () -> ()): ()     -- ButtonL2, ButtonR2
Input.Mark(instance: GuiObject, key: string): ()
Input.Marked(key: string): {GuiObject}
Input.Silence(instance: GuiObject): ()                   -- UIAudioHoverCue = "", UIAudioSuppressClick = true
```

- `Focusable` sets `Selectable = true` and a per-component `SelectionImageObject` (an empty transparent Frame, so the engine box never shows on Pulse controls and Classic keeps its default). Focus is shown through `OnFocus`, which the component maps to its selected look. `Decorative` calls `Silence`.
- A trapping group saves `GuiService.SelectedObject` on `Enter` and restores it on `Leave`. `Enter` selects only when `ShouldEnterFocus`.
- Context actions are named `Pulse_<purpose>_<n>` and unbound through `scope`.
- `Mark` applies the legacy name, text or attributes for `key` from `Contracts.Marks` and registers the instance. An unknown key errors. Views never type a tutorial name. A GuiButton named `Car`, `Race` or `Garage` without a mark fails lint.

```lua
Contracts.Reserved: {[string]: true}           -- from classic/contracts/_reserved_names.json
Contracts.Trap: {[string]: true}               -- DriveHUD, TouchGui, DrivingSpeedEffect, the RaceLifecyclePresentationClient kill list
Contracts.TrapDescendants: {[string]: true}    -- GarageRoot, DealershipRoot, CustomisationRoot, CustomizationRoot
Contracts.LockedButtonNames: {[string]: true}  -- Car, Race, Garage
Contracts.Marks: {[string]: {Name: string?, Text: string?, Attributes: {[string]: any}?}}   -- from _onboarding_targets.json
Contracts.PlayerAttributes: {[string]: string} -- name -> type, from _player_attributes.json
Contracts.Source: {Generator: string, Inputs: {[string]: string}}                           -- input file fingerprints
```

Generated by `gen_contracts.py`; never edited by hand. Data only.

```lua
Perf.Enabled: boolean                                         -- Studio and Config.UI.Pulse@PerfDebug, read once
Perf.Bind(name: string, layerRoot: GuiObject, step: (dt: number) -> ()): {Disconnect: () -> ()}
Perf.Count(counter: string, n: number?): ()
```

`Perf.Bind` is the only frame-binding point in Pulse. The step runs on `RenderStepped` only while `layerRoot.Visible` is true (it connects and disconnects on the property signal, it does not poll), wrapped in `debug.profilebegin("Pulse." .. name)`. When enabled, counters are published once a second as attributes on `PlayerScripts.PulsePerf` (a Folder it creates). Phase 1 has no frame step; the toast uses timers.

## 10. Owners and the gallery

**Owner shape (`Toasts.ToastClient`).** Header and start guard as the Classic owners:

```lua
local Client = {}
local state
function Client.start()
	if state then assert(state == "ready", "Client startup already attempted: " .. tostring(state)); return end
	state = "starting"
	local ok, message = xpcall(function() ... end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end
return Client
```

Order inside `start`: `Layers.Switch().Claim("Toasts")`; wait for `PlayerGui` and `PlayerScripts.Runtime.UI`; adopt or create `ShowTopNotification`; `Layers.Create("SharedTopNotification", {Frame = "Hud"})`; mount `Overlay.Toast` in slot `TopCentre`; connect the bindable to `Show`; then, each in its own task, `Text.Preload()` and `Routes.StartWatch()`. `Client.Controller` is `{Gui, Show, Relayout, Count}` after start.

**Gallery (`Dev.Gallery`, entry `PulseGallery`, tool flag `PulseGalleryEnabled`).** Returns `{start}`. Claims `Gallery`. One ScreenGui `PulseGallery` (order 1400, `Bare`), closed at start (`Root.Visible = false`, nothing mounted). BackSlash toggles it. Driven by attributes on that ScreenGui, so a probe needs no require:

| Attribute | Direction | Meaning |
|---|---|---|
| `GalleryOpen` | in, boolean | show or hide |
| `GalleryItem`, `GalleryState`, `GalleryPreset` | in, string | what to mount; a change remounts |
| `GalleryItems` | out, string | comma list of registered item ids |
| `GalleryMounted` | out, string | `<item>|<state>|<preset>` once mounted |
| `GalleryError` | out, string | `""` or the mount error |

Presets: `R720` 1280x720, `R1080` 1920x1080, `R1440` 2560x1440, `C844` 844x390 (touch), `C568` 568x320 (touch). Each mount builds `Root.StageHolder.Stage`, a Frame of exactly the preset size, with `Metrics.Bind(stage, Metrics.Fixed({Size = preset, TouchEnabled = compact, Input = compact and "Touch" or "KeyboardAndMouse", TopBarHeight = compact and 52 or 58, TopBarKeepOut = compact and Vector2.new(120, 52) or Vector2.new(208, 58)}))` and `Layers.Stage(stage, ctx, item.Frame)`. If the stage is larger than the window, `StageHolder` carries one static `UIScale` (a dev-tool exception; lint reads logical sizes). No remote, no profile, no player attribute. A remount destroys the previous scope first.

**Fixture registration.** Each `Dev.Fixtures.<Name>` module returns a list; the gallery reads the folder's children once at start:

```lua
type GalleryItem = {
Id: string,                 -- "Controls.Button"; unique
Frame: Frame3,              -- which composition frame the stage uses
Slot: SlotName?,            -- where the item is mounted; nil = stage centre
States: {{Id: string, Props: {[string]: any}}},       -- first is the default; include the longest strings
Mount: (parent: GuiObject, props: {[string]: any}, scope: Scope, ctx: Context) -> Component,
}
return { item1, item2 }
```

Every public constructor of sections 7.1 to 7.5 has at least one item, with states for each variant and for disabled, locked, selected and empty-image where they exist. A view (Phase 2 onwards) registers the same way.

## 11. Coding rules (checked by the static lint, E2)

1. Luau, `--!strict` optional, no `--!nocheck`. No globals. Services at the top through `game:GetService`.
2. First two lines of every source, as the Classic modules do: line 1 `-- Owns <what>; <what it does not own>.` line 2 `-- Pulse UI (phase1). <full instance path>. Requires: <names or none>.`
3. No `require` of a Classic UI module, `GarageComponents`, `RacingUIComponents`, `ResponsiveUIFoundation` or `UITheme`, and no string naming a Classic owner's path. Reach another entry through `Routes.Resolve`.
4. No write to `ScreenGui.Enabled`. No `Instance.new("ScreenGui")` outside `Kit.Layers`.
5. No `UIStroke`, no bevel, no `UICorner`, no `CanvasGroup`, no `TextScaled`, no tween of `TextSize` or of a `UIScale`. `UIScale` only in the `Text.Label` holder and the gallery `StageHolder`.
6. No `Color3`, `Font`, asset id or pixel literal outside `Kit.Tokens` (0 and 1 excepted). Geometry is `ctx.Px`, `ctx.Hair`, `ctx.Touch` results: whole pixels, no scale anchors for centring.
7. Functions passed to `Perf.Bind`, and anything they call, contain no `FindFirstChild`, `WaitForChild`, `GetAttribute`, `GetDescendants`, `GetChildren` or `Instance.new`. No `RenderStepped`, `Heartbeat` or `BindToRenderStep` outside `Kit.Perf`. No loop that polls for presence.
8. Only functions marked YIELDS in this file may yield. No `start()` waits on a font, an asset or a remote.
9. Every connection goes through the `scope` argument or is disconnected in `Destroy`.
10. No trap name. A reserved name only where this file or a phase contract assigns it. Created instances are named; no default class names left on roots.
11. Every source under 150,000 characters, LF line ends, no function near 200 locals.
12. Warnings are prefixed `[Pulse.<Module>]` and each distinct problem warns once.

## 12. Files

```text
scripts/ui_restyle/phase1/
CONTRACT.md  API.md  spec.json  declared.json  set_style.lua  verification.json        integrator
before/StarterPlayer.StarterPlayerScripts.ClientBase.lua                                integrator (copy of classic/sources)
after/<full instance path>.lua          one per ModuleScript plus ClientBase, named as in classic/sources/, e.g.
      ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua, ReplicatedFirst.UIStyleSwitch.lua
tests/<full instance path>_test.lua  tests/run_tests.lua
work/<agent>/after/  work/<agent>/tests/  work/<agent>/NOTES.md                         one agent each
out_audit.lua  out_apply.lua  out_rollback.lua  applied_hashes.json                     generated by engine/build.py
scripts/ui_restyle/phase1_proof/         spec.json and after/ for the create proof
```

`spec.json` belongs to the integrator alone. Agents never edit it, `phase1/after/` or `phase1/tests/` directly; the integrator copies from `work/`. One ModuleScript, one owner (CONTRACT 2 and 10).

## 13. Pure tests

Each agent supplies one test file per module it owns. The file returns one function:

```lua
return function(M: any, env: {Load: (instancePath: string) -> any, FakeSwitch: (style: string) -> any,
                            Detached: (className: string) -> Instance}): {{name: string, ok: boolean, detail: string?}}
```

- `M` is the module table, loaded by the harness from the repo source with `loadstring`, a fake `script` whose `.Parent.<Name>` are handles, and a fake `require` that returns other Phase 1 sources loaded the same way. No module in the place is ever required. `Layers.Switch` is replaced by `env.FakeSwitch("Pulse")`.
- `env.Detached` makes a real instance that the harness destroys afterwards. Nothing is parented into the game tree, nothing is left in `shared` or `_G`, and no test yields (so no `Text.Measure`, `Text.WaitReady`, `Routes.Resolve`, or latch first-require; test `Switch._resolve` instead). The timed paths are stepped through three seams a test may replace and must put back: `Text._delay`, `Overlay._toastDelay` (both `task.delay`) and `Text.Measure` itself; `Text._bounded` and `Text._estimate` are exposed for the same purpose.
- Use `Metrics.Fixed` for every context.

Minimum cases:

| Module | Must cover |
|---|---|
| `UIStyleSwitch` | `_resolve` for Pulse, Classic, absent, a non-string, dev list in and out of Studio |
| `Routes` | CONTRACT E4 and E5 |
| `Tokens` | every value of section 3 equals `Defaults`; `Flatten` round trip; no flat-name collision; `Asset("")` is nil |
| `Metrics` | the scale check values of section 6; Compact enter and leave; bands; `Px`, `Hair`, `Touch` rounding; `Of` with and without `Bind` |
| `Text` | `SizeFor` check values of 3.4, the floor of 14, the cap at 100, holder scale only for holder roles |
| `Layers` | `Check` accepts ladder names, refuses trap and unknown names; `Stage` slot positions at R1080 and C844 |
| `Contracts` | every reserved name of the programme contract 2.3 is present; no name is both reserved and trap |
| `Surface`, `Controls`, `Collections`, `Overlay` | each constructor on a detached parent: does not error with every asset empty, stays within its budget, `Set` with an unchanged patch changes no property, unknown key errors, `Destroy` leaves the parent empty and is repeat-safe; `Rail.SetItems` twice with the same keys creates nothing |
| `Perf` | `Count` with `Enabled` false is a no-op; `Bind` returns a disconnectable handle |
