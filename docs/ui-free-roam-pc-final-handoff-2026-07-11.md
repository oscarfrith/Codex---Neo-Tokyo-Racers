# PC Free-Roam UI Final Handoff

**Date:** 2026-07-11  
**Status:** Phase 4A confirmed; mirror refreshed; Git pushed  
**Next focus:** Race/time-trial menus and prize presentation

Read the normal project startup documents first. This file is the compact handoff for the completed PC free-roam UI stream.

## Locked Baseline

Phase 4A is the current confirmed PC free-roam UI baseline:

```text
scripts/roblox_ui_freeroam_pc_phase4a_dealership_teleport.lua
```

It includes:

- responsive PC-only free-roam HUD and action bar;
- centred, responsive car menu with category/sort dropdowns;
- live speed arc and boost bar/icon driven by vehicle state;
- cash panel and shared modal styling;
- north-up four-tile 2D minimap with configurable zoom/calibration;
- transparent image-only player and north-arrow markers;
- shared dealership confirmation from the top action and Buy More card;
- isolated server-authoritative dealership teleport with cooldown, race guard, vehicle cleanup, and driving-exit handoff.

The live mirror contains:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active
ServerScriptService.NeoTokyoRacers.Services.UI.FreeRoamHudTeleportService_Active
ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.UI.FreeRoamHudTeleportInvoke
ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.FreeRoamHudTeleport
```

## Visual Rules To Reuse

The authoritative reference is `docs/ui-free-roam-pc-design-system-2026-07-10.md`.

- Magenta/pink: structure and navigation.
- Cyan/blue: selected, active, live, or confirm state; matching borders and glows must share the same colour.
- Red: destructive actions.
- Tier colours: informational rating/tier badges only.
- Use shared semantic typography groups and a small number of configurable layout/effect tokens.
- Neutral gradients may overlay button colours; do not hard-code a separate gradient palette for each button.
- Prefer scale-based responsive layout plus bounded pixel offsets and runtime absolute-coordinate diagnostics.

## Important Lessons

- Keep the canonical UI owner isolated; do not add large UI blocks to the register-limited bootstrap.
- Diagnose clipping/placement from runtime absolute bounds before adding another visual patch.
- Same-header dropdown clicks should toggle the dropdown closed, and only one dropdown should be open.
- Rotating large ImageLabel descendants did not clip reliably. ViewportFrame cropping worked but changed the supplied artwork and complicated coordinates. The accepted minimap is north-up; the canvas translates while the centre marker rotates.
- Map display scale, coordinate rotation, world origin, axis flips, marker assets, and marker sizes must remain independent config values.
- Gameplay actions such as dealership teleport belong behind an isolated server-authoritative remote/service rather than inside the presentation controller.

## Deferred Free-Roam Work

Later phases are intentionally paused. Do not treat them as blockers for racing UI:

- real Robux cash-product receipt handling;
- persisted graphics/lighting/settings behavior;
- any further free-roam visual polish not tied to a regression;
- broader device/mobile free-roam redesign.

## Rollback

The clean client rollback is:

```text
scripts/roblox_ui_freeroam_pc_phase3d_image_only_map_markers.lua
```

For a complete Phase 4A rollback, also disable `FreeRoamHudTeleportService_Active`. Phase 3D is the locked pre-teleport HUD baseline.

## Next Chat

The race/time-trial UI branch described here was completed and confirmed through Phase 16F. Start current Racing UI work from `docs/racing-ui-final-handoff-2026-07-13.md`; use `docs/racing-next-chat-handoff-2026-07-10.md` only for the locked Phase 11Z gameplay history. Phase 4A remains the visual/token baseline, while Phase 16E now owns the rule that obsolete PC presentation objects, loops, and connections are not constructed.
