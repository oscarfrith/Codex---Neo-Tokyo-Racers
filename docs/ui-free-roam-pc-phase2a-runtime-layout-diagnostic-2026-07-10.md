# PC Free-Roam UI Phase 2A Runtime Layout Diagnostic

Date: 2026-07-10

## Purpose

Phase 1 is installed and the refreshed Studio mirror now contains its isolated `DesktopFreeRoamHudController_Active` controller and editable `DesktopFreeRoamHud` config. The first visual review found eight layout and hierarchy problems. Phase 2A measures those problems in live screen coordinates before the isolated controller is replaced.

This phase is read-only. It does not change Studio source, UI instances, config, gameplay, hierarchy, or the register-limited bootstrap.

## Script

```text
scripts/roblox_ui_freeroam_pc_phase2a_runtime_layout_diagnostic.lua
```

Run it from the Roblox Studio Command Bar while Play is running, with the Command Bar set to the client context.

## Recommended Two Captures

### Capture 1: driving and vehicle drawer

1. Start a PC Play test.
2. Spawn/enter an owned vehicle.
3. Open `MY VEHICLES` once so its cards are rendered. Leave the drawer open.
4. Run the complete Phase 2A diagnostic in the client Command Bar.
5. Copy the complete Output.

This capture measures the vehicle-card grid, dropdown clearance, car action geometry, speed arc ordering/clipping, metric sizes, and current driving state.

### Capture 2: on foot

1. Close `MY VEHICLES`.
2. Exit the vehicle so the player is on foot.
3. Run the same diagnostic again.
4. Copy the complete Output.

This capture confirms that both bottom-centre driving actions can be hidden on foot. The current Phase 1 controller is expected to warn that `CONTROLS` remains visible.

## What It Measures

- viewport, `DesignRoot` size, and `UIScale`;
- top-right button sizes and car-icon centring;
- cash/minimap width parity and cash-text visibility;
- whether `CONTROLS` and `EXIT VEHICLE` match driving state;
- vehicle drawer header, dropdowns, scrolling region, grid alignment, first cards, clipping, and important text sizes;
- speed and MPH typography;
- speed-arc segment order and estimated rotated bounds against the viewport;
- teleport title/description font consistency;
- cash-store footer centring;
- current `DesktopFreeRoamHud` config size and key layout values.

## Expected Current Warnings

The current mirrored Phase 1 source already confirms several likely warnings:

- car action is not double width;
- cash width is `210` while minimap size is `245`;
- the minimap gradient cannot fade its child roads;
- `CONTROLS` remains visible on foot;
- vehicle grid is left-aligned, uses fixed cells, and has too little separation below the dropdowns;
- dropdown and vehicle-card typography is too small;
- gauge activation begins at the top rather than the bottom;
- speed and MPH text are below the revised display targets;
- teleport description and cash footer use `GothamMedium` rather than the shared UI font;
- the cash footer uses a fixed offset instead of true panel centring.

Warnings are measurements for Phase 2B, not evidence that the diagnostic failed. Missing required runtime objects are reported as failures.

## Phase 2B Gate

Do not add another patch ladder to the Phase 1 controller. After reviewing both diagnostic captures, Phase 2B should canonically replace only the isolated desktop HUD controller and refine its config into a small semantic design system:

- shared theme colours by meaning;
- typography roles such as Display, Heading, Button, Body, Caption, and Metric;
- a compact spacing/geometry scale;
- restrained effect controls for gradient, glow, pattern, and minimap vignette strength;
- page-specific layout values only where genuinely necessary.

The target is roughly 35-45 useful values across the desktop UI foundation, not individual settings for every label. The replacement should preserve existing working gameplay actions and leave server, driving, racing, VFX, mobile UI, and the bootstrap untouched.

The user completed the diagnostic captures on 2026-07-10. Two on-foot captures at `2153.3 x 700` returned `pass=29 warn=14 fail=0`; one had the car drawer visible and one had it hidden. The final driving capture at `1615.3 x 846` returned `pass=30 warn=13 fail=0` with `driving=true`, both bottom actions visible, and telemetry visible. The changed viewport was useful because it confirmed the same inset problem at a second aspect ratio. Phase 2B therefore has sufficient measurement data.

The diagnostic now also recognises the Phase 2B four-edge minimap treatment and explicitly checks whether the action bar remains inside the vertical viewport, so the same script can be reused after installation.

## Mirror Status

The user refreshed the Studio mirror immediately before this phase. The refreshed mirror contains the Phase 1 controller/config and was used to create this diagnostic. Running Phase 2A does not mutate Studio, so it does not require another mirror refresh.
