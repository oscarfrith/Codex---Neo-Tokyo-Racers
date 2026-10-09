# Play record capture points

The 14 fixed points for `play_record.lua` (plan 1.8), for a desktop Studio Play session with keyboard and mouse. Steps are derived from the Classic sources in `scripts/ui_restyle/classic/sources/`; nothing here has been run in Studio yet, so the first Phase 0 pass also confirms these steps. Items marked **unconfirmed** could not be settled from source.

Short names: `PG` is `LocalPlayer.PlayerGui`, `HUD` is `PG.DesktopFreeRoamHud.DesignRoot`. Source files are named by their last path segment.

## Rules for every run

**Never do these:**

- Never cross a time-trial finish line, and never complete a lap. Quit after a completed lap records a personal best too (`TimeTrialServer` 697, 767). See `SANDBOX_NOTES.md`.
- Never press JOIN RACE (it queues the player with real matchmaking state).
- No purchase or equip of any kind unless the Player attribute `StudioVehicleSandboxActive` is `true` in this Play session. Even then, only the one set-up purchase below.
- Never click a paint swatch or release a paint slider (they commit at once, `GarageUI` 111-116), a PASSENGERS button in Settings (`DesktopFreeRoamHudUI` 607-612), or the start-screen `Shop` button (it teleports, `InitialLoadingAndStartScreenClient` 312-316).
- Do not walk within 5 studs of the dealership desk unless `DealershipIntroObjectiveComplete` is already `true` (the first approach writes a DataStore key; `DealershipIntroClient` 583-595).

**Before the run:**

1. Edit: `sandbox_window.lua` with `mode = "open"` (needs Oscar's yes). Leave `replay` off so the saved onboarding stage is used and the HUD buttons are not locked.
2. Play. Check rendering is live (`perf_sample.lua` with `seconds = 1` returns `render.frames > 0`).
3. Server: `profile_fingerprint_server.lua`. Confirm `sandboxActive` is true and read `playerAttributes.OnboardingStage`.
4. If `OnboardingStage` is below 4, the onboarding overlay will lock `Car`, `Garage` and `Race` until its pages are seen (`OnboardingClient` 666-671, 209-221). Advance it with `PG.Onboarding.Overlay.Bubble.Next`. Record the stage with the run, because the overlay changes the hashes.

**The one set-up purchase.** The sandbox starts with no vehicles (`ProfileServer` 204-213), so points 3, 4, 8, 9, 10 and 12 need a car. Buy one car in the dealership (point 11) after capturing it, with `StudioVehicleSandboxActive` confirmed. It is in memory only. This is a set-up step, not a capture point, and it is the integrator's decision with Oscar; the alternative is to run without the sandbox on Oscar's real profile, where every save is live.

**At each point:** wait 1.5 seconds for tweens to settle, then run `play_record.lua` with `label` set to the id below and `run = "a"`. Repeat the whole pass in a second Play session with `run = "b"` and compare each pair with `play_record_diff.py`.

## The points

| Id | Point | How to reach it from the previous state | Arrived when | Leave without committing |
|---|---|---|---|---|
| `01_start` | Start screen | Automatic after loading. Wait for `PG.LoadingSafeContent.SafeRoot.StartScreenActions.Buttons.Play` to exist (`InitialLoadingAndStartScreenClient` 114-140). | Player attribute `StartScreenActive == true` | Click `Buttons.Play` |
| `02_on_foot` | Free roam on foot | Click `Play`. | `StartScreenActive == false`; `HUD.BottomActions.Visible == false` | n/a |
| `03_driving` | Seated, driving HUD | Click `HUD.ActionBar.Car`, then the card `Vehicle_<VehicleId>` in `HUD.CarPanel` (`DesktopFreeRoamHudUI` 743-749). If the first-drive Controls modal opens, capture it as `05a` first, then click `HUD.ModalLayer.Controls.Done`. | `HUD.BottomActions.Visible == true`; `DrivingControlsOpen ~= true` | `HUD.BottomActions.Exit` ("EXIT VEHICLE") parks the car |
| `04_car_panel` | Car panel | Click `HUD.ActionBar.Car` (no key; 863-877). | `HUD.CarPanel.Visible == true` | Click `Car` again. Do not click `BuyMore` or `Despawn` |
| `05a_controls` | HUD modal: Controls | While seated, click `HUD.BottomActions.Controls` (979-985). | `DrivingControlsOpen == true` | `HUD.ModalLayer.Controls.Done` |
| `05b_settings` | HUD modal: Settings | Click `HUD.ActionBar.Settings` (889). | `HUD.ModalLayer.Settings.Visible == true` | `Settings.Done`. Do not click a PASSENGERS button |
| `05c_cash` | HUD modal: Get Cash | Click `HUD.LeftCluster.Money.Plus` (908-911). | `HUD.ModalLayer.Cash.Visible == true` | `Cash.Close`. The `Pack1..4.Buy` buttons only show a toast, but leave them alone |
| `06_full_map` | Full map | Press `M`, or click `HUD.LeftCluster.Minimap.RouteButton` (`FullMapUI` 676; HUD 958-963). | Player attribute `FullMapOpen == true` | `M`, `Escape`, or `PG.FullMap.Panel.Close` |
| `07_race_menu` | Race menu | Click `HUD.ActionBar.Race` (882-884). | `PG.RaceBrowser.Overlay.Visible == true` | The button named `Exit`. Do not click `TeleportToStart` |
| `08a_entry_setup` | Race entry: Setup | Drive into a route start zone and trigger the prompt `RaceEntryPrompt` ("Open Race Menu", key `E`; `TimeTrialServer` 109, 1293-1313). Keyboard input cannot trigger prompts (testing playbook): use `prompt:InputHoldBegin()` / `InputHoldEnd()` on the client. | `PG.RaceEntryPresentation` enabled with its first Frame visible | Button with Text "EXIT" |
| `08b_entry_records` | Race entry: Records | On the TIME TRIAL tab click "NEXT" (`RaceEntryPresentationClient` 808-811). | Header label text | "BACK" |
| `08c_entry_vehicles` | Race entry: Vehicles | Click "CHOOSE VEHICLE". Selecting a `Vehicle_<id>` card or a tier button is local only. | Header label text | "BACK", "BACK", "EXIT". Never "START TIME TRIAL" or "JOIN RACE" unless going on to point 9 |
| `09_in_race` | In-race HUD | From `08c` click "START TIME TRIAL". Capture once the countdown has finished and the car is stationary on the grid. Do not drive through any gate. | `PG.SharedInRaceHUD.ReferenceCanvas.Visible == true` | Point 10 |
| `10_quit_confirm` | Exit confirmation (the Quit path) | In `PG.SharedInRaceHUD.ReferenceCanvas.SessionControls` click the button with Text "EXIT" (`RaceSessionPresentationClient` 198). | `...ReferenceCanvas.ExitConfirmationShade.Visible == true` | Click "YES". With no lap completed this returns to free roam on foot at the route start and destroys the car; no results screen appears (`TimeTrialServer` 698-709) |
| `11_dealership` | Dealership browser | Click `HUD.ActionBar.Dealership`, then "YES" on `PG.SharedConfirmationOverlay` (capture that as `14` first). Trigger the prompt `CanonicalDealership` on `Workspace.World.Dealership.Intro.Desk.GarageDeskTrigger` (`GarageEntranceClient` 37-39, 152-160) from more than 5 studs away. | Player attributes `GarageSessionActive == true`, `GarageEntryMode == "Dealership"` | `CanonicalGarageBrowser.Exit` |
| `12a_customise_hub` | Customise hub | With an owned car: prompt `CanonicalCustomisation` on `...Dealership.Customisation.CustomisationDeskTrigger`, or `CanonicalDriveIn` on `DriveInCustomisationTrigger` while driving (`GarageEntranceClient` 42-52). | Workspace root attribute `TutorialPageId == "CustomisationHome"` (`GarageWorkspaceUI` 143, 351) | Only `Continue` ("DRIVE"), which spawns the car. There is no Back on the hub (`GarageUI` 178-210) |
| `12b_parts` | Customise: Add Modules | Click the hub card whose attribute `CanonicalGarageCardId` is `AddModules` (`GarageUI` 214-216). | `TutorialPageId == "AddModules"` | `Back` |
| `12c_upgrades` | Customise: Upgrades | Card `UpgradeModules` (hub or left rail, 303-305). | `TutorialPageId == "UpgradeModules"` | `Back` |
| `12d_paint` | Customise: Paint Shop | Card `PaintShop`. Capture only; touch no swatch or slider. | `TutorialPageId == "PaintShop"` | `Back` |
| `13a_garage_browser` | Owned-garage browser | Click `HUD.ActionBar.Garage` (878-880). | `PG.OwnedGarageBrowser.Overlay.Visible == true` | `Exit` |
| `13b_garage_interior` | Owned-garage interior HUD | In the browser click `Enter` ("ENTER GARAGE"; `OwnedGarageBrowserUI` 109-115). Needs an owned garage: **unconfirmed** for the sandbox profile. | Player attribute `OwnedGarageInside == true` | Prompt `FootExitPrompt` |
| `13c_garage_manage` | Owned-garage management | Inside, trigger the prompt `ManageGaragePrompt` (`OwnedGarageManagement` 235-243). Capture the Home page only. | `PG` attribute `OwnedGarageManagementOpen` | `Exit`. Never press a popup action reading BUY, EQUIP, DISPLAY, INVITE or REVOKE, or `Continue` when it reads SAVE |
| `14_confirm` | Shared confirmation overlay | Click `HUD.ActionBar.Dealership` (886). | `PG.SharedConfirmationOverlay` exists (DisplayOrder 1250) | Button with Text "NO", or `Escape` (`ResponsiveUIFoundation` 328-426) |

That is 14 points; points 5, 8, 12 and 13 have lettered sub-captures because the plan names each modal and page. The plan does not list the fourteenth point by name. `14_confirm` is this folder's choice (the shared confirmation is the only Classic dialog not covered by the other thirteen); change it if the programme contract names a different one.

**Results screen.** The plan puts "results via the Quit path" at point 10. From source, Quit shows `UnifiedRaceResults` only after a completed lap, and that path records a personal best and grants the reward. So point 10 is the exit confirmation, and the results screen is not captured by agents: use a gallery fixture, or Oscar's own finish.

**Short run** (plan 1.8, "four points plus the surface touched"): `01_start`, `02_on_foot`, `03_driving`, `06_full_map`.

## Buttons that share a name

Several surfaces name every button `Button` (race entry, confirmations). Find them by `Text`, then click by coordinates: `AbsolutePosition + AbsoluteSize / 2`. `layout_lint.lua` reports each ScreenGui's `absPos`, `ignoreGuiInset` and the gui inset so the offset can be checked once per session.

## ScreenGuis expected in PlayerGui

From source; DisplayOrder in brackets. The record lists whatever is really there.

- **Free roam:** `DesktopFreeRoamHud` (85), `ActivityHud` (84), `Onboarding` (990), `SharedTopNotification` (1100), `DrivingSpeedEffect` (-10, starts disabled), `FullMap` (90, starts disabled).
- **Loading:** `LoadingBackground` (1000), `LoadingSafeContent` (1001).
- **Racing:** `RaceBrowser` (170), `RaceEntryPresentation` (180), `RaceQueueBanner` (190), `SharedInRaceHUD` (155), `RaceCountdown` (205), `RaceTransitionFade_Phase8H` (210), `RaceRouteGuide_Phase5` (78), `UnifiedRaceResults` (220).
- **Garage:** `CanonicalGarageGui` (40), `OwnedGarageBrowser` (171), `OwnedGarageInteriorHUD` (58), `GarageEntranceStatus` (90), `DealershipIntroObjective` (18).
- **Transient:** `SharedConfirmationOverlay` (1250).
- **Touch only:** `MobileFreeRoamHud_Phase1` (88), `MobileDriveControls_Phase1` (96).
- **Dev, only if enabled:** `DriveToEarnCashTelemetry` (2000).

## Starting ignore list

Likely unstable between two identical runs, from source. Start with an empty `ARGS.ignore`, take runs `a` and `b`, and add only what `play_record_diff.py --detail` shows to differ. Digits in text are already normalised, so Cash, timers and speeds need no entry.

| Where | Instance names | Why |
|---|---|---|
| HUD minimap | `MapCanvas`, `PlayerMarker`, `NorthArrow` | Move and rotate with the player |
| HUD telemetry | `BoostFill`, `GaugeSegment*` | Sizes follow speed and boost |
| HUD car panel, race entry grid | `Vehicle_*` | Generated vehicle ids differ on every sandbox Play |
| Toasts | children of `SharedTopNotification.Stack` | Shown for 2.2 seconds |
| Full map | `PlayersHost`, `PlayerArrow`, `District`, `Hint` | Player positions and names |
| In-race | `PlayerMarker`, board rows | Positions and times |
| Race entry | `PersonalBest`, `YourRecord`, `WorldRecord`, `LeaderboardRows`, `DailyBonus` | Live records |
| Owned-garage browser | `Garage_*`, `Visit_*` | Property and player ids |
| Loading | `Status`, `ProgressFill` | Progress text and bar |
| Whole ScreenGui | `DriveToEarnCashTelemetry` | Dev telemetry text |

World position also matters: take each point at the same place (spawn point for 2 to 7) so the minimap and map content match.

## Unconfirmed from source

- Whether the sandbox profile owns a starter garage (`13b`, `13c`).
- Where the dealership teleport lands relative to the 5-stud desk radius (`11`).
- The exact world prompts for owned-garage entry (only the attribute `OwnedGarageEntryPrompt` is confirmed).
- Which other ScreenGuis are enabled at each point beyond those listed.
