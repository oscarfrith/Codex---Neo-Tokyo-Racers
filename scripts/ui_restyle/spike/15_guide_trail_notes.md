# Spike 15 notes: guide trail colour for Pulse

Read from source only: `ReplicatedStorage.Modules.Game.UI.OnboardingGuideTrailRenderer` (138 lines) and its one
caller, `OnboardingClient`. Answer first:

**Yes. `GuideTrail.new(config)` with a different config object is enough for a Pulse colour. The renderer needs no
edit.** A second config folder works, but it must carry all 30 trail attributes, not just the colour. A thin
overlay object is the smaller route. Details below.

## What the renderer reads

- `Renderer.new(config)` (64 to 69) stores the argument as `self.Config` and connects one `RenderStepped` (67).
- Every read goes through `config:GetAttribute(name)`: the helpers `number` (7 to 10), `boolean` (11 to 14) and
  `texture` (15 to 23), plus two direct reads of the colour. Nothing else is asked of the object: no `IsA`, no
  children, no `GetAttributeChangedSignal`, no name or path.
- Colour: `self.Config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)` at 76 (build) and **again every
  frame** at 121, then written to the beams (122) and every part arrow (124). So the colour is live and is one
  attribute. Its name stays `TutorialGold` whatever the colour is, and it must be a `Color3`
  (`ColorSequence.new(color)` at 41, 42, 45 and 122).
- Geometry: 30 attributes named `GuideTrail*` (ArrowScale, ArrowWidth, BeamCoreTransparency, BeamCoreWidth,
  BeamEnabled, BeamStartHeightOffset, BeamTransparency, BeamWidth, ChevronBeamEnabled, ChevronBrightness,
  ChevronTexture, ChevronTextureLength, ChevronTextureSpeed, ChevronTransparency, ChevronWidth, ChevronZOffset,
  EndOffset, HeadLength, HeadWidth, HeightOffset, MaximumArrows, MinimumDistance, PartArrowsEnabled, PulseAmplitude,
  PulseSpeed, ShaftEnabled, ShaftLength, Spacing, StartOffset, Transparency). A missing attribute falls back to a
  **code default, not to the Classic value**.

## Who calls it today

`OnboardingClient` 18: `config = ReplicatedStorage.Config.Player.Onboarding`; 22 requires the renderer; 28
`guideTrail = GuideTrail.new(config)` at module load; 657 `updateGuideTrail`, driven from the 0.2 s throttle at 757.
`OnboardingClient` 31 keeps its own `GOLD` from the same attribute for its callouts; that is view colour and is not
shared with the renderer.

`Config.Player.Onboarding` holds 83 attributes, 30 of them the trail set, and the live values differ from the code
defaults in most places (for example `GuideTrailTransparency` 0.5 against default 0.12, `GuideTrailBeamTransparency`
0.9 against 0.58, `GuideTrailMaximumArrows` 30 against 18, `GuideTrailMinimumDistance` 4 against 7,
`GuideTrailStartOffset` 0 against 4, `GuideTrailChevronTexture = "103838921533168"`).

## Two ways to give Pulse its colour

| Route | What | Cost and risk |
|---|---|---|
| **A. Overlay object (recommended)** | The Pulse onboarding owner passes a small table with one method: `GetAttribute(self, name)` returns the Pulse colour for `"TutorialGold"` and otherwise `classicConfig:GetAttribute(name)`. The renderer only ever calls `config:GetAttribute`, so a table satisfies it | No new config. Geometry stays in step with Classic tuning automatically. One closure call per attribute read. Relies on the renderer staying duck-typed; Classic is frozen and hash-checked (plan 1.8), so a change would stop the build |
| B. Second config folder | `Config.UI.Pulse.GuideTrail` (Folder) with `TutorialGold` set to the Pulse colour and **all 30** `GuideTrail*` attributes copied | Works with no code beyond passing the folder. Thirty duplicated values that drift when Classic is tuned. If `GuideTrailChevronTexture` is left out the renderer silently switches to part arrows (43 to 46, 79) |

Either way the colour token itself lives in `Kit.Tokens` / `Config.UI.Pulse` and the plan's Phase 8 line ("guide
trail colour") is met without touching `OnboardingGuideTrailRenderer`, `OnboardingClient` or `Config.Player.Onboarding`.

## Things the Phase 8 contract must carry

1. **One renderer at a time.** `EnsureFolder` (70 to 86) destroys any existing
   `Workspace.ClientOnly.OnboardingGuideTrail` (74) and builds its own. Classic `OnboardingClient` constructs a
   renderer when it is required (28). Under Pulse that entry is re-pathed and never required (plan 1.5 rule 2), so
   only the Pulse owner's renderer exists. Two live renderers would destroy each other's folder on every `SetTarget`.
2. **The chevron texture is tinted, not replaced.** `chevron.Color = ColorSequence.new(color)` (45, 122) multiplies
   the texture `103838921533168`. If that image has gold baked in, a cyan or pink token will come out muddy. This
   cannot be read from source: check it in the Phase 8 gallery capture. Fallback: a white chevron texture id in the
   overlay (`GuideTrailChevronTexture` is just another attribute), which is one more upload in the asset batch.
3. **`boolean()` cannot return false** (13: `type(value)=="boolean" and value or fallback`). A `false` attribute
   yields the fallback. Harmless today because every false value has a false fallback, but an overlay or a Pulse
   folder cannot turn `GuideTrailBeamEnabled`, `GuideTrailChevronBeamEnabled` or `GuideTrailShaftEnabled` off.
   Classic defect, not fixed here.
4. **Per-frame cost belongs to a shared module.** While a target is set, `Update` (98 to 134) makes about 15
   `GetAttribute` calls per frame plus the colour writes at 122 and 124. Plan 5.1 rule 4 binds Pulse code only; this
   is reported as shared-module cost in the Phase 8 `write_probe`, and route A adds one Luau call to each read.
5. `Renderer:Destroy()` (135 to 137) disconnects the `RenderStepped`; the Pulse owner calls it from its scope.
