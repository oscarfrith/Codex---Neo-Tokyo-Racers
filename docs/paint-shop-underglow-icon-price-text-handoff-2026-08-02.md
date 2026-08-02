# Paint Shop Underglow Icon And Price Text Handoff

**Date:** 2026-08-02  
**Status:** Installed, user-approved for handoff, and fully mirrored

## Locked baseline

The complete Studio export generated at `2026-08-02 11:29:51` is the authoritative baseline for this refinement. `roblox/exported_scripts/manifest.json`, `roblox/studio_snapshot/source_manifest.json`, and `roblox/studio_snapshot/checksums.json` each contain 193 source records with zero checksum mismatches.

Installed source ownership is intentionally limited to:

- `GarageReplacementComponents`: one shared `TextOnlyPrice` presentation branch;
- `GarageWorkspaceController`: forwards `row.BadgeStyle` as `RatingStyle`;
- `ModuleShopUIController`: sidebar-only icon lookup plus cosmetic/neon opt-in.

The live sidebar config is:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.NavigationIcons.UnderglowSidebarIcon
```

The mirrored value is `132867231924801`; the existing image normaliser converts a numeric string into `rbxassetid://132867231924801` at render time.

The bottom purchase-card artwork remains independently owned by:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.VehicleCosmetics.Underglow.Icon
```

Its mirrored value remains `rbxassetid://87739019174785`.

## Preserved contracts

- Affordability still reads current profile Cash and the existing authoritative price.
- Unowned vehicle-cosmetic and module-neon prices alone use plain top-right heading text: green when affordable and red when unaffordable.
- `OWNED`, locked, equipped, level, rating and unrelated garage badges retain their existing renderers.
- Purchase remotes, server validation, prices, Cash mutation, cosmetic ownership, persistence, layout ownership, gameplay and VFX are unchanged.
- No in-game backup object or second UI renderer was created.

## Recovery

Retain `scripts/roblox_ui_paint_shop_icon_price_text_refinement_v1.lua` as the only exact-scope installer/audit/rollback path. No ordinary Studio command is pending. If recovery is required, inspect a fresh mirror first, then use `MODE="AUDIT"` or `MODE="ROLLBACK"` in the same installer. Its exact source anchors are deliberately guarded and must not be bypassed with a follow-up patch ladder.

## Release regression

Retain focused checks for independent sidebar/bottom artwork, affordable and unaffordable colours, `$5,000` formatting, BUY and insufficient-funds outcomes, `OWNED` transition, unchanged unrelated badges, and desktop/laptop plus landscape phone/tablet clipping. These are regression checks, not pending installation work.
