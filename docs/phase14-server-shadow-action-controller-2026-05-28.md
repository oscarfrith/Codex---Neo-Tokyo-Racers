# Phase 14 Server Shadow Action Controller

**Created:** 2026-05-28  
**Last updated:** 2026-05-28  
**Current status:** Prepared  
**Studio script:** `scripts/roblox_hierarchy_phase14_server_shadow_action_controller.lua`

## Goal

Phase 14 creates a disabled shadow server action controller in the new architecture using the exact current V56 action block.

This is a switch candidate for a later phase. It does not go live yet.

## What The Script Creates

Under `ServerScriptService.NeoTokyoRacers.Services.Garage`:

```text
GarageActionController_Shadow_Disabled
```

Under `ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports`:

```text
Phase14_ServerShadowActionControllerReport
```

## What It Checks

Before writing the shadow script, it verifies:

- `HOVER_RACING_V2_Server` exists.
- The V56 begin/end markers exist.
- The current V56 hash matches the Phase 12 snapshot hash.
- If the generated snapshot module is stale/broken, the script can fall back to the Phase 12 report hash.
- The existing shadow script, if present, was created by this phase.

## What It Does Not Change

The script does not:

- Edit `HOVER_RACING_V2_Server`.
- Disable `HOVER_RACING_V2_Server`.
- Enable the shadow action controller.
- Replace `GarageInvoke.OnServerInvoke`.
- Change profile data, cash, purchases, vehicle spawn, UI, driving, VFX, mobile controls, LOD, lighting, traffic, or assets.

## Next Safe Step

The next phase can be a controlled server action owner switch:

1. Disable the legacy server action owner.
2. Enable `GarageActionController_Shadow_Disabled`.
3. Run Phase 13 server hash parity.
4. Run Phase 13B client `GetInitial` shape check.
5. Test dealership, purchases, customisation, spawn, driving, exit/re-enter.

Do not do this switch until you are ready to test immediately.

## Codex Safety Notes

- Do not enable this shadow script while `HOVER_RACING_V2_Server` is still active.
- This phase intentionally duplicates the V56 block as a safe bridge before splitting into smaller services.
- Real service extraction should happen after the new architecture owns the server action flow.

## 2026-05-28 Note

If Phase 14 reports that `V56ActionLayerSnapshot` cannot be required, rerun the updated Phase 12 script first. Phase 14 also has a fallback that can read the hash from `Phase12_ServerActionSnapshotReport`, but regenerating Phase 12 is still the cleanest path.
