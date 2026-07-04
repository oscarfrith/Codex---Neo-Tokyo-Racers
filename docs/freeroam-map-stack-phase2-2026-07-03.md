# Free Roam Map Stack Phase 2

**Created:** 2026-07-03  
**Status:** Generated in Git, ready for Studio install/test  
**Studio script:** `scripts/roblox_freeroam_map_stack_phase2.lua`

## Goal

Rework the free-roam UI into a compact top-right stack based on the provided sketch:

```text
MAP
CAR
SHOP | RACE
HOME | SETTINGS
```

This creates visual space for a future Illustrator-authored minimap without configuring the actual map movement yet.

## Installed Shape

The Phase 2 script canonically replaces only:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active
```

It keeps using:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav
```

It does not patch `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

Runtime UI:

```text
PlayerGui.NTR_FreeRoamLeftNav.MapStack
```

## Layout

- Top-right anchored stack.
- Square `MapFrame` placeholder at the top.
- Full-width `CarButton` below the map.
- Two-row grid below:
  - `ShopButton`
  - `RaceButton`
  - `HomeButton`
  - `SettingsButton`
- Small action drawer appears to the left of the stack when a button needs secondary actions.

The map is intentionally only a placeholder in Phase 2. Later phases can set `FreeRoamNav.MapImage` and add world-to-map calibration.

## Responsive Behaviour

The stack width is calculated from viewport size with min/max config values:

- `MapStackMinWidth`
- `MapStackMaxWidthDesktop`
- `MapStackMaxWidthTouch`
- `MapStackScreenWidthFractionDesktop`
- `MapStackScreenWidthFractionTouch`

Touch devices use a smaller max width and a tight top-right offset so the stack sits close to the screen corner.

Phase 2.1 mobile/icon repair notes:

- Existing non-empty icon asset IDs are preserved when rerunning the installer.
- Plain numeric asset IDs are normalized to `rbxassetid://...` at runtime.
- Touch layout defaults are smaller: `MapStackMaxWidthTouch = 148`, `MapStackTopMarginTouch = 8`, and `MapStackRightMarginTouch = 8`.

Phase 2.2 mobile polish notes:

- Button icons are square `ImageLabel` overlays, centred and sized from the smaller button dimension so full-width buttons do not stretch them.
- The map-stack controller no longer forces `HOVER_RACING_V67_MobileDriveControlsUI.Root.Visible`; that caused visible flicker when it fought the mobile controls controller.
- The installer patches the isolated `MobileDriveControlsController_Active` so mobile controls decide their own visibility from either `MobileDriveInputState.IsDriving`, seated vehicle state, or the active drive HUD.
- Mobile pedals sit near the bottom-right with the gas pedal's right edge aligned to the map stack's right edge.
- Mobile boost is centered at the bottom of the screen, with MPH directly above.
- Mobile thumbstick, boost, and pedals read the same theme colours as the map/dealership UI.

Phase 2.3 mobile visibility repair notes:

- If the mobile controls still hide even after the controller owns visibility, the map-stack controller now publishes `MobileDriveInputState.IsDriving = true` whenever touch is enabled and the player appears to be driving from the active drive HUD or vehicle-seat state.
- This does not force `Root.Visible`; it only repairs the shared driving-state signal so the mobile controls controller can show itself normally.
- The client smoke now prints a mobile diagnostic line with `IsDriving`, mobile GUI enabled, mobile root visible, and desktop drive GUI enabled values.

Phase 2.4 mobile visibility repair notes:

- The previous smoke showed `driveGuiEnabled=true` while `IsDriving=false` and `mobileRootVisible=false`, meaning the mobile controls were present but still hiding.
- The map-stack controller and the patched mobile controls controller now treat garage/dealership UI as open only when a real `GarageRoot` or `DealershipRoot` is visible. An enabled but hidden ScreenGui shell should no longer suppress mobile pedals.
- The client smoke now also prints `garageVisible`. During normal free-roam driving it should be `false`; if it is `true`, a visible garage/dealership root is still open and intentionally hiding the mobile controls.

Phase 2.5 mobile helper repair notes:

- A Phase 2.4 run could remove the V69 desktop-HUD helper block from `MobileDriveControlsController_Active`, causing `attempt to call a nil value` around line 504 in Play mode.
- The installer now repairs that missing helper block before patching visibility and replaces only the exact `findGarageVisible()` function instead of using a broad neighbour-function anchor.
- If that nil-call appears, stop Play, run the updated Phase 2 script in Edit mode, restart Play, then rerun the client smoke.

Phase 2.6 dealership/menu and laptop sizing notes:

- Phase 2.6 reduced laptop sizing and added menu-hiding, but its first visibility gate was too strict and was corrected by Phase 2.7.
- It hides while visible garage, dealership, customisation, or customization UI is open. The detector checks visible ancestry so hidden menu internals should not create false positives.
- Desktop/laptop defaults are about 20% smaller: `MapStackMaxWidthDesktop = 234` and `MapStackScreenWidthFractionDesktop = 0.188`.
- The full-width car button now uses the same row height and icon scale as the Shop/Race/Home/Settings buttons.

Phase 2.7 free-roam visibility correction:

- The Phase 2.6 driving-only gate was too strict. The map stack should appear in normal free roam while walking/running as well as while driving.
- The stack now hides only when visible garage, dealership, customisation, or customization UI is open, while remaining available during normal on-foot free roam.

Phase 2.8 pop-out and button surface polish:

- Action pop-out panels now align to the top of the map stack and match the full map-stack height.
- Stack buttons no longer use the old top/bottom bevel bars. The map frame keeps its existing framed look.
- Stack/action buttons use a configurable diagonal gradient plus purple outline.
- New `FreeRoamNav` config values:
  - `ButtonGradientTopLeft`
  - `ButtonGradientBottomRight`
  - `ButtonGradientRotation`
  - `ButtonOutline`

Phase 2.9 outline/action-button correction:

- Stack button gradients now live on an inner `ButtonFill` layer so the purple parent-button outline remains visible.
- Pop-out action buttons no longer use the stack-button gradient; they keep simple solid fills for clearer actions.

Phase 2.10 outline contrast and local text-glow controls:

- Stack button outlines are stronger and configurable through:
  - `ButtonOutline`
  - `ButtonOutlineThickness`
  - `ButtonOutlineTransparency`
  - `ButtonFillInset`
- The stack-button gradient fill is inset so it does not cover the outline.
- Free-roam pop-out labels/action-button text now supports the same glow effect style through:
  - `TextGlowEnabled`
  - `TextGlowColor`
  - `TextGlowThickness`
  - `TextGlowTransparency`
- Applying the same text glow broadly across dealership/customisation should be a separate shared UI theme phase, because it touches the larger dealership/customisation UI surface rather than only the isolated free-roam stack.

Phase 2.11 button layering and config-preservation notes:

- The stack buttons now layer as dark base frame, pink outline, inset gradient fill, hover dark overlay, then icon.
- The dark base remains visible around the inset gradient instead of leaving a transparent gap.
- Hover/press feedback uses a low-opacity black overlay above the gradient and below the icon.
- Future reruns preserve existing `FreeRoamNav` Bool/Number/Color config values instead of resetting player-tuned values.
- New `FreeRoamNav` config values:
  - `ButtonBaseColor`
  - `ButtonBaseTransparency`
  - `ButtonHoverOverlayTransparency`

## Actions

- `CAR`: opens a compact action drawer with current vehicle, `EXIT VEHICLE`, and `CUSTOMISE`.
- `SHOP`: opens a drawer with `OPEN SHOP`, using the existing `OpenGarageFromIntro` hook.
- `RACE`: placeholder drawer for future race cards and route tracking.
- `HOME`: opens a drawer with `ENTER GARAGE` and `RETURN CITY`.
- `SETTINGS`: placeholder drawer for UI/audio/camera/control preferences.

## Icon Assets

The preferred icon overlays are:

```text
assets/ui/icons/freeroam_nav_plain/
```

Upload the five `freeroam_plain_*.png` icons to Roblox and paste their asset IDs into:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.CarIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.RaceIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.GarageIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.SettingsIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.DealershipIcon
```

Until those are filled in, the UI shows text fallbacks.

## Studio Steps

1. In Studio Edit mode, run:

```text
scripts/roblox_freeroam_map_stack_phase2.lua
```

2. Start Play Solo.
3. In the CLIENT Command Bar, run the same script again for the smoke test.
4. Manually verify:
   - top-right stack appears;
   - stack appears while walking/running in free roam;
   - stack appears while driving;
   - stack hides while dealership/customisation menus are open;
   - map is a square placeholder;
   - desktop/laptop stack is about 20% smaller than the first Phase 2 version;
   - car row is full width but matches the other button row height and icon scale;
   - shop/race/home/settings are a 2x2 grid;
   - clicking Car/Race/Home/Settings/Shop opens a left pop-out that matches the full stack height;
   - stack buttons have visible purple outlines, centred icons, diagonal gradient fill, and no top/bottom bevel bars;
   - the inset gradient sits on top of a dark grey button base rather than transparent space;
   - hover/press feedback darkens the button surface while keeping the icon readable;
   - pop-out action buttons use solid fills, not the stack-button gradient;
   - free-roam pop-out header/action text has the configured glow effect;
   - dealership/garage UI hides the stack while open;
   - old top-right `DriveMenu` and old right-side `NTR_GarageAccessUI` are not visible.

## Rollback

Either:

- rerun `scripts/roblox_freeroam_left_nav_phase1.lua` to return to the earlier rail layout; or
- set `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.MapStackEnabled` to `false`; or
- disable/delete `FreeRoamNavController_Active`.

## Next Phase

When the Illustrator map is ready:

1. Upload the map PNG to Roblox.
2. Set `FreeRoamNav.MapImage`.
3. Add world-bounds calibration values.
4. Add map pan/rotation from vehicle/player position and heading.
