# Lighting Phase AR: 10 AM And 3 PM Day Copies

**Created:** 2026-07-13
**Status:** Installed and mirrored through 2026-07-14 00:15:37; runtime verification still recommended

## Studio Script

Run in Edit mode:

```text
scripts/roblox_lighting_phaseAR_10am_3pm_day_copies.lua
```

The script preserves every existing lighting preset, adds independent `TenAM`
and `ThreePM` tables copied from the current `Day` preset, and updates the cycle:

```text
7 AM -> 10 AM -> Day -> 3 PM -> 5 PM -> 8 PM -> Night -> 4 AM
```

Day and Night retain duration weight `2`; every other stage uses weight `1`.
With the default five-minute base duration, the expanded cycle lasts 50 minutes.

The new presets initially share Day's stored Sky reference. Capturing either
with the reusable selected-stage capture script creates its own named Sky copy.

## Verification

1. Run Phase AR in Edit mode.
2. Run `scripts/roblox_lighting_phaseAQ_audit.lua`; expect `fail=0` and eight stages.
3. Use the selected-stage Edit preview with `TenAM` and `ThreePM`; both should
   initially match Day.
4. Start Play and test keys `2` (10 AM) and `4` (3 PM).
5. Confirm both use day windows with managed street lights off.

## Rollback

Use Roblox place version history. No in-game backups are created. Phase AR uses
canonical replacement of the small schedule/preview owners and serializes the
existing preset table; it does not use fragile text replacement.
