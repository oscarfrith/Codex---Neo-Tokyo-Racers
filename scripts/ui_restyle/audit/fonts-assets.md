# UI restyle audit: fonts, existing image assets, asset route

Date: 2026-10-08. Place: Space Racers v3 (93959280828322), Studio in Edit, studio_id `9caa35ea-5714-406b-9ad3-1c2905e20d42`.
Read-only. Nothing in the repo or the place was changed. Method notes are at the end.

## Headline results

1. **Barlow Condensed is not available in Roblox, and custom fonts cannot be uploaded.** The Creator Store holds 91 font families today, all published by Roblox. None is a condensed family with an italic.
2. **Barlow (normal width, the same design as the mockup face) is in the Creator Store** with all 18 faces, including ExtraBold Italic and Black Italic. So is Kanit. Both load in v3 with `Font.new("rbxassetid://<id>", weight, style)` and no install step.
3. **The style sheet's sizes are CSS sizes, not Roblox TextSize.** Roblox TextSize is the font's line height. Each font needs its own multiplier (Barlow 1.20, Roboto Condensed 1.15, Titillium Web 1.57).
4. **TextSize is capped at 100** (confirmed in Studio). HeroNumber 200 and SpeedNumber 136 cannot be set as text sizes in any font. With Titillium Web even ScreenTitle 80 needs 125.
5. **At equal cap height Titillium Web Bold Italic is about 19% wider than the mockup face, not 10 to 15%.** Roboto Condensed Bold Italic is the narrowest real italic (about 12% wider). The sheet's line "Roboto Condensed is about 20% wider than Titillium" is true only at equal TextSize, where Roboto Condensed's letters are 36% taller.
6. **Titillium Web has no italic above Bold.** The sheet's "ExtraBold Italic" roles would silently render as Bold Italic.
7. **Every italic face is downloaded at run time**, including Titillium's and Roboto Condensed's. A "shipped" family has no loading advantage over a Creator Store family for italics.
8. **Most icons the sheet needs already exist as clean white 256 px glyphs.** Missing: teleport pin, set route, tick, loop, gamepad, upgrade arrow, coin, and white versions of lock and boost.
9. **Two upload routes are proven** (Studio MCP `upload_image`; Open Cloud `upload_image.py`). Neither is recorded as needing a manual step from Oscar, but project rules require his approval for each asset.

## A. Fonts

### A1. What Roblox ships (43 family files on disk; 40 reachable through Enum.Font)

Source: `%LOCALAPPDATA%\Roblox\Versions\version-9b554450a0fc4e65\content\fonts\families\*.json` (the Studio install), cross-checked with `Font.fromEnum` over `Enum.Font` in v3. `BuilderExtended`, `BuilderMono` and `Montserrat` exist as rbxasset families but have no Enum.Font item. `Enum.Font.Gotham*` measures identically to Montserrat and `Enum.Font.Arial*` to Arimo (aliases).

Families with a real italic face (from the family files):

| Family | Upright weights | Italic weights |
|---|---|---|
| Titillium Web | 200, 300, 400, 600, 700, 900 | 200, 300, 400, 600, **700 (highest)** |
| Roboto Condensed | 300, 400, 700 | 300, 400, 700 |
| Source Sans Pro | 200, 300, 400, 600, 700, 900 | 200, 300, 400, 600, 700, 900 |
| Montserrat | 100 to 900 | 100 to 900 |
| Roboto | 100, 300, 400, 500, 700, 900 | same |
| Nunito | 200 to 900 (no 500) | same |
| Arimo | 400 to 700 | 400 to 700 |
| Ubuntu | 300, 400, 500, 700 | same |
| Josefin Sans | 100 to 700 | 100 to 700 |
| Roboto Mono | 100 to 700 | 100 to 700 |
| Merriweather (serif) | 300, 400, 700, 900 | same |
| Fondamento (script) | 400 | 400 |

No italic: Oswald (200 to 700), Sarpanch, Jura, Builder Sans / Extended / Mono, Michroma (one face), Grenze Gotisch, Inconsolata, and all the single-face display families.

### A2. Measured widths, all shipped families

`TextService:GetTextBoundsAsync`, text `CUSTOMISE 0123456789`, Size 40, in pixels. N = Normal, I = Italic. Where N and I match, the family has no italic (or the italic has the same advances).

| Family | Bold N | Bold I | Heavy N | Heavy I |
|---|---:|---:|---:|---:|
| AmaticSC | 201 | 201 | 201 | 201 |
| IndieFlower | 259 | 259 | 259 | 259 |
| PatrickHand | 264 | 264 | 264 | 264 |
| GrenzeGotisch | 266 | 266 | 272 | 266 |
| Oswald | 271 | 271 | 271 | 271 |
| Kalam | 271 | 271 | 271 | 271 |
| RomanAntique | 276 | 276 | 276 | 276 |
| **TitilliumWeb** | 290 | **279** | 291 | 279 |
| Creepster | 290 | 290 | 290 | 290 |
| Bangers | 317 | 317 | 317 | 317 |
| Guru | 329 | 329 | 329 | 329 |
| PermanentMarker | 335 | 335 | 335 | 335 |
| DenkOne | 341 | 341 | 341 | 341 |
| **SourceSansPro** | 347 | **334** | 348 | **337** |
| **RobotoCondensed** | 351 | **348** | 351 | 348 |
| Fondamento | 351 | 352 | 351 | 352 |
| AccanthisADFStd | 359 | 359 | 359 | 359 |
| Nunito | 361 | 361 | 365 | 365 |
| Sarpanch | 362 | 362 | 382 | 362 |
| BuilderSans | 373 | 373 | 373 | 373 |
| RobotoMono | 373 | 360 | 373 | 360 |
| Zekton | 373 | 373 | 373 | 373 |
| HighwayGothic | 378 | 378 | 378 | 378 |
| Balthazar | 385 | 385 | 385 | 385 |
| BuilderMono / Inconsolata | 387 | 387 | 387 | 387 |
| FredokaOne | 389 | 389 | 389 | 389 |
| ComicNeueAngular | 397 | 397 | 397 | 397 |
| Roboto | 401 | 391 | 405 | 393 |
| Merriweather | 404 | 380 | 409 | 385 |
| GothamSSm / Montserrat | 418 | 418 | 430 | 430 |
| BuilderExtended | 422 | 422 | 422 | 422 |
| Ubuntu | 422 | 417 | 422 | 417 |
| Arial / Arimo / Jura / LuckiestGuy | 423 | 423 | 423 | 423 |
| PressStart2P | 440 | 440 | 440 | 440 |
| SpecialElite | 469 | 469 | 469 | 469 |
| JosefinSans | 473 | 478 | 473 | 478 |
| Michroma (current UI font) | 533 | 533 | 533 | 533 |
| LegacyArial | 637 (height 60) | | | |

Narrow, heavy, real-italic candidates among shipped families: **Titillium Web Bold Italic (279), Source Sans Pro Bold / Black Italic (334 / 337), Roboto Condensed Bold Italic (348)**. Oswald Bold (271) is narrow and heavy but upright only.

These raw numbers mislead on their own. See A4.

### A3. Creator Store fonts (web research plus live test)

- **Usable in experiences:** yes. Roblox launched the font section in January 2023 ("Fonts in Creator Marketplace + 81 New Fonts"). Stated goal: the whole Google Fonts catalogue.
  https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977
- **Reference in code:** `Font.new("rbxassetid://12187372847", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)` or `Font.fromId(12187372847, weight, style)` (number only). Rich text: `<font family="12187372847">`. API: https://create.roblox.com/docs/reference/engine/datatypes/Font
- **Custom uploads:** not possible. Official docs: "You cannot import fonts, but the Creator Store offers over 80 different fonts for your use." https://create.roblox.com/docs/projects/assets . Community threads from February and July 2026 still report no upload route.
- **Catalogue today:** 91 families, all by creator Roblox, listed from the public search API
  `https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=FontFamily&maxPageSize=100`. A keyword search for "condensed" returns 0.
- **Still growing:** six families were added between 2026-07-28 and 2026-08-21 (Antonio, Goldman, Jolly Lodger, Londrina Solid, DotGothic16, Comic Neue). Barlow Condensed could arrive later. Keep the family as one config value so the swap is one edit.
- **Loading:** faces download like textures; `ContentProvider:PreloadAsync` on a text object waits for its fonts. https://devforum.roblox.com/t/new-font-ui-live/1967004

Requested close matches:

| Family | In Creator Store | Asset id | Italic | Note |
|---|---|---|---|---|
| Barlow Condensed | **No** | - | - | |
| **Barlow** | **Yes** | `12187372847` | Yes, 100 to 900 | Same design as the mockup face, normal width |
| **Kanit** | **Yes** | `12187373592` | Yes, 100 to 900 | Wide. The sheet's "not shipped" is true only for rbxasset families |
| Teko | Yes | `12187376174` | No | Very narrow, 5 weights |
| Rajdhani | Yes | `12187375422` | No | |
| Antonio | Yes (added 2026-08-06) | `122516982241677` | No | Heavy condensed, close to the NFS Heat feel but upright |
| Goldman | Yes (added 2026-07-28) | `115884882777577` | No | Racing display face, wide |
| Fira Sans | Yes | `12187374954` | Yes, 100 to 900 | |
| Prompt | Yes | `12187607287` | Yes, 100 to 900 | Kanit's sibling, wide |
| Saira Condensed, Big Shoulders, Fjalla One, League Gothic, Bebas Neue, Anton, Chakra Petch, Exo 2 | **No** | - | - | |

Other store families with italics: Montserrat, Poppins, Raleway, Work Sans, Rubik, Noto Sans, Mulish, Nunito Sans, Open Sans, Lato, PT Sans, Comic Neue, plus serifs. All are wide.

Live test in v3 (Size 40, `CUSTOMISE 0123456789`, Normal / Italic):

| Family | Medium | SemiBold | Bold | ExtraBold | Heavy | Digits tabular |
|---|---|---|---|---|---|---|
| Titillium Web | 289/277 | 290/278 | 290/279 | 290/279 | 291/279 | **yes** |
| Roboto Condensed | 347/337 | 351/348 | 351/348 | 351/348 | 351/348 | **yes** |
| Source Sans Pro | 327/311 | 335/322 | 347/334 | 347/334 | 348/337 | **yes** |
| Oswald | 261/253 | 269/271 | 271/271 | 271/271 | 271/271 | no |
| **Barlow** | 355/343 | 356/345 | 359/349 | 363/351 | 365/353 | **no** |
| Kanit | 292/293 | 296/295 | 296/296 | 300/300 | 305/305 | no |
| Fira Sans | 355/349 | 358/351 | 361/353 | 364/355 | 367/361 | no |
| Prompt | 316/316 | 315/315 | 315/315 | 318/318 | 320/320 | no |
| Antonio | 259/257 | 267/274 | 274/274 | 274/274 | 274/274 | no |
| Teko | 216/195 | 235/261 | 261/261 | 261/261 | 261/261 | no |
| Rajdhani | 307/305 | 309/314 | 314/314 | 314/314 | 314/314 | no |
| Michroma | 533 | | | | | yes |

"Tabular" = `1111111111` and `0000000000` measure the same at Bold Italic. In Barlow, ten 1s are 119 px and ten 0s are 187 px, so a live speed or cash number would jitter unless each digit sits in a fixed-width cell.
`TextLabel.OpenTypeFeatures` exists and accepted `"tnum"` on an unparented label, but its effect could not be measured without parenting (TextBounds is 0 unparented; `GetTextBoundsParams` has no such property). Untested.

A bogus id returns a clear error ("Asset type does not match requested type" / "Request asset was not found"), so a missing family is detectable with `pcall` around `GetTextBoundsAsync`.

### A4. The correction that matters: TextSize is line height

Checked against the font files on disk: predicted width = advance x TextSize / (hhea ascent - descent). Predictions match Studio within 2% (Titillium Bold 289 predicted, 290 measured; Oswald Bold 269 / 271; Michroma 522 / 533). So at the same TextSize, fonts draw letters of very different heights.

Vertical metrics (shipped files read from disk; store families from the published capsize metrics, `@capsizecss/metrics@4.3.0`):

| Face | Line height (em) | Cap height / TextSize | Cap px at TextSize 100 | Caps sit off-centre by |
|---|---:|---:|---:|---:|
| Barlow Condensed (mockups, CSS) | 1.200 | 0.583 | - | - |
| **Barlow** | 1.200 | 0.583 | 58 | 4.2% low |
| **Roboto Condensed** | 1.172 | 0.607 | 61 | 1.2% high |
| Antonio | 1.294 | 0.664 | 66 | 6.0% low |
| Fira Sans | 1.200 | 0.579 | 58 | |
| Oswald | 1.482 | 0.547 | 55 | 3.2% low |
| Source Sans Pro (shipped file) | 1.257 | 0.525 | 52 | 2.0% low |
| Michroma (current) | 1.422 | 0.527 | 53 | 4.9% low |
| **Titillium Web** | 1.521 | 0.447 | 45 | 2.1% low |
| Kanit | 1.495 | 0.431 | 43 | 2.0% low |

**Mockup check.** In `04-customise-parts.jpg` (1200 px wide), CUSTOMISE has a 37 px cap height, STINGER 23, PARTS 7/7 25, DRIVE 20. Scaled to 1920 these are the sheet's sizes x 0.70 (Barlow Condensed's cap height). The sheet's numbers are CSS em sizes.

**Sheet size to Roblox TextSize for the same cap height** (multiply by 0.70 / cap ratio):

| Sheet role (size) | Barlow x1.20 | Roboto Cond. x1.15 | Source Sans x1.33 | Titillium x1.57 |
|---|---:|---:|---:|---:|
| ScreenTitle 80 | 96 | 92 | **107** | **125** |
| SectionHead 54 | 65 | 62 | 72 | 85 |
| HeroNumber 200 | **240** | **231** | **267** | **313** |
| SpeedNumber 136 | **163** | **157** | **181** | **213** |
| ButtonMain 44 | 53 | 51 | 59 | 69 |
| Button / TileName 38 | 46 | 44 | 51 | 60 |
| Status 34 | 41 | 39 | 45 | 53 |
| Tab 28 | 34 | 32 | 37 | 44 |
| Value 26 | 31 | 30 | 35 | 41 |
| Label 21 | 25 | 24 | 28 | 33 |

Bold = above the cap of 100. Confirmed in Studio: an unparented `TextLabel.TextSize = 200` reads back 100, `UITextSizeConstraint.MaxTextSize = 300` reads back 100, and `GetTextBoundsAsync` returns the same width for Size 100 and 200.
The community workaround is a `UIScale` ancestor; several developers report the result looks soft because the glyph is not re-drawn above 100 (thread, September 2025: https://devforum.roblox.com/t/allow-textsize-above-100/3959480). Not verified here.

**Width at equal cap height** (advance width / cap height, Studio measurement at Size 100; mockup = ink width / cap height, accurate to about 5%):

| Face | CUSTOMISE | STINGER | PARTS 7/7 | DRIVE | Average vs mockup |
|---|---:|---:|---:|---:|---:|
| Mockup: Barlow Condensed ExtraBold Italic | 5.73 | 4.26 | 5.36 | 3.30 | - |
| Antonio Bold (upright) | 4.70 | 3.42 | 4.25 | 2.44 | -21% |
| Oswald Bold (upright) | 5.76 | 4.28 | 5.16 | 3.07 | -2% |
| **Roboto Condensed Bold Italic** | 6.74 | 4.99 | 5.91 | 3.40 | **+12%** |
| Teko Bold (upright) | 6.79 | 4.99 | 6.16 | 3.57 | +15% |
| **Titillium Web Bold Italic** | 6.95 | 5.18 | 6.50 | 3.68 | **+19%** |
| **Barlow ExtraBold Italic** | 7.20 | 5.47 | 6.43 | 3.76 | **+22%** |
| Fira Sans ExtraBold Italic | 7.32 | 5.47 | 6.38 | 3.80 | +22% |
| Source Sans Pro Black Italic | 7.67 | 5.75 | 6.48 | 4.05 | +28% |
| Kanit ExtraBold Italic | 8.31 | 6.19 | 7.47 | 4.59 | +42% |
| Michroma (current) | 11.66 | 8.53 | 10.31 | 5.71 | +92% |

Reading: nothing in Roblox gives condensed + heavy + italic. The choice is either upright at the mockup's width (Oswald Bold) or italic and 12 to 22% wider.

### A5. Candidates ranked

| Rank | Face | For | Against |
|---|---|---|---|
| 1 | **Barlow** ExtraBold Italic + SemiBold Italic, `rbxassetid://12187372847` | Same letterforms as the approved mockups. Has the 800 and 900 italics the sheet asks for. Good cap ratio (0.583), so ScreenTitle 80 fits under the cap at 1080p. | 22% wider than the condensed cut. Proportional digits. Caps sit 4% low in the text box. |
| 2 | **Roboto Condensed** Bold Italic, `rbxasset://fonts/families/RobotoCondensed.json` | Narrowest real italic (+12%). Tabular digits. Best cap ratio of the italics (0.607). | Heaviest weight is Bold. No SemiBold (it resolves to Bold), so labels need Regular Italic. Plain, generic look. |
| 3 | **Titillium Web** Bold Italic (the sheet's current pick) | Tabular digits. Squared, technical look. | +19% wide. No italic above Bold. Cap ratio 0.447: sizes need x1.57 and every role from sheet size 64 up exceeds the cap at 1080p. Largest text will be softest. |
| - | Oswald Bold / Antonio Bold | Mockup width or narrower, heavy. | Upright only. Only relevant if Oscar accepts no italic. |
| - | Kanit, Source Sans Pro, Fira Sans, Prompt | | Too wide, or no better than the three above. |

### A6. How the current code picks fonts (limits the swap)

- Config: `Theme.FontFamily`, `Racing.Typography.FontFamily`, `GarageExperience.FontFamily` hold `rbxasset://fonts/families/Michroma.json`. `DesktopFreeRoamHud.Typography.PrimaryFont` and `.BodyFont` hold the **name** `Michroma`, with 21 more values there (sizes plus per-role Bold/Italic booleans). `Racing.Typography` has 5 sizes. `GarageReplacement` has 9 text-size attributes.
- `DesktopFreeRoamHudUI` line 170: `FONT = Enum.Font[...PrimaryFont] or Enum.Font.Michroma`. An Enum.Font cannot express Bold Italic or a Creator Store family. This resolver must change for any candidate, including Titillium.
- Script literals: `Michroma` 24 times in 16 scripts; `Enum.Font.*` 19 times in 14 scripts (Michroma 13, GothamBold 4, Gotham 1, Code 1); `Font.new` 9 in 7 scripts; `.Font =` 8 in 6 scripts; `.FontFace =` 8 in 6 scripts.
- `TextScaled = true` 6 times in 4 scripts; `UITextSizeConstraint` in 3 scripts; no RichText; `GetTextSize` in `ResponsiveUIFoundation` and `OnboardingClient`; `PreloadAsync` already used in `ReplicatedFirst.Loading.LoadingScreenView`.
- `RaceBrowserClient.ICON_CELLS` holds hand-tuned optical offsets per icon "measured at the 33 px desktop reference size". They were tuned beside Michroma text and will be wrong beside a font whose caps sit elsewhere in the box.

## B. Existing image assets

130 asset references under `ReplicatedStorage.Config.UI`. Only 30 `rbxassetid://` literals exist in scripts, none of them UI (vehicle catalogue data, road graph, sprint, taxi job). Glyph shapes below were read from the live images (in-memory read, alpha downsampled to a coarse text preview), so the descriptions of the less obvious glyphs (Buy, Owned, Customise, Decorations) are my reading of that preview, not a viewed image. Size and colour figures are exact.

### B1. Free-roam HUD: `DesktopFreeRoamHud.Assets` (StringValues)

| Name | Id | What it is | Size, colour |
|---|---|---|---|
| CarIcon | 88860760495187 | Car, front view | 256, pure white |
| DealershipIcon | 110010902394406 | Crossed tools. Also used as `NavigationIcons.BuildModulesIcon` and `OwnedGarageIcons.Modes.BuildGarage` | 256, pure white |
| GarageIcon | 139219537977577 | House with garage door | 256, pure white |
| RaceIcon | 82772526464800 | Waving chequered flag | 256, pure white |
| SettingsIcon | 81640143382366 | Gear | 256, pure white |
| BoostIcon | 127668984476658 | Lightning bolt | 128, **baked blue** (36, 111, 189) |
| MapNorthArrow | 112515035978701 | N with arrow | 128, white |
| MapPlayerIcon | 77959076685939 | Arrowhead | 128, **baked pink** |
| MapTileTopLeft / TopRight / BottomLeft / BottomRight | 105511999776909, 113515913291985, 85498926288328, 97942462366071 | Old 2x2 minimap tiles | |

Local sources: `assets/ui/icons/freeroam_nav_plain/*.png` (512 px white glyphs), `scripts/map_art/hud_icons/`.

### B2. Garage: attributes on `GarageReplacement` and its children

| Where | Name | Id | What it is |
|---|---|---|---|
| NavigationIcons | BackIcon | 130571746357911 | Return arrow, white, ink fills 75% of canvas |
| NavigationIcons | ExitIcon | 133533403173813 | Door with arrow, white, fills 100% |
| NavigationIcons | DriveIcon | 124917478219752 | Steering wheel, white |
| NavigationIcons | CustomiseIcon = CustomiseModulesIcon = UpgradeModulesIcon; also `ModuleCosmeticsIcon` | 85935652702038 | Wrench with gear, white |
| NavigationIcons | BuyModulesIcon | 78853137219660 | Shopping bag, white |
| NavigationIcons | OwnedModulesIcon | 76816973927488 | Round badge, white |
| NavigationIcons | PaintShopIcon; also `ModuleColourIcon`, `OwnedGarageIcons.Actions.Colour`, `Modes.StyleGarage`, `VehicleCosmetics.ThrustColour.Icon` | 139744856495281 | Paint brush / spray, white |
| NavigationIcons | UnderglowIcon; also `ModuleNeonIcon`, `Families.Lighting`, `VehicleCosmetics.Underglow.Icon` | 87739019174785 | Light bar with rays, white |
| NavigationIcons | UnderglowSidebarIcon_exotic | 137313031963928 | Exotic underglow diagram |
| GarageReplacement | ModuleLockIcon; also `OwnedGarageIcons.States.Locked` | 96467470526298 | Padlock, **grey with a baked soft halo** (mean 75, 75, 75) |
| GarageReplacement | ModulePerformanceIcon | 130179495223690 | Speed gauge, white |
| ModuleArtwork | All, Boost, Cockpit, FrontBody, FrontBumper, FrontEngine, RearBody, RearBumper, RearEngine, SidePods, Spoiler, Stabilisers, ThrustColour (`Image`, and `Image_exotic` on 10 of them) | 23 ids | Slot diagrams: light grey car (226, 228, 234) with a pink slot highlight, 512 px |
| OwnedGarageIcons | Navigation.Save 98867283361897 (floppy disk); Actions.Material 70574439126662; Modes.DisplayCars 77221165732303 (car on a stand); Families.Decorations 81092631604328; Families.Structure 135612377189871 (brick wall); 7 DecorationLocations; 7 StructureLocations | | White 256 px glyphs |

### B3. Racing, map, mobile, loading

| Where | Name | Id | What it is |
|---|---|---|---|
| Racing.Assets | RacingIconAtlas | 79062219140152 | 1024 px, 4x4 grid of 256 px cells, 12 used. Row 0: stopwatch, chequered flag, circuit, point-to-point. Row 1: laps loop, checkpoint gate, players, trophy. Row 2: banknote (prize), podium, pin with arrow, padlock. **Thin white outline style with cyan accents.** Source `assets/ui/icons/racing/racing-ui-icon-atlas.png`. Used by `RaceBrowserClient` and `RaceEntryPresentationClient` |
| Racing.Assets | MedalAtlas | 109150933268171 | 1024 px coloured medal art |
| Racing.Assets | DefaultMapImage, DefaultTrackImage | 120663188326007, 85813025967950 | Placeholders for event media |
| MapIcons (attributes) | Race, TimeTrial, Duel, Job, TaxiFare, TaxiDrop, CourierPickup, CourierDrop, Customisation, Dealership, Garage, Waypoint, Player, OtherPlayer | 14 ids, in `scripts/map_art/uploaded_assets.json` (`refined_icons_2026_09_27`) | 128 px map glyphs with baked colour (cyan places, pink activities, blue jobs), dark outline and halo |
| MapTiles (attributes) | R1C1 to R4C4 | 16 ids | 4x4 high-resolution map; row 4 is one shared transparent tile |
| MobileFreeRoamHud.Assets | AcceleratorImage, BrakeImage, DriftArrowImage, TurnArrowImage | 92143631801983, 105499559629319, 78905432253159, 94792915490549 | 512 px touch-control art in **baked dark teal** |
| LoadingSystem | StartScreenPlayIconAssetId 111016536187357 (play in a ring), StartScreenShopIconAssetId 72917122145318 (shopping cart) | | White 256 px |
| LoadingSystem.Artworks.NeoTokyoStreet01 | ImageAssetId plus 6 tiles R1C1 to R2C3 | 7 ids | Start-screen artwork (out of scope: the sheet leaves it unchanged) |

### B4. Style-sheet icons: have or missing

| Sheet icon | Status | Use |
|---|---|---|
| Car | Have | `DesktopFreeRoamHud.Assets.CarIcon` |
| Garage / home | Have | `GarageIcon` |
| Race flag | Have | `RaceIcon` |
| Dealership / tools | Have | `DealershipIcon` (crossed tools) |
| Settings | Have | `SettingsIcon` (gear; the mockup draws sliders) |
| Exit (door) | Have | `NavigationIcons.ExitIcon` |
| Back (return arrow) | Have | `NavigationIcons.BackIcon` |
| Drive (wheel) | Have | `NavigationIcons.DriveIcon` |
| Choose vehicle (car) | Have | `CarIcon` |
| Parts (wrench) | Have | `CustomiseIcon` or `DealershipIcon` |
| Paint (brush) | Have | `PaintShopIcon` |
| Save, shop cart, play | Have | owned-garage Save, start-screen icons |
| Route, laps, checkpoints, players | Outline only | RacingIconAtlas cells; thin outline, will not match solid glyphs |
| Records (trophy) | Outline only | RacingIconAtlas (3,1) |
| Race again (loop) | Outline only | RacingIconAtlas (0,1) |
| Teleport (pin) | **Missing** as a white glyph | Atlas (2,2) is outline with a cyan arrow; `MapIcons.Waypoint` is baked pink |
| Set route | **Missing** | |
| Equip / apply (tick) | **Missing** | |
| Controls (gamepad) | **Missing** | |
| Upgrades (arrow) | **Missing** | `ModulePerformanceIcon` is a gauge |
| Lock | **Redraw** | Existing lock is grey with a halo. Image tint multiplies, so it cannot become white |
| Coin | **Missing** | Atlas has a banknote outline |
| Boost | **Redraw** | Baked blue; cannot be tinted cyan or white |
| Title mark, rank ring, gauge arcs and ticks, minimap ring glow, tile and button glow, chequered corner, medal diamonds | **New** | None exist. `SliceCenter` is used nowhere in the scripts today, so 9-slice is new to this codebase |
| Mobile accelerator, brake, drift, turn | **Restyle** | Baked teal art will not sit in the new palette |

Other findings:

- **Padding is inconsistent.** Ink fills 75% of the canvas on BackIcon, 82 to 85% on Car / Garage / Race, 97 to 100% on Exit, Paint, Settings, Drive. At one frame size the icons will look different sizes. The garage UI already carries per-family zoom values (`OwnedGarageIcons.Sizing.*ImageZoom`) to cope.
- **Selected tiles turn white.** Slot diagrams are light grey (226, 228, 234); on a White tile the car shape will nearly vanish. They need a dark tint when selected, or the selected tile keeps a dark image well.
- **Dealership tiles have no car images for Exotic** (open issue EXO-03: `MenuImage` empty, cards show HOVERCAR text). The mockup's dealership rail assumes a car image per tile.
- **Map icon colours** (blue jobs) sit outside the sheet's five roles. The sheet is silent on the map.

## C. Asset route

### C1. How images were made

| Kind | Tool | Where |
|---|---|---|
| Map and HUD glyph icons | Pure Python / Pillow drawing, 128 px RGBA, contact sheets for review | `scripts/map_art/make_icons.py`, `make_icons_glyph.py`, `restyle_hud_icons.py` |
| Glow, rings, particles | numpy procedural textures, fixed seeds (`glow_soft.png`, `shock_ring.png`, ...) | `scripts/hover_feel/vfx_textures/make_textures.py`, output in `output/vfx_textures/exotic/` |
| Slot diagrams | Blender orthographic passes, then Pillow compositing to 512 px | `scripts/exotic_category/mesh/images.py`, `compose_diagrams.py` |
| Car card art | Blender render plus Codex paint-over | vehicle category playbook |
| Building textures | Python generators | `scripts/south_grid/textures/` |
| Pulling an existing uploaded image back to PNG | Edit-mode `EditableImage` read, posted to a loopback receiver | `scripts/map_art/export_icons.lua`, `tile_receiver.py` (port 8769) |

Pillow 12.3.0 is installed for `py -3`. Glow 9-slices, rings, arcs, the title mark and solid icons are all simple to draw this way.

### C2. How images were uploaded

1. **Studio MCP `upload_image`** (map icons, tiles, 2026-09-26 and 09-27). Serve the PNGs: `py -3 -m http.server 8767 --bind 127.0.0.1` from `scripts/`, then call `upload_image` with `http://127.0.0.1:8767/...` URLs (a batch per call). It returns a URL to `rbxassetid://` map. Ids are recorded in `scripts/map_art/uploaded_assets.json`. Documented in `docs/architecture/studio-testing-playbook.md` (Tooling constraints).
2. **Open Cloud script** (Exotic card images, diagrams, paint textures). `py -3 scripts/exotic_category/mesh/upload_image.py <file.png> "<name>" <user id>`. It reads the API key from the `ROBLOX_ASSETS_KEY` user environment variable (never printed), tries asset type Image, then Decal, polls the operation and prints the asset id and moderation state. A Decal id is not the image id; the script header gives the Studio call that resolves it.
3. **Oscar by hand** (the racing atlases in July; the 33 engine sounds in October).

`store_image` is not an upload: it only hands a local file to the generation tools.

### C3. Limits

- Open Cloud accepts png, jpeg, bmp, tga, up to 20 MB and under 8000 x 8000; an uploaded image cannot be updated, so every revision is a new id (https://create.roblox.com/docs/cloud/guides/usage-assets). Keep ids in config.
- Roblox stores images at 1024 x 1024 at most (project precedent: all atlases and tiles are 1024).
- Every upload is moderated before other players can see it; the docs say this usually finishes within a few hours (https://create.roblox.com/docs/projects/assets).
- Uploads land in Oscar's inventory and stay there. `docs/00_START_HERE.md` already records six unused test images from an earlier session.
- Route 1 needs Studio open on this PC and the local server running. Route 2 needs the key in Oscar's environment and his user id.

### C4. Does Oscar need to act?

Not mechanically: `mcp__Roblox_Studio__upload_image` is on the allow list in `.claude/settings.json`, and route 2 runs unattended once the key exists. By rule, yes: `docs/architecture/claude-code-setup.md` says asset tools "need explicit user approval for that asset", and the style sheet says the images are "all needing Oscar's approval before upload". Show a contact sheet, get a yes, then upload once.

## Recommendations

1. **Decide the typeface with a three-way capture before locking the sheet.** Put Barlow ExtraBold Italic, Roboto Condensed Bold Italic and Titillium Web Bold Italic on one real screen (Customise is the densest) in a throwaway Play-only ScreenGui at 1280x720, 1920x1080 and 3440x1440. My pick is Barlow: it is the mockup's own design and has the heavy italics.
2. **Store the font as tokens, not a name:** `Style.Typography.FontFamily` (content URI), `DisplayWeight`, `LabelWeight`, `Style`, plus two numbers per font: `CapHeightRatio` and `BaselineShift`. Shared label builders then size by cap height and centre caps optically. Swapping to Barlow Condensed later, if Roblox adds it, is one edit.
3. **Rewrite the sheet's size table as cap heights** (sheet size x 0.70) and derive TextSize from `CapHeightRatio`. Do not copy the CSS numbers into TextSize.
4. **Draw the big numbers as a digit sprite sheet.** Speed, hero cash and XP, and race position: 0 to 9 and `, . : $ % + -` rendered offline as white glyphs, tinted with `ImageColor3`. This avoids the 100 cap, guarantees fixed-width digits and stays sharp at 4K. It can use the real Barlow Condensed ExtraBold Italic, since the Open Font License allows images. Needs Oscar's approval to fetch the font file and upload one or two sheets.
5. **Give every other changing number fixed-width digit cells** if Barlow is chosen (cash chip, timer, stat values), or test `OpenTypeFeatures = "tnum"` in the capture from recommendation 1.
6. **Preload the faces in the loading screen** with `ContentProvider:PreloadAsync`, next to the existing preload in `LoadingScreenView`. All italics are cloud assets.
7. **Replace the `Enum.Font` resolver in `DesktopFreeRoamHudUI`** with `Font.new(family, weight, style)` when the HUD is restyled, and route the 19 `Enum.Font.*` literals through the shared label builder.
8. **Build one icon sheet for the new style** (1024 px, 128 px cells with a clear gutter, every glyph drawn to the same ink box, pure white). Re-use the existing white glyphs by exporting them with the `EditableImage` route and re-centring them; draw the missing ones (pin, set route, tick, loop, gamepad, upgrade arrow, coin, lock, boost, trophy, route, laps, checkpoints, players) solid to match. One upload, one moderation pass, consistent sizing.
9. **Keep old asset ids where they are.** New ids go in `Config.UI.Style.Icons` and `Style.Glow`; the old folders stay untouched, so switching back needs no asset work.
10. **Batch the uploads once** after Oscar approves a contact sheet: icon sheet, two or three glow 9-slices, ring glow, gauge arcs, title mark, digit sheet, four mobile control images. About ten files. Record ids in a new `scripts/ui_restyle/uploaded_assets.json`.
11. **Add right padding on italic labels** in the shared builder (about 0.2 x cap height), so the last slanted letter is not clipped in tight or auto-sized labels.

## Cautions

- **Sizes in the sheet are not TextSize.** Copying them gives text 13 to 36% smaller than the mockups, depending on the font.
- **TextSize stops at 100.** Under a `UIScale` above 1 the largest text may look soft. Fonts with small caps for their line height (Titillium Web, Kanit) suffer most. Not verified in Studio; check it in the capture.
- **Whether Roblox fakes a slant for families without an italic was not established.** Width measurements cannot show it and nothing was parented. Assume no, and do not plan on italic Oswald or Antonio.
- **Italic faces arrive after first use** unless preloaded; text shows in a fallback font until then.
- **Font width estimates against the mockup carry about 5% error** (ink measured from a JPEG against advance widths).
- **Image tint only darkens.** The blue boost icon, grey lock, pink map arrow, teal mobile controls and coloured map icons cannot be recoloured in code to white, cyan or yellow.
- **The racing atlas is thin outline art.** Next to solid glyphs it will look like a different product, and it reads weakly at 24 px.
- **Hand-tuned optical offsets** (`RaceBrowserClient.ICON_CELLS`) were set beside Michroma and will need re-tuning or replacing with metric-based centring.
- **Uploads cannot be edited or bulk-removed** by the tools here; each revision adds an asset to Oscar's inventory. Approve from a contact sheet first.
- **Creator Store fonts depend on Roblox keeping the asset available.** The catalogue is Roblox-published and has only grown, but keep the fall-back-and-warn-once rule from the sheet for a family that fails to load.

## Method and evidence

- Studio (Edit, read-only `execute_luau`): `Enum.Font` enumeration; `GetTextBoundsAsync` on unparented `GetTextBoundsParams`; clamp checks on unparented `TextLabel` / `UITextSizeConstraint`, destroyed straight after; `Config.UI` scan for asset values and font values; pattern counts over script sources; icon reads through in-memory `EditableImage` objects, destroyed straight after. No instance was parented and no property of the place was set.
- Disk (read-only): Roblox Studio's own font family JSON files and TTF files, for faces and metrics.
- Web: Creator Store search API, asset delivery (family JSON for Barlow and Kanit), capsize font metrics, Roblox docs and DevForum threads linked above, https://bloxodes.com/catalog/roblox-font-ids (third-party id list, cross-checked against the Roblox API).
- Helper scripts written beside this file in `tools/` (scratchpad only, not in the repo): `list_fonts.py`, `local_metrics.py`, `capsize_metrics.py`, `mockup_text.py`, and the saved API response `fonts_p1.json`. No font file was downloaded.
- Not done: no visual render of any candidate font, no Play session, no upload.
