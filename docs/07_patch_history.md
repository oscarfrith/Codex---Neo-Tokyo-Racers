# Patch History

Recent deliveries, newest first. Entries before September 2026 live in [the archive](history/patch-history-2026-05-to-2026-08.md).

## 2026-10-10 - Radio: free-roam music with skip and back (PR98)

Standard lane, client presentation only, in **PR98**. Installer: `scripts/ui_restyle/radio/` (engine AUDIT, APPLY, ROLLBACK; `py -3 scripts/ui_restyle/tools/serve.py` first). Pulse only: Classic has no radio and no Classic script, payload or config that Classic reads changed.

- **Contract:** one music owner, `ReplicatedStorage.Modules.Game.Audio.RadioClient` (one local Sound in the existing `GameplayMusic` group, so the loading mixer ducks it). It plays `Config.Audio.Radio.Tracks` in `Order`, advances at the end of a track and exposes `Next`, `Previous`, `State` and `Changed`. The Pulse free-roam HUD starts it and draws `UIPulse.FreeRoam.RadioStripView` (previous, track name, next) on its `BottomCentre` slot, lifted above the HUD buttons (above the gauge on touch). The strip follows the HUD: hidden in races, menus, the full map and under modals. No remote, saved data or server change.
- **Context audio stays off.** `ContextAudioClient` also has a Music channel; `ContextAudioEnabled` is still false and its track lists are blank. Do not give it music tracks while the radio is on, or two owners will play music. Its Ambience channel is unaffected.
- **Changed:** created `Config.Audio.Radio` (`Enabled`, `Volume`, eight tracks Oscar sorted into his Free Roam folder), `Audio.RadioClient` and `FreeRoam.RadioStripView`; edited Pulse `FreeRoam.HudClient` and `FreeRoam.HudView`. `engine/build.py` now accepts a spec with `placeId` 103397770260610 (PR98); the default is still v3.
- **Phase 2 chain:** the two edited HUD sources are mirrored into `phase2/families/free_roam/after/`, but `phase2/install/02_free_roam` has not been reassembled and does not know `RadioStripView`. Reassemble from the family folder (and add the module's create op) before the next free-roam family delivery.
- **Tuning:** `Config.Audio.Radio@Volume`, `@Enabled`; per track `Title`, `Order`, `Gain` and the asset id in `Value`. Add a track by duplicating a `TrackNN` value.
- **Checked (agent, Studio Play in PR98, desktop, Oscar's real profile, on foot only):** silent at 0:00 behind the start screen; starts on Play; next, next, previous through the real buttons; automatic advance at the end of a track; one Sound at a time; all clients ready; no errors. **Not checked:** by ear, phone or tablet layout, gamepad focus, while driving or in a race, a track that fails to load. Not user-confirmed.
- **Also in the place:** Oscar's audition folders under `SoundService` (`Free Roam`, `Race`, `Not sure`, `Free Roam - new candidates`) hold unwired Sound objects; the Race tracks are not on the radio.

## 2026-10-09 - PR98 (published place): Exotic and Muscle classes always on

Fast lane, config only, in **PR98** (103397770260610), now the working place. Script: `scripts/release/pr98_vehicle_classes_always_on.lua`.

- **Cause:** after publishing, the dealership listed no vehicles. Exotic and Muscle are gated by `Core.FeatureFlags` keys with default off; Studio turns them on through `ServerStorage.Config@Flag_*` overrides, which live servers ignore, and PR98's new universe has no Creator Dashboard configs.
- **Changed:** the `FeatureFlag` attribute is removed from the `EXOTIC` and `MUSCLE` category folders (no attribute = always enabled, like Piercer). The dashboard can no longer switch a class off.
- **Checked:** attribute values read back; not tested on a live server. **Needs a republish by Oscar.** PR98 has its own DataStores, so saves from v3 do not exist there.
- **Lesson:** before a publish, list every `FeatureFlags` key whose live default differs from the Studio override.

## 2026-10-09 - Day/night cycle is 10 minutes

Fast lane. `ReplicatedStorage.Config.World.Lighting@ContinuousCycleDurationSeconds` 180 -> 600 (Oscar). Config only; not Play-tested. Back: set 180.

## 2026-10-09 - Race checkpoints: mesh-category cars now trigger gates

Standard lane. One line in `ServerStorage.Modules.Game.Garage.VehicleBuildService`, installed through the UI restyle chain (`06_garage`) because that script is hash-checked there.

- **Cause:** `TimeTrialServer` and `MatchmakingServer` find a vehicle by a gate's `Touched`. Exotic and Muscle cars had no part with `CanTouch` (mesh parts are built with it off, and the root is cloned from the Piercer root with it off); the old block-built Piercer cars had 96 touchable parts.
- **Fixed:** the driven vehicle's root (`CockpitRoot_DoNotRename`) gets `CanTouch = true` at build. Templates and their fingerprints are unchanged, so every category, including future ones, is covered.
- **Checked:** installed; AUDIT and Classic verify clean. **Not Play-tested** (Oscar is testing).
- **Lesson:** a new vehicle category needs one touchable part; add "drive through a checkpoint" to the category gates.

## 2026-10-09 - UI restyle: second play-review fixes (race map, vignette order, Space/Shift swap, logo)

Standard lane; chain refreshed through `scripts/ui_restyle/phase2/install/`.

- **Changed:** driving keys: **Space is drift/handbrake, Shift is boost** (`Vehicles.DrivingClient`, two lines; gamepad and touch unchanged), named so in the Pulse and Classic controls lists. The race HUD route map has no panel, only the route image and a player arrow. The race vignette moved to its own gui behind every HUD (`SharedInRaceHUDScrim`, order 57). The start-screen logo sits top right, larger, with a slow drift.
- **Checked:** AUDIT and Classic verify clean (214 same, 7 declared edits); Play in the sandbox: start screen, time trial HUD, Shift boosts, Space drifts. Not user-confirmed. `phase2/verification.json` (`review_pass_5`).

## 2026-10-09 - UI restyle: first play-review fixes (loading art, logo, focus guard, bigger car images, icons)

Standard lane on top of wave 2; the install chain was refreshed through `scripts/ui_restyle/phase2/install/`. Ten images uploaded (six loading tiles and a fallback, two icon sheets, the logo).

- **Changed:** the loading and start screens use the PulseSunset01 artwork (`Config.UI.LoadingSystem.Artworks`; the old one is disabled, not removed; both UI sets show it). The Pulse start screen shows the new neon logo. Dealership tiles show the car full frame; the free-roam vehicles list shows the whole car in a 3:2 picture with tier and rating on the right. Car, dealership and race icons redrawn.
- **Fixed:** you could not move in the player garage and WASD stepped through menus. One cause: the kit gave keyboard players engine focus (`GuiService.SelectedObject`), and the engine then takes WASD for focus. Engine focus is now for gamepads only and a session guard (`Kit.Input.StartFocusGuard`, started by `Shell.CoreUiPolicy`) clears it on keyboard, mouse and touch.
- **Tooling:** the installer's ROLLBACK no longer refuses a sources transaction because a folder made by the hierarchy transaction was filled by a later unit; the Classic verify accepts declared changes to recorded config values (`phase2/declared_config.json`).
- **Checked:** engine tests 37 of 37; kit harness 971 of 972; AUDIT and Classic verify clean (216 same, no config differences); Play in the sandbox for each change and a Classic start. Not user-confirmed. Details: `phase2/verification.json` (`review_pass_4`).
- **Lesson:** a Play check that moves the character with `Humanoid:MoveTo` does not prove the keys work; press the keys.

## 2026-10-09 - UI restyle wave 2: every remaining screen in Pulse; default flipped to Pulse (v3)

High-Risk lane. Eight install units through `scripts/ui_restyle/phase2/install/` (kit additions, race menu, free roam, map and prompts, race session, race entry, garage, shell). 31 images uploaded. Four more Classic scripts carry small edits (`RouteGuide`, `RaceTransitionClient`, two loading scripts). Contract and evidence: `scripts/ui_restyle/phase2/`.

- **Changed:** with `Config.UI@UIStyle` = `Pulse` (now the saved default, at Oscar's request) every UI family is the new owner; `Classic` restores the old UI.
- **Checked:** every unit compiles and runs its pure tests in Edit; `delivery-reviewer` on free roam, race session, shell and garage (fixes applied); AUDIT and Classic verify after each install; Play in the sandbox for start screen, HUD, driving, race menu, map, a prompt, race entry and a dealership purchase through to Drive. Not user-confirmed; many paths untested (see `verification.json`).
- **Found on the way:** game scripts cannot connect `StarterGui.CoreGuiChangedSignal`; kit components re-write `Visible` from their own state, so callers must go through `Set`; a weak-keyed record table lost a server-made prompt; `execute_luau` hits an HTTP request limit after many bridge fetches in a minute.
- **Recovery:** `UIStyle` = `Classic`; or roll the units back in reverse order, then Phase 1.

## 2026-10-09 - UI restyle Phase 1: switch, kit core, Pulse toasts, gallery (v3, default Classic)

High-Risk lane. One existing script edited (`ClientBase`, eight inserted lines), 20 ModuleScripts and two config folders created, three attributes added. Contract, review and evidence: `scripts/ui_restyle/phase1/`.

- **Changed:** nothing a player sees while `Config.UI@UIStyle` is `Classic`. With `Pulse`, `SharedTopNotificationUI` is routed to the Pulse toast owner and the Studio gallery tool entry is added.
- **Checked:** 21 sources compile; 554 pure tests; lint clean; `delivery-reviewer` READY WITH FIXES (applied); create proof with a save and reopen; AUDIT, APPLY, ROLLBACK, APPLY; Classic verify; one Play session in each style in the no-save sandbox. Not user-confirmed.
- **Recovery:** `py -3 scripts/ui_restyle/tools/serve.py`, then `scripts/ui_restyle/phase1/out_rollback.lua` twice in v3 Edit. Switch: `UIStyle` = `Classic`.

## 2026-10-09 - UI restyle Phase 0: contract, Classic record, spikes, previews, asset batch (v3, nothing installed)

Read-only in the place apart from the sandbox test window, which was opened and restored. Contract and results: `scripts/ui_restyle/CONTRACT.md`, `scripts/ui_restyle/phase0/RESULTS.md`.

- **Produced:** programme contract; style sheet v2; Classic source record (221 scripts) and `out_verify_classic.lua`; generated contract tables; installer engine; probes; spike harness; 62 preview images; 18 generated assets (not uploaded).
- **Checked:** Classic verify before and after the Play session (221 scripts and 1,124 config values the same); engine self-test 30 of 30 in Edit on detached instances; one sandbox Play session for the spikes and Classic baselines. Not user-confirmed.
- **Reusable:** in Play the server datamodel can fetch from the local bridge; the client can run fetched text as the source of an unparented ModuleScript, and `shared` persists between `execute_luau` calls. `user_mouse_input` coordinates are `AbsolutePosition` values.
- **Recovery:** none; nothing installed.

## 2026-10-06 - Driving tune: tier nerf, speed readout, settle, bank lift, parked sway, steering direction (v3)

Standard lane, driving owner, client only. Four scripts (`DrivingClient`, `VehicleDynamics`, `FreeRoamParkedHoverClient`, `DesktopFreeRoamHudUI`), three new config folders, 12 attributes. Contract, review and evidence: `scripts/driving_tune/`.

- **Changed:** balance multipliers from `PerformanceIndex` where stats become forces (10% at E to 25% at S, extra 15% on acceleration and braking, extra 20% on drift terms); HUD speed curve; ride height that sinks at rest, rises with the lean and bobs; corner springs that follow the commanded lean; local sway for the anchored parked car; no-throttle steering assumes forwards.
- **Checked:** compile, AUDIT, APPLY, ROLLBACK, APPLY; `delivery-reviewer` READY WITH FIXES (two applied); three Play sessions with the S-tier Seraph: 0 to 100 mph 1.65 s to 2.7 s, full-lean clearance from about 1.5 studs under the road to 0.3 to 1.0 above it, no errors. Not user-confirmed; no other tier driven.
- **Recovery:** `py -3 scripts/driving_tune/serve.py`, then run `scripts/driving_tune/out_rollback.lua` in v3 Edit. Switches: `BalanceEnabled` 0, `SettleEnabled`, `BankLiftEnabled`, `ParkedAnchoredPresentationEnabled`, `SpeedDisplayCurveEnabled`, `SteeringCoastAssumeForward`.

## 2026-10-06 - Lighting realism mix, step 6: painted night sky off, day restyled from the original (v3)

Fast lane (30 attributes, one removed attribute, one sky property; no source change). From Oscar's fourth drive.

- **Changed:** `ContinuousNightSkyName` removed (single sky, no day-for-night, no veil); `HorizonDaySky.StarCount` 3000; ClearNight lighting, atmosphere and clouds; Day lighting, atmosphere, clouds, bloom and grade; Dusk and NightEnd fades to defaults.
- **Checked:** live preview of night and day before install; after install one full 180 s cycle on its own: no server or render error, no sky art change, and no per-frame jump (largest steps: haze 0.006, key brightness 0.005, haze colour 0.002, engine clock 0.003 h).
- **Recovery:** `scripts/lighting_realism/step6/install.lua` `ROLLBACK`.

## 2026-10-06 - Lighting realism mix, step 5: haze held through the sky change; 3 minute test cycle (v3)

Fast lane (7 attributes). From Oscar's third drive.

- **Changed:** Dusk and NightEnd haze/colour fades, both veil colours, `ContinuousCycleDurationSeconds` 720 to 180 (testing only).
- **Checked:** live preview of evening (21.4, 21.98, 22.02, 22.18) and morning (1.98, 2.02, 2.5) before install; after install one full 180 s cycle running on its own: no server or render error, sky changes at 22:00 and 02:00 only, haze has a single peak at each change (was fall, rise, fall).
- **Recovery:** `scripts/lighting_realism/step5/install.lua` `ROLLBACK`.

## 2026-10-06 - Lighting realism mix, step 4: no black at nightfall, bluer day, less bloom, visible blur (v3)

Standard lane (two lighting sources and config). From Oscar's second drive.

- **Changed:** `LightingCycle` and `LightingCycleDefinition` (veil colour per side of the sky change; absent attributes keep black); three cycle attributes; 38 look attributes (Day lighting, haze, clouds and saturation; bloom and `DepthOfField` in all six looks).
- **Measured:** the same haze colour is dimmer on screen under the day-for-night sky than under the real night before it, so the after colour is the brighter of the pair (125,92,168 before, 155,108,240 after).
- **Checked:** live preview and colour matching in Play; ROLLBACK then re-APPLY with final values (43 operations); startup and full-day scrub with no server or render error; sky changes at 22:00 and 02:00 only; darkest haze channel over the day 0.31 (was 0 at the change).
- **Recovery:** `scripts/lighting_realism/step4/install.lua` `ROLLBACK`.

## 2026-10-06 - Lighting realism mix, step 3: twilight fix, stylised grade, far blur (v3)

Fast lane (58 attributes and one sky property; no source change). From Oscar's first drive.

- **Cause found:** the sky change sat inside the bright violet twilight, so the veil read as pitch black between two bright states; after it the moon was drawn by the engine sun at full strength and bloomed.
- **Changed:** `NightSkyStartClockTime` 22, `NightSkyEndClockTime` 2, `NightSkyVeilHours` 0.2; `StarNightSky.SunTextureId` to a dim moon; Dusk and NightEnd haze/colour fades; saturation and bloom in all looks; `DepthOfField` enabled in all looks with a light far blur.
- **Checked:** live preview in Play before install; after install, startup and a full-day scrub with no server or render error; sky changes at 22:00 and 02:00 only.
- **Recovery:** `scripts/lighting_realism/step3/install.lua` `ROLLBACK`.

## 2026-10-06 - Lighting realism mix, step 2: day sky, night sky, clouds (v3)

Standard lane (lighting renderer and config; no remote, saved data or economy). Oscar approved the step.

- **Changed:** sources `LightingCycle`, `LightingClient`, `LightingCycleDefinition`, `LightingServer`; new sky templates `HorizonDaySky` and `StarNightSky`; a `Clouds` folder in each of the six looks; six cycle attributes on `Config.World.Lighting`; eight ClearNight values. Lighting service Edit state and existing sky templates unchanged.
- **Behaviour:** with the new attributes absent the new code matches the old output exactly (2,400 samples, zero difference). With them: night art 20:30 to 03:30 shown day-for-night, change hidden by a veil, day art turned by clock, clouds blended per look.
- **Route:** `scripts/lighting_realism/step2/build.py` on the continuous-lighting installer engine. AUDIT, APPLY, ROLLBACK, re-APPLY with tuned values (26 operations).
- **Checked:** pure cycle test in Edit before install; Play: startup, full-day scrub with no server or render error, sky changes at 20:30 and 03:30 only, frames either side of the change match. Evidence: `scripts/lighting_realism/evidence/step2-*.jpg`.
- **Recovery:** `step2/install.lua` `ROLLBACK`.

## 2026-10-06 - Lighting realism mix, step 1: Continuous looks retuned (v3)

Fast lane (tuning attributes only; no source, remote or saved data). Oscar approved the plan and asked for a fallback.

- **Changed:** 71 attributes in `ReplicatedStorage.Config.World.Lighting.ContinuousPresets` (all six looks). Lighting service, skies, `ContinuousLooks` timing, `LightingPresets` and garage/dealership looks are untouched (before/after dumps compared).
- **Route:** `scripts/lighting_realism/build.py` builds `install.lua` from `backup/before.json` and `looks.json` on the existing continuous-lighting installer engine. AUDIT before, APPLY 71, AUDIT installed.
- **Checked:** values previewed live in Play before install; normal startup after install with no `LightingCycleError`; before/after screenshots in `scripts/lighting_realism/evidence/`.
- **Recovery:** `install.lua` `ROLLBACK`.

## 2026-10-04 - Hover feel: scripted chase camera, Exotic voice, continuous VFX, impacts (v3)

High-Risk (driving, camera and VFX owners), reviewed by `delivery-reviewer` before each APPLY (two reviews, READY WITH FIXES; fixes applied). Contract: [hover_feel/CONTRACT.md](../scripts/hover_feel/CONTRACT.md).

- **State:** `DrivingClient` publishes client-local `Feel*` attributes; 75 inserted lines, no force, input or existing attribute changed.
- **Camera:** `DrivingCameraClient` Scriptable chase mode; V6.1 kept behind `ScriptedChaseEnabled`. Oscar approved the return to a scripted camera on 2026-10-04.
- **Audio:** `VehicleAudioClient` and `VehicleAudioCatalog`: opt-in feel drive, profile `EXOTIC_V10_AUDIO`, category mapping `CategoryProfile_exotic`. Server and remote unchanged.
- **VFX:** `VehicleVFXClient` and `VehiclePreviewVFXClient`: continuous inputs for the local driving car, impact sparks from a runtime source, landing dust.
- **Sounds:** 26 synthesised files (`scripts/hover_feel/synth/`), not uploaded.
- **Evidence:** Edit: compile, AUDIT, APPLY, ROLLBACK, APPLY. Play: two desktop sessions through the start screen (API spawn, keyboard driving, HUD exit). Not user-confirmed. Record: `scripts/hover_feel/verification.json`.
- **Also:** the toolbox RX-7 was removed from `Workspace` at Oscar's request.
- **Round 2 (same day, Oscar's feedback):** camera roll in turns and drifts, higher framing, edge speed streaks; pop and bang events with matching backfire burst; old generic layers and the rotary idle off on the Exotic; boost, wind and pop slots; sound set revised to 34 files. Same installer (APPLY over the earlier build); reviewed by reading and a Play test, not by a second `delivery-reviewer` pass.

## 2026-10-04 - Modern Muscle category, game setup on placeholders (v3)

High-Risk (prices, locks, saved ids), reviewed by `delivery-reviewer` before APPLY (conditions met; risks recorded). Contract: [muscle-category-contract](architecture/muscle-category-contract.md).

- **Content:** third category `muscle`: six cars (E 230, D 330, D 410, C 480, C 565, B 630), 144 modules, Exotic structure, primitive geometry from the blockout spec. Prices 32,000 to 850,000.
- **Cap:** no build reaches A in the garage rating (exact bound over every Muscle part of every family and every upgrade allocation; Modern ceiling 717.90).
- **Tools:** balance and content builders take `--category`; Exotic output is byte-identical (content hash `b2f4b211...`). The installer engine and catalogue generator are unchanged.
- **Config:** six attributes (`Hidden_muscle` on three artwork folders, `VariantLabels_muscle`, `DealershipHiddenCategories = "bruiser,muscle"`, `Flag_VehicleClass_muscle`).
- **Installed:** content hash `ba880c2d...`, catalogue revision `1100fd98...`. AUDIT, APPLY, second AUDIT (nothing to apply), Exotic AUDIT (this build), post-install checks, attribute read-back and a before and after state probe clean; Play starts with no errors. No game script changed.
- **Unchanged:** Piercer and Exotic content and chunks; every game script.
- **Evidence:** agent-verified to install and start-up level. Not user-confirmed. Open: MUS-01 (on-road tier), MUS-02, TOOL-05.
- **Recovery:** no ROLLBACK. Before any profile owns a Muscle car, remove `Flag_VehicleClass_muscle`. Content faults: new build and APPLY.

## 2026-10-04 - Exotic GT and EVO body parts add stats (v3)

High-Risk (balance), reviewed by `delivery-reviewer` (approve with conditions; conditions recorded in [INTEGRATION.md](../scripts/exotic_category/mesh/INTEGRATION.md), section "GT and EVO body parts earn their price").

- **Content:** 36 GT and EVO body parts gain stats (aero on Front Body and Wing, weight and cooling on Rear Body); all 72 body parts carry Standard / GT / EVO versions; count labels and kit names tidied. Prices, ids, core modules and cockpits unchanged.
- **UI:** `ui_variant_labels` shows engine versions as GT and EVO for Exotic and clears a hidden preselected car in the dealership.
- **Installed:** content hash `b2f4b211...`, catalogue revision `4a7229c2...`. AUDIT, APPLY (apply only), second AUDIT, post-install checks and attribute read-back clean; Play starts with no errors.
- **Limits:** Rosso ceiling 848.12 against S at 849.495; kit 5 and kit 6 steps are small for that reason.
- **Evidence:** agent-verified to install and start-up level. Not user-confirmed.

## 2026-10-04 - Exotic mesh cars for all six cockpits (Backup v2 only)

Cockpits `exotic_01`, `03`, `04` and `06` join `02` and `05` as mesh cars, from model asset `121164261170819` (560 MeshParts, all six cars). Contract: [INTEGRATION.md](../scripts/exotic_category/mesh/INTEGRATION.md), extension section. Reviewed by `delivery-reviewer` (approve with conditions; conditions met and recorded).

- **Content:** 24 more body ModuleIds (36 in all); 144 Exotic modules. Side Pods, Splitter and Diffuser start empty on every car.
- **Unchanged:** every game script; Piercer; every existing ModuleId and its attributes.
- **Installed:** content hash `c4bc69bc...`, catalogue revision `649a3f3c...`. AUDIT, APPLY, ROLLBACK, APPLY and post-install checks all clean.
- **Evidence:** agent-verified to install level only. Not user-confirmed. Seats are not measured.
- **Same day, second build (Standard lane, content only):** cars renamed Stinger, Zephyr, Aurora, Endura, Rosso, Seraph (display names only); glossy finish (Reflectance on paint and glass, darker glass, Plastic detail) to match the workspace WIP cars. `installer_engine.lua` now writes `Reflectance` from the channel table. Installed: content hash `f34e9503...`, catalogue revision `79fad2e6...`; AUDIT, APPLY and post-install checks clean. No live script writes `Reflectance` (216 scripts searched).
- **Same day, third build (content only):** the 42 mesh modules renamed to match the new designs (display names and three body descriptions; ModuleIds unchanged); Reflectance raised to 0.22 / 0.14 / 0.3. Installed: content hash `8f6a1b16...`, catalogue revision `15ecf730...`; AUDIT, APPLY and post-install checks clean.
- **Recovery:** build `stage_b` at commit `68b3ed0` and APPLY to return to the two-car state.

## 2026-10-03 - Exotic mesh pilot: Curve and Hyper from uploaded meshes (Backup v2 only)

Cockpits `exotic_02` and `exotic_05` and their modules are built from MeshParts cloned out of model asset `112592679936648`. Contract: [INTEGRATION.md](../scripts/exotic_category/mesh/INTEGRATION.md). Reviewed by `delivery-reviewer` (approve with conditions, recorded in the contract).

- **Content:** seven mesh slots per car, three versions each (Standard, GT, EVO). Twelve new body ModuleIds; 120 Exotic modules. Side Pods, Splitter and Diffuser start empty on the two mesh cars.
- **Unchanged:** every game script; Piercer; Exotic kits 01, 03, 04, 06.
- **Installed:** content hash `4d735c74...`, catalogue revision `7a9044f3...`. AUDIT, APPLY, ROLLBACK, APPLY and post-install checks all clean.
- **Evidence:** agent-verified, partial: dealership preview and purchase of the mesh Curve in Play. Not user-confirmed. Seats on 02 and 05 are not measured.
- **Recovery:** build `stage_b` at commit `b9d1c8a` and APPLY to return to the primitive Exotic.

## 2026-10-03 - Exotic vehicle category (Backup v2 only; v2 untouched)

A second vehicle category is installed in Space Racers Backup v2 (place 133417340424236). Nothing is on v2 and nothing is published. Contract: [exotic-category-contract](architecture/exotic-category-contract.md).

- **Category:**
  - Exotic (`CategoryId = "exotic"`), six cockpits, one per tier: Spider, Curve, Wedge, Longtail, Hyper, Gull.
  - 108 modules: 72 core (Standard, Lightweight, Power) and 36 body parts.
  - Ten slots: the eight Piercer slots plus Nose (`FrontBody`) and Engine Deck (`RearBody`).
  - A bought Exotic arrives with its own kit in all ten slots.
- **Prices and ratings:**
  - Cockpits from 50,000 to 12,500,000, about 25% over the matching Piercer.
  - Stock ratings E 220, D 390, C 540, B 675, A 800, S 938.
  - Lightweight and Power modules cost 12% of the cockpit price. Body parts cost 8,000 to 30,000 by kit.
- **Stage A (code, 19 operations):**
  - `VehicleCatalogData` is now an index plus chunk modules, because Roblox rejects a script source of 200,000 characters or more.
  - 7 server and 7 client sources lose the one-category and eight-slot assumptions. Every new behaviour is opt-in through data that Piercer does not have.
  - `BuyCockpitInstance` now validates everything before it changes the profile or debits.
- **Stage B (content):** one dedicated installer. A pilot (the Wedge and 18 modules) came first and was rolled back; it caught the seat height and the glass colour. The full install is 6 cockpits, 108 modules and 1,746 template parts.
- **Flag and sandbox:** `Flag_VehicleClass_exotic` is on in that place. The no-save sandbox is on; it is required there.
- **Piercer:** golden replies are identical on all 24 must-match lines. One deliberate change: a purchase with a `CategoryId` that is not the cockpit's own is refused with "Cockpit not found."
- **Not verified:** saving and rejoin, devices, two clients, race entry and time trial with an Exotic, the owned-garage bay.

Agent-verified in Studio; not user-confirmed. The Wedge was tested through the real UI and the other five through API calls. Evidence: scripts/exotic_category/verification.json. Specs: scripts/exotic_category/stage_a/spec.json and scripts/exotic_category/stage_b/README.md. Open items: EXO-01 to EXO-04, VEH-01 and GAR-01 in [open issues](06_current_known_issues.md).

## 2026-09-27 - Map and jobs refinements (whole-map full map, hi-res tiles, glyph icons, speed zoom, cockpit passenger)

- **Full map:**
  - Pans and zooms across the whole blockout; the ALL button or F shows everything.
  - The legend is the map key only; tutorial objectives hide while the map is open.
  - The JOBS button and panel are removed; cancel a job with the X on the job strip.
- **Map art:**
  - 4x4 tiles at 4096² (level-set re-render, smoothed coast, no water fringe).
  - Glyph-only icons at about 2x size, with a refined thin outline and soft shadow.
  - Dealership and garage use the free-roam HUD icons, restyled cyan.
  - The customisation icon is hidden (`MapPois.Customisation.Hidden`).
  - Job icons no longer pulse.
- **Minimap:** zooms out with speed, from 1x at 40 mph to 1.8x at 200 mph, with smoothing (tunable in `DesktopFreeRoamHud.Layout`); both HUDs.
- **Jobs:**
  - Trips are about 3x longer and spread over the whole blockout (zones, with a city quota).
  - A replacement job appears at least 2000 studs from the finished one, in a new zone.
  - No job within 350 studs of places; roadside spots outside the city.
- **Passenger seat:** moved from the rear deck into the cockpit in front of the driver (offset 0, 1.0, 1.5), so the fare no longer blocks the camera.

Agent-verified in Studio (synthetic movement). Specs: scripts/map_ui/spec-v2/v3/v4.json and scripts/activities/world_jobs/spec.json.

## 2026-09-27 - Tutorial no longer restarts for returning players

OnboardingClient asked for saved progress once, before the profile had loaded, and never retried. Returning players therefore saw the new-player dealership guide trail every session. The client now retries until the saved state arrives and draws no trail before then. Agent-verified: a saved stage-2 profile shows only objectives 2 and 3. [Verification](../scripts/onboarding_fix/verification.json).

## 2026-09-27 - World jobs live (v2)

GTA-style taxi fares and parcels are installed; the Courier hub pads were removed (hub_pads.lua RESTORE is paired with installer ROLLBACK).

- **Fixes from play testing:**
  - The prompt now rides on the player's own car. ProximityPrompts only show on screen, and a prompt on the kerb went off-screen when the car pulled alongside.
  - The fare now walks with its root anchored; before, it fell through the world when boarding.
  - Spots must be real pavement, never foliage or bare baseplate.
  - More kerb candidates per pass, and the failure warning now lists rejection reasons.
- **Agent-verified:**
  - A taxi and a courier trip each paid once and nothing auto-started.
  - The crash-penalty breakdown is correct.
  - No rig leak; tests 101/101.

## 2026-09-26 - Full-screen map, map icons, route line v2; world jobs built (paused)

Four parallel agents, one integrator. Contract: [map-markers-contract](architecture/map-markers-contract.md).

- **Full map (installed):**
  - New modules: MapMarkers (registry), MapIconLayer (upright icons, pooled, fallback badges), FullMapUI (ClientBase entry) and MapMath.
  - The minimap click and M open it. The ROUTE GUIDE modal is removed; its destinations are now in the legend.
  - Config: Config.UI.MapPois, MapIcons, MapIconLayer, FullMap.
  - Integration fix: a full-screen backdrop button was swallowing map clicks and has been replaced by a bounds check.
  - Tests 40/40; APPLY/ROLLBACK/APPLY.
- **Map art (installed):**
  - The only baked icons were customisation, garage and race flag; they were removed from MapTileBottomRight (new asset 97942462366071).
  - 14 new icons uploaded (scripts/map_art/uploaded_assets.json).
- **Route line v2 (installed):**
  - Sub-pixel road centres, least-squares junctions, line/arc fit, and 50-stud radius corners.
  - LineWidth 5, OutlineWidth 1.5.
  - Seven options were measured; this one halves the crossing bulge with the fewest points. Tests 47/47.
- **World jobs (built, rolled back):**
  - What it does:
    - JobBoard keeps 6 taxi fares and 5 parcels on verified pavement spots, with trips of 1800–4500 road studs.
    - Prompt on the car, a single standard mode, a speed bonus and a crash penalty; no auto-restart.
  - The delivery-reviewer blocker (no rollback for the hub pads) is fixed with hub_pads.lua DELETE/RESTORE. Its small findings are fixed too.
  - Play-testing found two faults, which were fixed: kerb spots on baseplate or foliage, and a prompt that goes off-screen next to the fare.
  - Open: the fare rig falls through the world when unanchored for boarding (see 00_START_HERE).

## 2026-09-26 - GPS route guide installed (v2)

Road graph generated from the minimap artwork: v2 blockout roads and spawn markers describe an older, larger layout. Pipeline: read-only EditableImage export of the four tiles, then road-pixel mask, closing/opening, thinning, junction tracing, spur pruning and pixel-to-world calibration; 309 nodes and 475 edges. New RoadRouting (pure A*), RoadGraphData and RouteGuide (client owner and minimap renderer). Clicking the minimap opens ROUTE GUIDE; the race browser gets SET ROUTE; the chip shows destination and distance; routes re-plan when off-route and clear on arrival. One canonical installer (AUDIT/APPLY/ROLLBACK) verified apply, rollback and re-apply. Pure tests 28/28; agent-verified desktop play (modal, race browser, re-plan, arrival, driving). Mobile runtime untested (ROUTE-01). [Reference](route-guide-system.md), [verification](../scripts/route_guide/verification.json).

## 2026-09-26 - Studio saving enabled on v2

Oscar enabled Studio API access for v2. The vehicle sandbox and onboarding replay test modes were turned off (two Onboarding config attributes). A Studio save/rejoin test passed for Cash, Driver Rank XP, PassengerAccess and owned vehicles. PB-01 now writes real personal bests from Studio. Proper dev modes are to be planned later.

## 2026-09-26 - Street Life RP features (parallel build)

Built with four parallel agents, each in its own folder under scripts/activities/, and one integrator. Contract: [activities-contract](architecture/activities-contract.md). New generic tool: scripts/feature_installer.py (spec-driven AUDIT/APPLY/ROLLBACK).

- **Foundation:**
  - ActivityService (one activity per player, cleanup watchers, ActivityInvoke through Core.Net).
  - ActivityPayout (the only Cash/XP path; job hourly ceiling).
  - ProgressionService (Driver Rank: additive profile.Progression; rank-up Cash via RankReward).
  - ActivityClient (ActivityHud: job strip, offers, countdown, beacons, JOBS panel, rank-up card).
  - HUD: rank strip, JOBS button and a PASSENGERS setting (profile.Settings).
- **Courier:** 3 hub pads; Standard, Hot and Fragile runs; anti-teleport check; JobPayout.
- **Passenger seats + Sky Taxi:**
  - Passenger seat: a massless plain PassengerSeat. The car's mass is unchanged with an NPC aboard.
  - Fares: NPC fares, plus player taxi requests.
  - Pay: TaxiFare, with a driven-distance plausibility check.
- **Garage visits:**
  - Admission: same server, owner inside, on foot, using the owner's saved access mode.
  - Visitors are ejected when the owner leaves.
  - The browser gets a VISIT tab.

Each feature went through a delivery-reviewer pass with its blockers fixed, then APPLY/ROLLBACK/APPLY, pure tests (foundation 18, courier 58, taxi 52, visits 78), and a single-client Studio play check with synthetic movement.

Two-player flows remain for Oscar to test: passengers, player taxi requests, duels and visits.

Street Duels is integrated separately.

## 2026-09-26 - Minimap follows the character; north arrow removed

User-confirmed the rotating minimap, then asked for rotation by the character/vehicle facing and no north arrow. FreeRoamMapPlayerMarkers now defaults to MapRotationMode Subject and MapNorthArrowMode Hidden (new mode), and config was set to match. Agent-verified: map rotation equals character heading independent of camera; arrow up; no north arrow.

## 2026-09-26 - Rotating minimap; Studio target moved to Space Racers v2

Oscar moved the working place to Space Racers v2 (71491191583884); its sources matched the last v1 capture plus the CameraService commit. Capture tooling now accepts v2 (v1 stays valid for historical records). Installed the rotating free-roam minimap ([design 10.1](design/street-life-update.md#101-rotating-minimap)): the Minimap container is a CanvasGroup so rotated content clips to the box and rounded corners; a MapRotator turns the unchanged pan carrier by the camera heading; the north arrow orbits the rim; other-player circles rotate with the map; the desktop Settings MINIMAP control now sets a session MinimapMode (ROTATE / NORTH UP). Tunables on Config.UI.FreeRoamMapPlayerMarkers: MapRotationMode, MapRotationResponse, MapNorthArrowMode, MapNorthOrbitInset. Agent-verified on desktop (on foot, driving, toggle, no errors); mobile runtime, two-client markers and low-end CanvasGroup cost remain open (MAP-02). [Verification](../scripts/minimap_rotation/verification.json).

## 2026-09-26 - Handoff for feature work

User confirmed the architecture programme is working. Added the [Studio testing playbook](architecture/studio-testing-playbook.md), [Project 12 comparison](architecture/project12-comparison.md) and the new feature checklist; updated the new-chat prompt and /start. Documentation only.

## 2026-09-26 - Architecture P7: CameraService installed

Driving camera and sprint now request FOV/zoom through Core.CameraService (validated priority stack). Rendered Play comparison against a same-session baseline: identical driving/sprint/exit values; fixed on-foot FOV stuck at 95 after sprint -> drive -> exit; suspend/resume, respawn and disabled-sprint-FOV edge cases clean. Other camera writers remain for a later phase. [Evidence](../scripts/architecture/p7/verification.json).

## 2026-09-26 - Architecture programme from the Project 12 comparison (P1-P6, P8, P9 installed; P7 prepared)

Nine-phase programme after a read-only review of the team game Project 12. Installed and Studio-verified: shared Core library (Signal, Tags, ConnectionScope, ConfigReader); Core.Net guard on all 12 client remotes; RACE-01 RaceIntegrity (Log mode); MoneyService single debit point (12 sites); GarageServer split into eight verbatim factory modules (2,767 -> 1,121 lines, 18-step golden replies identical); FeatureFlags, AnalyticsServer and an inert save-first ReceiptProcessor; retirement of four dead remotes, the legacy DriveInCustomisationSession event and five client-unused legacy actions. Every High-Risk phase was reviewed by the delivery-reviewer before APPLY; each has before/after captures and AUDIT/APPLY/ROLLBACK/APPLY evidence. P7 CameraService is reviewed and packaged but not installed (Studio viewport not rendering). ECON-01 and PB-01 recorded. [Programme reference](architecture/architecture-programme.md).

## 2026-09-26 - Camera NaN (CAM-02) and detached-button retention (PERF-06-A) fixed

Reproduced CAM-02 via API exit/re-entry; normal UI flows alone did not trigger it. Root cause: DrivingClient computed forces from an anchored parked vehicle (infinite AssemblyMass) and left NaN VectorForces that threw the vehicle to NaN on unanchor; DrivingCameraClient latched the NaN into zoom bounds. DrivingClient now holds zero force while anchored/non-finite; DrivingCameraClient rejects non-finite speed/distance/FOV/zoom. PresentationAudioClient now releases button bindings when a button leaves PlayerGui. Three existing sources changed through guarded delivery (AUDIT/APPLY, exact before/after captures). Verified in Studio: 0 NaN/clamp errors across API cycles, normal UI driving/exit/re-entry and time-trial release; retained TextButtons 56 to 0 in a comparable session. DRIVE-01 user-confirmed. Device, soak and multiplayer gates remain open. [CAM-02 evidence](../scripts/cam02/verification.json), [PERF-06-A evidence](../scripts/perf06a/verification.json).

## 2026-09-26 - Continuous lighting user-confirmed

User reviewed the V6 horizon/moon refinement and confirmed the lighting "all looks good for now". Documentation only; no Studio changes. Device, low-graphics, streaming/retention and two-client checks remain open under LIGHT-01.

## 2026-09-26 - Primary assistant switched from Codex to Claude Code

Workflow/repository change only; no Studio, gameplay, source or saved-data changes. Added CLAUDE.md (imports AGENTS.md so rules stay single-sourced), .claude/settings.json permissions, .claude/commands for the follow/suggest/audit/continue/handoff routing plus capture, debug, design and commit helpers, and a read-only delivery-reviewer subagent. Documented the Roblox Studio built-in MCP tool mapping and rules in [Claude Code setup](architecture/claude-code-setup.md). Split entries before September 2026 into [the archive](history/patch-history-2026-05-to-2026-08.md). Added [docs index](README.md). Read-only MCP connection check: Space Racers v1, Edit, 168 inventoried sources.

## 2026-09-23 - Brighter horizons, softer moon glare and five-second holds

V6 user-confirmed overall. Lifted warm exposure/post/Decay, lowered excessive twilight/night glare, enlarged sun 6 to 9 and shortened warm holds to five real seconds. Thirteen existing attributes and one Sky property changed; no source or object changes. Numerical 58,383 assertions, selected runtime targets and visual comparisons, normal startup, 122-second daytime observation, guarded reversal/reapply and exact before/after scope pass. Original artwork/recovery, owners and pre-existing Edit rays preserved. No full-duration/device acceptance, migration rerun or publish. [Delivery evidence](architecture/lighting-horizon-moon-handoff.md).

## 2026-09-23 - Twelve-minute cycle, larger sun and strong horizon rays

V5 user-confirmed. Set cycle to 720 seconds and sun size 4 to 6; raised warm/day rays to 0.2/0.07 with spread 0.9. Following user clarification, full ray strength now includes both horizons with smooth fades in adjacent twilight. One pure evaluator source, ten attributes and one Sky property change; pre-existing Edit ray settings and all other selected state preserved. Numerical 58,389 assertions, normal startup, eight live horizon/night targets, 122-second actual-speed sunset observation, clock-rate check and guarded refinement reversal/reapply pass. No full 12-minute observation, installed migration rerun or publish. [Delivery evidence](architecture/lighting-twelve-minute-handoff.md).

## 2026-09-23 - Shorter red/pink/violet sunrise and sunset

User confirmed the orange V4 cycle looks really good. Shortened full warm holds from ten to three test seconds, made the peak redder, and tuned a rose-pink to violet twilight blend with reversed morning colour timing. Twenty existing config attributes changed; no game source, node or sky asset changed. Numerical 58,283 assertions, normal startup, full 122-second observation with no clock jumps/errors, guarded refinement rollback/reapply and exact targeted scope pass. Original shared artwork and Stepped mode preserved. No installed migration rerun or publish. [Delivery evidence](architecture/lighting-red-pink-handoff.md).

## 2026-09-23 - Extended orange horizons and smoother rendering

Strengthened Continuous sunrise/sunset orange, extended full warm holds from two to ten test seconds each, and moved adjacent appearance anchors outward for broader fades. Replaced the single renderer's uneven capped Heartbeat cadence with PreRender updates. Full before/after 122-second observations found no clock reset/competing outdoor context; maximum measured brightness/haze update steps fell 71%/69%. Numerical 58,089 assertions, normal startup, controlled context release, guarded rollback/reapply and targeted scope checks pass. One V3 source and existing config attributes changed; original shared artwork, solar timing and Stepped recovery preserved. Location-specific jumps remain unconfirmed and user visual/device review stays open. No publish. See [delivery evidence](architecture/lighting-orange-continuity-handoff.md).

## 2026-09-23 — Sunset exposure, sky colour and sun refinement

Implemented the approved separate fade controls, mirrored dawn ordering, targeted warm Continuous palette changes, smaller native sun and restrained rays with a smooth night gate. Kept the uniform two-minute clock, six-look timeline, original shared artwork, owners and easy Stepped reversion. Four V2 source revisions and one root attribute; existing Continuous config and sky properties updated through the same guarded canonical installer. 58,013 numerical checks, 122-second runtime observation, invalid-edit recovery, controlled context restoration, full rollback/reapply and eight original Stepped targets pass. Targeted capture verifies expected scope. Sampled pre-sunset views retain sky colour; user artistic review and named device/flow checks remain open. No publish. See architecture/lighting-sunset-refinement-handoff.md.

## 2026-09-23 — Editable solar/look timeline revision

Implemented the approved revision: uniform two-minute solar time, complete original sunrise/sunset/twilight targets at solar milestones, Day/Night holds, cloudless Continuous sky and attribute-based timing/appearance editing. Removed V1 art overrides without changing original presets, schedule, sky assets or owners. Same guarded installer revised and recovery-tested; six endpoint comparisons, 5,817 pure checks, full 122-second runtime loop, live valid/invalid tuning, fresh startup, controlled context handoffs, respawn and all eight Stepped targets pass. Targeted capture confirms five revised V1 sources, three root attributes and 53 added config/sky nodes, with no other captured original changes. Horizon exposure/artistic acceptance and named device/flow/streaming checks remain open. No publish. See architecture/lighting-look-timeline-handoff.md and architecture/lighting-authoring.md.

## 2026-09-22 — Continuous day/night lighting

Implemented the approved continuous cycle with the original eight stages and 900-second timing. One client renderer owns environment presentation; existing interior/dealership controllers supply context. Forward clock anchors and latitude calibration, bounded atmosphere/color/brightness blending and horizon-aware glare preserve smooth outdoor transitions. Streetlights/windows switch at sunrise/sunset as requested. Original presets and Stepped paths remain available via a restart mode switch. One guarded installer adds three modules, updates seven sources and adds five config attributes; no asset/tag/save/schema changes or publish. Numerical 34,688 checks, accelerated cycle, visible normal startup/dealership exit, controlled context overlap, all eight Stepped preset comparisons and full rollback/reapply pass. Exact targeted after capture verifies expected scope. User visuals, owned-garage normal flow, streaming/lifecycle, device and two-client checks remain open; see architecture/continuous-lighting-handoff.md.

## 2026-09-22 — Workflow Phase 4 reusable validation and handoffs

Added scoped normal-start/transition/error/cleanup/device/load/save recipes and evidence init/check/handoff tooling. Fifteen focused tests pass, including rejection of API/UI, simulator/device, insufficient-load and no-save/persistence substitutions. Artifact hashes, deferred reasons and next actions keep handoffs reviewable. Reused existing runtime/capture helpers; refreshed laptop prompt to follow current status. Repository-only changes, no Studio writes, gameplay changes or mirror refresh. All four workflow phases delivered; performance acceptance and existing issue gates remain open. See architecture/validation-and-handoffs.md.

## 2026-09-22 — Workflow Phase 3 proportional delivery

Added capture-backed guarded source/primitive-attribute delivery with read-only audit, exact preflight, compile, repeat and rollback. Dedicated migrations retain broader recovery contracts. Ten Python and ten pure-table Studio Luau cases pass; 21 capture tests pass. Live generated audit and before/after inventory prove zero changes across 165 sources. No game code, physical state or full mirror changes. Assistant-operated workflow replaces ordinary manual delivery steps. See architecture/proportional-mcp-delivery.md.

## 2026-09-22 — Workflow Phase 2 targeted capture

Added read-only scoped capture/compare with versioned deduplicated source blobs, complete nine-service source inventory, selected property/tag coverage and atomic evidence publication. Adapted catalogue/preview and naming checks; historical input is explicit. Live source/config/vehicle captures pass, repeated vehicle delta is zero, all 165 sources match retained baseline, and 21 scoped tests pass. Retained full-pipeline tests pass on rerun with initial transient-lock count sensitivity recorded. Routine full mirrors retire; deliberate full checkpoints remain. No gameplay/Studio state/full-mirror changes. See architecture/targeted-capture-workflow.md.

## 2026-09-22 — Workflow Phase 1 documentation consolidation

Centralised current status and delivery procedure; shortened AGENTS and lesson startup reading, separated open issues from resolved milestones, replaced stale prompt/tool instructions with maintained links, and removed repeated topic status banners. Preserved prior workflow text as history. Recorded the user's general gameplay confirmation without closing camera/resource/device/persistence gates. No Studio, scripts, mirror or gameplay changes; full-capture policy remains until workflow Phase 2.

## 2026-09-22 — Begin performance Phase 6 acceptance

Validation only; no installed code/assets/config changes. Twenty sandbox API cycles (140 successful responses) and normal startup pass, but start-screen state remained active: these do not count as full gameplay/UI cycles. CAM-02 reproduced. Scene analysis found 111 additional unparented TextButtons attributed to PresentationAudioClient; retention cause/plateau remains unproven. User has neither iPhone 7 nor isolated multiplayer place available. Phase 6 stays open for camera/resource investigation, real UI/route/input tests, device/15-player soak and separate persistence release evidence. Refreshed mirror 13:14:39: exact Phase 5 parity, 165 sources/44,465 nodes/276,087 properties; projections fresh. See architecture/performance-phase6-validation.md.

## 2026-09-22 — Install performance Phase 5 catalogue transport reuse

Seven sources changed and GarageCatalogClient added. GarageServer builds its unchanged public catalogue once per session; validated KnownCatalogRevision omits unchanged catalogue payloads. Existing callers receive detached catalogue copies plus fresh profiles. Eight matched samples: warm JSON 177,251 -> 3,956 bytes (97.8% smaller); typed catalogue length/checksum unchanged. Observed round-trip timing is recorded separately, not isolated CPU or compressed-wire proof. Compile/repeat/rollback/reinstall/fault recovery, 21 transport/guard checks, normal startup and sandbox purchase/paint/spawn PI551/C, exit/re-entry/despawn/preview/upgrade pass. Cash remains fresh after both mutations. Existing CAM-02 persists. Mirror 13:01:09: 165 sources, 44,465 nodes, 276,087 properties, zero unexplained differences; generated preview/data freshness pass. User/device/phase-6 acceptance pending; no publish.

## 2026-09-22 — Install performance Phase 4 vehicle preview projection

Moved original Assets.Vehicles intact to ServerStorage; generated 2,105-instance VehiclePreviews excluding 333 upgrade folders and their 1,479 attributes. Eight navigation consumers changed; all physical/paint/VFX properties and gameplay calculations retained. Exact preflight/compile/repeat/rollback/reinstall/injected recovery pass. 749,912 calculation comparisons still pass against relocated templates. Normal startup, sandbox purchase/paint/spawn PI551/C, exit/re-entry/despawn, live 285-descendant preview and Velocity upgrade at $6,050 pass. Existing CAM-02 persists. Mirror 12:47:08 verifies 164 sources, 44,464 nodes, 276,087 properties, both generated outputs fresh and zero unexplained changes. RS descendants 4,313 -> 3,980. Mesh/texture cost unchanged; measured join/memory/device benefit remains open. User playthrough pending; no publish.

## 2026-09-22 — Install performance Phase 3 catalogue separation

Generated four immutable-data/access/index modules from existing authoring attributes; changed six shared/client consumers to remove repeated template scans while preserving one calculator and all physical content. Exact preflight, compile, repeat-install, rollback/reinstall and injected failure recovery pass. Pure before/after tests: 6 cockpits, 116 modules, 5,380 allocations, 749,912 comparisons, including owned profile/selection/upgrade previews. Normal startup and sandbox purchase/paint/spawn/exit/re-entry/despawn pass; PI551/C retained. Drive-in preview pad/ownership logs pass; visual acceptance pending. CAM-02 persists. Mirror 12:31:08: 164 sources, 42,359 nodes, 267,539 properties, zero unexplained differences and fresh projected catalogue. Added bounded Windows rename retries after safe import failures; 11 pipeline tests pass. Physical templates remain replicated; no FPS/download reduction claimed. User playthrough pending; no publish.

## 2026-09-22 — Install performance Phase 2 server-only storage

Moved six reviewed roots (three modules/three config groups, 14 instances) intact to ServerStorage; added four destination folders. Updated nine service literals in six server callers, with token proof and no gameplay/config-value/client/physical changes. One canonical installer supports exact preflight, compile, audit, idempotency and repository-backed rollback. Repeat/rollback/reinstall and injected transaction failure recovery pass. Normal startup 26 server/39 client/four skipped; sandbox purchase/paint/spawn/exit/re-entry/despawn and performance writer pass. CAM-02 camera errors recur, unchanged. Final mirror 12:07:02: 160 sources, 42,355 nodes, 267,539 properties; exact expected source/full captured property parity, zero unexplained changes. ReplicatedStorage descendants 4,323 → 4,309; no FPS claim. User playthrough pending. See architecture/performance-phase2-server-storage.md. No publish.

## 2026-09-22 — Performance Phase 1 local audit and initial baseline

User approved Phase 1 and selected iPhone 7. Added repeatable read-only mirror dependency analysis, bounded Studio runtime sampler and sandbox catalogue-response sampler. Reviewed six server-only move candidates (14 instances, 20,805 source bytes), transitive shared dependencies and 50 config groups. Captured four eight-second Studio windows and five GetInitial responses; catalogue is 173,361 JSON bytes per result, not measured wire size. All startup owners ready; no source/config/asset changes. Phone, controlled route/join, profiler/network attribution, 15-player and soak evidence explicitly deferred. Final mirror 11:13:49 passes exact cleanup Phase 4 parity. Phase 2 unimplemented. User authorised commit/push; no production publish.

## 2026-09-22 — Confirm cleanup Phase 4; propose performance programme

User reports successful testing, commit and push. Mark all four cleanup phases confirmed; protected physical staging/Archive decision and release gates remain separate. Refreshed mirror at 11:00:13 passes all 160 sources and exact expected 42,351 nodes/267,539 properties. Read-only MCP inventory finds 4,323 ReplicatedStorage descendants, including 2,437 vehicle asset and 1,480 config records. Proposed six deliveries in architecture/performance-and-replication-plan.md: measurement, server-only moves, catalogue separation, preview/template delivery, measured runtime/network optimisation and device/streaming acceptance. No gameplay, source, hierarchy or config mutation. Lesson: client consumers and generated public data determine replication boundaries; folder names/counts alone do not prove savings or unused content.

## 2026-09-22 — Cleanup Phase 4 finalisation

User approved Phase 4 and explicitly accepted preserving arrival differences: 628 arrow CFrames and 66 thumbnail-model records. Installed one exact-source cleanup: 61 bodies, 179 private identifier mappings, patch-stamp comment removal and diagnostic naming; token checks preserve executable logic and non-diagnostic contracts. No instance, asset, tag, attribute or physical changes. Generic snapshot exporter/receiver/importer replace active old entry points; originals archived unchanged. Read-only live/local audits added, current docs consolidated and old instructions archived.

Compile, repeat-install, rollback/reinstall, normal startup (26 server/39 client/four skipped), sandbox purchase/paint/spawn/exit/re-entry/garage state/race validation/TT start-cancel pass. Nine pipeline tests and final mirror verification pass: 2026-09-22 10:25:06, 160 sources, 42,351 nodes, 267,539 properties, zero unexplained changes. CAM-02 reproduced as pre-existing; no camera change. User full playthrough and protected staging/archive decision remain open. Canonical installer: scripts/roblox_cleanup_phase4_finalise.lua. No publish.


## 2026-09-05 — Fix Windows snapshot permissions blocking GitHub Desktop

The importer staging directory used tempfile.mkdtemp, whose Windows private ACL was retained by promoted mirrors. GitHub Desktop under Oscar could not read manifest.json although the sandbox could. Restored inherited permissions on both mirror roots; changed staging to exclusive UUID-named mkdir with normal parent ACL inheritance. Nine pipeline tests pass, including Windows staging inheritance and rollback-on-promotion-failure. No Studio or mirror content changes; Phase 3 remains user-confirmed. Retry commit with raw paste unchecked.

## 2026-09-05 — Confirm cleanup Phase 3; prepare laptop handoff

User reported all worked well. Locked Phase 3 as confirmed; Phase 4 is next. Read-only live audit and post-playtest mirror refresh at 16:06:57 pass all 160 source hashes, expected hierarchy/property parity and excluded Workspace checks. Added laptop transfer/runbook and new-chat prompt, corrected current owner/handoff status. No gameplay edits or publish. Git commit/push and a saved playable place transfer remain user actions; the mirror is not a full place backup.

## 2026-09-05 — Install cleanup Phase 3 generic naming

Complete cleanup Phases 1 and 2 are user-confirmed. Phase 3 is installed and agent-verified; user gameplay confirmation is pending. Phase 4 remains unimplemented. Current mirror: 2026-09-05 15:59:57, 160 sources, 42,285 nodes and 266,840 properties, with exact expected source/hierarchy/property parity. The two lighting-tag renames on 62 enumerated WIP objects are approved and installed. Protected staging/archive disposition remains pending. Canonical installer: scripts/roblox_cleanup_phase3_generic_naming.lua. Renamed World, Assets, Remotes, feature configs and technical tags/attributes; retired 210 nonphysical records, preserved physical content and stable external IDs. Controlled visible-client comparison reproduced the camera NaN/clamp issue on the exact Phase 2 baseline and Phase 3; left it unchanged as CAM-02. Audit/idempotency/rollback, six contract tests, feature smoke and full final mirror parity pass. User gameplay checkpoint pending. Lesson: equivalent runtime conditions resolved a misleading apparent regression.

## 2026-09-05 — Build cleanup Phase 3; restore baseline for camera comparison

Phase 3 installer built and exercised, then rolled back pending an equivalent camera-transition comparison. The two lighting-tag renames on the exact 62 WIP objects are authorised; staging/archive disposition remains pending. Phase 2 is installed and user-confirmed. Restored mirror 2026-09-05 15:52:58 passes all 160 source hashes and complete hierarchy/property parity. See docs/architecture/cleanup-phase3-generic-naming.md. Phases 3 and 4 remain unfinished. Canonical script: scripts/roblox_cleanup_phase3_generic_naming.lua. Compile/audit/idempotency/rollback/reinstall, physical/WIP invariants and six local contract tests passed. Sandbox feature smoke reached time-trial countdown, but BaseCamera clamp errors require a controlled comparison. No publish or production save. Lesson: runtime equivalence needs matching client conditions; source parity alone is insufficient.

## 2026-09-05 — Confirm cleanup Phase 2; prepare Phase 3 naming migration

User confirmed Phase 2 worked well and authorised Phase 3. Read-only live/source/compile and refreshed mirror checks pass: 160 sources, full expected hierarchy/property parity, unchanged Workspace at 15:28:27. Inventoried generic hierarchy/configuration migration and discovered two lighting tags shared with 62 excluded WIP objects; asked for a narrow scope decision and staging/archive disposition. No Phase 3 Studio source/hierarchy/tag changes and no installer generated yet. See architecture/cleanup-phase3-generic-naming.md and scripts/cleanup_phase3 evidence.

## 2026-09-05 — Confirm cleanup Phase 1; install Phase 2 canonical ownership

User confirmed Phase 1 working. Installed Phase 2: 323 to 160 sources, 133 forwarding adapters and old code hosts retired, live endpoints moved to feature Runtime folders, GarageUI startup direct and current driving callbacks extracted into DriveSessionClient. Removed unused legacy closure/helpers/alternate execution branches; preserved profile semantics, tuning, UI owners and entire Workspace. Compile, rollback/reinstall, startup and sandbox garage/vehicle/time-trial checks pass. Final mirror 15:14:10 matches every expected source/hierarchy/property record. Full gameplay checkpoint pending; two phases remain. Canonical installer: scripts/roblox_cleanup_phase2_canonical_ownership.lua. See architecture/cleanup-phase2-canonical-ownership.md. Lesson: move runtime endpoints and both readiness producer/consumer paths before retiring script hosts.

## 2026-09-05 — Complete cleanup Phase 1 scaffolding retirement

Installed the authorised first phase: removed 91 unused scaffold/report objects and 15 obsolete root migration attributes, without changing any of 323 gameplay sources or any Workspace content. Removed the exporter's in-game fallback-writing branch; receiver failure now creates nothing. Audit/repeat install/rollback/reinstall, compilation, 26 server/40 client startup with four tools skipped, dealership event, sandbox purchase/spawn/DriveReady/exit and eight pipeline tests passed. Full uninterrupted driving remains user verification. Final mirror 12:36:11 passes exact expected hierarchy and full source parity. Classified staging/archive assets; no physical deletion. Two originally detached historical shortcuts restore nil during explicit recovery. Canonical installer: scripts/roblox_cleanup_phase1_scaffolding.lua. See architecture/cleanup-phase1-scaffolding.md; three phases remain.

## 2026-09-05 — Revised complete cleanup plan (documentation only)

Recorded a proposed four-phase programme replacing the conversational three-delivery proposal: retire scaffolding, complete canonical ownership and remove legacy execution paths, migrate generic hierarchy/config/names, then tooling and final regression. Incorporated the World-only Workspace boundary, protected physical content, no in-game backups/fallback implementations, retained opt-in development tools and stable external data identifiers. Added per-phase gameplay/rollback/mirror gates and a no-unclassified-leftovers completion ledger. No Studio changes or mirror refresh; current installed baseline unchanged. See architecture/complete-cleanup-plan.md.

## 2026-09-05 — Confirm Phase 5; retire reviewed legacy items

User confirmed the final architecture phase and authorised cleanup while protecting models/meshes/parts. Removed 117 code/metadata objects (11 disabled scripts, four unused registry/resolver modules, 16 folders and 86 values) plus 70 obsolete source patch-stamp attributes. Retained opt-in development tools by user request, live adapters, tuning, designer links and uncertain theme/fallback areas. No surviving source changed. One exact-record installer supports AUDIT/INSTALL/ROLLBACK; compilation, repeat install, rollback/reinstall and normal Play startup (26 server, 40 client, four skipped) passed. Full mirror 12:07:40: 323 verified sources, all remaining exported node/property data matches the expected baseline, no physical changes. User cleanup playtest pending. See architecture/legacy-cleanup.md and scripts/roblox_legacy_cleanup.lua. Restore cleanup before older exact-baseline phase recovery.

## 2026-09-05 — Architecture Phase 5 LOD optimisation and handoff

Phase 4 user-confirmed. Replaced the canonical LODClient with a thin owner plus LODRuntime/LODPolicy, preserving live bands/collision semantics and placing tuning in WorldLOD attributes. Fixed recursive missing-proxy lookup, dynamic block/member registration, deferred-removal cleanup and far-clone retention; cached buckets skip unchanged work. Eight isolated tests, normal-client late block/removal/re-entry, startup, 338-source compilation and audit/idempotency/rollback passed. Controlled seven-position CPU trace median 27.37 → 14.11 ms; small registration/idle overhead is recorded, with no FPS claim. All 335 other sources retain parity. Full mirror 11:50:30 verified, raw paste untouched. Added company-facing architecture/workflow handoff and release gates. User final city/streaming playthrough next. Canonical installer: scripts/roblox_architecture_phase5_world_optimisation.lua.

## 2026-09-05 — Architecture Phase 4 client organisation

User confirmed Phase 3 gameplay. Installed ClientBase with 44 explicit entries and migrated 92 implementations to ReplicatedStorage.Modules, preserving old-path adapters and disabled experiments. Reused shared theme reading, extracted legacy preview-input subscription ownership, removed disabled proximity polling, and gated trailer/lighting tools behind Studio plus opt-in config. Existing gameplay/renderers/driving equations remain. Four isolated helper groups, exact audit/idempotency/rollback, 40 completed client startups + four skipped tools, all 26 server startups, sandbox purchase/garage preview/workshop and command/event spawn/exit/re-entry passed. All 336 sources compile; 148 out-of-scope sources retain exact parity. Full mirror 2026-09-05 11:34:22, integrity PASS. User guided gameplay/device test next; Phase 5 remains. Canonical installer: scripts/roblox_architecture_phase4_client_organisation.lua. See docs/architecture/phase4-client-organisation.md for limits and rollback.

## 2026-09-05 — Architecture Phase 3 server organisation

- User confirmed Phase 2 playthrough and authorised continuation. ServerBase now starts 26 explicit services; 41 implementations have canonical ServerStorage.Modules.Game paths with stateless old-path adapters. Disabled historical scripts remain disabled.
- Extracted EconomyServer and runtime/persistent profile filtering. Removed the garage-owned profile cache and garage/racing whole-profile imports; ProfileServer retains the authoritative session, save transport and stable schema/IDs.
- Nine isolated architecture tests passed. All 26 services reached ready; sandbox purchase/reward/paint preserved Cash and vehicle identity, and spawn/exit/re-entry, stale-import rejection and actual snapshot encoding passed. Repaired startup wait/lighting readiness in the same installer.
- Canonical installer: scripts/roblox_architecture_phase3_server_organisation.lua. Audit/idempotency/rollback/reinstall passed, 240 sources compile, mirror refreshed at 11:16:45 and verified. User gameplay acceptance remains pending; no publish or real production data mutation claimed. See architecture/phase3-server-organisation.md.

## 2026-09-05 — Architecture Phase 2 persistence/request safety

- User confirmed Phase 1 worked well and approved continuation. Added ProfileStore transport and GarageRequestGuard around the existing owners; no runtime renames, gameplay balance or asset changes.
- Blocked writable failed-load defaults, pinned no-save sessions, added renewable session leases, serialised revision-aware saves and coordinated closing. Garage hydration waits for authoritative data; generic requests are bounded and checked before expensive work.
- Canonical installer: scripts/roblox_architecture_phase2_persistence_safety.lua. Nineteen isolated tests, live sandbox/remote smoke, exact audit, repeat install, rollback/reinstall and all 195 script compilations passed.
- Refreshed mirror at 10:58:29; only two existing sources changed and two modules added. User gameplay acceptance and isolated published-place save/rejoin remain pending. Drain old profile writers before production deployment. See docs/architecture/phase2-persistence-safety.md.

## 2026-09-05 — Architecture Phase 1 foundation

- Approved company-familiar naming/ownership programme recorded; runtime migrations remain later phases.
- Replaced long current startup/issues pages with compact state and open risks; preserved both original records in docs/history.
- Added a read-only all-source compile audit, frozen source baseline, mirror verifier and failure-oriented tooling tests.
- Extended the existing V2 exporter with property schema revision 3 and fail-closed source reads. Normal HTTP export no longer writes Studio export objects.
- Added validated staged mirror replacement and rollback; raw paste is opt-in and its existing user diff is preserved.
- Gameplay sources, enabled states, settings and saved data were unchanged in Phase 1. Verification details: docs/architecture/phase1-verification.json. User subsequently broadly confirmed everything worked well.
