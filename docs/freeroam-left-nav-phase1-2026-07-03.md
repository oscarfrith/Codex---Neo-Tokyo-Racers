# Free Roam Left Navigation Phase 1

**Created:** 2026-07-03  
**Status:** Superseded by Free Roam Map Stack Phase 2  
**Studio script:** `scripts/roblox_freeroam_left_nav_phase1.lua`

## Goal

Create a compact left-side free-roam navigation UI that matches the dealership theme and replaces the scattered old free-roam controls with one consistent menu surface.

## Installed Shape

The Phase 1 script installs:

- `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active`
- `PlayerGui.NTR_FreeRoamLeftNav` at runtime

The controller is isolated. It does not patch `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

## Buttons

- `CAR`: current vehicle summary, exit vehicle, and open customisation/dealership flow.
- `RACE`: shell for nearby races, route tracking, rewards, and race entry.
- `GARAGE / HOME`: enter own garage, set public/private, and return to city.
- `SETTINGS`: shell for UI scale, camera, audio, mobile controls, and control hints.
- `DEALER`: opens the existing dealership/customisation flow through `OpenGarageFromIntro`.

## Icon Assets

The preferred plain white overlay PNG assets live in:

```text
assets/ui/icons/freeroam_nav_plain/
```

Files:

- `freeroam_plain_car.png`
- `freeroam_plain_race.png`
- `freeroam_plain_garage_home.png`
- `freeroam_plain_settings.png`
- `freeroam_plain_dealership.png`

These have transparent backgrounds and are intended to sit on top of the Roblox-made dark grey/pink beveled button frames.

The earlier generated neon framed concept assets are kept in:

```text
assets/ui/icons/freeroam_nav/
```

Files:

- `freeroam_nav_source_sheet.png`

Upload the five individual plain overlay icons to Roblox. Then paste their `rbxassetid://...` values into:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.CarIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.RaceIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.GarageIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.SettingsIcon
ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.DealershipIcon
```

Until asset IDs are filled in, the UI uses compact text fallbacks.

## Replacement Behaviour

Phase 1 suppresses these old free-roam UI surfaces client-side:

- `HOVER_RACING_V2_DriveHUD.DriveMenu`, the old top-right `Exit` menu.
- `NTR_GarageAccessUI`, the old right-side garage access MVP toggle.

It keeps the existing speed/boost drive HUD and mobile driving controls.

## Studio Steps

1. In Studio Edit mode, run:

```text
scripts/roblox_freeroam_left_nav_phase1.lua
```

2. Start Play Solo.
3. In the CLIENT Command Bar, run the same script again for the smoke test.
4. Manually click all five left-rail buttons.
5. Verify `CAR > EXIT VEHICLE`, `GARAGE / HOME > ENTER MY GARAGE`, `RETURN TO CITY`, and `DEALER > OPEN DEALERSHIP`.

## Verification Notes

Check desktop and mobile sizes:

- Rail should sit on the left and not cover the mobile thumbstick/drift ring.
- Only one slide-out panel should be visible at a time.
- Full dealership UI should hide the free-roam rail while open.
- The old top-right `Exit` menu and old right-side garage access toggle should not remain visible.

## Risks And Rollback

Risk is mainly layout/action routing, not source corruption. The phase adds an isolated LocalScript and config folder.

Rollback:

1. Disable or delete `FreeRoamNavController_Active`.
2. Set `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.Enabled` to `false`.
3. If needed, set `HideLegacyDriveMenu` and `HideLegacyGarageAccessUI` to `false` to let the old controls show again.

## Next Phase

Phase 2 supersedes this left-rail layout:

- `docs/freeroam-map-stack-phase2-2026-07-03.md`
- `scripts/roblox_freeroam_map_stack_phase2.lua`

After the Phase 2 top-right map stack is visually accepted:

- Move the Phase 25 garage customization controls into the `GARAGE / HOME` panel.
- Add real Race cards from race/checkpoint data.
- Add player settings persistence.
- Replace fallback text labels with uploaded Roblox icon asset IDs.
