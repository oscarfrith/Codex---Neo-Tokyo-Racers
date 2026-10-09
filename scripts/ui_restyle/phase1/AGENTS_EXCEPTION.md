# AGENTS.md exception text (Pulse Phase 1)

Source: `CONTRACT.md` section 11, copied exactly. Paste the block below into `AGENTS.md` under "Durable rules" as one bullet (the integrator's repo edit; this file changes nothing by itself). The line breaks are the contract's; they may be joined into one line when pasted, as the other bullets are.

```text
- Pulse UI backup exception (owner: Oscar; ends at Pulse Phase 10). Two UI sets are installed. One value,
ReplicatedStorage.Config.UI@UIStyle, read once per session by ReplicatedFirst.UIStyleSwitch (a Config
attribute, not Core.FeatureFlags), chooses Classic or Pulse; each surface has exactly one running owner
and Pulse owners live under ReplicatedStorage.Modules.Game.UIPulse. Classic UI scripts are frozen and
hash-checked (scripts/ui_restyle/classic). A delivery that must change one, or a payload or config value
Classic reads, runs the Classic verify and a Classic smoke check and lands in both sets. Review at the
default flip (Phase 9) and at each such delivery. Contract: scripts/ui_restyle/CONTRACT.md.
```
