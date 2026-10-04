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

## Extension to all six cockpits (2026-10-04)

Oscar confirmed the two pilot cars in Play and asked for the other four in game ("ok lets get them in game now"). Same place (Backup v2 only), same lane (High-Risk: 24 more saved ModuleIds), same decisions D1 to D16, now read for every kit. What changes:

| # | Now |
|---|---|
| D1 | Asset `121164261170819` ("Space Racers Exotic cars") replaces `112592679936648`. It holds all six cars: 560 MeshParts. Car letters: A `exotic_05`, B `exotic_02`, C `exotic_01`, D `exotic_03`, E `exotic_04`, F `exotic_06`. Cars A and B are re-exported from unchanged source (`mesh/cars.py`). |
| D3 | `fileOffsetX` is 0, 20, 40, 60, 80, 100 for A to F. |
| D6 | 24 more ModuleIds, same pattern, for N in 1, 3, 4, 6: 36 new ids and 144 modules in total. |
| D8 | Every cockpit declares no default for `SidePods`, `FrontBumper`, `RearBumper`. Those 18 modules stay primitive. |
| D9 | Stock PI on target for all six (220, 390, 540, 675, 800, 938). |
| D13 | Seat overrides for all six: driver `[-1.5, -0.1, 0.45]`, passenger mirrored; `exotic_06` uses X 1.1 (narrow canopy). None is measured in Play. |

This section supersedes the earlier text wherever the two disagree: the Goal and "Not in scope" lines that say kits 01, 03, 04 and 06 do not change, the builder rule that asks for proof of that, and the old asset id in the regenerate command (now `py -3 scripts/exotic_category/mesh/make_mesh_data.py 121164261170819`). `balance/report.md` and `stage_b/README.md` still word the mesh kits as "two cockpits" and "twelve ids" in places; the numbers in them are current.

Recovery to the two-car state (content hash `4d735c74...`): build `scripts/exotic_category/stage_b` at commit `68b3ed0` and APPLY that build. The old asset `112592679936648` stays in Oscar's inventory for that.

Asset hygiene, checked in Studio on 2026-10-04: the 560 MeshParts of `121164261170819` have a MeshId and no children, TextureID, MaterialVariant or attributes. The old asset still loads (189 parts).

Accepted risks added by the extension:
- Fitting the three empty slots with own-kit parts raises PI inside the tier on every cockpit: 220 to 244 (E), 390 to 406 (D), 540 to 550 (C), 675 to 680 (B), 800 to 802 (A), 938 to 938 (S).
- On `exotic_01` the Rear Bumpers of the six kits differ by 1.14 PI unrounded (limit was 1.0); shown indices stay within 1. `test_balance.py` records the wider limit for that case only.
- Stock socket counts: 15 on every cockpit except `exotic_02` (17, the recorded exception). Full-kit boosts carry up to 4 sockets.
- The primitive geometry of kits 01, 03, 04, 06 (cockpits and core/stock-body modules) is no longer installed. The 24 new ids are one-way in the same sense as the first twelve.

## Body parts behave like core parts (2026-10-04)

Oscar, after testing in Space Racers v3 (93959280828322): Nose and Tail modules "need to be locked until you buy the car, like the engine etc modules"; "if any other modules are not behaving like the engine modules in this way then fix"; "organised by price like the engines"; "the higher tier vehicles need to have more expensive body panels, aligned with engines"; slots renamed and reordered. Lane: **High-Risk** (economy and purchase rule). No ModuleId, SlotId, cockpit id or saved field changes. This section supersedes D7 (trim prices) and the INTERFACE.md rule "body modules: open to any Exotic owner, Price only".

| # | Decision |
|---|---|
| E1 | Every Exotic body module (all six body slots, base and `_GT` / `_EVO`) carries `SourceCockpitId` = the cockpit of its kit, and `SourceCockpitDisplayName` as core modules do. The existing purchase rule then locks it until the player owns that cockpit. It carries no `PurchasePrice`, `VariantName` or `VariantOrder`. Fitting an owned part to another Exotic is unchanged. |
| E2 | Prices of the three stock body slots (`FrontBody`, `RearBody`, `RearSpoiler`), per kit, from the kit's core variant price V (the `Price` of its Lightweight and Power core modules: 6,000 / 18,000 / 52,800 / 168,000 / 528,000 / 1,500,000): base part `Price` = V / 4; `_GT` = V / 2; `_EVO` = V. (Revised the same day: a `Price` of 0 on a module with a `SourceCockpitId` makes the server charge 12% of the cockpit price for a copy, `GarageCatalogLookup.modulePurchasePrice`, which would have priced the base part the same as EVO and listed it after GT. The first copy still comes with the car.) `NeonPrice` unchanged. The three hidden slots (`SidePods`, `FrontBumper`, `RearBumper`) keep their prices. |
| E3 | Slot labels (slot `DisplayName` and `RailLabel`, and the `DisplayName` attribute of the module type folder; folder names do not change): `FrontBody` "Front Body", `RearBody` "Rear Body", `Engine1` "Front Engine", `Engine2` "Rear Engine", `Stabilisers` "Drift Thrusters", `Boost` "Overdrive". `RearSpoiler` and the hidden slots keep theirs. |
| E4 | Slot `Order`: FrontBody 1, RearBody 2, Engine1 3, Engine2 4, Stabilisers 5, Boost 6, RearSpoiler 7, then FrontBumper, RearBumper, SidePods (8 to 10). |
| E5 | Stats, upgrade paths, ratings, stock PI targets and every id are unchanged. Piercer is unchanged. |

Review (`delivery-reviewer`, 2026-10-04): approve with conditions, both met here.

- **Recovery.** Before: commit `8b8bd63`, content hash `51e7eb79...`. After: content hash `4b9eae84...`. To go back, build `scripts/exotic_category/stage_b` at `8b8bd63` and APPLY that build in place. **Never run ROLLBACK in v3:** it removes the whole Exotic category, and v3 saves profiles that own Exotics. The older gate line "AUDIT, APPLY, ROLLBACK, APPLY" applies to a no-save place only.
- **What the lock gates (read from the server sources).** Purchase only (`buyModuleInstance` and the legacy `BuyModule`). Equipping an owned part on another Exotic, default grants on buying a car and the catalogue are unchanged. The charge is exactly `Price` because every body `Price` is above 0.
- **Verification plan.** After APPLY: installed hash `4b9eae84`; a second AUDIT reports nothing to apply; attributes read back on a base, a GT, an EVO and a hidden-slot module and on a slot folder; post-install checks. In Play (spends real Cash on a real profile, so it is Oscar's test or needs his go-ahead): a part of an unowned car is refused with Cash unchanged; a part of an owned car debits exactly `Price`; a new Exotic comes with its three stock parts; an owned part fits another Exotic; the shop lists locked cards last and base, GT, EVO in price order; the rails read Front Body, Rear Body, Front Engine, Rear Engine, Drift Thrusters, Overdrive, Wing.
- **Accepted, for Oscar to confirm.** No refund or top-up for parts bought at the old prices. Prices fall on kits 01 to 03 and rise up to 14 times on kits 04 to 06. GT and EVO body parts have the same stats as the base part, so the price buys the look. Hidden-slot parts are locked too and keep their old prices.

UI side (separate guarded installers under `scripts/exotic_category/ui_*`, client display only): the shop list breaks ties by `Price` before id, so a part's standard, GT and EVO versions read cheapest first; the Build and Customise rails put Front Body and Rear Body first.

## GT and EVO body parts earn their price (2026-10-04)

Oscar, after confirming the section above in Play: give GT and EVO body parts a stat benefit ("upgrade what makes the most sense ie aero, lightness etc. since these are body panels"), use GT and EVO as the version names on engines too, and tidy the leftover old names. Lane: **High-Risk** (balance). No ModuleId, SlotId or cockpit id changes. Recovery: before = commit `6e86683`, content hash `4b9eae84...`; build `stage_b` at that commit and APPLY in place. Never ROLLBACK in v3.

| # | Decision |
|---|---|
| F1 | `_GT` and `_EVO` of `FrontBody`, `RearBody` and `RearSpoiler` add stats to their base part. Front Body: `Downforce` and `SteeringResponse`. Rear Body: lower `Weight` and a little `EngineOutput` (cooling). Wing: `Downforce` and `LateralGrip`. EVO adds twice the GT step. Base parts, hidden-slot parts, core modules and cockpits do not change. |
| F2 | Size. On its own cockpit each GT part is strictly better than its base and each EVO strictly better than its GT (at least 0.3 PI unrounded per step). A full set of three EVO parts on a stock car adds between 3 and 8 PI where the tier has room. Where a stat is pinned at its technical limit on a cockpit (for example `Weight` at 60), the step uses the part's other stat so the rule still holds. |
| F3 | Tier safety, hard requirement. Every existing tier proof must hold with the GT and EVO parts of every kit included as options in every body slot (a player may fit any owned part to any Exotic): stock tier, the full-body build, and the highest-build and ceiling analyses. If a tier has too little room for F2, shrink the step for that kit and say so; never raise a ceiling past the tier. |
| F4 | Version naming on body parts: `VariantName` is "Standard", "GT" or "EVO" and `VariantOrder` 10, 20, 30, as core modules have them. `CardTitle` is the base part name on all three (the card then reads name plus version tag, like an engine card). `DisplayName` and `ModuleName` keep the " GT" / " EVO" suffix. This relaxes E1, which forbade both attributes. Still no `PurchasePrice`. |
| F5 | Leftover names. `CountLabel`: FrontBody "Front Bodies", RearBody "Rear Bodies". Kit names become the car names (Stinger, Zephyr, Aurora, Endura, Rosso, Seraph) in the spec generator, `ids.json`, the balance table and INTERFACE.md; the body module `Tier` attribute, which carries the kit name, follows. |

### Review and recovery (delivery review 2026-10-04: approve with conditions)

- **Recovery.** Before: commit `4c947cd` (or `6e86683`; the commit between them touches only `ui_variant_labels`), content hash `4b9eae84...`. After: content hash `b2f4b211...`. To go back, build `stage_b` at the before commit and APPLY that build in place. **Never ROLLBACK in v3.** `stage_b/out/installer.lua` is whichever mode `refine.py` built last (ROLLBACK): run only `full_audit.lua` and `full_apply.lua`, and check the `mode` in the header first.
- **Rosso margin.** The tier is read from the shown (rounded) index, so S starts at 849.495. The exotic_05 ceiling moves from 846.49 to 848.12: **1.38 PI of room** (3.00 before). Any later stat addition worth about 1.4 PI at that ceiling makes a maxed Rosso an S car. The ceiling covers every body part of every kit in every body slot and every upgrade allocation, with own-family core modules; another car's core modules on a lower cockpit were already outside it (report.md).
- **F2 exceptions, for Oscar to accept.** Kit 5 (Rosso): three GT parts +1.03 PI, three EVO +2.04 (target was 3 to 8). Kit 6 (Seraph): three GT +0.29, three EVO +0.58, steps of 0.08 to 0.13 PI. Both are held down by the Rosso ceiling, because kit 6 parts fit a Rosso.
- **On the road (VEH-01, existing issue).** The on-road index double-counts some module stats (about +16 on a Rosso, fitted estimate). A maxed Rosso already read S on the road before this change; the trims add about 2 to 3 PI there.
- **Server effect.** Only `instanceRating` changes: when an equipped part moves to another vehicle, the spare that backfills is now base, then GT, then EVO (before: instance id). Nothing is refused on rating. No saved stat snapshot exists, so owned GT and EVO parts improve in place; prices are unchanged.
- **Verification plan.** After APPLY: installed hash `b2f4b211`; a second AUDIT reports nothing to apply; attributes read back on a base, a GT, an EVO and a hidden-slot part (`VariantName`, `VariantOrder`, `CardTitle`, `Tier`, the two stats); `CountLabel` on the FrontBody and RearBody slot folders; post-install checks; Play starts clean. In Play (Oscar): the rating rises base to GT to EVO; a Rosso with three Seraph EVO parts still reads A; cards read name plus Standard/GT/EVO in price order; the on-road index of a high Rosso build; moving an equipped part backfills with the base spare.

Core modules keep `VariantName` "Lightweight" and "Power" (game code reads those words). The garage shows them as GT and EVO through a display map in config (`VariantLabels_exotic` on `Config.UI.GarageReplacement`; guarded installer `scripts/exotic_category/ui_variant_labels/`).

## Builder rules

- Write only under `scripts/exotic_category/stage_b/`, `scripts/exotic_category/balance/`, and `scripts/exotic_category/refine.py` if a step must change. Do not edit `mesh.json` by hand (re-run `py -3 scripts/exotic_category/mesh/make_mesh_data.py 112592679936648` if its generator needs a fix, and say so).
- Never touch Studio. Never run Git. Never `require` a gameplay module.
- Piercer behaviour and kits 01, 03, 04, 06 must not change: prove it (same generated content for those kits before and after, apart from the content hash and catalogue revision).
- Keep each file's existing style. Keep edits minimal. Public strings are ASCII, UK English.
- Do not weaken a test to make it pass. Where a test encodes "ten slots / six body defaults / 108 modules", update it to the per-cockpit truth in this contract.
