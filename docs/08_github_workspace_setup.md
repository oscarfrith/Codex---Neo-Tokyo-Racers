# GitHub Workspace Setup

This project is now arranged so GitHub can act as the long-term memory for ChatGPT/Codex.

## Recommended Repo

Use the private GitHub repository you created for this project:

```text
Neo Tokyo Racers
```

If GitHub uses a URL-friendly slug, it may appear as `neo-tokyo-racers`. Keep it private unless you are comfortable sharing your scripts, game structure, and design notes.

## Easiest Way To Publish

Use GitHub Desktop.

1. Install GitHub Desktop from GitHub.
2. Sign in with your GitHub account.
3. Choose `File > Add local repository`.
4. Select this folder:

```text
C:\Users\Oscar\Documents\Codex\2026-05-02\im-working-on-a-roblox-game
```

5. If GitHub Desktop says this is not a repository, choose `create a repository`.
6. Commit the initial files.
7. Click `Publish repository`.
8. Keep it private.

## What Should Be Tracked

Track these:

```text
AGENTS.md
README.md
docs/
scripts/
diagrams/
.gitignore
.gitattributes
```

The root contains many old command-bar patch scripts. `.gitignore` ignores those by default so the GitHub repo stays clean. The current important scripts are already copied into `/scripts`.

If you later want a full historical archive, create:

```text
archive/patch_scripts/
```

Then move/copy old root patch scripts there intentionally.

## How ChatGPT Should Use The Repo

After connecting GitHub to ChatGPT, use this in new chats:

```text
Use my Neo Tokyo Racers GitHub repo.
Read AGENTS.md and docs/00_START_HERE.md first.
Treat docs/ as the source of truth.
Before making changes, check docs/06_current_known_issues.md.
After changes, update the relevant docs and docs/07_patch_history.md.
```

## Normal Update Workflow

For every stable game change:

1. Add the new command-bar script to `/scripts`.
2. Update the relevant doc:
   - Driving: `docs/03_driving_mechanics.md`
   - UI: `docs/04_customisation_ui.md`
   - VFX: `docs/05_vfx_system.md`
   - Assets/folders: `docs/02_vehicle_folder_system.md`
3. Update `docs/06_current_known_issues.md`.
4. Update `docs/07_patch_history.md`.
5. Commit with a clear message.

Example commit messages:

```text
docs: add project handoff context
driving: add v75 boost delay and hover wobble
docs: mark v75 as confirmed stable
vfx: update engine boost stabiliser effect notes
```

## Stable Baseline Rule

Only mark a patch as stable after it has been play-tested in Roblox Studio.

Use wording like:

```text
Current confirmed stable baseline: V74
Latest generated patch: V75, needs play-test confirmation
```

This prevents future chats from assuming an untested script is safe.
