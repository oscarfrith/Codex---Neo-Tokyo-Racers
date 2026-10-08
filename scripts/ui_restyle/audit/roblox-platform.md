# Roblox platform research for the Pulse Racers UI restyle

Date: 2026-10-08. Read-only audit. Sources: create.roblox.com docs, devforum.roblox.com announcements, and read-only probes in Studio (Space Racers v3, Studio 0.742.0.7421053, Edit mode). Probes created only unparented temporary instances and read script `.Source`; nothing in the place was changed.

Legend: [doc] official docs, [ann] DevForum announcement, [staff] staff post or reply, [comm] community post (not authoritative), [probe] measured in Studio v742, [inferred] my reasoning, not stated by a source. "Unconfirmed" means I could not find an authoritative source.

## Headline items that change the plan

1. `TextSize` is clamped to 100, and so is `UITextSizeConstraint.MaxTextSize` [probe]. The sheet's `SpeedNumber` 136 and `HeroNumber` 200 cannot be set as text sizes. They need a `UIScale` on the label (or digit sprites). `GetTextBoundsAsync` also clamps at 100, so measure at 100 or less and multiply.
2. Titillium Web has no ExtraBold and no Heavy Italic [probe, width comparison]. "ExtraBold Italic" silently falls back to Bold Italic. Bold Italic and SemiBold Italic exist.
3. Titillium Web digits are already fixed-width (every digit 37.33 px at size 100, Bold Italic and SemiBold Italic) [probe]. No per-digit labels or `tnum` are needed. Oswald is proportional; Michroma is not quite uniform.
4. `UIShadow` is a released native drop shadow that supports coloured glow, announced fully released 2026-06-23 [ann]. It can replace the three planned glow 9-slice uploads for rectangular elements. It does not work on Path2D and has a jagged-edge issue on large corner radii.
5. `StyleSheet` styling is released, but styles do not apply to properties that code has set away from their defaults [ann]. The current builders set every property explicitly, so StyleSheets are not a sound switch for this code-built UI. Use a Luau token module.
6. Radial and conical `UIGradient` are Studio Beta only (2026-09-02) and could not be published at that date [ann]. They render in Studio Play but may not in a live client. Do not build the gauge on them yet.
7. `CanvasGroup` is already used for the minimap (DesktopFreeRoamHudUI line 929, MobileFreeRoamHudUI line 80) [probe]. A round minimap is the same node with `UICorner` 0.5 scale. It needs `ZIndexBehavior.Sibling`; two owners use `Global`.
8. Any property change under a ScreenGui invalidates that whole ScreenGui's cached appearance [doc][staff]. Per-frame elements (gauge, minimap, timer) should not share a ScreenGui with static chrome.
9. The player's Text Size setting (`GuiService.PreferredTextSize`) changes text in experience UI unless the label is `TextScaled` or capped by a `UITextSizeConstraint` [doc]. Dense fixed panels need a test at Largest.
10. Animating `UIScale` on anything containing text causes flicker; staff ticketed it in Oct 2024 with no fix shown [staff]. The sheet's "pressed 96%" and "selected 10% larger" should snap or scale a text-free layer.

## 1. Scaling strategy, sharpness and hairlines

- Roblox UI units are device-independent. A 2436x1125 phone reports 812x375; text and images are drawn at 3x. "if you make a 1 pixel line, it will be 3 native pixels wide on this device." "The mobile resolution scaling is there specifically so that you can use offset without worrying about high-DPI devices." [staff, quoted in https://devforum.roblox.com/t/specific-details-about-ui-scaling-best-practices/3888004]
- Staff guidance in the same quotes: build content (images, text) at fixed offset sizes and reflow the top level; "Scale sizing is, by far, the easiest way to make a UI that will only work on your own computer."
- Official cross-platform guide: position with Scale and AnchorPoint, then adapt with `GuiService.ViewportDisplaySize` (Small = phones, tablets, handhelds; Medium = laptops, monitors; Large = TVs). No numeric thresholds are published. [doc https://create.roblox.com/docs/en-us/projects/cross-platform] [ann https://devforum.roblox.com/t/full-release-build-cross-platform-ui-with-the-viewportdisplaysize-api/3880384, full release 2025-10-21]
- Text is rasterised at the exact pixel size it will be drawn, per size, into one shared atlas. Many distinct sizes fill the atlas and cause flicker, most often on phones. Tweening `TextSize` is described as potentially game-breaking. [staff https://devforum.roblox.com/t/all-about-text-best-practices/1515743]
- `UIScale` scales the object and everything in it, including UIStroke and UICorner [doc https://create.roblox.com/docs/en-us/ui/size-modifiers]. Whether text above an effective 100 px stays crisp under UIScale is disputed in the community thread and unconfirmed [comm https://devforum.roblox.com/t/allow-textsize-above-100/3959480]. It must be checked with a capture.
- `TextSize` drops fractions (17.6 reads back 17) [probe]. Offsets are integers [comm https://devforum.roblox.com/t/subpixel-accuracy-in-ui-widgets/58995]. Under a fractional UIScale (0.667 at 720p, 1.333 at 1440p) a 2 px hairline becomes 1.33 or 2.67 px. How the engine snaps that is not documented. Community reports describe one-pixel offsets and missing pixels. Unconfirmed; needs a capture test.
- Known UIScale defects: text flicker while the scale animates (open) [staff https://devforum.roblox.com/t/text-flickering-when-animating-ui-scale/3179333]; `AutomaticCanvasSize` wrong under an ancestor UIScale when children use Scale sizes (backlog since 2025-09, still reported 2026-01) [staff https://devforum.roblox.com/t/using-uiscale-on-a-guiobject-containing-a-scrollingframe-breaks-its-automaticcanvassize/3788583].
- Current code [probe]: 24 UIScale lines in 17 scripts. Garage and racing shells use a canonical canvas plus UIScale (`GarageComponents` CanonicalScale, `RacingMobileScaledDesktopLayout`, `RaceSessionPresentationClient`); the free-roam HUD uses a root UIScale with clusters.

Comparison [inferred from the above]:

| Approach | Text | Hairlines and alignment | Cost |
|---|---|---|---|
| One UIScale on a 1920x1080 canvas | Crisp (re-rasterised), but fractional effective sizes | Fractional; uneven risk; letterboxes on ultrawide | Lowest effort; already used in menus |
| Scale-based sizes (UDim scale everywhere) | Needs TextScaled (about 10x layout cost, more atlas sizes) | Stretches with aspect ratio | Discouraged by staff |
| Anchored clusters, each with a UIScale | Crisp; corners stay on screen edges | Same fractional hairline risk inside each cluster | Matches the sheet and the HUD today |
| Anchored clusters, integer-rounded metrics (`px(n) = round(n * scale)`), no UIScale | Integer sizes, small fixed set | Whole logical pixels everywhere; hairline = max(1, round(2 * scale)) | Rebuild on resize; most rewrite |

Hairline options to test: (a) integer-rounded thickness outside any UIScale; (b) a hairline frame with its own inverse UIScale so thickness lands on a whole pixel; (c) one inner UIStroke with a vertical transparency gradient (anti-aliased, but counts against the 300-stroke guidance and the sheet says "not strokes"). All three are [inferred]; none is documented practice.

## 2. Layout

- Flex: `UIListLayout.HorizontalFlex/VerticalFlex`, `ItemLineAlignment`, `UIFlexItem.FlexMode` (None, Grow, Shrink, Fill, Custom). Docs: flex "adds a slight performance cost above non-flex, especially when resizing the layout or dynamically adding/removing flex items." [doc https://create.roblox.com/docs/en-us/ui/list-flex-layouts]. The game uses no flex today [probe: 0 hits].
- `AutomaticSize` costs about one text-bounds calculation; `TextScaled` about ten times that [staff, All About Text]. Docs say avoid TextScaled in favour of AutomaticSize and never use both on one label [doc TextLabel].
- `UISizeConstraint` and `UIAspectRatioConstraint` override a layout's sizing of that object [doc size-modifiers].
- Layout cost: MicroProfiler `UpdateUILayouts/Layout` advice is "Reduce the amount of UI elements being resized or repositioned, such as those managed by UILayout and those tweened". `Rebuild Z-order list` runs on first render or when an element is added, removed or has ZIndex changed: "The more elements a LayerCollector has, the worse it performs"; "avoid frequently changing the parent and ZIndex". [doc https://create.roblox.com/docs/en-us/performance-optimization/microprofiler/tag-table]
- ScrollingFrame: `UICorner` and `UIGradient` do not apply to it [doc UICorner, UIGradient]. It always clips, so a selected tile that grows 10% with a 46 px glow is cut off unless the frame has padding for it or the highlight is drawn outside the frame [inferred]. `ScrollBarThickness = 0` hides bars [doc ScrollingFrame]. Gamepad auto-scroll to the selected child: unconfirmed in the docs I read.
- Rail practice [inferred]: fixed-offset cells in a horizontal `UIListLayout`; scale an inner visual frame, not the layout cell, so neighbours do not reflow; set `CanvasSize` from `AbsoluteContentSize` if AutomaticCanvasSize misbehaves under UIScale.

## 3. Text

- `Font.new(family, weight, style)`; FontWeight enum: Thin, ExtraLight, Light, Regular, Medium, SemiBold, Bold, ExtraBold, Heavy [probe].
- Titillium Web width probe at size 100, "HAMBURGEFONSTIV 0123456789": Normal ExtraLight 972, Light 975, Regular 977, SemiBold 981, Bold 985, ExtraBold 985 (same as Bold), Heavy 979. Italic: Regular 934, SemiBold 936, Bold 935, ExtraBold 935, Heavy 935 (same as Bold). Italic widths differ by only 1 to 2 px, so the italic weight set should be confirmed by eye.
- Digit widths at size 100 [probe]: Titillium Web Bold Italic 37.33 for all ten digits; Roboto Condensed Bold Italic 42.67 for all; Roboto Mono 46; Michroma 67.33 to 70.67; Oswald 26.67 to 37.33.
- `OpenTypeFeatures` accepted "tnum" with no error [probe], but the announcement only names `zero` and `ss03` on Builder Sans [staff https://devforum.roblox.com/t/introducing-opentypefeatures/3065736]. Do not rely on it.
- `RichText` is unused today [probe]. It can mix sizes in one label (number plus unit) but adds parsing.
- Typewriter effects should use `MaxVisibleGraphemes`, not substring writes [staff, All About Text].
- Each text instance costs roughly 2 KB [staff, 2021]. "sizes of 20 or above are readable on all devices"; class docs advise a minimum of 9.
- PreferredTextSize behaviour [doc https://create.roblox.com/docs/en-us/reference/engine/classes/GuiService]: constrained text stays within Min/Max; TextScaled text "will not be scaled by the PreferredTextSize value"; AutomaticSize elements grow; GetTextSize and GetTextBoundsAsync "honor changes related to PreferredTextSize".

## 4. StyleSheet styling

- Status: Client Beta 2025-08-26; the thread carries "[Update] 1/20/2026: Styling is now fully released!" [ann https://devforum.roblox.com/t/client-beta-you-can-now-publish-styles-in-your-experience/3901480]. StyleQuery fully released 2026-05-11 [ann https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519]. Transitions fully released 2026-07-27 [ann https://devforum.roblox.com/t/full-release-styling-transitions/4646870]. All classes instantiate in v742 [probe].
- Model: StyleSheet holds StyleRules; tokens are attributes referenced as `$Name`; themes swap through StyleDerive; StyleLink binds one sheet to a ScreenGui ("Only one StyleSheet can apply to a given tree"). Selectors: class, `.tag`, `#name`, `:state`, `@query`, `>`, `>>`, `::pseudo`. [doc https://create.roblox.com/docs/en-us/ui/styling, StyleRule reference]
- Decisive limit: "StyleRules do not apply to properties changed from their default values" (check with `Instance:IsPropertyModified`) [ann, client beta post]. Invalid property names "silently fail" [doc].
- Performance: setting rule properties and changing tokens is "relatively cheap"; creating or removing rules and changing derives is "slightly more expensive" [ann].
- GuiState has Idle, Hover, Press, NonInteractable only [probe]. There is no gamepad-focus state, so focus styling still needs code.
- Verdict [inferred]: not a sound switch here. The old UI must stay intact and is not style-driven; the new look changes structure (hairline frames, glow, layout), not only property values; per-frame colours and tween targets need Luau values anyway.

## 5. Rendering cost

- ScreenGui cache: appearance "is cached until" a descendant is added or removed, a descendant property changes, or a ScreenGui property changes [doc https://create.roblox.com/docs/en-us/reference/engine/classes/ScreenGui]. "Changing any GuiObject causes the entire LayerCollector's appearance to need recomputing"; split mostly-static and mostly-dynamic UI; avoid frequent writes to non-visual descendants such as NumberValues [staff https://devforum.roblox.com/t/static-ui-performance-improvements/222557].
- Budgets from announcements: under 300 UIStrokes on screen for low-end devices [ann UIStroke]; no more than 100 UIShadows on screen [ann UIShadow]; no more than 1000 gradients, with two-colour or evenly spaced gradients fastest and animating offset or rotation cheaper than colour or transparency [ann Upgraded UI Gradients]. UIGradient docs: no more than 6 colour stops; avoid frequent Color or Transparency changes.
- MicroProfiler: many "Process GuiEffect" labels mean too much `UIGradient` and `UICorner` on text labels. `Perform/Scene/UI`: "Using CanvasGroups can help at the expense of increased memory use." [doc tag table]
- UICorner has a per-pixel overhead; 9-slices are cheaper for many plain rounded rectangles [doc UICorner]. The style is square, so this is minor.
- CanvasGroup: renders descendants to a texture the size of its AbsoluteSize (DPI applied); only flattens under `ZIndexBehavior.Sibling`; "consumes extra texture memory"; quality and memory are capped by QualityLevel; over the cap it "will render as a blank texture"; use static sizes [doc https://create.roblox.com/docs/reference/engine/classes/CanvasGroup.md]. At client quality 3 or lower output may be downscaled and updates throttled [ann https://devforum.roblox.com/t/1797885]. Direct-child modifiers such as UIShadow are not affected by GroupTransparency; wrap content in an inner Frame [comm reply, https://devforum.roblox.com/t/canvasgroup-grouptransparency-does-not-affect-new-uishadow-transparency/4719520].
- Overdraw: overlapping partial transparency is rendered repeatedly [doc https://create.roblox.com/docs/en-us/performance-optimization/improve]. Full-screen tint plus gradients plus 0.86 panels stack several translucent layers on phones.
- Current counts in 145 client-visible scripts [probe]: UIStroke 29 lines, UIGradient 28, UICorner 16, CanvasGroup 8 (5 files), `RenderStepped:Connect` 15, `TweenService:Create` 24, `:Destroy()` 153, `fromRGB(` 273 in 37 files, `ZIndexBehavior.Global` in 2 files.

## 6. Glow, shadow and image resolution

- `UIShadow` [ann https://devforum.roblox.com/t/full-release-new-ui-capabilities-shadows-individual-corners/4636263]: Studio Beta 2026-05-14; 2026-06-23 "fully released and available to publish in your games". "You can set this to any color to create vibrant glow and aura effects." "purely visual - they won't affect your layout". "consistently faster than 9-sliced ImageLabels". Recommended limit 100 on screen. Works on any UI element except Path2D. Known issue: jagged on a large corner radius.
- v742 also exposes `UIShadow.Mode` (Shape, Text), `Inset` and `ShowBehindParent` (default true) [probe]. The `ApplyShadowMode` enum page documents Text mode [doc https://create.roblox.com/docs/en-us/reference/engine/enums/ApplyShadowMode.md], but the class page still says text is unsupported and the release post said native text shadows were not part of that release. Live-client status unconfirmed.
- `UIBlur` exists in v742 (Strength Light/Medium/Heavy, Color, Transparency) [probe] with no docs page (404) and no announcement found. Treat as unreleased.
- Images: "transparent pixels are set to black when uploading", so apply alpha bleeding to avoid dark fringes; `ImageRectOffset/Size` sprite sheets "load much quicker" for many small icons [doc ImageLabel]. Author at about 2x the offset size [staff quote]. GPU memory follows pixel count, not file size; most UI images should be 256 or 512 px [doc improve]. Maximum UI image resolution after upload: unconfirmed (1024 is the long-standing figure; docs now mention 4096 for 3D textures).
- 9-slice: corners unscaled, edges one axis, centre both; `SliceScale` scales the edges [doc https://create.roblox.com/docs/en-us/ui/9-slice]. Whether slice corners follow an ancestor UIScale is unconfirmed.

## 7. Path2D

- Full release 2024-06-17 [ann https://devforum.roblox.com/t/path2d-full-release/3027288]. Properties: Closed, Color3, Thickness (0 to 100 px), Visible, ZIndex. No Transparency property [probe]. A child UIGradient is supported [doc]. No UIShadow support [ann].
- `GetMaxControlPoints()` returns 100 [probe]; docs warn above 50 in `SetControlPoints` and call that update expensive; `GetLength` "can be expensive if called too frequently" [doc https://create.roblox.com/docs/reference/engine/classes/Path2D.md].
- "Path2D does not natively clip with other UI objects"; use a CanvasGroup parent to clip [ann].
- Arcs are possible as cubic Bezier segments (handle length about 0.5523 x radius per 90 degrees) [inferred, standard geometry]. A speed arc that fills needs control-point updates every frame. Per-frame cost, anti-aliasing quality and UIScale behaviour of Thickness: unconfirmed.

## 8. Round minimap

- `ClipsDescendants` does not clip by rounded corners; without `StarterGui.ClipsDescendantsSupportsRotation` it is ignored when the object or an ancestor is rotated [doc GuiObject]. That property exists on StarterGui in v742 but was not readable from script [probe]; status unconfirmed.
- UICorner on an ImageLabel or ViewportFrame rounds that element only: "Input, but not descendants, will be clipped to the round corner area" [doc UICorner].
- So a round window over rotating multi-child content (tiles, markers, route) needs CanvasGroup plus UICorner 0.5. A mask image cannot hide content over a live 3D scene [inferred].
- Cost at 307 px: about 0.4 MB at 1x, about 3.4 MB at 3x DPI [inferred: width x height x 4 bytes]; re-rendered whenever its content changes, which is every frame while driving.
- The four straight edge-fade frames (lines 968 to 975) do not suit a circle; a ring or vignette image is needed until radial gradients reach clients [inferred].

## 9. Gamepad and keyboard navigation

- `GuiService:Select(container)` picks the lowest `SelectionOrder`, ties to top-most then left-most. `SelectionGroup` with `SelectionBehaviorUp/Down/Left/Right` = Escape (default) or Stop. `SelectionChanged` bubbles to ancestors. Dialog pattern: SelectionGroup with Stop in every direction, then Select the dialog. If the selected item is destroyed, re-select the list. [ann https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278]
- `SelectionImageObject` "overrides the default selection adornment"; size it with scale values; `PlayerGui.SelectionImageObject` sets it for all [doc GuiObject].
- `GuiService.AutoSelectGuiEnabled`: Select or Backslash auto-selects a GUI. `GuiNavigationEnabled` toggles default navigation. `SelectedObject` "may reset to nil if the object is off screen". [doc GuiService]
- `UserInputService.PreferredInput` (KeyboardAndMouse, Gamepad, Touch, MicroGamepad in v742) replaces last-input heuristics [ann https://devforum.roblox.com/t/full-release-introducing-preferredinput-and-improved-touch-capabilities/3750890].
- Current code [probe]: SelectedObject only in ResponsiveUIFoundation (confirmation focus); no SelectionGroup, no SelectionImageObject, `NextSelection` in one file.

## 10. Safe areas

- `ScreenInsets`: None (background art only), DeviceSafeInsets (clear of cutouts), CoreUISafeInsets (default; also clear of the top bar), TopbarSafeInsets. `IgnoreGuiInset = true` maps to DeviceSafeInsets. [doc ScreenGui, ScreenInsets]
- `SafeAreaCompatibility` defaults to FullscreenExtension; docs: "it's recommended that you avoid fullscreen extensions for new work". CanvasGroup, ViewportFrame and VideoFrame backgrounds are not extended. `ClipToDeviceSafeArea` defaults true, is ignored with None, and does not clip rotated objects. [doc][ann https://devforum.roblox.com/t/notched-screen-support-full-release/2074324]
- Recommended structure: background in a `None` ScreenGui, interactive content in a safe-inset ScreenGui [ann].
- `GuiService:GetInsetArea(ScreenInsets)` returns a Rect relative to the CoreUISafeInsets area; `GuiService.TopbarInset` is the free top-bar rect and changes at run time [doc]. Both exist in v742 [probe]. ResponsiveUIFoundation line 400 and RaceSessionPresentationClient line 88 already clamp with GetInsetArea [probe].
- Default touch controls occupy the bottom-left and bottom-right corners [doc https://create.roblox.com/docs/en-us/ui/position-and-size].

## 11. Efficient updates

- Every property write under a ScreenGui invalidates its cache, so guard writes (only when the shown value changes) [doc/staff, section 5].
- TweenService runs natively in PreRender; advice is to reduce the number of tweened objects [doc tag table]. Styling Transitions claim better performance than Luau tweening but only fire for style-driven changes [ann].
- Pooling: adding, removing or reparenting elements rebuilds the Z-order list; keep tiles parented and rebind them [doc tag table, inferred].
- No official total-instance budget was found. Diagnostics: Ctrl+F2 (Shift+Ctrl+F2 in Studio) shows layout counts and render items [staff, All About Text].

## 12. 2025 to 2026 engine features

| Feature | Status | Source |
|---|---|---|
| UIStroke: ScaledSize, Inner/Center/Outer, BorderOffset, multiple border strokes | Full release 2025-12-04 | https://devforum.roblox.com/t/studio-beta-uistroke-improvements-scaling-offsets-and-more/3958036 |
| ViewportDisplaySize | Full release 2025-10-21 | thread 3880384 |
| PreferredInput | Full release (2025) | thread 3750890 |
| Styling (StyleSheet, StyleRule, StyleLink, StyleDerive) | Full release 2026-01-20 | thread 3901480 |
| StyleQuery, nested pseudo-instances | Full release 2026-05-11 | thread 4566519 |
| UIShadow, per-corner UICorner | Full release 2026-06-23 | thread 4636263 |
| Styling Transitions | Full release 2026-07-27 | thread 4646870 |
| Radial/conical UIGradient, TileMode, Scale | Studio Beta 2026-09-02, not publishable then | https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594 |
| UIShadow Text mode, Inset, ShowBehindParent | In v742 API; live status unconfirmed | probe; ApplyShadowMode enum page |
| UIBlur | In v742 API; undocumented | probe |
| UIDragDetector | Class present in v742; release post not found in this pass | probe |

UIStroke known issue: Bevel or Miter join with a UICorner is overridden to Round [ann]. UIStroke docs: tweening Thickness on text "renders and stores many glyph sizes each frame".

## Not confirmed in this pass

- Crispness of text above 100 px effective size under UIScale.
- How fractional rectangles (hairlines) are rasterised under UIScale.
- Whether 9-slice corners and Path2D thickness follow UIScale.
- Path2D anti-aliasing quality and per-frame update cost.
- Live-client status of UIShadow Text mode, ShowBehindParent, UIBlur, radial/conical gradients, `ClipsDescendantsSupportsRotation`.
- Maximum stored resolution for UI images.
- ScrollingFrame auto-scroll to the gamepad selection.
- Exact italic weight set of Titillium Web (width probe is weak for italics).
