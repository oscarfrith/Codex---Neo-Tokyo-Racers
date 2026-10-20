# PR98 HUD and downstream consumers: report for the gearbox, weight and spin-out plan (read-only research)

Studio PR98 (`09a86975-…`) was read in Edit mode. Nothing was changed. The live value is `ReplicatedStorage.Config.UI@UIStyle = "Pulse"`, with `UIStyleDevFamilies = ""`. Facts below were read from source unless marked INFERRED.

---

## A. HUD

### A1. How the speed reaches the gauge (one channel for every HUD)

1. **`ReplicatedStorage.Modules.Game.Vehicles.DrivingClient` lines 830–846, `updateExistingDriveUi(speedMph)`.**
   - It applies a display curve: `speedMph *= low + (high-low)*smoothstep(speedMph/SpeedDisplayFullMph)`.
   - Live values in `Config.Vehicles.Driving`: `SpeedDisplayCurveEnabled=true`, `SpeedDisplayLowMultiplier=0.86`, `SpeedDisplayHighMultiplier=1.08`, `SpeedDisplayFullMph=160` (the code default is 200).
   - It then calls `context.UpdateDriveUi(speed, Boost, DriftBlend>0.12, DriftCharge, MiniBoostTimer)`, but only if that function exists. It does not exist (see step 2), so **no HUD shows the drift charge**.
   - It also calls `context.PublishMobile(speedMph, state.Boost)`.
2. **`Vehicles.DriveSessionClient` lines 20–24.** `PublishMobile` writes `MobileDriveInputState.SpeedMph`, `.BoostPercent` (clamped 0–100) and `.IsDriving = true`.
3. **`Vehicles.MobileDriveInputState`.** This is a plain shared table: `Throttle, Steer, Drift, Boost, SpeedMph, BoostPercent, IsDriving, AnalogSteer, AnalogDrift, State{Accelerate,Brake,TurnLeft,TurnRight,DriftLeft,DriftRight,Boost}`.
4. **Pulse `UIPulse.FreeRoam.HudView.Step`, lines 377–409.** Each frame it reads `drive.SpeedMph` and `drive.BoostPercent`, then calls:
   - `gauge.SetSpeed(floor(speed+0.5), clamp(speed/maxMph,0,1))`, where `maxMph` is `Config.UI.DesktopFreeRoamHud.Layout.SpeedGaugeMaxMph`. The live value is **180** (code default 260).
   - `gauge.SetBoost(...)`, smoothed by `BoostBarSmoothing` (14).
   - `HudClient` lines 115–116 cache both config values once at start.
5. **Classic readers of the same fields.**
   - `UI.DesktopFreeRoamHudUI` lines 1277–1293 has a 16-segment arc. The top 18% of segments use `HighSpeed`, and it reads `mobileDriveInputState.SpeedMph/BoostPercent/IsDriving`.
   - `UI.MobileFreeRoamHudUI` line 493 does the same.
6. **No HUD reads any `Feel*` attribute.** `FeelSpeedMph` is read only by `VehicleVFXClient` (lines 332, 649).

### A2. Pulse HUD owners (`Routes.Swap`, `UIPulse.Routes` lines 13–31)

- `DesktopFreeRoamHudUI` is routed to `FreeRoam.HudClient`, the one HUD for every form factor. `MobileFreeRoamHudUI` is routed to `NoOp`.
- `MobileDriveControlsClient` is routed to `FreeRoam.TouchControlsClient`, a logic-identical fork.
- **The race HUD does not draw a gauge.** `RaceSession.RaceHudModel` line 22 sets `KEEP_TELEMETRY = true`, as does `QueueClient` line 23, so the free-roam gauge stays up during races. `ResultsModel` sets it false.
  - Race HUD slots: `LapProgress` uses TopLeftHud, the timer uses TopCentreHud, the board uses TopRight and `RaceMap` uses the Minimap slot (`RaceHudView` lines 141–239).
  - **One gauge change therefore covers both free roam and racing.**

### A3. Kit.Gauge (`UIPulse.Kit.Gauge`, 447 lines; repo copy `scripts/ui_restyle/phase2/kit/k3/after/…Kit.Gauge.lua`, same length, tests in `k3/tests/`)

- **Geometry** (`Kit.Sprites.Rings.Gauge`, lines 189–195): `StartDeg=135, SweepDeg=270, ArcRadius=210, BoostRadius=184, TipFraction=0.09` on a 512 ring. The bottom 45°–135° is left empty (`PARK` comment, lines 20–22).
- **Layers:** Track, Ticks, Glow and Arc (revealed by rotating `UIGradient` masks over two half windows), BoostArc, a Tip (`GlowSoft`), `Speed` (a BigNumber with `MaxCells=3`), `Unit` and `BoostText`.
- **Interior layout** as fractions of the frame: `SPEED_Y=-0.012`, `UNIT_Y=0.181`, `BOOST_Y=0.305`. Writes are quantised to 0.5°.
- **Public API:** `New`, `Set{Name,LayoutOrder,Visible,Size,Unit,ShowBoostText}`, `SetSpeed`, `SetBoost`, `SetUnit`, `SetVisibleBoost`. Units are `MPH` and `KM/H`.
- **Sizes** (`Kit.Tokens.Space`): `GaugeSize 403` (desktop), `GaugeTouchSize 240` (tablet TouchDrive), `CompactGauge 92` dp (phone, which has no boost line).
- **Digit sprites** (`Kit.Sprites` lines 122–182) contain `0–9 : . , $ % + - / x K M MPH KM/H XP`. **There are no `N`, `R` or `P` glyphs**, so a gear letter needs either the Barlow Text role or a new sprite upload.
- **Style sheet** (`docs/design/pulse-racers-ui-style-sheet.md` line 209): the ticks "turn pink in the last fifth". That is a ready-made redline zone. The speed arc runs cyan → violet → pink.
- **Colour tokens:** `Pink 255,45,149`, `Violet 154,61,255`, `Cyan 34,228,255` (live values), `Yellow` (cash only), `White`, `TextSecondary`.
- **Role sizes:** `SpeedNumber` cap 95, and `NumberCap.Compact.Speed = 24` dp.
- **Glow:** the gauge arcs are one of only three glow places (style sheet line 141). Baked gradient images are allowed for gauge parts (line 144) but are never tinted.

### A4. Layout (`Kit.Layers` slotLayout, lines 136–226)

**Desktop (Regular, Standard):**
- Gauge at bottom-right, anchor (1,1), at (W−40, H−28), 403 px.
- HudButtons (CONTROLS, EXIT VEHICLE) at bottom centre.
- Minimap at bottom-left, 307 px.
- Status at top-right, with the action bar under it.
- Radio strip at BottomCentre, lifted above the buttons.

**Tablet (Regular, TouchDrive):** gauge at bottom centre, 240; minimap top-right; HudButtons to the left of the gauge.

**Phone (Compact, 844×390, TouchDrive):**
- Gauge 92 dp at bottom centre, with EXIT to its left.
- Minimap 92 dp at top-right, with the status column and radio under it.
- Touch controls (`TouchControlsView._place`, lines 39–61):
  - Turn pair at bottom-left, the drift pair above it, Boost above the cluster.
  - Brake, then Accelerator, at bottom-right.
  - Hit sizes (`Sprites.Touch`): Accelerate 96×112 dp, Brake 80×64 dp.
- **Free room** (INFERRED, from arithmetic at scale 1):
  - About 48 dp above the Brake, beside the taller Accelerator.
  - About 180 dp of bottom row between the gauge's right edge (~468) and the Brake's left edge (~648).

**Phone verification is thin** (`scripts/ui_restyle/phase2/verification.json` `mobile_pass.not_verified`):
- No real phone or emulator was used.
- The touch controls and the Settings, Controls and Cash modals were not captured after the fix.
- 568×320 was arithmetic only.

### A5. Where a gear indicator, tach and shift light would fit (options)

- **Gear:** either in the empty bottom gap of the ring (y ≈ +0.38–0.42 of the frame) or above the speed digits (y ≈ −0.2). On the 92 dp phone gauge, the gear could take the place of the `MPH` unit line.
- **Tach:**
  - (i) Make the outer arc show rpm and keep speed as digits only (closest to a real car).
  - (ii) Add a third ring. There is only 26/512 of space between BoostRadius 184 and ArcRadius 210, and it needs a new uploaded image (Oscar's yes).
  - (iii) Add a thin rpm strip.
- **Shift light:** recolour or flash the Tip or `GaugeGlow`, or pulse the pink "last fifth" ticks.
- **Budgets that bind** (`CONTRACT.md` 5.1–5.2):
  - Steady-drive live HUD writes must have a median of ≤16 per frame.
  - The gauge component budget is 26 instances (`API2.md` 3.2).
  - **Per-frame Pulse code may not call `GetAttribute`.** Gear and rpm must therefore arrive through the shared `MobileDriveInputState` table, as speed does, not as vehicle attributes.

### A6. Classic is frozen (`scripts/ui_restyle/CONTRACT.md` 1.8; `AGENTS.md` line 29)

- The Classic UI scripts are frozen and hash-checked. `AGENTS.md` line 29 says:

  > "A delivery that must change one, or a payload or config value Classic reads, runs the Classic verify and a Classic smoke check and lands in both sets."
- **`scripts/ui_restyle/classic/manifest.json` hashes all 221 scripts, including the driving ones:**
  - `DrivingClient`, `DrivingCameraClient`, `DriveSessionClient`
  - `MobileDriveInputState`, `MobileDriveControlsClient`
  - `VehicleVFXClient`, `VehicleAudioClient`
  - `DesktopFreeRoamHudUI`
- So a handling delivery must declare its edits in `declared.json` (`classic/README.md` "Declared changes") or the verify fails.
- **Payloads and config Classic reads:**
  - `MobileDriveInputState.SpeedMph`, `.BoostPercent`, `.IsDriving`
  - `Layout.SpeedGaugeMaxMph`, `BoostBarSmoothing`
  - the `SpeedDisplay*` values, through DrivingClient

  New fields would be additive and ignored by Classic, but the module itself is hashed. A Pulse-only gear HUD needs a recorded exception.

---

## B. Touch and gamepad

**`TouchControlsClient` is a logic-identical fork.**
- The replaced spans are Classic lines 22–103 (the builders) and 176–192 (the layout).
- `CONTRACT.md` 1.7 requires every `MobileDriveInputState` write to be identical to Classic, and the build stops on any other difference.
- Shift buttons that write a new `State.ShiftUp/ShiftDown` would break that parity. The fork spec (`phase2/families/free_roam/forks`) and the contract would need amending.
- Visuals:
  - New baked images would need Oscar's yes for an upload (generated `Tokens.Assets`, "never edit by hand").
  - Alternatively, use kit icon glyphs that already exist: `chevron_up`, `chevron_down`, `plus`, `minus`.
- Onboarding marks: `Kit.Input.Mark` marks exist for DriftLeft, DriftRight and Boost only.

**Driving input** (`DrivingClient` lines 300–369, 1392):

| Input | Keyboard | Gamepad |
|---|---|---|
| Steer | A/D, arrows | Thumbstick1 |
| Throttle / brake | W/S | R2 / L2 |
| Drift | Space | B |
| Boost | Shift | A |
| Reset | R | Y (`BindActionAtPriority` line 1051) |
| Camera look | — | Thumbstick2 (`DrivingCameraClient` line 331) |
| Map | M | Select |

**Taken while driving:**
- **E** is used by world prompts: `JobClient` line 200, `TimeTrialServer` lines 1295 and 1308, `GarageEntranceClient` lines 123 and 157, `VehicleAccessServer` line 94.
- **F** is the passenger prompt (`PassengerClientView` line 73).
- **X** is the world-prompt button on gamepad.
- **Q** is used only while the full map is open.
- C, V, P and B do something only when the Studio trailer tools are on.

**Free while driving:** LB/RB (the Kit `Bumpers` bind only in menus), the D-pad, L3/R3 and Q. The icon sheet already has `pad_lb`, `pad_rb`, `pad_lt` and `pad_rt` glyphs.

**DRIVE: Highway** (inspiration only, `ReplicatedStorage.Modules.Game.Racer.HUD.Hud` lines 78–82 and 175–211): uses E/Q for gears on keyboard and RB/LB on a pad. In PR98, **E would clash with prompts**.

---

## C. Consumers

**DrivingCameraClient** (`Vehicles.DrivingCameraClient`, scripted chase):
- **Feel inputs:** only `FeelImpactRevision/Strength` and `FeelLandRevision/Strength` (lines 232–233, 431–454). The context gives `IsAccelerating` and `IsBoosting` only (`DrivingClient` lines 512–518).
- **Spin risk 1 — hard cut.** Line 484: `math.abs(wrapAngle(heading - chase.Heading)) > math.max(0.5, 8*dt)` causes `resetChase`, a hard cut. That fires above a yaw rate of 0.5/dt: 30 rad/s at 60 fps, but about 15 rad/s at 30 fps and 10 rad/s (~570°/s) at 20 fps. **A fast spin on a slow phone would cut every frame.**
- **Spin risk 2 — camera whip.** Lines 499–506: `slip` is computed only when `forwardSpeed > 0` and is clamped to ±60°. Once a spin passes 90°, the yaw target equals the heading, so the camera swings round with the car (`ChaseYawResponse` 7.5). Roll is capped at `ChaseRollMaxDegrees` 11. **Spin-out needs its own camera rule**, for example following the travel direction.
- **Shift kick.** The `Lag` spring already reacts to forward acceleration (`ChaseAccelLagStudsPerAccel` 0.045, max 3 studs), so a torque cut on a shift gives a small push-in for free. An explicit kick could copy the boost punch (`ChaseBoostPunchDegrees` 4, line 457) through a new revision attribute.
- **Speed-tied thresholds:** `HighSpeedStart` 70 → Full 180 (FOV 80/83/90/96); speed lines 110 → 230.

**VehicleVFXClient** (lines 596–700, 713–770):
- Thrust follows `FeelThrottle`.
- Drift jets are `state.DriftLeft/Right` scaled by `FeelSlip`. INFERRED: a spin without drift input shows no drift jets.
- Dust uses `FeelSpeedMph` and `FeelHover`. Brake sparks use the `Braking` attribute.
- The backfire fires on `FeelPopRevision`. Pops come from lift-off: throttle >0.6 above 40 mph for ≥0.8 s (`DrivingClient` lines 932–956). Upshift pops could reuse this, so double-firing must be avoided.

**Audio** (`VehicleAudioClient` lines 846–882): `revTarget = RevThrottleWeight*load + RevSpeedWeight*speed/RevReferenceMph + RevBoostWeight*boost`. There is no gear concept, so it needs an rpm feed.

**Race integrity** (`ServerStorage.Modules.Game.Racing.RaceIntegrity`):
- The limit is `max(RaceIntegrityMaxSpeedMph 400, 1.25×max(AbsoluteTopSpeedSafetyMph 320, PhysicalTopSpeedMaxMph 320))`, which is **400 mph**.
- Mode is **Log** (`ServerStorage.Config.Racing`; the dashboard flag overrides it).
- Check: gate-to-gate straight distance ≤ vmax×(elapsed + 0.35) + 24 + half the gate sizes.
- Staked duels always enforce (`DuelRules` line 443). `JobBoard` line 672 uses `limitMph` for its anti-teleport cap.
- **A spin cannot trip it.** Only a top speed above 400 mph, set outside the `Dynamics` caps, could.

**Personal bests, leaderboards and medals:**
- PB store: `NTR_TimeTrialPersonalBests_StudioTest_v1`, enabled. Global board: `NTR_TT_Global_v1_<event>_<tier>`, disabled.
- **The keys carry no physics version**, so old arcade PBs remain. A reset is a config suffix bump.
- PB-01 is still open: PBs are written even in the sandbox.
- Medal times are per tier on `Config.Racing.TimeTrialCatalog.<event>` (two events). Example, `ShowroomLoop` S tier: Bronze 70, Silver 60, Gold 54, Platinum 50 seconds. They need retuning.

**Wrong-way prompt** (`RaceRouteGuideClient` lines 326–360): needs ≥42 mph, a direction dot below −0.32, sustained for 3 s. A spin is too short to trigger it.

**World jobs** (`JobRules` lines 646–696; `TaxiRules` and `CourierRules`):
- A crash is a speed drop of more than 35 mph within the impact window (0.25 s in code; the contract says 0.2). Each crash costs −12% (taxi) or −15% (courier).
- Pay is set against `ReferenceMph` 85, multiplier 0.6–1.5.
- Pickup needs ≤18 mph.

**Drive rewards** (`Config.Vehicles.DriveRewards`): 0.1 cash per stud. Speeds above 540 studs/s (~337 mph) are rejected. The reference average is 43.4 mph.

**Collision** (`VehicleInteractions`): vehicles pass through each other above 20 mph and collide again below 16. **Low-speed spins in traffic will make contact.**

**Duels** (`DuelService` lines 634–680): a standing start, then a path check.

**Driver Rank:** XP comes only from job and duel payouts (`docs/architecture/activities-contract.md` line 144).

**Stats and PerformanceIndex:**
- The headline order is Speed, Acceleration, Handling, Drift, Braking, Boost (`PerformanceDefinitions` lines 11–43). Handling = LateralGrip .35, SteeringResponse .25, HoverStability .20, Downforce .10, Weight .10.
- PI is computed from stats, not from physics, so the bars will not follow a physics change. `08_Balance` multipliers are keyed on PI.
- The vehicle attribute `DynamicsMappedTopSpeedMph` (`VehicleDynamics` line 179) could scale the gauge per car. Physical top speeds run 150–320 mph, while `SpeedGaugeMaxMph` is 180.

**Muscle** (`docs/design/vehicle-categories/muscle.md` line 11): "heavy (high Weight), bad at turning (low SteeringResponse and LateralGrip)… The weakness must be felt in corners." With high power and low grip, Muscle is the class most likely to spin.

**Onboarding:**
- On PC, the first drive opens the Controls modal (`OnboardingModel` `FirstDrivePage="PCDriving"`).
- On touch, pages D7 (drift) and D8 (boost) are taught.
- New pages need the server `OnboardingServer` line 24 `allowedPages` list updated.

**Settings** (`HudModals` lines 213–286; opened by the HUD cog `OpenSettings`):
- Rows: TOUCH CONTROLS (touch only), MINIMAP, PASSENGERS.
- MINIMAP is a session-only player attribute; Classic line 631 notes "settings are not persisted yet". PASSENGERS is saved through a server action.
- **An AUTO/MANUAL row fits here** through a HudModel getter and setter. Saving it across sessions would mean a new profile field.
- The Controls list `DRIVING_ROWS` (lines 12–13) is sized so that "the title, the seven keys and the footer fit a 320 dp high screen".

### Impact table

| System | File / instance | What it reads | Likely impact | Must-check item |
|---|---|---|---|---|
| Pulse HUD gauge | `UIPulse.FreeRoam.HudView` 377–409; `Kit.Gauge` | `MobileDriveInputState.SpeedMph`, `.BoostPercent`, `.IsDriving`; `SpeedGaugeMaxMph` 180 | Add gear, rpm and shift light; new setters | Write budget ≤16 per frame; 26 instances; no N/R glyph; 92 dp phone gauge |
| Race HUD | `RaceSession.RaceHudModel` line 22 | uses the free-roam gauge (`KEEP_TELEMETRY`) | Same change covers races | Gear not hidden by the race vignette or board |
| Classic HUDs | `DesktopFreeRoamHudUI` 1277–1293; `MobileFreeRoamHudUI` 493 | same table | Frozen; no gear shown | Declare, verify, smoke; record a Pulse-only exception |
| Drive state | `DriveSessionClient` 20–24; `MobileDriveInputState` | `PublishMobile` | Add Gear, Rpm, Redline, Shift fields | Both hashed in the Classic manifest |
| Speed display curve | `Config.Vehicles.Driving` `SpeedDisplay*` | DrivingClient 833–838 | Displayed mph ≠ real mph | Decide: gears from real speed; keep or drop the curve |
| Touch controls | `TouchControlsClient` / `TouchControlsView` | `MobileDriveInputState.State` | Shift up/down buttons | Fork parity break; space above Brake; phone never device-tested |
| Gamepad / keys | `DrivingClient` 300–369 | Gamepad1 state | LB/RB, Q free; E taken | E used by world prompts |
| Settings | `HudModals` 213–286 | player attributes | Gearbox row | Session-only or saved; phone fit |
| Controls / onboarding | `HudModals` 12–13; `OnboardingModel` | — | New key rows or page | 320 dp fit; server `allowedPages` |
| Camera | `DrivingCameraClient` 484, 499–516 | Impact and Land revisions; IsAccelerating; IsBoosting | Spin whip; shift kick | Cut on low frame rate; spin yaw rule |
| VFX | `VehicleVFXClient` 596–770 | `Feel*`, `Braking` | Shift pops; spin smoke | Drift VFX gated on the drift button |
| Audio | `VehicleAudioClient` 846–882 | `Feel*`, velocity | Needs an rpm source | (audio area) |
| Race integrity | `RaceIntegrity`; `DuelRules` 443 | gate times; Dynamics caps | Safe | Top speed ≤320 cap; staked duels always enforce |
| PB / leaderboard / medals | `PersonalBestServer`; `GlobalLeaderboardServer`; `TimeTrialCatalog` | times per tier | Old PBs stale | Bump store suffix; retune medals |
| World jobs | `JobRules` 646–696 | server speed samples | Crash false positives | High-speed spin >35 mph in ~0.25 s; slower pay |
| Collision | `VehicleCollisionServer`; `VehicleInteractions` | speed 16/20 mph | Low-speed spin contacts | Spins in traffic |
| Duels / race starts | `DuelService` 634+; race countdowns | standing start | Launch spin | Full throttle plus steer at "GO" |
| Stats / PI | `PerformanceDefinitions`; `08_Balance` | stats | Bars won't track feel | Re-calibrate Weight and Handling |
| Muscle | `muscle.md` line 11 | low grip, high power | Most spin-prone | Still drivable |

**Questions this raises for the plan:**
- Should the gearbox default to AUTO, and should the setting be saved?
- Should MANUAL shifting use Q/E and move the prompts, or use other keys?
- Should the gear HUD be Pulse-only, accepting Classic without it?
- Should PBs be reset when the new handling lands?
- Should launches have a grace period at race and duel starts?