# Loading System Phase 6 Closure Handoff

**Status:** COMPLETE - user reports expected read-only audit outcome and manual closure behaviour  
**Mirror:** `2026-07-21 10:48:31`, 163 scripts  
**Read-only audit:** `scripts/roblox_ui_loading_phase6_readonly_audit.lua`  
**Working source baseline:** `NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_2_CONFIGURED_BUTTON_POSITION` plus `NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_4_GRID_FETCH_STATUS`

## Outcome And Scope

Phase 6 closes the approved loading/start-screen system. It does not install another controller or alter presentation. The fresh mirror confirms the working V1.3 start client, V1.4 Grid3x2 view, catalogue/runtime/input/audio owners, responsive config attributes, Phase 1-4 transition bridges and four race-readiness markers. The user subsequently reported that everything works as expected, closing the static and manual verification gates.

The only Studio command produced for Phase 6 is read-only. It compiles source without executing it, checks exact marker uniqueness, validates hierarchy/config/artwork/audio contracts and creates no Instances. Manual Play evidence remains necessary for lifecycle, device, input, audio and performance behaviour that a static mirror cannot prove.

## Fresh Mirror Evidence

- `ReplicatedFirst.NTRLoading` contains exactly the four expected sources in the exported manifest.
- `InitialLoadingAndStartScreenClient` is enabled, 331 lines / 13,856 bytes, checksum `303682342`, with configured-position V1.2 source.
- `LoadingScreenView` is 315 lines / 16,140 bytes, checksum `215716094`, with V1.4 per-tile fetch-status promotion.
- Loading config contains 36 attributes, including desktop `0.82`, landscape-phone `0.84`, portrait `0.80`, two grid attempts, `0.25`-second retry and three-second render deadline.
- All six tile folders and the single-image fallback remain present.
- All Phase 1-4 loading integration markers and all four `NTR_RACING_STAGING_READINESS_GATE_V1` sources are present.
- The exporter scans `ReplicatedFirst`, `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`, `StarterGui`, `Workspace`, `ServerStorage` and `Lighting`; it does not scan `SoundService`. The live read-only audit therefore verifies the six sound groups directly in Studio.

## Accepted Non-Blocking Baseline

- `MinimumVisibleSeconds=1.2` is now accepted as the confirmed live baseline because the user approved the resulting experience after Phase 6 verification. Future tuning remains config-only.
- `LoadingMusicAssetId` is blank by design. Short transitions remain silent. This warning does not block closure.
- Play/Shop icon IDs are blank unless final uploaded icons have been assigned. Blank icons are supported and do not consume layout space.

## Studio Audit - Complete

Run the complete `scripts/roblox_ui_loading_phase6_readonly_audit.lua` in the Studio Command Bar in Edit mode.

Expected result:

```text
[NTR Loading Phase 6 Audit] SUMMARY: ... PASS / 0 FAIL / 2 WARN
[NTR Loading Phase 6 Audit] STATIC PASS WITH WARNINGS: review the warnings, then proceed with the manual Phase 6 matrix.
```

The user reported the expected working outcome. The two accepted warnings are the `1.2` minimum and blank music. Preserve the audit for future regression checks; any future failure remains a hard stop rather than authorization to rerun an installer.

## Manual Play Matrix - Complete

### Initial Screen And Devices

- Fresh join on wide desktop: full-bleed tiled artwork, smooth progress, only PLAY/SHOP, row at desktop `0.82` and no world/HUD flash.
- Landscape phone: compact horizontal `188x40` pair at configured `0.84`, fully inside the device-safe area.
- Portrait phone: compact vertical `190x40` pair at configured `0.80`, fully clear of cutout/home-indicator areas.
- Tablet/narrow portrait: vertical `240x48` pair using the shared portrait value and safe clamp.
- PLAY releases through the `0.3`-second fade. SHOP remains covered until authoritative dealership placement succeeds.

### Included Transitions

- Free-roam SHOP to dealership on foot and while driving.
- Dealership/customisation entry and Drive exit.
- Owned-garage browser/drive-in and successful drive-out.
- Race-browser relocation to start, selected Time Trial start, and multiplayer post-queue staging.
- Active race/Time Trial exit and finished-results Exit to Start.
- Confirm destination UI becomes visible beneath the fading loading layer, input stays neutral while covered and gameplay audio returns after release.

### Explicit Exclusions

- Race/Time Trial reset.
- Ordinary vehicle spawn, despawn, selection or replacement.
- Queue waiting.
- Retry/Race Again and non-relocating results presentation.

None of these should create a loading screen.

### Failure And Repetition

- Exercise one cooldown/rejection path and confirm the prior UI, HUD, input and audio state return.
- Hold throttle/steering/boost across fade completion; controls must wait for neutral and then recover without braking or anchoring vehicle momentum.
- Complete ten mixed successful/rejected transitions. Confirm no duplicate loading UI, runtime sound, stuck presentation owner, retained input token, audio duck or missing HUD.
- Temporarily test one invalid tile only if safe to do so, then restore it. The single fallback must remain visible and Output must identify the failed tile/status rather than exposing black or a partial grid.

### Performance

- Test one lower-end phone/device-emulator profile after a clean Play start.
- Watch the first tile promotion and ten repeated transitions for large hitches, worsening texture memory, seams or progressive frame loss.
- A first-use fetch cost is acceptable; sustained growth or worsening transition cost is not. Keep `WarmPoolSize=1` and do not add a second artwork until this passes.

## TeleportGui Decision

Do not add `TeleportGui` now. Every currently covered transition is an in-place experience handoff under the existing teleport/placement owners, and the fresh mirror represents one PlaceId. Add cross-place loading ownership only when a second published PlaceId becomes part of a real dealership/garage/race flow. At that point, the current artwork catalogue and presentation can be reused, but Roblox teleport failure/rejoin ownership requires a separate contract.

## Closure And Rollback

Phase 6 is complete: the user reports the expected audit and manual behaviour, and the result is recorded in the main docs. No further Studio mutation or mirror refresh is needed for the read-only audit itself.

If a regression is isolated to start-button placement, restore only `InitialLoadingAndStartScreenClient` from the prior `10:17:35` mirror/Studio history. Do not revert the confirmed V1.4 view or unrelated systems. If Grid3x2 promotion regresses, retain the fallback and restore only `LoadingScreenView`; do not remove tile IDs or patch the transition runtime.

After closure, delayed loading music and a second catalogue artwork are separate optional enhancements, in that order.
