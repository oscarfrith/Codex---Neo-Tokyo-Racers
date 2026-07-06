# Continuous Improvement Workflow

**Created:** 2026-07-02  
**Purpose:** Make each Neo Tokyo Racers chat safer, faster, and more useful than the last one.

This project improves through confirmed baselines, good failure notes, and small repeatable scripts. Future chats should treat this file as part of the startup context.

## Startup Rule For New Chats

Before planning or patching, read:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- `docs/10_script_source_sync_workflow.md`
- `docs/11_manual_script_copy_map.md`
- this file

Then check `git status --short`.

If the task touches a specific area, read its topic doc before writing a script.

## What To Learn Each Time

After each task, record only useful lessons:

- confirmed working baseline;
- exact script that installed or verified it;
- exact Studio Output error if something failed;
- root cause, if known;
- script or workflow superseded by the fix;
- remaining manual verification;
- rollback path.

Do not preserve long failed patch ladders as the current path. Keep them only as history when they explain why the new baseline is safer.

## Safer Script Design

Prefer this order:

1. Read-only audit or diagnostic.
2. Isolated new service/client/module beside the risky script.
3. Canonical replacement of a small isolated script.
4. Guarded exact source patch.
5. Broad or repeated source replacement only if no cleaner route exists.

When a command-bar script patches source text:

- say it is fragile before the user runs it;
- include preflight markers and idempotent checks;
- stop on unknown source shape;
- print useful live-source diagnostics rather than guessing another patch;
- make reruns safe after partial installs.
- avoid unescaped Lua pattern matching for large exact source blocks. `string.gsub` treats punctuation in the source as pattern syntax, so a block can fail to match even when the live source is present. Prefer `string.find(..., plain=true)` plus line-window insertion, or escape every pattern character deliberately.

If two or more source-anchor repairs fail in the same live script, stop and prefer a canonical replacement of the isolated script, or refresh the Studio mirror and inspect the live source before continuing.

## Client Bootstrap Register-Limit Rule

`StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` is a register-limited legacy bridge. Roblox can fail Play startup with `Out of local registers` when new top-level local helpers are added, even if the feature itself is small.

For future work:

- do not add new top-level local functions, local constants, or bulky UI/feature helpers to the bootstrap;
- put new behavior in isolated LocalScripts or ModuleScripts under `Controllers`;
- if the bootstrap must be touched, add the smallest possible bridge and prefer a single table-backed/global phase namespace over multiple locals;
- after any unavoidable bootstrap bridge, restart Play specifically to check for `Out of local registers` before continuing;
- if the error returns, repair by removing/moving bootstrap locals, not by adding another patch on top.

## Condensing Phases Safely

It is good to reduce the number of Studio Command Bar inputs, but do not merge unrelated risk.

Good merged phase:

- one installer plus one smoke in the same dual-mode script;
- one isolated service plus matching remote plus client smoke;
- validation-only phase that changes no gameplay code.

Do not merge:

- server source patch plus major UI source patch plus VFX/driving changes;
- multiple fragile text replacements in unrelated scripts;
- cleanup/deletion with feature install;
- DataStore live-save changes with visual/UI experiments.

## Mirror And Staleness Rules

Treat `roblox/exported_scripts/` and `roblox/studio_snapshot/` as a searchable mirror, not live source.

Before a fragile patch, refresh or inspect the mirror if:

- Studio has changed since the last commit;
- a previous patch partially installed;
- an anchor is missing;
- line numbers shifted after repairs;
- the error mentions a live source path that differs from the mirror.

After a Studio-side change affects scripts, hierarchy, assets, services, config attributes, or live object placement, refresh the mirror before final handoff whenever practical.

Never commit `docs/studio-full-export-paste.txt`.

## Failure Handling

Use a diagnostic before a second guess. The best pattern is:

- reproduce or capture exact Output;
- identify whether the failing object/source is current live Studio or stale mirror;
- add a read-only diagnostic if the root is unclear;
- patch only after the diagnostic narrows the cause;
- update docs with the confirmed root, not just the symptom.

If a workaround is rejected by the user, mark it as rejected and name the desired behavior. Future chats should not resurrect rejected behavior unless the user explicitly asks.

## Documentation Handoff Checklist

When a phase or fix is confirmed:

- update `docs/00_START_HERE.md` if the current baseline changes;
- update `docs/06_current_known_issues.md` for risks, verification, or deferred work;
- update `docs/07_patch_history.md` with a concise entry;
- update the topic doc or phase plan that owns the system;
- if a workflow lesson was learned, update this file or `docs/10_script_source_sync_workflow.md`;
- include exact Studio script names and verification instructions in the final handoff.

## Current Lessons From The Garage MVP Run

- The Phase 17 module popup issue needed runtime-coordinate diagnostics, not repeated visual guesses. Future UI placement bugs should print absolute positions, parent, scale, selected target, and visible bounds before another repair.
- The Phase 23 access work showed that repeated anchor repairs against a drifting isolated service are worse than a canonical replacement. For isolated scripts, canonical replacement is often safer after partial installs.
- The Phase 24-28 garage MVP was smoother when new behavior lived in separate services/client scripts instead of the large garage controller or main client bootstrap.
- The mirror receiver should not block the mirror import just because the raw paste file cannot be written. `scripts/receive_studio_full_snapshot_export.py` now falls back to in-memory import for that case.
- Final audit scripts are worth keeping. Phase 28 caught the whole stack in one smoke and gave a clear completion signal.

## Current Lessons From Drive-In Customisation

- Phase 1 confirmed again that `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled` is register-limited. New systems should live in isolated controllers/services, with only tiny table-backed bootstrap bridges when unavoidable.
- Phase 2 showed that UI/camera correctness can require a full session state handoff, not just opening an existing menu. If a vehicle is despawned into garage customisation, explicitly handle player hold/freeze, camera, preview vehicle, and eventual unlock.
- Phase 3/3B showed that drive-in session locks must be released before the normal garage `SpawnVehicle` handoff. Otherwise seating/spawn can race an anchored hidden character and produce undriveable vehicles or streaming focus issues.
- The Phase 3 partial install showed why command-bar source patchers should not use unescaped `string.gsub` for punctuation-heavy Lua source. The safer repair used plain matching to find the `Customise -> SpawnVehicle` branch and inserted the smallest unlock block before the call.
