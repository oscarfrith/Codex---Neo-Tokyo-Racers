# Vehicle frame classes: more categories for modular construction

**Status: Design - not approved.** Written 2026-10-01 from the repository, the live vehicle assets in Space Racers Backup v2 (place 133417340424236, Edit, read-only inspection) and Oscar's reference images. No game code, saved data or live vehicle assets were changed. Blockout models were added to a new Workspace folder in the backup place only.

## 1. Player goal

Pick the kind of machine you love (a split-body muscle car, a drift tuner, a hot rod, a bike, a track car, a truck, a pure sci-fi racer), then build it your way from parts that always fit. Every part in a class fits every cockpit in that class, and the result always looks like one vehicle.

## 2. What exists today

Verified in Studio on 2026-10-01:

- One category: folder `PIERCER`, `CategoryId = bruiser`, six cockpits (`bruiser_01` to `bruiser_06`). A cockpit is about 8 W x 6 H x 17 L studs. A full Piercer with its kit is 20.5 W x 7.6 H x 29.2 L.
- Eight slots on every cockpit: `Engine1`, `Engine2`, `Stabilisers`, `Boost`, `FrontBumper`, `RearBumper`, `RearSpoiler`, `SidePods`.
- Every slot mount sits at the cockpit root origin. Modules are authored in cockpit-root space. A module fits every cockpit in the category only because the cockpits share the same body-kit geometry.
- Paint channels (Primary, Secondary, Detail, Glass, Neon, plus Underglow and thrust colour) recolour cockpit and modules together.
- The functional slots have three tunes per cockpit (Standard, Lightweight, Power) that share one mesh. Visual choice is narrow: most slots have one or two distinct meshes.
- Category already shows in the UI: the dealership browser has an "ALL" button plus one per catalogue category, and the free-roam car menu has a category filter.

So the engine for categories exists. What is missing is a rule for building a category so parts are guaranteed to interchange, and the categories themselves.

## 3. The proposal in one page

**A category becomes a frame class.** A frame class is a layout (where the cabin, the propulsion and the bodywork sit) plus a published **frame standard** that every cockpit and module in the class is built to. Culture and style are tags inside a class, never a fitting restriction.

Three levels:

| Level | What it is | Example |
|---|---|---|
| Frame class (`CategoryId`) | A layout and its frame standard. Parts interchange only inside a class. | Rift |
| Cockpit | The cabin or core. Belongs to one class. Carries a culture tag. | Brawler (70s fastback) |
| Module | One part for one slot of one class. Carries a culture tag. | Twin Longhorn front half |

### The frame standard (why parts always fit)

1. **Cockpit envelope.** A box every cockpit in the class stays inside.
2. **Slot envelopes.** One box per slot that every module for that slot stays inside. Envelopes never overlap each other or the cockpit envelope. Any cockpit with any set of modules therefore cannot clip. No pair needs to be tested by hand.
3. **Seams.** Each slot names the face where it meets its parent. Every cockpit reaches every cockpit seam; every module reaches its own seam and the seams of slots that hang off it. No holes and no floating parts.
4. **Shadow gap and linkage.** Parts do not share surfaces. A 0.2 to 0.8 stud gap bridged by dark linkage is the house look, taken from the split-body references. The gap hides any mismatch between, say, a muscle nose and a wedge cabin.
5. **Datums.** Each class fixes a beltline, a sill height and the hover plane so body lines and stripes run straight across the gaps.
6. **Paint unifies.** Every part declares a paint channel, so a mixed-culture build still reads as one car.
7. **Hardpoint pads.** Envelopes stop clipping but do not stop floating. Every blockout found the same thing: the first clean pass still had a plate hanging in the air. Each parent therefore carries fixed, flat pads at set positions (a hood pad, a spoiler pad, bumper hardpoints, a hitch bar, a nose collar), and modules land on pads, never on a particular body shape. In practice **every cockpit in a class ships the same chassis** (frame rails, pads, rest points) under a different cabin. Character goes in the glass, nose and tail faces.

This matches how the live system already works (all mounts at the root origin). It needs no new attachment code. The standard is a build rule plus a validator, not a runtime system.

### Slots: keep the eight, relabel them, add three cosmetic ones

Every class keeps the eight canonical slot IDs. The performance resolver, upgrade paths and save data depend on them. Each class gives them its own player-facing labels and its own physical meaning. "Front half, back half, middle section, then bumpers and spoilers" from the brief maps exactly onto `Engine1`, `Engine2`, `SidePods`, then the existing bumper and spoiler slots.

Up to three extra cosmetic slots per class come from a fixed list: `Hood`, `Roof`, `Accessory`. They carry little or no performance.

| Slot ID | Piercer (today) | Rift | Street | Rodder | Rider |
|---|---|---|---|---|---|
| Engine1 | Front Engine | Front Half | Front Clip | Engine Block | Front End |
| Engine2 | Rear Engine | Rear Half | Rear Clip | Rear Drums | Rear End |
| Stabilisers | Stabilisers | Hover Fins | Hover Rotors | Front Axle | Winglets |
| Boost | Boost | Afterburner | Exhaust | Headers | Exhaust |
| FrontBumper | Front Bumper | Front Bumper | Front Lip | Grille Guard | Fairing |
| RearBumper | Rear Bumper | Rear Bumper | Diffuser | Launch Gear | Tail Kit |
| RearSpoiler | Rear Spoiler | Spoiler | Wing | Rear Rig | Seat Unit |
| SidePods | Side Pods | Mid Section | Side Kit | Fenders and Rails | Body Panels |
| Hood (new) | none | Hood | Hood | Hood | Tank |
| Roof (new) | none | Roof | Roof | Roof | Screen |
| Accessory (new) | none | none | Extras | none | Bars |

| Slot ID | Apex | Cruiser | Hauler | Dart | Tether |
|---|---|---|---|---|---|
| Engine1 | Front Pods | Front Clip | Front Clip | Prow | Tow Engines |
| Engine2 | Power Unit | Rear Deck | Bed | Drive | Pod Thruster |
| Stabilisers | Floor | Hover Rotors | Hover Pods | Airbrakes | Engine Vanes |
| Boost | Exhaust | Pipes | Stacks | Afterburner | Afterburners |
| FrontBumper | Nose and Wing | Front Chrome | Front Bar | Nose Tip | Intake Cowls |
| RearBumper | Diffuser | Rear Chrome | Rear Bar | Tail Cone | Pod Tail |
| RearSpoiler | Rear Wing | Deck Trim | Bed Rig | Tail Fins | Pod Fins |
| SidePods | Sidepods | Flanks | Side Gear | Wings | Binder and Cables |
| Hood (new) | Airbox | Hood | Hood | Spine | Engine Shrouds |
| Roof (new) | Halo or Canopy | Roof | Roof Rig | Canopy | Windshield |
| Accessory (new) | none | Extras | Extras | none | none |

## 4. The frame classes

Working names. Nine new classes plus the existing Piercer. Each links to its class sheet (pitch, cockpits, modules, handling intent, concept images) and its frame sheet (envelope numbers and authoring rules from the 3D blockout).

| Class (`CategoryId`) | Fantasy | Car and bike culture it taps | Layout in one line | Sheets |
|---|---|---|---|---|
| Piercer (`bruiser`) | Compact pod-kit racer | The game's own look | Cockpit with engine pods front and rear | existing |
| **Rift** (`rift`) | Classic coupé sliced into floating sections | Muscle, pony, pro street, Euro GT, wedge exotics | Cabin, twin forward nacelles, rear-quarter pods | [class](vehicle-categories/rift.md), [frame](vehicle-categories/rift-frame.md) |
| **Street** (`street`) | Tuner with clip-on aero | Drift, time attack, underground, touge, rally | One compact body, hover rotors in the arches | [class](vehicle-categories/street.md), [frame](vehicle-categories/street-frame.md) |
| **Rodder** (`rodder`) | Hot rod and drag rail | Highboy, rat rod, T-bucket, gasser, slingshot, salt flat | Narrow cab, exposed engine on rails, fat rear drums | [class](vehicle-categories/rodder.md), [frame](vehicle-categories/rodder-frame.md) |
| **Rider** (`rider`) | Hoverbike | Supersport, café racer, chopper, motocross, streetfighter | Spine and rider, hover ring front and rear | [class](vehicle-categories/rider.md), [frame](vehicle-categories/rider-frame.md) |
| **Apex** (`apex`) | Circuit racer | Formula, vintage grand prix, endurance prototype, sprint car | Central tub, four outboard pods, wings | [class](vehicle-categories/apex.md), [frame](vehicle-categories/apex-frame.md) |
| **Cruiser** (`cruiser`) | Long, low land yacht | Lowrider, lead sled, fin era, VIP, kaido racer | Long cabin, long clips, rotors under skirts | [class](vehicle-categories/cruiser.md), [frame](vehicle-categories/cruiser-frame.md) |
| **Hauler** (`hauler`) | Truck and van | Prerunner, lifted, minitruck, show truck, courier, taxi | Tall cab, cargo bed, big corner pods | [class](vehicle-categories/hauler.md), [frame](vehicle-categories/hauler-frame.md) |
| **Dart** (`dart`) | Anti-grav racing dart | Sci-fi works teams and privateers | Slender fuselage, forward prongs, airbrakes | [class](vehicle-categories/dart.md), [frame](vehicle-categories/dart-frame.md) |
| **Tether** (`tether`) | Pod racer | Scrapyard engineering, desert racing | Small pod towed by two huge engines | [class](vehicle-categories/tether.md), [frame](vehicle-categories/tether-frame.md) |

Why these splits and not others:

- **A class boundary is a layout boundary, not a style boundary.** Hot rods and drag rails share one class because both are "narrow cab, exposed engine, big rear, small front". Drift, time attack and rally share one class because they are the same body with different clip-on parts. This keeps part pools large, which is what makes customisation deep.
- **Drag racing lives in two places on purpose.** Slingshot rails are Rodder cockpits. Pro-street muscle (blower through the bonnet, wheelie bars, parachute) is a Rift culture kit.
- **Street and Cruiser are separate** because the cabin length differs so much that a shared rear seam would force ugly compromises. They share the hover-rotor idea (see section 9).
- **Each class drives differently** inside the same performance budget, so owning several is worth it. Intent only, tuned later through the existing calibration tools:

| Class | Strong | Weak |
|---|---|---|
| Rift | Top speed, boost, long drifts | Weight, tight turns |
| Street | Drift control, steering, agility | Top speed, contact |
| Rodder | Acceleration, boost force | Sideways grip, braking |
| Rider | Steering, squeezing through gaps, acceleration | Contact, stability |
| Apex | Grip, braking, downforce | Drift, contact |
| Cruiser | Stability, straight-line speed | Steering, acceleration |
| Hauler | Contact, stability, boost torque | Steering, top speed |
| Dart | Top speed, airbrake turns | Low-speed handling |
| Tether | Extreme speed and boost | Width, stability, tight streets |

## 5. Player flow

Entry, states and exit stay as they are today. Only the content of each screen grows.

1. **Dealership (buy a cockpit).** Entry: E or tap at the dealership prompt. The browser's left list already shows "ALL" plus one button per category. With ten classes that list becomes a **class rail**: one `ModuleCategoryCard`-style tile per class with a silhouette icon and name, vertical on PC, horizontal on landscape phones. Choosing a class filters the `VehicleCard` grid. A culture filter and the existing sort control sit side by side with identical size, as the free-roam design system requires. Exit: Buy, Buy Another or Back.
2. **Class intro (first visit to a class only).** One dismissible panel: the class silhouette, three lines on how it drives, and the slot map (which part is where). No new screen owner; it is a state of the browser.
3. **Customisation (three workshops, unchanged).** Add Modules, Upgrade Modules, Paint Shop. The slot rail is built from the cockpit's own `ModuleSlots` folders in `Order`, using each slot's `DisplayName`. It no longer assumes eight fixed slots. Listing cards gain a small culture tag and a "kit" marker when the part belongs to a named kit. Owned and Buy lists and the Buy, Equip and Customise actions are unchanged.
4. **Free roam car menu.** The category filter already exists. It lists every owned class.
5. **Exit and cleanup.** Unchanged: previews are transient and owned by the existing preview lifecycle.

States that need care: a player who owns no cockpit in a class sees that class's tile with a lock-free "from $X" price, not an empty grid; a class with no published content is hidden by the catalogue, not by the UI.

### Inputs

| Action | PC | Touch (LandscapeSensor) | Controller |
|---|---|---|---|
| Move along class rail | Mouse, W/S or arrows | Tap; swipe to scroll | D-pad or left stick up/down |
| Move between rail and grid | Mouse, A/D or arrows | Tap | D-pad or left stick left/right |
| Select | Click, Enter | Tap (target 44 to 48 px) | A |
| Back or close | Escape | Back button | B |
| Culture filter, sort | Click | Tap | X opens, D-pad chooses, A confirms |
| Orbit preview | Drag | One-finger drag in the preview area | Right stick |

One responsive composition through `Shared.LayoutGarageShell`. No portrait layout. No nested vertical scrolling: the rail scrolls on its own axis and the card grid on the other.

## 6. Reused components and tokens

No new visual language is needed.

- `GarageComponents.VehicleCard` for every cockpit card (shared vehicle card system). No second card renderer.
- `GarageComponents.ModuleCategoryCard`, `ModuleCard`, `ModuleListingCard`, `Popup`, `ActionButton`, `AnchoredDropdown`, `ConfirmationModal`, `UpdateHorizontalCardCanvas`.
- `Shared.LayoutGarageShell` for layout; `RacingUIComponents` (`Button`, `Panel`, `Label`, `Colour`, `Stroke`) and `ResponsiveUIFoundation` (`Corner`, `StrokeWidth`, `ApplyBevel`, `Confirmation`, money formatters) for primitives.
- `Config.UI.Theme` tokens. Colour meaning is unchanged: pink for structure, cyan for selection, blue for purchase, red for destructive. Tier colours never mark selection.
- Per-slot preview camera angles from `Config.UI.GarageReplacement` attributes. No page-specific camera writer.

Exceptions to record if approved: (a) class silhouette icons are new art; (b) the slot rail's hard-coded `artworkDefinitions` in `GarageWorkspaceUI` becomes data read from the slot folders; (c) the culture tag is a new small label on `ModuleListingCard`, built from existing `Label` and `Stroke` primitives.

## 7. New configuration

All on the authoring folders in `ServerStorage.Assets.Vehicles.Categories`, so tuning stays in attributes.

| Where | Attribute | Purpose |
|---|---|---|
| Category folder | `FrameStandardVersion` (number) | Bumps when envelopes change. |
| Category folder | `ClassIcon`, `ClassBlurb`, `ClassOrder` | Class rail tile and intro panel. |
| Category folder | `HandlingBias_<Stat>` (number, default 0) | Design-time bias read by the calibration tools, not at runtime. |
| Category folder | `PreviewCameraDistance`, `PreviewCameraHeight` | A bike and a pod racer need different framing. |
| Category folder | `CollisionProfile` (string) | Names the class's simple collision hull (see risks). |
| Slot folder (existing) | `DisplayName`, `Order` | Already present. Now the only source for the slot rail. |
| Slot folder | `CosmeticOnly` (bool) | True for `Hood`, `Roof`, `Accessory`. Excluded from performance. |
| Slot folder | `IconId` | Slot rail artwork. |
| Cockpit and module | `CultureTag` (string) | Filter and kit grouping. Never restricts fitting. |
| Module | `KitId` (string, optional) | Parts that form a named kit. |
| `Core.FeatureFlags` | `VehicleClass_<id>` | Publish a class without a place update. |

The frame standard itself (envelope boxes, seams, datums) lives in the repository as one JSON file per class, next to the validator. It is an authoring contract, not runtime data.

## 8. Economy and persistence impact

- **Saved data: additive only.** A saved vehicle already stores `CategoryId`, `CockpitInstanceId` and `InstalledModules[slotId] = instanceId`. Module instances store `TemplateId`. New classes add new `CategoryId` values and new template IDs. New slots add new keys in `InstalledModules`. No key is renamed and `SchemaVersion` stays at 1 unless the implementation audit finds a consumer that enumerates slots from a fixed list.
- **Stable IDs.** `CategoryId` values are lower-case and permanent (`rift`, `street`, and so on). The existing mismatch (folder `PIERCER`, id `bruiser`) is preserved. Module IDs follow the current pattern with the class id as prefix.
- **Compatibility rule.** A module fits a cockpit when `CategoryId` matches and the cockpit has that `SlotId`. This is the existing rule; it must be enforced on the server at equip time for every class.
- **Economy.** Cockpits and modules are bought with Cash through `MoneyService.Debit`, exactly as now. Six cockpits per class across tiers E to S reuses the current price ladder ($40k to $10M). Cosmetic-slot parts should be cheap and frequent purchases. A class adds roughly 40 purchasable parts, so the Cash sink grows a lot; job and race pay should be reviewed with ECON-01 before more than two classes ship.
- **Catalogue.** `VehicleCatalogData` and `VehiclePreviews` are regenerated together after content changes, as today. New public attributes (`CultureTag`, `KitId`, `CosmeticOnly`, class attributes) must be added to the catalogue's public whitelist.

## 9. More ideas that fit

Ranked by value for effort. None is needed for the first class.

1. **Named kits.** When every fitted part shares a `KitId` the car earns a kit name on its card ("Full Kit: Longhorn"). Cosmetic only. It rewards coherent builds without punishing mixed ones.
2. **Culture filters and a "surprise me" button.** Filter the shop by culture; one button fits a random valid build for the preview. Mixed builds are where the screenshots come from.
3. **Class sound.** Each class gets its own audio profile through the existing `StandardAudioProfileId`: a lumpy rumble for Rodder, a high scream for Apex, a whine for Dart. Sound sells culture as much as shape.
4. **Shared rotor pool.** Street and Cruiser both use round hover rotors as their "rims". A slot's `AllowedModuleFolder` could point at a shared pool so a rotor set bought once fits both classes. Wheels are the most traded part in real car culture.
5. **Signature expression per class.** Rodder lifts its nose on a boosted launch; Cruiser hops and tilts on a key; Rider wheelies and leans; Dart flares its airbrakes. Each is a visual on top of existing physics, shipped later, one per class.
6. **Class events.** Restrict some races and duels to one class (a drag strip for Rodder and Rift, a touge run for Street, a circuit for Apex). The race system already has categories.
7. **Job tie-ins.** Hauler cabs and vans get a small bonus on taxi and parcel jobs. It gives the class a reason to exist beyond looks.
8. **Chained mounts (later).** Let a bumper follow the length of the front half it is fitted to by reading a named attachment on the parent module. Version one keeps fixed envelopes because they need no code; chained mounts would allow long-nose and short-nose parts in the same slot.
9. **More classes later.** Interceptor (winged fighter), Trike and sidecar, Kart, Offshore (twin-hull powerboat). Each needs a distinct layout to earn a class.

## 10. Out of scope

- Any implementation: no new scripts, remotes, catalogue changes or saved-data changes.
- Final meshes, textures, thumbnails and audio.
- Performance numbers and prices for the new classes.
- New driving mechanics (lean, wheelie, hop, airbrake turning). They are listed as later ideas.
- Changes to Piercer content.
- Livery and decal systems.

## 11. Contract (docs/15 headings)

```text
System/change: Vehicle frame classes: nine new modular vehicle categories built to a published frame standard, three new cosmetic slot IDs, class rail in the dealership.
Delivery lane and reason: High-Risk. Touches inventory, economy, saved vehicles and a cross-system catalogue contract, and becomes a dependency for future content. The class rail UI alone would be Standard.
Goal: Players choose a class, buy a cockpit and fit any part of that class with a guaranteed clean result.
Current confirmed baseline: One category (PIERCER, CategoryId bruiser), six cockpits, eight fixed slots, all mounts at root origin. Verified in Space Racers Backup v2, Edit, 2026-10-01.

Required changes:
- Content: one category folder per class with COCKPITS, MODULES and UPGRADES subfolders in the existing shape; slot folders carry DisplayName, Order, CosmeticOnly, IconId.
- Remove fixed-category assumptions: the "bruiser"/"bruiser_01" defaults in GarageServer, GarageProfile, OwnedGarageDisplay, VehiclePerformanceResolver and GarageUI; the eight-slot fallback in GarageServer; the Engine1/Engine2 special cases in GarageUI; the hard-coded slot artwork in GarageWorkspaceUI.
- Catalogue: add the new public attributes to the whitelist; regenerate VehicleCatalogData and VehiclePreviews together.
- UI: class rail and culture filter in the dealership browser; data-driven slot rail in customisation.
- Per-class runtime parameters: collision hull, hover dust sockets, seat position, preview and chase camera distance, spawn and grid spacing.
Must preserve: saved IDs and schema; the eight canonical slot IDs and their performance meaning; Piercer content and behaviour; MoneyService.Debit as the only spend path; Core.Net for remotes; LandscapeSensor; ClientBase and DriveSessionClient ownership.
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
Expected scale and bounded performance budget: per class 6 cockpits and about 40 modules; catalogue grows from 122 records to roughly 500 with all classes; preview geometry stays generated and replicated on demand; each vehicle keeps a simple collision hull.
Mobile, touch, controller and accessibility coverage: section 5 table; 44 to 48 px targets; reflow, not shrink; controller focus order for the class rail must be defined (none is documented for the garage rail today).
Streaming/open-world behaviour: unchanged; vehicles are spawned by the server from templates.
Failure, cancellation, retry and observability: unknown CategoryId or SlotId in a save is kept and ignored, never deleted; a hidden class leaves owned vehicles usable; log one warning per unknown id.

Shared components/contracts to reuse: section 6.
Implementation/installer and rollback approach: one canonical installer per class for content; one for the fixed-assumption removal (ship first, with Piercer as the only class, and prove no behaviour change); FeatureFlag per class for rollback.

Verification matrix:
- Static/install: frame standard validator passes for every cockpit and module mesh bound; catalogue projection check passes.
- Runtime transitions and cleanup: buy, equip, swap and paint in each class on desktop; preview cleanup on exit.
- Multi-client/security: cross-class equip rejected by the server; second client sees the right modules.
- Save/rejoin/migration: vehicle with new slots survives rejoin; old saves load unchanged; published-place persistence test (DATA-01/02) before release.
- Device/performance/streaming: landscape phone, tablet and controller pass on the class rail; memory check on preview loading with 500 records.

Readiness scorecard exceptions or deferred risks: section 12.
Done when: a second class is live behind its flag, every part of it fits every cockpit of it with the validator green, and a Piercer-only player sees no change.
```

## 12. Risks

- **Art volume.** A full class is about 6 cockpits and 40 modules. Nine classes is over 400 meshes. Ship one pilot class with 3 cockpits and 2 parts per slot (about 25 meshes) first.
- **Likeness.** "Inspired by" must stay at the level of era and genre. No real names, badges or exact body copies. This matters for Roblox moderation and for licensing.
- **Collision and width.** The live root part is 7.5 x 1.2 x 10.5 studs. A bike and a pod racer need different hulls. Rift and Tether are wide; city streets and race gates must be checked against the widest class.
- **Rider pose.** An astride rider needs a new seat pose and animation, and a decision on passengers.
- **Fixed assumptions.** The code has several `bruiser` defaults and an eight-slot fallback. Removing them is the real engineering risk and should ship alone, before any new content.
- **Camera.** Preview and chase cameras assume one vehicle size.

## 13. What the exploration taught us

Nine concept sets and nine blockouts were made against the same brief. The same points came up in class after class. They should become rules in the frame standard before any real mesh is built.

- **Hover units must not read as wheels.** Upright glowing discs look like thin wheels at a distance (Rodder, Rider, Apex, Cruiser, Hauler all hit this). Rule: hover units lie flat or are thin, hubless rings clear of the floor, and they always glow.
- **The cockpit owns all glass and the roofline.** Where a roof module tried to change the roofline it fought the cockpit's identity (Cruiser's Chop and Bubble, Apex's Halo and Canopy, Rift's T-Top). Rule: the `Roof` slot is trim on top of the cockpit (scoop, rack, light bar, skin), unless every cockpit in the class shares one beltline cut.
- **Each surface has one owner.** The art kept drawing arches, centre noses, fins and rear pods on two different parts. The frame sheet for each class names the single owning slot.
- **One slot, one module.** Several images showed two parts from one slot at once (skirts with spears, side exit with stacks). The game allows one. Where both are wanted, the class needs the `Accessory` slot or a combined part.
- **Paint channels cannot do patterns or chrome.** Flames, checker bands, pinstripes and bright trim appear all over the concept art. Today's channels recolour whole parts. Options, cheapest first: shaped Secondary-channel parts on the beltline datum; a fixed Trim material for chrome; a livery layer later.
- **Size needs a world check.** Rift and Dart are about 34 studs long, Tether about 18 wide, Hauler 9 tall. Lanes, race gates, garage bays, the dealership stage, the chase camera and the minimap icon all assume a Piercer.
- **Seats differ by class.** Passengers and taxi jobs assume a cabin. Rider, Apex, Dart and Tether are single-seaters; saloons, wagons and crew cabs suit four seats.
- **Expression moments are visual only.** Nose lift, hop and tilt, lean, wheelie and airbrake flare must be a pose on the model, owned by the existing vehicle visual layer, never a second physics owner.
- **Real cultures deserve respect.** Lowrider and kaido racer scenes are living communities. Names and details should be affectionate, not caricature.
- **A name clash to fix.** Street and Cruiser both list a "Longroof" wagon. One should be renamed before IDs are fixed.

What each blockout added (details in the frame sheets):

| Class | Lesson for interchange |
|---|---|
| Rift | Each parent needs named flat pads at fixed datums: hood, spoiler, boost, roof, bumper and side hardpoints. |
| Street | Mating faces are flat datums, not shapes. The cabin owns everything above the beltline. Clips own the arches and must all carry the same arch lip, or overfenders float. A roof spoiler cannot interchange because roof ends differ; it is a cockpit feature. |
| Rodder | Every cab ships the same chassis and rest points (rail stubs, drum spindle, firewall face, two roof rests). Every engine ships the same end plates, port rail and induction pad. |
| Rider | Everything the rider touches is a class datum: one hand position, one seat-tail height, cockpit-owned pegs. Bars cannot move the hands. |
| Apex | The Roof slot is a shell round a reserved driver head box, so a bubble canopy fits inside a sprint cage. |
| Cruiser | Bodies share flat sides and tops within half a stud of the seams. A roof chop cannot be a module; it is a cockpit. |
| Hauler | Every cab carries the same ladder frame with fixed axle beams. The Bed Rig is a portal outside and over the bed, so a rack can sit over a box van. |
| Dart | Prongs, drives and fins come in ones, twos and threes, so the seam is a single fixed centreline collar every module carries. |
| Tether | Every pod has the same hitch bar; every engine the same rails and end flanges. Cables only ever span hitch bar to inner rail. |

Limits of the blockout validator, to fix before it gates real meshes: it tests vertices only (a rotated part can cut the inside corner of an L-shaped envelope); a seam counts as reached when any one box of a union is reached; it does not know about pads. The agents covered these by eye and with their own checks.

## 14. Evidence from this exploration

- **3D blockouts** in Space Racers Backup v2 under `Workspace.VehicleCategoryBlockouts` (around X 6200, Y 2600, well clear of the world): one row per class. Each row shows the frame standard (coloured slot envelopes), an exploded build in slot colours, then eight assembled builds: one kit on three cockpits, one cockpit with three kits, and two mixed builds. A row of the existing Piercer is included for scale. About 12,000 anchored primitive parts, no scripts. Every part carries `SlotId` and `PaintChannel` attributes, and each build is grouped by slot in the Explorer.
- **What the blockouts prove.** Across the nine classes: 41 cockpits, 308 modules and 72 demo builds, all built from shared part lists, all passing the validator with zero errors. Inside a class, any cockpit takes any part without clipping. Street alone has about two million possible full builds from 4 cockpits and 37 parts. The Studio build was checked against the offline previews numerically (per-slot bounds match) and by screen capture. This is agent-verified geometry in primitive shapes; it is not a judgement of how final meshes will look, and nothing was driven.
- **Offline previews** of the same blockouts: run `py -3 scripts/vehicle_blockouts/preview.py scripts/vehicle_blockouts/specs/<id>.json` (written to `scripts/vehicle_blockouts/previews/<id>/`, not committed).
- **Concept images**: 72 images, eight per class, in each class sheet (full size under `output/vehicle-categories-2026-10-01/`, with every prompt saved). They are generated mood pieces for layout and culture, not model sheets.
- **Gallery page**: all nine classes with their images, slot tables and blockout captures on one page, published privately to Oscar at https://claude.ai/artifact/A3g7KKNRH27f4RQrEcr1yR. Rebuild locally with `py -3 scripts/vehicle_blockouts/make_gallery.py` (writes `output/vehicle-categories-2026-10-01/gallery/`).
- **Tools**: `scripts/vehicle_blockouts/` holds the spec format, validator, previewer, Studio builder and image helper. The shared brief is [CONTRACT.md](../../scripts/vehicle_blockouts/CONTRACT.md).

## 15. Open design questions

1. **Which classes first, and are the names right?** My recommendation is Rift (your reference look, and the pilot for the pipeline), then Street, Rodder and Rider, because together they cover muscle, drift, drag, hot rod and bike culture.
2. **How close to real cars?** I recommend era-and-genre originals with no badges, which is what the concept images show. Closer likeness raises moderation and licensing risk.
3. **Do Rider and Tether belong in the first wave?** Both need new technical work (rider pose, very wide and long hull, camera). They are the most distinctive classes but the most expensive to do well.
