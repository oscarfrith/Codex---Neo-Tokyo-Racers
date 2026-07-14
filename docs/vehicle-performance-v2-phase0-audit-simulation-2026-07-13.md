# Vehicle Performance V2 — Phase 0 Audit and Simulation

Date: 2026-07-13

Status: live Studio audit completed at 2026-07-13 20:11:53 with `21 PASS / 2 WARN / 0 FAIL`. Google Sheet simulation is draft-only and does not drive the game.

## Confirmed live audit result

The live audit confirmed five cockpits, 72 active modules, 23 upgrade definitions, all 17 raw variables, all 12 Viper donor geometry roots, and unused `bruiser_06` / `BRUISER_06` identities. Current V1 standard-build ratings were Viper C530, Forge C563, Vector C592, Nightline B600, and Rally B604.

Both warnings are understood:

1. The clamp-marker check used the wrong text shape (`math.clamp(engineFactor` instead of `local engineFactor = math.clamp(`). The refreshed mirror confirms the V1 dynamics factor clamps are present. The audit script is corrected for future runs.
2. Live `ReverseEngageDelaySeconds` is `0.3`, not the confirmed/documented `1.0`. Drift values are correct: `DriftForwardDragBase = 0.18`, `DriftForwardDragBlendExtra = 0.10`, and full drift `0.28`.

Phase 0 therefore passes its structural gate, but Phase 1 must not switch rating/physics until the reverse-delay discrepancy is either restored to `1.0` with a config-only change or explicitly accepted as a new baseline.

## Phase 0 boundary

Phase 0 establishes evidence and a safe tuning workspace. It does not replace the live V1 calculator, change driving physics, migrate upgrades, clone assets, create the sixth vehicle, or change any live cockpit/module price.

This is intentional. The current Driving Feel Phase 2.1 baseline is confirmed good, while the current rating calculator is linear/capped and the dynamics model has separate factor clamps. Switching either side before both use one curve definition risks a rating that describes different behaviour from the car players actually drive.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase0_audit.lua`

The audit is read-only. It checks:

- the shared Phase AL/AM performance modules and config;
- the 17-variable raw performance contract;
- current cockpit, active-module, and upgrade-definition counts;
- all five current cockpit identities and their standard builds under V1;
- the four included standard-module IDs on each cockpit;
- all 12 Viper Standard/Lightweight/Power donor models and their geometry roots;
- availability of `bruiser_06` and the `BRUISER_06` module-ID family;
- the live dynamics module and expected V1 clamp markers;
- preservation of the confirmed reverse-delay/drift-momentum config;
- the six target vehicles, target PI centres, and price guides as non-live reference data.

Expected Phase 0 counts are five cockpits, 72 active modules, and 23 upgrade definitions. A changed count is a warning, not automatically a failure, because the live place may legitimately be newer than this handoff.

## Sheet foundation

The existing Google Sheet gains two isolated, tall pages:

- `Tier Templates`: the six target stock builds and price guides. These values guide later balancing; they are not authored final ratings or live prices.
- `V2 Simulation`: a one-build sandbox that converts the existing Build Simulator raw values through draft per-stat power curves, relationship-based headline formulas, and an asymptotic PI curve.

The simulator preserves uncapped raw stats. Technical minimums prevent invalid inverse calculations only. It retains decimal PI internally and rounds only the display value.

Initial draft controls:

- `BalanceContribution = 0.075`
- `BaseContribution = 0.925`
- `InteractionBlend = 0.30`
- `RatingScale = 150`
- PI floor/soft ceiling `100 / 999`

These are calibration starting points, not runtime decisions. Phase 1 should tune them against all six balanced stock targets and specialist/cross-tier module swaps before any live switch.

## Exit gate

Proceed to Phase 1 only when:

1. the audit has zero failures;
2. all warnings are explained;
3. the Viper donor set and reserved Zenith IDs are safe;
4. the Sheet has no formula errors;
5. V2 remains clearly marked simulation-only;
6. the next implementation uses one shared definition for both rating and physics factors.

## Rollback

The Studio audit requires no rollback because it writes nothing. Sheet rollback is limited to deleting the two new tabs and the appended change-log row; no current vehicle data or V1 formula is overwritten.
