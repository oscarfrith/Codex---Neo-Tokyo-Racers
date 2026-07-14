# Mobile Free-Roam UI Phase 1G: Compact Borderless Car Menu

Date: 2026-07-13

## Outcome

Phase 1G refines only the mobile free-roam car menu after launched-phone testing of Phase 1F. The phone test proved the menu flow and dropdown behavior work, but long vehicle names were clipped and the title, field captions, footer, and decorative borders consumed too much space.

The canonical installer now:

- keeps vehicle names on one line and scales them between `6` and `8` pixels with a `UITextSizeConstraint`;
- removes `MY VEHICLES` and the separate `CATEGORY` / `SORT` captions;
- moves the approved dropdown fields into a compact `28 px` top row;
- reduces the target card width from `180` to `160` while preserving the two-column, two-complete-row responsive solver;
- reduces the Despawn footer to `20 px`;
- removes the outer panel border/glow and Despawn border/glow;
- preserves the panel and Despawn gradients, card borders, PC-parity dropdown choice surface, same-field close toggle, outside-tap behavior, and all spawn/despawn contracts.

This is an isolated canonical owner replacement. It does not use fragile text replacement and does not edit the register-limited bootstrap, the PC HUD owner, driving physics, server gameplay, VFX, or LOD.

## Studio Install

In Roblox Studio Edit mode, run the complete contents of:

```text
scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua
```

The installer intentionally requires the live Phase 1F owner marker. If its preflight fails, stop and refresh/inspect the live Studio source rather than weakening the guard.

## Verification

Use landscape Device Emulator and then the launched phone build:

1. Open the car menu while walking and while driving.
2. Confirm `MY VEHICLES`, `CATEGORY`, and `SORT` captions are absent.
3. Confirm the two dropdown values sit at the top, retain the approved PC-like gradients, and tapping the already-open field closes its list.
4. Confirm `BRUISER FORGE` and `PIERCER VIPER` are each complete on one line; shorter names should remain larger.
5. Confirm two card columns and at least two complete rows fit without card/footer clipping, with cards visibly smaller than Phase 1F but larger than the rejected Phase 1E result.
6. Confirm the menu has no pink outer border/glow and Despawn has no border/glow, while the dark gradients remain.
7. Confirm Buy More, vehicle spawn/swap, scrolling, Despawn, outside-tap close, and driving UI restoration still work.
8. Confirm the top map/action/cash cluster stays visible but cannot be pressed while the menu is open.

## Config And Rollback

Phase 1G defaults live on `ReplicatedStorage.NeoTokyoRacers.Config.UI.MobileFreeRoamHud`:

- `CarMenuTargetCardWidth = 160`
- `CarMenuPanelPadding = 5`
- `CarMenuCardGap = 5`
- `CarMenuCardTopSafePadding = 3`
- `CarMenuCardBottomSafePadding = 3`
- `CarMenuHeaderHeight = 36`
- `CarMenuDropdownHeight = 28`
- `CarMenuDespawnHeight = 20`
- `CarMenuFooterGap = 3`

The installer migrates only known Phase 1F default values, so intentional manual tuning is preserved. The clean rollback is Studio version history or reinstalling the confirmed Phase 1F source. Do not rerun an older installer blindly after Phase 1G because the canonical preflight markers are intentionally phase-specific.

## Mirror Status

At generation time, the repository mirror still stops at Phase 1C (`2026-07-13 15:33:06`) and therefore appears stale for Phases 1D through 1G. After Phase 1G is installed and confirmed, refresh it by running the local receiver and then the Studio exporter:

```text
py scripts/receive_studio_full_snapshot_export.py
scripts/roblox_studio_export_full_snapshot_for_github_v2.lua
```

Commit generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`. Do not commit `docs/studio-full-export-paste.txt`.
