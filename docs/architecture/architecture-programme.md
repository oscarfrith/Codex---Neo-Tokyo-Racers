# Architecture programme (Project 12 comparison), 2026-09-26

Reference for the owners introduced by the nine-phase programme that followed the read-only comparison with the team's Project 12. Current status and next action live only in [start here](../00_START_HERE.md). Per-phase evidence is in `scripts/architecture/p<N>/verification.json`; every phase has before/after targeted captures under `roblox/captures/arch-p<N>-after`.

## Delivery method

- One programme installer: `scripts/architecture/installer.py` (+ `installer.lua`). Operations: `source` (existing script body), `module` (create/remove a new script), `attribute` (primitive), `remove_instance` (childless, attribute-free, untagged remote/bindable/folder; rollback recreates class, name and parent). All-or-nothing, compile-checked, AUDIT/APPLY/ROLLBACK, repeat-safe, in-memory recovery on failure.
- Mechanical extraction (P5, P6): `scripts/architecture/luadeps.py` finds each range's free variables, exports and shared-state hazards; ranges move byte-for-byte into `return function(ctx) ... return exports end` factories rebound at the same position. Each extraction was re-verified by the delivery-reviewer with an independent scope resolver.
- Behaviour parity: an 18-step GarageInvoke golden sequence (canonical, id-normalised, FNV-hashed replies) run in a fresh no-save sandbox before and after (`scripts/architecture/p5/golden-*.txt`).

## Owners

| Owner | Path | Responsibility |
|---|---|---|
| Core library | ReplicatedStorage.Modules.Core: Signal, Tags, ConnectionScope, ConfigReader | In-process signals; streaming-safe tag binding; failure-isolated cleanup; typed, finite config reads that report invalid values once |
| Core.Net | ServerStorage.Modules.Core.Net | Admission for every client->server remote: action allowlist, bounded payload sanity, per-player-per-remote token bucket, optional busy lock, failure isolation with tracebacks, Studio `ServerStorage.Runtime.NetStats` counters. Handlers keep their bodies; `GarageRequestGuard` is a thin Net spec with the original limits/messages |
| RaceIntegrity | ServerStorage.Modules.Game.Racing.RaceIntegrity | RACE-01 gate-to-gate plausibility for time trials and matchmaking races. Mode Off/Log/Enforce from a valid dashboard config `RaceIntegrityMode`, else `ServerStorage.Config.Racing.RaceIntegrityMode` (installed Log). Enforce withholds reward, PB and leaderboard but lets the run finish |
| MoneyService | ServerStorage.Modules.Game.Player.MoneyService | The only place Cash is spent (`Debit`); refuses NaN/negative/infinite amounts or insufficient funds; `Debited` signal; never saves. Credits stay in EconomyServer |
| Garage services | ServerStorage.Modules.Game.Garage: GarageProfileView, GarageCapacity, GarageCatalogLookup, GarageCatalogService, GarageClientProfile, VehicleBuildService, VehicleSpawnService, VehicleLifecycleService | Verbatim factories extracted from GarageServer (2,767 -> 1,121 lines). GarageServer keeps the dispatcher, bridges bind inside their owning service at the original startup point |
| FeatureFlags | ServerStorage.Modules.Core.FeatureFlags | Non-yielding flag reads: Studio `ServerStorage.Config` `Flag_<key>` override, then Creator Dashboard ConfigService snapshot (60 s refresh, memoised per key), then default |
| AnalyticsServer | ServerStorage.Modules.Game.Player.AnalyticsServer (ServerBase entry) | Registry and sender: economy sinks (MoneyService.Debited), sources (EconomyCashCommitted), onboarding funnel on newly recorded milestones. Gated by `AnalyticsEnabled` |
| ReceiptProcessor | ServerStorage.Modules.Game.Player.ReceiptProcessor | Inert developer-product template: in-flight lock, grant+record together, save-first, retry re-saves, never double-grants. Before binding: persist and bound `PurchaseHistory` |
| CameraService (prepared, not installed) | ReplicatedStorage.Modules.Core.CameraService | Keyed priority FOV and zoom-limit requests with validation; DrivingCameraClient (100) and CharacterSprintClient (10) migrate to it. Waiting for a rendered Studio test |

## Rules going forward

- New client->server remote handlers are wrapped with `Net.invoke`/`Net.event`; never assign `OnServerInvoke`/`OnServerEvent` bare.
- Spend Cash only through `MoneyService.Debit`; grant only through EconomyServer commands.
- New live-tunable behaviour reads `FeatureFlags`, not ad hoc attributes.
- Report analytics through AnalyticsServer's registry.

## Not done / deferred (see 06)

- ECON-01: a failed request after a successful debit keeps the cash (pre-existing). Two refund designs were rejected in review (could mint cash or grant free items); needs per-action atomic transactions.
- P7 remainder: CameraType/Subject claims for garage preview, dealership intro, race transition, owned-garage touch guard and trailer tools; UI visibility arbiter (DesktopFreeRoamHudUI per-frame ScreenGui scan); input action registry and single PlayerModule controls writer. All need rendered, device-level verification.
- VehicleAccessServer enter-logic consolidation into VehicleSpawnService; unreachable legacy branches in the GarageServer dispatcher; unused runtime bindables; bare prints; WaitForChild-to-Tags migration for streamed World objects; server restart countdown (needs client UI and a new remote).
