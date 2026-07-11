# Racing UI Design System

**Created:** 2026-07-11  
**Status:** Desktop Gates A/B and responsive Gate C approved  
**Baselines:** PC free-roam Phase 4A and Racing Phase 11Z

## Approved References

Approved presentation boards live under `assets/ui/mockups/racing/`:

- `racing-ui-gate-a-entry-layouts.png`
- `racing-ui-gate-b-results-browser-records.png`
- Gate C defines responsive reflow and shared component states.

These are visual specifications, not flattened runtime assets. Build the live
interface from Roblox UI objects. Track art, maps, medals, avatars, and vehicles
remain configurable image slots.

## Shared Racing Shell

All desktop Racing menus use one `1200 x 720` reference shell with identical
header, outer padding, gutters, borders, corner radii, footer, button heights,
and typography roles. Two-region screens use equal-width columns after the
central gutter. Hierarchy comes from typography and grouping, not unequal
columns.

Time-trial and race overview maps use the exact same bounds. Their bottom edge
aligns with adjacent content and keeps consistent clearance above the footer.

## Semantic Colours

Reuse Phase 4A meanings:

- pink: structure, navigation, inactive borders;
- cyan: selection, active tabs, live timing, local-player rows;
- electric blue: prizes/cash and strong positive actions;
- red: destructive active-session quit only;
- white/cool grey: information hierarchy;
- tier and medal colours: informational badges only.

Racing-specific config belongs under `Config.UI.Racing` and should read the
Phase 4A semantic theme first.

## Screen Contracts

### Time Trial Overview

- Persistent Time Trial/Race tabs and E-S tier rail.
- Highest owned tier selected on open.
- Unowned tiers remain inspectable but locked from starting.
- Equal columns: track map left; prize, PB, and medal targets right.
- Footer: `VIEW RECORDS` and `CHOOSE VEHICLE`.

### Time Trial Records

- Equal columns.
- Left: World Record, medal targets, Your Record.
- Right: Global Top 20.
- Global rankings are a future server-owned contract; support loading, empty,
  unavailable, and error states until installed.

### Vehicle Selection

- Free-roam image-led vehicle-card language.
- Two desktop columns with responsive reduction and scrolling.
- Cyan selected state; no price, sell, favourite, or ownership-count controls.

### Race Overview

- Exact Time Trial Overview map bounds.
- Race format and placement rewards on the right.
- Existing open-category matchmaking remains authoritative.

### Results

Race and time-trial results share identical equal-column geometry.

- Race left: Your Result and Race Highlights; right: Race Results.
- Time trial left: Your Result and Session Laps; right: tier Global Top 20.
- Consume server result payloads; do not calculate prizes or PBs locally.
- Preserve confirmed retry, exit, and pending-cleanup actions.

### Free-Roam Race Browser

- Event rows show only thumbnail, track name, availability chips, and one PB.
- Route type, laps, checkpoints, player limits, and other metadata live only in
  the selected-event detail panel.
- Existing server-authoritative teleport remains the behavior owner.

## Responsive Rules

- Reflow instead of unlimited uniform shrinking.
- Landscape mobile uses a compact fixed header, scrollable tier rail, one main
  scroll region, and sticky footer.
- Records/Results use `SUMMARY`/`GLOBAL` or `RESULT`/`GLOBAL` sub-pages.
- Drop low-priority table columns before reducing readable text.
- Avoid nested vertical scrolling.
- Keep logical mobile touch targets approximately `44-48 px` minimum.

## Component States

Cover primary default/focus/pressed/disabled, secondary default/focus,
destructive quit, owned/selected/locked tier, default/selected/locked vehicle,
default/local/top-three leaderboard rows, loading/empty/unavailable/error data,
and transparent medal/track-image slots.

## Locked Ownership Boundaries

Do not change these for presentation:

- Phase 8H respawn-on-reset;
- Phase 11Y frozen/pending time-trial finish cleanup;
- reward calculation, cash grant, and run-id idempotency;
- PB recording, persistence, and lookup;
- matchmaking, placement, and queue state;
- route guide and Phase 11L V2 arrow proxy sync;
- transition fade/camera restoration;
- register-limited bootstrap.

World records, Global Top 20, fastest lap, and highest-speed awards require
separate server-authoritative contracts. Do not fabricate them in UI.

## Condensed Implementation Plan

1. Read-only Phase 0 live audit.
2. Shared semantic config/components plus Race Browser and static entry shell,
   only if owners are clean.
3. Entry data integration plus tier vehicle selection.
4. Shared in-race presentation while retaining reset/transition/route owners.
5. Shared time-trial/multiplayer result shell retaining retry/exit cleanup.
6. Separate competitive leaderboard and race-stat server contracts.
7. Responsive/lifecycle release audit.

