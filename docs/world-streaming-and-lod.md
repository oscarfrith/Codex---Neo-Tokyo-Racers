# World streaming and LOD

All four cleanup phases are user-confirmed. Performance Phase 2 is installed/agent-verified; user playthrough pending. Mirror 2026-09-22 12:07:02 passes exact expected parity. See architecture/performance-phase2-server-storage.md. This storage migration preserves this system's gameplay/presentation and tuning.

Workspace.World is the scoped world. LODClient/LODRuntime/LODPolicy retain ownership; Config.World.LOD holds tuning. Lighting uses Config.World.Lighting, Assets.World.Skies and Modules.Game.World.LightingSchedule/LightingPresets. No distance, loop, placement or geometry changes. Preserve current arrows and excluded thumbnail WIP.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/world-streaming-and-lod.md; old installation instructions are historical, not pending tasks.
