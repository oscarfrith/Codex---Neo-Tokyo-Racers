# Owned Garage And System Readiness Handoff

**Status:** Owned Garage Phase 12 V1.1 confirmed; proportional new-system readiness workflow adopted
**Mirror:** Refreshed 2026-07-20 11:10:20, 156 exported scripts
**Git baseline:** `c46ead4` on `main` and `origin/main`
**Rollback revision:** `NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1_1_HUD_DROPDOWNS`

## Locked Baseline

Start future owned-garage or new-system work from commit `c46ead4` and the refreshed mirror. Do not rerun Owned Garage Phases 0-12 unless restoring an older place or a confirmed matching regression.

Confirmed owned-garage scope includes:

- reusable property definitions, revisioned state projection and stale-request conflict handling;
- ProfileService-owned authoritative garage commands against the live session profile;
- persistent display assignments, drive-in/out and property-owned exterior transitions;
- asset-backed Structure customisation with stable section IDs;
- anchor-bounded Decorations with owned-item purchase/place/remove persistence;
- bounded local garage Lighting presets/intensity, separate from world Lighting;
- Access modes and persistent bounded Invitations through API/definition version 4;
- Phase 12 V1.1 persistent-HUD Access and Invite dropdowns that preserve Cash and Settings;
- `EnableVisitors=false`: access settings do not yet admit visitors.

The mirror contains all seven Phase 12 access/invitation source contracts and reports the V1.1 HUD-dropdown revision. Phase 10 Decorations and Phase 11 Lighting source/catalogue contracts are also present.

## Canonical Owners

| Concern | Owner |
|---|---|
| Authoritative profile/session mutation | `ProfileService_Active` through `OwnedGarageAuthoritativeCommandRuntime` |
| Schema normalisation/defaults | `OwnedGarageProfileRuntime` |
| Duplicate-safe revisioned transactions | `OwnedGarageDisplayAssignmentRuntime` |
| Immutable management projection/cache | `OwnedGarageManagementRuntime` |
| Property/capability definitions | `OwnedGaragePropertyCatalog` |
| Structure, decoration and lighting catalogues | Their versioned shared data modules |
| Physical interior/display presentation | Existing owned-garage interior/display runtimes |
| Management UI | `OwnedGarageWorkspaceController` using shared garage components |
| Persistent interior Access/Invite HUD | `GarageInteriorModeController` |
| Shared dropdown/card/presentation components | `GarageReplacementComponents` |

Do not add a second persistence, physical-presentation, management-state or interior-HUD owner to extend this system.

## Optional Next Studio Change

There is no required Studio change before the prototype/funding submission if V1.1 is acceptable. The generated optional refinement is:

```text
scripts/roblox_owned_garage_phase12_access_invitations.lua
```

Its current revision is `NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1_2_FULL_WIDTH_ICON_DROPDOWNS`. Run it once in Studio Edit mode only if the approved V1.2 visual refinement is still wanted. It projects and compiles eight sources, checks the Phase 11/V1/V1.1 baseline, audits exact markers and restores source/config snapshots on failure.

V1.2 changes presentation only:

- dropdowns span the combined Access/Invite HUD width;
- the container and rows are borderless with shared-theme gradients;
- row height matches the live HUD buttons;
- access modes and Invite receive configurable icons with glyph fallbacks;
- chevrons reflect open/closed state.

It preserves the V1.1 authoritative commands, saved schema, invitation bounds, Cash/Settings behaviour and `EnableVisitors=false` gate.

## V1.2 Verification

After an optional V1.2 install, restart Play and verify:

1. Access and Invite dropdowns span exactly the two-button HUD width on desktop, tablet and phone.
2. Rows have no enclosing dark shell/border and equal the live button height.
3. Access-mode and Invite icons/glyphs appear, and chevrons open/reset correctly.
4. Outside click/tap, selection, management open, menu state and garage exit close the dropdown cleanly.
5. All four access modes persist through close/rejoin.
6. With two players, invite/revoke, duplicate/self rejection and bounded scrolling still work.
7. Cash and Settings remain usable and no management workspace opens from either HUD button.
8. Structure, Decorations, Lighting, Display Cars and drive-in/out remain unchanged.
9. Refresh the full Studio mirror and confirm the V1.2 revision before changing the rollback baseline.

If any check fails, retain or restore V1.1 and repair the same canonical installer. Do not create a V1.2 patch ladder.

## Deferred Work And Risks

- Visitor admission/lifecycle remains intentionally disabled. `GarageInteriorService_Active` still contains an older in-memory visitor/access path; a future High-Risk visitor phase must explicitly transfer admission, destination/session, teleport and return ownership rather than enabling two systems.
- New offline username search/lookup is deferred. Persisted offline invite IDs remain visible for revoke.
- The broader architecture/performance hardening audit identified future work around multiplayer cosmetic state, per-frame configuration/debug work, mobile HUD layout, polling/lifecycle cleanup, VFX budgets, catalogue virtualisation and client presentation ownership. These are not submission blockers while the current prototype remains stable.
- The reusable new-system readiness audit is deferred until real system work identifies high-signal checks worth automating.

## Mandatory Future Workflow

New chats must read:

- `AGENTS.md`
- `docs/00_START_HERE.md`
- `docs/06_current_known_issues.md`
- `docs/07_patch_history.md`
- `docs/12_continuous_improvement_workflow.md`
- `docs/13_efficient_feature_delivery_protocol.md`
- `docs/14_new_system_readiness_standard.md` for new systems or substantial expansions
- `docs/15_new_system_contract_template.md` for Standard and High-Risk work
- this handoff for owned-garage continuation

The assistant selects Fast, Standard or High-Risk, derives the contract and applies it for the duration of the task. Keep Fast Lane fast; do not use a small diff to bypass server authority, saved-data, economy, reward, ownership or lifecycle safeguards.

## Repository Hygiene

- Commit `c46ead4` already contains the confirmed Studio mirror, owned-garage baseline and readiness workflow on `origin/main`.
- `docs/studio-full-export-paste.txt` remains local transport data and must not be committed.
- A documentation-only handoff update does not require another Studio export.

