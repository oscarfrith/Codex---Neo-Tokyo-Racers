## A20. `Kit.Gauge`: gear readout, shift light, punch and `Step`; budget 28 (extends 3.2; drivetrain_feel; 2026-10-20)

To append to `scripts/ui_restyle/phase2/API2_AMENDMENTS.md` after A19. Source: `scripts/drivetrain_feel/hud/after/Gauge.lua`
(canonical copy: `kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge.lua`). Approved with the drivetrain_feel
plan (Oscar, 2026-10-20; `scripts/drivetrain_feel/CONTRACT.md` section 7). This entry is the recorded exception to
"the Kit API is frozen after the free-roam HUD" (PC 2.2). The delivery-reviewer signs it off with the delivery.

```lua
Gauge.Light: { Off = 0, Warm = 1, Shift = 2, Limiter = 3, Spin = 4, Overdrive = 5 }   -- frozen
Gauge.New(parent, props, scope): Component & {
  SetSpeed, SetBoost, SetUnit, SetVisibleBoost,                 -- unchanged
  SetGear: (text: string?) -> (),       -- "N", "R", "1".."7"; a number shows its digits; nil or "" hides the readout
  PunchGear: () -> (),                  -- one punch of the shown gear; nothing while no gear shows
  SetShiftLight: (level: number) -> (), -- a Gauge.Light level; anything else is Off
  Step: (dt: number) -> () }            -- advances the punch and light clocks; call once a frame, first in the owner's step
```

No new prop and no change to an existing signature, value or default. A gauge that is never given a gear (every car
without drivetrain telemetry, and Classic, which does not use the kit) looks and writes exactly as before.

**New part: one `TextLabel` named `Gear`** (child of the root, ZIndex 6, hidden at build).

- Built with `Text.RawLabel(root, role, ctx)` in its real role. Role per gauge, following the speed number's own
  steps: `Status` on the full Regular gauge, `Value` on the smaller Regular (touch) gauge, `SectionHead` on Compact
  (12.6 dp, larger than the 9.7 dp unit line it replaces). All three are Fixed (API2 2.6), so the gear carries a
  **`SizeLock`**, found once at build. `layout()` sets the face and size of the current role with `Text.Font` and
  `Text.SizeFor`, and writes the lock's `MaxTextSize` = the top punch step (the box height). The punch stays a plain
  `TextSize` write, and the player's Text Size setting grows the gear no further than its box (`TextFits` at Largest).
  `AutomaticSize` is `None`: the gear is live text (PC 4 "AutomaticSize only on static text"), and `layout()` sets
  its box.
- Placed in the empty bottom gap of the ring at `GEAR_Y = 0.41` of the frame on Regular (below the boost line). On
  Compact (92 dp, no boost line) it takes the unit line's place at `GEAR_Y_COMPACT = 0.205` (the unit's 0.181, lowered
  2 dp so the larger cap clears the speed digits) and **`Unit` is hidden while a gear shows**; `SetGear(nil)` shows it
  again. Regular keeps `Unit`.
- The box spans the frame width (text centred) and is as tall as the largest punch step, centred on its line, so a
  punch writes only `TextSize` and nothing relayouts.
- **Budget 26 becomes 28.** API2 count (root included, size locks excluded, as the k3 `budgetOf`): **27**. Raw
  descendants plus root, with the `BoostText` and `Gear` size locks: **29** (under the PC table's 32 for the gauge).
  Parts: root, Track, Ticks, ArcLeft, ArcRight, BoostLeft, BoostRight, 6 images, 6 masks, Tip, Speed (root + 3
  cells), Unit, BoostText (+ SizeLock), **Gear (+ SizeLock)**.

**Shift light: the gear text colour and the `Tip` tint, nothing else.** Baked images keep `ImageColor3` white and the
`Speed` BigNumber colour is never changed (`Set({Colour})` would rewrite every cell).

| Level | Gear text and tip |
|---|---|
| 0 Off | `White` (the tip's colour today) |
| 1 Warm | `Cyan` |
| 2 Shift | `Pink` |
| 3 Limiter | `Pink` / `White` flash at **3 Hz**, duty 0.5, lit on its first frame (phase-locked to the level change). HudView sends it in a gear only: the limiter in N (neutral revs on the countdown) shows as a steady 2 Shift, so there is no bounce effect in neutral |
| 4 Spin warning | amber = `Yellow:Lerp(Pink, 0.3)` (255, 173, 80), steady. Derived from tokens like the cash chip's warm yellow (Kit.Data `CASH_WARM`); no colour literal. A `Colour.Warning` token would replace it if the integrator prefers |
| 5 Overdrive | brightness pulse `Cyan` toward `White` (0 to 60%) and back at 1.5 Hz in 4 whole steps (precomputed colours, no per-frame `Color3` allocation) |

A light change writes 2 properties; a steady light writes nothing per frame. Flashing never exceeds 3 Hz (PC and
drivetrain_feel contract 7).

**Punch.** `PunchGear` sets `TextSize` to base x 1.15 at once, then `Step` settles it in whole steps (x1.10, x1.05,
base) on an exponential clock (time constant 0.12 s): about 0.22 s, at most 3 extra text sizes, one write per step,
capped at `Type.MaxTextSize`. No `UIScale` anywhere in the gauge. **Recorded exception to PC 4 "TextSize is never
tweened"**: one or two glyphs, discrete steps, at most one punch per shift (shifts are at least
`ShiftMinIntervalSeconds` 0.25 s apart). `SetGear(nil)` ends a running punch.
**Recorded exception to PC 4 "At most twelve distinct text sizes on screen"**, for the punch only. Its steps
(47, 45 and 43 at 1080 on the full gauge) are transient. The gear shows one size at a time, so at any moment the punch
adds at most one size to the screen, for about 0.22 s per shift. The gear's base size is a role size and counts
toward the twelve like any other text. The integrator's census checks the steady HUD with a gear showing.

**`Step(dt)`.** The gauge still has no frame binding of its own. The owner calls `Step` from its one `Perf.Bind` step
(HudView.Step; the gallery fixture's step). It is called **first** in that step, before the frame's `SetGear`,
`PunchGear` and `SetShiftLight`. A punch or light change is then drawn at its full value before its clock moves, so
the top punch step shows for one frame at any frame rate. Called after them, it would skip the x1.15 step below about
46 fps. `Step` returns at once when no punch runs and the light is steady, and it ignores `dt <= 0`, NaN and nil.
Clocks are time-based, so the flash rate and the punch length do not depend on frame rate; the frames sampled from
them do. The light clock wraps every 2 s (a whole number of flash and pulse periods). No lookup, no creation.

**Write costs** (counted by `_writes()`, which now includes these setters): `SetGear` 1 (text) and 1 to 3 on show or
hide (visibility, and `Unit` on Compact); `PunchGear` 1; `SetShiftLight` 2 on a change; `Step` at most 1 punch write
plus 2 light writes in a frame. Steady drive with telemetry adds nothing per frame; the rpm arc costs what the speed
arc did (2 mask writes and 1 tip write per half-degree step).

**Pure test seams** (outside API2, like `_sweep`): `_gearText`, `_lightLevel`, `_flashOn`, `_lightColour`,
`_punchLevel`, `_punchSize`.

**Users.** `FreeRoam.HudView` through `HudView._telemetry(gauge)` (drivetrain_feel contract 3.2 and 7: rpm arc with a
needle spring, gear, punch on `GearRevision`, `ShiftLight` 0..4 and `Overdrive` mapped onto `Gauge.Light`, the
limiter in N as a steady Shift); `Dev.Fixtures.Gauge` (states `GearN`, `Gear1`, `Gear7`, `Reverse`, `ShiftWarm`,
`ShiftLight`, `Limiter` (in 3rd), `NeutralLimiter`, `SpinWarning`, `Overdrive`, `GearPunch`, `GearRun`,
`GearTouchSize`; fixture props `Gear`, `Light`, `Punch`, `Rpm`).

**Style sheet** (`docs/design/pulse-racers-ui-style-sheet.md` line 209, "The outer arc is speed"): add "For a car that
sends drivetrain telemetry (Exotic) the outer arc is rpm, with the redline at 0.87 of the sweep inside the pink last
fifth, and the gear sits in the bottom gap (on a phone it replaces the unit line); the shift light is the gear's colour
and the tip." Line 144 (baked images never tinted) is unchanged and holds.

Tests: `kit/k3/tests/...Kit.Gauge_test.lua` (budget 28 by the API2 count, the gear `SizeLock` at the top punch step
and no `AutomaticSize`, gear show/hide and Compact unit swap, light colours, no baked or digit tint, 3 Hz at 60 and
20 fps, punch steps and no `UIScale`, steady-drive writes) and `...Dev.Fixtures.Gauge_test.lua` (the new states and
the gear run).
