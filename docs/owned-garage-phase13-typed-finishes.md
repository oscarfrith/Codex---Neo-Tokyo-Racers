# Owned Garage Phase 13 Typed Fixtures And Finishes

**Status:** V1.3 user-confirmed; V1.4 submission hardening generated and awaiting Studio verification  
**Installer:** `scripts/roblox_owned_garage_phase13_typed_finishes.lua`  
**Committed-state audit:** `scripts/roblox_owned_garage_phase13_committed_state_audit.lua`  
**Target revision:** `NTR_OWNED_GARAGE_PHASE13_V1_4_SUBMISSION_HARDENING`

## V1.4 Submission-Hardening Contract

V1.4 is a proportional Standard continuation with no persistence, economy, remote or UI change. ServerStorage remains the only production asset authority. Scratch/editing libraries are not read by runtime, installer or audit and are excluded from readiness. `OwnedGarageFinishRuntime` preserves each cloned structure/decoration part's authored `CastShadow`; it does not force shadows on. Invisible collision and dynamic light-source shadows remain off.

The config-owned district moves to `(7000,3200,0)`, four columns and `512 x 512` spacing. `OwnedGarageInteriorRuntime` and the V1.2 request-scoped streaming handshake remain unchanged and consume the new attributes automatically. No template, asset or marker moves inside its local coordinate system.

Done means the V1.4 installer and post-restart audit pass with only authoritative ServerStorage present; authored shadow-on/off choices survive runtime cloning; two simultaneous interiors do not visibly, audibly or interactively interfere; mobile performance remains acceptable; and foot entry, drive-in, foot exit and drive-out retain their confirmed bounded failure behaviour.

Run `scripts/roblox_owned_garage_phase13_typed_finishes.lua` once in Edit mode and require `PASS ... authority=ServerStorage shadowPolicy=Authored ... grid=4x512x512`. Fully restart Studio, run `scripts/roblox_owned_garage_phase13_committed_state_audit.lua`, require `COMMITTED STATE PASS`, then complete the Play matrix and full mirror refresh.

## V1.3 Historical Implementation Plan And Acceptance Contract

V1.3 is a High-Risk proportional continuation because it changes saved customisation shape and economy-backed equip behaviour. It keeps the existing ProfileService command boundary, one garage revision, ServerStorage asset authority, runtime preview owners, shared workspace, collision shell and transition handshake.

1. Preflight the exact V1.2 source markers, compile all eight owners, require both populated/enabled Platform Option 1 copies and resolve all seven named MaterialVariants. Make no source write if any prerequisite fails.
2. Add declarative `StarterItemId` fields for Street Workshop, Open Rack and Platform Option 1. Apply starter placements once through `StarterLoadoutVersion`; keep `Required` solely as the clear/remove rule.
3. Advance only the owned-garage schema. Existing tester garage state may reset; vehicle/cockpit/module ownership and cash remain untouched.
4. Treat cloned asset properties as default appearance. Empty `Colors`/`Materials` override tables apply nothing. Project effective authored values to the client for controls without persisting them automatically.
5. Retain structure overrides per StyleId. Purchase/equip loads that style's own overrides or none; changing one style cannot repaint another.
6. Register ten stable material IDs with labels Concrete, Metal, Wood, Paint and Tiles A-F. Validate MaterialVariants server-side, apply base Material plus MaterialVariant together, hide unavailable entries and never allow material on Neon.
7. Replace the extra material-channel page with the shared Primary/Secondary/Detail tab renderer directly above material cards. Preserve pending values across tabs and save all populated channels atomically.
8. Compile every projected source before assignment, assign only after the complete projection succeeds, audit markers/contracts, and restore all eight source snapshots plus config attributes on failure.

Done means the starter fixtures equip for free, authored appearance survives purchase/equip, previews cancel correctly, colour/material changes persist across rejoin and style switching, unavailable channels/materials never surface, and desktop/mobile plus all four entry/exit paths retain V1.2 behaviour.

## V1.3 Material Mapping

| Stable ID | Player label | Roblox material contract |
| --- | --- | --- |
| `CONCRETE` | Concrete | Asphalt + `Asphalt New` variant |
| `METAL` | Metal | Metal |
| `WOOD` | Wood | Wood + `Plywood` variant |
| `PAINT` | Paint | Plastic |
| `TILES_A` | Tiles A | CeramicTiles |
| `TILES_B` | Tiles B | `Tiles Rectangular Horizontal (Small)` |
| `TILES_C` | Tiles C | `Tiles Rectangular Small` |
| `TILES_D` | Tiles D | `Tiles Rectangular Vertical (Small)` |
| `TILES_E` | Tiles E | `Tiles Square Large` |
| `TILES_F` | Tiles F | `Tiles Square Small` |

Historical V1.3 recovery compared the authoritative platform with an editing copy. V1.4 supersedes that requirement: only the populated/available authoritative Platform Option 1 is production-relevant, and folder-derived metadata is audited there.

## V1.3 Historical Installer Safety And Verification

The installer uses guarded exact transforms because eight existing isolated owners must retain their unrelated behaviour. Every anchor must occur once. All eight projected sources compile before assignment; a failed assignment or contract audit restores every source and tracked metadata. Source markers are authoritative if Team Create commits source while dropping attributes: when all eight markers are present, rerunning the same installer assigns no Source and repairs revision plus platform finish attributes transactionally. It never moves, creates, deletes or re-pivots platform assets. A partial marker set fails closed for a fresh mirror inspection.

1. The historical V1.3 recovery required `COMMITTED SOURCE/PLATFORM ATTRIBUTE RECOVERY PASS platformParts=6+6`; the user confirmed that result. The canonical filename now contains V1.4 and must not be expected to print V1.3 output.
2. The historical V1.3 audit passed before V1.4 planning. Use the current V1.4 authoritative-only audit after the new install.
3. Enter on foot and confirm Street Workshop, Open Rack and Platform Option 1 are equipped without a cash charge. Confirm both display platforms appear and vehicle assignments remain independent.
4. Buy/equip one structure and one decoration. They must initially retain their authored Studio colours/materials. Back/Exit must cancel previews without changing them.
5. Verify Colour shows only populated folders. Verify Material opens directly to Primary/Secondary/Detail tabs above the ten material cards; Neon must never appear there and no `Original` label should exist.
6. Change different materials on two channels, SAVE, switch structure style away/back and confirm that style's finishes return. Rejoin and confirm persistence.
7. Repeat colour/material/Back/SAVE on desktop and a phone viewport. Exercise foot entry, drive-in, foot exit and drive-out to ensure the confirmed V1.2 streaming/collision behaviour remains unchanged.
8. Refresh the complete Studio mirror and inspect the new source/config markers before treating V1.3 as the baseline.

## V1.1/V1.2 Historical Acceptance Contract

Phase 13 replaces the generic three-anchor decoration authoring contract with five property-defined fixed zones: `WorkshopWall`, `StorageWall`, `HangoutBay`, `FeatureCorner` and `IdentityWall`. V1.1 adds the optional paired `DisplayPlatforms` zone. Each option uses the same `ColourSlots/Primary|Secondary|Detail|Neon`, `Fixed` and `Technical` hierarchy. The UI derives its available controls from populated, enabled assets instead of hard-coded per-item channel lists.

Structure options adopt the same folder contract while retaining the existing `StructureChannel` attribute as a compatibility fallback. Structure supports colour on Primary, Secondary, Detail and Neon, and material on Primary, Secondary and Detail only. Decorations support colour only. Fixed/Technical descendants are never recoloured or rematerialed.

The existing `OwnedGarageWorkspaceController`, shared H/S/B paint renderer, `OwnedGarageManagementRuntime`, ProfileService-owned command boundary and one garage revision remain the presentation, geometry, persistence and conflict owners. Phase 13 creates no new remote, ScreenGui, profile owner, economy owner or per-frame loop.

V1.2 closes the physical-arrival contract without changing saved state. `OwnedGarageManagementRuntime` remains transition authority, the existing loading runtime remains presentation authority and `OwnedGarageBrowserController` performs only bounded destination streaming/readiness. The existing `OwnedGarageEvent` carries a request-scoped token; it does not create another remote or permit the client to select a destination or authorize a gameplay mutation.

## Authority And Saved State

- `OwnedGarageFinishRuntime` resolves ServerStorage assets, inspects populated folders, validates submitted channels and applies finishes.
- The server projects available colour/material channels to the immutable management response; the client cannot declare support.
- Decoration placements become `{ItemId, Colors}` records scoped to a property zone. Required Workshop/Storage defaults are normalised automatically.
- Structure retains section-scoped `StyleId`, `Colors` and `Materials`, adding dormant Neon colour state.
- Save commands retain `RequestId` and `BaseRevision`. The mutation fingerprint serialises colour/material tables deterministically.
- Preview belongs only to the active interior session. Back, Exit, management close and transition use the existing cancellation path.
- The `DisplayPlatforms` saved record owns appearance only. Vehicle IDs, display assignments and display marker geometry remain under their existing owners.

## Authoring Paths

```text
ServerStorage.NeoTokyoRacers.OwnedGarage.DecorationAssets.<TemplateId>.<SlotId>.<AssetName>
ServerStorage.NeoTokyoRacers.OwnedGarage.StructureAssets.<TemplateId>.<SectionId>.<OptionXX>
ServerStorage.NeoTokyoRacers.OwnedGarage.DecorationAssets.StarterTwoBay.DisplayPlatforms.PlatformOption01|02|03
ReplicatedStorage.ZZZ.DecorationAssets.StarterTwoBay.DisplayPlatforms.PlatformOption01|02|03
ServerStorage.NeoTokyoRacers.OwnedGarage.Templates.StarterTwoBay.CollisionShell
ReplicatedStorage.ZZZ.Templates.StarterTwoBay.CollisionShell
```

Every final asset model contains:

```text
ColourSlots
  Primary
  Secondary
  Detail
  Neon
Fixed
Technical
```

An empty colour folder does not appear in the UI. A structure part may set `GarageMaterialLocked=true`; a light may opt into the Neon colour with `FollowNeonColor=true`. New authored parts should use the folder contract. Legacy `StructureChannel` attributes remain readable during the transition.

V1.1 applies explicit `TemplateId`, `AssetKind`, `AssetId`, `SlotId`/`SectionId`, `EditableTemplate`, `FinishContractVersion`, `GarageColourChannel` and protection attributes to both the authoritative ServerStorage library and the ZZZ editing copy. Fixed/Technical parts receive `GarageFinishProtected=true`; their colour-channel attributes are cleared. This changes metadata only—no existing instance, pivot or CFrame is moved or replaced.

Existing assets remain `GaragePlacementMode=SlotLocal` because their stored CFrames were authored relative to the existing slot markers. The three new paired-platform containers use `GaragePlacementMode=TemplateOrigin`, allowing one option Model to contain both platform designs at their final template-relative locations. They begin empty with `Available=false`; add geometry to the appropriate folders, set the Model to `Available=true`, then copy the completed editing Model into the matching ServerStorage path.

`CollisionShell` is permanent technical geometry, not a structure style. V1.2 derives its initial floor and boundary proxies from Option01's floor plus the existing authored `CanCollide` intent for wall sections. Every proxy is invisible, anchored, collidable, non-touchable, queryable and marked `GarageCollisionPart=true` / `GarageFinishProtected=true`. It carries no `StructureSection`, `SurfaceGroup`, colour or material channel, so structure/decorations cannot hide or edit it. Future template authoring should edit the ZZZ shell deliberately and copy the complete template to ServerStorage; never place collision inside a purchasable style option.

## Transition And Failure Contract

1. Server creates and validates the destination without moving or removing gameplay state.
2. Server issues a GUID token containing only the authoritative destination position and expected named marker.
3. Client requests streaming around that position and confirms that exact interior/exterior marker is locally present.
4. Server accepts only the outstanding token for that same player and applies an eight-second bounded timeout.
5. Only after readiness does the server teleport, despawn a driven car, clear a display assignment or spawn a drive-out vehicle.
6. Timeout/failure leaves the player, driven vehicle and saved display assignment at the origin and clears the pending request/session safely.

Diagnostics are `NTR_OwnedGarageStreamState`, `NTR_OwnedGarageLastStreamSeconds` and `NTR_OwnedGarageLastStreamError`. They are observational only and never authorize a transition.

## Performance And Lifecycle Budget

- Capabilities are scanned from immutable ServerStorage assets and cached by the server module.
- Active presentation contains at most one decoration model per supported zone and one structure model per section.
- Slider motion is local to the shared UI; a physical preview request is sent only when input commits, and persistence occurs only through SAVE.
- Visual runtime clones remain anchored, non-collidable, non-queryable and stripped of scripts, prompts and seats. Navigation collision belongs only to the template shell.
- Streaming performs no polling outside an active transition; readiness checks end at success or the bounded timeout.
- No RenderStepped polling or arbitrary world-CFrame persistence is introduced.

## V1.2 Historical Installer Safety

The earlier `15:04:04` mirror proved Team Create can commit Source while losing attributes/hierarchy from the same Command Bar transaction. V1.2 therefore remains one canonical installer but automatically uses two transactions. The first unchanged run projects and compiles all three sources before writing any of them, and rolls all three back on failure. After a full Studio restart, the same unchanged script sees the committed V1.2 markers and performs hierarchy/config/attribute work with `sourceWrites=0`.

The asset transaction never replaces, deletes, moves or re-pivots existing assets. It snapshots every pre-existing BasePart parent/CFrame, creates only the two owned collision shells when absent, retains the V1.1 platform containers and audits authoritative/editing parity. Existing player data, vehicle/cockpit/module state, cash and display assignments are preserved. The separate post-restart audit performs no writes and proves both transactions actually committed.

## V1.2 Historical Verification

1. Run the canonical installer in Edit mode and require `SOURCE PASS sourceWrites=3`.
2. Fully restart Studio. Run the same unchanged installer again and require `ASSETS PASS sourceWrites=0 sourceContracts=11 ... collisionContract=1`.
3. Fully restart Studio. Run the read-only committed-state audit and require `COMMITTED STATE PASS`. Do not start Play before this gate passes.
4. Confirm both `Templates.StarterTwoBay.CollisionShell` models exist, have equal protected part counts and include at least one Floor proxy. Confirm no collision part carries a customisation classification.
5. Enter on foot after driving around the city. Loading must remain until the named runtime interior/CharacterSpawn is locally present; the character must arrive on the floor with walls, structure, lighting and fixtures visible.
6. Verify a two-channel asset shows only its populated controls and a fuller blockout shows every populated channel.
7. Preview colour, press Back and confirm committed appearance returns. Preview again, SAVE, close/reopen and confirm persistence.
8. Verify Structure shows only populated colour/material channels and never offers material for Neon.
9. Buy/place/clear an optional zone; required Workshop/Storage must reject clearing. Confirm cash charges only once.
10. Populate one platform option in ZZZ, copy it to the matching ServerStorage path, set `Available=true`, and verify the zone appears, preview hides the fallback pads, Back restores them, and SAVE affects no display assignment.
11. Exercise foot entry, drive-in, foot exit and drive-out. A timeout/rejection must preserve origin position, driven vehicle and display assignment. Check the streaming diagnostics.
12. Walk and jump along the floor and boundaries; structure previews/swaps must never change collision. Repeat ten mixed transitions on desktop and a low-memory phone profile, check duplicate runtime models/stuck loading/input, then rejoin to confirm saved finishes and refresh the complete mirror.

## V1.2 Historical Rollback

For V1.2, the SOURCE transaction restores all three exact prior sources if projection, compilation, assignment or marker audit fails. The ASSETS transaction restores changed attributes and destroys only collision/platform containers it created if it fails. After a successful source pass but failed asset pass, garage entry deliberately fails closed on the missing collision contract rather than placing a player in unsafe space. The clean behaviour rollback remains Phase 12 V1.1/V1.2 through Studio version history; do not rerun Phase 9/10 over the newer ProfileService command boundary.

The remaining paragraph describes the superseded V1.1 recovery transaction only.

The recovery never writes source. It restores changed attributes and destroys only containers it created if it fails before PASS. The existing hybrid source state is otherwise unchanged. The clean behaviour rollback remains Phase 12 V1.1/V1.2 through Studio version history; do not rerun Phase 9/10 over the newer ProfileService command boundary.
