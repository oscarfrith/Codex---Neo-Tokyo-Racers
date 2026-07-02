# Persistence/Garage Phase 17 UI Handoff

**Created:** 2026-07-02  
**Status:** Studio mirror refreshed; next repair script prepared for Studio testing.

## Why This Handoff Exists

The Persistence/Garage Phase 17 module picker is mostly working, but the BUY/LOCKED/EQUIP action button has been through several small patches that started trading one regression for another:

- when parented to the selected card, the action button centred correctly but module cards could spill outside the bottom carousel frame;
- when the carousel clipping was restored, the action button became offset from the selected card again;
- the register-safe tracker and destroyed-popup repairs fixed separate runtime errors but did not produce a stable visual result;
- the final action-rail workaround kept the carousel clipped but placed the action button in the centre above the module frame, which the user does not want.

The user wants the action button directly above the module card they clicked, with a small gap matching the Paint Cockpit primary/secondary/detail button spacing. The module carousel must stay clipped inside the bottom frame and must not overlap the cash panel or the right-side controls.

## Current Live Studio State

The refreshed Studio mirror includes `scripts/roblox_persistence_phase17_module_popup_action_rail_repair.lua`, because the user reported the BUY/LOCKED button is now centred in the screen/frame instead of above the clicked card. Treat that as a rejected workaround, not the desired baseline.

The next prepared repair after the card-tracked overlay diagnostic is:

```text
scripts/roblox_persistence_phase17_module_popup_anchor_target_repair.lua
```

It replaces the card-tracked overlay helper with explicit selected-card popup anchors. After running and play-testing it in Studio, refresh the mirror again with `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` and commit the generated `roblox/exported_scripts/` and `roblox/studio_snapshot/` changes. Do not commit `docs/studio-full-export-paste.txt`.

## Confirmed Working Progress To Preserve

- Persistence Phases 1-5 established the profile schema, ProfileService dry-run/DataStore flow, legacy mapper, mirror bridge, and save/load path.
- Persistence Phases 6-13 added two starting cockpit spaces, physical garage-property purchases, `Buy More` garage gallery, owned property data, and capacity from purchased garages.
- Persistence Phases 14-15 added instance-backed duplicate cockpit/module ownership so owning one module copy only lets one cockpit use that copy.
- Persistence Phase 16 added source-cockpit purchase locks, starter module sets attached to purchased cockpits, paid extra Standard module copies, and owned/unlocked/locked module sorting.
- Persistence Phase 17 added owned-vs-buy module tabs, separate owned module copy cards, front/rear engine filtering, BUY/EQUIP wording, locked preview behavior, restored H/S/B sliders, front-engine family catalog repair, module card text polish, locked-card colour polish, and drive handoff recovery.
- Dealership and customisation were reported working before the remaining action-button placement issue.
- Paint Cockpit Back is hidden after buying/selecting a cockpit, so players must continue to Build Modules and spawn rather than returning to the dealership list.

## Current Unresolved UI Issue

In Build Modules, when the user clicks a module card in `BUY MODULES` or `OWNED MODULES`:

- the action button should show `BUY`, `LOCKED`, or `EQUIP` based on the selected card;
- it should appear directly above that selected card, not centred in the screen or frame;
- it should stay horizontally centred over the selected card even after scrolling;
- it should sit just above the bottom module frame with a small gap;
- it should hide when the player scrolls the carousel, presses previous/next arrows, changes stage, presses Back/Next, or when the card list rerenders;
- module cards must remain clipped inside the carousel frame.

## Recommended Technical Direction

Do not continue adding coordinate patches on top of the rejected action rail. Replace the action-rail helper with one clean card-tracked overlay owner.

Preferred robust fix:

1. Keep the module cards inside a clipped `ScrollingFrame`.
2. Keep the action button outside the clipped card container on a stable overlay layer.
3. On card click, store the actual selected card object and the selected action data.
4. Position the overlay button each rendered frame from the selected card's `AbsolutePosition` and `AbsoluteSize`, but only while that exact card is still parented and visible inside the carousel.
5. Clamp the popup to the visible carousel bounds so it cannot overlap the cash panel or right controls.
6. Hide the popup on any carousel scroll, page arrow click, card pool begin/rerender, stage change, Back/Next, or if the selected card is destroyed/recycled.
7. Put helper functions on the existing `NTRPersistencePhase15` table or a small ModuleScript/controller to avoid the active bootstrap's 200 local-register limit.

If this still fights the giant bootstrap, the cleaner future-proof step is to extract Build Modules card rendering and action placement into a dedicated client controller ModuleScript, then leave the bootstrap with a small bridge. That is safer for mobile and future module customisation than repeated source text patches against the large bootstrap.

## Scripts In This Popup Repair Sequence

These scripts are useful history/recovery references, but they should not be blindly rerun as the current baseline:

- `scripts/roblox_persistence_phase17_module_popup_anchor_target_repair.lua` - current prepared next fix after diagnostic showed `dx=-47.3` and `gap=57.5`.
- `scripts/roblox_persistence_phase17_module_popup_alignment_diagnostic.lua` - read-only Play-mode measurement script; rerun after the anchor-target repair and expect `dx` near 0 and `gap` near 6.
- `scripts/roblox_persistence_phase17_module_popup_card_tracked_overlay_repair.lua` - restored carousel clipping but still produced offset/high popup placement in Studio.
- `scripts/roblox_persistence_phase17_module_popup_position_and_cockpit_back_lock.lua`
- `scripts/roblox_persistence_phase17_module_popup_screen_layer_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_card_anchor_repair.lua`
- `scripts/roblox_persistence_phase17_cockpit_paint_stage_scope_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_card_child_repair.lua`
- `scripts/roblox_persistence_phase17_module_carousel_clip_popup_overlay_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_tracker_layer_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_tracker_register_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_destroyed_instance_repair.lua`
- `scripts/roblox_persistence_phase17_module_popup_action_rail_repair.lua`

The action-rail script is specifically rejected by the user as the final UX because it centres the action button above the module frame instead of above the clicked card.

## Suggested New Chat Opening

Use this prompt in the next chat after refreshing the mirror:

```text
We are continuing Neo Tokyo Racers Persistence/Garage Phase 17. Read AGENTS.md, docs/00_START_HERE.md, docs/04_customisation_ui.md, docs/06_current_known_issues.md, docs/07_patch_history.md, docs/10_script_source_sync_workflow.md, docs/11_manual_script_copy_map.md, and docs/persistence-garage-phase17-ui-handoff-2026-07-02.md.

The current unresolved issue is the Build Modules BUY/LOCKED/EQUIP action button. The user wants it directly above the clicked module card, with the carousel cards still clipped inside the bottom module frame. The latest action-rail workaround is rejected because it centres the button above the frame/screen. Work from the freshly exported Studio mirror, not from old line-number assumptions, and prefer a robust controller/helper approach over another fragile coordinate patch.
```

## Verification For The Next Fix

After the next repair, verify:

- select a buyable module card near the left, middle, and far right of the carousel; BUY appears centred above each clicked card;
- select a locked module card near the left, middle, and far right; LOCKED appears centred above each clicked card;
- scroll while the popup is visible; the popup hides;
- press previous/next arrows while the popup is visible; the popup hides;
- module cards never overlap the cash panel or the right-side Customise/Back buttons;
- Paint Cockpit still has no Back button and Next still moves to Build Modules;
- Start Driving still spawns a hovering, driveable vehicle.
