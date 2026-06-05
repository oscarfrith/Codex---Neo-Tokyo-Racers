# Roblox Studio Output Debug Prompt

Use this when you paste Studio Output, errors, audit reports, or command-bar results.

```text
I am pasting Roblox Studio output for Neo Tokyo Racers.

Please:

1. Read the repo context first:
   - `AGENTS.md`
   - `docs/00_START_HERE.md`
   - `docs/06_current_known_issues.md`
   - `docs/07_patch_history.md`
   - any relevant topic docs/scripts for the system involved
2. Classify the output:
   - harmless informational output,
   - expected verification output,
   - warning that should be tracked,
   - real bug/regression,
   - missing context where another probe is needed.
3. Identify the likely root cause using file/script references where possible.
4. Do not write a fix immediately if a read-only probe or source inspection would reduce risk.
5. If a fix is needed, prefer a small guarded command-bar script and explain:
   - what it changes,
   - what it will not touch,
   - how I verify it in Studio.
6. Update the docs if this changes the project baseline or known issues.

Studio output:
[PASTE OUTPUT HERE]
```
