# Driving Hover Height Config Bridge V1

Status: user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

Installer:

`scripts/roblox_driving_hover_height_config_bridge_v1.lua`

## Purpose

The editable value already exists at:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Editable
  01_GAME_BALANCE_Editable
    Driving
      HoverHeightStuds [NumberValue]
```

`DriveTuning.Read()` already projects it, but the active driven, fallback and parked-hover controllers still use separate hard-coded `3` constants. The spawned vehicle's `HoverHeight` diagnostic attribute is also hard-coded to `3`.

V1 makes the existing NumberValue authoritative for all four consumers. It creates no second configuration value and does not change spring strength, damping, slope compensation, ray origins, sensor length, alignment, steering, acceleration, drift, camera, VFX or vehicle persistence.

## Runtime Contract

- The value is read once when each controller module starts, avoiding a config lookup every physics frame.
- The supported range is `0.5-8` studs. Metadata on the NumberValue records the units, range, owner and restart requirement.
- Restart Play after changing the value.
- The active driven controller, fallback controller and parked-hover controller use the same resolved value.
- The server-created vehicle's `HoverHeight` attribute reports the same resolved configuration for diagnostics; it does not become another physics owner.
- The dormant register-limited bootstrap remains untouched.

## Verification

1. Run the installer in Edit mode and require its PASS output.
2. Restart Studio or start a fresh Play session.
3. Compare the vehicle's root clearance while driving and while parked.
4. Change `HoverHeightStuds`, restart Play and confirm both states change together.
5. Test flat ground, uphill/downhill ramps, cresting, reset, exit/re-entry, garage drive-out and vehicle respawn.
6. Confirm there is no bouncing, ground clipping, missed raycast hover or parked/driven height jump.
7. Keep production tuning comfortably below the parked sensor limit; `2.5-4.5` is the recommended initial tuning range.

## Rollback

The installer compiles all four projected sources before mutation and restores every source and edited attribute if its committed audit fails. After a successful install, use Roblox place version history for full rollback.
