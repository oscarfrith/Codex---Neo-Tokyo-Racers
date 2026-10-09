# UI restyle measurement probes

Phase 0 probes for the Pulse UI restyle (plan sections 1.8, 5.2, 5.3 and 10). The integrator runs them in Studio through the MCP `execute_luau` tool: paste one file's text as the code, pick the datamodel in the table, and save the returned JSON.

**Status: written and desk-checked, not yet run in Studio.** No offline Luau is available, so syntax was checked by reading and by a block and bracket balance script. Treat the first run of each probe as its test.

## How to use

- Edit only the `local ARGS = { ... }` table at the top of a file before sending it.
- Every probe returns one JSON string. `ok = false` with an `error` field means it refused or found nothing to measure.
- Replies are kept under about 20 kB. `detail = true` returns longer lists.
- Client probes read `Players.LocalPlayer.PlayerGui`. Paste them inline: the client cannot fetch files.
- Check rendering first. If `perf_sample.lua` reports `render.frames = 0`, the Studio window is minimised or covered; tweens and frame counts are void until it is in front.
- Measure Classic and Pulse in separate Play sessions.

## Probes

All are read-only except `sandbox_window.lua`. None requires a module, fires a remote or creates an instance.

| Probe | Datamodel | Main ARGS | Returns | Cost |
|---|---|---|---|---|
| `instance_census.lua` | Client | `guis`, `root`, `detail`, `depth` | Per ScreenGui: Enabled, DisplayOrder, descendant and visible counts, counts by class, strokes, gradients, corners, CanvasGroups, shadow-like (name contains "shadow" or "glow"), distinct TextSize values and fonts of visible text; totals. `detail` adds subtree counts. | One walk; instant |
| `churn_start.lua` / `churn_stop.lua` | Client | start: `guis`, `force`; stop: `detail`, `top` | DescendantAdded and DescendantRemoving per ScreenGui between the two calls, ScreenGuis created or removed, top 15 instances by root, class and name, per second and per frame. | 2 connections per root |
| `churn_probe.lua` | Client | `seconds` (≤ 25), `guis` | Same as the pair, in one blocking call. | Blocks for `seconds` |
| `write_start.lua` / `write_stop.lua` | Client | start: `guis`, `maxInstances` (6000), `followNew`; stop: `top`, `detail` | Property changes per root, per class, per property, top 15 instance paths with their properties; per second; per frame mean, median, 95th percentile and max; truncation. | 1 `Changed` connection per instance, up to the cap |
| `write_probe.lua` | Client | `seconds` (≤ 25), `guis`, `maxInstances` | Same as the pair, in one blocking call. | Blocks for `seconds` |
| `layout_lint.lua` | Client | `guis`, `detail`, `minTextSize`, `minTarget`, `opaqueThreshold` | Environment (viewport, gui inset, TopbarInset, touch, keyboard, gamepad, PreferredInput, text-size preference), then per ScreenGui: non-integer geometry, small text, TextScaled, TextFits false, small targets, overlapping and close sibling buttons, fractional strokes, full-screen layers, cover percent. Examples per rule. | One walk plus a 64 x 36 grid per ScreenGui |
| `perf_sample.lua` | Client | `seconds` (≤ 20), `warmup`, `detail` | Render and heartbeat frame times: median, 95th, 99th, max, mean fps, frames over 33, 50 and 100 ms. Every `Stats` property that exists (2D UI draw calls and triangles included when the build has them), memory total and by tag. | Blocks for `warmup + seconds` |
| `play_record.lua` | Client | `label`, `run`, `geometry`, `ignore`, `detail` | Per ScreenGui: name, DisplayOrder, Enabled, instance count, `hash`, `visHash`. Also `ClientBase.StartupState`, Player attributes and the distinct console errors and warnings. | One walk; about 1 MB of hashing on a large PlayerGui |
| `play_record_diff.py` | local Python | two files, `--detail`, `--visible-only`, `--json` | Which ScreenGuis, start-up statuses and console messages differ between two records; with `--detail`, the deepest differing instances and candidate ignore names. Exit code 1 when different. | n/a |
| `profile_fingerprint_server.lua` | Server | `userName`, `invokeBindings`, `pbKeys`, `detail` | Cash, Player attributes, the runtime profile marker (vehicle and module counts), persistence and PB config, sandbox state, spawned vehicles, ServerBase start-up state, one `fingerprint` number. Level 2 adds vehicle ids hash, per-section profile hashes and named PBs. | Instant |
| `profile_fingerprint_client.lua` | Client | `label` | The replicated subset: Cash, Player attributes, vehicle ids as the HUD car panel lists them. | Instant |
| `profile_fingerprint_saved.lua` | Edit | `userId`, `detail` | Hashes of the SAVED profile, PB records and desk objective, by three DataStore `GetAsync` reads. Optional; needs Oscar's yes. | 3 DataStore reads |
| `sandbox_window.lua` | Edit | `mode` (`open`, `close`, `status`), `replay`, `note` | Before and after values of the two sandbox attributes and the marker. **Writes attributes.** | Instant |

Documents: `capture_points.md` (the 14 Play record points and their steps) and `SANDBOX_NOTES.md` (what the sandbox protects, with line references).

## Start and stop pairs

`execute_luau` blocks until the script returns, so an interaction cannot be driven while a timed probe waits. The pairs solve that:

1. Send `churn_start.lua` or `write_start.lua`. It connects, stores its counters in `shared.UIRestyleProbe` (also `_G.UIRestyleProbe`) and returns at once.
2. Perform the interaction with the input tools.
3. Send the matching stop file. It disconnects everything and returns the counts.

Churn and write sessions are independent and can run together. A second start refuses with `already_running` unless `force = true`.

**If stop returns `no_session`,** the `shared` table did not persist between calls in this Studio build. Use the blocking `churn_probe.lua` or `write_probe.lua` instead, and start the interaction from the user side.

## Reading the write counts

The write probe listens to `Changed`. Three limits matter when comparing against the plan's budgets:

- **Same-value writes are invisible.** The engine does not fire `Changed` when a property is set to the value it already holds. The count is of effective changes, so it is a lower bound on writes. Classic's "about 14 unconditional writes per frame" will read lower than the source audit if those writes repeat the same value.
- **Derived properties are separate.** `AbsolutePosition`, `AbsoluteSize`, `TextBounds`, `TextFits` and similar are reported as `derived`, not `writes`.
- **Attribute writes and config lookups are not seen.** The "config or attribute lookups per frame" budget cannot be measured from outside; it needs source inspection or `debug.profilebegin` labels in Pulse code.

Pass the static and live layers as separate entries in `ARGS.guis` (dotted paths under PlayerGui) to get one row each. The per-frame median covers all roots together, so run one root at a time when a per-layer median is needed.

## The Play record

1. Follow `capture_points.md`. At each point run `play_record.lua` with `label` set and `run = "a"`; save the reply as `<label>.a.json`.
2. Repeat in a second Play session with `run = "b"`.
3. `py -3 play_record_diff.py <label>.a.json <label>.b.json`
4. For each ScreenGui that differs, take both runs again with `detail = { gui = "<name>", depth = 3, descriptors = true }` and run the diff with `--detail`. Narrow with `detail.root = "A.B"` if rows are truncated.
5. Add the unstable instance names to `ARGS.ignore.names` (Lua patterns), or drop a field with `ARGS.ignore.fields`. Keep one ignore list for the whole programme and store it beside the records: a record is only comparable with another taken with the same `geometry` and `ignore`.

`hash` covers every instance, shown or hidden. `visHash` covers only what is effectively visible, and is the better first signal at a capture point. Same-named siblings are numbered `Name#2`, `Name#3` in child order in detail rows; if child order differs between runs, those rows will show as different.

## Agent test window

1. Edit: `sandbox_window.lua`, `mode = "open"`. Needs Oscar's yes.
2. Play. Server: `profile_fingerprint_server.lua`; confirm `sandboxActive` is true before any purchase.
3. Test. Stop Play.
4. Edit: `sandbox_window.lua`, `mode = "close"`; check `ok` is true and `after` equals `restored`.

Close the window before any installer AUDIT or APPLY, save-and-reopen check, handoff or publish. Installers and the handoff should call `mode = "status"` and refuse while `open` is true.

## Not measurable with these probes

- Same-value property writes, attribute writes and config lookups (see above).
- Script time per frame step; the plan uses `debug.profilebegin` labels and the MicroProfiler.
- Phone frame cost. Studio and the emulator prove layout only.
- Contrast ratios, margin-token equality, reserved and trap names, and the missing-mark check from the plan's `layout_lint` list. These depend on Pulse tokens and kit names that do not exist yet; add them when the kit contract is written.
- Screen coordinates of a GuiObject. `layout_lint.lua` works in each ScreenGui's own space and reports the inset facts instead.
