# Owned Garage Mobile Access And World Entries V1

Status: user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror. The installer is recovery-only for this exact scope.

## Compact readiness contract

- **Delivery lane:** Standard. This is a connected UI/world-entry change with clear existing owners and no new persistence, economy or remote boundary.
- **Goal:** Make the Private/Invite HUD and dropdown usable on narrow touch screens, and provide movable on-foot and drive-in entry locations for the starter garage.
- **Confirmed baseline:** The refreshed mirror contains the shared dropdown and authoritative owned-garage transition flow. `OwnedGarageExteriors.STARTER_TWO_BAY` contains only `FootExitSpawn` and `VehicleExitSpawn`; the later material-icon zoom is unrelated live-only state.
- **Required:** Scale the compact access HUD as one composition; add property-scoped native prompts; preserve the garage browser, server entry decision, vehicle lifecycle, streaming handshake and return spawns.
- **Excluded:** Final world art, a second teleport/remote owner, visitor admission, saved-data changes, changes to `OwnedGarageWorkspaceController`, and any ZZZ dependency.
- **Owners:** `GarageInteriorModeController` owns the access HUD; `OwnedGarageBrowserController` owns browser presentation and forwards existing entry intent; `OwnedGarageManagementRuntime` remains the sole transition/vehicle authority; the exterior property folder owns entry and exit geometry.
- **Inputs/outputs:** Touch viewport size and five runtime attributes produce one bounded HUD scale. A native prompt supplies a stable property ID to the existing browser, which submits the existing server request.
- **Lifecycle and streaming:** No loop or new connection owner is added. The existing prompt-service connection is extended. Exterior content may stream normally; triggering requires the prompt to be locally present.
- **Authority:** Entry parts and prompt attributes select presentation only. The server still verifies ownership, current vehicle, speed, capacity and transition state through the existing action.
- **Scale budget:** Two static parts and two prompts per property; no frame scan, Workspace scan or new remote traffic. HUD relayout occurs only on camera/viewport change.
- **Input coverage:** Native prompt supports E, gamepad X and touch. Touch scale is clamped from `0.72` to `1.0` by default.
- **Failure/rollback:** The installer preflights exact source anchors, compiles both projected sources and rolls source/config/new hierarchy back together on failure. Roblox version history remains the fallback after a later manual edit.
- **Done when:** Install prints PASS; both entry prompts open with the correct property selected; foot and seated-vehicle entry retain current behavior; dropdown buttons/rows align on desktop and a narrow phone; repeated open/close creates no duplicate prompts or HUD.

## Authoring paths

- Foot entry: `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.FootEntrance`
- Drive-in entry: `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.DriveInEntrance`
- Foot return: `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.FootExitSpawn`
- Vehicle return: `Workspace.NeoTokyoRacersWorld.OwnedGarageExteriors.STARTER_TWO_BAY.VehicleExitSpawn`

Move the whole entry part, not its prompt. The generated entry parts are transparent authoring/interaction markers and do not replace final building, door or road art.

## Mobile tuning

Tune these attributes on `ReplicatedStorage.NeoTokyoRacers.Config.Runtime.OwnedGarage_EditAttributes`:

- `InteriorHudTouchResponsiveScale`
- `InteriorHudTouchReferenceWidth`
- `InteriorHudTouchReferenceHeight`
- `InteriorHudTouchMinimumScale`
- `InteriorHudTouchMaximumScale`

Keep the scale shared between the anchor buttons and dropdown. The default minimum is intentionally conservative; lower it only after verifying readable text and reliable touch selection on the smallest target phone.
