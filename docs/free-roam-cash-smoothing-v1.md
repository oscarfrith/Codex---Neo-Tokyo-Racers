# Free-Roam Cash Smoothing V1

**Status:** Installed, user-confirmed, fully mirrored and handed off on 2026-07-27  
**Canonical installer:** `scripts/roblox_freeroam_cash_smoothing_v1.lua`  
**Revision:** `NTR_FREEROAM_CASH_SMOOTHING_V1`

## Contract

**Goal:** Make desktop and mobile free-roam Cash visibly count through small positive gains while the real server balance continues to commit at its bounded cadence. Free-roam Cash must use full grouped formatting, for example `$10,000,000`, rather than `$10.0M`.

**Lane:** Standard presentation with an economy-authority boundary. The feature changes only rendered text, but it must never become a balance, affordability, purchase, reward, persistence, or reconciliation owner.

**Confirmed baseline:** The user confirmed the installed smoothing and full-formatting result working well. The complete `2026-07-27 11:26:30` mirror has 191 matching exported-script, source-manifest and checksum entries and contains Drive-To-Earn V1.1 plus the shared, desktop and mobile presentation owners. The live config records `CashPerAcceptedStud=0.1`, `VisibleGrantBatchCash=1`, and `MinimumGrantIntervalSeconds=0.1`; the V1.1 service source safety-clamps the effective grant interval to `0.5` seconds.

## Owners and preserved behaviour

| Concern | Owner |
|---|---|
| Real Cash, rewards, ceiling, saves | Existing server economy/ProfileService owners |
| Replicated authoritative balance | Existing `leaderstats.Cash` |
| Shared bounded display interpolation | `ResponsiveUIFoundation.CreateCashDisplayPresenter` |
| Desktop free-roam label and Cash modal chip | Existing `DesktopFreeRoamHudController_Active` |
| Mobile free-roam label | Existing `MobileFreeRoamHudController_Active` |
| Garage affordability and purchase state | Existing raw `BindReplicatedCash` consumers; unchanged |

The installer does not change `BindReplicatedCash`, ProfileService, Drive-To-Earn, race rewards, garage actions, autosave, remotes, driving physics, or the register-limited bootstrap.

## Presentation state rules

1. The first replicated value snaps immediately.
2. Any decrease snaps immediately, so presentation never temporarily overstates Cash after a purchase or correction.
3. A small positive gain counts every whole dollar.
4. A large positive gain uses a bounded number of steps rather than one task/update per dollar.
5. A newer authoritative target increments a generation token. The old animation exits on its next bounded wake and the new animation retargets from the currently displayed value.
6. Displayed positive progress never exceeds the current authoritative target.
7. No recurring loop runs while the Cash display is idle.
8. Formatting is presentation-only and does not feed affordability, purchases, saves, rewards, or telemetry.

With defaults, `$10,010 -> $10,016` renders `$10,011`, `$10,012`, `$10,013`, `$10,014`, `$10,015`, and `$10,016` over about `0.4` seconds. The next normal authoritative drive update arrives no faster than the effective `0.5`-second server clamp.

## Designer configuration

Attributes are placed on `ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme` with matching `Descriptions` StringValues.

| Attribute | Default | Runtime bound / meaning |
|---|---:|---|
| `CashCountAnimationEnabled` | `true` | Presentation master switch |
| `CashCountDurationSeconds` | `0.4` | Clamped to `0.15-0.75` seconds |
| `CashCountEveryDollarLimit` | `12` | Clamped to `1-24`; gains within the limit show every dollar |
| `CashCountLargeIncreaseMaximumSteps` | `20` | Clamped to `4-60`; bounds large reward work |
| `FreeRoamCashUseFullFormatting` | `true` | `$10,000,000`; false restores compact free-roam formatting |

Configuration is read when a new target arrives; restarting Play remains the clean verification path after tuning.

## Performance budget

- Normal drive gain of `$5-$8`: at most 5-8 local text updates over about 0.4 seconds.
- Large reward: at most 20 updates by default.
- One bounded generation-owned task per active free-roam presenter; stale tasks exit after their next delay.
- No per-frame callback, server call, profile request, remote, save, Workspace scan, or idle polling.
- Desktop and mobile retain their existing device gates and existing label geometry.

## Installer and expected output

Run the complete contents of:

```text
scripts/roblox_freeroam_cash_smoothing_v1.lua
```

in the Edit-mode Studio Command Bar with `MODE="INSTALL"`.

Expected:

```text
[NTR Free-Roam Cash Smoothing V1] AUDIT PASS authority=leaderstats.Cash surfaces=Desktop+Mobile duration=0.40s everyDollarLimit=12 maximumSteps=20 fullFormatting=true noRemotes=true warnings=0
[NTR Free-Roam Cash Smoothing V1] INSTALL PASS. Restart Play and verify free-roam counting, full formatting, purchases, device layouts, and lifecycle cleanup.
```

The installer preflights exact source anchors, compiles all three projected sources before mutation, performs a committed-state audit, is idempotent, and restores the run snapshot on failure. It creates no in-game backup folder/script.

## Verification matrix

The user confirmation closes installation and ordinary presentation acceptance. Keep the detailed checks below as the release-regression matrix rather than treating unchecked rows as a pending handoff blocker.

### Authoritative and normal drive

- [ ] Initial join balance appears immediately with no count-up from zero.
- [ ] A normal `$5-$8` drive grant shows every intermediate whole dollar.
- [ ] Counting finishes before the next normal `0.5`-second authoritative update.
- [ ] Rapid subsequent targets cancel/retarget without falling permanently behind or creating a queue.
- [ ] `leaderstats.Cash` changes only at the server cadence; smoothing does not change its value.

### Formatting and responsive layout

- [ ] Desktop shows `$10,000,000`, not `$10.0M`.
- [ ] Mobile shows `$10,000,000`, not `$10.0M`.
- [ ] `$999`, `$1,000`, `$999,999`, `$1,000,000`, `$10,000,000`, and `$2,000,000,000` remain readable.
- [ ] Desktop Cash panel and Cash modal balance chip remain readable.
- [ ] Phone portrait, phone landscape, tablet, 16:9 desktop and ultrawide do not clip or overlap the `+` button.

### Corrections, rewards, and lifecycle

- [ ] A purchase/decrease snaps immediately to the lower authoritative value.
- [ ] A large Studio/Race reward completes in at most the configured maximum steps and lands exactly on the real value.
- [ ] Opening/closing the Cash modal during animation shows the same displayed value.
- [ ] Character respawn and free-roam UI recreation snap/rebind without duplicate counters.
- [ ] Garage entry/exit, Race, Time Trial, reset, teleport and rejoin do not leave an orphan animation.
- [ ] Garage affordability, purchase rejection and server Cash remain correct while a free-roam label is counting.

### Performance and regression

- [ ] Output contains no error/warning loop.
- [ ] MicroProfiler/low-end mobile smoke shows no material UI cost.
- [ ] No new RemoteEvent/RemoteFunction, profile request, save call or repeating idle task exists.
- [ ] Drive-To-Earn telemetry, grant cadence, cap usage and save/rejoin remain unchanged.

## Risks and rollback

- The free-roam label may be briefly behind the authoritative balance while counting upward. It never exceeds that balance, and logic never reads the displayed number.
- At extremely low frame rates some intermediate text assignments may not be visually painted even though the bounded presenter issues them in order. The final value remains exact.
- Very large positive rewards intentionally skip integers to keep work bounded.
- Full grouped balances are wider than compact money. Existing TextScaled/constraints should fit, but the listed device and `$2B` checks are required.
- The installer uses exact source anchors. If preflight stops, refresh/inspect the live mirror and repair this installer rather than creating a patch ladder.

For exact feature rollback, set `MODE="ROLLBACK"` in the same installer. It removes the shared presenter and free-roam hooks/config. Authoritative or saved Cash is never changed.

## Mirror status

The complete `2026-07-27 11:26:30` mirror contains 191 mutually matching exported-script, source-manifest and checksum entries with zero path/checksum mismatches. It contains:

- `NTR_FREEROAM_CASH_PRESENTER_V1` in `ResponsiveUIFoundation`;
- `NTR_FREEROAM_CASH_SMOOTHING_DESKTOP_V1` and `NTR_FREEROAM_CASH_SMOOTHING_MOBILE_V1`;
- `FreeRoamCashPresentationRevision=NTR_FREEROAM_CASH_SMOOTHING_V1` on all three owners;
- `CashCountAnimationEnabled=true`;
- `CashCountDurationSeconds=0.4`;
- `CashCountEveryDollarLimit=12`;
- `CashCountLargeIncreaseMaximumSteps=20`;
- `FreeRoamCashUseFullFormatting=true`.

Neither mirror area appears stale. No Studio command or mirror refresh is pending for ordinary use. Leave `docs/studio-full-export-paste.txt` unstaged.
