# Driving mechanics

All four cleanup phases are user-confirmed. Performance Phase 4 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 12:47:08 passes exact 164-source/44,464-node/276,087-property parity. See architecture/performance-phase4-vehicle-previews.md. Gameplay and physical properties are preserved; original templates are server-only and client previews are generated.

DrivingClient, DrivingCameraClient, VehicleDynamics and DriveSessionClient retain existing ownership/equations. Config.Vehicles holds tuning. Numeric tokens, camera setters and values are preserved. CAM-02 NaN/clamp is a pre-existing separate issue. Verify steering/reverse/braking/boost/drift and exit/re-entry.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/03_driving_mechanics.md; old installation instructions are historical, not pending tasks.
