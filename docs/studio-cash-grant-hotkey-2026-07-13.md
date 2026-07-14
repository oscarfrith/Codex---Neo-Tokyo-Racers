# Studio Cash Grant Hotkey

Date: 2026-07-13

Status: generated; awaiting Studio install and verification.

## Purpose

This is a development-only economy testing helper. Pressing `=` during a Studio Play session grants the `LucidityStudios` player `$100,000` through the existing server-authoritative garage cash bridge.

It is hard-disabled when `RunService:IsStudio()` is false, so firing its remote in a published server cannot grant cash.

## Installer

Run in Studio Edit mode:

`scripts/roblox_studio_cash_grant_hotkey.lua`

The installer creates only isolated config, remote, server, and client objects. It performs no source replacement and does not touch the main client bootstrap.

## Config

Edit attributes under:

`ReplicatedStorage.NeoTokyoRacers.Config.Runtime.StudioCashGrant`

- `Enabled`: enables the helper in Studio.
- `Amount`: cash per key press; defaults to `100000`.
- `KeyCode`: Roblox `Enum.KeyCode` name; defaults to `Equals` (`=`).
- `AllowedUserName`: defaults to `LucidityStudios`.
- `CooldownSeconds`: server rate limit; defaults to `0.5`.
- `StudioOnly`: must remain true. A second hard-coded server guard also blocks non-Studio grants.

## Verification

1. Restart Play after installation.
2. Wait for the player profile and garage service to load.
3. Press `=` while no text box is focused.
4. Confirm a `TEST CASH ADDED` notification appears.
5. Confirm cash and leaderstats increase by exactly `$100,000`.
6. Confirm Output prints the player name, grant amount, and resulting balance.

If the bridge has not started yet, the notification asks you to try again shortly.

## Removal

Disable it without deleting anything by setting `Enabled = false`. For complete removal, delete only:

- `Config.Runtime.StudioCashGrant`
- `Shared.Remotes.Debug.StudioCashGrantRequest`
- `ServerScriptService.NeoTokyoRacers.Services.Debug.StudioCashGrantService_Active`
- `StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Debug.StudioCashGrantClient_Active`

