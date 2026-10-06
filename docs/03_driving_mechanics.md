# Driving mechanics

Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

DrivingClient, DrivingCameraClient, VehicleDynamics and DriveSessionClient retain existing ownership/equations. Config.Vehicles holds tuning. Numeric tokens, camera setters and values are preserved. CAM-02 NaN/clamp is a pre-existing separate issue. Verify steering/reverse/braking/boost/drift and exit/re-entry.

Since 2026-10-06 ([driving tune](../scripts/driving_tune/CONTRACT.md)): `VehicleDynamics.Balance(vehicle)` scales forces by the car's `PerformanceIndex` (config `Dynamics.08_Balance`); DrivingClient owns a dynamic ride height (`HOVER_HEIGHT` x settle + bank lift + bob, config `HoverPose` and `HoverWobble`) and publishes the HUD speed through its display curve; FreeRoamParkedHoverClient animates the owner's anchored parked car locally. The real speed is still `FeelSpeedMph`.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/03_driving_mechanics.md; old installation instructions are historical, not pending tasks.
