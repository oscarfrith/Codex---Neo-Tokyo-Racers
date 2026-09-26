# Patch History

Recent deliveries, newest first. Entries before September 2026 live in [the archive](history/patch-history-2026-05-to-2026-08.md).

## 2026-09-26 - GPS route guide installed (v2)

Road graph generated from the minimap artwork: v2 blockout roads and spawn markers describe an older, larger layout. Pipeline: read-only EditableImage export of the four tiles, then road-pixel mask, closing/opening, thinning, junction tracing, spur pruning and pixel-to-world calibration; 309 nodes and 475 edges. New RoadRouting (pure A*), RoadGraphData and RouteGuide (client owner and minimap renderer). Clicking the minimap opens ROUTE GUIDE; the race browser gets SET ROUTE; the chip shows destination and distance; routes re-plan when off-route and clear on arrival. One canonical installer (AUDIT/APPLY/ROLLBACK) verified apply, rollback and re-apply. Pure tests 28/28; agent-verified desktop play (modal, race browser, re-plan, arrival, driving). Mobile runtime untested (ROUTE-01). [Reference](route-guide-system.md), [verification](../scripts/route_guide/verification.json).

## 2026-09-26 - Street Life RP features (parallel build)

Built with four parallel agents, each in its own folder under scripts/activities/, and one integrator. Contract: [activities-contract](architecture/activities-contract.md). New generic tool: scripts/feature_installer.py (spec-driven AUDIT/APPLY/ROLLBACK).

- **Foundation:**
  - ActivityService (one activity per player, cleanup watchers, ActivityInvoke through Core.Net).
  - ActivityPayout (the only Cash/XP path; job hourly ceiling).
  - ProgressionService (Driver Rank: additive profile.Progression; rank-up Cash via RankReward).
  - ActivityClient (ActivityHud: job strip, offers, countdown, beacons, JOBS panel, rank-up card).
  - HUD: rank strip, JOBS button and a PASSENGERS setting (profile.Settings).
- **Courier:** 3 hub pads; Standard, Hot and Fragile runs; anti-teleport check; JobPayout.
- **Passenger seats + Sky Taxi:**
  - Passenger seat: a massless plain PassengerSeat. The car's mass is unchanged with an NPC aboard.
  - Fares: NPC fares, plus player taxi requests.
  - Pay: TaxiFare, with a driven-distance plausibility check.
- **Garage visits:**
  - Admission: same server, owner inside, on foot, using the owner's saved access mode.
  - Visitors are ejected when the owner leaves.
  - The browser gets a VISIT tab.

Each feature went through a delivery-reviewer pass with its blockers fixed, then APPLY/ROLLBACK/APPLY, pure tests (foundation 18, courier 58, taxi 52, visits 78), and a single-client Studio play check with synthetic movement.

Two-player flows remain for Oscar to test: passengers, player taxi requests, duels and visits.

Street Duels is integrated separately.

## 2026-09-26 - Minimap follows the character; north arrow removed

User-confirmed the rotating minimap, then asked for rotation by the character/vehicle facing and no north arrow. FreeRoamMapPlayerMarkers now defaults to MapRotationMode Subject and MapNorthArrowMode Hidden (new mode), and config was set to match. Agent-verified: map rotation equals character heading independent of camera; arrow up; no north arrow.

## 2026-09-26 - Rotating minimap; Studio target moved to Space Racers v2

Oscar moved the working place to Space Racers v2 (71491191583884); its sources matched the last v1 capture plus the CameraService commit. Capture tooling now accepts v2 (v1 stays valid for historical records). Installed the rotating free-roam minimap ([design 10.1](design/street-life-update.md#101-rotating-minimap)): the Minimap container is a CanvasGroup so rotated content clips to the box and rounded corners; a MapRotator turns the unchanged pan carrier by the camera heading; the north arrow orbits the rim; other-player circles rotate with the map; the desktop Settings MINIMAP control now sets a session MinimapMode (ROTATE / NORTH UP). Tunables on Config.UI.FreeRoamMapPlayerMarkers: MapRotationMode, MapRotationResponse, MapNorthArrowMode, MapNorthOrbitInset. Agent-verified on desktop (on foot, driving, toggle, no errors); mobile runtime, two-client markers and low-end CanvasGroup cost remain open (MAP-02). [Verification](../scripts/minimap_rotation/verification.json).

## 2026-09-26 - Handoff for feature work

User confirmed the architecture programme is working. Added the [Studio testing playbook](architecture/studio-testing-playbook.md), [Project 12 comparison](architecture/project12-comparison.md) and the new feature checklist; updated the new-chat prompt and /start. Documentation only.

## 2026-09-26 - Architecture P7: CameraService installed

Driving camera and sprint now request FOV/zoom through Core.CameraService (validated priority stack). Rendered Play comparison against a same-session baseline: identical driving/sprint/exit values; fixed on-foot FOV stuck at 95 after sprint -> drive -> exit; suspend/resume, respawn and disabled-sprint-FOV edge cases clean. Other camera writers remain for a later phase. [Evidence](../scripts/architecture/p7/verification.json).

## 2026-09-26 - Architecture programme from the Project 12 comparison (P1-P6, P8, P9 installed; P7 prepared)

Nine-phase programme after a read-only review of the team game Project 12. Installed and Studio-verified: shared Core library (Signal, Tags, ConnectionScope, ConfigReader); Core.Net guard on all 12 client remotes; RACE-01 RaceIntegrity (Log mode); MoneyService single debit point (12 sites); GarageServer split into eight verbatim factory modules (2,767 -> 1,121 lines, 18-step golden replies identical); FeatureFlags, AnalyticsServer and an inert save-first ReceiptProcessor; retirement of four dead remotes, the legacy DriveInCustomisationSession event and five client-unused legacy actions. Every High-Risk phase was reviewed by the delivery-reviewer before APPLY; each has before/after captures and AUDIT/APPLY/ROLLBACK/APPLY evidence. P7 CameraService is reviewed and packaged but not installed (Studio viewport not rendering). ECON-01 and PB-01 recorded. [Programme reference](architecture/architecture-programme.md).

## 2026-09-26 - Camera NaN (CAM-02) and detached-button retention (PERF-06-A) fixed

Reproduced CAM-02 via API exit/re-entry; normal UI flows alone did not trigger it. Root cause: DrivingClient computed forces from an anchored parked vehicle (infinite AssemblyMass) and left NaN VectorForces that threw the vehicle to NaN on unanchor; DrivingCameraClient latched the NaN into zoom bounds. DrivingClient now holds zero force while anchored/non-finite; DrivingCameraClient rejects non-finite speed/distance/FOV/zoom. PresentationAudioClient now releases button bindings when a button leaves PlayerGui. Three existing sources changed through guarded delivery (AUDIT/APPLY, exact before/after captures). Verified in Studio: 0 NaN/clamp errors across API cycles, normal UI driving/exit/re-entry and time-trial release; retained TextButtons 56 to 0 in a comparable session. DRIVE-01 user-confirmed. Device, soak and multiplayer gates remain open. [CAM-02 evidence](../scripts/cam02/verification.json), [PERF-06-A evidence](../scripts/perf06a/verification.json).

## 2026-09-26 - Continuous lighting user-confirmed

User reviewed the V6 horizon/moon refinement and confirmed the lighting "all looks good for now". Documentation only; no Studio changes. Device, low-graphics, streaming/retention and two-client checks remain open under LIGHT-01.

## 2026-09-26 - Primary assistant switched from Codex to Claude Code

Workflow/repository change only; no Studio, gameplay, source or saved-data changes. Added CLAUDE.md (imports AGENTS.md so rules stay single-sourced), .claude/settings.json permissions, .claude/commands for the follow/suggest/audit/continue/handoff routing plus capture, debug, design and commit helpers, and a read-only delivery-reviewer subagent. Documented the Roblox Studio built-in MCP tool mapping and rules in [Claude Code setup](architecture/claude-code-setup.md). Split entries before September 2026 into [the archive](history/patch-history-2026-05-to-2026-08.md). Added [docs index](README.md). Read-only MCP connection check: Space Racers v1, Edit, 168 inventoried sources.

## 2026-09-23 - Brighter horizons, softer moon glare and five-second holds

V6 user-confirmed overall. Lifted warm exposure/post/Decay, lowered excessive twilight/night glare, enlarged sun 6 to 9 and shortened warm holds to five real seconds. Thirteen existing attributes and one Sky property changed; no source or object changes. Numerical 58,383 assertions, selected runtime targets and visual comparisons, normal startup, 122-second daytime observation, guarded reversal/reapply and exact before/after scope pass. Original artwork/recovery, owners and pre-existing Edit rays preserved. No full-duration/device acceptance, migration rerun or publish. [Delivery evidence](architecture/lighting-horizon-moon-handoff.md).

## 2026-09-23 - Twelve-minute cycle, larger sun and strong horizon rays

V5 user-confirmed. Set cycle to 720 seconds and sun size 4 to 6; raised warm/day rays to 0.2/0.07 with spread 0.9. Following user clarification, full ray strength now includes both horizons with smooth fades in adjacent twilight. One pure evaluator source, ten attributes and one Sky property change; pre-existing Edit ray settings and all other selected state preserved. Numerical 58,389 assertions, normal startup, eight live horizon/night targets, 122-second actual-speed sunset observation, clock-rate check and guarded refinement reversal/reapply pass. No full 12-minute observation, installed migration rerun or publish. [Delivery evidence](architecture/lighting-twelve-minute-handoff.md).

## 2026-09-23 - Shorter red/pink/violet sunrise and sunset

User confirmed the orange V4 cycle looks really good. Shortened full warm holds from ten to three test seconds, made the peak redder, and tuned a rose-pink to violet twilight blend with reversed morning colour timing. Twenty existing config attributes changed; no game source, node or sky asset changed. Numerical 58,283 assertions, normal startup, full 122-second observation with no clock jumps/errors, guarded refinement rollback/reapply and exact targeted scope pass. Original shared artwork and Stepped mode preserved. No installed migration rerun or publish. [Delivery evidence](architecture/lighting-red-pink-handoff.md).

## 2026-09-23 - Extended orange horizons and smoother rendering

Strengthened Continuous sunrise/sunset orange, extended full warm holds from two to ten test seconds each, and moved adjacent appearance anchors outward for broader fades. Replaced the single renderer's uneven capped Heartbeat cadence with PreRender updates. Full before/after 122-second observations found no clock reset/competing outdoor context; maximum measured brightness/haze update steps fell 71%/69%. Numerical 58,089 assertions, normal startup, controlled context release, guarded rollback/reapply and targeted scope checks pass. One V3 source and existing config attributes changed; original shared artwork, solar timing and Stepped recovery preserved. Location-specific jumps remain unconfirmed and user visual/device review stays open. No publish. See [delivery evidence](architecture/lighting-orange-continuity-handoff.md).

## 2026-09-23 — Sunset exposure, sky colour and sun refinement

Implemented the approved separate fade controls, mirrored dawn ordering, targeted warm Continuous palette changes, smaller native sun and restrained rays with a smooth night gate. Kept the uniform two-minute clock, six-look timeline, original shared artwork, owners and easy Stepped reversion. Four V2 source revisions and one root attribute; existing Continuous config and sky properties updated through the same guarded canonical installer. 58,013 numerical checks, 122-second runtime observation, invalid-edit recovery, controlled context restoration, full rollback/reapply and eight original Stepped targets pass. Targeted capture verifies expected scope. Sampled pre-sunset views retain sky colour; user artistic review and named device/flow checks remain open. No publish. See architecture/lighting-sunset-refinement-handoff.md.

## 2026-09-23 — Editable solar/look timeline revision

Implemented the approved revision: uniform two-minute solar time, complete original sunrise/sunset/twilight targets at solar milestones, Day/Night holds, cloudless Continuous sky and attribute-based timing/appearance editing. Removed V1 art overrides without changing original presets, schedule, sky assets or owners. Same guarded installer revised and recovery-tested; six endpoint comparisons, 5,817 pure checks, full 122-second runtime loop, live valid/invalid tuning, fresh startup, controlled context handoffs, respawn and all eight Stepped targets pass. Targeted capture confirms five revised V1 sources, three root attributes and 53 added config/sky nodes, with no other captured original changes. Horizon exposure/artistic acceptance and named device/flow/streaming checks remain open. No publish. See architecture/lighting-look-timeline-handoff.md and architecture/lighting-authoring.md.

## 2026-09-22 — Continuous day/night lighting

Implemented the approved continuous cycle with the original eight stages and 900-second timing. One client renderer owns environment presentation; existing interior/dealership controllers supply context. Forward clock anchors and latitude calibration, bounded atmosphere/color/brightness blending and horizon-aware glare preserve smooth outdoor transitions. Streetlights/windows switch at sunrise/sunset as requested. Original presets and Stepped paths remain available via a restart mode switch. One guarded installer adds three modules, updates seven sources and adds five config attributes; no asset/tag/save/schema changes or publish. Numerical 34,688 checks, accelerated cycle, visible normal startup/dealership exit, controlled context overlap, all eight Stepped preset comparisons and full rollback/reapply pass. Exact targeted after capture verifies expected scope. User visuals, owned-garage normal flow, streaming/lifecycle, device and two-client checks remain open; see architecture/continuous-lighting-handoff.md.

## 2026-09-22 — Workflow Phase 4 reusable validation and handoffs

Added scoped normal-start/transition/error/cleanup/device/load/save recipes and evidence init/check/handoff tooling. Fifteen focused tests pass, including rejection of API/UI, simulator/device, insufficient-load and no-save/persistence substitutions. Artifact hashes, deferred reasons and next actions keep handoffs reviewable. Reused existing runtime/capture helpers; refreshed laptop prompt to follow current status. Repository-only changes, no Studio writes, gameplay changes or mirror refresh. All four workflow phases delivered; performance acceptance and existing issue gates remain open. See architecture/validation-and-handoffs.md.

## 2026-09-22 — Workflow Phase 3 proportional delivery

Added capture-backed guarded source/primitive-attribute delivery with read-only audit, exact preflight, compile, repeat and rollback. Dedicated migrations retain broader recovery contracts. Ten Python and ten pure-table Studio Luau cases pass; 21 capture tests pass. Live generated audit and before/after inventory prove zero changes across 165 sources. No game code, physical state or full mirror changes. Assistant-operated workflow replaces ordinary manual delivery steps. See architecture/proportional-mcp-delivery.md.

## 2026-09-22 — Workflow Phase 2 targeted capture

Added read-only scoped capture/compare with versioned deduplicated source blobs, complete nine-service source inventory, selected property/tag coverage and atomic evidence publication. Adapted catalogue/preview and naming checks; historical input is explicit. Live source/config/vehicle captures pass, repeated vehicle delta is zero, all 165 sources match retained baseline, and 21 scoped tests pass. Retained full-pipeline tests pass on rerun with initial transient-lock count sensitivity recorded. Routine full mirrors retire; deliberate full checkpoints remain. No gameplay/Studio state/full-mirror changes. See architecture/targeted-capture-workflow.md.

## 2026-09-22 — Workflow Phase 1 documentation consolidation

Centralised current status and delivery procedure; shortened AGENTS and lesson startup reading, separated open issues from resolved milestones, replaced stale prompt/tool instructions with maintained links, and removed repeated topic status banners. Preserved prior workflow text as history. Recorded the user's general gameplay confirmation without closing camera/resource/device/persistence gates. No Studio, scripts, mirror or gameplay changes; full-capture policy remains until workflow Phase 2.

## 2026-09-22 — Begin performance Phase 6 acceptance

Validation only; no installed code/assets/config changes. Twenty sandbox API cycles (140 successful responses) and normal startup pass, but start-screen state remained active: these do not count as full gameplay/UI cycles. CAM-02 reproduced. Scene analysis found 111 additional unparented TextButtons attributed to PresentationAudioClient; retention cause/plateau remains unproven. User has neither iPhone 7 nor isolated multiplayer place available. Phase 6 stays open for camera/resource investigation, real UI/route/input tests, device/15-player soak and separate persistence release evidence. Refreshed mirror 13:14:39: exact Phase 5 parity, 165 sources/44,465 nodes/276,087 properties; projections fresh. See architecture/performance-phase6-validation.md.

## 2026-09-22 — Install performance Phase 5 catalogue transport reuse

Seven sources changed and GarageCatalogClient added. GarageServer builds its unchanged public catalogue once per session; validated KnownCatalogRevision omits unchanged catalogue payloads. Existing callers receive detached catalogue copies plus fresh profiles. Eight matched samples: warm JSON 177,251 -> 3,956 bytes (97.8% smaller); typed catalogue length/checksum unchanged. Observed round-trip timing is recorded separately, not isolated CPU or compressed-wire proof. Compile/repeat/rollback/reinstall/fault recovery, 21 transport/guard checks, normal startup and sandbox purchase/paint/spawn PI551/C, exit/re-entry/despawn/preview/upgrade pass. Cash remains fresh after both mutations. Existing CAM-02 persists. Mirror 13:01:09: 165 sources, 44,465 nodes, 276,087 properties, zero unexplained differences; generated preview/data freshness pass. User/device/phase-6 acceptance pending; no publish.

## 2026-09-22 — Install performance Phase 4 vehicle preview projection

Moved original Assets.Vehicles intact to ServerStorage; generated 2,105-instance VehiclePreviews excluding 333 upgrade folders and their 1,479 attributes. Eight navigation consumers changed; all physical/paint/VFX properties and gameplay calculations retained. Exact preflight/compile/repeat/rollback/reinstall/injected recovery pass. 749,912 calculation comparisons still pass against relocated templates. Normal startup, sandbox purchase/paint/spawn PI551/C, exit/re-entry/despawn, live 285-descendant preview and Velocity upgrade at $6,050 pass. Existing CAM-02 persists. Mirror 12:47:08 verifies 164 sources, 44,464 nodes, 276,087 properties, both generated outputs fresh and zero unexplained changes. RS descendants 4,313 -> 3,980. Mesh/texture cost unchanged; measured join/memory/device benefit remains open. User playthrough pending; no publish.

## 2026-09-22 — Install performance Phase 3 catalogue separation

Generated four immutable-data/access/index modules from existing authoring attributes; changed six shared/client consumers to remove repeated template scans while preserving one calculator and all physical content. Exact preflight, compile, repeat-install, rollback/reinstall and injected failure recovery pass. Pure before/after tests: 6 cockpits, 116 modules, 5,380 allocations, 749,912 comparisons, including owned profile/selection/upgrade previews. Normal startup and sandbox purchase/paint/spawn/exit/re-entry/despawn pass; PI551/C retained. Drive-in preview pad/ownership logs pass; visual acceptance pending. CAM-02 persists. Mirror 12:31:08: 164 sources, 42,359 nodes, 267,539 properties, zero unexplained differences and fresh projected catalogue. Added bounded Windows rename retries after safe import failures; 11 pipeline tests pass. Physical templates remain replicated; no FPS/download reduction claimed. User playthrough pending; no publish.

## 2026-09-22 — Install performance Phase 2 server-only storage

Moved six reviewed roots (three modules/three config groups, 14 instances) intact to ServerStorage; added four destination folders. Updated nine service literals in six server callers, with token proof and no gameplay/config-value/client/physical changes. One canonical installer supports exact preflight, compile, audit, idempotency and repository-backed rollback. Repeat/rollback/reinstall and injected transaction failure recovery pass. Normal startup 26 server/39 client/four skipped; sandbox purchase/paint/spawn/exit/re-entry/despawn and performance writer pass. CAM-02 camera errors recur, unchanged. Final mirror 12:07:02: 160 sources, 42,355 nodes, 267,539 properties; exact expected source/full captured property parity, zero unexplained changes. ReplicatedStorage descendants 4,323 → 4,309; no FPS claim. User playthrough pending. See architecture/performance-phase2-server-storage.md. No publish.

## 2026-09-22 — Performance Phase 1 local audit and initial baseline

User approved Phase 1 and selected iPhone 7. Added repeatable read-only mirror dependency analysis, bounded Studio runtime sampler and sandbox catalogue-response sampler. Reviewed six server-only move candidates (14 instances, 20,805 source bytes), transitive shared dependencies and 50 config groups. Captured four eight-second Studio windows and five GetInitial responses; catalogue is 173,361 JSON bytes per result, not measured wire size. All startup owners ready; no source/config/asset changes. Phone, controlled route/join, profiler/network attribution, 15-player and soak evidence explicitly deferred. Final mirror 11:13:49 passes exact cleanup Phase 4 parity. Phase 2 unimplemented. User authorised commit/push; no production publish.

## 2026-09-22 — Confirm cleanup Phase 4; propose performance programme

User reports successful testing, commit and push. Mark all four cleanup phases confirmed; protected physical staging/Archive decision and release gates remain separate. Refreshed mirror at 11:00:13 passes all 160 sources and exact expected 42,351 nodes/267,539 properties. Read-only MCP inventory finds 4,323 ReplicatedStorage descendants, including 2,437 vehicle asset and 1,480 config records. Proposed six deliveries in architecture/performance-and-replication-plan.md: measurement, server-only moves, catalogue separation, preview/template delivery, measured runtime/network optimisation and device/streaming acceptance. No gameplay, source, hierarchy or config mutation. Lesson: client consumers and generated public data determine replication boundaries; folder names/counts alone do not prove savings or unused content.

## 2026-09-22 — Cleanup Phase 4 finalisation

User approved Phase 4 and explicitly accepted preserving arrival differences: 628 arrow CFrames and 66 thumbnail-model records. Installed one exact-source cleanup: 61 bodies, 179 private identifier mappings, patch-stamp comment removal and diagnostic naming; token checks preserve executable logic and non-diagnostic contracts. No instance, asset, tag, attribute or physical changes. Generic snapshot exporter/receiver/importer replace active old entry points; originals archived unchanged. Read-only live/local audits added, current docs consolidated and old instructions archived.

Compile, repeat-install, rollback/reinstall, normal startup (26 server/39 client/four skipped), sandbox purchase/paint/spawn/exit/re-entry/garage state/race validation/TT start-cancel pass. Nine pipeline tests and final mirror verification pass: 2026-09-22 10:25:06, 160 sources, 42,351 nodes, 267,539 properties, zero unexplained changes. CAM-02 reproduced as pre-existing; no camera change. User full playthrough and protected staging/archive decision remain open. Canonical installer: scripts/roblox_cleanup_phase4_finalise.lua. No publish.


## 2026-09-05 — Fix Windows snapshot permissions blocking GitHub Desktop

The importer staging directory used tempfile.mkdtemp, whose Windows private ACL was retained by promoted mirrors. GitHub Desktop under Oscar could not read manifest.json although the sandbox could. Restored inherited permissions on both mirror roots; changed staging to exclusive UUID-named mkdir with normal parent ACL inheritance. Nine pipeline tests pass, including Windows staging inheritance and rollback-on-promotion-failure. No Studio or mirror content changes; Phase 3 remains user-confirmed. Retry commit with raw paste unchecked.

## 2026-09-05 — Confirm cleanup Phase 3; prepare laptop handoff

User reported all worked well. Locked Phase 3 as confirmed; Phase 4 is next. Read-only live audit and post-playtest mirror refresh at 16:06:57 pass all 160 source hashes, expected hierarchy/property parity and excluded Workspace checks. Added laptop transfer/runbook and new-chat prompt, corrected current owner/handoff status. No gameplay edits or publish. Git commit/push and a saved playable place transfer remain user actions; the mirror is not a full place backup.

## 2026-09-05 — Install cleanup Phase 3 generic naming

Complete cleanup Phases 1 and 2 are user-confirmed. Phase 3 is installed and agent-verified; user gameplay confirmation is pending. Phase 4 remains unimplemented. Current mirror: 2026-09-05 15:59:57, 160 sources, 42,285 nodes and 266,840 properties, with exact expected source/hierarchy/property parity. The two lighting-tag renames on 62 enumerated WIP objects are approved and installed. Protected staging/archive disposition remains pending. Canonical installer: scripts/roblox_cleanup_phase3_generic_naming.lua. Renamed World, Assets, Remotes, feature configs and technical tags/attributes; retired 210 nonphysical records, preserved physical content and stable external IDs. Controlled visible-client comparison reproduced the camera NaN/clamp issue on the exact Phase 2 baseline and Phase 3; left it unchanged as CAM-02. Audit/idempotency/rollback, six contract tests, feature smoke and full final mirror parity pass. User gameplay checkpoint pending. Lesson: equivalent runtime conditions resolved a misleading apparent regression.

## 2026-09-05 — Build cleanup Phase 3; restore baseline for camera comparison

Phase 3 installer built and exercised, then rolled back pending an equivalent camera-transition comparison. The two lighting-tag renames on the exact 62 WIP objects are authorised; staging/archive disposition remains pending. Phase 2 is installed and user-confirmed. Restored mirror 2026-09-05 15:52:58 passes all 160 source hashes and complete hierarchy/property parity. See docs/architecture/cleanup-phase3-generic-naming.md. Phases 3 and 4 remain unfinished. Canonical script: scripts/roblox_cleanup_phase3_generic_naming.lua. Compile/audit/idempotency/rollback/reinstall, physical/WIP invariants and six local contract tests passed. Sandbox feature smoke reached time-trial countdown, but BaseCamera clamp errors require a controlled comparison. No publish or production save. Lesson: runtime equivalence needs matching client conditions; source parity alone is insufficient.

## 2026-09-05 — Confirm cleanup Phase 2; prepare Phase 3 naming migration

User confirmed Phase 2 worked well and authorised Phase 3. Read-only live/source/compile and refreshed mirror checks pass: 160 sources, full expected hierarchy/property parity, unchanged Workspace at 15:28:27. Inventoried generic hierarchy/configuration migration and discovered two lighting tags shared with 62 excluded WIP objects; asked for a narrow scope decision and staging/archive disposition. No Phase 3 Studio source/hierarchy/tag changes and no installer generated yet. See architecture/cleanup-phase3-generic-naming.md and scripts/cleanup_phase3 evidence.

## 2026-09-05 — Confirm cleanup Phase 1; install Phase 2 canonical ownership

User confirmed Phase 1 working. Installed Phase 2: 323 to 160 sources, 133 forwarding adapters and old code hosts retired, live endpoints moved to feature Runtime folders, GarageUI startup direct and current driving callbacks extracted into DriveSessionClient. Removed unused legacy closure/helpers/alternate execution branches; preserved profile semantics, tuning, UI owners and entire Workspace. Compile, rollback/reinstall, startup and sandbox garage/vehicle/time-trial checks pass. Final mirror 15:14:10 matches every expected source/hierarchy/property record. Full gameplay checkpoint pending; two phases remain. Canonical installer: scripts/roblox_cleanup_phase2_canonical_ownership.lua. See architecture/cleanup-phase2-canonical-ownership.md. Lesson: move runtime endpoints and both readiness producer/consumer paths before retiring script hosts.

## 2026-09-05 — Complete cleanup Phase 1 scaffolding retirement

Installed the authorised first phase: removed 91 unused scaffold/report objects and 15 obsolete root migration attributes, without changing any of 323 gameplay sources or any Workspace content. Removed the exporter's in-game fallback-writing branch; receiver failure now creates nothing. Audit/repeat install/rollback/reinstall, compilation, 26 server/40 client startup with four tools skipped, dealership event, sandbox purchase/spawn/DriveReady/exit and eight pipeline tests passed. Full uninterrupted driving remains user verification. Final mirror 12:36:11 passes exact expected hierarchy and full source parity. Classified staging/archive assets; no physical deletion. Two originally detached historical shortcuts restore nil during explicit recovery. Canonical installer: scripts/roblox_cleanup_phase1_scaffolding.lua. See architecture/cleanup-phase1-scaffolding.md; three phases remain.

## 2026-09-05 — Revised complete cleanup plan (documentation only)

Recorded a proposed four-phase programme replacing the conversational three-delivery proposal: retire scaffolding, complete canonical ownership and remove legacy execution paths, migrate generic hierarchy/config/names, then tooling and final regression. Incorporated the World-only Workspace boundary, protected physical content, no in-game backups/fallback implementations, retained opt-in development tools and stable external data identifiers. Added per-phase gameplay/rollback/mirror gates and a no-unclassified-leftovers completion ledger. No Studio changes or mirror refresh; current installed baseline unchanged. See architecture/complete-cleanup-plan.md.

## 2026-09-05 — Confirm Phase 5; retire reviewed legacy items

User confirmed the final architecture phase and authorised cleanup while protecting models/meshes/parts. Removed 117 code/metadata objects (11 disabled scripts, four unused registry/resolver modules, 16 folders and 86 values) plus 70 obsolete source patch-stamp attributes. Retained opt-in development tools by user request, live adapters, tuning, designer links and uncertain theme/fallback areas. No surviving source changed. One exact-record installer supports AUDIT/INSTALL/ROLLBACK; compilation, repeat install, rollback/reinstall and normal Play startup (26 server, 40 client, four skipped) passed. Full mirror 12:07:40: 323 verified sources, all remaining exported node/property data matches the expected baseline, no physical changes. User cleanup playtest pending. See architecture/legacy-cleanup.md and scripts/roblox_legacy_cleanup.lua. Restore cleanup before older exact-baseline phase recovery.

## 2026-09-05 — Architecture Phase 5 LOD optimisation and handoff

Phase 4 user-confirmed. Replaced the canonical LODClient with a thin owner plus LODRuntime/LODPolicy, preserving live bands/collision semantics and placing tuning in WorldLOD attributes. Fixed recursive missing-proxy lookup, dynamic block/member registration, deferred-removal cleanup and far-clone retention; cached buckets skip unchanged work. Eight isolated tests, normal-client late block/removal/re-entry, startup, 338-source compilation and audit/idempotency/rollback passed. Controlled seven-position CPU trace median 27.37 → 14.11 ms; small registration/idle overhead is recorded, with no FPS claim. All 335 other sources retain parity. Full mirror 11:50:30 verified, raw paste untouched. Added company-facing architecture/workflow handoff and release gates. User final city/streaming playthrough next. Canonical installer: scripts/roblox_architecture_phase5_world_optimisation.lua.

## 2026-09-05 — Architecture Phase 4 client organisation

User confirmed Phase 3 gameplay. Installed ClientBase with 44 explicit entries and migrated 92 implementations to ReplicatedStorage.Modules, preserving old-path adapters and disabled experiments. Reused shared theme reading, extracted legacy preview-input subscription ownership, removed disabled proximity polling, and gated trailer/lighting tools behind Studio plus opt-in config. Existing gameplay/renderers/driving equations remain. Four isolated helper groups, exact audit/idempotency/rollback, 40 completed client startups + four skipped tools, all 26 server startups, sandbox purchase/garage preview/workshop and command/event spawn/exit/re-entry passed. All 336 sources compile; 148 out-of-scope sources retain exact parity. Full mirror 2026-09-05 11:34:22, integrity PASS. User guided gameplay/device test next; Phase 5 remains. Canonical installer: scripts/roblox_architecture_phase4_client_organisation.lua. See docs/architecture/phase4-client-organisation.md for limits and rollback.

## 2026-09-05 — Architecture Phase 3 server organisation

- User confirmed Phase 2 playthrough and authorised continuation. ServerBase now starts 26 explicit services; 41 implementations have canonical ServerStorage.Modules.Game paths with stateless old-path adapters. Disabled historical scripts remain disabled.
- Extracted EconomyServer and runtime/persistent profile filtering. Removed the garage-owned profile cache and garage/racing whole-profile imports; ProfileServer retains the authoritative session, save transport and stable schema/IDs.
- Nine isolated architecture tests passed. All 26 services reached ready; sandbox purchase/reward/paint preserved Cash and vehicle identity, and spawn/exit/re-entry, stale-import rejection and actual snapshot encoding passed. Repaired startup wait/lighting readiness in the same installer.
- Canonical installer: scripts/roblox_architecture_phase3_server_organisation.lua. Audit/idempotency/rollback/reinstall passed, 240 sources compile, mirror refreshed at 11:16:45 and verified. User gameplay acceptance remains pending; no publish or real production data mutation claimed. See architecture/phase3-server-organisation.md.

## 2026-09-05 — Architecture Phase 2 persistence/request safety

- User confirmed Phase 1 worked well and approved continuation. Added ProfileStore transport and GarageRequestGuard around the existing owners; no runtime renames, gameplay balance or asset changes.
- Blocked writable failed-load defaults, pinned no-save sessions, added renewable session leases, serialised revision-aware saves and coordinated closing. Garage hydration waits for authoritative data; generic requests are bounded and checked before expensive work.
- Canonical installer: scripts/roblox_architecture_phase2_persistence_safety.lua. Nineteen isolated tests, live sandbox/remote smoke, exact audit, repeat install, rollback/reinstall and all 195 script compilations passed.
- Refreshed mirror at 10:58:29; only two existing sources changed and two modules added. User gameplay acceptance and isolated published-place save/rejoin remain pending. Drain old profile writers before production deployment. See docs/architecture/phase2-persistence-safety.md.

## 2026-09-05 — Architecture Phase 1 foundation

- Approved company-familiar naming/ownership programme recorded; runtime migrations remain later phases.
- Replaced long current startup/issues pages with compact state and open risks; preserved both original records in docs/history.
- Added a read-only all-source compile audit, frozen source baseline, mirror verifier and failure-oriented tooling tests.
- Extended the existing V2 exporter with property schema revision 3 and fail-closed source reads. Normal HTTP export no longer writes Studio export objects.
- Added validated staged mirror replacement and rollback; raw paste is opt-in and its existing user diff is preserved.
- Gameplay sources, enabled states, settings and saved data were unchanged in Phase 1. Verification details: docs/architecture/phase1-verification.json. User subsequently broadly confirmed everything worked well.
