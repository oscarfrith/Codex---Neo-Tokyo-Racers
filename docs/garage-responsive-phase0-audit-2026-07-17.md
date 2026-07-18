# Garage Responsive Phase 0 Audit

Status: complete. Edit and desktop Play Client outputs reviewed on 2026-07-18.

## Purpose

Prepare the confirmed canonical garage UI for tablet and mobile without creating a second UI tree or disturbing the desktop baseline. This phase is deliberately read-only.

The audit script is:

`scripts/roblox_ui_garage_responsive_phase0_audit.lua`

The same script auto-detects its execution context:

- Edit Command Bar: checks the live canonical owners and simulates supported desktop, tablet, and phone viewports.
- Play Client Command Bar: checks the actual open garage page for clipping, overlap, scale ownership, popup/budget separation, and physical touch-target size.

## Responsive contract being audited

- One `CanonicalGarageGui` and one `CanonicalScale` remain authoritative.
- Browser and all post-selection pages continue to call the same `GarageReplacementComponents.LayoutGarageShell` layout owner.
- Existing shared cards, stats, economy chips, category rails, carousel, action popup, upgrade cards, and colour controls are reused.
- Desktop composition is scaled rather than rebuilt for touch.
- Responsive exceptions are limited to explicit safe-area padding, minimum readable text, invisible touch hit-target padding, and overflow/scroll behavior.
- No mobile-only visual fork is permitted.

## Simulated gates

The Edit audit models:

- 1920x1080 desktop
- 1366x768 laptop
- 1280x800 and 1024x768 tablets
- 915x412, 844x390, 740x360 and 667x375 phones

It reports the live base size, minimum scales, applied scale, virtual canvas, scaled action height and scaled module-copy size for each profile.

Expected pre-install findings are:

- explicit safe-area ownership is required because the canonical `ScreenGui` ignores the Roblox inset;
- visually scaled 30px actions become smaller than a reliable 44px touch target, so invisible padded hit targets are required;
- the smallest phone may be forced above its true fit scale by the existing minimum-scale clamp;
- touch copy needs a readability floor without changing the shared component hierarchy.

These are implementation gates, not reasons to duplicate the interface.

## Run order

1. Stop Play and run the script once from the Edit Command Bar.
2. Start Play, enter Dealership or Customisation, and leave a canonical garage page visible.
3. Run the same script from the Play Client Command Bar at the current viewport.
4. Paste both complete outputs before generating the responsive installer.

No source, Instance, Attribute, profile data, vehicle, module, or UI state is changed by either run.

## Installer gate

Do not generate the responsive installer until the live outputs establish:

- the current canonical owner fingerprints;
- the current configuration values;
- whether the smallest supported viewport clips because of the minimum scale;
- which controls need padded touch targets;
- whether the live budget strip, popup, rails and carousel have any existing overlap.

The subsequent installer should change the shared layout/config contract once so Browser, Paint, Build Modules, Owned/Buy Modules, module customisation and performance upgrades inherit the same responsive behavior.

## Confirmed results

Edit mode completed at `pass=18 warn=7 blocker=9`. Desktop Play Client completed at `pass=7 warn=1 blocker=1` with a `1918x1080` viewport and canonical scale `1.02`.

The important findings are:

- All four canonical controller owners exist.
- Browser and Workspace both consume `GarageReplacementComponents.LayoutGarageShell`.
- One `CanonicalGarageGui`, canvas and scale own the presentation.
- The shared shell keeps the header, left rail, right rail and carousel separated at every simulated desktop, tablet and phone size.
- Both rails already use native `ScrollingFrame` ownership, so a separate mobile carousel is unnecessary.
- The existing `MobileMinScale=0.42` exceeds the true fit scale at `740x360` and `667x375`; those sizes can clip.
- Every simulated touch profile scales the 30px actions below a 44px physical target.
- Touch module copy drops below 10px from `1024x768` downward.
- No explicit safe-area contract exists on the canonical garage owner.
- The card-relative action popup remained separated from the upgrade budget in the live desktop run.

The live header reported `y=-29.4` while the Roblox top inset was exactly `58px`. Categories were shifted by the same `58px` coordinate difference (`72 * 1.02 - 58 = 15.4`). This is an `IgnoreGuiInset`/absolute-coordinate basis mismatch, not evidence that the confirmed desktop layout should be moved. Preserve desktop geometry and add the confirmed race-style safe-area fitting only to the touch branch.

The two static marker warnings were audit-location errors, not feature regressions. Both `NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1` and the UI copy of `NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1` live in `ModuleShopUIController`, not `GarageExperienceController_Active` or `GarageWorkspaceController`. Their behavior was already user-confirmed.

The runtime audit found only named Browser descendants (`Header`, `Categories`, `Exit` and `CardActionPopup`). Several shared panels still have generic runtime names, so absence of a runtime rectangle for Right/Carousel was not a visual failure. The responsive installer must give key shared shell objects stable names and run its post-install geometry audit through those names.

## Approved implementation direction

The evidence supports one guarded responsive installer with no mobile UI fork:

1. Extend the shared `LayoutGarageShell` touch branch with the confirmed racing safe-area model: configurable `SafeTop=72`, `SafeBottom=10`, `SafeSide=10`, and a true fit scale permitted down to `0.25`.
2. Keep the desktop branch and its confirmed visual positions unchanged.
3. Keep the same cards and rails, but add transparent touch-only hit targets of at least `44x44` physical pixels around essential actions.
4. Add touch-only readable text floors through shared component constraints rather than page-specific font overrides.
5. Preserve native horizontal/vertical scrolling and the existing overflow-driven carousel arrows.
6. Give the shared shell's key panels stable names and add desktop/tablet/phone runtime geometry checks to the installer.

This is the next recommended phase. It should be installed as one canonical shared-layout change so every garage page inherits it together.

The approved installer is now generated as `scripts/roblox_ui_garage_responsive_scaled_touch_installer.lua`; see `docs/garage-responsive-scaled-touch-v1-2026-07-18.md`.
