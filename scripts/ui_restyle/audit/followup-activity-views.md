# UI restyle audit: followup-activity-views

Read-only audit, 2026-10-09. Source of truth: live Studio, Space Racers v3 (placeId 93959280828322), Edit mode.
Nothing was changed in Studio or the repo. Nothing was run in Play, so every behaviour below is read from
source, not observed. Sizes "on a phone" are worked out from the formula, not measured.

Scripts read in full (all five exist at the listed paths):

| Script | Lines | Color3.fromRGB | Enum.Font | UDim2 | ctx.Theme reads |
|---|---:|---:|---:|---:|---:|
| ReplicatedStorage.Modules.Game.Activities.JobClient | 438 | 0 | 0 | 0 | 5 |
| ...Activities.DuelClientView | 296 | 0 | 0 | 3 | 7 |
| ...Activities.PassengerClientView | 188 | 0 | 0 | 0 | 1 |
| ...Activities.CourierClientView | 67 | 1 (world prop) | 0 | 0 | 2 |
| ...Activities.TaxiClientView | 43 | 0 | 0 | 0 | 1 |

Also read for context (owned by another audit group): ActivityClient (323 lines), JobRules (804), RacingUIComponents (194),
MapMarkers (131), parts of ResponsiveUIFoundation, MapIconLayer, ClientBase, docs/architecture/activities-contract.md.

## Headline

1. These five scripts hold almost no view code. They are state, polling and intents. Everything drawn on screen goes
   through `ActivityClient.Context` (`ctx`), which ActivityClient builds inside its `ActivityHud` ScreenGui. So the
   restyle seam for Street Life is **ActivityClient's `ctx.UI` and `ctx.Theme`**, not these files. All five can stay
   byte-identical and serve both the old and the new style.
2. Three things in this group are built directly, outside `ctx.UI`:
   - the CHALLENGE button's size, colours and position (DuelClientView 252-263);
   - two native `ProximityPrompt`s (JobClient 198-206, PassengerClientView 69-79), which use Roblox's default prompt
     look and cannot be restyled through `ctx`;
   - world props (parcel crate, offer anchor), which are not UI.
3. `ctx.Theme.Telemetry`, `HighSpeed` and `ElectricBlue` are passed as real `Color3` values into Part.Color,
   PointLight.Color and MapMarkers `Color`. A restyled theme must keep them as Color3, and must decide what each one
   means, because the views use `HighSpeed` for five different meanings.
4. One functional bug that the restyle will touch: after the duel stake menu times out, the CHALLENGE button stays on
   screen but does nothing (details in Defects, D1).

## Shared context: what the views get from ActivityClient

ActivityClient (started by ClientBase; depends on SharedTopNotificationUI) mounts the views once, in this fixed order
(ActivityClient 292): CourierClientView, PassengerClientView, TaxiClientView, DuelClientView. It forwards every
`ActivityEvent` payload to every view's `OnEvent` in a pcall (305-314). There is no unmount.

### ActivityHud (owner: ActivityClient, for reference)

- ScreenGui `ActivityHud`: DisplayOrder 84, IgnoreGuiInset true, ResetOnSpawn false, ZIndexBehavior Sibling (73).
  An existing `ActivityHud` is destroyed first (71-72). `Enabled` follows `FullMapOpen` only (75-77).
- `DesignRoot` Frame with a `UIScale` (78-79). `layoutRoot` (80-86):
  - desktop: `scale = clamp(min(vp.X/1920, vp.Y/1080), 0.72, 1.12)`
  - mobile: `scale = clamp(vp.Y/720, 0.55, 1)`
  - `root.Size = fromOffset(vp.X/scale, vp.Y/scale)`, so the root always covers the whole viewport. Children use
    scale-anchored positions with design-pixel offsets, which keeps edge clusters on the edges on ultrawide.
  - Re-runs on `ViewportSize` change of the camera that existed at start (88). No `CurrentCamera` re-hook.
- No safe-area or GuiInset handling anywhere in ActivityHud.
- DisplayOrder 84 is below DesktopFreeRoamHud (85) and MobileFreeRoamHud_Phase1 (88), so free-roam HUD elements draw
  over the strip, the offer card and the CHALLENGE button where they overlap.
- `isMobile = TouchEnabled and not KeyboardEnabled` (32). `ResponsiveUIFoundation.IsMobile()` is `TouchEnabled` only
  (Foundation 19-21). A touch laptop gets desktop ActivityHud layout but mobile strokes, corners and toast widths.
- Theme (33-43): 13 colour names read through `RacingUIComponents.Colour(name, fallback)` from
  `Config.UI.Racing.Colours`, plus `Font = Enum.Font.Michroma`. `Config.UI.Racing.Colours` has 12 values and **no
  `HighSpeed`**, so `ctx.Theme.HighSpeed` is always the literal `246, 83, 159` at ActivityClient 38.

### The ctx contract these five scripts rely on

Line numbers are the call sites in this group.

| Member | Used at | What the callers assume |
|---|---|---|
| `ctx.Root` | Duel 252 | GuiObject parent in design pixels under a UIScale. |
| `ctx.IsMobile` | Duel 251 | Boolean, read once at mount. |
| `ctx.Theme.Telemetry` | Job 274, 281; Duel 186; Passenger 111; Taxi 26 | Color3. |
| `ctx.Theme.HighSpeed` | Job 281, 304, 306; Duel 138, 222, 223, 257 | Color3. |
| `ctx.Theme.ElectricBlue` | Courier 33, 48 | Color3; line 33 assigns it to `Part.Color`. |
| `ctx.Theme.PanelDeep`, `.Text` | Duel 256, 258 | Color3. |
| `ctx.UI.Button(parent, props)` | Duel 252 | First return is a button the caller can set `.Text`, `.Visible`, `.AnchorPoint`, `.Position` on, read `.Parent` from, and connect `.Activated` and `.Destroying` on. Props passed: Name, Text, Size, Color, StrokeColor, TextColor. |
| `ctx.UI.Strip.Set(kind, text, colour?)` | Job 274, 281; Duel 223; Passenger 111 | Keyed by kind ("Taxi", "Courier", "Duel", "Passenger"). Newest Set wins. Called repeatedly with unchanged text: every 0.2 s by JobClient, every 0.4 s by PassengerClientView. Strip uppercases the text. |
| `ctx.UI.Strip.Clear(kind)` | Job 263; Duel 104; Passenger 114 | Safe to call when the kind is not set. |
| `ctx.UI.Offer(spec) -> close` | Duel 149, 181 | `spec = { Title, Body, Buttons = { { Text, Accent?, OnClick, Enabled? } }, Timeout? }`. One offer at a time; a new one closes the old one. A click closes the card, then runs `OnClick` in a new thread. `close()` is idempotent. **No callback on timeout or replacement.** |
| `ctx.UI.Countdown(goAtServerTime, label)` | Duel 220 | Replaces any current countdown; removes itself after GO. |
| `ctx.UI.Beacon(id, position, colour) -> remove` | Job 176, 306; Duel 222 | Same id replaces. Ids: `JobOffer_<offerId>`, `JobDestination`, `Duel`. |
| `ctx.Toast(text, seconds)` | Job x6; Duel x8; Passenger x4 | Fires `PlayerScripts.Runtime.UI.ShowTopNotification`. The notification controller uppercases every message (Foundation 522). |
| `ctx.Invoke(action, args) -> reply` | Job 147; Duel 112, 126, 156; Passenger 85 | Yields. Always returns a table with `Ok`. |
| `ctx.RouteGuide.SetDestination / Clear / GetActive` | Job 264, 283, 284, 301; Duel 103, 221 | The shared RouteGuide module. |

Not used by any of the five: `ctx.UI.Label`, `ctx.Jobs`, `ctx.Gui`, `ctx.Player`, `ctx.Theme.Font` and the other theme colours.

### What ctx.UI currently draws (ActivityClient, for sizing the restyle)

- **JobStrip** (99-122): 560 x 44 (460 x 44 mobile), top centre, y 18 (8 mobile). Label at x 16, width `1, -72`,
  TextSize 13, Heading role (Michroma bold), truncates at end. Cancel "X" button 36 x 30 (44 x 30 mobile) with a Danger
  stroke; it calls `Invoke("Cancel")` with no confirmation and is shown for every strip kind, including Passenger.
  About 10 instances, persistent.
- **Offer** (139-186): 560 x 170 (520 mobile), bottom centre, bottom edge at -190 (-150 mobile). Title 17, body 12
  wrapped in a 50 px box, buttons 44 tall (48 mobile) sharing the width equally, 3 px timer bar tweened over `Timeout`.
  Rebuilt from nothing each time. About 12 + 7 per button instances: about 47 for the five-button stake menu.
- **Countdown** (189-216): 220 x 220 card at (0.5, 0.42), number TextSize 96, a RenderStepped connection for its
  lifetime (about 4 s) that writes Text and TextColor3 every frame.
- **Beacon** (219-233): a 260-stud Neon cylinder plus a PointLight (Range 40, Brightness 2) parented to
  `workspace.CurrentCamera`. World object, not UI.
- **Toast**: SharedTopNotification ScreenGui (DisplayOrder 1100), stack at top centre, y `max(12, inset.Y + 10)`,
  max width 820 (280 on touch), text 15 (12 on touch), hard-coded grey gradient card (Foundation 529-538).

A `RacingUIComponents.Button` is 7 instances: TextButton, UICorner, GradientOverlay Frame with UICorner and UIGradient,
Stroke, GlowStroke. It connects MouseEnter and MouseLeave for hover (137-152) and has no focus, pressed or disabled
state and no TextTruncate.

---

## 1. JobClient

**1. Purpose and lifecycle.** Shared world-jobs client for Taxi and Courier. Presentation and intents only (header
1-10). Not started by itself: `TaxiClientView.Mount` and `CourierClientView.Mount` both call `JobClient.Mount(ctx)`;
the `mounted` flag (25, 403-404) makes the second call a no-op. Then each registers a kind with `RegisterKind`.
- Start: `Mount` finds or creates `Workspace.World.Runtime.ClientJobProps` (407-414; clears it if it exists), spawns
  `mirror()` (415) and connects a Heartbeat accumulator (416-423) and `ActivityKind` changed (424-427).
- Stop and cleanup: none. No Unmount. The Heartbeat connection, the `ActivityKind` connection, the folder
  ChildAdded/ChildRemoved connections (389-390) and one `AttributeChanged` connection per offer (242) are never
  disconnected. The per-offer one dies with the server-destroyed Configuration.
- State is module-level (24-36), so there is one JobClient per client through the require cache.

**2. Instance tree.** No ScreenGui and no GuiObjects. It creates:
- `World.Runtime.ClientJobProps` Folder (client-local).
- Per streamed-in offer: anchor Part `JobOffer_<id>` (2x2x2, transparent, 155-174), whatever `spec.BuildProp` adds
  (Courier: 3 Parts), and a beacon through `ctx.UI.Beacon` (176).
- On the driven car's root: Attachment `JobDriverPrompt` with ProximityPrompt `JobPrompt` (193-212).
- MapMarkers entries `JobOffer_<id>` (Kind "Job", Priority 20, Pulse, Color = kind colour; 226-229) and
  `JobDestination` (Kind "Activity", Priority 60, EdgeClamp, Color = HighSpeed; 302-305).
- RouteGuide source `"Job"` (284, 301).
- On-screen UI only through `ctx.UI.Strip` and `ctx.Toast`.

**3. Scaling and layout.** None of its own. Strip text inherits the strip's fixed width and TextSize 13.

**4. Config read.**
- `Config.Activities.Jobs` attributes, all 65 board tunables through `JobRules.ReadBoardConfig`, re-read every 2 s
  (44-49). The client uses `AcceptMaxMph` (361), `StreamRadius`, `StreamHysteresis` (365), `PromptDistance` (368) and
  `RoadFactor` (278).
- `Config.Activities.<Kind>.Enabled` and `Config.Activities.Jobs.Enabled` (51-55).
- No UI config.

**5. Dependencies and API.**
- State: `ReplicatedStorage.ActivityState.JobOffers` children (Configuration; attributes Kind, Position, Distance,
  Estimate, Label; 123-132, 384-392). LocalPlayer attribute `ActivityKind`. Vehicle attribute `OwnerUserId`,
  `DriverSeat` VehicleSeat, `CockpitRoot_DoNotRename`.
- Remote: `ctx.Invoke("JobAccept", { OfferId })` (147).
- Events through `OnEvent(kind, payload)`: `<Kind>:Started` (Destination, TripId, Distance, Pay, Boarding, Label),
  `:Driving` (TripId, ServerStartTime), `:Crash` (TripId, Crashes, DamageFactor), `:Completed` (Cash, Base,
  SpeedBonus, CrashPenalty, Crashes, Xp, Capped), `:Failed` (Reason), `:Cancelled` (Reason) (288-348).
- Modules: `JobRules` (pure), `Modules.Game.UI.MapMarkers` (optional, lazily required, 79-93), `ctx.RouteGuide`.
- Public API: `RegisterKind(spec)` (396-400), `Mount(context)` (402-428), `OnEvent(kind, payload)` (430-435).
  Spec fields used: Kind, Title, Icon, DropIcon, ActionText, DropLabel, StripTitle, BoardingText, Colour, StartedText,
  DoneTitle, FailTitle, CancelTitle, BuildProp. `Nearest` and `Order`, passed by both views, are never read (left over
  from the retired JOBS panel).

**6. Input.** One native ProximityPrompt (see "Native prompts"). No UserInputService, ContextActionService or
GuiService use. The strip's X is ActivityClient's.

**7. Polling and rebuilds.** Heartbeat accumulator runs `poll()` every 0.2 s (22, 417-423), in a pcall:
- `refreshBoard` (rate-limited to 2 s), `myPosition()` then `drivenRoot()` again (354-355: the driven root is resolved
  twice per poll).
- Loop over all offers (at most TaxiOffers 8 + CourierOffers 6 = 14): distance, `offerVisible` (which calls
  `kindEnabled`, 6 FindFirstChild and 2 GetAttribute per offer), create or drop the prop.
- `updateDriverPrompt` (375): writes ActionText, ObjectText and Enabled every poll while a target exists (213-217).
- During a trip, `updateTrip` (270-286) builds the strip text with `string.format` and calls `Strip.Set` every poll
  (5 Hz). The text changes about once a second. Each call allocates a table in ActivityClient and rewrites the label.
- `syncMarkers` once a second (378-381) plus on every add.
- Rebuilds: offer props are destroyed and recreated as offers stream in and out (hysteresis 150 studs) and all are
  dropped when a trip starts (299). The prompt Attachment is rebuilt only when the driven root changes (193-194).
- Instances: with MinOfferSpacing 700 and StreamRadius 600, usually 0 to 2 offers nearby, each 3 to 6 instances; the
  prompt is 2; a trip beacon is 2.

**8. Mobile.** No branch. The native prompt shows its own touch button on touch devices.

**9. Hard-coded look.** No colours, fonts or GUI sizes. World numbers: anchor size and +3 offset (166-167), beacon +9
(176), prompt attachment +4 (197), MaxActivationDistance 30 (204). Text formats are literal (116, 279-280, 320,
327-337).

**10. Defects.**
- 279 uses two spaces around the dot ("%s  %s  ·  %s"), 116 and the toasts use one. With TextSize 13 Michroma in a
  488 px label (388 px on mobile) the longest form, about 50 characters with a crash count, is likely to truncate.
- 281 re-sets the strip at 5 Hz with unchanged text; 354-355 resolves the driven root twice; 51-55 walks the config
  tree per offer per poll. Small, but all avoidable.
- 144 disables `entry.Prompt`, which is never assigned (only cleared at 137). Dead code; the real prompt is
  `driverPrompt.Prompt`, which the next poll disables.
- 327-337 sends the whole pay breakdown as one toast, up to about 95 characters: two lines on desktop (820 px), four or
  more on a phone (280 px).
- 215-216: ActionText is sentence case ("Give ride", "Pick up parcel", "Take job") while the passenger prompt is
  "RIDE".
- No GamepadKeyCode is set on the prompt (default ButtonX); the passenger prompt sets ButtonY.

**11. Seam.** All of it is logic except the strings. A new presentation needs no change here, provided
`ctx.UI.Strip`, `ctx.UI.Beacon`, `ctx.Toast` and the three theme colours keep their contract. Single-owner items that
must not be duplicated: the JobOffers mirror, marker ids `JobOffer_*` and `JobDestination`, RouteGuide source "Job",
`ClientJobProps`, the `JobDriverPrompt` attachment. No other script references these names (script_grep). FullMapUI
570 depends on `marker.Kind == "Job"`; MapIconLayer 44-47 uses the marker `Color` override ahead of its own tokens.

---

## 2. DuelClientView

**1. Purpose and lifecycle.** Street duel client: finds a nearby challengeable driver, shows the CHALLENGE button,
stake menu, incoming challenge card, countdown, finish beacon, route and result toast. Mounted once by ActivityClient
(last in the order). Returns `{ Mount, OnEvent }` (295).
- Start: `mount` (249-287) builds the button and connects a Heartbeat scan.
- Stop: the scan disconnects itself when `button.Parent` is nil (274-277). `button.Destroying` calls `clearActive`
  (265-267). No Unmount and **no mounted guard**: a second `Mount` would create a second button and scan.
- Module-level state (12-19): button, target, outgoing, incoming, stakeMenuClose, active, busyInvoke.

**2. Instance tree.** One TextButton `DuelChallengeButton` (7 instances) parented to `ctx.Root` in ActivityHud
(252-259). Everything else is drawn by ActivityClient on request: Offer card, Countdown, Strip, Beacon.

**3. Scaling and layout.**
- Size is fixed design pixels: 240 x 40 desktop, 240 x 52 mobile (255). AnchorPoint (0.5, 1) (260). Position
  `(0.5, 0, 1, -84)` desktop, `(0.5, 0, 1, -120)` mobile (262).
- The offset is chosen against another owner's layout: the comment at 261 says "above the free-roam CONTROLS / EXIT
  VEHICLE row (38 px tall at the bottom edge)". That row belongs to DesktopFreeRoamHud, which has its own UIScale read
  from `Config.UI.DesktopFreeRoamHud.Layout` (MinScale, MaxScale), while ActivityHud hard-codes 0.72 to 1.12. They
  match today only because the defaults are equal.
- Text: `Config.UI.Racing.Typography.Button` (14), Michroma bold, no TextScaled, no truncation, no size constraint.
- Scale on viewport change comes from ActivityHud's root. `mobile` is read once (251).
- No min or max clamp of its own, no safe-area handling.

**4. Config read.** `Config.Activities.Duels`: `ChallengeRange` (79; default 60, clamped 10 to 300) and `Enabled`
(165). Indirectly `Racing.Colours` and `Racing.Typography` through `ctx.UI.Button`. No layout config.

**5. Dependencies and API.**
- Invokes: `DuelChallenge { TargetUserId, Preview = true }` (126) returning `Ok, Message, Stakes, StakeMinRank`;
  `DuelChallenge { TargetUserId, Stake }` (112) returning `Ok, DuelId, ExpiresAt`; `DuelRespond { DuelId, Accept }`
  (156).
- Events: `Duel:Challenge` (DuelId, Stake, FromName, ExpiresAt; 174-190), `Duel:Closed` (DuelId, Message, Outcome;
  192-205), `Duel:Countdown` (DuelId, Finish, Pot, OpponentName, GoAtServerTime; 207-225), `Duel:Go` (empty, 227),
  `Duel:Result` (Cash, Xp, WinnerUserId, Outcome, Stake; 229-246).
- State read: `Workspace.World.Runtime.PlayerVehicles`; vehicle attributes OwnerUserId, RaceParticipant, RaceRunId;
  player attributes ActivityKind, RaceQueueActive, GarageSessionActive, OwnedGarageInside (49-65).
- RouteGuide source "Duel", strip kind "Duel", beacon id "Duel".
- Public API: `Mount(ctx)`, `OnEvent(payload)`.

**6. Input.** Mouse or touch on the CHALLENGE button and on Offer buttons only. No keyboard shortcut, no gamepad
binding, no `GuiService.SelectedObject`, no ContextActionService. A controller player can only reach these buttons by
entering Roblox's UI selection mode by hand.

**7. Polling and rebuilds.** Heartbeat accumulator, `refreshButton` every 0.25 s (9, 271-286):
- `duelConfig()` twice (165), then `findTarget` (68-89): for **every** vehicle in PlayerVehicles,
  `vehicle:FindFirstChild("DriverSeat", true)` (53), a recursive search of the whole car model, four times a second,
  for the life of the session, whether or not the player is driving (the early exit at 70 only checks `playerFree`).
- Writes `button.Visible` and `button.Text` each scan (167-168).
- Rebuilds: none of its own. Each stake menu or incoming challenge builds a fresh Offer card (about 47 and 26
  instances) in ActivityClient.

**8. Mobile.** Button height 52 instead of 40 and offset -120 instead of -84 (255, 262). At the phone scale of 0.55
that is about 132 x 29 real pixels: under the 44 px in the activities contract and the 48 px in the style sheet.

**9. Hard-coded look.** Size 240 x 40 / 240 x 52 (255); offsets -84 / -120 (262); anchor (260); colours by token:
PanelDeep fill, HighSpeed stroke, Text (256-258); stake accent HighSpeed (138); accept accent Telemetry (186). Three
UDim2 literals, no Color3 literals, no font literal. A private money formatter (34-39).

**10. Defects.**
- **D1 (functional).** 124 returns early while `stakeMenuClose` is set. It is cleared only by `closeStakeMenu`
  (92-98), which runs on a stake click, CANCEL, or `Duel:Countdown`. When the Offer card times out after 15 s
  (ActivityClient 182) or is replaced by another offer (ActivityClient 141), ActivityClient closes the card but the
  view is never told, so `stakeMenuClose` stays set and CHALLENGE stays visible and inert until the next
  `Duel:Countdown`. The same gap leaves a stale `incoming[duelId]` when a second challenge replaces the first card
  (181), until the server sends `Duel:Closed`.
- 168 with 255: "CHALLENGE " plus an uppercased DisplayName (up to 20 characters) in a 240 px button at Michroma 14
  bold with no truncation. Long names overflow the button.
- 262: position coupled to another ScreenGui's row height and scale (see 3).
- Mobile: the stake Offer card's bottom edge is at -150 and the button's top is at -172, so they overlap by 22 design
  pixels; the button is not hidden while the stake menu is open (166-167 do not test `stakeMenuClose`).
- 53: recursive seat search per vehicle at 4 Hz.
- 34-39: second money formatter (the third is `JobRules.Money`); the shared one is
  `ResponsiveUIFoundation.FormatCompactMoney`. Output differs only from $1,000,000 up, so nothing is visibly wrong at
  today's stakes.
- 138: a cash stake is signalled only by a pink outline. Under the style sheet an action that spends Cash is a yellow
  Buy button.
- 116, 118, 129 and others: toasts are written in sentence case but the notification controller uppercases them.

**11. Seam.** State and intents: 21-89, 100-120, 152-246. View construction: 122-150 (builds the Offer spec),
162-169 (button text and visibility), 249-264 (button). A new presentation can leave this file alone if the new
`ctx.UI.Button` returns a TextButton-rooted object and accepts (or ignores) Color, StrokeColor and TextColor, and if
the new HUD still has room at bottom centre 84 design pixels up. If the new free-roam bottom row changes height, the
offset at 262 is the one number in this group that must move. `DuelChallengeButton` is referenced by no other script.

---

## 3. PassengerClientView

**1. Purpose and lifecycle.** Shows a local RIDE prompt on other players' PassengerSeat when access allows, sends the
`Ride` intent, shows the riding strip, and toasts joins and leaves. Mounted once by ActivityClient.
- Start: `Mount` (150-163) spawns an endless `while true` loop that runs `refresh` every 0.4 s in a pcall, and
  connects `Players.PlayerRemoving`.
- Stop: none. No Unmount, **no mounted guard**. Per-prompt `Triggered` connections are disconnected in `removePrompt`
  (57-63).

**2. Instance tree.** No GuiObjects. One ProximityPrompt `PassengerRidePrompt` per eligible streamed-in seat, parented
to the seat (69-79). Strip through `ctx.UI.Strip` kind "Passenger".

**3. Scaling and layout.** None. `prompt.UIOffset = (0, 40)` (78) is in screen pixels and does not scale; it exists to
sit under the server's Enter prompt.

**4. Config read.** None. `Config.Activities.Passengers` has `Enabled`, `FriendCacheSeconds` (120) and
`RideRangeStuds` (18), but the view hard-codes 120 s (13) and 14 studs (76) and never checks `Enabled`.

**5. Dependencies and API.**
- Invoke: `Ride { OwnerUserId }` (85).
- Events (165-185): `Passenger:Allowed` (OwnerUserId, Seconds), `Taxi:RequestAccepted` with Role "Rider"
  (DriverUserId), `Passenger:Revoked`, `Passenger:Joined` (Name), `Passenger:Left` (RiderUserId, Name, Reason).
- State: owner attribute `PassengerAccess`; `localPlayer:IsFriendsWith` (web call, cached, 31-40); vehicle attributes
  OwnerUserId, RaceParticipant, RaceRunId; owner attributes RaceQueueActive, GarageSessionActive, OwnedGarageInside;
  `seat.Occupant`.
- Public API: `Mount(ctx)`, `OnEvent(payload)`.

**6. Input.** Native prompt only: F on keyboard, ButtonY on gamepad, tap on touch (73-74).

**7. Polling and rebuilds.** Every 0.4 s (12): `riderStrip`, then for every vehicle in PlayerVehicles
`vehicle:FindFirstChild("PassengerSeat", true)` (126), a recursive search per car at 2.5 Hz. While riding it calls
`Strip.Set` every 0.4 s with the same text (111), which also moves "Passenger" back to the top of the strip order each
time. Prompts are created once per seat and reused (65-67).

**8. Mobile.** No branch.

**9. Hard-coded look.** No colours, fonts or GUI sizes. ActionText "RIDE", ObjectText the owner's DisplayName,
MaxActivationDistance 14, UIOffset (0, 40). Strip text literal at 111.

**10. Defects.**
- 111: strip text "RIDING WITH <name> · JUMP TO EXIT" is up to 47 characters; likely truncated in the mobile strip.
  "JUMP TO EXIT" is a keyboard instruction shown to touch players too.
- 111: redundant re-set at 2.5 Hz that also reorders the strip.
- 126: recursive seat search per vehicle.
- 13, 76: config values exist but are not read; `Enabled` is not honoured on the client.
- The strip's X (ActivityClient 106-111) is shown for a rider and calls `Cancel`, which is a job action.

**11. Seam.** All logic. Nothing to change for a restyle except the prompt's look, which is not reachable through
`ctx` (see "Native prompts"). `PassengerRidePrompt` is referenced by no other script.

---

## 4. CourierClientView

**1. Purpose and lifecycle.** Registers the Courier kind with JobClient and forwards `Courier:*` events. Mounted first
by ActivityClient; `Mount` (36-59) calls `JobClient.Mount(ctx)` and `RegisterKind`. No connections, no cleanup.

**2. Instance tree.** None of its own. `buildParcel` (15-34) adds three anchored, non-colliding Parts under the offer
anchor: Parcel, ParcelTop (Cardboard) and Band (Neon).

**3. Scaling and layout.** None.

**4. Config read.** None directly (JobClient reads `Config.Activities.Courier.Enabled`).

**5. Dependencies and API.** `JobClient`, `JobRules.Miles`. Public: `Mount(ctx)`, `OnEvent(payload)` (61-64, forwards
payloads whose Type starts "Courier:").

**6. Input.** None.

**7. Polling and rebuilds.** None. `buildParcel` runs each time a courier offer streams in.

**8. Mobile.** None.

**9. Hard-coded look.** One Color3 literal: cardboard `176, 128, 80` (30), a world prop colour and marked as such.
Kind colour `ctx.Theme.ElectricBlue` (48) and the Neon band (33). Strings at 40-57.

**10. Defects.** 41 `Nearest` and 49 `Order` are dead fields. 33 puts a UI theme colour on a world part, so changing
the UI palette changes the parcel band.

**11. Seam.** Nothing to change. The only restyle decision is what `ElectricBlue` becomes (below).

---

## 5. TaxiClientView

**1. Purpose and lifecycle.** Registers the Taxi kind with JobClient and forwards `Taxi:*` events. Mounted third.
`Mount` (14-35). No connections.

**2 to 8.** No instances, layout, config, input, polling or mobile branch of its own. Depends on `JobClient` and
`JobRules.Miles`. Public: `Mount(ctx)`, `OnEvent(payload)` (37-40).

**9. Hard-coded look.** Kind colour `ctx.Theme.Telemetry` (26). Strings at 18-33.

**10. Defects.** 19 `Nearest` and 27 `Order` are dead fields. Note that `Taxi:RequestAccepted` is also consumed by
PassengerClientView (168); JobClient ignores it because it has no `RequestAccepted` handler.

**11. Seam.** Nothing to change.

---

## Colours passed as meaning

The five style-sheet roles are Slate, White, Ink, Pink, Violet, Cyan, Yellow (plus Danger as an exception). The views
pass three old tokens as meaning. Every one must stay a `Color3`, because they reach `Part.Color` (Courier 33),
`PointLight.Color` and Part.Color in the beacon (ActivityClient 224, 227) and MapMarkers, which drops anything that is
not a Color3 (MapMarkers 34) and then falls back to MapIconLayer's own token.

| Old token (RGB) | Where | Meaning | Closest new role | Gap |
|---|---|---|---|---|
| Telemetry (43, 225, 218) | Job 274, 281 strip; Passenger 111 strip | Live status readout | Cyan (live values) | None. |
| Telemetry | Taxi 26, then Job 176 beacon, 228 map marker | Taxi job identity | Cyan | Collides with Courier if both become Cyan. |
| Telemetry | Duel 186 ACCEPT button accent | Positive or confirm action | Main button (Pink to Violet) | The sheet has no "confirm" colour; it has a main button. |
| ElectricBlue (25, 116, 255) | Courier 48, then Job 176 beacon, 228 map marker | Courier job identity | None | No blue in the new palette. |
| ElectricBlue | Courier 33 Neon band on the parcel | World prop accent | Not UI | Should stop reading the UI theme. |
| HighSpeed (246, 83, 159) | Job 304 marker, 306 beacon; Duel 222 beacon | Destination or objective | Pink, or Cyan ("route lines") | The sheet puts routes in Cyan and accents in Pink; needs a ruling. |
| HighSpeed | Job 281 strip when crashes > 0 | Warning or penalty | None | Danger is reserved for destructive buttons. |
| HighSpeed | Duel 223 strip | Duel active | Pink | Fine. |
| HighSpeed | Duel 138 stake button accent | This button spends Cash | Yellow Buy button | Must become Yellow under "Cash only". |
| HighSpeed | Duel 257 CHALLENGE button stroke | Decoration | None (no structural outlines) | Drop. |

Inside ActivityClient the same tokens also colour: strip default stroke (Telemetry), offer timer fill (Telemetry),
"GO!" (Telemetry), rank-up kicker (Telemetry), rank-up cash reward (ElectricBlue, which was the old cash colour and
becomes Yellow), offer and countdown outlines (Outline).

Two ways to bridge without editing the five views:

- **Map by value inside the new ctx.** The new `ctx.Theme` keeps the three names as distinct Color3 values, and the
  new `ctx.UI.Offer` and `ctx.UI.Strip` translate by equality: `Accent == Theme.HighSpeed` gives the Buy variant,
  `Accent == Theme.Telemetry` gives the main variant, strip colour `HighSpeed` gives the alert variant. Zero edits to
  the views. Works because Color3 compares by value. The cost is an implicit convention.
- **Add semantic fields later.** Views pass `Role = "Cash" | "Confirm" | "Alert" | "Objective"` beside the colour.
  The old ctx.UI ignores unknown fields, so the old style still works. Cleaner, but it edits the shared logic files.

Job identity in the world (beacons, map icons) is information, like the medal and paint-swatch exceptions in the
sheet. The icons already differ (TaxiFare, CourierPickup, TaxiDrop, CourierDrop in `Config.UI.MapIcons`), so both jobs
could share Cyan and rely on the icon, or a small "world marker" palette could be added as a documented exception.

## Native prompts

| | JobClient `JobPrompt` (198-217) | PassengerClientView `PassengerRidePrompt` (69-79) |
|---|---|---|
| Parent | Attachment `JobDriverPrompt` at +4 on the driven car root | The other player's PassengerSeat |
| ActionText | spec.ActionText: "Give ride", "Pick up parcel", fallback "Take job" | "RIDE" |
| ObjectText | "TAXI FARE · LABEL · 1.2 MI TRIP · ~$1,234" (offerLabel, 112-117) | Owner's DisplayName |
| Keys | E; gamepad default (ButtonX) | F; ButtonY |
| HoldDuration | 0 | 0 |
| MaxActivationDistance | 30 | 14 |
| RequiresLineOfSight | false | false |
| Exclusivity | AlwaysShow | default |
| UIOffset | default | (0, 40) |
| Style | default (not set) | default (not set) |

Both use Roblox's built-in prompt look. So do the four other prompts in the place (GarageEntranceClient,
TimeTrialServer, OwnedGarageManagement, VehicleAccessServer). No script sets `ProximityPromptStyle.Custom` or listens
to `ProximityPromptService.PromptShown`. The style sheet says the only key cap is on the world Start/interact banner,
which is one of these native prompts today.

Restyling prompts therefore means one new global client renderer for all six prompts, with each prompt's `Style` set
to Custom. That is a new owner and it touches server scripts, so it is a separate decision from the ctx.UI restyle.
If it is done, a renderer that only draws when the style flag is on, and leaves `Style` at Default when it is off,
keeps the old look as the fallback. The job prompt's long ObjectText needs a two-line layout in any custom design.

## Defects, in priority order

1. **D1** Duel stake menu timeout or replacement leaves CHALLENGE visible but inert (Duel 92-98, 124, 149;
   ActivityClient 141, 178-183). The Offer contract has no close notification.
2. **Phone scale.** `clamp(vp.Y/720, 0.55, 1)` (ActivityClient 83) gives 0.55 on a phone about 390 px tall. CHALLENGE
   240 x 52 becomes about 132 x 29 px; Offer buttons about 26 px tall; the strip's X about 24 x 17 px; strip text
   13 becomes 7 px. All under the 44 px contract and the sheet's 48 px and 11 px minimums. Sizes in Duel 255 assume
   scale 1.
3. **Desktop clamp.** 0.72 to 1.12 with text at 12 to 13 design px: at 1280x720 strip and offer text is about 9 px;
   at 3840x2160 the whole Street Life HUD is 56% of its 1080p relative size.
4. **Fixed-width text.** Strip 560/460 with truncation (ActivityClient 99-104) against composed strings of up to 50
   characters (Job 279-280, Passenger 111); CHALLENGE button overflows on long names (Duel 168, 255).
5. **Polling.** Recursive `FindFirstChild(name, true)` on every vehicle at 4 Hz (Duel 53) and 2.5 Hz (Passenger 126);
   strip re-set at 5 Hz and 2.5 Hz with unchanged text (Job 281, Passenger 111); double `drivenRoot` (Job 354-355).
6. **Colour meaning.** `HighSpeed` carries five meanings and is not a config value (ActivityClient 38); a cash stake
   is marked only by a pink outline (Duel 138).
7. **Controller.** No gamepad route to CHALLENGE or to Offer buttons (accept or decline a duel).
8. **Coupled and overlapping layout.** CHALLENGE offset hard-coded against the free-roam bottom row (Duel 261-262);
   on mobile the stake card overlaps the button by 22 design px; the job strip (top centre, y 18 to 62) and the toast
   stack (top centre, y `inset + 10`) are positioned by two unrelated rules and sit within a few pixels of each other.

Lower priority: Passenger view ignores its config folder (13, 76); three money formatters (Duel 34-39, JobRules
780-786, Foundation 108-113); mixed prompt text case; dead spec fields `Nearest` and `Order`; dead `entry.Prompt`
(Job 144); no Unmount on any view; `Mount` unguarded in Duel and Passenger; a job result with a pay breakdown is a
long wrapping toast (Job 327-337).

## The seam for a switchable presentation

**Leave all five scripts untouched.** They are the shared logic for both styles, not "old UI".

**Switch inside ActivityClient.** Today ActivityClient builds the theme (33-43), the root (70-88) and the five
`ctx.UI` helpers (90-233) inline. The cleanest change:

1. Move that drawing code, unchanged, into a module such as `ActivityHudClassic` that returns
   `{ Theme, Root, Gui, UI = { Button, Label, Strip, Offer, Countdown, Beacon }, RankUp }`.
2. Write `ActivityHudPulse` with the same return shape, built from the shared Pulse components (Panel, Button, Main
   button, Buy button).
3. ActivityClient reads the Core.FeatureFlags style flag once at start, picks one, and builds `ctx` from it. Exactly
   one `ActivityHud` ScreenGui exists either way. Views are mounted once, as now.

Switching back is the flag plus a new Play session, matching the style sheet ("takes effect on the next Play start").
A live swap is not possible without adding Unmount to every view, because the views cache `ctx` and the button.

**What the Pulse ctx.UI must honour** (from the contract table above):

- `Button` returns a TextButton-rooted object (decoration as children) so `.Text`, `.Visible`, `.Position`,
  `.AnchorPoint`, `.Activated`, `.Destroying` and `.Parent` keep working; it must accept Color, StrokeColor and
  TextColor props without erroring.
- `Strip.Set` is called up to 5 times a second with unchanged text: compare before writing, never animate per call,
  size the strip to its text (or use two lines) instead of truncating.
- `Offer` keeps one-at-a-time, click-closes-then-calls, idempotent `close`, and `Enabled == false`. Adding an optional
  `OnClosed` field would let D1 be fixed, but fixing D1 needs a small edit in DuelClientView.
- `Beacon` ids and replace-by-id; `Countdown` replace and self-remove.
- Theme values stay Color3 and keep all 13 names plus `Font`.
- `ctx.Root` stays a design-pixel parent; `ctx.IsMobile` stays a boolean.

**Must stay single-owner:** the `ActivityHud` ScreenGui; the `ActivityEvent.OnClientEvent` connection and
`ActivityInvoke` calls (ActivityClient); the JobOffers mirror, `JobOffer_*` and `JobDestination` markers, RouteGuide
sources "Job" and "Duel", `ClientJobProps`, `JobDriverPrompt`; `PassengerRidePrompt` on seats; the
`ShowTopNotification` listener (SharedTopNotificationUI).

**References to this group's instance names from other scripts:** none found for `ActivityHud`, `DuelChallengeButton`,
`JobStrip`, `JobPrompt`, `JobDriverPrompt`, `PassengerRidePrompt`, `ClientJobProps`, `ActivityBeacon_`,
`JobDestination`. External couplings are by data: `marker.Kind == "Job"` (FullMapUI 570), the marker `Color` override
(MapIconLayer 44-47), the `FullMapOpen` and `ActivityKind` attributes, and the icon keys in `Config.UI.MapIcons`.

## Not checked

- Nothing was run in Play. Phone and 720p sizes are from the formulas; text widths are estimates for Michroma.
- Whether Roblox reports a phone viewport of about 390 px tall in v3 was not measured.
- Overlap between the job strip, the toast stack, the onboarding objectives and the free-roam HUD was reasoned from
  positions, not captured.
- Server payloads were taken from what the views read, not from the server modules.
- The `Cancel` action's effect for a rider or during a duel was not traced on the server.
