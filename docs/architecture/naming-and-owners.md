# Naming and ownership

ServerStorage.Assets.Vehicles is the sole full vehicle authoring/spawn source. ReplicatedStorage.Assets.VehiclePreviews is a generated presentation-only output, never used as the authoritative upgrade/spawn source. PathResolver.VehicleCategories chooses by runtime side. No new lifecycle or network owner.

VehicleCatalogData/VehicleCatalog own immutable public definitions and ID resolution; VehicleDefinition shares attribute access across records and authoring Instances. VehicleTemplateIndex owns bounded preview-template lookup only. Server authority, startup, UI, preview geometry, persistence and lifecycle ownership remain unchanged.

Performance Phase 4 is installed and agent-verified; user playthrough pending. Mirror 2026-09-22 12:47:08 passes exact 164-source/44,464-node/276,087-property parity. See performance-phase4-vehicle-previews.md. Gameplay and physical properties are preserved; original templates are server-only and client previews are generated.

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
