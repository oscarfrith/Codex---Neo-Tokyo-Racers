"""Record Phase 2 handoff; prune only obsolete generated projection files."""
from prepare import *
import gzip

def replace(path,old,new):
    p=ROOT/path;s=read(p)
    assert s.count(old)==1,(path,old[:90],s.count(old))
    write(p,s.replace(old,new,1))

def paragraph(path,prefix,new):
    p=ROOT/path;s=read(p);matches=[x for x in s.split('\n\n') if x.startswith(prefix)]
    assert len(matches)==1,(path,prefix)
    replace(path,matches[0],new)

def note(path,text):
    p=ROOT/path;s=read(p);head,body=s.split('\n',1);write(p,head+'\n\n'+text+'\n'+body)

link='[Complete cleanup Phase 2](architecture/cleanup-phase2-canonical-ownership.md)'
status='Phase 1 is user-confirmed. Complete cleanup Phase 2 is installed and agent-verified; user gameplay checkpoint pending. Phases 3 and 4 remain unimplemented.'
paragraph('docs/00_START_HERE.md','**Current programme:**',f'**Current programme:** {link} is installed and agent-verified; user gameplay checkpoint pending. Phase 1 is user-confirmed. Sources reduced from 323 to 160, with old adapters/code hosts removed and feature-owned Runtime endpoints preserved. Entire Workspace and physical content are unchanged. The [four-phase plan](architecture/complete-cleanup-plan.md) has two phases remaining. Wait for the user checkpoint before Phase 3; physical staging/archive decisions remain open.')
paragraph('docs/00_START_HERE.md','The user confirmed all five','The user confirmed all five original architecture phases and the subsequent complete-cleanup Phase 1 playthrough. The current Phase 2 checkpoint supersedes earlier pending cleanup wording. Read [the current handoff](architecture/cleanup-phase2-canonical-ownership.md). Opt-in development tools stay. Target-device and published persistence release gates remain distinct from phase completion.')
replace('docs/00_START_HERE.md','| Whole source mirror | Complete-cleanup Phase 1: 323 sources, refreshed 2026-09-05 12:36:11. All source SHA-256 hashes and remaining exported properties match the expected pre-phase baseline. Entire Workspace unchanged. ServerBase: 26 ready; ClientBase: 40 ready, 4 development tools skipped. All sources compile. |','| Whole source mirror | Complete-cleanup Phase 2: 160 sources, refreshed 2026-09-05 15:14:10. Source SHA-256 and complete expected exported hierarchy/property parity pass. Entire Workspace unchanged. ServerBase: 26 ready; ClientBase: 39 ready, 4 development tools skipped. All sources compile. |')
replace('docs/00_START_HERE.md','Phase 4 implementations live in ReplicatedStorage.Modules.Game; old paths forward to the same owners/renderers.','Canonical implementations live in ReplicatedStorage.Modules.Game; forwarding adapters are removed. GarageUI starts directly; DriveSessionClient owns vehicle session callbacks.')
paragraph('docs/00_START_HERE.md','Generated, installed,','Generated, installed, runtime verified and user confirmed are distinct states. Source parity does not prove gameplay acceptance. Old Services/client adapter trees and GarageClient are removed. GarageServer, GarageUI and DriveSessionClient are current owners; use the Phase 2 maps and actual exported manifest.')
paragraph('docs/architecture/complete-cleanup-plan.md','2026-09-05.',f'2026-09-05. **{status}** See [the Phase 2 handoff](cleanup-phase2-canonical-ownership.md). This programme is separate from the five completed original architecture phases.')
paragraph('docs/architecture/complete-cleanup-plan.md','Phase 1 is **',status+' Canonical current installer: `scripts/roblox_cleanup_phase2_canonical_ownership.lua`; already run. See its handoff for verification and recovery. Physical staging/archive disposition remains open for the later asset portion. No new phase subdivision is authorised.')
paragraph('docs/architecture/cleanup-phase1-scaffolding.md','2026-09-05.','2026-09-05. **User-confirmed working by the continuation to complete cleanup Phase 2.** This is Phase 1 of the new four-phase plan. Current installed source baseline is in [the Phase 2 handoff](cleanup-phase2-canonical-ownership.md).')
replace('docs/06_current_known_issues.md','| CLEAN-01 | Phase 1 installed / user checkpoint | 91 scaffold/report objects and 15 obsolete root attributes removed; all 323 sources and entire Workspace unchanged. Audit, repeat install, rollback/reinstall, startup and sandbox spawn/exit passed; user short-drive test pending. Three phases remain. See architecture/cleanup-phase1-scaffolding.md. |','| CLEAN-01 | Phase 1 user-confirmed | User reported all working and authorised Phase 2. Original scaffolding retirement remains intact; two phases remain after the installed Phase 2. |\n| CLEAN-03 | Phase 2 installed / user checkpoint | 160 sources; adapters, old code hosts and dormant GarageClient removed. 26 server/39 client ready, four tools skipped. Sandbox purchase/paint/spawn/exit/re-entry/garage and TT lifecycle checks pass; full driving, garage interiors, race completion and landscape touch need the user checkpoint. Mirror 15:14:10 matches all expected source/hierarchy/property changes; entire Workspace unchanged. See architecture/cleanup-phase2-canonical-ownership.md. |')
paragraph('docs/06_current_known_issues.md','| ARCH-01 |','| ARCH-01 | Prior cleanup superseded | All five original architecture phases are user-confirmed; the later complete-cleanup Phase 1 playthrough is also confirmed. Current acceptance is tracked by CLEAN-03. Prior retirement evidence remains in architecture/legacy-cleanup.md. |') if False else None
# Table rows are replaced individually, not as prose paragraphs.
p=ROOT/'docs/06_current_known_issues.md';s=read(p);lines=s.splitlines()
for i,line in enumerate(lines):
    if line.startswith('| ARCH-01 |'):lines[i]='| ARCH-01 | Prior cleanup superseded | Five original architecture phases and complete-cleanup Phase 1 are user-confirmed. Current acceptance is CLEAN-03; earlier retirement evidence remains in architecture/legacy-cleanup.md. |'
    if line.startswith('| ARCH-02 |'):lines[i]='| ARCH-02 | Resolved in cleanup Phase 2 | Forwarding adapters and the dormant GarageClient closure are removed. Canonical modules and explicit Runtime feature owners are installed; no feature hot reload. Remaining technical naming is Phase 3 scope. |'
    if line.startswith('| STATE-01 |'):lines[i]=line.replace('Old paths forward to canonical modules.','Cleanup Phase 2 removes the old forwarding paths; profile projection semantics remain current.')
write(p,'\n'.join(lines)+'\n')
replace('docs/06_current_known_issues.md','Known retired scripts remain disabled.','Retired Phase 2 implementations are absent; do not recreate them.')
replace('docs/06_current_known_issues.md','plus the Phase 3/4 maps','plus the cleanup Phase 2 maps')
paragraph('docs/architecture/naming-and-owners.md','**2026-09-05 update:**',f'**2026-09-05 update:** {status} [Phase 2 ownership and maps](cleanup-phase2-canonical-ownership.md) supersede historical path proposals below. Server and shared/client modules use Modules.Core/Game; runtime objects use ServerStorage.Runtime and PlayerScripts.Runtime by feature. No old adapters remain.')
paragraph('docs/architecture/naming-and-owners.md','**Phases 3/4 user-confirmed;','**Current ownership:** ServerBase/ClientBase own startup; ProfileServer owns authoritative profiles. GarageUI owns current interface startup and DriveSessionClient invokes current DrivingClient. Existing rendering/preview/geometry and LOD owners remain. The old phase-specific destination table below is historical evidence, not a current tree.')
replace('docs/architecture/naming-and-owners.md','Compatibility paths may retain old names while callers are migrated; they must not contain competing implementations.','Do not recreate compatibility path wrappers or retired implementations.')
replace('docs/architecture/naming-and-owners.md','Temporary adapters forward to an owner; they do not duplicate balances, inventories or vehicle registries.','Do not add adapters that duplicate balances, inventories or vehicle registries.')
paragraph('docs/10_script_source_sync_workflow.md','Latest complete-cleanup Phase 1 mirror:', 'Latest complete-cleanup Phase 2 mirror: `2026-09-05 15:14:10`, 160 verified sources and 266,996 captured properties. Both mirror areas are current. Source hashes and the complete expected hierarchy/properties match the migration; entire Workspace unchanged. `scripts/cleanup_phase2/verify_migration.py` verifies the frozen baseline against the final map. Exporter remains receiver-only; raw paste untouched. Restore Phase 2 before earlier exact-baseline recovery.')
paragraph('docs/11_manual_script_copy_map.md','Complete cleanup Phase 1 is now', 'Complete cleanup Phase 2 is installed through MCP. No manual run is pending. Current canonical script: `scripts/roblox_cleanup_phase2_canonical_ownership.lua`; intentional Edit recovery uses its ROLLBACK mode. Current paths are in the exported manifest and cleanup_phase2 maps, not the old adapter paths. Do not paste a historical standalone script into a canonical ModuleScript. Restore Phase 2 before earlier cleanup/architecture recovery. See `docs/architecture/cleanup-phase2-canonical-ownership.md`.')
replace('docs/11_manual_script_copy_map.md','the old LOD path remains an adapter. Other client/shared and server paths remain in the Phase 4/3 maps.','the old LOD adapter was removed by cleanup Phase 2. Current paths are in the cleanup Phase 2 maps; Phase 4/3 maps below are historical.')
note('docs/architecture/installer-index.md','**Current entry point:** `scripts/roblox_cleanup_phase2_canonical_ownership.lua` — installed; user gameplay checkpoint pending. All earlier phase installers in the historical index below require dependent cleanup rollback before exact-baseline recovery. Do not reinstall them over the current layout. See [Phase 2 handoff](cleanup-phase2-canonical-ownership.md).')
note('docs/architecture/mcp-workflow.md','**Current cleanup Phase 2:** 160 canonical sources; live state/endpoints use ServerStorage.Runtime.<Feature> and PlayerScripts.Runtime.<Feature>. Inspect normal ServerBase/ClientBase readiness; do not require gameplay modules through MCP to test startup, because execution contexts can create duplicate owners. Apply the single canonical installer in Edit, stop Play before export, run receiver/exporter and both mirror integrity and cleanup_phase2/verify_migration.py. Exporter/receiver legacy filenames and wire route remain current until Phase 4 tooling migration. [Current handoff](cleanup-phase2-canonical-ownership.md).')
note('docs/architecture/company-handoff.md','**Current baseline update:** '+status+' Sources: 160; startup: 26 server, 39 client, four opt-in tools skipped. Old adapter paths in earlier sections are historical. See [current ownership handoff](cleanup-phase2-canonical-ownership.md).')
for path,message in {
 'docs/02_vehicle_folder_system.md':'Canonical vehicle modules are under ReplicatedStorage.Modules.Game.Vehicles and ServerStorage.Modules.Game.Vehicles. Runtime endpoints moved with their owners. No vehicle model, mesh, part, asset ID, catalogue value or staging/archive content was changed.',
 'docs/03_driving_mechanics.md':'DriveSessionClient now owns spawn/exit callbacks and mobile telemetry, invoking the existing DrivingClient/VehicleDynamics. Driving numeric tokens are unchanged; the unused alternate driving implementation is removed. Full control/boost/drift/reverse remains the current user checkpoint.',
 'docs/04_customisation_ui.md':'ClientBase starts GarageUI directly; dormant GarageClient and unused helpers are removed. Current shared UI renderer, layout, preview and geometry owners are reused. Feature events/state moved to PlayerScripts.Runtime. No UI redesign or device/orientation change.',
 'docs/05_vfx_system.md':'VFX implementations/callers now use canonical ReplicatedStorage.Modules.Game paths and feature Runtime state. Existing preview/runtime attachment owners, effect values and physical assets are preserved.',
 'docs/world-streaming-and-lod.md':'LODClient still owns LODPolicy/LODRuntime under ReplicatedStorage.Modules.Game.World. Policy/runtime sources are byte-identical to the prior baseline; only dependency/reporting context changes. Diagnostics now report on PlayerScripts.Runtime.World. Entire Workspace is unchanged; World/asset naming is Phase 3 scope.'
}.items():note(path,'**Complete cleanup Phase 2, 2026-09-05 — installed, user checkpoint pending.** '+message+' See [current handoff](architecture/cleanup-phase2-canonical-ownership.md). Historical paths below are recovery history.')
note('docs/07_patch_history.md','## 2026-09-05 — Confirm cleanup Phase 1; install Phase 2 canonical ownership\n\nUser confirmed Phase 1 working. Installed Phase 2: 323 to 160 sources, 133 forwarding adapters and old code hosts retired, live endpoints moved to feature Runtime folders, GarageUI startup direct and current driving callbacks extracted into DriveSessionClient. Removed unused legacy closure/helpers/alternate execution branches; preserved profile semantics, tuning, UI owners and entire Workspace. Compile, rollback/reinstall, startup and sandbox garage/vehicle/time-trial checks pass. Final mirror 15:14:10 matches every expected source/hierarchy/property record. Full gameplay checkpoint pending; two phases remain. Canonical installer: scripts/roblox_cleanup_phase2_canonical_ownership.lua. See architecture/cleanup-phase2-canonical-ownership.md. Lesson: move runtime endpoints and both readiness producer/consumer paths before retiring script hosts.')
# Bullets in this section share a paragraph, so replace the exact line.
p=ROOT/'AGENTS.md';s=read(p);lines=s.splitlines()
for i,line in enumerate(lines):
    if line.startswith('* The former `StarterPlayer.'):lines[i]='* GarageClient and old client/server adapter trees were removed in complete cleanup Phase 2. Do not resurrect them. ClientBase starts GarageUI directly; DriveSessionClient owns vehicle-session callbacks. Keep shared rendering/preview/geometry owners and explicit feature APIs; ClientBase owns startup only.'
    if line.startswith('* The successor cleanup programme'):lines[i]='* The successor cleanup programme is `docs/architecture/complete-cleanup-plan.md`. Phase 1 is user-confirmed; Phase 2 is installed and agent-verified, awaiting user gameplay checkpoint. Read `docs/architecture/cleanup-phase2-canonical-ownership.md`; wait for continuation before Phase 3. Workspace edits remain limited to the original NeoTokyoRacersWorld subtree; other Workspace content is excluded WIP. Preserve physical assets and external saved IDs. No in-game backups, fallback implementations or new adapters. Keep opt-in tools; exporter is receiver-only.'
    if line.startswith('* All five architecture phases'):lines[i]='* All five original architecture phases are user-confirmed. Current server implementations are in ServerStorage.Modules; client/shared implementations are in ReplicatedStorage.Modules. Old Services/client adapters are removed. Runtime endpoints use feature folders under ServerStorage.Runtime and PlayerScripts.Runtime. Roll back dependent cleanup before older exact-baseline recovery.'
write(p,'\n'.join(lines)+'\n')

# Compress this task's immutable recovery hierarchy after exact round-trip verification.
p=HERE/'hierarchy-before.json'
if p.exists():
    raw=p.read_bytes();target=p.with_suffix('.json.gz');target.write_bytes(gzip.compress(raw,mtime=0))
    assert gzip.decompress(target.read_bytes())==raw
    assert p.resolve().parent==HERE.resolve();p.unlink()
# Remove only unreferenced files inside this task's generated projection directory.
payload=json.loads(read(HERE/'payload.json'))
keep={('.'.join(r['path'])) for r in payload['sources']}
folder=(HERE/'projected').resolve();removed=[]
for p in folder.rglob('*.lua'):
    assert folder in p.resolve().parents
    key='.'.join(p.relative_to(folder).with_suffix('').parts)
    if key not in keep:removed.append(str(p.relative_to(folder)));p.unlink()
stale=HERE/'unresolved-paths.txt'
if stale.exists():stale.unlink()
print('Updated handoff; removed obsolete projected files:',len(removed))
