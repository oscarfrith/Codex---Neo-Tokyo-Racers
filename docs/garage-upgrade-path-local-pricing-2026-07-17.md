# Garage path-local upgrade pricing

Date: 2026-07-17

Status: installed and user-confirmed working in Play on 2026-07-17.

## Root cause

The shared V2 runtime selected `Point(total module points + 1)CostGuide`. Consequently, purchasing a level on Drift also advanced the displayed and server-charged prices for Grip and Response.

## Fix

- `VehiclePerformanceV2UpgradeRuntime.NextPointCost` now accepts the selected path and selects the cost from that path's own next level.
- The module's total two- or six-point allocation limit remains shared and unchanged.
- Optional `PointNCostGuide` attributes on an individual path override the module fallback, allowing future path-specific balancing without another code change.
- Catalog previews and server purchases call the same path-aware helper.
- `VehiclePerformanceResolver.UpgradeCost` exposes that exact helper to the canonical garage UI.
- Upgrade cards no longer calculate prices independently.

## Example

With Drift at Level 1 and Grip/Response at Level 0, Drift quotes the module's Level 2 price while Grip and Response continue to quote its Level 1 price.

## Safety

No allocation, capacity, effect, ownership, transaction or persistence schema changes are made. The installer compiles all three sources before assignment, uses exact single-occurrence anchors, is rerunnable, and restores every source in memory if its post-install audit fails.
