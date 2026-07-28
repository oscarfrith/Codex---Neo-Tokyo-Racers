# Free-Roam Map Player Markers And Smooth Pan V1.1

**Date:** 2026-07-28  
**Status:** Confirmed working and mirrored  
**Lane:** Standard  
**Canonical installer:** `scripts/roblox_freeroam_map_players_smooth_pan_v1.lua`

## Acceptance Contract

Goal: add lightweight other-player circles to both free-roam minimaps and make the existing four-tile map pan as smoothly as Roblox's 2D renderer permits.

Current confirmed baseline: the user confirmed V1.1 working well. The complete `2026-07-28 14:21:10` / 193-source mirror contains the installed desktop/mobile HUD, shared module and config revisions with zero cross-manifest mismatches.

Required changes:

- show only other players whose characters are currently streamed to the client;
- hide players while their replicated authoritative race-vehicle, garage or owned-interior state is active;
- render no name, direction, distance, edge arrow or pulse;
- size another player's marker at `0.65` of the corresponding local-player arrow;
- preserve the same proportional reduction on desktop and landscape mobile;
- render the existing four map tiles once through a configurable four-times logical pan carrier;
- give desktop and mobile the same frame-rate-independent exponential pan response;
- reuse the two existing HUD render callbacks rather than creating another loop.

Must preserve:

- the confirmed north-up four-tile artwork, calibration, zoom, coordinate rotation and axis flips;
- the existing local-player arrow and heading behaviour;
- map edge fades and clipping;
- desktop/mobile HUD ownership and suppression during racing, garages and menus;
- driving, racing, VFX, LOD, streaming settings, server authority and persistence.

Shared components and owners:

- `DesktopFreeRoamHudController_Active` remains the desktop map geometry/visibility/render owner;
- `MobileFreeRoamHudController_Active` remains the touch map geometry/visibility/render owner;
- new `FreeRoamMapPlayerMarkers` is a shared client-only marker lifecycle/projection module called by those owners;
- `Config.UI.FreeRoamMapPlayerMarkers` owns marker and pan tuning.

Lifecycle:

- existing players register once, then `PlayerAdded`, `PlayerRemoving` and `CharacterAdded` maintain the bounded cache;
- replicated garage/owned-interior Player attributes and authoritative seated-vehicle race attributes update marker eligibility without polling;
- `Humanoid.SeatPart` changes bind and release only the relevant streamed vehicle attribute signals;
- a missing or streamed-out `HumanoidRootPart` hides and resets only that marker;
- hidden maps stop marker work and reset rendered marker positions;
- a streamed-back marker starts at its current position rather than sweeping from stale coordinates;
- leaving players release their marker and connections.

Device coverage: one shared marker module serves desktop, laptop, controller/console-sized desktop composition, landscape phone and landscape tablet. No portrait contract is introduced.

Persistence/economy/security: not applicable. The feature sends no client intent, creates no remote and saves nothing.

Explicit exclusions:

- server-wide player visibility outside streaming;
- names, direction, friends/party colours, clustering and edge arrows;
- a second map renderer, ViewportFrame, EditableImage or server position relay;
- map artwork, zoom/calibration, marker styling, racing state or any server/runtime owner.

Done when:

- slow walking and fast driving pan look smoother on desktop and touch;
- another player's circle remains visibly smaller than the local arrow at the same `0.65` ratio;
- two clients track one another correctly while walking and driving;
- streamed-out edge markers disappear unobtrusively beneath the existing fades and reconstruct safely;
- respawn, leave, garage/menu/racing transitions and repeated entry/exit do not leak markers or connections;
- a representative 15-player test remains within the bounded 14-marker budget with no meaningful low-end-mobile frame-time regression.

## Architecture

The implementation is client-only. It deliberately accepts that a player near a faded minimap edge may disappear when their character streams out. This removes the proposed position broadcaster, unreliable remote, server loop and duplicate movement payload.

The shared module owns at most 14 other-player records. It never calls `GetDescendants`, searches Workspace, computes headings, measures text or binds a render event. Race/TT visibility is derived from the streamed seated vehicle's existing server-owned `NTR_RaceParticipant`, `NTR_RaceRunId`, `NTR_RaceMode` and `NTR_RaceFinishedPendingExit` attributes. Each existing HUD owner supplies:

- the local streamed map-subject position;
- map size and visible world width;
- coordinate rotation and flips;
- the corresponding local-arrow size;
- current map visibility.

The module converts cached other-player root positions into the same north-up map basis and writes one small marker position only when its smoothed value changes.

## Visual Contract

Default other-player markers use:

- `OtherPlayerMarkerScale = 0.65`;
- desktop reference arrow `22 px`, producing approximately `14 px`;
- mobile reference arrow `18 px`, producing approximately `12 px`;
- cyan fill with a light outline;
- Z-index `13` beneath desktop edge fades/local arrow;
- Z-index `7` beneath mobile edge fades/local arrow.

`OtherPlayerIcon` is optional. When blank, the module uses a lightweight circular ImageLabel background plus `UICorner` and `UIStroke`; supplying one transparent circle asset later removes the fallback fill/stroke without changing layout or runtime ownership.

## Smooth-Pan Contract

V1 proved that relative scale coordinates alone do not remove the final visible step. V1.1 preserves the target, calibration and four existing tile images, but parents that same single canvas under one transparent logical carrier:

1. `MapPanSubpixelFactor=4` makes the carrier and canvas coordinates four times larger.
2. One `UIScale=0.25` returns the carrier to the original visual size.
3. The rounded logical position therefore advances in quarter-pixel visual increments without another map image, renderer or loop.
4. Both devices retain:

```text
alpha = 1 - exp(-MapPanResponse * dt)
```

5. `MapPanResponse` remains `12`; this changes spatial resolution, not responsiveness or update frequency.
6. `MapPanSubpixelFactor=1` is the immediate visual/performance fallback. At factor 1, the existing `UseRelativeCanvasTransform` fallback remains available.

Roblox may still rasterise the final image at physical pixels, so Studio visual evidence remains authoritative. The carrier adds two lightweight GUI instances per active HUD construction and no extra images or frame callback.

## Config

The installer creates attributes under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamMapPlayerMarkers
```

Primary tuning:

- `Enabled = true`
- `OtherPlayerMarkerScale = 0.65`
- `MinimumMarkerSizePixels = 8`
- `MaximumMarkerSizePixels = 16`
- `MaximumOtherPlayers = 14`
- `MarkerResponse = 14`
- `MapPanResponse = 12`
- `MapPanSubpixelFactor = 4`
- `EdgeOverscanPixels = 8`
- `PositionEpsilonPixels = 0.01`
- `UseRelativeCanvasTransform = true`
- `OtherPlayerIcon = ""`

Do not raise the marker cap above the representative 15-player target without profiling. Do not use a one-pixel position epsilon; that would deliberately recreate visible stepping.

## Studio Installation

1. Stop Play.
2. Open `scripts/roblox_freeroam_map_players_smooth_pan_v1.lua`.
3. Leave `MODE = "INSTALL"`.
4. Paste and run the whole file once in the Edit-mode Command Bar.
5. Require:

```text
[NTR Free-Roam Map Players + Smooth Pan V1.1] AUDIT PASS
[NTR Free-Roam Map Players + Smooth Pan V1.1] INSTALL PASS
```

An empty-icon warning is expected until a custom marker asset is supplied; the circular fallback remains functional.

The installer uses guarded exact-source replacement in the two current isolated HUD controllers. This is intentionally fragile: if an anchor fails, stop, refresh/inspect the live mirror and repair this same canonical installer. Do not loosen the anchor or rerun an older free-roam HUD installer.

The first V1.1 run compiled/projected but failed its final audit because `_V1` was counted inside the `_V1_1` marker line. Transactional restoration returned Studio to V1, confirmed by the complete `14:10:13` mirror. The repaired installer counts complete marker lines; this was an audit predicate fault, not a failed source anchor or partial Studio mutation.

## Verification

### One client

1. Walk slowly in a straight line and compare map-pan step cadence with the previous baseline.
2. Drive at low, medium and high speed; confirm the map remains north-up, aligned and clipped.
3. Turn through 360 degrees; confirm only the local arrow rotates.
4. Open/close the car menu, settings, dealership confirmation, race browser and owned garage; confirm normal map visibility and no stale marker surface.
5. On landscape phone/tablet, repeat walking/driving and confirm the pan response matches desktop without affecting controls or telemetry.
6. With controller input, repeat walking/driving and confirm the desktop-composition map and markers remain readable.

### Two clients

1. Stand together; each client should show one smaller cyan circle for the other player.
2. Walk and drive apart through the map centre and faded edges.
3. Confirm markers do not show direction or names and remain below the local arrow/edge fades.
4. Respawn one player, leave/rejoin and stream out/back near the edge.
5. Enter a multiplayer Race and confirm the participant disappears from a free-roam observer's map, then returns after race exit.
6. Repeat for active Time Trial and its finished-pending-exit state; the marker must remain hidden until the vehicle race attributes clear.
7. Enter/exit a garage and confirm reconstruction and cleanup.

### Performance

- Test a local server up to the practical Studio client limit and retain a 15-player published/representative release check.
- Compare client frame time with zero, one and fourteen markers.
- Confirm `OtherPlayerMarkers` contains at most one marker per tracked other player and returns to the same bounded count after repeated transitions.
- Confirm there is no new server script, remote, network traffic or standalone render binding.

## Rollback

Change the same installer to:

```text
local MODE = "ROLLBACK"
```

Run it once in Edit mode. Exact rollback removes only the V1.1 carrier and vehicle-race filtering, restoring the user-confirmed and mirrored V1 player-marker/relative-pan baseline. It refuses drifted source rather than overwriting later work.

For an immediate visual/performance fallback without changing marker or race filtering behaviour, set:

```text
MapPanSubpixelFactor = 1
```

At factor 1, `UseRelativeCanvasTransform=false` also restores the original pixel-offset canvas assignment.

## Mirror Handoff

The full Studio mirror was refreshed after confirmation:

1. Generated in Studio at `2026-07-28 14:21:10`.
2. Exported manifest, source manifest and checksums contain 193 matching records.
3. Both HUD revisions, shared module/config revision and factor-4 tuning are present.
4. No ordinary exporter rerun is pending.
5. Do not commit `docs/studio-full-export-paste.txt`.
