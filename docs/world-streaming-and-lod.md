# World streaming and LOD

All four cleanup phases are user-confirmed. Performance Phase 4 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 12:47:08 passes exact 164-source/44,464-node/276,087-property parity. See architecture/performance-phase4-vehicle-previews.md. Gameplay and physical properties are preserved; original templates are server-only and client previews are generated.

Workspace.World is the scoped world. LODClient/LODRuntime/LODPolicy retain ownership; Config.World.LOD holds tuning. Lighting uses Config.World.Lighting, Assets.World.Skies and Modules.Game.World.LightingSchedule/LightingPresets. No distance, loop, placement or geometry changes. Preserve current arrows and excluded thumbnail WIP.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/world-streaming-and-lod.md; old installation instructions are historical, not pending tasks.
