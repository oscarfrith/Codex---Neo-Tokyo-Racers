# Presentation Audio: UI, Preview, Objectives And Racing V1

**Created:** 2026-07-26  
**Lane:** Standard  
**Canonical installer:** `scripts/roblox_presentation_audio_ui_preview_race_v1.lua`  
**Status:** V1.3.2 installed, user-confirmed and fully mirrored at `2026-07-26 20:46:20`

## V1.3.2 Immediate UI, Objective And Race One-Shots

The confirmed controller's eight-voice pool currently reuses any idle `Sound`, replaces its `SoundId` and immediately calls `Play()`. Roblox may need to load that replacement asset first, explaining why Click and Checkpoint can be responsive on one request but heavily delayed on another.

V1.3.2 keeps the bounded pool and makes two isolated changes:

- controller startup asynchronously warms enabled, populated UI, objective and racing one-shot assets;
- an idle voice already associated with the requested cue/asset is preferred before a generic idle voice is reassigned.

Warmup is capped by described `PreloadOneShotAssetLimit=24` and can be disabled with `PreloadOneShotsEnabled=false`. It never waits in the input or race-event path. Preview loops and vehicle audio are excluded, so Ignition readiness and its short Idle lead remain unchanged.

The user confirmed the repair working and requested handoff. The complete `20:46:20` mirror contains 188 matching exported scripts/source-manifest/checksum entries, `InstallerRevision=NTR_PRESENTATION_AUDIO_UI_PREVIEW_RACE_V1_3_2`, the immediate-one-shot controller marker and both described controls. Confirmed live limits are preload enabled, 24 unique warmed assets and eight pooled voices.

## V1.3.1 Ignition Playback Repair

The installed V1.3 coordinator calls `Catalog.Get(profileId)`, but `VehicleAudioCatalog` exposes `GetProfile(profileId)`. That runtime error occurs after engine-loop targets are calculated and before Ignition playback is requested, matching the observed delayed Idle with no startup one-shot.

V1.3.1 corrects the lookup and strengthens delivery without another owner:

- the persistent local lane and loading/seat/Internal-route gate remain;
- `Play()` requests no longer consume the session immediately;
- `AudioPlayer.IsPlaying` must confirm startup;
- failure retries with described bounded timing and attempt controls;
- exhaustion warns once and releases engine loops safely;
- local engine loops remain held until confirmation plus a short configurable lead, preventing Idle from masking Ignition.

The user confirmed the repaired startup and retained presentation/garage cues working. The complete `19:03:42` mirror contains 187 matching exported scripts/source-manifest/checksum entries, `InstallerRevision=NTR_PRESENTATION_AUDIO_UI_PREVIEW_RACE_V1_3_1`, `NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION` and the corrected `Catalog.GetProfile(profileId)` call. Confirmed live tuning is `ReliableIgnitionEnabled=true`, `IgnitionAfterReadyDelaySeconds=0.1`, `IgnitionPlaybackConfirmSeconds=0.07`, `IgnitionMaxPlayAttempts=3`, `IgnitionRetryDelaySeconds=0.1` and `IgnitionToIdleLeadSeconds=0.15`.

## V1.3 Owned-Garage Cues And Reliable Ignition

V1.3 adds four independent described cues beneath `Config.Audio.Presentation.UI`: `DecorationPurchaseSuccess`, `DecorationEquipSuccess`, `StructurePurchaseSuccess` and `StructureEquipSuccess`. The existing authoritative result remains the only producer. A purchase already equips/places in the same transaction, so it emits one purchase cue and never layers an equip cue. Successful owned-garage `AssignDisplay` reuses `VehiclePurchaseSuccess`; failed assignment uses `ActionRejected`.

Local startup no longer depends on the replaceable vehicle loop graph. The current V3 controller can discover a new powered vehicle while loading audio is ducked, play Ignition into its External graph, and then destroy that graph/one-shot when seating selects the Internal route. V1.3 suppresses only that local legacy path, prepares the selected profile's Ignition asset on a persistent internal vehicle-bus lane, and releases it after:

1. the player is seated as the local driver;
2. `LoadingPresentationState.Active` is false;
3. the Internal route is stable, or its bounded readiness timeout has elapsed;
4. the configured post-ready delay and bounded asset-warm wait are satisfied.

The cue plays once per new vehicle instance and survives later graph rebuilds. Remote clients retain the existing external 3D Ignition. `ReplayIgnitionOnRunningVehicleReentry=false` preserves the confirmed parked-running behaviour; it can be changed later without source editing.

## V1.2 Vehicle-Purchase Cue

V1.2 adds `Config.Audio.Presentation.UI.VehiclePurchaseSuccess`, including `AssetId`, `Gain`, `Pitch`, `CooldownSeconds`, `MaximumVoices`, `Bus`, `Enabled` and matching descriptions.

- `BuyCockpitInstance` with `Success=true` emits `UI.VehiclePurchaseSuccess`.
- Rejected, busy or unavailable vehicle purchases keep `UI.PurchaseRejected`.
- Module purchases retain the V1.1 module-equip success cue.
- Neon, cosmetic, property and other successful purchases retain `UI.PurchaseSuccess`.

The current V1.1 upgrade uses one guarded outcome replacement plus one revision-marker replacement in `ModuleShopUIController`, canonically updates the small `PresentationAudioBridge` module and add-if-missing creates one cue folder. No dealership transaction, price, ownership, saved data or UI flow changes.

## V1.1 Focused Refinement

The same canonical installer now upgrades the confirmed V1 installation without rewriting the presentation controller or changing audio configuration:

- a successful `BuyModuleInstance` result selects `UI.ModuleEquipSuccess`, matching an explicit module equip;
- a rejected, busy or unavailable module purchase remains `Purchase` and therefore still selects `UI.PurchaseRejected`;
- the onboarding shades, advance catcher and `NEXT` button set `UIAudioHoverCue=""`, suppressing mouse hover/controller focus across the prompt;
- onboarding `NEXT.Activated` is unchanged, so mouse, touch and controller activation still plays `UI.Click` and advances once.

Only `ModuleShopUIController` and `OnboardingClient_Active` change in V1.1. All six guarded installed-V1 anchors occur exactly once in the refreshed mirror, both projected sources compile before mutation and failure rolls the transaction back. No sound ID, gain, cooldown, UI layout, objective state, remote, persistence or economy rule changes.

## Acceptance Contract

```text
Goal: Add consistent, easily configured local audio for UI, vehicle preview, onboarding objectives and races.
Required changes: One persistent presentation-audio runtime, a cue catalogue/config tree, global button binding, stable preview loops and small semantic outcome hooks.
Preserved behaviour: Existing UI components/layout, garage/race authority, purchase/equip validation, profile persistence, vehicle audio, VFX, driving and race timing.
Shared components: Existing NTR_UI, NTR_Vehicle and NTR_GameplaySFX buses; current preview root/ProfileId; existing GarageInvoke results and RaceEvent.
Ownership: Client controller owns only local playback. Existing servers remain authoritative for purchases, equips, objectives and race progress.
Lifecycle: Runtime starts once, binds present/future GuiButtons, pools at most eight one-shots and keeps preview loops outside rebuildable vehicle clones.
Device coverage: Mouse hover, controller focus and Activated for mouse/touch/controller. Hover is never required for an action.
Persistence/economy: No new remote, saved field, product or purchase owner. Future whole-vehicle audio-package selection remains deferred.
Failure/rollback: Four exact source integrations are unique-checked and every projected/new source compiles before mutation. Failed INSTALL restores its transaction. DISABLE turns off presentation playback while retaining sources/config/assets.
Done when: INSTALL/AUDIT pass; input, purchase/rejection, preview continuity, objective and race checks pass; no duplicate cues or unbounded Sounds; full mirror refreshed.
```

## Runtime Shape

- `PresentationAudioBridge` accepts semantic local events such as confirmed purchase, module equip and objective completion.
- `PresentationAudioCatalog` reads designer tuning from `Config.Audio.Presentation`.
- `PresentationAudioController` owns the local Sound pool, two persistent preview loops, global `GuiButton` registration and existing `RaceEvent` subscription.
- `PresentationAudioRuntimeController_Active` starts the controller once from the isolated Audio controllers folder.
- No Sound is inserted into a button, preview clone or world vehicle.

The UI binder registers existing and future `GuiButton` descendants of `PlayerGui`. It plays hover for mouse entry, the same cue for controller focus, and click from `Activated`, which also covers touch. Invisible, inactive, contentless and explicitly silent controls are ignored.

Optional button attributes are:

- `UIAudioSilent=true`: suppress this button and its descendants.
- `UIAudioHoverCue="UI.Hover"`: choose another configured hover/focus cue; use a blank string to suppress hover/focus while preserving click.
- `UIAudioClickCue="UI.Back"`: choose another configured activation cue.
- `UIAudioSuppressClick=true`: suppress the generic click when a specialised interaction should be silent.

Purchase/rejection/equip cues are emitted only after the existing authoritative result returns. Button text and toast wording are never used to infer success.

## Preview Contract

The persistent preview Sounds live under `SoundService.NTR_PresentationAudioRuntime_Local`, not under `HOVER_RACING_V2_LOCAL_PREVIEW` or its cloned car. A brief configurable missing-preview grace survives clone rebuilds. Replacing modules, changing paint or moving a thrust-colour slider therefore does not restart the loop.

- `Preview.IdleLoop` is active whenever a dealership/customisation preview vehicle exists.
- `Preview.BoostLoop` is active while the existing root attribute `PreviewVFXMode="ThrustColour"`.
- A blank preview `AssetId` reuses its `ProfileLayer` (`Idle` or `BoostLoop`) from the selected vehicle audio profile.
- A genuinely different future profile or changed asset/tuning crossfades rather than hard-cutting.
- Preview playback is local and non-positional. Live/free-roam cars keep the existing local-driver and external 3D vehicle-audio routes.

`PreviewVehicleController` publishes `PreviewAudioProfileId`. It accepts future `ResolvedAudioProfileId`/`AudioProfileId` data but defaults to the cockpit's existing `StandardAudioProfileId`, then `GENERIC_STANDARD_AUDIO`. This prepares whole-vehicle sound packages without implementing purchase, ownership or persistence.

## Objective And Race Contract

The onboarding hook compares the previous completion snapshot with the next one. It emits `Objective.Complete` only for a new false-to-true transition and never for the first load of already-saved completion state.

Race cues consume the existing `RaceEvent`:

- server-time `TimeTrialCountdownScheduled`/`RaceCountdownScheduled` produces one tick per changed number;
- `TimeTrialStarted`/`RaceStarted` produces GO;
- checkpoint and lap cues use run/lap/checkpoint identities to reject duplicate delivery;
- finish, DNF and staged/match-found cues use their existing server-confirmed messages.

`Racing.WrongWayWarning` is configured but intentionally has no producer until the game has one stable semantic wrong-way event.

## Configuration

All values are under:

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      Audio
        Presentation
          Global
          UI
          Preview
          Objective
          Racing
```

Every configurable attribute has a matching `Descriptions` StringValue explaining its unit and purpose. Numeric IDs and `rbxassetid://` values are accepted. Defaults are add-if-missing, so rerunning the installer preserves assigned asset IDs and tuning.

Global controls include master enablement, section enablement, one-shot pool size, preview polling rate, hover/focus switches and section master gains. Every cue exposes `Enabled`, `AssetId`, `Gain`, `Pitch`, `CooldownSeconds`, `MaximumVoices` and `Bus`; preview loops also expose profile layer, fade, crossfade and rebuild-grace controls.

All one-shot `AssetId` values start blank and safely remain silent until populated, including `UI.VehiclePurchaseSuccess`. The generic preview Idle should already reuse the populated vehicle Idle layer. The preview Boost loop remains silent until either `Preview.BoostLoop.AssetId` or the profile's `BoostLoopAssetId` is populated.

## Confirmed Baseline, Recovery And Regression

No Studio command is pending. For ordinary tuning, edit the existing described attributes; do not rerun the installer. If exact-scope recovery is required, run the same canonical installer, require V1.3.2 INSTALL/AUDIT pass, repeat the matrix below and refresh the complete mirror.

Retain this focused release regression:

1. Restart Play and verify:
   - mouse hover, touch click and controller focus/activation;
   - purchase success, insufficient-funds rejection and module equip;
   - idle continuity through car/module/paint changes;
   - boost-preview continuity through repeated thrust-colour changes;
   - one objective completion with no cue on saved-state initial load;
   - time-trial and multiplayer countdown, GO, checkpoint, lap, finish and DNF;
   - repeated UI/race activity never creates more than the configured one-shot pool.
   - successful module purchase and explicit module equip use the same cue;
   - rejected module purchase still uses the purchase-rejected cue;
   - onboarding `NEXT` is silent on mouse hover/controller focus but still clicks and advances through mouse, touch and controller.
   - a successful vehicle purchase uses `VehiclePurchaseSuccess`, a rejected vehicle purchase uses `PurchaseRejected`, and a non-vehicle purchase still uses `PurchaseSuccess`.
   - decoration and structure purchase/equip each use their own cue, with no purchase/equip double hit;
   - successful owned-garage display assignment uses `VehiclePurchaseSuccess`, while failure uses `ActionRejected`;
   - dealership/customisation exit, owned-garage drive-out and free-roam new-vehicle spawn each play Ignition once after loading;
   - simple exit/re-entry of the same running parked car does not replay Ignition;
   - replacing/destroying vehicles leaves no persistent ignition players, faders or wires;
   - a second client still hears external 3D Ignition with the existing attenuation/acoustics rules.
2. Run at least ten repeated new-vehicle spawns and confirm no repeated warnings or growing players, faders or wires.
3. Verify same-running-car exit/re-entry does not replay Ignition.
4. Use a second client to confirm external 3D Ignition still follows distance, direction and bounded acoustics.
5. Repeat the core startup/UI flow in landscape-mobile.

Cold-start first use, alternating UI/race cues and bounded-pool inspection remain part of release regression.

For non-destructive disable, run the same script with `MODE="DISABLE"`. Re-enable by setting both `Config.Audio.Presentation.Global.PresentationAudioEnabled=true` and `Config.Audio.Global.ReliableIgnitionEnabled=true`; rerunning `INSTALL` deliberately preserves explicit tuning/enable values.
