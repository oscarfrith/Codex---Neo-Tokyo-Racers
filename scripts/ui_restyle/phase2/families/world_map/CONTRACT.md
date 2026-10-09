# WorldMap family: acceptance contract

Under `../../CONTRACT.md` (wave) and `../../API2.md` 5.4. Status: generated, not installed. Lane: High-Risk (second owner
for the full map; a new client owner over world prompts). No server script, remote, saved field or config value is added.

## Owners, before and after

| Surface | Classic (unchanged, never required under Pulse) | Pulse |
|---|---|---|
| Full map state, `FullMapOpen`, waypoint, map input, the frame step while open | `UI.FullMapUI` | `WorldMap.FullMapClient` (entry `FullMapUI`) over `FullMapModel`, `FullMapView` |
| Map tiles, pan, zoom, rotation, culling | `MapTileSet` driven by each owner | `Map.MapCanvas` over the shared `MapTileSet`, `MapMath` |
| Marker icon drawing | `UI.MapIconLayer` | `Map.MapIcons` over the shared `MapMarkers` registry |
| Route line, chip, edge pip | `RouteGuide.newMapRenderer` | `Map.MapRoute` over `RouteGuide.GetRouteState()` |
| World prompt drawing | engine default prompt UI | `World.WorldPromptView` (Pulse-only entry `PulseWorldPrompts`) over `WorldPromptModel` |
| Race event card | none | `World.EventCardView`, mounted by `WorldPromptView` |

Unchanged owners: the route and its `Update` throttle (`RouteGuide`), the marker registry (`MapMarkers`), other players'
markers (`FreeRoamMapPlayerMarkers`), the input gate (`GameplayInputGate`), every prompt's creation, `Enabled`,
`Triggered` handler and action (server scripts, `RaceLifecyclePresentationClient`, `GarageEntranceClient`,
`OwnedGarageBrowserUI`, `PassengerClientView`, `JobClient`).

## Must preserve

1. `FullMapClient` keeps `Open(): boolean`, `Close()`, `Toggle(): boolean`, `IsOpen(): boolean`, `start()`, all safe
   before start.
2. Single owners: one writer of player attribute `FullMapOpen` (false at start, true on open, false on close); context
   actions `FullMapToggle` (ButtonSelect, `High.Value`, permanent) and `FullMapPad` (`High.Value + 50`, while open);
   `GameplayInputGate.Acquire("FullMap", "V1")` / `Release(token, true)`; marker and route source id `"Waypoint"`;
   one caller of `RouteGuide.Update` per frame (the map only while open).
3. Waypoint calls and order: `RouteGuide.Clear("Player")`, `RouteGuide.SetDestination("Waypoint", pos, {Label,
   Priority = 5})`, `MapMarkers.Set("Waypoint", {Position, Icon = "Waypoint", Label, Kind = "Waypoint", Priority = 50,
   EdgeClamp = true})`; reconcile on `RouteGuide.Changed` and `Arrived`; the tap rule (waypoint icon clears; Place,
   Race and Job markers route to the marker at `WaypointY`; anything else routes to the tapped point).
4. `blocked()`: the eight player attributes, `PlayerGui@OwnedGarageManagementOpen`, presentation owners, a racing
   vehicle, `Config.UI.FullMap@Enabled`. Keyboard and pad opens need a showing HUD minimap.
5. Keys: M, Escape, E/=/keypad +, Q/-/keypad -, C, F, Backspace/Delete, WASD and arrows; pad A, B, X, Y, LB, RB, left
   stick; wheel, drag, pinch, tap. Key hints stay and follow the input.
6. Prompts: client only. Only `Style` is written, locally, only on the twelve known prompt names, only after the banner
   host exists. Never `Enabled`, never a `Triggered` connection, never a remote for the action. Touch uses
   `InputHoldBegin` / `InputHoldEnd`. Any banner error sets that one prompt back to `Default` for good.
7. Event card: the two existing reads only, `RaceRequest "GetEntryDetails" {EventId, Mode}` and
   `"GetTimeTrialPersonalBest" {EventId, VehicleTier}`, at most once each per show, never from a view, never retried;
   the card draws without them. The prize is the server's `BaseReward` through `Data.Money`; no client arithmetic.
8. No `ScreenGui.Enabled` write; `Claim` first; `start()` waits only where Classic waits (FullMapUI 29-48) or not at
   all (`WorldPromptView`: `PlayerGui` only; roots are found in spawned, bounded waits).

## Budgets

Route layer 64 pooled segments (plus one holder). Icons: one instance per marker, pooled, compared before every write.
Pan and zoom: 0 instances created or destroyed; a route writes nothing on pan, zoom or rotation until the view leaves
a 1.5x clip box. Prompts: no per-frame code. Legend and event card rows are patched in place.

## Tests (pure, `tests/`)

Map maths wrappers against `MapMath`; canvas, icon and route steps writing nothing when unchanged; route clipping
(box, progress segment, at most 64, thinning end to end); icon placement (rect, round, edge clamp), picking, pool reuse
and the surface flag; the map model (attribute writes, gate, presence, every blocker, toggle, waypoint calls, tap rule,
legend rows and debounce, zoom limits, pointers, step, legend default); the map view at R1080 and C844 (mount, no write
on re-render, no churn on a legend or input change, step, destroy); client key and pad tables; prompt family
classification, visibility rules, banner props, the banner state machine (24 rows), refresh and fail-safe; event card
texts, rows, slot rule, both request call sites as `(remote, action, keys)`, cache and untrusted replies; fixtures
shape.

## Gates (Play, integrator)

`NOTES.md` section E. Not done by this agent: compile, lint, any run, any Studio or git action.
