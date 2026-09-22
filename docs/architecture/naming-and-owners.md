# Naming and ownership

Current: all cleanup phases confirmed. Performance Phase 2 installed/agent-verified; user test pending. Server-only schema/projection/writer modules and Persistence/PersonalBests/Leaderboards settings now live under ServerStorage.Modules/Config; shared calculation and presentation remain replicated. See performance-phase2-server-storage.md.

Naming follows the inspected Untitled Experience vocabulary without claiming a company-wide standard: ServerBase, ClientBase, Modules.Core/Game and responsibility-based FeatureServer, FeatureClient, FeatureUI names.

| Responsibility | Canonical owner/location |
|---|---|
| Server/client startup | ServerBase / ClientBase, explicit dependencies only |
| Server implementations | ServerStorage.Modules.Core/Game |
| Client/shared implementations | ReplicatedStorage.Modules.Core/Game |
| Server/player runtime endpoints | ServerStorage.Runtime / PlayerScripts.Runtime by feature |
| Profile and persistence authority | ProfileServer; projection never owns a second balance/profile |
| Garage UI / vehicle-session callbacks | GarageUI / DriveSessionClient |
| Shared UI geometry / preview | Existing shared components and preview owners; reuse rather than duplicate |
| VFX attachment / preview VFX | VehicleVFXClient / VehiclePreviewVFXClient |
| LOD policy and registration | LODClient / LODRuntime / LODPolicy |
| Assets, tuning, networking | Assets / Config / Remotes, by feature |
| Authored world / early loading | Workspace.World / ReplicatedFirst.Loading |

Runtime behaviour is preserved. Private version-prefixed identifiers and branded storage aliases were renamed; token proof is in scripts/cleanup_phase4/source-change-report.json. Saved identities, catalogue IDs and exact lifecycle surface-suppression keys are explicit exceptions, not aliases to old implementations. Complete ledger: cleanup-phase4-finalisation.md.

Protected staging/Archive content remains pending disposition. No new adapter, backup or duplicate owner may be introduced to resolve a naming conflict. Historical migrations: ../history/cleanup-phase4-prior-docs/naming-and-owners.md.
