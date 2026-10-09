# Compact type roles (proposal from the Phase 0 phone previews)

Status: proposal for Oscar. Nothing is installed. Source: `compact.css` (`.cx` variables) and frames c01 to c19.

## Scale used in the previews

- Compact design unit = 1 dp at 844x390. `scale = clamp(viewportHeight / 390, 0.85, 1.10)`.
- 568x320 gives 0.85 (raw 0.82, clamped: the canvas gets smaller, not the UI), 640x360 gives 0.92, 844x390 gives 1.00, 932x430 gives 1.10.
- Touch target `T = max(48, 48 / scale)` design units and gap `G = max(8, 8 / scale)`, so a target is never under 48 dp and a gap never under 8 dp. At 568x320 that is 56.5 and 9.4 design units; every layout was fitted with those values.
- Roblox top bar reserve: 120 x 52 dp, converted to design units.

## Table

Cap height in dp at scale 1. `TextSize = round(cap x scale / 0.583)` for Barlow (CSS font-size = cap / 0.70).

| Role | Cap (dp) | TextSize at 0.85 / 1.00 / 1.10 | Weight | Used for |
|---|---:|---|---|---|
| ScreenTitle | 22 | 32 / 38 / 42 | 900 italic | CUSTOMISE, RACES, track name, RACE COMPLETE |
| SectionHead | 17 | 25 / 29 / 32 | 900 italic | PARTS 7/7, stat panel car name, modal title, tier letters |
| ButtonMain | 14 | 20 / 24 / 26 | 800 italic | Main and Buy buttons, Start banner |
| Button, TileName, Status | 13 | 19 / 22 / 25 | 800 italic | Other buttons, list row names, status strip, cash chip |
| Tab, Value, RailTileName | 12 | 17 / 21 / 23 | 800 italic | Tabs, Shop/Owned, stat numbers, facts, medal times, names on rail tiles |
| Label | 10 | 15 / 17 / 19 | 600 italic (800 on chips) | Small labels, tile sub-lines, chips, board rows |
| Body (sentence case) | 10 | 15 / 17 / 19 | 500 upright | Toasts, callout copy, modal sentences |
| TimerNumber | 21 | sprite | Barlow Condensed 800 italic | Race timer, personal best |
| SpeedNumber | 35 | sprite | same | Gauge speed |
| PositionNumber | 40 | sprite | same | Race position, tier letter on the prize panel |
| HeroNumber | 46 | sprite | same | Results cash and XP |
| CountdownNumber | 88 | sprite | same | 3, 2, 1, GO |

Six text sizes plus body, under the plan's limit of twelve on screen.

## Reasoning

- **Label sets the floor.** Cap 10 is the smallest value that stays at or above TextSize 14 at scale 0.85 (it gives 15). Cap 9 would give 13.
- **The ratio between roles is flatter than Regular.** Regular runs 15 to 56 (3.7x); Compact runs 10 to 22 (2.2x). A phone has 320 to 430 dp of height, and a 48 dp button row, a 52 dp top bar band and a rail must all fit, so the title cannot keep its desktop share.
- **ScreenTitle 22** is the largest cap that lets the longest title (SHOWROOM LOOP, DEALERSHIP) sit in the top-bar band beside the Roblox buttons with the status strip on the right at 568x320.
- **Button 13 inside a 48 dp target** leaves room for an icon and two buttons side by side in the 212 dp action block.
- **RailTileName 12** fits FRONT ENGINE on one line of a 128 dp tile; DRIFT THRUSTERS wraps to two lines as on desktop.
- **Value and Tab share cap 12** to keep the glyph atlas small.
- **Numbers above cap 21 are image digits**, as on Regular. None of the word roles reaches TextSize 100.
- **Not tested here:** the player Text Size setting at Largest, and Barlow's real Roblox metrics (the previews assume cap 0.70 em and TextSize = CSS size x 1.2).
