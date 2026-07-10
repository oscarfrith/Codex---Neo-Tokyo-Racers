# PC Free-Roam UI Phase 2B Canonical Visual Foundation

Date: 2026-07-10  
Status: Installed and runtime-audited; visually improved but superseded by the generated Phase 2C inset/visibility/card-edge repair.

## Studio Script

Run this script in Roblox Studio Edit mode:

```text
scripts/roblox_ui_freeroam_pc_phase2b_canonical_visual_foundation.lua
```

Phase 2B does not use fragile source anchors inside the controller. It accepts only the known Phase 1 or Phase 2B isolated-controller marker, then replaces the complete `DesktopFreeRoamHudController_Active.Source` with the canonical Phase 2B source.

It does not modify `NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`, server actions, driving physics, VFX, racing, mobile UI, or unrelated garage/dealership UI.

## Diagnostic Inputs

Phase 2A produced three valid client reports:

- car drawer open, on foot, viewport `2153.3 x 700`, `pass=29 warn=14 fail=0`;
- normal HUD, on foot, viewport `2153.3 x 700`, `pass=29 warn=14 fail=0`;
- normal driving HUD, viewport `1615.3 x 846`, `pass=30 warn=13 fail=0`.

The second viewport was useful rather than problematic. Both sizes showed the same negative top coordinate, confirming that safe-area/inset ownership needed correction rather than one-resolution retuning.

## What Phase 2B Changes

- changes the new ScreenGui to respect the Roblox GUI inset and keeps the action row inside the visible viewport;
- makes the car action double width and centres its icon through anchor-based placement;
- makes the cash panel exactly the minimap width and strengthens the cash metric;
- replaces the ineffective minimap-parent gradient with four child-safe gradient edge overlays;
- hides the complete bottom-centre action cluster while on foot;
- separates the car drawer header from its scrolling content;
- uses two equal, dynamically calculated card columns with centred `UIGridLayout` alignment;
- increases dropdown, vehicle-name, badge, cash, speed, and MPH hierarchy sizes;
- rebuilds the speed gauge as 16 ordered segments from bottom to top and keeps the rotated bounds inside its larger telemetry frame;
- uses the configured UI font for the teleport description;
- centres the cash secure footer using a `0.5` anchor instead of a fixed horizontal offset;
- adds restrained native gradients, glow strokes, and diagonal facet patterns;
- preserves all confirmed Phase 1 car spawn/swap, despawn, exit, garage, race, modal, and profile calls.

## Editable Configuration

Phase 2B keeps the existing semantic groups under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud
```

Important groups:

- `Colours`: semantic pink, cyan, blue, red, panel, text, muted, and disabled colours;
- `Typography`: `PrimaryFont`, `BodyFont`, `Heading`, `Button`, `Body`, `Caption`, `Metric`, `MetricUnit`, and `CashMetric`;
- `Effects`: panel/button/gradient/glow/pattern transparency and minimap edge strength;
- `Layout`: shared scale clamps, edge offsets, action size/gap, minimap size, car panel geometry, card gap, and speed maximum;
- `Defaults`: current visual-only settings defaults;
- `Assets`: icon and future map image IDs.

These are semantic roles, not per-label overrides. Most future colour or typography changes should require one token edit and a fresh Play session.

Phase 2B removes the obsolete Phase 1 `CashWidth` and `MapFeatherImage` values: cash width is deliberately derived from `MinimapSize`, and the native four-edge treatment replaces the unused single feather asset.

## Required Verification

1. Stop Play and run Phase 2B in Edit mode.
2. Confirm Output reports the canonical Phase 2B controller install and no assertion failures.
3. Start a fresh PC Play test.
4. On foot, confirm there is no bottom-centre `CONTROLS` button.
5. Confirm cash and minimap widths match, cash is readable, and the four map edges darken/fade the map content.
6. Confirm the car action is double width with its icon centred.
7. Open `MY VEHICLES`; confirm dropdowns and cards do not overlap, both columns are centred, card names/badges are readable, and scrolling/despawn remain independent.
8. Test category, rating, price, and A-Z choices.
9. Spawn/swap a vehicle, exit/re-enter it, and despawn it. Existing behavior must remain unchanged.
10. While driving, confirm both bottom-centre actions appear and the speed metric responds.
11. Confirm the speed arc fills from its bottom segment upward and does not clip the right or bottom edge.
12. Open teleport and cash modals; confirm the description font matches and the secure footer is centred.
13. Inspect Controls, Settings, Cash, and Teleport for the new restrained gradient/glow/facet treatment.
14. Verify a short/wide window similar to `2153 x 700` and a normal window similar to `1615 x 846`.
15. Confirm mobile/touch still does not create `NTR_DesktopFreeRoamHud`.

After opening the car drawer once, run the updated read-only diagnostic in both on-foot and driving states:

```text
scripts/roblox_ui_freeroam_pc_phase2a_runtime_layout_diagnostic.lua
```

The target is `fail=0` with no unresolved layout warnings. Copy the complete outputs and screenshots back before treating Phase 2B as confirmed.

## Deferred Functional Work

- calibrated moving/rotating minimap;
- real boost percentage bridge;
- server-authoritative dealership teleport;
- Developer Product receipts;
- settings effects and persistence.

The boost bar remains a clearly known placeholder. Phase 2B changes its presentation only.

## Rollback

Use Roblox version history to restore the pre-Phase-2B place version. The older Phase 1 installer intentionally refuses an unknown/newer Phase 2B marker, so do not rely on rerunning it as a downgrade. Do not create an in-game backup script/folder.

## Mirror Requirement

Phase 2B changes live script source and config/hierarchy. After installation and initial verification, refresh the Studio mirror with the full receiver/exporter workflow before the final handoff.

## Phase 2B Review Result

The post-install audit passed `42`, warned `1`, and failed `0`. Screenshots then confirmed three follow-up defects: the full HUD was shifted down by the Roblox top inset, vehicle-card strokes were clipped by the scrolling frame, and visibility was unreliable at startup/Laptop emulation. Phase 2C supersedes Phase 2B for those issues without changing its successful visual hierarchy or gameplay actions.
