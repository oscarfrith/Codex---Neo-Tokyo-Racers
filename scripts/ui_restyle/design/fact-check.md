# Fact check of recommended-plan.md

Date: 2026-10-09. Read-only. Live Studio "Space Racers v3 (placeId: 93959280828322)", Edit mode,
studio_id 1071f5cf-8bbe-4913-acf7-1c4c410323d9 (the id in the brief was stale; this one was confirmed with
list_roblox_studios). Nothing was changed in Studio or the repo. No Play session. No gameplay module was required.

Method: `script_read` on the named scripts, and read-only `execute_luau` that reads `.Source`, attributes and children.
One `loadstring` was used, on the entries table literal cut out of ClientBase (pure data), to count entries and
resolve paths. Line numbers are the ones `script_read` prints.

Verdicts: CONFIRMED, WRONG, PARTLY, UNVERIFIABLE.

## 1. The twelve listed claims

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | ClientBase 105-109 is the only code that turns an entry into a module; 46 entries; StartupState on 104 | CONFIRMED | L104 creates the folder. L105-109: `WaitForChild` walk of `entry.path` from `game`, then `require`. Two `require(` in the script: L3 (ClientLifecycle) and L108. Parsed table: 46 entries, no whitespace in names, every path resolves |
| 2 | ClientLifecycle (49 lines): L36 blocks on a dependency that is not ready; L29 skips disabled tool entries | CONFIRMED | L29 sets `skipped`. L36 sets `blocked` ("Dependency failed") for any status other than `ready`, so a skipped entry blocks its dependants. Also L30-33: dependants give up after 30 s ("Dependency timeout") |
| 3 | Config.UI: 0 attributes, 17 children, no Style or Pulse; no UIPulse; ReplicatedFirst holds only Loading; FeatureFlags only in ServerStorage | CONFIRMED | Config.UI: 0 attributes, 17 Folder children. Modules.Game has 10 folders, none UIPulse. ReplicatedFirst: Loading (3 ModuleScripts, 1 LocalScript). One instance named FeatureFlags in the place: ServerStorage.Modules.Core.FeatureFlags |
| 4 | Race menu and entry: `touch = touchDevice and not scaledDesktop`; IsEnabled true on touch unless Enabled is false; attribute true; save/restore branches unreachable | CONFIRMED | RaceBrowserClient L16, L26, L27; RaceEntryPresentationClient L17, L30, L31. Layout L15-17. `MobileScaledDesktop@Enabled = true` (boolean). `touch` is assigned once in each script, so L406-410 and L351-357 never run |
| 5 | GarageComponents 294-311 CanonicalHost; only callers GarageUI, GarageBrowserUI, GarageWorkspaceUI | CONFIRMED | L298-301 adopt or create the ScreenGui, DisplayOrder 40, Enabled true. L305 canvas 1600x900. L309 destroys other UIScales on the canvas. Callers: GarageUI L131 and L156, GarageBrowserUI L26, GarageWorkspaceUI L142. OwnedGarageWorkspaceUI reaches it only through `WorkspaceUI.new()` |
| 6 | OnboardingClient 666-671 applyLocks | CONFIRMED | L669 walks `playerGui:GetDescendants()` and sets Active, Selectable and AutoButtonColor on every GuiButton named Car, Race or Garage |
| 7 | FullMapUI 464-478 minimap check; L20 Open false when not started; HUDs use FindFirstChild("FullMapUI") | CONFIRMED | L464-478 as described; used by `toggle()` L541 (M key L676-677, ButtonSelect L721-723). L20 `api ~= nil and api.open() or false`. DesktopFreeRoamHudUI L960, MobileFreeRoamHudUI L260; both toast "MAP NOT AVAILABLE" on false |
| 8 | RouteGuide: route and progress private (36-38); only GetActive (89-91) reads state | CONFIRMED | L36 `local route`, L37 `routeVersion`, L38 `progress`. Public: Changed, Arrived, SetDestination, Clear, GetActive, Destinations, SetDestinationById, Update, newMapRenderer. None returns points or remaining distance |
| 9 | LoadingTransitionRuntime L8; InitialLoadingAndStartScreenClient L13, L15-18, L22, L26-46 | CONFIRMED | Runtime L8 requires LoadingScreenView at module load. Start script: L13 waits Config.UI.LoadingSystem; L15-18 early return; L22 RacingUIComponents; L26-36 save and set (TimeoutSeconds 86400 at L36); L40-46 restore |
| 10 | ProfileServer L183 and L252; both Studio flags false | CONFIRMED | Path ServerStorage.Modules.Game.Player.ProfileServer. L183 returns nil unless the attribute is `true`. L252 `noSave = not enabledAtLoad or studioVehicleSandboxConfig() ~= nil`. Both attributes are boolean false |
| 11 | OwnedGarageWorkspaceUI 189 lines, L12 requires, no Instance.new; OwnedGarageClient 8-10 | CONFIRMED | Every `require(` is on L12 (also PresentationAudioBridge). No `Instance.new`, no `ScreenGui`. It uses `Shared.ConfirmationModal`, `Shared.ProjectEconomy`, `UI.Asset`, `WorkspaceUI.new`. OwnedGarageClient L8 order list, L9 `controller.Start()`, L10 sets OwnedGarageClientStarted |
| 12 | Touch gates; both HUDs on touch plus keyboard; no PreferredInput | CONFIRMED | MobileDriveControlsClient L12, MobileFreeRoamHudUI L13. DesktopFreeRoamHudUI L16-19 returns only for touch without keyboard and without mouse, so touch plus keyboard or mouse starts both. `PreferredInput`: 0 of 221 scripts |

## 2. The four questions to confirm from live source

| Question | Verdict | Evidence |
|---|---|---|
| Can one path per entry be chosen in ClientBase? | CONFIRMED | `entries` is a local table of `{name, path, dependencies, tool?}` (L5-103) passed at L105. Swapping `path` strings between L104 and L105 changes what L107-108 requires. Names and dependencies must stay valid: `Lifecycle.validate` (L21) asserts duplicates, missing dependencies and cycles |
| Is a Config attribute readable from ReplicatedFirst before the loading screen draws? | PARTLY | Precedent in live code: InitialLoadingAndStartScreenClient reads `StartScreenEnabled` at L15 and other attributes at L26-36, before `Begin` (L38) and `RemoveDefaultLoadingScreen` (L53). It yields on `WaitForChild` first. That attributes arrive with the instance on a cold start cannot be shown in Edit |
| Which scripts require RacingUIComponents and GarageComponents? | CONFIRMED | 19 and 9. Lists below |
| Would a new ModuleScript under Modules.Game.UI be picked up without registration? | PARTLY | It replicates and can be required by path; no script enumerates the folder and there is no manifest. Nothing starts it: ClientBase L1 "No descendant auto-discovery", explicit list only. Creating a ModuleScript in v3 through the tools was not tested (read-only) |

RacingUIComponents (19): InitialLoadingAndStartScreenClient, ActivityClient, GarageUI, RaceBrowserClient,
RaceCountdownPresentationClient, RaceEntryPresentationClient, RaceQueueClient, RaceSessionPresentationClient,
RaceTimeTrialResultCoachClient, DesktopFreeRoamHudUI, FullMapUI, GarageBrowserUI, GarageComponents,
GarageInteriorModeUI, GarageWorkspaceUI, MobileFreeRoamHudUI, OnboardingClient, OwnedGarageBrowserUI,
OwnedGarageWorkspaceUI.

GarageComponents (9): GarageUI, RaceEntryPresentationClient, DesktopFreeRoamHudUI, GarageBrowserUI,
GarageInteriorModeUI, GarageWorkspaceUI, MobileFreeRoamHudUI, OwnedGarageBrowserUI, OwnedGarageWorkspaceUI.

ClientBase dependency edges (from the parsed table): ActivityClient -> SharedTopNotificationUI;
DealershipIntroClient -> GarageUI; GarageEntranceClient -> LoadingTransitionUI, GarageUI;
GaragePreviewPresentationClient -> LightingClient; RaceEntryPresentationClient -> LoadingTransitionUI;
OwnedGarageClient -> LoadingTransitionUI; OwnedGarageEnvironmentLightingClient -> LightingClient;
GarageUI -> DriveSessionClient, LoadingTransitionUI, SharedTopNotificationUI; LightingPreviewClient -> LightingClient.
Tool entries: the three Trailer clients and LightingPreviewClient; all four ClientTools flags are false.

## 3. Other statements in the plan that were checked

| Plan statement | Verdict | Evidence |
|---|---|---|
| 221 scripts in the place (1.8) | CONFIRMED | ReplicatedStorage 140, ServerStorage 73, ReplicatedFirst 4, Workspace 2, ServerBase 1, ClientBase 1 |
| "The other module of a pair is never required" (1.5 rule 2) | CONFIRMED | No script outside ClientBase requires a Classic owner, except inside the garage family: GarageUI L13, OwnedGarageClient L8-9, GarageInteriorModeUI L52, GarageInteriorTransitionUI L6, and the two HUDs' FullMapUI lookup |
| ClientLifecycle requires one module per entry at 38-44 | CONFIRMED | L40 `resolve(entry)`, L42 `feature.start()` |
| RouteGuide holds 4 instances per segment; chip takes an Enum.Font (section 0) | CONFIRMED | `_segment` L259-282: two Frames and two UICorners. L234 `chip.Font = options.Font or Enum.Font.Michroma` |
| RaceTransitionClient label at 57-72 is a font literal (1.6) | CONFIRMED | L57-72; L68 GothamBold, L70 Michroma FontFace. The script has no `require(` today |
| Four scripts read MobileMajorMenuOpen (2.3) | CONFIRMED | Writer MobileFreeRoamHudUI. Readers MobileDriveControlsClient, OnboardingClient, GarageInteriorModeUI, FullMapUI (L450) |
| Foundation confirmation: overlay name, DisplayOrder 1250, priority 10000 (2.2) | CONFIRMED | ResponsiveUIFoundation L326-332 and L426 (Escape and ButtonB) |
| ProjectEconomy and BindReplicatedCash live in ResponsiveUIFoundation (2.1) | CONFIRMED | L222 and L253; re-exported by RacingUIComponents L181 and GarageComponents L45 |
| FreeRoamVehicleExitButtonClient is already a no-op (1.7) | CONFIRMED | L8-9: comment and `return` |
| SetCoreGuiEnabled has one caller (7.1) | CONFIRMED | TrailerModeClient only |
| TimeTrialServer 1298 and 1311 set Default (7.2) | CONFIRMED | Both lines set `Enum.ProximityPromptStyle.Default` |
| The guide trail renderer takes its config as an argument (appendix A) | CONFIRMED | OnboardingClient L28 `GuideTrail.new(config)` |
| The full map binds ButtonSelect (7.1) | CONFIRMED | FullMapUI L721-723, priority High |
| Kill switch delay "about a minute" (1.4) | CONFIRMED | FeatureFlags `REFRESH_SECONDS = 60` |
| Five activity view scripts | CONFIRMED | ActivityClient L292 loads four `*ClientView` modules; Courier and Taxi views require JobClient |
| Installer engine ops and place assert (10) | CONFIRMED | scripts/lighting_realism/step2/install.lua: kinds source, tree, attribute, property, create; placeId 93959280828322 and Edit asserted. scripts/studio_capture.py L11 lists three place ids, not v3 |
| Touch camera guard, GarageInteriorModeUI 48-270, "moved unchanged" (1.7) | WRONG | L52, inside that range, requires Classic `OwnedGarageWorkspaceUI` by path |
| "Game testing uses the existing Studio no-save sandbox" (section 0) | PARTLY | The sandbox exists but is off in v3 (attribute false). Section 10 says so; section 0 and the Phase 0 row do not |

## 4. Errors and gaps in the plan

1. **Touch camera guard cannot be moved unchanged.** GarageInteriorModeUI L52 requires Classic OwnedGarageWorkspaceUI.
   An unchanged copy would ask a module that was never started (`IsCameraTouchBlocked` returns false) and would fail
   the plan's own lint (1.5 rule 7). L52 has to be a listed replaced span.
2. **The fallback is not all-or-nothing from Phase 8.** If `Compose` fails, ClientBase keeps the Classic list, but
   LoadingTransitionRuntime, InitialLoadingAndStartScreenClient and RaceTransitionClient read the latch themselves
   and stay Pulse. "Nothing has started at that point" is then false. The fallback must downgrade the latch, or go.
3. **`Lifecycle.validate` is outside the protected block.** ClientLifecycle L21 (asserts at L5-8) runs inside
   `lifecycle.start`. A composed list with a duplicate name or a missing dependency throws there and no client entry
   starts. Validate the composed list inside the protected call before swapping.
4. **Phase 3 breaks lint rule 7.** The gate needs the Classic map to open by click. The only click route is to
   require `Modules.Game.UI.FullMapUI` and call `Open()` (as the Classic HUDs do at L960 and L260). That is a Pulse
   module requiring a Classic owner. The HUD should resolve the map module through `Routes`.
5. **Lanes.** docs/13 L28 lists "uncertain or multiple runtime owners" as High-Risk. Phases 2 to 6 each install a
   second owner for a surface and are labelled Standard; Phases 2, 4 and 6 list no delivery-reviewer although they
   call teleport, prompt and queue remotes.
6. **Phase 0 is not read-only.** Its Play sessions need either the sandbox window (an Edit write to
   `Config.Player.Onboarding`, needing Oscar's yes) or Oscar's real profile. The row says "Nothing installed" and
   lane Fast.
7. **Dependency timeout.** ClientLifecycle L30-36 blocks dependants after 30 s. The Pulse toast owner and garage
   owner are dependencies of ActivityClient, DealershipIntroClient and GarageEntranceClient. "Preloaded by the first
   Pulse owner" must be stated as non-blocking in `start()`.
8. **Classic onboarding scale on Pulse screens.** OnboardingClient L235-244 takes its scale from the first UIScale
   above the target. Pulse screens have none, so from Phase 2 to Phase 7 callouts use the default or the 0.6 phone
   value. The gates only check that targets are found.
9. **Edit tests through `loadstring`.** Section 9 runs agents' tests in Edit through `loadstring`. AGENTS.md forbids
   requiring gameplay modules through MCP and separate module caches. The plan should limit this to pure model
   and kit code and say so.
10. **Edit count.** "Five edited, 216 byte-identical" becomes six and 215 if the kill switch is taken (ServerBase).

## 5. Not verifiable in Edit

- Attribute arrival at ReplicatedFirst time on a cold start (the plan marks it as a spike).
- Whether ClientBase can run before ReplicatedStorage has fully arrived. Note ClientBase L3 and L4 already index
  `.Core.ClientLifecycle` and `.ClientTools` without waiting, and work today.
- Creating a ModuleScript in v3 through the tools, save and reopen.
- All instance counts, frame costs and rendering claims (TextSize 100, UIShadow, hairlines, PreferredInput values).
- Oscar's viewport of 2065.33 x 1152.
