The hud part is written: all four after files compile in PR98 Studio Edit (the loadstring check returned OK for each), but none of the new tests have run. There is no offline Luau, and the test runner only works in the integrator's Studio harness.

**Files written**
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\after\DriveSessionClient.lua` (compiles, 3099 bytes)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\after\HudView.lua` (23922)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\after\Gauge.lua` (23540)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\after\Fixtures.Gauge.lua` (9001)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\tests\` holds three test files: the Kit.Gauge and Fixtures.Gauge tests copied from k3 and extended, and the free_roam HudView test copied and extended.
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\API2_AMENDMENT.md` (entry A20)
- `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\NOTES.md`

**What each file does**
- **DriveSessionClient:** `PublishMobile(speed, boost, telemetry)` copies the six telemetry fields onto the shared drive state. A nil third argument clears all six, and so does `SetMobileDriving(false)` after `Reset()`. `MobileDriveInputState` itself is not edited.
- **HudView:** when `RpmFraction` is nil, the arc is exactly today's speed arc and nothing else is drawn.
  - With telemetry, the arc shows rpm through a needle spring (ω 25, ζ 0.5). The spring step is exact, so it moves the same at 60 fps, 20 fps or in one step.
  - The arc does a 0.5 s start-up sweep on first telemetry.
  - The gear is set when it changes. A gear change punches the readout, but the first `GearRevision` seen is only a baseline.
  - `ShiftLight` 0–4 and `Overdrive` map onto the gauge's light levels; the spin warning wins over Overdrive.
  - Gear and light are cleared when driving stops or telemetry disappears. `Gauge.Step(dt)` is called from `HudView.Step`.
- **Kit.Gauge:** adds one gear TextLabel in the empty bottom gap of the ring, plus `SetGear`, `PunchGear`, `SetShiftLight`, `Step` and `Gauge.Light`.
  - The punch writes `TextSize` in 3 whole steps (about 0.22 s). There is no UIScale.
  - The shift light changes only the gear text colour and the existing tip: White, then Cyan for warm, Pink for shift.
  - The limiter flashes Pink/White at 3 Hz, the spin warning is amber, and Overdrive is a 1.5 Hz cyan brightness pulse.
  - Baked images and the speed digits are never tinted.
  - On the phone gauge the gear replaces the `MPH` line while it shows.
  - The gauge is 28 instances counted raw, 27 by the API2 count.
  - Nothing in the per-frame path calls `GetAttribute` or `FindFirstChild`. A steady light or an idle `Step` writes nothing.
- **Fixtures.Gauge:** 12 new states: `GearN`, `Gear1`, `Gear7`, `Reverse`, `ShiftWarm`, `ShiftLight`, `Limiter`, `SpinWarning`, `Overdrive`, `GearPunch`, `GearRun` (animated, for the writes-per-frame probe) and `GearTouchSize`.

**Checks run**
- **Lint:** `lint_phase2.py` on the kit and free_roam units with the new files gives the same findings as the current sources. Its per-frame trace through `view.Step` finds nothing forbidden.
- **Kit-call checker:** `check_kit_calls.py` reports no errors and the same notes as before.
- **Maths:** a Python port confirmed the needle, flash rate, punch sizes and layout numbers the tests rely on.

**Decisions and open risks**
- **Gear has no size lock.** It is built without the usual text size constraint, so the punch is a plain `TextSize` write and the gauge stays at 28 parts. The catch is that the gear grows with the player's Text Size setting, like the unit line does. At the Largest setting the phone gear may touch the speed digits.
- **Rule exceptions recorded in A20, for the reviewer to accept:**
  - stepping `TextSize` for the punch;
  - extending the Kit API after it was frozen;
  - deriving the amber from Yellow, which is otherwise cash-only;
  - the rpm arc taking the place of speed, which needs the style sheet line 209 edit.
- **Not seen yet:** gear positions, text sizes and the amber were chosen from geometry, not from a capture. They are the first thing to check in the gallery.
- **HUD tuning is not in config.** The needle, punch and colour values are named constants at the top of each file, because Pulse views can't read attributes and HudClient isn't in this part.

**Bookkeeping the integrator must do** (exact list in NOTES.md):
- **Canonical copies:**
  - Gauge and Fixtures.Gauge go to `kit/k3/after`, their tests to `kit/k3/tests`.
  - HudView goes to `families/free_roam/after`, its test to `families/free_roam/tests`.
  - The physics `DrivingClient` also goes to `families/free_roam/after`. After that, the drivetrain ROLLBACK must run before any 02_free_roam rollback.
- **Six Classic scripts outside the chain:** pin them under a new `"scripts"` block in `phase2/declared_config.json`, plus about 3 lines in `assemble.py` so it merges that block:
  - DriveSessionClient, VehicleDynamics, DrivingCameraClient
  - VehicleVFXClient, VehicleAudioClient, VehicleAudioCatalog

  Without this, every later ui_restyle Classic verify fails on them.
- **Reassemble the whole chain in order:** kit, race_menu, free_roam, world_map, race_session, race_entry, garage, shell. This regenerates `state.json`; the expected new fingerprints are in NOTES. Without it, the next ui_restyle AUDIT blocks on Kit.Gauge, Fixtures.Gauge, HudView and DrivingClient.
- **API text:** append A20 to `API2_AMENDMENTS.md` and amend style sheet line 209.
- **Classic verify:** before APPLY, use the existing 07_shell set; after APPLY, use your `classic_declared.py`. No Classic config declarations are needed.
- **Classic smoke check:** drive an Exotic and a non-Exotic car with `UIStyle = Classic`; the Classic gauge should show speed only.