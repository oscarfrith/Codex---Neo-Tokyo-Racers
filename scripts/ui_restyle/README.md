# UI restyle (Pulse Racers): working folder

**Status, 2026-10-09:** design phase complete; recommendations put to Oscar; awaiting his decisions. Nothing is installed. No game script, config or asset in Studio has been changed, and no build is approved.

## What Oscar asked for (2026-10-08)

Build the UI shown in the previews, improved to scale and align better and to be more consistent and refined; well optimised without losing quality; every current screen changed so the UI is cohesive; shared cards and components; the old UI kept as a backup the game can switch back to. He asked for recommendations **before** any build.

## What is here

| Path | What it is |
|---|---|
| `../../docs/design/pulse-racers-ui-style-sheet.md` | The visual target. Design, not approved. It has known errors (listed at its top). |
| `../../assets/ui/mockups/pulse_restyle/` | The ten mockup frames Oscar reviewed. |
| `audit/*.md` | Read-only audit of every UI owner in live v3 source, one file per group, with line references. Also project delivery rules, Roblox platform research and fonts/assets. `critic.md` lists gaps, contradictions and open questions. |
| `audit/structured-summaries.json` | The same audit as short structured summaries (defects, risks, seams) per group. |
| `design/proposal-*.md` | Three independent build proposals (safest backup, most cohesive, quality and speed). |
| `design/review-*.md` | Three adversarial reviews of the proposals (rules and regression, platform and performance, completeness and UX). |
| `design/recommended-plan.md` | The synthesised plan: switch, kit, scaling, budgets, phases, delivery route. **Read with `fact-check.md`**, which lists ten corrections not yet folded in. |
| `design/fact-check.md` | The plan's key claims checked against live v3 source: 20 confirmed, 3 partly, 1 wrong, plus ten plan errors to fix when the contract is written. |
| `workflows/*.js` | The two agent workflows that produced the audit and the design pass. |

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

1. Get Oscar's answers to the decisions in `design/recommended-plan.md` (approach and phases, look and uploads, Roblox core UI and navigation, test mode). Do not build before he answers.
2. Fold the ten fact-check corrections into the plan, correct the style sheet, and write `CONTRACT.md` here.
3. Phase 0: rendering spike, preview frames for the screens the mockups do not cover, asset contact sheet. Nothing installed.
