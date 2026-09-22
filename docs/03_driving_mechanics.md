# Driving mechanics

All four cleanup phases are user-confirmed. Post-confirmation mirror 2026-09-22 11:00:13 passes exact Phase 4 parity. The separate performance/replication programme is proposed only; see architecture/performance-and-replication-plan.md.

DrivingClient, DrivingCameraClient, VehicleDynamics and DriveSessionClient retain existing ownership/equations. Config.Vehicles holds tuning. Numeric tokens, camera setters and values are preserved. CAM-02 NaN/clamp is a pre-existing separate issue. Verify steering/reverse/braking/boost/drift and exit/re-entry.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/03_driving_mechanics.md; old installation instructions are historical, not pending tasks.
