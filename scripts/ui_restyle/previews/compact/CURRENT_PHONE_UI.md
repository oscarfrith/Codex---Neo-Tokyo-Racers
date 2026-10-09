# Current (Classic) phone UI, measured for 844x390

Read from the Classic record, not from Play: `classic/sources/…MobileFreeRoamHudUI.lua` `layout()` (L346-366), `…MobileDriveControlsClient.lua` `layout()` (L177-191), `classic/config.json` (`UI.MobileFreeRoamHud`, `UI.GarageReplacement`) and `audit/garage-core.md` 4.3. At 390 dp of height both scripts take their `tiny` branch (`vp.Y < 500`). Classic measures the full viewport and ignores the safe area, so x and y below are from the screen's top-left corner. Screen area is 329,160 dp².

## Free roam

| Element | Where | Size (dp) | Drawn as | Share |
|---|---|---|---|---:|
| Minimap | top-right, margin 10 | 128 x 128 | filled disc | 5.0% |
| Nav row (Car double width, Garage, Race, Dealership, Settings) | top edge, left of the map, gap 4 | 224 x 34 (buttons 34, Car 72) | filled buttons | 2.1% |
| Cash | under the map, gap 4 | 128 x 30 | filled chip | 1.2% |
| Rank strip | under cash, gap 4 | 128 x 18 | 72% filled strip, 8 to 9 px text | 0.7% |
| Speed, gauge, boost bar, MPH, Exit | bottom-centre, 2 above the edge | frame 260 x 118 (420 x 190 at UIScale 0.62); drawn parts about 13,000 dp² | text and 16 small segments, no backing | 3.9% (frame 9.3%) |
| Turn left / right | bottom-left, margin 10 | 90 x 60 each, gap 7 | card at 0.4 opacity | 3.3% |
| Drift left / right | row above the turn arrows | 90 x 60 each | card at 0.4 opacity | 3.3% |
| Boost | centred above the arrows, gap 8 | 44 x 44 hit, icon about 37 | icon only | 0.4% |
| Brake, Accelerator | bottom-right, 10 from the right, 8 from the bottom, no gap | 125 x 125 each | image at 0.7 opacity, card opacity 0 | 9.5% |
| Vehicles list (when open) | left edge, top 68 | about 197 x 320, two columns, three rows | filled panel | (19%) |

- **Driving: about 29% of the screen is drawn on (35% if the transparent telemetry frame and the hit boxes are counted).** Only about 16% has a filled backing (map, nav, cash, rank, arrow cards); the pedals, boost and speed are bare glyphs, which is why it reads as light.
- On foot: map, nav, cash and rank only, about 9%.
- Centre of the screen: nothing but the speed readout at the bottom-centre. The arrow block (to x = 197) and the pedals (from x = 584) reach into the middle 60% of the width, below 65% of the height.
- Placement logic: everything hangs off a corner or the bottom-centre; one top-right cluster (map with nav to its left, cash and rank under it); steering left thumb, pedals right thumb.
- The weakness is legibility, not size: text is 7 to 15 px (rank 8 to 9, Exit about 6 after the 0.62 scale), nav targets are 34 dp, Exit is about 47 x 19.

## Garage, dealership, customise

One desktop layout (1600 x 900 reference) shrunk by `scale = 0.42` at 844x390.

| Element | Where | Size (dp) | Share |
|---|---|---|---:|
| Header (title, subtitle) | top-centre | 176 x 34 | 1.8% |
| Category rail | left edge, from y = 68 | 90 x 236 | 6.5% |
| Stat panel plus two economy chips | right edge, from y = 12 | 149 x 189 | 8.6% |
| Carousel | bottom, 8 above the edge, 26 in from each side | 775 x 70, cards 95 x 61 | 16.5% |
| Carousel arrows | ends of the carousel | 32 x 32 (the only element with a minimum size) | 0.6% |
| Action buttons | right, 20 above the carousel | 71 x 19 each | 1.2% |

- **About 35% of the screen covered; the car keeps the middle.** Order from the bottom: carousel, then the button row above it on the right.
- Labels land at 4 to 6 px and buttons at 20 dp, so it is unreadable and hard to hit on a phone.

## What the rework takes from it

- Corner clusters and the same thumb positions: steering, drift, boost, pedals, speed and Exit are where Classic has them.
- Review 3 (2026-10-09): the drive controls are the Classic ones restyled (same pictograms, square Slate plate, gradient outline), one baked image each, no labels. The slanted shapes of review 2 were rejected. Plates: turn and drift 52 x 52, boost 48 round, brake 76 x 64, accelerate 72 x 100 dp. The speed readout is the desktop gauge at 92 dp.
- Cash and rank as the whole free-roam status (no tier / PI block).
- Garage order: rail on the bottom edge, buttons above it on the right, stats top-right.
- What changes: every target is 48 dp or more, no text under TextSize 14, the safe area is respected, and the footprint goes down (16.1% driving after review 3, 14.1% after review 2, 26.8% customise and 27.9% dealership after review 2, with the action row at the top centre and the stat block always visible).
