# Dealership / Customisation Split Phase 5

Date: 2026-07-04

## Purpose

Phase 5 makes two small follow-up UI changes after the Phase 4 customisation-zone test:

- the selected owned cockpit action now says `Customise` while still opening the Build Modules / `ModuleShop` screen;
- cockpit menu thumbnails come from one shared cockpit model attribute, `MenuImage`, so dealership, customisation, and free-roam UI can use the same image.

## Studio Script

Run this in Roblox Studio Edit mode:

```text
scripts/roblox_dealership_customisation_split_phase5_cockpit_menu_images.lua
```

## What It Changes

- Ensures every cockpit model under `ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.*.COCKPITS_ReplaceAssetsHere` has a `MenuImage` string attribute.
- Adds a small marker to the garage catalogue path. The catalogue already copies primitive cockpit attributes, so `MenuImage` is sent to the client without adding a new server field.
- Patches the active dealership/customisation bootstrap so cockpit cards render `MenuImage` when present and fall back to the old simple car shape when empty.
- Patches the isolated `FreeRoamNavController_Active` so the free-roam car button prefers the current cockpit's `MenuImage`, then falls back to `ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav.CarIcon`, then falls back to text.

## Where To Put Cockpit Images

Select the cockpit model in Studio, for example:

```text
ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories.BRUISER.COCKPITS_ReplaceAssetsHere.COCKPIT_BRUISER_01
```

Set its attribute:

```text
MenuImage = rbxassetid://YOUR_IMAGE_ID
```

A plain numeric asset ID is also accepted by the UI normaliser, but `rbxassetid://...` is the clearest format.

## Verification

1. Run the Phase 5 script in Edit mode.
2. Set at least one cockpit model's `MenuImage` attribute to a valid uploaded Roblox image asset.
3. Restart Play.
4. Open the dealership and confirm that cockpit's buy card shows the image.
5. Open the customisation zone and confirm owned duplicate cards show the same image, tier badge, and rating.
6. Select that cockpit/build, return to free roam, and confirm the free-roam car button uses the same image.
7. Click an owned cockpit in customisation and confirm the right-panel button says `Customise` but opens the module-buy/equip screen.

## Risks And Rollback

This phase uses guarded text replacement against the active dealership bootstrap and isolated free-roam controller. If the expected Phase 4 or Free Roam Map Stack source shape is not present, it should stop before changing that source.

The first generated version failed at `Could not find source anchor for cockpit catalog MenuImage note` because the live server catalogue had changed from the older helper-call shape to `item.CockpitId = item.CockpitId or cockpit.Name`. That server edit was only a comment marker and was not needed: `V56_primitiveAttributes(cockpit)` already carries `MenuImage` into the catalogue. The current script now audits that attribute-copy path instead of patching the server source.

Rollback options:

- use Roblox version history to restore the pre-Phase 5 scripts and attributes;
- clear `MenuImage` attributes to return cockpit cards/free-roam car button to their fallbacks;
- rerun the previous confirmed Phase 4 script if only the customisation action wording/path needs to be restored.
