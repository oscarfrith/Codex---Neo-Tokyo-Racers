# Pulse Racers UI style sheet

**Created:** 2026-10-08
**Status:** Design - not approved. Nothing in this document is installed.
**Scope:** every player-facing screen: free-roam HUD, car panel, race menu and entry, in-race HUD, results, dealership, customisation, paint shop, owned garage, full map, modals and settings.
**Game title:** Pulse Racers (the Studio place is still named Space Racers v3).

This sheet turns the direction Oscar chose on 2026-10-08 into rules a build can follow. The direction is Need for Speed Heat's structure and palette, with a small amount of neon glow, reduced to five colour roles and one typeface.

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

The mockups are web drawings laid over game captures. They are the visual target, not runtime assets. Build the live UI from Roblox UI objects. The mockups use Barlow Condensed, which Roblox does not ship (see Typography).

## Contract

```text
System/change: one visual style for all Pulse Racers UI, replacing the pink-outline / Michroma style.
Delivery lane and reason: Standard, presentation only. High-Risk preservation gates apply wherever a
  screen shows price, Cash, purchase, spawn, queue or race results (display must stay a projection of
  server data). The token and switch step touches every UI owner, so it is reviewed as one change.
Goal: every screen reads as one product: bolder, easier to read at speed, fewer colours.
Current confirmed baseline: v3, audited read-only on 2026-10-08. All UI is built in code (StarterGui is
  empty; about 20 ScreenGuis at start-up). Colours live in three near-identical config folders plus
  about 230 literals in scripts. Michroma is named in four config values and in script literals.

Required changes: see "Style rules", "Components" and "Screens" below.
Must preserve: every flow, owner, remote, saved field and server payload; compact money formatter;
  48 px touch targets; safe-area clamping; confirmation focus and cancel behaviour; LandscapeSensor;
  positive action on the right, cancel on the left; no key legends that the current UI does not need.
Explicit exclusions: no new remotes, saved data, economy values or purchase owners; no world,
  vehicle, VFX, audio or driving change; no portrait layout; the start screen logo art is unchanged.

Canonical owners:
- State: unchanged (GarageUI, DesktopFreeRoamHudUI, MobileFreeRoamHudUI, the Race*Client owners,
  FullMapUI, OwnedGarage* owners, ResponsiveUIFoundation for confirmations and notifications).
- Geometry/visibility: unchanged owners. This sheet changes what they draw, not who draws it.
- Preview/runtime attachment: unchanged.
- Persistence/authoritative mutation: none. No saved or authoritative state is added.

Inputs, outputs and dependencies: reads one new token folder (below) and Core.FeatureFlags for the
  style switch. Needs a small set of uploaded images (glow, ring, gauge arcs, icons).
Entry, transitions, exit and cleanup: unchanged per screen. The style is read when a screen is built;
  switching style takes effect on the next Play start, as theme edits do today.
Client/server authority and remote validation: N/A, client presentation only.
Stable IDs, saved schema/API version and migration impact: none.
Expected scale and bounded performance budget: no new frame loops. Glow is static images, never
  per-frame effects. Instance count per screen within 10% of today.
Mobile, touch, controller and accessibility coverage: see "Responsive and input".
Streaming/open-world behaviour: N/A, PlayerGui only. The event card and start banner use existing
  race-start proximity data.
Failure, cancellation, retry and observability: if the token folder or a token is missing, each owner
  falls back to its current look and warns once.

Shared components/contracts to reuse: ResponsiveUIFoundation (corners, strokes, money, confirmation,
  notifications), RacingUIComponents, GarageComponents, the shared vehicle card
  (GarageReplacementComponents.VehicleCard contract), Config.UI layout folders.
Implementation/installer and rollback approach: scripts/studio_delivery.py, one delivery per build
  step below, each AUDIT / APPLY / ROLLBACK. The style switch is the first rollback: turn it off.

Verification matrix:
- Static/install: token folder present; every owner reads it; switch off reproduces today's captures.
- Runtime transitions and cleanup: each screen opened, used and closed in Play with the switch on and
  off; no new errors; rerender counts unchanged.
- Multi-client/security: N/A.
- Save/rejoin/migration: N/A.
- Device/performance/streaming: 1280x720, 1920x1080, 3440x1440; phone landscape; controller.

Readiness scorecard exceptions or deferred risks: font choice, three colour exceptions and controller
  hints are open (see "Open questions"). Race entry, in-race HUD, results, full map, car panel and
  mobile layouts were not captured live before this sheet was written.
Done when: Oscar has confirmed each screen in Play with the switch on, and the old style is removed
  only on his say.
```

## Style rules

### Colour

Five roles. A colour is never used outside its role.

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

Changes to earlier approved rules, for Oscar to confirm:

- Cash moves from electric blue to yellow (free-roam and racing design systems).
- Selection moves from a cyan outline to a white fill (both design systems).
- Structural pink outlines are removed. Pink becomes an accent line only.
- Tier badges E to S become white with dark letters. The Phase AO tier palette leaves the UI (see Open questions for a lighter alternative).
- Dealership price text was green when affordable and red when not (shared vehicle card V1.2). Proposed: yellow chip when affordable, `TextMuted` on the same dark chip when not.

### Typography

One typeface for the whole UI. Headings, numbers, buttons and tile names are heavy italic capitals. Small labels are the same face at semi-bold italic. The wide tech face (Michroma) is dropped.

A read-only probe in v3 on 2026-10-08 showed which families Roblox ships:

| Family | Shipped | Real italic | Note |
|---|---|---|---|
| Barlow Condensed (used in mockups) | No | - | Would need a Creator Store font asset, if one exists |
| Kanit | No | - | Same |
| **Titillium Web** | Yes | Yes | Recommended. Narrow, slightly squared, reads as technical |
| Roboto Condensed | Yes | Yes | Fallback. About 20% wider than Titillium at the same size |
| Oswald | Yes | No | Narrowest, but no italic |

Recommended: **Titillium Web**, Bold Italic for display and SemiBold Italic for labels. Expect text about 10 to 15% wider than the mockups; sizes below allow for it.

Reference sizes at 1920x1080. Scale through the existing responsive rules; never use `TextScaled` on dense panels.

| Role | Size | Weight | Use |
|---|---:|---|---|
| `ScreenTitle` | 80 | Bold Italic | CUSTOMISE, RACES, track name |
| `SectionHead` | 54 | Bold Italic | PARTS 7/7, WING 3/9 |
| `HeroNumber` | 200 | ExtraBold Italic | Results cash and XP |
| `SpeedNumber` | 136 | ExtraBold Italic | Speed gauge |
| `ButtonMain` | 44 | Bold Italic | Main action, Buy |
| `Button` | 38 | Bold Italic | Other buttons |
| `TileName` | 38 (30 on a rail of seven) | Bold Italic | Tile and event names |
| `Status` | 34 | Bold Italic | Tier, rank, cash readouts |
| `Tab` | 28 | Bold Italic | Tabs |
| `Value` | 26 | Bold Italic | Stat numbers, facts, medal times |
| `Label` | 21 | SemiBold Italic | Small labels, tile sub-lines |

All capitals except supporting sentences, which stay sentence case at `Label` size. Numbers that change every frame use fixed-width layout so they do not jitter.

### Shape, line and glow

- **Corners:** square. Set the foundation's corner scale to 0 for this style.
- **Outlines:** none. Do not use `UIStroke` for structure. Bevels are off.
- **Hairlines:** a panel has a 2 px `White` line on its top edge at 0.85 opacity and a 2 px line on its bottom edge at 0.22 opacity. These are thin frames, not strokes.
- **Texture:** none. No stripes, dots or scanlines on panels or tiles.
- **Title mark:** one small slanted block of pink diagonal stripes to the left of each screen title. This is the only striped element.
- **Glow:** three places only, each a static 9-slice image behind the element:
  - selected tile or selected list row: `Pink`, about 46 px soft radius, 0.55 opacity;
  - main button: `Pink`, about 42 px, 0.6 opacity;
  - speed gauge arcs and the minimap ring: `Cyan` and `Pink`, about 10 px, 0.45 opacity.
- **Shadow:** titles and section heads over the 3D scene carry a soft dark drop shadow for legibility. No coloured offset shadows.

### Scene treatment

- **In play (HUD):** nothing dims the scene. A soft dark gradient may sit behind the top and bottom 20% to hold text contrast.
- **Garage screens:** a dark gradient on the left 38% and bottom 40%, so the car stays bright.
- **Full menus (race menu, race entry, modals):** whole-screen tint from `8, 6, 24` at 0.94 to `34, 14, 72` at 0.85, with a faint pink corner. Optional whole-screen blur behind it. Roblox cannot blur behind one panel only.

## Components

Each component is built once and reused. Copying coordinates between screens is not reuse.

| Component | Spec | States |
|---|---|---|
| **Panel** | `Slate` 0.86, hairlines, square, padding 22 px | - |
| **Screen title** | Title mark + `ScreenTitle`, top-left at the screen margin (100 px) | - |
| **Tabs** | Row under the title, `Tab` size, icon + label, 34 px gap | Active: `White` with 4 px `Pink` underline. Inactive: `TextMuted`. Locked: 0.45 opacity |
| **Status cluster** | Top-right. One slate strip: car icon + tier badge + rating, rank ring, cash chip. Garage screens show garage spaces in place of the car rating | - |
| **Cash chip** | `Yellow` fill, `Ink` text, coin icon. Same position on every screen. Uses the shared money formatter | Counts up on change (existing CashCount attributes) |
| **Tile** | 315 x 242 px, `Slate`, 2 px bottom line at 0.22. Name bottom-left, `Label` sub-line above it, index or variant chip top-left, status chip top-right, silhouette or card image centred | Selected: `White` fill, `Ink` text, 6 px `Pink` base line, pink glow, 10% larger. Owned/fitted: neutral chip (white 0.16 fill). Locked: 0.6 opacity, lock icon, reason in the sub-line. Focus (controller) = selected |
| **Price chip** | `Ink` fill, `Yellow` text, top-right corner of a tile | Unaffordable: `TextMuted` text |
| **Tile rail** | One horizontal row at the bottom, 10 px gap, section head above it with a count ("WING 3/9"). Scrolls horizontally; clipped at the right edge to show there is more | - |
| **Button** | `Slate` strip with hairlines, icon + label, about 72 px tall | Hover/focus: `White` fill, `Ink` text. Disabled: 0.4 opacity, no hairline. Pressed: 96% scale |
| **Main button** | `Pink` to `Violet` gradient, white text, pink glow, trailing chevrons. One per screen, right-most | Same hover/disabled rules |
| **Buy button** | `Yellow` fill, `Ink` text, price in the label. Used only where the action spends Cash | Unaffordable: disabled style, label unchanged |
| **Destructive button** | `Danger` fill, white text | - |
| **Button row** | Bottom-right at the screen margin; centred on results and in the free-roam HUD. Order: back or exit, secondary, main. No key caps | - |
| **Stat panel** | 480 px wide panel, top-right under the status cluster. Car name + tier badge, one or two sub-lines, six rows: label, segmented bar, value | Preview: gained part of the bar in `Cyan`, a `Cyan` chip with the gain. A loss uses a `Pink` chip |
| **Segmented bar** | Segments 10 px wide, 3 px gap, 10 px tall. Filled `White`, empty white at 0.2 | - |
| **Tier badge** | `White` fill, `Ink` letter | On a selected tile: `Ink` fill, `White` letter |
| **Fact list** | Rows of icon + label left, value right, hairline between rows. Prize row ends in a yellow chip | - |
| **Event list row** | Route thumbnail left, small label, name, modes | Selected as Tile |
| **Icon** | Single colour, drawn at 24 px grid, inherits text colour | - |

### Icons

Icons replace text on the action bar and sit before the label on every button and tab. Reuse the existing uploaded icons where they exist (`Config.UI.DesktopFreeRoamHud.Assets`, `Config.UI.GarageReplacement.NavigationIcons`); the mockup icons are stand-ins.

| Use | Icon |
|---|---|
| Action bar | car, garage, race flag, dealership/tools, settings |
| Buttons | exit (door), back (return arrow), drive (wheel), teleport (pin), set route, records (trophy), choose vehicle (car), equip/apply (tick), race again (loop), controls (gamepad) |
| Tabs | parts (wrench), upgrades (arrow), paint (brush) |
| Facts | route, laps, checkpoints, players |
| State | lock, coin |

## Screens

Positions are at 1920x1080. Screen margin is 100 px for menus and 58 px for the in-play HUD.

### Free-roam HUD

- **Top-right:** status cluster, then the action bar: five 77 x 60 px icon tiles. The open one is white.
- **Bottom-left:** round minimap, 307 px, with a 5 px ring (pink to cyan gradient) and a soft glow. North marker on the rim. District name beneath. Driver rank and its progress line to the right of the map.
- **Bottom-right:** one speed gauge, 403 px. Outer arc is speed (white, turning pink in the last fifth), inner arc is boost (cyan). Speed number and unit inside, boost percentage beneath.
- **Bottom-centre:** two small buttons, Controls and Exit vehicle (driving only).
- **At a race start:** event card top-left (name, type and laps, route, YOU against ENTRY in a diagonal split, prize in a yellow corner) and a Start banner over the start zone. The banner carries the single interact key cap.
- The car panel, settings, controls and cash-store modals use Panel, Tile and Button as above. The car panel keeps its rules: Buy more first, no prices, Despawn fixed.

### Race menu and race entry

- **Race menu:** full-screen tint. Title RACES with filter tabs. Event list on the left (480 px wide). Detail on the right: event art with the name over it and a pink rule beneath, then the route map and the fact list side by side. Buttons: Exit, Set route, Teleport (main).
- **Race entry:** keeps the approved racing layout (tabs, tier rail, map left, prize and times right). Title is the track name. The viewed tier is a white tile; completed tiers carry a white underline; locked tiers are dimmed. Prize in a yellow chip beside the tier letter. Medal rows: the one you hold is white with a pink "yours". Buttons: Exit, View records, Choose vehicle (main).

### In-race HUD and results

- **In-race:** position top-left as the largest element, lap beneath. Timer top-centre with a pink underline and a cyan delta chip; checkpoint pips under it. Live order top-right, four rows around the player; the player's row is white. Minimap and gauge as in free roam.
- **Results:** title RACE COMPLETE in white, event line beneath. Two hero numbers side by side: cash banked in `Yellow`, driver XP in `Pink`, each with a small white label above. One strip beneath: finish, time, best lap. Buttons centred: Race again, Continue (main). All figures come from the server result payload.

### Dealership, customisation and paint

- **Shared frame:** title top-left with tabs, status cluster top-right, stat panel beneath it, tile rail along the bottom, button row bottom-right.
- **Dealership:** tabs are the categories. Rail of cars with tier badge, rating, name and price chip. Buttons: Exit, Buy (yellow).
- **Customise:** Add Modules, Upgrade Modules and Paint Shop become three tabs (Parts, Upgrades, Paint), removing the hub screen. Parts shows one rail of the car's slots, each naming the fitted part. Buttons: Back, Drive (main).
- **Module shop:** Owned Modules and Buy Modules become a Shop / Owned switch beside the section head. Tiles carry a variant chip (STD, GT, EVO) and a price or Fitted chip. The stat panel names the fitted and previewed part and shows gains. Buttons: Back, Drive, Equip or Buy.
- **Paint:** a panel on the left with the channel switch (Primary, Second, Detail, Neon; active is white), three sliders with their values, and the swatch grid. Paint areas are the bottom rail. Buttons: Back, Drive, Apply (main).

Removing the hub screen and merging Owned/Buy change navigation, not only appearance. They need their own acceptance step inside the garage build.

## Responsive and input

- **Desktop:** build anchored clusters, not one scaled canvas. Verify at 1280x720, 1920x1080 and 3440x1440. Corner clusters stay on the screen edges on ultrawide.
- **Phone landscape:** same clusters, larger relative text. `Label` never below 11 px after scaling; buttons and tiles never below 48 px on their short side. The tile rail shows fewer tiles and scrolls. The stat panel collapses to name, tier and the changed stats. The button row stays bottom-right above the safe area.
- **Controller:** focus uses the selected state (white fill). Bumpers switch tabs; triggers switch Shop / Owned. Confirm and cancel keep the foundation's behaviour.
- **Key hints:** none on buttons or tabs. The only key cap is on the world Start/interact banner.
- **Accessibility:** text is white on near-opaque slate, or ink on white or yellow, so it holds over bright scenes (contrast not yet measured in Studio). Colour is never the only signal: selected is also larger, locked also has an icon, gains also have an arrow.

## Config

One new folder, read by every UI owner:

```text
ReplicatedStorage.Config.UI.Style
  Colours     (Color3Value: Slate, White, Ink, Pink, Violet, Cyan, Yellow, TextSecondary, TextMuted, Danger)
  Typography  (StringValue FontFamily; NumberValue per role in the table above)
  Shape       (NumberValue: PanelOpacity, HairlineTop, HairlineBottom, HairlinePixels, CornerScale,
               TileSelectedScale, ScreenMargin, HudMargin)
  Glow        (StringValue image ids; NumberValue opacity per glow)
  Icons       (StringValue image ids by icon name)
```

The switch is one Core.FeatureFlags flag, default off (current style). The existing colour folders (`DesktopFreeRoamHud.Colours`, `Racing.Colours`, `GarageExperience`) and `Config.UI.Theme` stay in place while the old style exists and are removed with it. Layout folders (`GarageReplacement` attributes, `DesktopFreeRoamHud.Layout`, `Racing.Layout`) keep their role; new layout values are added beside them, not in the Style folder.

## Assets to upload

About a dozen small images, all needing Oscar's approval before upload:

- glow 9-slices: tile, button, soft edge;
- minimap ring (gradient) and its mask;
- speed gauge arcs, if the current segment images cannot be reused;
- title mark;
- any icons not already uploaded.

## Build order

Each step is its own delivery behind the switch, verified in Play with the switch on and off.

1. Remaining captures (in-race HUD, results, race entry, full map, car panel, mobile), then lock this sheet.
2. Style folder, the switch, and the shared components in ResponsiveUIFoundation, RacingUIComponents and GarageComponents.
3. Free-roam HUD. Client only and seen every session: the first real test of the look.
4. In-race HUD and results.
5. Race menu and race entry.
6. Dealership, customise, module shop, paint. The largest step: most fixed colours and the navigation changes.
7. Car panel, modals, settings, owned garage, full map; then the phone and controller pass.
8. Switch the default on Oscar's confirmation. Remove the old style only when he says.

## Open questions

1. **Typeface.** Titillium Web ships with Roblox and has a real italic. The mockups use Barlow Condensed, which does not ship. Use Titillium Web, or look for Barlow Condensed as a Creator Store font?
2. **Tier and affordability colour.** Tier badges are white and unaffordable prices are muted, which removes six tier colours plus green and red. Keep it that way, or bring tier colour back as a thin line under the letter?
3. **Controller hints.** No key caps appear on buttons or tabs. Should bumper and trigger hints appear when a gamepad is the active input, or stay hidden there too?
