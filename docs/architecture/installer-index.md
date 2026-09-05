# Current tools and recovery index

**Current entry point:** scripts/roblox_cleanup_phase3_generic_naming.lua — installed and user-confirmed. No manual run needed. Earlier installers require dependent cleanup rollback before exact-baseline recovery. See [Phase 3 handoff](cleanup-phase3-generic-naming.md).

This index selects current entry points; it does not certify every historical installer against today's place. Files not listed are historical/unreviewed for execution, not automatically obsolete or safe to delete.

| Scope | Canonical script in scripts/ | Status / normal use |
|---|---|---|
| Complete cleanup Phase 2 | roblox_cleanup_phase2_canonical_ownership.lua | Current user-confirmed phase; Phase 3 installer is not generated yet. INSTALL/AUDIT/ROLLBACK against its exact baseline |
| Complete cleanup Phase 1 | roblox_cleanup_phase1_scaffolding.lua | User-confirmed historical recovery; restore Phase 2 first |
| Legacy cleanup | roblox_legacy_cleanup.lua | Historical retirement evidence; restore dependent complete-cleanup phases before recovery |
| Architecture Phase 1 | roblox_architecture_phase1_foundation_audit.lua | Read-only audit; no gameplay install |
| Architecture Phase 2 | roblox_architecture_phase2_persistence_safety.lua | User-confirmed historical recovery; superseded source layout, do not rerun over Phase 3 |
| Architecture Phase 3 | roblox_architecture_phase3_server_organisation.lua | User-confirmed server layout; inspect subsequent dependencies before rollback |
| Architecture Phase 4 | roblox_architecture_phase4_client_organisation.lua | User-confirmed client layout; Phase 5 supersedes LOD fingerprint, roll it back before Phase 4 recovery |
| Architecture Phase 5 | roblox_architecture_phase5_world_optimisation.lua | User-confirmed final phase; restore subsequent cleanup before exact-baseline recovery |
| Phase 5 isolated tests | roblox_architecture_phase5_safety_tests.lua | Agent-run disposable policy/lifecycle fixtures |
| Phase 5 CPU benchmark | roblox_architecture_phase5_benchmark.lua | Edit, isolated city clones; not FPS/device evidence |
| Phase 4 isolated tests | roblox_architecture_phase4_safety_tests.lua | Agent-run dependency/gating/subscription tests; no DataStore calls |
| Phase 3 isolated tests | roblox_architecture_phase3_safety_tests.lua | Agent-run Edit dependency/state tests; no DataStore calls |
| Phase 2 isolated tests | roblox_architecture_phase2_safety_tests.lua | Agent-run Edit in-memory tests; no DataStore access or instance writes |
| Mirror export | roblox_studio_export_full_snapshot_for_github_v2.lua | Agent-run Edit export to receiver; schema revision 3 |
| Mirror receiver | receive_studio_full_snapshot_export.py | Agent-run loopback receiver |
| Mirror integrity | verify_studio_mirror.py | Local read-only verification |
| Mirror failure tests | test_studio_snapshot_pipeline.py | Disposable fixture outputs only |
| Steering V1.2 | roblox_driving_reverse_turn_bank_direction_v1.lua | Already installed; runtime acceptance pending; do not reinstall for Phase 1 |
| Paint Shop icon/price | roblox_ui_paint_shop_icon_price_text_refinement_v1.lua | Confirmed recovery-only; no ordinary run |
| Free-roam markers/map | roblox_freeroam_map_players_smooth_pan_v1.lua | Confirmed recovery-only; no ordinary run |
| Showroom Loop | roblox_racing_showroom_loop_route_v1.lua | Confirmed recovery-only; no ordinary run |
| Onboarding | roblox_player_onboarding_v1.lua | Recovery-only; inspect latest topic/source before use |
| Drive-to-earn | roblox_drive_to_earn_cash_system_v1.lua | Installed scope; no ordinary run |

Old May architecture phase scripts do not implement the newly approved programme. Do not execute an old “Phase 1” by matching its filename. Each later approved phase gets one canonical implementation after current-owner inspection.

Phase 3 supersedes Phase 2's source/class layout. Phase 2 was user-confirmed; its installer is historical recovery evidence, not safe to rerun against Phase 3.
