# Vehicle Multiplayer VFX, Collision, Parking and Exit V1.1

**Status:** V1.1 installed, audited, user-confirmed and handed off; complete mirror refreshed at `2026-07-26 19:03:42`  
**Delivery lane:** High-Risk because multiplayer presentation transport and physics collision boundaries touch the confirmed race/session isolation contract.  
**Canonical installer:** `scripts/roblox_vehicle_multiplayer_vfx_collision_and_exit_v1.lua`

## Acceptance Contract

Goal:

- show engine, acceleration, boost and directional drift VFX for other players;
- preserve free-roam versus race and separate-session visibility isolation;
- make all player vehicles pass through one another;
- let on-foot players collide with slow or parked free-roam vehicles, but pass through vehicles above 20 mph;
- prevent on-foot players from pushing parked vehicles;
- place the exiting player a few studs to the seat's right;
- immediately stop/fix exits at or below 10 mph, but let faster exits retain momentum and coast before authoritative parking.

Required changes:

- reuse the existing server-validated vehicle semantic-state transport for remote VFX instead of adding another remote;
- keep semantic-state validation/replication alive when audio playback is silent or disabled;
- add one isolated server collision lifecycle owner for free-roam vehicles and normal characters;
- preserve `RaceSessionAssetService_Active` as the active race participant and arrow/barrier collision owner;
- immediately freeze and server-fix low-speed vehicles inside the existing authoritative exit action;
- keep faster exited vehicles character-pass-through, apply bounded drag through the existing parked-hover owner, reject re-entry while moving and server-fix them on settle/timeout;
- unfix, zero and return network ownership before re-entry;
- make the client parked-hover owner ignore fixed vehicles.

Must preserve:

- `NTR_RACING_PHASE11E_VFX_GATE` and `RaceParticipantVisibilityClient_Active`;
- same-session racer visibility and free-roam/race invisibility;
- `NTR_RaceParticipant` and race arrow/barrier collision;
- local-driver VFX responsiveness;
- driving, camera, race staging, checkpoints, reset, garage and owned-garage handoffs;
- saved vehicle/profile data and cosmetic/VFX authoring.

Explicit exclusions:

- no saved schema, profile, inventory, economy or reward change;
- no replacement driving controller or bootstrap feature block;
- no new VFX attachment owner, remote, ScreenGui or in-game backup.
- no HUD wording change; the existing mobile success toast may say `VEHICLE PARKED` before a fast exit finishes coasting.

## Canonical Owners

- **Local driving state:** `DrivingControllerV47` retains immediate local `Accelerating`, `Boosting` and drift state.
- **Replicated presentation state:** existing `VehicleAudioController` -> `VehicleAudioState` -> `VehicleAudioStateService_Active` validation publishes `NTRAudioIgnition`, `NTRAudioDrive`, `NTRAudioDrift` and `NTRAudioBoost`. VFX is only another consumer.
- **VFX:** `CachedThrustVisualRuntime` remains the only live attachment/state owner. Local vehicles use immediate state; remote vehicles use replicated semantic state; the existing race gate is applied afterward.
- **Free-roam collision:** new `VehicleCollisionLifecycleService_Active` owns normal characters and slow/fast free-roam vehicle grouping.
- **Race collision:** `RaceSessionAssetService_Active` retains `NTR_RaceParticipant` and `NTR_RaceSessionAsset`.
- **Parking/exit:** `GarageActionController_Shadow_Disabled` retains authoritative `ExitVehicle` and `ReEnterVehicle`; `VehicleCollisionLifecycleService_Active` owns the bounded server settle/fix transition.
- **Prompt re-entry:** `VehicleAccessPromptService_Active` retains the normal world prompt entry, hides/rejects it while coasting and clears fixed state before assigning ownership/seating.
- **Persistence:** N/A; no saved data changes.

## Collision Contract

The installer creates/configures `NTR_Character`, `NTR_VehicleSlow` and `NTR_VehicleFast`, and reuses `NTR_RaceParticipant` plus `NTR_RaceSessionAsset`.

| Pair | Collidable |
|---|---:|
| Character ↔ character/default world | Yes |
| Slow free-roam vehicle ↔ character | Yes |
| Fast free-roam vehicle ↔ character | No |
| Any free-roam vehicle ↔ any free-roam vehicle | No |
| Race participant ↔ race participant | No |
| Race participant ↔ normal character/free-roam vehicle | No |
| Race asset ↔ race participant | Yes |
| Race asset ↔ free-roam vehicle | No |
| Free-roam vehicle ↔ default world | Yes |

Speed is server-observed from assembly velocity using the established `0.625 mph/stud-per-second` conversion. Hysteresis prevents boundary flicker:

- enter fast pass-through above `20 mph`;
- restore slow character collision at or below `16 mph`.

The new owner does not reassign active race vehicles. When the race owner restores their original group, free-roam collision resumes on the next bounded update.

## Parking, Coasting and Exit Contract

On a valid owned free-roam exit, the server validates the seat and measures horizontal assembly speed using `0.625 mph/stud-per-second`.

- At or below `10 mph`, it returns network ownership, zeros velocity, anchors the welded root, sets `NTR_ParkedFixed=true`, commits parked state, then unseats and moves the character to the right.
- Above `10 mph`, it preserves linear/angular velocity, marks `NTR_ExitCoasting=true`, transfers temporary ownership to the exiting player and moves the character right. The existing parked-hover owner maintains hover and applies mass-proportional horizontal drag.
- During the complete coast, the collision service forces the car into character pass-through and both server entry paths reject/hide re-entry.
- After at least `0.75` seconds, the server fixes the car once it reaches `8 mph` or less. A `6` second safety timeout fixes it even if terrain/forces prevent settlement.
- Active race participants are rejected from this free-roam exit path; their established race lifecycle remains authoritative.

Re-entry validates root/seat before mutation, unanchors and zeros the fixed root, clears transient coast/fixed markers, assigns driver/network ownership and seats the player. `FreeRoamParkedHoverController_Active` cleans up/skips fixed vehicles. Driven hover is unchanged.

Editable defaults under `Config.Editable.01_GAME_BALANCE_Editable.VehicleInteractions`:

- `VehiclePassThroughEnterMph = 20`
- `VehiclePassThroughExitMph = 16`
- `CollisionUpdateHz = 10`
- `ExitRightStuds = 6`
- `ExitUpStuds = 2.5`
- `ExitImmediateParkMaxMph = 10`
- `ExitCoastSettleMph = 8`
- `ExitCoastMinSeconds = 0.75`
- `ExitCoastMaxSeconds = 6`
- `ExitCoastDragPerSecond = 0.8`

## Authority, Lifecycle and Performance

- The semantic remote accepts only the driver's own runtime vehicle while actually seated.
- Payload enums and increasing client revision remain validated by `VehicleAudioStateContract`.
- Clients never select collision groups, final parking authority or exit position. The server temporarily assigns the exiting player as physics owner while coasting and always reclaims ownership before fixing.
- The collision service registers only `PlayerVehicles` and player characters, observes additions event-by-event and makes one registered-vehicle pass at `10 Hz`.
- No whole-Workspace or per-frame descendant scan is added.
- Vehicle destruction/removal disconnects owned connections; character/race owners restore prior groups across respawn/session exit.
- Growth is bounded by players/vehicles; verify the target 15-vehicle case before release.

## Installer and Rollback

The installer preflights confirmed VFX/audio/garage/prompt/race markers, requires unique anchors, compiles all projected sources, snapshots every touched source/attribute, rolls back on failure, is idempotent and supports `MODE="AUDIT"`.

The source edits are guarded text replacements and therefore fragile. Every V1.1 anchor was checked exactly once against the fresh confirmed V1 mirror. If an anchor count changes in Studio, stop and refresh/inspect the live mirror instead of adding another patch.

After a successful saved install, rollback is the pre-install Roblox place version or a deliberate reversal generated from the refreshed pre-install mirror. No in-game backups are created.

## Verification Matrix

### Edit install

1. Run the installer once in Edit mode.
2. Require:

```text
[NTR Vehicle Multiplayer VFX Collision Exit V1.1] AUDIT PASS checks=14
[NTR Vehicle Multiplayer VFX Collision Exit V1.1] PASS
```

3. Confirm `VehicleCollisionLifecycleService_Active` is enabled and all ten config defaults are present.
4. Fully restart Studio.

### Two-client free roam

1. Start a local server with two players and drive beside one another.
2. From each client verify the other vehicle's idle, acceleration, boost and correct left/right drift VFX.
3. Drive through one another at low/high speed; neither vehicle should bump, rotate or transfer momentum.
4. Exit at `0`, about `9` and exactly/about `10 mph`: the vehicle must stop immediately, remain fixed when pushed and place the player on the seat's right without overlap.
5. Exit just above the boundary (`11-15 mph`) and at higher speed (about `50 mph`): velocity must continue naturally rather than snap to zero. The player must pass through the coasting car and its entry prompt must stay hidden/rejected.
6. Confirm the car fixes only after at least `0.75` seconds once at/below `8 mph`, or by the `6` second timeout. Test once on a slope/against a wall.
7. Once fixed, re-enter and confirm unfix, seat, driving, camera, HUD and VFX resume once.
8. On foot, collide with a parked/slow vehicle; above 20 mph pass through; below 16 mph after separation confirm collision restores.
9. Disable audible vehicle playback temporarily and confirm remote VFX state still updates.

### Two-client race isolation

1. Join the same race: racers see each other's VFX, vehicles pass through, and arrow/barrier/checkpoint collision remains correct.
2. Put one player in free roam while the other races: body, vehicle, name tag, VFX and physics must not leak across the boundary.
3. If practical, use separate runs and confirm isolation.
4. Finish, DNF and exit-to-start; visibility and free-roam groups must restore.

### Regression

- Repeat exit/re-entry ten times with stable service/constraint counts.
- Exit two players' cars above `10 mph` at the same time and confirm each settles independently.
- Test desktop and touch exit controls.
- Test respawn, despawn/switch, reset, time trial, multiplayer countdown, garage drive-in and owned-garage drive-out.

## Readiness Scorecard

| Area | Status |
|---|---|
| Ownership | PASS by design; existing VFX/race/garage owners are retained and one free-roam collision owner is added. |
| Security | PASS by design; semantic client intent remains validated and physics/parking are server-controlled. |
| Data | N/A; no persistence change. |
| Lifecycle | PASS for confirmed scope; retain repeated exit, respawn, destruction and race restoration in release regression. |
| Performance | PASS for confirmed scope; bounded event-driven design with the multi-vehicle case retained in release regression. |
| Mobile/input | PASS for confirmed scope; the early mobile `VEHICLE PARKED` wording remains cosmetic. |
| Streaming | PASS by confirmed event-driven registration/removal contract. |
| Failure handling | Installer transaction rollback and runtime validation defined. |
| Observability | Collision/fixed attributes and installer audit present. |
| Documentation | PASS; confirmed status, mirror evidence, rollback and regression checks are recorded. |

## Done When

Complete. The user confirmed the V1.1 result working and requested handoff; the `2026-07-26 19:03:42` mirror contains 187 matching exported scripts/source-manifest/checksum entries plus all V1.1 lifecycle markers and tuning revision. Treat this as the rollback baseline.
