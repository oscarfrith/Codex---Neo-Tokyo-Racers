# Shared Vehicle Card System V1.2

**Status:** V1.1 was user-confirmed working and fully mirrored at `2026-07-26 22:27:01/02`. V1.2 is generated from that exact live browser source and awaits Studio installation and runtime confirmation.

**Canonical installer:** `scripts/roblox_shared_vehicle_card_system_v1.lua`

## Acceptance and readiness contract

System/change: one true shared vehicle-card renderer across every active selector.  
Delivery lane: Standard, with High-Risk preservation gates for economy and race authority.  
Goal: Dealership, Customisation, desktop/touch free-roam, Race and Time Trial call `GarageReplacementComponents.VehicleCard`.

Required changes:

- Dealership purchase offers show bold price text at the bottom-right of the shared footer, on the same baseline and at the same size as the left-aligned vehicle name.
- Dealership price text is green when replicated authoritative Cash is sufficient and red otherwise; it has no coloured badge surface.
- The existing shared Cash event immediately refreshes visible Dealership affordability.
- Dealership prices below one million remain full; prices at or above one million use exactly two decimals (`$1.00M`, `$9.95M`, `$10.00M`).
- The garage/dealership Cash readout always shows the full grouped amount, while Cash and Garage Spaces use larger bold responsive text. Narrow free-roam HUD Cash remains compact to prevent phone overflow.
- V1.2 keeps the confirmed PC Cash/Spaces maximum sizes at `17/16` and reduces touch/mobile to `11/10`, with minimum `8`.
- Mobile Dealership action popups omit the price and show `BUY`/`BUY ANOTHER`; PC retains the formatted price. Both routes call the same existing primary action.
- Desktop and touch free-roam vehicle layouts have transparent containers.
- Free-roam, Race and Time Trial retire duplicated card construction.
- Owned-only selectors never pass the purchase-price contract.
- The shared artwork and footer surfaces extend to a stroke-safe two-pixel inset, with a modest Fit-mode image zoom and no gap around the old inner rectangle.
- Owned-selector rating/tier badges use one renderer prop: `1.5x` on desktop, `0.75x` on compact phone layouts and `1x` on scaled touch/tablet race layouts.

Must preserve:

- `VehicleId`/`CockpitId`, images, tiers, ratings, sort/category filters and selected state;
- authoritative purchase, free-roam spawn/despawn, queue and race-start actions;
- physical owned-vehicle selection for Race and Time Trial;
- queued vehicle lock, menu suppression and input release;
- Dealership factory preview versus Customisation saved-owned preview;
- scrolling, touch activation, keyboard and controller-selectable buttons;
- unrelated garage and racing pages.

Explicit exclusions: no bootstrap, remote, server action, saved schema, product, vehicle asset, VFX, driving, race rule or unrelated page change.

Canonical owners:

- card geometry/state: `GarageReplacementComponents.VehicleCard`;
- colour, focus, bevel/stroke and money: `RacingUIComponents` and `ResponsiveUIFoundation`;
- Dealership/Customisation rows, preview and purchase dispatch: `GarageBrowserController`;
- free-roam visibility, filters and spawn dispatch: existing desktop/touch HUD controllers;
- Race/Time Trial selection/start dispatch: `RaceEntryPresentationController_Active`;
- Cash, ownership, purchase, spawn, queue and race authority: unchanged server owners.

Lifecycle/scale: rerenders destroy old cards and their `Activated` connections. One existing Cash binding per browser updates badge properties without rebuilding cards. Work is linear in visible card count, with no new loop, poll, remote or Workspace scan.

Authority/data: price and affordability are display projections only. Server purchase validation remains authoritative. No saved schema, stable ID or migration change.

Rollback: the V1.2 installer snapshots the one changed browser source, compiles before assignment and restores it if committed audit fails. After a committed install, use Studio version history or restore the confirmed `2026-07-26 22:27:01/02` V1.1 browser source.

## Installer contract

Run the complete installer once in the Edit-mode Command Bar with `MODE="INSTALL"`.

It requires the confirmed V1.1 marker on all five owners, exact-checks the two changed browser windows, compiles the one projection before mutation, audits all five committed owners/actions, reruns safely, and supports read-only `MODE="AUDIT"`.

The installer uses guarded plain-text source replacement. If an anchor differs, stop and refresh/inspect live source rather than weakening its guards.

## Verification matrix

Dealership:

- Cross one vehicle's price threshold in both Cash directions while the page stays open; price text must change immediately.
- Check `$40,000`, `$350,000`, `$1.10M`, `$3.50M`, `$9.95M` and `$10.00M`.
- Confirm the name is bottom-left, the price is bottom-right, both share a baseline and size, and no price badge background remains.
- Confirm Cash shows a full grouped amount such as `$1,000,000`; Cash and Garage Spaces are larger/bolder without clipping.
- Confirm PC retains the approved Cash/Spaces size, while phone and tablet use the reduced `11/10` caps.
- Confirm mobile popup copy is `BUY`/`BUY ANOTHER` with no price; confirm PC still shows its formatted price.
- Preview/purchase an unowned factory vehicle and verify authoritative Cash/ownership.
- Verify an owned Dealership cockpit still offers genuine “buy another”.
- Verify Customisation shows saved owned appearance and no price badge.

Free-roam:

- Desktop and touch cards float over the world with no black panel.
- Desktop badges are `1.5x`; compact-phone badges are reduced and do not dominate the card.
- Categories, rating/price/name sorting, scroll, selected state, BUY MORE and DESPAWN work.
- Spawn a non-current physical owned vehicle and verify its requested `VehicleId`.
- Close through outside tap/back/controller navigation and verify HUD/input release.

Race and Time Trial:

- Choose distinct physical vehicles sharing a cockpit type and verify the selected `VehicleId` is staged.
- Both modes use the shared renderer and show no Dealership prices.
- Desktop badges are `1.5x`, compact-phone badges are `0.75x`, and scaled touch/tablet badges use the intermediate scale.
- While queued, attempt an invalid vehicle change and verify the existing lock rejects/prevents it.
- Exit/back/start retain suppression and input release.

States/devices/performance:

- Inspect selected, focused, affordable, unaffordable, owned, unavailable and empty states.
- Inspect artwork/footer edges: they should meet the stroke-safe inset without covering the coloured border; Fit-mode artwork must not crop.
- Repeat on desktop mouse/keyboard, controller, tablet touch, landscape phone and portrait phone where supported.
- Reopen, filter and rerender each selector at least ten times. Card count must equal expected rows plus one intentional empty/unavailable card, old cards must be destroyed, and no duplicate action or Cash callback may occur.

## Readiness scorecard

- Ownership: PASS.
- Security/economy: PASS by preservation; runtime purchase rejection remains regression.
- Data/persistence: N/A.
- Lifecycle/performance: static PASS; repeated-rerender runtime check pending.
- Mobile/input: one implementation; device matrix pending.
- Streaming: N/A for this UI-only change.
- Failure/observability: PASS for installer; runtime Output pending.
- Documentation: PASS for generated state; confirmation/mirror handoff pending.

Done when V1.1 installation and runtime checks pass, the user confirms the result, and a fresh complete mirror contains all five V1.1 revision markers with matching manifests/checksums.
