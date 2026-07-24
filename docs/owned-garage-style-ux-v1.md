# Owned Garage Style UX V1

Status: user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

Canonical installer: `scripts/roblox_owned_garage_style_ux_v1.lua`

## Acceptance contract

This is a High-Risk bounded expansion because one user action may persist finishes across several saved structure sections or decoration slots. It preserves the confirmed Phase 14/V1.1 ownership boundaries:

- ProfileService remains the only saved-state and revision owner.
- `OwnedGarageManagementRuntime` remains the active-session preview and physical-presentation owner.
- The existing shared garage workspace, module listing card, category card, colour control and action-button renderers remain the presentation owners.
- Existing stable section, slot, style, item, preset and material IDs remain unchanged.
- No remote, service, ScreenGui, saved field or schema migration is added.

Done means desktop and mobile can style one target or the virtual All target, unowned cards expose prices, unaffordable prices are red, real unavailable capabilities use the shared lock state, the material rail clears its channel tabs, navigation is repositioned, and preview/save/back transitions no longer remove the whole physical presentation for a frame.

## Behaviour

`All Structure` and `All Decorations` are virtual client/server-derived targets; they are not saved IDs. The server derives the current garage's valid targets from its authoritative definition and installed/equipped state. Unsupported channels are skipped. A bulk save validates a complete draft and commits it once with one revision increment, or commits nothing.

The bulk editor uses a sparse draft. Values shared by every compatible target can be shown initially; mixed values remain untouched until the player changes that channel. `All Decorations` exposes only Colour. No target counts, bulk completion banner or decoration-material warning card are shown.

Build cards use the shared available module-card state for unowned purchasable content. The price is red when current cash is lower than the authoritative projected price. Owned content has no price. The shared locked module-card state is reserved for a genuine missing colour/material capability and carries the reason in its footer.

## Stable physical preview lifecycle

The old implementation destroyed and rebuilt every structure/decor/lighting runtime child, while the client also sent four sequential cancel requests on many page changes. That could expose one rendered frame with no structure, decorations or lighting.

V1 uses one preview-cancellation request. A finish change on the same selected asset applies in place. An asset/preset swap is cloned and prepared before the old runtime model is removed. Decoration and lighting roots are updated per target rather than cleared wholesale. This preserves the active session owner and avoids adding another visual state owner.

## Icon/config contract

Under `ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.OwnedGarageIcons`:

- `Navigation.Save`
- `Actions.Colour`, `Actions.Material`
- `States.Locked`
- `StructureLocations.AllStructure`
- `DecorationLocations.AllDecorations`
- `Materials.CONCRETE`, `METAL`, `WOOD`, `PAINT`, `TILES_A` through `TILES_F`

Blank values use existing documented fallbacks. `Actions.Colour` is seeded from the current module colour icon and `States.Locked` from the shared module lock icon. `GarageReplacement.MaterialRailTabClearance` and `OwnedGarageUnaffordablePriceColor` are edit-time tuning attributes.

## Verification

1. Run the installer once in Edit mode and require its `PASS` and `READY` lines.
2. Restart Studio, enter the starter garage and open management.
3. Verify Style > Structure and Style > Decorations select their All row first.
4. Change one All Structure colour and material. Save each, remain in the editor, exit/rejoin and confirm persistence without overwriting untouched mixed channels.
5. Change All Decorations colour and confirm there is no material/warning/count card.
6. Check an individual structure and decoration still preview, save and restore on Back.
7. Check an unowned Build card with enough cash and one without enough cash; price visibility/colour must change without using a lock card. Purchase once and verify the price disappears.
8. Rapidly change tabs, colours and materials. The room, decorations and lighting must not disappear or jump for a frame.
9. Verify Exit below cash, Back/Save at lower right, the material rail above channel tabs, and desktop plus phone portrait/landscape reachability.
10. Regression-check Display Cars, Build purchase/equip, lighting independent colours, management close, garage exit and rejoin.
11. Refresh both Studio mirror areas before treating V1 as confirmed.

## Rollback and risks

The installer is transactional and idempotent. Any missing/non-unique compressed-source anchor, projected compile failure or hierarchy failure restores every touched source/config value. Until Play checks pass, V1.1/Phase 14 V2.2 remains the rollback baseline.

Staged swaps can briefly overlap old/new geometry for one scheduler step instead of leaving an empty frame. Runtime clones are non-collidable visual assets and the separate collision shell remains authoritative, so this should not affect movement. Extremely expensive authored models may still make cloning itself slow; asset budgets remain necessary.
