# Game Overview

Game name: Neo Tokyo Racers

## Concept

Neo Tokyo Racers is an open-world Roblox racing game with modular hovercars. Vehicles are futuristic hover racers with swappable cockpits, engines, boost modules, stabilisers, bumpers, spoilers, side pods, colours, neon, thrust colours, and VFX.

The visual direction discussed in chat is inspired by brutalist modular pod-racer hovercars, cyberpunk/neon city garages, and high-contrast futuristic UI.

## Core Player Flow

Current planned/implemented flow:

1. Loading screen with game title and loading bar.
2. Dealership intro objective/path guides the player to the desk.
3. Reaching the desk opens the dealership/cockpit selection menu.
4. Cockpit purchase/select creates the local-only preview.
5. Cockpit paint.
6. Module selection.
7. Module customisation.
8. Spawn into the final drivable vehicle at the editable dealership exit marker and start driving.
9. Free roam with exit/re-enter/saved cars UI.

The current dealership intro baseline is documented in `docs/dealership-intro-flow-2026-06-03.md`. The first cockpit-buy menu includes an Exit button; after exiting, the menu stays closed until the player leaves and re-enters the dealership desk zone.

## Current Vehicle Category

The active category is `BRUISER`.

Known Bruiser slots:

- Front engine
- Rear engine
- Stabilisers
- Boost
- Front bumper
- Rear bumper
- Rear spoiler
- Side pods

Invisible upgrade systems discussed/implemented in UI:

- Brakes
- Converter
- Fuel system

## Input Direction

Current controls from the latest stable scripts:

- Keyboard: `WASD` driving, `SHIFT` drift, `SPACE` boost, `R` reset.
- Controller: common gamepad inputs were added earlier.
- Mobile: separate mobile driving HUD was added, with pedals, steering/drift buttons, boost, and MPH display.

Exact live bindings should be verified in Roblox Studio after each command-bar patch.
