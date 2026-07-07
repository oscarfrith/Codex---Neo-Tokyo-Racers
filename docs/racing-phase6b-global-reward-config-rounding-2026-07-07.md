# Racing Phase 6B - Global Reward Config And Rounding

**Script:** `scripts/roblox_racing_phase6b_global_reward_config_rounding.lua`  
**Status:** Generated after Phase 6 was reported working well  
**Depends on:** Racing Phase 6 cash reward bridge

## What It Changes

- Replaces the isolated `RaceRewardService_Active` with a Phase 6B version.
- Rounds time-trial cash prizes to the nearest configured amount, default `$250`.
- Moves all reward multipliers into two global folders:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards.TimeTrial
ReplicatedStorage.NeoTokyoRacers.Config.Racing.Rewards.Race
```

- Keeps each event/track responsible for its own `BaseReward`.
- Removes old per-track multiplier attributes from `TimeTrialCatalog` and `RaceCatalog`.
- Does not touch `Config.Racing.RouteGuide`.

## Time Trial Config

```text
Config.Racing.Rewards.TimeTrial
  EnableCashRewards = true
  BaseRewardDefault = 500
  RewardRoundToNearest = 250
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

Formula:

```text
rounded reward = nearest $250 of (event BaseReward * medal multiplier * vehicle tier multiplier)
```

Repeat runs use `RepeatRewardMultiplier` unless the medal improves. First platinum adds `FirstPlatinumBonus` before rounding.

## Race Config

```text
Config.Racing.Rewards.Race
  EnableCashRewards = true
  BaseRewardDefault = 750
  RewardRoundToNearest = 250
  GoldPlaceMax = 1
  SilverPlaceMax = 2
  BronzePlaceMax = 3
  GoldRewardMultiplier = 1.0
  SilverRewardMultiplier = 0.85
  BronzeRewardMultiplier = 0.65
  DNFRewardMultiplier = 0
  MinReward = 0
  MaxReward = 10000
```

Race payout calculation is prepared for the future multiplayer phase but Phase 6B only changes the live time-trial reward grant path.

## Track/Event Config

Events should keep only track-specific balancing values, especially:

```text
BaseReward = 500
```

Do not put medal, placement, repeat, or tier reward multipliers on individual event folders. Phase 6B removes old copies of those attributes from the existing catalogs.

## Verification

1. Run `scripts/roblox_racing_phase6b_global_reward_config_rounding.lua` in Studio Edit mode.
2. Restart Play.
3. Finish a time trial.
4. Confirm the result-panel prize is rounded to the nearest `$250`.
5. Confirm `leaderstats.Cash` increases by that rounded amount.
6. Confirm event folders still have `BaseReward`, but no old `RewardTierMultiplier_*`, medal multiplier, placement multiplier, or repeat multiplier attributes.
7. Confirm `Config.Racing.RouteGuide` and Phase 5F checkpoint pill attributes are unchanged.

## Rollback

Rerun `scripts/roblox_racing_phase6_time_trial_rewards_pack.lua` to restore the first Phase 6 reward service and flat `Config.Racing.Rewards` attributes. Then rerun Phase 6B again if you want the global folder model back.
