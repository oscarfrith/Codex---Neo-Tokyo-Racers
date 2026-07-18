# Canonical Garage Flow, Navigation, and Colour V1

Date: 2026-07-18

Installer: `scripts/roblox_ui_garage_flow_navigation_colour_palette_installer.lua`

Status: generated against the refreshed responsive V1.2 mirror; awaiting Edit install and Play verification.

Installer revision V1.1 removes an invalid `Disabled` audit from the two canonical ModuleScripts. The V1 attempt rolled back cleanly before completion, so no revert or mirror refresh is required before rerunning V1.1.

## Scope

This phase changes only the canonical client presentation and route ownership. It deliberately leaves profiles, module-instance persistence, server garage actions, preview assembly, performance calculations, driving, and racing untouched.

- Reuses one shared icon-and-text action button for Exit, Back, Customise, and Drive.
- Sizes the red and blue navigation actions from the same two-column width contract used by Cash and Spaces.
- Reserves a popup-safe action lane above card-centred Buy and Equip controls.
- Routes Dealership purchase through Paint Vehicle and then a new Garage hub.
- Routes owned-vehicle Customisation selection and drive-in entry directly to the Garage hub.
- Adds the two-card Build Modules / Customise Modules hub with no left rail and no Back action.
- Replaces Build's Owned/Buy left rail with a two-card source picker and an explicit list -> source -> slots -> hub Back stack.
- Centralises Drive through the existing required-module validation, transient-preview cleanup, session close, and spawn path.
- Widens the colour panel, places Hue/Saturation/Brightness beside one another, and adds a configurable two-row palette.
- Applies shared comma formatting to garage cash and price presentation.
- Shortens `POINT LIMIT REACHED` to `LIMIT REACHED`.

## Configuration

The installer creates `ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.NavigationIcons`. Its attributes are reusable image IDs/URLs:

- `BackIcon`
- `ExitIcon`
- `DriveIcon`
- `CustomiseIcon`
- `BuildModulesIcon`
- `CustomiseModulesIcon`
- `OwnedModulesIcon`
- `BuyModulesIcon`

Blank Back/Exit attributes use a text fallback. The installer also creates these tuning attributes on `GarageReplacement` when absent:

- `NavigationButtonHeight = 46`
- `NavigationPopupClearance = 48`
- `WorkspacePaintWideWidth = 900`
- `PaintPaletteColumns = 12` (clamped from 10 to 15)

## Verification

Run installer V1.1 once in the Edit Command Bar, restart Play, and require `12 PASS / 0 FAIL`.

1. Dealership: select and purchase a vehicle, paint it, then use Customise to reach the hub.
2. Customisation entrance: select an owned vehicle and confirm it opens the hub directly.
3. Drive-in: confirm it opens the same hub.
4. Hub: confirm there is no left rail or Back action, both bottom cards work, stats/economy remain visible, and Drive spawns the authoritative equipped build.
5. Build: select a slot, choose Owned or Buy at the bottom, open a list, and verify Back walks list -> source picker -> slots -> hub.
6. Customise: verify Back returns to the hub and Drive uses the same shared action.
7. Select Buy/Equip cards on desktop and touch; verify their centred popup does not overlap either navigation action.
8. Exercise all three sliders and representative light/dark swatches, then change pages and confirm committed colours persist.
9. Verify five-plus-digit cash/prices use commas and upgrade exhaustion reads `LIMIT REACHED`.
10. Preview a module without buying/equipping, then Back or Drive; confirm the transient preview is cleared.
