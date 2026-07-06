# Free Roam Vehicle Spawn Phase 4D - Parked Despawn, Driving-Only Speed Gate, Card Polish

Prepared: 2026-07-06

Script:

- `scripts/roblox_freeroam_vehicle_spawn_phase4d_despawn_speed_card_polish.lua`

## Goal

Repair the follow-up issues seen after Phase 4C:

- Despawning a parked vehicle teleported the already-exited player back to the vehicle.
- Spawning a new vehicle was blocked by the old parked vehicle's speed when that car was moving over `10 MPH`.
- On desktop, the free-roam car menu panel was wider than needed for three cockpit cards.
- Free-roam cockpit cards/images had pink outline layers that did not match the dealership cockpit-card style.

## Implementation

- Adds a server helper that checks whether the player's humanoid is currently seated inside their spawned vehicle.
- `DespawnVehicle` now moves/unseats the player only when they are actually seated in that vehicle. If the player already exited, the vehicle is destroyed and the player stays where they are.
- The `10 MPH` gate now applies only when the player is actively seated/driving their owned vehicle.
- The spawn request position now uses the vehicle position only while driving. If the player is on foot after exiting, it uses the player position instead of the old parked/moving car.
- Free-roam car panel desktop width is fitted to three compact cards: `3 * 146px + gaps/padding = 470px`.
- Free-roam cockpit cards use filled card/image layers with no pink outline on the card or image box. The selected card still uses the magenta selected fill.

## Verification

Restart Play after running the repair:

1. Spawn a vehicle from the free-roam car menu.
2. Exit the vehicle and walk away.
3. Open the car menu and press `DESPAWN`; the vehicle should disappear and the player should not teleport.
4. Exit from a moving vehicle and try to spawn another while on foot; the old parked car speed should not block the spawn.
5. While actively driving over `10 MPH`, try to spawn another vehicle; it should still block until you slow down.
6. On desktop, the free-roam car panel should be just wide enough for three cockpit buttons.
7. Cockpit card/image boxes should not have pink outlines, while selected cards still show the magenta fill.

## Notes

The Phase 4D UI patch is intentionally scoped to `FreeRoamNavController_Active`. It does not change dealership/customisation card rendering.
