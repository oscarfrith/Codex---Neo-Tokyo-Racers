---
description: Take a targeted Studio capture (sources, config, vehicles or custom roots)
argument-hint: <capture-name> [preset sources|config|vehicles | roots JSON]
---
Take a targeted capture following docs/architecture/targeted-capture-workflow.md.
Arguments: $ARGUMENTS

1. Confirm Space Racers v2 (71491191583884) and Edit mode via MCP.
2. Discover local Python. Start the receiver in the background: `py scripts/studio_capture.py receive --name <name> --preset <preset>` (or --roots / --properties).
3. When it prints Ready, run via execute_luau in Edit: `return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/script"))()`
4. Verify: `py scripts/studio_capture.py verify roblox/captures/<name>/capture.json`. If a matching before-capture exists, run compare and summarise deltas.
Report timestamp, source count, roots, and any errors. No game mutations. Never write or commit the raw paste blob.
