# Laptop continuation — confirmed cleanup Phase 3

Handoff date: 2026-09-05. User reported Phase 3 worked well and requested continuation on a laptop. No Phase 4 implementation was started during this handoff.

## Confirmed baseline

- Project: Space Racers v1, place ID **121304917315753**.
- Repository: https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers ; branch **main** at handoff preparation.
- All five original architecture phases and complete-cleanup Phases **1, 2 and 3** are user-confirmed. These are separate programmes.
- Next: **Phase 4 — Tooling, final regression and closure**, in complete-cleanup-plan.md. One canonical installer/delivery; do not subdivide or rerun earlier phases.
- Current installer: scripts/roblox_cleanup_phase3_generic_naming.lua. Already installed; no manual run needed. Its AUDIT is read-only; INSTALL is not an arrival check.
- Post-playtest mirror: **2026-09-05 16:06:57**. 160 sources, 42,285 nodes, 266,840 captured properties. Full expected source SHA-256 and hierarchy/property parity pass, zero unexplained differences. Exact tags separately pass live installer audit. See scripts/cleanup_phase3/verification.json.
- Studio was left in Edit. No production publish or saved-player-data migration was performed. No saved-place/cloud synchronization success is claimed by this handoff.

## Commit-access fix after handoff

GitHub Desktop initially failed with lstat manifest.json: Permission denied because snapshot staging had a sandbox-only Windows ACL. Inheritance was restored on both mirror roots and the importer now preserves repository-parent access; nine tests pass. Include scripts/import_studio_full_snapshot_export.py and scripts/test_studio_snapshot_pipeline.py in the transfer commit. No place or mirror content changed. Line-ending warnings are not this failure.

## Transfer before leaving this desktop

1. **Save the actual current Studio place.** The reliable independent transfer is a local `.rbxl` or `.rbxlx` saved from the current Edit session, copied to the laptop using your normal private file transfer. Keep it outside this source repository. The JSON/source mirror cannot reconstruct all physical assets, terrain and unlisted properties. A cloud-saved editable version is another option only if you verify that the laptop opens these exact changes; publishing to live players is not required or authorised here.
2. **Commit and push the repository changes in GitHub Desktop on main.** At preparation the repo had many accumulated uncommitted modifications, deletions and new directories, including the earlier architecture/cleanup work. Include the intended project docs, prompts, scripts, diagrams, exported sources and snapshot; preserve the complete recovery/build evidence referenced by current installers. Review unrelated changes instead of blindly including them.
3. **Explicitly uncheck docs/studio-full-export-paste.txt.** It is historically tracked, so its ignore rule does not exclude its existing modification. Leave that local change alone. Do not transfer private Codex credentials or caches through Git.
4. Suggested commit title: `Confirm cleanup Phase 3 and prepare laptop handoff`. Description: `Record confirmed architecture and cleanup baseline; include canonical installers and recovery evidence; refresh Studio mirror and document Phase 4 continuation, protected assets and known camera issue. Exclude raw Studio export paste.`
5. Push and verify the new commit appears on GitHub. Record its commit ID and compare it on the laptop. This assistant did not commit, push or verify a remote upload. The pre-handoff HEAD was 4ee9981, which predates the uncommitted cleanup; that commit alone is insufficient.
6. Stop editing this desktop copy once transferred, to avoid divergent Studio state or repository changes.

## Laptop setup

1. Clone the repository, or fetch/pull **main** in the existing clone. Match the newly pushed desktop commit. Confirm this handoff and scripts/cleanup_phase3/verification.json are present. Open that checkout as the Codex project; its local directory may differ from the desktop path.
2. Open the transferred current place in Roblox Studio, or the verified matching editable cloud version. Keep the existing original whole-game backup separately. A local save can have a different/zero place identity; if so, stop for explicit target reconciliation rather than disabling the installer place-ID guard.
3. Connect the laptop's Roblox Studio MCP server and verify Codex can list Space Racers v1 and read Edit state. Do not reuse the desktop MCP instance UUID. Leave Studio visible during client-input tests; backgrounded tests previously stalled.
4. This desktop uses a local Windows server launch: command `cmd.exe`, arguments `["/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]`. This was read from the working desktop configuration. Use it only on a Windows laptop where the matching Roblox MCP installation provides that file. Install/enable the same Studio MCP integration first; do not assume cloning the repo installs it. On macOS, use the integration's native setup instead of this Windows command.
5. MCP configuration can be user-level `~/.codex/config.toml` or project-level `.codex/config.toml`. The repo ignores `.codex/`; the desktop's user-level configuration is not part of this checkout. Configure only the needed connection, rather than copying the entire desktop config/credentials. See [official MCP configuration guidance](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
6. Ensure Python 3 is available for receiver/verifiers, or let Codex discover its bundled Python runtime. Do not reuse the desktop cache interpreter path. No live server/session must remain running on this desktop for the laptop workflow.
7. Start a new chat using prompts/07_resume_cleanup_on_laptop.md. It carries the scope and next step without requiring the old conversation.

## First checks in the laptop chat

Read AGENTS.md and required baseline/issues/history/sync/copy-map/workflow documents, then complete-cleanup-plan.md, cleanup-phase3-generic-naming.md and this handoff. Inspect the relevant topic docs and canonical scripts. Check Git branch/status and local mirror integrity before overwriting anything.

List Studio instances afresh; verify target, Edit state, Workspace.World and current Config/Assets/Remotes roots. Execute the canonical Phase 3 installer in **AUDIT** mode from the reviewed local file, not INSTALL. The exact full-source/config/tag preflight should match. Never require stateful gameplay modules through MCP as a startup check.

If necessary export the laptop place only after confirming it is the intended transferred version: run scripts/receive_studio_full_snapshot_export.py locally, then scripts/roblox_studio_export_full_snapshot_for_github_v2.lua in Studio. Run scripts/verify_studio_mirror.py and scripts/cleanup_phase3/verify_migration.py. Investigate mismatches; do not overwrite a newer live place or reapply an old installer to force a match. These current exporter names remain valid until Phase 4 intentionally migrates tooling.

Once parity and scope are established, continue Phase 4. No extra approval is needed for already approved ordinary cleanup, but the physical-asset decision below remains unresolved.

## Boundaries and unresolved items

- Preserve gameplay, UI/preview owners, tuning, physics, input, saved schemas/IDs, authority and lifecycle protections. Mobile remains LandscapeSensor.
- Workspace scope is only the original World subtree, now Workspace.World. Sole exception: two approved lighting-tag renames on the exact 62 WIP objects in scripts/cleanup_phase3/wip-lighting-tags.json, already completed. No broader WIP edits.
- No physical model/mesh/part deletion or reshaping. **ServerStorage.NeoTokyoRacers.VehiclePerformanceV2_Staging and ServerStorage.Archive remain protected.** The tag approval did not approve their deletion/rename/move. Obtain a concrete disposition decision before declaring the whole cleanup closed; do not disguise them as new current systems.
- Keep opt-in development tools off by default. No in-game backup trees, alternate legacy implementations or old-path adapters. Recovery belongs in repository records.
- External NTR DataStore/session identity strings and stable catalogue IDs are intentional compatibility exceptions; do not silently migrate to empty stores. Internal historical logs/variables and tooling naming still need Phase 4 review.
- CAM-02: rapid command-driven purchase/spawn/exit/re-entry reproduced NaN zoom bounds and BaseCamera:594 clamp errors on both verified Phase 2 and Phase 3. Predates this migration. User playthrough worked well; issue remains for an isolated follow-up. Do not fix camera behaviour under naming cleanup. CAM-01 is a separate older unparented DriverSeat issue.
- Device profiling, multiplayer, real isolated-place save/rejoin/contention and production rollout remain release gates, not proven by Studio sandbox or broad phase acceptance.

Rollback is unnecessary for this transfer. If later needed, restore Phase 3 using its exact ROLLBACK mode before Phase 2 or earlier recovery. Never run historical patches over the current layout.
