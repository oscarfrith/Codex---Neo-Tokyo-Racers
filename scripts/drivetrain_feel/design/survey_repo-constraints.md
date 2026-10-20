# Delivery rules, past deliveries and constraints for the PR98 gears, weight, spin-out, sound and HUD change

Studio was used read-only for a few PR98 checks. Nothing was changed.

**Live PR98 checks (read-only):**
- `DrivingClient` line 833 contains `configBool("Driving", "SpeedDisplayCurveEnabled", true)`.
- `DrivingClient` line 1569 contains `configBool("Driving", "FeelStateEnabled", true)`.
- `Config.Vehicles` has `HoverPose` and `HoverWobble`. `Config.Vehicles.Dynamics` has `01_Acceleration` through `08_Balance`.
- So the driving_tune and hover_feel work is present in PR98.
- `MobileDriveInputState` is a plain table (lines 2-21) holding `Throttle, Steer, Drift, Boost, SpeedMph, BoostPercent, IsDriving, AnalogSteer, AnalogDrift, State{...}`.

---

## 1. Lane and the safeguards it needs

**Lane: High-Risk for the combined batch.** It could be split into Standard parts if Oscar prefers.
- docs/13 line 28 defines High-Risk as covering "uncertain or multiple runtime owners, VFX attachment". The batch touches:
  - the driving owner (`DrivingClient`, `VehicleDynamics`);
  - the audio owner (`VehicleAudioClient`, `VehicleAudioCatalog`, `Config.Audio.VehicleProfiles`);
  - the HUD (Pulse `HudView` and `Kit.Gauge`);
  - possibly the camera owner (a shift kick) and VFX (shift or spin effects).
- Precedents:
  - `scripts/hover_feel/CONTRACT.md` line 4: "Lane: High-Risk (driving owner, camera owner, VFX attachment owner)".
  - `scripts/driving_tune/CONTRACT.md` line 3: "Lane: Standard, driving owner (client physics and presentation only)".
- docs/13 line 30: "A small diff cannot bypass remote, saved-data, authority, reward or lifecycle safeguards." There is no saved data, economy or remote change as long as gear state is not sent to the server. If gear or RPM is sent over a remote (for example added to `Remotes.Audio.VehicleAudioState`), the remote rules apply as well: Core.Net and NET-01.

**What each lane requires**
- docs/13 lines 24-28:
  - **Fast:** "Inspect owner/baseline; guarded installer or direct repo edit; focused check."
  - **Standard:** "Concise contract, shared-component/owner review, current source/mirror, transactional installer, affected transition/input tests."
  - **High-Risk:** "Live audit where necessary, authority/invariants/migration semantics, complete recovery and applicable lifecycle/security/save/load/device tests."
- docs/14 lines 37-66 say the same. Standard uses the compact docs/15 contract. High-Risk uses the full contract and adds "do not activate the new owner until invariants and rollback are proven".
- docs/15 is a template: system, lane, goal, baseline, required, preserve, exclusions, owners, inputs and outputs, lifecycle, authority, IDs and schema, scale, mobile, streaming, failure, reuse, installer and rollback, verification matrix, exceptions, done-when. N/A is allowed with a reason.

**Before and after capture**
- docs/13 line 69 makes targeted before/after captures the default.
- **The capture tool refuses PR98.** `scripts/studio_capture.py` line 11 reads `PLACE_IDS = (121304917315753, 71491191583884, 133417340424236)`, which is v1, v2 and Backup v2. It accepts neither v3 nor PR98. TOOL-05 (docs/06 line 47) says changing that place guard "needs Oscar's approval".
- Both prior deliveries worked around this by dumping exact live bytes through `serve.py` `POST /put/<name>` into `before/`:
  - `driving_tune/build.py` docstring: "before/ holds the exact live sources and config captured from Space Racers v3".
  - hover_feel: "(serve.py POST route)".

**AUDIT/APPLY/ROLLBACK installer**
- Both contracts give the same done-when: "sources compile; AUDIT clean; APPLY, ROLLBACK, APPLY clean" (driving_tune CONTRACT line 111; hover_feel CONTRACT line 79).
- hover_feel's record (`verification.json` lines 36-40) adds that a repeat APPLY is a no-op.

**delivery-reviewer**
- CLAUDE.md line 29: required before APPLY on High-Risk work.
- hover_feel ran two passes: "state and camera; audio and VFX", both "READY WITH FIXES", fixes applied (CONTRACT line 86).
- The ui_restyle contract (line 497) requires a reviewer "on every edit to an existing script" for Pulse surfaces, which matters for any HUD edit.
- Agent definition: `.claude/agents/delivery-reviewer.md`. It is read-only, has Studio read tools, and returns BLOCKERS, RISKS and CHECKS MISSING.

**Verification record**
- Both deliveries kept a `verification.json` in the delivery folder.
- The driving_tune shape (`scripts/driving_tune/verification.json`):
  - delivery, contract, place, date, status;
  - `evidence_scope`, which names the car, PI, input method and API-versus-UI steps;
  - `edit` (compile, installer, scripts_changed, config_created);
  - `baseline_before`, `after`, `not_verified`, `found_not_fixed`.
- docs/13 line 63: `scripts/validation_record.py` keeps evidence types, pinned artifacts and open next actions for connected or deferred work.

**Play test evidence categories**
- `scripts/validation_checks.json` defines `kind` as static, ui, runtime, api, device, multiplayer or persistence.
- Checks that apply here:
  - `tooling` and `installation` (static);
  - `startup` (ui: real Play button, `StartScreenActive` false);
  - `race` (ui: spawn, exit and re-enter, stage or cancel, drive and finish; "API staging alone is not a driven finish");
  - `errors` (runtime: console before and after);
  - `cleanup` (runtime: repeated cycles, connections and instances);
  - `streaming` (drive at speed, stream out, respawn);
  - `device` (a physical phone; "An emulator or Studio window proves layout only"; iPhone 7 baseline);
  - `multiplayer` (an isolated published place; one Studio client cannot satisfy it).
  - `garage`, `api` and `persistence` are N/A unless a shared payload changes.
- Evidence labels (AGENTS line 26): generated, installed, agent-verified, user-confirmed. "Source parity and successful remote calls are not gameplay confirmation."
- Both contracts end with: "Oscar judges the feel. Agent checks are not acceptance of taste."
- Testing rules:
  - Check rendering before camera, UI or audio checks: count RenderStepped (`studio-testing-playbook.md` line 8).
  - Play in the no-save sandbox through `scripts/ui_restyle/probes/sandbox_window.lua`. It opens and restores `StudioVehicleSandboxEveryPlay`, and installs refuse while it is open (ui_restyle CONTRACT line 499).
  - **Never finish a time trial** in the sandbox (PB-01).

**Docs and commit (docs/13 §6)**
- Update 00_START_HERE, 06 (DRIVE-02 and FEEL-01 rows or a new row), one 07 entry, the topic docs (03 driving, 05 VFX, 16 audio) and a docs/12 lesson where one is earned.
- Commit and push under the standing authorisation, staging explicit paths (CLAUDE.md line 31).
- **00_START_HERE is stale.** Line 3 still says "Target: Space Racers v3 … Updated 2026-10-04", while CLAUDE.md line 7 says PR98 has been the working place since 2026-10-09.

---

## 2. How driving_tune and hover_feel were packaged, and reusing that route

**Folder layout** (`scripts/driving_tune/`, `scripts/hover_feel/`):
- `CONTRACT.md`;
- `before/` (exact live sources plus `config.json`);
- `after/`;
- per-part folders (driving_tune: `balance/`, `pose/`, `integrator/`, each with `edits.py`, `NOTES.md`, `after/`, and the offline models `model.py` and `sim.py`);
- `build.py`, `installer_engine.lua`, `serve.py`, `out_audit.lua`, `out_apply.lua`, `out_rollback.lua`, `applied_hashes.json`, `verification.json`.

**Part deliverable format** (driving_tune CONTRACT lines 80-92):
```python
EDITS = {"DrivingClient": [(old, new, count), ...], ...}   # exact-text replacements, tabs are tabs
INSTANCES = [{"parent": [...], "name": "HoverPose", "class": "Folder", "attributes": {...}}]
ATTRIBUTES = [(["ReplicatedStorage","Config","Vehicles","Driving"], "Key", value)]
```
- `py -3 scripts/driving_tune/build.py --part <part>` checks the anchors (match count must equal `count`) and writes `<part>/after/`.
- hover_feel used whole-file `after/` for `DrivingCameraClient`, the audio and the VFX, plus anchored insertions into `DrivingClient`. Its config came from `audio/config_spec.json` and `vfx/config_spec.json`.

**build.py** (driving_tune):
- `PLACE_ID = 93959280828322` (v3). hover_feel `build.py` line 24 has the same. **A new delivery must use 103397770260610.**
- It composes the parts against `before/`, computes djb2 before/after hashes, and keeps the earlier after-hashes as `prior`.
- It embeds DATA as JSON in a `[==[ ]==]` long string and refuses if `]==]` appears in it.
- It writes `out_<mode>.lua` = `local MODE=...; local DATA=JSONDecode(...)` followed by the engine.

**installer_engine.lua** (driving_tune, 160 lines):
- Asserts `game.PlaceId == DATA.placeId` and that Play is not running.
- Each script must be in the before, after or prior state, otherwise it BLOCKS. The after-source is fetched with `HttpService:GetAsync("http://127.0.0.1:8796/"..)`, hash-checked and compiled with `loadstring` before anything is written.
- Attributes:
  - a new attribute keeps a tuned value on APPLY;
  - an existing attribute must equal its before or after value.
- Instances carry `DrivingTuneInstalled=true`, and ROLLBACK destroys only marked ones.
- ChangeHistory waypoints are set, and sources are restored on a write failure.
- hover_feel's engine (221 lines) adds `DATA.builders` (pure instance builders, the Exotic V2 VFX templates), `DATA.updates` and `DATA.lateInstances`, and marks with `HoverFeelInstalled`.

**serve.py**: `GET /<path>` serves repo files; `POST /put/<name>` writes into `before/`.

| Delivery | Port |
|---|---|
| hover_feel | 8794 |
| driving_tune | 8796 |
| `scripts/ui_restyle/tools/serve.py` | 8796 |

driving_tune and ui_restyle share 8796, so a new delivery needs its own port. 8797-8799 are unused by the repo's Python serve scripts.

**applied_hashes.json** is the after-hash history, so a rebuilt delivery can APPLY over its own earlier build:
- driving_tune: DrivingClient has 2 hashes and FreeRoamParkedHoverClient has 3.
- hover_feel: VehiclePreviewVFXClient has 8.

**Size:** `out_*.lua` stays at about 22 KB because sources are fetched over HTTP, not embedded. Roblox rejects a Source of 200,000 characters or more (docs/12 line 48), so embedding several ~72 KB DrivingClient-size sources is not viable.

**Does the installer need execute_luau to reach localhost? Yes.**
- `claude-code-setup.md` line 23: "Network access is not stable, so probe it each session … Run a one-line localhost request before relying on it … If it fails, send data in the code string, or give the user a small Command Bar script (the Command Bar has network access)."
- docs/12 line 49: probe the network each session.
- CLAUDE.md line 30: Claude Code must run on the same PC as Studio.

**Old ROLLBACKs no longer work for these scripts (INFERRED from hashes; not executed):**
- Live DrivingClient no longer matches driving_tune's before, after or prior hashes. Pulse wave 2 (`scripts/ui_restyle/phase2/install/02_free_roam/`) edited it again to swap the keys: lines 368 and 1392, Space for drift and Shift for boost (commit c4cfa5a1). `DesktopFreeRoamHudUI` was also re-edited by that family.
- So `driving_tune/out_rollback.lua` and `hover_feel/out_rollback.lua` would BLOCK on "unknown". They also assert the v3 place id.
- A new delivery must take a fresh `before/` from PR98 and becomes the recovery point for these scripts.

**If a new ModuleScript is needed** (for example a pure gearbox model):
- Per `proportional-mcp-delivery.md` line 9, creation is a "dedicated canonical migration". driving_tune's contract banned new scripts.
- `scripts/ui_restyle/engine/` has a proven `create` op with ops `source, tree, attribute, property, create`, the hover_feel hash guards, and marked-instance rollback.
- Its lesson (ui_restyle CONTRACT line 496): "Two transactions per phase. Hierarchy and config first, verified; then sources. A mixed command once lost new config values." Save and reopen after APPLY.
- The ui_restyle installers were retargeted to PR98 in commit 28a38f6e.
- The simplest path is to extend existing owners only, as both precedents did.

**Other routes:**
- `scripts/studio_delivery.py` (the guarded bundle for existing sources and primitive attributes) depends on studio_capture records, so it is blocked for PR98 as well.
- Fast-lane config-only changes in PR98 used small guarded scripts: `scripts/audio/pr98_vehicle_radio_mix.lua` with `PLACE_ID = 103397770260610`, a before/after assert per value, and `MODE="ROLLBACK"`.

**Parallel agents** (memory `feedback-parallel-agent-builds.md`; docs/12 lines 30-44):
- One contract first. Each agent gets its own folder and writes `edits.py` and `NOTES.md` only, with no Studio or git.
- The integrator owns the fresh capture, the compile (`loadstring`; agents cannot run Luau), AUDIT, APPLY, ROLLBACK, APPLY, the Play test and the commit.
- Offline option studies with metrics come first (as `balance/model.py` and `pose/sim.py` did).
- Budget a Play pass per agent deliverable.

**Autonomy** (`feedback-autonomous-delivery.md`): once a plan is approved, run end to end without check-ins, keep the safeguards, and report once. `feedback-decisions-in-chat.md`: list decisions with recommended defaults in the message, not in a popup.

---

## 3. Constraints the change must respect

**Owners: extend them, and add no new owner, remote or startup path.**
- driving_tune CONTRACT lines 20-27:
  - `VehicleDynamics`: stat-to-physics mapping and balance (`Model.Balance(vehicle)`; `StepLongitudinal`, `StepHandling`).
  - `DrivingClient`: per-frame forces, hover, pose, steering intent and HUD speed (`updateExistingDriveUi`).
  - `FreeRoamParkedHoverClient`: the parked car.
  - Tuning in `Config.Vehicles.*`.
- hover_feel CONTRACT lines 21-30:
  - camera: `DrivingCameraClient`, with FOV only via `CameraService.SetFieldOfView("DrivingCamera", fov, 100)`;
  - audio: `VehicleAudioClient`, `VehicleAudioCatalog`, `Config.Audio.VehicleProfiles`;
  - VFX: `VehicleVFXClient` and `VehiclePreviewVFXClient`;
  - remote transport: `Remotes.Audio.VehicleAudioState` is unchanged, and "Remote cars derive continuous values from replicated velocity".
- AGENTS line 17: `DriveSessionClient` owns vehicle callbacks.
- AGENTS line 20: "driving work must not alter unrelated UI/server/VFX systems."

**Feel-state interface** (hover_feel CONTRACT lines 32-62):
- `DrivingClient` writes client-local `Feel*` attributes every Heartbeat and clears them to nil in `Controller.Stop`.
- Consumers treat a missing attribute as unavailable and fall back to the booleans and the velocity.
- Values are quantised (0.02 or 0.5).
- `FeelSpeedMph` must stay the **real** speed (driving_tune CONTRACT line 31). The HUD curve is display-only.
- New gear, RPM, shift and spin signals would follow the same pattern. They would be added to the `FEEL_ATTRIBUTES` list (`hover_feel/build.py` FEEL_HELPERS).

**Rules for driving code** (driving_tune CONTRACT lines 94-107):
- Luau with tabs, using `configNumber(folder, name, fallback, min, max)` with clamps.
- **Every new behaviour has an enable switch or a 0/1 value.** Config is read per frame through the existing readers, or through the 4 Hz cache table as balance and pose do.
- No new instances per frame; no raycasts beyond the four hover rays; no per-frame `GetDescendants` or `GetBoundingBox`; no new connections per vehicle; no `task.spawn` loops.
- Smoothing must be frame-rate independent: `1 - math.exp(-rate*dt)` or a sub-stepped semi-implicit spring.
- NaN guards: clamp dt and use `math.max` on divisors. This follows the CAM-02 lesson: anchored assemblies report infinite mass, so forces must be zero while anchored (docs/12 line 26).
- Do not rename or remove existing attributes, functions or state fields, and do not change `Controller.Start/Stop` signatures.

**Config conventions**
- Numbered category folders under `Config.Vehicles.Dynamics`: `01_Acceleration` … `08_Balance` (live). A new one would be `09_…`.
- Every numeric attribute gets a `_RaisingThisDoes` string and every boolean a `_Description` (balance NOTES line 72; pose NOTES line 113).
- Folders must exist before the first drive frame, or "the readers' one-time name cache misses them … live edits would do nothing until the next session" (balance NOTES lines 194-197).
- Code fallbacks equal the defaults, so deleting a folder does not switch a feature off. An explicit `…Enabled` switch is needed (pose NOTES lines 166-167; DRIVE-02).
- docs/02 line 9: `Config.Vehicles` groups Driving, Dynamics, Camera, Performance, Spawn, MobileControls, DriveRewards, Authoring, DriverSeat and StabiliserVFX.

**Existing switches a new feature should sit beside**
- `08_Balance@BalanceEnabled`.
- `HoverPose@SettleEnabled`, `BankLiftEnabled`, `ParkedAnchoredPresentationEnabled`, `DebugAttributes`.
- `HoverWobble@WobbleEnabled`, `ParkedWobbleEnabled`.
- `Driving@SpeedDisplayCurveEnabled`, `SteeringCoastAssumeForward`, `FeelStateEnabled`.
- `Camera@ScriptedChaseEnabled`.
- `Audio.Global@FeelAudioEnabled`.
- `StabiliserVFX@FeelVFXEnabled`, `ExoticVFXV2Enabled`.
- `Dynamics@Enabled` (when false, the legacy path).
- Per-profile audio `<Layer>Disabled`, plus a `ProfileRevision` bump to rebuild a live graph (hover_feel `audio/NOTES.md` lines 17 and 27).

**FeatureFlags exception for client feel config**
- architecture-programme.md line 29 says "New live-tunable behaviour reads FeatureFlags". But FeatureFlags is server-only (`ServerStorage.Modules.Core.FeatureFlags`).
- hover_feel CONTRACT line 87: "The four switches are client config attributes, not FeatureFlags, because FeatureFlags is server-side". FEEL-01 accepted this, and ui_restyle CONTRACT line 131 cites it as precedent. Record the same exception.
- PR98 lesson (07, 2026-10-09): FeatureFlags live defaults differ from Studio overrides. Do not gate this feature on a flag whose live default is off.

**Saved data and stats are untouched.**
- driving_tune CONTRACT lines 29-31: "No stat, rating, PerformanceIndex, tier, price or catalogue value changes: the nerf is applied where stats become forces … Server files are not touched."
- Stat names come from the shared calculator (history doc `docs/history/cleanup-phase4-prior-docs/02_vehicle_folder_system.md` lines 195-272): `TopSpeed, Acceleration, Handling, Drift, Braking, Weight, Boost, BoostDuration, BoostRecharge, BoostRechargeDelay`, plus raw `EngineOutput, LateralGrip, SteeringResponse, HoverStability, DriftControl, DriftGrip, DriftChargeRate, BrakingForce, BoostForce, BoostEfficiency, Drag, Downforce`.
- Current docs/02 does not define the stats. It points to the catalogue owners and says new public attributes need the catalogue whitelist (frame-classes line 198). Avoid adding stats.
- `Weight` today (from the driving_tune `after/VehicleDynamics.lua` copy, **older than live**):
  - acceleration: `WeightReference` 118, `WeightAccelerationExponent` 0.22, clamped 0.82-1.18 (lines 226-230);
  - braking: `BrakeWeightExponent` 0.2, clamped 0.8-1.2 (line 248).
  - No yaw or inertia use was seen by grep (INFERRED; confirm live).

**Classic frozen rule (AGENTS line 29; ui_restyle CONTRACT §1.8 lines 202-212)**
- The Classic record (`scripts/ui_restyle/classic/manifest.json`, 221 scripts; the record's `placeId` field is 103397770260610) hash-checks **every** script in the place. That includes `DrivingClient`, `DrivingCameraClient`, `VehicleDynamics`, `VehicleAudioClient`, `VehicleAudioCatalog`, `VehicleVFXClient`, `FreeRoamParkedHoverClient`, `MobileDriveInputState`, `MobileDriveControlsClient`, `DesktopFreeRoamHudUI` and `MobileFreeRoamHudUI`.
- Edits must be listed in a `declared.json` (`classic/README.md`: `py -3 build_verify.py --declared declared.json`) so `out_verify_classic.lua` reports them as declared rather than failing. Run the Classic verify in AUDIT.
- §1.8: if a Classic **UI** script must change, "the forks stop building on the hash mismatch, the Classic record is re-taken, and the feature lands in both sets or Oscar brings Phase 10 forward. Every later delivery that touches a payload or config Classic reads runs a short Classic smoke check."
- Line 498: "Existing hash chains (… DesktopFreeRoamHudUI) get no new link."
- `MobileDriveControlsClient` is a logic-identical fork into Pulse `TouchControlsClient`: "every `MobileDriveInputState` write is identical" and "A changed Classic source stops the build" (line 197). A touch shift button would hit this.
- The Classic config record covers only `Config.UI`, `.Development` and `.Player` (README), so new `Config.Vehicles` and `Config.Audio` attributes do not trip it. New `Config.UI.*` attributes would need declaring.
- Precedent for a Pulse-only feature: the radio. "Pulse only: Classic has no radio and no Classic script, payload or config that Classic reads changed" (07, 2026-10-10).

**HUD (Pulse is the default; UI-01)**
- `UIPulse.FreeRoam.HudView` lines 370-405 read `drive.SpeedMph` and `drive.BoostPercent` from the shared `MobileDriveInputState`. They call `gauge.SetSpeed(math.floor(speed+0.5), speed/maxMph)` and `gauge.SetBoost`.
- `HudClient` lines 115-116 read `SpeedGaugeMaxMph` (260) and `BoostBarSmoothing` (14) from `layoutConfig` (folder not confirmed; INFERRED `Config.UI…`).
- The Classic `DesktopFreeRoamHudUI` reads `mobileDriveInputState.SpeedMph` (driving_tune `integrator/edits.py` line 67).
- Kit API rules: "frozen after the free-roam HUD" (CONTRACT lines 261 and 581), so adding gear or RPM to `Kit.Gauge` is an API extension that needs review.
- Write-on-change: speed is written on an integer change and the gauge angle in half-degree steps (line 346).
- Budgets: steady drive median ≤16 live-layer writes per frame (line 371); HUD cover ≤12% of the screen at 1080p and ≤18% on a phone (line 377); big numbers use `BigNumber` image sprites (line 328).
- Every state is checked through gallery fixtures (`UIPulse.Dev.Gallery`).
- Pulse owners never write `ScreenGui.Enabled`.

**Mobile**
- `StarterGui.ScreenOrientation = LandscapeSensor`; no portrait layouts and no runtime orientation writers (AGENTS line 18).
- Keep `MobileParticleScale`, central controllers and no per-object scripts (hover_feel CONTRACT line 69).
- Audio on small touch devices: rev budget 8, no twin, 30 Hz step (hover_feel `audio/NOTES.md` lines 115-117; FEEL-01).

**Audio limits**
- 6 detailed + 6 simple remote graphs, 15 Hz parameter updates, 8 one-shots per vehicle (docs/16 line 242).
- The remote's rate limit is unchanged.
- Local driver: hard limit 48 voices, default desktop budget 46.
- Profile chosen per category through `Config.Audio.VehicleProfiles@CategoryProfile_<CategoryId>`. Templates are frozen, so the mapping lives in config (hover_feel CONTRACT line 88).
- PR98 mix: `LocalDriverGain` 1.05, `ExternalVehicleGain` 0.9, `IgnitionGain` 0 on both profiles (07, 2026-10-10).
- Memory: "borrow DRIVE's techniques and improve on them; do not reuse its combustion engine loops."

**MCP rules**
- No gameplay module require through MCP and no hot reload (AGENTS line 24).
- `multi_edit` only for Fast-lane, single-owner edits (claude-code-setup line 46).
- Announce fragile anchors, and stop after two anchor failures in one live script.
- Publishing is Oscar's action. Changes made in Studio must be saved, and need a republish to reach live PR98.

---

## 4. Open issues and unverified items that overlap this work

| ID | Overlap and what to fold in or check |
|---|---|
| DRIVE-01 | Steering V1.2 reverse, brake and three-point behaviour is **user-confirmed**. A reverse gear or neutral must preserve it, along with `SteeringCoastAssumeForward` and `SteeringReverseAsked` (integrator edits lines 26-35). |
| DRIVE-02 | Only the S-tier Seraph has been driven. E-A tiers come from `balance/model.py` only. Top speed, boost and drift strength are unmeasured. Piercer and Muscle bodies, mobile HUD, touch and "each switch turned off" are untested. `ROLLBACK removes live-tuned config values`. Gear ratios and spin thresholds need per-tier measurement, which this gap also needs. |
| balance NOTES item 7 (lines 187-189) | Camera, FOV, speed lines and **engine audio** scale against the un-nerfed `dynamicsStats.TopSpeed`, so they "will read slower". Gear ratios and RPM should reference the balanced cap (`maxMph` times `DynamicsBalanceTopSpeed`). |
| balance NOTES lines 125-129 | Coast mismatch: measured 34 to 16 mph in 1.6 s against the model's 26. Something outside `StepLongitudinal` slows a coasting car. Engine braking per gear would stack on this unexplained loss, so it is worth finding first. |
| Balance finding 1 (NOTES lines 54-61) | Top speed is limited by drag, not by the cap. `AerodynamicDragPerMphSquared` 0.2 clamps to 0.002 and `BaseForwardAcceleration` 90 clamps to 80. A gearbox that limits revs in top gear interacts with this. |
| FEEL-01 | Nobody has judged the sound by ear. Mobile and gamepad, two clients, and Piercer and Muscle after the VFX change are untested. Toolbox ids (turbo whistle, blow-off) may not load on a published server. **`Catalog.GlobalBool` ignores a configured false**, and the camera `flag()` helper ignores a configured false for `Enabled` and `RespectTrailerCameraKeys` (both pre-existing). New audio or camera switches must not rely on those helpers. Remote Exotics keep up to 3 rev loops. |
| hover_feel "Not in this delivery" | No Muscle or Piercer voices exist yet (only `GENERIC_STANDARD_AUDIO` and `EXOTIC_V10_AUDIO`). The grungier-sound request likely means building these. |
| VEH-01 | On-road `PerformanceIndex` double-counts module `TopSpeed`, `Weight` and three boost stats. The balance multiplier, and any weight-based mass, inertia or spin threshold, would read inflated values. |
| MUS-01 / MUS-02 | Muscle's design is "powerful, heavy, fast, weak in corners" (`Weight` ×1.20, `LateralGrip` ×0.72). But `LateralGrip` has a floor of 0.82 and `SteeringResponse` uses exponent 0.1, so E and D cars all sit on the grip floor and stats barely differentiate low-tier handling. Spin-out tuned on grip would feel identical across those cars. The Modern's on-road tier may read A. |
| RACE-01 | Server plausibility flags speeds above max(400 mph, 1.25 × driving caps) (Log mode). A gearbox must not raise caps. Race start and countdown should be re-tested. |
| PB-01 | The sandbox still writes personal bests, so never finish a time trial. |
| EXIT-01 | The server shifts the car about 6 studs on exit. This confuses parked and exit tests. |
| CAM-02 lesson | Spin-out torque or impulses must be zero while the car is anchored. |
| UI-01 | The Pulse HUD is agent-verified on desktop only. The in-race HUD, phone and gamepad are unverified, and so is the gauge on touch (`TouchDrive` centred gauge). |
| TOOL-05 | No capture tool for v3 or PR98. Repeat the POST /put route or ask Oscar to approve the place guard. |
| PERF-01 / PERF-06 | Device gates are open. Extra audio voices or HUD writes need a phone check. |
| Docs drift | 00_START_HERE header still names v3. `project-drive-highway-port.md` records DRIVE: Highway as place 120511086614436, while this task uses the DEVELOPMENT place 111000019231429. Both are read-only references. |

---

## 5. Design direction facts

**Vehicles** (memory `feedback-vehicle-design-direction.md`; `docs/design/vehicle-frame-classes.md` line 9):
- Only actual wheels are banned; "Lift and thrust come from jets and thrusters".
- Engine, stabiliser and boost modules "are fundamental and must exist as real, visible modules on every cockpit".
- Real-car likeness is wanted ("Realistic cars as hover-jet versions"). The Exotic target is "real hypercars with slight futuristic changes", with "boost sits where the exhausts would be" and headlights on the front engine modules.

**Identity** (pitch deck):
- "Modular hover vehicles"; "The sci-fi setting lets content be far more varied than a real-car game without breaking the world's rules".
- Pillars: collection, personalisation, progression; E-S tiers; racing-first open world.

**Class handling intent** (frame-classes lines 119-132):
- Muscle: strong in "Acceleration, boost, straight-line speed", weak in "Braking, tight turns".
- Exotic: strong in "Top speed, grip, braking".
- Ideas list (lines 204-206): "Class sound … through the existing `StandardAudioProfileId`"; "Engine choice you can hear and see"; "Signature expression per class" (for example Rodder lifts its nose on a boosted launch).

**Existing engine voice**
- Exotic is "voiced like a high-revving V10 with sci-fi layers" (hover_feel CONTRACT line 18).
- Synth round 3 already added "depth and grunge" (`synth/README.md`): sub-octave, a 35-220 Hz rumble bed, exhaust rasp and harder saturation, with the ring-mod sci-fi sheen at -20 dB.
- The RPM model exists: firing Hz = rpm/60×5. The rev layers span 1000 (idle) to 8000 rpm, with rev position = `(rpm/8000 - 0.125)/0.875` (`audio/NOTES.md` line 68).
- Today's rev has **no gears**: `clamp(0.25*load + 0.75*speed/RevReferenceMph + 0.08*boost)`, where `RevReferenceMph = 170` was "a guess" (NOTES lines 49 and 134).

**DRIVE port decisions** (memory): scripted chase camera approved; no near-miss kick, no cockpit view, no banked-track camera; take inspiration and do not copy combustion loops.

**Presentation suggestions (INFERRED; not decided):**
- Present gears as engine-module stages or "power bands" with real-car numbering (1-N, R, N) for readability.
- Present a shift as a thrust-jet flicker or pop, using the existing `FeelPop*` and VFX pattern.
- Present spin-out as a stabiliser losing hold: stabiliser jet VFX stutter plus `SlipStrain` audio, rather than tyre language. There are no tyres; the existing `stabiliser_strain` slot replaced the tyre squeal.

---

## Where a change would hook in

- **New delivery folder:** for example `scripts/drivetrain/`, cloned from the driving_tune pattern.
  - `CONTRACT.md` with the full docs/15 contract;
  - parts `gearbox/`, `chassis/` (weight and spin), `audio/`, `hud/`, plus `integrator/`;
  - `build.py` with `PLACE_ID = 103397770260610` and its own port;
  - `before/` dumped from PR98 by POST.
- **Physics:** `VehicleDynamics.StepLongitudinal` for gear torque, rev limit and engine braking, applied beside the `balance.*` multipliers. `StepHandling` for grip loss and spin. `DrivingClient` for yaw and inertia, shift timing and the throttle-plus-steer spin trigger.
- **Config:** new numbered folders `Config.Vehicles.Dynamics.09_*` with `…Enabled` switches and `_RaisingThisDoes` strings, created before the first drive frame.
- **Feel and HUD signals:**
  - add Feel attributes for gear, RPM, shift events and spin in `DrivingClient`;
  - add plain fields (for example `Gear`, `Rpm`) to the `MobileDriveInputState` table from `DrivingClient`. No module edit is needed, but it is a shared table that both HUDs read.
- **Audio:** in `VehicleAudioClient`, replace the speed term in the rev formula with Feel RPM when present. Keep velocity-derived RPM for remote cars so the remote stays unchanged. Add new or extended profiles under `Config.Audio.VehicleProfiles` and map them by `CategoryProfile_<id>`.
- **HUD:** Pulse `HudView` (lines 370-405) plus a `Kit.Gauge` API extension, reviewed. Leave Classic HUD scripts unchanged and treat the feature as Pulse-only, following the radio precedent. Declare all edited Classic-recorded scripts in `declared.json`, and run the Classic verify and smoke check.