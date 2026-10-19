# Pulse Racers 2098: identity and pitch deck

**Created:** 2026-10-19 (deck built 2026-10-09 to 2026-10-10). **Status:** reference. The deck is finished for now and is Oscar's to send; nothing here changes the game.

Read this before writing anything player-facing, any pitch or store copy, or any doc that names the game.

## Name

- **Player-facing title: Pulse Racers 2098.** "Pulse Racers" is fine in short form. Oscar set the name on 2026-10-08.
- **Older names, same project:** Space Racers (most docs, Studio place names v1 to v3), Neo Tokyo Racers (repo name, early docs), Codex. Do not use them in player-facing text. Do not rename docs, folders or places unless Oscar asks.
- **Working place:** PR98 (103397770260610), see CLAUDE.md.

## Logo

- **Canonical logo:** the neon outline wordmark used on the in-game start screen: PULSE / RACERS stacked, pink to violet outline glow, "2098" in cyan, a pink-to-cyan line with a heartbeat spike underneath.
- **File:** `scripts/ui_restyle/assets/out/logo_pulse_racers.png` (1024x519, transparent). **Roblox asset:** `rbxassetid://86895264649881` (`scripts/ui_restyle/assets/uploaded_assets.json`, key `Logo`; read by `StartScreenPulse` as `LOGO_DEFAULT`).
- **Not the logo:** `assets/ui/logo/candidates/` (six alternatives from the play-review round) and `assets/ui/logo/pulse-racers-logo-pulse-theme.*` (a flat white wordmark drawn for the deck on 2026-10-09 and rejected the same day). Keep them as alternatives only.

## Look

The deck and the Pulse UI share one look; the source of truth is the [UI style sheet](pulse-racers-ui-style-sheet.md).

- Dark slate panels (`#0E0D1A` to `#211E3A`) with a white top hairline, square corners.
- Accent pink `#FF2D95` into violet `#9A3DFF`; cyan `#22E4FF` for live values and arrows; yellow `#FFE433` for money only.
- Barlow Condensed ExtraBold Italic capitals for headings (Barlow in game), Barlow for body text.
- The slanted pink striped title mark beside every heading.
- Tier colours: E `#848E91`, D `#69BE81`, C `#4ACCD3`, B `#5289EB`, A `#F4BC41`, S `#EC5CA8`.
- Neon Tokyo-inspired city, sunset and night palettes. Hero image: the white and red hover car on the waterfront at sunset.

## What the game is (the pitch in one paragraph)

A futuristic open-world racing and role-play game on Roblox. Modular hover vehicles (hover cars now; bikes, spaceships and pod racers planned) are built from interchangeable parts, painted, tuned and pushed up E to S tiers to unlock races and time trials with bigger rewards; prices climb steeply with each tier. Players store and display their collection in garages and homes they also customise, and invite friends round to show it off. The sci-fi setting lets content be far more varied than a real-car game without breaking the world's rules.

## Main drivers

These are Oscar's stated pillars; keep new features and copy aligned with them.

1. **Collection, personalisation and progression** are the key pillars. "Racing drives the progression. Customisation drives the identity. Collection and garages drive the retention."
2. **Modular vehicles**: one cockpit, many module sets; parts lock to the car they come from, so wanting a part is a reason to buy the car. Deck line: "1 vehicle, ultimate customisation".
3. **Garages as status**: more cars need more space; showing off a collection to friends is the end of the loop.
4. **Racing-first open world**: roads built from real-track principles; races and time trials rotate weekly with locked tiers.
5. **Live content**: regular vehicles, body kits, garages and apartments; target lifespan 5+ years with support.
6. **Long term: a sandbox for player creation**: player-made race routes, mini games and RP missions.

Game loop used in the deck: Drive, Race, Earn, Buy, Customise, Upgrade, Display, Expand.

## The deck

- **Artifact (Slides, private to Oscar):** https://claude.ai/artifact/5hk1yZq5koh1qGxaRt32X4. Built from Oscar's June Gamefam application (`H:\My Drive\Roblox\Neo Tokyo Racers\Documents\Gamefam Application\IND - GDD.pdf`, 17 pages) and kept close to its layouts.
- **Audience:** the directors at Cinnamon, Oscar's employer, as an internal pitch (2026-10-10). All funding content was removed: no budget, roadmap, funding opportunity, support-needed or closing ask.
- **11 pages:** 1 cover (sunset hero + logo, feature tags) · 2 in-game screenshots (4) · 3 summary, USPs and prototype status · 4 unique features and hooks (6 cards) · 5 game loop and first 5 to 10 minutes · 6 map (recoloured city crop with district labels) and district inspiration images · 7 modular vehicles, customisation flow, vehicle variation · 8 performance, tuning and progression (E to S) · 9 social status and economy · 10 updates, live-ops and long-term vision · 11 market position and risks.
- **Facts the deck states:** 12 finished vehicles in 2 categories (Piercer, Exotic) plus 6 Muscle in blockout; 400+ modules; 20 polished city blocks; taxi and courier jobs, duels, driver rank; continuous day and night. Check these against the build before reusing them.
- **Images:** in-game captures from Studio in `roblox/captures/pitch-deck-2026-10-09/`; the recoloured map in `assets/ui/map/pulse-city-map-neon-crop.jpg`; Exotic card renders in `scripts/exotic_category/mesh/images_out/cards/`. Oscar's own screenshots and reference images are stored only in the artifact.

## Caveats carried in the deck

- **Tier score ranges** on page 8 (E 100-349, D 350-474, C 475-599, B 600-724, A 725-849, S 850+) are inferred from the A and S thresholds and the six Exotic ratings; only A and S are confirmed in the repo.
- **District labels** on the map (Hyperways, North Gateway, West Crescent, Radial West, The Core, Kairo Row, Dealership Quarter, South Grid) come from `output/world-design-2026-09-26/STYLE_GUIDE_V2.md`; their positions are a best guess, and only the Dealership Quarter is placed from world coordinates.
- **Market figures** (22.4B+ visits, 190k+ peak CCU, reference games) are from June 2026 and were not refreshed.
- **Real brands in images:** a Rolls-Royce-style concept (page 4), a Pagani-style concept (page 7) and some real signage in the district references. Fine internally; swap before anything external.
- Oscar's cover message calls the vehicles "placeholder" while the deck says "12 fully upgradable vehicles"; he was told to reconcile the wording.
