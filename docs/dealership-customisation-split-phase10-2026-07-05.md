# Dealership / Customisation Split Phase 10

Superseded for ordering by Phase 11: `scripts/roblox_dealership_customisation_split_phase11_sorted_cockpit_cards.lua` keeps the Phase 10 layout but sorts dealership cockpits by price, customisation cockpits by rating, and categories alphabetically.

## Purpose

Phase 10 polishes the dealership/customisation layout after the Phase 9 Studio test:

- shrinks the free-roam car icon back to the same scale as the other free-roam stack icons;
- shortens the bottom-right Exit frame while keeping the Exit button the same size;
- moves the Exit button down so the frame padding is consistent above and below it;
- moves the right-panel action button (`Buy`, `Buy Another`, or `Customise`) slightly lower;
- removes the `Categories` heading and moves the category button list upward;
- narrows the right stats panel on mobile and gives the central cockpit grid that space;
- increases cockpit-card name/price text on desktop while keeping mobile text close to the liked Phase 9 size;
- keeps stat values inside the bars, but moves them to the left in dark text for readability.

The same bootstrap layout path is used by dealership and owned-cockpit customisation, so these changes apply to both.

## Studio Script

```text
scripts/roblox_dealership_customisation_split_phase10_responsive_layout_polish.lua
```

Run in Studio Edit mode after Phase 9 has been installed.

## Config

The script updates:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.CockpitMenuCards
```

Useful Phase 10 values:

- `FreeRoamCarIconScale`
- `DesktopNameTextSize`
- `MobileNameTextSize`
- `DesktopNameHeight`
- `MobileNameHeight`
- `DesktopCardScaleMax`
- `MobileCardScaleMax`
- `DesktopStatsPanelWidth`
- `MobileStatsPanelWidth`
- `ExitPanelVerticalPadding`
- `PanelActionBottomPadding`

Defaults are conservative: mobile right stats panel width is `230`, desktop remains `270`, and the free-roam car icon scale is `0.48`.

## Verification

1. Run the Phase 10 script in Edit mode.
2. Restart Play.
3. Verify the free-roam car icon matches the other free-roam icons in size.
4. Open dealership on mobile and verify the right stats panel is narrower and the central cockpit area is wider.
5. Verify the bottom-right Exit frame is shorter, with even top/bottom padding around the unchanged Exit button.
6. Verify `Buy Another` / `Buy` / `Customise` sits slightly lower in the right panel.
7. Verify the left `Categories` heading is gone and the Bruiser button starts higher.
8. Verify desktop cockpit-card name/price text is larger, while mobile text remains close to Phase 9.
9. Verify stat numbers sit inside the bars, on the left, in dark readable text.
10. Enter the customisation zone and repeat the dealership layout checks.

## Risk / Rollback

This is a guarded source patch against the active client bootstrap and the isolated free-roam nav controller. If it cannot find the Phase 9 marker or any exact source block, stop and refresh the Studio mirror before creating another patch.

Rollback through Roblox Studio version history.
