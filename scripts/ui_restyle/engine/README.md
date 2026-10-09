# UI restyle installer engine

The one canonical installer for the Pulse UI programme (recommended-plan.md section 10). Nothing has been installed
with it yet. Phase 1 uses it first, starting with the `create` rehearsal.

Status: **self-tested in Studio; create op exercised against the place; nothing left installed.**

- `selftest.lua` ran in Studio Edit on 2026-10-09: 30 of 30 cases passed
  (`scripts/ui_restyle/phase0/results/engine_selftest_result.json`).
- The `create` op was exercised against the place the same day by `scripts/ui_restyle/phase1_proof` (AUDIT before,
  APPLY, AUDIT after).
- Still pending: save-and-reopen of a created module, and ROLLBACK of a created module.

## Files

| File | Role |
|---|---|
| `build.py` | Validates a phase `spec.json`, runs the offline dry run, writes `out_audit.lua`, `out_apply.lua`, `out_rollback.lua` |
| `plan.py` / `plan.lua` | Decision logic (state per op, block rules, transaction order, rollback refusal). Line-for-line mirrors |
| `hash.lua` | The programme's hash convention: djb2 + fnv1a32 over source bytes, same as `classic/manifest.json` |
| `engine.lua` | Reads the place, fetches and checks sources, writes one transaction, undoes on failure |
| `bootstrap.lua` | Binds the engine to the real place (services, HTTP, `.Source`, ChangeHistoryService) |
| `vectors.py` | 207 decision vectors made by `plan.py`, replayed against `plan.lua` inside `selftest.lua` |
| `selftest_body.lua` -> `selftest.lua` | Studio Edit self-test on a detached tree. Generated: `build.py --selftest` |
| `test_engine.py` | Offline tests |
| `sample_phase/` | One create, one attribute, one source edit (ClientBase). `installable: false`; golden files for the tests |

## Commands

```
py -3 scripts/ui_restyle/tools/serve.py                         leave running (127.0.0.1:8796, serves repo files)
py -3 scripts/ui_restyle/engine/build.py scripts/ui_restyle/<phase>
py -3 scripts/ui_restyle/engine/build.py scripts/ui_restyle/<phase> --inline
py -3 scripts/ui_restyle/engine/build.py --selftest
py -3 scripts/ui_restyle/engine/test_engine.py
```

Run an `out_*.lua` in Studio Edit through `execute_luau`. Each returns one JSON string.

`--inline` is for a Studio that cannot reach the server. It also writes `out_apply.partN.lua` and
`out_rollback.partN.lua`, each under 190,000 characters. Run every part, then `out_apply.lua`. Parts keep the text in
`shared.UIRestyleInline` for the Studio session and write nothing to the place. Inline AUDIT does not check sources
or run the Classic verify.

## spec.json

```json
{
 "phase": "phase1",                     // must equal the folder name
 "classicVerify": true,                 // AUDIT also runs classic/out_verify_classic.lua; or a repo path (below)
 "installable": true,                   // false: APPLY and ROLLBACK refuse (sample_phase)
 "ops": [
  {"id": "kit", "kind": "create", "class": "Folder", "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse"],
   "attributes": {"Accent": {"Type": "Color3", "R": 0, "G": 0.5, "B": 1}}},
  {"id": "tokens", "kind": "create", "class": "ModuleScript",
   "path": ["ReplicatedStorage", "Modules", "Game", "UIPulse", "Tokens"], "after": "after/Tokens.lua"},
  {"id": "style", "kind": "attribute", "path": ["ReplicatedStorage", "Config", "UI"], "key": "Style",
   "before": null, "after": "Classic", "was": []},
  {"id": "label", "kind": "property", "path": ["..."], "key": "Value", "before": "a", "after": "b"},
  {"id": "clientbase", "kind": "source", "class": "LocalScript",
   "path": ["StarterPlayer", "StarterPlayerScripts", "ClientBase"],
   "before": "before/ClientBase.lua", "after": "after/ClientBase.lua"}
 ]
}
```

- `create`: Folder, ModuleScript, Configuration and value objects. No Script or LocalScript (a second startup owner).
  A parent created by the same spec must come first. Attributes, properties and the source go on the create op.
- `tree`: shorthand, `{"kind": "tree", "path": [...], "tree": {"class", "attributes", "children": [{"name", ...}]}}`.
  It expands to one create op per node (ids `id/Child`).
- `attribute`: `before` must be written down. `null` means absent. `was` lists earlier values of this delivery.
- `source`: files sit in `before/` and `after/`. After-sources are limited to 150,000 characters, LF only.
- `classicVerify`: `true` runs `classic/out_verify_classic.lua`. A string is the repo path of a phase's own declared
  verify build, made with `classic/build_verify.py --declared <phase>/declared.json --out <path>`, for example
  `"scripts/ui_restyle/phase1/out_verify_classic_phase1.lua"`; AUDIT runs that file instead.
- Keys starting with `_` are notes. Values are booleans, numbers, strings, or `{"Type": "Color3" | "Vector3" |
  "Vector2" | "UDim" | "UDim2", ...}`.
- A fingerprint is `<djb2>-<fnv1a32>-<bytes>`. Each build adds the after-fingerprints to `applied_hashes.json`, so a
  rebuilt phase accepts its own earlier build as `prior`.

## Modes

| Mode | Does |
|---|---|
| AUDIT | Writes nothing. Each op is `before`, `after`, `prior` or `BLOCKED` with a reason. Each transaction has its own state (`before`, `after`, `mixed`, `blocked`, `empty`). Shows what APPLY and ROLLBACK would do and why ROLLBACK would refuse. Fetches and compiles the sources APPLY would write. Runs the Classic verify |
| APPLY | Writes the first transaction that is not `after`: hierarchy, then sources. One per run |
| ROLLBACK | Writes the first transaction that is not `before`: sources, then hierarchy, ops in reverse. One per run |

A full install is APPLY, AUDIT, APPLY, AUDIT. The `next` field of the report says what to run.

## Guarantees

- Place id 93959280828322 and Edit mode, or every mode blocks.
- Any blocked op blocks the whole run. Nothing is written.
- An existing script must match its before, after or a prior fingerprint.
- Every source to be written is fetched, matched against its fingerprint and compiled with `loadstring` first.
  The place is read again after fetching; a change blocks.
- Hierarchy and sources are never written in one run. A spec or op that mixes them is refused at build and at run.
- Created instances carry `UIRestyleInstall = "<phase>:<opId>"`. An unmarked instance at a create path blocks.
  ROLLBACK removes only marked instances whose source matches, and refuses if one has a child without a mark of
  this phase.
- An attribute or property that is neither its before, after nor a `was` value blocks APPLY and ROLLBACK.
- On a failed write every change of the run is undone in reverse (sources restored, created instances destroyed,
  removed instances put back). The report says whether recovery was complete.
- APPLY refuses while the sandbox test window is open: `Config.Player.Onboarding@StudioVehicleSandboxEveryPlay` is
  true, the `UIRestyleTestWindow` attribute is set, or the folder cannot be found.
- Sources are written with direct `.Source`, and history uses `ChangeHistoryService:SetWaypoint`, as the lighting
  and hover_feel engines do. To change that, edit `getSource`/`setSource`/`waypoint` in `bootstrap.lua`.

## Untested until Studio

This list was written before the runs in Status and has not been re-checked item by item against their results:
the self-test (detached tree) and the proof's AUDIT, APPLY, AUDIT exercised several of these. The save-and-reopen
and created-module ROLLBACK item is certainly still open. `test_engine.py` checks block balance and names only.

- `ModuleScript.Source` read and write on an unparented instance (selftest and the create op both rely on it).
- `RunService:IsEdit()`, `loadstring` with a chunk name, `string.format("%d")` on values above 2^31.
- `shared` persisting between `execute_luau` calls (inline mode). If it does not, APPLY blocks with "inline source
  not loaded".
- `HttpService:GetAsync` returning the file bytes unchanged. A changed byte shows as a `mismatch` block.
- Whether a created ModuleScript survives save and reopen with its mark, and ROLLBACK of a created module (the
  Phase 1 rehearsal, CONTRACT 7.2 P3 to P6).
- `out_verify_classic.lua` run through `loadstring` inside AUDIT, and the size of its result in the report.
