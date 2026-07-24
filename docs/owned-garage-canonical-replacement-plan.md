# Owned Garage Canonical Replacement Plan

## Phase 14 approved management composition and V1 foundation

The next approved composition is `DISPLAY CARS`, `BUILD GARAGE` and `STYLE GARAGE`. Build owns preview plus purchase/equip for Structure, Decorations and whole-garage Lighting. Style edits only the currently equipped asset: Structure exposes Colour/Material, Decorations expose populated colour channels and Lighting exposes Primary/Secondary. One shared left rail swaps between the three modes and the selected family's locations; two simultaneous rails are prohibited for mobile space and input clarity.

Phase 14 V1 is generated first because the existing preview owner reconstructed each channel request from committed state, allowing Secondary to discard an unsaved Primary preview. V1 establishes complete drafts, same-target server merging, SAVE-without-navigation, per-preset lighting finishes and one TemplateOrigin lighting model. After V1 install/audit/Play confirmation and mirror refresh, advance the same canonical installer to the shared navigation/Build/Style composition. See `docs/owned-garage-phase14-lighting-and-flow.md`.

V1 is now user-confirmed and mirrored. V2 generates that shared composition as a one-source upgrade: root mode cards, mode/family rail, location rail at Structure/Decoration target depth, Build purchase/equip-only actions and Style finish-only controls. Server/persistence owners remain the V1 baseline.

V2 and V2.1 are user-confirmed and mirrored. V2.1 completed shared-component visual parity: bottom and sidebar navigation call `ModuleCategoryCard`, with one `OwnedGarageCategoryCardImageZoom` value supplying both consumers.

V2.2 is the final responsive navigation closure for this approved composition. It keeps location-rail scroll memory stable across nested Structure/Decoration pages and gives empty Style decoration locations a shared-card route to Build on the same target. The route does not mutate state; Build remains purchase/equip authority and Style remains finish-edit authority.

Phase 14 V2.2 is user-confirmed and present in the complete `2026-07-22 21:37:10/11` mirror. The approved owned-garage replacement/overhaul is complete. There is no Phase 15 in this plan; future visitor admission, architecture reorganisation or new garage content starts from the closure handoff as a separately approved scope.

Status: Phases 0-12 passed. Phase 12 Access and Invitations V1.1 is confirmed and present in the refreshed `2026-07-20 11:10:20` mirror with revision `NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1_1_HUD_DROPDOWNS`. Its optional V1.2 full-width icon-dropdown refinement is generated and awaits Studio verification. See `docs/owned-garage-and-readiness-handoff-2026-07-20.md`.

## Reusable Garage Expansion Gate

Before Phase 7 introduces definition-driven properties, revisioned transactions and cached state, run:

```text
scripts/roblox_profile_service_session_ownership_readonly_audit.lua
```

The initial gate returned `10/0/4` in Edit and `25/0/6` in fresh Play. Repair V1 persisted the ProfileService lifecycle, in-place import and read-only `GetInitial` source contracts; the refreshed mirror contains them. Follow-up was `19/0/2` Edit and `35/0/3` Play. Two failures were non-semantic convenience attributes discarded by Studio, while the remaining runtime failure exposed direct nested-table replacement in `OwnedGarageProfileRuntime.Ensure` and `Restore`.

Run this separate game-wide repair once in Studio Edit mode:

```text
scripts/roblox_profile_service_authoritative_session_lifecycle_repair.lua
```

It does not belong to the garage Phase 7 installer. Corrected V1.1 preserves the already-installed ProfileService/GetInitial work and additionally reconciles owned-garage schema/reset and rollback updates into the existing nested table. Its audit uses durable source markers because Studio did not persist the convenience attributes. Final fresh-Play evidence passed `40/0/0`, including five seconds of stable server-owned session generation and identity. The gate is closed.

## Phase 7 Reusable Property Framework

Canonical installer:

```text
scripts/roblox_owned_garage_phase7_reusable_property_framework.lua
```

Phase 7 is a Standard-lane architecture foundation, not the visual overhaul. It keeps the Phase 6 interface and persistence schema intact while making later garages and management pages data-driven:

- `OwnedGaragePropertyCatalog` becomes a validated, immutable version-2 definition contract for template, display slots, structure sections, surface groups, decoration anchors, capabilities and UI metadata.
- Management state uses catalogue display-space IDs instead of hard-coded `Space01`/`Space02`, publishes API/definition versions and future access/decoration metadata, and caches a cloned projection by garage revision, active interior, vehicle signature and cash.
- Mutations carry a unique request ID and the menu's base revision. Duplicate requests replay the same result, reused IDs with different payload context are rejected, and stale revisions return a conflict/current revision instead of overwriting newer state.
- `GetState` and `GetManagementState` are read-only cooldown exemptions. Successful mutations invalidate the cache; player departure clears cache, request history and transaction locks.

Done when the Edit installer reports PASS, Play preserves the Phase 6 browser/entry/exit/management flow, assign/clear/style/access operations refresh to a newer revision, repeated unchanged reads are safe, stale conflicts recover by refreshing, and the full Studio mirror is refreshed. Any source-anchor mismatch must stop before mutation; repair this same canonical installer rather than creating a Phase 7 patch ladder.

Phase 7 is complete. The focused client check returned API/definition version `2/2`, an unchanged-read cache hit and correct stale mutation rejection, and the user refreshed the mirror at `15:32:55`.

## Phase 8 Canonical Display Cars Vertical Slice

Canonical installer:

```text
scripts/roblox_owned_garage_phase8_canonical_vertical_slice.lua
```

Phase 8 is the first reusable player-facing slice over the Phase 7 contract. It replaces the old owned-garage vehicle scan/full-render controller with authoritative dealership vehicle summaries, shared vehicle cards, rating ordering, cross-property usage state, preview-before-commit, move confirmation and revision-aware assignment. Browser and management opens become asynchronous/warm; card-only selection uses an incremental shared render; production audit and empty presentation loops are gated off.

The same transaction makes desk, door and displayed-car prompts tap-only, suppresses all interior prompts while management/transitions own input, returns drive-out results, and applies the approved garage HUD policy on desktop/mobile. V1.4 uses the existing interior-mode controller and navigation-icon folder rather than depending on new hierarchy instances that failed to persist. V1.5 retains the visible workspace across transient refresh failures, coalesces mutation/push refresh ownership, and reuses the complete shared Build Modules rail sizing/alignment contract so all four category cards occupy the intended full-height rail. V1.6 completes component reuse with Build's `.5` rail icon scale and dealership's exact vehicle card route, makes preview/commit separate states, validates the saved response before success and hides the free-roam HUD during management. V1.7 makes the selected action and returned management projection explicit. V1.8 fixes the underlying write boundary: copied `GetProfile` results are immutable read models, while a ProfileService-owned command binding performs all garage mutations against the live session table. That command seam preserves the schema and UI contracts and can be moved behind a reorganised service layer after the submission. Config attributes remain optional tuning overrides with safe source defaults. Structure, Decorations, Lighting, Invitations and Visitors remain disabled until their dedicated phases.

The transition-completion installer keeps Phase 8's UI and persistence owners intact. Entry becomes an explicit prepare/despawn-detach/commit/verified-teleport/render transaction. A vehicle already assigned to the selected property retains its slot without a redundant revision; a vehicle from elsewhere still uses the duplicate-safe authoritative move. Exterior placement is definition-driven through `ExteriorSpawnId` and two editable world markers per property, so future garages add data and placement rather than runtime branches. Foot and vehicle exits resolve their selected property's markers before mutating session or display state.

Done when the Edit installer reports Phase 8 PASS; two distinct saved vehicles show correct identity/image/rating through the exact dealership card; previews do not change `0/2`; the shared `DISPLAY` action changes the saved count/revision and occupied-space card; two different vehicles remain in two slots after closing/reopening management; the same vehicle moves instead of duplicating; driving into the selected property detaches/despawns before a verified interior arrival and shows that vehicle in exactly one slot; foot and vehicle exits use the property's exterior markers; no thrust-preview error appears; all four shared category cards remain visible; and prompts/drive-out work on tap. Refresh the full mirror after those checks.

Phase 8 is complete. The transition installer passed after its guarded mixed-state recovery, the user confirmed the flow working well, and the refreshed mirror contains 154 scripts plus `OwnedGarageExteriors.STARTER_TWO_BAY` with both attributed exit markers and all four transition source contracts.

## Phase 9 Canonical Structure Vertical Slice

Phase 9 replaces the coarse staged `SurfaceStyles` path; it must not expose that legacy path through the new UI. The current template labels every wall only as `SurfaceGroup="Walls"`, so it cannot independently address Front, Left, Right and Back. The current style catalogue also has no price, ownership, channel or template-compatibility contract, and the old `SetSurfaceStyle` mutation predates the ProfileService-owned authoritative command boundary.

The canonical Phase 9 contract is:

- `OwnedGarageInteriorStyleCatalog` becomes a versioned, immutable structure-definition catalogue keyed by stable `SectionId` and `StyleId`. The six sections are `FrontWall`, `LeftWall`, `RightWall`, `BackWall`, `Floor`, and `Ceiling`; every section initially exposes four ordered presets. Option 1 is granted by default. Other presets carry price, compatibility and Primary/Secondary/Detail defaults. Optional future asset/template identifiers are data, not runtime branches.
- Saved state remains under each property and adds a normalised structure namespace containing selected styles, owned style IDs and per-section Primary/Secondary/Detail colour/material overrides. It is additive and must preserve display assignments, access, vehicles, cash and the current profile root identity.
- Purchases, equips and channel edits execute only through `ExecuteOwnedGarageCommand` against the live ProfileService session. Buying validates cash and ownership atomically; selecting an owned style does not charge again. Every successful mutation increments the same garage revision, invalidates the same state cache and returns the immutable management projection.
- Preview is session-owned and non-persistent. Selecting a style or channel option applies a temporary override to the active runtime interior; Back, Exit, category change, management close, transition or player cleanup restores the last committed structure state. Preview never writes compatibility tables or player data.
- The `StarterTwoBay` template receives explicit `StructureSection` and `StructureChannel` attributes. Runtime application targets those attributes, not part names. Additional templates must satisfy their property definition's section contract; a missing required section fails preflight rather than silently recolouring another surface.
- Physical variants live under `ServerStorage.NeoTokyoRacers.OwnedGarage.StructureAssets.<TemplateId>.<SectionId>.<AssetOption>` and align to `StructureSlots.<SectionId>` in the matching template. Runtime section models contain presentation/collision geometry only; desks, prompts, exits, display markers and other gameplay owners remain in the garage template. Placeholder assets are editable and preserved on installer rerun.
- Structure first renders six shared module-style section cards. Selecting a section changes the left rail to the same six section cards and renders four shared upgrade-style preset cards with price/owned/current state. The existing shared selected-action popup supplies `BUY` or `CUSTOMISE`; no owned-garage-only card or modal clone is allowed.
- Customise renders Material and Colour through the shared cosmetics-category composition. Both expose Primary, Secondary and Detail. Colour reuses the confirmed shared H/S/B slider component; Material uses the same panel bounds with catalogue-allowed material buttons. Current simple geometry may map multiple channels to authored parts, while future templates can add more attributed parts without changing UI, persistence or commands.
- All controls use `Activated`, the existing scaled `1200 x 720` host, 44-pixel touch targets, incremental rerendering and no polling loop. Structure state is included in cache keys/revisions rather than fetched through a second remote.

Done when all six sections are independently targetable; four presets appear per section; Option 1 is owned by default; preview is visible but mutation-free; Buy deducts once and survives close/rejoin; owned styles customise without another purchase; Primary/Secondary/Detail colour and material persist; cancelling restores committed presentation; Display Cars, entry/exit, prompts, HUD policy and two-slot persistence remain unchanged; desktop and phone layouts pass; and the refreshed mirror contains the catalogue, template attributes and source contracts.

Phase 9 V1.1 is complete. The user confirmed its asset listing, preview, purchase and customisation flow working and refreshed the full mirror.

## Phase 10 Canonical Decorations Vertical Slice

Canonical installer:

```text
scripts/roblox_owned_garage_phase10_decorations_vertical_slice.lua
```

Phase 10 keeps decoration geometry, preview and persistence under the existing owners. It corrects StarterTwoBay to expose all three physical anchors, adds a versioned catalogue with Plants, Paintings, Furniture, Lighting, Storage and Signs, and creates two editable placeholder assets per category. Saved state is an owned-item unlock map plus one item reference per stable anchor; no world transforms are saved.

The shared flow is category -> position -> item. Selecting an item creates a session-only physical preview. `BUY`, `PLACE` and `REMOVE` use the same revisioned ProfileService command boundary, return the committed immutable management state, and rebuild only `DecorationRuntime`. Runtime assets are bounded, anchored, non-collidable and stripped of scripts/prompts/seats. This is the mobile/scalability gate before any later constrained move/rotate editor.

Done when all six categories and three positions render; starter items are owned; a locked item charges once and is placed; an owned item can replace one position without changing the other two; Remove affects one position; preview cancels on Back/category/Exit; three placements survive management close and save/rejoin; no duplicate runtime model remains per anchor; Structure, display cars and transitions regressions are absent; desktop/phone pass; and the mirror contains the catalogue, three canonical anchors, twelve asset models and Phase 10 source markers.

Phase 10 is complete. The user confirmed the category/position/item flow and persistence working and refreshed the full mirror.

## Phase 11 Canonical Garage Lighting Vertical Slice

Canonical installer:

```text
scripts/roblox_owned_garage_phase11_lighting_vertical_slice.lua
```

Phase 11 separates room illumination from both decoration props and global environmental lighting. Each property definition exposes stable fixture-slot IDs. The garage template owns their placement; ServerStorage owns editable fixture assets; an immutable catalogue owns preset colour, brightness, range, price and intensity choices. Saved state contains owned preset IDs, the selected preset and one bounded intensity level.

Preview remains session-only. Purchase, equip and intensity changes use the same revisioned ProfileService command and immutable response. Runtime creates at most one sanitised fixture per definition slot, with collision/query/touch/shadows disabled and range capped. It never edits the global `Lighting` service or the game's stage schedule.

Done when Presets and Intensity use shared cards/actions; four presets preview distinctly; the default is owned; a locked preset charges once; Apply and intensity persist through close/rejoin; Back/Exit restores committed presentation; each active StarterTwoBay interior contains exactly four runtime fixtures; no global lighting stage/value changes; Structure, Decorations, Display Cars and transitions remain stable; desktop/phone pass; and the refreshed mirror contains API version 3, the catalogue, four slots, fixture asset and Phase 11 source contracts.

Phase 11 V1.1 is complete. The user confirmed it working after a Studio restart and refreshed the full mirror.

## Phase 12 Canonical Access and Invitations Vertical Slice

Canonical installer:

```text
scripts/roblox_owned_garage_phase12_access_invitations.lua
```

Phase 12 activates the access data already present in each property instead of creating a second visitor system. Four access modes and a bounded, deduplicated invited-user list mutate through the same revisioned ProfileService-owned command boundary. V1 proved that contract through shared workspace pages; V1.1 moves the two entry interactions into anchored persistent-HUD dropdowns. Invitation candidates are other players in the current server, while saved offline IDs remain revokeable.

The property definition and runtime config enable Access and Invitations, but Visitors remains false. The legacy `GarageInteriorService_Active` retains its older in-memory visit flow and must not become a competing owner. A later visitor phase must explicitly switch admission, destination/session state, teleport and return ownership onto the canonical property/access projection before Public, Friends Only or Invite Only affects entry.

Done when all four modes persist; both HUD buttons open the correct anchored dropdowns without entering management; a second same-server player can be invited and revoked; duplicate/self invitations are rejected; offline saved IDs can be revoked; unchanged reads cache against both garage and player-list signatures; stale revisions conflict; cash/settings remain usable; phone targets and scrolling pass; prior garage categories and transitions regressions are absent; Visitors remains disabled; and the refreshed mirror reports API/definition version 4 plus the Phase 12/V1.1 source markers.

Phase 12 V1.1 is complete and is the confirmed rollback baseline. Both persistent HUD buttons use `GarageReplacementComponents.AnchoredDropdown`, call the same commands directly and never open management. Cash/Settings remain visible, the invite list refreshes on demand and scrolls after a configurable row cap, and viewport changes relayout through camera signals rather than a per-frame loop. The refreshed mirror contains the V1.1 revision and all seven access/invitation source contracts. Optional V1.2 changes only dropdown width/border/gradient/icon/chevron presentation and must pass the handoff verification matrix before becoming the new baseline.

## Phase 13 Typed Fixtures And Shared Finishes

Canonical installer:

```text
scripts/roblox_owned_garage_phase13_typed_finishes.lua
```

Phase 13 replaces the generic decoration category/anchor contract with five fixed property zones and makes asset folders the authoring interface for both decoration and structure colour/material support. V1.1 adds a sixth optional `DisplayPlatforms` zone that uses the same decoration workflow. Every asset contains `ColourSlots` with Primary, Secondary, Detail and Neon plus protected `Fixed` and `Technical` folders. Empty channel folders are omitted from the projected UI automatically.

Workshop and Storage are required fixtures whose visible shells can be upgraded while the desk prompt remains in the garage template. Hangout, Feature and Identity are optional. Decoration colours save with each property placement. Structure retains section/style state, adds Neon colour and allows whitelisted material changes only on populated Primary/Secondary/Detail channels.

The isolated finish runtime owns capability inspection, validation and clone application. Existing workspace/paint UI, management presentation, ProfileService command, economy, revision and preview-cancellation owners remain intact. Physical preview occurs only on committed input, while SAVE performs the revisioned mutation. No arbitrary placement, saved world CFrame, second remote or per-frame layout/presentation loop is introduced. Existing assets remain slot-local; new origin-authored platform options are placed through the template origin so both authoring modes have an explicit contract.

Done when six zones and eighteen catalogue options exist; the optional platform zone stays hidden while its three template models are empty/disabled; required fixtures load without breaking the desk prompt; folder population exactly controls visible buttons; Fixed/Technical remain unchanged; Neon has no material action; preview/cancel/save/purchase persist correctly; repeated cycles create no duplicate runtime models; displays, lighting, access and all entry/exit paths regress cleanly; PC/tablet/phone pass; and a refreshed mirror contains revision `NTR_OWNED_GARAGE_PHASE13_TYPED_FIXTURES_FINISHES_V1_1_ATTRIBUTE_PLATFORM_REPAIR`.

## Acceptance Contract

Replace the physical owned-garage MVP with a clean, persistent, walkable two-bay system. HOME opens a `1200 x 720` My Garages browser using the Race Browser scale contract and the confirmed dealership component family. Display spaces store stable saved `VehicleId` references, survive save/rejoin, never duplicate an owned vehicle, and replace only the display assignment. Players can enter on foot, drive a vehicle in, leave through the door, or use a displayed vehicle to drive out. A native desk prompt opens shared garage management UI. The minimap is hidden inside while other free-roam actions remain visible and safe.

Existing test profile data does not need migration. The eventual installer may perform an explicit Studio-only tester reset, but it must preserve the current ProfileService and authoritative vehicle/cockpit/module saving architecture for all newly created data.

## Locked Owners

| Concern | Intended owner |
|---|---|
| Vehicle identity/configuration | Existing ProfileService and garage vehicle runtime |
| Garage property state | New `OwnedGarageProfileRuntime` |
| Display assignments | New `OwnedGarageDisplayAssignmentRuntime` |
| Interior lifecycle | New `OwnedGarageManagementRuntime` started by one final isolated service |
| Display construction | New `OwnedGarageDisplayRuntime` |
| Live vehicle spawn/despawn | Existing owner through one narrow server binding |
| UI state | New `OwnedGarageBrowserController` and `OwnedGarageWorkspaceController`, each started once by the final isolated client controller |
| Components/theme | Existing `GarageReplacementComponents` and `RacingUIComponents` |
| Responsive scale | Existing `RacingMobileScaledDesktopLayout` |
| Interior HUD policy | New `GarageInteriorModeController` |
| Transition cleanup | New `GarageInteriorTransitionController` |

Do not add a second vehicle spawner, profile saver, display assignment writer, geometry owner, map owner, or transition owner.

## Delivery Phases

1. Phase 0: read-only Edit, Play-server and Play-client ownership/runtime audit.
2. Phase 1: clean per-property schema, catalogues, validation, idempotency and profile transaction runtime.
3. Phase 2: configurable `StarterTwoBay` template, isolated runtime pool and lightweight display models.
4. Phase 3: HOME browser, foot entry/exit, drive-in replacement and display-car drive-out through the existing vehicle lifecycle owner.
5. Phase 4: shared Display Cars, Interior and Access workspace using the confirmed UI modules.
6. Phase 5: mobile safe-area/touch work, minimap suppression, external-menu cleanup and performance hardening.
7. Phase 6: atomic activation, explicit tester reset, save/rejoin and regression verification, mirror refresh and handoff.

Phases 1-6 are internal checkpoints in one maintained canonical installer, not a user-run patch ladder. Repair the same installer after a failure. Do not split the approved scope without asking.

## Phase 0 Audit

Script:

```text
scripts/roblox_owned_garage_phase0_ownership_runtime_audit.lua
```

The script is read-only and auto-detects its context. Run the same complete contents in:

1. Studio Edit Command Bar.
2. Play Server Command Bar with the tester connected.
3. Play Client Command Bar while inside the current garage interior; opening Race Browser first is optional and provides a runtime shell-size comparison.

Copy all three result blocks back to Codex. Do not run a reset or replacement installer before reviewing them.

Confirmed 2026-07-19 results:

- Edit/static: `pass=41 warn=2 blocker=0 info=17`.
- Play server: `pass=3 warn=0 blocker=0 info=3`; three vehicles, three cockpit instances, 42 module instances, three valid display references, zero duplicate or missing vehicle references.
- Play client: `pass=4 warn=1 blocker=0 info=7`; HOME and the Race Browser shell were present, and the expected minimap-inside-interior gap was confirmed.

## Planned Canonical Installer

```text
scripts/roblox_owned_garage_canonical_replacement.lua
```

Phase 2 passed and is present in the refreshed `2026-07-19 11:02:32` mirror. It contains `ServerStorage.NeoTokyoRacers.OwnedGarage.Templates.StarterTwoBay`, editable `OwnedGarage_EditAttributes`, `OwnedGarageInteriorRuntime`, and `OwnedGarageDisplayRuntime`. The template has two display markers, floor/walls/roof, management desk, native disabled desk/exit prompts, character/drive markers and decoration anchors. Runtime interiors use a configurable isolated grid at `Y=3200` rather than going below `FallenPartsDestroyHeight`. Display construction consumes a requested saved `VehicleId`, rejects duplicates and strips scripts, seats, VFX, collision, queries and shadows.

Phase 3 stages `OwnedGarageManagementRuntime` and `OwnedGarageBrowserController`. The server module owns future per-player interior sessions, prompt connections, slot replacement transactions and entry/exit orchestration; it delegates live vehicle discovery/spawn/despawn through `OwnedGarageVehicleLifecycleBridge`. The client module builds one `1200 x 720` browser from the actual Racing/garage shared modules, uses `Activated`, supports image/title/district/description/capacity fields and confirms full-garage replacement without deleting the displaced vehicle. `OwnedGarageInvoke`, `OwnedGarageEvent`, `OpenOwnedGarageBrowser` and the lifecycle binding are installed inert. No Start function is called and the lifecycle binding has no owner, so this checkpoint still cannot alter live play.

Installer V1.1 records that inert state with `OwnedGarageStagingInert` attributes rather than reading `OnServerInvoke` or `OnInvoke`; Roblox callback members are write-only and the original callback-read audit correctly triggered a complete transaction rollback.

Phase 4 stages `OwnedGarageWorkspaceController`, `OwnedGarageInteriorStyleCatalog` and `OpenOwnedGarageWorkspace`. The controller instantiates the existing `GarageWorkspaceController` so the desk UI uses the same canonical host, layout, cards, carousel, action popup, scaling and semantic tokens as dealership/customisation. Display Cars uses a space-first flow and the Phase 1 assignment transaction; Interior applies validated catalogue styles to template `SurfaceGroup` attributes and saves selections per property; Access saves `Private`, `FriendsOnly`, `InviteOnly` or `Public` policy but does not activate visitor admission. The management runtime refreshes live display/style presentation only after validated mutations and restores presentation from the profile snapshot when a transaction fails. Everything remains inactive until the final starter/owner switch.

The current recovery path is `scripts/roblox_owned_garage_phase4_missing_objects_recovery.lua`. It starts from the observed partial baseline, validates the existing Phase 4 Profile/Assignment/Management sources and shared UI modules, and creates only the missing style catalogue, workspace controller and open event. `scripts/roblox_owned_garage_phase4_persistence_audit.lua` then validates all existing source contracts plus the recovery revision/run ID from a separate command. Phase 4 is accepted only after `18 PASS / 0 FAIL` and a matching mirror.

Phase 4 passed that boundary after a generic two-command Folder probe showed the current Studio session discarded every Command Bar-created instance. A complete Studio restart made the same probe persist, after which the focused recovery and `18/0` audit passed. This rules out the garage hierarchy/source as the root cause of that failure; do not add further recovery logic for a session-level Studio fault.

Phase 5 is `scripts/roblox_owned_garage_phase5_mobile_safety_hardening.lua`. It retains the desktop/mobile HUDs as the sole minimap visibility owners and adds a guarded `NTR_OwnedGarageInside` condition rather than a competing visibility loop. It stages inert `GarageInteriorModeController` and `GarageInteriorTransitionController` modules, adds owned-browser/workspace close contracts and scaled 44-pixel touch-target hardening, and adds server-authoritative rejection for free-roam vehicle changes, dealership teleport and race teleport while inside. Settings, cash and browser actions may still open safely; blocked world transitions return a message and do not mutate the garage session. No Phase 5 controller starts and no HOME/profile/service/lifecycle switch occurs until Phase 6.

Phase 6 is `scripts/roblox_owned_garage_phase6_atomic_activation.lua`. Preflight found that the staged schema could not safely replace `profile.Garage`, because that table remains authoritative for vehicle capacity and existing cockpit purchase rules. Activation therefore namespaces the new property/display state under `profile.OwnedGarage`; vehicle/cockpit/module data and `profile.Garage` remain untouched. The existing vehicle snapshot-import adapter explicitly carries `OwnedGarage` forward so later vehicle edits cannot erase assignments.

The same atomic transaction adds the two small server/client starters, connects HOME to `OpenOwnedGarageBrowser`, and installs the guarded lifecycle callback inside the existing action owner where its local vehicle helpers are available. It retires only the five legacy physical-garage scripts and their old world entrance prompt; dealership/customisation and the authoritative vehicle action owner remain enabled. A revision-token reset clears only tester `7915427645`'s new `OwnedGarage` namespace once, never their saved vehicle/cockpit/module data. Character death/reset and disconnect release the session and unload its runtime interior.

## Mobile And Editability Contracts

- One shared `1200 x 720` composition scaled through `RacingMobileScaledDesktopLayout`.
- Minimum `44 px` physical touch targets and `Activated` input.
- Native `ProximityPrompt` for keyboard, controller and touch.
- No permanent polling loops or hover-only action.
- Property, template, surface and decoration catalogues own content and future expansion.
- Template markers/attributes own desk, door, display-space and decoration geometry.
- Config attributes own transition timing, isolated interior placement, unload delay and debug behaviour.
- Display models are anchored, non-drivable, VFX-free and lazily created.
- Runtime interiors unload after the final occupant leaves.

## Verification Boundary

Before handoff, require empty/full display assignment, duplicate rejection, replacement without vehicle deletion, save/rejoin, drive-in cancel/confirm, drive-out from both spaces, foot exit, death/reset/disconnect cleanup, owner/visitor permissions, internal HOME/Car/Race/Shop/Settings safety, PC/tablet/phone coverage and stable instance/connection counts over repeated entry.
