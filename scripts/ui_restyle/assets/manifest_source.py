"""The one upload batch. Nothing here is uploaded; status stays "not uploaded" until Oscar approves
each file from out/contact_sheet.png. Ids later go to Config.UI.Pulse.Assets and uploaded_assets.json."""

KEY = "Config.UI.Pulse.Assets."

# file, key, purpose, slice / rect data (or the json that carries it), tintable
BATCH = [
    ("icons.png", "IconSheet", "58 UI glyphs (second pass), 128 px cells, 96 px ink box; rects in icons.json", {"rects": "icons.json"}, True),
    ("map_icons.png", "MapIconSheet", "14 map icons, white badges with the second-pass glyphs cut out, 128 px cells; rects in map_icons.json",
     {"rects": "map_icons.json", "PinTipY": 0.9219}, True),
    ("glow_soft.png", "GlowSoft", "Selected tile outer glow (9-slice)",
     {"SliceCenter": [62, 62, 66, 66], "edge_inset": 44}, True),
    ("glow_tight.png", "GlowTight", "Main button glow (9-slice)",
     {"SliceCenter": [30, 30, 34, 34], "edge_inset": 20}, True),
    ("glow_line.png", "GlowLine", "Hairline base-line glow (stretches horizontally only)",
     {"SliceCenter": [30, 0, 34, 64], "end_inset": 20}, True),
    ("digits_256.png", "Digits256", "BigNumber digits, 256 px cells (HeroNumber, countdown, results)",
     {"rects": "digits.json sheets.256"}, True),
    ("digits_128.png", "Digits128", "BigNumber digits, 128 px cells (SpeedNumber, timers, position)",
     {"rects": "digits.json sheets.128"}, True),
    ("digits_punct.png", "DigitsPunct", "BigNumber punctuation and units, both sizes, variable-width cells",
     {"rects": "digits.json punctuation"}, True),
    # review 3 (2026-10-09): baked-colour gradient images (not tintable; ImageColor3 stays white). Geometry in rings.json.
    ("minimap_ring_gradient.png", "MinimapRing", "BAKED COLOUR. Round minimap ring, pink to violet to cyan round the circle, soft glow",
     {"geometry": "rings.json minimap_ring_gradient.png"}, False),
    ("rank_arc_gradient.png", "RankArc", "BAKED COLOUR. Driver-rank arc: full gradient ring outside the minimap ring, revealed at run "
     "time; also the touch boost charge ring", {"geometry": "rings.json rank_arc_gradient.png"}, False),
    ("gauge_track.png", "GaugeTrack", "BAKED COLOUR. Speed gauge plate with its rim and the dim speed and boost tracks",
     {"geometry": "rings.json gauge"}, False),
    ("gauge_ticks.png", "GaugeTicks", "BAKED COLOUR. Speed gauge ticks in three weights, 61 over 270 degrees, pink in the top band",
     {"geometry": "rings.json gauge"}, False),
    ("gauge_glow.png", "GaugeGlow", "BAKED COLOUR. Soft glow behind the speed arc; revealed with it",
     {"geometry": "rings.json gauge"}, False),
    ("gauge_arc_gradient.png", "GaugeArc", "BAKED COLOUR. Speed arc, full 270 degree sweep, cyan to violet to pink along the sweep; "
     "revealed by a rotating UIGradient", {"geometry": "rings.json gauge"}, False),
    ("boost_arc_gradient.png", "BoostArc", "BAKED COLOUR. Boost meter, inner 270 degree arc, blue to pale cyan along the sweep; revealed",
     {"geometry": "rings.json gauge"}, False),
    ("title_slash_gradient.png", "TitleSlash", "BAKED COLOUR. Screen-title slash mark, pink to violet",
     {"geometry": "rings.json title_slash_gradient.png"}, False),
    ("minimap_vignette.png", "MinimapVignette", "Minimap inner vignette, tinted Ink", {"geometry": "static_geometry.json minimap"}, True),
    ("map_player_arrow.png", "MapPlayerArrow", "Player arrow for minimap and full map; points up, pivot at centre", {}, True),
    ("segment_strip.png", "SegmentStrip", "StatPanel SegmentedBar tile (ScaleType.Tile)",
     {"TileSize": "UDim2.new(0, pitch, 1, 0)", "fill_fraction": 46 / 64}, True),
    ("chequer_corner.png", "ChequerCorner", "Chequered corner mark on event cards (white squares only)", {}, True),
    ("wordmark_placeholder.png", "TitleMark", "PLACEHOLDER 'PULSE RACERS' lockup in Barlow ExtraBold Italic; not a logo", {}, True),
    ("keycap_9slice.png", "KeyCap", "Key cap (9-slice) for prompt banners; letter drawn in Ink on top",
     {"SliceCenter": [20, 20, 44, 44]}, True),
] + [
    # review 3 (2026-10-09): the Classic touch controls restyled, one baked 512 px image per control and state
    ("touch_%s%s.png" % (n, s), "Touch%s%s" % (n.capitalize(), "Pressed" if s else ""),
     "BAKED COLOUR. Touch %s%s: %s" % (n, ", pressed" if s else "", d), {"sizes": "touch.json"}, False)
    for n, d in (("accelerate", "upright pedal on a Slate plate (Classic pictogram)"),
                 ("brake", "wide pedal with a bar beneath (Classic pictogram)"),
                 ("turn", "single chevron, drawn pointing left; mirrored for right"),
                 ("drift", "double chevron, drawn pointing left; mirrored for right"),
                 ("boost", "round button with the bolt; charge ring is rank_arc_gradient.png"))
    for s in ("", "_pressed")
]

# Shown on the contact sheet for a decision, not part of the count.
ALTERNATIVES = [
    ("chequer_corner_two_tone.png", "ChequerCorner", "ALTERNATIVE to chequer_corner.png: white and Ink squares baked in "
     "(matches the mockup on any background, cannot be tinted). Pick one.", {}, False),
]

NOTES = {
    "tier_colours": "Tier badges need no art: each is a coloured frame with text. Oscar asked for one colour per vehicle "
                    "tier (E, D, C, B, A, S); the values are being chosen in the previews and will be recorded as "
                    "colour tokens, not as uploads.",
    "touch_controls": "Review 3 (2026-10-09): the slanted two-sheet set is withdrawn. The touch controls are the Classic "
                      "controls restyled: ten baked-colour 512 px images (five controls, idle and pressed). Right-hand "
                      "turn and drift are the left images mirrored; disabled is the idle image dimmed.",
    "baked_colour": "Review 3 (2026-10-09): Oscar allowed images for the rings, gauge and touch controls. Rows with "
                    "tintable_white false and a purpose starting BAKED COLOUR carry their own colours and are never tinted. "
                    "Icons, digits, glows, vignette, arrow, key cap, chequer and wordmark stay white and tintable.",
    "icons_second_pass": "Redrawn 2026-10-09 after Oscar's review. Names and cell positions are unchanged; drift and "
                         "gauge were appended in row 7.",
    "revision": "Third pass, after review 3. Nothing has been uploaded, so no asset id is superseded.",
}


def manifest():
    def row(f, key, purpose, data, tint, alt=False):
        return {"file": "out/" + f, "purpose": purpose, "config_key": KEY + key, "data": data,
                "tintable_white": tint, "alternative": alt, "status": "not uploaded", "asset_id": None}
    return {"batch": "Pulse UI restyle, Phase 0, one upload batch",
            "note": "Nothing is uploaded. Each file needs Oscar's yes from out/contact_sheet.png. "
                    "Uploads cannot be edited; a revision is a new id. No existing asset id changes.",
            "notes": NOTES,
            "count": len(BATCH),
            "files": [row(*b) for b in BATCH] + [row(*a, alt=True) for a in ALTERNATIVES]}
