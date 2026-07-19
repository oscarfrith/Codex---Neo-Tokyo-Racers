# Owned Garage Canonical Replacement Plan

Status: Phases 0-5 passed and are present in the refreshed `2026-07-19 12:14:59` mirror. Phase 6 atomic activation is generated and awaiting Studio execution and Play verification.

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
