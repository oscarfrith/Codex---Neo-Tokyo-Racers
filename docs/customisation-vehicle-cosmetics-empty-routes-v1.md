# Vehicle Cosmetics And Empty Module Routes V1

Status: V1.2 user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

Installer:

`scripts/roblox_customisation_vehicle_cosmetics_and_empty_routes_v1.lua`

## Acceptance Contract

This is a High-Risk connected customisation change because it adds per-vehicle purchases, saved state, server mutations, asset hierarchy, preview behaviour, and VFX ownership guards.

- Thrust Colour and Underglow are separate per-vehicle purchases.
- Owned Thrust, Underglow, Cockpit, and All selections open the shared colour sliders directly.
- All exposes Primary, Secondary, Detail, and Neon. Its Neon save updates cockpit neon, every installed module instance whose neon is owned, and owned underglow atomically.
- Front and rear vehicle lights are never included in thrust or All Neon recolouring.
- Underglow is one cockpit-root Attachment with one SurfaceLight. It is disabled until purchased and contains no physics parts.
- Missing physical modules show one shared plus card with `BUY TO UNLOCK` or `EQUIP TO UNLOCK`. Selecting it opens the exact Add Modules source page and returns to the originating Paint/Upgrade page after a successful buy/equip.
- An empty compatible Owned Modules source uses the shared locked listing style and `BUY MODULE`.
- Existing module instances, upgrades, prices, driving, racing, dealership flow, owned-garage flow, and front/rear light paint remain unchanged.

## Ownership And Persistence

- `VehicleCosmeticCatalog` owns definitions, defaults, capability checks, presentation, and protected-light classification.
- `VehicleCosmeticServerRuntime` owns purchase validation and atomic saved mutations.
- The active garage action controller remains the only remote action owner.
- Saved state lives on the existing vehicle record:

```text
Vehicles[VehicleId].Cosmetics
  SchemaVersion
  Unlocks.ThrustColour
  Unlocks.Underglow
  Colours.Underglow
```

The existing full `Vehicles` persistence bridge carries this additive table. The global profile schema version is not bumped; the nested cosmetic state has its own version and normalisation.

## Asset Contract

V1 created a legacy Attachment mount. V1.1 retains support for that shape but makes attributed SurfaceLights authoritative and adds an authoring folder beneath every cockpit root:

```text
CockpitRoot_DoNotRename
  UNDERGLOW_EMITTERS_DoNotRename [Folder]
    FrontEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
    CentreEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
    RearEmitter [Part]
      UnderglowSurfaceLight [SurfaceLight]
```

Emitter Parts are authored in their final cockpit-local positions. The installer never moves or creates emitter geometry. It makes recognised parent Parts invisible, non-collidable, non-queryable, non-touchable, massless, unanchored and shadowless; the existing spawned-vehicle builder welds them to the cockpit root. Do not add manual WeldConstraints.

Every authored SurfaceLight must use `VehicleCosmeticId="Underglow"`; V1.2 also accepts `LightChannel="Underglow"`, the new folder ancestry, and the old `UNDERGLOW_MOUNT_DoNotRename` ancestry. The runtime owns only `Color` and `Enabled`. Each cockpit template independently authors Brightness, Range, Angle, Face, Shadows and every other light property in Studio.

Tuning and economy attributes are under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.VehicleCosmetics
  ThrustColour
  Underglow
```

Prices, icons, default colour, availability and diagnostics remain editable there. V1.2 removes the obsolete global Brightness, Range, Angle and MaxEmitters attributes and sets `LightPropertyMode="AuthoredPerVehicle"`. `DebugEnabled` optionally publishes detected/enabled/unlocked/colour attributes on runtime vehicle models for focused testing; keep it false for production.

## Transaction And Rollback Rules

- Purchase checks the current vehicle, availability, support, ownership, and cash before mutation.
- Thrust and All Neon capture physical module-instance state through the existing authoritative instance runtime.
- Capture failure restores the complete affected colour/instance snapshot.
- The Studio installer compiles all projected sources before mutation and restores sources, attributes, existing mount/light properties, and newly created instances if its committed audit fails.
- No in-game backup folder or script is created.

## Verification

1. Restart Studio after the installer passes.
2. Open Paint Shop with a vehicle that has all core modules.
3. Confirm All and Cockpit open sliders immediately.
4. Confirm locked Thrust and Underglow show a priced shared purchase card; buy each and confirm it immediately opens its sliders.
5. Change thrust colour and verify thrust VFX changes while front and rear lights do not.
6. Change underglow and verify every attributed SurfaceLight beneath the vehicle changes while its authored Brightness, Range, Angle, Face and Shadows remain unchanged.
7. Change All Neon and verify cockpit neon, owned module neon, and owned underglow change together while front/rear lights remain unchanged.
8. Remove or switch away from a physical module. From Paint and Upgrade, select its short plus card, buy/equip the exact module, and confirm the UI returns to the originating page.
9. Test desktop and mobile, Drive, vehicle switching, garage display vehicles, save/rejoin, and insufficient-cash purchase handling.
10. Refresh the Studio mirror only after these checks pass.

For V1.2, also verify the installer prints six cockpits and eight current lights, Bruiser 01 reports its three Part emitters, all emitter Parts remain in their authored positions, and repeated preview/Drive/display transitions do not create extra lights or physics parts. More than four authored lights on one cockpit produces a mobile profiling warning but does not disable or alter any light.

## Rollback

If the installer aborts, its in-memory transaction restores the pre-run Edit state. After a successful install, use Roblox place version history for a full rollback; do not construct an in-game backup hierarchy.
