# Driving tune: contract

Requested by Oscar on 2026-10-06. Target: Space Racers v3 (place 93959280828322). Lane: Standard, driving owner
(client physics and presentation only). Current status lives in `docs/00_START_HERE.md`.

## Goal (Oscar's words, condensed)

1. Cars are too good. Nerf E class about 10%, S class about 25% across the board, gradual in between. Drifting an
   added 20% on top. Acceleration and braking an extra 15% on top. Percentages are a guideline: find what works.
2. The mph shown reads lower than real at low speed and a little higher than real at high speed. Not by much.
3. Slowing to a stop, the car lowers closer to the ground in a cool dynamic way. After you get out it still
   wobbles slightly. Improve the wobble visually.
4. Turning and drifting, the low side of the car clips into the ground. Keep the tilt; raise the car a little as it
   turns or drifts so nothing goes underground. Smooth and dynamic.
5. Stationary or very slow, steering sometimes thinks the car is in reverse and turns the wrong way. With no
   forward or reverse held and speed about zero or above, assume forwards.

Must look great, be dynamic and fun, and stay cheap per frame.

## Owners (extend these; no new owner, script, remote or startup path)

| Concern | Owner | Part |
|---|---|---|
| Stat to physics mapping, balance multipliers | `ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics` | balance |
| Per-frame driving forces, hover, pose, steering intent, HUD speed | `...Vehicles.DrivingClient` | balance, pose, integrator |
| Parked hover after exit | `...Vehicles.FreeRoamParkedHoverClient` | pose |
| Tuning | `ReplicatedStorage.Config.Vehicles.*` attributes | all |

Nothing is saved, spent or sent. No stat, rating, PerformanceIndex, tier, price or catalogue value changes: the
nerf is applied where stats become forces, so garage ratings and saved data are untouched. Server files are not
touched. Feel attributes (`scripts/hover_feel/CONTRACT.md`) keep their meaning: `FeelSpeedMph` stays the real speed.

## Facts measured in v3 (2026-10-06)

- `HoverHeightStuds` = 2.3 (root centre above ground). Root part 7.5 x 1.2 x 10.5 on every car; body underside is
  0.6 below the root centre (0.8 on one Piercer), so clearance at rest today is about 1.7.
- Body half-width: Exotic 4.0, Piercer 4.1 to 5.0, Muscle 4.8. Length 17 to 25.
- Bank: `TurningBankDegrees` 12 + `DriftExtraBankDegrees` 5 = 17 degrees max, plus wobble roll.
- `Config.Vehicles.HoverWobble` does not exist, so the wobble runs on its code defaults.
- Spawned vehicles carry the replicated attribute `PerformanceIndex` (server `VehiclePerformance`). Tier bands:
  E 100, D 300, C 450, B 600, A 725, S 850.
- Live config: `before/config.json`. Live sources: `before/*.lua` (exact bytes).

## Parts and file ownership

Line numbers refer to `before/DrivingClient.lua`. A part only anchors edits inside its own regions.

### balance (agent)
- `VehicleDynamics.lua`: whole file.
- `DrivingClient.lua`: stats block 804-847; drift force block 995-1026; mini-boost and boost 1027-1116;
  turn rate 1121-1186 (only where a multiplier must be applied).
- Config: a new category folder `Config.Vehicles.Dynamics.08_Balance` (numeric attributes, each with a
  `_RaisingThisDoes` string, as the other categories have).

### pose (agent)
- `DrivingClient.lua`: `state` table fields 24-69; `updateHoverWobble` 513-543; resets in `Controller.Start`
  742-746 and `stopCameraAssist` 509-510; hover loop 881-901; pose 1205-1251 (wobble call and `Align.CFrame`);
  the anchored early-return branch 784-796 only to reset pose state.
- `FreeRoamParkedHoverClient.lua`: whole file.
- Config: new folders `Config.Vehicles.HoverWobble` (the names the code already reads) and
  `Config.Vehicles.HoverPose` (settle and bank lift).

### integrator (main session)
- `DrivingClient.lua`: steering intent 960-983; `updateExistingDriveUi` 568-577; anything left over.
- Build, install, Play tests, tuning of the numbers against the real cars.

## Interfaces between parts

- balance exposes `VehicleDynamicsModel.Balance(vehicle)` returning a table of multipliers (1 = unchanged), read
  once per frame in DrivingClient after `ResolveStats`. pose does not depend on it.
- pose keeps the existing meaning of `HOVER_HEIGHT` as the full ride height and derives everything from it:
  `rideHeight = HOVER_HEIGHT * settleScale + bankLift + bob`. `FeelHover` keeps meaning compression against the
  current target, so `state.Feel.HoverSum` must still be fed `targetDistance - result.Distance` with the dynamic
  target, and its divisor stays `HOVER_HEIGHT`.
- The driving and parked controllers must agree on height at hand-over (exit and re-entry) so the car never
  jumps: both use the same config and the same settle function of speed.

## Deliverable format (both agents)

`scripts/driving_tune/<part>/edits.py` defining:

```python
EDITS = {"DrivingClient": [(old, new, count), ...], "VehicleDynamics": [...], "FreeRoamParkedHoverClient": [...]}
INSTANCES = [{"parent": ["ReplicatedStorage","Config","Vehicles"], "name": "HoverPose", "class": "Folder",
              "attributes": {"Key": 1.0, "Key_RaisingThisDoes": "..."}}]
ATTRIBUTES = [(["ReplicatedStorage","Config","Vehicles","Driving"], "ExistingOrNewKey", value)]
```

Edits are exact-text replacements against the before file with the expected match count (tabs are tabs). Run
`py -3 scripts/driving_tune/build.py --part <part>` to check that the anchors apply; it writes
`scripts/driving_tune/<part>/after/*.lua` for reading. Plus `scripts/driving_tune/<part>/NOTES.md`: what was
built, each config value and why, what to look at in Play, anything unsure.

## Rules

- Luau, matching the surrounding style (tabs, `configNumber(folder, name, fallback, min, max)` with clamps).
- Every new behaviour has an enable switch or a value that turns it off (0 or 1), so it can be tuned live in
  Studio without a script edit. Config is read per frame through the existing readers (that is how the file
  already works), except constants that need a restart, which must say so.
- No new instances per frame, no new raycasts per frame beyond the four hover rays (pose may add none), no
  `GetDescendants` or `GetBoundingBox` per frame (once at start is fine), no new connections per vehicle beyond
  the existing Heartbeat. No `task.spawn` loops.
- Frame-rate independent smoothing (`1 - math.exp(-rate * dt)` or a semi-implicit spring with clamped dt).
- Guard against NaN: clamp dt, never divide by a config value without `math.max`.
- Do not touch Studio. The integrator installs and tests. No git commits.
- Do not rename or remove any existing attribute, function or state field. Do not change `Controller.Start/Stop`
  signatures.

## Done when

- Edit: sources compile; AUDIT clean; APPLY, ROLLBACK, APPLY clean.
- Play (Studio, keyboard, normal UI): drive, drift both ways, boost, brake to a stop, steer at a standstill,
  reverse, exit, re-enter; no console errors; measured top speed, 0 to 100 and clearance recorded in
  `verification.json`.
- Oscar judges the feel. Agent checks are not acceptance of taste.
