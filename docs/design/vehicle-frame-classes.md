# Vehicle frame classes: more categories for modular construction

**Status: Design - not approved.** Round 2, written 2026-10-01 from the repository, the live vehicle assets in Space Racers Backup v2 (place 133417340424236, Edit, read-only inspection) and Oscar's reference images and feedback. No game code, saved data or live vehicle assets were changed. Blockout models exist in a Workspace folder in the backup place only.

Round 2 applies Oscar's feedback on round 1:

- **No wheels and nothing wheel-like.** Lift and thrust come from jets and thrusters.
- **Engines, stabilisers and boost are fundamental.** Every cockpit in every class carries them as real, visible modules. Where they sit is up to the class.
- **Swaps must fit well, look great and still look different** from other cockpits' modules.
- **Three new classes of realistic cars as hover jets.** Likeness to real cars is fine.
- **Everything from round 1 refined** under the same rules.

## 1. Player goal

Pick the kind of machine you love (a muscle car, a supercar, a drift tuner, a hot rod, a bike, a track car, a truck, a pure sci-fi racer), then build it your way from parts that always fit. Every part in a class fits every cockpit in that class, the result always looks like one vehicle, and every choice visibly changes it.

## 2. What exists today

Verified in Studio on 2026-10-01:

- One category: folder `PIERCER`, `CategoryId = bruiser`, six cockpits. A cockpit is about 8 W x 6 H x 17 L studs. A full Piercer with its kit is 20.5 W x 7.6 H x 29.2 L.
- Eight slots on every cockpit: `Engine1`, `Engine2`, `Stabilisers`, `Boost`, `FrontBumper`, `RearBumper`, `RearSpoiler`, `SidePods`. Engines, stabilisers and boost carry the performance.
- Each cockpit already has its own Standard, Lightweight and Power engine, stabiliser and boost modules, and `Default...ModuleId` attributes naming them.
- Every slot mount sits at the cockpit root origin. Modules are authored in cockpit-root space, so a module fits every cockpit only if the cockpits share the same hardpoints.
- Paint channels (Primary, Secondary, Detail, Glass, Neon, plus Underglow and thrust colour) recolour cockpit and modules together.
- The dealership browser already lists "ALL" plus one button per category, and the free-roam car menu has a category filter.

## 3. The proposal in one page

**A category is a frame class.** A frame class is a layout plus a published **frame standard** that every cockpit and module in the class is built to. Culture and style are tags inside a class, never a fitting restriction.

| Level | What it is | Example |
|---|---|---|
| Frame class (`CategoryId`) | A layout and its frame standard. Parts interchange only inside a class. | Muscle |
| Cockpit | The cabin. Belongs to one class. Has a signature kit. | Fastback |
| Signature kit | One module for every slot, designed with one cockpit. Carries a culture tag. | Classic |
| Module | One part for one slot of one class. | Shaker Turbine (Hood Engine) |

### Slots

| Slot ID | Kind | Meaning in every class |
|---|---|---|
| `Engine1` | Fundamental | A jet engine. Visible intake, body and nozzle. |
| `Engine2` | Fundamental | A second jet engine, somewhere else on the vehicle. |
| `Stabilisers` | Fundamental | Hover stabiliser hardware: lift jets, vectoring nozzles, vanes with jet tips. |
| `Boost` | Fundamental | The boost unit: afterburner cans, a slot burner, staged stacks. |
| `FrontBody` (new) | Body | Front half, front clip, nose or prow. |
| `RearBody` (new) | Body | Rear half, rear clip, engine deck, tail or bed. |
| `SidePods` | Body | Mid section, sills or flanks. |
| `FrontBumper`, `RearBumper`, `RearSpoiler` | Body | As today. |
| `Hood`, `Roof`, `Accessory` (new) | Cosmetic | Optional trim. Used by Rider and Hauler. |

The eight existing slot IDs keep their meaning, so the performance, upgrade and save systems carry over. Your "front half, back half, middle section" are `FrontBody`, `RearBody` and `SidePods`. Each class sets its own player-facing labels.

### Where the fundamentals sit

| Class | Engine1 | Engine2 | Stabilisers | Boost |
|---|---|---|---|---|
| Rift | Front Engines, under the front nacelles | Rear Engines, behind the rear-quarter pods | Stabilisers, under the cabin on outriggers | Afterburner, centre tail |
| Muscle | Hood Engine, through the bonnet | Tail Engine, in the tail panel | Lift Jets, in the blanked arches | Side Burners, along the sills |
| Exotic | Main Turbine, behind the cabin | Side Engines, on the flanks | Stabilisers, at the corners | Afterburner, high centre tail |
| GT | Front Engine, in the bonnet | Rear Engine, in the tail | Lift Jets, at the corners | Afterburner, where the exhausts were |
| Street | Bonnet Engine | Tail Engine, in an open bay | Arch Jets | Exhaust Burner |
| Rodder | Front Engine, exposed on the rails | Side Jets, long barrels beside the cab | Axle Jets, on the front beam | Headers |
| Rider | Main Turbine, under the tank | Rear Thruster, on the swingarm | Lift Fork, at the front | Afterburner, the exhaust |
| Apex | Power Unit, behind the driver | Shoulder Jets | Corner Thrusters, on wishbones | Afterburner |
| Cruiser | Bonnet Turbine | Boot Turbine | Sill Jets | Tail Burner |
| Hauler | Hood Engine | Bed Engine, large, in the bed | Lift Jets, at the corners | Stacks |
| Dart | Main Drive, at the tail | Wing Engines | Airbrakes, with control jets | Afterburner |
| Tether | Tow Engines, the big pair ahead | Pod Thruster | Engine Vanes | Afterburners |

Every class has six options in each of the four slots (five in Street and Rodder), and each option shows a glowing nozzle.

### The frame standard (why parts always fit)

1. **Cockpit envelope.** A box every cockpit in the class stays inside.
2. **Slot envelopes.** One box (or union of boxes) per slot. Envelopes never overlap, so nothing can clip.
3. **Seams.** Each slot names the face where it meets its parent. Every parent reaches the seam and so does every module.
4. **Contact.** Every module comes within 0.6 studs of every cockpit or parent module it could sit on. The validator checks every pair. This is what stops floating parts.
5. **Hardpoint pads.** Each parent carries fixed flat pads at set positions, and modules land on pads, never on a body shape. In practice **every cockpit in a class ships the same chassis** under a different cabin.
6. **Shadow gap and linkage.** A 0.2 to 0.6 stud gap bridged by dark linkage hides the join between unlike parts.
7. **Datums.** A fixed beltline, sill height and hover plane per class keep body lines straight across the gaps.
8. **Paint unifies.** Every part declares a paint channel, so a mixed build still reads as one vehicle.
9. **One surface, one owner.** The cockpit owns all glass and the roofline. Each arch, nose, fin and pod belongs to one slot.
10. **Signature kits.** Each cockpit has its own kit. This matches the live game, where each cockpit already has its own default engine, stabiliser and boost modules. Any cockpit can wear any other cockpit's kit.
11. **Distinctness.** Options for one slot must differ in outline, not only in detail. The validator scores this from side, top and front outlines after removing the area every option shares (the pads and seams the standard forces on all of them). Target: 0.35 or more for the big slots, 0.25 for small ones and for cockpits.

This matches how the live system already works (all mounts at the root origin). It needs no new attachment code. The standard is a build rule plus a validator, not a runtime system.

## 4. The frame classes

Twelve new classes plus the existing Piercer. Each links to its class sheet (pitch, cockpits, kits, modules, handling intent, concept images) and its frame sheet (envelope numbers, pads and authoring rules from the blockout).

| Class (`CategoryId`) | Fantasy | Culture it taps | Cockpits in the blockout | Sheets |
|---|---|---|---|---|
| Piercer (`bruiser`) | Compact pod-kit racer | The game's own look | existing six | existing |
| **Muscle** (`muscle`) | American muscle and pony cars, one-piece bodies | Classic Muscle, Pro Street, Trans-Am, Modern Muscle, Pony, Restomod | Fastback, Hardtop, Notch, Modern, Ragtop, Ute | [class](vehicle-categories/muscle.md), [frame](vehicle-categories/muscle-frame.md) |
| **Exotic** (`exotic`) | Mid-engined supercars and hypercars | Wedge, Analogue, Hypercar, Track Special, Longtail, Concept | Wedge, Curve, Hyper, Spider, Longtail, Gull | [class](vehicle-categories/exotic.md), [frame](vehicle-categories/exotic-frame.md) |
| **GT** (`gt`) | Front-engined sports cars and grand tourers | Classic GT, Rear-Engine Sports, Modern GT, Roadster, Shooting Brake, GT3 | Longnose, Teardrop, Bruiser, Roadster, Brake, Gullwing | [class](vehicle-categories/gt.md), [frame](vehicle-categories/gt-frame.md) |
| **Rift** (`rift`) | Classic coupé sliced into floating sections | Muscle, Pro Street, Wedge Exotic, Euro GT, Roadster, Turbo Pony | Brawler, Outlaw, Stiletto, Regent, Mamba, Nightshift | [class](vehicle-categories/rift.md), [frame](vehicle-categories/rift-frame.md) |
| **Street** (`street`) | Tuner with clip-on aero | Touge, Kanjo, Drift, Time Attack, Rally | Touge, Pocket, Syndicate, Roadster, Estate | [class](vehicle-categories/street.md), [frame](vehicle-categories/street-frame.md) |
| **Rodder** (`rodder`) | Hot rod and jet dragster | Highboy, T-Bucket, Rat Rod, Slingshot Drag, Salt Flat | Deuce, Bucket, Rat Cab, Slingshot, Lakester | [class](vehicle-categories/rodder.md), [frame](vehicle-categories/rodder-frame.md) |
| **Rider** (`rider`) | Jet hoverbike | Supersport, Café Racer, Chopper, Motocross, Streetfighter, Speeder | Supersport, Cafe, Chopper, Scrambler, Streetfighter, Speeder | [class](vehicle-categories/rider.md), [frame](vehicle-categories/rider-frame.md) |
| **Apex** (`apex`) | Circuit racer | Formula, Vintage Grand Prix, Prototype, Wing Car, Speedway Sprint, Stock Oval | Formula, Cigar, Prototype, Wingcar, Sprint, Oval | [class](vehicle-categories/apex.md), [frame](vehicle-categories/apex-frame.md) |
| **Cruiser** (`cruiser`) | Long, low land yacht | Lowrider, Lead Sled, Fin Era, VIP, Kaido Racer, Surf Wagon | Hardtop, Sled, Finliner, VIP, Kaido, Longroof | [class](vehicle-categories/cruiser.md), [frame](vehicle-categories/cruiser-frame.md) |
| **Hauler** (`hauler`) | Truck and van | Prerunner, Lifted, Minitruck, Show Truck, Cab, Courier | Single Cab, Crew Cab, Kei Cab, Cab-Over, Checker Cab, Van Nose | [class](vehicle-categories/hauler.md), [frame](vehicle-categories/hauler-frame.md) |
| **Dart** (`dart`) | Anti-grav racing dart | Record Breaker, Works Team, Prototype, Privateer, Salvage, Interceptor | Needle, Delta, Manta, Twinboom, Bubble, Arrowhead | [class](vehicle-categories/dart.md), [frame](vehicle-categories/dart-frame.md) |
| **Tether** (`tether`) | Pod racer | Scrapyard, Desert, Works, Showboat, Harbour, Atomic | Bucket, Sled, Capsule, Chariot, Skiff, Bubble | [class](vehicle-categories/tether.md), [frame](vehicle-categories/tether-frame.md) |

Why these splits:

- **A class boundary is a layout boundary, not a style boundary.** Hot rods and drag rails share one class because both are "narrow cab, exposed engine, long side jets". Drift, time attack and rally share one class because they are the same body with different clip-on parts. This keeps part pools large.
- **The three realistic classes split by where the engine and cabin sit.** Muscle is long bonnet and short deck. Exotic is cab-forward with the engine behind the cabin. GT is the balanced front-engined sports car. Each has real-car proportions, so they cannot share seams.
- **Rift and Muscle are both muscle-led.** Rift is the split, floating-section look from the first reference images. Muscle is the one-piece realistic car.
- **Each class drives differently** inside the same performance budget. Intent only, tuned later through the existing calibration tools:

| Class | Strong | Weak |
|---|---|---|
| Muscle | Acceleration, boost, straight-line speed | Braking, tight turns |
| Exotic | Top speed, grip, braking | Contact, rough streets |
| GT | Balance, stability at speed, steering | No single standout stat |
| Rift | Top speed, boost, long drifts | Weight, tight turns |
| Street | Drift control, steering, agility | Top speed, contact |
| Rodder | Acceleration, boost force | Sideways grip, braking |
| Rider | Steering, squeezing through gaps | Contact, stability |
| Apex | Grip, braking, downforce | Drift, contact |
| Cruiser | Stability, straight-line speed | Steering, acceleration |
| Hauler | Contact, stability, boost torque | Steering, top speed |
| Dart | Top speed, airbrake turns | Low-speed handling |
| Tether | Extreme speed and boost | Width, stability, tight streets |

## 5. Player flow

Entry, states and exit stay as they are today. Only the content of each screen grows.

1. **Dealership (buy a cockpit).** Entry: E or tap at the dealership prompt. The browser's left list becomes a **class rail**: one `ModuleCategoryCard`-style tile per class with a silhouette icon and name, vertical on PC, horizontal on landscape phones. Choosing a class filters the `VehicleCard` grid. A culture filter and the existing sort control sit side by side with identical size. A cockpit arrives with its signature kit fitted, as cockpits arrive with their default modules today. Exit: Buy, Buy Another or Back.
2. **Class intro (first visit to a class only).** One dismissible panel: the class silhouette, three lines on how it drives, and the slot map. It is a state of the browser, not a new screen owner.
3. **Customisation (three workshops, unchanged).** Add Modules, Upgrade Modules, Paint Shop. The slot rail is built from the cockpit's own `ModuleSlots` folders in `Order`, using each slot's `DisplayName`. Engines, stabilisers and boost come first. Listing cards gain a small culture tag and a kit marker. Owned and Buy lists and the Buy, Equip and Customise actions are unchanged.
4. **Free roam car menu.** The existing category filter lists every owned class.
5. **Exit and cleanup.** Unchanged: previews are transient and owned by the existing preview lifecycle.

States that need care: a player who owns no cockpit in a class sees that class's tile with a "from $X" price, not an empty grid; a class with no published content is hidden by the catalogue, not by the UI.

### Inputs

| Action | PC | Touch (LandscapeSensor) | Controller |
|---|---|---|---|
| Move along class rail | Mouse, W/S or arrows | Tap; swipe to scroll | D-pad or left stick up/down |
| Move between rail and grid | Mouse, A/D or arrows | Tap | D-pad or left stick left/right |
| Select | Click, Enter | Tap (target 44 to 48 px) | A |
| Back or close | Escape | Back button | B |
| Culture filter, sort | Click | Tap | X opens, D-pad chooses, A confirms |
| Orbit preview | Drag | One-finger drag in the preview area | Right stick |

One responsive composition through `Shared.LayoutGarageShell`. No portrait layout. No nested vertical scrolling.

## 6. Reused components and tokens

No new visual language is needed.

- `GarageComponents.VehicleCard` for every cockpit card. No second card renderer.
- `GarageComponents.ModuleCategoryCard`, `ModuleCard`, `ModuleListingCard`, `Popup`, `ActionButton`, `AnchoredDropdown`, `ConfirmationModal`, `UpdateHorizontalCardCanvas`.
- `Shared.LayoutGarageShell` for layout; `RacingUIComponents` and `ResponsiveUIFoundation` for primitives.
- `Config.UI.Theme` tokens. Pink for structure, cyan for selection, blue for purchase, red for destructive. Tier colours never mark selection.
- Per-slot preview camera angles from `Config.UI.GarageReplacement` attributes. No page-specific camera writer.

Exceptions to record if approved: (a) class silhouette icons are new art; (b) the slot rail's hard-coded `artworkDefinitions` in `GarageWorkspaceUI` becomes data read from the slot folders; (c) the culture tag is a new small label on `ModuleListingCard`, built from existing primitives.

## 7. New configuration

All on the authoring folders in `ServerStorage.Assets.Vehicles.Categories`.

| Where | Attribute | Purpose |
|---|---|---|
| Category folder | `FrameStandardVersion` | Bumps when envelopes change. |
| Category folder | `ClassIcon`, `ClassBlurb`, `ClassOrder` | Class rail tile and intro panel. |
| Category folder | `HandlingBias_<Stat>` (default 0) | Design-time bias read by the calibration tools, not at runtime. |
| Category folder | `PreviewCameraDistance`, `PreviewCameraHeight` | A bike and a pod racer need different framing. |
| Category folder | `CollisionProfile` | Names the class's simple collision hull. |
| Slot folder (existing) | `DisplayName`, `Order` | Already present. Now the only source for the slot rail. |
| Slot folder | `CosmeticOnly`, `IconId` | Cosmetic slots are excluded from performance. |
| Cockpit | `SignatureKitId` | The kit a new cockpit arrives with. Feeds the existing `Default...ModuleId` attributes. |
| Cockpit and module | `CultureTag` | Filter and kit grouping. Never restricts fitting. |
| Module | `KitId` (optional) | Parts that form a named kit. |
| `Core.FeatureFlags` | `VehicleClass_<id>` | Publish a class without a place update. |

The frame standard itself lives in the repository as one JSON file per class, next to the validator. It is an authoring contract, not runtime data.

## 8. Economy and persistence impact

- **Saved data: additive only.** A saved vehicle already stores `CategoryId`, `CockpitInstanceId` and `InstalledModules[slotId] = instanceId`. New classes add new `CategoryId` values and template IDs. Five new slot IDs (`FrontBody`, `RearBody`, `Hood`, `Roof`, `Accessory`) add new keys in `InstalledModules`. No key is renamed and `SchemaVersion` stays at 1 unless the implementation audit finds a consumer that enumerates slots from a fixed list.
- **Performance model: unchanged in shape.** Engines, stabilisers and boost stay the stat carriers, as today. Body slots carry small or no stats.
- **Stable IDs.** `CategoryId` values are lower-case and permanent. The existing mismatch (folder `PIERCER`, id `bruiser`) is preserved.
- **Compatibility rule.** A module fits a cockpit when `CategoryId` matches and the cockpit has that `SlotId`. This must be enforced on the server at equip time for every class.
- **Economy.** Cockpits and modules are bought with Cash through `MoneyService.Debit`, as now. A class in the blockout has 5 or 6 cockpits and 48 to 72 modules, so the Cash sink grows a lot. Job and race pay should be reviewed with ECON-01 before more than two classes ship.
- **Catalogue.** `VehicleCatalogData` and `VehiclePreviews` are regenerated together after content changes. New public attributes must be added to the catalogue's public whitelist.

## 9. More ideas that fit

1. **Named kits.** When every fitted part shares a `KitId` the car earns a kit name on its card. Cosmetic only.
2. **Culture filters and a "surprise me" button** that fits a random valid build for the preview.
3. **Class sound.** Each class gets its own audio profile through the existing `StandardAudioProfileId`.
4. **Engine choice you can hear and see.** The engine and boost options differ strongly in shape (one big turbine, twins, a cluster of four, a slot burner). Give each family its own thrust VFX shape and sound layer through the existing VFX sockets.
5. **Signature expression per class.** Rodder lifts its nose on a boosted launch; Cruiser hops and tilts; Rider leans; Dart flares its airbrakes. Visual only, shipped later.
6. **Class events.** Restrict some races and duels to one class (a drag strip for Rodder and Muscle, a touge run for Street, a circuit for Apex and Exotic).
7. **Job tie-ins.** Hauler cabs and vans get a small bonus on taxi and parcel jobs.
8. **More classes later.** Rally and off-road, kei and micro cars, classic saloons, vans as their own class, a winged Interceptor.

## 10. Out of scope

- Any implementation: no new scripts, remotes, catalogue changes or saved-data changes.
- Final meshes, textures, thumbnails and audio.
- Performance numbers and prices for the new classes.
- New driving mechanics (lean, wheelie, hop, airbrake turning).
- Changes to Piercer content.
- Livery and decal systems.

## 11. Contract (docs/15 headings)

```text
System/change: Vehicle frame classes: twelve new modular vehicle categories built to a published frame standard, five new slot IDs (FrontBody, RearBody, Hood, Roof, Accessory), signature kits, class rail in the dealership.
Delivery lane and reason: High-Risk. Touches inventory, economy, saved vehicles and a cross-system catalogue contract, and becomes a dependency for future content. The class rail UI alone would be Standard.
Goal: Players choose a class, buy a cockpit with its signature kit, and fit any part of that class with a guaranteed clean result.
Current confirmed baseline: One category (PIERCER, CategoryId bruiser), six cockpits, eight fixed slots, all mounts at root origin, per-cockpit default engine, stabiliser and boost modules. Verified in Space Racers Backup v2, Edit, 2026-10-01.

Required changes:
- Content: one category folder per class with COCKPITS, MODULES and UPGRADES subfolders in the existing shape; slot folders carry DisplayName, Order, CosmeticOnly, IconId; cockpits carry SignatureKitId and the existing Default...ModuleId attributes.
- Remove fixed-category assumptions: the "bruiser"/"bruiser_01" defaults in GarageServer, GarageProfile, OwnedGarageDisplay, VehiclePerformanceResolver and GarageUI; the eight-slot fallback in GarageServer; the Engine1/Engine2 special cases in GarageUI; the hard-coded slot artwork in GarageWorkspaceUI.
- Catalogue: add the new public attributes to the whitelist; regenerate VehicleCatalogData and VehiclePreviews together.
- UI: class rail and culture filter in the dealership browser; data-driven slot rail in customisation.
- Per-class runtime parameters: collision hull, hover dust and thrust VFX sockets, seat position, preview and chase camera distance, spawn and grid spacing.
Must preserve: saved IDs and schema; the eight existing slot IDs and their performance meaning (engines, stabilisers and boost carry the stats); Piercer content and behaviour; MoneyService.Debit as the only spend path; Core.Net for remotes; LandscapeSensor; ClientBase and DriveSessionClient ownership.
Explicit exclusions: new driving mechanics, liveries, monetisation, Piercer rework.

Canonical owners:
- State: GarageServer (ownership, equip), GarageProfile and GarageProfileProjection (saved vehicles), VehicleCatalog (definitions).
- Geometry/visibility: GarageUI with GarageBrowserUI and GarageWorkspaceUI through Shared.LayoutGarageShell.
- Preview/runtime attachment: the existing preview lifecycle and the existing module attachment owner. No second attacher.
- Persistence/authoritative mutation: PlayerProfileSchema and the garage server commands. Cash through MoneyService.Debit only.

Inputs, outputs and dependencies: authoring folders in ServerStorage.Assets.Vehicles; generated VehicleCatalogData and VehiclePreviews; frame standard JSON per class in the repository; Core.FeatureFlags per class.
Entry, transitions, exit and cleanup: unchanged dealership and three-workshop flow; class rail and intro panel are browser states; previews stay transient.
Client/server authority and remote validation: server validates CategoryId match and slot existence on every equip and purchase; client never decides compatibility.
Stable IDs, saved schema/API version and migration impact: additive CategoryId, CockpitId, ModuleId and SlotId values; no renames; SchemaVersion 1 expected to hold, to be confirmed by audit.
Expected scale and bounded performance budget: per class 5 to 6 cockpits and 48 to 72 modules; catalogue grows from 122 records to roughly 900 with all classes; preview geometry stays generated and replicated on demand; each vehicle keeps a simple collision hull.
Mobile, touch, controller and accessibility coverage: section 5 table; 44 to 48 px targets; reflow, not shrink; controller focus order for the class rail must be defined.
Streaming/open-world behaviour: unchanged; vehicles are spawned by the server from templates.
Failure, cancellation, retry and observability: unknown CategoryId or SlotId in a save is kept and ignored, never deleted; a hidden class leaves owned vehicles usable; log one warning per unknown id.

Shared components/contracts to reuse: section 6.
Implementation/installer and rollback approach: one canonical installer per class for content; one for the fixed-assumption removal (ship first, with Piercer as the only class, and prove no behaviour change); FeatureFlag per class for rollback.

Verification matrix:
- Static/install: frame standard validator passes for every cockpit and module mesh bound (envelopes, contact, distinctness); catalogue projection check passes.
- Runtime transitions and cleanup: buy, equip, swap and paint in each class on desktop; preview cleanup on exit.
- Multi-client/security: cross-class equip rejected by the server; second client sees the right modules.
- Save/rejoin/migration: vehicle with new slots survives rejoin; old saves load unchanged; published-place persistence test (DATA-01/02) before release.
- Device/performance/streaming: landscape phone, tablet and controller pass on the class rail; memory check on preview loading with the larger catalogue.

Readiness scorecard exceptions or deferred risks: section 12.
Done when: a second class is live behind its flag, every part of it fits every cockpit of it with the validator green, and a Piercer-only player sees no change.
```

## 12. Risks

- **Art volume.** A full class is 5 or 6 cockpits and 48 to 72 modules. Twelve classes is about 770 meshes. Ship one pilot class with 3 cockpits and their 3 kits first (about 30 meshes).
- **Shared chassis limits how different cockpits can be.** Every cockpit in a class carries the same pads and floor. Cockpits differ in roofline and glass, not in footprint. This is the price of guaranteed fit.
- **Likeness.** Oscar has accepted real-car likeness. The concept images carry no logos, badges or text. Final models and names should still avoid trademarks, which matter for Roblox moderation.
- **Collision and width.** The live root part is 7.5 x 1.2 x 10.5 studs. A bike and a pod racer need different hulls. Rift and Tether are wide; Cruiser builds reach 37 studs long.
- **Rider pose.** An astride rider needs a new seat pose and animation, and a decision on passengers.
- **Fixed assumptions.** The code has several `bruiser` defaults and an eight-slot fallback. Removing them is the real engineering risk and should ship alone, before any new content.
- **Camera.** Preview and chase cameras assume one vehicle size.
- **Paint channels cannot do patterns or chrome.** Stripes, checker bands and bright trim need shaped Secondary-channel parts, a fixed Trim material, or a later livery layer.

## 13. What the exploration taught us

- **Envelopes stop clipping but not floating.** Round 1 passed with a plate hanging in the air. Round 2 adds the contact rule and fixed pads, checked for every possible pair.
- **Hover hardware must not read as wheels.** Round 1 used rings and discs. Round 2 uses jets: a nozzle or pod is longer than it is wide, and arches are blanked or hold a lift jet. The validator flags disc-shaped parts. The image reviewer still had to regenerate 19 of 96 concept images, because image models add wheels by default.
- **The cockpit owns all glass and the roofline.** A roof chop or canopy cannot be a swappable part; it is a cockpit.
- **Each surface has one owner.** Arches, noses, fins and pods each belong to exactly one slot.
- **Fundamentals need room.** When engines were given a sliver of space, every option looked the same. Each class now reserves an envelope large enough for one big turbine, a twin pair, a cluster of four and a flat slot burner.
- **Distinctness has a ceiling set by the standard.** The pads and seams shared by every nose or tail are a large part of its outline. Measured on the whole part, front and rear body options scored as low as 0.05 while looking clearly different. The score now removes the shared area first.
- **Size needs a world check.** Lanes, race gates, garage bays, the dealership stage, the chase camera and the minimap icon all assume a Piercer.
- **Seats differ by class.** Rider, Apex, Dart and Tether are single-seaters; saloons, wagons and crew cabs suit four seats.
- **Expression moments are visual only.** Nose lift, hop, lean and airbrake flare must be a pose owned by the existing vehicle visual layer.
- **Real cultures deserve respect.** Lowrider and kaido racer scenes are living communities.

Per-class lessons are in each frame sheet.

## 14. Evidence from this exploration

- **3D blockouts** in Space Racers Backup v2 under `Workspace.VehicleCategoryBlockouts` (around X 6200 to 8100, Y 2600, clear of the world). One block per class in a 4 by 3 grid, with the existing Piercer beside it for scale. Each block is the **interchange matrix**: one row per cockpit, one column per signature kit, so every cockpit is shown wearing every kit. Each block also has the frame standard (coloured slot envelopes), an exploded build in slot colours and the mixed builds. Anchored primitives only, no scripts. Every part carries `SlotId` and `PaintChannel` attributes and each vehicle is grouped by slot in the Explorer.
- **The Studio copy matches the specs.** Oscar rebuilt it on 2026-10-02 with [install_showroom.lua](../../scripts/vehicle_blockouts/install_showroom.lua) from the Command Bar, so it holds the fixes from all three review rounds. The Studio Assistant's sandbox can no longer fetch local files, so a rebuild needs the local server and the Command Bar; the steps are at the top of that file.
- **Exotic concept art, batch 1.** Model-sheet style art for the Wedge and Hyper cockpits, their twenty modules and eight assembled combinations, generated from Studio blockout screenshots so the camera and layout are fixed. Pack and artist notes: [exotic-art/README.md](vehicle-categories/exotic-art/README.md); method: [exotic-art/BRIEF.md](vehicle-categories/exotic-art/BRIEF.md); review page: https://claude.ai/artifact/CsNZDawrTKZm6gRfjAEuFe. The photo booth is `Workspace.VehicleCategoryBlockouts._ConceptBooth_EXOTIC` in the backup place.
- **What the blockouts prove.** Across the twelve classes: 70 cockpits, 70 signature kits and 700 modules, giving 410 cockpit-and-kit combinations, all passing the validator with zero errors and zero warnings. Engines, stabilisers and boost are present on every one. This is agent-verified geometry in primitive shapes. It is not a judgement of how final meshes will look, and nothing was driven.
- **Per-module swap test.** Whole-kit swaps are the easy case. Each class also has two mix sheets: twelve builds where every slot holds a random option (seeded, so repeatable), drawn from front and rear, with the module list in `mix.txt`. This is the test of "any module beside any other".
- **Three review rounds.**
  1. A critic that had not built the class looked at every cockpit in every kit. First builds scored about 3 out of 5, with 46 high and 66 medium defects across the twelve classes: jet drums that still read as wheels, engines hidden from the chase view, hard width steps on some swaps, look-alike options. A fixer per class worked through them.
  2. A second, fresh reviewer per class judged the fixed builds on the mix sheets and the matrix. It found 10 high and 50 medium defects, mostly single modules that looked wrong beside another kit's parts. A fixer closed them and a separate read-only verifier checked the result: no high defects remained in any class, and five medium ones remained in four classes (Rift, Muscle, GT, Cruiser).
  3. A third fix closed those five. The Cruiser fix changed its frame standard so each Rear Half owns its own rear quarters. GT now keeps the heaviest possible mix at 217 parts.
- **Final verifier scores** (1 to 5, after round 2; Rift, Muscle, GT and Cruiser were fixed again afterwards and not re-scored): swap fit 4.0 to 5.0, swap looks 4.0 in every class, fundamentals 4.0 to 5.0, no wheels 4.5 to 5.0, distinctness 3.5 to 4.0, recognisability 4.0 to 5.0. The integrator also looked through a mix sheet for every class after the last fix: every mix reads as one vehicle, with both engines, stabilisers and boost visible as jets and nothing wheel-like. What each fixer left open is listed under open risks in each frame sheet.
- **Offline previews**: run `py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json`. It writes the matrix, one larger sheet per cockpit (front and rear), the two mix sheets, the engine, stabiliser and boost options sheet, an exploded view and four views per build to `scripts/vehicle_blockouts/previews/<id>/` (not committed).
- **Concept images**: 96 images, eight per class, in each class sheet (full size under `output/vehicle-categories-2026-10-01/`, with every prompt saved; round 1 images are kept under `v1/`). Each set was checked by an independent reviewer for wheels, missing jets and text. They are generated mood pieces, not model sheets.
- **Gallery page**: all twelve classes on one page, published privately to Oscar at https://claude.ai/artifact/A3g7KKNRH27f4RQrEcr1yR. Rebuild locally with `py -3 scripts/vehicle_blockouts/make_gallery.py`.
- **Tools**: `scripts/vehicle_blockouts/` holds the spec format, a generator per class (`gen/`), the validator, previewer, showroom exporter, Studio builder and image helper. The shared brief is [CONTRACT.md](../../scripts/vehicle_blockouts/CONTRACT.md). Round 1 specs are in git history (commit 7701b16).

## 15. Open design questions

1. **Which classes first?** My recommendation is Muscle as the pilot (realistic, strongest blockout and art, and the simplest layout), then Exotic, Street and Rider.
2. **Are the fundamentals in the right places?** Section 3 lists where each class puts its engines, stabilisers and boost. They can move per class.
3. **Do Rider and Tether belong in the first wave?** Both need new technical work: a rider pose, and a very wide, long hull.
