# Mobile Free-Roam UI Phase 1L - Modal Safe Area And PC Cash

Date: 2026-07-13

## Scope

Phase 1L moves the central mobile popup family onto the same safe-area sizing principles approved for Mobile Racing UI. It changes only the isolated `MobileFreeRoamHudController_Active` and `Config.UI.MobileFreeRoamHud`.

Covered popups:

- Settings, retaining Mobile Controls as the first section;
- Get Cash, porting the PC 2x2 product-card composition;
- Teleport to Dealership confirmation.

It does not change the car menu, navigation/map/cash HUD placement, driving controls, race menus, PC HUD, gameplay, rewards, server services, bootstrap, VFX, or LOD.

## Studio Script

Run this whole file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_ui_freeroam_mobile_phase1l_modal_safe_area_pc_cash.lua
```

Leave `MODE = "INSTALL"`, run it once, restart Play, and verify. Then change to `MODE = "SMOKE"` and run it again in Edit mode.

## Layout Contract

All modal shells centre within a safe rectangle using:

```text
ModalSafeTop = 72
ModalSafeBottom = 10
ModalSafeSide = 10
ModalScaleMin = 0.25
ModalScaleMax = 1.00
```

Per-popup reference sizes:

```text
Settings = 720 x 420
Cash = 840 x 650
Confirmation = 650 x 270
```

The Cash modal uses the PC balance chip, four 2x2 cash-pack cards, amount/Robux labels, Best Value badge, Close action, theme colours, gradients, and facet treatment. Cash products remain deliberately visual-only; pressing a pack reports that products are not enabled and never starts a purchase.

## Verification

On a short and standard landscape mobile viewport:

1. Open Settings and confirm the full shell is centred with all four sections and Done inside it.
2. Confirm Arrows, Thumbstick, and Tilt remain the first Settings section and selection still works.
3. Open Get Cash from the Plus button and confirm all four cards, balance, Best Value, Close, and disabled-products footer fit inside the shell.
4. Tap each cash pack and confirm no purchase prompt appears.
5. Open the Dealership confirmation and confirm its title, message, No, and Yes controls are centred and contained.
6. Confirm the background HUD remains visible beneath the dim layer but cannot be pressed through the popup.
7. Resize/rotate the emulator once and confirm the active popup recentres and rescales.
8. Confirm the car menu, driving HUD/controls, race menus, and PC free-roam UI are unchanged.

## Risk And Rollback

This is a fragile but guarded source patch. It replaces one exact modal-family range and one exact old viewport-layout line in the refreshed Phase 1K owner. Both edits are staged before Studio source or config is mutated; a missing/duplicate anchor stops installation.

For rollback, restore `MobileFreeRoamHudController_Active` from the pre-install Studio snapshot refreshed at `2026-07-13 20:07:14`, or use Studio version history. The added `Modal*` config attributes are inert under the older source.

Refresh the Studio mirror again after Phase 1L is installed and confirmed.
