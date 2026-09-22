# World streaming and LOD

All four cleanup phases are user-confirmed. Post-confirmation mirror 2026-09-22 11:00:13 passes exact Phase 4 parity. The separate performance/replication programme is proposed only; see architecture/performance-and-replication-plan.md.

Workspace.World is the scoped world. LODClient/LODRuntime/LODPolicy retain ownership; Config.World.LOD holds tuning. Lighting uses Config.World.Lighting, Assets.World.Skies and Modules.Game.World.LightingSchedule/LightingPresets. No distance, loop, placement or geometry changes. Preserve current arrows and excluded thumbnail WIP.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/world-streaming-and-lod.md; old installation instructions are historical, not pending tasks.
