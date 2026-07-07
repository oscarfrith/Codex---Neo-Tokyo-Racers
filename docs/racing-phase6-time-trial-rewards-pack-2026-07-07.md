# Racing Phase 6 - Time Trial Rewards Pack

**Script:** `scripts/roblox_racing_phase6_time_trial_rewards_pack.lua`  
**Status:** Installed/tested by the user; superseded for balancing by Phase 6B  
**Depends on:** Racing Phase 4 results flow and Phase 5/5F route guide stability

Phase 6B now supersedes the reward config layout below. Use `docs/racing-phase6b-global-reward-config-rounding-2026-07-07.md` for the current preferred balancing model: `Config.Racing.Rewards.TimeTrial`, `Config.Racing.Rewards.Race`, and `$250` prize rounding.

## What It Adds

- Installs `ServerScriptService.NeoTokyoRacers.Services.Racing.RaceRewardService_Active`.
- Creates `Config.Racing.Rewards` tuning attributes.
- Adds a tiny server-only garage cash bridge under `GarageProfileMutationBindings.GrantCash`.
- Patches `TimeTrialService_Active` so each finished run asks the reward service for a payout once.
- Patches the Phase 4 result panel to show the reward amount or reward message.
- Keeps `Config.Racing.RouteGuide` untouched, so Phase 5F pill-label tuning is preserved.

## Original Phase 6 Reward Config

The first Phase 6 script created these editable attributes directly under:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards
```

Useful values:

```text
EnableCashRewards = true
BaseRewardDefault = 500
FinishedRewardMultiplier = 0
BronzeRewardMultiplier = 0.55
SilverRewardMultiplier = 0.75
GoldRewardMultiplier = 1.0
PlatinumRewardMultiplier = 1.3
RepeatRewardMultiplier = 0.35
MedalUpgradeRewardMultiplier = 1.0
FirstPlatinumBonus = 250
MinReward = 0
MaxReward = 10000
TierMultiplier_E = 1.0
TierMultiplier_D = 1.15
TierMultiplier_C = 1.35
TierMultiplier_B = 1.6
TierMultiplier_A = 1.9
TierMultiplier_S = 2.25
```

Per-event `BaseReward` on the time-trial catalog still wins over `BaseRewardDefault`.

Current preferred balancing after Phase 6B:

```text
Config.Racing.Rewards.TimeTrial
Config.Racing.Rewards.Race
```

Event folders should keep `BaseReward` only for reward balancing. Medal, tier, placement, and repeat multipliers should be global.

## Anti-Double-Claim Rules

`RaceRewardService_Active` keeps a server-side claimed-run ledger keyed by `RunId`, so repeated finish touches or duplicate finish payloads should not pay twice for the same run.

The garage cash bridge updates the same legacy garage profile cash that shop/customisation actions use, refreshes `leaderstats.Cash`, then mirrors that profile through the existing persistence bridge. The reward service records racing best data afterward so the garage mirror does not wipe the racing metadata.

## Verification

1. Run `scripts/roblox_racing_phase6_time_trial_rewards_pack.lua` in Studio Edit mode.
2. Restart Play.
3. Start a time trial and finish it.
4. Confirm the results panel shows a reward line.
5. Confirm `leaderstats.Cash` increases by the expected amount.
6. Retry the same event and finish again; repeat rewards should use `RepeatRewardMultiplier` unless the medal improves.
7. Confirm the Phase 5F checkpoint pill attributes under `Config.Racing.RouteGuide` did not change.

## Rollback

Disable/delete:

```text
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceRewardService_Active
```

Then rerun Phase 4 if you want to remove the finish-payload reward call/result-panel line. The garage bridge is inert without the racing reward service calling it.

For a no-cash test without removing scripts, set:

```text
Config.Racing.Rewards.EnableCashRewards = false
```
