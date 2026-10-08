# UI restyle (Pulse Racers): working folder

**Status, 2026-10-09:** design phase, paused overnight at Oscar's request. Nothing is installed. No game script, config or asset in Studio has been changed. Oscar has not yet been given recommendations and has approved no build.

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
| `design/review-*.md`, `design/recommended-plan.md`, `design/fact-check.md` | Added when the design pass finishes. If they are missing, the pass was interrupted: see "To resume". |
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

1. Read `design/recommended-plan.md` and `design/fact-check.md`. If missing, re-run `workflows/design-panel.js` after changing its `ROOT` constant to this folder's `audit` path (the three proposals already exist, so the review, synthesis and fact-check stages are what remain).
2. Give Oscar the recommendations and the decisions he must make. Do not build before he answers.
3. After his answers: correct the style sheet, write `CONTRACT.md` here, then a rendering spike and a one-screen pilot before any wider build.
