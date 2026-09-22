# Driving mechanics

All four cleanup phases are user-confirmed. Performance Phase 5 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 13:01:09 passes exact 165-source/44,465-node/276,087-property parity. See architecture/performance-phase5-catalogue-transport.md. Unchanged catalogue responses are reused; every GetInitial still reads a fresh profile. Gameplay, physical properties and existing presentation owners are preserved.

DrivingClient, DrivingCameraClient, VehicleDynamics and DriveSessionClient retain existing ownership/equations. Config.Vehicles holds tuning. Numeric tokens, camera setters and values are preserved. CAM-02 NaN/clamp is a pre-existing separate issue. Verify steering/reverse/braking/boost/drift and exit/re-entry.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/03_driving_mechanics.md; old installation instructions are historical, not pending tasks.
