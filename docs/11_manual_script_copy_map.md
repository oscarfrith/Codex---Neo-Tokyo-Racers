# Current Studio entry points

Performance Phase 5 is already installed through MCP; user playthrough pending. No manual paste is needed.

| Purpose | Script |
|---|---|
| Current audit / deliberate recovery | scripts/roblox_performance_phase5_catalogue_transport.lua; MODE AUDIT / ROLLBACK |
| General read-only audit | scripts/studio_cleanup_audit.lua |
| Export Edit place | scripts/studio_export_snapshot.lua, with scripts/receive_studio_snapshot.py running locally |
| Local mirror integrity | scripts/verify_studio_mirror.py |
| Exact current source/property parity | scripts/performance_phase5/verify_migration.py |
| Executable naming exceptions | scripts/audit_cleanup.py |

Actual source paths are roblox/exported_scripts/manifest.json. Do not paste historical standalone scripts over canonical modules. Roll back performance Phase 5 then Phase 4 then Phase 3 then Phase 2 before cleanup Phase 4 or older recovery; preserve the accepted September 22 physical baseline. Old instructions are history/cleanup-phase4-prior-docs/11_manual_script_copy_map.md.
