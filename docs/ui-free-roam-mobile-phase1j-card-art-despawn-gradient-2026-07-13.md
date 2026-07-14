# Mobile Free-Roam UI Phase 1J: Card Art And Despawn Gradient

Date: 2026-07-13

## Outcome

The user confirmed the Phase 1I three-row card layout looks great. Phase 1J makes the final two requested presentation adjustments without changing layout or behavior:

- vehicle artwork starts at `13%` of card height instead of `8%`, moving it down by roughly four pixels on a `92 x 80` target card;
- fallback `HOVERCAR` artwork text moves by the same amount;
- the existing background-only Despawn gradient is retained and strengthened to `0.72` overlay transparency so it reads clearly;
- the Despawn border and glow remain removed.

The three-row solver, card dimensions, badge/name positions, cash containment, dropdowns, gradients, spawn/despawn behavior, outside-tap handling, and driving-input handoff remain unchanged. This is a canonical replacement of the isolated mobile owners and does not patch the bootstrap, PC UI, gameplay, physics, VFX, or LOD.

## Studio Install

Run the complete contents of this file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer requires live Phase 1I markers. If preflight fails, stop and inspect/refresh the live Studio source.

## Verification

1. Confirm each vehicle image sits slightly lower inside its card without touching the vehicle name.
2. Confirm tier/rating badges remain in the top-right and are not displaced.
3. Confirm fallback `HOVERCAR` text follows the same lower artwork position.
4. Confirm Despawn has a visible top-to-bottom surface gradient but still has no border or glow.
5. Recheck three complete rows, scrolling, dropdowns, cash fit, spawn/swap, Despawn, outside-tap close, and driving UI restoration.

## Config And Rollback

Editable attributes under `ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud`:

```text
CarMenuVehicleImageYOffset = 0.13
CarMenuDespawnGradientTransparency = 0.72
```

Increase the image offset slightly to move artwork lower. Increasing gradient transparency makes the Despawn gradient subtler; decreasing it makes the overlay stronger. Clean rollback is Studio version history or the confirmed Phase 1I canonical source.

## Mirror Status

The repository mirror still contains Phase 1C mobile owners from `2026-07-13 15:33:06`, so it is stale for Phases 1D-1J. After confirming Phase 1J, start `py scripts/receive_studio_full_snapshot_export.py`, then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Studio. Never commit `docs/studio-full-export-paste.txt`.
