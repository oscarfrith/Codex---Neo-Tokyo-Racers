# PC Free-Roam UI Design System

**Created:** 2026-07-10  
**Status:** User-approved visual baseline; Phase 2C installed/reviewed, Phase 2D component polish generated and awaiting Studio verification
**Scope:** PC free-roam HUD, car menu, shared modals, cash store, and settings

## Approved Concept Images

The approved concepts are stored under:

```text
assets/ui/mockups/free_roam_pc/
```

- `pc-free-roam-hud.png`
- `pc-car-menu.png`
- `pc-dealership-teleport-modal.png`
- `pc-controls-modal.png`
- `pc-cash-store-modal.png`
- `pc-settings-modal.png`

These images are the visual target for implementation, not flattened runtime UI assets. Build the live interface from Roblox UI objects so layout, colours, text, scaling, and states remain editable. Use image assets only where they materially improve the result, such as the minimap, minimap feather overlay, icons, and curved speed-gauge segments.

## Design Language

The free-roam family extends the existing dealership/customisation language:

- compact futuristic proportions;
- dark translucent charcoal glass;
- thin hot-pink structural outlines;
- cyan/electric-blue selected states and live telemetry;
- white primary text and cool-grey secondary text;
- restrained glow rather than broad bloom;
- subtle diagonal facet overlays inside large panels;
- small corner radii and shallow bevel/depth layers;
- image-led vehicle cards with compact tier/rating badges.

Avoid introducing page-specific accent colours without a semantic reason. Every future UI family should begin from these tokens and override only values that genuinely represent a different state.

## Authoritative Colour Tokens

The implementation should create editable `Color3Value`s under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme
```

HUD-specific fallbacks/overrides may live under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud.Colours
```

| Token | RGB | Hex | Use |
|---|---:|---|---|
| `PanelDeep` | `9, 12, 16` | `#090C10` | Main modal and menu surfaces |
| `Panel` | `15, 19, 24` | `#0F1318` | Standard cards and controls |
| `PanelSoft` | `24, 29, 36` | `#181D24` | Hover layers and secondary surfaces |
| `PanelBlue` | `8, 42, 84` | `#082A54` | Cash chip and blue-positive surfaces |
| `Outline` | `244, 46, 151` | `#F42E97` | Structural borders and navigation identity |
| `OutlineSoft` | `214, 74, 175` | `#D64AAF` | Secondary borders and inactive highlights |
| `Telemetry` | `43, 225, 218` | `#2BE1DA` | Speed, boost, selected card, active controls |
| `ElectricBlue` | `25, 116, 255` | `#1974FF` | Cash, purchase focus, strong positive action |
| `HighSpeed` | `246, 83, 159` | `#F6539F` | High end of the speed gauge only |
| `Danger` | `196, 57, 75` | `#C4394B` | Despawn and destructive confirmation |
| `Text` | `246, 248, 252` | `#F6F8FC` | Primary text and icons |
| `Muted` | `163, 171, 184` | `#A3ABB8` | Secondary labels and faint footer actions |
| `Disabled` | `81, 88, 99` | `#515863` | Disabled controls and unavailable actions |

### Semantic Colour Rules

- **Pink:** structure, brand identity, inactive outlines, navigation borders.
- **Cyan:** current selection, live state, speed/boost telemetry, keyboard keycaps.
- **Electric blue:** cash, purchase focus, and strong positive confirmation.
- **Red:** destructive actions only, including `DESPAWN`.
- **White/grey:** information hierarchy; do not colour ordinary body copy.
- Do not use tier colours for selection. A selected vehicle keeps its tier badge and gains a separate cyan selection highlight.

## Vehicle Tier Colours

Keep the confirmed existing Phase AO palette exactly:

| Tier | RGB | Hex |
|---|---:|---|
| `E` | `132, 142, 145` | `#848E91` |
| `D` | `105, 190, 129` | `#69BE81` |
| `C` | `74, 204, 211` | `#4ACCD3` |
| `B` | `82, 137, 235` | `#5289EB` |
| `A` | `244, 188, 65` | `#F4BC41` |
| `S` | `236, 92, 168` | `#EC5CA8` |

Tier badges are informational. They must not recolour whole vehicle cards or replace the global pink/cyan interaction language.

## Typography

- Use the existing futuristic/Michroma-style font for headings, buttons, badges, and telemetry where readable.
- Use a simpler consistent fallback such as Gotham for small supporting text when the futuristic font becomes cramped.
- Use uppercase for headings, labels, and primary actions.
- Keep supporting sentences in sentence case.
- Avoid `TextScaled` for dense PC panels; use explicit sizes plus responsive scale rules and `UITextSizeConstraint` where needed.
- Numerical HUD text should remain stable in width and should not resize every frame.
- Configure weight and style by semantic role rather than by individual label. Current roles are Heading, Button, Body, Caption, Metric, MetricUnit, and CashMetric.
- The selected font family controls whether bold and italic variants visibly exist; Michroma may not render every requested combination.

## Component Rules

### Panels

- Main panels use `PanelDeep` with controlled transparency.
- Standard borders use `Outline`, normally `1-2 px` after scaling.
- Large panels may contain a low-opacity diagonal facet overlay.
- Modal backdrops dim the game but keep the world recognisable.

### Buttons

- Default/inactive: charcoal surface plus pink outline.
- Hover/focus: slightly lighter surface and brighter pink outline.
- Selected/positive: cyan or electric-blue inner fill/glow while retaining the pink family outline where practical.
- Destructive: `Danger` fill with restrained pink/red depth.
- Disabled: greyed surface, no glow, and visibly reduced contrast.
- All button families may use the same subtle neutral grey overlay gradient. The gradient must preserve the semantic base fill colour rather than replacing it.
- When a state changes a border to cyan/blue, the associated outer glow must change to the same colour.

### Vehicle Cards

- Two columns in the approved PC car panel.
- Image-led composition with the name below the vehicle image.
- Tier/rating badge overlays the image at top-right.
- No sell buttons, favourite stars, price labels, or ownership counts in the free-roam car menu.
- `BUY MORE` is always the first grid card.
- The selected vehicle uses a cyan inner highlight, not a tier-coloured outline.

### Dropdowns

- Category and sort controls share identical height and width.
- The label is small and muted; the active value is larger and white.
- The dropdown list uses the same panel/card tokens rather than a Roblox-default visual.
- Dropdown list shells use a neutral grey surface without a pink outer border/glow. Clicking the already-open dropdown header closes it.

### Modals

- Use one shared modal shell for teleport confirmation, controls, cash, and settings.
- Only one modal may own input focus at a time.
- Background HUD remains visible but dimmed and inactive.
- Positive action is on the right; cancel/back is on the left.

## Approved Screen Behaviour

### Free-Roam HUD

- Bottom-left: blue cash chip above the minimap.
- Bottom-centre: faint `CONTROLS` and driving-only `EXIT VEHICLE`.
- Bottom-right: speed, boost, and curved speed-progress gauge while driving.
- Top-right: car, garage, race, dealership/customisation, settings.

### Car Menu

- Opens on the left and hides the minimap/cash cluster to prevent overlap.
- Keeps the top-right action row visible with the car action selected.
- Category filter defaults to all categories.
- Sort defaults to rating descending.
- `BUY MORE` opens the same dealership teleport modal as the top-right dealership action.
- Vehicle grid scrolls independently; `DESPAWN` remains fixed.
- Clicking an owned vehicle card is intended to spawn/swap through the existing server-validated action.

### Controls

Confirmed PC values:

- Driving: `W` accelerate, `S` brake/reverse, `A/D` steer, `SHIFT` drift, `SPACE` boost, `R` reset vehicle.
- On foot: `WASD` move, `SHIFT` sprint, `SPACE` jump, `E` interact/enter vehicle, mouse camera.

### Settings

Approved visual options:

- Graphics: `Potato`, `Low`, `Medium`, `High`, `Ultra`.
- Lighting: `Off`, `Low`, `High`.
- Camera shake.
- Reduce flashes.
- Music and SFX volume.
- UI scale and HUD opacity.
- Minimap rotation mode.
- MPH/KPH speed units.

Settings should save automatically once the persistence design is implemented. Do not imply persistence before it exists.

### Cash Store

The approved concept contains example pack values only. Product amounts and Robux prices must be economy-reviewed before implementation. Real purchases require a separate server-authoritative, idempotent Developer Product receipt phase.

## Responsive PC Rules

- Build independent anchored clusters rather than scaling one full-screen composition.
- Target `1920x1080`; verify at `1280x720`, `1366x768`, `1600x900`, `2560x1440`, and `3440x1440`.
- Use viewport scaling with editable minimum/maximum clamps.
- Preserve minimum readable text and click targets at the smallest supported PC size.
- Keep corner clusters attached to screen edges on ultrawide displays.
- The new PC controller must remain disabled on touch/mobile so the current mobile controls are not disturbed.

## Architecture Boundary

Install new presentation in isolated controllers/modules. Do not add new top-level local helpers or large UI blocks to `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

The only anticipated bootstrap edit is a tiny guarded telemetry event fired from the existing `UpdateDriveUi` callback. It is a fragile source patch and must have exact preflight markers, idempotency, and a register-limit restart test.

## Next Studio Step

Run the read-only audit:

```text
scripts/roblox_ui_freeroam_pc_phase0_audit.lua
```

Do not generate the installer until the audit output confirms the current live hooks and source markers.
