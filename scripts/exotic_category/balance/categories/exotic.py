"""Exotic category: the tables build_balance.py and test_balance.py read (CONFIG at the end).

The constants were moved here from build_balance.py unchanged. This file must not import
build_balance: the report callables get the build module through their argument.
"""

# ---------------------------------------------------------------------------
# INTERFACE.md tables
# ---------------------------------------------------------------------------

CATEGORY_ID = "exotic"
RATING_REFERENCE_COCKPIT_ID = "exotic_03"

# N, CockpitId, model, DisplayName, spec cockpit, spec kit, kit name, tier, price, target PI,
# Piercer cockpit of the same tier.
COCKPITS = [
    (1, "exotic_01", "COCKPIT_EXOTIC_01", "Stinger", "spider", "track", "Stinger", "E", 50000, 220, "bruiser_02"),
    (2, "exotic_02", "COCKPIT_EXOTIC_02", "Zephyr", "curve", "analogue", "Zephyr", "D", 150000, 390, "bruiser_03"),
    (3, "exotic_03", "COCKPIT_EXOTIC_03", "Aurora", "wedge", "wedge", "Aurora", "C", 440000, 540, "bruiser_01"),
    (4, "exotic_04", "COCKPIT_EXOTIC_04", "Endura", "longtail", "longtail", "Endura", "B", 1400000, 675, "bruiser_04"),
    (5, "exotic_05", "COCKPIT_EXOTIC_05", "Rosso", "hyper", "hyper", "Rosso", "A", 4400000, 800, "bruiser_05"),
    (6, "exotic_06", "COCKPIT_EXOTIC_06", "Seraph", "gull", "concept", "Seraph", "S", 12500000, 938, "bruiser_06"),
]
# Card image per cockpit (MenuImage and PreviewImage). The same ids are in stage_b/data/ids.json (cardImage);
# build_content.py refuses a build where the two disagree.
CARD_IMAGES = {1: "rbxassetid://109265876230687", 2: "rbxassetid://83032945669952", 3: "rbxassetid://101056947506601",
               4: "rbxassetid://87472007004585", 5: "rbxassetid://138661557393114", 6: "rbxassetid://135623705599137"}
COCKPIT_FIELDS = ["n", "id", "model", "name", "spec_cockpit", "spec_kit", "kit_name", "tier", "price", "target", "piercer"]
COCKPITS = [dict(zip(COCKPIT_FIELDS, row)) for row in COCKPITS]


# SlotId -> (id stem, donor stem, ModuleFolder, ModuleType, ModuleSlot, EnginePosition, RearEngine)
CORE_SLOTS = {
    "Engine1": ("MODULE_ENGINE_EXOTIC", "MODULE_ENGINE_BRUISER", "Engines", "Engine", "Engine", "Front", False),
    "Engine2": ("MODULE_ENGINE_B_EXOTIC", "MODULE_ENGINE_B_BRUISER", "Engines_B", "Engine", "Engine", "Rear", True),
    "Stabilisers": ("MODULE_STABILISER_EXOTIC", "MODULE_STABILISER_BRUISER", "Stabilisers", "Stabilisers", "Stabilisers", None, None),
    "Boost": ("MODULE_BOOST_EXOTIC", "MODULE_BOOST_BRUISER", "Boost", "Boost", "Boost", None, None),
}

# SlotId -> (id stem, live accessory donor, ModuleFolder)
BODY_SLOTS = {
    "FrontBody": ("MODULE_FRONTBODY_EXOTIC", "MODULE_FRONTBUMPER_LVL1", "FrontBodies"),
    "RearBody": ("MODULE_REARBODY_EXOTIC", "MODULE_REARBUMPER_LVL1", "RearBodies"),
    "SidePods": ("MODULE_SIDEPODS_EXOTIC", "MODULE_SIDEPODS_LVL1", "SidePods"),
    "FrontBumper": ("MODULE_FRONTBUMPER_EXOTIC", "MODULE_FRONTBUMPER_LVL1", "FrontBumpers"),
    "RearBumper": ("MODULE_REARBUMPER_EXOTIC", "MODULE_REARBUMPER_LVL1", "RearBumpers"),
    "RearSpoiler": ("MODULE_REARSPOILER_EXOTIC", "MODULE_REARSPOILER_LVL1", "RearSpoilers"),
}
RAIL_LABEL = {"FrontBody": "Front Body", "RearBody": "Rear Body", "SidePods": "Side Pods", "FrontBumper": "Splitter",
              "RearBumper": "Diffuser", "RearSpoiler": "Wing", "Engine1": "Front Engine", "Engine2": "Rear Engine",
              "Stabilisers": "Drift Thrusters", "Boost": "Overdrive"}

# Price of a body part of the three hidden slots (SidePods, FrontBumper, RearBumper). The three stock body
# slots are priced from the kit's core variant price (mesh/INTEGRATION.md E2): see BODY_TRIMS.
BODY_PRICE_BY_KIT = [8000, 11000, 14000, 18000, 23000, 30000]
BODY_NEON_PRICE_BY_KIT = [6500, 7000, 7500, 8000, 8500, 9500]

# Mesh kits (scripts/exotic_category/mesh/INTEGRATION.md D6 to D9). Written out here on purpose, as the
# INTERFACE.md tables above are: test_balance.py compares the ids with stage_b/data/mesh.json.
MESH_KITS = (1, 2, 3, 4, 5, 6)
# The stock body parts of a mesh cockpit. Its other three body slots declare no default and start empty.
MESH_STOCK_BODY = ["FrontBody", "RearBody", "RearSpoiler"]
# Extra ModuleIds per mesh kit and stock body slot: <base id>_<TRIM>. Same stats and upgrade paths as the
# base part; name = base name + " " + trim. Prices (mesh/INTEGRATION.md E2): percent / 100 of the kit's
# core variant price V (the Price of its Lightweight and Power core modules), which must give a whole
# positive number. The base part is never 0: on a module with a SourceCockpitId the server would then
# charge 12% of the cockpit price for a copy (GarageCatalogLookup.modulePurchasePrice).
STOCK_BODY_PERCENT = 25
# (trim, percent of V, VariantOrder, number of stat steps).
BODY_TRIMS = [("GT", 50, 20, 1), ("EVO", 100, 30, 2)]

# One stat step of a trim, by slot and kit (mesh/INTEGRATION.md F1 to F3). GT adds one step to its base
# part and EVO two. Front Body: Downforce and SteeringResponse. Rear Body: less Weight and a little
# EngineOutput. Wing: Downforce and LateralGrip. Nothing else changes.
#
# Size (F2): on its own cockpit a step is worth at least 0.3 PI, and three EVO parts 3 to 8 PI on a stock
# car where the tier has room. A flat stat is worth less the higher the tier (one EngineOutput is 2.7 PI
# on the E cockpit and 0.1 on the S cockpit), so the steps grow with the kit. Weight sits on its technical
# minimum (60) on exotic_05 and exotic_06, so there the Rear Body step earns its PI from EngineOutput.
#
# Tier safety (F3) caps the two top kits, because any owned part fits any Exotic:
# - exotic_05 had 3.00 PI between its ceiling (846.49 before the trims) and S, which starts at 849.495
#   because the tier is read from the shown index. Kit 5 keeps each step just over 0.3 PI, so its three
#   EVO parts add about 2 PI, not 3; the ceiling is now 848.12, with 1.38 PI of room left.
# - Kit 6 cannot have 0.3 PI steps at all: a stat is worth about a quarter on exotic_06 of what it is
#   worth at the exotic_05 ceiling, so steps of that size would lift exotic_05 into S. Kit 6 is shrunk to
#   steps a little larger than kit 5's (BODY_TRIM_SHRUNK; test_balance.py holds the ceiling under S).
BODY_TRIM_STEPS = {
    "FrontBody": {
        1: {"Downforce": 0.5, "SteeringResponse": 0.5},
        2: {"Downforce": 0.5, "SteeringResponse": 0.5},
        3: {"Downforce": 1, "SteeringResponse": 1},
        4: {"Downforce": 1, "SteeringResponse": 1.5},
        5: {"Downforce": 0.5, "SteeringResponse": 2},
        6: {"Downforce": 0.5, "SteeringResponse": 2.5},
    },
    "RearBody": {
        1: {"Weight": -0.5, "EngineOutput": 0.25},
        2: {"Weight": -0.5, "EngineOutput": 0.5},
        3: {"Weight": -0.5, "EngineOutput": 0.5},
        4: {"Weight": -0.5, "EngineOutput": 0.75},
        5: {"Weight": -0.5, "EngineOutput": 0.75},
        6: {"Weight": -0.5, "EngineOutput": 1},
    },
    "RearSpoiler": {
        1: {"Downforce": 0.5, "LateralGrip": 0.5},
        2: {"Downforce": 0.5, "LateralGrip": 0.5},
        3: {"Downforce": 1, "LateralGrip": 0.5},
        4: {"Downforce": 1, "LateralGrip": 1},
        5: {"Downforce": 1, "LateralGrip": 1},
        6: {"Downforce": 1, "LateralGrip": 1.25},
    },
}
BODY_TRIM_MIN_STEP_PI = 0.3
BODY_TRIM_SET_PI = (3.0, 8.0)   # three EVO parts on the stock car of their kit
BODY_TRIM_NO_ROOM = (5,)        # kits whose tier has no room for the 3 PI set (steps still at least 0.3 PI)
BODY_TRIM_SHRUNK = (6,)         # kits whose steps are under 0.3 PI on their own cockpit (still strictly better)

# ---------------------------------------------------------------------------
# Balance design
# ---------------------------------------------------------------------------

# Exotic character against the Piercer of the same tier (INTERFACE.md "Balance data").
# Applied to the Piercer stock profile before the scale is solved.
CHARACTER = {
    "TopSpeed": 1.12,          # up: the class headline
    "SteeringResponse": 1.15,  # up: sharp turn-in
    "Weight": 0.90,            # lighter
    "HoverStability": 0.85,    # down: nervous near the limit
    "DriftControl": 0.85,      # down: hard to hold a slide
    "BoostDuration": 0.80,     # down: short bursts
}

# Body modules: flat raw stats at Piercer accessory LVL1 size (live LVL1: 1 or 2 per stat, Weight 2).
# Keyed by slot, then kit number 1..6. Flavour follows the part.
#
# Rule: every style in a slot is worth about the same on EVERY cockpit, so the price steps are
# cosmetic prestige. test_balance.py holds the PI spread between the six styles of a slot under
# 1.0 on the E tier cockpit and under 0.5 on the others (report.md section 6).
#
# No body part carries Drag, in either direction. A flat Drag value cannot be tier-neutral: the
# S tier stock Drag total is 1.325 against a technical minimum of 1, so +1 Drag costs Gull 2.9 PI
# and -0.5 Drag gains it 1.5 PI, while the same values are worth 0.3 PI or less on every other
# cockpit. The live LVL1 accessories carry no Drag either. A draggy shape is written as a small
# TopSpeed penalty and a slippery shape as TopSpeed.
#
# The mix of stats matters as much as the size. EngineOutput and BrakingForce are worth relatively
# more on fast cockpits; HoverStability, DriftControl and Downforce relatively more on slow ones.
# Each part balances the two groups so its value holds from E to S. Kit 1 feeds the E tier
# cockpit, so its stats also stay under 80 percent of that cockpit's share.
BODY_STATS = {
    "FrontBody": {
        1: ("Spine Nose: long pointed nose with a raised centre spine and a wide jaw intake. Grip and braking; the big intake costs a little top speed.",
            {"TopSpeed": -0.5, "EngineOutput": 0.5, "SteeringResponse": 1, "HoverStability": 0.5, "BrakingForce": 0.5,
             "Downforce": 0.5, "Weight": 2.5}),
        2: ("Droplet Nose: short and round. Calm and direct.",
            {"TopSpeed": 1, "SteeringResponse": 1.5, "HoverStability": 0.5, "Weight": 2}),
        3: ("Bull Nose: deep rounded nose with a large mouth. Front downforce.",
            {"TopSpeed": 1, "SteeringResponse": 1, "BrakingForce": 0.5, "Downforce": 1.5, "Weight": 2}),
        4: ("Valley Nose: short and low between the fenders, with a full-width light bar. Slippery: the most top speed.",
            {"TopSpeed": 2.5, "SteeringResponse": 1, "Weight": 2}),
        5: ("Vented Nose: sharp nose with louvred bonnet vents. Most front downforce.",
            {"LateralGrip": 0.5, "SteeringResponse": 1.5, "Downforce": 2, "Weight": 2}),
        6: ("Raised Nose: narrow raised nose over an open floor. Sharpest turn-in.",
            {"TopSpeed": 1, "SteeringResponse": 2, "Weight": 2}),
    },
    "RearBody": {
        1: ("Chopped Tail: tall tail cut off flat, with blade lamps and a centre spine. More output and a loose tail, less top speed.",
            {"TopSpeed": -1, "EngineOutput": 1, "LateralGrip": 0.5, "DriftControl": 1, "Downforce": 0.5, "Weight": 2}),
        2: ("Boat Tail: narrow drooping tail. Smooth air and top speed. Lightest.",
            {"TopSpeed": 2.5, "HoverStability": 1, "Downforce": 0.5, "Weight": 1.5}),
        3: ("Sloped Tail: louvred deck that slopes to a low edge. Most output. Heavy.",
            {"TopSpeed": -0.5, "EngineOutput": 1.5, "HoverStability": 0.5, "Downforce": 0.5, "Weight": 3}),
        4: ("Bar Tail: square tail with a full-width light bar. The slipperiest: most top speed.",
            {"TopSpeed": 3, "HoverStability": 1, "Weight": 2}),
        5: ("Louvred Tail: slatted tail face over a deep diffuser. Most rear downforce.",
            {"EngineOutput": 0.5, "LateralGrip": 0.5, "HoverStability": 0.5, "Downforce": 3, "Weight": 2}),
        6: ("Open Tail: narrow tail over an open diffuser floor. Downforce and calm.",
            {"TopSpeed": 0.5, "EngineOutput": 0.5, "HoverStability": 1, "Downforce": 2.5, "Weight": 2}),
    },
    "SidePods": {
        1: ("Barge Trays: wide floor tray and barge boards. Grip, drift bite and braking.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 0.5, "DriftControl": 1.5,
             "DriftGrip": 2, "DriftChargeRate": 2, "BrakingForce": 1.5, "Weight": 2.5}),
        2: ("Torpedo Pods: round pods on pylons. All-round, close to the Piercer pods.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 1, "DriftControl": 2,
             "DriftGrip": 2, "DriftChargeRate": 2, "BrakingForce": 0.5, "Weight": 2}),
        3: ("Strake Intakes: straked intake wedge that feeds the side engines. Most output.",
            {"TopSpeed": -0.5, "EngineOutput": 2, "LateralGrip": 2, "SteeringResponse": 1.5, "HoverStability": 1.5,
             "DriftControl": 1, "DriftGrip": 2, "DriftChargeRate": 2, "Downforce": 0.5, "Weight": 2.5}),
        4: ("Full Fairings: smooth full-height fairing. Slippery and steady.",
            {"TopSpeed": 2.5, "EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 2,
             "DriftControl": 1, "DriftGrip": 1.5, "DriftChargeRate": 1, "Weight": 2}),
        5: ("Floating Blades: thin blade on struts, air runs behind it. Light, sharp, with downforce.",
            {"EngineOutput": 1, "LateralGrip": 2.5, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 1.5,
             "DriftGrip": 2, "DriftChargeRate": 0.5, "Downforce": 2.5, "Weight": 1.5}),
        6: ("Waisted Cheeks: low cheek intake that pinches to nothing. Light and quick to turn.",
            {"EngineOutput": 1, "LateralGrip": 2, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 2,
             "DriftGrip": 2, "DriftChargeRate": 2, "Weight": 1.5}),
    },
    "FrontBumper": {
        1: ("Plough: deep plough splitter. Bites, and costs a little top speed.",
            {"TopSpeed": -0.5, "LateralGrip": 0.5, "BrakingForce": 1.5, "Downforce": 1, "Weight": 2}),
        2: ("Soft Lip: small rounded lip. Light.",
            {"HoverStability": 0.5, "BrakingForce": 1.5, "Downforce": 0.5, "Weight": 1.5}),
        3: ("Chin Blade: flat chin blade.",
            {"SteeringResponse": 0.5, "BrakingForce": 1.5, "Downforce": 0.5, "Weight": 2}),
        4: ("Long Tongue: long low tongue. Slippery: top speed.",
            {"TopSpeed": 2, "BrakingForce": 1, "Weight": 2}),
        5: ("Keel Planes: stacked keel planes. Most front downforce, less top speed.",
            {"TopSpeed": -1, "SteeringResponse": 1, "BrakingForce": 1, "Downforce": 3, "Weight": 1.5}),
        6: ("Scoop Bib: bib scoop that feeds the brakes and intake.",
            {"EngineOutput": 0.5, "BrakingForce": 1, "Downforce": 1, "Weight": 2}),
    },
    "RearBumper": {
        1: ("Crash Bar: crash structure and rain light. Most braking. Heavy.",
            {"HoverStability": 0.5, "DriftGrip": 0.5, "BrakingForce": 2, "Weight": 3}),
        2: ("Smooth Valance: clean valance. A little of everything.",
            {"TopSpeed": 0.5, "HoverStability": 0.5, "DriftControl": 0.5, "BrakingForce": 1, "Downforce": 1, "Weight": 2}),
        3: ("Strake Diffuser: straked diffuser. Downforce and drift control.",
            {"DriftControl": 1, "BrakingForce": 1, "Downforce": 2.5, "Weight": 2}),
        4: ("Tail Tray: tray under the long tail. Steady, with some top speed.",
            {"TopSpeed": 1, "HoverStability": 1.5, "BrakingForce": 0.5, "Downforce": 0.5, "Weight": 2}),
        5: ("Venturi: deep venturi tunnels. Most rear downforce.",
            {"HoverStability": 0.5, "DriftControl": 1, "BrakingForce": 0.5, "Downforce": 3, "Weight": 2}),
        6: ("Keel Fin: centre keel fin. Stability. Light.",
            {"TopSpeed": 0.5, "HoverStability": 1.5, "DriftControl": 1, "Weight": 1.5}),
    },
    "RearSpoiler": {
        1: ("Spine Wing: lip wing on the tail edge; the kits carry a plane on one centre pylon. Downforce, grip and braking, a little less top speed.",
            {"TopSpeed": -1, "LateralGrip": 2, "SteeringResponse": 1.5, "HoverStability": 0.5, "DriftControl": 0.5,
             "DriftGrip": 1, "BrakingForce": 1.5, "Downforce": 1, "Weight": 2.5}),
        2: ("Twin-Post Wing: low wing on two posts. All-round, close to the Piercer spoiler.",
            {"TopSpeed": 1, "LateralGrip": 2, "SteeringResponse": 2, "HoverStability": 1, "DriftGrip": 1, "Weight": 2}),
        3: ("Drop-Tip Wing: wing with tips that turn down. Grip, a little less top speed.",
            {"TopSpeed": -0.5, "LateralGrip": 2.5, "SteeringResponse": 2, "HoverStability": 1, "BrakingForce": 0.5,
             "Downforce": 1, "Weight": 2}),
        4: ("Bridge Wing: low blade between two fins. Slippery: most top speed.",
            {"TopSpeed": 2.5, "LateralGrip": 1.5, "SteeringResponse": 1.5, "HoverStability": 1, "DriftControl": 0.5,
             "DriftGrip": 0.5, "Weight": 1.5}),
        5: ("Race Wing: swan-neck race wing. Most downforce.",
            {"TopSpeed": 1, "LateralGrip": 2.5, "SteeringResponse": 1, "HoverStability": 0.5, "BrakingForce": 0.5,
             "Downforce": 3, "Weight": 2}),
        6: ("Pylon Wing: wide wing on two pylons. Light and sharp.",
            {"TopSpeed": 1.5, "LateralGrip": 1.5, "SteeringResponse": 2.5, "HoverStability": 1, "DriftControl": 0.5,
             "Weight": 1.5}),
    },
}

# New upgrade paths for the two new slots. PathIds are saved keys (profile V2UpgradePoints).
# Flat deltas at accessory size (live accessory paths use 1 to 4 per point).
# - No new path carries Drag, for the reason given above BODY_STATS (the cloned live accessory
#   paths do, as on Piercer: report.md section 12).
# - The two weight paths carry a second delta. Hyper and Gull sit on the Weight minimum (60), where
#   a Weight cut alone is worth nothing in the rating or on the road. The second delta follows the
#   legacy definitions in VehicleUpgradeDefinitions (Lightweight Internals: Weight and
#   SteeringResponse +1; Lightweight Arms: Weight and DriftGrip +1).
NEW_UPGRADE_PATHS = {
    "FrontBody": [
        ("NoseCanards", "Nose Canards", 1, {"SteeringResponse": 2, "Downforce": 1, "TopSpeed": -1}),
        ("SlipstreamNose", "Slipstream Nose", 2, {"TopSpeed": 2, "Downforce": -1}),
        ("LightweightNose", "Lightweight Nose", 3, {"Weight": -3, "SteeringResponse": 1}),
    ],
    "RearBody": [
        ("DeckCooling", "Deck Cooling", 1, {"EngineOutput": 1, "BoostEfficiency": 2, "Weight": 1}),
        ("TailStrakes", "Tail Strakes", 2, {"HoverStability": 2, "DriftControl": 1, "TopSpeed": -1}),
        ("LightweightDeck", "Lightweight Deck", 3, {"Weight": -3, "DriftGrip": 1}),
    ],
}



# ---------------------------------------------------------------------------
# Report text that names Exotic cars, files or history (build_balance.write_report asks for it by key).
# Each function takes the report environment E: the build module (E.B) and the data of this build.
# ---------------------------------------------------------------------------


def report_structure(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("## Mesh kits (exotic_02 Curve, exotic_05 Hyper)")
    add("")
    add("From `scripts/exotic_category/mesh/INTEGRATION.md` (D6 to D9). It changes how the sections below read for these two cockpits; the other four are as before.")
    add("")
    add("- **Stock build**: cockpit + four Standard core modules + three body defaults (Nose, Engine Deck, Wing). `SidePods`, `FrontBumper` and `RearBumper` declare no default and start empty. The cockpit's own raw stats absorb those three parts, so the stock totals and the stock PI are unchanged. Wherever a section says \"six body parts\" or \"its six default body modules\", read three for these two cockpits.")
    add("- **Fitting the three empty slots adds stats on top of the target total.** With all six own-kit parts: %s." % "; ".join(
        "%s %s %d (stock %d, %+.2f unrounded)" % (c["id"], analysis["category"][c["id"]]["FULL_BODY"]["Overall"]["Tier"], analysis["category"][c["id"]]["FULL_BODY"]["Overall"]["PerformanceIndex"],
                                                  cockpits[c["id"]]["stockPI"], analysis["category"][c["id"]]["FULL_BODY"]["Overall"]["UnroundedPerformanceIndex"] - analysis["category"][c["id"]]["STANDARD"]["Overall"]["UnroundedPerformanceIndex"])
        for c in COCKPITS if c["n"] in MESH_KITS))
    add("  The tier does not change. \"Highest build found\" and \"Ceiling\" (section 7) already search every body slot, filled or empty.")
    add("- **36 GT and EVO ModuleIds**: `_GT` and `_EVO` of the Front Body, Rear Body and Wing of every kit. Each carries the upgrade paths of its base part and its attribute set. Every body part carries `SourceCockpitId` and `SourceCockpitDisplayName` of its kit's cockpit, so it is locked until that cockpit is owned (INTEGRATION.md E1); the base part of a stock slot costs a quarter of the kit's core variant price (the first copy comes with the car), GT half and EVO the whole of it (E2). `VariantName` is Standard, GT or EVO and `VariantOrder` 10, 20, 30; `CardTitle` is the base name on all three (F4).")
    add("- **GT and EVO add stats** (F1 to F3; section 6a). GT adds one step to its base part and EVO two. Front Body: `Downforce` and `SteeringResponse`. Rear Body: less `Weight` and a little `EngineOutput`. Wing: `Downforce` and `LateralGrip`. Base parts, hidden-slot parts, core modules and cockpits are unchanged.")
    add("")
    rows = []
    for n in MESH_KITS:
        for slot in MESH_STOCK_BODY:
            base_id = module_id(BODY_SLOTS[slot][0], n)
            for this_id in body_part_ids(slot, n):
                attributes = modules[this_id]["attributes"]
                rows.append(["`%s`" % this_id, attributes["DisplayName"], fmt(attributes["Price"]), fmt(attributes["NeonPrice"])])
    add(table(["ModuleId", "Name", "Price", "NeonPrice"], rows))
    add("")
    add("- In sections 6, 8 and 10 a style swap on these two cockpits is made in the three stock slots; a part of an empty slot is rated as fitted on top of the stock build.")
    add("")
    return L


def report_drag_bullet(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("- **No body part carries `Drag`.** A flat Drag value cannot be worth the same on every tier. Gull's stock `Drag` is %s against a minimum of 1, so +1 Drag costs Gull %.1f PI, while it costs %.1f PI or less on every other cockpit. The live LVL1 accessories carry no Drag either. A draggy shape is a small `TopSpeed` penalty; a slippery shape is `TopSpeed`." % (
        fmt(design["exotic_06"]["totals"]["Drag"], 3), -analysis["drag_plus_one"]["exotic_06"],
        under(max(-analysis["drag_plus_one"][c["id"]] for c in COCKPITS[:5]))))
    return L


def report_card_rating_note(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("\"Card rating\" is the module card rating after Stage A (`RatingReferenceCockpitId=exotic_03`): the PI of a stock Wedge with that part swapped in. \"On E\" to \"On S\" is the PI of the stock cockpit of that tier with only this part swapped (its own part gives its stock PI).")
    return L


def report_trim_notes(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("- Kit 5 (Rosso) keeps each step just over %s PI, so its three EVO parts add about 2 PI rather than %s: the Rosso ceiling has to stay under the S band (section 7)." % (fmt(BODY_TRIM_MIN_STEP_PI), fmt(BODY_TRIM_SET_PI[0])))
    add("- Kit 6 (Seraph) is shrunk: its steps are worth under %s PI on its own car. A stat is worth about a quarter on Seraph of what it is worth at the Rosso ceiling, and any owned part fits any Exotic, so 0.3 PI steps on Seraph would lift Rosso into S. Each part is still strictly better than the one below it." % fmt(BODY_TRIM_MIN_STEP_PI))
    return L


def report_cost_notes(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("- The Piercer figure includes four LVL3 accessories at 19,000 each. The Exotic body parts come with the cockpit, which is why the Spider build is cheaper than the Forge build.")
    add("- Body and Standard upgrade guides do not scale with the cockpit (live pattern). On Spider a Standard engine point (6,050) costs more than a Lightweight engine (6,000). Forge has the same pattern today (4,800).")
    add("- A full Lightweight build costs the same as a full Power build apart from the upgrade choice. Neon is extra: `NeonPrice` per module.")
    return L


def report_new_paths_note(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("New paths for the two new slots (explicit `upgradePaths`, the same on all six parts of the slot). **These `PathId`s are new saved keys.** None is a live `PathId`, a legacy upgrade id or a category `UPGRADE_*` id.")
    return L


def report_path_notes(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    add("- The six new paths gain PI on every cockpit. No new path carries `Drag` (section 6). `LightweightNose` and `LightweightDeck` carry a second stat because Hyper and Gull sit on the `Weight` minimum of 60, where a weight cut alone is worth nothing in the rating or on the road. The second stat follows the legacy `VehicleUpgradeDefinitions` (Lightweight Internals: `Weight` and `SteeringResponse` +1; Lightweight Arms: `Weight` and `DriftGrip` +1).")
    add("- Everything is small on Gull: the index curve is nearly flat at S.")
    add("- The cloned paths are the live Piercer paths, unchanged. Their odd rows are flagged in section 12.")
    return L


def report_cockpit_attribute_notes(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    cockpit_names = sorted(cockpits["exotic_01"]["attributes"])
    add("Cockpits carry the %d non-colour attributes of the live Piercer cockpit plus the six new `Default<Slot>ModuleId` names (%d in all): %s." % (
        len(cockpit_names) - 6, len(cockpit_names), ", ".join("`%s`" % name for name in cockpit_names)))
    add("")
    add("The mesh cockpits `exotic_02` and `exotic_05` carry three of the six new names (`DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultRearSpoilerModuleId`; %d attributes in all): a slot that starts empty has no default attribute." % len(cockpits["exotic_02"]["attributes"]))
    add("")
    add("Not in `balance.json`: the six `Default*Color` attributes (Color3, a paint decision) and the seat offsets. `MenuImage` and `PreviewImage` are empty strings. Legacy cockpit values `Acceleration=70`, `Handling=30`, `Drift=0`, `Braking=100`, `Boost=0`, `Power=40` are the constants on all six live cockpits.")
    return L


def report_flags(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    e6 = design["exotic_06"]
    hyper = analysis["category"]["exotic_05"]
    rally = analysis["piercer"]["bruiser_05"]
    spider = analysis["category"]["exotic_01"]
    worth = analysis["path_worth"]
    lowest_fraction = min(
        (design[c["id"]]["cockpit_raw"][name] / (design[c["id"]]["totals"][name] * live.shares[name]["Cockpit"]), c["id"], name)
        for c in COCKPITS for name in R.RAW_ORDER if name not in R.LOWER_IS_BETTER)

    def gains(slot, this_id):
        return worth[slot][this_id]["gain"]

    dead = []
    harmful = []
    for slot in BODY_ORDER:
        for this_id, entry in worth[slot].items():
            zero = [c["name"] for c in COCKPITS if abs(entry["gain"][c["id"]]) < 0.005]
            down = ["%s %.1f" % (c["name"], entry["gain"][c["id"]]) for c in COCKPITS if entry["gain"][c["id"]] <= -0.005]
            assert not (entry["new"] and (zero or down)), "a new path is worthless or harmful: " + this_id
            if zero:
                dead.append("%s `%s` on %s" % (RAIL_LABEL[slot], this_id, " and ".join(zero)))
            if down:
                harmful.append("%s `%s` (%s)" % (RAIL_LABEL[slot], this_id, ", ".join(down)))
    mixes = [(R._luau_round(R._rounded(analysis["mix"][c["id"]]["best"][0], 2)) - cockpits[c["id"]]["stockPI"],
              R._luau_round(R._rounded(analysis["mix"][c["id"]]["worst"][0], 2)) - cockpits[c["id"]]["stockPI"]) for c in COCKPITS]
    flags = [
        "**Weight cannot go lighter at the top.** The technical minimum is 60. Zenith is already at 60 and Rally at 61, so Gull equals Zenith (60) and Hyper is 1 lighter than Rally (60). The other four are 10 to 12 percent lighter than their Piercer.",
        "**Gull needed a larger scale (%.3f; the others %.3f to %.3f).** At S tier `Weight` and `BoostRecharge` are pinned at their minimum and the index curve is flat, so the other stats carry the 13 points over Zenith. Gull `TopSpeed` is %s against Zenith 360." % (
            e6["scale"], min(design[c["id"]]["scale"] for c in COCKPITS[:5]), max(design[c["id"]]["scale"] for c in COCKPITS[:5]), fmt(e6["totals"]["TopSpeed"])),
        "**Curve shares three totals with Spider.** `Weight`, `Drag` and `BoostRecharge` are equal on the E and D cockpits (section 3), as they are on Forge and Vector. Every other stat rises with the tier.",
        "**Gull is sensitive to Drag.** Its stock `Drag` is %s (minimum 1). +1 Drag costs it %.1f PI (Hyper %.2f, the rest %.2f or less). The live Zenith (`Drag` 1.475) has the same sensitivity. It is a rating effect only: the road drag factor is clamped at 0.65, which is reached at Drag 16.9 (runtime.md 7.4, read from source, not measured)." % (
            fmt(e6["totals"]["Drag"], 3), -analysis["drag_plus_one"]["exotic_06"], -analysis["drag_plus_one"]["exotic_05"],
            max(-analysis["drag_plus_one"][c["id"]] for c in COCKPITS[:4])),
        "**So nothing authored here carries Drag.** No body part and no new upgrade path has a Drag value. With that, any whole kit and any mix of parts moves a stock build by %+d to %+d PI at most (section 8)." % (
            min(low for _, low in mixes), max(high for high, _ in mixes)),
        "**The cloned accessory paths still carry Drag, as on Piercer.** Splitter, Diffuser, Wing and Side Pods clone the live LVL1 paths, as the brief asks. On a stock Gull three points of `FrontSplitter` cost %.1f PI, `RearDiffuser` %.1f, `DownforcePackage` %.1f and `DriftAero` %.1f, while `LowDragProfile` gains %.1f and `AirflowChannels` %.1f. Once `LowDragProfile` is bought (Drag -9) the total sits on the minimum and the other paths stop costing. Zenith with LVL accessories behaves the same today. Decision for Oscar: keep the clones, or give the four slots Exotic paths without Drag (`balance.json` allows explicit `upgradePaths` on any module)." % (
            -gains("FrontBumper", "FrontSplitter")["exotic_06"], -gains("RearBumper", "RearDiffuser")["exotic_06"],
            -gains("RearSpoiler", "DownforcePackage")["exotic_06"], -gains("RearSpoiler", "DriftAero")["exotic_06"],
            gains("RearSpoiler", "LowDragProfile")["exotic_06"], gains("SidePods", "AirflowChannels")["exotic_06"]),
        "**Cloned paths that are worth nothing at stock:** %s. These are pure `Weight` cuts on cockpits already at the 60 minimum, so they do nothing in the rating or on the road. Live Zenith has the same. The two new weight paths avoid it with a second stat (section 10)." % ("; ".join(dead) if dead else "none"),
        "**Cloned paths that lower PI at stock:** %s. The Splitter `LightweightMounts` trades `BrakingForce` -1 for `Weight` -3, which is a loss where weight is cheap. Live pattern, not changed." % ("; ".join(harmful) if harmful else "none"),
        "**Hyper stays in A.** A fully upgraded Hyper tops out at %s %d (highest build found: %s %d). The ceiling no Hyper build can beat is %s %d, under the S band at 850. Rally tops out at %s %d." % (
            hyper["POWER_MAX"][0]["Overall"]["Tier"], hyper["POWER_MAX"][0]["Overall"]["PerformanceIndex"],
            hyper["ANY_MAX"][0]["Overall"]["Tier"], hyper["ANY_MAX"][0]["Overall"]["PerformanceIndex"],
            hyper["ANY_CEILING"]["Overall"]["Tier"], hyper["ANY_CEILING"]["Overall"]["PerformanceIndex"],
            rally["ANY_MAX"][0]["Overall"]["Tier"], rally["ANY_MAX"][0]["Overall"]["PerformanceIndex"]),
        "**Exotic has two more upgradable slots than Piercer** (12 more points per build). The lower tiers cross one tier band with a full Power set and all upgrades, as Piercer does today (section 7).",
        "**A stock Exotic can be upgraded without buying anything else.** Its six body parts each take six points, so a Standard Spider reaches %s %d on upgrades alone. A stock Piercer has no body parts to upgrade; with four LVL1 accessories Forge reaches %s %d." % (
            spider["STANDARD_MAX"][0]["Overall"]["Tier"], spider["STANDARD_MAX"][0]["Overall"]["PerformanceIndex"],
            analysis["piercer"]["bruiser_02"]["STANDARD_LVL1_MAX"][0]["Overall"]["Tier"], analysis["piercer"]["bruiser_02"]["STANDARD_LVL1_MAX"][0]["Overall"]["PerformanceIndex"]),
        "**Body parts are worth more on cheap cockpits.** The same flat stat is a bigger share of an E tier total. Removing the four optional parts drops Spider to %d but Gull only to %d (section 7). The styles of a slot are still worth the same as each other on each cockpit." % (
            spider["NO_OPTIONAL_BODY"]["Overall"]["PerformanceIndex"], analysis["category"]["exotic_06"]["NO_OPTIONAL_BODY"]["Overall"]["PerformanceIndex"]),
        "**Cockpit raw values are lower than a Piercer cockpit's.** The body parts carry part of the cockpit share. The smallest remainder is %s `%s` at %.0f%% of its share. No value is negative." % (
            lowest_fraction[1], lowest_fraction[2], lowest_fraction[0] * 100),
        "**Dealership rating depends on Stage A.** Until `VehiclePerformanceResolver` counts the six body defaults, the dealership shows less than the stock PI (at most the \"optional body parts removed\" figure).",
        "**Extra Standard copies.** With `Price=0` and `PurchasePrice=0` the live `modulePurchasePrice` charges 12% of the source cockpit price, looked up in category `bruiser` (`GarageCatalogLookup` line 123). Stage A changes that lookup to the module's own category. Without it an extra Exotic Standard copy would cost 1,000.",
        "**`Point4CostGuide` to `Point6CostGuide` are never charged live.** `NextPointCost` is always called with a path id and uses the next point on that path (1 to 3). This is live behaviour for Piercer too. Reported, not changed. The guides are still written, as on the donors.",
        "**Three variants share one `DisplayName`** (INTERFACE.md: the spec display name). Any text that shows only the name cannot tell Standard from Power.",
        "**Road feel is not proven by the rating.** `VehicleDynamics` clamps most stats (runtime.md 7.4), so the top tiers differ less on the road than in PI. Raw `TopSpeed` barely moves road speed in the live tuning, so the slippery and draggy body flavours are rating flavours first. Check in Play.",
        "**`OwnedByDefault=true`** is copied from the live cockpits. No live script reads it.",
        "**`TargetStockPI` on Forge and Vector** is 200 and 375 live, but they compute to 202 and 374. Unrelated to Exotic. Reported, not changed.",
    ]
    for flag in flags:
        add("- " + flag)
    return L


def report_deviations(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    for item in [
        "**Weight at A and S tier.** INTERFACE.md asks for a lighter `Weight` than the Piercer of the same tier. The live technical minimum is 60, so Hyper is 60 (Rally 61) and Gull is 60 (Zenith 60).",
        "**Floor rule.** \"No cockpit raw value below the technical minimum\" is applied to the cockpit for higher-is-better stats, and to the stock total for `Weight`, `BoostRecharge`, `BoostRechargeDelay` and `Drag`. A literal reading cannot be met: live Piercer cockpits already sit under those minimums (Zenith cockpit `Weight` 42, `BoostRecharge` 1.4).",
        "**Attribute values beyond numbers and strings.** INTERFACE.md says \"every numeric and string attribute\". Booleans from the donors are included too (for example `RearEngine`, `V2Materialised`). Color3 values are not.",
        "**Opt-in attributes included.** `CardTitle` and `RatingReferenceCockpitId` are in every module's attributes with the INTERFACE.md values, so the file is the whole attribute set.",
        "**Either/or.** A module entry has `upgradePathDonor` or `upgradePaths`, never both and never a null.",
        "**`MaxPointsPerPath` on variants.** Absent on Lightweight and Power, as on the live donors (INTERFACE.md names it for Standard only).",
        "**Engine split.** The design note \"Main Turbine leans on top speed, Side Engines on acceleration\" is not applied. Both engines carry the same numbers, as the live allocation policy and the task require.",
        "**No Drag on body parts.** The brief gives \"a long tail lowers drag\" as an example flavour. It is written as `TopSpeed` instead (Streamer Tail `TopSpeed` +3), because a flat Drag value breaks the rule that every style in a slot has similar value (section 6). This also drops the small negative Drag values the first build carried: -0.5 Drag was worth 1.5 PI on Gull and under 0.2 PI elsewhere, and Gull's own deck carried -0.5, so a deck without Drag cost Gull 1.7 PI.",
        "**Ladder rule.** A lower-is-better total is never worse than on the tier below (section 3). The brief does not ask for it; without it the D cockpit was heavier and draggier than the E cockpit.",
        "**New weight paths carry a second stat** (section 10), so a point is never worthless on the two cockpits at the `Weight` minimum.",
    ]:
        add("- " + item)
    return L


def report_not_verified(E):
    B = E.B
    R = B.R
    design, live, analysis, cockpits, modules = E.design, E.live, E.analysis, E.cockpits, E.modules
    fmt, under, table, module_id, body_part_ids = B.fmt, B.under, B.table, B.module_id, B.body_part_ids
    BODY_ORDER = B.BODY_ORDER
    L = []
    add = L.append
    for item in [
        "The port was not run against the live Luau modules (no gameplay module may be required through MCP). It reproduces the six Piercer stock ratings found independently in ui.md, and the source hashes match.",
        "Nothing was installed or driven. On-road speed, feel and the possible runtime double count (runtime.md 9.1) are open for Play.",
        "The dealership rating, the module card rating and the price of an extra Standard copy depend on Stage A code that other builders are writing.",
        "\"Similar overall value\" is measured as PI. Two parts with the same PI can still feel different.",
        "The \"highest build found\" column is a search. The tier statement in section 7 rests on the ceiling, which is a bound, and covers own-family core modules only (a player who owns two cockpits can move core sets between them: section 8).",
        "`test_balance.py` was run with `py -3` only. Its tests are plain `test_*` functions without fixtures, but pytest is not installed here, so a pytest run is not verified.",
    ]:
        add("- " + item)
    return L


# ---------------------------------------------------------------------------
# What test_balance.py holds this category to. Written out again on purpose: the tests compare the
# generated data with these values, not with the tables above.
# ---------------------------------------------------------------------------

TEST = {
    # Files next to this folder (scripts/exotic_category) that the ids, names and prices are compared with.
    "interface_path": "INTERFACE.md",
    "mesh_data_path": "stage_b/data/mesh.json",
    "mesh_module_count": 126,
    # Body prices by kit (INTERFACE.md) and mesh/INTEGRATION.md E2: Price as a share of the kit's core variant price V.
    "body_prices": [8000, 11000, 14000, 18000, 23000, 30000],
    "body_neon": [6500, 7000, 7500, 8000, 8500, 9500],
    "stock_body_base_price": {1: 1500, 2: 4500, 3: 13200, 4: 42000, 5: 132000, 6: 375000},
    "core_variant_price": {1: 6000, 2: 18000, 3: 52800, 4: 168000, 5: 528000, 6: 1500000},
    "trim_prices": {1: {"GT": 3000, "EVO": 6000}, 2: {"GT": 9000, "EVO": 18000}, 3: {"GT": 26400, "EVO": 52800},
                    4: {"GT": 84000, "EVO": 168000}, 5: {"GT": 264000, "EVO": 528000}, 6: {"GT": 750000, "EVO": 1500000}},
    # Cockpit price: about 25% over the Piercer of the same tier.
    "price_rule": {"kind": "over_reference", "low": 1.24, "high": 1.28},
    # Character: the stock totals against the Piercer totals of the same tier, as they are.
    "character": {"kind": "absolute", "up": ("TopSpeed", "SteeringResponse"),
                  "down": ("HoverStability", "DriftControl", "BoostDuration"), "weight": "lighter"},
    # No stat is worse on a higher cockpit: higher-is-better stats rise strictly, lower-is-better fall or hold.
    "ladder_strict": True,
    # Piercer family whose upgrade paths each core family clones (the Piercer of the same tier).
    "tier_family": {"exotic_01": 2, "exotic_02": 3, "exotic_03": 1, "exotic_04": 4, "exotic_05": 5, "exotic_06": 6},
    # The PathIds of the Front Body and Rear Body paths. Here they are new saved keys.
    "explicit_path_ids": ["DeckCooling", "LightweightDeck", "LightweightNose", "NoseCanards", "SlipstreamNose", "TailStrakes"],
    "explicit_paths_are_new": True,
    # Cockpits whose stock Weight sits on the technical minimum.
    "weight_minimum_cockpits": ["exotic_05", "exotic_06"],
    # GT and EVO (mesh/INTEGRATION.md F2). F3 limits F2 on the two top kits (BODY_TRIM_STEPS says why). Kit 5:
    # every step is still at least 0.3 PI, but the tier has no room for a 3 PI set. Kit 6: shrunk, a step is under
    # 0.3 PI on its own car.
    "trim_min_step_pi": 0.3,
    "trim_set_pi": (3.0, 8.0),
    "trim_set_pi_by_kit": {},
    "trim_no_room_kits": (5,),
    "trim_shrunk_kits": (6,),
    # The two exceptions are forced by F3: this ceiling has under 3 PI of room below the next tier band.
    "trim_no_room_ceiling": ("exotic_05", "S"),
    # Similar value of the six base styles of a slot: the most the unrounded PI may spread, by cockpit tier.
    # The E limit is wider only because one half step of a stat is worth up to 1.3 PI on Spider. A slot that
    # starts empty adds its part on top of the stock total, where Spider's curve is a little steeper: Rear
    # Bumper spreads 1.14 there (shown indices still within 1).
    "body_spread_limit": {"E": 1.0, "D": 0.5, "C": 0.5, "B": 0.5, "A": 0.5, "S": 0.5},
    "body_spread_extra": {("E", "RearBumper"): 0.2},
    "body_shown_spread_limit": 1,
    # A whole foreign kit in the stock body slots moves the shown index by at most this.
    "whole_kit_shift_limit": 1,
    # All six own parts fitted: the shown index is above stock, except here (+0.2 unrounded, the index does not move).
    "full_body_equal_stock": ("exotic_06",),
    # The ceiling of a cockpit must stay in this tier and under the band of the next: (cockpit, tier, next tier).
    "ceiling_checks": [("exotic_05", "A", "S")],
    # No category cap (build_balance CROSS_FAMILY_CAP): the top cockpit is S.
    "tier_cap": None,
}

REPORT = {
    "checks_note": " (last output in `test_output.txt`)",
    "source_doc": "INTERFACE.md",
    "ladder_word": "tier",
    "held_note": "Forge and Vector have the same `Weight`, `Drag` and `BoostRecharge`, and each tier solves its own scale, so without this rule the D cockpit came out slightly heavier and draggier than the E cockpit.",
    "bar_note": ", so Gull fills every bar, as Zenith does",
    # The stock build was six body parts when the report was written; "Mesh kits" says to read three.
    "stock_body_word": "six",
    "mix_combinations": "46,656",
    "mix_legend": "Nose, Deck, Pods, Splitter, Diffuser, Wing",
    "picks_legend": "core variants (Main Turbine, Side Engines, Stabilisers, Afterburner: S, L or P) then kits (Nose, Deck, Pods, Splitter, Diffuser, Wing; `-` is empty)",
    "ceiling_history": " (Since 2026-10-03. Before, the best value per stat was also taken across the modules of a slot: a looser bound, which gave Hyper A 849 with six default body parts and would give S 852 now that the Hyper cockpit absorbs three of them.)",
    "explicit_path_word": "new",
    # The names the report uses for the cars in running text (the blockout names), by cockpit number.
    "names": {1: "Spider", 2: "Curve", 3: "Wedge", 4: "Longtail", 5: "Hyper", 6: "Gull"},
    "structure": report_structure,
    "drag_bullet": report_drag_bullet,
    "card_rating_note": report_card_rating_note,
    "trim_notes": report_trim_notes,
    "cost_notes": report_cost_notes,
    "new_paths_note": report_new_paths_note,
    "path_notes": report_path_notes,
    "cockpit_attribute_notes": report_cockpit_attribute_notes,
    "flags": report_flags,
    "deviations": report_deviations,
    "not_verified": report_not_verified,
}

CONFIG = {
    "category_id": CATEGORY_ID,
    "display_name": "Exotic",
    # Repository path of the blockout spec, and the folder under balance/ for balance.json and report.md ("": balance/ itself).
    "spec_path": "scripts/vehicle_blockouts/specs/exotic.json",
    "output_dir": "",
    "rating_reference_cockpit_id": RATING_REFERENCE_COCKPIT_ID,
    "cockpits": COCKPITS,
    "card_images": CARD_IMAGES,
    "core_slots": CORE_SLOTS,
    "body_slots": BODY_SLOTS,
    "rail_label": RAIL_LABEL,
    "body_price_by_kit": BODY_PRICE_BY_KIT,
    "body_neon_price_by_kit": BODY_NEON_PRICE_BY_KIT,
    # Kits whose cockpit has three stock body parts and three hidden slots that start empty (Exotic: the mesh kits).
    "empty_hidden_slot_kits": MESH_KITS,
    "stock_body_slots": MESH_STOCK_BODY,
    "stock_body_percent": STOCK_BODY_PERCENT,
    "body_trims": BODY_TRIMS,
    "body_trim_steps": BODY_TRIM_STEPS,
    "body_trim_min_step_pi": BODY_TRIM_MIN_STEP_PI,
    "body_trim_set_pi": BODY_TRIM_SET_PI,
    "body_trim_no_room": BODY_TRIM_NO_ROOM,
    "body_trim_shrunk": BODY_TRIM_SHRUNK,
    "character": CHARACTER,
    "body_stats": BODY_STATS,
    "new_upgrade_paths": NEW_UPGRADE_PATHS,
    # The blockout kit of a cockpit carries the car name (INTERFACE.md F5); the build refuses a spec that differs.
    "spec_kit_name_is_car_name": True,
    # No category cap: the ceiling offers a cockpit its own core family only, and is held to the Piercer of its tier.
    "cross_family_cap": None,
    # The floor rule holds the cockpit share above the kit's parts of all six body slots (see enforce_cockpit_floor).
    "floor_counts_all_body_slots": True,
    "report": REPORT,
    "test": TEST,
}
