# Route line options (2026-09-26)

Owner feedback: the GPS line on the minimap was still jagged. It should look straight or smooth, follow the drawn roads, and be thicker. This note compares the options measured offline and records the winner, which is now implemented.

Reproduce with `py -3 scripts/route_guide/route_line_lab.py`, which writes `lab_results.json`, `compare_diagonal.png` and `compare_ring.png`. It uses the geometry in `centreline.py`, which is shared with `build_road_graph.py`.

## Why the old line was jagged

The old pipeline was: mask, then closing/opening, Zhang-Suen skeleton, junction tracing, spur prune, junction contraction, RDP with ε 1.0, and finally quadratic corners with r = 28 studs at runtime. Three faults caused the jaggedness:

1. **Skeleton pixel centres are quantised.** A diagonal street becomes a staircase. RDP with ε 1.0 keeps some stair vertices, so straight streets get small random kinks (±0.5 px).
2. **Junction nodes sit at skeleton centroids.** The centroid is usually 1–3 px off the true crossing, and every edge bends into it. A route going straight through a crossing therefore bulges sideways at each side street. This was the main visible fault: see the "A" row of `compare_diagonal.png`, where the 5 px line wobbles at every side street on the diagonal avenue.
3. **Runtime rounding worked per vertex with r ≤ 0.45 × segment.** With 28 studs (2 map px) it did almost nothing on the minimap, and on dense points it multiplied the point count (up to 907 points per route).

## Candidates

All geometry is in minimap pixels. 1 px is 13.77 studs, or about 1.2 UI px on the minimap.

- **A**: the baseline above.
- **A2 / A3**: the baseline plus Chaikin ×3 or centripetal Catmull-Rom at runtime. These are cheap runtime-only fixes.
- **B**: Gaussian smoothing of the skeleton pixels (σ 2 px, ends pinned), then RDP 0.35 px.
- **C**: sub-pixel centreline (candidate 1). Each skeleton point moves to the midpoint of the road cross-section, measured perpendicular to the local direction with bisection-refined edges. Unreliable sections fall back to the skeleton point. Then Gaussian σ 2 px and RDP 0.35.
- **D**: C's centre points, then a per-edge line/arc fit (candidate 2). The fit is greedy and uses the fewest straight lines and circular arcs within the tolerance, preferring lines. Arcs are sampled with a chord error of 0.08 px or less and steps of 9° or less.
- **E**: D plus least-squares junctions (candidate 3). Each junction node moves to the least-squares intersection of its incident centre lines, fitted over 10 px just outside the junction mouth. The move is kept only if the lines meet within 1.5 px, it stays within the mouth radius, and it lies on the road. Edge points inside the mouth are dropped so edges run straight into the node. Each fitted edge is validated to stay on the road; if it leaves, a half trim is tried and then the untrimmed centre line.
- **F**: C plus least-squares junctions. This is E with RDP instead of line/arc fitting.
- **E2**: E plus Catmull-Rom at runtime (candidate 4).
- **Runtime corners, same for B–F**: the new `RoadRouting.Smooth`, a "fillet" (quadratic corner with r = 50 studs measured along the route). Rows "E no runtime corner" and "E old quad r28" isolate its effect.

## Metrics

The lab measures 160 random node-to-node routes of 3–40 edges each. The route polylines go through the runtime step, as they are drawn.

- **dev**: |offset| of the line from the true road centre, as mean / p95 in px. The true centre is the midpoint of the cross-section in the processed mask. Samples within a junction mouth are excluded, since cross-sections are meaningless there. Pixel edges alone add about ±0.25 px of noise to this reference.
- **jog**: straight-through junctions only (the route turns less than about 36° and there is no other junction within 12 px). The value is the maximum sideways excursion within ±12 px of the node, measured against the line's own σ 3 px smoothing, as mean / p95 in px. This is the "bulge at crossings" metric.
- **rough**: RMS distance between the line and its σ 3 px smoothing, away from junctions (high-frequency wobble).
- **turn**: total |turn| per 100 px away from junctions. Lower means straighter; real curves set a floor.
- **rev**: sign-reversing turns (> 2°) within 30 studs of each other, per 1000 px (zig-zags).
- **kink**: vertices turning more than 10° away from junctions, per 1000 px.
- **out%**: share of samples whose line centre is off the road.
- **pts**: points per route after runtime smoothing, as mean / max.
- **graph pts**: data points in the graph.

| Candidate | dev mean / p95 | jog mean / p95 | rough | turn | rev | kink | out% | pts mean / max | graph pts |
|---|---|---|---|---|---|---|---|---|---|
| A baseline (pixel skel, RDP1, quad r28) | 0.34 / 0.87 | 0.28 / 0.83 | 0.064 | 24.6 | 0.20 | 0.33 | 0.00 | 158 / 614 | 1205 |
| A2 baseline + Chaikin ×3 | 0.40 / 1.05 | 0.23 / 0.71 | 0.068 | 37.5 | 0.84 | 4.99 | 1.15 | 251 / 872 | 1205 |
| A3 baseline + Catmull-Rom | 0.66 / 1.92 | 0.31 / 1.13 | 0.067 | 36.7 | 0.11 | 2.87 | 2.61 | 337 / 1266 | 1205 |
| B Gauss skel + RDP.35 + fillet | 0.27 / 0.60 | 0.29 / 0.86 | 0.053 | 25.2 | 0.20 | 0.74 | 0.00 | 123 / 369 | 1983 |
| C sub-pixel + Gauss + RDP.35 + fillet | **0.14** / 0.44 | 0.31 / 0.96 | 0.053 | 26.5 | 0.60 | 1.54 | 0.00 | 142 / 434 | 2100 |
| D sub-pixel + line/arc fit + fillet | 0.18 / 0.48 | 0.33 / 1.11 | 0.059 | 34.0 | 1.63 | 2.47 | 0.00 | 152 / 483 | 3090 |
| **E D + LSQ junctions + fillet (tol 0.45), chosen** | 0.19 / 0.51 | **0.14 / 0.44** | **0.049** | **21.8** | 0.35 | 0.97 | 0.01 | **83 / 294** | 1922 |
| E2 E + Catmull-Rom | 0.24 / 0.64 | 0.12 / 0.44 | 0.047 | 23.5 | 0.40 | 0.97 | 0.01 | 344 / 1207 | 1922 |
| F C + LSQ junctions + fillet | 0.14 / 0.44 | 0.15 / 0.50 | 0.049 | 21.5 | 0.42 | 0.87 | 0.01 | 81 / 291 | 1484 |
| E, tol 0.30 | 0.18 / 0.45 | 0.15 / 0.48 | 0.050 | 22.8 | 0.66 | 0.93 | 0.01 | 86 / 306 | 2168 |
| E, tol 0.60 | 0.22 / 0.58 | 0.14 / 0.46 | 0.049 | 20.7 | 0.64 | 0.93 | 0.01 | 81 / 303 | 1801 |
| E, tol 0.80 | 0.26 / 0.70 | 0.14 / 0.45 | 0.049 | 20.1 | 0.55 | 1.10 | 0.01 | 78 / 297 | 1616 |
| E, no runtime corner | 0.19 / 0.51 | 0.20 / 0.80 | 0.054 | 22.0 | 0.23 | 4.77 | 0.01 | 38 / 202 | 1922 |
| E, old quad r28 corner | 0.19 / 0.51 | 0.16 / 0.58 | 0.051 | 22.1 | 0.01 | 0.11 | 0.01 | 162 / 907 | 1922 |

**Maximum deviation.** It is 5–7 px for every candidate. It comes from the same few places: shallow merges, splits of dual carriageways and the baked-in map icons. It is not a differentiator, so it is left out of the table (see `lab_results.json`).

**Offline check of the chosen setup.** Across 400 random routes the largest single-vertex turn after the runtime fillet is 23°, and routes have at most 335 points.

## Findings

- **Runtime-only smoothing (A2, A3) makes it worse.** Chaikin and Catmull-Rom only round the existing jogs into wavy S-shapes. They pull the line off the road centre (1–2.6% of samples fall outside the road) and multiply the points 2–8×. Rejected.
- **Sub-pixel centres (C) fix the centring but not the crossings.** C has the best centre deviation, 0.14 px mean against 0.34 for the baseline. But crossing jogs get worse (0.31 px), because the ends still bend into the skeleton centroid.
- **Line/arc fitting alone (D) is not enough.** With the old junction positions it turns the end bends into extra primitives, giving the most kinks and reversals.
- **Least-squares junctions are the decisive step (E, F).** Crossing jogs halve (mean 0.28 → 0.14 px, p95 0.83 → 0.44 px), turning on straight stretches falls, and routes need half the points.
- **E against F.** Both are equal within noise on every metric. F sits 0.05 px closer to the centre, about 0.06 UI px, which is invisible under a 5 px line. E was chosen because its geometry is exactly what the owner asked for. 297 of 458 edges are single straight segments, the rest are true circular arcs, and a straight street cannot wobble at any zoom. That matters for the full-screen map, which zooms in further than the minimap.
- **Fit tolerance.** 0.45 px balances centring against straightness. Below 0.3 the fit starts following the pixel noise (more reversals); above 0.6 the curves drift off-centre.
- **Runtime corner.** The new fillet (r = 50 studs, about 3.6 map px or 4.3 UI px, close to the line width) matches the old quadratic's smoothness at turns (kinks 0.97 against 4.77 with no rounding). It uses about half as many points (max 294 against 907), because it spans the radius along the route and absorbs dense points instead of rounding each one. Radii from 28 to 100 studs were tried, and none put the line centre off the road.
- **E2 (Catmull-Rom on top) is rejected.** It adds 4× the points for a 0.02 px jog gain.

Also added:

- **Despike in `FindRoute`.** Where two roads merge at a shallow angle, the junction node can sit a few studs beyond the fork, so a route through it doubles back. A vertex turning 120° or more with a leg under 120 studs is dropped.
- **Tail cleanup in the generator.** Interior points within 1.5 px of an edge end, or hooks within 3 px, are removed.

## Rendering options

| Option | Verdict |
|---|---|
| Rotated pill Frames (UICorner) inside the map canvas, all outlines one ZIndex below all lines | **Kept.** Joins are round with no notches, it rotates and clips with the minimap's CanvasGroup, and there is one rebuild per re-plan (≤ 300 segments, i.e. ≤ 600 Frames). `LineWidth` is now 5 and the new `OutlineWidth` is 1.5 (UI px, multiplied by `PixelScale`). The blip grows with the line width. |
| More segments or angle-dependent joins | Not needed. With E the geometry is already dense only on arcs, where each step turns ≤ 9°. Pill caps fill every join, and the fillet makes each vertex turn ≤ 23°. |
| `Path2D` (native anti-aliased vector strokes) | **Promising follow-up, not implemented.** One instance per stroke would replace hundreds of Frames and give true anti-aliasing. It has not been verified in Studio inside the rotating `MapRotator` / `CanvasGroup` with `UIScale` supersampling, and the offline build has no Studio access. It needs a spike (does it clip, rotate and scale like Frames; how does thickness behave under `UIScale`) before it can replace the Frames. The renderer internals are isolated in `MapRenderer:_segment` / `Step`, so the swap would be local. |
| EditableImage overlay painted with the route | **Rejected.** A map-sized RGBA buffer is 2048² × 4 = 16 MB of client memory, which is a problem on phones. There is no thick or anti-aliased line primitive (strokes would be built from circles or rectangles per pixel run). Every re-plan would repaint in Luau. It also needs the experience's EditableImage permissions in live servers. It gives nothing geometry E does not already fix. |

## Changes made

- `centreline.py` (new): the sub-pixel centres, least-squares junctions, line/arc fit, validation and the Python mirror of the runtime fillet.
- `build_road_graph.py`: `pixel_graph()` is factored out (steps 1–6), step 7 uses `centreline.production`, and `GeneratorVersion` is 2. The previews draw the fitted polylines.
- `RoadGraphData.lua`: regenerated. It has 292 nodes, 458 edges (297 single straight segments), 1922 points and 45.5 KB (was 32.5 KB).
- `RoadRouting.lua`:
  - `Smooth(points, radius, samples, minTurnDegrees?)`: corners of 10° or more are rounded over `radius` studs along the route, and `samples` is now the number of steps per 90°. Endpoints are exact and sampled arcs are left alone.
  - `FindRoute`: drops short doubling-back spikes.
  - The API is unchanged.
- `RouteGuide.lua`:
  - `CornerRadius` defaults to 50, with 8 steps per 90°.
  - `LineWidth` defaults to 5 (clamped 1–16).
  - New `OutlineWidth` attribute, defaulting to 1.5 (clamped 0–6).
  - The renderer rebuilds when a width changes.
  - The public API is unchanged.
- `tests.lua`: all previous assertions are kept unchanged. The old corner test still gives 7 points, (80, 0) and (100, 20). New tests cover:
  - the dense-corner fillet
  - arcs left alone
  - spike removal
  - graph v2 with at least 40% straight edges
  - each real destination route drawing with < 400 points and a maximum vertex turn < 35°
- `spec-route-line.json`: the delivery spec, with 3 sources and 3 attributes.
- `route_line_lab.py`, `lab_results.json`, `compare_*.png`: the evidence.

## Recommended changes to docs/route-guide-system.md (for the integrator)

- **"What players see".** "The route is a thick cyan line (5 px) with a dark outline. It runs straight along straight streets, follows curves as true arcs and rounds its turns, drawn on the rotating minimap."
- **Tuning table.**
  - `LineWidth` default **5** (was 3), meaning route line width in UI px.
  - Add `OutlineWidth` with default **1.5**, meaning outline thickness each side in UI px (0 hides it).
  - Add `CornerRadius` with default **50**, meaning turn rounding in studs along the route.
- **Regenerating the road graph, step 3.** "`build_road_graph.py` now also runs `centreline.py`: sub-pixel road centres, least-squares junctions, line/arc fit. Optionally run `route_line_lab.py` to re-measure and review `compare_*.png`."
- **Owners, RoadRouting.** "`Smooth` rounds turns over a radius along the route. `FindRoute` removes short spikes at shallow merges."
- **Known limits.**
  - Thin roads (1–2 px strokes in the art, e.g. the south-west diagonal outside the ring) are still removed by the opening step and are not routable.
  - The baked-in map icons (garage, customisation) are treated as road surface.
