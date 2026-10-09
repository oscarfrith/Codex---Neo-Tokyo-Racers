# Pulse wave 2: binding API (kit v2, routes v2, family table)

Status: **binding for the wave-2 build agents; nothing here is installed.** It extends `../phase1/API.md` ("API1") and never repeats it: every API1 signature stays valid unless a row below says "changed". Programme contract = `../CONTRACT.md` ("PC"); wave contract = `CONTRACT.md` in this folder. If something here is wrong or missing, stop and tell the integrator; this file is amended first, then the code.

Paths: `UIP` = `ReplicatedStorage.Modules.Game.UIPulse`, `Kit` = `UIP.Kit`. "Design px" = px at 1920x1080 (Regular); "dp" = units at 844x390 (Compact). Evidence labels: **[seen]** read off a preview frame; **[src]** read from Classic source; **[assumed]** my decision, to be checked by the integrator in Play.

## 1. Assets and `Kit.Sprites`

### 1.1 The 31 asset keys

`Tokens.Assets` holds exactly these keys. **The code default of each key is the uploaded id** copied from `../assets/uploaded_assets.json`; the attributes on `Config.UI.Pulse.Assets` mirror them (same name, same string). The game therefore shows images with empty or missing attributes. `gen_sprites.py` (1.3) writes the id block of `Tokens` too, so ids are never typed by hand. `Tokens.Asset(key)` is unchanged (nil for `""`, so an attribute set to `""` still gives the API1 3.6 flat state).

| Key | Kind | Geometry source | Used by |
|---|---|---|---|
| `IconSheet` | white, tinted | `icons.json`: 1024 px, cell 128, 58 glyphs | `Surface.Icon`, every component with an `Icon` prop |
| `MapIconSheet` | white, tinted | `map_icons.json`: 512 px, cell 128, 14 glyphs | `Surface.MapIcon` (map layers, legend) |
| `GlowSoft` / `GlowTight` / `GlowLine` | white 9-slice, tinted | `static_geometry.json` | `Surface.Glow` kinds Tile / Button and Ring / Line |
| `Digits256`, `Digits128`, `DigitsPunct` | white, tinted | `digits.json` | `Kit.BigNumber` only |
| `GaugeTrack`, `GaugeTicks`, `GaugeGlow`, `GaugeArc`, `BoostArc` | baked colour, never tinted | `rings.json` `gauge` | `Kit.Gauge` only |
| `MinimapRing`, `MinimapVignette`, `MapPlayerArrow` | ring baked; vignette and arrow white | `rings.json`, `static_geometry.json` | `Kit.Minimap` |
| `RankArc` | baked colour | `rings.json` | `Kit.Minimap` rank arc; `Kit.Touch` boost charge ring |
| `SegmentStrip` | white, tiled | `static_geometry.json` `segment` | `Data.SegmentedBar` |
| `TitleSlash` | baked colour | `rings.json` (160x192; draws 53.3 x 64 design px) | `Surface.TitleMark`, `Controls.Header`, modal and confirm titles |
| `ChequerCorner` | two-tone, never tinted | `marks.json` (256 px) | the race event card corner (WorldMap family) |
| `KeyCap` | white 9-slice | `static_geometry.json` `keycap` | `Surface.KeyCap`, `Overlay.PromptBanner`, map key hints |
| `TouchAccelerate`, `TouchBrake`, `TouchTurn`, `TouchDrift`, `TouchBoost` and each with `Pressed` (10 keys) | baked colour | `touch.json` | `Kit.Touch` only |

**Removed Phase 1 keys** (their attributes stay on the folder as `""` and are ignored; no engine "remove attribute" op is used):

| Removed | Replaced by |
|---|---|
| `GaugeRing` | `GaugeTrack` + `GaugeArc` + `GaugeGlow` + `BoostArc` (with `GaugeTicks`, which stays) |
| `MinimapRankRing` | `RankArc` |
| `TouchControls`, `TouchControls2` | the ten `Touch*` keys |
| `TitleMark` | `TitleSlash`. The wordmark placeholder was not uploaded; the start screen keeps its current logo |

`Tokens.Slices` (unchanged values): `GlowSoft` (62,62,66,66) inset 44; `GlowTight` (30,30,34,34) inset 20; `GlowLine` (30,0,34,64) inset 20; `KeyCap` (20,20,44,44) inset 0. Baked images always keep `ImageColor3` white. Lint: an asset key string outside `Tokens`, `Sprites` and the kit modules of the "Used by" column fails.

### 1.2 `Kit.Sprites` (new, generated, data only, requires nothing)

Written by `phase2/kit/gen_sprites.py` from `../assets/out/*.json` and `uploaded_assets.json` (`--check` fails when the file on disk differs). Never edited by hand. All numbers are source-image pixels; arrays, not `Vector2`, so requiring it creates no datatype churn.

```lua
Sprites.Icons    = { Asset = "IconSheet", Cell = 128, Glyphs = {[name] = {column, row}} }      -- 58 names, zero-based
Sprites.MapIcons = { Asset = "MapIconSheet", Cell = 128, PinTipY = 0.921875,
                     Pins = {Waypoint = true, TaxiDrop = true, CourierDrop = true}, Glyphs = {[name] = {column, row}} }
Sprites.Digits   = { [256] = Sheet, [128] = Sheet }
  -- Sheet = { Asset = "Digits256", Cell = {148, 256}, Cap = 185, Baseline = 218, Pitch = 130, PitchTight = 117,
  --           Glyphs = {["0"] = {x, y, advance, originX}, ... "9"} }        (128: cell {80,128}, cap 92, baseline 108, pitch 65/58)
Sprites.Punct    = { [256] = {Asset = "DigitsPunct", Glyphs = {[token] = {x, y, w, h, advance, originX}}}, [128] = {...} }
  -- tokens: ":" "." "," "$" "%" "+" "-" "/" "x" "K" "M" "MPH" "KM/H" "XP"
Sprites.Rings    = { Size = 512,
  Gauge   = { StartDeg = 135, SweepDeg = 270, ArcRadius = 210, BoostRadius = 184, TipFraction = 0.09 },
  Minimap = { FrameScale = 512 / 480 },                     -- ImageLabel side = map diameter x FrameScale, same centre
  Rank    = { FrameScale = 1.099 * 512 / 480, StartDeg = 180, SweepRegular = 90, CompactFromDeg = 165, CompactToDeg = 285 },
  TitleSlash = { Size = {160, 192}, Design = {53.3, 64} } }
Sprites.Touch    = { [control] = { Idle = assetKey, Pressed = assetKey, PlateDp = {w, h}, FrameDp = {w, h}, HitDp = {w, h} } }
  -- control: "Accelerate" "Brake" "Turn" "Drift" "Boost"; values from touch.json (e.g. Accelerate plate 72x100, frame 110, hit 96x112)
Sprites.Source   = { Generator = string, Inputs = {[file] = sha256} }
```

Icon glyph names (the only valid `IconName` values): `garage dealership customise race_flag map settings_cog controls gamepad car passenger players taxi parcel exit back steering_wheel trophy medal star coin timer loop laps checkpoints pin set_route route north boost upgrade lock tick chevron_left chevron_right chevron_up chevron_down plus minus close title_mark warning info duel paint keycap_blank dpad pad_select pad_start pad_a pad_b pad_x pad_y pad_lb pad_rb pad_lt pad_rt drift gauge`. Map glyph names: `Race TimeTrial Duel Job TaxiFare CourierPickup TaxiDrop CourierDrop Customisation Dealership Garage Waypoint Player OtherPlayer` (these equal the `Icon` keys `MapMarkers` records carry **[src]**).

Angle convention for every ring: degrees clockwise from +X in screen space (0 = 3 o'clock, 90 = 6, 180 = 9, 270 = 12).

## 2. Changes to Phase 1 modules

Installed as `source` ops whose `before` is the `../phase1/after/` file. Owner agent: **K1** = Tokens, Sprites, Metrics, Layers, Contracts; **K2** = Text, Surface, Controls, Collections, Input; **K3** = Overlay, Gauge, Minimap; **K4** = BigNumber, Data, Touch. K1 also writes `Kit.Presence`; the integrator writes `Routes`, `UIP.NoOp` and the fixtures index. Each delta keeps existing callers (toasts, gallery, Phase 1 fixtures and tests) working.

### 2.1 Dependencies (replaces the kit rows of API1 1; still no cycles)

| Module | May require |
|---|---|
| `Kit.Sprites`, `Kit.Contracts`, `Kit.Perf`, `Kit.Presence` | nothing |
| `Kit.Tokens` | Sprites |
| `Kit.Metrics` | Tokens |
| `Kit.Layers` | Tokens, Metrics, Contracts |
| `Kit.Text`, `Kit.Surface` | Tokens, Sprites, Metrics |
| `Kit.Input` | Tokens, Metrics, Contracts |
| `Kit.BigNumber` | Tokens, Sprites, Metrics |
| `Kit.Controls`, `Kit.Collections` | Tokens, Metrics, Text, Surface, Input |
| `Kit.Data` | Tokens, Metrics, Text, Surface, Input, Controls, Collections, BigNumber |
| `Kit.Gauge`, `Kit.Minimap` | Tokens, Sprites, Metrics, Text, Surface, BigNumber, Perf |
| `Kit.Touch` | Tokens, Sprites, Metrics, Surface |
| `Kit.Overlay` | everything above except Gauge, Minimap, Touch |
| `UIP.NoOp` | nothing |
| family modules (`UIP.<Family>.*`) | any Kit module; `UIP.Routes`; `Core.ConnectionScope`, `Core.ConfigReader`; the shared modules their family row lists (section 5) |

### 2.2 `Kit.Tokens`

- `Tokens.Assets`: the 31 keys of 1.1 with uploaded ids as defaults (changed: was 20 keys, all `""`).
- `Tokens.Icons` stays, now built from `Sprites.Icons` (`{Cell, Glyphs}`), so API1 callers keep working. New code uses `Sprites`.
- `Tokens.Tier` is unchanged and is now also used by tier buttons (`Controls.Tabs` `Tier` items, 3.6).
- New `Tokens.NumberCap = {Regular = {...}, Compact = {...}}`, flat names `NumberCap<Role>` and `CompactNumberCap<Role>`:

```text
Regular:  Speed 95   Hero 140   Position 150   Timer 62   Countdown 260   Rank 22   Small 31
Compact:  Speed 24   Hero 31    Position 28    Timer 17   Countdown 67    Rank 10   Small 12
```

- New `Tokens.Space` keys (flat `Space<Key>`; design px unless marked dp):

```text
MenuTopRightTop 67        RightColumnTop 152        HudRightColumnTop 186     RailButtonsLift 30
StatusHeight 54           StatusPad 6               ActionTileWidth 77        ActionTileHeight 60     ActionGap 8
HudButtonHeight 56        GaugeSize 403             GaugeTouchSize 240        MinimapSize 307         MinimapInset 18
MinimapLabelBand 52       RankArcWidth 10           RankArcGap 8              SidePanelWidth 600      StatRowHeight 48
StatPanelHeight 448       SegmentWidth 10           SegmentGap 3              SegmentHeight 10        FactRowHeight 58
PromptWidth 590           PromptHeight 84           PromptLift 330            KeyCapSize 40           TitleMarkWidth 34
TitleMarkHeight 60        HeaderTabsGap 14          ModalMaxWidth 900         SwitchGap 30            StepperWidth 220
SliderHeight 40           DropdownRowHeight 56      TextShadowOffset 2
CompactBottom 8 (dp)      CompactTop 8 (dp)         CompactRightColumnTop 45 (dp)   CompactRailButtonsLift 14 (dp)
CompactTileHeight 60 (dp) CompactStatPanelWidth 176 (dp)   CompactGauge 92 (dp)   CompactMinimap 92 (dp)
CompactActionTile 32 (dp) CompactSidePanelWidth 232 (dp)   CompactHudButton 36 (dp)   CompactPromptLift 112 (dp)
CompactPromptWidth 300 (dp)   CompactStatusHeight 26 (dp)   CompactKeepOutGap 8 (dp)
```

- New `Tokens.Opacity` keys: `TextShadow 0.60`, `TouchDisabled 0.40`, `ButtonPlate 0.86`, `HairButtonTop 0.85`, `HairButtonBottom 0.22`, `Vignette 0.90`, `RankTrackImage 0.25`.
- New `Tokens.Scale` key: `RegularDp 1.25` (see `ctx.Dp`).
- `Tokens.Flatten` covers the new groups; `Assets`, `Slices`, `Icons` stay outside it (API1 note). The integrator regenerates the attribute ops from `Tokens.Flatten(Tokens.Defaults)` exactly as Phase 1 did; code defaults equal config by construction.

### 2.3 `Kit.Metrics`

Added to `Context` (and to `Metrics.Fixed`'s spec as optional fields with the same names):

```lua
Dp: (dp: number) -> number,      -- Compact: Px(dp). Regular: round(dp x ScaleRegularDp), at least 1. Used ONLY by Kit.Touch and the
                                 -- touch fork's layout, so on-screen pedals keep a physical size on tablets
ChatKeepOut: Vector2,            -- real px, ScreenInsets.None space: bottom-right corner of the Roblox chat window while it is shown;
                                 -- (0, 0) when chat is hidden or disabled. Studio measure: window (8,12) 475 x 273.5
```

- Source: `TextChatService.ChatWindowConfiguration` (`Enabled`, `AbsolutePosition`, `AbsoluteSize`) and `StarterGui:GetCoreGuiEnabled(Chat)`. Metrics stays the only listener; a change fires `Changed` with `Layout = true` after the settle time. **[assumed]**: the player collapsing chat from the top bar is visible through these properties; if it is not, `ChatKeepOut` is the full rectangle whenever chat is enabled (integrator records which).
- `Metrics.Fixed` defaults: `ChatKeepOut = (0, 0)`. Gallery presets `R720`, `R1080`, `R1440` gain a state toggle `GalleryChat` (in, boolean attribute) that sets it to `(483, 286)`.
- Nothing else changes: class, band, arrangement, input and scale rules are API1 6.

### 2.4 `Kit.Layers`

`Frame3` and `Layer` are unchanged. `Layer.Slot(name)` accepts the names below; the eight API1 names keep their API1 meaning **except where marked changed**.

**Margins (changed; resolves Phase 1 note B1/B2).** `M` (side) and `B` (bottom):

| Class | Frame | `M` | `B` |
|---|---|---|---|
| Regular | `Menu`, `Scene` | `Px(MenuMargin)` 68 | `Px(MenuBottom)` 30 |
| Regular | `Hud`, `Bare` | `Px(HudMargin)` 40 | `Px(HudBottom)` 28 |
| Compact | every frame | `Px(CompactMargin)` 12 dp | `Px(CompactBottom)` 8 dp |

`Scene` used the Hud values in Phase 1; no installed caller uses `Scene`, and the `Layers` test's C844 expectations are updated by K1.

**Keep-out rules, enforced by slot positions and checked by `layout_lint`:**

1. Nothing of ours is drawn inside `ctx.TopBarKeepOut` (208 x 58 real px in Studio, top-left). `barBottom = max(0, round(TopBarHeight - Origin.Y))`.
2. Regular: every top-left block starts at `barBottom + TopBarGap` (12 real px). Compact: titles sit **beside** the Roblox buttons on the bar row, starting at `x = TopBarKeepOut.X + Px(CompactKeepOutGap)`; anything below the title starts at `max(barBottom, title bottom) + Px(CompactKeepOutGap)` **[seen c11, c12]**. `Controls.Header` (3.6) implements both; screens never compute it.
3. In-play top-left HUD content uses `TopLeftHud`, which starts 12 real px below the chat rectangle while chat shows (`ChatKeepOut.Y`), else at rule 2. What does not fit between it and the minimap goes to `RightColumn` (the race-start event card does this **[seen r16a]**).
4. Chat is hidden while any `Presence` kind other than `Race` is open (3.9; `Shell.CoreUiPolicy`, 5.3).

**Slots.** `W`, `H` = root size (floored). Anchor = the slot's `AnchorPoint`, which a child copies (API1 8). "Sized" slots are not zero-size: a child may fill them with `Size = UDim2.fromScale(1, 1)` or scale-1 width; this is the answer to Phase 1 note D1 (a `Rail` in `BottomRail` fills the slot width).

| Slot | Anchor | Regular | Compact | TouchDrive difference |
|---|---|---|---|---|
| `TopLeft` (changed on Compact) | 0,0 | `(M, barBottom + TopBarGap)` | `(M, Px(CompactTop))`; `Header` applies rule 2 | none |
| `TopLeftHud` | 0,0 | `(M, max(barBottom, ChatKeepOut.Y - Origin.Y) + TopBarGap)` | same formula with `M` Compact | none |
| `TopRight` (changed) | 1,0 | Hud: `(W - M, Px(TopRightTop))` 40. Menu/Scene: `(W - M, Px(MenuTopRightTop))` 67 | `(W - M, Px(CompactTop))` | none |
| `TopCentre` | 0.5,0 | `(W/2, barBottom + Px(ToastTopGap))` (toasts; unchanged) | unchanged | none |
| `TopCentreHud` | 0.5,0 | `(W/2, Px(TopRightTop))` (race timer) | `(W/2, Px(CompactTop))` | none |
| `ActionBar` | Regular 1,0; Compact 0.5,0 | `(W - M, Px(TopRightTop) + Px(StatusHeight + 2 x StatusPad) + Px(Gap))` (under the status strip) | `(W/2, Px(CompactTop))` (top centre **[seen c02]**) | none |
| `HudStatus` | 1,0 | = `TopRight` | Standard: = `TopRight`. TouchDrive: under the minimap, `(W - M, minimap bottom + Px(TouchGap))` **[seen c02]** | as stated |
| `RightColumn` (fixed now), sized | 1,0 | Menu/Scene: `(W - M, Px(RightColumnTop))` 152, width `Px(StatPanelWidth)`. Hud: `(W - M, Px(HudRightColumnTop))` 186, same width | `(W - M, Px(CompactRightColumnTop))`, width `Px(CompactStatPanelWidth)` | Hud + TouchDrive + Regular: starts under the minimap |
| `SidePanel`, sized | Regular 0,0; Compact 1,0 | `(0, 0)`, size `(Px(SidePanelWidth), H)`; content insets itself by `M` and `barBottom + TopBarGap` **[seen r09]** | right side: `(W - M, Px(CompactTop))`, size `(Px(CompactSidePanelWidth), H - Px(CompactTop) - B)` **[seen c03]** | none |
| `BottomRail` (changed: sized) | 0,1 | `(M, H - B)`, width `W - M` (runs to the right edge of the root, where it clips) | same | none |
| `RailButtons` | 1,1 | `(W - M, H - B - Px(TileHeight) - Px(RailButtonsLift))`: the row's bottom edge; 64 high, on the rail heading line **[seen r01, r03, r12]** | `(W - M, H - B - Px(CompactTileHeight) - Px(CompactRailButtonsLift))` | none |
| `BottomRight` | 1,1 | `(W - M, H - B)` | same | none |
| `BottomLeft` | 0,1 | `(M, H - B)` | same | none |
| `BottomCentre` | 0.5,1 | `(W/2, H - B)` | same | none |
| `Centre` | 0.5,0.5 | `(W/2, H/2)` | same | none |
| `Minimap` | Standard 0,1; TouchDrive 1,0 | Standard: `(M + Px(MinimapInset), H - B - Px(MinimapLabelBand))` (the frame's bottom-left; district label goes in the band below) | Standard: same with Compact tokens and `MinimapLabelBand` 0 | TouchDrive Regular: `(W - M - Px(MinimapInset), Px(HudRightColumnTop))`. TouchDrive Compact: `(W - M - Px(TouchGap), Px(CompactTop) + Px(TouchGap))` |
| `Gauge` | Standard 1,1; TouchDrive 0.5,1 | `(W - M, H - B)` | same | `(W/2, H - B)` |
| `HudButtons` | Standard 0.5,1; TouchDrive 1,1 | `(W/2, H - B)` | same | left of the gauge: `(W/2 - gaugeHalf - Px(Gap), H - B)`, `gaugeHalf = floor(Px(GaugeTouchSize) / 2)` Regular, `floor(Px(CompactGauge) / 2)` Compact **[seen c02]** |
| `PromptStack` (fixed now) | 0.5,1 | `(W/2, H - Px(PromptLift))`; the stack grows upward | `(W/2, H - B - Px(CompactPromptLift))` | none |

Arrangement-aware slots (`Minimap`, `Gauge`, `HudButtons`, `HudStatus`, `ActionBar`) are the only place Standard and TouchDrive differ. A screen never tests `ctx.Arrangement` to place something; it may test it to choose a size (`GaugeSize` against `GaugeTouchSize`).

**Ladder additions (`Layers.Order` rows added by K1; `<name>Live` = base + 1 and `<name>Scrim` = base - 1 by the API1 rule unless listed):**

```text
PulseWorldPrompts 80        PulseEventCard 81           DesktopFreeRoamHudLive 86      ActivityHudLive 87 (row: 84 + 1 is taken)
FullMapScrim 89             FullMapLive 91              MobileDriveControls_Phase1 96  SharedInRaceHUDLive 156
OwnedGarageBrowserScrim 168 (row)   RaceBrowserScrim 169    RaceEntryPresentationScrim 179     UnifiedRaceResultsScrim 219
CanonicalGarageGuiScrim 39  CanonicalGarageGuiLive 41   OwnedGarageInteriorHUDLive 59  GarageEntranceStatus: not created (toast)
LoadingSafeContentScrim 1000 (row)   LoadingSafeContent 1001 (row)   Onboarding 990 (unchanged)
```

`Layers.Create` gains one option, `RootName: string?` (default `"Root"`), because Classic readers need `DesktopFreeRoamHud.DesignRoot`, `ActivityHud.DesignRoot` and `LoadingSafeContent.SafeRoot` by name; `layer.Root` is that frame. It is otherwise unchanged. A family that needs a static and a live gui calls `Create(name, {...})` and `Create(name, {Live = true, ...})`; a family never creates a ScreenGui whose name is not in `Order`.

### 2.5 `Kit.Contracts`

Regenerated by K1 (`gen_contracts.py`, moved to `phase2/kit/`), same fields. Two additions: `Contracts.Owner: {[ownerName]: {ScreenGuis: {string}, Remotes: {{Remote: string, Action: string, Keys: {string}}}, Bindables: {string}, Attributes: {string}}}` built from `classic/contracts/<Owner>.json` for the owners named in section 5 (used by the parity check, never at run time), and `Contracts.GenericNames` = the reserved names that are also generic (`Root`, `Panel`, `Text`, `Status`, `Body`, `Image`, `Price`, `Rating`, `Back`, `Buy`, `Exit`, `Detail`, `Cash`, `Settings`, `Controls`, `Stroke`), which lint rule 10 allows anywhere (Phase 1 note B). Mark keys are unchanged (Phase 1 note B "Marks keys": a legacy name is its own key; `Card`, `Card.<id>`, `Page.<id>`, `Text.TimeTrial`, `Text.Race`, `Text.Dealership`).

### 2.6 `Kit.Text`

- `Fixed` default (Phase 1 note C5): display roles **and `Value`** are Fixed; only `Label` and `Body` grow with the player's Text Size.
- `Shadow` uses `Opacity.TextShadow` and `Space.TextShadowOffset` (was `Opacity.Panel` and a hairline offset).
- The holder `UIScale` is excluded from budgets (Phase 1 note C4). `Text.ReadyChanged` and `Metrics.Changed` are Luau signals with `Connect`, `Once`, `Wait` (not `RBXScriptSignal`); this is now the documented type (note C1).
- `BigNumber` does **not** live here; it is `Kit.BigNumber` (3.1).
- New: `Text.StyleForeign(label: TextLabel, role: TextRole): ()` sets `FontFace`, `TextSize` (for `Metrics.Screen()`), `TextColor3` White and `TextStrokeTransparency = 1` on a label the kit did not build. Its one caller is the RaceTransitionClient seam (section 5.5).
- New helper, pure: `Text.RawLabel(parent, role, ctx): TextLabel` builds one plain TextLabel with the role's face, size, baseline shift and a `SizeLock` constraint when the role is Fixed. Kit modules use it inside budgeted components (it is what `Controls` and `Collections` already do privately, note D3); family code uses `Text.Label`.

### 2.7 `Kit.Surface`

- `Icon`: reads `Sprites.Icons` (was `Tokens.Icons`); new optional prop `Opacity: number?`. Unknown name still errors.
- `Glow`: uses the uploaded 9-slices; kinds unchanged (`Tile` = `GlowSoft`, `Button` and `Ring` = `GlowTight`, `Line` = `GlowLine`). The image is tinted by `Colour`. With the ids now present a real ImageLabel is created; the empty-asset path is kept.
- `Scrim` kind `Garage`: now two gradients (left 38% and bottom 40%, PC style sheet), budget 3. Kind `Hud` added: top and bottom 20% soft dark gradient, `Active = false`, budget 3.
- New constructors:

| Constructor | Props | Notes |
|---|---|---|
| `TitleMark` | `Height: number?` (default `TitleMarkHeight`) | One ImageLabel of `TitleSlash`, untinted, aspect 160:192. Empty asset: a `Pink` block of the design box. Budget 1 |
| `MapIcon` | `Icon: string` (a `Sprites.MapIcons` name), `Colour: ColourRole?`, `Size: number` | One ImageLabel. Pin glyphs (`Sprites.MapIcons.Pins`) set `AnchorPoint` (0.5, `PinTipY`), others (0.5, 0.5). The named colour exception of PC 2.3 (map marker colours) is passed as `Tint: Color3?` and is accepted **only** by this constructor |
| `KeyCap` | `Text: string?`, `Icon: IconName?`, `Size: number?` | 9-slice `KeyCap` in White with an Ink letter (role `Value`), or a gamepad glyph from the sheet (`pad_a` ...). Budget 2 |
| `Divider` | `Vertical: boolean?`, `Opacity: number?` | One Frame, `ctx.Hair(2)`; rows of lists and the status strip |

### 2.8 `Kit.Controls`

- **`Button`, variants `Default` and `Danger` (changed look, same props):** a visible plate. `Default`: `Slate` at `Opacity.ButtonPlate` with a top hairline (`White`, `HairButtonTop`) and a bottom hairline (`White`, `HairButtonBottom`) **[seen r00, r01, r03]**. Hover, press and focus still turn `Fill` White with Ink text and hide the hairlines; Disabled is 0.40 with no hairline. New required child names `HairTop`, `HairBottom`. **Budget 6 (7 Main)** (resolves Phase 1 note D2). `Main` and `Buy` keep no hairline; `Main` appends the trailing chevrons (`»`, as text) and `Buy` too **[seen r01]**.
- `Button` new props: `Size = "Hud"` (height `HudButtonHeight`, Compact `CompactHudButton`), `IconOnly: boolean?` (square, width = height), `Selected: boolean?` (White fill held, as an open action-bar tile).
- `Button` sizes on Compact: drawn height `CompactButtonDrawn` (36 dp) inside a `ctx.Touch` hit box; the root is the hit box, `Fill` is the drawn plate.
- **`ButtonRow`:** every row is `ButtonHeight` (64) high. New prop `Place: "Slot" | "None"` (default `"Slot"`): the row anchors to its parent with the parent slot's anchor (so it works unchanged in `RailButtons`, `BottomRight`, `BottomCentre`, `HudButtons`). `Align` keeps its meaning for the row's own content. Order rule unchanged (back or exit, secondary, main; main right-most).
- **`Tabs`:** unchanged behaviour. Items gain `Tier: Tier?` (a tier button: the letter and base line in the tier colour; the selected one is filled with it, Ink letter; Locked dims **[style sheet, race entry]**) and `Count: string?`. New prop `Style: "Tabs" | "Segment"` (default Tabs). `Segment` is the smaller Shop / Owned form (`SwitchGap`, no icons) **[seen r03]**; with `Triggers = true` the triggers switch it (PC 2.2).
- New constructors: section 3.6.

### 2.9 `Kit.Collections`

- **`Tile` (changed look, same props):** plate `Slate` at `Opacity.Panel` plus a bottom hairline at `HairBottom`, in every state except Selected (White fill, Pink-to-Violet base line) **[seen r01]**. New child name `HairBottom`. **Budget 13.**
- `Tile` new props: `ChipRightKind: "Neutral" | "Pink" | "Cyan" | "Tick"` (the pink `EMPTY` chip and the cyan tick corner **[seen c12]**; resolves note D8), `Selectable: boolean?` (default true). **Changed:** `Status = "Unaffordable"` no longer sets `Active = false`; the tile can be selected and previewed, its price is muted, and only the Buy button is disabled (resolves note D9; Classic lets you preview a car you cannot afford). `Locked` still sets `Active = false` unless `Selectable = true` is passed (race-entry vehicle rail shows locked cars but they cannot be chosen **[seen r12]**).
- `TierBadge`: unchanged signature; the letter cell always uses `Tokens.Tier[tier]`; `Dim` lowers the whole badge to `Opacity.Locked`. Sizes `BadgeLarge/Medium/Small`; on Compact the badge height is `max(Px(CompactStatusHeight - 4), TextSize)`.
- **`Rail`:** fills a sized parent (2.4). New props `Width: number?` (design px; overrides) and `Rows: number?` (default 1; 2 gives the Compact car-panel grid **[seen c03]**, vertical scroll). New methods `SetHeading(text, count)` and `HeadingRight: Frame` (a frame on the heading line, right of the count, where a screen mounts a `Tabs` `Segment` **[seen r03]**). Default cell: Regular `TileWidth` x `TileHeight`; Compact width fits the name with `CompactTileMinWidth`, height `CompactTileHeight`.
- `ListRow` new props: `Chip: string?` and `ChipKind` (SPAWNED / PARKED **[seen r09]**), `Height: number?`, `Columns: {string}?` (results and leaderboard rows: fixed column texts instead of `Title`/`Right`), `Accent: boolean?` (the Pink left bar of "your row" **[seen r15a]**). Budget 12.
- New `Collections.List(parent, props, scope)`: a vertical keyed pool of `ListRow`s, same contract as `Rail` (`SetItems`, `Select`, `ScrollTo`, `Row(key)`), props `RowHeight`, `Width`, `Header: {string}?`, `OnSelected`. Zero churn on a data or selection change once the pool has grown.
- `Collections.Pool(make: (index) -> T, reset: (T) -> ()): {Take, Release, ReleaseAll, Count}` is exported for family views that pool something the kit has no component for (map icons, route segments, order rows).

### 2.10 `Kit.Input`

- `Input.Mark(instance, key)` also sets the attribute `PulseMark = key` on the instance (a Play probe can then list marks without a require).
- Classic-onboarding callout scale on Pulse screens (PC 2.3), decided: **no remedy is built.** With no `UIScale` ancestor Classic falls through to `clamp(min(w/1600, h/900), 0.68, 1.08)` on desktop and 0.6 on a short screen **[src OnboardingClient 235-246]**, which is within 8% of the kit scale. No Pulse module adds a `UIScale` for it. The gates check callout position and that targets are found; size is recorded, not gated. It ends when the Shell family lands.
- New `Input.FocusGroup` method `Remove(button)` (needed by pooled lists; resolves note D11). `Rail` and `List` now register one group each.
- New `Input.BindAction(scope, name: string, handler, priority: number?, ...: Enum.KeyCode | Enum.UserInputType)`: for owners that must keep a **Classic action name** (`FullMapToggle`, `FullMapPad`); the name is used as given instead of `Pulse_<purpose>_<n>`.

### 2.11 `Kit.Overlay`

- `Confirm`: unchanged contract. Title now uses `Surface.TitleMark`. The scrim stays inside the safe-area gui (Phase 1 note E).
- `Toast`: new optional second argument form `Show({Text, Icon: IconName?, Kind: "Neutral" | "Good" | "Bad"}, duration)`; a string behaves as today. Good = Cyan edge, Bad = Danger edge.
- `Modal` additions and `PromptBanner`: section 3.7.

## 3. New kit modules

Conventions of API1 2 apply (constructor shape, `Set`, `Destroy`, design values, no colours from screens). Nothing here yields unless marked. Budgets are descendants including the root, excluding glows and `SizeLock` constraints.

### 3.1 `Kit.BigNumber` (K4)

```lua
BigNumber.Layout(text: string, sheet: 128 | 256, tight: boolean?): {Cells: {{Token: string, X: number}}, Width: number}   -- pure
BigNumber.SheetFor(capPx: number): 128 | 256                                                -- pure: 128 when capPx <= 92
BigNumber.New(parent, props, scope): Component & {SetText: (text: string) -> ()}
```

Props: `Text: string`, `Role: "Speed" | "Hero" | "Position" | "Timer" | "Countdown" | "Rank" | "Small"` (cap from `Tokens.NumberCap`), `Colour: ColourRole` (default White), `Align: "Left" | "Centre" | "Right"`, `MaxCells: number` (required; the pool size and the fixed width), `Tight: boolean?`, `Fixed: boolean?` (default true: digits sit in fixed cells of `Pitch` so a changing number does not jitter; false = proportional advances, for static hero numbers).

- Tokeniser: longest match first over `Sprites.Punct` tokens (`KM/H`, `MPH`, `XP`), then single characters; an unknown character errors at build and is skipped with one warning at run time. A space advances half a pitch.
- Each cell is one ImageLabel (`ImageRectOffset/Size` from the sheet, tinted by role). Draw scale = `Px(cap) / sheet.Cap`. Cell x = pen - originX, pen advances by `Pitch` (Fixed) or the glyph advance; digit cells overlap by the italic overhang, as `digits.json` `layout` says. Whole pixels.
- `SetText` writes **only cells whose token changed** (`ImageRectOffset`, `ImageRectSize`, `Size`), plus `Visible` for cells that appear or disappear; an unchanged text writes nothing. Callable from a `Perf.Bind` step (no lookups, no creation: the pool is `MaxCells`).
- The root has the fixed size `(MaxCells x pitch, cell height)` so nothing around it relays out. Budget `MaxCells + 1`.
- Empty asset: one `Text.RawLabel` in role `SectionHead` instead (flat state).

### 3.2 `Kit.Gauge` (K3)

```lua
Gauge.Angles(fraction: number): (number, number)        -- pure: rotations of the two mask gradients, quantised to 0.5 degree
Gauge.New(parent, props, scope): Component & {
  SetSpeed: (value: number, fraction: number) -> (),    -- integer shown; fraction 0..1 of the arc
  SetBoost: (fraction: number) -> (), SetUnit: (unit: "MPH" | "KM/H") -> (), SetVisibleBoost: (boolean) -> () }
```

Props: `Size: number?` (design; default `GaugeSize`, pass `GaugeTouchSize` or `CompactGauge` for TouchDrive and Compact), `Unit`, `ShowBoostText: boolean?` (default true on Regular; the Compact gauge has no boost line **[seen c02]**).

- Stack, bottom to top, all the gauge frame size, same centre: `Track` (`GaugeTrack`), `Ticks` (`GaugeTicks`), `Glow` (`GaugeGlow`, revealed), `Arc` (`GaugeArc`, revealed), `Boost` (`BoostArc`, revealed), `Tip` (`GlowSoft`, White, `TipFraction` of the frame, on `ArcRadius` at the current angle), then `Speed` (`BigNumber` role `Speed`, `MaxCells = 3`), `Unit` (`Text.RawLabel`, role `Label`) and `BoostText` (role `Value`, Cyan, "BOOST 64%").
- **Reveal** = spike 06 method (`../spike/06_gauge_gradient_reveal.lua`): each revealed image is two half windows (`ClipsDescendants` frames named `<Layer>Left`, `<Layer>Right`) each holding the full-size image with one `UIGradient` whose transparency sequence is a hard step; the sweep starts at `StartDeg` 135 and covers `SweepDeg` 270. `Glow` and `Arc` share angles. Budget 26.
- **Write on change (PC 5.1 rule 5):** `SetSpeed` writes the number only when the integer changes, and the arc only when the angle changes by 0.5 degree; `SetBoost` only when the whole percent changes; the tip moves with the arc. A steady drive costs at most 2 gradient writes, 1 tip write and the changed digit cells per frame; parked costs 0.
- The gauge has no frame binding of its own. The owner calls `SetSpeed`/`SetBoost` from its one `Perf.Bind` step; both are safe there.
- The seam at the half-window join is judged by the integrator on the real images (PC 6); the fallback (a segmented arc) is not built in this wave.

### 3.3 `Kit.Minimap` (K3) - a frame, not a map

```lua
Minimap.New(parent, props, scope): Component & {
  Content: Frame,            -- the clipped round area; the screen parents its map canvas, route and icon layers here
  Overlay: Frame,            -- above the vignette, unclipped: edge-clamped icons, route chip
  SetRank: (rank: number, fraction: number) -> (),      -- rank number and XP fraction 0..1 of the arc
  SetHeading: (mapRotationDegrees: number) -> (),       -- places the north marker on the rim; write on 0.5 degree change
  SetArrow: (rotationDegrees: number) -> (),            -- the player arrow, centred
  SetLabel: (text: string) -> (), SetRound: (boolean) -> () }
```

Props: `Size: number?` (design diameter; default `MinimapSize`, Compact `CompactMinimap`), `Round: boolean?` (default true), `ShowRank: boolean?`, `Label: string?`, `OnActivated: (() -> ())?` (click opens the full map).

- Root is a TextButton (hit box = the circle's box) named **`Minimap`** by default: Classic `FullMapUI` and onboarding look for a showing descendant of that name under `DesktopFreeRoamHud` (PC 2.3) **[src FullMapUI 464-478]**.
- `Content` is the programme's one `CanvasGroup` with the one `UICorner` (lint allows both only in this module). `Round = false` (config fallback) uses a plain clipping Frame.
- Layers above `Content`: `Vignette` (`MinimapVignette`, Ink), `Ring` (`MinimapRing`, side = diameter x `FrameScale`), `RankTrack` (`RankArc` at `RankTrackImage`), `RankFill` (`RankArc` revealed clockwise from 180 degrees over `SweepRegular` 90; Compact from 165 to 285; same two-half reveal as the gauge), `RankNumber` (`BigNumber` role `Rank`, with a `RANK` label on Regular **[seen r00]**; on Compact a round Ink badge on the ring **[seen c02]**), `North` (the `north` glyph on a small Ink disc, on the rim), `Arrow` (`MapPlayerArrow`, White), `Label` (district name, role `Label`, in the `MinimapLabelBand` under the frame).
- The frame never reads map state and has no frame step; the screen's own step calls the setters. `SetRank` and `SetLabel` are event-driven. Budget 30 excluding `Content`'s children.

### 3.4 `Kit.Data` (K4)

```lua
Data.Money(amount: number, compact: boolean?): string     -- section 3.5; the ONLY money formatting in Pulse
Data.CashChip(parent, props, scope): Component & {Bind: (player: Player) -> (), SetAmount: (amount: number) -> ()}
Data.StatusCluster(parent, props, scope): Component & {Cash: Component, SetVehicle: (...) -> (), SetSpaces: (...) -> (), SetRank: (...) -> ()}
Data.SegmentedBar(parent, props, scope): Component
Data.StatPanel(parent, props, scope): Component & {SetRows: (rows) -> (), SetHeader: (header) -> ()}
Data.FactList(parent, props, scope): Component & {SetRows: (rows) -> ()}
Data.DeltaChip(parent, props, scope): Component
```

| Constructor | Props | Notes |
|---|---|---|
| `CashChip` | `Compact: boolean?` (short form `$3.61M`; default = `ctx.Class == "Compact"`), `Plus: boolean?`, `OnPlus: (() -> ())?`, `MarkKey` | Yellow fill (a Yellow-to-warmer `UIGradient`), Ink text, `coin` icon. Width is fixed to the widest of the old and new text during a count and re-fitted when the count ends. `Bind` = section 3.5. Mount it on a **live** layer. Budget 6 |
| `StatusCluster` | `Mode: "Vehicle" | "Garage" | "CashOnly"`, `Tier`, `Rating`, `Spaces: string?` ("3 / 4"), `Rank: number?`, `ShowPlus: boolean?`, `OnSpacesPlus`, `OnCashPlus`, `MarkKey` | One slate strip, height `StatusHeight` inside `StatusPad`: car icon + `TierBadge` + rating (Vehicle) or garage icon + spaces (+) (Garage), a divider, the rank ring (a small ring with the number), the `CashChip` **[seen r00, r01]**. `CashOnly` is the Compact HUD form. `cluster.Cash` is the embedded chip. Budget 20 excluding the chip |
| `SegmentedBar` | `Value: number` (0..1), `Preview: number?` (0..1), `Segments: number?` (default 16), `PreviewColour: "Cyan" | "Pink"` | Tiled `SegmentStrip` images (`ScaleType = Tile`, tile width = `Px(SegmentWidth + SegmentGap)`): `Empty` (White at `SegmentEmpty`), `Fill` (White, clipped to the value), `Gain` (the previewed part). **At most 4 instances.** Widths are whole segments |
| `DeltaChip` | `Delta: number`, `Suffix: string?` | Cyan chip with an up arrow for a gain, Pink with a down arrow for a loss, hidden at 0. Colour is never the only signal. Budget 3 |
| `StatPanel` | `Title: string`, `Tier`, `Rating`, `Sub: {string}?` (one or two lines), `Rows: {{Id, Label, Value: number, Max: number?, Preview: number?, Text: string?}}`, `Price: string?`, `Width`, `Height` | A `Panel` with the header (name + `TierBadge` Large), sub-lines, then pooled rows: label, `SegmentedBar`, value cell, `DeltaChip` **[seen r01, r03]**. `SetRows` updates in place (no create or destroy when the row ids are unchanged). Compact: the collapsed form (badge + name, optional `PRICE` row, rows without delta chips unless changed) **[seen c11, c12]**. Budget 12 + 12 per row |
| `FactList` | `Rows: {{Id, Icon: IconName?, Label: string, Value: string, Kind: "Text" | "Prize"}}` | Icon + label left, value right, a `Divider` between rows; a `Prize` row ends in a Yellow chip **[seen r12]**. Pooled. Budget 2 + 6 per row |

`TierBadge` is `Collections.TierBadge`, reused everywhere a tier shows; `Data` adds no second badge.

### 3.5 Cash and money (binding; read with PC 2.1)

PC 2.1 lists "the money formatters, cash presenter, `ProjectEconomy` and `BindReplicatedCash` in `ResponsiveUIFoundation`" as reused unchanged, and API1 rule 3 forbids requiring `ResponsiveUIFoundation` from Pulse. Resolution for this wave: **`Kit.Data` is the one Pulse module allowed to require `ReplicatedStorage.Modules.Game.UI.ResponsiveUIFoundation`**, lazily, through the private function `foundation()` (a `FindFirstChild` walk, then `require`; never at module load, never from a `Perf.Bind` step). Lint whitelists that one path in that one file. No other Pulse module names it.

Facts **[src ResponsiveUIFoundation]**: `FormatCompactMoney(value)` L108 ("$1,234" or "$1.2M"), `FormatFullMoney(value)` L123, `FormatFreeRoamMoney(value)` L127, `CreateCashDisplayPresenter(render, options?)` L134 (returns `{SetTarget, Snap, GetDisplayed, GetAuthoritative, Destroy}`; counts up only), `BindReplicatedCash(player, callback)` L253 (callback `(number, cashValue)` from `leaderstats.Cash`, waits for late leaderstats, returns a disconnect function), `ProjectEconomy(response, fallback)` L222 (pure; `{Cash, Used, Capacity}`). None creates an instance or takes a Classic component. `Foundation.Confirmation` does both and is **never** called from Pulse (`Overlay.Confirm` replaces it).

```lua
Data.Money(amount, compact)          -- compact and FormatCompactMoney(amount) or FormatFullMoney(amount)
Data.FreeRoamMoney(amount)           -- FormatFreeRoamMoney(amount): the HUD chip on Regular
Data.ProjectEconomy(response, fallback)   -- ProjectEconomy, unchanged: {Cash, Used, Capacity}
chip.Bind(player)                    -- presenter = CreateCashDisplayPresenter(render); BindReplicatedCash(player, presenter.SetTarget);
                                     -- both released through scope. render(displayed) writes the label only when the text changes
Data._foundation                     -- test seam: a function returning the Foundation table; tests replace it with a fake
```

The first `foundation()` call requires a Classic module and may yield once (it waits for `Config.UI.Theme`, which is present at start). Owners therefore call `Data.Money` and `Bind` from their view build, never from a `Perf.Bind` step, and no `start()` depends on its return.

Rules for every family: Cash on screen is always `leaderstats.Cash` through `CashChip:Bind` or a server reply field; a price is always the server or catalogue value passed through `Data.Money`; no Pulse module adds, subtracts or predicts Cash, and affordability is `ProjectEconomy`'s answer or the server's, exactly where Classic uses each.

### 3.6 `Kit.Controls` additions (K2)

| Constructor | Props | Notes |
|---|---|---|
| `Header` | `Title: string`, `Sub: string?`, `Count: string?`, `Tabs: TabsProps?`, `MarkKey: string?` (applied to the title TextLabel, e.g. `Text.Dealership`), `Shadow: boolean?` | `TitleMark` + `ScreenTitle` + optional sub-line + optional `Tabs` row under it, mounted in `TopLeft`. Implements keep-out rule 2 for both classes. `header.Tabs` is the tabs component. `header.Height()` returns its real-pixel height so a screen can stack a body under it **[seen r01, r03, r12, c11]** |
| `Switch` | `On: boolean`, `LabelOn: string?`, `LabelOff: string?`, `Disabled`, `OnChanged: (on: boolean) -> ()` | A two-state control drawn as two cells; the active one is White with Ink text. A real TextButton. Budget 5 |
| `Stepper` | `Value: number`, `Min`, `Max`, `Step: number?`, `Format: ((number) -> string)?`, `OnChanged`, `MarkKey` | minus button, value, plus button; buttons disable at the ends; holding does not repeat (the lap selector is tap-only **[src RaceEntry 737-738]**). Budget 9 |
| `Dropdown` | `Label: string`, `Options: {{Id, Text}}`, `Selected: string`, `OnSelected`, `MaxRows: number?` | A button showing `LABEL VALUE` and a chevron; the list is built on first open **inside the owning layer's root** (never a new ScreenGui), closes on outside press, Escape and ButtonB, traps focus while open. Budget 5 closed, + 2 per option open |
| `Slider` | `Value: number` (0..1), `Label: string?`, `ValueText: string?`, `Gradient: ColorSequence?` (**the paint named exception**: accepted only here), `OnChanged`, `OnReleased` | Track + handle; drag with mouse or touch, left and right with keys or the pad (step 1/100, 1/20 with the bumper held). `OnChanged` fires while dragging, at most once per frame. `Active = true` so it blocks camera orbit. Budget 7 |
| `IconButton` | `Icon: IconName`, `Selected: boolean?`, `Disabled`, `Size: "Action" | "Small"`, `MarkKey`, `OnActivated` | The action-bar tile (`ActionTileWidth` x `ActionTileHeight`; Compact `CompactActionTile` drawn in a 48 dp hit box). Selected = White fill, Ink glyph **[seen r09]**. Budget 4 |
| `Swatch` | `Colour: Color3` (**named exception: paint swatches**), `Selected: boolean?`, `OnActivated` | A square colour cell; Selected adds the White frame and Pink base line. Budget 3 |

`Tabs` with icons is the existing `Tabs` (`Icon` per item, API1 7.3) plus the 2.8 additions.

### 3.7 `Kit.Overlay` additions (K3)

```lua
Overlay.PromptBanner(parent, props, scope): Component & {SetProgress: (fraction: number) -> ()}
Overlay.PromptStack(parent, props, scope): Component & {Show: (id: string, props) -> Component, Hide: (id: string) -> (), Count: () -> number}
```

- **`PromptBanner`** props: `Action: string`, `Object: string?`, `Key: Enum.KeyCode?`, `PadKey: Enum.KeyCode?`, `Main: boolean?`, `Hold: boolean?`, `OnPress: (() -> ())?`, `OnRelease: (() -> ())?`. A slate strip `PromptWidth` x `PromptHeight` with hairlines: action in `ButtonMain`, object in `Label`, and on the right a `KeyCap` (keyboard) or pad glyph, following `ctx.Input` live **[seen r16a]**. With `ctx.Input == "Touch"` there is no key cap and the whole banner is a TextButton of at least 48 dp calling `OnPress`/`OnRelease`; otherwise it is not clickable. `SetProgress` fills a Cyan base line for hold prompts. Body roles grow with Text Size. Budget 9.
- **`PromptStack`**: a keyed pool of banners for one slot (`PromptStack`), newest at the bottom, at most 3 shown. `Show` with an existing id updates in place.
- **`Modal`** additions: props `Buttons: ButtonRowProps?` (a footer row, right-aligned), `Scrim: "Menu" | "Confirm" | "None"`, `Side: "Centre" | "Left" | "Right"` (a full-height side panel: no scrim, mounted in slot `SidePanel` **[seen r09, c03]**), `CloseButton: boolean?` (the X of the Compact panel). `Open` registers a `Presence` entry of kind `Modal` (or `SidePanel`) and releases it on `Close`. Still built on first open, at most 120 instances per modal (PC 5.2).

### 3.8 `Kit.Touch` (K4) - visual builders only

```lua
Touch.Button(parent, props, scope): Component & {SetPressed: (boolean) -> (), SetDisabled: (boolean) -> (), SetCharge: (fraction: number) -> ()}
```

Props: `Control: "Accelerate" | "Brake" | "Turn" | "Drift" | "Boost"`, `Mirror: boolean?` (right-hand turn and drift: `ImageRectOffset (512, 0)`, `ImageRectSize (-512, 512)`), `Name: string` (the fork passes the Classic names, e.g. `DriftLeft`, `DriftRight`, `Boost`).

- Root is an **ImageButton or TextButton of the Classic class** (the fork states which per control) sized `ctx.Dp(HitDp)`, transparent, `Active = true`; child `Art` is an ImageLabel sized `ctx.Dp(FrameDp)`, centred on the plate. `SetPressed` swaps `Art.Image` between the idle and pressed ids (never layers them); `SetDisabled` sets `ImageTransparency = 1 - TouchDisabled`. `Boost` adds the charge ring: `RankArc` in a frame 1.02 x the boost frame, track at `RankTrackImage`, fill revealed clockwise from 270 degrees by `SetCharge` (whole percent) **[seen c20]**.
- **It connects no input, reads no input state and writes no attribute.** The forked Classic touch client keeps every `InputBegan`/`InputEnded`/touch handler and every `MobileDriveInputState` write, and calls `SetPressed` where Classic changed a colour or image. Budget 2 (6 for Boost).

### 3.9 `Kit.Presence` (K1) - who is open

```lua
type Kind = "FullMenu" | "Garage" | "Results" | "Map" | "Modal" | "SidePanel" | "Race" | "Loading"
Presence.Open(surface: string, kind: Kind): () -> ()      -- returns a release function, repeat-safe
Presence.Any(kind: Kind?): boolean
Presence.Is(surface: string): boolean
Presence.Changed: Signal                                   -- fires (surface, kind, open)
```

In-memory only: no instance, no attribute, no remote. It replaces nothing Classic reads: **every player attribute and bindable in section 5 is still written or fired as Classic does**; `Presence` only lets Pulse owners (the core UI policy, the HUD, prompts) react to each other without polling PlayerGui (PC 5.1 rule 7). Each full-screen view calls `Presence.Open` when it shows and the release when it hides.

### 3.10 `UIP.NoOp` (integrator)

`return {start = function() end}` with the two header lines. Routed for entries whose work another Pulse owner does. It claims nothing.

## 4. `Routes` v2 (integrator; generated from the families' `routes.json` fragments)

API1 5 is unchanged: `Families`, `Swap`, `Add`, `Compose`, `Resolve`, `StartWatch`. `Routes.Families` grows by one name per family install, in this order; the table below is the end state.

```lua
Routes.Families = { "Toasts", "RaceMenu", "FreeRoam", "WorldMap", "RaceSession", "RaceEntry", "Garage", "Shell" }
```

| Entry name (ClientBase) | Family | Pulse path under `UIP` | Route |
|---|---|---|---|
| `SharedTopNotificationUI` | Toasts | `Toasts.ToastClient` | new owner (installed) |
| `RaceBrowserClient` | RaceMenu | `RaceMenu.RaceMenuClient` | new owner |
| `DesktopFreeRoamHudUI` | FreeRoam | `FreeRoam.HudClient` | new owner, every form factor |
| `MobileFreeRoamHudUI` | FreeRoam | `NoOp` | no-op (one HUD owner, PC 1.7) |
| `MobileDriveControlsClient` | FreeRoam | `FreeRoam.TouchControlsClient` | logic-identical fork |
| `ActivityClient` | FreeRoam | `FreeRoam.ActivityHudClient` | new owner; the five views stay shared |
| `FullMapUI` | WorldMap | `WorldMap.FullMapClient` | new owner |
| `RaceSessionPresentationClient` | RaceSession | `RaceSession.RaceHudClient` | new owner |
| `RaceCountdownPresentationClient` | RaceSession | `RaceSession.CountdownClient` | new owner |
| `RaceQueueClient` | RaceSession | `RaceSession.QueueClient` | new owner |
| `RaceRouteGuideClient` | RaceSession | `RaceSession.RouteGuideClient` | logic-identical fork (5.5) |
| `RaceTimeTrialResultCoachClient` | RaceSession | `RaceSession.ResultsClient` | new owner |
| `RaceEntryPresentationClient` | RaceEntry | `RaceEntry.RaceEntryClient` | new owner |
| `GarageUI` | Garage | `Garage.GarageClient` | new owner |
| `OwnedGarageClient` | Garage | `Garage.OwnedGarageClient` | new owner over forks |
| `GarageEntranceClient` | Garage | `Garage.GarageEntranceClient` | logic-identical fork |
| `OnboardingClient` | Shell | `Shell.OnboardingClient` | new owner |

Pulse-only entries (`Routes.Add`):

| name | Family | path under `UIP` | dependencies | tool |
|---|---|---|---|---|
| `PulseGallery` | nil | `Dev.Gallery` | none | `PulseGalleryEnabled` |
| `PulseCoreUiPolicy` | FreeRoam | `Shell.CoreUiPolicy` | none | - |
| `PulseWorldPrompts` | WorldMap | `World.WorldPromptView` | `SharedTopNotificationUI` | - |

Every other ClientBase entry is **left as it is** under both styles and is never named in `Swap`: `RaceEntryMenuClient`, `RaceLifecyclePresentationClient`, `RaceParticipantVisibilityClient`, `RaceSessionAssetsClient`, `RaceTransitionClient` (edited, 5.5), `LoadingTransitionUI`, `FreeRoamVehicleExitButtonClient` (already returns at its line 9 **[src]**), `DealershipIntroClient`, `GaragePreviewPresentationClient`, `ThrustPreviewClient`, `DriveSessionClient`, `CharacterSprintClient`, `FreeRoamParkedHoverClient`, `RuntimeVFXClient`, and the audio, lighting, LOD, window and dev-tool entries. Dependencies are untouched: a swapped entry keeps its name, so `ActivityClient -> SharedTopNotificationUI`, `GarageUI -> DriveSessionClient, LoadingTransitionUI, SharedTopNotificationUI`, `GarageEntranceClient -> LoadingTransitionUI, GarageUI`, `OwnedGarageClient -> LoadingTransitionUI`, `RaceEntryPresentationClient -> LoadingTransitionUI` and `DealershipIntroClient -> GarageUI` still hold. Every Pulse `start()` on those names must reach `ready` without waiting on an asset, a font or a remote reply (PC 1.3).

Cross-family calls go through `Routes.Resolve(entryName)` only: the HUD opens the map with `Routes.Resolve("FullMapUI").Open()` (Classic `FullMapUI` until the WorldMap family lands, then `FullMapClient`, which keeps `Open`, `Close`, `Toggle`, `IsOpen`).

## 5. The family table (binding)

Common to every row: folder `scripts/ui_restyle/phase2/families/<folder>/`; Pulse modules under `UIP` as listed; `Dev.Fixtures.<Family>` registers every view state with the gallery; ScreenGuis come only from `Layers.Create` with the names given. The "must keep" lists are the minimum the parity check enforces; the generated `classic/contracts/<Owner>.json` is the full list. Line numbers refer to `../classic/sources/<full instance path>.lua`. "Model" lines hold logic to carry over exactly; view lines are replaced. Budgets are PC 5.2. Bindables are under `PlayerScripts.Runtime` unless a path is given.

### 5.1 Toasts - done (Phase 1)

No work in this wave except the 2.11 `Toast` kinds, by K3.

### 5.2 RaceMenu (`race_menu`)

Replaces `Racing.RaceBrowserClient` (617 lines). Route: new owner.

- **Modules (4):** `RaceMenu.RaceMenuModel`, `RaceMenu.RaceMenuView`, `RaceMenu.RaceMenuClient`, `Dev.Fixtures.RaceMenu`.
- **ScreenGui:** `RaceBrowser` 170 (`Frame = "Menu"`, `Scrim = true`). Marks: `CardContent` on the event list frame, `TeleportToStart` on the main button (onboarding N1, N6). Open state is the root `Visible`.
- **Model to preserve:** `catalogEvents`, `addMode`, `buildRows` 70-106 (row `{Key = RouteId or eventId, DisplayName, TimeTrial, Race, Primary}`; Primary is TimeTrial if present; sorted by lower-case name; first row selected on every open); `mediaFor` 180-186; `availabilityText`, `routeDescriptor` 188-202; the facts rule 267-274; `teleportSelected` 416-441 with its `teleportBusy` guard; `routeSelected` 444-454; `setOpen` 403-415 (rows rebuilt on open). `Data.Money(v, false)` replaces the private formatter 61-68.
- **Remote (copy exactly):** `Remotes.Racing.RaceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {EventId = summary.EventId, Mode = "TimeTrial" | "Race"})` (427). Success is `Ok == true or Success == true`; failure text is `Message or Error or "TELEPORT FAILED"`.
- **Bindables:** connect `UI.OpenRaceBrowser` (toggle). Fire `Racing.RaceTransitionRequest` with the four payloads of 423, 432, 439, 440 and the 0.25 s wait. Fire `UI.FreeRoamVehicleExited` on teleport success, before closing. Fire `UI.FreeRoamHudPresentationMode {Owner = "RaceBrowser", Active, KeepTelemetry = false}` on every open and close, **on every device** (the Classic touch branch 406-410 that disables other ScreenGuis is not carried). Fire `UI.ShowTopNotification("ROUTE SET: " .. upper(DisplayName), 2.2)`.
- **Shared modules it may require:** `Racing.RaceConfigReader` (`GetEventSummary`), `UI.RouteGuide` (`SetDestinationById(key, "Player")`).
- **New in Pulse (PC 8):** filter tabs (All, Time trial, Race) as a client-side filter of the same rows; Escape and ButtonB close; Compact is list first, then detail. `Presence.Open("RaceBrowser", "FullMenu")`.
- **Target frames:** mockup `02-race-menu.jpg`, `c05`, `c06`. Budget 150 instances, 0 churn per row click.
- **Gates:** teleport and set-route sequences equal Classic's; Classic onboarding finds N1 and N6; the empty state ("NO EVENTS AVAILABLE", both actions disabled).

### 5.3 FreeRoam (`free_roam`)

Replaces `UI.DesktopFreeRoamHudUI` (1376) and `Activities.ActivityClient`; routes `UI.MobileFreeRoamHudUI` (502) to `NoOp`; forks `Vehicles.MobileDriveControlsClient`. D = Desktop source, M = Mobile source, MDC = touch source, AC = ActivityClient. May be built by two agents: **A** = HUD (first seven modules), **B** = touch, activity, policy.

- **Modules (12):** `FreeRoam.HudModel`, `FreeRoam.HudView`, `FreeRoam.HudMinimap`, `FreeRoam.CarPanelView`, `FreeRoam.HudModals`, `FreeRoam.HudClient`, `Dev.Fixtures.FreeRoam` (A); `FreeRoam.TouchControlsView`, `FreeRoam.TouchControlsClient`, `FreeRoam.ActivityHudView`, `FreeRoam.ActivityHudClient`, `Shell.CoreUiPolicy` (B).
- **ScreenGuis:** `DesktopFreeRoamHud` 85 and `DesktopFreeRoamHudLive` 86 (`Frame = "Hud"`, `RootName = "DesignRoot"`) on **every** device; `MobileFreeRoamHud_Phase1` is not created. `MobileDriveControls_Phase1` 96 (`Bare`). `ActivityHud` 84 (`RootName = "DesignRoot"`) and `ActivityHudLive` 87.
- **Names kept:** under `DesktopFreeRoamHud.DesignRoot`: `ModalLayer` with a child `Controls` that is visible exactly while the controls modal is open (OnboardingClient 459-462); `CarPanel`, visible while the car panel is open (475-476); a showing `Minimap` (Classic FullMapUI 464-478; it is the `Kit.Minimap` root); action buttons marked `Car`, `Garage`, `Race` (onboarding writes `Active`, `Selectable` and `AutoButtonColor` on them: show the locked look, do not fight the write). Touch: marks `DriftLeft`, `DriftRight`, `Boost`, and the Classic names `TurnLeft`, `TurnRight`, `Accelerator`, `Brake`, `ThumbstickHit`, `TiltDrift`, `TiltRecenter`, `TiltStatus`. Activity: `JobStrip`, `Offer`, `Countdown`, `RankUp`; Duel's `DuelChallengeButton` is parented by the shared view.
- **HUD model to preserve:** profile read and cache D338-366 (`GarageCatalogClient.Fetch(garageInvoke, {})`); visibility, seat and loading helpers D368-421; modal state machine and first-drive onboarding D424-473 and D986-1008; teleport D508-534; passenger access D597-618; minimap mode D632-635; vehicle rows, filter and sort D645-698 and D754-791; spawn D746-751; despawn D825-836; rank D919-927; the `updateRuntime` rules D1113-1296 (what hides the HUD: `GarageSessionActive`, `PlayerGui@OwnedGarageManagementOpen`, `FullMapOpen`, `OwnedGarageInside`, presentation owners; the map pause while racing D1142); the presentation-mode listener D1337-1353 (payload is the table `{Owner, Active, KeepTelemetry}` or the string `"Racing"`); mobile state M168, M187-190, M198-213 (control mode), M268-286.
- **Remotes (copy exactly):** `Remotes.Garage.GarageInvoke`: `"SpawnOwnedVehicleFromFreeRoam", {VehicleId, CockpitId}` (D748); `"DespawnVehicle", {}` (D829); `"ExitVehicle", {}` then `humanoid.Sit = false` (D1002). `Remotes.UI.FreeRoamHudTeleportInvoke:InvokeServer("TeleportToDealership")`, success `.Success` (D519), behind `Overlay.Confirm`. `Remotes.Activities.ActivityInvoke`: `"SetPassengerAccess", {Access = "Friends" | "Anyone" | "Nobody"}`, success `.Ok` (D612); `"Cancel", {}` (AC109); the generic `ctx.Invoke(action, args)` (AC64-68). Listen `Remotes.Activities.ActivityEvent` (AC305-314). The cash modal has **no** purchase remote: its buttons toast "CASH PRODUCTS ARE NOT ENABLED YET" (D577).
- **Bindables (`UI.*`):** fire `ShowTopNotification(text, 2.2)`; `OpenRaceBrowser`, `OpenOwnedGarageBrowser` (a missing event gives the "NOT READY" toast); `FreeRoamVehicleSpawned` and `FreeRoamVehicleExited` at the Classic points. Invoke `LoadingTransitionInvoke`: `Begin {Destination = "DealershipExterior", Status = "TRAVELLING TO DEALERSHIP"}`, then `Complete {Generation, Status = "READY"}` or `Fail {Generation, Status = "RETURNING", Reason}` (D517-528). Connect `OpenDrivingControlsFromOnboarding` (acquires `GameplayInputGate.Acquire("FirstDriveControls", "V1")`) and `FreeRoamHudPresentationMode`. `RouteGuide.Arrived` toasts "ARRIVED: " .. Label. Activity creates `OpenJobs` as AC57 does.
- **Player attributes written (same values, same moments):** `MobileFreeRoamCarMenuOpen`, `MobileMajorMenuOpen`, `MobileControlMode` (whenever `TouchEnabled`, which is when Classic's mobile HUD ran; readers MDC197, FullMapUI 449-450, OnboardingClient 473-474, GarageInteriorModeUI 273), `DrivingControlsOpen`, `FirstDrivePresentationPending`, `MinimapMode`. The activity root is hidden while `FullMapOpen` (root `Visible`, not `Enabled`).
- **Per frame:** one `Perf.Bind("FreeRoamHud", liveRoot, step)`. Exactly one `RouteGuide.Update(position)` per frame, and none while `FullMapOpen` (the map owner calls it then; D1116). Speed, boost and driving state come from `Vehicles.MobileDriveInputState` (`SpeedMph`, `BoostPercent`, `IsDriving`). Config is cached at start. Budget: 260 instances at start on Regular, modals 0 until opened, median 16 live writes per frame driving, 0 parked from Pulse code.
- **Minimap content (`HudMinimap`):** the shared `UIP.Map.*` layers (5.4) inside `Kit.Minimap.Content`, with `MapTileSet`, `MapMarkers`, `FreeRoamMapPlayerMarkers` and `RouteGuide.GetRouteState()`. `HudClient` exposes `IsMinimapShowing(): boolean` for the map family.
- **Touch fork (`TouchControlsClient`):** kept unchanged: the gate at MDC12 and the input and mode code MDC105-174 and 194-201, with every `MobileDriveInputState` write (`M.State[action]` 114, `M.AnalogDrift` 114 and 162, `M.SetSteering` 126, `M.State[*] = false` 161, `M.Refresh()` 108). Replaced spans: builders and layout MDC22-103 and 176-192. The replacement must supply the local names the kept code reads (`pressed(b, on)`, `thumbOuter`, `thumbKnob`, `tiltStatus`, the nine controls `setMode` shows and hides), built by `TouchControlsView` over `Kit.Touch` (`pressed` calls `SetPressed`). Classic positions; `ctx.Dp` sizes from `Sprites.Touch`. The visibility rule at 197 is kept, with `gui.Enabled` read as the root `Visible`.
- **Activity (`ActivityHudClient`):** model AC52-68, 123-136, 219-233, 236-251, 270-314. The `ctx` handed to the five views keeps every field of AC270-288 (`Player, Invoke, Gui, Root, IsMobile, Theme, RouteGuide, Toast, UI = {Button, Label, Strip, Offer, Countdown, Beacon}, Jobs`); `ctx.UI.Button` and `ctx.UI.Label` become kit-backed functions with the Classic call shape. `ctx.Root` is a **design-pixel frame with the one named `UIScale`** (PC 3.4), placed so Duel's 240 x 52 button at y -120 clears the Pulse bottom row. Mount order Courier, Passenger, Taxi, Duel (AC292).
- **`Shell.CoreUiPolicy`** (claims `CoreUi`): player list, health and backpack off through `SetCoreGuiEnabled`; `GuiService.AutoSelectGuiEnabled = false`; chat hidden while `Presence.Any()` is true for any kind except `Race`, restored after; chat restyle (`ChatWindowConfiguration` `FontFace`, `TextColor3`, `BackgroundColor3`) from tokens. No polling. The trailer tool re-enabling core UI is a recorded exception.
- **Edit to an existing script (reviewer):** `UI.RouteGuide`: one function inserted after line 91 (the `end` of `GetActive`); nothing else changes:

```lua
function RouteGuide.GetRouteState()
	return { Points = route and table.clone(route.Points) or nil, Version = routeVersion, Segment = progress.Segment, Point = progress.Point, Remaining = progress.Remaining, Active = active }
end
```

- **Target frames:** `r00`, `r09`, `r10a` to `r10c`, `r17`, `c01`, `c02` and its three sizes, `c03`, `c04a`, `c04b`, `c20`.
- **Gates:** spawn, despawn, exit and teleport payloads; one HUD on touch plus keyboard; input-state trace Classic against Pulse on touch (every `MobileDriveInputState` write identical); the Classic map opens by click, M and Select; Classic onboarding locks and callouts; the five activity views work untouched; kit API frozen after this family.

### 5.4 WorldMap (`world_map`)

Replaces `UI.FullMapUI` (856). Adds the world prompt owner and the event card. **The three `UIP.Map.*` modules are written by this agent and installed with FreeRoam** (the HUD minimap needs them); their ops are in `spec_ops_shared.json`.

- **Modules (10):** `Map.MapCanvas`, `Map.MapIcons`, `Map.MapRoute`; `WorldMap.FullMapModel`, `WorldMap.FullMapView`, `WorldMap.FullMapClient`; `World.WorldPromptModel`, `World.WorldPromptView`, `World.EventCardView`; `Dev.Fixtures.WorldMap`.
- **Shared map layers (signatures binding for FreeRoam too):**

```lua
type MapView = { Calibration: any, CentreX: number, CentreZ: number, VisibleStuds: number, RotationDegrees: number,
                 Size: Vector2, Round: boolean, FullMap: boolean }           -- real px; the owner fills one table in place each step
MapCanvas.Calibration(): any      -- MapMath.Calibration from Config.UI.DesktopFreeRoamHud Layout / Defaults (FullMapUI 96-107); cached
MapCanvas.New(content: Frame, props: {ZIndex: number?}, scope): {Canvas: Frame, Step: (view: MapView) -> (), Destroy: () -> ()}
MapIcons.New(content: Frame, overlay: Frame, props: {IconSize: number, FullMap: boolean}, scope):
  {Step: (view: MapView) -> (), HitTest: (point: Vector2) -> string?, SetVisible: (boolean) -> (), Destroy: () -> ()}
MapRoute.New(canvas: Frame, overlay: Frame, props: {Width: number}, scope):
  {Step: (view: MapView, routeState: any) -> (), SetVisible: (boolean) -> (), Destroy: () -> ()}
```

  `MapCanvas` holds a `MapTileSet` and culls it. `MapIcons` reads `MapMarkers.All()` and its `Changed` / `IconsChanged` signals, keeps a keyed pool, compares before every write, draws `Surface.MapIcon` (`Tint` from the marker's `Color` when present) and honours `Minimap`, `FullMap`, `EdgeClamp` and `Priority`. `MapRoute` takes the state of `RouteGuide.GetRouteState()`, rebuilds its segment pool only when `Version` changes, holds at most 64 segments clipped to the view in code, in Cyan. Every `Step` is `Perf.Bind`-safe. Neither requires `UI.MapIconLayer` nor calls `RouteGuide.newMapRenderer`.
- **Full map ScreenGuis:** `FullMap` 90 (`Frame = "Menu"`, `Scrim = true`) and `FullMapLive` 91. The order comes from `Layers.Order`, not `Config.UI.FullMap@DisplayOrder` (recorded difference).
- **Public API kept on the client module:** `Open(): boolean`, `Close()`, `Toggle(): boolean`, `IsOpen(): boolean`, `start()`.
- **Model to preserve:** pan and zoom state 178-241; subject 243-263; waypoint 265-293 (`setWaypoint`: `RouteGuide.Clear("Player")`, `RouteGuide.SetDestination("Waypoint", pos, {Label, Priority = 5})`, `MapMarkers.Set("Waypoint", {Position, Icon = "Waypoint", Label, Kind = "Waypoint", Priority = 50, EdgeClamp = true})`; reconcile on `RouteGuide.Changed` and `Arrived`); the tap rule 560-577; legend data 296-324; `blocked()` 449-461 with every attribute in it; open, close and toggle 480-543; pointer, pinch, keyboard and pad 545-733; presentation owners 750-761; the render step 771-846 with `RouteGuide.Update(position)` at 815 (the map is the one caller while open).
- **`minimapShowing` (464-478) is replaced** by `Routes.Resolve("DesktopFreeRoamHudUI").IsMinimapShowing()`; no PlayerGui walk.
- **Single-owner identifiers kept exactly:** player attribute `FullMapOpen` (written at 496, 520, 848; read by the HUD, activity and onboarding); context actions `"FullMapToggle"` (ButtonSelect, `High.Value`, permanent) and `"FullMapPad"` (`High.Value + 50`, bound while open) through `Input.BindAction`; `M` toggles and Escape closes; `GameplayInputGate.Acquire("FullMap", "V1")` and `Release`; marker and source id `"Waypoint"`; closes on `GuiService.MenuOpened`. No remote. Key hints stay (`Surface.KeyCap`) and follow `ctx.Input`.
- **Shared modules it may require:** `UI.RouteGuide`, `UI.MapMarkers`, `UI.MapMath`, `UI.MapTileSet`, `UI.FreeRoamMapPlayerMarkers` (given its container and config folder), `Vehicles.GameplayInputGate`.
- **World prompts (`WorldPromptView`, PC 7.2):** ScreenGui `PulseWorldPrompts` 80 (`Hud`); banners in slot `PromptStack` through `Overlay.PromptStack`. Families and their scoped roots **[src]**: `RaceEntryPrompt` under `World.RaceRoutes.<Route>.StartZones.<Zone>`; `EnterVehiclePrompt` under `World.Runtime.PlayerVehicles` (hidden when the vehicle's `OwnerUserId` is not the local player); `DriveOutPrompt`, `FootExitPrompt`, `ManageGaragePrompt` under `World.Interiors.OwnedGarageInstances` (the first and third hidden for a player with `OwnedGarageVisitor`); the static `OwnedGarageDriveInEntryPrompt` and `OwnedGarageFootEntryPrompt` under `World.OwnedGarageExteriors`; the client-made `CanonicalDealership` / `CanonicalCustomisation` / `CanonicalDriveIn`, `PassengerRidePrompt` and `JobPrompt`. Rules: set `Style = Custom` locally only after the banner host exists; re-apply on stream-in through `DescendantAdded` on those roots only; draw on `PromptShown`, remove on `PromptHidden`; **never** write `Enabled`, connect `Triggered` or call a remote for the action; on touch the banner calls `prompt:InputHoldBegin()` and `InputHoldEnd()`; any build error sets that prompt back to `Default` and leaves it alone; nothing shows while `Presence.Any()` is true for a kind other than `Race`.
- **Event card (`EventCardView`):** ScreenGui `PulseEventCard` 81; slot `RightColumn` while chat shows, else `TopLeftHud`. On `PromptShown` of a `RaceEntryPrompt` it reads the zone attributes `EventId`, `Mode`, `RouteId`, `PromptActionText` and, once per show and cached per event, `Remotes.Racing.RaceRequest:InvokeServer("GetEntryDetails", {EventId, Mode})` (reply `{Ok, Summary}`) and `("GetTimeTrialPersonalBest", {EventId, VehicleTier})`. Both are existing rate-limited reads (one token of 60 each). The card renders without them and fills in when they return. `ChequerCorner` sits on the card.
- **Target frames:** `r08`, `c16`, `r16a`, `r16b`, `c17`. Budget: route layer 64 instances; 0 churn on pan and zoom.
- **Gates:** the single-owner list ticked; prompts trigger the same server handlers by key, pad and touch; a forced banner error falls back to Default; Classic prompts untouched in Classic; the seated-in-start-zone and touch-hold checks that Phase 0 spike 11 left open.

### 5.5 RaceSession (`race_session`)

Replaces `Racing.RaceSessionPresentationClient` (324), `RaceCountdownPresentationClient` (68), `RaceQueueClient` (60) and `RaceTimeTrialResultCoachClient` (230); forks `RaceRouteGuideClient` (450); edits `RaceTransitionClient`. All remotes are under `ReplicatedStorage.Remotes.Racing`.

- **Modules (10):** `RaceSession.RaceHudModel`, `RaceSession.RaceHudView`, `RaceSession.RaceHudClient`, `RaceSession.CountdownClient`, `RaceSession.QueueClient`, `RaceSession.RouteGuideClient`, `RaceSession.ResultsModel`, `RaceSession.ResultsView`, `RaceSession.ResultsClient`, `Dev.Fixtures.RaceSession`.
- **ScreenGuis:** `SharedInRaceHUD` 155 and `SharedInRaceHUDLive` 156 (`Hud`); `RaceCountdown` 205; `RaceQueueBanner` 190; `RaceRouteGuide_Phase5` 78; `UnifiedRaceResults` 220 (`Menu`, `Scrim = true`). No other script reads these names. **Never** create a gui named in the kill list of `RaceLifecyclePresentationClient` 23-35 (`Kit.Contracts.Trap`).
- **Listens:** `RaceEvent.OnClientEvent` by `payload.Type` and `RaceQueueEvent.OnClientEvent`, with exactly the kinds each Classic owner handles (Session 303-316; Countdown 53-60; Queue 46-53; RouteGuide 418-430; Results 214-221).
- **Race HUD model:** `show` 269-271 (RunId, EventId, VehicleTier, CurrentLap, LapTarget, ParticipantCount); `TimeTrialLapCompleted` (LapTimes, Lap, Elapsed, NextLap, CurrentLap); `RacePositionUpdate` (Place, ParticipantCount, CurrentLap, LapTarget, `Positions[] {UserId, Place, Name}`); hide kinds 314-315; route-map marker maths 204-268. **Fix carried by the model (PC Phase 5 gate):** a `RacePositionUpdate` is ignored when no session is active or its `RunId` differs, so the HUD does not return after finish or exit. The timer is the client clock, as today; the delta chip is lap against best lap only; checkpoint pips use only fields already in the payloads.
- **HUD calls (copy exactly):** `RaceRequest:InvokeServer("GetTimeTrialPersonalBest", {EventId, VehicleTier})` on `TimeTrialStarted`. RESET and EXIT with payload `{RunId, EventId}`: in a race, `RaceQueueRequest` `"ResetToLastCheckpoint"` / `"ExitRaceToStart"`; in a time trial, `RaceRequest` `"ResetActiveTimeTrial"` / `"ExitActiveTimeTrial"`. Around them, `Racing.RaceTransitionRequest`: `FadeOut {Reason, Label = "RESETTING" | "EXITING"}`, 0.25 s, `RestoreCamera {Reason}`, `FadeIn {Reason, Delay, Success}` (189-196). The exit confirmation is `Overlay.Confirm`. Fire `UI.FreeRoamHudPresentationMode {Owner = "RaceSession", Active, KeepTelemetry}` in show and hide, with the `KeepTelemetry` value of Classic line 164.
- **Countdown:** token and schedule 30-60 (`GoAtServerTime`, `Countdown`, `Workspace:GetServerTimeNow()`). **`Runtime.Racing:SetAttribute("CountdownPresentationReady", true)` once, as the last statement of `start()`, after connecting** (RaceTransitionClient waits for it at 265 and degrades staging without it). Digits are `BigNumber` role `Countdown`.
- **Queue (single owner; carry 24-27 and 44-53 into the model verbatim):** connect `Racing.StartRaceQueueRequest` (`{EventId, VehicleId, DisplayName}`): set player attributes `LastRacingEventId` and `LastRacingVehicleId`, then `RaceQueueRequest:InvokeServer("JoinQueue", {EventId, VehicleId})`. LEAVE is `("LeaveQueue", {})`. On `RaceStarted`: hide, `RequestStreamAroundAsync` for `(RouteId, NextGateIndex)`, fire `UI.FreeRoamVehicleSpawned` now and after 0.25 s. Presentation owner `"RaceQueue"` with the `KeepTelemetry` value of Classic line 25, fired on change only.
- **Results model:** time-trial fields 125-147 and race fields 151-193 as the Classic source reads them; leaderboard `RaceRequest:InvokeServer("GetTimeTrialLeaderboard", {EventId, VehicleTier, Limit = 20})`; **the buttons exist before that call returns.** Actions (copy exactly): time trial EXIT = transition `BeginLoading {Destination = "RaceStart", Status = "RETURNING TO START"}`, `RaceRequest "ExitFinishedTimeTrial", {}`; on success fire `UI.FreeRoamVehicleExited`, hide, `CompleteLoading {Status = "READY"}`; on failure `FailLoading {Status = "RETURNING", Reason}`. TRY AGAIN = `RaceRequest "StartStagedTimeTrial", {EventId, VehicleId = SelectedVehicleId, LapCount = LapTarget}`. Race EXIT = the same steps with `RaceQueueRequest "ExitRaceToStart", {}` and no `FreeRoamVehicleExited`. RACE AGAIN = read `LastRacingEventId` and `LastRacingVehicleId`, hide, fire `StartRaceQueueRequest {EventId, VehicleId, DisplayName}`. Owner `"RaceResults"` with the `KeepTelemetry` value of Classic line 95. Hero numbers: cash is `RewardAmount` from the payload through `Data.Money`; driver XP is the change in player attributes `Rank` and `XpIntoRank` after the result, hidden if none arrives within 2 s. Rows are pooled (`Collections.List`). Every state comes from fixtures.
- **Route-guide fork (`RouteGuideClient`):** the 3D gate guide is world art and out of scope, so this is a **fork, not a rebuild** (a recorded change from the "new owner" list of PC 1.7). One replaced span: the wrong-way label builder 271-300, which becomes a kit label styled as a `PromptBanner` in `RaceRouteGuide_Phase5`, exposing the same local `wrongWay` with a writable `Visible`. The fork keeps its `ResponsiveUIFoundation` require for the three helpers the 3D billboard uses (`IsMobile`, `Corner`, `StrokeWidth`): a lint exception for this file only.
- **Edit to an existing script (reviewer):** `Racing.RaceTransitionClient`: four lines inserted between lines 71 and 72 (after the Michroma `pcall`, before `label.Parent = fade`). Every Classic statement stays and runs first:

```lua
pcall(function()
	local switch = require(game:GetService("ReplicatedFirst"):FindFirstChild("UIStyleSwitch"))
	if switch.Active("RaceSession") then require(game:GetService("ReplicatedStorage").Modules.Game.UIPulse.Kit.Text).StyleForeign(label, "Label") end
end)
```

  The label is built inside `Client.start()` **[src]**, so `Active` is read after `Compose` has committed or downgraded.
- **Target frames:** `r13a`, `r13b`, `r14`, `r15a`, `r15b`, `c08`, `c09`, `c10`. Budgets: HUD 140 with 0 per event; results 150.
- **Gates:** `CountdownPresentationReady` set; owner keys unchanged; the HUD does not return after finish or exit; every result state from fixtures; **no agent crosses a time-trial finish** (PB-01); the Quit path in Play.

### 5.6 RaceEntry (`race_entry`)

Replaces `Racing.RaceEntryPresentationClient` (901). Route: new owner.

- **Modules (6):** `RaceEntry.RaceEntryModel`, `RaceEntry.SetupView`, `RaceEntry.RecordsView`, `RaceEntry.VehicleView`, `RaceEntry.RaceEntryClient`, `Dev.Fixtures.RaceEntry`.
- **ScreenGui:** `RaceEntryPresentation` 180 (`Menu`, `Scrim = true`). Marks: the mode tabs `Text.TimeTrial` and `Text.Race` (the two buttons show exactly `TIME TRIAL` and `RACE`); on the Setup page the tier buttons `TierE` to `TierS` together with `LapSelector`, `PrizeSummary` and `MedalTargets`; `RaceFormat` on the race setup panel. The Records page must **not** carry `LapSelector` (it would be taken for TimeTrialSetup).
- **Model to preserve:** `tiers` 40; `call` 72-76; `timeText` 82-96 (money through `Data.Money`); `roundedRacePrize` 98-108, the prize preview rule `clamp(floor(base x mult / nearest + 0.5) x nearest, MinReward, MaxReward)` from `Config.Racing.Rewards.Race`, a projection of what the server pays, not to be changed; `readOwnedTiers` 211-225; `vehiclePresentationForId` 227-260; `racingVehicleRows` 262-291 (Race: all vehicles; time trial: `tier == selectedTier`; **Pulse always sorts by rating, highest first, with no Category or Sort drop-downs**, style sheet review 2); `pairedEventId`, `lapBounds`, `modeSummary` 293-341; page order and gates (TimeTrial: Setup, Records, Vehicles; Race: Setup, Vehicles; NEXT and CHOOSE gated on `ownedTiers[selectedTier]` with "OWN A X CLASS VEHICLE TO ENTER"); the open handler 880-892 (resets mode, page and lap).
- **Remotes (copy exactly):** `Remotes.Garage.GarageInvoke` `"GetInitial"` through `GarageCatalogClient.Fetch(remote, {})` on every open; `Remotes.Racing.RaceRequest` `"GetTimeTrialPersonalBest", {EventId, VehicleTier}` and `"GetTimeTrialLeaderboard", {EventId, VehicleTier, Limit = 20}`.
- **Bindables (`Racing.*`):** connect `RaceEntryPresentationRequest` (payload `Summary`, `EventId`, `RaceEventId`, `TimeTrialEventId`). After closing, fire `RaceEntryLegacyAction:Fire("Close")` on exit, or `:Fire("StartSelectedVehicle", {Mode, EventId = pairedEventId(mode), VehicleId, CockpitId, Tier, LapCount})` (679); the listeners `RaceEntryMenuClient` 63-85 and `RaceLifecyclePresentationClient` 242-250 do the spawn and queue. Fire `UI.FreeRoamHudPresentationMode {Owner = "RaceEntry", Active, KeepTelemetry = false}` on every device.
- **Required fixes (PC 5.1 rule 8):** fetch first, then draw; one render token per screen, so a late reply never draws into a newer page; footer buttons exist before any remote returns; `GetTimeTrialMedals` is protected; the personal best is fetched once per event and tier per open.
- **Shared modules it may require:** `Garage.GarageCatalogClient`, `Racing.RaceConfigReader` (`GetEventSummary`, `GetTimeTrialMedals`). Vehicle tiles are `Collections.Tile`, never `GarageComponents.VehicleCard`.
- **Target frames:** mockup `03-race-entry.jpg`, `r11`, `r12`, `c07`. Budget 220, 0 per click.
- **Gates:** `StartSelectedVehicle` payload identical; prize preview equals the Classic rule for every tier fixture; no stale page or duplicate footer under rapid clicks; Classic onboarding replay of pages 17 to 19.

### 5.7 Garage (`garage`) - one atomic family; the reviewer reads the whole family

Replaces `Garage.GarageUI` (702) with its views `UI.GarageBrowserUI`, `UI.GarageWorkspaceUI`, `UI.GarageComponents`; replaces `UI.OwnedGarageClient`, `UI.OwnedGarageBrowserUI` and the interior HUD part of `UI.GarageInteriorModeUI`; forks `UI.OwnedGarageWorkspaceUI`, `UI.GarageInteriorTransitionUI`, `Dealership.GarageEntranceClient` and the touch camera guard. May be built by two agents: **A** = dealership and customise (first seven modules), **B** = owned garage and forks.

- **Modules (17):** `Garage.GarageModel`, `Garage.GarageRoutes`, `Garage.GarageScreenView`, `Garage.PaintView`, `Garage.GarageModals`, `Garage.GarageClient`, `Dev.Fixtures.Garage` (A); `Garage.OwnedGarageClient`, `Garage.OwnedGarageBrowserModel`, `Garage.OwnedGarageBrowserUI`, `Garage.OwnedGarageWorkspaceUI` (fork), `Garage.OwnedGarageDeskView`, `Garage.GarageCompat`, `Garage.GarageInteriorHud`, `Garage.TouchCameraGuard` (fork), `Garage.GarageInteriorTransitionUI` (fork), `Garage.GarageEntranceClient` (fork) (B).
- **ScreenGuis and names:** `CanonicalGarageGui` 40 (`Scene`, `Scrim = true`, `RootName = "CanonicalCanvas"`) and `CanonicalGarageGuiLive` 41. Under the root: `CanonicalGarageBrowser` (dealership root; its title label carries mark `Text.Dealership`, text exactly `DEALERSHIP`, and no button may have that text); `CanonicalGarageWorkspace` (customise root; mark `Page.<id>`); `OwnedGarageCanonicalWorkspace` (the desk root: **this exact name**, or `GaragePreviewPresentationClient` 77-91 treats the desk as a dealership); `CanonicalGarageModal`. `OwnedGarageBrowser` 171 (marks `GarageList`, `Enter`). `OwnedGarageInteriorHUD` 58 with child `AccessControls`. `GarageEntranceStatus` is not created. Other marks: `Categories`, `Stats`, `Capacity`, `VehicleScroller`, `TutorialCardScroller`, `UpgradeBudget`, `Card` on every tile that is a tutorial card, `Card.<id>` on the tabs and desk cards.
- **Navigation (PC 8; Oscar accepts it in the gallery before `GarageModel` is finished):** `GarageRoutes` is data. Tabs Parts / Upgrades / Paint replace the hub; Shop / Owned replaces Owned Modules / Buy Modules. The tab bar carries `Page.CustomisationHome`; the three tabs carry `Card.AddModules`, `Card.UpgradeModules`, `Card.PaintShop`; the page body carries the current tab's `Page.<id>`.
- **Model to preserve (GarageUI):** `Adapter` 19-40 (`Adapter.Busy` is the only double-spend guard: one `GarageInvoke` in flight, busy reply "Please wait.", failure "Garage server did not respond."; **no purchase is ever retried**; reply fields `Success`, `Message`, `Catalog`, `Profile`, then `ProjectEconomy(result)`); the state fields of line 44; loading 46-52; selectors 55-74 (`coreReady`: Engine1 or Engine2, Stabilisers, Boost; else "Equip one engine, stabilisers, and boost before driving."); performance 75-87; preview and paint 99-124; camera 125-136 and 147-150; drive 179-189; the empty-slot detour 274-286 (triggered at 397 and 565; returns at 295, 358, 370); `clearTransientModulePreview` 100-102 on every tab change; where Back goes (362-375, 477, 660-669); entry 674-694; post-purchase paint 194 and 197-200; errors as an inline line and a toast. Card rows come from `GarageModuleCardViewModel.Owned(ctx)` and `.Shop(ctx)`, unchanged.
- **The remote table (copy the Classic call sites exactly).** `Remotes.Garage.GarageInvoke:InvokeServer(action, payload or {})`: `GetInitial` (through `GarageCatalogClient.Fetch`, with `KnownCatalogRevision`); `SetVehicleCosmeticColor {CosmeticId, Color, ReturnProfile = true}` (115, 116); `SetCockpitColor {Channel, Color, Scope, ReturnProfile = true}` (117, 120, 121); `SetAllNeonColor {Color, ReturnProfile = true}` (119); `SetModuleColor {SlotId, Channel, Color, ReturnProfile = true}` (122); `BuyGarageProperty {PropertyId}` (174); `SpawnVehicle {}` (185); `SelectVehicleInstance {VehicleId, CockpitId}` (194) and `{VehicleId}` (691); `BuyCockpitInstance {CockpitId, CategoryId}` (194); `EquipModuleInstance {ModuleInstanceId, VehicleId, SlotId, AllowReassign}` (288); `BuyModuleInstance {ModuleId, VehicleId, SlotId}` (358); `UpgradeModule {SlotId, ModuleId, UpgradeId}` (437); `BuyVehicleCosmetic {CosmeticId}` (558); `BuyNeon {SlotId}` (604); `EnsureCustomisationAccess {}` (678); `DespawnVehicle {}` (691). `Remotes.UI.GarageSessionRequest`: `End {ReturnToEntry = true}` (183, 195, 684, 689); from the entrance fork, `Begin {Mode}` (178) and `End {ReturnToEntry = true}` (196). The audio map of line 18 and its overrides 29-30 are kept (`PresentationAudioBridge`).
- **Owned garage remotes (`Remotes.Garage.OwnedGarageInvoke`).** Browser: `GetVisitableGarages {}`, `LeaveVisit {}`, `VisitGarage {OwnerUserId}`, `EnterSelectedGarage {PropertyId}` and `{PropertyId, ReplacementSlotId}`, `GetState {}`, `ExitOnFoot {}`; `OwnedGarageEvent:FireServer({Type = "OwnedGarageStreamReady", Token, Success, Message})` (138) and the `OnClientEvent` kinds of 135-144 (a second browser controller would acknowledge stream tokens twice). Interior HUD: `GetManagementState {}` (27), `SetAccessMode {AccessMode}` (38), `SetInvitation {Action, TargetUserId}` (42), each mutation with `BaseRevision` and `RequestId` (31). The desk's 37 call sites live in the **fork** and are unchanged by construction.
- **Bindables:** connect (and create if missing, 151) `Dealership.OpenGarageFromIntro`, `OpenOwnedCockpitCustomisation`, `OpenDrivingVehicleCustomisation` (payload `{LoadingGeneration, LoadingDestination}`); fire `Dealership.GarageClosedFromDealershipExit`, `UI.FreeRoamVehicleSpawned`, `UI.FreeRoamVehicleExited`, `UI.ShowTopNotification`; invoke `UI.LoadingTransitionInvoke` `Begin` / `Complete` / `Fail` with the Classic destinations and status texts (51, 181-195, 675, 689, 693). Browser: connect `UI.OpenOwnedGarageBrowser`; fire `UI.FreeRoamHudPresentationMode {Owner = "OwnedGarageBrowser", Active, KeepTelemetry = false}`.
- **Attributes:** player `GarageEntryMode` cleared at the Classic points (GarageUI) and set, cleared and listened to by the entrance fork; preview root `PreviewVFXMode`; `PlayerGui@OwnedGarageManagementOpen` (single writer: the desk fork, 35); `PlayerGui@OwnedGarageInteriorMode` (interior HUD); `Runtime.UI@OwnedGarageClientStarted = true`, set by `OwnedGarageClient` after every part's `Start()` returned ok (order table at Classic line 8). `GarageSessionActive` is server-written and stays the only garage-open signal; `Presence.Open("Garage", "Garage")` mirrors it for Pulse.
- **Preview and camera (shared, never forked):** `PreviewVehicleClient.Build` guarded by `GarageModuleInstancePreviewAdapter.ProfileFingerprint` (104-107) and `.ApplyPaint` (112); `PreviewCameraClient.BindInput` (one controller only), `.Update`, `.Release`, `.SetCameraSection`, `.Reset`; `GarageVehiclePreviewProfile.ForBrowser`. **The 3D preview is rebuilt only when its input fingerprint changes** (PC 5.1 rule 9; Classic rebuilds on every `renderUpgrade` and `renderPaintShop`). Full-screen tints are `Active = false` and panels `Active = true`, or orbit breaks.
- **Cash:** dealership tile affordability is `leaderstats.Cash` against the catalogue price (as the Classic browser view does through `BindReplicatedCash`); cosmetic and neon affordability is `State.Profile.Cash` from the last reply (556, 579); module shop tiles carry **no** client affordability (the server decides). Spaces come from `Data.ProjectEconomy(result)`. Nothing else.
- **Forks (the build tool copies the Classic source; the diff must equal the listed spans):**

| Fork | Classic source | Replaced spans | Supplied by |
|---|---|---|---|
| `Garage.OwnedGarageWorkspaceUI` | `UI.OwnedGarageWorkspaceUI` | line 12: the three requires `WorkspaceUI`, `Shared`, `UI` only | `OwnedGarageDeskView` (`new()`; `.Root` with `Name`, `Visible`, `Active`; `.TouchMapEnabled`; `:Show`, `:RefreshCards`, `:Message`, `:Hide`, `:IsTouchBlocked`) and `GarageCompat` (`ProjectEconomy` = `Data.ProjectEconomy`; `ConfirmationModal(root, opts)` returning an object with `:Destroy`, over `Overlay.Confirm`; `Asset(name)`) |
| `Garage.TouchCameraGuard` | `UI.GarageInteriorModeUI` 48-270 | line 52: the require becomes `Garage.OwnedGarageWorkspaceUI`; plus a header that re-declares the outer locals the range reads (`settings`, `number` 5-6, `player`, `playerGui`, services) | - |
| `Garage.GarageInteriorTransitionUI` | `UI.GarageInteriorTransitionUI` | line 6: the two require targets (`Garage.OwnedGarageBrowserUI`, `Garage.OwnedGarageWorkspaceUI`; both keep `Close(reason)`) | - |
| `Garage.GarageEntranceClient` | `Dealership.GarageEntranceClient` | 65-91 (old gui destroy, ScreenGui, label) and `flash` 93-106, which becomes `ShowTopNotification:Fire(text)` | - |

- **`Garage.GarageInteriorHud`:** new owner for the rest of `GarageInteriorModeUI` (build 11-17, state 19-28, mutate 30-34, visibility and wiring 271-278); it starts `TouchCameraGuard`. **`Garage.OwnedGarageBrowserUI`** keeps the public API `Start`, `Close(reason)`, `IsOpen()`; model lines 47-59, 86-93, 107-144.
- **Target frames:** `r01`, `r02`, `r03`, `r04a`, `r04b`, `r05`, `r06`, `r07`, `r21`, mockups 04 to 06, `c11`, `c12` and its sizes, `c13`, `c14`, `c15`. Budget 240 live per page, 0 created or destroyed on a selection.
- **Gates:** fork checks pass; `contract.json` equals the remote table; sandbox purchase matrix with **end-state comparison Classic against Pulse** (same purchase sequence, equal profile fingerprint); affordability as stated; orbit under scrims; Classic onboarding replay of pages 1 to 5 and 9 to 14; desk tests within the sandbox's no-save extent; Oscar confirms one real purchase.

### 5.8 Shell (`shell`)

Replaces `UI.OnboardingClient` (765); adds a Pulse loading view and a start-screen fork in ReplicatedFirst; edits two ReplicatedFirst scripts.

- **Modules (6):** `Shell.OnboardingModel`, `Shell.OnboardingView`, `Shell.OnboardingClient`, `Dev.Fixtures.Shell`, and (outside `UIP`, as PC 1.6 names them) `ReplicatedFirst.Loading.LoadingScreenViewPulse` and `ReplicatedFirst.Loading.StartScreenPulse`.
- **Onboarding ScreenGui:** `Onboarding` 990 (`Bare`, `Scrim = true` for the shade).
- **Onboarding model to preserve:** state 26-30; pages, cards, `actionSteps = {N6, X3}` and placement 37-80; `pageOrder` 223 and page signals 202-222 (**19 page ids plus `PCDriving`, saved and server allow-listed: never renamed**); gates 329-341; `beginPage`, `markSeen`, `advance` 432-451; objective rules 479-504; first drive 672-699 (fires `UI.OpenDrivingControlsFromOnboarding {FirstDrive = true}`, writes `FirstDrivePresentationPending`); locks 666-671 (`Car`, `Race`, `Garage`: `Active`, `Selectable`, `AutoButtonColor`); `accept` 720-727; loading gate 728-744; the `GetState` retry 747-755.
- **Remotes (`Remotes.Onboarding`, copy exactly):** `OnboardingInvoke:InvokeServer("GetState", {})`; `("MarkSeen", {PageId = pageId})`; listen `OnboardingStateChanged`. Audio `PresentationAudioBridge.Emit("Objective.Complete", {Key, ObjectiveIndex})`.
- **Rebuilt (PC Phase 8):** targets resolve through `Input.Marked(key)` and `Presence`, plus the attributes and bindables Classic already listens to. **No timer walks PlayerGui or Workspace**: the 0.2 s tick at 757 and the Workspace walk at 649 are not carried; the desk anchor comes from a scoped listener on `World.Interiors.OwnedGarageInstances`. Scale is the kit's. Callouts advance by pad and keyboard. The highlight is White and Pink. Guide trail: `OnboardingGuideTrailRenderer.new(overlay)`, where `overlay:GetAttribute(name)` returns the Pulse value for `TutorialGold` and falls through to `Config.Player.Onboarding` for everything else (Phase 0 spike 15); the renderer is shared and unchanged.
- **Loading view (`LoadingScreenViewPulse`):** the public API of `LoadingScreenView` **[src]**: `View.Create(playerGui, config, colours)`, `:Warm(entries, limit)`, `:SetArtwork(entry)`, `:Show(statusText)`, `:SetProgressImmediate(value)`, `:StartMotion(enabled)`, `:SetStatus(text)`, `:SetProgress(value, duration)`, `:FadeOut(duration)` (yields until the fade ends), `:Hide()`, `:Destroy()`. ScreenGuis through `Layers.Create("LoadingSafeContent", {Frame = "Bare", Scrim = true, RootName = "SafeRoot"})`; artwork and the input blocker live in `LoadingSafeContentScrim`. Under `SafeRoot`: `Status` (TextLabel) and `ProgressTrack` > `ProgressFill` (a Frame whose X scale is the progress; the start screen clones it). Artwork handling (catalogue entry fields, grid tiles, motion) is carried from the Classic view unchanged; only type, bar and status are Pulse. It may wait for `UIP.Kit` with `WaitForChild` at require (the Classic start screen already waits for `Modules.Game.UI` at its line 22). It shows with the root `Visible` and starts `Text.Preload()`.
- **Start screen (`StartScreenPulse`, a ModuleScript returning `{Run = function() ... end}`):** fork of `InitialLoadingAndStartScreenClient` lines 20-328. Kept exactly: 20-21; 23-111, including the temporary `TimeoutSeconds` and artwork `Enabled` writes and their restore (26-46); `release` 293-304; the Play and Shop handlers 306-326 (`Remotes.UI.FreeRoamHudTeleportInvoke:InvokeServer("TeleportToDealership")`, `FreeRoamVehicleExited`); every `StartScreenActive` write (52, 82, 297). Replaced spans: line 22 (the `RacingUIComponents` require; the kit is resolved here, and `Run` returns false without it); the status literal at 38 (`"LOADING PULSE RACERS"`); the menu builder 113-229 and `updateLayout` 231-280 (kit buttons in a `Layers.Stage` on `SafeRoot`; no portrait branch; Play focused for pad and keyboard); `setBusy` 282-291.
- **Edits to existing scripts (reviewer), exact.** `ReplicatedFirst.Loading.LoadingTransitionRuntime`: line 8 becomes two lines:

```lua
local okPulse, pulseView = pcall(function() local module = require(game:GetService("ReplicatedFirst"):FindFirstChild("UIStyleSwitch")).Active("Shell") and packageFolder:FindFirstChild("LoadingScreenViewPulse"); return module and require(module) or nil end)
local View = (okPulse and type(pulseView) == "table" and pulseView) or require(game:GetService("ReplicatedFirst"):WaitForChild("Loading"):WaitForChild("LoadingScreenView"))
```

  `ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient`: two lines inserted after line 18:

```lua
local okPulse, pulseStart = pcall(function() local module = require(ReplicatedFirst:FindFirstChild("UIStyleSwitch")).Active("Shell") and packageFolder:FindFirstChild("StartScreenPulse"); return module and require(module) or nil end)
if okPulse and type(pulseStart) == "table" and type(pulseStart.Run) == "function" and pulseStart.Run() == true then return end
```

  Both read the latch, find the Pulse module with `FindFirstChild` (never an unbounded wait) and require it, all inside one `pcall`. A missing or broken latch, a missing Pulse module, or one that errors on require gives Classic in both: the runtime then runs the Classic require of line 8 as written (`packageFolder` is its line 6), and the start script falls through to the Classic flow below. With style Classic each script runs the statements it runs today plus the one protected latch require. `StartScreenPulse.Run()` returns **false** only when it stopped before `Begin` (kit not available within one 5 s budget, a kit module that errors on require, or any error ahead of `Begin`); from `Begin` onwards it returns **true** (begin refused, safe content missing, menu released, menu shown) or raises, and the caller returns only on `true`, so exactly one flow calls `Begin` and writes `StartScreenActive`. The menu build after `Begin` is protected: when it fails, `Run` calls the kept `release(true, ...)`, the path Play takes, and the player enters the game. The downgrade residual of PC 1.3 is **accepted** for this wave (a reported failed state; AUDIT runs `Compose` against the recorded entry table).
- **Target frames:** `r18`, `r19a`, `r19b`, `c18`, `c19a`, `c19b`.
- **Gates:** cold starts in both styles (Classic full Play record identical); start reachable by pad and keyboard; every page begins and completes once on a fresh sandbox profile (`StudioReplayEveryPlay` window) on PC, a phone preset and a controller; exactly one start-screen flow calls `Begin`; reviewer; Oscar confirms.

## 6. Conventions for family agents

### 6.1 Files (one folder per agent; never touch another folder, `phase1/`, Studio or git)

```text
scripts/ui_restyle/phase2/kit/          K1 to K4, one sub-folder each (k1/ .. k4/): after/ tests/ NOTES.md; k1 also holds gen_sprites.py, gen_contracts.py
scripts/ui_restyle/phase2/families/<folder>/
  CONTRACT.md       the family's acceptance contract: owners before and after, must-preserve, tests (one page)
  after/<full instance path>.lua     one per ModuleScript, named as in classic/sources/
                                     (e.g. ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuModel.lua)
  before/<full instance path>.lua    ONLY for an edited existing script: a byte copy of classic/sources/; its after/ file is the edit
  forks/<Pulse module name>.json     {"source": "<classic instance path>", "replace": [{"lines": [from, to], "with": "<file in forks/>"}]}
  tests/<full instance path>_test.lua   pure tests (6.4)
  contract.json     parity declaration (6.5)
  routes.json       {"family": "RaceMenu", "swap": {"RaceBrowserClient": "ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuClient"}, "add": []}
  spec_ops.json     ops in the engine's format (../engine/README.md): create ops for Folders, then ModuleScripts ("path" arrays,
                    "after" relative to the family folder); source ops with "before" and "after" for edited scripts
  NOTES.md          every API question and the reading used; what the integrator must check in Play
```

The integrator owns the per-family `spec.json`, `Routes`, the fork build, lint, installs and Play. A fork's `after/` file is produced by the integrator's fork tool from `forks/*.json`; the agent supplies the replacement spans and may add a hand-assembled `after/` for review.

### 6.2 Model, view, client

- **Model** (`<X>Model`): headless. State, reducers, remote calls, bindable fires, attribute writes. It creates **no GuiObject** and requires no Kit module except `Kit.Presence` and `Kit.Data`. Constructor `Model.new(deps)`, where `deps` carries every service handle, remote, bindable and shared module the model uses (`{Remotes = {...}, Bindables = {...}, Player = ..., Clock = os.clock, Spawn = task.spawn, ...}`), so pure tests pass fakes. It exposes state through plain getters and one Luau signal `Changed(reason)`. Every remote call goes through one `call(remote, action, payload)` function whose call sites match `contract.json`.
- **View** (`<X>View`): `View.Mount(layer: Layer, model, scope): {Render: (reason: string?) -> (), Destroy: () -> ()}`. Kit components only, in slots only; no remote, attribute write or bindable. It builds once; `Render` then patches components through `Set` (0 churn). Compact and Regular are branches of the view's one layout function on `layer.Metrics.Class`, rebuilt only when the class changes. Modals and secondary pages are built on first use.
- **Client** (`<X>Client`): the entry, in exactly the API1 section 10 owner shape. Order in `start()`: `Layers.Switch().Claim("<surface>")`; resolve remotes and bindables (waits allowed only where the Classic owner waits, and never on a font, asset or remote reply); `Layers.Create(...)`; `Model.new`; `View.Mount`; connect; `layer.SetVisible(false)` for menus. Claim names: `RaceBrowser`, `FreeRoamHud`, `TouchControls`, `ActivityHud`, `CoreUi`, `FullMap`, `WorldPrompts`, `RaceHud`, `RaceCountdown`, `RaceQueue`, `RaceRouteGuide`, `RaceResults`, `RaceEntry`, `Garage`, `OwnedGarage`, `GarageEntrance`, `Onboarding`, `Loading`, `StartScreen`.
- A view gets its ScreenGui **only** from the `Layer` its client created and its positions only from `layer.Slot(name)`. Show and hide is `layer.SetVisible`. Never `Enabled`.
- Onboarding targets: `MarkKey` props or `Input.Mark(instance, key)` with the keys of `Kit.Contracts.Marks`. A view never types a tutorial name or attribute.
- Small owners (countdown, queue, core UI policy) may be one module if their decision logic is exported as pure `_functions` for tests.

### 6.3 Gallery fixtures

`Dev.Fixtures.<Family>` returns `GalleryItem`s (API1 section 10): one item per screen and per modal. `Mount` builds the view over a **fake model** (same getters, canned state, `Changed` fired by the state switch): never the real model, a remote or a player attribute. States must include empty, loading, the longest strings, locked, unaffordable, the error line, and each Compact page. Items state their `Frame` and use the real slots, so `R720`, `R1080`, `R1440`, `C844` and `C568` all exercise the layout.

### 6.4 Pure tests

Format and limits of API1 section 13 (one file per module, `return function(M, env)`, no yield, nothing parented into the game tree, `Metrics.Fixed` contexts, `env.Scope()`). Required per family: every model reducer and rule named in its row (rows, sort, gates, prize rule, page order, payload builders) against fixtures; each remote call asserted as `(remote, action, payload keys)` through the fake `deps`; each view mounted on a detached `Layers.Stage` at R1080 and C844 over the fake model: no error, within budget, `Render` twice with unchanged state changes no property, a selection change creates and destroys nothing.

### 6.5 Parity declaration (`contract.json`): a list with one object per Pulse owner

```json
{ "owner": "ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuClient", "replaces": ["RaceBrowserClient"],
  "screenGuis": [{"name": "RaceBrowser", "displayOrder": 170}],
  "remotes": [{"remote": "Remotes.Racing.RaceBrowserTeleportInvoke", "kind": "invoke", "action": "TeleportToRaceStart", "keys": ["EventId", "Mode"]}],
  "listens": [],
  "bindables": [{"name": "Runtime.UI.OpenRaceBrowser", "dir": "connect"},
                {"name": "Runtime.Racing.RaceTransitionRequest", "dir": "fire", "keys": ["Step", "Reason", "Label", "Delay"]}],
  "attributes": [], "names": ["CardContent", "TeleportToStart"], "contextActions": [], "renderSteps": [], "audio": [],
  "dropped": [{"item": "Enabled writes on other ScreenGuis (406-410)", "reason": "API2 5.2"}],
  "added": [{"item": "Escape and ButtonB close", "reason": "API2 5.2"}] }
```

`attributes` entries are `{"on": "Player" | "PlayerGui" | "<path>", "name": ..., "dir": "read" | "write"}`. The integrator compares the file with `classic/contracts/<Owner>.json` and with the Pulse source (a scan for `InvokeServer`, `FireServer`, `:Fire(`, `:Invoke(`, `SetAttribute`). Every difference must appear in `dropped` or `added` **with a reference to a section of this file**; anything else fails the family.

### 6.6 Coding rules

API1 section 11 applies in full, with line 2 of each source reading `-- Pulse UI (phase2). <full instance path>. Requires: <names or none>.` and these changes:

1. Rule 3 exceptions, exhaustive: `Kit.Data` may require `ResponsiveUIFoundation` (3.5); the `RaceSession.RouteGuideClient` fork keeps its Classic require (5.5); a family may require the **shared, look-free** modules its row lists (`GarageCatalogClient`, `GarageModuleCardViewModel`, `RaceConfigReader`, `RouteGuide`, `MapMarkers`, `MapMath`, `MapTileSet`, `FreeRoamMapPlayerMarkers`, `GameplayInputGate`, `MobileDriveInputState`, `PresentationAudioBridge`, the preview and camera modules, `OnboardingGuideTrailRenderer`, `Core.*`). Nothing else Classic, and never `GarageComponents`, `RacingUIComponents`, `UITheme`, `MapIconLayer` or a Classic owner.
2. Rule 5 exceptions, exhaustive: `CanvasGroup` and `UICorner` in `Kit.Minimap`; the design-pixel `UIScale` in `FreeRoam.ActivityHudClient`; whatever the shared `FreeRoamMapPlayerMarkers` creates inside its container.
3. Rule 6: `Kit.Sprites` is exempt (generated data). A family source holds no `Color3`, `Font`, asset id or pixel literal; a missing size is a token request to the integrator, not a local constant.
4. A forked file is exempt from rules 5, 6 and 9 **inside its kept ranges only**.
5. One `Perf.Bind` per live layer. No `task.wait` loop that polls for presence; timers only for time (countdowns, toasts, debounce).
6. Every remote reply is an untrusted shape: check `type(reply) == "table"` before reading a field; a failed or late reply never leaves a page without its footer buttons.
7. Fetch first, then draw; one render token per screen (PC 5.1 rule 8).
8. Player-facing strings are copied from the Classic source unless this file or a preview changes them; a changed string is listed in `added`.

### 6.7 Hard safety rules (a violation fails the family, whatever the diff size)

- No new remote, remote action, payload key, bindable, saved field, economy value, config value or server edit. No `Instance.new` of a `RemoteEvent` or `RemoteFunction` anywhere.
- Cash is never computed client-side beyond the existing projection (`Data.ProjectEconomy`, the presenter's count-up). No optimistic Cash and no client price arithmetic, except the race-entry prize preview rule carried from Classic (5.6).
- Purchase, equip, upgrade, paint-save, spawn, despawn, teleport, queue and start calls copy the Classic call sites exactly: same remote, same action string, same payload keys, same busy guard; never retried; never sent from a view.
- One owner per surface: `Claim` first; never start, require or name a Classic owner; never add a second listener to a bindable whose handler sends a remote (`StartRaceQueueRequest`, `RaceEntryLegacyAction`, `OpenOwnedGarageBrowser`, the garage `Open*` events).
- Saved ids never change: onboarding page ids and vehicle, module, slot, property and event ids are passed through untouched.
- Nothing in this wave is tested by crossing a time-trial finish, and no Play test runs outside the sandbox window.
