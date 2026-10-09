"""Shell family: writes routes.json, spec_ops.json and contract.json (API2 6.1, 6.5). Run: py -3 gen_fragments.py
Kept as a script so the three fragments are always valid JSON and are regenerated from one place."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
UIP = ["ReplicatedStorage", "Modules", "Game", "UIPulse"]
P = "ReplicatedStorage.Modules.Game.UIPulse."
A = "API2 5.8"


def put(name, value):
    (HERE / name).write_text(json.dumps(value, indent=1) + "\n", encoding="utf-8", newline="\n")


def create(op_id, path):
    return {"id": op_id, "kind": "create", "class": "ModuleScript", "path": path, "after": "after/" + ".".join(path) + ".lua"}


def attr(on, name, *dirs):
    return [{"on": on, "name": name, "dir": d} for d in dirs]


put("routes.json", {"family": "Shell", "swap": {"OnboardingClient": P + "Shell.OnboardingClient"}, "add": []})

put("spec_ops.json", [
    {"id": "shell", "kind": "create", "class": "Folder", "path": UIP + ["Shell"],
     "_note": "UIPulse.Shell is first created by the FreeRoam install (Shell.CoreUiPolicy, API2 5.3). The integrator drops "
              "this op when the folder is already in the chain; it is here so the family is complete on its own."},
    create("shell.onboardingmodel", UIP + ["Shell", "OnboardingModel"]),
    create("shell.onboardingview", UIP + ["Shell", "OnboardingView"]),
    create("shell.onboardingclient", UIP + ["Shell", "OnboardingClient"]),
    create("shell.fixtures", UIP + ["Dev", "Fixtures", "Shell"]),
    create("shell.loadingview", ["ReplicatedFirst", "Loading", "LoadingScreenViewPulse"]),
    dict(create("shell.startscreen", ["ReplicatedFirst", "Loading", "StartScreenPulse"]),
         _note="Fork output (forks/StartScreenPulse.json); the after/ file in this folder is the hand assembly for review."),
    {"id": "shell.runtime", "kind": "source", "class": "ModuleScript",
     "path": ["ReplicatedFirst", "Loading", "LoadingTransitionRuntime"],
     "before": "before/ReplicatedFirst.Loading.LoadingTransitionRuntime.lua",
     "after": "after/ReplicatedFirst.Loading.LoadingTransitionRuntime.lua",
     "_note": "API2 5.8: line 8 becomes two lines. Reviewer."},
    {"id": "shell.initialloading", "kind": "source", "class": "LocalScript",
     "path": ["ReplicatedFirst", "Loading", "InitialLoadingAndStartScreenClient"],
     "before": "before/ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient.lua",
     "after": "after/ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient.lua",
     "_note": "API2 5.8: two lines inserted after line 18. Reviewer."},
])

LOADING_STATE = "PlayerScripts.Runtime.UI.LoadingPresentationState"
onboarding = {
    "owner": P + "Shell.OnboardingClient", "replaces": ["OnboardingClient"],
    "screenGuis": [{"name": "Onboarding", "displayOrder": 990}, {"name": "OnboardingScrim", "displayOrder": 989}],
    "remotes": [
        {"remote": "Remotes.Onboarding.OnboardingInvoke", "kind": "invoke", "action": "GetState", "keys": []},
        {"remote": "Remotes.Onboarding.OnboardingInvoke", "kind": "invoke", "action": "MarkSeen", "keys": ["PageId"]}],
    "listens": [{"remote": "Remotes.Onboarding.OnboardingStateChanged"}],
    "bindables": [
        {"name": "Runtime.UI.OpenDrivingControlsFromOnboarding", "dir": "fire", "keys": ["FirstDrive"]},
        {"name": "Runtime.UI.FreeRoamVehicleSpawned", "dir": "connect"},
        {"name": "Runtime.UI.FreeRoamHudPresentationMode", "dir": "connect"},
        {"name": "Runtime.UI.LoadingPresentationChanged", "dir": "connect"}],
    "attributes": (
        attr("Player", "FirstDrivePresentationPending", "write", "read", "listen")
        + attr("Player", "StartScreenActive", "read", "listen")
        + attr("Player", "FullMapOpen", "read", "listen")
        + attr("Player", "DrivingControlsOpen", "read", "listen")
        + attr("Player", "OwnedGarageInside", "read", "listen")
        + attr("Player", "GarageSessionActive", "read", "listen")
        + attr("Player", "GarageSessionMode", "read", "listen")
        + attr("Player", "RaceSessionActive", "read", "listen")
        + attr("Player", "MobileFreeRoamCarMenuOpen", "read", "listen")
        + attr("Player", "MobileMajorMenuOpen", "read", "listen")
        + attr("Player", "OnboardingStage", "listen")
        + attr("PlayerGui", "OwnedGarageManagementOpen", "read", "listen")
        + attr(LOADING_STATE, "Active", "read", "listen")
        + attr(LOADING_STATE, "Destination", "read")),
    "names": [], "contextActions": [], "renderSteps": [],
    "audio": [{"cue": "Objective.Complete", "keys": ["Key", "ObjectiveIndex"]}],
    "dropped": [
        {"item": "RenderStepped 0.2 s tick (757) that ran applyLocks, refreshObjective, updateGuideTrail and pollPages",
         "reason": A + ": no timer walks PlayerGui or Workspace; the same four steps run on events (marks, Presence, attributes, bindables)"},
        {"item": "RenderStepped waits in scheduleLayout (375) and refreshLoadingGate (732)",
         "reason": A + " and API1 11 rule 7: no frame binding outside Kit.Perf; layout follows AbsolutePosition and AbsoluteSize signals, the gate uses two zero-length timers"},
        {"item": "Enabled writes on the Onboarding ScreenGui (730, 734)",
         "reason": "API2 6.2 and PC 1.5 rule 8: shown and hidden with the layer root Visible"},
        {"item": "PlayerGui walks by name, text and attribute (named, buttonWithText, labelStarts, screenRoot, canonicalBrowser, cardGroup, "
                 "visibleScrollerCards, workspacePage, 115-188) and every name they look up: CanonicalGarageGui, CanonicalCanvas, "
                 "CanonicalGarageBrowser, RaceBrowser, RaceEntryPresentation, OwnedGarageBrowser, DesktopFreeRoamHud, DesignRoot, ModalLayer, "
                 "Controls, CarPanel, AccessControls, Car, Race, Garage, Boost, BoostButton, DriftLeft, DriftRight, DriftLeftButton, "
                 "DriftRightButton, Categories, Stats, Capacity, VehicleScroller, TutorialCardScroller, UpgradeBudget, CardContent, "
                 "TeleportToStart, TierE, TierD, TierC, TierB, TierA, TierS, PrizeSummary, MedalTargets, LapSelector, RaceFormat, "
                 "DetailColumn, GarageList, Enter; the texts DEALERSHIP, TIME TRIAL, RACE",
         "reason": A + ": targets resolve through Input.Marked(key) with the keys of Kit.Contracts.Marks; this owner types no tutorial name"},
        {"item": "Attribute reads CanonicalGarageCard, CanonicalGarageCardId, TutorialWorkspace, TutorialPageId on GUI instances",
         "reason": A + " and API2 2.5: read generically from Contracts.Marks[key].Attributes, never by name"},
        {"item": "Workspace walk for DeskPromptAnchor (649); OwnerUserId, DriverUserId, RaceParticipant, RaceRunId vehicle attribute reads stay",
         "reason": A + ": a scoped DescendantAdded listener on World.Interiors.OwnedGarageInstances"},
        {"item": "Objective card enter, exit and reflow tweens with their stagger and unlock delay (543-611); CanvasGroup cards",
         "reason": A + " (rebuilt) and API1 11 rule 5 (no CanvasGroup): three pooled cards shown and hidden in the TopLeftHud slot"},
        {"item": "Objective cards hung under AccessControls inside an owned garage, under the HUD shortcut row on phones, and the Boost overlap shrink (613-640)",
         "reason": A + " and API2 2.4 keep-out rule 3: cards sit in the TopLeftHud slot; AccessControls and BoostButton are not marks"},
        {"item": "Config reads for the Classic look and scale: TutorialGold (callout), DimTransparency, NextGradientTransparency, "
                 "HighlightPaddingPixels, CalloutMarginPixels, EdgeOverscanPixels, TargetStabilityFrames, LandscapePhoneShortSidePixels, "
                 "LandscapePhoneScale, LandscapePhoneTextWidthRatio, LandscapePhoneShortcutWidthRatio, LandscapePhoneShortcutGapPixels, "
                 "ShortcutCalloutGapPixels, TutorialTextSize, TutorialMinimumScale, TutorialMaximumScale, TutorialDesktopMinimumScale, "
                 "TutorialPhoneMinimumTextSize, TutorialDesktopMinimumTextSize, TutorialStackedWidthPixels, TutorialMaximumTextWidth, every "
                 "Objective* size and timing; LoadingSystem DisplayOrder",
         "reason": A + ": scale is the kit scale (API2 2.10); sizes are tokens; the order is Layers.Order Onboarding 990"},
        {"item": "TextService GetTextSize with Enum.Font.Michroma; GuiService GetGuiInset; TweenService",
         "reason": A + ": the kit measures and lays out its own text; safe area and top bar come from Kit.Metrics"},
        {"item": "UIAudioHoverCue writes typed by the owner (87, 88, 93)",
         "reason": "API1 section 9: Input.Silence and the kit button set the audio attributes"},
        {"item": "Classic start-up print line (759)", "reason": A + ": a new owner prints its own line"}],
    "added": [
        {"item": "OnboardingScrim ScreenGui (989) for the dimmer", "reason": A + ": Layers.Create Onboarding with Scrim = true"},
        {"item": "Presence (Presence.Any, Presence.Changed) in place of the menu-open PlayerGui walks", "reason": A + " and API2 3.9"},
        {"item": "Attribute listens on GarageSessionActive, GarageSessionMode, RaceSessionActive, MobileFreeRoamCarMenuOpen, MobileMajorMenuOpen, "
                 "OwnedGarageInside, OnboardingStage and PlayerGui OwnedGarageManagementOpen (Classic read them on its tick)",
         "reason": A + ": the attributes Classic already reads become the events that replace the tick"},
        {"item": "Re-check triggers: UserInputService.InputEnded (activation inputs), Humanoid.Seated, CharacterAdded, and Visible / AncestryChanged "
                 "/ attribute listeners on marked instances, with a bounded settle (0.15 to 4 s)",
         "reason": A + ": no polling; NOTES question 1 asks for the Input signal that would replace the input trigger"},
        {"item": "Pages do not begin before GetState has returned",
         "reason": A + " (returning players get their saved progress); Classic guarded the objectives and the trail this way, not the pages"},
        {"item": "Strings: TIP n OF m on the callout; GETTING STARTED . STEP n OF 3 over the objective cards; n/3 in the Compact number cell",
         "reason": A + " target frames r18 and c18 (API2 6.6 rule 8)"},
        {"item": "NEXT takes focus for pad and keyboard (trapping focus group)", "reason": A + ": callouts advance by pad and keyboard"},
        {"item": "Guide trail colour overlay: TutorialGold answered with the Pulse Cyan token; every other trail attribute still read from Config.Player.Onboarding",
         "reason": A + " (Phase 0 spike 15)"},
        {"item": "Retry delay for a missing card target backs off from 0.08 s to 0.64 s", "reason": "API2 6.6 rule 5: no wait loop that polls for presence"}],
}

loading = {
    "owner": "ReplicatedFirst.Loading.LoadingScreenViewPulse", "replaces": ["LoadingScreenView"],
    "screenGuis": [{"name": "LoadingSafeContent", "displayOrder": 1001}, {"name": "LoadingSafeContentScrim", "displayOrder": 1000}],
    "remotes": [], "listens": [], "bindables": [], "attributes": [],
    "names": ["SafeRoot", "Status", "ProgressTrack", "ProgressFill"],
    "contextActions": [], "renderSteps": [], "audio": [],
    "dropped": [
        {"item": "LoadingBackground ScreenGui (31)",
         "reason": A + ": artwork and the input blocker live in LoadingSafeContentScrim (1000); no other script reads the name (audit foundation-startup 553)"},
        {"item": "Enabled writes on LoadingBackground and LoadingSafeContent (31, 40, 243, 244, 303, 304)",
         "reason": "API2 6.2 and PC 1.5 rule 8: both roots are shown with Visible"},
        {"item": "DisplayOrder from Config.UI.LoadingSystem DisplayOrder; ScreenInsets CoreUISafeInsets",
         "reason": A + " and API2 2.4: Layers.Order rows 1000 and 1001; DeviceSafeInsets from Layers.Create"},
        {"item": "StatusWidthConstraint, the UISizeConstraints, UICorners and the bar UIGradient; colours from Config.UI.DesktopFreeRoamHud.Colours",
         "reason": A + " (only type, bar and status are Pulse) and API1 11 rule 5"}],
    "added": [
        {"item": "LoadingSafeContentScrim ScreenGui (1000) in place of LoadingBackground", "reason": A + " and API2 2.4 ladder rows"},
        {"item": "Presence.Open Loading while shown", "reason": "API2 3.9"},
        {"item": "Deferred Claim Loading when the latch publishes UIStyleCommitted", "reason": "API2 6.2 claim names; API1 4 (Claim refuses before Commit)"}],
}

ARTWORKS = "ReplicatedStorage.Config.UI.LoadingSystem.Artworks.*"
LOADING_CONFIG = "ReplicatedStorage.Config.UI.LoadingSystem"
start = {
    "owner": "ReplicatedFirst.Loading.StartScreenPulse", "replaces": ["InitialLoadingAndStartScreenClient"],
    "screenGuis": [],
    "remotes": [{"remote": "Remotes.UI.FreeRoamHudTeleportInvoke", "kind": "invoke", "action": "TeleportToDealership", "keys": []}],
    "listens": [],
    "bindables": [{"name": "Runtime.UI.FreeRoamVehicleExited", "dir": "fire"}],
    "attributes": (
        attr("Player", "StartScreenActive", "write")
        + attr(LOADING_CONFIG, "TimeoutSeconds", "write", "read")
        + attr(ARTWORKS, "Enabled", "write", "read")
        + attr(ARTWORKS, "StartScreenEligible", "read")),
    "names": ["LoadingSafeContent", "SafeRoot", "Status", "ProgressTrack", "ProgressFill", "StartScreenCompletionFill", "StartScreenActions"],
    "contextActions": [], "renderSteps": [], "audio": [],
    "dropped": [
        {"item": "RacingUIComponents require (22) and UI.Button, UI.Colour, UI.Asset, UI.Font", "reason": A + ": replaced span, kit buttons"},
        {"item": "Menu builder and layout (113-280): portrait and phone branches, StartScreenButtonYScaleDesktop, "
                 "StartScreenButtonYScaleLandscapePhone, StartScreenButtonYScalePortrait, StartScreenPlayIconAssetId, "
                 "StartScreenShopIconAssetId, the camera ViewportSize listener",
         "reason": A + ": replaced spans; kit slots, kit icons, no portrait branch"},
        {"item": "StartScreenEnabled read and the early RemoveDefaultLoadingScreen (15-18)",
         "reason": A + ": stays in InitialLoadingAndStartScreenClient, before the guard"},
        {"item": "Status literal LOADING NEO TOKYO (38)", "reason": A + ": LOADING PULSE RACERS"}],
    "added": [
        {"item": "READY label over the buttons on Regular; Shop left of Play", "reason": A + " target frame r19b; API1 7.3 button order (main right-most)"},
        {"item": "Play focused for pad and keyboard", "reason": A},
        {"item": "Deferred Claim StartScreen when the latch publishes UIStyleCommitted", "reason": "API2 6.2 claim names; API1 4"}],
}

put("contract.json", [onboarding, loading, start])
print("wrote routes.json, spec_ops.json, contract.json")
