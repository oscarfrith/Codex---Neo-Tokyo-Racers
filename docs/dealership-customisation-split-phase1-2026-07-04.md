# Dealership / Customisation Split Phase 1

**Date:** 2026-07-04  
**Status:** Installed by the user and reported working  
**Script:** `scripts/roblox_dealership_customisation_split_phase1_buy_only.lua`

## Goal

Start separating the dealership from owned-vehicle customisation.

Phase 1 changes the dealership into a buy-only surface:

- unowned cockpits show `Buy $...`;
- owned cockpits show `Buy Another $...`;
- the old dealership `Select` button is removed;
- the starter Bruiser cockpit price is set to `$15000`;
- fresh session profiles no longer receive `bruiser_01` as an owned cockpit for free.

Existing saved/test players who already own `bruiser_01` keep that ownership. The new rule applies to fresh profiles or reset test data.

## Implementation Notes

The installer is a guarded Command Bar script. It patches:

- `ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.*.COCKPITS_ReplaceAssetsHere` starter cockpit `Price` attribute;
- `ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled`;
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled`.

The script deliberately does not add the separate customisation zone yet. That should be Phase 2, using a new opener/owned-cockpit selection path rather than reusing the dealership desk as a selector.

This patch depends on fragile source anchors in the active server controller and large client bootstrap. If it aborts, refresh the Studio mirror before another attempt.

## Studio Steps

Already run by the user on 2026-07-04 and reported working. If reinstalling after rollback, run this in Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase1_buy_only.lua
```

2. Restart Play.
3. Reach the dealership desk.
4. Verify the right panel shows either:

```text
Buy $15000
```

or:

```text
Buy Another $15000
```

It should never show `Select`.

5. Optionally run the same script from the client Command Bar during Play. It checks the catalog price and prints whether the current test player already owns the starter cockpit.

## Manual Verification

- Fresh/no-save test player: `bruiser_01` should not be owned before purchase.
- Starter cockpit card and right panel should show `$15000`.
- Buying the starter cockpit should spend `$15000`, create a cockpit/vehicle instance, unlock the preview, and advance to Paint Cockpit.
- Existing player with `bruiser_01` already owned should see `Buy Another`, not `Select`.
- Buying another copy should respect garage capacity and then advance to Paint Cockpit.
- Module shop, cockpit paint, customisation, and Start Driving should behave as before after purchase.

## Rollback

Use Roblox version history for the Studio-side script/source changes.

If rolling back manually, restore:

- `COCKPIT_BRUISER_01.Price` to the previous value;
- the default profile starter ownership lines in `GarageActionController_Shadow_Disabled`;
- the previous `renderDealershipPanel` block in the active bootstrap.

Do not rerun older dealership `Select`/duplicate-copy patches unless intentionally restoring the previous combined dealership selector behavior.
