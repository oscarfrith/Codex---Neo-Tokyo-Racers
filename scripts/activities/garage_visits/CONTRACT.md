# Garage visits: acceptance contract (Agent D, High-Risk)

Status: generated, not installed, not agent-verified in Studio. Target: Space Racers v2 (71491191583884). Base sources: capture `roblox/captures/route-smooth-after` (OwnedGarageManagement e6314823, OwnedGarageBrowserUI 5627cc41, GarageInteriorModeUI fc679f3e). Run `delivery-reviewer` on this contract, `spec.json` and the diffs against those blobs before APPLY.

## Goal

A player can walk into another player's owned garage on the same server while that owner is inside it. The owner's saved `AccessMode` decides who may enter. Visitors look around on foot and leave through the door. The owner experience does not change.

## Rules (owner decisions)

- Visits happen only while the **owner is inside their own garage**: they have a live session, `OwnedGarageInside` is true and no transition is running. Visits are same-server only.
- Visitors come **on foot**. A visitor who is seated (driver or passenger), racing, queued, in a dealership/customisation garage session, in an activity, mid-stream, in their own garage or already visiting is refused.
- `MaxVisitorsPerGarage` = 8 (`ReplicatedStorage.Config.Activities.Visits`), clamped to 0..24.
- Admission uses the owner's saved per-property `AccessMode`:

| Mode | Who may visit |
|---|---|
| Public | anyone |
| FriendsOnly | `visitor:IsFriendsWith(owner.UserId)` (pcall; a failure counts as "not a friend" and is not cached; results are cached per visitor:owner pair for `Visits.FriendCacheSeconds`, default 300) |
| InviteOnly | the visitor's UserId is in the owner's `InvitedUserIds` |
| Private (and any invalid value) | nobody |

- **Gate** (all three must be true): `FeatureFlags.IsEnabled("EnableGarageVisits", true)`, `Config.Activities.Visits.Enabled == true`, and `Config.Garage.Interior.EnableVisitors == true`. The flag defaults to true, so it works as a dashboard kill switch. The two config attributes are the explicit opt-in (the spec sets `EnableVisitors = true`).

## Owners (no new owners)

| Concern | Owner | Change |
|---|---|---|
| Interiors, sessions, teleports, streaming, garage player attributes | `ServerStorage.Modules.Game.Garage.OwnedGarageManagement` | Adds a separate `visitors[player] = {Owner, OwnerUserId, Interior, PropertyId, Slot, Pending?, Leaving?}` table. Visitors never get a `sessions` entry. |
| Admission maths | new pure `ServerStorage.Modules.Game.Garage.GarageVisitRules` | `CanVisit`, `StillAdmitted`, `Admits`, `BuildVisitableList`, `NextSlot`, `SpawnOffset`, `Message`. No services and no instances. |
| Saved AccessMode / InvitedUserIds | OwnedGarageProfile, through the ProfileService command boundary (unchanged) | Read only, via `GetProfile` on the owner. Nothing is written. |
| Browser UI | `ReplicatedStorage.Modules.Game.UI.OwnedGarageBrowserUI` | Adds a VISIT tab and the VisitEnded toast. |
| Interior access HUD | `GarageInteriorModeUI` | Hidden for visitors (two anchored edits). See "Exception" below. |
| Remote | `Remotes.Garage.OwnedGarageInvoke` through `Core.Net.invoke` (unchanged instance) | Three new allowlisted actions. |
| Push | `Remotes.Garage.OwnedGarageEvent` (unchanged instance) | New server-to-client `Type = "VisitEnded"`, `{Reason, OwnerUserId}`. |

No saved data, schema, economy, Cash, XP or vehicle changes.

## Player attributes

When a visitor is inside, the server sets these in this order:

1. `OwnedGarageVisitor = true`
2. `OwnedGaragePropertyId = <owner's property>`
3. `OwnedGarageOwnerUserId = <owner UserId>`
4. `OwnedGarageInside = true`

Because `OwnedGarageInside` is set, every existing guard also applies to visitors: race teleport, dealership teleport, GarageServer vehicle actions, drive rewards and ActivityService.IsBusy. When the visit ends, the server calls `setInside(nil)` and then clears `OwnedGarageVisitor`.

## Remote actions (OwnedGarageInvoke)

- **`GetVisitableGarages`** (read; no transition cooldown; rate-limited like other mutations). Returns `{Success, Enabled, MaxVisitors, Garages = rows}`. Each row is `{OwnerUserId, OwnerName, PropertyId, GarageName, District, Image, AccessMode, VisitorCount, MaxVisitors, CanVisit, Reason, Message, Visiting}`. Garages that deny this player by access (Private, not a friend, not invited), whose owner is outside or offline, or that belong to the caller are **not listed**, so private garages are never revealed. A full garage, or a busy caller, gives a disabled row.
- **`VisitGarage {OwnerUserId}`** runs these steps:
  1. Check admission (pure `CanVisit`).
  2. The friend lookup, profile read and lifecycle call can yield. Afterwards, rebuild the owner's state from their saved profile (AccessMode, InvitedUserIds, visitor count). Run `CanVisit` again, reusing the friend result from step 1 or the per-pair cache, with no new web call (V2).
  3. Synchronously re-check the owner session, no transition, owner inside, and capacity.
  4. Reserve the slot (`Pending`).
  5. Stream the interior with `streamDestination`.
  6. Right before the teleport, synchronously re-check (V1): character alive, `humanoid.SeatPart == nil`, `ActivityKind == ""`, no `GarageSessionActive`, `RaceQueueActive`/`RaceBrowserTeleporting` not set, `sessions[player] == nil`, and the owner still inside the same session. If any check fails, free the Pending slot and reply with the reason message.
  7. Teleport to `CharacterSpawn` plus a ring offset for the slot (3.5 studs).
  8. Set the attributes.

  If the visit ends during steps 4 to 7 (owner leaves, the visitor dies, the owner revokes access), the request fails. A visitor who already landed inside is moved back out.
- **`LeaveVisit`**: streams `FootExitSpawn` of the visited property, teleports there (with the slot offset) and clears the attributes.
- **Visitor guard**: before any other handling, a visitor can only call `GetState`, `GetManagementState` and `GetVisitableGarages`. `LeaveVisit` and `ExitOnFoot` go to `leaveVisit`. Every other action (management, previews, configure, display, enter, drive out, SetManagementOpen, SetAccessMode, SetInvitation) returns `{Success=false, Visitor=true}`. All of these already require `sessions[player]`, which visitors never have. The guard is a second, explicit barrier.
- **`GetState`/`GetManagementState`** also return `Visiting = {OwnerUserId, OwnerName, PropertyId, GarageName}` (or nil) and `VisitsEnabled`. These fields are added after the stateFor cache, so the cache keys are unchanged.

## Interior prompts

- `ManageGaragePrompt` and `DriveOutPrompt` still check `triggeringPlayer == player` (owner only).
- `FootExitPrompt`: the owner's path is unchanged. A visitor of **that** interior gets `leaveVisit`, and the server pushes `FootExitResult` to them so their loading screen finishes.
- Client: the browser never starts the drive-out loading screen for a visitor.

## Ejection

Ejection moves the visitor to the property's `FootExitSpawn` plus the slot offset, clears the attributes and pushes `VisitEnded` with a Reason. A forced move anchors the visitor's root, pivots, streams, then unanchors, so it is safe even when the interior is destroyed in the same frame. During the forced move the server holds `locks[player]` (when free) and an `ejecting[player]` marker, which the handler treats as a held lock (V3). A new `VisitGarage` or any other request therefore cannot replace the exit stream request mid-eject. The move runs in a pcall, and the lock, the marker and the anchor are always released.

| Trigger | Reason | Where |
|---|---|---|
| Owner foot exit succeeds | OwnerLeft | `exitOnFoot` |
| Owner drive out succeeds | OwnerLeft | `driveOut` |
| Owner death, or any enter failure that abandons the session | OwnerLeft | `abandonSession` |
| Owner disconnects (before the interior is destroyed) | OwnerLeft | `PlayerRemoving` |
| Owner changes AccessMode, or revokes an invite, so the visitor no longer qualifies | AccessRevoked | re-checked after a successful `SetAccessMode`/`SetInvitation` (`task.spawn`) |
| Visitor dies | Died | no move; they respawn normally |
| Visitor respawns | Respawned | no move |
| Visitor disconnects | (no push) | slot freed |

`scheduleUnload` does not destroy an interior while any visitor record points at it. After the last visitor leaves an interior whose owner has no session on it, `endVisit` reschedules the unload. Visitors do not count against `MaxActiveInteriorsPerServer`, because they never create interiors.

## Admission and security argument

- The client sends only `OwnerUserId`. The server resolves the owner with `Players:GetPlayerByUserId`, reads AccessMode and InvitedUserIds from the owner's server profile, runs the friend check itself, and derives every busy flag from server state. A client cannot claim to be a friend or to be invited.
- Capacity cannot be raced. The count, including pending records, is re-checked and the slot reserved with no yield in between. Per-player `locks` serialise each player's own requests.
- Visitors never enter `sessions`. Every owner mutation path reads `sessions[player]`, and the new guard rejects visitors before any profile work. The owner's `ExecuteOwnedGarageCommand` is only ever invoked with the calling player, so a visitor can never write the owner's profile.
- Prompt callbacks compare `triggeringPlayer` to the owner. The only visitor path is leaving.
- Private garages are never listed. Denied requests return only a generic reason.
- No Cash, XP, items or saved fields change, so visits cannot be exploited economically.

## Exception (documented)

`GarageInteriorModeUI` is edited only because it shows the owner's Access/Invite dropdown HUD whenever `OwnedGarageInside` is true. Without the edit, visitors would see owner controls that the server rejects. The edit adds `and player:GetAttribute("OwnedGarageVisitor")~=true` to `root.Visible` and connects that attribute's change signal to `update`. Nothing else in that file changes.

## Preserved (owner flows exactly as before)

With no visitors present, every new call is a no-op:

- `ejectVisitors` returns 0.
- The extra `interiorHasVisitors` condition is false.
- The re-check after SetAccessMode/SetInvitation finds nobody.
- The guard is skipped when `visitors[player]` is nil.
- The GetState reply only gains the `Visiting`/`VisitsEnabled` fields.
- The browser's MY GARAGES tab renders exactly as before. The tabs appear only when `VisitsEnabled` is true or a visit is active.

## Tests

- **Pure:** `tests.lua` loads `http://127.0.0.1:8767/activities/garage_visits/GarageVisitRules.lua`. It covers:
  - the 4×3×3 matrix (modes × friend/invited/stranger × owner inside/outside/offline);
  - gate, self-visit, invalid owner and invalid mode;
  - capacity: 7 of 8, 8 of 8, max 0, the default, the clamp and NaN;
  - every busy reason, including access denial winning over busy;
  - revalidation;
  - list filtering and order;
  - slot and offset maths.

  It returns `{failures, results}`.

## Studio checklist (2 players: Test → Clients and Servers, 2 players)

Setup: set Studio flag override `ServerStorage.Config` attribute `Flag_EnableGarageVisits = true` (or rely on the default). Both players own `STARTER_TWO_BAY`.

1. **Gate off.** With `EnableVisitors = false`, P2's HUD garage button shows no VISIT tab. A direct `VisitGarage` call is refused with Disabled.
2. **Private.** P1 enters their garage (Access = Private). The VISIT list for P2 is empty ("NO OPEN GARAGES").
3. **Public.** P1 sets Public from the interior HUD. P2 refreshes, sees P1's garage (0/8 VISITORS, hosted by P1) and presses VISIT. The loading screen runs and P2 lands inside next to CharacterSpawn. P2's attributes are OwnedGarageInside=true, OwnedGarageVisitor=true and OwnedGarageOwnerUserId=P1. P2 sees no Access/Invite HUD.
4. **Owner-only prompts.** P2 triggers the desk prompt: nothing opens. P2 triggers a DriveOutPrompt: nothing happens and no loading screen appears. P2 calls `AssignDisplay`/`SetAccessMode`/`EnterSelectedGarage`/`DriveOut` from the command bar: each returns `Visitor=true`.
5. **Visitor leaves.** P2 uses FootExitPrompt and lands at the STARTER_TWO_BAY FootExitSpawn with the attributes cleared. P2 visits again, then uses the browser's LEAVE GARAGE button: same result.
6. **Driving.** While seated in a car, P2's browser shows "EXIT YOUR CAR TO VISIT" (disabled), and the server refuses with Driving.
7. **InviteOnly.** P1 sets InviteOnly. P2 is not listed. P1 invites P2, and P2 is listed and can visit. P1 revokes the invite: P2 is ejected to FootExitSpawn with the toast "The owner closed the garage to you."
8. **FriendsOnly.** For non-friend test accounts, P2 is not listed. If a friend pair is available, P2 is listed and can visit.
9. **Switch to Private while visited.** P2 is ejected with AccessRevoked.
10. **Owner leaves.** For each of foot exit, drive out, owner reset/death and owner leaving the game: P2 is ejected to FootExitSpawn, does not fall, and gets the toast "The owner left the garage…". After InteriorUnloadDelaySeconds the interior is gone.
11. **Visitor dies inside.** Attributes clear and P2 respawns normally. P1's interior still unloads normally after P1 leaves.
12. **Capacity.** Set `MaxVisitorsPerGarage = 1`. A third client (or a direct call) is refused with Full, and the row shows as disabled.
13. **Regression (owner).** Enter on foot, drive in, drive out, manage displays/structure/lighting, set access and invites, foot exit. All behave as before. The console shows no new `[Owned Garage]` warnings.
14. **Leak check.** Repeat visit and leave ten times. The `OwnedGarageInstances` child count and the NetStats reject counts stay stable.

## Rollback

The installer's ROLLBACK reverses `spec.json` in reverse order, restoring each captured before-value:

1. `Config.Garage.Interior.EnableVisitors` goes back to its prior value (false). This closes admission on its own: `visitSettings().Enabled` becomes false, VISIT tabs disappear and new `VisitGarage` calls return Disabled. Visitors already inside stay until they leave or the owner leaves.
2. `Config.Activities.Visits.FriendCacheSeconds` is removed (or restored).
3. `GarageInteriorModeUI` source goes back to blob fc679f3e.
4. `OwnedGarageBrowserUI` source goes back to blob 5627cc41.
5. `OwnedGarageManagement` source goes back to blob e6314823.
6. The `GarageVisitRules` module is removed. Remove it only after step 5; the restored management source no longer requires it.

Source changes take effect on the next server start. Nothing is saved (no profile fields, schema or economy), so no data migration or cleanup is needed. The live kill switch without an install is `FeatureFlags` `EnableGarageVisits = false` (dashboard) or setting `Visits.Enabled = false`.

## Open risks

- The client streams the interior per visitor with the existing `streamDestination`. Visitors on a slow device can time out ("Destination streaming timed out."). This is the same behaviour and message as for owners.
- Forced ejection anchors the visitor's HumanoidRootPart for up to `GarageStreamTimeoutSeconds` while their client streams the exterior.
- The onboarding guide trail may point an unfinished-onboarding visitor at the owner's desk (OnboardingClient keys on `OwnedGarageInside`). This is cosmetic, because the desk is owner-only.
- `IsFriendsWith` makes a web call. The first FriendsOnly lookups in a list refresh can yield. Results are cached per pair, and a failure counts as not a friend.
- ProximityPrompts replicate to everyone, so visitors still see the desk and Drive Out prompt labels. The server ignores those prompts for visitors and the client skips the loading screen. Hiding the labels per player would need a client prompt filter, which is out of scope.
- The free-roam HUD's owned-garage presentation (HUD hidden inside the garage) also applies to visitors. They leave through the door prompt or the browser (if reachable).
