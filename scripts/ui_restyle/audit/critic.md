# UI restyle audit: completeness critic

Read-only. Live Studio "Space Racers v3" (93959280828322), Edit mode. Nothing changed in Studio or the repo.
No Play session. Sources: one whole-place source sweep, targeted line reads, the eleven reader notes, the style sheet.

## 1. Whole-place sweep

221 LuaSourceContainers in the place (ReplicatedStorage.Modules 140, ServerStorage.Modules 73, ReplicatedFirst.Loading 4,
ClientBase 1, ServerBase 1, two 16-line prop scripts under Workspace "FBX - 3D Lady Head v2" and
"FBX - 3D Vehicle Holographic v3"). 145 are client-visible. StarterGui, StarterPack and StarterCharacterScripts are empty.
73 scripts matched at least one UI pattern. 273 `Color3.fromRGB` in 37 client scripts (the sheet says about 230).

### 1.1 Matched scripts that no reader covered

| Script | Lines | Matched | What it is |
|---|---:|---|---|
| RS.Modules.Game.Activities.JobClient | 438 | ProximityPrompt 4, ctx.UI.Beacon, MapMarkers, toasts | Job offers: map markers, world beacon, local "JobPrompt" (E), accept flow |
| ...Activities.DuelClientView | 296 | ctx.UI.Offer, Countdown, Strip, toasts | Street duel stake menu, incoming challenge card, countdown |
| ...Activities.PassengerClientView | 188 | ProximityPrompt 2, Strip, toasts | "RIDE" prompt (F / ButtonY, UIOffset 0,40), rider strip |
| ...Activities.CourierClientView | 67 | fromRGB 1 | Strip title COURIER; the colour is a world prop |
| ...Activities.TaxiClientView | 43 | none (ctx only) | Strip title TAXI |
| ...Audio.PresentationAudioClient | 415 | PlayerGui 2, GuiButton classes | Binds hover, focus and click sounds to every GuiButton in PlayerGui |
| ...Racing.RaceParticipantVisibilityClient | 78 | BillboardGui, SurfaceGui, Highlight, name-tag properties | Hides other racers: parts, effects, any BillboardGui/SurfaceGui/Highlight, Humanoid name and health display |
| ...Racing.RaceSessionAssetsClient | 287 | world arrows | Route arrow markers and barrier proxies (world wayfinding) |
| ...Vehicles.VehicleVFXClient | 1189 | PlayerGui 3, TouchGui | L1053 looks up `PlayerGui.DriveHUD`; L1057 toggles Roblox `TouchGui` |
| ...Garage.ThrustPreviewClient | 82 | PlayerGui, TouchGui | Same `DriveHUD` and `TouchGui` handling |
| ...Vehicles.DrivingCameraClient | 787 | ScreenGui 1, CanvasGroup | `DrivingSpeedEffect` speed lines. Only the speed-line part was read (foundation-startup s6) |
| ...Development.DriveToEarnCashTelemetryClient | 95 | ScreenGui, Frame, TextLabel, UIStroke, fromRGB 3, Enum.Font.Code | Studio-only panel, DisplayOrder 2000, top-right. Config flag is false |
| ...Development.StudioCashGrantClient | 59 | SetCore | Studio-only; `SetCore("SendNotification")` (Roblox core toast) |
| ...Development.TrailerModeClient | 89 | SetCoreGuiEnabled, PlayerGui 3 | Tool-gated (off). Only SetCoreGuiEnabled caller; disables every ScreenGui in PlayerGui |
| SS.Modules.Game.Racing.TimeTrialServer | 1427 | ProximityPrompt 3 | L1293-1314 creates `RaceEntryPrompt`, Style Default, "Open Race Menu" |
| SS...Vehicles.VehicleAccessServer | 140 | ProximityPrompt 1 | L90-95 "Enter" / "Vehicle" prompt |
| SS...Garage.OwnedGarageManagement | 415 | ProximityPrompt 4 | L190-211 "Drive Out" prompts; enables ManageGarage / FootExit prompts |
| SS...Garage.OwnedGarageInterior | 57 | ProximityPrompt 1 | Disables template prompts on clone |
| SS...Garage.OwnedGarageFinish | 96 | ProximityPrompt 1 | Strips prompts from display copies |

Read by a reader as support, so not listed as uncovered: LoadingTransitionRuntime, LoadingArtworkCatalog, Core.ClientLifecycle,
RaceEntryMenuClient (headless), GaragePreviewPresentationClient, PreviewCameraClient, MobileDriveInputState, FeatureFlags,
ConfigReader, ConnectionScope.

Matched a pattern but are not UI (paint defaults, world props, audio or asset catalogues): PaintClient, PreviewVehicleClient,
GarageVehiclePreviewProfile, GarageModuleInstancePreviewAdapter, the three OwnedGarage*Catalog modules, LightingCycle,
VehiclePreviewVFXClient, TaxiJob (NPC skin and shirt colours; name tags set to None at L114), GarageProfileView, GarageServer,
GarageCatalogService, VehicleBuildService, PlayerProfileSchema, LODRuntime, RoadGraphData, the audio catalogues.

### 1.2 Pre-built GUI instances in the place

- ScreenGui: 0.
- BillboardGui: 18, all `ShowroomLoopAuthoringLabel` under `Workspace.World.RaceRoutes.ShowroomLoop`, `Enabled = false`
  ("CHECKPOINT 01".."17", "SHOWROOM LOOP START PIVOT"). Authoring aids, not player UI.
- SurfaceGui: 226. 148 city `TKY_*` billboards, 4 on an FBX building, 18 parking-garage signs, 56 under
  `Workspace.Test + WIP Assets`. World art. Six labels on the dealership building are wayfinding: BUY, CUSTOMIZE,
  CUSTOMIZATION, DEALERSHIP, ENTRANCE x2 (GothamSSm, American spelling).
- ProximityPrompt: 6. Enabled: `OwnedGarageDriveInEntryPrompt` and `OwnedGarageFootEntryPrompt` under
  `Workspace.World.OwnedGarageExteriors.STARTER_TWO_BAY`. Disabled templates: `ManageGaragePrompt` and `FootExitPrompt`
  in `ServerStorage.Assets.Garage.Templates.StarterTwoBay` and in `ServerStorage.Archive.ZZZ`. All Style Default.
- Highlight, SelectionBox, Dialog, ClickDetector, Tool: none.

### 1.3 Service settings that shape UI (read in Edit)

- StarterGui: ScreenOrientation LandscapeSensor, ResetPlayerGuiOnSpawn true, ShowDevelopmentGui true.
- StarterPlayer: NameDisplayDistance 100, HealthDisplayDistance 100, DevTouchMovementMode UserChoice, UserEmotesEnabled true,
  EnableMouseLockOption true.
- TextChatService: ChatVersion TextChatService; chat window enabled, top-left, BuilderSans 18, grey 25,27,29 at 0.3;
  input bar enabled; bubble chat enabled (white bubbles, BuilderSans 20); channel tabs off. VoiceChatService default voice on.
- `SetCoreGuiEnabled` appears only in the tool-gated TrailerModeClient, so PlayerList, Chat, Health, Backpack and
  EmotesMenu are all on in a live session. `leaderstats` exists (EconomyServer), so the player list shows Cash.
- Zero hits in any script: `SliceCenter`, `SelectionImageObject`, `PreferredTextSize`, `PreferredInput`, `ReducedMotion`,
  `TopbarInset`, `PromptShown`, `ProximityPromptStyle.Custom`, `RichText`, `AutoLocalize`, `MouseIconEnabled`,
  `PromptProductPurchase`.

## 2. Uncovered groups

1. **activity-views** (JobClient, DuelClientView, PassengerClientView, CourierClientView, TaxiClientView). They own the
   strip text, offer and stake cards, countdowns, beacon colours, toasts and two native prompts, all through
   `ActivityClient.Context`. Any new `ctx.UI` must keep that contract. They pass `ctx.Theme.Telemetry / HighSpeed /
   ElectricBlue` as meaning, which the five new roles do not cover.
2. **world-prompts** (TimeTrialServer, VehicleAccessServer, OwnedGarageManagement, OwnedGarageInterior, OwnedGarageFinish).
   About ten prompt families, all engine-drawn. The sheet's Start banner with a key cap needs `Style = Custom`, which is
   set by server scripts and templates. That is outside the sheet's "client presentation only".
3. **ui-coupled-runtime** (PresentationAudioClient, RaceParticipantVisibilityClient, RaceSessionAssetsClient,
   VehicleVFXClient, ThrustPreviewClient, DrivingCameraClient). They draw little or nothing but react to UI by class, name
   or attribute. New components must honour `UIAudioSilent`, `UIAudioSuppressClick`, `UIAudioHoverCue`, `UIAudioClickCue`.
4. **dev-studio-panels** (DriveToEarnCashTelemetryClient, StudioCashGrantClient, TrailerModeClient). Studio-only. Decide
   they are excluded from the restyle and that trailer mode still hides the new ScreenGuis.

## 3. Checks of reader claims against source

| Claim | Source | Verdict |
|---|---|---|
| `readValue` cannot return false (freeroam-desktop D1) | DesktopFreeRoamHudUI L123 `item and item.Value ~= nil and item.Value or fallback` | Correct |
| ClientBase has 46 entries (foundation-startup) | 46 `{name=` | Correct |
| 273 fromRGB in client scripts (roblox-platform, foundation) | 273 in 37 files | Correct; sheet's 230 is low |
| Michroma in 3 config values (foundation) / 5 (fonts-assets) / 4 (sheet) | Theme.FontFamily, Racing.Typography.FontFamily, GarageExperience.FontFamily, DesktopFreeRoamHud.Typography.PrimaryFont and BodyFont | Five |
| Mobile `MinimapSize` 180 (map) / 170 (mobile-onboarding) | attribute = 170 | 170 |
| "No in-race minimap today" (map) | RaceSessionPresentationClient L31-69 builds a route map from `Config.Racing.HudMapCatalog` | Too strong; a desktop route-map panel exists |
| Two ScreenGuis use Global ZIndex (garage-owned-entry, roblox-platform) | Explicit Global in Foundation and RaceSessionPresentationClient; never set in RaceBrowser, RaceEntry, Countdown, Queue, RouteGuide, Results, Transition, OwnedGarageBrowser, GarageEntrance | About eleven |
| Three near-identical colour folders (sheet, brief) | HUD and Racing match (HUD adds HighSpeed). GarageExperience has different values and one reader (GarageEntranceClient). Theme is a different legacy palette | Two match |
| `MobileScaledDesktop.Enabled = true` (racing-menus) | true; ScaleMin 0.25 | Correct |
| Intro objective off (garage-owned-entry) | ShowObjectiveText, DynamicArrowTetherEnabled, AutoOpenGarageAtDesk all false | Correct |
| VehiclePreviews.Categories 9,302 descendants, 440 models | same | Correct |
| studio_delivery route rejects v3 (docs-and-delivery) | scripts/studio_capture.py L11 lists three place ids, not v3 | Correct |
| `Config.UI.DriveInCustomisation` (10 values) | no script reads the folder | Dead config, not mentioned by any reader |

## 4. Contradictions, other surfaces and open questions

These are returned in the structured result. The main ones:

- Two switch models are mixed across the notes: new modules chosen in ClientBase with the old scripts untouched, and
  style-aware shared components edited in place. They conflict for RacingUIComponents, which the backup depends on.
- "Byte-identical backup" holds per group but not overall: about nine old scripts need small edits.
- The owned-garage desk draws through the old GarageWorkspaceUI, so it stays old-style under garage-core's option B.
- Font choice (Titillium against Barlow), glow method (9-slice against UIShadow) and the delivery tool are unsettled.
- Roblox core UI (player list with Cash top-right, chat top-left, default prompts, name tags, selection box) sits where
  the sheet puts new clusters and no script manages it.
