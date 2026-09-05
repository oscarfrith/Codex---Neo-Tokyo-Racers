# Complete cleanup Phase 3 — generic naming and configuration

2026-09-05. **Installed and user-confirmed.** User authorised the two lighting-tag renames on the enumerated 62 WIP objects. Phase 4 has not started.

## Delivery evidence

Canonical installer: scripts/roblox_cleanup_phase3_generic_naming.lua. Applied directly via MCP to Space Racers v1, place 121304917315753. No manual installer run is pending. This remains one coordinated phase.

- 160 projected sources, 187 explicit instance moves/renames, 210 nonphysical retirements, four new config/asset folders and nine tag contracts.
- 862 attribute renames, 519 unused stamp removals and three string-value corrections.
- Exact source preflight/compile, install audit, repeat install and rollback/reinstall passed. Physical identity/covered properties and the excluded WIP invariants passed, with only the approved two-tag exception.
- Six local contract tests and separate numeric-token/external-ID/source-path checks passed. Two server-created GarageSessionRequest paths and one absent optional CameraAssist config are classified path exceptions.
- Normal startup: 26 server and 39 client modules ready; four opt-in tools skipped. Sandbox purchase, paint, spawn, exit/re-entry, race vehicle validation, time-trial staging/countdown/cancel and world runtime readiness were checked. A malformed paint smoke request using Slot was correctly rejected; the real Channel contract succeeded.
- Final receiver/exporter mirror: **2026-09-05 16:06:57**, 160 sources, 42,285 nodes, 266,840 properties. verify_migration.py passes complete expected source SHA-256 and hierarchy/property parity, zero unexplained differences, including unchanged excluded Workspace export records. Tags are separately checked by the live installer because the exporter does not capture them.

Source changes are frozen full replacements guarded by exact before-source checks. Local projection generation uses exact guarded source anchors, not unconstrained live substring replacement. No saved namespace, schema or catalogue ID changed. No physical asset was deleted or reshaped, no backup implementation was created, and nothing was published. Sandbox saves remained suppressed.

## Camera comparison — resolved as pre-existing, not fixed here

The first Phase 3 smoke test produced PlayerModule.BaseCamera:594: invalid argument #3 to clamp (max must be greater than or equal to min). Phase 3 was rolled back while investigating. The restored Phase 2 mirror at 15:52:58 proved all 160 source hashes and all exported hierarchy/property records matched the frozen baseline exactly.

After the user brought Studio to the foreground, the same visible-client sequence reproduced the error on **both Phase 2 and Phase 3**: Play button, dealership event, sandbox purchase/spawn, then exit/re-entry. Both reported successful commands and **NaN for CameraMinZoomDistance and CameraMaxZoomDistance**. This establishes that the error predates the naming migration. The zoom setter is byte-identical between projections. No camera fix was added. See CAM-02 and scripts/cleanup_phase3/camera-comparison.json.

This rapid command-driven transition smoke is not a full human playthrough. Root cause beyond invalid zoom state is not established; do not conflate it with the older unparented DriverSeat issue. Recommend an isolated camera hardening task after cleanup acceptance.

Lesson: comparable visible-client conditions matter. Source parity alone did not resolve the concern; exact baseline restoration and reproduction on both baselines did.

## User verification and recovery

Test normal dealership/customisation, purchase/equip/paint/preview, spawn/driving/boost/drift/braking, exit/re-entry, owned-garage transitions, complete race/time trial and cancel, city lighting/LOD/audio/VFX, respawn and landscape touch. Report new behaviour or Output errors. Full device coverage, multiplayer and published save/rejoin are separate unverified release gates.

If migration recovery is required, stop Play and use ROLLBACK in the same canonical installer. Restore Phase 3 before using Phase 2 or earlier exact-baseline recovery. Recovery lives only in repo/installer records, not in-game backups. The rollback/reinstall path was exercised and the restored baseline independently exported and compared.

## Contract and preflight

High-Risk architecture migration. Preserve existing ServerBase/ClientBase composition, all feature state/geometry/visibility/preview/attachment owners, ProfileServer authority, remote payload/validation/rate limits, saved schema and IDs, tuning, assets, physics, lifecycle and LandscapeSensor. The intended changes are technical names, paths, unused metadata and feature-based configuration organisation. No additional runtime loops, owners, remote calls or work per frame; no claimed FPS improvement from renaming.

MCP identifies Space Racers v1, place 121304917315753, in Edit. The pre-migration receiver/exporter refresh at 15:28:27 verified 160 sources, 266,996 property values and 42,491 nodes. Phase 3 was temporarily installed for tests and then fully restored as described above.

## Scope decisions

Two current lighting tags cross the protected Workspace boundary:

| Contract | World/in-scope members | Excluded WIP members | Current consumer |
|---|---:|---:|---|
| NTR_WindowMaterial | 39 | 53 | Modules.Game.World.WindowMaterialClient |
| NTR_NightLamppostLight | 545 | 9 | Modules.Game.World.NightLamppostLightClient |

Exact 62 WIP instance paths/classes are recorded in `scripts/cleanup_phase3/wip-lighting-tags.json`. **User approved renaming those two tags too.** This authorises only NTR_WindowMaterial → WindowMaterial and NTR_NightLamppostLight → NightLamppostLight membership changes on those exact objects. All other WIP names, attributes, properties and hierarchy remain excluded. Consumers and all memberships migrate together, without old-tag fallbacks.

The separately pending asset decision is whether to retain or remove `ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging` and `ServerStorage.Archive`. Current authorisation protects their physical contents. Refer to the Phase 1 exact inventory; a limited shape match is not a complete duplicate proof. No deletion/move/rename is authorised by silence. If retained untouched, record them as explicit asset exceptions rather than disguising an archive as a current Development system.

The client input/loading stall cleared when Studio was brought to the foreground; the controlled camera comparison is recorded above.

## Installed migration map

| Existing location | Intended location / treatment |
|---|---|
| Workspace.NeoTokyoRacersWorld | Workspace.World; same Folder and descendant identities |
| ReplicatedFirst.NTRLoading | ReplicatedFirst.Loading |
| ReplicatedStorage.NeoTokyoRacers.Assets | ReplicatedStorage.Assets |
| ReplicatedStorage.NeoTokyoRacers.Shared.Remotes | ReplicatedStorage.Remotes; same remote instances/classes/handlers |
| Config.Audio / Config.Development / Config.Racing / Config.UI under the branded root | Corresponding ReplicatedStorage.Config feature folders |
| Branded Config.Runtime.WorldLOD | Config.World.LOD |
| Branded Config.Runtime.DRIVING_MECHANICS_EditAttributes | Config.Vehicles.Driving |
| Branded Config.Runtime.VehicleDynamics_EditAttributes | Config.Vehicles.Dynamics |
| Branded Config.Runtime.DrivingCamera_Default_EditAttributes | Config.Vehicles.Camera; current DrivingCameraClient uses this source |
| Branded Config.Runtime.DrivingCamera_EditAttributes | Retired after consumer/reference preflight |
| Branded Config.Runtime.DriveToEarnCash_EditAttributes | Config.Vehicles.DriveRewards |
| Branded Config.Runtime.FreeRoamVehicleSpawn | Config.Vehicles.Spawn |
| Branded Config.Runtime.FreeRoamHudTeleport | Config.World.FreeRoamTeleport |
| Branded Config.Runtime.Onboarding_EditAttributes | Config.Player.Onboarding |
| Branded Config.Runtime.OwnedGarage_EditAttributes | Config.Garage.Interior |
| Branded Config.Runtime.DriveInCustomisation | Config.Garage.DriveIn |
| Branded Config.Runtime.StudioCashGrant | Config.Development.CashGrant |
| Shared.Config.CharacterMovement_EditAttributes | Config.Player.Movement |
| Shared.Config.MobileDriveControls_EditAttributes | Config.Vehicles.MobileControls |
| Shared.Config.Persistence_EditAttributes | Config.Player.Persistence |
| Shared.Config.VehiclePerformanceV2_EditAttributes | Config.Vehicles.Performance; preserve schema version and active comparison semantics |
| Shared.Config.VehiclePerformance_EditAttributes | Separate retirement candidate; no literal consumer found, requires dynamic/reference check |
| Config.Editable.01_GAME_BALANCE_Editable | Config.Vehicles.Authoring; retain current child folders, value types and readers |
| Config.Editable.DRIVER_SEAT_POSITION_DoNotRename | Config.Vehicles.DriverSeat |
| Config.Editable.STABILISER_VFX_DIRECTION_DoNotRename | Config.Vehicles.StabiliserVFX |
| ServerStorage.NeoTokyoRacers.OwnedGarage / Racing | ServerStorage.Assets.Garage / Racing |
| ReplicatedStorage.Shared lighting configuration, definitions and skies | Config.World.Lighting, Modules.Game.World definitions and Assets.World.Skies, respectively |
| SoundService.NTR_* groups/effect | Responsibility-only names; preserve effects, volumes and SoundGroup object references |

The canonical installer applies the complete reviewed map; do not apply rows individually. Configuration values are mapped individually; unused mirrors cannot overwrite current Theme or camera values. Physical hook names containing DoNotRename are not permission for a blanket model/part rename.

`scripts/cleanup_phase3/` contains the frozen Phase 2 baseline, naming candidates and source consumer evidence. Its 386 branded-string candidates include user-facing words such as CONTROLS that are substring false positives; they are not a replacement list. The 19 identifier candidates likewise contain INTRO_PATH_NAME. Automatic substring stripping is prohibited. Saved DataStore names and NTRSessionToken/NTRSessionLeaseUntil metadata must remain unchanged. Technical metadata revisions must be distinguished from schema/ownership/lifecycle safeguards.

## Remaining programme work

The user confirmed Phase 3 worked well; no script needs running manually. Phase 4 owns tooling names, final current-code naming review, regression and the completion ledger. Some internal historical variable/log labels and external identity exceptions still exist; this is not a claim that the entire cleanup programme is finished. Staging and Archive remain protected and need explicit disposition before closure. In particular, ServerStorage.NeoTokyoRacers remains only as the protected staging host; it was not silently relabelled or deleted.
