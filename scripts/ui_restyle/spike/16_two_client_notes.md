# Spike 16 notes: can the Studio MCP tools drive a two-client local test?

Not run (this agent does not touch Studio). Read from the MCP tool schemas and the project setup doc.

## Expected answer: no, not on their own

- `start_stop_play` takes only `is_start` and `studio_id`. It has no mode argument, so it starts the ordinary solo
  Play (one server and one client datamodel inside the same Studio window). It cannot start "Test > Clients and
  Servers" (a local server with N players), which is a Studio ribbon action.
- `execute_luau` selects a datamodel with `datamodel_type = Edit | Client | Server` inside one `studio_id`. In solo
  Play there is exactly one Client. There is no argument to choose "client 2".
- A local server test opens **separate Studio windows**: one server and one per player. Whether those windows
  register with the MCP proxy as extra entries in `list_roblox_studios` is the open point. If they do, each has its
  own `studio_id` and `execute_luau` / the capture tool could be aimed at each client. If they do not, the tools see
  only the original Edit window.
- Local-server players are `Player1`, `Player2` with negative user ids. `PersonalBestServer` skips the DataStore
  for a non-production UserId (245 to 251) and `ProfileServer` 252 sets `noSave` when the DataStore is off or the
  sandbox attribute is on, so such a session should not touch Oscar's profile, but the sandbox window rule in plan
  section 10 still applies.

## What the integrator should check (five minutes, needs Oscar to press one Studio button)

1. Edit mode: `list_roblox_studios`, note the ids and names.
2. Oscar starts Test > Clients and Servers with 2 players (the tools cannot).
3. `list_roblox_studios` again. Record: how many entries, their names, whether new ids appeared.
4. For each new id: `get_studio_state` (which datamodel types it offers), then a one-line
   `execute_luau` on `Client` returning `game:GetService("Players").LocalPlayer.Name`.
5. If two different player names come back, run `11a_prompt_census.lua` on each client as a real probe and take one
   capture of each.
6. Oscar stops the test from the server window. `list_roblox_studios` once more; never reuse the temporary ids.

## What each result selects (plan section 10)

| Result | Method |
|---|---|
| Both client windows are listed and accept `execute_luau` | Two-client checks (passenger RIDE prompt, other-player map dots, duel offer, queue with a second racer) are agent-run, with Oscar starting and stopping the test. Record the start procedure in docs/architecture/claude-code-setup.md |
| Only one window, or none of the new ones, is reachable | **Fallback, already chosen:** fixture replay in the gallery for every two-player state, plus Oscar's confirmation run with a second account. No agent-driven two-client test |
| Windows are listed but captures or input do not work on them | Data probes on both clients, captures by Oscar |

Either way nothing in Phases 1 to 3 depends on this. The first two-player surface is the activity HUD and the
passenger prompt (Phases 3 and 4).
