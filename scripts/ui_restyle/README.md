# UI restyle (Pulse Racers): working folder

**Status, 2026-10-09:** Oscar approved the plan ("happy with all recommendations"). `CONTRACT.md` is the binding programme contract. **Phase 0 has been run and waits at its gate** for Oscar (results: `phase0/RESULTS.md`; preview images were converted to JPG after rendering). Nothing is installed: no game script, config or asset in Studio has been changed. Phase 0 opens the Studio no-save sandbox for its Play sessions (one Edit attribute write, restored after each session) and creates only transient Play-session instances.

Decided: Pulse is a second UI set beside Classic; Classic stays installed as the backup and is removed once Pulse is confirmed complete (Phase 10, on Oscar's go); typeface Barlow; no live kill switch or preview list (unreleased prototype). Oscar's sign-off blocks at Phases 0, 1, 7, 8, 9 and 10.

## What Oscar asked for (2026-10-08)

Build the UI shown in the previews, improved to scale and align better and to be more consistent and refined; well optimised without losing quality; every current screen changed so the UI is cohesive; shared cards and components; the old UI kept as a backup the game can switch back to. He asked for recommendations **before** any build.

## What is here

| Path | What it is |
|---|---|
| `CONTRACT.md` | **The programme contract.** Switch, kit, scaling, type, budgets, core UI, phases 0 to 10, delivery and test route. Supersedes `design/recommended-plan.md`. |
| `../../docs/design/pulse-racers-ui-style-sheet.md` | The visual target, v2. Awaiting Oscar's approval at the Phase 0 gate. Points here for mechanics. |
| `../../assets/ui/mockups/pulse_restyle/` | The ten mockup frames Oscar reviewed. |
| `audit/*.md` | Read-only audit of every UI owner in live v3 source, one file per group, with line references. Also project delivery rules, Roblox platform research and fonts/assets. `critic.md` lists gaps, contradictions and open questions. |
| `audit/structured-summaries.json` | The same audit as short structured summaries (defects, risks, seams) per group. |
| `design/proposal-*.md` | Three independent build proposals (safest backup, most cohesive, quality and speed). |
| `design/review-*.md` | Three adversarial reviews of the proposals (rules and regression, platform and performance, completeness and UX). |
| `design/recommended-plan.md` | The synthesised plan as put to Oscar. **Superseded by `CONTRACT.md`**; kept as the record. Do not build from it. |
| `design/fact-check.md` | The plan's key claims checked against live v3 source. Its ten corrections are folded into the contract (appendix D). |
| `workflows/*.js` | The two agent workflows that produced the audit and the design pass. |

Added by Phase 0:

| Path | What it is |
|---|---|
| `classic/` | Classic source record: every script source, the manifest with hashes and the typed `Config.UI` dump. The proof baseline that Classic is unchanged. |
| `engine/` | The programme's installer engine and its mock tests. Not run against Studio until Phase 1. |
| `probes/` | Read-only client probes (instance census, churn, writes, layout lint, performance sample). |
| `spike/` | The throwaway Play-only harness for the unverified engine behaviours, and its results. |
| `previews/` | Preview frames for screens the mockups do not cover and for each phone composition. |
| `assets/` | Offline asset generators, the contact sheet and, after upload, `uploaded_assets.json`. |
| `tools/` | Build and capture helpers (local source server, contract extractor). |

Each later phase adds one sub-folder with its own `CONTRACT.md`, before and after sources, build script, installer outputs and `verification.json`.

Paths inside the notes point at a session scratch folder; the files were copied here unchanged.

## What the audit established

All of this is read from source, config and documentation. None of it was verified in Play.

- **Switch:** every UI owner is one closure exporting only `start()`. ClientBase starts modules from an entry list with one path-resolve step, so a new module can be built beside each old one and one set chosen at start-up, leaving old scripts byte-identical. `Core.FeatureFlags` is server-side and cannot be the switch; a replicated config value is needed.
- **Shared modules are the hard part:** 19 scripts use `RacingUIComponents` and 9 use `GarageComponents`. Restyling those in place would change the old UI, so the new look needs its own kit and the old kit stays frozen.
- **Scaling:** no shared scale source. Free roam clamps at 0.72 to 1.12 of 1920x1080, garage stops growing at 1.02 of 1600x900, racing at 1.15 of 1200x720; phones shrink the desktop canvas to about 0.43, giving 4 to 9 px text and 20 px buttons.
- **Fonts:** Barlow Condensed (the mockup face) is not in Roblox and fonts cannot be uploaded. Creator Store Barlow (`rbxassetid://12187372847`) has the heavy italics. `TextSize` is capped at 100 and is line height, so the style sheet's sizes need converting.
- **Roblox's own UI** overlaps the mockups: player list (top-right), chat (top-left), top-bar inset, default proximity prompts, default gamepad selection box.
- **Delivery:** the generic delivery and capture tools refuse the v3 place; v3 work uses per-task installers. Creating new ModuleScripts in v3 is not yet proven. v3 Play saves Oscar's real profile.
- **Existing defects** in the current UI were found along the way (see each note's defects section). They are unverified in Play and none has been fixed.

## Side effects of the mock-up capture sessions (2026-10-08)

Play sessions in v3 used Oscar's real profile: Cash rose by $13 from a short drive, and the race-browser tutorial prompts were followed (Next, Teleport), which may have advanced saved tutorial progress. Nothing was bought. The UI was hidden and the character moved by script for a few seconds, Play-session only.

## To resume

1. Read `CONTRACT.md` (sections 0, 9 and 10 first), then `docs/00_START_HERE.md` for the current step.
2. Finish Phase 0: spike results, Classic record taken twice, baselines, preview frames, contact sheet. Check the sandbox attribute is back at its earlier value.
3. Phase 0 gate: Oscar approves style sheet v2, the previews and the asset batch. Phase 1 (High-Risk) does not start before that.
