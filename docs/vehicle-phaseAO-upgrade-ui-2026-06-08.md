# Vehicle Phase AO Upgrade UI

Status: installed and confirmed working on 2026-06-08.

## Purpose

Phase AO exposes the confirmed Phase AN module-specific upgrade system in the live customisation menu.

It removes the visible legacy controls:

- Brakes.
- Converter.
- Fuel System.
- Generic `UPGRADE (LVL 1)`.

Each installed module instead gets a `Performance` screen containing its own upgrade cards.

## UI Behaviour

Each upgrade card shows:

- Upgrade name.
- Current and maximum level.
- Next-level price.
- Per-level raw performance effects.

Selecting a card previews one additional level in the right-hand stats panel. Pressing `Buy` calls the existing server-authoritative `UpgradeModule` action.

The upgrade list uses a horizontal scrolling frame. It supports touch swiping on mobile and remains inside the existing bottom customisation panel.

## Stats Panel

The right-hand stats panel always starts with:

```text
Tier + Performance Index
```

For general screens it shows the six headline stats:

- Speed.
- Acceleration.
- Handling.
- Drift.
- Braking.
- Boost.

When an installed module is selected, it switches to a contextual view:

- The two headline stats most affected by that module's available upgrades.
- Up to five detailed raw variables affected by those upgrades.
- Preview values when an upgrade card is selected.

This keeps the main UI compact while still exposing detailed tuning information where it is relevant.

## Fragile Patch Warning

The installer uses guarded exact text replacement against the refreshed Phase AN main client bootstrap:

```text
StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
```

It preflights every replacement and performs exactly one `Script.Source` assignment. Do not bypass a failed exact-match assertion. Refresh the Studio mirror and update the installer against the new source instead.

## Install

The install and audit were completed successfully. Keep these scripts as recovery/history tools; do not rerun the installer on the confirmed working place unless Phase AO has been rolled back.

Run in Edit mode:

```text
scripts/roblox_vehicle_phaseAO_upgrade_ui.lua
```

Then run separately:

```text
scripts/roblox_vehicle_phaseAO_upgrade_ui_audit.lua
```

Expected audit:

- Module types with upgrades: `7`.
- Module-specific upgrades: `23`.
- Phase AN purchases enabled: `true`.
- Client phase attribute: `AO`.
- Warnings: `0`.

## Play Test

The user reported the installed Phase AO flow working well. Keep the checklist below for regression and device testing:

1. Start a fresh Play session.
2. Open the dealership and continue to Customise.
3. Confirm Brakes, Converter, and Fuel System are absent from the left list.
4. Select an installed engine.
5. Confirm the right panel shows a tier/index header and engine-related detailed variables.
6. Press `Performance`.
7. Confirm four engine upgrade cards appear.
8. Select an upgrade card and confirm the right panel previews its next-level effects.
9. Buy one level and confirm cash, level, detailed variables, and performance index update.
10. Repeat with stabilisers, boost, and one body module.
11. In Studio's mobile emulator, confirm the left list scrolls, upgrade cards swipe horizontally, text remains readable, and the Buy popup remains on-screen.
12. Spawn the vehicle and confirm driving still works.

## Risks

- The main client remains close to Roblox's local-register limit. Phase AO adds one global phase table instead of multiple top-level locals.
- Context rows are selected from upgrade definitions and headline weights. Changing those definitions automatically changes which rows are shown.
- An upgrade preview adds exactly one next level. It does not preview several levels at once.
- Upgrade ownership remains session-memory only until the garage profile receives unified DataStore persistence.

## Rollback

Use Roblox version history from immediately before Phase AO.

Rolling back Phase AO only removes the new presentation layer. Phase AN purchases and owned module levels remain valid.

## Mirror Refresh

The committed mirror is still the pre-AO/Phase AN-era export. Refresh it now:

1. Run `py scripts/receive_studio_full_snapshot_export.py`.
2. Run `scripts/roblox_studio_export_full_snapshot_for_github_v2.lua` in the Studio Command Bar.
3. Commit generated changes under `roblox/exported_scripts/` and `roblox/studio_snapshot/`.
4. Do not commit `docs/studio-full-export-paste.txt`.
