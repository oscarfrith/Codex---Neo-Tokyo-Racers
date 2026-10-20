1. **MAJOR. `hud/after/Gauge.lua` lines 49 and 342–349, plus `placeGear` at 387–399.** The gear label is built as role `"Label"`, a growing role, so it has no `SizeLock`. Its real roles (Status, Value, SectionHead) are Fixed under API2 2.6, so this breaks the rule. The ui_restyle CONTRACT line 377 requires `TextFits` at the largest text setting, and that also fails here. The engine grows the gear past its reserved box, and on the 92 dp phone gauge it overlaps the speed digits. At default size the cap top already sits where the unit's cap was, about 1 dp under the digits. The reason given, staying at 28 raw instances, does not hold. The contract's "26" uses the API2 count, which excludes SizeLocks (k3 `budgetOf`), so a SizeLock still gives 27, which is within ≤ 28.
   - **Fix:** build the label with `Text.RawLabel(root, gearRole(), ctx)` and keep a reference to its lock at build time: `local gearLock = gear:FindFirstChild("SizeLock")`. This runs at build only, not per frame. In `placeGear`, add `write(gearLock, "MaxTextSize", peak)`. The punch stays a single `TextSize` write, and any growth from the player's setting is capped at the box height. Delete `GEAR_BUILD_ROLE`.
   - **Tests:** in `hud/tests/...Kit.Gauge_test.lua`, drop the `rawCountOf(root) <= 28` checks (lines 247, 259 and the Compact case), because the raw count becomes 29. Keep `budgetOf <= 28`. Add `expect(root.Gear.SizeLock.MaxTextSize == M._punchSize(base, 3))`.
   - **Docs:** correct the counts in A20 to "API2 27, raw 29", and update the NOTES risks.

2. **MAJOR. `hud/NOTES.md` lines 234–238 and 263–270 (bookkeeping step 1).** Step 1 copies the physics `DrivingClient` into the ui_restyle chain (`families/free_roam/after`, op `b_driving_keys`). That `DrivingClient` calls new `VehicleDynamics` functions with no guard: `DrivetrainCategory` at physics after line 1075 (called from Start), and `ResetGearbox` and `StepNeutral`. None of these exist in `before/VehicleDynamics.lua`, and `VehicleDynamics` is not in the chain.
   - **Failure case:** after a drivetrain ROLLBACK, live `DrivingClient` is back at 72479, which is now only a prior state of 02_free_roam. The next ui_restyle AUDIT flags it, and an APPLY or refit installs the drivetrain `DrivingClient` on top of the old `VehicleDynamics`. Start then calls a nil function, and driving is broken. The NOTES only covers ROLLBACK order.
   - **Fix, step 1 needs one of these:**
     - add a `source` op for `VehicleDynamics` (before = `before/VehicleDynamics.lua`, after = the physics after) to `families/free_roam/spec_ops_b.json`, so the unit carries both halves; or
     - require the physics part to guard the dependency (`typeof(VehicleDynamicsModel.DrivetrainCategory) == "function"`, otherwise inactive), so the chain's copy falls back to today's driving with the old `VehicleDynamics`.

     Record which option was chosen in the NOTES.

3. **MINOR. `hud/after/HudView.lua` lines 512–514; `hud/after/Fixtures.Gauge.lua` line 118.** `telemetry.Step` (which calls `PunchGear` and `SetShiftLight`) runs before `gauge.Step(dt)` in the same frame. The punch clock therefore advances a full dt before the first render. Below about 46 fps the top punch step (×1.15) is never drawn; at 30 fps the peak shown is ×1.10. A20's claim that the punch does not depend on frame rate is wrong.
   - **Fix:** call `gauge.Step(dt)` before `local rpm = telemetry.Step(dt, drive)` in HudView, and move `gauge.Step(dt)` to the top of the fixture's `step`. The limiter is still lit on its first frame.

4. **MINOR. `hud/after/HudView.lua` lines 179–185 and 232–236; `hud/after/Fixtures.Gauge.lua` line 194.** Physics sends `ShiftLight` 3 whenever `LimiterActive` is set, and that includes N on the anchored countdown or a teleport, where `NeutralRevTarget` 1.02 keeps the limiter bouncing for as long as W is held. The HUD then strobes Pink/White at 3 Hz for seconds. Critique-experience item 17 says "no bounce effects in neutral", and the contract is silent on the HUD side.
   - **Fix:** in `_telemetry.Step`, show limiter level 3 as steady Shift (2) when `drive.Gear == "N"`. Move the `Limiter` fixture to a driving gear (for example `"3"`) and add a steady `NeutralLimiter` state. Extend the light-mapping test to cover it.

5. **MINOR. `hud/after/Gauge.lua` line 342.** `Text.RawLabel` leaves `AutomaticSize = X` on the gear. The gear is live text: it changes on every shift and its `TextSize` steps on every punch. PC (ui_restyle CONTRACT line 332) says "AutomaticSize only on static text", and each punch write triggers an automatic-size pass.
   - **Fix:** add `gear.AutomaticSize = Enum.AutomaticSize.None` after the build. `placeGear` sets the box explicitly anyway.

6. **MINOR. `hud/API2_AMENDMENT.md` lines 52–56.** A20 records the exception to "TextSize is never tweened" but not the next rule in the same PC line 332: "At most twelve distinct text sizes on screen". The punch adds up to 3 transient sizes (47/45/43 at 1080).
   - **Fix:** add that exception to A20, or add a 12-size census of the live HUD during `GearPunch` to the integrator checks in NOTES item 5.

7. **MINOR. `hud/NOTES.md` lines 236–238.** Critique-delivery item 2 requires a durable record that `DrivingClient`'s recovery point has moved. The NOTES only says "Record that in the commit", and `state.json` is generated, so it cannot be hand-edited.
   - **Fix:** tell the integrator to extend `b_driving_keys._note` in `scripts/ui_restyle/phase2/families/free_roam/spec_ops_b.json`, which reassembly carries into `install/02_free_roam/spec.json`. Mention it in docs/06 as well. Do this in addition to the commit message.

Checked and fine:
- **Compile:** all four after files compile in PR98 Edit (OK 3099, 23922, 23540, 9001).
- **Fingerprints:** the NOTES fingerprints match the files.
- **Base copies:** the `before/` files are byte-identical to the canonical k3 and free_roam copies.
- **Physics telemetry:** it matches section 3.2 (`Overdrive` boolean, `Gear` string).
- **Classic manifest:** the six scripts NOTES lists are all recorded in it.

READY WITH FIXES