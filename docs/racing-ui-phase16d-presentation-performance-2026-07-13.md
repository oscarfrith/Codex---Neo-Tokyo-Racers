# Racing UI Phase 16D - Presentation Performance

Status: Generated; awaiting Studio confirmation.

Run `scripts/roblox_racing_ui_phase16d_presentation_performance.lua` in Studio
Edit mode after the confirmed Phase 16C2 map alignment. Restart Play after the
installer reports `SMOKE PASS`.

This is a client-presentation optimization only. It does not change Phase 8H
reset ownership, Phase 11Y finish cleanup, lap/checkpoint authority, rewards,
personal bests, matchmaking, vehicle physics or the register-limited bootstrap.

## Changes

### Incremental authored route arrows

The previous `RaceSessionAssetsClient_Active` called `hideAll()` and traversed
the complete `ArrowMarkers` hierarchy every 0.2 seconds. The current route has
about 508 instances under that hierarchy. Repeated `GetDescendants()` tables and
property writes could accumulate allocation pressure and surface as periodic
garbage-collection hitches.

Phase 16D indexes each static segment once. An unchanged 0.2-second proxy check
now exits after comparing a small run/route/segment signature. When the segment
does change, only segments leaving or entering the configured visibility window
are touched. The initial safety hide still runs once when the controller starts.

### Suppressed free-roam work

The confirmed free-roam speed and boost display remains active during a racing
session. Its hidden minimap conversion and two-second garage/profile request are
paused until racing presentation ends. This removes duplicate map work and a
periodic remote snapshot without changing the visible racing telemetry.

### Cached in-race map inputs

Route folder lookup, route anchor discovery, image calibration, flip settings,
rotation trigonometry and the initial vehicle subject are resolved once when a
session opens. The render step now performs coordinate arithmetic and marker
presentation only. If the cached vehicle disappears, subject discovery retries
at a bounded interval.

`MapOpacity` remains live-tunable through its existing changed signal.

## Configuration

The installer creates:

`ReplicatedStorage.NeoTokyoRacers.Config.Racing.PresentationPerformance`

- `ArrowProxyPollSeconds = 0.2`: compatibility poll for server proxy segment
  changes. Unchanged polls no longer traverse arrow descendants.
- `HudMapSubjectResolveSeconds = 0.5`: retry interval only when the cached local
  vehicle subject is missing.
- `PauseFreeRoamMapDuringRace = true`: skips the hidden free-roam minimap path.
- `PauseFreeRoamProfileDuringRace = true`: pauses the two-second profile request.

The recommended values should remain unchanged for the first comparison test.

## Test gate

1. Start a Time Trial and drive continuously for at least 60 seconds.
2. Confirm authored arrow groups still advance at checkpoint boundaries and no
   stale group remains visible behind the configured window.
3. Confirm the fixed race map and player arrow remain aligned and smooth.
4. Confirm speed and boost telemetry still update during the session.
5. Exit normally and confirm the free-roam minimap, money display and menus
   return; allow two seconds for the first post-session cash refresh.
6. Repeat with a multiplayer Race and confirm live position presentation and
   exit/reset cleanup are unchanged.
7. Compare the former periodic driving hitch over the same section of track.
   Optionally record MicroProfiler captures before and after for Lua GC and
   Instance-property activity.

Do not treat Phase 16D as confirmed until both Time Trial and Race pass this
gate. If a hitch remains in free roam as well as racing, the next audit should
profile the two-second profile owner and non-racing world services separately.
