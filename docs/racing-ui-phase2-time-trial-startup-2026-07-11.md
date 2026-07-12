# Racing UI Phase 2 - Time Trial Startup

**Created:** 2026-07-11  
**Status:** Generated; awaiting Studio install and visual confirmation

Installer V2 replaces the original pattern-based bridge insertion with unique,
literal plain-text anchors. This fixes the Command Bar line 439 presentation-
bridge failure without changing the confirmed entry source contract.

Installer V3 explicitly disables the legacy entry ScreenGui during the modern
startup presentation and restores it only for the confirmed vehicle picker or
full close. It also suppresses background UI before profile/PB calls can yield,
preventing the old setup page from appearing during the startup handoff.

Installer V4 uses equal 50/50 setup columns aligned to the footer buttons, one
shared semantic gap, matched lower baselines, and a corrected left-column map /
lap stack. The right column now follows the compact prize, personal-best, and
horizontal medal-target hierarchy. Track-map media resolves through the Race
Catalog first, matching the Race Browser's configured image source. Header tabs
use the same centre gap as the footer actions.

Installer V5 centres the minus/count/plus lap controls in one fixed-width row;
splits the prize summary into class, centred prize, and configurable daily bonus
columns; moves the achieved medal and actual PB vehicle image into Your Best;
enlarges target medals by 1.3x and their target times; and applies proportional
desktop edge buffers (`10%` horizontal / `8%` vertical) with a lower responsive
scale floor for smaller PC viewports. `Copy.DailyBonusDisplay` defaults to `2X`.

V5.1 removes the runtime hard wait on the optional `Copy` folder. The controller
boots with `2X` as a local fallback and reads `Copy.DailyBonusDisplay` when the
installer-created folder is available.

Installer V6 rebuilds Your Best as three equal presentation zones: achieved
medal and medal name, centred PB time and label, then an unframed vehicle image
and vehicle name. Tier buttons retain a neutral gradient while their border and
glow always use the tier colour; selection fills the button with that colour,
including locked tiers. A selected locked tier now disables the footer action
and displays `OWN A X CLASS VEHICLE TO ENTER` inside the button, with no separate
overlapping warning. The installer also upgrades the shared UI module and Race
Browser controller to one responsive-scale helper, so both menus use identical
shell dimensions, PC edge buffers, minimum scale, and viewport fitting.

Installer V7 gives the Race tab its own open-category composition without a
tier selector or editable lap count. It retains the exact Time Trial shell,
columns, gaps and footer, replacing the tier rail with race facts and the lap
selector with a track-record panel. Placement-prize rows are display-only views
of the confirmed event `BaseReward` and global `Rewards.Race` multipliers, using
the same rounding and min/max clamps as Phase 11A. Checkpoint and player values
remain catalog-driven. Each RaceCatalog event receives a presentation-only
`TrackLengthMiles` attribute (default `0`, displayed as unavailable until set).
The track-record panel deliberately shows `NO RECORD SET` until authoritative
record data is provided; it does not create a second leaderboard owner.

V7.1 fixes intermittent tab selection colour at its presentation boundary. The
shared button hover handler restores the colour captured when a button was
constructed, which could overwrite the later blue selected state on mouse enter
or leave. The entry controller now reasserts only the currently selected tab
after the shared hover callback, preserving all other shared button behaviour.

V8 makes the map the Time Trial page's visual hero, with a large `TIME TRIAL`
overlay, track subtitle, and compact lap adjustment floating over the lower map.
The PB frame removes the vehicle image while retaining the achieved medal, time,
and recorded vehicle name. Medal targets become four horizontal rows for faster
scanning. The Race map receives the same title treatment as `MULTIPLAYER RACE`,
without changing the confirmed race information or reward composition.

V8.1 removes the inherited lap heading and centres minus, lap count and plus as
one row inside the cyan overlay. The Time Trial right column is now transparent,
with three full-width sibling frames and one shared gap rather than nested
borders; the prize frame is taller, and the medal-title label is removed. The
Race track-record block is removed so its map fills the left column. Every entry
interaction now opens on Time Trial by default, with Race still available from
the persistent top tab.

V9 corrects the lap overlay's layer ownership: its control row and time label now
render above the decorative gradient. Primary Time Trial frames use the same
outline treatment as the map and Race panels, map media receives a deeper inset
and matching corner radius, and every footer uses one text size. The Time Trial
action becomes `NEXT`, opening a state-preserving 50/50 Records page with World
Record, Medal Targets, Your Record, and Global Top 20 regions. `BACK` returns to
setup and `CHOOSE VEHICLE` continues through the confirmed legacy picker. Until
an authoritative OrderedDataStore service exists, global/world sections show an
explicit unavailable/empty state and do not fabricate rankings or records.

V10 makes the Records tier rail read-only: the chosen class stays filled while
all other tiers are neutral, disabled context. It adds a shared racing vehicle
picker using free-roam card, category-dropdown and sorting semantics. Time Trial
pre-filters vehicles to the chosen class; Race exposes every owned vehicle.
Cards default to the highest-rated eligible vehicle, support Category plus
Rating/Name/Class sorting, and use a cyan selection state. A guarded bridge in
the confirmed legacy entry controller retains its server-validated vehicle
spawn, staged Time Trial start and multiplayer queue handoffs.

## Studio installer

`scripts/roblox_racing_ui_phase2_time_trial_startup.lua`

Run from the Studio Command Bar in Edit mode with `MODE = "INSTALL"`.

## Scope

- installs isolated `RaceEntryPresentationController_Active`;
- reuses `RacingUIComponents` and the confirmed 1200x720 browser shell;
- adds Time Trial/Race header tabs, E-S class selection, track map, lap selector,
  PB medal/time/vehicle presentation, medal targets, locked-tier visibility,
  and shared responsive scaling;
- selects the highest owned class by default;
- creates `Config.UI.Racing.Assets.MedalAtlas`, `MedalAtlasSize`, and
  `MedalAtlasCellSize`;
- installs a tiny two-BindableEvent bridge into the confirmed entry client;
- hands `CHOOSE VEHICLE` back to the confirmed legacy vehicle/staging path with
  selected mode and lap count preserved.

It does not replace reward/PB ownership, vehicle validation, staging, countdown,
HUD, reset, finish lifecycle, matchmaking, or server remotes.

## Medal atlas

Upload `assets/ui/icons/racing/racing-medal-atlas.png`, then set its asset ID in
`Config.UI.Racing.Assets.MedalAtlas`.

The atlas is 1024x1024 with a 2x2 grid of exact 512x512 cells: Platinum
top-left, Gold top-right, Silver bottom-left, and Bronze bottom-right.

## Verification

1. Confirm installer smoke passes without warnings.
2. Enter the race start zone and confirm only the new shell opens.
3. Confirm Time Trial is selected and the highest owned class is selected.
4. Confirm each tier keeps its tier-coloured border/glow, selection fills with
   the tier colour, and locked classes show the disabled ownership requirement.
5. Confirm map, PB and medal targets update when switching class.
6. Confirm lap minus/plus obey the configured minimum and maximum.
7. Switch to Race and back; confirm shell dimensions do not move.
8. Press `CHOOSE VEHICLE`; confirm the existing vehicle page opens and the
   selected lap count reaches staging.
9. Confirm Exit/close restores free-roam UI.
10. Open the Race Browser at 1920x1080 and 1366x768 and confirm it uses the same
    edge buffer and overall shell scale as the startup menu.
11. Test landscape touch emulation.

Do not patch rewards, reset or finish services to correct presentation issues.
