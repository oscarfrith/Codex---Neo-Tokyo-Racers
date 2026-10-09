# Compact type roles (proposal from the Phase 0 phone previews)

Status: proposal for Oscar, revised after review 1 (2026-10-09: "a lot of the ui looks too big"). Nothing is installed. Source: `compact.css` (`.cx` variables) and frames c01 to c19.

## Scale used in the previews

- Compact design unit = 1 dp at 844x390. `scale = clamp(viewportHeight / 390, 0.85, 1.10)`.
- 568x320 gives 0.85 (raw 0.82, clamped: the canvas gets smaller, not the UI), 640x360 gives 0.92, 844x390 gives 1.00, 932x430 gives 1.10.
- Touch target `T = max(48, 48 / scale)` design units and gap `G = max(8, 8 / scale)`, so a hit box is never under 48 dp and a gap never under 8 dp.
- **New: what is drawn is smaller than the hit box.** Buttons, tabs, tier buttons and segment options are 36 units tall inside a `T`-tall hit box; nav icons are 32 in 48; the boost ring is 44 in 52; pedal rings are 68 and 44 inside 96 x 112 and 80 x 64 hit boxes. Rows of controls are spaced by their hit boxes, not by what is drawn.
- Roblox top bar reserve: 120 x 52 dp, converted to design units.

## Table

`TextSize = round(CSS px x 1.2 x scale)` for Barlow. Cap height is 0.70 of the CSS size.

| Role | CSS px (was) | Cap (dp) | TextSize at 0.85 / 1.00 / 1.10 | Weight | Used for |
|---|---:|---:|---|---|---|
| ScreenTitle | 22 (31.4) | 15.4 | 22 / 26 / 29 | 900 italic | CUSTOMISE, DEALERSHIP, track name, RACE COMPLETE |
| SectionHead | 18 (24.3) | 12.6 | 18 / 22 / 24 | 900 italic | PARTS 3/7, modal title, tier letters, 2ND |
| ButtonMain | 16.5 (20) | 11.6 | 17 / 20 / 22 | 800 italic | Main and Buy buttons, START prompt |
| Text | 15 (17.1 to 18.6) | 10.5 | 15 / 18 / 20 | 800 italic | Other buttons, tabs, status strip, cash, row names, values, stat numbers |
| Label | 13.8 (14.3) | 9.7 | 14 / 17 / 18 | 600 italic (800 on chips, tile names, board rows) | Rail tile names, small labels, chips, prices, MPH |
| Body (sentence case) | 13.8 (14.3) | 9.7 | 14 / 17 / 18 | 500 upright | Toasts, callout copy, modal sentences |
| TimerNumber | 24 (30) | 17 | sprite | Barlow Condensed 800 italic | Race timer, personal best |
| SpeedNumber | 34 (50) | 24 | sprite | same | Speed readout |
| PositionNumber | 40 (57) | 28 | sprite | same | Race position, tier letter on the prize panel |
| HeroNumber | 44 (66) | 31 | sprite | same | Results cash and XP |
| CountdownNumber | 96 (126) | 67 | sprite | same | 3, 2, 1, GO |

Five text sizes (four word roles plus Label/Body), down from six. The rank number on the minimap arc is Label; the minimap's N is part of the ring image.

## Reasoning

- **Label sets the floor.** 13.8 px is the smallest size that stays at TextSize 14 at scale 0.85 (13.8 x 1.2 x 0.85 = 14.08). The render check prints the smallest TextSize on every frame: 14.1 at 568x320, 15.3 at 640x360, 16.6 at 844x390, 18.2 at 932x430.
- **Everything above the floor moved down toward it.** The old table ran 14.3 to 31.4 px (2.2x). The new one runs 13.8 to 22 px (1.6x). On a 390 dp tall screen hierarchy comes from weight, colour and position more than from size; the title sits beside the Roblox buttons and does not need to be the biggest thing on the screen.
- **Text 15** is one size for buttons, tabs, values and the status line, which removes three near-identical roles (17.1, 18.6, 18.6) and keeps a 36-tall button comfortable.
- **Rail tile names are Label, one line.** Tiles size to their name (minimum 88 units), so DRIFT THRUSTERS stays on one line and all seven part slots fit an 844 dp screen.
- **Numbers at 24 px and above are image digits**, as on Regular. The speed number dropped from cap 35 to cap 24 because it no longer sits inside a dial.
- **Not tested here:** the player Text Size setting at Largest, and Barlow's real Roblox metrics (the previews assume cap 0.70 em and TextSize = CSS size x 1.2).
