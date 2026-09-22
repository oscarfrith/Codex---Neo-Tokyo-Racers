# Driving mechanics

All four cleanup phases are user-confirmed. Performance Phase 2 is installed/agent-verified; user playthrough pending. Mirror 2026-09-22 12:07:02 passes exact expected parity. See architecture/performance-phase2-server-storage.md. This storage migration preserves this system's gameplay/presentation and tuning.

DrivingClient, DrivingCameraClient, VehicleDynamics and DriveSessionClient retain existing ownership/equations. Config.Vehicles holds tuning. Numeric tokens, camera setters and values are preserved. CAM-02 NaN/clamp is a pre-existing separate issue. Verify steering/reverse/braking/boost/drift and exit/re-entry.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/03_driving_mechanics.md; old installation instructions are historical, not pending tasks.
