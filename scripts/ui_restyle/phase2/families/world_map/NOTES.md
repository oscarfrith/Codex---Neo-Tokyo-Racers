# WorldMap family (F3): notes for the integrator

Status: **generated, not installed, never run.** There is no offline Luau here: every file was desk-checked line by line and
passed a block and bracket balance script; nothing was compiled or executed. Kit v2 did not exist while this was written,
so every kit call is written from `API2.md` and `phase1/API.md` only.

## Files

| File | What |
|---|---|
| `after/…UIPulse.Map.MapCanvas.lua`, `Map.MapIcons.lua`, `Map.MapRoute.lua` | shared map layers; ops in `spec_ops_shared.json` (install with FreeRoam) |
| `after/…UIPulse.WorldMap.FullMapModel.lua`, `FullMapView.lua`, `FullMapClient.lua` | full map owner (entry `FullMapUI`) |
| `after/…UIPulse.World.WorldPromptModel.lua`, `WorldPromptView.lua`, `EventCardView.lua` | world prompt owner (entry `PulseWorldPrompts`) and the event card |
| `after/…UIPulse.Dev.Fixtures.WorldMap.lua` | three gallery items |
| `tests/*_test.lua` | ten pure test files, one per module |
| `contract.json`, `routes.json`, `spec_ops.json`, `spec_ops_shared.json`, `CONTRACT.md` | parity, routes, ops, acceptance contract |

## A. API questions, and the reading used

1. **Who calls `RouteGuide.Update` while the map is open.** The task brief says "the HUD owns it; the map reads state".
   API2 5.3 says the HUD makes no call while `FullMapOpen` "(the map owner calls it then)" and 5.4 keeps the call at
   Classic line 815 ("the map is the one caller while open"). The API is binding, so **the map calls `Update` in its
   step while open** (`FullMapClient`, step 12, one line). If the HUD is to keep calling it with the map open, delete
   that line; nothing else depends on it. Either way there is one caller per frame.
2. **`Input.BindAction` handler shape** is not stated. Used: the ContextActionService shape
   `(actionName, inputState, inputObject) -> Enum.ContextActionResult`, because both Classic handlers return `Pass` or
   `Sink` depending on state. `FullMapPad` is bound on a `Core.ConnectionScope` made per open and destroyed on close
   (assumes `BindAction` unbinds when its scope is destroyed).
3. **Client-made prompts are outside the three listed roots.** `CanonicalDealership/Customisation/DriveIn` sit under
   `Workspace.World.Dealership` (GarageEntranceClient 30-52). A fifth scoped root, `World.Dealership`, is watched.
   `PassengerRidePrompt` and `JobPrompt` hang from vehicles, so `World.Runtime.PlayerVehicles` covers them (assumed:
   the player's own car is in that folder). Any known prompt that shows before it was found is left engine-drawn for
   that one show and made Custom when it hides.
4. **Sized slots and the anchor rule.** A2 2.4 says a child copies the slot's anchor, and also that a child may fill a
   sized slot. For `RightColumn` (anchor 1,0, sized) copying the anchor with `Position = 0` would put the child outside
   the slot. Used: in a sized slot the child keeps anchor 0,0, position 0, and the slot's own width token.
5. **`View.Mount(layer, model, scope)` and two layers.** `FullMapView.Mount` takes an optional fourth argument
   `{PlayerMarkers, MarkerConfig}` (the shared marker module and its config folder, which a view may not look up).
   The map surface is drawn in **`FullMapScrim`** (`layer.ScrimRoot`, full screen, under the chrome), the static
   chrome in **`FullMap`**, and **`FullMapLive.Root` is only the root the frame step is bound to**; it holds no
   instance. Reason: the ladder puts `FullMapLive` above the chrome, and the map must be under it [seen r08]. The
   split still does what PC 5.1 rule 1 wants: a pan re-renders the map gui only.
6. **`PromptActionText`** (A2 5.4 lists it among the zone attributes the card reads). The banner shows the prompt's
   live `ActionText`, which the server sets from that attribute (TimeTrialServer 1312); the attribute is not read.
7. **"Once per show and cached per event."** Used: `GetEntryDetails` once per event and mode per session;
   `GetTimeTrialPersonalBest` once per show (it changes after a run), last value shown meanwhile, skipped when the
   player is on foot (no tier: the server would only answer "Choose a vehicle tier") and for Race zones. The two calls
   run one after the other in one thread, never in parallel. A call that never returns leaves that event's entry busy
   (no more requests for it; the card still draws).
8. **`MapIcons.HitTest(point)`** has no radius argument, so `TapRadiusPixels` / `TouchTapRadiusPixels` are not read;
   the radius is 0.75 of the drawn icon (MapIconLayer's own default).
9. **`Surface.MapIcon` props.** Passed `Tint` always (the marker's `Color`, else the White token) and no `Colour`, so
   a pooled icon never keeps an old tint. Assumes `Tint` alone is accepted and `Set({Icon, Tint})` re-anchors pins.
10. **`Collections.Pool`**: assumed `Take()` returns a made-or-released item and `Release(item)` keeps it parented.
    `MapIcons` hides the item itself before `Release`, so it does not depend on `reset` being called.
11. **`Surface.Panel` with a changing `Height`**: both panels (legend, event card) set `Height` in design units from
    their row count. If `Panel` grows with its content when `Height` is nil, those `Set({Height})` calls can go.
12. **`Surface.KeyCap` with long texts** (`CLICK`, `BACKSPACE`) is assumed to widen (9-slice).
13. **`WorldPromptModel` has no `Changed` signal** (6.2): it is driven by engine signals and returns effects; small
    owner clause of 6.2.

## B. Classic behaviour not reproduced exactly

1. No open and close tween (a tweened `UIScale` is banned); the map shows and hides at once.
2. A press outside the panel no longer closes the map: the Pulse map has no outside.
3. `blocked()` is no longer polled every frame. The eight player attributes, `OwnedGarageManagementOpen`, the
   presentation owners and the current vehicle's `RaceParticipant` / `RaceRunId` close the map from their changed
   signals. `Config.UI.FullMap@Enabled` set false while the map is open no longer closes it until the next open.
4. Config no longer read: `DisplayOrder`, `LegendWidth`, `MobileLegendWidth`, tap radii, `RouteLineScale`, tween
   times, `BackdropTransparency`; all of `Config.UI.MapIconLayer` (icon sizes, pins, shadow, pulse) and
   `Config.UI.MapIcons` (the glyphs are the uploaded sheet). The rest of `Config.UI.FullMap` is read at start and on
   each open, not at use; the calibration and `MapRotationOffsetDegrees` once per session.
5. Markers do not pulse (`Pulse = true` job offers). The route has no dark outline and no destination diamond, is
   always Cyan (Classic drew activity routes in pink), and its ends are square. A route with more than 64 visible
   segments is thinned (every 2nd, 4th… point) instead of drawn in full.
6. No "ADD MAP TILE IDS" label; `MapCanvas.New(...).Complete` says whether the tile set is complete.
7. A marker whose `Icon` is not on the sheet draws a fallback glyph by kind (Classic drew a letter).
8. The player arrow is the sheet's `Player` glyph, rotated; assumed to point up at rotation 0.
9. Legend: the YOU row uses the same glyph; the list scrolls inside a capped panel. The controls are left
   (Regular) or right (Compact) as in r08 / c16, not bottom-right of the map view.
10. Prompts: hold prompts show a full base line while held, not an animated fill (every hold duration is 0 at run
    time today). After the fail-safe the engine draws the prompt again from its next show, not the current one.
11. Event card: no track thumbnail; the car is text ("S 939"), not a `TierBadge`; the prize is the event's
    `BaseReward` as the server sends it (no client arithmetic); a change of class while the card or map is mounted
    keeps the icon sizes of the mount class.

## C. Token requests (existing tokens were reused meanwhile; no literal sizes in the sources)

Full-map icon size (used `BadgeLarge` / `CompactActionTile`), route width (`TileBaseLine`), legend row height
(`StatRowHeight` / `CompactActionTile`), legend icon (`BadgeSmall` / `CompactStatusHeight`), chequer size
(`IconButton`), event card row heights (`FactRowHeight`, `BadgeSmall`). `FullMapModel` carries the Classic config
fallbacks as numbers (pan bounds, `DragThresholdPixels` 8, `WaypointY` 101…): they are `Config.UI.FullMap` defaults,
not layout.

## D. Lint and harness notes

- `MapRoute` places segments with **scale** positions and sizes inside the canvas, as RouteGuide's renderer does. That
  is what makes pan, zoom and rotation cost zero writes; it is an exception to "whole pixels" for this one layer.
- `FullMapView` and `EventCardView` create plain `Frame`, `UIListLayout`, one `ScrollingFrame` and one `ImageLabel`
  (`ChequerCorner`, which A2 1.1 assigns to this family) beside kit components.
- The parity scan will find `:Fire(` on Luau `Changed` signals (not bindables), `self.C.Enabled` (a config flag) and
  the words Enabled / Triggered in comments. No ScreenGui or prompt `Enabled` is written anywhere.
- Step functions were kept free of `FindFirstChild`, `GetAttribute`, `Instance.new`: pools grow on signals
  (`MapIcons` on `MapMarkers.Changed`, deferred), the 64 route segments are made in `New`, the subject part is cached.
  `RouteGuide.GetRouteState()` clones the point list on every call (its own code); `FreeRoamMapPlayerMarkers:Step`
  is the shared module's.
- Tests need: `env.Scope()`; `env.Load("ReplicatedStorage.Modules.Game.UI.MapMath")` served from `classic/sources`
  (it is pure); `env.Load` returning the **same** module table a sibling `require` gets (the seams `MapCanvas._math`,
  `_tiles`, `_hudConfig`, `MapIcons._markers`, `_defer`, `MapRoute._config` are set on it); family modules reaching
  the kit as `script.Parent.Parent.Kit` and each other as `script.Parent.<Name>` / `script.Parent.Parent.Map.<Name>`.
- Route layer budget: 64 segments plus one holder frame = 65 instances (A2 says 64); the chip and the edge pip are in
  the overlay.

## E. What the integrator must check in Play

1. Map opens by minimap click, `M` and ButtonSelect (the last two only with the HUD minimap showing); closes by `M`,
   Escape, B, the Roblox menu, a presentation owner and each blocking attribute. `FullMapOpen` flips exactly once
   each way; the input gate is released; the HUD comes back.
2. Pointer space: taps land where pressed (the map frame is in a `ScreenInsets.None` gui; `ToLocal` subtracts its
   `AbsolutePosition` as Classic does). Presses on chrome do not pan or set a waypoint; the wheel over the legend
   scrolls the legend, not the map.
3. Waypoint: set by tap, by a place icon, by pad A; cleared by tap on it, Backspace, X, the button; replaced by a
   race-menu route; removed on arrival. Route line, chip distance, minimap edge pip.
4. Icons: every `MapMarkers` icon key resolves to a sheet glyph; pins sit on their tip; edge-clamped icons ride the
   rim (rect and round); 0 instances created on pan and zoom (`churn_probe`).
5. Prompts, each family, by key, pad and touch tap: the same server handler fires; no default prompt UI beside the
   banner; Enter hidden on others' cars; Drive Out and Manage Garage hidden for a visitor; all hidden while a menu,
   the map or results are open and back after. The two checks spike 11 left open: seated in a start zone, and
   `InputHoldBegin` from the banner on touch.
6. Fail-safe: force `Overlay.PromptStack.Show` to error once; that prompt returns to the engine's UI and the others
   keep their banners.
7. Event card: in the right column with chat showing, top-left without; fills in after the replies; no request when
   on foot; `Core.Net` token use per show (at most two).
8. Compact: legend closed below 760 px wide, key hints follow the input, 48 dp targets.
