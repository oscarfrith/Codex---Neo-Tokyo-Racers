# Mobile Racing UI Phase 1 - Scaled Desktop Trial

Date: 2026-07-13

## Outcome

This phase tests the lowest-risk mobile migration requested by the user: reuse the approved PC racing-menu composition and uniformly scale it into a mobile safe area instead of maintaining a separate touch reflow.

The phase covers the existing isolated presentation owners for:

- Race Browser;
- race/time-trial setup, placement prizes, records, and vehicle selection;
- unified race and time-trial results/prize presentation.

It deliberately does not change the in-race HUD, race progression, matchmaking, rewards, personal-best storage, route arrows, driving, VFX, LOD, server services, or the register-limited bootstrap.

## Studio Installer

Run this entire file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_ui_mobile_phase1_scaled_desktop_trial.lua
```

Leave `MODE = "INSTALL"`, run it once, restart Play, and test on a touch/mobile viewport. After installation, switch the same file to `MODE = "SMOKE"` and run it again in Edit mode for the structural check.

## Implementation

The installer creates:

```text
ReplicatedStorage.NeoTokyoRacers.Shared.Modules.UI.RacingMobileScaledDesktopLayout
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.MobileScaledDesktop
```

It then applies exact guarded source edits to:

```text
RaceBrowserClient_Active
RaceEntryPresentationController_Active
RaceTimeTrialResultCoachClient_Active
```

On touch devices with `Enabled = true`, each owner selects its existing desktop layout branch. The shared module keeps the shell at the PC `1200 x 720` reference size and uses one `UIScale` to fit it below Roblox's top controls. PC devices keep the existing `RacingUIComponents.AttachResponsiveScale` path unchanged.

Default tuning attributes:

```text
Enabled = true
ReferenceWidth = 1200
ReferenceHeight = 720
SafeTop = 72 (Phase 1B; Phase 1 originally used 84)
SafeBottom = 10
SafeSide = 10
ScaleMin = 0.25
ScaleMax = 1.00
```

The layout updates when the camera viewport or tuning attributes change, including phone rotation and emulator resize.

## Verification

Use Mobile Emulator or a real landscape phone and verify:

1. Open Race Browser from the free-roam Race button.
2. Confirm the complete PC composition is visible below the Roblox top buttons, including title, event list, media, event details, prize, Exit, and Teleport.
3. Confirm nothing overlaps the two footer buttons and every button is tappable.
4. Enter the race/time-trial menu and visit setup, placement prizes, records, and vehicle selection.
5. Confirm each page preserves the PC proportions and all text/cards remain inside the shell.
6. Finish one time trial and, if practical, one race; confirm the unified result/prize screen fits and both footer actions work.
7. Rotate or resize the emulator once and confirm the shell recentres/rescales.
8. Repeat one Browser open/close cycle on PC and confirm the approved PC layout is unchanged.

This is a visual trial. If the complete PC composition is readable and usable, retain the shared system and tune only the config safe area/scale. If important text is too small on real phones, use a targeted mobile typography/content-density follow-up rather than restoring the old full-screen touch reflow wholesale.

## Risk And Rollback

The installer uses fragile text replacement, but it is limited to exact refreshed source anchors. It stages all six source edits in memory before mutating Studio and stops on the first missing or duplicate anchor.

For an immediate layout rollback, set:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.MobileScaledDesktop.Enabled = false
```

Then restart Play. That returns touch devices to the previous touch-specific layout. PC behavior is not controlled by this flag.

For a full source rollback, use Studio version history or restore the three presentation owners from the pre-install snapshot refreshed at `2026-07-13 19:38:44`.

## Mirror Requirement

The pre-install mirror was refreshed at `2026-07-13 19:38:44` and contains Mobile Free-Roam Phase 1K plus Racing Phase 16F. Phase 1 was subsequently installed and user-confirmed working. Phase 1B changes only `SafeTop` from `84` to `72`; refresh the Studio mirror again after that config refinement is confirmed.
