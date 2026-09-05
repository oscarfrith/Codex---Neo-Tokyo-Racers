# Phase 5 source and verification

Canonical installer: `../roblox_architecture_phase5_world_optimisation.lua` (INSTALL/AUDIT/ROLLBACK, Edit only). Already applied by MCP; no ordinary manual installation. The original canonical LODClient is frozen in original.lua for exact rollback. No in-game backup is created.

Author LODClient.lua, LODRuntime.lua and LODPolicy.lua here; run build_installer.py to package the full source replacement and isolated tests/benchmark. Generated mirror source is output only. baseline.json records all pre-phase source identities so unrelated source/class/enabled changes can be rejected. Parent folders already exist; installer never creates unrelated architecture.

Tests use disposable unparented Instances. Deferred hierarchy callbacks are awaited with bounded predicates, not assumptions about one frame. Benchmark uses identical cloned authored city data and a fixed seven-position trace, with warmup and seven timed passes; it is not real-time FPS/streaming/device evidence. Cleanup destroys even legacy detached proxy clones.

Config: ReplicatedStorage.NeoTokyoRacers.Config.Runtime.WorldLOD. Defaults match the confirmed live source. Change tuning in Edit, then start fresh Play. DiagnosticsEnabled can be toggled during Studio Play; aggregated diagnostics update every five seconds at the old LODClient_Active adapter's Phase5Diagnostics attribute. Phase5Status reports waiting/running/failed. No diagnostic remote is added. Restore config defaults before an exact migration rollback.

LODRuntime tracks supported members via root signals, with reverse membership for deferred removal, plus two proxy-root child signals. Near bucket membership is cached; unchanged ticks do not scan hierarchies or write visibility. Far metadata for previously seen blocks uses scalar centers and authored template references; it does not retain unloaded models/parts. Far clones are destroyed outside the hysteresis band, trading future clone work for bounded retained instances. Runtime authoring renames should be followed by a fresh session; authored names are semantic IDs.

After any Studio installation/rollback, refresh the full mirror. Phase 4's exact migration verifier/rollback intentionally no longer matches the modified LODClient; roll Phase 5 back first rather than rewriting its frozen manifest.
