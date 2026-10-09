Both documents follow. Nothing was written to the repo or Studio. Points the integrator and reviewer should check before saving, because they are my decisions and not stated in the programme contract:

- **Latch require in ClientBase uses `FindFirstChild`, not `WaitForChild`**, so a missing latch gives Classic with one warning instead of hanging start-up in both styles. The `Routes` require keeps unbounded `WaitForChild` (programme 0, "missing-module safety net").
- **`Compose(entries, switch)` takes the latch as its second argument** and calls `switch.Commit` last. `Downgrade` is allowed until the first `Claim` (equivalent to "before lifecycle.start", needs no extra ClientBase line).
- **`UIStyleDevFamilies` format**: comma-separated family names that must be a prefix of `Routes.Families`. An invalid value makes `Compose` error, which is also the forced-failure test.
- **Regular scale floor must be exactly 16/24**, not 0.667, or the snap drops 1280x720 to 15/24. Compact uses steps of 1/20 and clamps 0.85 to 1.10 (from `previews/compact/TYPE_ROLES.md`).
- **`Config.UI.Pulse.Assets` is a second new folder** (programme 6 and the manifest's `config_key` name it; 1.6 says "one new folder").
- **Classic timing change**: ClientBase now waits for `Config.UI` (through the latch) before `lifecycle.start`. Today it waits only for `Config.Development`.
- **Toast ordering constraint found in source**: `DesktopFreeRoamHudUI` 100 and `MobileFreeRoamHudUI` 38 `WaitForChild("ShowTopNotification")` unbounded at module load with no declared dependency, so the Pulse owner must create the bindable before any yield.
- **Toast text**: I kept Classic's `string.upper` and its duration clamp; `TopNotificationMaxCards` is absent from the config record, so the token is 3.
- **"Button heights 64/88"**: the sheet says 64 replaced 88. I kept 88 as `SpaceButtonHeightLarge`, reserved and unused in Phase 1.
- **No "review 3" or "baked gradient" text exists in the style sheet**; the main button uses a `UIGradient` and no asset key was invented.
- **`PlayerScripts.Runtime.UI`** is Studio-authored (no script creates it); AUDIT should confirm it exists.
- **Oscar is needed twice** for save and reopen: once in the create proof, once after the main APPLY.
