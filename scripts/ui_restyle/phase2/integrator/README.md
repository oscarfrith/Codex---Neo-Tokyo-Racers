# Pulse wave 2: integrator runbook

One unit at a time, in the order of `../CONTRACT.md` section 5: `kit`, `race_menu`, `free_roam`, `world_map`,
`race_session`, `race_entry`, `garage`, `shell`, then `flip`. A unit is not started until the one before it has passed
step 12 of the contract. The tools are in `../tools/`; none of them talks to Studio or git.

Status of the tools: **generated and tested offline** (`test_lint_phase2.py`, `test_tools.py`). The three `.lua`
harness files have not run in Studio yet; treat their first run as their test.

## Folders

| Folder | Written by | Holds |
|---|---|---|
| `../kit/k1..k4/`, `../families/<unit>/` | the build agents | sources, tests, fragments (API2 6.1). The tools only read them |
| `integrator/` (this folder) | you and the tools | `UIPulse.NoOp.lua`; `tokens_flat.json` (from the harness); `lint_accept.json` (reviewed lint exceptions); `kit_after/` and `kit_tests/` (kit files you write yourself, such as an edited gallery); `forks_out/<unit>/` (generated) |
| `../install/<NN>_<unit>/` | `assemble.py` | the installable phase folder: `spec.json`, `after/`, `before/`, `tests/`, `declared.json`, the Classic verify, `test_manifest.json`, `out_*.lua` |
| `../install/state.json` | `assemble.py` | the chain: which unit installed which script. A unit's `before` is the previous unit's `after` |

## The sequence for one unit

Run from the repository root. `<unit>` is the folder name, `<NN>_<unit>` its install folder (`00_kit`, `01_race_menu`, ...).

```
py -3 scripts/ui_restyle/tools/serve.py                                  leave running (127.0.0.1:8796)
py -3 scripts/ui_restyle/phase2/tools/status.py                          what has arrived, what is open
```

**1. Assemble** (contract step 1). Builds the forks, merges the fragments, regenerates `Routes`, writes the
cumulative `declared.json`, builds the Classic verify, runs `engine/build.py`.

```
py -3 scripts/ui_restyle/phase2/tools/assemble.py <unit>
```

It stops with a list when a file is missing, a fragment is wrong or an op collides with another unit. `--partial`
turns "missing file" into a warning for a dry run. Exit code 3 means PROVISIONAL (kit only, see below).

**2. Lint** (step 4). 0 open findings, or each one accepted in `integrator/lint_accept.json` with a reason.

```
py -3 scripts/ui_restyle/phase2/tools/lint_phase2.py <unit>              add --show-exempt to list kept fork lines
```

**3. Parity** (step 5, families only). 0 open rows.

```
py -3 scripts/ui_restyle/phase2/tools/parity_check.py <unit>             add --all to list covered rows too
```

**4. Forks** (step 5, units with `forks/`). `assemble.py` has already built them; this prints the report to read: the
hand-assembled copy must say `match`, and the "guarded words" list shows every removed or new line that touches
`MobileDriveInputState`, a remote, a bindable, an attribute write or `.Enabled`.

```
py -3 scripts/ui_restyle/phase2/tools/build_forks.py <unit>
```

**5. Edit harness** (steps 2 and 3). Studio in Edit, the v3 place. Open `tools/run_tests_phase2.lua`, set
`ARGS.unit = "<NN>_<unit>"` and send the whole file through `execute_luau`. It fetches
`install/<NN>_<unit>/test_manifest.json`, compiles every source and runs the pure tests of the unit, the kit and
Phase 1 (`ARGS.scope = "all"` runs every family's tests too; `ARGS.failuresOnly = true` shortens a long result).
Pass: `ok` true, `compileErrors` empty, the three `harness` rows ok. Save the JSON as
`install/<NN>_<unit>/results/edit_tests_<n>.json`.

**6. Reviewer** (step 6). `delivery-reviewer` on `install/<NN>_<unit>/spec.json`, `before/` against `after/`, the
unit's `CONTRACT.md` and `contract.json`; again on every edit to an existing Classic script (`assemble.py` prints
`EDITS A CLASSIC SCRIPT`) and on every fork; the whole Garage family with its purchase table.

**7. AUDIT and APPLY** (steps 7 to 9). Each `out_*.lua` in `install/<NN>_<unit>/` is sent whole through `execute_luau`
in Edit; each run writes at most one transaction, so APPLY runs twice. The sandbox test window must be closed.

```
out_audit.lua      every op "before"; Classic verify ok (241 + declared)
out_apply.lua      hierarchy          then out_audit.lua
out_apply.lua      sources            then out_audit.lua: every op "after"
save, close, reopen                   then out_audit.lua: every op "after"
out_rollback.lua   twice, out_audit.lua after each: "before"         (once per install, before Play)
out_apply.lua      twice, out_audit.lua after each: "after"; save
```

**8. Play checks** (steps 10 and 11). Style and the sandbox window are set in Edit with `../../phase1/set_style.lua`
(`mode = "classic"`, then `"pulse"`, and `"restore"` before any AUDIT or save). During Play, each file in
`tools/play_check/` is run on the client as the source of an unparented ModuleScript, as the Phase 1 probes were;
edit its `ARGS` table first. Each returns one JSON string and writes nothing.

| File | Use |
|---|---|
| `startup_state.lua` | every entry `ready`; latch attributes; every ScreenGui with `UIStyle`, DisplayOrder, descendant count, duplicate flag; client errors and Pulse/ClientBase warnings. Set `expectStyle`, and `absentGuis` to the Classic gui names the delivered families replace |
| `buttons.lua` | `ARGS.gui = "<ScreenGui name>"`: visible buttons with name, text, mark attributes and centre (`mouse` = centre + GuiInset, for mouse input) |
| `layer_writes.lua` | `ARGS.guis`, `ARGS.seconds`: Changed counts per ScreenGui, per property, plus descendant churn. A resting Pulse layer shows 0; a Classic gui shows `byProperty.Enabled` 0 while a Pulse screen opens and closes |

**9. Record** (step 12): `install/<NN>_<unit>/verification.json`, the docs, commit of explicit paths.

## Kit only: the token attributes

The kit's token attribute ops come from `Tokens.Flatten(Tokens.Defaults)` of the kit v2 source, read in Studio.

```
py -3 scripts/ui_restyle/phase2/tools/assemble.py kit                    PROVISIONAL (exit 3): spec not installable
   run the Edit harness on 00_kit; save its JSON
py -3 scripts/ui_restyle/phase2/tools/tokens_from_dump.py <saved result.json>     writes integrator/tokens_flat.json
py -3 scripts/ui_restyle/phase2/tools/assemble.py kit                    installable
```

Until then the ops come from `kit/k1/tokens_flat.json` (K1's desk parse). When both files exist they must agree or
the assembly stops. The asset attributes take the ids in `../../assets/uploaded_assets.json`.

## Rules the tools enforce that are worth knowing

- **Chain.** Units are assembled in order. Reassembling a unit drops the later ones from `state.json`; assemble them
  again. `state.json` and `install/` are generated: never edit them.
- **Classic verify.** A script changed by the unit being installed is left unpinned in that unit's `declared.json`,
  because AUDIT must pass both before and after APPLY; the next unit pins it. A Classic script may be edited by one
  unit only (the verify holds one after-hash per Classic script); a second edit stops the assembly.
- **`UIPulse.NoOp`** is created by the kit install (CONTRACT section 2, row 0). `assemble.py kit --noop-on-first-need`
  leaves it to the first family whose routes name it (FreeRoam) instead. Decide once, before the kit's first APPLY.
- **Op ids** become install marks (`<NN>_<unit>:<id>`). Agents' ids are kept. Do not rename one after the first APPLY.
- **Forks.** The fork build is what is installed. A hand-assembled copy that differs stops the assembly
  (`--forks-win` installs the fork build anyway and prints the difference).
- **Lint on forks.** Lines of a fork that are kept Classic text are exempt from API2 6.6 rules 5 and 6 and from the
  `.Enabled` rule. Other findings on kept lines (a kept `RenderStepped`, a kept warning, Classic's own first line
  where the Pulse header would be) are listed as "kept: review" and do not fail the unit. A kept Classic `require`
  does fail, except in `RaceSession.RouteGuideClient`.
- **Accepting a lint finding.** `integrator/lint_accept.json`:
  `{"accept": [{"file": "<file name or glob>", "rule": "<rule>", "line": 12, "reason": "...", "reviewer": "..."}]}`.
  An inline `-- lint-ok:` comment is honoured for style rules only; safety rules need the file.
- **Parity.** A row is covered when a `dropped` or `added` entry names its key word in `item` and cites a section in
  `reason`. "review" rows (common reserved names, a declared superset of bindable keys) are printed and not counted.
  Rows of part B (declaration against the code) cannot be covered: fix the code or the declaration.

## Tests of the tools

```
py -3 scripts/ui_restyle/phase2/tools/test_lint_phase2.py
py -3 scripts/ui_restyle/phase2/tools/test_tools.py                      builds a throw-away kit and family in a temp folder
py -3 scripts/ui_restyle/phase2/tools/gen_routes.py phase1               must print: byte for byte equal ... yes
```

Every tool takes `--kit-dir`, `--families-dir`, `--install-dir` and `--integrator-dir` to work on another tree.
