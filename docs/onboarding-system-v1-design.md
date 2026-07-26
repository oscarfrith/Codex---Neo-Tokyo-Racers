# Player Onboarding System V1 Design Contract

Status: canonical V1.13 confirmed and handed off after fresh four-client, race-exit/customisation and cross-session persistence verification. The `2026-07-26 13:36:41` mirror records both Studio test overrides false.

Presentation Audio V1.1 adds no onboarding state or layout owner. The existing shades, advance catcher and `NEXT` button use `UIAudioHoverCue=""`, so the full prompt is silent on hover/controller focus while `NEXT` keeps the global click cue and advances exactly once.

Customisation Refinement V1.1 is confirmed and handed off. The scope extends only the existing `majorMenuOpen` visibility predicate: objective cards remain hidden while the authoritative garage session is active in Customisation or Drive-In mode. The server sets that state before accepted entry/loading presentation and clears it after session finish, covering Browser, all workshops, preview, purchase, Back, Drive, Exit, failure, and re-entry gaps without adding a second onboarding owner or saved field.

## Goal

Teach the minimum needed to:

1. Buy a vehicle and start driving.
2. Enter an owned garage and open Garage Management.
3. Enter a race or time trial.

The experience must stay lightweight. Objective 1 appears alone; after it completes, the independent Garage and Race objectives appear together. Menu explanations appear only the first time the player opens the relevant page.

## Preserved Behaviour

- Keep the existing dealership trail VFX.
- Reuse the existing PC driving-controls popup.
- Keep existing dealership, customisation, racing, garage, preview, economy, reward and persistence owners.
- Settings, accessibility, vehicle exit and other safety controls are never progression-locked.
- Do not add another DataStore or profile owner.
- A later racing UI change will make the time-trial reward display include the selected tier multiplier.

## Three Independent State Groups

### Objective progress

- `FirstVehiclePurchased`
- `FirstVehicleDriven`
- `FirstEventEntered`
- `GarageManagementEntered`

### First-view progress

Each approved menu page has its own seen state. Completing an objective never marks an unseen page tutorial as seen.

### Shortcut unlocks

- My Vehicles unlocks when the player acknowledges `B2`.
- My Garages unlocks when the player acknowledges `B3`.
- Race unlocks when the player acknowledges `B4`.
- `B2`, `B3` and `B4` run sequentially after first driving and never activate their buttons.

Existing players reconcile objective completion from saved ownership and relevant existing progress where reliable, but still receive any unseen page explanations.

## Objective Card Lifecycle

- Objective 1 is the only card before `FirstVehiclePurchased`, `FirstVehicleDriven` and the non-navigating B2 acknowledgement are complete.
- Completion holds briefly, then moves the card left offscreen with a fade and destroys it.
- Objectives 2 and 3 enter from the left together after Objective 1 exits, with Garage above Race and a short stagger.
- Garage and Race complete independently. A completed card exits and is removed; the remaining card eases upward.
- Loading screens and blocking menus temporarily hide the objective layer without destroying cards or replaying entrance animation.
- Motion has one approved presentation on all supported devices; there is no separate reduced-motion fade branch.

Default tuning is `0.55s` Quint Out entry, `0.15s` completion hold, `0.4s` Quart In exit, `0.45s` Quint Out reflow and a `0.10s` two-card stagger. Titles can wrap to two lines and progress uses `1/3`, `2/3`, `3/3`.

## Scoped Card Highlights

G2, K1 and AA1 resolve the visible `CanonicalGarageCard` descendants of their semantic scroller. The highlight is the live union of those cards, not the full scroller or page root. This preserves responsive card fit, follows horizontal scrolling and prevents left navigation cards from joining bottom-row prompts.

## Studio Replay And Production Persistence

The persistence architecture is installed now, but `Config.Runtime.Onboarding_EditAttributes.StudioReplayEveryPlay` defaults to `true` for the current iteration period.

When that attribute is true in Studio:

- every player begins each new Test Play at Objective 1 with no tutorial pages seen;
- progress advances normally for the rest of that server session;
- stopping and starting a new Test Play resets the tutorial again;
- onboarding progress is not read from or written to the saved profile;
- Car, Race and Garage use the same stage locks as production so each Studio replay tests the real onboarding gate. An established full-capacity test profile must use the existing capacity purchase control before buying the replay vehicle.

This override is Studio-only. Published servers continue to use ProfileService-backed objective and first-view persistence. During repeated purchase testing, `StudioVehicleSandboxEveryPlay=true` additionally clears vehicle ownership and vehicle display references only in the loaded Studio session, supplies `StudioVehicleSandboxCash`, and marks that session `NoSave`. Garage properties and garage customisation remain intact. ProfileService returns before every save path, and the hard `RunService:IsStudio()` guard prevents activation in published servers.

When the sequence is ready for persistence and rejoin testing, set both `StudioReplayEveryPlay=false` and `StudioVehicleSandboxEveryPlay=false`; no installer or architecture change is required.

## Objective Completion Boundaries

### Objective 1 — Get Your First Car

Text: `Buy a vehicle and start driving.`

Complete only after both a successful authoritative vehicle purchase and an owned vehicle entering its active driving state. A failed/full-capacity purchase does not count, and merely restoring or sitting in an older vehicle cannot complete a fresh Studio replay objective. Existing production profiles with vehicles migrate both milestones so established players are not forced to repurchase.

### Objective 2 — Enter an Event

Text: `Enter a race or time trial.`

Complete on the existing authoritative client event `RaceStarted` or `TimeTrialStarted`. Teleporting, joining a queue, staging, countdown, failure, cancellation or leaving the queue does not count.

### Objective 3 — Explore Your Garage

Text: `Enter your garage and customise it.`

Complete when the player is inside an owned garage and the canonical Garage Management workspace opens successfully. No purchase, style change or save is required.

## Objective Panel Visibility

Show the objective panel during unobstructed free roam and while walking inside an owned garage.

Hide it during:

- dealership and vehicle-customisation pages;
- Race Browser, event entry, vehicle selection and queue;
- race/time-trial staging, countdown, active session and results;
- owned-garage property browser, transitions and Garage Management; while walking inside, anchor it beneath the existing Private/Invite controls;
- desktop and mobile My Vehicles menus;
- any blocking modal that would overlap it.

After Objective 3, the objective panel disappears permanently.

## Interaction Rules

- One tutorial target is active at a time.
- Non-target controls cannot be activated while a tutorial step is active.
- Clicking anywhere or pressing Next advances an explanatory step. Its overlay captures the explanatory click, including over the highlighted control.
- B2/B3/B4 are explanatory introductions with Next buttons. Their real shortcuts remain blocked until that introduction is acknowledged and no menu opens automatically.
- N6/X3 are action steps: the real highlighted button remains actionable, there is no separate Next button, and activating that target performs the existing action and completes the tutorial page.
- A page tutorial is marked seen only after its final step advances.
- Closing a page early leaves its unfinished tutorial unseen so it can restart cleanly.
- Tutorial steps use stable semantic IDs. Shared workspace pages/cards publish their current page and card IDs; controls outside that renderer resolve within their active page root.

## Approved Copy And Order

### Objective 1 — Dealership

`G1`

> Vehicle categories group cars into families. Cars in the same category can share compatible modules.

`G4`

> Tier shows the vehicle's performance class. Overall rating gives a quick summary of its total performance.

`A2`

> You have limited vehicle space. Buy more garages to increase your capacity.

`G2`

> Select a vehicle to preview it. Buy it to add it to your collection.

### Objective 1 — Customisation Home

`J1`

> Buy and equip modules in each vehicle slot. Modules can be swapped between vehicles in the same category.

`J2`

> Upgrade the modules fitted to your vehicle. Each module has several upgrade paths and a limited point budget.

`J3`

> Change your vehicle's paint and lighting per module. You can also customise thrust, neon and underglow.

### Objective 1 — Add Modules

`K1`

> Choose a module location. Buy and swap modules from your different owned vehicles.

### Objective 1 — Upgrade Modules

`L1`

> Choose an equipped module to see its upgrades. Different modules offer different upgrade paths.

`L2`

> Each module has a limited upgrade-point budget. Spending points on one upgrade leaves fewer for the others.

### Objective 1 — Paint Shop

`M1`

> Choose which part of the vehicle you want to customise. You can edit the whole vehicle, cockpit, effects or individual modules.

### Objective 1 — First Driving

PC opens the existing free-roam Controls popup automatically once.

`D7` mobile:

> Use the drift arrows while turning to slide around corners. Drifting helps with tighter turns.

`D8` mobile:

> Hold Boost for a burst of speed. The boost meter shows how much energy remains.

`B2`, after Objective 1:

> Open My Vehicles to spawn, switch or despawn your cars. New vehicles appear here after you buy them.

### Objective 2 — Free Roam And Race Browser

`B4`

> Open the Race Browser to find events around the city. Events can support races, time trials or both.

`N1`

> Select an event to view its route and details.

`N6`

> Teleport to the selected event's starting area.

`O1`

> Choose Race to compete against other players. Choose Time Trial to race against target times.

### Objective 2 — Time Trial

`Q1`

> Choose a vehicle class for the time trial. Each class has separate target times, records and eligible vehicles.

`Q5`

> This shows your selected class and the best available reward. Higher tiers have greater rewards.

`Q8`

> Beat these target times to earn medals and cash. Faster times award higher medals.

`Q4`

> Choose how many timed laps you want to run. Your best completed lap is used for the result.

### Objective 2 — Multiplayer Race

`P1`

> This shows the route, lap count and player limit. Multiplayer races use an open vehicle category.

### Objective 3 — Free Roam And Property Browser

`B3`

> Open My Garages to view your owned properties. Each garage can display vehicles and has its own customisation.

`X1`

> Choose one of your owned garage properties. Each card shows how many display spaces it contains.

`X3`

> Enter the selected garage. You can manage its vehicles, assets and appearance from inside.

### Objective 3 — Garage Management

`Z1`

> Choose which owned vehicles are displayed in your garage. Each vehicle is assigned to a physical display space.

`Z2`

> Buy and equip different walls, floors, ceilings, decorations and lighting.

`Z3`

> Customise the assets already equipped in your garage. Change their colours, materials and lighting.

`AA1`

> Choose a display space to manage. Empty spaces can receive a vehicle, while occupied spaces can be changed.

`AB1`

> Choose Structure, Decorations or Lighting. Build adds new assets; Style changes the look of equipped assets.

`AC1`

> Choose which section of the garage you want to rebuild. The selected style is previewed in that location.

`AD1`

> Choose where you want to place a decoration. Each location has its own compatible asset options.

## Shared Overlay Visual Contract

- Reuse the established shared heading/body/button typography and semantic UI colours.
- Reserve a warm electric-gold semantic colour for tutorials. It must complement the current cyan/magenta interface and remain distinct from success, danger and normal selection.
- Use a dark navy translucent callout surface, gold target border and connector, white copy and the existing primary button style.
- Dim the non-target screen with four exact, non-overlapping surrounding blockers so the real target remains visible; a transparent full-screen input layer captures the explanatory advance click.
- Fit the border from the target's live `AbsolutePosition` and `AbsoluteSize`, with configurable padding and corner radius.
- Automatically place the callout above, below, left or right according to available safe space.
- Place bottom card/carousel callouts directly above-centred. Place free-roam shortcut callouts directly below-centred, clamped away from screen edges while keeping the connector centred on the target.
- Place O1 directly below-centred beneath its Time Trial/Race button group.
- Keep the callout within Roblox inset, mobile safe areas and configurable screen margins.
- Pin the current page and target for the duration of the step. Accept geometry after two stable rendered frames, then recalculate from target geometry/visibility events, viewport changes and responsive reflow.
- Never clone a live button as the interaction owner. Only N6/X3 leave the real target actionable; explanatory steps block the highlighted control as well.
- Resolve shared workspace pages/cards through renderer-owned semantic attributes and reject any target with a hidden or disabled ancestor.
- Preserve the active step through a bounded page-abandon period; temporary renderer rebuilding must not restart the page or rediscover its first step.
- Round cutout bounds outward, tile adjacent shade regions without overlap and overscan only the raw viewport edge so fractional scaling and curved device edges cannot expose seams or double-dark bands.
- Reuse the shared panel/button gradient, reduced border glow, fonts and semantic colours. The connector has no glow. Measure the rendered copy; body and Next share one tutorial text size independent of target typography.
- Scale tutorial visual metrics from the nearest owning shared `UIScale`; use a bounded landscape-phone fallback only when no owner scale exists. Keep Next at least 44 physical pixels high and keep target cutout geometry on raw live absolute bounds.
- Convert every target into the onboarding overlay's local coordinate space, and use that overlay's absolute size for cutout clamping, dim tiles, safe bounds and callout fitting. Never mix overlay-local targets with camera viewport boundaries.
- Support desktop, narrow desktop, landscape phone and landscape tablet. Portrait layout and testing are intentionally out of scope because the game locks mobile orientation to landscape.
- Disable the complete onboarding ScreenGui while the existing loading/start presentation is active, then resume only after that presentation is inactive and two rendered frames have passed.

## Representative Mockups

The visual language is approved through three representative cases rather than one mockup per tutorial:

1. Free-roam objective panel below the Roblox controls.
2. Large dealership panel/card highlight with dimming, border, connector and callout.
3. Small mobile driving-control highlight for drift and Boost.

The three approved visual references use current 2026-07-24 screenshots:

- `diagrams/onboarding-v1/free-roam-objective.png`
- `diagrams/onboarding-v1/dealership-g1-highlight.png`
- `diagrams/onboarding-v1/mobile-d7-highlight.png`

These are visual direction references rather than fixed geometry. Runtime layout must still derive from the live target and safe area.

## Intended Implementation Ownership

- One isolated onboarding controller owns tutorial sequence, overlay presentation and local target selection.
- Existing UI controllers own and register their live target instances.
- Existing gameplay/race/garage owners publish confirmed lifecycle boundaries.
- Existing ProfileService-backed persistence owns saved objective and seen-step data.
- The isolated onboarding guide renderer owns tutorial trail presentation; the legacy objective and tether presentation are retired.
- Existing shared UI components/tokens remain the visual source.

## Generated V1 Implementation Contract

- Lane: High-Risk, because this adds saved state plus connected client/server lifecycle hooks.
- Canonical installer: `scripts/roblox_player_onboarding_v1.lua`.
- Saved owner: the existing ProfileService receives one `ExecuteOnboardingCommand` binding and stores `Onboarding.Completed` plus `Onboarding.SeenPages` inside the existing profile/DataStore.
- Client authority: the client may request only `GetState` and an allowlisted page `MarkSeen`. It cannot complete an objective.
- Trusted completion:
  - Objective 1 records successful `BuyCockpitInstance` inside the canonical garage transaction owner and separately observes a server-created runtime vehicle whose `OwnerUserId` and `DriverUserId` both match the player. Stage 1 requires both.
  - Objective 2 is published only when the existing owned-garage runtime accepts `SetManagementOpen(Open=true)` for an active session.
  - Objective 3 is published only beside the existing server `RaceStarted` and `TimeTrialStarted` boundaries.
- Lifecycle: one isolated server service and one isolated client controller; no bootstrap addition, new DataStore, second race/garage/vehicle owner or continuous per-frame server loop.
- Legacy intro: `ShowObjectiveText` and `DynamicArrowTetherEnabled` are false; one onboarding guide renderer owns both approved destinations.
- Installation is idempotent, compiles all projected/new source before mutation and rolls back source, attributes and newly created instances on failure.
- `StudioReplayEveryPlay=true` is a session-only test override. It never clears or overwrites saved onboarding data.
- Shared target contract: each shared workspace root publishes `TutorialWorkspace=true` and `TutorialPageId`; its bottom row publishes `TutorialCardScroller`, and generated cards publish `CanonicalGarageCardId`.

## Install And Verification

1. In Edit mode, run `scripts/roblox_player_onboarding_v1.lua` with `MODE="INSTALL"`. The default installed config keeps `StudioReplayEveryPlay=true` and `StudioVehicleSandboxEveryPlay=true`; V1.12 preserves the installed UI and upgrades the guide renderer in place.
2. Restart Studio, change the same script to `MODE="AUDIT"` and run it once.
3. Use a new test profile on PC:
   - confirm loading/start fully covers onboarding and the objective appears below Roblox controls only after loading has finished;
   - follow Dealership `G1/G4/A2/G2`, buy a vehicle and start driving;
   - confirm the existing Controls popup opens once and B2 appears only after it is closed;
   - press Next on B2/B3/B4 and confirm Car/Garage/Race unlock in order without any menu opening;
   - enter an owned garage, open management and verify Objective 2 completes;
   - enter a time trial and verify Objective 3 completes only when timing actually starts.
4. Repeat on iPhone 13 landscape, one landscape tablet and at least one narrow desktop viewport; portrait is not supported or tested:
   - verify `D7` surrounds both drift arrows and `D8` surrounds Boost;
   - rotate/rescale during a prompt and confirm the border remains within roughly two pixels of the live target, the callout remains in the safe area and no dimming seam, double-dark band or curved-edge gap appears;
   - advance G1 to G4 and confirm the right-side stats highlight remains active rather than returning to Categories;
   - confirm G1 and G4 use the same body/Next tutorial text size despite their different target typography;
   - confirm every non-tutorial control is blocked until the prompt advances;
   - confirm K1 encloses the complete bottom module-slot row, L2 sits above Upgrade Points, AA1 encloses only the display-space cards and `AB1` appears once on the first Build or Style visit;
   - confirm O1 is below-centred with no clipped text/Next button;
   - confirm N6/X3 perform their real action when pressed;
   - confirm every right-side target and shade uses the full iPhone landscape canvas with no uncovered strip.
5. During copy/layout iteration, stop and start Play and confirm the entire tutorial resets without altering the underlying vehicle/garage profile.
6. Run a two-player race check. Queueing, teleport and countdown must not complete Objective 3; `RaceStarted` must complete it for each actual participant.
7. Set `StudioReplayEveryPlay=false`, then rejoin after leaving several optional pages unseen. Completed objectives must remain complete, while each unseen page tutorial must still appear on first visit.
8. Restore `StudioReplayEveryPlay=true` if further copy iteration is required, then refresh the full Studio mirror after the installer and Play matrix pass.

## Done-When Checks

- New PC and mobile players can complete all three objectives without a deadlock.
- Objective 2 completes only after Garage Management opens.
- Objective 3 completes only on `RaceStarted` or `TimeTrialStarted`.
- Completing objectives does not suppress unseen page tutorials.
- Interrupted page tutorials restart safely.
- Highlight geometry follows responsive and scrolling targets.
- Only N6/X3 are actionable tutorial targets; explanatory targets remain blocked.
- Shortcut locks never block Settings, accessibility or essential exit controls.
- Existing-player reconciliation does not force a redundant purchase.
- The objective panel never overlaps the named major menus or active race presentation.
- Loading/start never displays onboarding beneath or above it, and onboarding resumes cleanly afterward.
- Tutorial-yellow dealership and garage trails appear and clear only at their documented boundaries.

## V1.5 Superseding Contract

V1.5 supersedes the earlier objective-order, shared-root and trail notes in this document.

- Objective 1 is `BUY A VEHICLE AND START DRIVING`, with `Follow the trail to the dealership.` before purchase and `Start driving your new vehicle.` afterward.
- Objective 2 is `EXPLORE YOUR GARAGE`, with `Enter your garage and open customisation.`
- Objective 3 is `ENTER AN EVENT`, with `Join a race or start a time trial.`
- The objective card displays `OBJECTIVE N`, the uppercase title, one short hint and `N / 3`.
- Shortcut introductions run `B2`, `B3`, then `B4`; none activates its shortcut.
- The saved milestone fields and trusted completion boundaries are unchanged. Only the server-derived stage order changes to vehicle, garage, race, so no profile migration is required.
- Shared workspace discovery requires `TutorialWorkspace=true` plus the matching `TutorialPageId`; it never depends on `CanonicalGarageWorkspace` versus `OwnedGarageCanonicalWorkspace`.
- The shared workspace publishes `TutorialCardScroller`/`TutorialTargetId=CardScroller`. K1 targets that single bottom carousel and does not union individual cards or target the left category rail.
- G4 prefers the left of the performance panel. B2/B3/B4 use the dedicated `ShortcutCalloutGapPixels` setting so landscape-phone callouts remain close to their icons.
- The legacy dealership objective and tether are disabled. `OnboardingGuideTrailRenderer` is the single local guide presentation owner, using `TutorialGold`.
- The dealership guide targets `Intro.Desk.GarageDeskTrigger` until `FirstVehiclePurchased`.
- Inside an owned garage, the same renderer targets the nearest `ManagementDesk.DeskPromptAnchor` until Garage Management opens.
- Loading, loss of the target, objective completion and leaving the applicable space clear the local guide folder.

V1.5 verification must confirm K1 encloses only the complete visible bottom module row, every owned-garage tutorial page resolves, G4 sits left of stats on landscape phone, shortcut callouts remain close to their icons, and both guide destinations clear at their stated boundaries.

## V1.6 Superseding Contract

V1.6 supersedes V1.5's single-card stage swap, full-scroller bounds and simplified arrow-only guide presentation.

- Objective 1 remains visible through the B2 acknowledgement, then exits and is destroyed.
- Objectives 2 and 3 appear together after Objective 1, with Garage above Race. Their trusted gameplay completion boundaries remain independent.
- Completed cards do not remain in the stack. A lower remaining card reflows upward smoothly.
- G2, K1 and AA1 fit only visible canonical cards within the relevant semantic scroller.
- The guide renderer reuses the original dealership chevron, aura-beam and core-beam construction, recoloured through `TutorialGold`, for both approved destinations.
- V1.6 verification must include rapid/duplicate state updates to prove the polling loop cannot restart animations or recreate completed cards.

## V1.7 Superseding Contract

V1.7 supersedes V1.6's objective-card copy, typography/bounds and established-profile purchase-testing note.

- Objective 1's display title is `BUY AND CUSTOMISE A CAR`. Its authoritative completion boundary remains purchase, active driving and B2 acknowledgement; the title change does not add a customisation requirement.
- Objective cards use explicit responsive tutorial sizes, reserve two title lines and show exact untruncated `1/3`, `2/3`, `3/3` progress.
- The visual panel is inset inside a padded, non-clipping CanvasGroup shell. The shell owns the existing slide/fade tween while the inset prevents the shared stroke/glow from being cut by group compositing or the left screen edge.
- `StudioVehicleSandboxEveryPlay=true` creates a clean vehicle-testing copy of the loaded profile for each Studio server. It preserves owned garage properties and garage customisation, supplies configured test cash and never writes the modified session.
- `NTR_StudioVehicleSandboxActive=true` and the ProfileService output line identify an active sandbox. All save entry points return `Studio vehicle sandbox; save suppressed.` before encoding or DataStore access.
- Before production persistence verification or publishing, set both Studio replay attributes false. Confirm a rejoin restores the unchanged real vehicle collection, then refresh the full Studio mirror.

## V1.8 Superseding Contract

V1.8 supersedes only V1.7's responsive presentation rules. State ownership, trusted completion, first-view persistence, shortcut unlocking, guide VFX and the Studio vehicle sandbox are unchanged.

- Desktop objective card bounds remain unchanged while number, title, hint and progress text use a configurable 1.5 multiplier.
- Landscape-phone objective text sizes remain unchanged. Cards use a compact height and gap, begin immediately below the Roblox top inset and check the live Boost button before accepting the stack height.
- Hardware-edge safety and Roblox top-bar exclusion are separate concepts. Landscape-phone callouts preserve left, right and bottom physical insets but may occupy vertical space beside the top bar.
- G4 retains left-centred placement beside the live stats target. B2, B3 and B4 use a narrower landscape-phone width and a small target gap, with the connector still centred on the shortcut.
- Done when desktop text is clearly readable without card growth, G4 is centred beside stats rather than at its bottom, shortcut bubbles sit close beneath their icons without clipping, and the phone objective stack neither overlaps Roblox controls nor the live Boost button.

## V1.9 Superseding Contract

V1.9 supersedes only V1.8's landscape-phone objective Y anchor and internal vertical spacing.

- Do not use `GuiService:GetGuiInset()` as the phone objective Y source; device emulation can report a top inset substantially below the visible controls.
- Use the bottom of the live semantic Car/Race/Garage shortcut row plus `ObjectivePhoneTopRowClearancePixels`. Use `ObjectivePhoneFallbackTopPixels` only when that row is unavailable.
- Keep the V1.8 mobile card height and text sizes. Lay out label, title and description sequentially, use a one-pixel title/description gap and reserve the remaining lower area for two-line descriptions.
- Keep the progress label isolated at lower right, preserve the Boost-overlap check and retain physical left-edge safety.
- Done when the objective stack sits immediately below the Roblox controls, Objective 2's two-line description is fully visible, and Objectives 2/3 remain compact without overlapping one another or Boost.

## V1.10 Superseding Contract

V1.10 supersedes only V1.9's landscape-phone card height and lower-content alignment.

- Assume a maximum of two description lines for the approved objective copy.
- Use a 48-pixel phone card with a 46-pixel responsive minimum.
- Calculate two description line heights from the current mobile hint text size.
- Align the progress bottom to the same calculated second-line bottom and leave a common three-pixel margin beneath both.
- Preserve the live top-row anchor, mobile text sizes, desktop cards, completion lifecycle, persistence and VFX.
- Done when the card bottom sits close beneath Objective 2's second description line and `2/3` or `3/3` shares that visual bottom edge without clipping.

## V1.11 Superseding Contract

V1.11 supersedes only the guide trail's pulse displacement and beam-start height.

- Replace the hard-coded `.08`-stud arrow displacement with `GuideTrailPulseAmplitude`, default `.4`.
- Keep `GuideTrailPulseSpeed` as frequency. Either speed or amplitude at `0` produces a fixed arrow trail.
- Use `GuideTrailBeamStartHeightOffset`, default `-1`, only for the player-side beam anchor.
- Keep `GuideTrailHeightOffset` as the arrow height and destination-side beam-end height.
- Preserve the guide endpoints, arrow/beam geometry, tutorial colour, cleanup boundaries and single local renderer ownership.
- Done when pulse speed visibly changes frequency, pulse amplitude changes travel distance and the beam begins below the player's head without affecting the destination endpoint.

## V1.12 Superseding Contract

V1.12 folds in the uninstalled V1.11 origin work and supersedes the moving-chevron presentation only.

- Keep the existing wide aura and narrow core Beams.
- Add one face-camera, wrapped `ChevronBeam` using the same two attachments and `TutorialGold`.
- Put texture asset, speed, repeat length, width, transparency, brightness and Z offset in `Onboarding_EditAttributes`.
- Accept either a numeric uploaded asset ID or `rbxassetid://` URI; malformed values fall back to Parts.
- Do not invent an asset ID. If the texture is empty, automatically use the existing Part chevrons so onboarding remains visible.
- With a valid texture and `GuideTrailPartArrowsEnabled=false`, do not create physical arrow Parts.
- Preserve endpoints, lower player-side origin, lifecycle, cleanup, objectives, persistence and the single local renderer owner.
- Done when the texture moves toward the destination, reverses with negative speed, follows both destinations and cleans up without leaving Parts or Beams after completion.

## V1.13 Superseding Contract

V1.13 preserves the working V1.12 presentation and repairs the authoritative state boundary exposed by the first complete new-player race test.

- ProfileService remains the only owner of saved onboarding state. Every generic garage/racing snapshot import must retain the current `session.Profile.Onboarding` table before profile reconciliation; external snapshots cannot clear or replace it.
- No saved fields or schema migration are added.
- The PC controls popup may open only while the player is driving a normal free-roam vehicle. A vehicle marked `NTR_RaceParticipant` or carrying `NTR_RaceRunId` is excluded during staging, countdown and racing.
- Desktop objective descriptions reserve up to two lines inside the existing card. `N/3` is vertically centred beside the description region. Mobile card metrics remain unchanged.
- Done when a new player can complete Objective 1, enter and quit a race, return to free roam and re-enter customisation without Objective 1, shortcut prompts or already-seen menu prompts returning; the controls popup never interrupts a race; and the two-line desktop description is fully visible.

Focused V1.13 regression:

1. With Studio replay/sandbox enabled, complete Objective 1 and dismiss the free-roam shortcut prompts.
2. Enter an event and confirm the PC controls popup does not appear in staging, countdown or the running race.
3. Quit to free roam. Confirm Objective 1 and dismissed shortcut prompts remain absent.
4. Re-enter each already-seen customisation page. Confirm its prompts do not replay.
5. Confirm Objective 2/3 descriptions can wrap to two desktop lines with `N/3` aligned beside them.
6. Disable both Studio test overrides, rejoin twice and repeat the state checks against the saved profile before publishing.

## V1.13 Confirmation

The user completed the full sequence with a fresh Player 4 profile in a server-and-clients session. Completed objectives, shortcut introductions and already-seen customisation prompts remained dismissed after race exit. With `StudioReplayEveryPlay=false` and `StudioVehicleSandboxEveryPlay=false`, the same state remained complete in a later server session. This confirms authoritative persistence as well as within-session state ownership.
