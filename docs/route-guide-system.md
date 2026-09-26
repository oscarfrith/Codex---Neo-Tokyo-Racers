# Route guide (GPS)

Reference for the free-roam route guide installed 2026-09-26 on Space Racers v2 (Street Life design [10.2](design/street-life-update.md#102-route-guide-gps)). Evidence: [verification](../scripts/route_guide/verification.json).

## What players see

- Clicking or tapping the minimap opens **ROUTE GUIDE**. It lists the configured destinations, CLEAR ROUTE and CLOSE.
- The race browser footer is **EXIT | SET ROUTE | TELEPORT**. SET ROUTE drives you to the selected event's start instead of teleporting you there.
- The route is a cyan line with a dark outline, drawn on the rotating minimap. Activity routes (for future jobs and duels) are drawn pink. A chip at the top of the map shows the destination and the remaining distance. An edge pip points to destinations that are off the map.
- Leaving the route for more than 60 studs re-plans it after 1 s. Arriving within 45 studs clears the route and shows "ARRIVED".

## Owners

| Piece | Location | Role |
|---|---|---|
| RoadRouting | ReplicatedStorage.Modules.Game.World | Pure maths: graph loading, snapping to the nearest road, A* routing, route progress. Tested by scripts/route_guide/tests.lua. |
| RoadGraphData | ReplicatedStorage.Modules.Game.World | Generated data only. Never edit by hand. |
| RouteGuide | ReplicatedStorage.Modules.Game.UI | Client owner of destination requests and the active route. Provides `newMapRenderer`. No remotes, saves or loops of its own. |
| Desktop/MobileFreeRoamHudUI | existing | Host the renderer inside `MapCanvas`, call `RouteGuide.Update` from their existing render callbacks, and own the ROUTE GUIDE modal. |
| RaceBrowserClient | existing | Owns the SET ROUTE button. |

**API for future activities:**

- `RouteGuide.SetDestination(sourceId, Vector3, { Label, Priority, Kind = "Activity" })` and `RouteGuide.Clear(sourceId)`. The highest priority wins; players use priority 10.
- `RouteGuide.SetDestinationById(idOrRouteId, sourceId)`.
- `RouteGuide.Changed` and `RouteGuide.Arrived` signals.

## Tuning (Config.UI.RouteGuide attributes)

| Attribute | Default | Meaning |
|---|---|---|
| Enabled | true | Master switch |
| LineWidth | 3 | Route line width (px) |
| OffRouteStuds | 60 | Distance from the route that counts as off-route |
| OffRouteSeconds | 1 | How long off-route before re-planning |
| ReplanMinSeconds | 1 | Minimum time between re-plans |
| ArriveStuds | 45 | Distance that counts as arrived |
| ProgressHz | 10 | Progress updates per second |
| StudsPerMile | 5760 | Distance conversion; matches the game's 0.625 mph per stud/s |
| ChipEnabled | true | Show the distance chip |
| LineColour / ActivityColour | (unset) | Optional overrides; the HUD passes theme tokens |

## Destinations

`Config.UI.RouteGuide.Destinations.<Id>` holds `DisplayName`, `Kind`, `Order`, `SourcePath`, `Position` and, for races, `RouteId` (matched by the race browser). The installer copies `Position` from the `SourcePath` part. After moving a source part, or to add a destination, edit `DESTINATIONS` in scripts/route_guide/build_installer.py and reinstall.

## Regenerating the road graph (after the minimap art changes)

1. Start the mask receiver: `py -3 scripts/route_guide/mask_receiver.py`. Serve `scripts/` on 127.0.0.1:8767.
2. In Studio Edit, run scripts/route_guide/export_road_mask.lua. It is read-only: it loads the four minimap tiles into memory and posts the road runs.
3. Run `py -3 scripts/route_guide/build_road_graph.py`. Review road_graph_preview.png and road_graph_city.png.
4. Rerun the tests. Rebuild and run the installer as an update: the installer treats a changed data module as drift, so roll back first, then apply the new build.

## Known limits

- **Flat map only.** The graph comes from the flat map, so bridges and ramps that cross other roads look like junctions.
- **Coastal loops.** The coastal loop roads are included because the map draws them as roads.
- **Last leg.** Route starts and ends that are off the road are joined to the road with a straight line.
- **Not yet built:** a full-screen map with tap-to-waypoint, and in-world chevrons.
- **Not yet tested:** mobile at runtime on a touch device.
