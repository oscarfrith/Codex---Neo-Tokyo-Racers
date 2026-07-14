# Vehicle Performance V2 — Phase 4 Variant Calibration

Date: 2026-07-13

Status: confirmed. Studio passed `7/0/0`; mirror refreshed at `2026-07-13 21:21:01`.

## Purpose

Phase 4 defines Standard, Lightweight, and Power versions of every front engine, rear engine, stabiliser, and boost donor component across E–S.

Standard remains non-upgradable. Lightweight and Power each declare six upgrade points, but this phase deliberately does not define the individual point paths yet.

## Variant character

- Standard: exact Phase 3 component allocation, zero price, zero upgrade capacity.
- Lightweight engines/stabilisers: `1.08x` higher-is-better output and `0.88x` lower-is-better values.
- Lightweight boost: `1.03x` higher-is-better output and `0.88x` lower-is-better values.
- Power: `1.10x` higher-is-better output with `1.04x` lower-is-better values as its mass/drag/recharge trade-off.
- Lightweight and Power use the same guide price: `12%` of donor cockpit price, rounded to the nearest `$100`.

The variants are compared by their effect on the complete native stock build, not by equal raw numbers. Diminishing returns mean high-tier internal PI gains are intentionally smaller than low-tier gains.

## Sheet

Every vehicle dossier now includes a tall `V2 LIGHTWEIGHT / POWER VARIANT POLICY` table. It records per-component multipliers, six-point capacity, and equal guide prices.

The linked Sheet Change Log marks Phase 4 `VERIFIED` with both Studio and Sheet confirmation.

## Studio script

Run in Studio Edit mode:

`scripts/roblox_vehicle_performance_v2_phase4_variant_calibration.lua`

It adds only shadow config folders beneath each profile's `VariantDefinitions`. It performs no source replacement and does not edit live module models or prices.

## Verification

1. Confirm `FAIL=0`.
2. Confirm 24 `VARIANT` lines compare Lightweight and Power for six donors × four components.
3. Both choices must improve internal PI and each pair must be within `1.5 PI`.
4. Confirm eight donor `LADDER` lines rise monotonically through E–S.
5. Confirm Standard capacity is zero and both alternatives use six points.
6. Confirm live asset hierarchy is unchanged and both runtime switches remain false.
7. Refresh the Studio mirror and paste the full Output into chat.

Confirmed result: all 24 printed component comparisons passed, all 48 non-Standard variants improved PI, every Lightweight/Power pair stayed within `1.5 PI`, all eight donor ladders rose from E through S, the live hierarchy was unchanged, and both runtime switches remained false.

## Rollback

Delete `VariantPolicy` and each profile's `VariantDefinitions`, then restore schema/source revision attributes to Phase 3. No live asset/runtime rollback is required.
