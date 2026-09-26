# Full map, map markers and upright minimap icons (Agent F)

Lane: **Standard**. The change is client-only UI and client route state. It adds no remotes, saved data, economy or server code. Binding contract: [map-markers-contract](../../docs/architecture/map-markers-contract.md). Before-sources for the two HUDs come from `roblox/captures/activities-duels-after/capture.json`; they are byte-identical to `scripts/activities/foundation/*FreeRoamHudUI.lua`.

## Files

| File | Installs as | Role |
|---|---|---|
| MapMath.lua | `ReplicatedStorage.Modules.Game.UI.MapMath` (new) | Pure maths: calibration, world to map and back, minimap placement, edge clamp, zoom and pan clamps, picking. Tested by tests.lua. |
| MapMarkers.lua | `…UI.MapMarkers` (new) | Client registry per the contract (`Set`, `Remove`, `Get`, `All`, `Changed`). Adds `IconAsset(key)` and `IconsChanged`. On first require it registers `Config.UI.MapPois` as `Poi_<name>` and reads icon ids from `Config.UI.MapIcons`. Draws nothing. |
| MapIconLayer.lua | `…UI.MapIconLayer` (new) | Shared renderer: pooled upright icons, fallback badge, EdgeClamp, Pulse, HitTest. Used by both minimaps and the full map. |
| FullMapUI.lua | `…UI.FullMapUI` (new) | Owner of the full map. Started by a new ClientBase entry. |
| DesktopFreeRoamHudUI.lua, MobileFreeRoamHudUI.lua | existing (source ops) | Click or tap on the minimap calls `FullMapUI.Open()`. The ROUTE GUIDE modal is removed. They host a minimap MapIconLayer and hide while `FullMapOpen` is set. |
| spec.json | feature_installer spec | 4 modules, config folders, 5 POIs, 2 HUD sources |
| tests.lua | loopback test | `{failures, results}` |

## Owners

- **FullMapUI** owns:
  - the `FullMap` ScreenGui (DisplayOrder 90);
  - the Player attribute `FullMapOpen`;
  - the waypoint: RouteGuide source `"Waypoint"` (priority 5) plus the MapMarkers id `"Waypoint"`;
  - the M key and the gamepad Back/Select toggle;
  - a GameplayInputGate token while open (`LockGameplayInput`);
  - **`RouteGuide.Update` while the map is open**, because the HUD owners stop stepping then.
- **The HUD owners** keep:
  - the minimap;
  - the minimap RouteGuide renderer;
  - `RouteGuide.Update` while the map is closed.

  They react to `FullMapOpen` by disabling their ScreenGui and closing their own dropdowns and modals. The desktop HUD never closes the onboarding Controls modal, and FullMapUI refuses to open while it is up.
- **Who hides the ActivityHud.** ActivityClient hides it; that step is integrator work (below).
- **Why ClientBase starts FullMapUI.** It is started by ClientBase rather than by a HUD because there are two HUD owners (a touch laptop can run both), and the toggles must work without a click. Each HUD requires the module lazily inside the click handler. It is the same ModuleScript, so both get the same instance and there is no second owner.
- **One player destination at a time.** Setting a waypoint clears the `"Player"` route. When a `"Player"` route becomes active (race browser SET ROUTE), it clears the waypoint. Activity routes (jobs, duels) keep priority, and the waypoint marker stays until they end.

## Flows

**Open.** The map opens from a minimap click or tap, M, or Back/Select.
- M and Back/Select only work while a HUD minimap is visible.
- Opening is refused while any of these is set:
  - GarageSessionActive
  - OwnedGarageInside
  - RaceSessionActive
  - RaceQueueActive
  - DrivingControlsOpen
  - FirstDrivePresentationPending
  - MobileMajorMenuOpen
  - MobileFreeRoamCarMenuOpen
  - OwnedGarageManagementOpen
  - a FreeRoamHudPresentationMode owner
  - a racing vehicle
- On open:
  1. `FullMapOpen = true`.
  2. The view centres on the player at `OpenVisibleStuds`, or at the remembered zoom.
  3. The panel tweens in (scale 0.96 to 1, backdrop fade).

**Close.** The map closes from X, Esc, the Roblox menu opening, B, M, Back, a tap on the backdrop, or a blocking state appearing while it is open. On close:
- `FullMapOpen = false`;
- the input gate is released only after inputs are neutral;
- the other-player markers are destroyed;
- the gui is disabled after the tween.

**Waypoint.**
- **Click or tap empty map:** `RouteGuide.SetDestination("Waypoint", pos, {Label = "WAYPOINT", Priority = 5})` plus `MapMarkers.Set("Waypoint", {Kind = "Waypoint", Icon = "Waypoint", EdgeClamp = true, Priority = 50})`. Y comes from `WaypointY` (101).
- **Click or tap a place, race or job icon:** sets the waypoint on that place, using its label.
- **Click the waypoint again,** CLEAR WAYPOINT, X on the pad, or Backspace/Delete: clears it.
- **Arrival:** `RouteGuide.Arrived` clears the route. FullMapUI then removes the marker; this is wired at start, so it works while the map is closed.

**Legend** (right-hand panel; the LEGEND button toggles it).
- **DESTINATIONS** lists the static POIs plus any `RouteGuide.Destinations()` entry without a matching POI. That covers everything the old ROUTE GUIDE modal listed.
  - Clicking a row sets the waypoint there and pans to it.
  - Clicking the active row clears it.
  - The active row is highlighted (PanelBlue fill, Telemetry stroke).
- **MAP KEY** shows YOU, OTHER DRIVERS and WAYPOINT, then every icon key currently present in MapMarkers (jobs appear when offers exist).
- The legend rebuilds only when its rows change.

**Full-map render** (only while open), in this order:
1. canvas pan and zoom;
2. player arrow, clamped to the view edge;
3. other players, drawn by the shared FreeRoamMapPlayerMarkers in a square host with smoothing off;
4. MapIconLayer;
5. the RouteGuide renderer on the full canvas, with `PixelScale = RouteLineScale` (2) for a thicker line. The renderer's minimap-only edge pip is kept off-screen by passing a virtual `MapSize` and `VisibleStuds` of 1e7.

The route chip shows at the top of the map view.

## Inputs

| Action | PC | Touch | Controller |
|---|---|---|---|
| Open or close | Click minimap, M; Esc, X or the backdrop to close | Tap minimap; X or the backdrop | Back/Select; B closes |
| Pan | Drag; WASD or arrows | One-finger drag | Left stick |
| Zoom | Wheel (about the cursor); Q/E, -/=; +/- buttons | Pinch (about the midpoint); +/- buttons | LB / RB |
| Centre on player | ME button, C | ME button | Y |
| Waypoint | Click (drag threshold 8 px) | Tap (radius 30 px) | A at the centre crosshair |
| Clear waypoint | Click the waypoint, Backspace/Delete, CLEAR WAYPOINT | Tap the waypoint, CLEAR WAYPOINT | X |

- **Touch targets** are at least 44 px when touch-only (`TouchEnabled` and no keyboard).
- **Landscape only.** There is no orientation code.
- **Theme.** All colours are `RacingUIComponents.Colour` tokens, and all buttons, labels and panels are `RacingUIComponents`.

## Config (created by spec.json)

- **`Config.UI.MapPois.<Id>`** has attributes `Label`, `Kind`, `Icon`, `Position` and `Order`, plus `DestinationId` and/or `RouteId`. Entries: Dealership, MyGarage, Customisation, Race_ShowroomLoop, Race_ShiftedCanalSprint.
  - A POI without a Vector3 `Position` is skipped.
  - **Customisation has no Position yet.** The integrator fills it; see `todo` in spec.json.
- **`Config.UI.MapIcons`** holds all 14 contract keys, set to "". An empty value draws a badge with glyphs such as $, G, C, R, TT, T, P, D, W, VS and J.
- **`Config.UI.MapIconLayer`** holds:
  - `MinimapEnabled`, `FullMapEnabled`;
  - icon sizes: minimap 18, mobile minimap 14, full map 26, touch full map 32;
  - `EdgeInset` 11, `Overscan` 12;
  - `PulseSpeed`, `PulseAmount`.
- **`Config.UI.FullMap`** holds:
  - `Enabled`, `DisplayOrder`;
  - zoom: `OpenVisibleStuds` 3600, `MinVisibleStuds` 500, `MaxVisibleStuds` 9000, `ZoomStep` 1.25, `RememberZoom`;
  - pan bounds: `PanMinX` / `PanMaxX` / `PanMinZ` / `PanMaxZ` (the Core district ±2500);
  - `RouteLineScale`, `WaypointY`;
  - input: drag threshold, tap radii, pan speeds, `CentreResponse`, `LockGameplayInput`;
  - presentation: backdrop, tween times, legend options, `DistrictName`.

  Every tunable also has a bounded code default, so the folder is optional.

## Integrator steps (not in spec.json)

1. **ClientBase** (`StarterPlayer.StarterPlayerScripts.ClientBase`, source op from the capture). Add this entry to `entries`, for example after the MobileFreeRoamHudUI entry:
   ```lua
   {name="FullMapUI",path="ReplicatedStorage.Modules.Game.UI.FullMapUI",dependencies={}},
   ```
   No dependencies are needed: the module waits for its own instances. Without this entry, clicking the minimap toasts "MAP NOT AVAILABLE".
2. **ActivityClient** (`ReplicatedStorage.Modules.Game.Activities.ActivityClient`). Directly after the `ActivityHud` ScreenGui is created (the `gui = new("ScreenGui", { Name = "ActivityHud", ...` line), add:
   ```lua
   local function syncFullMap() gui.Enabled = player:GetAttribute("FullMapOpen") ~= true end
   player:GetAttributeChangedSignal("FullMapOpen"):Connect(syncFullMap)
   syncFullMap()
   ```
   ActivityClient sets `gui.Enabled` nowhere else. World beacons are 3D and can stay.
3. **Customisation POI.** Put the `Position` into the Customisation folder op before APPLY.
4. **MapIcons.** Fill the ids after Agent M's PNGs are uploaded. The renderers restyle live on `AttributeChanged`.
5. **Capture roots.** The activities-duels-after capture does not include `Config.UI` or the new module paths. The installer's "already exists" guard therefore does not cover them, so AUDIT in Studio first; the engine still refuses drift.
6. **Optional, after a Play check.** Add the same `FullMapOpen` hide to any other on-screen HUD that shows through the backdrop, such as the MobileDriveControlsClient buttons and FreeRoamVehicleExitButtonClient. Input is already locked by the gate while the map is open.
7. **Docs.** Update docs/route-guide-system.md: the minimap now opens the full map, and the destinations are in its legend.

## Test checklist

**Pure tests.** Serve `scripts/` on 127.0.0.1:8767 and run `scripts/map_ui/tests.lua` in Edit. Expect 0 failures. The tests cover:
- the transform matches RouteGuide's canvas maths and FreeRoamMapPlayerMarkers' minimap maths;
- round trips across rotations and flips;
- edge clamp direction;
- zoom and pan clamps;
- picking.

**Play, PC:**
- [ ] The minimap shows upright POI badges (Dealership $, Garage G, race R). They stay upright while the map rotates, and the waypoint badge sits on the rim when far away.
- [ ] Clicking the minimap opens the full map. The HUD and ActivityHud are hidden, and the car stops taking input.
- [ ] Tiles align with the minimap.
  - The player arrow points the way the car faces.
  - The Dealership and Garage icons sit on their buildings.
  - Clicking a tile point then driving there shows ARRIVED.
- [ ] Drag pans. The wheel zooms about the cursor and stops at the min/max limits and at the bounds.
- [ ] Click empty map: a waypoint icon appears, and a route line (thicker than the minimap's) plus the chip appear. Close the map: the minimap shows the route. Click the waypoint on the map: it clears.
- [ ] Legend: clicking Dealership pans there and sets the route, and the row highlights. Clicking it again clears. Waterfront Sprint and Showroom Loop are listed.
- [ ] Race browser SET ROUTE replaces the waypoint. Setting a waypoint replaces a race-browser route.
- [ ] M toggles the map. Esc, X and the backdrop close it. The HUD returns and driving input resumes after the keys are released.
- [ ] The map cannot open in a garage, a race, the race queue or onboarding Controls. Starting a race while it is open closes it.

**Play, touch** (device emulator, landscape):
- [ ] A tap opens the map. One-finger drag pans, pinch zooms, a tap sets the waypoint and a tap on the waypoint clears it.
- [ ] Buttons are at least 44 px. The legend fits, or starts hidden below a 760 px viewport width, and the LEGEND button shows it.
- [ ] Tapping the backdrop closes the map, and the mobile HUD returns.

**Play, controller:**
- [ ] Back opens the map and the crosshair shows. The stick pans, LB/RB zoom, A sets the waypoint at the crosshair, X clears, Y centres, and B or Back closes.

**Regression:**
- [ ] Other-player dots, the north arrow, rank strip, JOBS, the car panel and Settings are unchanged on both HUDs.
- [ ] No ROUTE GUIDE modal remains.
