---
description: follow - implement an approved change with proportional safeguards
argument-hint: <approved change>
---
follow: $ARGUMENTS

Implement within the requested scope using docs/13 and docs/architecture/proportional-mcp-delivery.md.
1. Orient (/start steps 1-3 if not already done this session). Pick the lane and state it.
2. For Standard/High-Risk, state the acceptance contract and the owners of state, geometry, visibility, preview, attachment and persistence before writing anything.
3. Take the targeted before-capture that covers the affected scope.
4. Build the delivery (studio_delivery.py for source bodies/primitive attributes; one canonical installer otherwise). Show the exact diff and config values. Run AUDIT via execute_luau.
5. High-Risk: run the delivery-reviewer subagent on the spec, diff and contract; address its findings.
6. APPLY only within the approved scope. Take the after-capture, compare, and investigate every out-of-scope delta.
7. Run the focused checks. Label evidence honestly: generated / installed / agent-verified / user-confirmed.
8. Update only the documents whose responsibilities changed (docs/13 section 6) and add one 07_patch_history entry. Do not commit unless asked.
