# Racing UI Phase 1 - Shared Shell And Race Browser

**Created:** 2026-07-11  
**Status:** Phase 1 V9 reviewed in Studio; canonical V10 detail/prize polish generated

## Studio Script

```text
scripts/roblox_racing_ui_phase1_shared_shell_browser.lua
```

Run in Edit mode with `MODE = "INSTALL"`.

Rerun the same canonical installer for V2. V2 removes the redundant event-list
shell/header and detail availability chips, enlarges full-width event cards,
uses unboxed availability text plus route/lap/checkpoint summaries, adds a clear
cyan selected-card state, changes the footer action to `TELEPORT`, and aligns
button gradients/fills with the Phase 4A family.

V3 follows the confirmed free-roam car-card fix: event cards now live inside a
physically inset `CardContent` frame so selected strokes cannot be clipped by
the scrolling boundary. The Phase 4A button pattern is also copied accurately:
the neutral gradient sits on a background-only child layer, while button text
and paired border/glow strokes remain above it. This repairs the faint/behind
footer appearance without changing button actions.

V4 sets shared strokes to Roblox `Border` mode so pink/cyan strokes no longer
outline button text. It also grows the desktop content region by `16 px` and
moves the footer buttons up `8 px`, leaving a consistent approximately `16 px`
content-to-footer gap and bottom margin. This matches the Phase 4A settings
footer more closely.

V5 removes the duplicate centred header copy, renames the top-left title to
`RACE BROWSER`, sets the header divider to `50%` transparency, and adds the
shared neutral gradient to event-card backgrounds. The gradient overlay is
created before the thumbnail, labels, and click layer so it cannot cover or
fade card imagery/text.

V6 adds the transparent 4x3 racing icon atlas to Event Details, with circuit or
point-to-point, laps, checkpoints, players, and prize icons mapped to their
matching rows. The heading now matches event-card title typography; fact rows
are brighter, bold, consistently inset, and vertically centred against icons.
It also creates empty `TrackImage` and `MapImage` attributes on every Race and
Time Trial catalog event. The Race Catalog media takes visual precedence in
the free-roam browser, with Time Trial/route media retained as fallback.

Upload `assets/ui/icons/racing/racing-ui-icon-atlas.png` to Roblox, then set its
asset ID in `Config.UI.Racing.Assets.RacingIconAtlas`. The source atlas is
`1024 x 1024` with a 4x4 grid of exact `256 x 256` cells. The first three rows
contain the twelve icons and the fourth row is reserved/transparent. Leave
`RacingIconCellSize` at `256`.

V7 also rounds and slightly insets media images so they cannot cover their
frame borders, adds a low-opacity matching-colour glow to Racing panels, adds
the approved neutral gradient to Event Details, grows the hero image, and
shortens the lower map/details row. Event Details and its fact rows now share
the event-card title size. Opening the browser records and disables other
PlayerGui ScreenGuis; closing, exiting, or teleporting restores each GUI to its
exact previous Enabled state. Roblox CoreGui is deliberately left unchanged.

V8 increases Event Details icons from `22 px` to `33 px` on desktop and from
`16 px` to `24 px` on touch. Each icon and label now sits in a shared fixed-
height row and is centred against the same vertical midpoint. The Event Details
heading is increased to `16 px` desktop / `12 px` touch. Background suppression
now remains enforced while the browser is open, including ScreenGuis recreated
or re-enabled by another controller, while preserving their original states for
restoration on close/exit/teleport.

V9 measures and compensates for the uneven transparent padding inside each
atlas cell. Circuit, point-to-point, laps, checkpoint, players, and prize icons
now carry individual X and Y optical offsets measured at the `33 px` desktop
reference size. Offsets scale proportionally for the `24 px` touch icons and
then inherit the shell UIScale, keeping alignment stable across viewports. Event
card availability and route-summary lines are increased to `14 px` desktop /
`10 px` touch. Each browser opening now explicitly selects the first sorted
event row, fixing the stale-table-reference case and guaranteeing its cyan
fill, border, and glow appear immediately.

V10 moves the five Event Details fact rows down by `8 px` desktop / `6 px`
touch while leaving the heading fixed. The final row is now split into a white
`PRIZE` label and a cyan formatted amount, with a restrained contextual text
stroke providing the requested small outer glow without affecting the icon or
panel border.

## Scope

This condensed first visible phase:

- creates editable `Config.UI.Racing` semantic colours, layout, typography,
  and empty asset slots;
- installs reusable `Shared.Modules.UI.RacingUIComponents`;
- canonically replaces only isolated `RaceBrowserClient_Active`;
- combines Time Trial/Race catalogs into simplified route event cards;
- uses the approved shared shell and simplified event-row hierarchy;
- preserves server-authoritative teleport, fade, vehicle-exit handoff, and the
  existing free-roam `OpenRaceBrowser` bridge.

It does not patch `RaceEntryMenuClient_Active`, the bootstrap, rewards, PB
ownership, matchmaking, reset, route-guide logic, result cleanup, or driving.

## Verification

1. Run the installer in Edit mode and confirm its smoke passes.
2. Start Play and open `RACE` from the Phase 4A free-roam HUD.
3. Confirm the browser matches the approved shell and fits the viewport.
4. Switch/select available event cards and confirm details update.
5. Confirm event rows show the configured map thumbnail, name, availability,
   and route summary.
6. Confirm every Event Details icon matches its row and remains vertically
   centred at desktop and touch-emulator sizes.
7. Confirm image/map corners remain inside their rounded borders and every
   panel glow matches its pink or selected-cyan border.
8. Set `TrackImage` and `MapImage` on a `Config.Racing.RaceCatalog` event and
   confirm the hero image, large map, and event thumbnail update.
9. Confirm track image/map empty slots remain clean when no asset is configured.
10. Confirm other PlayerGui interfaces disappear while the browser is open and
   return to their previous state after Exit, close, and Teleport.
11. Press `TELEPORT`; confirm fade, vehicle cleanup, teleport, browser
   close, camera recovery, and entry-zone interaction still work.
12. Test at `1920x1080`, `1366x768`, and a landscape touch emulator.

If placement or clipping is wrong, capture a screenshot and viewport size before
another patch. Do not patch entry/lifecycle services to fix browser layout.
