# Owned Garage Mobile Camera Guard V1-V2.2

**Status:** V1 confirmed; V1.1 broadly working; V1.2 runtime-failed; V2 confirmed; V2.1 geometry retained; V2.2 confirmed/mirrored 2026-07-27  
**Lane:** Standard camera/input lifecycle repair  
**Canonical installer:** `scripts/roblox_owned_garage_mobile_thumbstick_camera_guard_v1.lua`

## V2.2 compact contract

- **Goal:** preserve V2.1's improved visible-versus-empty regions while stopping actual native movement touches from rotating the camera.
- **Owners:** V2.1's shared workspace remains the unchanged geometry owner. `GarageInteriorModeController` remains the only physical-garage touch/camera lifecycle owner.
- **Touch states:** visible management UI becomes protected immediately; an empty touch in the broad native movement region becomes `PendingMovement`; post-Roblox evidence promotes it to protected movement; an unconfirmed candidate remains world/camera input.
- **Confirmation:** retain the exact `InputObject`, start position and pre-touch camera snapshot; check the dynamic marker after the synchronous input callbacks and once after Heartbeat; use a new public `Humanoid.MoveDirection` transition only as a bounded single-candidate fallback.
- **Camera behavior:** promotion restores the pre-touch orientation, follows humanoid translation and retains ownership through that input's End/Cancel. Empty camera/world input is never promoted after the `0.35 s` confirmation window.
- **Transitions:** confirmed movement/UI touches retain V2 close/exit protection. Pending touches are discarded at management close, owned-garage exit, respawn or camera replacement.
- **Preserved:** the V2.1 map, short/overflowing scrolling, all management pages, outside-management walking, native controls, PC, dealership/customisation, driving/racing, server state, remotes, persistence and economy.
- **Performance:** one deferred check, one bounded next-Heartbeat check and only candidate `InputChanged` checks before confirmation/expiry. The existing post-camera render binding runs only while a protected touch is held. No idle loop or hierarchy scan.
- **Tuning:** `MobileThumbstickSemanticConfirmWindowSeconds=0.35`, audit-clamped to `0.05-0.75`.
- **Rollback:** one exact V2.1 source-range projection compiles before assignment; the interior source and tuning attribute restore together on failure. After a successful install, use the pre-install Studio version/history point.
- **Confirmed result:** the user reported the combined behavior working well. Movement, empty-space regions and visible UI now coexist under the intended owners, and the complete `21:26:44` mirror contains V2.2 exactly.

## V2.1 compact contract

- **Goal:** keep confirmed V2 camera behavior while releasing every management region that contains no currently rendered UI.
- **Owners:** `GarageWorkspaceController` owns visible UI geometry, `OwnedGarageWorkspaceController` opts its complete page family into that map, and `GarageInteriorModeController` remains the physical-garage touch-lifetime owner.
- **Visible-surface contract:** only clipped rectangles for visible, non-transparent cards, buttons, panels, text, images, strokes and controls block. Hidden pages, disabled screens, transparent layout containers, fully transparent CanvasGroups and zero-area/clipped objects do not.
- **Scroll contract:** a non-overflowing category rail or bottom carousel disables only its empty scrolling shell; its rendered child cards remain normal controls. A genuinely overflowing scroller retains its complete gesture strip.
- **Movement contract:** management uses the actual visible `ThumbstickStart`; it never treats the oversized `DynamicThumbstickFrame` as movement territory. Outside management, V2's confirmed broad walking fallback remains.
- **Page/device scope:** all pages rendered by the owned-management workspace on landscape phones/tablets. PC and dealership/customisation preview input are preserved.
- **Performance:** the map rebuilds once after coalesced layout/content/visibility changes and stores rectangles. Touch classification is a bounded table pass. There is no idle frame work, recurring poll, per-touch hierarchy scan or whole-`PlayerGui` query.
- **Persistence/security:** N/A; no remote, saved data, economy, authority or server behavior changes.
- **Rollback:** all three projected modules compile before mutation; source/config snapshots restore together if committed audit fails. After a successful install, use the pre-install Studio version/history point.
- **Observed result:** installed V2.1 substantially improves visible-versus-empty hit behavior, but its synchronous `ThumbstickStart` check misses movement ownership and reintroduces camera pan. The complete `21:08:10` mirror is its exact installed state; V2.2 retains its geometry and supersedes only that timing rule.

## V2 compact contract

- **Goal:** preserve normal camera behavior in every physical-garage state, allow native pan on genuinely empty management space, and prevent movement/UI touches from rotating or contaminating the later free-roam camera.
- **State/camera owner:** `GarageInteriorModeController` remains the physical owned-garage lifecycle and native-camera guard owner. It classifies each touch once and retains that ownership through End/Cancel.
- **Geometry owner:** `OwnedGarageWorkspaceController` exposes one bounded read-only query against its own visible canonical root. It does not inspect unrelated `PlayerGui` surfaces.
- **Touch contract:** Dynamic Thumbstick and real management cards/buttons/panels/text/images hold camera orientation. Empty management space remains unguarded and uses normal native pan.
- **Scroll contract:** overflowing scrollers retain their gesture region; explicit category/carousel shells with short lists release unused space while their real cards and controls remain blocking.
- **Transition contract:** management close or on-foot garage exit does not hand an already-protected touch to CameraModule. Restoration occurs after the touch ends. A seat, race/garage session, replacement camera, character replacement or respawn still yields immediately to its current owner.
- **Shared preview preservation:** V1.2's owned-management state and geometry logic is removed from `PreviewCameraController`; dealership/customisation restore their confirmed pre-V1.2 classifier and pinch behavior.
- **Scope:** touch devices inside the physical owned garage. PC, server actions, remotes, persistence, economy, driving values and racing remain unchanged.
- **Performance:** one bounded GUI hit query only when a touch begins during management, plus one render binding only while at least one protected touch is held. No idle polling or whole-PlayerGui scan.
- **Rollback:** all three projected modules compile before assignment; the installer snapshots all three sources and relevant attributes and restores them together on failure. After a successful Studio install, use the pre-install Studio version/history point.
- **Done when:** the complete phone/tablet lifecycle matrix passes, empty-space pan is available, no touch contaminates free roam, PC/custom-preview regressions pass, and the complete mirror contains V2 plus its config state.

## Why V1.2 failed

The complete `2026-07-27 20:29:06` mirror contains V1.2 exactly, with 192 matching manifest, source-manifest and checksum entries. The mirror is current; the failure is behavioral.

V1.2 assumed that `PreviewCameraController` could arbitrate management touch. The mirror instead shows its only `BindInput` consumer is `ModuleShopUIController`, with an active predicate scoped to that controller's own browser/workspace instances. Physical owned-garage management creates a separate workspace and continues using Roblox's native humanoid camera.

Removing V1.1's full-root `Active` sink therefore exposed the original native CameraModule/Dynamic Thumbstick overlap. V1.2's content-aware preview hit test could not reliably stop it, and a held touch could cross the management/exit boundary before camera recovery.

V2 fixes the ownership boundary rather than adding another sink or preview-camera patch.

## V1.2 historical contract — runtime-failed

- **Goal:** retain V1.1 Follow/recovery while allowing camera pan over genuinely empty owned-management space.
- **Owner:** the existing shared `PreviewCameraController` remains the only preview-input owner; `OwnedGarageWorkspaceController` retires its temporary full-root sink.
- **Blocking contract:** buttons, text boxes, explicitly active controls, visible panel/text/image surfaces and overflowing scrollers block camera drag and pinch.
- **Empty-space contract:** transparent layout containers and unused portions of non-overflowing left/bottom scrollers permit camera pan; visible child cards still block.
- **Scope:** content-aware classification applies only on touch while inside owned-garage management. Dealership/customisation and desktop retain the existing classifier.
- **Performance:** one bounded `GetGuiObjectsAtPosition` ancestry pass when a preview drag begins; no frame loop, polling or layout scan.
- **Security/data/streaming:** N/A; no remote, saved schema, authority, world object or persistence change.
- **Rollback:** both projected sources compile before assignment; the installer snapshots both sources and both relevant attributes and restores them together on failure.
- **Done when:** empty, short-list and overflowing-list regions behave according to the contract across phone/tablet, with V1/V1.1 and PC/custom-preview regressions passing.

This contract was disproved by runtime evidence and is superseded by V2. Do not extend or recover its preview-camera interception.

## V1.1 compact contract

- **Goal:** preserve the confirmed physical-garage walking hold while preventing management UI touch from moving the camera and restoring normal recentering after management/free-roam transitions.
- **Owners:** `StarterPlayer.DevTouchCameraMovementMode` owns the native touch preference; `OwnedGarageWorkspaceController` owns touch containment for its visible root; `GarageInteriorModeController` owns bounded transition recovery.
- **Inputs/outputs:** touch-device capability plus existing inside, management, garage/race-session, character, seat and `CurrentCamera` state; output is only camera preference/input containment/subject-type restoration.
- **Lifecycle:** management open cancels pending recovery and consumes background touch; management close, foot exit, respawn and camera replacement queue a two-Heartbeat revalidated recovery; seated, active garage-session and race-session states yield to their current owners.
- **Preserved:** V1 movement guard, Dynamic Thumbstick, intentional Scriptable previews, vehicle driving camera, PC camera, server actions, remotes, persistence, economy and garage content.
- **Scale/performance:** two existing source owners and three config/property values; event-driven with no idle frame loop or hierarchy scan.
- **Security/data/streaming:** N/A; this is local presentation/input state with no remote, saved schema, authoritative mutation or streamed-world dependency.
- **Rollback:** the installer snapshots both sources, all three attributes and the native touch property and restores them on failure; after a successful install use the pre-install Studio version/history point.
- **Done when:** the phone/tablet transition matrix passes, PC and custom-preview behavior remain unchanged, and the complete mirror contains both V1.1 markers and all values.

## Evidence and root cause

The live touch audit reproduced the defect with:

- `NTR_OwnedGarageInside=true`;
- `NTR_OwnedGarageManagementOpen=false`;
- `CurrentCamera.CameraType=Custom`;
- `CameraSubject` equal to the local humanoid;
- the touch physically intersecting `TouchGui.TouchControlFrame.DynamicThumbstickFrame`;
- `gameProcessedEvent=false`.

Disabling the complete onboarding GUI and rebinding PlayerModule controls did not change the defect. This rules out onboarding, Follow camera mode, the custom garage preview camera and a stuck PlayerModule enable/disable state.

The remaining behavior is Roblox's normal CameraModule consuming the same unprocessed left-thumb touch that Dynamic Thumbstick uses for movement, specifically after entering the physical owned-garage lifecycle.

## Ownership and behavior

`GarageInteriorModeController` already owns the physical owned-garage client lifecycle and observes the authoritative inside/management state. V1 extends that existing owner rather than adding another controller.

On touch devices only, a touch beginning inside `DynamicThumbstickFrame` while physically inside the owned garage and outside management temporarily:

1. snapshots the normal camera type, subject, orientation and humanoid-relative offset;
2. switches the camera to `Scriptable`;
3. follows humanoid translation at post-camera render priority without accepting rotation from that movement touch;
4. restores the original camera type and subject immediately when the touch ends or is cancelled.

The guard also releases on management open, owned-garage exit, respawn or `CurrentCamera` replacement. A left/lower-screen fallback supports Dynamic Thumbstick hierarchy timing before its frame resolves.

The tradeoff is intentional: while the left movement thumb is held inside the owned garage, simultaneous second-finger camera rotation is held. Releasing the movement thumb immediately restores normal touch camera control.

## Preserved

- Roblox Dynamic Thumbstick remains the movement owner.
- Roblox CameraModule remains the normal camera owner outside the guarded movement touch.
- Right-side camera drag works whenever the movement thumb is not held.
- Garage management, preview camera, access HUD, onboarding, driving, racing, server state, persistence and economy are unchanged.
- No new Script, ModuleScript, remote, saved field, frame loop while idle or in-game backup object is created.

## V2.2 verification

1. On a landscape phone, enter the owned garage and walk with Dynamic Thumbstick. The character must move while yaw/pitch remain fixed.
2. Release movement, then swipe an empty world region. Native camera pan must work normally.
3. Open management. Touch and hold the thumbstick briefly before moving, then move immediately on a second attempt. Both must move the character without rotating or visibly jumping the camera.
4. On every management page, drag across each actual card, button, visible panel, text box, header, economy/navigation surface and modal. UI behavior must work and camera yaw/pitch must remain fixed.
5. On every page, drag over genuinely empty central/right/left/bottom space, including the marked regions beside the short left rail and bottom carousel. Player movement/camera pan must work.
6. Test a short category rail and short bottom carousel. Their unused regions must move/pan; their real cards remain clickable and must not rotate the camera.
7. Test overflowing left and bottom lists. Scrolling and card selection must work without rotating the camera.
8. While walking, add a second empty-space camera touch. Retain the documented V2 behavior: the camera remains held until the movement touch releases, then normal pan returns immediately.
9. Hold Dynamic Thumbstick while closing management. Continue holding briefly, release, then confirm free-roam/garage walking camera behavior is normal.
10. Hold a protected management UI touch while triggering an available close/exit transition. After release, confirm `Custom` plus the correct humanoid subject and normal right-drag.
11. Drive out, walk in free roam, rotate camera, enter a vehicle and drive. No stuck Scriptable camera or movement-driven pan may remain.
12. Re-enter management, close it, exit/re-enter the garage and respawn once.
13. Repeat the focused matrix on a landscape tablet/iPad profile. On PC, confirm management, dealership and customisation mouse camera behavior is unchanged.
14. Hide/replace a page and confirm none of its invisible former surfaces block the current page.
15. Output must contain both `[NTR Owned Garage Mobile Camera Guard V2.2] AUDIT PASS` and `INSTALL PASS` from installation and no runtime errors.

## Risks and rollback

The installer replaces one exact unique V2.1 range in the existing interior controller. It compiles the projection before assignment and restores the prior source/config if audit fails.

V2.2 still uses the public runtime `TouchGui` marker as its primary post-input ownership evidence, but no longer requires it synchronously. If Roblox changes that hierarchy completely, the bounded `Humanoid.MoveDirection` transition remains as fallback; the combined stationary-then-move and simultaneous-touch checks must remain release regression.

Roblox currently allows interactive children inside a non-scrolling `ScrollingFrame`. Verify that category and vehicle cards remain clickable after their short parent scroller disables shell input. If Studio behavior differs, repair this same installer with compact interaction bounds rather than restoring the full invisible rectangle.

After a successful installation, restore the pre-install Studio version/history point for rollback.

## Mirror handoff

V2.2 is installed and user-confirmed in the complete `2026-07-27 21:26:44` / 192-source mirror. The exported manifest, source manifest and checksums agree with zero mismatches. The installed arbitration block matches the canonical installer byte-for-byte, both V2.1 visible-surface owners remain present and `MobileThumbstickSemanticConfirmWindowSeconds=0.35` is captured.

No Studio command or mirror refresh is pending for ordinary use. Retain the canonical installer for exact-scope audit/recovery and keep the complete V2.2 verification matrix as release regression. Continue committing generated mirror changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`; do not commit `docs/studio-full-export-paste.txt`.
