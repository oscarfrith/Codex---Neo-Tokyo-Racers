# Garage Responsive Scaled Touch V1.2

Status: V1.1 installed and device-emulator reviewed; canonical V1.2 correction generated and awaiting Studio installation/verification.

Installer:

`scripts/roblox_ui_garage_responsive_scaled_touch_installer.lua`

## Scope

This is one canonical shared-layout change. It does not create mobile copies of Browser, Paint, Build Modules, Owned/Buy Modules, module customisation or performance upgrades.

The installer changes only `GarageReplacementComponents` and responsive Attributes under `Config.UI.GarageReplacement`. Existing Browser and Workspace controllers continue to call `Shared.LayoutGarageShell` and retain all existing callbacks, card renderers, preview behavior and server actions.

## V1.2 touch contract

- Near-edge canvas inset: top/bottom/side `4px`. The garage is an edge-layout composition, so it does not reuse the race shell's broad top inset.
- The category rail uses the same physical top-offset contract as the confirmed free-roam car menu: `68px` on viewports below `500px` tall and `82px` otherwise.
- True-fit minimum: `0.25`, preventing the former `0.42` clamp from clipping small phones.
- Cash/Spaces `+`, main actions and selected-card popups retain their exact PC dimensions and scale uniformly with the canonical canvas. Carousel arrows remain the sole intentional `32px` physical-size exception.
- All automatic touch text enlargement is retired. The Upgrade Points labels use the same fixed `13px` logical size as module-card names, and the point-limit status uses that size with truncation disabled.
- The Upgrade Points panel is centred at the exact logical width of three module cards plus their two gaps, giving its title, pips and used count independent space.
- Cards and categories keep their existing shared styling and native scrolling.
- The canonical modal shade still owns the complete renderable garage canvas. Device Emulator's black rounded bezel is outside Roblox's renderable viewport and cannot be covered by a ScreenGui.

Because Roblox cannot safely fire another button's existing `Activated` connections, the installer enlarges the real touch controls instead of layering duplicate transparent action buttons. This preserves the authoritative action route and avoids callback duplication.

## Configuration Attributes

- `ResponsiveTouchEnabled = 1`
- `TouchSafeTop = 4`
- `TouchSafeBottom = 4`
- `TouchSafeSide = 4`
- `TouchScaleMin = 0.25`
- `TouchArrowPixels = 32`
- `TouchCategoryTopTiny = 68`
- `TouchCategoryTop = 82`
- `TouchVisualControlScaling = 0`

## Safety

- The installer accepts the refreshed V1.1 shell and replaces only the uniquely marked shared-shell section, shared status-label line and Workspace budget function/layout line.
- Shared and Workspace sources plus responsive Attributes roll back together if compilation, assignment or the post-install audit fails.
- It verifies Browser and Workspace still consume the shared layout.
- Generated source is compiled before assignment and compiled again from Studio readback.
- Source and responsive Attributes are restored if assignment or audit fails.
- The main client bootstrap, server, persistence, vehicle preview, module transactions, performance calculation and desktop page controllers are untouched.

## Verification

After install, restart Play and use Device Emulator for one tablet and at least `915x412`, `740x360` and `667x375` phones.

Visit:

1. Dealership vehicle selection.
2. Owned vehicle selection.
3. Paint Cockpit.
4. Build Modules slots and Owned/Buy lists.
5. Module Colour/Cosmetics/Performance.
6. An upgrade page with the point budget and card action popup visible.

Require `[NTR Garage Responsive Runtime] PASS` for each visited page. Also verify that the rail sits directly beneath Roblox controls, cash/space `+` remains inside each chip, Back/Start Driving and card-centred Buy/Equip/Customise match scaled PC height, the three-card-width budget stays centred, `UPGRADE POINTS` and `X/X USED` remain single-line, and `POINT LIMIT REACHED` is complete.

Desktop should retain the approved composition because safe-area fitting, target enlargement and text scaling are touch-only.
