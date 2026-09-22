# Vehicle VFX and audio

All four cleanup phases are user-confirmed. Performance Phase 2 is installed/agent-verified; user playthrough pending. Mirror 2026-09-22 12:07:02 passes exact expected parity. See architecture/performance-phase2-server-storage.md. This storage migration preserves this system's gameplay/presentation and tuning.

VehicleVFXClient remains runtime attachment owner; VehiclePreviewVFXClient owns preview behaviour. VFXAttachments folder hooks and generic audio groups are current. Physical attachment names, effects, tuning and subscriptions are preserved. Development tools stay opt-in.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/05_vfx_system.md; old installation instructions are historical, not pending tasks.
