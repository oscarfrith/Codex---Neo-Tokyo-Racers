# Space Racers project instructions

## Read first

Read [current status](docs/00_START_HERE.md) and [open issues](docs/06_current_known_issues.md), then the relevant topic/source files. Prefer the newest confirmed working baseline, not the newest generated script.
For multi-step Studio work read [workflow lessons](docs/12_continuous_improvement_workflow.md); for connected UI/runtime/persistence/VFX/architecture work read the [delivery workflow](docs/13_efficient_feature_delivery_protocol.md).
Before a new system, substantial expansion or connected networking/persistence/runtime change, also read the [readiness standard](docs/14_new_system_readiness_standard.md); use [the contract template](docs/15_new_system_contract_template.md) proportionally. The assistant selects the lane and keeps its safeguards active through repairs.

## Durable rules

- Orient from this checkout and live Studio. Check Git and rediscover the intended Studio instance before writes; do not trust old session IDs.
- Follow the routing and delivery rules in the workflow: follow implements; suggest recommends without implementation; audit is read-only; continue executes the next approved incomplete step; handoff stops expansion and records the baseline.
- Prefer small guarded Command Bar scripts and one canonical installer per approved scope. Repair that installer rather than adding a patch ladder. Do not split an approved phase into additional phases or user-run tasks without asking.
- Fast work stays fast. Remotes, saved data, economy, rewards, authority and lifecycle boundaries retain applicable safeguards regardless of diff size.
- For connected or ambiguous changes, state a concise acceptance contract and identify existing state, geometry, visibility, preview, attachment and persistence owners. Never add an owner to overpower an existing one.
- Reuse actual shared UI components, renderers, layout functions and semantic tokens. Copying coordinates is not reuse. Document any necessary page-specific exception.
- ClientBase owns startup only and starts GarageUI directly. DriveSessionClient owns vehicle callbacks. Do not resurrect GarageClient or retired client/server adapter trees.
- Mobile orientation is native StarterGui.ScreenOrientation = LandscapeSensor. No portrait layouts or runtime orientation writers unless the product requirement changes.
- Use configuration folders/attributes for tuning where practical. Preserve saved IDs/schema and authoritative mutation boundaries.
- Keep scope narrow; driving work must not alter unrelated UI/server/VFX systems. Workspace scope is World plus explicitly approved exceptions; preserve WIP, physical assets, protected staging/Archive and opt-in tools.
- No in-game backup folders/scripts, fallback implementations or duplicate startup owners unless explicitly requested. Keep recovery evidence in the repository.
- Announce fragile text replacement before writing it. After two source-anchor failures in one live script, stop guessing and inspect/refresh the actual source; prefer isolated canonical replacement where appropriate.
- If an older Roblox version is a cleaner recovery, say so before another patch. Challenge a materially safer/faster alternative once, explain its tradeoff, then respect the decision.
- No gameplay module require through MCP. Inspect normal startup/runtime evidence; do not create duplicate owners through a separate module cache.
- Distinguish generated, installed, agent-verified and user-confirmed. Source parity and successful remote calls are not gameplay confirmation.
- Follow the current mirror/recovery policy in the delivery workflow. Never commit docs/studio-full-export-paste.txt. Windows mirror staging must inherit repository ACLs.
- Update only the documentation responsibilities affected by a change. Record reusable lessons after confirmed work; keep historical experiments out of the current run queue.

Paths: scripts/ for delivery tools; docs/ for design/handoff; diagrams/ for diagrams. Current task/status, mirror timestamp and next action belong only in docs/00_START_HERE.md.
