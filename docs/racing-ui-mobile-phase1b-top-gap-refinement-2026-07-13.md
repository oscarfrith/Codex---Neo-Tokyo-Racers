# Mobile Racing UI Phase 1B - Top Gap Refinement

Date: 2026-07-13

Phase 1 was installed and user-confirmed working across the scaled Race Browser, Entry submenus, prize/records/vehicle pages, and unified Results. The only requested refinement is a smaller gap beneath Roblox's built-in top controls.

Run this entire file in the Roblox Studio Command Bar in Edit mode:

```text
scripts/roblox_racing_ui_mobile_phase1b_top_gap_refinement.lua
```

It changes only:

```text
ReplicatedStorage.NeoTokyoRacers.Config.UI.Racing.MobileScaledDesktop.SafeTop
84 -> 72
```

The shared layout module already watches this attribute, so emulator resizing remains responsive. Restart Play after running the script to verify from a clean client.

Check Race Browser and one Entry page on a short and standard landscape viewport. The shell should sit close beneath the Roblox buttons with a small visible gap and no overlap. Footer containment, menu scale, PC layout, gameplay, rewards, results data, and in-race HUD must remain unchanged.

Rollback is config-only: set `SafeTop` back to `84` and restart Play. Refresh the Studio mirror after confirmation because this changes a live config attribute.
