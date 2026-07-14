# Mobile Free-Roam UI Phase 1I: Guaranteed Three Card Rows

Date: 2026-07-13

## Root Cause And Outcome

The Phase 1H screenshot showed two complete card rows and a large unused region above Despawn. Reducing only `CarMenuTargetCardWidth` was insufficient because the responsive height solver still used `CarMenuVisibleRows = 2`, so it was allowed to preserve two-row card dimensions.

Phase 1I changes the actual responsive contract:

- `CarMenuVisibleRows = 3` makes the solver reserve three complete rows between the dropdown header and Despawn;
- `CarMenuTargetCardWidth = 92` produces approximately `92 x 80` cards when space allows;
- short landscape screens can reduce cards to approximately `86 x 75` to keep the third row complete;
- rating badges, names, fallback text, card strokes, and Buy More content scale down with the cards;
- the Phase 1H bounded/scaling cash-value fix remains unchanged.

The two-column grid, scrolling, gradients, dropdown behavior, borderless panel/footer, spawn/despawn actions, outside-tap behavior, and driving-input handoff remain unchanged. This is a canonical replacement of the isolated mobile owners, not fragile text replacement, and does not touch the bootstrap, PC UI, gameplay services, physics, VFX, or LOD.

## Studio Install

Run the complete contents of this file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer requires live Phase 1H markers. If preflight fails, stop and inspect/refresh the live Studio source rather than weakening the guard.

## Verification

In the same landscape viewport as the supplied screenshot:

1. Populate or own enough vehicles to create at least three grid rows.
2. Confirm three complete rows fit between the dropdowns and Despawn without clipping.
3. Confirm the third row remains fully visible on a short landscape emulator.
4. Confirm the tier/rating badge and vehicle names remain readable and inside each card.
5. Confirm `BRUISER FORGE` and `PIERCER VIPER` remain complete on one line.
6. Recheck scrolling with more than three rows, dropdown close/switch, spawn/swap, Despawn, outside-tap close, cash fitting, blocked top-HUD actions, and driving UI restoration.

Note: the supplied account currently shows only Buy More plus two vehicles, which naturally creates two occupied rows in a two-column grid. The three-row guarantee controls how many rows can fit before scrolling; testing it visually requires at least five vehicle cards plus Buy More, or equivalent test data.

## Config And Rollback

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.CarMenuVisibleRows = 3
ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud.CarMenuTargetCardWidth = 92
```

Only known Phase 1H defaults (`2` rows and `108 px`) migrate automatically. Intentional custom values remain untouched. Clean rollback is Studio version history or the Phase 1H canonical source.

## Mirror Status

The repository mirror still contains Phase 1C mobile owners from `2026-07-13 15:33:06`, so it is stale for Phases 1D-1I. After Phase 1I is installed and confirmed, start `py scripts/receive_studio_full_snapshot_export.py`, then run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in Studio. Never commit `docs/studio-full-export-paste.txt`.
