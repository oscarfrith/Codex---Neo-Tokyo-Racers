# Phase 4 recovery and verification

Canonical installer: ../roblox_cleanup_phase4_finalise.lua. Already installed; user test pending. Do not run older phase installers without dependent rollback.

before/, baseline.json and hierarchy-before.json.gz freeze the September 22 arrival baseline after user approval of physical differences. arrival-* records explain differences from September 5; historical Phase 3 verification files remain unchanged.

build.py uses token-aware identifier/diagnostic mappings and collision/reflection guards; installer.lua is packaged with exact before/after sources. No live anchor patching or instance mutations. source-change-report.json enumerates changes. verify_migration.py compares every source and captured property against that baseline. verification.json and runtime-verification.json record final evidence.

Historical GUI suppression keys and saved identities are deliberate exceptions. Protected staging/archive content is untouched. See docs/architecture/cleanup-phase4-finalisation.md.
