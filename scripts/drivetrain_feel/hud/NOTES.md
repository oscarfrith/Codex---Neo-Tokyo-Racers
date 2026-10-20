# hud part: rpm arc, gear readout and shift light (drivetrain_feel contract 3.2 and 7)

Status: **generated, compile-checked, linted; not installed, not run.** All four after files compile in PR98 Studio Edit
(the contract's loadstring check over the bridge: `OK` for each). The phase2 lint and the kit-call checker report no
new finding against the canonical sources (details under "Checks run"). The pure tests were written but not run:
there is no offline Luau, and the test runner (`scripts/ui_restyle/phase2/tools/run_tests_phase2.lua`) is the
integrator's Studio harness. The needle, flash, punch and layout numbers were cross-checked in Python.
The adversarial review (round 1) has been applied: see "Review fixes" at the end. Everything below describes the
files after those fixes.

## Files

| File | Base | What it is |
|---|---|---|
| `after/DriveSessionClient.lua` | `before/DriveSessionClient.lua` | `ReplicatedStorage.Modules.Game.Vehicles.DriveSessionClient` (Classic-recorded) |
| `after/HudView.lua` | `before/HudView.lua` | `ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudView` |
| `after/Gauge.lua` | `before/Gauge.lua` | `ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge` |
| `after/Fixtures.Gauge.lua` | `before/Fixtures.Gauge.lua` | `ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge` |
| `tests/...Kit.Gauge_test.lua` | `ui_restyle/phase2/kit/k3/tests/` | k3 test plus 9 cases |
| `tests/...Dev.Fixtures.Gauge_test.lua` | `ui_restyle/phase2/kit/k3/tests/` | k3 test plus 2 cases |
| `tests/...FreeRoam.HudView_test.lua` | `ui_restyle/phase2/families/free_roam/tests/` | family test plus 7 cases |
| `API2_AMENDMENT.md` | | entry A20 for `ui_restyle/phase2/API2_AMENDMENTS.md` |

Fingerprints at the time of writing (`djb2-fnv1a32-length`, the ui_restyle convention; `classic_declared.py`
recomputes them):

| Script | before (live 2026-10-20) | after |
|---|---|---|
| DriveSessionClient | 699830675-2795974467-2088 (= Classic baseline) | 2542873564-843433840-3099 |
| FreeRoam.HudView | 3772154053-3098603401-19189 (= 02_free_roam after) | 2735155409-3541343987-24334 |
| Kit.Gauge | 2502745895-1498110527-14702 (= 00_kit after) | 3194700109-4098534631-24023 |
| Dev.Fixtures.Gauge | 2664637028-3852216940-5423 (= 00_kit after) | 1734057305-3955494879-9309 |

## What changed and where

**DriveSessionClient**
- New local `publishTelemetry(mobile, telemetry)`. With a table it copies `Gear`, `GearRevision`, `RpmFraction`,
  `ShiftLight` and `Spin`, plus `Overdrive` as a boolean, onto `MobileDriveInputState`. With anything else it sets all
  six to nil.
- `PublishMobile(speedMph, boostPercent, telemetry)`: the third argument is optional. Every call ends with
  `publishTelemetry`, so a nil third argument clears the six fields that frame.
- `SetMobileDriving(false)`: after `mobile.Reset()` it clears the six fields (Reset does not know them).
  `MobileDriveInputState` is not edited. The file keeps its own 4-space indentation.

**HudView**
- Module constants `NEEDLE_OMEGA` 25, `NEEDLE_ZETA` 0.5, `SWEEP_UP/HOLD/DOWN` 0.2/0.06/0.24 s, and
  `SHIFT_LIGHT`/`LIMITER_LIGHT`/`SPIN_LIGHT`/`OVERDRIVE_LIGHT` 2/3/4/5 (the `Kit.Gauge.Light` values).
- `HudView._needleStep(position, velocity, target, dt, omega, zeta)` (pure): the exact closed-form step of an
  underdamped spring with the target held over dt. One 0.5 s step, 30 steps at 60 fps and 10 steps at 20 fps give
  the same result. zeta is clamped to 0.05..0.95. Overshoot at zeta 0.5 is 16% of the step.
- `HudView._startSweep(elapsed, live)` (pure): the start-up self-test. The needle goes 0 to full in 0.2 s, holds for
  0.06 s, then eases down to the live reading over 0.24 s. Total 0.5 s.
- `HudView._lightLevel(shiftLight, overdrive, gear)` (pure): maps `ShiftLight` 0..4 onto `Kit.Gauge.Light`. Overdrive
  maps to 5 unless the spin warning (4) is showing. The limiter (3) in `"N"` maps to a steady Shift (2): physics sends
  3 whenever `LimiterActive` is set, and neutral revs on the countdown hold the limiter for as long as W is held, so a
  3 Hz strobe would run for seconds (critique-experience item 17: no bounce effects in neutral). In a gear the limiter
  still flashes. Anything else maps to 0.
- `HudView._telemetry(gauge)` returns `{Step(dt, drive), Clear()}`.
  - `Step` returns nil when `drive.RpmFraction` is not a number. The caller then draws the speed arc exactly as before.
    If telemetry was showing, `Step` also clears it.
  - When telemetry first appears it starts the sweep. It treats the first `GearRevision` it sees as a baseline.
  - It calls `SetGear` when `drive.Gear` changes, `PunchGear` when `GearRevision` changes, and `SetShiftLight` when
    the mapped level changes. It returns the needle fraction.
  - `Clear` runs once, setting light 0 and hiding the gear.
- `Mount`: `local telemetry = HudView._telemetry(gauge)`. In `self.Step`, while driving: `gauge.Step(dt)` **first**,
  then `gauge.SetSpeed(floor(speed + 0.5), telemetry.Step(dt, drive) or clamp(speed / maxMph, 0, 1))`. Stepping the
  gauge's clocks before the telemetry setters means a punch or light change made this frame is drawn at its full value
  before the clock moves it on, so the top punch step (x1.15) shows for one frame at any frame rate. While not driving:
  `telemetry.Clear()`. This also resets the gear and the light when driving stops (critique item 21).
- The `DriveState` comment now lists the new fields. There is no new require, remote, attribute or bindable.

**Kit.Gauge** (API2 amendment A20 has the full API text)
- Module constants:
  - layout: `GEAR_Y` 0.41, `GEAR_Y_COMPACT` 0.205;
  - roles: `GEAR_ROLE` Status, `GEAR_ROLE_SMALL` Value, `GEAR_ROLE_COMPACT` SectionHead (all Fixed under API2 2.6);
  - punch: `PUNCH_SCALE` 0.15, `PUNCH_SECONDS` 0.12, `PUNCH_STEPS` 3;
  - light: `FLASH_HZ` 3, `FLASH_DUTY` 0.5, `PULSE_HZ` 1.5, `PULSE_STEPS` 4, `PULSE_REACH` 0.6, `LIGHT_WRAP` 2,
    `WARN_WARM` 0.3;
  - tables: `LIGHT`, and the derived `AMBER` and `PULSE_COLOURS`.
- Pure helpers `gearText`, `lightLevel`, `flashOn`, `pulseStep`, `lightColour`, `punchLevel` and `punchSize`, exposed
  as `Gauge._*` test seams. `Gauge.Light` is the frozen level table.
- In `New`:
  - the `shown` table gains `Gear`, `GearText`, `GearTextSize`, `Punch`, `Light` and `Colour`; `geometry` gains
    `GearSize`; a new `clocks` table holds `Punch` and `Light`;
  - one `gear` TextLabel is built after `BoostText` with `Text.RawLabel(root, gearRole(), ctx)`, so it carries the
    Fixed roles' `SizeLock`. `gearLock` is looked up once at build (no per-frame lookup). `AutomaticSize` is set to
    `None` (live text; PC "AutomaticSize only on static text"); `placeGear` sets the box;
  - new functions `gearRole()`, `placeGear()` and `unitShown()`. `placeGear` writes `gearLock.MaxTextSize` = the top
    punch step, which is also the box height: the punch stays one `TextSize` write, and the player's Text Size setting
    can grow the gear no further than its box;
  - `layout()` now calls `placeGear()` and writes `Unit.Visible`;
  - new setters `applyPunch`, `paint`, `setGear`, `punchGear`, `setShiftLight` and `step`;
  - the returned handle adds `SetGear`, `PunchGear`, `SetShiftLight` and `Step`.
- The header line now says the module owns the gear readout and its clocks, and not the frame binding.

**Dev.Fixtures.Gauge**
- New fixture props: `Gear`, `Light`, `Punch` and `Rpm`.
- `still()` now also applies the gear and the light.
- A frame clock runs when a state animates, punches, or shows a light that moves by itself (`wantsClock()`: limiter
  or Overdrive). The step calls `gauge.Step(dt)` first, as HudView does.
- `runAt(elapsed, period)` (pure, exposed as `_runAt`) drives the `GearRun` state: gears 1 to 7, needle 0.45 to 0.87,
  warm at 0.6 and lit at 0.85 of each gear's climb, never lit in top gear, and a punch on each shift.
- `component.Set` re-applies the still values unless an animation owns the gauge.
- New states, in this order:
  - `GearN`, `Gear1`, `Gear7`, `Reverse`;
  - `ShiftWarm`, `ShiftLight`, `Limiter` (3rd gear on the limiter, flashing), `NeutralLimiter` (N on the limiter: the
    steady shift light HudView maps it to), `SpinWarning`, `Overdrive`;
  - `GearPunch`, `GearRun`, `GearTouchSize`.

## Config values

This part creates no config. The HUD tuning in `Drivetrain.exotic` (contract 4.6: `HudRedlineSweep`,
`HudShiftLeadSeconds`, `HudShiftMinFraction`, `HudWarmBandFraction`) is read by DrivingClient, which sends the result
already mapped as `RpmFraction` and `ShiftLight`. Pulse view code may not read attributes, and HudClient (which caches
HUD config) is not owned here. The HUD's own feel is therefore set by named module constants at the top of each file.
Each one changes the feel, not any data:

| Constant | File | Default | Raising it |
|---|---|---|---|
| `NEEDLE_OMEGA` | HudView | 25 rad/s | a quicker, stiffer needle. Lower is lazier |
| `NEEDLE_ZETA` | HudView | 0.5 (0.05..0.95) | less overshoot. 0.5 gives 16%; 0.7 gives about 5% |
| `SWEEP_UP`, `SWEEP_HOLD`, `SWEEP_DOWN` | HudView | 0.2, 0.06, 0.24 s | a slower start-up self-test |
| `GEAR_Y`, `GEAR_Y_COMPACT` | Kit.Gauge | 0.41, 0.205 of the frame | the gear moves down |
| `GEAR_ROLE`, `GEAR_ROLE_SMALL`, `GEAR_ROLE_COMPACT` | Kit.Gauge | Status, Value, SectionHead | a text role name: a larger role is a larger gear |
| `PUNCH_SCALE` | Kit.Gauge | 0.15 | a bigger punch. 0 means no punch |
| `PUNCH_SECONDS` | Kit.Gauge | 0.12 s | a longer punch |
| `PUNCH_STEPS` | Kit.Gauge | 3 | a smoother punch, with more text sizes |
| `FLASH_HZ` | Kit.Gauge | 3 | must stay at 3 or less (the programme's flashing ceiling) |
| `PULSE_HZ`, `PULSE_REACH` | Kit.Gauge | 1.5, 0.6 | a faster or brighter Overdrive pulse |
| `WARN_WARM` | Kit.Gauge | 0.3 | a more orange spin warning (toward Pink) |
| `RUN_*`, `PUNCH_REPEAT` | Fixtures.Gauge | | gallery only |

If Oscar wants the needle in config later, HudClient should read two numbers once at start and pass them in
`extra`, as it does for `SpeedGaugeMaxMph`. That is a HudClient edit, outside this part.

## What was preserved

- **Cars without telemetry draw exactly what they drew before.** `RpmFraction` is nil for every non-Exotic car and
  for an Exotic with `Enabled` 0. The arc is then `clamp(speed / maxMph, 0, 1)` as before, the gear stays hidden, the
  tip stays White, and `Unit` stays visible. Each frame adds one table read, two function calls that return early,
  and six nil assignments in `PublishMobile`. Nothing is written to any instance.
- Every existing Gauge signature, prop, default, value and part is unchanged. So are the existing k3 test
  expectations (writes 5 on the first SetSpeed, 0 when parked, and so on); only the budget line moves from 26 to 28.
- The baked gauge images are never tinted. The `Speed` BigNumber colour never changes. There is no UIScale. There is
  no `GetAttribute`, `FindFirstChild`, `WaitForChild`, `GetDescendants` or `Instance.new` in any per-frame path. Every
  write sits behind a comparison.
- `MobileDriveInputState` is not edited. Classic HUDs read only `SpeedMph`, `BoostPercent` and `IsDriving`, which are
  unchanged. The new fields are additive, and Classic ignores them.
- The race HUD uses the free-roam gauge (`KEEP_TELEMETRY`), so it gets the same rpm arc and gear. The contract scope
  ignores races; nothing here is race-specific.

## Interface the physics part must meet (contract 3.2)

- Call `context.PublishMobile(speedMph, state.Boost, telemetry)` with one table preallocated at module load. Pass it
  only while the drivetrain is active; otherwise pass nil.
  - This includes the anchored branch (`updateExistingDriveUi(0)` at before-line 1083), so neutral revs and N show on
    the countdown.
  - `SetMobileDriving(false)` is already called in Stop.
- Fields:
  - `Gear`: a string, `"N"`, `"R"` or `"1"`..`"7"`.
  - `GearRevision`: a number, +1 per shift event, including Launch. The HUD punches on every change after the first
    value it sees.
  - `RpmFraction`: 0..1, already mapped so the redline sits at `HudRedlineSweep`.
  - `ShiftLight`: 0..4.
  - `Spin`: 0..1. Carried, but not drawn by the HUD; the amber comes from `ShiftLight` 4.
  - `Overdrive`: a boolean.
- During Overdrive, send `ShiftLight` 0 (there is no upshift in top gear and no limiter cut). The HUD pulses Cyan.
  The spin warning (4) still wins.
- `ShiftLight` 3 may be sent in N (neutral revs on the countdown). The HUD shows it there as a steady shift light, so
  physics needs no special case.

## Test hooks

- **Gallery** (`Config.Development.ClientTools@PulseGalleryEnabled`, item `Gauge.Gauge`):
  - the thirteen new states listed above, at R720, R1080, R1440, C844 and C568;
  - `GearRun` publishes `GaugeFrames` and `GaugeWrites` on the gauge root once a second, as `Sweep` does, for a
    writes-per-frame probe.
- **Seams:**
  - `gauge._writes()` now counts the gear, light, punch and Step writes;
  - Kit.Gauge: `_gearText`, `_lightLevel`, `_flashOn`, `_lightColour`, `_punchLevel`, `_punchSize`;
  - HudView: `_needleStep`, `_startSweep`, `_lightLevel`, `_telemetry`;
  - Fixtures.Gauge: `_runAt`.
- **New test cases:**
  - Kit.Gauge:
    - budget 28 by the API2 count (size locks excluded), on Regular and Compact;
    - the gear carries a `SizeLock` whose `MaxTextSize` is the top punch step (full, touch-size and Compact gauges)
      and has no `AutomaticSize`;
    - gear show, change and hide, with write counts;
    - Compact unit swap, gear larger than the unit;
    - light colours on text and tip only, with every other image and digit colour unchanged;
    - limiter at most 3 Hz, measured at 60 and 20 fps;
    - a steady light and an idle Step write nothing;
    - punch steps, at most 4 sizes, settled within a second, no UIScale, ended by `SetGear(nil)`;
    - a size change re-places the gear;
    - setters are quiet after Destroy;
    - steady drive with telemetry costs at most 4 counted writes a frame.
  - Fixtures.Gauge: every required state is present (the flashing `Limiter` in a gear, `NeutralLimiter` steady in N),
    plus the gear-run maths.
  - HudView:
    - the needle step matches across frame rates, settles, and overshoots slightly;
    - the sweep reaches full, ends on the live value, and takes about 0.5 s;
    - the light mapping, including the limiter in N as a steady shift light;
    - the telemetry driver in N on the limiter sends one steady shift light, and the limiter level once in a gear;
    - the telemetry driver against a fake gauge: no telemetry makes no gauge calls; the sweep runs; the gear is set
      on change; the punch fires on a new revision, with the first one as a baseline; lights; the clear runs once;
      when telemetry returns, its revision is a new baseline;
    - the needle is frame-rate independent after the sweep.

## What the integrator checks in Studio and Play

1. Run the three test files through `run_tests_phase2.lua` once they are copied into the chain (see bookkeeping).
2. **Gallery captures** of the thirteen states at R1080, R1440 and C844, and of `GearTouchSize` at R1080:
   - the gear sits in the bottom gap below `BOOST 64%`, clear of the arc ends and the boost line;
   - on C844 it sits where `MPH` was, clear of the speed digits, and `MPH` is gone;
   - `Limiter` (3rd gear) flashes at no more than 3 Hz; `NeutralLimiter` is a steady pink N with no flash;
   - the `Overdrive` pulse is visible but calm;
   - `SpinWarning` reads as amber, not as cash yellow;
   - `GearPunch` is visible and does not clip;
   - the Largest-text pass (`TextFits`, ui_restyle CONTRACT line 377). The gear's `SizeLock` caps it at the top punch
     step, the height of its box, so it should not grow past the box; check the C844 gear stays clear of the speed
     digits at Largest.
3. **Play, Exotic, desktop and phone emulation:**
   - the start-up sweep on entering;
   - N with neutral revs on the countdown;
   - 1 to 7 with a punch per shift;
   - the light warms and turns pink before upshifts only, never in top gear;
   - the limiter flash in a gear; in N on the countdown with W held, a steady pink N and no flash;
   - Overdrive at the boosted top;
   - amber before a spin;
   - after exit and re-entry, no stale gear or light.
4. **Play, a non-Exotic car:** the speed arc, no gear, a white tip, `MPH` on the phone. This must look the same as
   before the install.
5. **`write_probe`** on `DesktopFreeRoamHudLive` over 10 s of steady Exotic driving: median of 16 or fewer writes per
   frame. The estimate is the same as today: 2 mask writes and 1 tip write per half-degree step, plus the digits.
   The rpm arc is still in steady cruise. **`instance_census`:** the gauge is 27 by the API2 count (root included,
   size locks excluded; budget 28) and 29 raw, with the `BoostText` and `Gear` size locks (under the PC table's 32
   for the gauge).
   **Text-size census** (PC "at most twelve distinct text sizes on screen"): count the distinct `TextSize` values of
   visible text on the live free-roam HUD with an Exotic gear showing, at R1080 and C844. The steady count must be 12
   or fewer, with the gear's base size counted like any other text. Repeat during `GearPunch` (or a live shift): the
   gear shows one size at a time, so the punch can add at most one size for about 0.22 s. A20 records that transient
   as an exception; a steady count over 12 is a finding.

## ui_restyle bookkeeping (the integrator applies it, in the same commit)

The ui_restyle install chain tracks three of these scripts by fingerprint, and the Classic verify tracks all ten
scripts of the delivery. Without the steps below, the next ui_restyle AUDIT (Phase 9 hardening, Phase 10 retirement,
any refit) blocks:
- Kit.Gauge and Fixtures.Gauge (00_kit `create` ops) and HudView (02_free_roam `create` op) report "created script was
  edited since install".
- DrivingClient (02_free_roam `source` op `b_driving_keys`) reports "source matches no recorded hash".

A rebuild from the stale canonical `after/` would also silently revert the gear HUD. And the chain must never hold the
drivetrain DrivingClient without the drivetrain VehicleDynamics (step 1).

1. **Canonical sources** (byte copies):
   - `hud/after/Gauge.lua` to `scripts/ui_restyle/phase2/kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge.lua`
   - `hud/after/Fixtures.Gauge.lua` to `.../kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge.lua`
   - `hud/after/HudView.lua` to `.../families/free_roam/after/ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudView.lua`
   - the physics part's `after/DrivingClient.lua` to
     `.../families/free_roam/after/ReplicatedStorage.Modules.Game.Vehicles.DrivingClient.lua`. This file is
     physics-owned.
   - **VehicleDynamics goes into the chain with it (review item 2: option a chosen).** The physics DrivingClient calls
     new VehicleDynamics functions with no guard (`DrivetrainCategory` from Start, `ResetGearbox`, `LaunchGearbox`,
     `StepNeutral`, `DrivetrainProfile`, `DrivetrainTuning`). None exists in the old VehicleDynamics. If the chain
     carried only DrivingClient, an APPLY or refit of 02_free_roam after a drivetrain ROLLBACK would put the new
     DrivingClient over the old VehicleDynamics, Start would call nil, and driving would break. So the unit carries
     both halves:
     - copy the physics part's `after/VehicleDynamics.lua` to
       `.../families/free_roam/after/ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics.lua`;
     - copy `scripts/drivetrain_feel/before/VehicleDynamics.lua` to
       `.../families/free_roam/before/ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics.lua`. assemble.py
       requires a source op's `before/` to be a byte copy of `classic/sources`. Checked 2026-10-20: the drivetrain
       before copy is byte-identical to `ui_restyle/classic/sources/...VehicleDynamics.lua` (Classic manifest
       1003619947 / 195961823 / 25406), so live VehicleDynamics has not changed since the Classic baseline;
     - add one op to `.../families/free_roam/spec_ops_b.json`, after `b_driving_keys`:
       ```json
       {"_note": "drivetrain_feel 2026-10-20: b_driving_keys now installs the drivetrain DrivingClient, which calls VehicleDynamics.DrivetrainCategory, ResetGearbox, StepNeutral and more with no guard; this op keeps the two halves together so no APPLY or refit installs one without the other",
        "after": "after/ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics.lua",
        "before": "before/ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics.lua",
        "class": "ModuleScript", "id": "b_drivetrain_dynamics", "kind": "source",
        "path": ["ReplicatedStorage", "Modules", "Game", "Vehicles", "VehicleDynamics"]}
       ```
       No other unit edits VehicleDynamics (no other `spec_ops*.json` names it), so the rule of one after-hash per
       Classic script holds. assemble.py prints "EDITS A CLASSIC SCRIPT" for this op, which is expected. Under its
       dotted name, the physics after file has 0 phase2 lint findings (checked 2026-10-20), the same as DrivingClient.
     - Option b would have physics guard the dependency (`typeof(VehicleDynamicsModel.DrivetrainCategory) ==
       "function"`, otherwise inactive), as it already guards `StepHandling`. That is a physics-part change, which
       the hud part cannot make. It is worth adding as defence in depth, but option a does not depend on it.
   - **Recovery points afterwards:**
     - To undo only the drivetrain, use drivetrain_feel's ROLLBACK. It restores DrivingClient to 72479 and
       VehicleDynamics to the Classic baseline, the pair that ran before.
     - 02_free_roam's ROLLBACK now takes DrivingClient and VehicleDynamics back to the Classic baseline together. That
       removes the drivetrain and the 2026-10-09 key swap at once.
     - After a drivetrain ROLLBACK, a 02_free_roam AUDIT reports DrivingClient at a prior state (72479) and
       VehicleDynamics at `before`. A refit APPLY then installs both drivetrain halves together, so driving stays
       consistent.
   - **Durable record of the moved recovery point** (critique-delivery item 2; review item 7):
     - Extend `b_driving_keys._note` in `.../families/free_roam/spec_ops_b.json` with: "drivetrain_feel 2026-10-20:
       after is now the drivetrain DrivingClient (physics part); pairs with b_drivetrain_dynamics; to undo only the
       drivetrain use drivetrain_feel's ROLLBACK".
     - assemble.py strips keys that start with `_` (`family_ops`, line 398), so this note stays in spec_ops_b.json
       and does not reach the generated `install/02_free_roam/spec.json`. spec_ops_b.json is the hand-authored,
       committed source, so it is the durable place.
     - Also add a line to docs/06 (next to UI-01, or in the drivetrain entry), and say it in the commit message.
2. **Canonical tests:**
   - `hud/tests/...Kit.Gauge_test.lua` and `hud/tests/...Dev.Fixtures.Gauge_test.lua` to `.../kit/k3/tests/`
   - `hud/tests/...FreeRoam.HudView_test.lua` to `.../families/free_roam/tests/`
3. **API text:**
   - append `hud/API2_AMENDMENT.md` to `scripts/ui_restyle/phase2/API2_AMENDMENTS.md` as A20;
   - amend style sheet line 209 as A20 says.
4. **Scripts outside the chain:**
   - Add a `"scripts"` block to `scripts/ui_restyle/phase2/declared_config.json` pinning the five Classic-recorded
     drivetrain scripts that no ui_restyle unit owns, each with its after fingerprint: `Vehicles.DriveSessionClient`,
     `Vehicles.DrivingCameraClient`, `Vehicles.VehicleVFXClient`, `Audio.VehicleAudioClient`,
     `Audio.VehicleAudioCatalog`. `Vehicles.VehicleDynamics` is no longer in this list: the 02_free_roam op from step 1
     pins it.
   - Add about 3 lines to `tools/assemble.py` `Assembler.declared()` so it merges `extra.get("scripts")` into
     `declared["scripts"]` where a unit has not pinned the path. Today it merges only config and unpinned
     `addedScripts`.
   - Extend the file's `_note` the way the radio did.
   - Without this, every later unit's Classic verify reports those five as "changed".
5. **Reassemble the whole chain in order:**
   `py -3 scripts/ui_restyle/phase2/tools/assemble.py kit`, then `race_menu`, `free_roam`, `world_map`,
   `race_session`, `race_entry`, `garage`, `shell`. Reassembling `kit` drops the later units from the chain; the
   phone pass (commit 3f5d90b3) did the same. This regenerates for every unit:
   - `install/<NN>_<unit>/after`, `tests`, `spec.json` and `declared.json`;
   - `out_verify_classic_<NN>_<unit>.lua`, `test_manifest.json`, `out_audit/apply/rollback.lua` and
     `applied_hashes.json`;
   - `install/state.json`. The file is generated: do not hand-edit it.
6. **Expected `state.json` entries afterwards:**
   - `00_kit` `Kit.Gauge` fp `3194700109-4098534631-24023`;
   - `00_kit` `Dev.Fixtures.Gauge` fp `1734057305-3955494879-9309`;
   - `02_free_roam` `FreeRoam.HudView` fp `2735155409-3541343987-24334`;
   - `02_free_roam` `Vehicles.DrivingClient` fp: the physics after-hash;
   - `02_free_roam` `Vehicles.VehicleDynamics` (new, `kind` source, `classic` true) fp: the physics after-hash.

   The old fingerprints move to each unit's `applied_hashes.json` as prior states. `07_shell/declared.json` then pins
   the new HudView, Kit.Gauge and Fixtures.Gauge under `addedScripts`, and the new DrivingClient and VehicleDynamics
   under `scripts`.
7. **AUDIT of the reassembled 00_kit and 02_free_roam against live after this delivery's APPLY:** every op reports
   `after`. Do not APPLY them; they would write the same bytes.
8. **Classic verify for this delivery:** the integrator's `scripts/drivetrain_feel/classic_declared.py` already does
   what critique-delivery item 1 asks.
   - It starts from 07_shell's `declared.json`.
   - It re-pins DriveSessionClient and the other Classic-recorded scripts under `scripts`, and HudView, Kit.Gauge and
     Fixtures.Gauge under `addedScripts`.
   - Use the committed 07_shell verify before APPLY and after ROLLBACK, and `classic/out_verify_classic_after.lua`
     after APPLY.
   - No `configNodes` or `configAttrs` are needed. `Config.Vehicles.*` and `Config.Audio.*` are outside the Classic
     config record (`Config.UI`, `.Development`, `.Player`).
9. **The radio unit** (`scripts/ui_restyle/radio`) is already historical for HudView: its `hud_view` op pins the
   15330-byte source, and the phone pass replaced that. Do not re-run its installer.
10. **Classic smoke check** (AGENTS line 29): with `UIStyle = Classic`, drive an Exotic and a non-Exotic car. The
    Classic speed gauge shows speed only. This delivery records the Pulse-only gear HUD as contract scope ("Classic UI
    gauge changes" not in scope); note it in docs/06 next to UI-01.

## Checks run

- **Compile** (PR98 Studio Edit, through the bridge on 8797, loadstring only), on the files after the review fixes:
  `DriveSessionClient OK 3099`, `HudView OK 24334`, `Gauge OK 24023`, `Fixtures.Gauge OK 9309`.
- **Phase2 lint** (`tools/lint_phase2.py`):
  - first round, kit unit with the new k3 files: 14 findings, identical to the canonical kit (all pre-existing; none
    in Gauge or Fixtures.Gauge);
  - first round, free_roam unit with the new HudView: 3 findings, identical to canonical (pre-existing radio and
    `PlayerVehicles`). The Perf.Bind step trace through `view.Step` finds no forbidden call;
  - after the review fixes, `--path` on each of Gauge, HudView and Fixtures.Gauge: the same findings as the
    `before/` file (only the loose-file header naming, plus the pre-existing RadioStripView require in HudView).
- **Kit-call checker** (`tools/check_kit_calls.py`, free_roam and kit_fixtures), after the review fixes, run on a
  scratch copy of phase1 and phase2 with the three new sources in place: ERROR 0, NOTE 2 and 20, the same as
  canonical.
- **Python cross-check** of the maths:
  - needle: 60 fps, 20 fps and one step agree to 1e-15; peak overshoot 0.781 for a 0.2 to 0.7 step;
  - limiter: 11 changes in 2 s at 60 fps and 12 at 20 fps;
  - punch sizes for a base of 41: 47, 45, 43, then 41 after 0.217 s. With `gauge.Step` run before the setters, the
    47 step is drawn for one frame at any rate; before the fix it was skipped below about 46 fps (30 fps peaked at 45);
  - layout:
    - Compact gear centre +19.5 dp, against the unit's +17.5;
    - Regular gear box 343..390 in a 402 frame, with the boost box ending at 340;
    - touch-size gear caps clear the boost caps by about 6 px;
  - Status size at scales 0.667, 1, 1.333 and 2: 27, 41, 55, 82, peaking at 31, 47, 63, 94 (under 100).

## Open risks

- **Sizes and positions not seen.** The gear position, role sizes and amber are numbers chosen from geometry, not
  from a capture. They are the first thing to check in the gallery.
- **Gear `SizeLock` at the top punch step.** The gear now carries a `SizeLock` (review item 1). Its `MaxTextSize` is
  the top punch step, so the player's Text Size setting can grow the gear by at most about 15%, which fits its box.
  The engine's Largest multiplier is still a [spike] in the ui_restyle contract. If the C844 gear still touches the
  speed digits at Largest, lower `GEAR_Y_COMPACT`. The count is 27 by API2 (budget 28) and 29 raw.
- **Exceptions to programme rules that the reviewer must accept.** Each is recorded in A20:
  - TextSize steps for the punch (PC 4 "TextSize is never tweened"), and at most one transient extra size for about
    0.22 s per shift (PC 4 "at most twelve distinct text sizes on screen");
  - the Kit API extension after its freeze (PC 2.2);
  - the amber derived from Yellow (Yellow is otherwise cash only);
  - the rpm arc in place of speed for telemetry cars (style sheet line 209).
- **The needle sweep reruns** after a HUD remount, which happens when the screen class or arrangement changes mid-drive.
- **Unverified physics-side assumptions:**
  - the HUD trusts `RpmFraction` to be already mapped (redline at 0.87) and the light rules to live in DrivingClient;
  - a wrong mapping shows as a wrong arc, not as an error.
- **HUD tuning is not in config.** It is set by module constants, because Pulse views cannot read attributes and
  HudClient is outside this part.
- **Physics does not guard its VehicleDynamics calls.** Bookkeeping step 1 (option a) keeps the two halves together
  in the chain. A guard in the physics DrivingClient (option b) would also protect any other route that installs one
  without the other. That is for the physics part or the integrator to decide.

## Review fixes (adversarial review, round 1)

| Item | Severity | Result |
|---|---|---|
| 1. Gear built as a growing role with no `SizeLock` | MAJOR | **Fixed.** Built with `Text.RawLabel(root, gearRole(), ctx)`. `gearLock` is looked up once at build, and `placeGear` writes its `MaxTextSize` = the top punch step (guarded for a growing role, if a constant is ever tuned to one). `GEAR_BUILD_ROLE` is deleted. Tests drop the raw `<= 28` checks, keep `budgetOf <= 28`, and assert `Gear.SizeLock.MaxTextSize == _punchSize(base, 3)` on the full, touch-size and Compact gauges. A20 now says API2 27, raw 29. |
| 2. Chain copy of DrivingClient without VehicleDynamics | MAJOR | **Fixed in the bookkeeping (option a).** Step 1 adds the `b_drivetrain_dynamics` source op, with its before and after copies, to 02_free_roam. Option b is a physics-part change, so it is recorded as a recommendation only. |
| 3. Punch clock advanced before the first render | MINOR | **Fixed.** `gauge.Step(dt)` now runs before `telemetry.Step` in HudView, and at the top of the fixture's step. A20 and the Gauge `step` comment state the ordering. |
| 4. Limiter strobe in N on the countdown | MINOR | **Fixed.** `HudView._lightLevel(shiftLight, overdrive, gear)` maps 3 in `"N"` to a steady 2. The `Limiter` fixture moves to 3rd gear, and there is a new steady `NeutralLimiter` state. Tests cover the mapping, the driver and the fixtures. |
| 5. `AutomaticSize = X` on live gear text | MINOR | **Fixed.** `gear.AutomaticSize = None` after the build, with a test. |
| 6. Twelve-sizes rule not covered | MINOR | **Fixed both ways.** A20 records the transient exception: the gear shows one size at a time, so the punch adds at most one size for about 0.22 s. Integrator check 5 adds a text-size census. |
| 7. Durable record of the moved recovery point | MINOR | **Applied, with one correction.** The NOTES now tell the integrator to extend `b_driving_keys._note` in spec_ops_b.json, add the docs/06 line and say it in the commit. The review said reassembly carries `_note` into `install/02_free_roam/spec.json`. It does not: `assemble.py` `family_ops` drops every `_` key (line 398). The note stays in the hand-authored spec_ops_b.json, which is committed and durable. |

No item was declined.
