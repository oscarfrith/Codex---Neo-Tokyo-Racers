# Stat-scaled post-drift boost

## Status

Generated against the refreshed `2026-07-14 11:55:47` Studio mirror; awaiting Studio installation and Play verification.

## Purpose

The preceding post-drift reward used universal hard-coded duration and acceleration. A full charge could last about `1.78 s` and apply almost the same acceleration to every tier. Normal boost also paused the timer, allowing the reward to queue and resume afterward.

`scripts/roblox_driving_drift_mini_boost_stat_scaling.lua` changes the reward while preserving every existing config value:

- drift charge determines reward quality;
- `DriftChargeRate` still determines how quickly quality is earned;
- mapped `BoostForce` applies bounded diminishing scaling to reward acceleration;
- mapped `BoostDuration` applies bounded diminishing scaling to reward duration and already includes its existing small `BoostEfficiency` contribution;
- normal boost has priority, but the post-drift timer continues expiring instead of queueing;
- the default absolute duration cap becomes `0.90 s`.

This makes the Boost `Burst` upgrade path improve post-drift force and the Boost `Endurance` path improve post-drift duration. Recovery remains specific to normal boost recovery.

## Configuration

All new numbers and paired descriptions are under:

`ReplicatedStorage.NeoTokyoRacers.Config.Runtime.VehicleDynamics_EditAttributes.03_Drifting`

The installer snapshots every existing Attribute in the full dynamics config and verifies each remains equal before and after source installation. Existing edited acceleration, handling, drift, boost, braking, grip, top-speed, boolean, and metadata values are not rewritten.

Important starting values:

- `DriftMiniBoostAbsoluteMaxDurationSeconds = 0.90`
- `DriftMiniBoostBaseMinDurationSeconds = 0.18`
- `DriftMiniBoostBaseMaxDurationSeconds = 0.70`
- `DriftMiniBoostMinAcceleration = 32`
- `DriftMiniBoostMaxAcceleration = 72`
- `DriftMiniBoostBoostForceMinMultiplier = 0.65`
- `DriftMiniBoostBoostForceMaxMultiplier = 1.25`
- `DriftMiniBoostBoostDurationMinMultiplier = 0.80`
- `DriftMiniBoostBoostDurationMaxMultiplier = 1.20`

## Verification

1. Use low-, middle-, and high-tier stock builds and perform similarly charged drifts.
2. Confirm the low-tier reward is substantially weaker and no reward exceeds about `0.90 s` with defaults.
3. Compare two otherwise identical builds with different BoostForce values; higher BoostForce should increase `DriftMiniBoostAcceleration`.
4. Compare different mapped BoostDuration values; higher duration should increase `DriftMiniBoostDurationSeconds` within the cap.
5. Spend Burst and Endurance points on eligible Lightweight/Power boost modules and confirm the corresponding reward property increases.
6. Hold normal boost as drift ends. Confirm normal boost takes priority and the post-drift timer expires rather than resuming afterward.
7. Confirm normal boost drain, duration, recharge, camera response, drifting, and steering remain otherwise unchanged.

With existing drift debug enabled, the spawned vehicle exposes charge quality, duration/force multipliers, final duration, and final acceleration.

## Rollback

Set `DriftMiniBoostStatScalingEnabled = 0` to restore the legacy reward formula. Set `DriftMiniBoostExpiresDuringNormalBoost = 0` to restore queued timer behaviour. Full source rollback uses the preceding confirmed Studio history point; no backups are created.

## Mirror

The mirror is not refreshed for this generated change. Refresh the full Studio snapshot after installation and verification.
