# Vehicle Performance V2 — Phase 2 Catalogue Calibration

Date: 2026-07-13

Status: confirmed at `8 PASS / 0 WARN / 0 FAIL`; refreshed Studio mirror generated at `2026-07-13 20:53:08` contains the calibrated source, config, and all six profiles.

## Outcome

Phase 2 calibrates six balanced complete-stock shadow builds across E–S. It does not create Zenith assets, copy Viper models, change live cockpit/module stats or prices, or enable V2 rating/physics.

The calibrated curve adds an editable `PerformanceOrigin` before the asymptote:

```text
ratingInput = max(CombinedPerformance - PerformanceOrigin, 0)
PI = 100 + (999 - 100) * (1 - exp(-ratingInput / RatingScale))
```

This prevents low-tier ratings bunching around C while keeping raw stats uncapped and increasingly less effective at the high end.

## Calibrated settings

- `TopSpeed.Reference = 180`
- `OverallRating.PerformanceOrigin = 54.05258886598588`
- `OverallRating.RatingScale = 50.43508980641478`
- E–S thresholds remain `100 / 300 / 450 / 600 / 725 / 850`
- runtime rating and physics switches remain false

The Google Sheet now includes a tall `Balanced Stock Profiles` tab. Editing any complete-stock raw value recalculates its effective factors, six headline values, internal/display PI, tier, spread, and calibration status.

## Six shadow profiles

| Tier | Vehicle | Cockpit ID | Target PI | Price guide |
|---|---|---|---:|---:|
| E | Forge | `bruiser_02` | 200 | $40,000 |
| D | Vector | `bruiser_03` | 375 | $120,000 |
| C | Viper | `bruiser_01` | 525 | $350,000 |
| B | Nightline | `bruiser_04` | 662 | $1,100,000 |
| A | Rally | `bruiser_05` | 787 | $3,500,000 |
| S | Zenith | `bruiser_06` | 925 | $10,000,000 |

Price remains a progression guide, not a copied competitor value or runtime price change.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase2_catalogue_calibration.lua`

The installer performs one guarded exact source replacement in the isolated Phase 1 `VehiclePerformanceV2Calculator` only. It adds the performance-origin calculation, writes the curve settings and six raw profiles beneath `VehiclePerformanceV2_EditAttributes.BalancedStockProfiles`, then validates every profile.

Studio can retain an earlier ModuleScript `require` result during a Command Bar session even after its `Source` changes. The installer therefore validates through a fresh temporary clone of the isolated calculator and destroys that clone immediately. It is not retained as a backup or runtime object.

If the exact calculator anchor is absent or duplicated, the script stops before mutation. Do not attempt another anchor repair; refresh and inspect the mirror.

## Verification

1. Confirm the final summary has `FAIL=0`.
2. Confirm six `PROFILE` lines appear from Forge E through Zenith S.
3. Each profile must match its target tier, stay within 3 internal PI of target, and have headline spread at or below 1.
4. Confirm the E-tier `+20 EngineOutput` PI gain is larger than the S-tier gain, while both remain positive.
5. Confirm both runtime switches remain false and V1 sources are unchanged.
6. Briefly Play-test that current Viper rating, driving, garage, spawning, and UI remain unchanged; Phase 2 is shadow-only.
7. Stop Play and refresh the full Studio mirror.

## Rollback

Before any V2 runtime switch, rollback is contained: remove `BalancedStockProfiles`, restore TopSpeed reference `130`, RatingScale `150`, remove `PerformanceOrigin`, and restore the Phase 1 calculator source from the pre-Phase-2 mirror. A place-version revert should not be necessary if the installer completes cleanly.
