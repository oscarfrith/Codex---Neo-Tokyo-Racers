# Driving Feel Tuning Reference

**Baseline:** Driving Feel Phase 2.1, user-confirmed improved on 2026-07-13

## Where To Tune

In Studio Edit mode, select:

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      Runtime
        VehicleDynamics_EditAttributes
```

Edit values in the folder's **Attributes** section in Properties. Restart Play and spawn a fresh vehicle after changes. Changes made only while Play is running normally revert when Play stops.

`Reference` values are neutral comparison points, not maximums. `Exponent` values control how strongly a vehicle stat affects physics: raising an exponent generally increases the difference between low- and high-stat builds.

## Recommended Everyday Controls

| Attribute | Current | Raise it | Lower it |
|---|---:|---|---|
| `BaseForwardAcceleration` | `24` | Stronger acceleration everywhere | Softer acceleration |
| `AccelerationCurveExponent` | `0.65` | Power fades earlier as speed rises | More pull toward top speed |
| `AerodynamicDragCoefficient` | `0.012` | More high-speed resistance | Easier top-speed approach |
| `CoastBaseDeceleration` | `3.2` | Slows sooner after releasing acceleration | Floats/coasts longer |
| `CoastSpeedCoefficient` | `0.03` | More speed-dependent coast-down | More consistent coasting at all speeds |
| `BaseBrakeDeceleration` | `30` | Shorter stopping distance | Softer braking |
| `ReverseEngageDelaySeconds` | `1.0` | Longer pause before reverse | Reverse engages sooner |
| `ReverseAcceleration` | `12` | Stronger reverse launch | Gentler reverse |
| `BaseNormalLateralGrip` | `6.6` | More planted ordinary cornering | More ordinary sideways slip |
| `BaseDriftLateralGrip` | `1.05` | Drift slides less sideways | Drift becomes looser |
| `BaseDriftSideForce` | `34` | Stronger drift side-force/authority | Softer drift movement |
| `DriftForwardDragBase` | `0.18` | Drift loses forward speed faster | Drift carries more momentum |
| `DriftForwardDragBlendExtra` | `0.10` | Fully committed drift loses more speed | Full drift retains more speed |
| `BaseAlignResponsiveness` | `22` | Vehicle aligns to terrain more sharply | Softer, floatier alignment |

At full drift, forward-drag coefficient is approximately `DriftForwardDragBase + DriftForwardDragBlendExtra`, currently `0.28`. Change these in small steps of about `0.02–0.05`.

## Stat Scaling Controls

| Attribute pair | Vehicle stat affected | Meaning |
|---|---|---|
| `EngineOutputReference` / `EngineOutputExponent` | `EngineOutput` | Acceleration strength; exponent controls build-to-build difference |
| `WeightReference` / `WeightAccelerationExponent` | `Weight` | Lighter builds accelerate better; exponent controls sensitivity |
| `DragReference` | `Drag` | Higher vehicle Drag increases aerodynamic resistance |
| `BrakingForceReference` / `BrakingForceExponent` | `BrakingForce` | Higher stat gives stronger brakes |
| `LateralGripReference` / `LateralGripExponent` | `LateralGrip` | Higher stat resists ordinary sideways slide |
| `DownforceReference` / `DownforceGripInfluence` | `Downforce` | Higher stat adds more grip as speed rises |
| `DriftGripReference` / `DriftGripExponent` | `DriftGrip` | Higher stat reduces sideways drift slip |
| `DriftControlReference` / `DriftControlExponent` | `DriftControl` | Higher stat increases drift side force and turning authority |
| `DriftChargeReference` / `DriftChargeExponent` | `DriftChargeRate` | Higher stat charges drift mini-boost faster |
| `HoverStabilityReference` / `HoverStabilityExponent` | `HoverStability` | Higher stat makes terrain alignment more responsive |

`HighSpeedGripMph` controls the speed where the Downforce contribution reaches full influence. It does not set vehicle top speed.

## Parking And Reverse

| Attribute | Current | Effect |
|---|---:|---|
| `ThrottleDeadzone` | `0.05` | Ignores very small throttle/brake input |
| `StopThresholdMph` | `1.5` | Speed below which held brake can enter stopped/reverse-delay state |
| `AutoHoldMph` | `1.25` | Speed below which neutral input holds the vehicle still |
| `ReverseEngageDelaySeconds` | `1.0` | Continuous stopped brake-hold time before reverse |
| `ReverseCurveExponent` | `0.8` | How quickly reverse acceleration fades near reverse top speed |

Avoid raising `StopThresholdMph` or `AutoHoldMph` too far: the vehicle can start snapping to a stop while it is still visibly moving.

## Advanced And Safety Attributes

- `Enabled`: master Phase 1–2.1 dynamics switch. `false` uses the legacy force path.
- `DetailedStatsEnabled`: enables individual detailed vehicle-stat reads.
- `HandlingEnabled`: disables only Phase 2 detailed handling when `false`.
- `DebugAttributes`: publishes `Dynamics...` attributes on the spawned vehicle.
- `SoftLimiterStrength`: correction strength only after exceeding forward/reverse speed limits.
- `BrakeWeightExponent`: how strongly Weight modifies braking.
- `DownforceGripInfluence`: maximum strength of Downforce's high-speed grip contribution.

## Related Older Driving Config

These remain under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes
```

Important examples are `ReverseMaxMph`, the `SpeedSteering...` curve values, `ReverseSteeringMultiplier`, `BoostSteeringMultiplier`, drift mini-boost requirements, slope-hover tuning, and acceleration/brake pitch tilt. They were not moved into `VehicleDynamics_EditAttributes` to avoid disturbing already-confirmed systems.

