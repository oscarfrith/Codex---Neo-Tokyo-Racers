# Proportional MCP delivery

One approved task produces one reviewed delivery and one handoff. The assistant handles local tooling, MCP execution, evidence and authorised Git operations. The user tests gameplay when relevant; ordinary supported work needs no manual receiver, copying or Git steps while these connections are available.

## Choose the right route

- Documents: edit and check locally. No Studio export or installer.
- Existing source bodies / primitive attributes: use scripts/studio_delivery.py with the existing targeted capture workflow. Select Fast, Standard or High-Risk by meaning, not file count. Fast needs a task and focused verification; connected work also needs its contract and applicable readiness checks.
- Creation, deletion, renaming, hierarchy moves, physical properties, typed Roblox attributes, saved-data migration or coordinated generated assets: use a dedicated canonical migration. The generic tool does not implement these. Capture enough recovery state, compile/preflight, audit and reverse dependent changes in order.

## Supported delivery

1. Verify target place and Edit mode. Capture current sources plus affected config roots using [targeted capture](targeted-capture-workflow.md). Inspect current owners, dependencies, source and Git differences.
2. Prepare after-source files under the task's scripts directory and one JSON spec. Each operation is either `{"kind":"source","path":["ReplicatedStorage","Modules","..."],"file":"scripts/task/after.lua"}` or `{"kind":"attribute","path":["ReplicatedStorage","Config","..."],"key":"Example","value":true}`. Null removes an attribute. Attribute targets must be present uniquely in the captured hierarchy. Supply `task`, `lane`, `verification`, and `contract` for connected work. These describe review requirements, not an automatic safety certification.
3. Build with `python scripts/studio_delivery.py SPEC CAPTURE scripts/task/delivery.lua --mode AUDIT`. Review the spec, exact before/after source diff and config values. The verified capture owns before-state; Studio remains authoritative. Generated code embeds exact source bytes and does no live text-anchor replacement.
4. Execute the generated AUDIT through MCP. Rebuild the same canonical file with `--mode APPLY` and execute after review within the user's approved scope. All targets must uniquely resolve with expected classes, and all values must collectively match before or after. Compile both source versions before writes. Wrong place/Play, drift or partial installation stops without mutation. Repeated application is a no-op.
5. Capture the same scope afterward, compare, and inspect every source delta outside scope. Confirm expected source/config results and run focused behavioural checks. Installation evidence is not gameplay acceptance. Never automatically overwrite an unrelated delta.
6. Keep spec, source versions through capture blobs, and verification with the task. Commit/push when authorised and report the result. No automatic production publish.

Recovery: regenerate the same delivery using its original verified before capture and unchanged after files with `--mode ROLLBACK`. Review then execute. All operations must still match the installed state; intervening edits block rollback. Ordinary assignment/post-write failures trigger reverse in-memory recovery. An incomplete recovery is an explicit error: inspect/capture before retrying. No game backup instances, fallback owners, hot reload or gameplay module require are introduced.

## Limits and verification

This is an Edit-mode source/config transaction, not a runtime or durable database transaction. Process loss, Studio/plugin callbacks, side effects and semantic dependency changes cannot be undone by restoring only these values. Do not concurrently edit targets. It guards the specified values/classes and paths, not every dependency or all metadata. Include all relevant state in scope and use a dedicated migration when its guarantees are insufficient. The tool deliberately refuses protected roots and Workspace outside World.

Phase 3 verification: 10 Python builder tests, 10 pure-table Luau executor cases inside Studio, and all 21 existing capture tests pass. Coverage includes exact UTF-8/CRLF, scope/path rejection, duplicate/missing records, compile/drift/class/place/mode rejection, repeat, rollback, injected write recovery and intervening-edit refusal. No mock test creates an Instance. Live generated AUDIT of FreeRoamVehicleExitButtonClient returns changed=0; identical before/after values report state=after, which does not mean new code was installed. Before/after source captures show zero changes across all 165 sources. Live mutation recovery remains mock-tested, not proven against arbitrary Studio callbacks. No gameplay regression run is required for this tooling-only delivery.

An initial automatic audit-fixture selection chose a WIP Workspace script; the builder correctly refused it. A subsequent attempted execution lacked a generated file and failed parsing before execution. The corrected supported target passed. Neither attempt changed game objects. Always check a local build/read succeeds before invoking MCP.

Tests: scripts/test_studio_delivery.py and scripts/test_studio_delivery.luau. The latter receives the engine as local `run` and uses pure tables. The frozen audit example is scripts/workflow_phase3/audit.lua, not a gameplay installer. Full mirrors remain historical checkpoints; no full refresh is required here.
