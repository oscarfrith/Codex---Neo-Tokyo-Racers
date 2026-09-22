# Current Studio entry points

Phase 4 is already installed through MCP. No manual paste is needed.

| Purpose | Script |
|---|---|
| Exact Phase 4 audit / deliberate recovery | scripts/roblox_cleanup_phase4_finalise.lua; MODE AUDIT / ROLLBACK |
| General read-only audit | scripts/studio_cleanup_audit.lua |
| Export Edit place | scripts/studio_export_snapshot.lua, with scripts/receive_studio_snapshot.py running locally |
| Local mirror integrity | scripts/verify_studio_mirror.py |
| Exact Phase 4 source/property parity | scripts/cleanup_phase4/verify_migration.py |
| Executable naming exceptions | scripts/audit_cleanup.py |

Actual source paths are roblox/exported_scripts/manifest.json. Do not paste historical standalone scripts over canonical modules. Roll back Phase 4 before older recovery; preserve the accepted September 22 physical baseline. Old instructions are history/cleanup-phase4-prior-docs/11_manual_script_copy_map.md.
