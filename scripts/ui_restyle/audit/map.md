# UI restyle audit - group "map"

Read-only audit, 2026-10-08. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.
All seven scripts exist at the listed paths and were read completely. Line numbers are live-source line numbers.

| Script | Lines | Class | Colour literals | Instance.new sites | Frame hooks |
|---|---:|---|---:|---:|---|
| `ReplicatedStorage.Modules.Game.UI.FullMapUI` | 857 | ModuleScript | 13 fromRGB + 1 Color3.new | 1 (helper `new`) | BindToRenderStep while open |
| `...UI.MapIconLayer` | 336 | ModuleScript | 10 fromRGB + 1 Color3.new | 6 | none (stepped by host) |
| `...UI.MapMarkers` | 131 | ModuleScript | 0 | 0 | none |
| `...UI.MapMath` | 252 | ModuleScript | 0 | 0 | none (pure) |
| `...UI.MapTileSet` | 88 | ModuleScript | 0 | 1 | none (culled by host) |
| `...UI.RouteGuide` | 412 | ModuleScript | 3 fromRGB + 1 Color3.new | 12 | none (stepped by host) |
| `...UI.FreeRoamMapPlayerMarkers` | 458 | ModuleScript | 2 fromRGB | 4 | none (stepped by host) |

Context read to answer the minimap questions (not in my group, partial reads only):
`DesktopFreeRoamHudUI` 126-156, 366-392, 886-985, 1038-1066, 1100-1280, 1340-1377;
`MobileFreeRoamHudUI` 76-106, 340-366, 396-503; `RacingUIComponents` 1-155; `RoadRouting.Smooth` 244-306; `JobClient` 94-112.

Repo mirrors and contract: `scripts/map_ui/*` (installers, `tests.lua` for MapMath), `docs/architecture/map-markers-contract.md`.

---

## 0. How the pieces fit

```
MapMarkers (registry, singleton)  <- JobClient (job offers / trip markers), FullMapUI ("Waypoint"), Config.UI.MapPois
RouteGuide (route state, singleton) <- FullMapUI ("Waypoint"), RaceBrowserClient ("Player"), JobClient, DuelClientView
MapMath (pure maths)

Three render surfaces, each built by a host that owns the frame loop:
  Desktop minimap  = DesktopFreeRoamHudUI  (CanvasGroup "Minimap", bottom-left, 245 design px)
  Mobile minimap   = MobileFreeRoamHudUI   (CanvasGroup "Minimap", top-right, 128-180 px)
  Full map         = FullMapUI             (plain Frame "MapView", near full screen)

Each surface instantiates the same four renderers:
  MapTileSet.new{Canvas}            tiles
  RouteGuide.newMapRenderer{...}    route line, destination blip, edge pip, distance chip
  FreeRoamMapPlayerMarkers.new{...} other players
  MapIconLayer.new{...}             upright icons from MapMarkers
```

There is **no in-race minimap today**. Desktop hides `leftCluster` while a racing presentation owner is active (Desktop 1135) and skips the whole map step when `Racing...PauseFreeRoamMapDuringRace` is true (Desktop 1142). FullMapUI refuses to open during a race (FullMapUI 449-461). The style sheet's "minimap and gauge as in free roam" for the in-race HUD is therefore new behaviour with new per-frame cost, not a restyle.

---

## 1. FullMapUI

### 1.1 Purpose and lifecycle
- GTA-style full-screen map. Header comment 1-6.
- Started once by ClientBase entry `FullMapUI` (ClientBase line 72; entry order: ... DesktopFreeRoamHudUI, FreeRoamVehicleExitButtonClient, LoadingTransitionUI, MobileFreeRoamHudUI, **FullMapUI**, OnboardingClient ...). `FullMap.start()` 25-854 guards on `startState` (26-27); a second start asserts.
- Everything lives in one closure inside `start()`. No `stop`, no `Destroy`. All connections are permanent for the session:
  - `RouteGuide.Changed` 278, `RouteGuide.Arrived` 288
  - `MapMarkers.Changed` 353, `Players.PlayerAdded/PlayerRemoving` 356-357
  - `UserInputService.InputChanged` 639, `InputEnded` 654, `InputBegan` 668, `LastInputTypeChanged` 732
  - `GuiService.MenuOpened` 693
  - `ContextActionService:BindActionAtPriority("FullMapToggle", ..., High, ButtonSelect)` 718-723 (permanent)
  - `FreeRoamHudPresentationMode.Event` 751-761
  - camera `ViewportSize` 763-767 (a new connection per camera change, old one never disconnected)
  - six button `Activated` handlers 736-748
- Bound only while open: `RunService:BindToRenderStep("FullMapUI", Last+10, renderStep)` 533 / unbind 486; `ContextActionService "FullMapPad"` 530-532 / 487; `FreeRoamMapPlayerMarkers` instance created 522-524 and destroyed 491.
- Old instance cleanup: destroys any existing `PlayerGui.FullMap` at start (110-111).

### 1.2 Instance tree
```
PlayerGui.FullMap  ScreenGui  IgnoreGuiInset=true  ResetOnSpawn=false  Enabled=false
                   DisplayOrder = Config.UI.FullMap@DisplayOrder (90)  ZIndexBehavior=Sibling      (112-113)
  Backdrop   TextButton, full screen, black, transparency tweened 1 <-> 0.35, no handler          (114-115)
  Panel      UI.Panel (Frame + UICorner + Stroke + GlowStroke), centred, Active                    (116-120)
    OpenScale  UIScale (open/close tween 0.96 <-> 1 only)                                          (121)
    Title "MAP", District                                                                          (123-124)
    LegendToggle "LEGEND", Close "X"   UI.Button                                                   (125-126)
    MapView    Frame, ClipsDescendants=true, UICorner 6, Active                                    (128-130)
      MapCanvas  Frame (resized/moved every frame)                                                 (131)
        16 x MapTileR<r>C<c> ImageLabel (MapTileSet)                                               (133)
        RouteGuide  Frame (segments, DestinationBlip)                                              (137)
      MapMissing label                                                                             (134-136)
      RouteEdgePip, RouteChip (RouteGuide container items)                                         (137-140)
      PlayersHost  Frame, square of side max(W,H), centred -> OtherPlayerMarkers while open        (141-142, 523)
      MapIcons     Frame (MapIconLayer overlay; pooled Icon_<id>)                                  (143)
      PlayerArrow  ImageLabel (or "▲" TextLabel fallback)                                          (144-153)
      Crosshair    Frame + UICorner 999 + UIStroke (gamepad only)                                  (154-157)
      Controls     Frame -> ZoomIn "+", ZoomOut "-", Centre "ME", ShowAll "ALL"                    (158-162)
      Hint         TextLabel with 0.25-transparent background                                      (163-167)
    Legend     UI.Panel (NoGlow)                                                                   (169-170)
      Title "MAP KEY", List ScrollingFrame + UIListLayout, ClearWaypoint button                    (171-176)
        Key_<Icon> rows: Frame + MapIcon (5 instances) + Label = 7 instances per row               (343-350)
```
Instance estimate at rest: about 150-200 (16 tiles, 6 buttons at ~6 instances each, 5 instances per map icon, 7 per legend row), plus 4 instances per route segment (see RouteGuide), plus 3 per other player while open.

### 1.3 Scaling and layout
- **No reference-canvas UIScale.** One scalar `s` computed in `layout()` (374):
  - desktop: `clamp(min(vp.X/1920, vp.Y/1080), 0.72, 1.12)`
  - mobile: `clamp(vp.Y/720, 0.55, 1)`
- Every size is an offset: `px(v) = floor(v*s + 0.5)` (375); `target(v)` = `max(44, px(v))` on mobile (376).
- Panel fills the viewport minus `margin` on all sides: desktop `px(36)`, mobile `max(8, px(16))` (377-381). Centred with AnchorPoint 0.5 (117-118).
- Header band `target(56)`; title 90 wide at `px(24)`; district at `px(13)`; buttons `target(40)` high (380-395).
- Legend width: `clamp(target(LegendWidth 260 | MobileLegendWidth 220), 150, 34% of panel)` (397). Map view takes the rest (399-404).
- Legend auto-closed on mobile when viewport.X < `MobileLegendMinViewport` 760 (515).
- Text: explicit `TextSize = px(n)` everywhere (384-430). No TextScaled, no minimum.
- Map zoom is "studs visible across the view's shorter side" (`visibleStuds`); canvas side = `FullStuds * Short / visibleStuds` (205-207, MapMath 106-108). Zoom limits 208-214; pan clamp to world bounds 215-220.
- Viewport change: `ViewportSize` signal -> `layout()` when open (763-765). `layout()` always sets `legendDirty = true; legendSignature = nil` (443-444) so the legend is destroyed and rebuilt.
- **Safe area: none.** `IgnoreGuiInset = true` and only the fixed margin. No `GuiService:GetGuiInset`, no `ScreenInsets`, no notch handling.
- Map icons do not follow `s`: `MapIconLayer.new` is called without `IconSize` (143) and `layout()` never calls `iconLayer:SetIconSize`. Icons are 48 px (56 touch) at every resolution.
- Route line width does not follow `s`: `RouteLineScale` 2 x `LineWidth` 5 = 10 px always (819).

### 1.4 Config read
- `Config.UI.FullMap` attributes (29 present; folder optional, `WaitForChild(..., 10)` at 47, every value has a default): `Enabled, DisplayOrder, BackdropTransparency, BoundsMarginStuds, PanMinX/MaxX/MinZ/MaxZ, OpenVisibleStuds, MinVisibleStuds, MaxVisibleStuds, ZoomStep, RememberZoom, LegendOpen, LegendWidth, MobileLegendWidth, MobileLegendMinViewport, DistrictName (empty), OpenTweenSeconds, CloseTweenSeconds, LockGameplayInput, TapRadiusPixels (26), TouchTapRadiusPixels (34), DragThresholdPixels, WaypointY, KeyboardPanSpeed, GamepadPanSpeed, CentreResponse, RouteLineScale`.
- `Config.UI.DesktopFreeRoamHud.Layout`: `MapPixels, MapCalibrationPixels, MapCalibrationStuds, MapWorldCenterX, MapWorldCenterZ, MapCoordinateRotationDegrees` (96-107), `MapRotationOffsetDegrees` (814, read every frame).
- `Config.UI.DesktopFreeRoamHud.Defaults`: `MapFlipX, MapFlipZ`.
- `Config.UI.DesktopFreeRoamHud.Assets`: `MapPlayerIcon` (144, 305).
- `Config.UI.FreeRoamMapPlayerMarkers` folder, passed to the player-marker module (46, 523).
- `Config.UI.Racing.Colours` through `RacingUIComponents.Colour` (53-61): Panel, PanelDeep, PanelSoft, PanelBlue, Outline, OutlineSoft, Telemetry, ElectricBlue, HighSpeed, Danger, Text, Muted, Disabled. **`HighSpeed` does not exist in Racing.Colours**, so that token always resolves to the literal 246,83,159.
- `Config.UI.Racing.Typography` / `Layout` indirectly through `UI.Label`, `UI.Button`, `UI.Panel`.
- Indirectly: `Config.UI.MapTiles`, `MapIcons`, `MapIconLayer`, `MapPois`, `RouteGuide`.

### 1.5 Dependencies and public API
- Public API (20-23): `FullMap.Open()`, `Close()`, `Toggle()`, `IsOpen()`, `start()`. All return false / no-op until started.
- Callers: `DesktopFreeRoamHudUI` 958-963 and `MobileFreeRoamHudUI` 259-265 look the module up **by name** (`Modules.Game.UI:FindFirstChild("FullMapUI")`) and call `.Open()`; failure shows the toast "MAP NOT AVAILABLE".
- Owns Player attribute **`FullMapOpen`** (496, 520, 848). Readers: DesktopFreeRoamHudUI (1116, 1351), MobileFreeRoamHudUI (330-331), ActivityClient (75-77), OnboardingClient (334, 742).
- Reads Player attributes (blocking, 449-461): `GarageSessionActive, OwnedGarageInside, RaceSessionActive, RaceQueueActive, DrivingControlsOpen, FirstDrivePresentationPending, MobileMajorMenuOpen, MobileFreeRoamCarMenuOpen`; PlayerGui attribute `OwnedGarageManagementOpen`; vehicle attributes `OwnerUserId, RaceParticipant, RaceRunId`.
- Bindables under `PlayerScripts.Runtime.UI`: fires `ShowTopNotification` (91-94, defined but `toast` is never called in this file); listens to `FreeRoamHudPresentationMode` (751-761).
- `GameplayInputGate.Acquire("FullMap","V1")` / `Release(token, true)` (521, 495).
- Owns the player waypoint: RouteGuide source `"Waypoint"` + MapMarkers id `"Waypoint"` (267-277), reconciled with the `"Player"` source (278-293).
- While open it is the only caller of `RouteGuide.Update` (815); the HUD owners return early.
- **Reads other owners' instance names**: `minimapShowing()` 464-478 looks for ScreenGuis `DesktopFreeRoamHud` and `MobileFreeRoamHud_Phase1` and a descendant named `Minimap`. M / Back only open the map when that returns true (541).
- No remotes, no saved data.

### 1.6 Input
- Keyboard (668-692): `M` toggle (needs a showing minimap to open), `Esc` close, `E / = / KeypadPlus` zoom in, `Q / - / KeypadMinus` zoom out, `C` centre on player, `F` whole map, `Backspace / Delete` clear waypoint. `WASD` / arrows pan, polled with `IsKeyDown` in the render step (776-783).
- Mouse: wheel zoom about the cursor (641-643), drag pan, click sets or clears a waypoint (560-577). A press outside the panel closes (621-628).
- Touch: drag, two-finger pinch (584-610), tap. Tap radius 34 px.
- Gamepad: `ButtonSelect` toggles (718-723, permanent binding). While open (695-717, sunk at High+50): `A` waypoint at the crosshair, `B` close, `X` clear, `Y` centre, `LB/RB` zoom, left stick pan.
- **No GuiService selection.** No `SelectedObject`, no `Selectable=false`; the legend list cannot be scrolled with a controller.
- `GuiService.MenuOpened` closes the map (693).

### 1.7 Per-frame work and rebuilds
Render step runs only while open (771-846). Each frame:
- `blocked()` (773): ~9 `GetAttribute` calls plus `subject()` (a parent walk).
- `subject()` again at 806.
- `cfg()` reads: KeyboardPanSpeed, GamepadPanSpeed, CentreResponse, Min/MaxVisibleStuds (through `clampView` -> `studLimits`), RouteLineScale. Each is a `GetAttribute` + clamp.
- Allocations: `down()` closure plus four temporary tables (777-781), `project` closure (800), `Hits` entries in MapIconLayer.
- `canvas.Size` and `canvas.Position` written every frame (796-797); 16-tile cull (799).
- `routeRenderer:Step`, `playerMarkers:Step(1, ...)`, `iconLayer:Step`.
- `readValue(layoutConfig, "MapRotationOffsetDegrees")` (814) = `FindFirstChild` per frame.
- Legend rebuild throttled to 4 Hz, only when dirty (842-845).

Rebuild patterns:
- Legend rows are destroyed and recreated when the icon-set signature changes (333-351), and on every `layout()` because the signature is cleared (444): every viewport-size event and every legend toggle.
- `FreeRoamMapPlayerMarkers` instance is created on each open and destroyed on close (491, 523): 3 instances and about 8-12 connections per other player, each time.
- Route segments and map icons are pooled and never recreated.

### 1.8 Mobile differences
- `isMobile = TouchEnabled and not KeyboardEnabled`, evaluated once at start (50).
- Different scale formula and margins (374, 377); 44 px minimum targets (376); narrower legend, closed below 760 px wide; larger icons (56) and tap radius (34); arrow 40 px; touch hint text (364).

### 1.9 Hard-coded style
- Colours: 13 `fromRGB` fallbacks (54-57) + black backdrop (114). Palette is the pink-outline set.
- Font: `FONT = Enum.Font.Michroma` (51), passed to RouteGuide chip and MapIconLayer glyphs. Labels and buttons use `RacingUIComponents.Font` (Racing.Typography.FontFamily = Michroma). Two font mechanisms in one screen.
- Sizes: about 35 numeric literals in `layout()` (374-434): 36, 16, 12, 56, 90, 24, 100, 13, 40, 44, 15, 120, 12, 16, 30, 11, 28, 32, 36/40, 26; plus corner 6 (130), 999 (156), stroke 2 (157), arrow clamp inset 14 (810).
- Text content: "X", "+", "-", "ME", "ALL", "LEGEND" are text buttons, not icons (125-126, 159-162). Hint strings carry key legends (362-366).

### 1.10 Defects
1. **Text far below the legibility floor on phones.** `px(11)` at `s = 0.55` is 6 px (hint 427), `px(12)` is 7 px (legend rows 415, legend toggle 395, clear 411), `px(13)` is 7 px (district 387), close "X" `px(15)` is 8 px (392). Style sheet floor is 11 px.
2. **No safe-area or top-bar handling** (112, 377-394). The header band (title top-left; legend toggle and close top-right) starts 8-16 px from the screen edge on phones and 26-40 px on desktop, under the Roblox top bar and device notches.
3. **Rotated route segments are probably not clipped on the full map.** `MapView` is a plain Frame with `ClipsDescendants` (128-129). Route segments and the blip are rotated Frames (RouteGuide 202, 334). Roblox does not clip rotated descendants with `ClipsDescendants`, which is why both minimaps use a CanvasGroup (Desktop 931). When zoomed in on a long route, segments can draw over the header band and margins. Not verified in Play.
4. **1.12 scale cap** (374): on 2560x1440 and 4K the whole map chrome shrinks relative to the screen (labels 13 px on a 2160-high screen).
5. **Map icons and route width ignore the scale** (143, 819): 48 px icons at 720p and at 4K, while legend icons use `target(30)`.
6. **Legend rebuilt on every resize event and toggle** (443-444) instead of resized.
7. **Legend labels truncate at small scales**: Michroma is wide; "COURIER DROP-OFF" at 12 px needs ~160 px, the label has about 139 px at 720p (397, 347-349).
8. Per-frame waste: `blocked()` + two `subject()` walks, ~8 attribute reads, table and closure allocation (773-806).
9. `isMobile` never re-evaluated (50); a phone with a keyboard attached gets the desktop layout.
10. `watchViewport` adds a connection per camera change and never disconnects (763-767).
11. `minimapShowing()` couples to two ScreenGui names and a child name owned by other scripts (465-467).
12. Colours come from `Racing.Colours` while both minimaps use HUD colours; `HighSpeed` is silently a literal.
13. `toast()` (91-94) is dead code.

### 1.11 Seam
- **No internal seam.** Controller state (pan, zoom, pointers, waypoint, open/close, blocking) and view construction share upvalues in one 830-line closure. A new view cannot reuse the logic without editing this file.
- State / logic: `calibration` 96-107; pan/zoom 178-241; `subject`/`playerUnit` 243-263; waypoint ownership 266-293; `keyEntries` 303-324; `blocked` 449-461; `minimapShowing` 464-478; `open`/`close`/`toggle` 480-543; pointer, pinch and tap 545-665; keyboard and gamepad 667-733; presentation owners 750-761; `renderStep` 771-846.
- View: GUI build 109-176; legend rows 338-351; hint text 360-369; `layout` 371-446; tweens inside open/close 497-504, 525-529.
- Cleanest switchable route: a **new module with the same public API** (`Open/Close/Toggle/IsOpen/start`), built as controller + view, started by ClientBase **instead of** FullMapUI when the style flag is on. FullMapUI stays byte-identical as the backup. The pure maths is already in MapMath, so the fork is the controller logic only.
- The two must never both be started: both would write `FullMapOpen`, bind `M`, `ButtonSelect`, the `FullMapToggle`/`FullMapPad` actions, the `FullMapUI` render step, own the `"Waypoint"` source, and (if the new gui is also named `FullMap`) destroy each other's ScreenGui at start (110-111).
- Single-owner items: `FullMapOpen`; `"Waypoint"` in RouteGuide and MapMarkers; `RouteGuide.Update` while open; the InputGate token; the two CAS action names; the render-step name.
- Names others depend on: module name `FullMapUI` (HUD owners). Nothing outside the map group references `PlayerGui.FullMap`, `MapView`, `MapCanvas`, `Legend` or any child by name (grep over 219 scripts).
- Names this script depends on: `DesktopFreeRoamHud`, `MobileFreeRoamHud_Phase1`, `Minimap` (465-467). **A new HUD presentation that renames any of these silently disables M / Back on the old full map.**

---

## 2. MapIconLayer

### 2.1 Purpose and lifecycle
- Draws MapMarkers into one container as upright icons. `Layer.new(options)` 149-184; `Layer:Step(dt, state)` 268-320 called from the host's frame loop; `Layer:Destroy()` 327-333.
- Instances: Desktop minimap (Desktop 949-952), mobile minimap (Mobile 98-101), full map (FullMapUI 143). Static icons for the legend through `Layer.CreateIcon` (139-146).
- Connections kept per layer: `MapMarkers.Changed` (dirty flag), `MapMarkers.IconsChanged` (restyle flag), `Config.UI.MapIconLayer.AttributeChanged` (174-182). Disconnected in `Destroy`.

### 2.2 Instance tree
- `MapIcons` Frame overlay, full size of the container (164-171). Destroys an existing `MapIcons` child first (162-163).
- Per marker `Icon_<id>` (62-106): root Frame, `Shadow` ImageLabel, `Image` ImageLabel, `Glyph` TextLabel, `Pulse` UIScale = **5 instances**. Pooled (213-219, 233).
- Live count today: 4 visible POIs (5 configured, Customisation hidden) + waypoint + job offers/trip markers. Roughly 5-15 icons per surface, 25-75 instances, on three surfaces.

### 2.3 Scaling and layout
- Icon size is an absolute offset from config: `FullMapIconSize` 48, `TouchFullMapIconSize` 56, `MinimapIconSize` 32, `MobileMinimapIconSize` 24, or `options.IconSize` / `SetIconSize` (186-211).
- Position is scale within the container: `UDim2.fromScale(x/width, y/height)` (314).
- On the desktop minimap the container sits inside the HUD's `DesignRoot` UIScale, so the 32 px follows the HUD scale. On mobile and the full map it is raw pixels.
- Two projection modes (273-288): the host supplies `Project` + `Size` (full map), or the layer builds the rotating-minimap projection from `MapMath.MinimapPoint`.
- **Edge handling is rectangular**: `MapMath.Inside` (305) and `MapMath.ClampToRect` with `EdgeInset` (307).
- Pin icons (`PinIcons` = Waypoint, TaxiDrop, CourierDrop) are offset so the tip marks the point (254; `PinTipY` 0.9219).
- Z order: `ZIndex + 1 + 2 * clamp(Priority, 0, 60)` (249).

### 2.4 Config
- `Config.UI.MapIconLayer` attributes (14): `EdgeInset, FullMapEnabled, MinimapEnabled, FullMapIconSize, TouchFullMapIconSize, MinimapIconSize, MobileMinimapIconSize, Overscan, PinIcons, PinTipY, PulseAmount (0), PulseSpeed, ShadowOffset, ShadowTransparency (1 = shadow off)`.
- `Config.UI.MapIcons` attributes through `MapMarkers.IconAsset` (14 icon ids).

### 2.5 API
`Layer.new`, `Layer.CreateIcon`, `Layer.Glyph`, `Layer.Colour`, `:Step`, `:SetVisible`, `:SetIconSize`, `:HitTest(x, y, radius)` (323-325, used by FullMapUI tap), `:Destroy`.

### 2.6 Input
None. `HitTest` is a pure lookup into the last frame's `Hits`.

### 2.7 Per-frame work
- Per visible marker: one projection, an inside test, optional clamp, `Visible`/`Position` writes guarded by equality (312-315), and a new `Hits` table entry (317). `table.clear(Hits)` each frame (298).
- `_sync` only after `MapMarkers.Changed` (294); it clones the registry (`MapMarkers.All()`).
- `_style` only when a record is new or a restyle is flagged (300).

### 2.8 Mobile
Smaller minimap icon (24), larger full-map icon (56), chosen by `options.Mobile`.

### 2.9 Hard-coded style
- 10 `fromRGB` in `DEFAULT_THEME` (29-32); `ImageColor3` forced to white (114), so icons show their artwork colours and **cannot be tinted** to a text colour.
- Font fallback `Enum.Font.Michroma` (96). Fallback glyph uses `TextScaled = true` at 62% of the icon (95-97) with a 0.15 text stroke (98).
- Token-per-kind maps name the old palette: `ElectricBlue, Outline, Telemetry, HighSpeed, OutlineSoft, Danger` (26-27). They only affect the text-glyph fallback.

### 2.10 Defects
1. Square clamp and inside test only (305-307): on a round minimap, edge-clamped icons would sit in the corners and be cut by the circular clip.
2. Icons live inside the host's clipping container; on a circle, rim icons are cut in half. A round map needs rim icons drawn in an unclipped sibling.
3. No tint option (114), which blocks "icons are a single colour and inherit text colour".
4. Per-frame `Hits` allocation on the two minimaps, where nothing ever calls `HitTest`.
5. `CreateIcon` re-reads config per call (142-143); minor.

### 2.11 Seam
- Already presentation-neutral: container, theme, font, size and surface are injected. A new host can use it unchanged for square surfaces.
- Needed for the new look, all additive with defaults that keep today's output: `Shape = "Circle"` (radial inside and clamp), `Tint` (optional ImageColor3), `TrackHits = false`.
- Single-owner: none beyond the per-container `MapIcons` child name.

---

## 3. MapMarkers

### 3.1 Purpose and lifecycle
- Client marker registry; draws nothing (1-5). Singleton by module cache. On first require it spawns a task (102-128) that waits for `Config.UI.MapIcons` and `Config.UI.MapPois`, registers `Poi_<name>` markers and watches for changes.
- Connections kept for the session: `MapIcons.AttributeChanged` (108), each POI folder's `AttributeChanged` (120), `MapPois.ChildAdded/ChildRemoved` (126-127).

### 3.2-3.3 Instances, scaling
None.

### 3.4 Config
- `Config.UI.MapIcons` (14 asset-id attributes: CourierDrop, CourierPickup, Customisation, Dealership, Duel, Garage, Job, OtherPlayer, Player, Race, TaxiDrop, TaxiFare, TimeTrial, Waypoint).
- `Config.UI.MapPois` children (5: Dealership, MyGarage, Customisation [Hidden], Race_ShowroomLoop, Race_ShiftedCanalSprint), attributes `Position, Hidden, Kind, Icon, Label, Priority, EdgeClamp, Order, RouteId, DestinationId`.

### 3.5 API
- `Set(id, marker)`, `Remove(id)`, `Get(id)`, `All()` (clone), `IconAsset(key)`; signals `Changed(id, markerOrNil)`, `IconsChanged()`.
- Marker fields (27-44): `Id, Position, Icon, Label, Kind, Priority, Color, Minimap, FullMap, EdgeClamp, Pulse, Order, RouteId, DestinationId, Static`.
- Writers: MapMarkers itself (POIs), FullMapUI (`Waypoint`), JobClient (95-108, through a lazy pcall require).
- Readers: MapIconLayer, FullMapUI (legend, tap).

### 3.6-3.9
No input, no frame work, no style. `Order`, `RouteId`, `DestinationId` are carried but the legend no longer uses them (FullMapUI legend is "MAP KEY only", 295).

### 3.10 Defects
- A POI attribute change removes and re-adds the marker (121-122), firing `Changed` twice. Harmless.
- A fifth copy of the asset-id normaliser (72-80).

### 3.11 Seam
Pure data. Shared unchanged by old and new presentation. Must stay a single registry.

---

## 4. MapMath

- Pure functions, no services (1-6). Tested by `scripts/map_ui/tests.lua`.
- API: `Finite`, `Calibration`, `MapDelta`, `WorldDelta`, `WorldToUnit`, `UnitToWorld`, `Heading`, `MinimapPoint`, `ClampToRect`, `Inside`, `ClampVisibleStuds`, `CanvasSide`, `ScreenToUnit`, `UnitToScreen`, `ZoomAbout`, `BoundsToUnits`, `ClampPan`, `MaxStudsForBounds` (unused), `FitStudsForBounds`, `TileRect`, `TileOverlaps`, `AssetId`, `ResolveTiles`, `PinCentreOffset`, `Approach`, `PickNearest`; constants `MaxTileGrid = 8`, `LegacyTiles`.
- Used by FullMapUI (25 sites), MapIconLayer, MapTileSet. **Not used by either HUD owner, RouteGuide's renderer or FreeRoamMapPlayerMarkers**, which each carry their own copy of the same transform (Desktop 1147-1223, Mobile 409-470, RouteGuide 304-311 and 374-380, PlayerMarkers 420-427).
- Defect: no circular helpers (`ClampToCircle`, `InsideCircle`). `BoundsToUnits` allocates four small tables per call but is only called on layout.
- Seam: add circle helpers here (additive, testable). Shared unchanged otherwise.

Calibration in use: `FullStuds = 2048 * 2850 / 207 = 28,197 studs` across the tiled canvas.

---

## 5. MapTileSet

### 5.1 Purpose and lifecycle
- Builds the N x N tile ImageLabels into a host canvas (39-66). `:Cull(uMin, uMax, vMin, vMax)` 69-74 hides tiles outside a map-unit box; `:ShowAll`, `:Destroy`.
- Three instances: desktop minimap (Desktop 937), mobile minimap (Mobile 87), full map (FullMapUI 133). No connections.

### 5.2 Instances
`MapTileR<r>C<c>` (or the four legacy names). Live config `GridSize = 4`, so **16 ImageLabels per surface, 48 in total**; all 16 ids present.

### 5.3 Layout
Scale position, `Size = UDim2.new(1/n, overlap, 1/n, overlap)` with a 1 px overlap on inner edges (47, 58-59). `ScaleType.Stretch`.

### 5.4 Config
`Config.UI.MapTiles` attributes `GridSize`, `R<r>C<c>`; fallback `Config.UI.DesktopFreeRoamHud.Assets` `MapTileTopLeft/TopRight/BottomLeft/BottomRight`. Resolved once at construction; tiles are not re-read live.

### 5.7 Per-frame
`Cull` is 16 overlap tests and guarded `Visible` writes. On the minimaps the reach is `visibleStuds * 0.75 / FullStuds` = 0.076 of the canvas against a 0.25 tile, so 1-4 tiles are visible.

### 5.10 Defects
- The 1 px overlap is in canvas pixels. On the minimaps the canvas is supersampled 4x and scaled back (Desktop 1157-1163), so the overlap is 0.25 screen px and may not hide seams. Not verified in Play.
- Tile magnification on the full map: at `OpenVisibleStuds` 5000 on a 950 px-high view the canvas is 5,357 px, 1,339 px per tile; at `MinVisibleStuds` 500 it is 13,393 px per tile. Tile native resolution is unknown from Studio; if 1024 px, the default zoom is already upscaled and close zoom is very soft.

### 5.11 Seam
No style. Reuse unchanged.

---

## 6. RouteGuide

### 6.1 Purpose and lifecycle
- Two things in one module: (a) singleton route state and planner (28-170); (b) a `MapRenderer` class that draws the route on a map (172-409).
- No startup of its own; required by DesktopFreeRoamHudUI (25), MobileFreeRoamHudUI (103), FullMapUI (34), ActivityClient (25, handed to JobClient and DuelClientView as `ctx.RouteGuide`), RaceBrowserClient (24).
- `RouteGuide.Update(position)` (144-170) is called every frame by whichever host owns the screen and throttles itself (`ReplanMinSeconds` 1, `ProgressHz` 10).
- Renderer instances: one per surface; `MapRenderer:Destroy` 405-409. No connections.

### 6.2 Instance tree per renderer
```
<Canvas>.RouteGuide        Frame, full canvas                                  (188-196)
  DestinationBlip          Frame rotated 45 + UIStroke                         (198-209)
  RouteOutline<i>, RouteLine<i>   Frame + UICorner(1,0) each, rotated          (259-282)
<Container>.RouteEdgePip   Frame 9x9 rotated 45 + UIStroke                     (211-224)
<Container>.RouteChip      TextLabel 20 px high, AutomaticSize.X,
                           UICorner 6 + UIStroke 1 + UIPadding 8               (226-249)
```
**4 instances per route segment.** Points = road-graph nodes on the path plus up to 8 curve points per 90 degree corner (`RoadRouting.Smooth(points, CornerRadius 50, 8)`, 137). A cross-city route is plausibly 100-300 points, so 400-1,200 instances per renderer; two renderers hold them at once (the HUD's and the full map's). Segments are pooled by index and never destroyed.

### 6.3 Layout
- Segment position and length are scale on the canvas; thickness is offset pixels: `UDim2.new(lengthScale, width, 0, width)` (331-333). Width = `LineWidth` 5 x `PixelScale` (316): x4 on the supersampled minimap canvases, x2 on the full map.
- Chip: fixed `TextSize 10`, 20 px high, 6 px from the container top, centred (228-233).
- Pip: fixed 9x9 (216); clamp limit `mapSize/2 - 10` (381).
- Edge pip test and clamp are **square**: `max(|rx|, |rz|) > limit` (382-385).

### 6.4 Config
`Config.UI.RouteGuide` attributes (12): `Enabled, ChipEnabled, ArriveStuds, CornerRadius, LineWidth, OutlineWidth, OffRouteSeconds, OffRouteStuds, ProgressHz, ReplanMinSeconds, StudsPerMile, Owner`. Optional `LineColour`, `ActivityColour` (255-256) are not set and every host passes colours, so those two are dead. Child folder `Destinations` (4 children: Dealership, MyGarage, Race_ShowroomLoop, Race_ShiftedCanalSprint) with `Position, DisplayName, Kind, RouteId, Order`.

### 6.5 API
- State: `SetDestination(sourceId, position, {Label, Priority, Kind})`, `Clear(sourceId?)`, `GetActive()`, `Destinations()`, `SetDestinationById(id, sourceId?)`, `Update(position)`; signals `Changed(active)`, `Arrived(destination)`.
- Sources in use: `"Waypoint"` (FullMapUI), `"Player"` (RaceBrowserClient 446), job trip (JobClient 284, 301), duel finish (DuelClientView 221).
- Renderer: `newMapRenderer{Canvas, Container, ZIndex, ChipZIndex, Font, Colours}`, `:Step(state)`, `:SetVisible`, `:Destroy`.
- **`route` and `progress` are module-private** (36-38). There is no getter for the points, version, progress point or remaining distance, so no other module can draw the route or its distance.
- Depends on `Modules.Game.World.RoadRouting` and `RoadGraphData`.

### 6.7 Per-frame work
`MapRenderer:Step` (294-403), per surface per frame while a route is active:
- 3 `GetAttribute` reads (`Enabled`, `LineWidth`, `OutlineWidth`), `ChipEnabled`, `StudsPerMile`.
- Two closures allocated (`toCanvas`, `place`).
- Re-places the first visible segment every frame (358): about 10 property writes.
- Blip: 5 property writes (362-368).
- Chip text rebuilt by string concat and `FormatDistance` every frame (394), plus 4 property writes.
- Full re-place of every segment when the route version, colour, width or pixel scale changes (322-347).
- Segments ahead of the player are all `Visible`, wherever they are; there is no spatial culling, only progress-based hiding (348-357).

### 6.9 Hard-coded style
- 3 `fromRGB` fallbacks (255, 256, 313) + white (397). Font fallback Michroma (234).
- Fixed: pip 9 px (216), chip 20 px / text 10 / top 6 / corner 6 / stroke 1 / padding 8 / transparency 0.15 (229-247, 396), blip `8 * pixelScale` (363), pill caps `UICorner(1,0)` (277).

### 6.10 Defects
1. Chip and pip never scale: 10 px text on the full map at any resolution; about 7 px inside the desktop HUD at scale 0.72.
2. Chip is top-centre **inside** the host's clip; a circular clip cuts it.
3. Square edge-pip maths (382-385).
4. No accessor for route geometry or remaining distance, so a restyled chip or line cannot be drawn elsewhere.
5. Rotated segments rely on the host's clip; on the full map that clip does not apply to rotated children (see 1.10 item 3).
6. Every segment ahead stays visible and laid out; when the minimap canvas resizes with speed zoom, the engine re-lays out all of them each frame, inside a CanvasGroup that re-rasterises.
7. Chip shape (rounded, stroked) is fixed in code; it contradicts "square, no strokes".
8. Per-frame string and closure allocation (304, 324, 394).

### 6.11 Seam
- Route state must stay one singleton shared by old and new.
- The renderer is injectable for colour and font only. For the new look it needs additive, default-off options: `ChipParent` / `ShowChip = false`, `PipShape = "Circle"`, per-surface `ChipTextSize`, square caps; and one additive read-only getter (for example `RouteGuide.GetRouteState()` returning points, version, first segment, progress point, remaining) so a new chip can live in the HUD's own component.
- `Config.UI.RouteGuide@ChipEnabled` is global; turning it off for the new look also turns it off for the old one, so it is not a per-style switch.

---

## 7. FreeRoamMapPlayerMarkers

### 7.1 Purpose and lifecycle
- Other-player dots for a map surface, plus shared rotation helpers used by both HUD owners (`ResolveRotation` 92-109, `MapHeading` 111-119, `StepHeading` 121-126, `PlaceNorth` 130-146).
- `Module.new{Container, Config, ZIndex}` 148-189; `:Step(dt, state)` 381-445; `:SetVisible`; `:Destroy` 447-455.
- Instances: desktop minimap (Desktop 943-947), mobile minimap (Mobile 92-96), full map (created per open, FullMapUI 523).
- Connections per instance: 14 config attribute signals (175-179), `PlayerAdded`, `PlayerRemoving`; per other player 3 attribute signals + `CharacterAdded` (337-348), character `ChildAdded/ChildRemoved` + humanoid `SeatPart` (274-301), and per vehicle 4 attribute signals + `AncestryChanged` (245-254). All released in `_removePlayer` / `Destroy`.

### 7.2 Instances
`OtherPlayerMarkers` Frame overlay with `ClipsDescendants = true` (163-172; destroys an existing one first, 161-162). Per player `Player_<UserId>` ImageLabel + UICorner(1,0) + UIStroke = 3 instances. Cap `MaximumOtherPlayers` 14.

### 7.3 Layout
- Marker size = `clamp(round(LocalMarkerSize * OtherPlayerMarkerScale 0.65), Min 8, Max 16)` offset px (407).
- Position is scale within the overlay (441), smoothed with `MarkerResponse` (408, 435).
- Square cull: hidden when `|x - half| > half + Overscan` on either axis (428).

### 7.4 Config
`Config.UI.FreeRoamMapPlayerMarkers` attributes (22). Read here: `Enabled, OtherPlayerMarkerScale, MinimumMarkerSizePixels, MaximumMarkerSizePixels, MaximumOtherPlayers, MarkerResponse, EdgeOverscanPixels, PositionEpsilonPixels, OtherPlayerIcon (empty), MarkerColor (54,224,255), MarkerStrokeColor (236,255,255), MarkerBackgroundTransparency, MarkerStrokeTransparency, MarkerStrokeThickness, MapRotationMode (Subject), MapRotationResponse, MapNorthArrowMode (Hidden), MapNorthOrbitInset`. Read by the HUD owners **through `mapPlayerMarkers.Config`**: `UseRelativeCanvasTransform, MapPanSubpixelFactor (4), MapPanResponse` (Desktop 1155-1156, 1194; Mobile 417-418, 443).

### 7.5 Dependencies
- Player attributes `GarageSessionActive, OwnedGarageInside, RaceSessionActive` (61-65); `MinimapMode` ("NORTH UP" / "ROTATE", written by the desktop settings menu, Desktop 631-634) in `ResolveRotation` (95-100).
- Vehicle attributes `OwnerUserId, RaceParticipant, RaceRunId, RaceMode, RaceFinishedPendingExit` (54-74).

### 7.7 Per-frame
Per player: one transform, a cull, a lerp, `Visible` write, guarded size and position writes (410-444). Cheap; bounded at 14.

### 7.9 Hard-coded style
2 `fromRGB` fallbacks (201-202). Marker colour comes from this folder's own attributes, a fourth colour source beside the three theme folders. Round dot with a stroke (320-325).

### 7.10 Defects
- Square cull (428); fine inside a CanvasGroup circle (the clip hides corners) but markers pop at the square edge, not the rim.
- Marker colour is not a theme token.
- Map-behaviour settings (`MapPanSubpixelFactor`, `MapRotationMode`, `MapNorthArrowMode`) live in a folder named for player markers; easy to miss when a new host is written.
- `SetVisible(true)` writes `Overlay.Visible` unguarded (372); trivial.

### 7.11 Seam
- The config folder is injected (`options.Config`), so a new host can pass a second folder with the new marker style and leave the old one untouched. That folder must carry all 22 attributes because the hosts and `ResolveRotation` read map behaviour from it.
- Rotation helpers are shared logic; keep single copies.

---

## 8. Minimap rendering (hosts) and the round-minimap question

### 8.1 How it renders today
Desktop (Desktop 929-975), mobile identical in structure (Mobile 80-106):
```
Minimap        CanvasGroup, ClipsDescendants, UICorner 9      <- the clip
  MapRotator   Frame, Rotation = -heading                      <- whole map turns about the centre
    MapPanCarrier  Frame mapSize*4, UIScale 1/4                <- quarter-pixel pan
      MapCanvas    Frame, offset size and position             <- pan and zoom
        16 tiles, RouteGuide layer
  OtherPlayerMarkers, MapIcons (upright), PlayerMarker, NorthArrow,
  RouteEdgePip, RouteChip, MapMissing, RouteButton (opens the full map)
  EdgeLeft/Right/Top/Bottom   48 px linear-gradient fades (desktop only)
```
- **Clipping**: the CanvasGroup renders its subtree to a texture and clips it to its box and UICorner shape. This is what clips the rotated map; a plain `ClipsDescendants` Frame would not (comment at Desktop 931, Mobile 81).
- **Rotation**: `MapRotator.Rotation = -displayedMapHeading`; mode from `ResolveRotation` (Subject / Camera / NorthUp) and the player's `MinimapMode` attribute (Desktop 1211-1223).
- **Zoom with speed**: `visibleStuds = MapVisibleStuds 2850 * speedZoomFactor` (Desktop 1152). Factor eases from 1 at 40 mph to 1.8 at 200 mph, out-response 1.6, in-response 0.8 (Desktop 130-151; the same function is duplicated at Mobile 368-388). Canvas side = `FullStuds * mapSize / visibleStuds` = 2,424 design px at rest, 1,347 at full zoom-out.
- **Size**: desktop `MinimapSize` 245 design px inside `DesignRoot` (UIScale `clamp(min(vp.X/1920, vp.Y/1080), 0.72, 1.12)`, Desktop 1050-1062), anchored bottom-left at `EdgeMargin` 20. Mobile `clamp(vp.Y * 0.27, 145, MinimapSize 180)` (128-160 when vp.Y < 500), raw pixels, **top-right** (Mobile 348-357).
- **Frame loop**: desktop `BindToRenderStep("PCFreeRoamHudPhase4A", 3000)` (1368); mobile `RenderStepped` (391).

### 8.2 Per-frame cost of a minimap (desktop)
Every frame while the HUD is enabled:
- about 25 `L()` / `B()` / `readValue` reads, each a `FindFirstChild` + `IsA` (1147-1224), plus ~6 `GetAttribute` on the player-marker config and 6 in `speedZoomFactor`;
- 16-tile cull; canvas size and position writes; rotator and player-marker rotation;
- `mapPlayerMarkers:Step` (up to 14), `mapIcons:Step` (5-15), `RouteGuide.Update`, `routeRenderer:Step`;
- the CanvasGroup re-rasterises whenever anything inside changes, which is every frame while moving or turning. The texture is small (245 x 1.12 = 275 px; 344 px at the style sheet's 307).
The script cost is small (tens of microseconds); the CanvasGroup redraw is the real cost and is already paid today. While the full map is open the HUD returns early (Desktop 1116) and FullMapUI's step replaces it, so the two never both run.

### 8.3 Is a round minimap feasible?
**Yes, with the current rendering.** A CanvasGroup clips to its UICorner, so `UICorner.CornerRadius = UDim.new(0.5, 0)` on the existing `Minimap` CanvasGroup gives a circular clip with no new technique and no extra per-frame cost. The work is in the parts that assume a square:

| Part | Today | Needed for a circle |
|---|---|---|
| Clip | UICorner 9 on CanvasGroup (Desktop 930, Mobile 80) | radius 0.5 scale |
| Edge fade | four 48 px linear fades (Desktop 968-975) | one static radial vignette image |
| Ring + glow | none (borderless) | ring drawn as a sibling **above** the CanvasGroup so it covers the clip edge; glow image behind |
| Edge-clamped icons | `ClampToRect` inside the clip (MapIconLayer 305-307) | radial clamp; rim icons in an unclipped sibling overlay |
| Route edge pip | square clamp (RouteGuide 382-385) | radial clamp, drawn on the ring |
| Route chip | top-centre inside the clip (RouteGuide 229) | move outside the circle (under or beside the map) |
| North marker | corner placement, mode Hidden (PlaceNorth 130-146) | existing `Orbit` mode already rides the rim |
| Other players | square cull (PlayerMarkers 428) | acceptable as is; optional radial cull |
| Tile cull reach | 0.75 x visible (Desktop 1183) | can drop to about 0.55 for a circle |

Caveats to check on device: CanvasGroup textures can be rendered at reduced resolution on low-memory devices, which softens the map; the clip edge of a CanvasGroup is not perfectly smooth, which the ring should cover.

### 8.4 Full map and CanvasGroup
The full map's `MapView` is not a CanvasGroup, so rotated route segments are not clipped there. Making it a CanvasGroup would fix that but means a near-full-screen texture (about 3000 x 1300 on 3440x1440) redrawn every frame while panning. Cheaper: clip the route polyline to the view rectangle in code (pure maths, only when pan or zoom changes).

---

## 9. Cross-cutting findings

### 9.1 Duplicated logic
- Map transform (flip, rotate, scale): MapMath; Desktop 1170-1193; Mobile 428-456; RouteGuide 304-311 and 374-380; PlayerMarkers 420-427.
- `speedZoomFactor`: Desktop 130-151 and Mobile 368-388, identical.
- Asset-id normaliser: FullMapUI 79-84, MapMath 180-185, MapMarkers 72-80, PlayerMarkers 40-45, RacingUIComponents 36-42.
- Subject lookup (seat -> owned vehicle -> root): FullMapUI 243-257, PlayerMarkers 76-86, both HUD owners.

### 9.2 Colour and font sources for map surfaces
| Surface | Colours from | Font from |
|---|---|---|
| Desktop minimap | `DesktopFreeRoamHud.Colours` via `C()` (Desktop 951, 955) | `FONT` in the HUD |
| Mobile minimap | local constants DEEP, CYAN, PINK ... (Mobile 100, 104) | `FONT` in the HUD |
| Full map | `Racing.Colours` via RacingUIComponents (FullMapUI 53-61) | `Enum.Font.Michroma` literal + Racing.Typography |
| Other-player dots | `FreeRoamMapPlayerMarkers` attributes | - |
| Map icons | artwork colours (untinted) | Michroma for the text fallback |
The token values are identical today (checked Panel, PanelDeep, PanelSoft, PanelBlue, Outline, OutlineSoft, Telemetry, ElectricBlue, Danger, Text, Muted, Disabled); `HighSpeed` exists only in the HUD folder.

### 9.3 Style-sheet conflicts in this group
- "No key hints except the world Start banner": the full map's hint strip is all key legends (FullMapUI 362-366). Without it the map controls are undiscoverable; needs a decision.
- "Round minimap bottom-left, 307 px": on phones the minimap is top-right because the bottom-left holds driving controls.
- "Minimap in the in-race HUD": no minimap runs during a race today (see section 0).
- "Icons inherit text colour": map icons are full-colour artwork and cannot be tinted.
- "Route lines are Cyan": matches today's `Telemetry` line; activity routes are pink (`HighSpeed`), which the sheet does not mention.
- "No UIStroke for structure": route chip, pip, blip, crosshair, other-player dots and every UI.Button / UI.Panel on the full map use strokes.

### 9.4 Recommended seam for the whole group
1. Leave **FullMapUI** untouched as the backup. Add a new full-map module with the same API (controller + view built from the shared components), and have ClientBase start exactly one of the two from the style flag.
2. Keep **MapMarkers**, **MapMath**, **MapTileSet**, RouteGuide's state half and FreeRoamMapPlayerMarkers' logic as shared infrastructure for both styles.
3. Make additive, default-off changes to the three shared renderers so old output is unchanged: circle shape and tint in MapIconLayer; chip placement, pip shape, sizes and a read-only route getter in RouteGuide; circle helpers in MapMath.
4. Give the new presentation its own player-marker config folder.
5. Keep the minimap host names (`DesktopFreeRoamHud`, `MobileFreeRoamHud_Phase1`, child `Minimap`) or accept that the old full map's M / Back toggle only works with the old HUD.
6. In the new view: cache config and subscribe to changes instead of re-reading each frame; resize the legend instead of rebuilding; scale icons, chip and line width with the screen; honour the safe area; set a text floor.

### 9.5 Not verified (needs Play or assets)
- Whether route segments visibly spill outside the full map view when zoomed in.
- Native pixel size of the 16 map tiles, and whether tile seams show on the supersampled minimap canvas.
- Typical route point counts (estimate 100-300).
- CanvasGroup sharpness on a low-end phone.
- Instance count of `Foundation.ApplyBevel` per button (not read).
