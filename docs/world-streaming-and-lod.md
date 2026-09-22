# World streaming and LOD


Current baseline and acceptance: [start here](00_START_HERE.md); outstanding checks: [open issues](06_current_known_issues.md).

Workspace.World is the scoped world. LODClient/LODRuntime/LODPolicy retain ownership; Config.World.LOD holds tuning. Lighting uses Config.World.Lighting, Assets.World.Skies and Modules.Game.World.LightingSchedule/LightingPresets. No distance, loop, placement or geometry changes. Preserve current arrows and excluded thumbnail WIP.

See architecture/cleanup-phase4-finalisation.md. Detailed historical behaviour/tuning notes remain in history/cleanup-phase4-prior-docs/world-streaming-and-lod.md; old installation instructions are historical, not pending tasks.
