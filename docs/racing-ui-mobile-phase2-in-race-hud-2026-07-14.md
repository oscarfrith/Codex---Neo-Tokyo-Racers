# Mobile Racing UI Phase 2: In-Race HUD

**Date:** 2026-07-14  
**Status:** Installed and refined layout user-confirmed working; mirror refresh required  
**Installer:** `scripts/roblox_racing_ui_mobile_phase2_in_race_hud.lua`

## Scope

This phase reuses the confirmed PC Phase 16 in-race HUD objects and race-event data on touch devices. It does not rebuild lap, timing, PB, standings, reset, exit, or results behavior.

Touch layout:

- lap counter at the upper-left, below Roblox's built-in controls;
- current lap time or race position at the upper-centre;
- lap history plus PB, or multiplayer standings, at the upper-right;
- no race-map panel on touch;
- RESET above race EXIT near the bottom centre-left;
- race EXIT uses the mobile free-roam vehicle-EXIT region, shifted slightly left for the larger controls;
- RESET and EXIT use `126 x 48` reference-canvas buttons, exactly 1.5 times the initial `84 x 32`, with their shared centre moved farther left from the initial `800` to `700` and their vertical gap increased from `6` to `18`;
- the existing mobile speed, boost, arrows/thumbstick/tilt, boost control, accelerator, and brake remain in their confirmed positions.

The mobile free-roam HUD now honours the existing `KeepTelemetry` presentation contract. During an active session it keeps only bottom telemetry visible, hides its top map/navigation/cash, and hides the vehicle-exit action so the race EXIT can own that location.

## Configuration

The installer creates `ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.InRace.Mobile` with editable values for:

- top card positions and sizes;
- board size, rows, text, and avatars;
- reset/exit location, size, and gap.

Reruns preserve existing values.

The refinement upgrades only installer-created values that are still exactly at the initial defaults. Manually edited control values are preserved.

## Installation

1. Open Studio in Edit mode.
2. Paste the complete contents of `scripts/roblox_racing_ui_mobile_phase2_in_race_hud.lua` into the Command Bar with `MODE = "INSTALL"`.
3. Restart Play using a touch device or Device Emulator.
4. After visual and behavior checks, stop Play, change the script to `MODE = "SMOKE"`, and run it from the Edit-mode Command Bar.
5. Refresh the Studio mirror.

This is a guarded exact-source patch across two isolated controllers. It preflights every expected anchor in memory and assigns neither source until all anchors pass. If an anchor fails, do not attempt another guessed repair; refresh the mirror and inspect the live sources.

## Verification

- Start a multi-lap time trial and confirm LAP is upper-left, the running lap timer is upper-centre, and PB/lap rows are upper-right.
- Start a multiplayer race and confirm position replaces the timer while standings populate the upper-right board.
- Confirm no race map or free-roam map/navigation/cash appears during either session.
- Confirm the speedometer, boost bar, boost button, selected steering mode, accelerator, and brake are visually unchanged.
- Confirm race EXIT is in the old free-roam EXIT location and RESET is directly above it.
- Confirm tapping race EXIT opens the existing confirmation flow; confirm RESET retains the Phase 8H respawn behavior.
- Finish and exit both session types, then confirm the normal free-roam top HUD and vehicle EXIT return.
- Confirm no `NTR_RaceHud`, `NTR_RaceHud_Phase3`, old checkpoint badge, or old session-control HUD is visible.

## Rollback

The clean rollback is the immediately preceding Studio history version. Because this phase changes only two isolated UI controllers and a new config folder, it does not require reverting driving, VFX, server racing logic, rewards, PB persistence, route assets, or mobile input code.
