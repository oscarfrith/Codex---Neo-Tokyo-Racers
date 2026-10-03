# Exotic mesh pilot: garage integration contract

Status: approved in principle by Oscar on 2026-10-03 ("get them in game, replacing the models for 2 of the exotic cars, so I can test them"). Place: **Space Racers Backup v2 (133417340424236)** only. v2 is not touched. Lane: **High-Risk** (new saved ModuleIds, installer change). This file is the interface every builder works to. If it is wrong against the code, say so in your report and build to the nearest correct form.

## Goal

Cockpits `exotic_02` (Curve, round car, mesh car B) and `exotic_05` (Hyper, sharp car, mesh car A) and their modules are built from uploaded mesh parts instead of primitives, so Oscar can buy, customise and drive them in Play. Cockpits 01, 03, 04 and 06 and their modules rebuild exactly as today.

## Not in scope

- No Stage A change: no edit to any game script, catalogue generator, UI, remote, profile field or flag.
- No change to the ten slot ids, to any existing ModuleId, or to the kits 01, 03, 04, 06.
- No new slot. No per-cockpit rail labels (the rail comes from the first cockpit; accepted for this test).

## Decisions

| # | Decision |
|---|---|
| D1 | Geometry source for kits 02 and 05 is model asset `112592679936648`, loaded in Edit mode with `game:GetObjects("rbxassetid://ID")[1]`. It holds one MeshPart per module and paint channel, named `<A or B>_<SLOT>_<TRIM>__<channel>`. Oscar approved the upload (2026-10-03); this is the recorded exception to the contract's "asset tools are not used" clause. |
| D2 | `stage_b/data/mesh.json` (written by `mesh/make_mesh_data.py`, do not hand-edit) lists, for each cockpit and ModuleId, the source part names with channel, centre and size in root space, triangle count, and jet sockets. |
| D3 | File space to root space: turn 180 degrees about Y, then subtract `fileOffsetX` (20 for car B) from X. In Luau: `rel = CFrame.Angles(0, math.pi, 0) * source.CFrame; rel = rel - Vector3.new(fileOffsetX, 0, 0)`. `mesh.json` centres are already in root space and are the check value (within 0.05). |
| D4 | Slot mapping: NOSE to `FrontBody`, TAIL to `RearBody`, FPOD to `Engine1`, RPOD to `Engine2`, STAB to `Stabilisers`, BOOST to `Boost`, WING to `RearSpoiler`. |
| D5 | Trim mapping for the four core slots: STD, GT, EVO to the existing `_STANDARD`, `_LIGHTWEIGHT`, `_POWER` ModuleIds. The three variants now have different geometry. |
| D6 | Body slots get two **new** ModuleIds per slot per kit: `MODULE_FRONTBODY_EXOTIC_0N_GT`, `_EVO`; `MODULE_REARBODY_EXOTIC_0N_GT`, `_EVO`; `MODULE_REARSPOILER_EXOTIC_0N_GT`, `_EVO` for N in 2, 5. Twelve new ids, 120 modules in total. The existing id (no suffix) takes the STD mesh. Oscar confirmed these names on 2026-10-03. |
| D7 | New body modules copy every attribute of their kit's existing module in that slot (same stats, same upgrade paths, same attribute set: do not add `VariantName`), except: `DisplayName`, `CardTitle` and `ModuleName` (the three must stay equal) are the base name plus " GT" or " EVO"; `Price` is base x 2 (GT) and base x 3.5 (EVO), rounded to 100; `NeonPrice` unchanged. |
| D8 | Cockpits 02 and 05 keep all ten `SLOT_` folders. They declare **no** default for `SidePods`, `FrontBumper` and `RearBumper` (those slots start empty). Their defaults are the four Standard core modules plus `MODULE_FRONTBODY_EXOTIC_0N`, `MODULE_REARBODY_EXOTIC_0N`, `MODULE_REARSPOILER_EXOTIC_0N`. The modules `MODULE_SIDEPODS_`, `MODULE_FRONTBUMPER_`, `MODULE_REARBUMPER_EXOTIC_02` and `_05` stay as they are today (primitive). |
| D9 | Stock build for 02 and 05 = cockpit + four Standard core + three default body modules. Its PI must still be within 3 of the target (02: 390, tier D; 05: 800, tier A). The cockpit's raw stats absorb the three missing body modules. |
| D10 | Channel mapping for mesh parts: `primary` P, `secondary` S, `detail` D, `thrust` T, `neon` N (optional neon, as today), `lights` always-on white lamp, `lights_red` always-on red lamp (fixed colour 255, 30, 20; a new code), `glass` G on cockpits and **D on modules** (modules carry no glass). Always-on lamps go in `LIGHTS_AlwaysOn` with `PaintChannel="Lights"`, Material Neon, on **any** mesh module that has them (Engine1 carries the headlights; Boost and RearBody carry red lamps). Part names must still avoid the forbidden words. |
| D11 | Every mesh clone: `Anchored=true`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`, `DoubleSided=true`, `CastShadow` as today's rule for that channel, Color, Material and Transparency from the channel exactly as primitives get them. |
| D12 | Sockets for mesh modules come from `mesh.json` `sockets` (`name`, `position` in root space, `dir` = the way the flame points). Templates as today: `EngineJet_Exotic` for Engine1 and Engine2, `BoostJet_Exotic` for Boost, `StabiliserJet_ExoticLeft` / `Right` for the four stabiliser sockets. Flame runs along the attachment's local +Z; convert `dir` to the orientation convention the existing sockets use. Body modules have no sockets. |
| D13 | Seats: `data/seats.json` gets explicit `overrides` for `exotic_02` and `exotic_05`. Start from driver `[-1.5, -0.1, 0.45]`, passenger `[1.5, -0.1, 0.45]` for both (lower than today because the roofs are lower: tops at 4.64 and 4.23). The integrator measures in Play and corrects the numbers; build the plumbing so a later data-only change works. |
| D14 | Cockpit fixtures (root, hover dust, underglow, lens parts, slot mounts) for 02 and 05: exactly as today. |
| D15 | Content hash and fingerprints must cover the asset id and the mesh part names for kits 02 and 05. Preview parity and signature checks that cannot see a MeshId must not report a false pass: say what they do and do not cover. |
| D16 | AUDIT must load the asset (a read) and fail with a BLOCKER if any part named in `mesh.json` is missing, or any centre differs by more than 0.05. |

## Gates before APPLY (integrator)

`refine.py` green offline; AUDIT with no blockers; `delivery-reviewer` on this contract and the diff; AUDIT, APPLY, ROLLBACK, APPLY; `post_install_checks.lua`; Play test of both cars; targeted capture; `check_projection.py` and `check_catalogue.py`.

## Review and recovery (added 2026-10-03 after the delivery review: approve with conditions)

- **Recovery to the before-state.** ROLLBACK of this build removes the whole Exotic category; it does not restore the primitive install. To return to the primitive Exotic (content hash `5284a9ad...`), build `scripts/exotic_category/stage_b` at commit `b9d1c8a` and APPLY that build (replace in place). Do not amend that commit.
- **One-way for new ids.** A profile that owns a `_GT` or `_EVO` body module keeps that TemplateId if the place goes back to the primitive build; the server warns and skips it. The backup place does not save, so this only matters after a move to v2.
- **Seats on 02 and 05 are generated, not measured,** until `measure_seat.lua` has been run on both in Play and `data/seats.json` updated.
- **Accepted risks.** Stock Curve has 17 jet sockets against a guideline of 16. Fitting the three empty slots raises PI above target but inside the tier (Curve 383 to 407, Hyper 799 to 802). The Hyper tier ceiling is A 846, 3.5 PI below S; the proof covers own-family core modules only.
- **Asset hygiene.** Checked on 2026-10-03: the 189 source MeshParts have no children, no TextureID, no MaterialVariant and no attributes. The installer does not check this itself.

## Builder rules

- Write only under `scripts/exotic_category/stage_b/`, `scripts/exotic_category/balance/`, and `scripts/exotic_category/refine.py` if a step must change. Do not edit `mesh.json` by hand (re-run `py -3 scripts/exotic_category/mesh/make_mesh_data.py 112592679936648` if its generator needs a fix, and say so).
- Never touch Studio. Never run Git. Never `require` a gameplay module.
- Piercer behaviour and kits 01, 03, 04, 06 must not change: prove it (same generated content for those kits before and after, apart from the content hash and catalogue revision).
- Keep each file's existing style. Keep edits minimal. Public strings are ASCII, UK English.
- Do not weaken a test to make it pass. Where a test encodes "ten slots / six body defaults / 108 modules", update it to the per-cockpit truth in this contract.
