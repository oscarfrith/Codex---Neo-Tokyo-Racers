# Vehicle VFX and audio

Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

VehicleVFXClient remains runtime attachment owner; VehiclePreviewVFXClient owns preview behaviour. VFXAttachments folder hooks and generic audio groups are current. Physical attachment names, effects, tuning and subscriptions are preserved. Development tools stay opt-in.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/05_vfx_system.md; old installation instructions are historical, not pending tasks.

## Drivetrain cues (2026-10-20, DRIVE-03)

For an Exotic with the drivetrain active, thrust intensity follows `FeelLoad`, a vent flame fires on hard upshifts (`FeelShiftRevision`, never through `FeelPopRevision`), the stabiliser jets stutter on `FeelSpin`, and the rear over-glows on `FeelThrustSlip`. Switch: `Config.Vehicles.StabiliserVFX@DrivetrainVFXEnabled`. The camera's spin mode, shift nod and limiter shimmer sit behind `Config.Vehicles.Camera@ChaseDrivetrainEnabled`. Details: [camerafx NOTES](../scripts/drivetrain_feel/camerafx/NOTES.md).
