# Studio testing playbook

Practical recipes for agent-driven testing through the Roblox Studio MCP, learned while delivering the architecture programme (2026-09-26). Rules for which evidence counts are in the [delivery workflow](../13_efficient_feature_delivery_protocol.md) and [validation procedure](validation-and-handoffs.md); this page is the how-to.

## Before testing

- `list_roblox_studios` -> Space Racers v1 (121304917315753) -> `get_studio_state` (Edit). IDs change between sessions.
- **Check rendering before any camera, UI, tween or race test.** In Play, run on the Client: count `RunService.RenderStepped` for 1 s. If it is 0 while Heartbeat is 60, the Studio window is minimised/covered: tweens freeze (the start-screen Play button never appears), camera render-step code does not run and race staging never gets its countdown acknowledgement. Ask the user to bring Studio to the front. Server logic and GarageInvoke APIs still work without rendering.
- Sandbox: Config.Player.Onboarding `StudioVehicleSandboxEveryPlay` and `StudioReplayEveryPlay` are true, so every Play starts with no vehicles and 1,000,000 cash and profile saves are suppressed. Exception: **PersonalBestServer still writes PBs from the sandbox (PB-01)** - avoid finishing time trials until that is fixed, or accept the dev-account PB change.

## Driving the normal UI

- Start screen: wait for `PlayerGui.LoadingSafeContent.SafeRoot.StartScreenActions.Buttons.Play` (created after the loading tween), click it with `user_mouse_input` `instance_path`; confirm player attribute `StartScreenActive == false`.
- Buttons that share a name (e.g. confirmation YES/NO) cannot be targeted by path: compute `AbsolutePosition + AbsoluteSize/2` (+ GuiInset unless the ScreenGui has `IgnoreGuiInset`) and click by coordinates.
- **Onboarding tutorial overlay** (`PlayerGui.Onboarding.Overlay`) shades the screen and blocks clicks/driving input on modal steps. Advance with `Onboarding.Overlay.Bubble.Next`; some steps wait for a target click (e.g. the Race action button). Read the visible TextLabels to see the current step.
- First drive opens a controls modal (`DesktopFreeRoamHud...ModalLayer.Controls.Done`) that gates driving input (`DrivingControlsOpen`).
- Exit by the HUD button (`DesktopFreeRoamHud.DesignRoot.BottomActions.Exit`) stops the client drive session; the server `ExitVehicle` API does not (client camera stays in driving mode until despawn) - use the same method in before/after comparisons.
- Keyboard: `user_keyboard_input` keyDown/keyUp; W/S throttle, A/D steer, LeftShift drift (sprint on foot), Space boost, E prompts, P/C/V/B trailer camera keys.
- `character_navigation` walks the character to an instance (e.g. the dealership GarageDeskTrigger) but cannot drive a car; route barriers block straight-line driving.

## Useful sandbox APIs (Client datamodel, no-save sandbox only)

- `Remotes.Garage.GarageInvoke`: `GetInitial`, `BuyCockpitInstance {CategoryId="bruiser", CockpitId="bruiser_01"}`, `BuyModuleInstance {ModuleId="MODULE_SIDEPODS_LVL1", SlotId="SidePods"}`, `BuyVehicleCosmetic {CosmeticId="Underglow"}`, `BuyNeon {SlotId}`, `UpgradeModule {SlotId, ModuleId, UpgradeId}` (upgrade ids come from the module's own Upgrades list), `SpawnVehicle`, `ExitVehicle`, `DespawnVehicle`, `SpawnOwnedVehicleFromFreeRoam {VehicleId}`.
- `Remotes.Racing.RaceRequest`: `StartTimeTrial {EventId="shifted_canal_sprint_tt", VehicleId}`, `CancelTimeTrial`, `ExitFinishedTimeTrial`; listen to `RaceEvent` for Staged/Started/Checkpoint/Finished payloads.
- `Remotes.Garage.OwnedGarageInvoke`: `GetState`, `EnterSelectedGarage`, `ExitOnFoot` (transition cooldown ~1 s), `ConfigureStructure {Action="Purchase", SectionId, StyleId, RequestId, BaseRevision}`.
- Server: `ServerStorage.Runtime.NetStats` (runtime, Studio) shows calls/rejections per remote action; ServerBase/ClientBase `StartupState` attributes show ready/failed.
- Record API-driven results as API evidence, not normal-UI evidence.

## Race tests without a driver

Gates are real parts under `Workspace.World.RaceRoutes.<Route>` (Checkpoints + FinishLine). The owning client can `PivotTo` the car into each gate (dwell ~0.25 s so the server Touched fires) with waits of `distance / speed`: a plausible speed (<= 250 mph) must not be flagged by RaceIntegrity; zero waits simulate a teleport cheat. Label this evidence synthetic.

## Behaviour-parity (golden) testing

For refactors, run a fixed action sequence in a fresh sandbox before and after and compare canonical replies: encode tables with **sorted keys after normalising generated ids** (`vehicle_/module_/cockpit_` + 12 hex -> `<id>`), numbers `%.6g`, and hash each reply (FNV-1a) because execute_luau output is capped at 100,000 characters. Sorting before normalising makes random ids reorder entries and produces false mismatches. Reference sequence: `scripts/architecture/p5/golden-before.txt`.

## Tooling constraints

- `execute_luau` on the Client cannot use HttpService; paste client scripts inline. Edit/Server can load files from a localhost server: `py -3 -m http.server 8767 --bind 127.0.0.1` from `scripts/`, then `loadstring(HttpService:GetAsync("http://127.0.0.1:8767/..."))`.
- Never `require` gameplay modules through MCP. Pure library tests load the module source with `loadstring` and inject fakes with `setfenv` (see `scripts/architecture/p*/tests.lua`).
- Luau `string.gsub` returns two values: wrap in parentheses before passing to `table.insert`.
- Targeted captures: `py -3 scripts/studio_capture.py receive --name <name> --preset sources` (background), then in Edit `loadstring(HttpService:GetAsync("http://127.0.0.1:8766/script"))()`; `compare` two captures to prove scope. The sources preset does not record non-script instances (e.g. remotes).
- Installs: `scripts/architecture/installer.py <spec> <capture> <out.lua> --mode AUDIT|APPLY|ROLLBACK`; always AUDIT, then APPLY -> ROLLBACK -> APPLY to prove recovery; run the `delivery-reviewer` subagent before APPLY on High-Risk work.
