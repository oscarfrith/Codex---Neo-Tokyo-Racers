# Loading And Start Screen System

**Status:** COMPLETE - Phases 1-6 confirmed, mirrored and handed off  
**Canonical installer:** `scripts/roblox_ui_loading_and_start_screen_system.lua`  
**Config-only companion:** `scripts/roblox_ui_loading_start_screen_config.lua`  
**Current target revision:** `NTR_LOADING_SYSTEM_PHASE5_START_BUTTON_POSITION_V1_3`

The user confirmed the start flow, compact buttons, Grid3x2 repair, configured Phase 5 V1.3 placement and Phase 6 closure behaviour. The refreshed `2026-07-21 10:48:31` mirror captures the confirmed V1.4 view, V1.3 start client, responsive config and every transition/readiness marker. The system is handed off with no active implementation phase.

## Acceptance Contract

- **Lane:** High-Risk integration. The feature is client presentation, but it crosses global UI visibility, driving input, audio mixing and future race/session transitions.
- **Goal:** One reusable loading presentation for major location/session handoffs plus the initial Play/Shop start screen.
- **Current confirmed baseline:** Phases 1-6, `NTR_RACING_STAGING_READINESS_GATE_V1`, configured start-client V1.3 and loading-view V1.4 are user-confirmed in the refreshed `2026-07-21 10:48:31` mirror. Preserve all current owners and use the read-only Phase 6 audit for future regression checks.
- **State owner:** `ReplicatedFirst.NTRLoading.LoadingTransitionRuntime`.
- **Geometry owner:** `ReplicatedFirst.NTRLoading.LoadingScreenView`.
- **Artwork owner:** versioned `LoadingSystem.Artworks` catalogue consumed by `LoadingArtworkCatalog`.
- **UI suppression contract:** retained `LoadingPresentationState`/`LoadingPresentationChanged`, with the current free-roam vertical slice reusing `FreeRoamHudPresentationMode`.
- **Input owner:** `GameplayInputGate`; the driving controller only reads its locked state and returns neutral intent.
- **Audio owner:** `AudioMixController`; future audio producers assign sounds to the installed category groups rather than writing group volume.
- **Physical movement and teleport authority:** unchanged existing driving and server teleport owners.
- **Persistence/economy:** no schema, profile, cash, inventory or saved-data change.

## Approved Experience Contract

- The loading screen appears immediately after the player confirms a covered action.
- The loading cover remains fully present for at least `1.5` seconds before fade-out begins.
- Other applicable NTR UI is suppressed while loading.
- Destination UI is restored behind the loading screen at fade start.
- The loading overlay remains modal until its `0.3` second fade completes.
- Runtime loading images use a five-second `Sine Out` pan/zoom so motion is visible during a typical 1.5-second transition; the later start screen remains static.
- Driving input becomes neutral without anchoring, braking, zeroing velocity or changing hover/physics.
- Held controls must return to neutral before input is restored, with a bounded safety timeout.
- Loading music begins only if the screen remains active past `0.9` seconds. Missing music is silent and non-blocking.
- The music threshold measures genuine unfinished transition time, not an artificial minimum-visibility hold.
- The bar uses the existing `PanelSoft`, `ElectricBlue`, `Telemetry` and `Text` semantic colours.
- Progress is frame-smooth and monotonic: it reaches about `85%` during the first 80% of the minimum, approaches `94-98%` while genuinely waiting and reserves `100%` for confirmed completion.

## Explicit Exclusions

- Race or time-trial reset.
- Free-roam vehicle spawn, switch or replacement.
- Ordinary page/category navigation, purchases, upgrades and colour changes.
- Race results that do not relocate the player.
- TeleportGui activation for cross-place teleports; Phase 5 keeps the view/catalogue compatible but does not introduce a teleport owner.

## Phase 1 Scope

Phase 1 installs the complete reusable foundation and connects only the existing free-roam HUD dealership teleport on desktop and touch.

It creates:

```text
ReplicatedFirst.NTRLoading
  LoadingArtworkCatalog
  LoadingScreenView
  LoadingTransitionRuntime

ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client
  Input.GameplayInputGate
  Audio.AudioMixController

StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI
  LoadingTransitionInvoke
  LoadingPresentationState
  LoadingPresentationChanged
  LoadingTransitionController_Active

SoundService
  NTR_LoadingMusic
  NTR_GameplayMusic
  NTR_Vehicle
  NTR_Ambience
  NTR_GameplaySFX
  NTR_UI
```

The installer adds guarded bridges to:

- `DrivingControllerV47` for neutral input, boost/drift cancellation and reset suppression while locked;
- `DesktopFreeRoamHudController_Active` for dealership teleport begin/complete/fail;
- `MobileFreeRoamHudController_Active` for the same touch path.

The server teleport service is not patched. It remains responsible for cooldown, race/garage guards, unseating, character placement, vehicle despawn and failure responses.

## Phase 2 Scope

Phase 2 keeps the Phase 1 owners and extends the same request boundary to:

- dealership entry from the canonical entrance prompt;
- on-foot customisation entry from the canonical entrance prompt;
- drive-in customisation entry after its existing eligibility/countdown gate;
- Exit from the dealership/customisation browser back to the physical entrance;
- Drive from dealership/customisation into free roam after existing core-module readiness checks.

`GarageEntranceController_Active` begins the cover before `GarageSessionRequest.Begin`. It forwards the generation through the existing open event, and `ModuleShopUIController` completes only after profile refresh, camera setup and destination rendering. Existing legacy open events without a generation use the same module-side fallback wrapper.

`ModuleShopUIController` remains the only garage UI/vehicle-exit owner. Foot Exit completes after the server session ends and the camera/UI state is restored. Drive returns the hidden character to the saved entrance before requesting the existing exit-marker vehicle spawn, then completes only after spawn success and `FreeRoamVehicleSpawned`. A session-end rejection retains the garage view; a later spawn rejection safely restores on-foot free roam at the entrance rather than exposing the hidden hold position. Phase 2 adds no remote, saved state, vehicle constructor, camera owner or duplicated UI.

### Phase 2 verification

- Enter Dealership, Customisation and Drive-In Customisation; each cover must appear before the session request and reveal the correct destination beneath the fade.
- Use browser Exit in both dealership and customisation modes; confirm return-to-entry placement, camera, free-roam HUD, input and audio recover.
- Use Drive after a valid build; confirm the cover remains until the vehicle exists, the driving HUD is ready and controls recover after neutral input.
- Reject Drive with a missing core module; no loading screen should appear because the readiness check happens first.
- Exercise server/session failure paths; the cover must say `RETURNING`, fade safely and leave either the retained garage view or on-foot entrance fallback without duplicate requests or vehicles.
- Repeat on desktop and touch, including held throttle/boost/drift during drive-in and drive-out.

### Phase 2 readiness scorecard

| Concern | Status | Evidence / remaining gate |
|---|---|---|
| Ownership | PASS | Existing entrance, garage UI, camera, vehicle, loading, input and audio owners are reused. |
| Server authority | PASS | Existing session and vehicle remotes remain authoritative; no new remote or trusted client result is added. |
| Persistence/economy | N/A | Phase 2 performs no new saved-data, purchase, reward or currency operation. |
| Lifecycle/failure handling | DEFERRED | Static generation/failure/timeout cleanup is present; Studio rejection and repetition evidence is required. |
| Performance | DEFERRED | No new loop or artwork allocation is added; low-end device transition checks remain required. |
| Mobile/input | DEFERRED | Shared `Activated`/prompt and input-gate paths are retained; touch/held-input Play checks remain required. |
| Streaming | N/A | The existing local dealership triggers and authoritative session checks are unchanged. |
| Observability/rollback | PASS | One revision, exact markers, projected/final compile audit, transactional command rollback and place-history rollback are documented. |

## Phase 3 Scope

Phase 3 reuses `OwnedGarageBrowserController` as the owned-garage client transition owner and `OwnedGarageManagementRuntime` as the authoritative session, persistence, teleport, display-assignment, compensation and vehicle-lifecycle owner.

It covers:

- entering a selected owned garage on foot or in the currently driven vehicle;
- the full-garage replacement-space confirmation path;
- returning to the city through the browser while already inside;
- the physical `FootExitPrompt` inside the garage;
- physical `DriveOutPrompt` activation for a displayed vehicle.

The browser begins loading immediately before its existing remote request. Successful entry closes the browser and reveals the interior beneath the fade; rejection restores the browser. A full-garage response finishes the first cover before showing the replacement choice, then the selected replacement starts a fresh generation.

Physical prompt covers begin from the local `ProximityPromptService.PromptTriggered` signal while the server retains the only trusted prompt validation and transition execution. The existing `DriveOutResult` push completes or fails drive-out. Phase 3 adds a result message for the existing physical foot-exit server callback so rejection can release immediately instead of waiting for the global timeout. Attribute loss of `NTR_OwnedGarageInside` remains a success fallback if a result push arrives late.

Phase 3 adds no remote, saved field, display mutation, vehicle spawn/despawn implementation, interior geometry, management UI or visitor behaviour.

### Phase 3 verification

- Enter the selected property on foot; confirm the browser closes only after success and the interior HUD is visible beneath the fade.
- Enter while driving below the configured speed. Confirm the live vehicle is removed once, its stable `VehicleId` is assigned once, and the correct display model/interior appears beneath the fade.
- Fill all display spaces, choose a replacement, and confirm the first cover returns to the replacement prompt before the second covers the committed transition.
- Use browser `RETURN TO CITY` and physical `FootExitPrompt`; confirm both arrive at the property foot-exit marker with free-roam HUD/input/audio restored.
- Use a displayed vehicle's physical `DriveOutPrompt`; confirm one saved clear, one vehicle spawn at the property vehicle-exit marker, seating/driving readiness and no duplicate display/live vehicle.
- Exercise empty-slot, cooldown, excessive-speed, missing-marker and lifecycle rejection paths where practical. The cover must return to the browser/interior, prompts must re-enable and saved assignments must remain or compensate correctly.
- Repeat all applicable paths on desktop and touch, including held throttle/boost/drift during vehicle entry/exit.

### Phase 3 readiness scorecard

| Concern | Status | Evidence / remaining gate |
|---|---|---|
| Ownership | PASS | Existing browser and management/lifecycle owners are reused; loading adds presentation only. |
| Server authority | PASS | Server prompt validation, teleport, assignments, compensation and vehicle construction remain unchanged and authoritative. |
| Persistence/economy | PASS | No schema/economy change; existing revisioned assignment/clear and compensation contracts are called unchanged. |
| Lifecycle/failure handling | DEFERRED | Static success/failure/result/attribute fallback paths are present; Studio compensation and repetition evidence is required. |
| Performance | PASS | One event-driven prompt listener and existing pushes are used; no polling, render loop or extra artwork allocation is added. |
| Mobile/input | DEFERRED | Shared prompts/buttons and input gate are reused; touch and held-input Play evidence is required. |
| Streaming | PASS | Property-owned exterior markers and server-created interiors remain authoritative; no client CFrame is introduced. |
| Observability/rollback | PASS | Physical foot exit gains a result push on the existing event; exact-marker compile audit, transaction rollback and place-history rollback remain. |

## Phase 4 Scope

Phase 4 reuses `RaceTransitionClient_Active` as the existing race camera/session-transition owner and delegates only the approved full-screen handoffs to the shared loading runtime. It covers:

- Race Browser teleport to the selected event's physical start;
- selected time-trial start, beginning immediately before its existing vehicle/session preparation;
- multiplayer Race staging after queue waiting ends and the authoritative `RaceStaged` event arrives;
- confirmed Exit from an active Race or Time Trial while driving;
- finished Race/Time Trial results `EXIT TO START`.

Queue waiting stays visible and interactive rather than becoming a potentially long loading screen. `JOIN RACE` therefore does not cover the queue; the cover begins only when matchmaking has committed to staging. Reset keeps the existing short black camera-cover fade and never calls the loading runtime. `TRY AGAIN`, `RACE AGAIN`, ordinary vehicle spawn/switch and results that do not relocate the player remain excluded.

The existing `RaceTransitionRequest` remains the local transition seam. Race Browser already publishes teleport fade requests; Phase 4 maps those covered requests to loading generations. `RaceEntryMenuClient_Active` explicitly begins/fails immediate time-trial loading, `RaceSessionPresentationController_Active` reports authoritative active-exit success, and `RaceTimeTrialResultCoachClient_Active` wraps results exit. `RaceStaged`, `RaceStarted`, exit and error events provide event-driven completion/failure fallbacks.

Phase 4 adds no remote, saved field, queue rule, staging implementation, checkpoint/timing logic, result/reward calculation, vehicle builder, reset implementation or new presentation owner.

The first Phase 4 command reached final source compilation but Studio dropped the unrelated loading config revision attribute, reproducing the documented mixed source/attribute transaction fault for a second phase. V1.1 therefore uses the project-standard source-only recovery: the installed Phase 1-3 loading modules, bridge, critical timing attributes and Grid3x2 artwork are verified read-only; only the four existing Racing sources are assigned; there is no yield, hierarchy creation, property change or attribute write. The four Phase 4 source markers are the current revision evidence.

### Phase 4 verification

- From Race Browser, use `TELEPORT`; confirm the cover appears before the existing server teleport and reveals the physical start/menu beneath the fade. Reject the teleport where practical and confirm the Browser returns.
- Start a Time Trial with a selected vehicle; confirm the cover begins from the button action, remains through staging and reveals the countdown/session only after authoritative readiness.
- Join a multiplayer Race queue; confirm the queue banner remains visible with no loading cover while waiting. Confirm loading begins at staging and finishes at `RaceStarted` before controls release.
- While actively driving in a Race and Time Trial, confirm Exit, approve the modal and verify the cover stays until authoritative exit-to-start succeeds. A rejection must restore the active HUD/modal path without unlocking a stale request.
- From finished Race and Time Trial results, use `EXIT TO START`; confirm results remain logically owned until server cleanup succeeds, then free-roam/start presentation appears beneath the fade.
- Press RESET during Race and Time Trial; confirm only the existing short black reset fade appears, never the loading image/bar. Confirm lap-time/reset ownership remains unchanged.
- Use `TRY AGAIN` and `RACE AGAIN`; confirm they remain uncovered in this phase and still follow their existing lifecycle.
- Repeat applicable paths on desktop and touch, including held throttle/boost/drift through staging/exit and a queue rejection/leave.

### Phase 4 readiness scorecard

| Concern | Status | Evidence / remaining gate |
|---|---|---|
| Ownership | PASS | Existing race camera/session transition, entry, in-session and result owners are reused; no fifth presentation owner is added. |
| Server authority | PASS | Existing remotes/events remain authoritative for teleport, queue, staging, reset, timing, results and cleanup. |
| Persistence/economy | N/A | Phase 4 changes no saved data, PB, reward or currency operation. |
| Lifecycle/failure handling | DEFERRED | Static success/error/timeout and event/remote ordering fallbacks are present; desktop/touch and multiplayer Studio evidence is required. |
| Performance | PASS | Existing event signals and one retained loading generation are used; no polling, extra artwork allocation or race render-step work is added. |
| Mobile/input | DEFERRED | Existing scaled UI/buttons and shared input gate are reused; touch, held-input and countdown-release Play evidence is required. |
| Streaming | PASS | Browser teleport and race staging keep their existing server placement and `RequestStreamAroundAsync` owners. |
| Observability/rollback | PASS | Four source revision markers, exact-anchor projected/final compilation, source-only transaction rollback and Phase 3/place-history rollback are documented. |

## Phase 5 Scope

Phase 5 reuses the existing `ReplicatedFirst.NTRLoading` package and loading singleton unchanged. It creates one isolated `InitialLoadingAndStartScreenClient`; no bootstrap hook, module rewrite or central-config mutation is needed. Initial loading waits boundedly for the Roblox load state, the NTR world and the local character root, while reporting progress through the confirmed smooth bar.

Before beginning, the client temporarily raises `TimeoutSeconds` only in its local replicated config copy; the runtime captures that start-generation deadline and the client immediately restores the attribute. This holds the screen without modifying the canonical runtime or Studio config. Motion remains disabled because the generation is marked `StartScreen=true`. At completion, a cloned overlay fill reaches 100% independently of the runtime's still-active smooth progress loop, then the status/bar are hidden and replaced only by shared `RacingUIComponents.Button` actions inside the existing safe-area root:

- **PLAY:** releases the same input/audio/UI generation and fades into free roam over the configured `0.3` seconds.
- **SHOP:** invokes the existing server-authoritative `TeleportToDealership` action while the cover remains present, then fades after success. A rejection displays the reason and re-enables both actions.

V1.1 removes the title and description entirely so branding comes from the artwork. Wide screens use a slightly lower horizontal row. Touch devices whose short viewport side is at most `700` are phones: landscape uses two `188x40` buttons horizontally and portrait uses two `190x40` buttons vertically. Other portrait/narrow layouts use `240x48`; wide layouts use `270x52`. This fixes the former width-only classification that sent landscape phones into `294x58` desktop buttons.

Each button contains a left icon and label as one centred group. The optional String attributes `StartScreenPlayIconAssetId` and `StartScreenShopIconAssetId` live on `ReplicatedStorage.NeoTokyoRacers.Config.UI.LoadingSystem`; numeric IDs or `rbxassetid://` values are accepted. Blank or absent values hide the icon and leave the text centred. To avoid the confirmed Studio mixed source/attribute persistence fault, the V1.1 installer reads these keys but does not write placeholder attributes in the source transaction.

The client temporarily disables non-`StartScreenEligible` entries only in its local replicated catalogue before asking the unchanged runtime to choose destination `StartScreen`, then immediately restores them. This preserves the approved future multi-artwork weighted catalogue without a catalogue-module rewrite. The current single Grid3x2 entry is already eligible; later entries can opt in independently.

To mitigate Studio's recurring mixed source/hierarchy fault—and the documented failure of delayed in-command audits across a `task.wait()` history boundary—the canonical installer remains no-yield and source-only. V1.3 accepts only exact V1.3/V1.4 view markers plus known V1/V1.1/V1.2 start-client markers, compiles the complete replacements before mutation, changes no config/hierarchy owner, audits immediately and restores original source on failure. Against the confirmed live baseline it preserves the V1.4 view and upgrades only the isolated initial/start client.

### Configured button-position V1.3

This isolated Fast Lane refinement keeps the confirmed responsive button sizes and orientations. It replaces four unrelated hard-coded Y positions with three editable values: desktop `0.82`, landscape phone `0.84`, and shared portrait `0.80`. Higher values move the buttons down. All branches reuse one position helper that reads the applicable attribute live and caps the menu centre against its current safe-root height, complete menu height and an eight-pixel bottom inset. This keeps phone and tablet scaling consistent without allowing an aggressive tune to enter curved/home-indicator areas.

### Grid3x2 V1.2 repair

The refreshed mirror proves the catalogue has six complete IDs, but V1.3 of the view performs one preload while the grid is hidden and immediately gates promotion on all six `ImageLabel.IsLoaded` values. That state is not retried or diagnosed. V1.2 keeps the required single fallback, records `PreloadAsync` callback fetch status for each tile, retries at most `GridPreloadAttempts`, and reports exact tile/status/ID failures. Once all fetches succeed, it makes the grid visible behind the higher-Z fallback and waits up to `GridPromotionWaitSeconds` for all six render labels before hiding the fallback.

The icon and grid timing keys are created first by a config-only companion transaction. This is intentionally separate from the view source transaction because the project has twice reproduced Studio dropping mixed source/config changes. Defaults are `GridPreloadAttempts=2`, `GridPreloadRetrySeconds=0.25`, `GridPromotionWaitSeconds=3`, and blank Play/Shop icon strings. Existing values are never overwritten.

### Phase 5 verification

- Join a fresh Play session. Confirm the custom cover is visible before Roblox's default loading screen is removed, the bar fills smoothly, and no world/HUD flashes above it.
- Confirm completed loading reveals static artwork plus only PLAY/SHOP; the generated title and description are absent and no start-screen pan or zoom occurs.
- Leave the screen open for at least 20 seconds. Confirm it does not time out, fade, unlock input or duplicate loading UI.
- Press PLAY. Confirm destination UI is restored beneath the fade, gameplay audio returns smoothly, and on-foot/driving input is usable only after release.
- Rejoin and press SHOP. Confirm the cover stays present through authoritative placement and fades at the dealership exterior. Force a teleport rejection where practical and confirm the error is readable and both buttons become usable again.
- Repeat on desktop, tablet, portrait phone and landscape phone. Confirm full-bleed artwork/black backing covers curved areas, buttons remain inside safe insets, landscape phone actions stay horizontal and compact, and portrait phone actions stay vertical and compact.
- After PLAY and SHOP, exercise dealership/customisation/owned-garage/race transitions and one readiness-gated Time Trial. Confirm exactly one loading singleton and the complete five-second countdown.
- Set `MODE="AUDIT"` and rerun after installation. Require Phase 5 initial-controller, catalogue and runtime markers with no mutation.

### Phase 5 readiness scorecard

| Concern | Status | Evidence / remaining gate |
|---|---|---|
| Ownership | PASS | Existing view/catalogue/runtime/input/audio owners are reused; one isolated initial lifecycle client is added. |
| Server authority | PASS | SHOP calls the existing validated dealership teleport; PLAY is local presentation release only. |
| Persistence/economy | N/A | No saved field, inventory, reward, cash or purchase operation changes. |
| Lifecycle/failure handling | DEFERRED | Locally extended captured timeout, bounded readiness, retryable SHOP and safe fallback are projected; Studio repetition proof is required. |
| Performance | DEFERRED | One startup polling loop is bounded and ends before actions appear; existing artwork warm/grid costs require low-end device proof. |
| Mobile/input | DEFERRED | Shared `Activated` buttons and safe-area responsive layout are present; touch/portrait/held-input proof is required. |
| Streaming | PASS | Initial readiness observes world/character only; SHOP placement remains server-owned. |
| Observability/rollback | PASS | Bounded-readiness warning, exact markers, staged installer audit and scoped rollback are included. |

## Artwork Catalogue

Phase 1 V1.2 supports `Single` and `Grid3x2` through the same catalogue, geometry owner and transition runtime. The six-tile composition works around the lower effective resolution currently delivered to `ImageLabel` while preserving the confirmed single image as an automatic fallback.

Default entry:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.LoadingSystem.Artworks.NeoTokyoStreet01
```

Editable attributes:

- `ImageAssetId`: uploaded image ID; blank safely renders the black backing.
- `Enabled`: catalogue eligibility.
- `Weight`: future weighted shuffle-bag selection.
- `Destinations`: comma-separated destination IDs or `*`.
- `FocalPointX` / `FocalPointY`: crop pivot from `0` to `1`.
- `MotionPreset`: `SlowPanRight`, `SlowPanLeft`, `SlowPanUp`, `SlowPanDown`, `SlowZoom` or `None`.
- `Layout`: `Grid3x2` for the default entry; `Single` remains supported.
- `Columns` / `Rows`: fixed to `3` / `2` for this version.
- `AspectRatio`: logical composite aspect ratio; default `16/9`.
- `CompositeResolution`: authoring note, default `3072x1728`.
- `StartScreenEligible`: future Phase 5 eligibility.

`NeoTokyoStreet01.Tiles` contains six coordinate-owned folders in row-major order:

```text
R1C1  R1C2  R1C3
R2C1  R2C2  R2C3
```

Each tile folder has `Row`, `Column` and editable `ImageAssetId` attributes. The renderer promotes the grid only after all six IDs report successful fetch status and all six visible-behind-fallback `ImageLabel`s report loaded. Until then, the existing `NeoTokyoStreet01.ImageAssetId` single image remains visible. A missing or moderated tile therefore cannot expose a partial grid.

### Grid3x2 artwork export

1. Prepare the final master at exactly `3072 x 1728` (`16:9`).
2. Export six crops at exactly `1024 x 864` using the row-major map above. Do not resize each crop independently after splitting.
3. Keep colour profile, export quality and sharpening identical for all six files.
4. Avoid adding borders, padding or transparent margins. If the editor supports guides, place vertical cuts at `x=1024` and `x=2048`, and the horizontal cut at `y=864`.
5. Upload all six as image assets and assign their IDs to the matching tile folders. The existing single image remains the fallback and should not be removed.

The common `ArtworkMotion` parent owns crop, focal alignment, pan/zoom and fade. Tiles never animate independently. `GridOverlapPixels=1` hides subpixel sampling cracks; set it to `0` only if a visible doubled seam appears in the supplied artwork.

## Configuration

`ReplicatedStorage.NeoTokyoRacers.Config.UI.LoadingSystem` uses editable attributes. Important defaults:

```text
FadeOutSeconds = 0.3
MinimumVisibleSeconds = 1.5
CompletionFillSeconds = 0.2
ReadyHoldSeconds = 0.06
TimeoutSeconds = 12
MotionDurationSeconds = 5
MotionStartScale = 1.06
MotionEndScale = 1.10
MotionTravelPercent = 0.012
LoadingMusicStartDelaySeconds = 0.9
LoadingMusicFadeInSeconds = 0.5
GameplayAudioDuckSeconds = 0.25
WarmPoolSize = 1
GridOverlapPixels = 1
StartScreenButtonYScaleDesktop = 0.82
StartScreenButtonYScaleLandscapePhone = 0.84
StartScreenButtonYScalePortrait = 0.80
```

`LoadingMusicAssetId` defaults blank. Do not treat silence as an installation failure. Higher start-button Y-scale values move the appropriate layout down. The client clamps the complete menu inside the safe-content root, so an aggressive value cannot place the buttons below the device-safe area.

## Canonical Installation

1. Run complete `scripts/roblox_ui_loading_start_screen_config.lua` in the Studio Command Bar in Edit mode and require its PASS.
2. Run complete `scripts/roblox_ui_loading_and_start_screen_system.lua` and require the Phase 4 preservation message plus final `NTR_LOADING_SYSTEM_PHASE5_START_BUTTON_POSITION_V1_3` PASS.
3. Set all six `NeoTokyoStreet01.Tiles.R1C1` through `R2C3` `ImageAssetId` attributes. Numeric IDs and `rbxassetid://` values are both accepted.
4. Keep `NeoTokyoStreet01.ImageAssetId`; it is the safe single-image fallback.
5. Optionally set `LoadingSystem.LoadingMusicAssetId`.
6. Stop and refresh the mirror if a confirmed marker is missing. Do not broaden an anchor or create a repair script.

## Foundation Regression Verification

### Static/Edit

- Installer prints PASS with no rollback.
- All six foundation markers, the three Phase 1 integrations, both Phase 2 integrations, both Phase 3 integrations and four Phase 4 integrations exist exactly once in their target sources.
- The four Phase 4 Racing source markers are present exactly once. Phase 4 does not rewrite or require a new loading config revision attribute; the existing Phase 1-3 config is validated read-only.
- Exactly one active loading LocalScript and one request BindableFunction exist.
- Default artwork layout is `Grid3x2`, with exactly six coordinate-valid tile folders.

### Desktop Play

1. Confirm `[NTR Loading System Phase 1] Runtime controller ready.`
2. Test SHOP -> TELEPORT TO DEALERSHIP while on foot.
3. Confirm the cover appears before relocation, free-roam UI hides, progress advances and the destination HUD appears beneath the `0.3` second fade.
4. Confirm a fast teleport remains fully covered for at least `1.5` seconds before fade start; the bar must advance smoothly, never regress or jump immediately to `100%`, and must complete before the fade.
5. Confirm all six tiles appear as one continuous 16:9 image: no gap, doubled seam, stretching, independently moving tile or partial reveal.
6. Confirm the complete image begins moving immediately, pans right subtly and zooms from `1.06` toward `1.10`; no tile may move independently and the crop must not expose black edges.
7. Clear one tile ID temporarily and confirm the complete single-image fallback appears instead of five tiles; then restore the ID.
8. Repeat while seated and accelerating, steering, drifting and boosting. The vehicle must not be artificially braked/anchored by the client; input and boost/drift intent must become neutral.
9. Hold an input through fade completion. Input must remain locked until neutral, then recover.
10. Trigger cooldown rejection. The previous UI must return and input/audio locks must release.

### Touch Play

- Repeat the same confirmation from the mobile SHOP button.
- Confirm pedal, steering, drift and boost state do not remain latched.
- Confirm safe content is unobscured at phone/tablet cutouts and the artwork remains full bleed.
- Confirm the 16:9 composite crops rather than stretches on portrait devices and the focal subject remains acceptable.

### Repetition

- Perform at least ten successful/rejected transitions.
- Confirm only one `NTR_LoadingBackground`, one `NTR_LoadingSafeContent` and one runtime loading Sound exist.
- Confirm no stuck `LoadingTransition` presentation owner, input token, audio duck or disabled HUD remains.

## Failure And Rollback

- Config failure removes only attributes added by that config-only command. V1.3 source failure restores the exact pre-command start-client source and, only if an older V1.3 grid view required upgrade, its pre-command view source. Catalogue/runtime/config and Phase 4 sources are read-only. No backup Instances are created.
- Runtime timeout returns to the previous valid UI and ignores later stale generation completions.
- Missing or moderated artwork falls back to black.
- An incomplete or failed Grid3x2 set falls back atomically to the entry's single image.
- Missing loading music stays silent.
- For a position regression discovered after a successful V1.3 command, restore only `InitialLoadingAndStartScreenClient` from the `10:17:35` V1.1 mirror or use Studio history; do not revert the confirmed V1.4 Grid3x2 view or the complete experience. Repair the same canonical installer rather than stacking a patch.

## Optional Post-Handoff Enhancements

1. Assign delayed loading music and test its audio duck/fade contract on genuinely long transitions.
2. Add one second catalogue artwork to validate shuffle-bag variation, eligibility and memory bounds before expanding further.
3. Reconsider `TeleportGui` only if another published PlaceId becomes part of a real player flow.

These are separate optional scopes. Preserve the handed-off baseline and update the same canonical installer rather than creating a patch ladder.
