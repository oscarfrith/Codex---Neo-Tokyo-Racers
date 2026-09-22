# World streaming and LOD

All four cleanup phases are user-confirmed. Performance Phase 5 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 13:01:09 passes exact 165-source/44,465-node/276,087-property parity. See architecture/performance-phase5-catalogue-transport.md. Unchanged catalogue responses are reused; every GetInitial still reads a fresh profile. Gameplay, physical properties and existing presentation owners are preserved.

Workspace.World is the scoped world. LODClient/LODRuntime/LODPolicy retain ownership; Config.World.LOD holds tuning. Lighting uses Config.World.Lighting, Assets.World.Skies and Modules.Game.World.LightingSchedule/LightingPresets. No distance, loop, placement or geometry changes. Preserve current arrows and excluded thumbnail WIP.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/world-streaming-and-lod.md; old installation instructions are historical, not pending tasks.
