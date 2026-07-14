# Mobile Free-Roam UI Phase 1H: Smaller Cards And Cash Fit

Date: 2026-07-13

## Outcome

Phase 1G looked better in the user's follow-up test, but the vehicle cards still needed to be substantially smaller and their internal rating/name content needed to scale with them. The mobile cash amount could also escape its intended area when the balance became long.

Phase 1H updates only the isolated canonical mobile HUD/control owners:

- changes the vehicle-card target width from `160` to `108`, approximately two-thirds of the Phase 1G size;
- keeps the `0.88` card aspect, producing a normal target card size of roughly `108 x 95`;
- proportionally reduces the tier/rating badge, rating text, vehicle-name range, fallback text, card stroke, Buy More plus, and Buy More label;
- keeps vehicle names on one self-fitting line with a `5-7 px` constraint;
- reserves `52 px` of the cash card for padding and the `+` button;
- scales cash text from `14 px` down to `5 px` inside the remaining width;
- enables clipping on the cash card as a final overflow guard.

It preserves Phase 1G's borderless menu/footer, approved gradients/dropdowns, same-field dropdown close, spawn/despawn behavior, outside-tap handling, and driving-input suppression. It does not patch the bootstrap, PC UI, server gameplay, driving physics, VFX, or LOD.

## Studio Install

Run the complete contents of this file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer requires live Phase 1G markers on both canonical mobile owners. If that preflight fails, stop and inspect/refresh the live Studio source rather than weakening the guard.

## Verification

In landscape Device Emulator and on the launched phone build:

1. Open the mobile car menu and confirm the cards are approximately two-thirds of their Phase 1G width and height.
2. Confirm the tier/rating badge, vehicle name, fallback label, and Buy More content all look proportionally smaller rather than crowded.
3. Confirm `BRUISER FORGE` and `PIERCER VIPER` still remain complete on one line.
4. Confirm at least two complete rows fit on short landscape screens; the reported `1350 x 613` viewport should fit about four complete rows.
5. Test a long cash balance and confirm it scales inside the area to the left of `+`, never overlaps the button, and never escapes the cash card.
6. Recheck dropdown open/close, scrolling, vehicle spawn/swap, Despawn, outside-tap close, blocked top-HUD actions, and driving UI restoration.

## Config And Rollback

The primary editable value remains:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.CarMenuTargetCardWidth = 108
```

The installer migrates only the known Phase 1G default of `160`; an intentionally customised value is preserved. Clean rollback is Studio version history or the confirmed Phase 1G source. Do not blindly rerun an older installer because phase preflight markers are intentional.

## Mirror Status

The repository mirror still contains Phase 1C mobile owners from `2026-07-13 15:33:06`, so it is stale for Phases 1D-1H. After installing and confirming Phase 1H, start:

```text
py scripts/receive_studio_full_snapshot_export.py
```

Then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar. Commit generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`, but never commit `docs/studio-full-export-paste.txt`.
