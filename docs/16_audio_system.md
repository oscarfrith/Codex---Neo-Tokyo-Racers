# Audio System

**Created:** 2026-07-21  
**Current status:** Phases 1-3 installed/audited and mirrored; tuning/cue expansion generated; asset population and audible verification pending  
**Canonical installers:** confirmed baseline `scripts/roblox_audio_system_v1.lua`, `scripts/roblox_audio_context_phase2.lua`, `scripts/roblox_audio_acoustics_phase3.lua`; next installer `scripts/roblox_audio_vehicle_tuning_and_cues_v1.lua`

## Generated Vehicle Tuning And Cue Expansion (2026-07-22)

`scripts/roblox_audio_vehicle_tuning_and_cues_v1.lua` is the canonical next installer. It is Standard Lane work because it extends connected local presentation and validated external cue replication, but it does not change gameplay authority, persistence, economy or ownership.

```text
Goal: Make vehicle audio fully tuneable and add stable accelerator, drift-duration and boost-resource cues without input chatter or a second driving owner.
Required changes: Add five blank profile layers; condition accelerator presentation; ramp DriftLoop by continuous drift time; play/cancel one recharge one-shot; distinguish boost release, empty and uninterrupted near-full depletion; expose mix/speed/pitch/fade/distance tuning; document config in Studio.
Preserved behaviour: All existing audio attributes/assets, Phase 1 local/external graph routing, Phase 2 contexts, Phase 3 acoustics, driving physics, VFX, UI, camera, bootstrap, customisation, persistence and economy.
Shared components: Existing Audio folders/profile, VehicleAudioCatalog, VehicleAudioController, AudioBusController, state contract/service, MobileDriveInputState and Phase 1 RemoteEvent.
State transitions: Accelerator uses pending-enter/active/pending-release confirmation; drift elapsed resets on exit; recharge latches on actual rising charge and cancels on boost/full; boost depletion queues a bounded validated cue revision.
Device/scale: Existing 15 Hz parameter budget and 8-one-shot cap remain; managed channels allow one accelerator transient, one boost transient and one recharge cue; no new frame loop or continuous network telemetry.
Persistence impact: N/A. Future whole-profile selection still resolves through ResolvedAudioProfileId.
Failure/rollback: Exact anchors must occur once and all projected sources compile before mutation. Failed INSTALL restores source/attributes/descriptions. DISABLE sets VehicleAudioCueExpansionEnabled=false without deleting assets. Master Phase 3 DISABLE remains the complete playback rollback.
Done when: INSTALL/AUDIT pass; assets are assigned; tap/recharge/drift/depletion tests pass locally and in two clients; lifecycle counts remain bounded; mobile profiling passes; full mirror is refreshed.
```

New blank profile layers are `AccelerationEnter`, `AccelerationRelease`, `BoostRecharge`, `BoostEmpty` and `FullBoostSpent`. Every layer—including the original thirteen—retains the same `AssetId`, `Gain`, and `Pitch` attribute contract. `ProfileMasterGain` normalises a complete future package; global local-driver, external-vehicle and one-shot multipliers prevent package assets from forcing per-layer retuning.

Accelerator cues use a confirmation state machine. A short press that never passes `AccelerationEnterConfirmSeconds` is silent. A brief release inside `AccelerationReleaseConfirmSeconds` resumes the active session without another enter/release. One managed `AccelerationTransient` channel prevents stacking, and only confirmed queued cues replicate to external 3D listeners.

`DriftLoop` now begins at `DriftLoopStartGainMultiplier` and reaches full configured gain/pitch at `DriftRampFullSeconds`, shaped by `DriftRampCurveExponent`. No additional network value is required because every listener measures elapsed time from the existing semantic drift transition.

`BoostRecharge` is a driver-only managed one-shot. It begins once per actual rising-charge session after the gameplay recharge delay has already elapsed, cancels through a short fade if normal boost resumes, and optionally stops at full. The audio controller reuses `MobileDriveInputState.BoostPercent`; it does not simulate or own charge.

Normal early release still plays `BoostRelease`. Crossing `BoostEmptyThreshold` after real drain plays `BoostEmpty`. Starting at/above `FullBoostStartThreshold` and continuously consuming at least `FullBoostMinimumConsumedFraction` plays `FullBoostSpent`; `FullBoostReplacesEmpty=true` prevents a cluttered double hit. Only those discrete harmless presentation cues extend the validated Phase 1 payload.

Roblox attributes do not support native descriptions. The installer therefore creates `Descriptions` folders directly under existing `Config.Audio.Global`, `Config.Audio.Quality`, and `VehicleProfiles.GENERIC_STANDARD_AUDIO`. Matching StringValues explain each new global control, all quality controls and every original/new layer attribute without changing the runtime's attribute lookup contract.

## Recommended Three-Phase Plan

1. **Standard vehicle audio foundation** — one standard profile, validated vehicle state, local-driver 2D presentation, other-player 3D presentation, shared mix buses, bounded quality tiers and lifecycle cleanup.
2. **Context music and key-location ambience** — walking and driving playlists plus priority zones for selected interiors/landmarks such as the dealership. This is zone-driven, not one zone per city block.
3. **Acoustics, optimisation and activation** — Roblox-native geometry acoustics for only the nearest important emitters, lightweight interior ambience reverb, low-end/mobile quality controls, readiness checks and guarded activation after approved assets are populated.

Purchasing or applying alternate vehicle sound packages is not part of these phases. The Phase 1 `ResolvedAudioProfileId` boundary is intentionally retained so a future customisation transaction can select one whole profile for a vehicle without rewriting the runtime mixer. The future authoritative customisation/profile owner must resolve that value; the audio client must never decide ownership or purchase eligibility.

## Confirmed Phase 1 Installation Evidence

- The user reported the Edit install/audit passing on 2026-07-21. The captured audit reports six cockpit templates, `0/13` populated assets and `enabled=false`, matching the intentionally silent contract.
- The refreshed `20:36:31` mirror contains 170 scripts, all six Phase 1 sources exactly matching the installer, all six `StandardAudioProfileId` cockpit attributes and the Phase 1 installer revision.
- The mirror now scans `SoundService` and captures all six planned mix groups.
- This confirms installation shape, source and mirror coverage. Audible 1/2-player transitions and mobile performance remain deferred until approved assets are populated and the system is enabled.

## Phase 2 Contextual Audio Contract

```text
System/change: Context music and key-location ambience foundation
Delivery lane and reason: Standard; new isolated client presentation owner with world/session inputs and bounded zone checks.
Goal: Select and crossfade walking, driving and selected interior music/ambience without one zone or emitter per city block.
Current confirmed baseline: Phase 1 install/audit and 20:36:31 mirror pass; audio remains disabled with blank assets.

Required changes: Folder-driven context catalogue, two bounded local playback channels, deterministic context priority, sparse tagged-zone support and one isolated runtime starter.
Must preserve: Phase 1 vehicle audio, existing SoundGroups/loading mixer, driving, garage/session authority, UI, VFX, persistence, economy and world geometry.
Explicit exclusions: Sound assets, activation, purchases, saved preferences, per-wall emitters, 3D ambience emitters, occlusion and reflections.

Canonical owners:
- Context state: ContextAudioController resolves existing player/session/seat state plus registered tagged zones.
- Playback: ContextAudioController owns only local Sound instances under SoundService.NTR_ContextAudioRuntime_Local.
- Mix: existing NTR_GameplayMusic and NTR_Ambience SoundGroups remain authoritative.
- Garage/interior state: existing NTR_GarageSessionActive/Mode and NTR_OwnedGarageInside attributes remain authoritative inputs.
- Persistence/authoritative mutation: N/A; Phase 2 is local presentation only.

Entry/transitions/cleanup: Owned garage overrides dealership session, which overrides tagged zones, driving and on-foot defaults. Context changes crossfade; track Ended advances a bounded playlist; disable/stop destroys all local sounds and connections.
Scale/performance: At most two steady local Sounds and four during crossfade; context resolves at 5 Hz; at most 32 registered tagged BasePart/Model zones; no Workspace descendant scan or per-frame city geometry work.
Streaming: CollectionService added/removed signals register streamed zones; missing zones fall back safely to driving/on-foot context.
Mobile/input: No input/UI fork. The same two-channel runtime runs on all clients and can be disabled globally.
Failure/observability: Blank tracks are skipped, audio defaults disabled, debug output is gated and runtime failure does not block gameplay.
Rollback: MODE="DISABLE" sets only ContextAudioEnabled=false; failed install rolls back its own sources/hierarchy/attributes.
Done when: Install/audit pass, tracks are assigned, on-foot/drive/dealership/owned-garage transitions crossfade correctly, tagged-zone overlap/streaming works, repetition does not grow sounds and the mirror is refreshed.
```

### Phase 2 Context Definitions

The installer creates four stable definitions under `Config.Audio.Context.Contexts`:

- `FREE_ROAM_ON_FOOT`
- `FREE_ROAM_DRIVING`
- `DEALERSHIP_INTERIOR`
- `OWNED_GARAGE_INTERIOR`

Each contains `MusicTracks` and `AmbienceTracks`. Tracks are ordered `StringValue` objects with `Gain`, `Order` and `Loop` attributes. Add more tracks by duplicating `Track01` and changing its value/attributes; runtime code does not need another location branch.

Key world areas use sparse authoring volumes. Tag a BasePart or Model `NTR_AudioContextZone` and give it `AudioContextId`; optional `AudioContextPriority` resolves overlaps. Do not place zones on every block or emitters on every wall. Dealership and owned-garage sessions use existing authoritative player attributes and need no physical zone.

## Confirmed Phase 2 Installation Evidence

- The user reported the Phase 2 Edit audit passing with four context profiles, zero populated tracks and context playback disabled.
- The refreshed `20:48:08` mirror contains 173 scripts and exact copies of `ContextAudioCatalog`, `ContextAudioController` and `ContextAudioRuntimeController_Active` from the canonical installer.
- All four definitions, their blank `MusicTracks`/`AmbienceTracks`, Phase 2 revision and SoundService groups are present. This confirms the silent installation shape; audible transition and mobile evidence still requires assets and activation.

## Phase 3 Acoustics And Activation Contract

```text
System/change: Bounded acoustics, context reverb, quality budgets and guarded activation.
Delivery lane and reason: Standard; isolated local presentation owner using confirmed Phase 1/2 contracts with no new networking or persistence.
Goal: Let nearby remote vehicles respond to city geometry and interiors sound distinct without wall emitters, manual city raycasts or unbounded simulation.
Current confirmed baseline: Phases 1-2 install/audit and 20:48:08 mirror pass; all audio assets remain blank and disabled.

Required changes: Native acoustic-simulation controller, nearest-emitter desktop/mobile caps, context-driven ambience reverb, readiness counts and atomic ACTIVATE/DISABLE modes.
Must preserve: Phase 1/2 sources, existing SoundGroups/loading mixer, local-driver 2D presentation, driving, UI, VFX, garage/session state, persistence, economy and world geometry.
Explicit exclusions: Assets, automatic activation, wall/probe placement, manual raycast occlusion, saved audio preferences and sound-package purchases.

Canonical owners:
- Vehicle geometry acoustics: AcousticsController toggles Roblox native simulation only on Phase 1 runtime emitters and the active listener.
- Interior ambience reverb: one owned ReverbSoundEffect under NTR_Ambience, driven by the current Phase 2 context definition.
- Global activation: the Phase 3 command-bar installer validates readiness before changing the three master enable attributes.
- Persistence/authority: N/A; all behaviour is local presentation and the existing vehicle-state server remains unchanged.

Scale/performance: 2 Hz priority updates; nearest 4 emitters on desktop or 2 on small touch devices; 180-stud acoustic range; Phase 1 still bounds audible remote graphs to 12. No per-wall object, per-layer raycast or whole-city scan.
Streaming/lifecycle: Runtime vehicle descendant signals register/deregister emitters; camera listener is rediscovered; disabling/stopping restores global/listener/emitter state and removes local connections/runtime folders.
Failure/observability: Installer preflights native acoustic properties; runtime property writes are protected; detailed logs are gated; absent assets remain silent; optional acoustic failure cannot stop driving or Phase 1/2 startup.
Activation: ACTIVATE requires five populated vehicle assets including Ignition, Idle, EngineLow, Acceleration and Coast, plus at least two populated context definitions. It changes enable attributes atomically and rolls them back on failure.
Rollback: DISABLE turns vehicle, context and acoustic playback off while preserving assets/definitions. Failed INSTALL restores created source/config/effect changes.
Done when: Install/audit pass, assets satisfy readiness, ACTIVATE passes, 1/2-player occlusion/diffraction/interior reverb is audible, repeated transitions stay bounded, low-end mobile profiling passes and the mirror is refreshed.
```

Roblox's current modular audio API provides native acoustic simulation for occlusion, diffraction and reverberation when SoundService, AudioEmitter and AudioListener simulation are enabled. Phase 3 uses that geometry-aware engine path for only the nearest few remote vehicles. It does not create reflection emitters along buildings. Phase 2 background ambience remains local 2D audio; selected interior contexts instead use one lightweight group reverb effect.

## Confirmed Phase 3 Installation Evidence

- The user reported the Phase 3 Edit audit passing with assets/tracks still blank and playback disabled.
- The refreshed `21:00:59` mirror contains 175 scripts. Both Phase 3 sources exactly match the canonical installer, and the Phase 3 revision, acoustics quality attributes and owned context ambience reverb are present.
- The complete three-phase structural baseline is therefore confirmed. It is intentionally not an audible or release baseline until approved assets are populated, ACTIVATE passes and the runtime matrix below is completed.

## Phase 1 Standard Contract

```text
System/change: Standard vehicle audio foundation
Delivery lane and reason: Standard; new isolated client/server runtime with a validated remote and bounded per-vehicle presentation.
Goal: Give every vehicle one future-ready audio profile and present it as local-driver 2D audio or remote-player 3D audio.
Current confirmed baseline: V74 camera is confirmed; V75 driving is generated/current in the mirror but remains verification-sensitive. Existing SoundService groups and loading AudioMixController remain authoritative for their mix.

Required changes: Versioned semantic state contract, server validation/replication, folder-driven profile catalogue, audio bus bridge, local runtime controller and exporter coverage for SoundService.
Must preserve: Driving physics/state ownership, loading mixer, UI, garage/customisation, VFX, persistence, economy, camera and vehicle spawning.
Explicit exclusions: Purchases, applying packages, saved sound selection, walking/driving music, location ambience, world acoustics and final sound assets.

Canonical owners:
- State: existing DrivingController attributes locally; VehicleAudioStateService validates and republishes presentation state for other clients.
- Runtime attachment/presentation: VehicleAudioController owns client-only AudioPlayer/Fader/Wire/Emitter graphs.
- Mix: existing SoundGroups remain the user-facing mix owner; AudioBusController mirrors their volume into advanced-audio faders.
- Profile resolution: server stamps the standard inherited cockpit profile unless a future authoritative owner already supplied a valid ResolvedAudioProfileId.
- Persistence/authoritative mutation: N/A in Phase 1.

Inputs/outputs/dependencies: Runtime PlayerVehicles, OwnerUserId/DriverUserId, DriverSeat occupant, current driving state attributes, Audio config folders and one versioned RemoteEvent.
Entry/transitions/exit: Vehicle registration is event-driven; seating starts Running state; semantic changes send only transitions; driver/remote route changes rebuild one graph; vehicle destruction and controller stop remove all graphs, wires and connections.
Client/server authority: Client requests semantic presentation only for its currently occupied owned vehicle. Server checks payload shape, enums, revision, rate, owner, driver and seat occupant before writing replicated NTRAudio attributes.
Stable IDs/API: Profile folders use stable IDs. Phase 1 schema and remote contract are version 1. No saved schema exists.
Scale/performance budget: Local driver always detailed. At most 6 remote detailed plus 6 remote simple graphs within 240 studs by default; parameters update at 15 Hz and priority at 4 Hz; at most 8 one-shots per vehicle. All values are editable attributes.
Mobile/input: No separate controls or UI. The same bounded client runtime is used; quality attributes can be reduced after device profiling.
Streaming/open world: Only Runtime.PlayerVehicles are observed; no whole-city scans, wall emitters or per-block objects. Destruction/removal releases references and re-entry reconstructs state.
Failure/observability: AudioSystemEnabled defaults false, blank assets remain silent, debug logs are gated, invalid requests warn with a reason, and optional audio failure does not patch or stop driving.
Rollback: Set MODE="DISABLE" and rerun the canonical installer, or set Config.Audio.Global.AudioSystemEnabled=false. The installer creates no backup Instances and rolls back its own failed transaction.
Done when: Edit audit passes; approved assets are assigned; 1/2-player driver/remote transitions and cleanup pass; mobile performance is stable; mirror includes SoundService and all installed source/config.
```

## Installed Shape

```text
ReplicatedStorage.NeoTokyoRacers
  Config.Audio
    Global
    Quality
    VehicleProfiles.GENERIC_STANDARD_AUDIO
  Shared.Modules.Common.Audio.VehicleAudioStateContract
  Shared.Modules.Client.Audio
    AudioBusController
    VehicleAudioCatalog
    VehicleAudioController
  Shared.Remotes.Audio.VehicleAudioState

ServerScriptService.NeoTokyoRacersServer.Services.Audio
  VehicleAudioStateService_Active

StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio
  AudioRuntimeController_Active
```

Each cockpit template receives `StandardAudioProfileId="GENERIC_STANDARD_AUDIO"` only when that attribute is absent. A live vehicle receives `ResolvedAudioProfileId`, `AudioProfileRevision`, `AudioProfileSource` and semantic `NTRAudio...` attributes from the server service. A future package system may provide a different valid resolved profile before the live vehicle is registered; Phase 1 does not expose or sell that choice.

## Audio Layers

The standard profile has editable asset, gain and pitch attributes for:

- `Ignition`, `Shutdown`
- `Idle`, `EngineLow`, `EngineHigh`, `Acceleration`, `Coast`
- `DriftEnter`, `DriftLoop`
- `BoostEnter`, `BoostLoop`, `BoostRelease`
- `DriverWind`

All asset IDs start blank. Blank layers are skipped cleanly. This avoids hard-coded assets and makes a future whole-vehicle sound package a new profile folder using exactly the same fades and state contract.

## Perspective And Mixing

- The local driver's vehicle uses a non-positional route into the local audio output. This avoids the engine sliding around the stereo field as the camera moves.
- Other vehicles use one `AudioEmitter` attached to the vehicle root with distance attenuation. Other clients can hear server-validated semantic state through their own client graphs.
- The existing `NTR_Vehicle` SoundGroup volume is retained as the vehicle-mix control. The advanced-audio bus observes that group and multiplies its volume into registered faders rather than replacing the confirmed loading mixer.
- Phase 1 adds no wall emitters. Phase 3 uses Roblox-native scene-geometry acoustics for a capped nearest-emitter set and one context ambience reverb; it still requires no wall-by-wall or block-by-block authoring.

## Phase 1 Verification

1. In Edit mode run the canonical installer with `MODE="INSTALL"`; require `INSTALL PASS` and no rollback.
2. Change its first mode line to `AUDIT`, rerun it, and require `AUDIT PASS`.
3. Populate approved assets under the standard vehicle profile and at least two context definitions, then use Phase 3 `MODE="ACTIVATE"`; do not bypass its readiness gate by manually enabling the master attributes.
4. In a one-player test, enter/exit a vehicle repeatedly. Confirm ignition/shutdown once, continuous loops without duplicates, local non-positional presentation and no driving/UI/VFX change.
5. In a two-client server, confirm the second client hears the moving vehicle spatially, distance fade works, and spoofed/non-driver state requests are rejected.
6. Spawn/switch/destroy vehicles repeatedly and verify `SoundService.NTR_AudioRuntime_Local` remains a single bounded folder with no growing graphs or one-shot wires.
7. Test desktop and a low-end mobile profile. Measure before increasing the default 6 detailed + 6 simple remote budget.
8. Refresh the full Studio mirror with the updated exporter and confirm `SoundService`, all six installed source markers and audio config/profile attributes are present.

## Activation And Final Verification Still Pending

The three implementation phases are generated, but the audio system is not finished or activated until approved assets exist. Do not lower the activation thresholds simply to make `ACTIVATE` pass. Populate and audition the standard vehicle profile and at least two context definitions first, then test the full matrix before treating audio as a dependency or release baseline.
