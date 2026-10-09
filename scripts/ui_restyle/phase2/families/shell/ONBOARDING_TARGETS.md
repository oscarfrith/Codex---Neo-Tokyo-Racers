# Onboarding targets: which Pulse mark each page and card needs, and who registers it

Desk audit, 2026-10-09. Nothing here ran in Studio. Line numbers are the working copies under `scripts/ui_restyle/phase2/` at the time of the audit; other agents were editing the garage, race entry and race menu files the same day, so re-grep `Mark(` and `MarkKey` if a line has moved.

Short paths: `GSV` = `families/garage/after/…Garage.GarageScreenView.lua`, `GR` = `…Garage.GarageRoutes.lua`, `GM` = `…Garage.GarageModel.lua`, `OGB` = `…Garage.OwnedGarageBrowserUI.lua`, `DESK` = `…Garage.OwnedGarageDeskView.lua`, `HUD` = `families/free_roam/after/…FreeRoam.HudView.lua`, `TOUCH` = `…FreeRoam.TouchControlsView.lua`, `RM` = `families/race_menu/after/…RaceMenu.RaceMenuView.lua`, `SETUP` = `families/race_entry/after/…RaceEntry.SetupView.lua`, `REC` = `…RaceEntry.RecordsView.lua`.

How the finder reads a mark (`Shell.OnboardingClient._targets`): the instance must be in `Input.Marked(key)`, be showing (every ancestor `Visible`, size above 1 px), and still carry the mark. "Carry" is: the mark's attributes for an attribute mark; the mark's text for a text mark; for a name mark, the mark's `Name` **or** `PulseMark == key` (added in this pass, see the two mismatches below).

## Result

52 targets (19 page signals, 33 cards): **49 ok, 3 mismatched, 0 missing.** All three mismatches are fixed inside the shell family; no other family has to change for onboarding to work. Two one-line hardening changes in the garage are listed at the end and are optional.

## Pages (the signal that begins a page)

| Page | Pulse screen | Mark key(s) | Registered at | Status |
|---|---|---|---|---|
| Dealership | Garage, dealership browser | `Text.Dealership` | GSV:322 (Header `MarkKey`; the kit marks the title label) | ok |
| CustomisationHome | Garage, customise tab bar (stands for the Classic hub) | `Page.CustomisationHome` | GSV:378 (`Routes.HomeMark`, GR:41) | ok |
| AddModules | Garage, Parts tab body | `Page.AddModules` | GSV:614 (GR:33) | ok |
| UpgradeModules | Garage, Upgrades tab body | `Page.UpgradeModules` | GSV:614 (GR:35) | ok |
| PaintShop | Garage, Paint tab body | `Page.PaintShop` | GSV:614 (GR:37) | ok |
| MobileDriving | Touch drive controls (touch only) | `DriftLeft` (or `DriftLeftButton`) | TOUCH:143 (spec TOUCH:22) | ok; `DriftLeftButton` is not registered and is not needed |
| VehicleShortcut | HUD action bar (stage 2 and up) | `Car` | HUD:143 (IconButton `MarkKey`, HUD:134) | ok |
| GarageShortcut | HUD action bar (after VehicleShortcut) | `Garage` | HUD:144 | ok |
| GarageBrowser | Owned garage browser | `GarageList` | OGB:115 | ok |
| GarageHome | Garage desk, Home | `Page.GarageHome` | DESK:239 (host frames, ids DESK:15) | ok |
| DisplayCars | Garage desk, Display spaces | `Page.DisplayCars` | DESK:239 | ok |
| GarageAssetFamilies | Garage desk, Build or Style | `Page.GarageAssetFamilies` | DESK:239 | ok |
| BuildStructure | Garage desk, Build structure | `Page.BuildStructure` | DESK:239 | ok |
| BuildDecorations | Garage desk, Build decorations | `Page.BuildDecorations` | DESK:239 | ok |
| RaceShortcut | HUD action bar (after GarageShortcut) | `Race` | HUD:145 | ok |
| RaceBrowser | Race menu, event list | `CardContent` | RM:197 | ok |
| EventMode | Race entry, mode tabs | `Text.TimeTrial` and `Text.Race` | SETUP:26-27 (tabs SETUP:371), REC:23-24 (tabs REC:231) | ok; needs an event that offers both modes, as Classic |
| TimeTrialSetup | Race entry, time-trial setup | `TierE` and `LapSelector` | SETUP:152 (tier tabs), SETUP:417 (Stepper `MarkKey`) | ok; needs an event with a tier E, as Classic |
| RaceSetup | Race entry, race setup | `RaceFormat` | SETUP:473 | ok |

## Cards (the control a callout points at)

| Card | Page | Mark key(s) | Registered at | Status |
|---|---|---|---|---|
| G1 | Dealership | `Categories` | GSV:331 (category tabs) | ok |
| G4 | Dealership | `Stats` | GSV:335 on the `Data.StatPanel` root (GSV:333) | **mismatched**: the panel writes its root `Name` back to `StatPanel` on its next draw (`Kit.Data` 1700 through `Kit.Surface` 120), so the name mark was lost as soon as a vehicle's rows arrived. Fixed in shell (PulseMark). |
| A2 | Dealership | `Capacity` | GSV:343 (proxy frame, sized from the status strip at GSV:591) | ok |
| G2 | Dealership | scroller `VehicleScroller`, cards `Card` | GSV:352; tiles GSV:76 (`item.Card`, GM:1184) | ok |
| J1 | CustomisationHome | `Card.AddModules` | GSV:370 (tab `MarkKey`, GR:33) | ok: the tab button is the card |
| J2 | CustomisationHome | `Card.UpgradeModules` | GSV:370 (GR:35) | ok |
| J3 | CustomisationHome | `Card.PaintShop` | GSV:370 (GR:37) | ok |
| K1 | AddModules | scroller `TutorialCardScroller`, cards `Card` | GSV:388; tiles GSV:76 (`_cardMark`, slot tiles GM:1507) | ok. Slot tiles carry the generic `Card` mark (no `CanonicalGarageCardId`); K1 asks only for `Card`, so no id is needed |
| L1 | UpgradeModules | `Categories` | GSV:455 (module picker, built at GSV:672 when the page has a picker) | ok |
| L2 | UpgradeModules | `UpgradeBudget` | GSV:464 on a `Text.Label` root (GSV:463) | **mismatched**: `Text.Label` writes its root `Name` (`BudgetText`) on every draw (`Kit.Text` 578); the very next `BudgetText.Set` in the workspace render undid the mark. Fixed in shell (PulseMark). |
| M1 | PaintShop | `Categories` | GSV:455 (area picker) | ok |
| D7 | MobileDriving | `DriftLeft`, `DriftRight` | TOUCH:143 (TOUCH:22-23) | ok; the two `…Button` names are Classic alternates |
| D8 | MobileDriving | `Boost` | TOUCH:143 (TOUCH:26) | ok |
| B2 | VehicleShortcut | `Car` | HUD:143 | ok (also the lock target; HUD:137 mirrors `Active` as the locked look) |
| B3 | GarageShortcut | `Garage` | HUD:144 | ok |
| B4 | RaceShortcut | `Race` | HUD:145 | ok |
| N1 | RaceBrowser | `CardContent` | RM:197 | ok |
| N6 | RaceBrowser | `TeleportToStart` | RM:306 | Regular ok. **Compact mismatched**: the button is on the detail page, where the list (the page root) is hidden, so the page was abandoned after 3 s and N1 replayed on every visit. Fixed in shell (`Model.OffRoot`). |
| O1 | EventMode | `Text.TimeTrial`, `Text.Race` | SETUP:26-27, REC:23-24 | ok |
| Q1 | TimeTrialSetup | `TierE` … `TierS` | SETUP:152 (SETUP:31) | ok |
| Q5 | TimeTrialSetup | `PrizeSummary` | SETUP:424 | ok |
| Q8 | TimeTrialSetup | `MedalTargets` | SETUP:436 | ok |
| Q4 | TimeTrialSetup | `LapSelector` | SETUP:417 | ok |
| P1 | RaceSetup | `RaceFormat` (fallback `DetailColumn`) | SETUP:473 | ok; `DetailColumn` is registered nowhere and is only the Classic fallback |
| X1 | GarageBrowser | `GarageList` | OGB:115 | ok |
| X3 | GarageBrowser | `Enter` | OGB:193 | ok |
| Z1 | GarageHome | `Card.DisplayCars` | DESK:70 (tile `MarkKey` from the row id) | ok |
| Z2 | GarageHome | `Card.BuildGarage` | DESK:70 | ok |
| Z3 | GarageHome | `Card.StyleGarage` | DESK:70 | ok |
| AA1 | DisplayCars | scroller `TutorialCardScroller`, cards `Card` | DESK:289; tiles DESK:70 | ok |
| AB1 | GarageAssetFamilies | `Card.Structure`, `Card.Decorations`, `Card.Lighting` | DESK:70 | ok |
| AC1 | BuildStructure | `Categories` | DESK:408 (location tabs) | ok |
| AD1 | BuildDecorations | `Categories` | DESK:408 | ok |

## The fixes for the three mismatches (all in the shell family)

1. **G4 and L2, name marks undone by the kit.** `Shell.OnboardingClient` `matches`: a name mark is carried when `instance.Name == mark.Name` or when `instance:GetAttribute("PulseMark") == key` (the attribute `Input.Mark` writes, `Kit.Input` 13 and 328). A re-marked instance has another `PulseMark`, so the "no longer carries the mark" rule still holds. Test: `OnboardingClient_test`, "name marks survive a kit rename".
2. **N6 on Compact.** `Shell.OnboardingModel` `Model.OffRoot = { N6 = true }`: when the page root is gone, a card listed there is looked up without a root; while its target shows the page is kept and the callout is pinned. Only N6 is listed, because `Categories` and `Card` exist on several screens. Test: `OnboardingModel_test`, "off-root card (N6)".

## Optional hardening in other families (not required; do not block on these)

Each makes the instance keep its mark name by itself, so a Play probe that reads names agrees with the finder.

| File:line | Change |
|---|---|
| GSV:333 | `Data.StatPanel(browserColumn, { Name = "Stats", Title = "", Rows = {} }, scope)` (add `Name = "Stats"`) |
| GSV:463 | in the `Text.Label` props, `Name = "UpgradeBudget"` in place of `Name = "BudgetText"` |

`Enter` (OGB:193) and `TeleportToStart` (RM:306) are marked with `Input.Mark` on a `ButtonRow` button. They keep their names today because neither row is given a new `Buttons` list after the mark; if one ever is, `Controls._rowPatch` renames the button to `Button<Id>`. The shell fix covers that case too; passing `MarkKey = "Enter"` (OGB:182) and `MarkKey = "TeleportToStart"` (RM:301) in the button spec would make the kit own the mark.

## What only Play can show

- Whether each marked part is on screen when its card is reached: G4 needs a selected vehicle (the stat panel is drawn when the page has stats), L2 needs a module with an upgrade budget, X3 and N6 point at a button that is disabled until a garage or an event is selected (the race menu selects its first row on open, RaceMenuModel 389; the garage browser was not checked), and the dimmer blocks every other control on an action step, as in Classic.
- First appearance of parts drawn after a fetch (NOTES question 1): a page whose marked parts appear more than 4 s after the last event waits for the next click.
