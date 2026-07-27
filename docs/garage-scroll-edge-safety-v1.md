# Garage Scroll Edge Safety V1

**Status:** Confirmed/mirrored 2026-07-27  
**Lane:** Standard connected presentation change  
**Canonical installer:** `scripts/roblox_garage_scroll_edge_safety_v1.lua`

## Acceptance contract

Goal: keep the complete first/last/bottom card border and glow visible and reachable in Dealership, Customisation and Owned Garage without adding another menu, scroll or orientation owner.

Required:

- Phones and tablets use Roblox's native global `StarterGui.ScreenOrientation=LandscapeSensor`.
- The two legacy VFX/preview runtime orientation writers are retired; no orientation polling remains.
- Dealership and top-level Customisation carousels reserve enough physical edge clearance for shared card strokes at their current scale.
- Garage workspace carousels measure actual mixed card widths. Vehicle cards are `226` logical pixels while ordinary workspace cards are `210`; the canvas must not assume they are all `210`.
- Owned Garage reserves scale-aware left/top/right/bottom clearance, including its scrollbar and final-card glow.
- Small-window PC retains the same physical clearance; normal desktop composition is otherwise unchanged.

Preserved: card renderer and semantics, catalogue/order/filter state, selection, previews, action popups, navigation, Cash/capacity, purchases, owned-garage actions, remotes, persistence, audio, VFX appearance and driving.

Explicit exclusions: portrait layouts, a runtime orientation controller, new scrolling frames, paging/virtualisation, server changes and unrelated UI.

Done when landscape phone/tablet and PC can reach the last horizontal or vertical card with its complete border/glow visible, no runtime orientation writer remains, and the complete mirror contains all six revision markers plus the native orientation property.

## Root cause and ownership

`GarageWorkspaceController` renders `CardKind="Vehicle"` at `CardWidth` (`226` fallback) but previously sized its canvas as `count * WorkspaceCardWidth` (`210` fallback). This undercounted every vehicle row by `16` logical pixels per card.

The shared horizontal carousels used a fixed `6` logical-pixel end gutter. Owned Garage used a fixed `4` logical-pixel inset with no explicit bottom padding. Under `UIScale`, those gutters can become smaller than the device-pixel `Glow` stroke (`2 px` touch, `3 px` desktop), so clipping depends on viewport and scale.

Canonical ownership remains:

- shared physical/logical edge conversion and measured horizontal canvas: `GarageReplacementComponents`;
- Dealership/Customisation carousel lifecycle: `GarageBrowserController`;
- workshop/mixed-card carousel lifecycle: `GarageWorkspaceController`;
- Owned Garage vertical list lifecycle: `OwnedGarageBrowserController`;
- orientation: native `StarterGui.ScreenOrientation`, not VFX or preview code.

The helper runs only after existing render/layout events and loops over the small visible card row. It adds no frame loop, remote, saved field or new UI owner.

## Studio install

1. Stop Play.
2. Run the complete contents of `scripts/roblox_garage_scroll_edge_safety_v1.lua` in the Edit-mode Command Bar.
3. Expect:

   `INSTALL PASS | restart Play; verify landscape phone/tablet and PC end-card borders, then refresh the complete Studio mirror.`

The installer preflights unique source anchors, projects and compiles all six sources, snapshots every changed source plus the prior orientation property, audits the committed result and rolls the complete mutation set back on failure. It creates no backup objects.

## Verification

### Orientation

1. Start on an iPhone/Android phone emulator and a tablet/iPad emulator.
2. Confirm the experience stays landscape and can rotate between the two landscape sensor directions.
3. Confirm no portrait UI branch or portrait-only menu appears.

### Dealership and Customisation

1. Test a landscape phone and tablet with enough vehicles to overflow.
2. Drag and use the arrows to reach the final vehicle/category/workshop card.
3. Confirm the rightmost card's structural/selected/focused border and glow are complete.
4. Test a mixed workspace vehicle row and confirm the final `226`-wide card is fully reachable.
5. Repeat after selecting a card, opening/closing its popup and changing category.

### Owned Garage

1. Test enough owned garage properties to overflow vertically.
2. Scroll to the final property.
3. Confirm its left/right/bottom border and glow remain fully visible and do not sit under the scrollbar.
4. Repeat with the final card selected.

### PC and regression

1. Repeat all three menus at normal desktop and a small resizable window.
2. Confirm short rows remain centred, arrows appear/disappear correctly and saved scroll positions remain clamped.
3. Confirm purchases, previews, Customisation actions, Enter/Exit Garage and card ordering are unchanged.
4. Check Output for compile/runtime errors.

## Risks and rollback

- Installation uses exact fragile source anchors. An anchor failure performs no mutation; refresh/inspect rather than weakening the guards.
- `AbsoluteSize` is sampled after the controllers' existing deferred Heartbeat layout step. A zero-size fallback still uses the card's declared logical width.
- Restore the pre-install Studio version/history point for rollback after a successful installation. The installer automatically restores all six sources and the prior orientation value if its committed audit fails.

## Mirror handoff

After confirmation, run the standard receiver/full-export workflow and commit generated changes under both mirror areas. Do not commit `docs/studio-full-export-paste.txt`.
