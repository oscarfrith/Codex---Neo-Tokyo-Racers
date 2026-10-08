# UI restyle audit: group "racing-menus"

Read-only audit, 2026-10-08. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode. Nothing was changed in the repo or in Studio. Play was not started, so everything below is from source and config; items that need Play to confirm are marked "not verified in Play".

Scripts read completely:

| Script | Class | Lines | Chars |
|---|---|---:|---:|
| `ReplicatedStorage.Modules.Game.Racing.RaceBrowserClient` | ModuleScript | 618 | 24,014 |
| `ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient` | ModuleScript | 902 | 58,733 |
| `ReplicatedStorage.Modules.Game.UI.RacingUIComponents` | ModuleScript | 194 | 8,409 |
| `ReplicatedStorage.Modules.Game.UI.RacingMobileScaledDesktopLayout` | ModuleScript | 89 | 3,703 |

All four listed paths exist as given. Supporting scripts read in part: `ResponsiveUIFoundation` (1-115, 205-224), `GarageComponents` (1-150), `RaceEntryMenuClient` (all), `OnboardingClient` (118-224, 464-472, 724-732), `ClientBase` (1-12, 88-113), `RaceLifecyclePresentationClient` (236-252), `DesktopFreeRoamHudUI` (1334-1350), `ServerStorage.Modules.Core.FeatureFlags` (1-60).

---

## 0. Headline findings

1. **One fixed 1200x720 canvas, scaled as a block.** Both menus build every child in offset pixels inside a 1200x720 shell and put one `UIScale` on the shell. Desktop scale is clamped to 0.55-1.15, so the menu stops growing at about 986 px of viewport height. At 2560x1440 it covers 54% x 58% of the screen, at 3440x1440 40% x 58%, at 3840x2160 36% x 38%.
2. **Phones get the desktop canvas shrunk to about 0.43.** `Config.UI.Racing.MobileScaledDesktop.Enabled = true`, so every touch device uses the desktop tree. On an 844x390 phone the shell is 513x308 px, body text is 6 px, the smallest text is 3.9 px and a 48 px button is 20.5 px tall. This breaks the style sheet's "48 px touch targets" and "Label never below 11 px" rules today.
3. **The separate touch layout is dead code.** `touch = touchDevice and not scaledDesktop` is always false with live config. 207 `touch and a or b` branches (164 in race entry, 43 in the browser) never run.
4. **Logic and view are one closure.** Each client exports only `Client.start()`. State, remote calls and instance building share local upvalues, so a new view cannot call the old script's logic. The clean switch point is the composition root (`ClientBase`), choosing one module path or the other.
5. **Full destroy-and-rebuild on every interaction.** Selecting a list row, a tier, a tab, a dropdown option or a vehicle card clears the page and rebuilds it. No per-frame work exists in any of the four scripts.
6. **Race entry renders across server yields with no guard.** Stale pages show (and can be clicked) on open, and a second click during a yield leaves duplicate footer buttons.
7. **`RacingUIComponents` is the de facto kit for 19 scripts**, but it only has Label, Panel, Button and token readers. It has no tile, tab, list row, fact list, stat panel, tier badge, selected state, disabled state or pressed state. Every consumer builds those inline.
8. **`Core.FeatureFlags` is server-only** (`ServerStorage.Modules.Core.FeatureFlags`; no client script references it). The style sheet's switch needs a replicated value the client can read at start-up.

---

## 1. RacingUIComponents

### 1.1 Purpose and lifecycle
Shared racing UI kit: token readers plus three primitives. Library module; no `start`. At require time it blocks on `WaitForChild` for `ResponsiveUIFoundation` and `Config.UI.Racing.{Colours, Layout, Typography, Assets}` (lines 7-12). No cleanup API. Connections it creates are never returned or disconnected (hover on every button, lines 137-152; one camera `ViewportSize` connection per `AttachResponsiveScale` call, line 173).

### 1.2 Public API (complete)

| Member | Lines | What it does |
|---|---|---|
| `Colour(name, fallback)` | 20-22 | `Config.UI.Racing.Colours.<name>.Value`, else fallback, else white |
| `Layout(name, fallback)` | 24-26 | `Config.UI.Racing.Layout.<name>.Value`, else fallback, else 0 |
| `Type(name, fallback)` | 28-30 | `Config.UI.Racing.Typography.<name>.Value`, else 12 |
| `AssetValue(name, fallback)` | 32-34 | `Config.UI.Racing.Assets.<name>.Value` |
| `Asset(value)` | 36-42 | Normalises a number or id string to `rbxassetid://` |
| `Font(object, role)` | 44-53 | Sets `Enum.Font.GothamBold`/`Gotham`, then `FontFace` from `Typography.FontFamily` (default Michroma), Bold for Heading/Button/Metric, Regular otherwise |
| `Corner(parent, radius)` | 55-57 | `Foundation.Corner` with `Layout.CornerRadius` (5) |
| `Stroke(parent, color, thickness, transparency)` | 59-67 | New `UIStroke`, Border mode, default `Outline` pink, default transparency 0.18 |
| `Label(parent, props)` | 69-87 | `TextLabel`, transparent, fixed `TextSize`, truncate AtEnd, left aligned |
| `Panel(parent, props)` | 89-111 | `Frame` + `UICorner` + `Stroke` + `GlowStroke` (a second, 3 px stroke at 0.82 transparency) |
| `Button(parent, props)` | 113-154 | `TextButton` + corner + bevel overlay + `Stroke` + `GlowStroke` + hover handlers; returns `item, stroke` |
| `AttachResponsiveScale(shell)` | 155-175 | Adds `UIScale` named `ResponsiveScale`; see 1.4 |
| `SetCorner`, `StrokeWidth`, `StyleStroke`, `ApplyBevel` | 176-179 | Re-exports of `ResponsiveUIFoundation` |
| `FormatMoney` | 180 | `Foundation.FormatCompactMoney` |
| `ProjectEconomy`, `BindReplicatedCash` | 181-182 | Re-exports |
| `MetricLabel(parent, props)` | 183-188 | `Label` + `Foundation.StyleMetric` (which hard-codes Michroma Bold, Foundation line 217) |
| `ConfirmationModal(root, options)` | 189-191 | `Foundation.Confirmation(root, options, Components)` |

### 1.3 Who uses it (19 scripts, member call counts from a source scan)

| Consumer | Members used |
|---|---|
| `GarageComponents` | Colour 51, Label 26, Corner 15, Button 5, StrokeWidth 5, Panel 2, Font 2, SetCorner, FormatMoney, ProjectEconomy, MetricLabel, ConfirmationModal |
| `RaceEntryPresentationClient` | Label 41, Panel 20, Button 15, AssetValue 4, Corner 3, AttachResponsiveScale 1 (Colour/Layout/Type through local `C`/`L`/`T`) |
| `RaceTimeTrialResultCoachClient` | Label 26, Panel 2, Button 2, Corner 2, AssetValue 2, AttachResponsiveScale 1 |
| `GarageWorkspaceUI` | Colour 23, Label 7, Corner 6, Button 4, StrokeWidth 2, BindReplicatedCash 1 |
| `RaceSessionPresentationClient` | Label 13, Button 4, Panel 2, Corner 2, SetCorner 1 |
| `RaceBrowserClient` | Label 11, Panel 4, Button 3, AssetValue 2, Asset 2, Corner 2, AttachResponsiveScale 1 |
| `GarageBrowserUI` | Colour 11, Button 4, Label 2, StrokeWidth 2, BindReplicatedCash 1 |
| `OwnedGarageBrowserUI` | Label 9, Asset 5, Button 3, Panel 1, AttachResponsiveScale 1 |
| `FullMapUI` | Label 7, Button 7, Panel 2, Corner 2, Stroke 1 |
| `ActivityClient` | Label 9, Button 3, Panel 1, FormatMoney 1 |
| `GarageUI` | Colour 5, Button 4, Label 3 |
| `OnboardingClient` | Label 5, Panel 3, Button 1, Corner 1 |
| `InitialLoadingAndStartScreenClient` (ReplicatedFirst) | Colour 7, Button 2, Asset 1, Font 1 |
| `GarageInteriorModeUI` | Colour 7, Label 1, Corner 1, Asset 1 |
| `RaceQueueClient` | Label 3, Panel 1, Button 1 |
| `RaceCountdownPresentationClient` | Label 2, Corner 1 |
| `OwnedGarageWorkspaceUI` | Asset 1 |
| `DesktopFreeRoamHudUI`, `MobileFreeRoamHudUI` | Passed whole as the components argument to `Foundation.Confirmation` (lines 533 and 255) |

`AttachResponsiveScale` (the 1200x720 scale) has four callers: `RaceBrowserClient` 492, `RaceEntryPresentationClient` 849, `RaceTimeTrialResultCoachClient` 205, `OwnedGarageBrowserUI` 14.

### 1.4 Scaling mechanism: `AttachResponsiveScale` (lines 155-175)

```
edgeX = max(48, viewport.X * Layout.DesktopEdgeBufferXRatio)   -- 0.10
edgeY = max(48, viewport.Y * Layout.DesktopEdgeBufferYRatio)   -- 0.08
fitX  = (viewport.X - 2*edgeX) / Layout.ShellWidth             -- 1200
fitY  = (viewport.Y - 2*edgeY) / Layout.ShellHeight            -- 720
scale = clamp(min(fitX, fitY), Layout.ResponsiveScaleMin, Layout.ScaleMax)   -- 0.55 .. 1.15
```

Viewport is `workspace.CurrentCamera.ViewportSize`. Recomputed on that camera's `ViewportSize` change. It does not rebind if `CurrentCamera` changes and is never disconnected.

Computed results (live config):

| Viewport | Scale | Shell px | Share of screen | 14 px text | 10 px text | 48 px button |
|---|---:|---|---|---:|---:|---:|
| 1280x720 | 0.84 | 1008x605 | 79% x 84% | 11.8 | 8.4 | 40.3 |
| 1366x768 | 0.896 | 1075x645 | 79% x 84% | 12.5 | 9.0 | 43.0 |
| 1920x1080 | 1.15 (clamped from 1.26) | 1380x828 | 72% x 77% | 16.1 | 11.5 | 55.2 |
| 2560x1440 | 1.15 (from 1.68) | 1380x828 | 54% x 58% | 16.1 | 11.5 | 55.2 |
| 3440x1440 | 1.15 (from 1.68) | 1380x828 | 40% x 58% | 16.1 | 11.5 | 55.2 |
| 3840x2160 | 1.15 (from 2.52) | 1380x828 | 36% x 38% | 16.1 | 11.5 | 55.2 |

The clamp is reached at a viewport height of about 986 px. Above that the menu is a fixed 1380x828 block in the centre.

### 1.5 Config read
`Config.UI.Racing.Colours` (12 values), `.Layout` (17 values), `.Typography` (6), `.Assets` (12). Live values:

- Colours: `Danger 196,57,75`; `Disabled 81,88,99`; `ElectricBlue 25,116,255`; `Muted 163,171,184`; `Outline 244,46,151`; `OutlineSoft 214,74,175`; `Panel 15,19,24`; `PanelBlue 8,42,84`; `PanelDeep 9,12,16`; `PanelSoft 24,29,36`; `Telemetry 43,225,218`; `Text 246,248,252`.
- Layout: `BrowserListFraction 0.38`, `CornerRadius 5`, `DesktopEdgeBufferXRatio 0.1`, `DesktopEdgeBufferYRatio 0.08`, `FooterHeight 72`, `Gap 16`, `HeaderHeight 64`, `MobileBreakpoint 900`, `OuterPadding 24`, `PanelTransparency 0.08`, `ResponsiveScaleMin 0.55`, `ScaleMax 1.15`, `ScaleMin 0.72`, `ShellHeight 720`, `ShellStrokeWidth 2`, `ShellWidth 1200`, `StrokeWidth 1.5`.
- Typography: `Body 14`, `Button 14`, `Caption 11`, `Heading 22`, `Metric 22`, `FontFamily rbxasset://fonts/families/Michroma.json`.
- Assets: `MedalAtlas rbxassetid://109150933268171` (cell 512, sheet 1024), `RacingIconAtlas rbxassetid://79062219140152` (cell 256, sheet 1024), `DefaultMapImage`, `DefaultTrackImage`, and four empty `*Medal` strings.

Unused by any script (scan of all 221 scripts): `Layout.MobileBreakpoint`, `Layout.ScaleMin`, `Layout.StrokeWidth`, `Assets.DefaultMapImage`, `Assets.DefaultTrackImage`, `Assets.GoldMedal/SilverMedal/BronzeMedal/PlatinumMedal`, `Assets.MedalAtlasSize`, `Assets.RacingIconAtlasSize`. `Config.UI.RaceBrowser` (4 waypoint values) is read by no script.

Through `ResponsiveUIFoundation`: `Config.UI.Theme` values `CornerScaleDesktop 0.7`, `CornerScaleMobile 0.5`, and stroke widths that fall back to script defaults (Glow 3 desktop / 2 mobile, Emphasis 1.5 / 1.25, Structural 1.2 / 1). So `CornerRadius 5` renders as 3.5 px on desktop and 2.5 px on touch.

### 1.6 Input
`Button` only handles `MouseEnter` and `MouseLeave`. No pressed state, no disabled styling, no gamepad focus styling, no `SelectionImageObject`.

### 1.7 Per-frame work and cost
None per frame. Cost is per build:
- `Panel` = 4 instances (Frame, UICorner, 2 UIStroke); with `NoStroke` 2.
- `Button` = 7 instances (TextButton, UICorner, bevel Frame, its UICorner, UIGradient, 2 UIStroke) and 2 connections.
- Every token read is a `FindFirstChild` + `IsA` (no cache). Every label does a `pcall` + `Font.new` (line 49-51).

### 1.8 Hard-coded style
- Line 46: `Enum.Font.GothamBold` / `Gotham`. Line 47: Michroma literal as the fallback family.
- Line 21: white fallback colour. Lines 63, 106, 120, 135, 142-143, 150-151: literal transparencies (0.18, 0.82, 0.08, 0.02, 0.7, 0.12).
- Line 122: default button size 160x48. Line 164: fallback viewport 1920x1080.
- Via `Foundation.ApplyBevel` (Foundation 90): grey `95,95,95`.

### 1.9 Defects
- **Hover changes a button for good** (lines 63 and 150): a stroke is created at transparency 0.18 but `MouseLeave` sets 0.12. After one hover a button's outline is brighter than its neighbours.
- **Hover wipes caller state** (lines 146-152): `MouseLeave` restores the construction colour, so any selected state the caller applied is lost. Race entry works around it with `task.defer(updateTabs)` (entry lines 857-868).
- **`NoGlow` is ignored by `Button`** (lines 133-136): only `Panel` honours it. Race entry's dropdown options pass `NoGlow = true` (entry line 646) and still get a pink glow stroke.
- **Bold is asked of a single-weight family** (line 50): Michroma ships one weight as far as known, so Heading/Button/Metric roles are unlikely to differ from Body by weight. Not verified in Play.
- **ZIndex arithmetic** (line 126, `parent.ZIndex + 2`): written for `ZIndexBehavior.Global`, which is what `Instance.new("ScreenGui")` gives (confirmed in Studio). Layering is by absolute numbers across the whole ScreenGui.
- **Scale clamp** (line 169): see 1.4. Also reads `ResponsiveScaleMin`, while a different unused `ScaleMin` sits beside it in config.
- **Two UIStrokes per panel and per button** as the "glow": about 40 UIStrokes on the time trial setup page. The new style removes structural strokes.

### 1.10 Seam
Because 19 scripts draw through `Colour`, `Font`, `Panel`, `Button`, `Label`, `Corner` and `Stroke`, a style branch inside this module would reskin colours, font and corners game-wide without touching consumers. It cannot deliver the new style on its own:
- Old tokens do not map one-to-one to the new roles. `Telemetry` cyan is used for at least five different meanings in race entry alone (section headings 526/535/554/561, prize money 458/756, times 530/557/779, selection 373, focus). The new sheet splits these into White, Yellow (cash) and Cyan (live values).
- Geometry, scaling and the hard-coded literals stay as they are.
- It edits a script that the backup depends on.

Recommended: leave `RacingUIComponents` byte-identical as the old kit and build a new kit module beside it (see section 5).

---

## 2. RacingMobileScaledDesktopLayout

### 2.1 Purpose and lifecycle
Fits a desktop-reference shell into a touch viewport with one `UIScale`. Library; no `start`. `Attach(shell)` keeps one record per shell in a weak table (line 8), cleans up a previous record for the same shell (lines 22-23), and disconnects everything when the shell leaves the DataModel (lines 81-83). This is the only one of the four scripts with real cleanup.

### 2.2 API
- `Layout.IsEnabled(touchDevice)` (15-17): `touchDevice == true and config:GetAttribute("Enabled") ~= false`.
- `Layout.Attach(shell)` (19-86): returns the `UIScale` named `MobileScaledDesktopScale`.

Callers: `RaceBrowserClient` 26/487, `RaceEntryPresentationClient` 30/844, `RaceTimeTrialResultCoachClient` 27/205, `OwnedGarageBrowserUI` 14.

### 2.3 Mechanism (lines 37-58)

```
availableWidth  = viewport.X - 2*SafeSide
availableHeight = viewport.Y - SafeTop - SafeBottom
scale = clamp(min(availableWidth/ReferenceWidth, availableHeight/ReferenceHeight), ScaleMin, ScaleMax)
shell.AnchorPoint = (0.5, 0.5)
shell.Size        = fromOffset(ReferenceWidth, ReferenceHeight)
shell.Position    = fromOffset(SafeSide + availableWidth/2, SafeTop + availableHeight/2)
```

It overwrites the shell's AnchorPoint, Size and Position on every update, so it is the geometry owner of the shell on touch devices. Updates on camera `ViewportSize`, on `Workspace.CurrentCamera` change (rebinds), and on any of seven config attribute changes.

### 2.4 Config
`Config.UI.Racing.MobileScaledDesktop` attributes, live: `Enabled true`, `ReferenceWidth 1200`, `ReferenceHeight 720`, `SafeTop 72` (script fallback 84), `SafeBottom 10`, `SafeSide 10`, `ScaleMin 0.25`, `ScaleMax 1`.

Computed results:

| Device (landscape) | Scale | Shell px | 14 px text | 10 px text | 48 px button | 44 px lap +/- |
|---|---:|---|---:|---:|---:|---:|
| 667x375 | 0.407 | 488x293 | 5.7 | 4.1 | 19.5 | 17.9 |
| 844x390 | 0.428 | 513x308 | 6.0 | 4.3 | 20.5 | 18.8 |
| 932x430 | 0.483 | 580x348 | 6.8 | 4.8 | 23.2 | 21.3 |
| 1024x768 tablet | 0.837 | 1004x602 | 11.7 | 8.4 | 40.2 | 36.8 |
| 1180x820 tablet | 0.967 | 1160x696 | 13.5 | 9.7 | 46.4 | 42.5 |

On a phone the shell uses about 62% of the available width; the height is the limit.

### 2.5 Defects
- **Phone result is unreadable and untappable** (design, lines 43-57): see the table.
- **Safe area is three hand-typed numbers** (lines 45-47), not `GuiService:GetGuiInset()`, `ScreenGui.ScreenInsets` or the device safe area.
- **Coordinate spaces are mixed** (lines 42, 56): size comes from the camera viewport, but the offset position is applied inside a ScreenGui that has `IgnoreGuiInset = true` (device safe insets). On a notched phone the ScreenGui origin is inset, so the shell would sit off-centre by the left inset. Not verified in Play.
- **Chosen by `TouchEnabled`, not by size** (line 16): a touchscreen laptop gets the phone rules (72 px top reserve, maximum scale 1.0).
- `IsEnabled` is read once at start-up by callers; the `Enabled` attribute is not reactive.

### 2.6 Seam
Self-contained and safe to leave untouched. A new layout helper should replace it for the new views (anchored clusters, real insets) rather than extend it.

---

## 3. RaceBrowserClient

### 3.1 Purpose and lifecycle
The race menu: list of events on the left, detail on the right, EXIT / SET ROUTE / TELEPORT.

- Started by `StarterPlayer.StarterPlayerScripts.ClientBase` through `Core.ClientLifecycle.start`; entry `RaceBrowserClient`, dependencies `{}` (ClientBase lines 32-33).
- `Client.start()` (lines 4-616) is guarded by a `state` variable (`starting` / `ready` / `failed`); a second call asserts.
- `start` builds the ScreenGui once (line 610) and connects `OpenRaceBrowser` (line 606).
- No stop, no cleanup. Kept for the session: 1 bindable connection, 3 footer click connections, 6 hover connections, 1 camera connection (desktop) or the mobile layout record. Per render: 1 click connection per list row, dropped when the row is destroyed.

### 3.2 Instance tree

```
PlayerGui.RaceBrowser            ScreenGui  DisplayOrder 170, IgnoreGuiInset true, ResetOnSpawn false,
                                            ZIndexBehavior Global (engine default)        lines 459-464
  Overlay                        Frame      full screen, black 0.38, Visible false        466-473
    RacingShell                  Panel      1200x720, centred, ClipsDescendants, stroke 2 475-493
      ResponsiveScale | MobileScaledDesktopScale   UIScale
      Title                      Label      "RACE BROWSER", x 24, height 64               496-503
      (divider)                  Frame      1 px at y 64                                  505-511
      Content                    Frame      x 24, y 88, size (1,-48),(1,-168) = 1152x552  515-520
        AvailableEvents          Frame      width 0.38 - 8                                524-530
          EventList              ScrollingFrame  AutomaticCanvasSize Y                    531-541
            CardContent          Frame      AutomaticSize Y, UIListLayout, cards          542-549
              Event_<RouteId>    Panel      height 126; GradientOverlay, Select button,
                                            Thumbnail 162x126, three labels                330-374
        EventDetail              Frame      width 0.62 - 8                                551-556
          TrackImage             Panel      hero, height 240, name label over it          242-249
          TrackMap               Panel      lower left, 56% wide                          254
          EventDetails           Panel      lower right; heading + 5 fact rows            255-319
      Status                     Label      red, anchored above the footer                558-569
      Exit / SetRoute / TeleportToStart     Button x3, 48 tall, y = bottom - 64           574-603
```

### 3.3 Scaling and layout
- Desktop: shell `fromOffset(ShellWidth, ShellHeight)` + `UI.AttachResponsiveScale` (491-492).
- Touch with scaled desktop (live): `MobileScaledDesktop.Attach(shell)` (487).
- Touch without it (dead with live config): shell `(1,-16),(1,-16)`, no UIScale, literal touch sizes (489).
- Inside the shell: header, padding, footer and row sizes are offsets; the list/detail split and the map/details split are scale fractions (0.38, 0.56) with offset gutters.
- Text: fixed `TextSize` everywhere, scaled only by the shell UIScale. No `TextScaled`, no `UITextSizeConstraint`, no `AutomaticSize` on text.
- Viewport change: UIScale recomputed. Nothing is rebuilt.

### 3.4 Config read
- `Config.UI.Racing` through `UI.Colour/Layout/Type/AssetValue`: colours `Danger, Disabled, Muted, Outline, Panel, PanelBlue, PanelDeep, PanelSoft, Telemetry, Text`; layout `BrowserListFraction, CornerRadius, FooterHeight, Gap, HeaderHeight, OuterPadding, PanelTransparency, ShellHeight, ShellStrokeWidth, ShellWidth`; type `Body, Caption, Heading`; assets `RacingIconAtlas, RacingIconCellSize`.
- `Config.UI.Racing.MobileScaledDesktop` through the layout module.
- `Config.Racing.TimeTrialCatalog` and `Config.Racing.RaceCatalog` children (Folder or Configuration; attribute `EventId`) (lines 70-94). Live: 2 events each (`ShiftedCanalSprint`, `ShowroomLoop`), so the list has 2 rows.
- `RaceConfigReader.GetEventSummary(eventId, mode)` fields used: `RouteId, DisplayName, RouteDisplayName, RouteType, Laps, CheckpointCount, MinPlayers, MaxPlayers, BaseReward, EventId, TrackImage, MapImage`.

### 3.5 Remotes, bindables, state, API
- Public API: `Client.start()` only.
- Listens: `PlayerScripts.Runtime.UI.OpenRaceBrowser` (BindableEvent) toggles open/closed (606-608). Fired by `DesktopFreeRoamHudUI` 883 and `MobileFreeRoamHudUI` 314.
- Calls: `Remotes.Racing.RaceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {EventId, Mode})` (427). Server handler is `RaceTeleportServer` behind `Net.invoke`, capacity 10, refill 2.
- Fires: `Runtime.Racing.RaceTransitionRequest` with `Step` = `FadeOut`, `FadeIn`, `RestoreCamera` (388-395, 423-440); `Runtime.UI.FreeRoamVehicleExited` (383-386); `Runtime.UI.FreeRoamHudPresentationMode` with `{Owner = "RaceBrowser", Active, KeepTelemetry = false}` (397-401); `Runtime.UI.ShowTopNotification` ("ROUTE SET: ...", 2.2) (452-453).
- Calls module: `RouteGuide.SetDestinationById(selected.Key, "Player")` (446).
- Local state: `rows`, `selected`, `teleportBusy`; the browser always reopens on the first sorted row (105).

### 3.6 Input
Mouse and touch through `MouseButton1Click` only (375, 583, 593, 603). No keyboard (no Escape to close), no gamepad, no `GuiService` selection, no `ContextActionService`. List rows have no hover feedback. The overlay and shell are non-Active Frames, so pointer input that misses a button is not sunk (not verified in Play).

### 3.7 Per-frame work and rebuilds
- No per-frame or polling work. `RunService` is required and unused; `suppressionHeartbeat` (line 50) is declared and never assigned.
- Persistent tree: about 37 instances.
- Each open (414): `buildRows()` (one `GetEventSummary` per catalog entry), `renderList()`, `renderDetail()`.
- Each row click (375-379): destroys and rebuilds the whole list and the whole detail. List row is about 15 instances; detail about 39. Today (2 routes) that is about 70 instances per click; it grows as `15N + 40`.

### 3.8 Mobile and touch
With live config a phone sees the desktop tree at about 0.43 scale (section 2.4). The legacy touch branch would also disable every other ScreenGui in PlayerGui and watch `ChildAdded` (407-410); with live config all devices use `FreeRoamHudPresentationMode` instead.

### 3.9 Hard-coded style (representative)
- Colours: 208 white overlay, 216 white to `95,95,95` gradient, 468 black scrim (1 `fromRGB`, 3 `Color3.new`). 34 token reads through `C()`.
- Text: 10 `TextSize` sites; desktop mostly tokens (`Heading`, `Body`, `Caption`), literal 16 at 265; touch literals 10, 12, 13, 16.
- Sizes: hero 240 (241), row 126 and thumbnail 162 (332, 348), fact row 40 and icon 33 (276-277), buttons 48 at y -64 (571-578), status 18 (562), icon optical offsets per glyph in a table (146-155), strokes 2 and 1.2 (336).
- Strings: `RACE BROWSER`, `EVENT DETAILS`, `TELEPORT`, `SET ROUTE`, `EXIT`, separators with a bullet.

### 3.10 Defects
- **Own money formatter** (61-68) instead of `UI.FormatMoney`; the style sheet requires the compact formatter to be preserved.
- **Fractional pixel geometry**: footer thirds `third = -(2*pad + 2*gap)/3 = -26.67` (573-598) give 373.33 px buttons at fractional x; list width `0.38 * 1152 - 8 = 429.76` (529). Edges land between pixels before the UIScale is even applied.
- **Status text overlaps the buttons** (558-569): status spans y 644-662 from the shell top; buttons start at 656. Line 561's position is dead (overwritten at 568).
- **Footer geometry differs from race entry**: bottom margin 16 px here (buttonY -64, height 48) against 24 px in entry; `Layout.FooterHeight` (72) is used here and hard-coded 48 in entry; button text 14 here, 13 there.
- **Hero title has no backing** (243-249): the name is drawn straight over the track image. Race entry uses a shaded title strip for the same job.
- **No close path except the HUD toggle and EXIT**; opening race entry does not close the browser, so both overlays can be open (DisplayOrder 170 under 180) with both presentation owners active.
- **`task.wait(0.25)` then an unbounded `InvokeServer`** inside the click handler (424-428): no timeout; the button reads TELEPORTING... until the server answers.
- Divider and several frames are unnamed; `kit`, `shared`, `racingModules`, `uiModules`, `controllers`, `racingRemotes` are unused locals.

### 3.11 Seam
State and logic (reusable as-is by a new view, but only by copying, since nothing is exported):
- `catalogEvents`, `addMode`, `buildRows` (70-106): row model `{Key, DisplayName, TimeTrial, Race, Primary}`.
- `mediaFor`, `availabilityText`, `routeDescriptor` (180-202) and the `facts` table (267-274).
- `teleportSelected` (416-441) and `routeSelected` (444-454): the exact remote, transition and notification sequence.
- `publishPresentation` / `setOpen` (397-415).

View construction: `imageSlot`, `detailIcon`, `cardGradient`, `renderDetail`, `renderList`, `buildGui`.

A new view module can call the same remote, bindables, `RaceConfigReader` and `RouteGuide`. Nothing server-side changes.

Must stay single-owner:
- ScreenGui name `RaceBrowser` (the script destroys any existing one at 457-458; `OnboardingClient` 211 and 469 look it up by name).
- The one listener on `OpenRaceBrowser` (two listeners would open two menus).
- `FreeRoamHudPresentationMode` owner string `"RaceBrowser"`.
- The teleport busy guard and the `RaceBrowserTeleportInvoke` call.

Names other scripts depend on: `OnboardingClient` resolves `CardContent` (N1, line 195) and `TeleportToStart` (N6, line 195) inside this screen, and treats the first visible child of the ScreenGui as the screen root (136-141).

---

## 4. RaceEntryPresentationClient

### 4.1 Purpose and lifecycle
The race entry menu opened at a race start: TIME TRIAL and RACE tabs, tier rail, track map, lap selector, prize, personal best, medal targets, records page with a global top 20, and vehicle selection.

- Started by `ClientBase`; entry `RaceEntryPresentationClient`, dependencies `{LoadingTransitionUI}` (ClientBase lines 38-39).
- Line 1 requires `Garage.GarageCatalogClient` at module load.
- `Client.start()` guard as in the browser. Builds the ScreenGui once (894) and connects `RaceEntryPresentationRequest` (880).
- No stop, no cleanup. Kept for the session: 1 bindable connection, 2 tab click connections, 4 tab hover-repair connections plus 4 shared hover connections, 1 scale connection.

### 4.2 Instance tree

```
PlayerGui.RaceEntryPresentation  ScreenGui  DisplayOrder 180, IgnoreGuiInset true, ResetOnSpawn false,
                                            ZIndexBehavior Global                          lines 827-832
  Frame (overlay, unnamed)       black 0.38, Visible false                                 833-839
    Panel (shell, unnamed)       1200x720, centred, ClipsDescendants                       840-850
      ResponsiveScale | MobileScaledDesktopScale
      Label (header title)       x 24, width 0.35, height 64                               852
      Button x2                  TIME TRIAL, RACE tabs, 160 wide, centred                  855-856
      Frame (divider)            y 64                                                      872
      Frame (content)            x 24, y 88, 1152 x 520                                    876
      Frame (footer)             x 24, bottom 24, 1152 x 48                                877
```

Pages (rendered into `content` and `footer`):

- **Time trial setup** (683-813): tier rail `TierE..TierS` (52 tall); `TimeTrialMapColumn` with `TrackMap`, shaded title, `LapSelector` (`LapControlRow`: minus, text, plus); `TimeTrialRightColumn` with `PrizeSummary` (tier badge, prize, `DailyBonus`), `PersonalBest`, `MedalTargets` (4 rows). Footer: EXIT | NEXT.
- **Race setup** (400-489): `RaceInformationStrip`; `RaceLeftColumn` map; `RaceRightColumn` with `RaceFormat`, `PlacementPrizes` (1ST, 2ND, 3RD rows), `RaceStats` (2 panels). Footer: EXIT | CHOOSE VEHICLE.
- **Records** (491-612): read-only tier rail; `RecordsLeftColumn` with `WorldRecord`, `RecordMedalTargets`, `YourRecord`; `RecordsRightColumn` with `GlobalTop20` (header row, `LeaderboardRows` ScrollingFrame, up to 20 rows). Footer: BACK | CHOOSE VEHICLE.
- **Vehicles** (614-681): `VehicleContext` strip; `Category` and `Sort` dropdowns; `VehicleGrid` ScrollingFrame with `UIGridLayout`, 4 columns, cell height 190, cards from the shared `GarageComponents.VehicleCard`. Footer: BACK | START TIME TRIAL or JOIN RACE.

Flow today: time trial is Setup, then Records, then Vehicles. Race is Setup, then Vehicles. The style sheet lists "Exit, View records, Choose vehicle" on one screen, which is a navigation change, not only a restyle.

### 4.3 Scaling and layout
Same shell mechanism as the browser (843-850). Inside the shell: two 50% columns with `gap/2` offsets; almost every height, y position, inset and text size is an offset literal chosen for the 1200x720 canvas. Fixed `TextSize`, no `TextScaled`, no text constraints. Viewport change only recomputes the UIScale.

### 4.4 Config read
- `Config.UI.Racing` tokens: colours `Disabled, Muted, Outline, OutlineSoft, Panel, PanelBlue, PanelDeep, PanelSoft, Telemetry, Text`; layout `CornerRadius, Gap, HeaderHeight, OuterPadding, PanelTransparency, ShellHeight, ShellStrokeWidth, ShellWidth`; type `Body, Caption, Heading`; assets `MedalAtlas, MedalAtlasCellSize, RacingIconAtlas, RacingIconCellSize`.
- `Config.UI.Racing.Copy.DailyBonusDisplay` ("2X") (33, 293-296, 759).
- `Config.Racing.Rewards.Race` attributes `GoldRewardMultiplier, SilverRewardMultiplier, BronzeRewardMultiplier, RewardRoundToNearest, MinReward, MaxReward` (103-108). Live: 1, 0.85, 0.65, 250, 0, 50000.
- `Config.Racing.RaceCatalog.<eventId>` attribute `TrackLengthMiles` (337-341). Live value is 0, so the strip shows "-- MI".
- `RaceConfigReader.GetEventSummary` and `RaceConfigReader.GetTimeTrialMedals(eventId, tier)`.
- Fallback art: `ReplicatedStorage.Assets.VehiclePreviews.Categories.*.COCKPITS_ReplaceAssetsHere.<model>` attributes `MenuImage, DisplayName, CockpitId` (247-258).

### 4.5 Remotes, bindables, state, API
- Public API: `Client.start()` only.
- Listens: `PlayerScripts.Runtime.Racing.RaceEntryPresentationRequest` (880). Fired by `RaceEntryMenuClient` 92 when the server sends `RaceEvent` `{Type = "OpenRaceEntry"}` (from `TimeTrialServer` 1271). Payload fields used: `Summary, EventId, RaceEventId, TimeTrialEventId`; summary fields `DisplayName, MinLapCount, MaxLapCount, DefaultLapCount, Laps, BaseReward, CheckpointCount, TrackLengthMiles, EventId`.
- Fires: `Runtime.Racing.RaceEntryLegacyAction`:
  - `"Close"` (481, 807).
  - `"StartSelectedVehicle", {Mode, EventId, VehicleId, CockpitId, Tier, LapCount}` (679).
  - Consumers: `RaceEntryMenuClient` 63-85 (spawns the vehicle, then `StartStagedTimeTrial` or the race queue) and `RaceLifecyclePresentationClient` 242-252 (entry-open tracking).
- Fires: `Runtime.UI.FreeRoamHudPresentationMode` `{Owner = "RaceEntry", Active, KeepTelemetry = false}` (343-347).
- Server calls:
  - `Remotes.Garage.GarageInvoke` `"GetInitial"` through `GarageCatalogClient.Fetch` (73, 213), on every open.
  - `Remotes.Racing.RaceRequest` `"GetTimeTrialPersonalBest", {EventId, VehicleTier}` (516, 763).
  - `Remotes.Racing.RaceRequest` `"GetTimeTrialLeaderboard", {EventId, VehicleTier, Limit = 20}` (521).
- Local state: `payload, summary, selectedMode, selectedTier, selectedLap, currentPage, selectedVehicleId, vehicleCategory, vehicleSort, ownedTiers, garageProfile, garageCatalog`.

### 4.6 Input
`MouseButton1Click` on all kit buttons; `Activated` on vehicle cards (665). No keyboard, no gamepad, no `GuiService` selection, no `ContextActionService`. Read-only tier buttons are set non-Active and non-Selectable (396). Dropdowns do not close on an outside click and both can be open together.

### 4.7 Per-frame work and rebuilds
- No per-frame or polling work. `RunService` unused; `suppressHeartbeat` (70) never assigned.
- Persistent tree: about 25 instances.
- `render()` (815-822) clears `content` and `footer` and rebuilds the current page. It runs on: open, either tab, each tier button, NEXT, BACK, CHOOSE VEHICLE, each dropdown option, **each vehicle card click** (665). Only the lap plus and minus update a label in place (737-738).
- Estimated instances per page:
  - Time trial setup: about 138 (about 40 UIStrokes on screen), plus 1 server round trip.
  - Race setup: about 97, no server call.
  - Records: about 211 with 20 leaderboard rows, plus 2 sequential server round trips.
  - Vehicles: about 44 + 17 per vehicle (about 250 for 12 cars), 5 connections per card, rebuilt on every card click.
- `racingVehicleRows()` (262-291) walks the whole catalogue twice per vehicle (once in `vehiclePresentationForId`, once for the category) and is called again on Start (678).
- The personal best is fetched on Setup and again on Records for the same tier; nothing is cached.

### 4.8 Mobile and touch
Same as the browser: desktop tree at about 0.43 on a phone. Three real differences on touch devices: the scale module, `RatingScale` 1 instead of 1.5 on vehicle cards (664), and the foundation's smaller corners and thinner strokes. The 164 `touch and` branches are dead with live config.

### 4.9 Hard-coded style (representative)
- **Tier palette** (41-45): six `Color3.fromRGB` literals (E `145,162,171`; D `93,202,126`; C `71,195,202`; B `79,139,238`; A `178,92,255`; S `224,78,255`). Used for tier buttons (390-393), the tier badge (750) and card rating badges (664). Duplicates the tier colours other screens define.
- **Medal names** (797): Gold `255,205,55`, Bronze `220,132,75`.
- Gradient grey `95,95,95` (127); white and black `Color3.new` at 118, 154, 834.
- Total: 9 `fromRGB`, 4 `Color3.new`, 134 token reads.
- **Text sizes**: 56 `TextSize` sites; only 3 use typography tokens (145, 394, 852). Desktop literals in use: 9, 10, 11, 12, 13, 14, 15, 16, 22, 26, 27, 28, 30, 34. That is 14 sizes on one screen family against 5 roles in config. Examples: 30 map title (165), 11 subtitle (166), 12 strip (420), 13 footers (478, 599, 668, 802), 10 leaderboard (564, 593), 9 dropdown caption (638), 34 tier letter (751), 27 prize (756), 26 times (557, 779).
- **Sizes**: tier rail 52 (495, 701), body offset 68 (423, 499, 705), format 88 (440), stats 76 (446), prize row 54 (452), world record 122 (524), targets 202 (533), summary 112 (746), PB 112 (769), lap panel 84 and controls 320x44 (716-722), context 44 (627), filter 60 (633), card cell 190 (657), tabs 160 wide (853), footer 48 (874).
- Via the shared vehicle card (`GarageComponents` 108-139): selected fill `18,45,54`, name plate `5,8,12`, grey `132,142,145`, `163,171,184`, success green `89,255,102` (the `Success` token it asks for does not exist in `Config.UI.Racing.Colours`).

### 4.10 Defects
- **Stale page on open** (880-892): `setOpen(true)` shows the overlay before `readOwnedTiers()` yields and before `render()` clears `content`. The previous session's last page is visible and its footer buttons are live during the fetch. If that page was Vehicles, START fires `StartSelectedVehicle` with the old vehicle id and the new event id.
- **Render is not re-entrant** (763, 516, 521 yield inside page builders): a tier, tab or card click during a yield starts a second render. The first one resumes, parents its remaining panels to a destroyed column, and adds its two footer buttons to the live footer. Result: duplicate, stacked footer buttons, each firing its handler.
- **No exit while waiting** (803-807 after 763): on time trial setup the EXIT button is created only after the personal-best call returns. `call()` (72-76) has no timeout.
- **Unprotected reader call** (515, 762): `RaceConfigReader.GetTimeTrialMedals` is not wrapped; an error leaves a half-built page without a footer.
- **Dropdown width mixes coordinate spaces** (643): `UDim2.fromOffset(holder.AbsoluteSize.X, ...)` uses a post-scale screen measurement as a pre-scale offset. The option list is narrower than its button at scale 0.84 and 15% wider at 1.15.
- **Layering depends on Global ZIndex** (636-646, ZIndex 30/31/34/80/82): under `Sibling` the vehicle grid would cover the open dropdown.
- **Tier rail is not aligned to the columns** (388-389): the first tile is 4 px wider than the others and the rail ends 4 px short of the content's right edge.
- **Prize block is off-centre** (752-756): the label region runs from x 108 to 104 px from the right, overlapping the Daily Bonus panel by 15 px and sitting about 13 px right of the true centre between the badge and the bonus.
- **Header title collides with the tabs** (852-855, 818): the title box is x 24-444; the tabs start at x 432. "CHOOSE TIME TRIAL VEHICLE" at 22 px Michroma is likely truncated. Not verified in Play.
- **Card size argument is dead** (659, 664): `Size = 260x190` is overridden by the `UIGridLayout` cell (657).
- **Own money formatter** (82-89), not the shared one.
- **Client-side prize arithmetic** (103-108): placement prizes are computed on the client from config. The preview must stay a projection of what the server pays; a new view must reuse this exact rule or a server-supplied figure.
- **"DAILY BONUS 2X" is a static string** (759) from config copy, not state.
- **World-record avatar is a "?" placeholder** (527-528).
- Overlay, shell, content and footer are unnamed (`Frame`, `Panel`), which hurts captures and diagnosis.
- Tabs stay live on the Records and Vehicles pages and silently reset the page to Setup (869-870).

### 4.11 Seam
State and logic (pure or remote-facing; no instances):
- `call` (72-76), `money`, `timeText`, `numberAttribute`, `roundedRacePrize` (82-108).
- `readOwnedTiers` (211-225), `vehiclePresentationForId` (227-260), `racingVehicleRows` (262-291).
- `copyValue`, `pairedEventId`, `browserMedia`, `lapBounds`, `modeSummary`, `raceCatalogAttribute` (293-341).
- `publishPresentation`, `suppressOthers`, `setOpen` (343-363).
- The page state machine (`currentPage`, `selectedMode`, and the transitions inside the click handlers).
- The `StartSelectedVehicle` payload shape (679).

View construction: `gradient`, `imagePanel`, `mapTitleOverlay`, `medalIcon`, `raceDetailIcon`, `updateTabs`, `renderTierRail`, `renderRaceSetup`, `renderRecordsPage`, `renderVehiclePage`, `renderSetup`, `buildGui`. The remote calls sit inside the render functions, which is the cause of the yield defects.

A new view module can use the same bindables and remotes unchanged. `RaceEntryMenuClient` is already a headless bridge and needs no change as long as the action names and payload shape are kept.

Must stay single-owner:
- ScreenGui name `RaceEntryPresentation` (destroyed and recreated by name at 825-826; `OnboardingClient` 212 and 469).
- The one listener on `RaceEntryPresentationRequest`.
- The one sender of `RaceEntryLegacyAction` `"Close"` and `"StartSelectedVehicle"`.
- Presentation owner string `"RaceEntry"`.

Names and texts other scripts depend on (`OnboardingClient` 195-197, 212-214):
- Buttons whose text is exactly `TIME TRIAL` and `RACE` (resolver O1 and the EventMode page signal).
- `TierE`, `TierD`, `TierC`, `TierB`, `TierA`, `TierS` (Q1; `TierE` plus `LapSelector` signal the TimeTrialSetup page).
- `PrizeSummary` (Q5), `MedalTargets` (Q8), `LapSelector` (Q4).
- `RaceFormat` or `DetailColumn` (P1; `RaceFormat` signals the RaceSetup page).

A new view must keep these names and texts, or the onboarding resolvers must change in the same delivery.

### 4.12 Vehicle selection and the shared card
Vehicle selection does use the shared card: `GarageComponents.VehicleCard(parent, props)` (`GarageComponents` line 108). The same function is used by `DesktopFreeRoamHudUI` (744, 775), `MobileFreeRoamHudUI` (292, 301) and `GarageBrowserUI` (120). Props passed here: `Name, DisplayName, Image, Rating, RatingColor, Selected, Owned, SemanticState ("Owned" | "Unavailable"), RatingScale, Size, NameTextSize, UnavailableText, Active, Selectable`. The card sets attributes `CanonicalGarageCard`, `CanonicalVehicleCard`, `VehicleCardSemanticState`, `VehicleOwned`, `VehicleSelected`, `VehicleFocused`, which onboarding and the garage use.

The style sheet names this contract `GarageReplacementComponents.VehicleCard`. No module of that name exists in Studio; the live one is `GarageComponents.VehicleCard`.

Everything else on these screens (event row, tier tile, tabs, fact row, medal row, leaderboard row, dropdown, lap stepper, image panel with title shade) is built inline and has no shared component. `imagePanel`/`imageSlot`, the gradient helper and the icon-atlas helper are duplicated between the browser and entry scripts.

---

## 5. Recommended seam for a switchable new presentation

1. **Leave all four scripts byte-identical.** They are the backup.
2. **New kit module** beside `RacingUIComponents` (for example `Modules.Game.UI.PulseUI`), reading `Config.UI.Style`. It should own: Panel with hairlines, Tile, EventRow, Tabs, Button / MainButton / BuyButton / Destructive, TierBadge, FactList, MedalRow, LeaderboardRow, Dropdown, Stepper, ImagePanel with title, and the layout helper. Give buttons real selected, disabled, pressed and focus states so callers stop repairing hover.
3. **New layout helper** to replace both scale functions for the new views: anchored regions, real safe insets, a scale that keeps growing on tall and wide screens, and a phone rule that enforces 48 px targets and an 11 px text floor. The other two users of the 1200x720 shell (`RaceTimeTrialResultCoachClient`, `OwnedGarageBrowserUI`) can adopt it later.
4. **New view modules** with the same `Client.start()` contract, for example `RaceBrowserPulseClient` and `RaceEntryPulseClient`. Put the logic listed in 3.11 and 4.11 into small headless model modules used only by the new views (fetch first, then build; one render token so a late response cannot draw into a newer page). The old scripts keep their inlined copies.
5. **Switch at the composition root.** `ClientBase` resolves each entry's path in one function (lines 105-108). A path map applied there when the style is on swaps `RaceBrowserClient` and `RaceEntryPresentationClient` for the new modules. Exactly one of each pair starts, so ScreenGui names, bindable listeners and presentation owner strings stay single-owner. Switching back is the flag.
6. **Flag transport.** `Core.FeatureFlags` lives in `ServerStorage` and no client reads it. The server has to publish the style choice somewhere replicated (an attribute under `ReplicatedStorage.Config.UI.Style`, or a player attribute) before `ClientBase` resolves paths. Takes effect on the next join, as the style sheet already says.
7. **Keep for onboarding:** the ScreenGui names and the child names and button texts listed in 3.11 and 4.11.

## 6. Unknowns

- Nothing was run in Play. Truncation, notch offset, input pass-through and gamepad behaviour are read from source.
- Whether Michroma has a real Bold face.
- Whether `GarageCatalogClient.Fetch` caches `GetInitial` (not read).
- `RaceConfigReader` internals and whether it applies the unused `DefaultMapImage` / `DefaultTrackImage` (the scan found no script naming them).
- Whether the viewport Roblox reports on a scaled Windows display is physical pixels, which decides how small the clamped shell looks at 4K.
- The style sheet's "filter tabs" on the race menu and the three-button race entry footer have no counterpart in the current logic.
