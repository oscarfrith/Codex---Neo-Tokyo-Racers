"""The one upload batch. Nothing here is uploaded; status stays "not uploaded" until Oscar approves
each file from out/contact_sheet.png. Ids later go to Config.UI.Pulse.Assets and uploaded_assets.json."""

KEY = "Config.UI.Pulse.Assets."

# file, key, purpose, slice / rect data (or the json that carries it), tintable
BATCH = [
    ("icons.png", "IconSheet", "UI glyphs, 128 px cells, 96 px ink box; rects in icons.json", {"rects": "icons.json"}, True),
    ("map_icons.png", "MapIconSheet", "14 map icons redrawn white, 128 px cells; rects in map_icons.json",
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
    ("gauge_ring.png", "GaugeRing", "Speed gauge 270 degree arc; revealed by a rotating UIGradient",
     {"geometry": "static_geometry.json gauge"}, True),
    ("gauge_ticks.png", "GaugeTicks", "Speed gauge tick ring, 11 major and 40 minor ticks over the same 270 degrees",
     {"geometry": "static_geometry.json gauge"}, True),
    ("minimap_ring.png", "MinimapRing", "Round minimap ring (pink to cyan UIGradient at run time); also the gauge track",
     {"geometry": "static_geometry.json minimap"}, True),
    ("minimap_vignette.png", "MinimapVignette", "Minimap inner vignette, tinted Ink", {"geometry": "static_geometry.json minimap"}, True),
    ("map_player_arrow.png", "MapPlayerArrow", "Player arrow for minimap and full map; points up, pivot at centre", {}, True),
    ("segment_strip.png", "SegmentStrip", "StatPanel SegmentedBar tile (ScaleType.Tile)",
     {"TileSize": "UDim2.new(0, pitch, 1, 0)", "fill_fraction": 46 / 64}, True),
    ("chequer_corner.png", "ChequerCorner", "Chequered corner mark on event cards (white squares only)", {}, True),
    ("wordmark_placeholder.png", "TitleMark", "PLACEHOLDER 'PULSE RACERS' lockup in Barlow ExtraBold Italic; not a logo", {}, True),
    ("keycap_9slice.png", "KeyCap", "Key cap (9-slice) for prompt banners; letter drawn in Ink on top",
     {"SliceCenter": [20, 20, 44, 44]}, True),
    ("touch_controls.png", "TouchControls", "Four touch-control images, 512 px cells: accelerate, brake, drift, boost",
     {"rects": "marks.json touch"}, True),
]

# Shown on the contact sheet for a decision, not part of the count.
ALTERNATIVES = [
    ("chequer_corner_two_tone.png", "ChequerCorner", "ALTERNATIVE to chequer_corner.png: white and Ink squares baked in "
     "(matches the mockup on any background, cannot be tinted). Pick one.", {}, False),
]


def manifest():
    def row(f, key, purpose, data, tint, alt=False):
        return {"file": "out/" + f, "purpose": purpose, "config_key": KEY + key, "data": data,
                "tintable_white": tint, "alternative": alt, "status": "not uploaded", "asset_id": None}
    return {"batch": "Pulse UI restyle, Phase 0, one upload batch",
            "note": "Nothing is uploaded. Each file needs Oscar's yes from out/contact_sheet.png. "
                    "Uploads cannot be edited; a revision is a new id. No existing asset id changes.",
            "count": len(BATCH),
            "files": [row(*b) for b in BATCH] + [row(*a, alt=True) for a in ALTERNATIVES]}
