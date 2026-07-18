# Driving Feel Phase 3 — Tier Curves And Drift Drive

Date: 2026-07-14

Status: generated as one consolidated stage; awaiting Studio install and Forge/Viper/Zenith verification.

## Purpose

Vehicle Performance V2 exposed physical ranges that were much wider than the earlier driving model expected. The rating calculator applied diminishing returns, but steering and boost timing still consumed several raw values almost directly:

- E-to-S SteeringResponse was `15` to `210`;
- effective boost duration was approximately `1` to `6` seconds;
- boost recharge was `14` to `4` seconds;
- acceleration was strongest from zero speed and only fell afterward;
- full drift reduced lateral grip from about `6.6` to `1.05`, added a strong sideways force, and did not rotate velocity into the corner.

Phase 3 leaves raw stats, PI, tier bands, modules, upgrades, prices, and economy unchanged. It maps raw stats into bounded physical ranges inside the isolated dynamics owner.

## Installer

Run in Studio Edit mode:

`scripts/roblox_driving_feel_phase3_tier_curve_drift_drive.lua`

This is one stage. It canonically replaces `VehicleDynamicsModel` and makes two hard-preflighted exact-source replacements in `DrivingControllerV47`: the weight influence block and drift-drive block. The replacements are fragile by nature; if either anchor differs, the installer stops before mutation. It does not touch the register-limited bootstrap.

On the first install it writes the new baseline values. Safe reruns preserve edited Phase 3 values.

## Where to tune

Select this folder in Studio Edit mode and use its Attributes panel:

`ReplicatedStorage.NeoTokyoRacers.Config.Runtime.VehicleDynamics_EditAttributes`

Restart Play and spawn a fresh vehicle after editing.

## Main acceleration controls

| Attribute | Baseline | Raise it | Lower it |
|---|---:|---|---|
| `BaseForwardAcceleration` | `32` | More acceleration across the full curve | Less acceleration everywhere |
| `LaunchAccelerationMultiplier` | `0.45` | Stronger initial 0–14 MPH launch | Softer initial launch |
| `LaunchRampEndMph` | `14` | Soft-launch phase lasts longer | Full acceleration arrives sooner |
| `LaunchEngineInfluence` | `0.35` | Larger tier difference from standstill | More similar launches across tiers |
| `EngineOutputExponent` | `0.55` | Larger acceleration difference between low/high power | More compressed tier difference |
| `PowerBandStartRatioLow` | `0.48` | Low-power cars retain pull further toward top speed | Low-power acceleration fades earlier |
| `PowerBandStartRatioHigh` | `0.70` | Powerful cars retain pull further toward top speed | Powerful acceleration fades earlier |
| `HighSpeedAccelerationExponent` | `0.80` | Pull falls more sharply after the power band | Gentler high-speed falloff |
| `HighSpeedAccelerationFloor` | `0.06` | More engine pull very near top speed | Less pull near top speed |
| `AerodynamicDragPerMphSquared` | `0.00012` | More high-speed air resistance | Less high-speed resistance |

The intended shape is soft at launch, strongest after roughly 10–14 MPH, then progressively weaker after the vehicle’s power band. EngineOutput moves the power-band end later for more powerful builds.

## Main handling controls

| Attribute | Baseline | Raise it | Lower it |
|---|---:|---|---|
| `BasePhysicalSteeringResponse` | `58` | Faster steering for every car | Slower steering for every car |
| `SteeringResponseExponent` | `0.42` | Larger E-to-S steering difference | More similar steering across tiers |
| `SteeringResponseMinMultiplier` | `0.78` | Makes the weakest cars turn better | Makes low-tier steering heavier |
| `SteeringResponseMaxMultiplier` | `1.30` | Allows sharper top-tier steering | Caps top-tier steering more strongly |
| `SteeringWeightInfluenceExponent` | `0.12` | Weight changes steering more | Weight has less steering effect |
| `BaseNormalLateralGrip` | `6.6` | More planted normal cornering | More normal sideways movement |
| `LateralGripExponent` | `0.40` | Larger stat-based grip difference | More consistent grip across tiers |
| `DownforceGripInfluence` | `0.22` | Downforce affects high-speed grip more | Downforce affects handling less |

The steering response physical range is initially bounded to approximately `0.78x–1.30x`, before the much smaller weight influence. This prevents the raw `15–210` stat range from becoming a 14× turn-rate range.

## Main drift controls

| Attribute | Baseline | Raise it | Lower it |
|---|---:|---|---|
| `BaseDriftLateralGrip` | `2.0` | Less sideways slide; more planted drift | Looser, more boat-like drift |
| `BaseDriftSideForce` | `26` | More artificial sideways rotation | Less sideways shove |
| `DriftForwardDragBase` | `0.10` | More speed loss throughout drift | Better momentum retention |
| `DriftForwardDragBlendExtra` | `0.06` | More loss at full drift commitment | Full drift retains more speed |
| `DriftEngineAssist` | `0.20` | Engines pull harder through the corner | Less extra drift drive |
| `DriftVelocityAlignmentRate` | `2.0` | Momentum rotates toward vehicle facing faster | More lingering sideways velocity |
| `DriftVelocityAlignmentMaxAcceleration` | `30` | Stronger maximum cornering pull | Softer alignment intervention |
| `DriftThrottleMinimum` | `0.05` | More throttle required before assist starts | Assist begins with lighter throttle |
| `PhysicalDriftControlMaxMultiplier` | `1.25` | Allows more top-tier yaw authority | Caps high-tier drift authority |

Velocity alignment is force-based and only active while acceleration is held. It does not snap `AssemblyLinearVelocity`. DriftControl affects turning/alignment, DriftGrip affects remaining slip, and EngineOutput affects drive assistance.

## Main boost controls

| Attribute | Baseline | Raise it | Lower it |
|---|---:|---|---|
| `BoostDurationMinSeconds` | `2.2` | Low-tier boost drains more slowly | Low-tier boost drains faster |
| `BoostDurationMaxSeconds` | `4.2` | Top-tier boost lasts longer | Top-tier boost drains faster |
| `BoostRechargeMinSeconds` | `6.5` | Fastest recharge becomes slower | Fastest recharge becomes quicker |
| `BoostRechargeMaxSeconds` | `10.5` | Slowest recharge becomes slower | Low-tier recharge becomes quicker |
| `BoostRechargeDelayMinSeconds` | `0.40` | Raises the shortest post-boost delay | Allows shorter top-tier delays |
| `BoostRechargeDelayMaxSeconds` | `1.0` | Raises the longest post-boost delay | Shortens low-tier delays |
| `BoostEfficiencyTimingExponent` | `0.15` | BoostEfficiency changes timing more | BoostEfficiency has less timing effect |

Raw boost stats still determine where each build sits within these physical bounds. The initial target is roughly `2.2s / 10.5s` at E and `4.2s / 6.5s` at S instead of approximately `1s / 14s` and `6s / 4s`.

## Organised Studio tuning layout

The canonical organiser also includes the stat-scaled post-drift reward values under `03_Drifting`. Category values remain authoritative, so rerunning it preserves live edits while retaining the specific duration/force descriptions instead of treating these settings as unknown advanced values.

After Phase 3 is installed, run `scripts/roblox_driving_feel_phase3_organized_tuning_values.lua` once in Edit mode. It preserves every current numeric value and migrates the flat tuning attributes into ordered category folders:

```text
VehicleDynamics_EditAttributes
  01_Acceleration
  02_Handling
  03_Drifting
  04_Boost
  05_Braking_Reverse_Parking
  06_Grip_Hover
  07_Advanced
```

Select one category Folder to see all of that category's tuning in its Attributes panel. Every numeric attribute is followed alphabetically by a paired string attribute using the same name plus `_RaisingThisDoes`, for example:

```text
BaseForwardAcceleration = 32
BaseForwardAcceleration_RaisingThisDoes = "Increases forward acceleration across the speed range."
```

The migration supports the original flat Phase 3 layout, the earlier generated per-setting-folder layout, and this final flat-category layout. Existing category numbers win first, then prior `01_Value` NumberValues, then original root numeric attributes, then defaults. Source readers are changed only after hierarchy verification, and obsolete per-setting folders are removed only after both readers are installed. Reruns preserve existing category attributes. Boolean rollback/debug switches and string metadata remain as root attributes.

## Physical top-speed curve

The same canonical organiser adds six new `01_Acceleration` attributes without changing any existing edited value:

| Attribute | Initial value | Raise it |
|---|---:|---|
| `PhysicalTopSpeedAtReferenceMph` | `140` | Raises physical top speed around the reference stat for every vehicle |
| `TopSpeedRawReference` | `137` | Reduces mapped speed for the same raw TopSpeed stat |
| `PhysicalTopSpeedExponent` | `0.55` | Widens the physical speed difference below and above the reference |
| `PhysicalTopSpeedMinMph` | `60` | Raises the lowest result the mapping can produce |
| `PhysicalTopSpeedMaxMph` | `300` | Raises the normal configurable physical ceiling |
| `AbsoluteTopSpeedSafetyMph` | `320` | Raises the final safety ceiling when the physical maximum is also high enough |

The physical target is:

```text
PhysicalTopSpeedAtReferenceMph * (RawTopSpeed / TopSpeedRawReference) ^ PhysicalTopSpeedExponent
```

It is then constrained by the editable physical minimum, physical maximum, and absolute safety maximum. Raw TopSpeed remains unchanged for V2 rating, module swapping, and upgrade calculations. With the initial values, the six stock raw speeds map to approximately Forge `86`, Vector `114`, Viper `140`, Nightline `169`, Rally `207`, and Zenith `238 MPH`. The old hidden fixed `260 MPH` controller/module caps are replaced by the mapped result and configurable safety value.

Useful debug attributes on a spawned vehicle are `DynamicsRawTopSpeed` and `DynamicsMappedTopSpeedMph`. The mapped target is not guaranteed road speed: acceleration fade and `AerodynamicDragPerMphSquared` still determine whether the car has enough force to reach it. The refreshed pre-patch mirror records a user-edited aerodynamic coefficient of `0.015`, versus the original Phase 3 default `0.00012`; this is intentionally preserved and can create a much lower aerodynamic equilibrium speed.

## Verification

Test Forge E, Viper C, and Zenith S in a fresh Play session:

1. Compare 0–10, 10–60, and 60 MPH-to-top-speed acceleration.
2. Confirm all three launch softly, accelerate harder after approximately 10–14 MPH, and lose pull near top speed.
3. Confirm Forge steering is usable and Zenith is sharper without being twitchy or rotating excessively.
4. Fully drain and recharge boost; record approximate duration, recharge delay, and full refill time.
5. Enter a 50–70 MPH drift while holding acceleration. The vehicle should rotate and pull through the corner rather than continuing sideways like a boat.
6. Release acceleration during drift. Engine assist/alignment should stop and the car should remain looser.
7. Verify braking, parking hold, one-second reverse, boost force, drift mini-boost, camera, UI, VFX, mobile, and racing remain healthy.

Useful spawned-vehicle debug attributes include `DynamicsLaunchFactor`, `DynamicsPowerBandStartRatio`, `DynamicsHighSpeedAccelerationFactor`, `DynamicsMappedSteeringResponse`, `DynamicsMappedBoostDuration`, `DynamicsMappedBoostRecharge`, `DynamicsDriftEngineAssist`, and `DynamicsDriftAlignmentAcceleration`.

## Rollback

Set the root attribute `VehicleDynamics_EditAttributes.Enabled = false` to return to the legacy driving-force path. For a narrower rollback, restore the previous Phase 2.1 values and source through Roblox version history; no in-game backup objects are created.
