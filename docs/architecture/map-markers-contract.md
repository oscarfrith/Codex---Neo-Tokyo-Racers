# Map markers, full map and world jobs contract

Status: **contract for the parallel build**, 2026-09-26. It covers Oscar's refinements: GTA-style world jobs, the full-screen map with waypoints and a legend, upright map icons, and a smoother route line. It extends [activities-contract](activities-contract.md) and [route-guide-system](../route-guide-system.md). Target place: Space Racers v2 (71491191583884). Agents write only inside their own folder and never touch Studio or git; the integrator installs.

## Shared client API: `ReplicatedStorage.Modules.Game.UI.MapMarkers` (owner: Agent F)

A pure client registry that the minimap and the full map render from. It has no rendering of its own.

```lua
MapMarkers.Set(id: string, marker: {
    Position: Vector3,            -- world position
    Icon: string,                 -- icon key, see "Icon keys" below
    Label: string,                -- shown in the legend / tooltip
    Kind: "Place" | "Race" | "Job" | "Waypoint" | "Activity" | "Player",
    Priority: number?,            -- draw order; higher on top (default 10)
    Color: Color3?,               -- tint for fallback shapes / icons (default theme per Kind)
    Minimap: boolean?,            -- default true
    FullMap: boolean?,            -- default true
    EdgeClamp: boolean?,          -- keep on the minimap rim when off-screen (default false; true for Waypoint/Activity)
    Pulse: boolean?,              -- gentle pulse (e.g. available jobs)
})
MapMarkers.Remove(id)
MapMarkers.Get(id) -> marker?
MapMarkers.All() -> { [id]: marker }
MapMarkers.Changed  -- Core.Signal (id, marker or nil)
```

- **Icons are always upright.** On the rotating minimap, markers are positioned with the map transform but never rotated.
- **Static places** come from `ReplicatedStorage.Config.UI.MapPois`. Each child Folder has attributes `Label`, `Kind`, `Icon` and `Position` (Vector3), plus an optional `RouteId` or `DestinationId`. Agent F's installer spec creates them from world parts (Dealership, My Garage, Customisation, each race start). `MapMarkers` registers them on start.
- **Waypoint.** Clicking the full map calls `RouteGuide.SetDestination("Waypoint", position, { Label = "WAYPOINT", Priority = 5 })` and `MapMarkers.Set("Waypoint", { Kind = "Waypoint", Icon = "Waypoint", EdgeClamp = true, ... })`. Clicking the waypoint again, or arriving, clears both.

## Icon keys: `ReplicatedStorage.Config.UI.MapIcons` (attributes: key -> asset id string)

Keys are `Dealership`, `Garage`, `Customisation`, `Race`, `TimeTrial`, `TaxiFare`, `CourierPickup`, `CourierDrop`, `TaxiDrop`, `Waypoint`, `Player`, `OtherPlayer`, `Duel` and `Job`.

- **Asset ids.** Agent M produces the PNGs and the integrator uploads them and fills the ids.
- **Fallback.** Renderers must use a clean fallback when an id is empty: a round theme-coloured badge with a 1–2 letter glyph. Nothing may break without assets.

## World jobs: `ReplicatedStorage.ActivityState.JobOffers` (owner: Agent J)

- **Where offers live.** The server `JobBoard` creates the `ActivityState/JobOffers` folder at runtime (it is not saved in the place). Each available offer is a `Configuration` named by offer id, with these attributes:
  - `Kind`: "Taxi" | "Courier"
  - `Position`: Vector3 pickup at the kerb
  - `Facing`: Vector3 optional
  - `Distance`: estimated trip studs
  - `Estimate`: estimated pay
  - `ExpiresAt`: server time
- **Client display.** Clients mirror offers into `MapMarkers` with icons `TaxiFare` or `CourierPickup`, Kind "Job" and Pulse.
- **Starting a job.** In the world there is an NPC (taxi) or a parcel stand (courier) with a ProximityPrompt ("Give ride" / "Pick up parcel") that appears only when you drive up slowly. It triggers `ActivityInvoke` action `JobAccept { OfferId }`, added to the ActivityService allowlist at integration. During a job the destination is an `Activity` route plus the `TaxiDrop` or `CourierDrop` marker.
- **One job, then find the next.** Completing a job does not start another; the player finds the next one on the map.

## Route line (owner: Agent R)

`RouteGuide.newMapRenderer(options)` keeps its API. Its internals, the road graph data and the generator may change. The full map reuses it with its own canvas and pixel scale. Line width becomes configurable and thicker by default.

## Ownership

| Agent | Folder | May modify existing |
|---|---|---|
| R route line | `scripts/route_guide/` | RoadRouting, RoadGraphData, RouteGuide (renderer internals), build_road_graph.py |
| F full map + markers | `scripts/map_ui/` | DesktopFreeRoamHudUI, MobileFreeRoamHudUI (minimap click opens the full map, POI layer hosting) |
| J world jobs | `scripts/activities/world_jobs/` | CourierJob, CourierRules, CourierClientView, TaxiJob, TaxiRules, TaxiClientView (rework); may add `JobBoard` |
| M map art | `scripts/map_art/` | none (produces PNGs and a manifest) |
