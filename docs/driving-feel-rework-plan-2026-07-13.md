# Driving Feel Rework Plan

**Created:** 2026-07-13  
**Status:** Phase 0 passed; Phase 1 confirmed; Phase 2 installed/good overall; Phase 2.1 correction generated

## Confirmed Mirror Findings

The 2026-07-13 10:59:59 Studio mirror is fresh, but it exposes a mismatch between the documented Phase AM baseline and the active `DrivingControllerV47` source:

- `VehiclePerformanceRuntimeService_Active` still writes the detailed runtime variables and rating.
- `RuntimeIntegration.PhysicsEnabled` is still `true`.
- The mirrored active driving module does not contain `NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE` and reads legacy totals instead.
- Initial forward force still uses `Acceleration * 3.1` with a linear speed limiter and an `0.08` force floor.
- Brake and reverse still share one continuous negative-throttle branch.
- Neutral drag remains low and the parked-hover client does not explicitly settle horizontal/angular velocity.
- The collidable vehicle root remains in the default collision setup, allowing characters to push it.
- Vehicle exit still uses a fixed `CFrame.new(-10, 3, 0)` offset rather than vehicle bounds and clearance checks.

Do not rerun the older Phase AM integration installer unchanged. Its guarded source replacements target an older controller shape.

## Condensed Delivery Plan

### Phase 0 — Live audit gate

Confirmed on 2026-07-13. The Edit audit passed `11/10/0` (`pass/warn/fail`) and the spawned `C 538` vehicle confirmed matching legacy/detailed headline aliases plus a collidable `Default` root. The two Play failures were caused only by running the audit in client context where server-only objects are hidden; the canonical audit now skips those checks on the client.

### Phase 1 — Core vehicle feel and detailed-stat reconnection

One installer may safely combine acceleration, progressive top-speed approach, coasting, braking/stopped/reverse states, and detailed-stat reconnection because these all own the same longitudinal force decision. Prefer an isolated `VehicleDynamicsModel` plus a small guarded bridge in `DrivingControllerV47`. Preserve hover, camera, input, boost publication, VFX attributes, and confirmed steering/pitch patches.

Installed and user-confirmed working well. The post-confirmation mirror was refreshed at 2026-07-13 12:30:18. See `docs/driving-feel-phase1-core-dynamics-2026-07-13.md`.

### Phase 2 — Handling and drift calibration

Connect `SteeringResponse`, `LateralGrip`, `Downforce`, `HoverStability`, `DriftControl`, `DriftGrip`, and `DriftChargeRate` through separate normal-driving and drift curves. Tune Standard first, then compare Lightweight and Power builds before changing performance-rating normalization or module economy.

Installed and reported good overall. The post-install mirror exposed excessive fixed drift drag and a reverse stopped-hold defect; the condensed Phase 2.1 correction is `scripts/roblox_driving_feel_phase2_1_drift_momentum_reverse_repair.lua`. See `docs/driving-feel-phase2-1-drift-momentum-reverse-2026-07-13.md`.

### Phase 3 — Parking, collision, and safe exit pack

This phase can safely combine low-speed parked settling, player-versus-vehicle collision groups, a low-speed exit gate, and bounds-aware clear exit placement because they share the parked/exit lifecycle. Keep vehicle-versus-world collision enabled and do not anchor parked vehicles.

### Phase 4 — Balance matrix and confirmation

Measure acceleration, braking, coast-down, top-speed approach, turning, drift recovery, parked displacement, exit clearance, and player pushing across representative Standard/Lightweight/Power builds and keyboard/gamepad/mobile. Update the confirmed baseline only after the user approves the feel.

## Initial Targets

- Standard 0–60 MPH: about `3.5–4.5 s`.
- Standard 0–100 MPH: about `8–11 s`.
- Reach 90% of top speed in about `12–18 s` rather than almost immediately.
- Brake 60–0 MPH in about `2.2–3.0 s` as a starting arcade target.
- Settle below parking speed without drifting indefinitely or engaging reverse immediately.
- Require a short stopped hold before reverse engages.
- Prevent characters from physically pushing vehicles while preserving world and vehicle collision.

## Rollback Strategy

- Use a config feature flag for the new dynamics path so the confirmed V75/V47 force path can be restored without deleting scripts.
- Keep new calculation behavior in an isolated module rather than the register-limited client bootstrap.
- Use guarded plain-text source checks for the small controller bridge and stop on unknown source shape.
- Create no in-game backups.
- Refresh the full Studio mirror after every installed and confirmed Studio phase.
