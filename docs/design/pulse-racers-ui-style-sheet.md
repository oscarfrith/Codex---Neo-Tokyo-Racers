# Pulse Racers UI style sheet

**Created:** 2026-10-08. **Revised:** 2026-10-09 (v2).
**Status:** Design v2 - awaiting Oscar's approval at the Phase 0 gate. Nothing in this document is installed.
**Scope:** every player-facing screen: free-roam HUD, car panel, race menu and entry, in-race HUD, results, dealership, customisation, paint shop, owned garage, full map, modals, settings, world prompts, onboarding, loading and start screen.
**Game title:** Pulse Racers (the Studio place is still named Space Racers v3).

This sheet says what the new UI (**Pulse**) looks like. How it is built, switched, scaled, measured and delivered is in the [programme contract](../../scripts/ui_restyle/CONTRACT.md); this sheet points there rather than repeating it. Where the two disagree on mechanics, the contract wins.

The direction is the one Oscar chose on 2026-10-08: Need for Speed Heat's structure and palette, with a small amount of neon glow, reduced to five colour roles and one typeface.

## v2 changes

- **Type** roles are cap heights, converted to Roblox `TextSize` per font. Sizes above the engine's limit of 100 are image digits or are capped.
- **Typeface** is Barlow (Creator Store), chosen by Oscar on 2026-10-09. Titillium Web is dropped: it has no italic heavier than Bold.
- **Switch** is `Config.UI@UIStyle` (`Classic` or `Pulse`), not `Core.FeatureFlags`, which is server-side. Pulse is a second UI set beside today's UI (**Classic**), not a restyle of the existing owners.
- **Shared card** is the new kit `Tile`. Classic's real shared card is `GarageComponents.VehicleCard`; it stays frozen.
- **Delivery** follows the contract: per-phase installers (the generic delivery tool refuses v3), High-Risk from Phase 1.
- **Phone:** minimap stays top-right. Phones get their own Compact compositions, designed with each screen.
- **Results:** driver XP comes from replicated attributes, not the result payload.
- **Acceptance:** "instance counts within 10% of today" is replaced by the contract's budgets, which are lower than today.
- **Added:** Roblox core UI policy, world prompt banners, gamepad selection, Compact rules.
- Config folder is `Config.UI.Pulse`, tokens are owned by the kit, and the build order is the contract's phase list.

## Accepted mockups

Oscar reviewed six passes and asked for this write-up after the last one. The frames are in `assets/ui/mockups/pulse_restyle/`.

| File | Screen | Background |
|---|---|---|
| `01-free-roam.jpg` | Free-roam HUD with event card at a race start | Real capture, v3 |
| `02-race-menu.jpg` | Race browser | Real capture, v3 |
| `03-race-entry.jpg` | Time trial overview | Real capture, v3; prize and times are example values |
| `04-customise-parts.jpg` | Customise, slot rail | Real capture, v3 |
| `05-module-shop.jpg` | Module shop for one slot | Real capture, v3; stat gains and lock reason are examples |
| `06-paint-shop.jpg` | Paint shop | Real capture, v3 |
| `07` to `10` | Dealership, results, race HUD, event card | Sketches on drawn scenery |

The mockups are web drawings laid over game captures, in Barlow Condensed. They are the visual target, not runtime assets. Screens they do not cover, and every phone composition, get preview frames in Phase 0 (`scripts/ui_restyle/previews/`).

## Contract

The binding contract is [scripts/ui_restyle/CONTRACT.md](../../scripts/ui_restyle/CONTRACT.md). In brief:

- **Lane:** High-Risk programme. Pulse installs a second owner for every UI surface.
- **Owners:** each surface is drawn by its Classic owner or its Pulse owner, never both. Pulse owners are new modules under `ReplicatedStorage.Modules.Game.UIPulse`, built from one kit. Classic's owners and shared modules are not restyled.
- **Switch:** `ReplicatedStorage.Config.UI@UIStyle`, read once per session. Absent means Classic. Oscar looks at Pulse by setting it to `Pulse` in Studio. There is no live kill switch or preview list; the game is an unreleased prototype.
- **Must preserve:** every flow, remote, payload, saved field and onboarding page id; display of price, Cash, purchase, spawn, queue and results as a projection of server data; the compact money formatter; confirmation focus and cancel behaviour; LandscapeSensor; positive action on the right, cancel on the left.
- **Exclusions:** no new remotes, saved data, economy values or purchase owners; no world, vehicle, VFX, audio or driving change; no portrait layout; start-screen artwork unchanged.
- **Backup:** Classic stays installed and switchable until Oscar confirms Pulse complete, then is removed (contract Phase 10).
- **Done when:** Oscar has confirmed each screen in Play with `UIStyle` set to `Pulse`.

## Style rules

### Colour

Five roles. A colour is never used outside its role. Screens ask the kit for a role; they cannot pass a colour.

| Token | RGB | Hex | Role |
|---|---:|---|---|
| `Slate` | `14, 13, 26` | `#0E0D1A` | Every panel, tile and button. Opacity 0.86 (BackgroundTransparency 0.14). |
| `White` | `243, 240, 255` | `#F3F0FF` | Primary text, icons, the selected item's fill, hairlines. |
| `Ink` | `7, 6, 13` | `#07060D` | Text and icons on white or yellow. Price chip fill. |
| `Pink` | `255, 45, 149` | `#FF2D95` | Accent: title mark, active-tab underline, selected-tile base line, your row. |
| `Violet` | `154, 61, 255` | `#9A3DFF` | Only as the end of the main-button gradient (`Pink` to `Violet`, left to right). |
| `Cyan` | `34, 228, 255` | `#22E4FF` | Live values: stat gains, route lines, boost, timer delta, checkpoint pips. |
| `Yellow` | `255, 228, 51` | `#FFE433` | Cash only: balance chip, prices, prizes, Buy buttons, banked total. |
| `TextSecondary` | `217, 211, 245` | `#D9D3F5` | Supporting text on slate. |
| `TextMuted` | `185, 179, 214` | `#B9B3D6` | Small labels, inactive tabs. |

Exceptions, all information rather than decoration:

- **Destructive actions** (Despawn, quit an active race) keep the existing `Danger` red `196, 57, 75`. It appears on no other element.
- **Paint swatches** show their own colours.
- **Medal markers** keep four small metal-coloured diamonds.
- **Activity theme** colours (the shared activity views assign them to parts and lights) and **map marker** colours.

Changes to earlier approved rules, for Oscar to confirm at the gate:

- Cash moves from electric blue to yellow (free-roam and racing design systems).
- Selection moves from a cyan outline to a white fill (both design systems).
- Structural pink outlines are removed. Pink becomes an accent line only.
- Tier badges E to S become white with dark letters. The Phase AO tier palette leaves the UI (see Open questions).
- Dealership price text was green when affordable and red when not. Now: yellow chip when affordable, `TextMuted` on the same dark chip when not.

### Typography

One typeface for the whole UI: **Barlow**, from the Creator Store (`rbxassetid://12187372847`). Headings, numbers, buttons and tile names are ExtraBold Italic capitals. Small labels are SemiBold Italic. The wide tech face (Michroma) is dropped.

Barlow is the normal-width cut of the mockup face (Barlow Condensed is not in Roblox and fonts cannot be uploaded), so text runs about 22% wider than the mockups at the same height. Layouts allow for it. If Roblox adds Barlow Condensed, the swap is one token. If Barlow fails to load, text falls back to Roboto Condensed with one warning.

**Roles are cap heights**, the height of a capital letter in pixels at 1920x1080. Roblox `TextSize` is the line height, so the kit converts: `TextSize = round(cap x scale / CapRatio)`, where `CapRatio` is 0.583 for Barlow. The engine stops `TextSize` at 100. The floor is `TextSize` 14 on every device.

| Role | Cap height | Weight | Use |
|---|---:|---|---|
| `ScreenTitle` | 56 | ExtraBold Italic | CUSTOMISE, RACES, track name |
| `SectionHead` | 38 | ExtraBold Italic | PARTS 7/7, WING 3/9 |
| `HeroNumber` | 140 | image digits | Results cash and XP |
| `SpeedNumber` | 95 | image digits | Speed gauge |
| `ButtonMain` | 31 | ExtraBold Italic | Main action, Buy |
| `Button` | 27 | ExtraBold Italic | Other buttons |
| `TileName` | 27 (21 on a rail of seven) | ExtraBold Italic | Tile and event names |
| `Status` | 24 | ExtraBold Italic | Tier, rank, cash readouts |
| `Tab` | 20 | ExtraBold Italic | Tabs |
| `Value` | 18 | ExtraBold Italic | Stat numbers, facts, medal times |
| `Label` | 15 | SemiBold Italic | Small labels, tile sub-lines |

Barlow `TextSize` at four scales (the scale rule is in Responsive and input). Figures are what the formula gives; `100*` means the role has reached the limit.

| Role | 1280x720 (0.667) | 1920x1080 (1.0) | 2560x1440 (1.333) | 3840x2160 (2.0) |
|---|---:|---:|---:|---:|
| `ScreenTitle` | 64 | 96 | 100* | 100* |
| `SectionHead` | 43 | 65 | 87 | 100* |
| `ButtonMain` | 35 | 53 | 71 | 100* |
| `Button`, `TileName` | 31 | 46 | 62 | 93 |
| `TileName` on a rail of seven | 24 | 36 | 48 | 72 |
| `Status` | 27 | 41 | 55 | 82 |
| `Tab` | 23 | 34 | 46 | 69 |
| `Value` | 21 | 31 | 41 | 62 |
| `Label` | 17 | 26 | 34 | 51 |

- **Big numbers** (speed, results cash and XP, race position, countdown, timers) are image digits drawn offline from Barlow Condensed ExtraBold Italic, in fixed cells, tinted by role. They are not limited to 100, stay sharp at 4K and do not jitter.
- **Words above 100.** `ScreenTitle` reaches the limit just above 1080p. The Phase 0 spike decides between a static scaled holder and simply stopping at 100. No home-made text renderer is built.
- **Other changing numbers.** Barlow's digits are proportional, so the cash chip and similar readouts keep a fixed width while they count.
- All capitals except supporting sentences, which stay sentence case at `Label` size.
- Italic labels get right padding of 0.2 x cap so the last letter is not clipped. Capitals are centred with a baseline shift (Barlow sits about 4% low).
- No `TextScaled`. Text is never under an animated scale. At most twelve distinct text sizes on screen.
- **Player Text Size setting.** Body roles (`Label`, `Value`, sentences, toasts, modal bodies, prompt banners) grow in containers sized for the largest setting. Display roles and fixed chips do not.
- Phones (Compact) have their own cap-height table, set from the phone previews in Phase 0.

### Shape, line and glow

- **Corners:** square. The only rounded element is the minimap.
- **Outlines:** none. No `UIStroke` for structure. No bevels.
- **Hairlines:** a panel has a 2 px `White` line on its top edge at 0.85 opacity and a 2 px line on its bottom edge at 0.22 opacity. These are thin frames, not strokes, and scale to whole pixels, never under 1.
- **Texture:** none. No stripes, dots or scanlines on panels or tiles.
- **Title mark:** one small slanted block of pink diagonal stripes to the left of each screen title. This is the only striped element.
- **Glow:** three places only, each a static 9-slice image behind the element:
  - selected tile or selected list row: `Pink`, about 46 px soft radius, 0.55 opacity;
  - main button: `Pink`, about 42 px, 0.6 opacity;
  - speed gauge arcs and the minimap ring: `Cyan` and `Pink`, about 10 px, 0.45 opacity.
  At most twelve glows on screen. The engine's own shadow object replaces the images only if it is seen working on a live phone and PC.
- **Shadow:** titles and section heads over the 3D scene carry a soft dark drop shadow for legibility. No coloured offset shadows.

### Scene treatment

- **In play (HUD):** nothing dims the scene. A soft dark gradient may sit behind the top and bottom 20% to hold text contrast. HUD panels cover at most 12% of the screen at 1080p and 18% on a phone.
- **Garage screens:** a dark gradient on the left 38% and bottom 40%, so the car stays bright. Tints do not block camera orbit; panels do.
- **Full menus (race menu, race entry, modals):** whole-screen tint from `8, 6, 24` at 0.94 to `34, 14, 72` at 0.85, with a faint pink corner. Optional whole-screen blur behind it. Roblox cannot blur behind one panel only. At most two translucent full-screen layers on a phone.

## Components

Each component is built once in the kit and reused. Screens place components in named slots; they hold no coordinates. Sizes below are design values at 1920x1080. The full list and each component's contract are in the contract, section 2.

| Component | Spec | States |
|---|---|---|
| **Panel** | `Slate` 0.86, hairlines, square, padding 22 px | - |
| **Screen title** | Title mark + `ScreenTitle`, top-left at the screen margin (100 px) | - |
| **Tabs** | Row under the title, `Tab` size, icon + label, 34 px gap | Active: `White` with 4 px `Pink` underline. Inactive: `TextMuted`. Locked: 0.45 opacity |
| **Status cluster** | Top-right. One slate strip: car icon + tier badge + rating, rank ring, cash chip. Garage screens show garage spaces in place of the car rating | - |
| **Cash chip** | `Yellow` fill, `Ink` text, coin icon. Same position on every screen. Uses the shared money formatter and the existing cash binding | Counts up on change; width fixed during a count |
| **Tile** | The one shared card for parts, vehicles, events and listings. 315 x 242 px, `Slate`, 2 px bottom line at 0.22. Name bottom-left, `Label` sub-line above it, index or variant chip top-left, status chip top-right, silhouette or card image centred. A designed state for a missing image | Selected: `White` fill, `Ink` text, 6 px `Pink` base line, pink glow, inner image 10% larger; slot diagrams turn ink. Owned/fitted: neutral chip (white 0.16 fill). Locked: 0.6 opacity, lock icon, reason in the sub-line. Unaffordable: muted price. Focus (controller) = selected |
| **Price chip** | `Ink` fill, `Yellow` text, top-right corner of a tile | Unaffordable: `TextMuted` text |
| **Tile rail** | One horizontal row at the bottom, 10 px gap, section head above it with a count ("WING 3/9"). Scrolls horizontally; clipped at the right edge to show there is more | - |
| **Button** | `Slate` strip with hairlines, icon + label, about 72 px tall | Hover/focus: `White` fill, `Ink` text. Disabled: 0.4 opacity, no hairline, not clickable. Pressed: the inner fill changes; the hit box and text do not scale |
| **Main button** | `Pink` to `Violet` gradient, white text, pink glow, trailing chevrons. One per screen, right-most | Same hover/disabled rules |
| **Buy button** | `Yellow` fill, `Ink` text, price in the label. Used only where the action spends Cash | Unaffordable: disabled style, label unchanged |
| **Destructive button** | `Danger` fill, white text | - |
| **Button row** | Bottom-right at the screen margin; centred on results and in the free-roam HUD. Order: back or exit, secondary, main. No key caps | - |
| **Stat panel** | 480 px wide panel, top-right under the status cluster. Car name + tier badge, one or two sub-lines, six rows: label, segmented bar, value | Preview: gained part of the bar in `Cyan`, a `Cyan` chip with the gain. A loss uses a `Pink` chip |
| **Segmented bar** | Segments 10 px wide, 3 px gap, 10 px tall. Filled `White`, empty white at 0.2. Drawn as tiled image strips | - |
| **Tier badge** | `White` fill, `Ink` letter | On a selected tile: `Ink` fill, `White` letter |
| **Fact list** | Rows of icon + label left, value right, hairline between rows. Prize row ends in a yellow chip | - |
| **Event list row** | Route thumbnail left, small label, name, modes | Selected as Tile |
| **Big number** | Image digits in fixed cells | - |
| **Confirm, modal, toast** | Panel, Button and the type roles above. Confirmation behaviour is unchanged: NO left, YES right, NO focused, Escape and B cancel | - |
| **Prompt banner** | Action, object, and a key cap or gamepad glyph. On touch it is a button of at least 48 dp with no key cap | - |
| **Icon** | Single colour, drawn on one sheet to the same ink box, tinted by role | - |

### Icons

Icons replace text on the action bar and sit before the label on every button and tab. One new 1024 px sheet with 128 px cells, every glyph pure white. Existing white glyphs are re-centred onto it (their padding varies from 75% to 100% today); the mockup icons are stand-ins.

| Use | Icon | Source |
|---|---|---|
| Action bar | car, garage, race flag, dealership/tools, settings | Existing, re-centred |
| Buttons | exit (door), back (return arrow), drive (wheel), choose vehicle (car) | Existing, re-centred |
| Buttons | teleport (pin), set route, records (trophy), equip/apply (tick), race again (loop), controls (gamepad) | Drawn |
| Tabs | parts (wrench), paint (brush) | Existing, re-centred |
| Tabs | upgrades (arrow) | Drawn |
| Facts | route, laps, checkpoints, players | Drawn solid (today's are thin outlines) |
| State | lock, coin, boost | Drawn (today's lock is grey and boost is blue; a tint cannot lighten them) |
| Chrome | chevrons, plus, close, north marker, key cap, gamepad glyphs | Drawn |

The 14 map icons have baked colours. A redrawn white set tinted by role is part of the asset batch, so both maps match the palette. Classic keeps its own ids.

## Screens

Positions are at 1920x1080. Screen margin is 100 px for menus and 58 px for the in-play HUD.

### Free-roam HUD

- **Top-right:** status cluster, then the action bar: five 77 x 60 px icon tiles. The open one is white.
- **Bottom-left:** round minimap, 307 px, with a 5 px ring (pink to cyan gradient) and a soft glow. North marker on the rim. District name beneath. Driver rank and its progress line to the right of the map.
- **Bottom-right:** one speed gauge, 403 px. Outer arc is speed (white, turning pink in the last fifth), inner arc is boost (cyan). Speed number and unit inside, boost percentage beneath.
- **Bottom-centre:** two small buttons, Controls and Exit vehicle (driving only).
- **At a race start:** event card top-left (name, type and laps, route, YOU against ENTRY in a diagonal split, prize in a yellow corner) and a Start banner. The banner carries the single interact key cap.
- **On a touch device** the minimap is top-right and the gauge bottom-centre, because steering holds the bottom-left. Touch drive controls are redrawn in white; their input behaviour is unchanged.
- The car panel, settings, controls and cash-store modals use Panel, Tile and Button as above. The car panel keeps its rules: Buy more first, no prices, Despawn fixed. Settings shows only rows that do something: passenger access, minimap mode and, on touch, control mode.

### Race menu and race entry

- **Race menu:** full-screen tint. Title RACES with filter tabs. Event list on the left (480 px wide). Detail on the right: event art with the name over it and a pink rule beneath, then the route map and the fact list side by side. Buttons: Exit, Set route, Teleport (main).
- **Race entry:** keeps the approved racing layout (tabs, tier rail, map left, prize and times right). Title is the track name. The viewed tier is a white tile; completed tiers carry a white underline; locked tiers are dimmed. Prize in a yellow chip beside the tier letter. Medal rows: the one you hold is white with a pink "yours". Buttons: Exit, View records, Choose vehicle (main). These are shortcuts; the pages and their order stay.

### In-race HUD and results

- **In-race:** position top-left as the largest element, lap beneath. Timer top-centre with a pink underline and a cyan delta chip (lap against best lap); checkpoint pips under it. Live order top-right, four rows around the player; the player's row is white. Gauge as in free roam. The free-roam minimap does not run in races; the restyled route map stays on Regular screens.
- **Results:** title RACE COMPLETE in white, event line beneath. Two hero numbers side by side: cash banked in `Yellow`, driver XP in `Pink`, each with a small white label above. One strip beneath: finish, time, best lap. Medals, leaderboard and lap list stay, below the hero numbers. Buttons centred: Race again, Continue (main).
  - Cash and placings come from the server result payload. Driver XP is not in that payload: it is shown as the change in the replicated `Rank` and `XpIntoRank` attributes after the result, and hidden if none arrives within 2 seconds.

### Dealership, customisation and paint

- **Shared frame:** title top-left with tabs, status cluster top-right, stat panel beneath it, tile rail along the bottom, button row bottom-right.
- **Dealership:** tabs are the categories. Rail of cars with tier badge, rating, name and price chip. Buttons: Exit, Buy (yellow).
- **Customise:** Add Modules, Upgrade Modules and Paint Shop become three tabs (Parts, Upgrades, Paint), removing the hub screen. Parts shows one rail of the car's slots, each naming the fitted part. Buttons: Back, Drive (main).
- **Module shop:** Owned Modules and Buy Modules become a Shop / Owned switch beside the section head. Tiles carry a variant chip (STD, GT, EVO) and a price or Fitted chip. The stat panel names the fitted and previewed part and shows gains. Buttons: Back, Drive, Equip or Buy.
- **Paint:** a panel on the left with the channel switch (Primary, Second, Detail, Neon; active is white), three sliders with their values, and the swatch grid. Paint areas are the bottom rail. Buttons: Back, Drive, Apply (main).

Removing the hub and merging Owned/Buy change navigation, not only appearance. Oscar signs off the flow in the gallery, with fixtures, before the garage controller is written. Behaviour that is not look stays: the empty-slot detour to Parts and back, Drive needing engine, stabilisers and boost, where Back goes, and errors as a toast plus an inline line.

### Full map, owned garage, onboarding, loading

- **Full map:** Panel, legend and icons as above. Its key hints stay: without them the map controls cannot be discovered.
- **Owned garage:** browser and desk use Tile, Rail and the shared frame; the interior HUD uses the HUD rules.
- **Onboarding:** callouts and objective cards use Panel and the type roles. Page ids and order do not change.
- **Loading and start screen:** Pulse type and buttons. Artwork unchanged.

## Roblox core UI and world prompts

Applied only under Pulse; Classic is as today. Mechanics are in the contract, section 7.

| Element | In Pulse |
|---|---|
| Player list, health bar, backpack | Hidden. The status cluster shows Cash |
| Chat | Kept in play and in races. Hidden while a full menu, garage screen, results or the full map is open, then restored. The top-left slot starts below it |
| Top bar | Top slots start below it |
| Gamepad selection box | Replaced by each component's own selected look. The engine's automatic selection is off; HUD tiles are not selectable while driving |
| On-foot touch controls | Roblox defaults; bottom corners stay clear on foot |
| Name tags, core notifications, Esc menu, purchase prompts, emotes | Unchanged |

**World prompts** (enter car, garage, race start, jobs): drawn as Prompt banners in one stack in the lower middle of the screen, if the Phase 0 spike passes. The server sees the same trigger. If a banner cannot be drawn, that prompt returns to Roblox's default. If the spike fails, prompts stay Roblox-drawn under Pulse as a recorded exception.

## Responsive and input

One rule for every screen, owned by the kit (contract, section 3).

- **Two layout classes, from screen size only.** `Compact` when the safe height is under 600 or the safe width under 1000; otherwise `Regular`. A phone with a gamepad is still Compact.
- **Scale.** Regular: `min(height / 1080, width / 1600)`, between 0.667 and 2.0, in steps of 1/24. Below the floor the canvas gets smaller, not the UI. Compact: `height / 390`, about 0.85 to 1.25.
- **Regular** uses anchored clusters, not one scaled canvas. Corner clusters follow the screen edges up to 21:9, then stay inside a centred 21:9 box. Menus are a centred block no wider than 2:1.
- **Compact** is drawn on its own at 844x390, 640x360 and 568x320, not shrunk from desktop:
  - its own cap-height table; nothing under `TextSize` 14;
  - every button and tile at least 48 x 48 dp with 8 dp between targets;
  - the tile rail shows fewer tiles and scrolls; the stat panel collapses to name, tier and the changed stats;
  - the race menu is list first, then detail;
  - the button row stays bottom-right inside the safe area; notches and rounded corners are cleared by the engine's safe insets;
  - minimap top-right, gauge bottom-centre.
- **Controller:** focus uses the selected state (white fill). Bumpers switch tabs; triggers switch Shop / Owned. Modals trap focus and restore it. Confirm and cancel keep today's behaviour.
- **Key hints:** none on buttons or tabs. Key caps and gamepad glyphs appear on world prompt banners and on the full map, and follow the input in use.
- **Sharpness:** sizes and offsets are whole pixels. No scaling object sits over chrome.
- **Accessibility:** contrast at least 4.5:1, or 3:1 for large capitals. Colour is never the only signal: selected is also larger, locked also has an icon, gains also have an arrow. Every gate includes a pass at the largest Text Size setting.
- **Verified at:** 1280x720, 1366x768, 1920x1080, 2560x1440, 3440x1440, 3840x2160, a 1180x820 tablet and four phone sizes, then a gamepad pass.

## Config

Tokens are a table in the kit (`UIPulse.Kit.Tokens`), kept in git. The same values sit as typed attributes under one new folder for tuning:

```text
ReplicatedStorage.Config.UI.Pulse        colour roles, cap heights, CapRatio, BaselineShift, spacing,
                                         opacities, hairlines, glow method and opacities
ReplicatedStorage.Config.UI.Pulse.Assets uploaded image ids (icon sheet, glow, digits, gauge, map icons)
ReplicatedStorage.Config.UI@UIStyle      "Classic" or "Pulse"; absent means Classic
```

No existing config value or asset id changes. The Classic colour, layout and theme folders stay as they are while Classic exists and go with it in Phase 10.

## Assets to upload

One batch from one contact sheet, each needing Oscar's yes; about 14 to 18 files:

- the icon sheet;
- three glow 9-slices;
- two or three digit sheets;
- gauge ring and tick ring; minimap ring and vignette;
- title mark, chequered corner and key cap;
- white map player arrow and the recoloured map icons;
- four touch-control images redrawn white.

Digits and drawn icons are rendered offline by headless Chrome using the Google Fonts web face, so no font file is downloaded. Uploads cannot be edited; a revision is a new id.

## Build order

The contract's phase list (section 9): spike and previews, foundation and switch, race menu pilot, free-roam screen, world and map, race session and results, race entry, garage, shell, hardening and flip, then retiring Classic. Phones and controllers are built with each screen.

## Open questions

1. **Tier and affordability colour.** Tier badges are white and unaffordable prices are muted, which removes six tier colours plus green and red. Keep it that way (this sheet's default), or bring tier colour back as a thin line under the letter?
2. **Controller hints on tabs.** No hints appear on buttons or tabs (this sheet's default). Should bumper and trigger glyphs appear beside the tabs and the Shop / Owned switch when a gamepad is in use?

Typeface is no longer open: Barlow.
