# Small Refinements: Lifecycle Phase 2 V1

**Status:** V1.3 confirmed/mirrored 2026-07-27  
**Lane:** Standard connected lifecycle/presentation change  
**Canonical installer:** `scripts/roblox_small_refinements_lifecycle_phase2_v1.lua`

## Acceptance contract

Goal: complete the four approved lifecycle/input/audio refinements without creating a second garage, camera, onboarding, input or audio owner.

Required behavior:

1. A seated player can drive into their owned garage at any speed. Existing ownership, garage capacity/replacement, streaming, despawn, assignment, rollback and teleport validation still run.
2. On mobile, walking inside the owned garage does not also rotate the garage preview camera.
3. Free-roam onboarding icon pages, objectives and guide trails never appear while first-drive Controls is opening, active or fading.
4. Loading reveals the already-prepared black first-drive Controls screen directly, with no intervening free-roam frame. `NEXT` fades to free roam, then releases ignition/idle and free-roam music/ambience through their existing owners.
5. Objective 2 enters and the Race shortcut prompt becomes eligible immediately after the Garage shortcut prompt is acknowledged. Objective 3 enters immediately after the Race shortcut prompt is acknowledged, even if Objective 2 is still active.

Preserved:

- Stable vehicle IDs, ownership, persistence, economy, slots and replacement confirmation.
- Vehicle spawn/despawn authority and rollback.
- Onboarding completion/seen-page persistence and all later manual Controls behavior.
- Driving physics, camera physics, audio assets/mix tuning, VFX, Race/Time Trial and the register-limited bootstrap.
- Touch devices do not receive the desktop first-drive Controls page under the current confirmed onboarding contract.

Done when the focused matrix passes without new Output errors and the full Studio mirror contains all six V1 markers, the onboarding V1.1/V1.2/V1.3 markers and `DriveInSpeedGateEnabled=false`.

## V1.3 sequence

```text
Successful first FreeRoamDrive spawn
  -> black Controls opens beneath loading
  -> loading releases directly to Controls
  -> all onboarding presentation remains blocked
  -> NEXT completes black fade
  -> input/audio and onboarding blocker release
  -> Vehicle shortcut prompt
  -> Garage shortcut NEXT
  -> Objective 2 enters and Race shortcut prompt becomes eligible
  -> Race shortcut NEXT
  -> Objective 3 enters alongside Objective 2
  -> either objective may complete independently
```

The existing `SeenPages.VehicleShortcut`, `SeenPages.GarageShortcut` and `SeenPages.RaceShortcut` fields are the persistent acknowledgements. V1.3 removes Objective 2 completion from Objective 3 eligibility, leaving `SeenPages.RaceShortcut` as its sequencing gate. It adds no saved field or migration.

## Ownership and state contract

| Concern | Owner | Phase 2 change |
|---|---|---|
| Garage entry transaction | `OwnedGarageManagementRuntime` | Existing speed rejection becomes opt-in; default is disabled. |
| Garage preview orbit | `PreviewCameraController` | Rejects/clears touch drag during physical garage walking. |
| One-time first-drive decision | `OnboardingClient_Active` | Acquires presentation gate and sends `{FirstDrive=true}`. |
| Controls geometry/fade | `DesktopFreeRoamHudController_Active` | Publishes Controls-open state, owns black backdrop/`NEXT`/fade/release. |
| Gameplay input | `GameplayInputGate` | Existing token API blocks and neutralises input; source is unchanged. |
| Vehicle presentation audio | `VehicleAudioController` | Observes gate; ignition and local layers remain silent until release. |
| Music/ambience | `ContextAudioController` | Observes gate; stops context channels and resolves again on release. |
| Saved onboarding state | Existing server onboarding owner | Unchanged. |

Temporary local attributes:

- `NTR_DrivingControlsOpen`: HUD-published visibility state used by onboarding suppression.
- `NTR_FirstDrivePresentationPending`: acquired by onboarding, released by the HUD after the fade, observed read-only by audio.

## Studio install

1. Stop Play.
2. Open the Studio Command Bar in Edit mode.
3. Paste and run the complete contents of `scripts/roblox_small_refinements_lifecycle_phase2_v1.lua` once.
4. Expect:

   `INSTALL PASS | restart Play, verify Race prompt Next immediately adds Objective 3 alongside Objective 2, then refresh the complete Studio mirror.`

The installer preflights exact source anchors, projects and compiles all six sources before mutation, applies one config attribute, audits the committed result and restores its complete mutation set on failure. It creates no backup objects.

## Focused verification

Use a fresh onboarding test profile for the first-drive checks.

### Owned garage entry

1. Drive into the owned garage slowly and confirm normal entry.
2. Repeat clearly above `5 MPH`; confirm the first press enters and no “Slow below 5 MPH” rejection appears.
3. With a full garage, confirm the existing replacement-space choice still appears and both cancel/confirm paths behave normally.
4. Confirm the vehicle is not duplicated and failure/teleport recovery still restores a usable vehicle.

### Mobile garage walking

1. Test a phone viewport with the supported Dynamic Thumbstick/movement setting.
2. Enter the owned garage on foot and walk using the left movement control.
3. Confirm the character moves while the camera does not receive an extra preview-orbit drag.
4. Open garage management and confirm its intended preview/workspace interactions still work.
5. Repeat after closing management and after leaving/re-entering the garage.

### First-drive Controls, onboarding and audio

1. On a fresh or Studio-replayed desktop profile, buy the first vehicle and begin driving in free roam.
2. Test once with a fast load and once with a deliberately slower load. Confirm loading goes directly to completely black Controls with `NEXT`, without one frame of the free-roam world/HUD.
3. Confirm no onboarding icon prompt, objective card or guide trail overlays Controls or its fade.
4. Hold movement/boost keys and confirm the vehicle does not move or consume hidden input.
5. Confirm no local ignition, idle/engine, acceleration, drift, boost, wind, free-roam music or ambience is audible behind Controls.
6. Select `NEXT`. Confirm black fades to free roam, then ignition plays once, idle follows, and free-roam music/ambience starts.
7. Confirm the Vehicle shortcut prompt appears only after the fade/close.
8. Complete the Vehicle prompt. Confirm Objective 2 is still absent until Garage shortcut `NEXT`.
9. Select Garage shortcut `NEXT`. Confirm Objective 2 enters and the Race shortcut prompt becomes eligible immediately, without waiting for Objective 2 completion.
10. Select Race shortcut `NEXT` before completing Objective 2. Confirm Objective 3 enters immediately and both Objective 2 and Objective 3 cards are visible.
11. Complete either objective first and confirm the other remains independently active.
12. Rejoin after each shortcut checkpoint and confirm only the correct next objective/page returns.
13. Open Controls manually later. Confirm it uses the normal dim backdrop and `DONE`, does not replay ignition, and does not invoke the first-drive audio gate.
14. Enter later vehicles, Race and Time Trial. Confirm their existing audio and presentation are unchanged.

### Lifecycle and diagnostics

1. Reset/respawn once during or immediately after the first-drive reveal and check for a stuck black screen, locked input or silent audio.
2. Check Output for installer/runtime errors and duplicate-controller warnings.
3. Run the same installer with `MODE="AUDIT"` if source/config proof is needed.

## Risks and rollback

- Source installation uses exact fragile text anchors. A preflight failure means the live source differs from the refreshed mirror; stop and refresh/inspect rather than weakening anchors.
- The direct handoff depends on the confirmed `FreeRoamVehicleSpawned` event occurring before `LoadingTransition Complete` for `Destination=FreeRoamDrive`; the refreshed mirror proves that ordering. The actively-driving check remains a fallback.
- The mobile camera repair targets the mirrored preview-camera listener. If movement still rotates the normal Roblox camera, record the exact Studio device, movement mode and camera mode before changing PlayerModule behavior.
- To roll back before confirmation, restore the pre-Phase-2 Studio version/history point. This is cleaner than a second patch because the installer spans six connected owners plus one config attribute.

## Mirror handoff

After successful Play verification:

1. Run `py scripts/receive_studio_full_snapshot_export.py` locally.
2. Run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar.
3. Confirm generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`.
4. Do not commit `docs/studio-full-export-paste.txt`.
