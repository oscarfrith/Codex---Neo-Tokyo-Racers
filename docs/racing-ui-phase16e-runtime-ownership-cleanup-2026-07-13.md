# Racing UI Phase 16E — Runtime Ownership Cleanup

Status: installed and confirmed on 2026-07-13. The user reported the driving lag was much better. Local course arrows required the Phase 16F StreamingEnabled cache repair, which was also confirmed.

## Purpose

Phase 16E removes the obsolete PC presentation owners that remained alive behind the approved Phase 4A and current Racing UI. This is a runtime cleanup, not a gameplay rewrite. It does not change Phase 8H reset, Phase 11Y finish cleanup, rewards, PB ownership, matchmaking, route progression, server collision proxies, or LOD.

Installer: `scripts/roblox_racing_ui_phase16e_runtime_ownership_cleanup.lua`

## Ownership changes

- Retires `RaceClient_Active`, `RaceSessionControlsClient_Active`, and `RaceHudExitCleanupClient_Active`.
- Replaces the large legacy `RaceEntryMenuClient_Active` with a headless event/action bridge. Vehicle spawning, entry handoff, race queue start, staged time-trial start, streaming handoff, and driving exit handoff remain.
- Moves legacy free-roam navigation, vehicle-exit, drive HUD, and mobile drive controls behind touch-only module loaders. Their UI, loops, and connections are not created on PC.
- Adds a tiny PC table proxy at the existing bootstrap drive-HUD constructor. This is the only bootstrap change.
- Removes construction of the old checkpoint badge while preserving local world route guidance and wrong-way logic.
- Removes the Phase 8H transition controller's repeated PlayerGui suppression pulse while retaining its reset/camera/fade ownership.
- Converts participant visibility from a render-step descendant sweep to event-driven state changes and descendant-added handling.
- Replaces browser/entry/results GUI suppression polling on PC with named `FreeRoamHudPresentationMode` ownership messages.
- Makes the current in-race HUD return immediately from its render callback when no racing session is active.

## Map and arrow rules

- Race HUD map presentation creates one `PlayerMarker`, owned by the local player.
- No opponent or other-player map marker is created or updated.
- Local authored route-arrow segments remain available.
- Visible arrow transparency uses `NTR_ArrowOriginalTransparency` when present and `0` otherwise. It never treats the currently hidden transparency as the visible fallback.
- Server collision proxies and route progression are unchanged.

## Install and verification

1. Open Studio in Edit mode.
2. Paste the entire Phase 16E installer into the Command Bar with `MODE = "INSTALL"`.
3. Stop and restart Play.
4. Verify free roam, Race Browser, both entry modes, vehicle selection, race/time-trial start, reset, exit confirmation, finish, results, retry, and exit-to-start.
5. In a two-player test, verify players only see their own map marker. Text standings may still list competitors.
6. Verify local course arrows are visible and only the required local segments appear.
7. Inspect `PlayerGui`: the approved Phase 4A/current Racing interfaces may exist, but the retired `NTR_FreeRoamLeftNav`, `NTR_FreeRoamVehicleExitButton`, `HOVER_RACING_V2_DriveHUD`, old race HUD, old checkpoint badge, old session controls, and old Phase 4 results UI must not be constructed on PC.
8. Confirm the previous periodic driving hitch is absent or materially reduced.
9. Return to Edit mode, set `MODE = "SMOKE"`, and rerun the installer.

If an anchor fails, do not write another guessed source repair. Refresh the mirror and inspect the named isolated controller. If two anchors fail, prefer a new canonical isolated replacement.
