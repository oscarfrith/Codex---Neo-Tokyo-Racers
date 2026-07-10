# PC Free-Roam UI Phase 2C Inset, Visibility, and Card-Edge Repair

Date: 2026-07-10  
Status: Generated after Phase 2B installation and screenshot/runtime review; not installed or confirmed yet.

## Studio Script

Run in Roblox Studio Edit mode:

```text
scripts/roblox_ui_freeroam_pc_phase2c_inset_visibility_card_edge_repair.lua
```

This is a guarded canonical replacement of only `DesktopFreeRoamHudController_Active`. It accepts the known Phase 1, Phase 2B, or Phase 2C marker and writes the complete Phase 2C isolated-controller source. It does not use fragile live-source text replacement and does not patch the register-limited bootstrap.

## Confirmed Phase 2B Evidence

- Phase 2B runtime audit passed `42`, warned `1`, failed `0` at both tested viewport heights.
- The only diagnostic warning was a physical dropdown-to-grid gap of `15.2 px`, just below the `16 px` target.
- The action row, cash/minimap width, cash text, minimap edges, driving visibility, double-width car action, speed arc, typography, and footer centring all passed.
- Screenshots showed that every cluster was visually shifted down by the Roblox top inset.
- Vehicle-card outer strokes/glows were clipped by the scrolling frame even though their geometry aligned with the dropdown columns.
- The HUD could remain hidden until a resize and did not reliably appear in Laptop device emulation.

## Root Causes

### Downward shift

Phase 2B changed `NTR_DesktopFreeRoamHud.IgnoreGuiInset` to `false`. In this project the existing free-roam composition and Roblox top bar are designed in the full-screen coordinate space. The change added the top inset visually to all clusters. Phase 2C restores `IgnoreGuiInset=true`.

### Intermittent visibility

The Phase 2B `isMajorMenuOpen()` fallback treated any enabled ScreenGui whose name contained `dealership`, `garageui`, or customisation text as a blocking full-screen menu. This could mistake the dealership intro objective or another companion UI for the actual garage menu.

Phase 2C suppresses the HUD only when:

- the exact `HOVER_RACING_V2_GarageUI` ScreenGui is enabled; or
- another enabled ScreenGui contains an actually visible semantic `GarageRoot`, `DealershipRoot`, `CustomisationRoot`, or `CustomizationRoot`.

The runtime ScreenGui now exposes `SuppressedByMajorMenu` for diagnostics.

### Laptop emulator eligibility

Phase 2B returned immediately whenever `TouchEnabled=true`. Touch-capable laptops and some Studio device profiles can report touch support while still supporting desktop keyboard/mouse input. Phase 2C returns only when touch is enabled and neither keyboard nor mouse is available. The runtime ScreenGui exposes `DesktopInputEligible`.

### Card-edge clipping

The two card columns exactly filled `VehicleGrid`, so the scroll frame clipped the outer half of their strokes/glows. Phase 2C expands the scrolling viewport horizontally by `CardStrokeSafePadding=5` while leaving the centred card content width unchanged. The card edges therefore remain aligned with the category/sort dropdowns, but the strokes have room to render.

`CarHeaderHeight` is raised from `146` to `154`, producing a clear physical gap even at the minimum `0.72` scale.

## Additional Emulator Stability

Phase 2C stores the last applied camera viewport and re-runs responsive layout whenever the actual viewport changes. This supplements Roblox property-change connections and removes the need to manually resize the Studio window after changing device profiles.

## Verification

1. Stop Play and run Phase 2C in Edit mode.
2. Start a fresh normal PC Play session. The HUD must appear immediately without resizing.
3. Confirm the action row sits near the top in the same full-screen position as the pre-Phase-2B composition.
4. Confirm cash/minimap and telemetry sit against the intended bottom margins.
5. Open `MY VEHICLES` and confirm the panel has moved upward with the rest of the HUD.
6. Confirm both vehicle-card outer borders/glows are complete and their outside edges align with the dropdowns.
7. Scroll the vehicle grid; cards must remain clipped vertically to the scrolling region and must not cover the header or despawn button.
8. Close/open the car drawer and all local modals several times.
9. Enter/exit a vehicle and confirm driving-only controls and telemetry remain correct.
10. Enable Laptop device emulation before Play. The desktop HUD must appear immediately without resizing.
11. Switch between normal and Laptop emulator sizes if practical and confirm the layout updates automatically.
12. Verify a Phone/mobile device still uses the existing mobile UI and does not create the desktop HUD.
13. Open and close the real dealership/garage UI. The desktop HUD must hide while the full menu is open and return after it closes.
14. Confirm the dealership intro objective alone does not suppress the free-roam HUD.

Then run the updated read-only diagnostic after opening the car drawer once:

```text
scripts/roblox_ui_freeroam_pc_phase2a_runtime_layout_diagnostic.lua
```

The diagnostic now reports ScreenGui eligibility/suppression attributes, inset-normalised action coordinates, card/dropdown alignment, and the existing responsive checks.

## Mirror Status

The repository Studio mirror still represents the pre-Phase-2B export from `16:05:49`, so it is stale relative to the installed Phase 2B Studio source. Phase 2C was generated from the exact guarded Phase 2B installer source plus the successful Phase 2B runtime hierarchy/diagnostic output. After installing and testing Phase 2C, refresh the complete Studio mirror before final confirmation.

## Rollback

Use Roblox version history to return to the pre-Phase-2C place version. Do not create an in-game backup controller or folder.
