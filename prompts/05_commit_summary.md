# Commit Summary Prompt

Use this when GitHub Desktop shows changed files and you want a clean commit title/description.

```text
Please inspect the current Git changes for Neo Tokyo Racers and give me a precise GitHub Desktop commit title and description.

Active repo path:
H:\My Drive\Roblox\Neo Tokyo Racers\Codex - Neo Tokyo Racers

GitHub repo:
https://github.com/oscarfrith/Codex---Neo-Tokyo-Racers

Please:

1. Check Git status and diff summary.
2. Read changed docs/scripts/mirror files enough to understand the actual scope.
3. If `roblox/exported_scripts/` or `roblox/studio_snapshot/` changed, verify:
   - `roblox/exported_scripts/MANIFEST.md` script count,
   - `roblox/studio_snapshot/hierarchy.md` Studio timestamp,
   - `roblox/studio_snapshot/checksums.json` count,
   - current paths such as `NeoTokyoRacersClient` are present,
   - removed old paths such as `ReplicatedStorage.HOVER_RACING_V2_KIT` are absent unless intentionally still in Studio.
4. Warn me if unrelated work is mixed into the same commit.
5. Suggest whether it should be one commit or split into smaller commits.
6. Remind me not to commit `docs/studio-full-export-paste.txt`.
7. Give me:
   - one concise commit title,
   - one commit description in bullet points,
   - any final checks I should run before pushing.

GitHub Desktop screenshot or context:
[PASTE IF USEFUL]
```
