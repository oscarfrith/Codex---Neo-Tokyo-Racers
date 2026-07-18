# Garage upgrade point budgets and shared cards

Date: 2026-07-17

Status: guarded installer generated from the confirmed canonical resolver/card baseline; awaiting Studio and Play verification.

## Scope

- Standard core modules receive the same three data-driven upgrade paths as their matching Lightweight sibling and a total capacity of two points.
- Lightweight and Power core modules retain six total points.
- Per-path limits remain three points, allowing players to distribute the module budget between the available paths.
- Allocations continue to live on physical module instances and therefore retain their colours, neon, cosmetics and performance choices when moved between vehicles.
- Performance upgrade choices render through the existing shared `ModuleListingCard`, with the installed module's vehicle name, path tag, current path allocation, next price, effect summary and existing card-centred action popup.
- A compact shared budget strip shows used/available points. Its layout reserves explicit vertical clearance above the action popup and adds a runtime overlap assertion.
- Selecting an available next point previews the resulting canonical PI and six headline stats before purchase.

## Safety

The installer clones path folders only from the matching Lightweight sibling in the same source-vehicle/module-family folder. It does not modify base performance values. It compiles all changed sources before assignment, records attributes in memory, and removes cloned roots plus restores sources/attributes if its post-install audit fails.

## Next gate

After desktop Play confirmation, use this final shared card/budget composition for the tablet and phone responsive pass. Do not create a separate mobile garage implementation.
