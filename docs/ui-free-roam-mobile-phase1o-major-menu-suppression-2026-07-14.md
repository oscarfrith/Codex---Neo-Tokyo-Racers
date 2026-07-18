# Mobile Free-Roam UI Phase 1O: Major Menu Suppression

**Date:** 2026-07-14  
**Status:** Installed and user-confirmed working; mirror refresh required  
**Installer:** `scripts/roblox_ui_freeroam_mobile_phase1o_major_menu_suppression.lua`

Phase 1O gives mobile major menus one consistent presentation boundary without rebuilding or resizing them.

The user confirmed the completed suppression works well. Preserve this as the current mobile major-menu ownership baseline.

## Behaviour

- Opening Settings, Get Cash, or the dealership teleport confirmation hides the mobile navigation, map, cash card, toast, speed/boost telemetry, Exit button, steering/drift controls, boost, accelerator and brake.
- The modal and its shade remain visible because they live inside the free-roam HUD `ScreenGui`.
- The independently-owned vehicle-control `ScreenGui` reads `NTRMobileMajorMenuOpen`, hides its root and releases any held steering, drift, boost, throttle or brake input once when blocked.
- Closing the popup clears the flag and the existing driving/on-foot state restores the correct HUD automatically.
- Mobile Race Browser and Entry retain their existing full-screen `ScreenGui` suppression, which disables both free-roam owners; the control owner also treats its disabled `ScreenGui` as a block so held inputs release immediately.
- PC UI, car-menu presentation, racing layouts, control geometry, assets and gameplay actions are unchanged.

## Verification

1. Run `INSTALL` in Edit mode and restart Play in a touch device profile.
2. While driving, open Settings, Get Cash and the dealership confirmation in turn. Confirm only the popup/shade remains and every vehicle control disappears.
3. Hold Accelerator or a steering control, then open a popup. Confirm input releases immediately and the vehicle does not keep accelerating or turning.
4. Close each popup and confirm the correct driving HUD and controls return.
5. Open Race Browser and each Race/Time Trial Entry submenu. Confirm no map, cash, navigation, telemetry or vehicle controls remain underneath.
6. Confirm the mobile car menu retains its previously approved top HUD behaviour.
7. Run `SMOKE`, then refresh the full Studio mirror.

## Risk And Rollback

The installer uses two guarded exact replacements in the isolated mobile HUD owner and one in the isolated mobile control owner. All replacements are preflighted in memory before either source is assigned. On an anchor failure, stop and refresh the mirror. Rollback is the immediately preceding Roblox Studio history version.
