Fixed items:
1. **MAJOR, gear SizeLock** (`hud/after/Gauge.lua`): the gear is now built with `Text.RawLabel(root, gearRole(), ctx)`. `gearLock` is looked up once at build (`gear:FindFirstChild("SizeLock")`). `placeGear` writes `MaxTextSize` = the top punch step, with a nil guard in case a role constant is ever tuned to a growing role. `GEAR_BUILD_ROLE` is deleted. In the tests, the `rawCountOf <= 28` checks and the helper are gone, `budgetOf <= 28` stays, and `Gear.SizeLock.MaxTextSize == _punchSize(base, 3)` is checked on the full, touch-size and Compact gauges. A20 now reads "API2 27, raw 29 (under the PC table's 32)". The NOTES risks and census are updated.
2. **MAJOR, DrivingClient copied into the chain without VehicleDynamics**: I chose option (a) and recorded it in NOTES bookkeeping step 1.
   - A new 02_free_roam source op `b_drivetrain_dynamics` goes into `families/free_roam/spec_ops_b.json`, with the full JSON given. The before copy is `drivetrain_feel/before/VehicleDynamics.lua` and the after copy is the physics after.
   - I confirmed `before/VehicleDynamics.lua` is byte-identical to `ui_restyle/classic/sources/...VehicleDynamics.lua` (1003619947 / 195961823 / 25406), which `assemble.py` requires.
   - No other unit's spec_ops names VehicleDynamics. The physics after file lints with 0 findings under its dotted name.
   - Step 4 now pins five scripts instead of six, step 6 adds the VehicleDynamics `state.json` entry, and the recovery-point consequences are written out.
   - Option (b), a guard inside physics, is a physics-part change. It is recorded as a recommendation only.
3. **MINOR, punch clock ordering**: `gauge.Step(dt)` now runs before `telemetry.Step` in `hud/after/HudView.lua`, and at the top of the fixture `step` in `hud/after/Fixtures.Gauge.lua`. A20 and the Gauge `step` comment state the ordering.
4. **MINOR, limiter strobe in N**: `HudView._lightLevel(shiftLight, overdrive, gear)` maps 3 in `"N"` to a steady 2, using new constants `SHIFT_LIGHT` and `LIMITER_LIGHT`. The `Limiter` fixture moves to gear `"3"` (Speed 83) and there is a new steady `NeutralLimiter` state (N, Light 2). Tests cover it: light-mapping asserts, a new telemetry-driver case for N on the limiter, and fixture asserts.
5. **MINOR, AutomaticSize**: `gear.AutomaticSize = Enum.AutomaticSize.None` after the build, with a test.
6. **MINOR, twelve-text-sizes rule**: I did both options. A20 now records the transient exception: the gear shows one size at a time, so the punch adds at most one size for about 0.22 s. NOTES integrator check 5 adds a text-size census.
7. **MINOR, durable record of the moved recovery point**: NOTES now tell the integrator to extend `b_driving_keys._note` in spec_ops_b.json, add a line to docs/06, and say it in the commit message.

Declined:
- **The part of item 7 claiming reassembly carries `_note` into `install/02_free_roam/spec.json`.** It does not: `scripts/ui_restyle/phase2/tools/assemble.py` `family_ops` (line 398) drops every key starting with `_`. The durable record therefore stays in the committed, hand-authored spec_ops_b.json. Nothing else was declined.

Final compile check (PR98 Edit, bridge loadstring, after all after-file edits):
- DriveSessionClient: OK 3099 (unchanged)
- HudView: OK 24334
- Gauge: OK 24023
- Fixtures.Gauge: OK 9309

New fingerprints, recorded in NOTES:

| Script | Fingerprint |
|---|---|
| HudView | 2735155409-3541343987-24334 |
| Kit.Gauge | 3194700109-4098534631-24023 |
| Fixtures.Gauge | 1734057305-3955494879-9309 |

Other checks:
- **Phase2 lint**, run on each changed file on its own: the same findings as the `before/` copies, none new.
- **Kit-call checker** (free_roam and kit_fixtures, on a scratch copy of phase1 and phase2 with the new sources): ERROR 0, NOTE 2 and 20, the same as canonical.
- **Test files:** edited but not compiled or run. The contract allows the Studio compile check on after files only, and there is no offline Luau.

Files changed (all in `C:\Users\Oscar\Documents\LUCIDITY\Codex---Neo-Tokyo-Racers\scripts\drivetrain_feel\hud\`):
- after\Gauge.lua
- after\HudView.lua
- after\Fixtures.Gauge.lua
- tests\ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge_test.lua
- tests\ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudView_test.lua
- tests\ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge_test.lua
- NOTES.md (new "Review fixes" section at the end)
- API2_AMENDMENT.md