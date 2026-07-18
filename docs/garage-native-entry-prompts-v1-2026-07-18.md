# Garage native entry prompts V1

Status: installer generated; awaiting Studio Play verification.

Installer: `scripts/roblox_ui_garage_native_entrance_prompts_installer.lua`

## Root cause

The canonical entrance controller created a real `ProximityPrompt`, set it to `Custom`, and then displayed a separate `BillboardGui`. Keyboard E still reached the hidden prompt, but the billboard itself was not an interactive control. Touch players therefore saw TAP text without a tappable prompt.

## Canonical fix

- Replaces only the isolated `GarageEntranceController_Active` source.
- Uses Roblox's default `ProximityPrompt`, matching the existing vehicle entry presentation.
- Uses `Enter` for the action and `Dealership` / `Customisation` for the object label.
- Uses E on keyboard, X on gamepad, and `ClickablePrompt = true` for touch.
- Keeps the existing authoritative `GarageSessionRequest` begin/end flow and bindable-event UI handoff.
- Hides all entrance prompts while a garage session is active.
- Shows the drive-in prompt only while the player is seated in their own vehicle.
- Retains a small themed message only for errors; the old non-interactive entrance billboard is removed.

## Verification

1. Run the installer once from the Studio Edit Command Bar and restart Play.
2. On PC, approach the Dealership and Customisation entrance triggers and confirm the native E prompt opens each menu.
3. In Device Emulator touch mode, approach both triggers and confirm the hand/tap prompt opens each menu.
4. Confirm the prompt disappears while a garage menu is open and returns after exiting.
5. Drive an owned vehicle into the drive-in bay and confirm the same native prompt appears; confirm it does not appear there while on foot.
