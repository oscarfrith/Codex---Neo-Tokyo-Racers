# Shared Responsive UI Foundation V1.1

**Status:** V1.1 installed, user-confirmed and fully source-mirrored

**Delivery lane:** The original foundation remains High-Risk because it crosses active UI and projects authoritative economy responses. The approved V1.1 continuation is Standard presentation-only: it centralises bevel/stroke rendering without changing authority, state or lifecycle.

## Acceptance Contract

### Goal

Establish one reusable responsive foundation for active Neo Tokyo Racers UI without a blanket `UICorner` scan or another profile polling loop.

### Required Changes

- Scale semantic desktop corner radii to `70%` of their existing base values.
- Scale semantic touch/mobile corner radii to `50%` of their existing base values.
- Format money through one shared compact formatter:
  - `$350,000`
  - `$999,999`
  - `$1.0M`
  - `$9.9M`
  - `$10.0M`
- Give Cash and Garage Spaces one shared bold, unwrapped metric treatment.
- Project Cash/space values from successful authoritative `Profile` or `ManagementState` responses immediately, then reconcile Cash from replicated `leaderstats.Cash`.
- Give shared confirmations controller focus, `Escape`/controller `B` cancellation, minimum `48 px` targets, safe-area clamping and viewport/orientation relayout.
- Give shared top notifications a borderless grey gradient, white text, responsive sizing, safe-area placement and a bounded three-card stack.
- Keep the free-roam Cash surface dark blue and ensure mobile no longer inherits the pink panel outline.
- Give active shared surfaces one idempotent neutral bevel owner.
- Use device-aware semantic widths: structural `1.2 px` desktop / `1 px` mobile, emphasis `1.5 px` / `1.25 px`, and glow `3 px` / `2 px`.
- Remove the mobile free-roam navigation's missing-bevel and oversized-border drift.

### Must Preserve

Server-authored prices and purchase results, ProfileService ownership, garage capacity rules, saved data, previews, purchases, race lifecycle, controls, vehicle spawning, mobile drive controls, VFX, audio and unrelated presentation.

### Explicit Exclusions

- Free-roam and racing vehicle-picker migration.
- The register-limited client bootstrap.
- Blanket or repeated runtime scans of every `UICorner`.
- A two-second profile polling loop.
- New remotes, saved fields, economy commands or purchase owners.

## Inventory And Canonical Owners

| Concern | Confirmed active owner | V1 contract |
|---|---|---|
| Corner tokens and compact money | New `Shared.Modules.UI.ResponsiveUIFoundation` | Pure shared calculations and constructors; desktop `0.70`, mobile `0.50` |
| Stroke/bevel tokens | `ResponsiveUIFoundation` | Structural/emphasis/glow widths and one direct-child, idempotent neutral bevel applicator |
| Shared racing/garage primitives | `Shared.Modules.UI.RacingUIComponents` | Delegates corners, money, metrics and confirmation creation to the foundation |
| Shared UI theme/factory | `Shared.Modules.UI.UITheme` and `UIFactory` | Read/delegate the same semantic corner contract |
| Garage semantic rendering | `GarageReplacementComponents`, `GarageWorkspaceController`, `GarageBrowserController` | One metric renderer; shared confirmation; immediate response projection |
| Dealership/customisation transactions | `ModuleShopUIController.Adapter` plus `GarageInvoke` | Server response replaces client `Profile` before rendering; shared economy projection records the same response |
| Owned-garage transactions | `OwnedGarageWorkspaceController` plus `OwnedGarageInvoke` | Successful response projects Cash immediately and adopts returned `ManagementState`; revision pushes remain reconciliation |
| Replicated Cash reconciliation | Existing `leaderstats.Cash` | Shared event-driven binder; no recurring profile request |
| Free-roam HUDs | Desktop and mobile free-roam HUD controllers | Consume shared corners, bevels, strokes, formatter, metric/binder and shared confirmation |
| Shared confirmations | `ResponsiveUIFoundation.Confirmation` | One lifecycle/focus/safe-area owner used by garage and free-roam confirmations |
| Shared top notifications | `SharedTopNotificationController_Active` | Only notification queue owner; delegates layout/cards to the foundation |

The older `Shared.Modules.Common.UITheme`, `Shared.Modules.Client.UI.UIFactory` and `ClientThemeAdapter` are compatibility-era duplicates with no active direct consumer found in the current mirror. V1 does not make them competing owners.

## Hard-Coded Corner And Stroke Audit

V1 moves active shared racing components, the canonical garage renderer, both free-roam HUDs, race countdown/session/results, race HUD, personal-best board, route guide and session controls onto the semantic corner constructor.

Justified exclusions:

- `RaceClient_Active` is the intentionally disabled Phase 2 HUD retired by the Phase 3/16 presentation stack. V1 neither enables nor rewrites it; `RaceSessionPresentationController_Active` remains the active race HUD owner.
- The register-limited bootstrap retains retired legacy corner construction because canonical garage presentation suppresses those surfaces and adding another bootstrap bridge would risk `Out of local registers`.
- Mobile driving controls and world/intro prompt surfaces remain outside this presentation-only scope; changing them would touch unrelated controls or world interaction owners.
- Vehicle-picker composition remains explicitly deferred to Chat 3.

No runtime descendant scan is installed.

V1.1 also removes common active hard-coded widths from the shared renderer, both free-roam HUDs and the active garage presentation owner. Remaining exceptions are semantic rather than drift:

- selected/purchase/warning surfaces may request the shared emphasis role;
- tutorial/objective gold and destructive red retain their meaning;
- top notifications remain borderless;
- mobile driving controls retain their dedicated control glow;
- race route ticks, physical indicators, scrollbars and text strokes are not structural UI borders;
- vehicle-picker coordinates, state, card composition and actions remain deferred.
- `GarageExperienceController_Active` remains disabled and marked `SupersededBy=NTR_GARAGE_REPLACEMENT_BROWSER_V1_4`; the enabled canonical Browser/Workspace renderers own garage geometry and styling.

## Authority And State Projection

- Clients still send intent only.
- `GarageActionController_Shadow_Disabled`, owned-garage authoritative commands and ProfileService remain the mutation owners.
- `ModuleShopUIController` continues to replace its detached client profile with the complete successful server response before rerendering.
- `OwnedGarageWorkspaceController` consumes the response's `ManagementState` in the same request and keeps revision pushes for later reconciliation.
- The shared projection helper reads only response snapshots; it never mutates saved state or invokes a remote.
- Visible Cash labels subscribe to `leaderstats.Cash` changes after the immediate response render. The binder is event-driven and has bounded connections.

## Lifecycle And Performance

- Corner scaling occurs only when each participating renderer constructs a corner.
- Bevel application inspects only the named direct child of the surface being styled and updates it idempotently; it performs no hierarchy-wide scan.
- Confirmation input, viewport and selection connections disconnect when the popup closes.
- Top notifications retain at most three live cards; each card expires within a bounded duration.
- Cash reconciliation uses property/child events, not a timer.
- No frame loop, workspace scan, catalogue scan or new server request is added.

## Canonical Installer And Rollback

Run:

```text
scripts/roblox_shared_responsive_ui_foundation_v1.lua
```

in Studio Edit mode with `MODE="INSTALL"`.

The V1.1 installer:

- preflights the confirmed/mirrored V1 source owners and unique upgrade anchors;
- projects and compiles every changed/new source before assignment;
- snapshots changed sources and config values in memory only;
- rolls the complete command back automatically if assignment or audit fails;
- creates no in-game backup folder/script;
- is idempotent after a passing install;
- provides `MODE="AUDIT"` for a read-only committed-state audit.

The source projections are guarded exact-anchor replacements. That is intentionally fragile to an unknown live-source shape: an anchor mismatch is a hard stop. Refresh/inspect the live mirror and repair this same canonical installer rather than guessing another patch. After a successful committed install, Roblox version history is the clean rollback point.

## Verification Matrix

### Edit / Install

- Require `[NTR Shared Responsive UI V1.1] AUDIT PASS`.
- Require `[NTR Shared Responsive UI V1.1] INSTALL PASS`.
- Change only `MODE` to `AUDIT` and rerun after restarting Studio.
- Require all five formatter cases, exact `0.70` / `0.50` corner tokens, and all six device/role stroke values.

### Desktop Keyboard / Mouse

- Open dealership, Customisation and owned-garage management; Cash and Spaces use the same bold treatment.
- Complete one vehicle/module/upgrade or owned-garage purchase. The visible Cash value changes on the successful response without waiting for a poll.
- Open the dealership teleport confirmation. Mouse activation works, focus begins on cancel, and `Escape` closes without teleporting.
- Trigger four top notifications quickly. At most three remain, all use the borderless grey gradient and stay below the top safe area.
- Confirm the free-roam Cash surface is dark blue with no pink outline.
- Confirm shortcut buttons, ordinary panels and Cash use the same neutral bevel direction and visibly thinner structural borders.

### Controller

- Open the shared confirmation; left/right focus moves between cancel/confirm.
- Controller `B` closes without activating the action.
- Confirm with the selected button and verify it triggers exactly once.

### Phone / Tablet

- Test portrait and landscape orientation changes while a confirmation is open.
- Confirm both buttons remain at least `48 px`, visible and inside safe bounds.
- Verify Cash remains dark blue with a blue/non-pink outline.
- Verify mobile shortcut buttons now carry the same bevel as desktop/shared buttons and structural borders render at `1 px`.
- Verify compact money at `$999,999`, `$1.0M`, `$9.9M` and `$10.0M` without clipping.
- Stack notifications in both orientations; none may leave the safe width or grow beyond three.

### Regression

- Purchases, rejection copy, saved Cash, Garage Spaces, previews, Back/Exit/Drive, race entry/countdown/results, free-roam controls and save/rejoin remain unchanged.
- Vehicle-picker geometry, selection, cards, actions and responsive layout remain unchanged.
- No new repeating `GetInitial`, `GetManagementState` or two-second profile request appears.
- Repeated open/close and orientation changes do not grow confirmation connections or notification cards.

## Readiness Scorecard

| Area | Status |
|---|---|
| Ownership | PASS: one shared foundation and enabled consumer set confirmed |
| Security | PASS: no authority or request boundary changes |
| Data | N/A: no saved schema, stable ID or migration change |
| Lifecycle | PASS: existing bounded/event-driven owners preserved |
| Performance | PASS by source audit and confirmed runtime |
| Mobile/input | PASS for the reported mobile free-roam visual regression; retain the wider device matrix as release regression |
| Streaming | N/A: PlayerGui-only presentation |
| Failure handling | PASS: guarded transaction and automatic same-run rollback |
| Observability | PASS: focused install/audit markers and bounded runtime owners |
| Documentation | PASS: confirmed baseline, mirror state and optional hierarchy warning recorded |

## Mirror Status

The complete `2026-07-26 21:28:23` mirror contains 189 mutually matching exported scripts, source-manifest entries and checksums. All 18 intended owners contain exactly one V1.1 marker, the relevant LocalScripts remain enabled, and `GarageExperienceController_Active` remains disabled/superseded. Neither mirror area appears stale for the confirmed source baseline.

Studio persisted the V1.1 sources but dropped the eight newly created optional Theme tuning `NumberValue`s and retained V1 hierarchy revision attributes after the mixed source/hierarchy command. `ResponsiveUIFoundation` contains and uses the identical audited defaults, so the confirmed runtime is complete. The canonical audit treats this hierarchy-only discrepancy as a warning. Do not claim those tuning objects exist or rerun a working feature; use the documented generic persistence probe and a hierarchy-only recovery only if editable tuning becomes necessary.
