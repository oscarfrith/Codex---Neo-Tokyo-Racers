# PC Free-Roam UI Phase 2I Borderless Boost Icon

Date: 2026-07-10  
Status: Installed and approved; current pre-minimap HUD baseline

Run in Edit mode:

`scripts/roblox_ui_freeroam_pc_phase2i_borderless_boost_icon.lua`

Phase 2I preserves Phase 2H positioning and configuration but removes the icon container's fill, rounded panel, border, glow, and inner padding. The configured image fills the complete icon area, so the visible image is 32px by default—larger than the 24px boost bar.

Set the image at:

`ReplicatedStorage.NeoTokyoRacers.Config.UI.DesktopFreeRoamHud.Assets.BoostIcon`

Size and spacing remain editable through `Layout.BoostIconSize` and `Layout.BoostIconGap`.

Verify that only the image appears beside the bar, no square/frame/glow is visible, and live drain/recharge still works. Roll back by rerunning `scripts/roblox_ui_freeroam_pc_phase2h_configurable_boost_icon.lua`.

Refresh the Studio mirror after acceptance.
