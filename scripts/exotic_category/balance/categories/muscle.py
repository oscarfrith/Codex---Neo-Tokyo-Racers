"""Modern Muscle category: the tables build_balance.py and test_balance.py read (CONFIG at the end).

    py -3 scripts/exotic_category/balance/build_balance.py --category muscle
    py -3 scripts/exotic_category/balance/test_balance.py --category muscle

Heavy and powerful. The category tops out at tier B: no build of any Muscle car may reach A
(CROSS_FAMILY_CAP). Structure, attribute sets, donors, variant rules, cost guides and core NeonPrice
are the Exotic ones. This file must not import build_balance.
"""
from . import exotic

# ---------------------------------------------------------------------------
# Contract tables
# ---------------------------------------------------------------------------

CATEGORY_ID = "muscle"
RATING_REFERENCE_COCKPIT_ID = "muscle_04"

# N, CockpitId, model, DisplayName, spec cockpit, spec kit, kit name, tier, price, target PI, Piercer reference.
# The names are placeholders: the blockout cockpit names. The kit name is the car name (the Exotic F5 rule);
# the blockout kits have other names (Trans-Am, Restomod, Pony, Pro Street, Classic, Modern), so the spec is
# only used for the module display names (SPEC_KIT_NAME_IS_CAR_NAME is False).
# Two cars share a Piercer reference in D and in C. The category has no A or S car.
# muscle_06: the highest target in steps of 5 from 650 down to 610 for which the cap holds with an EVO set
# worth at least 3 PI on that car. That is 630 (cross-family ceiling 717.90, limit 721.49). With the steps
# below, 650, 645, 640 and 635 give ceilings of 734.22, 730.13, 726.05 and 721.98. 635 holds (721.46) only
# with kit 5 cut to a set worth 3.8 PI on its own car, under its 4 PI floor, so it is not used.
# The other five targets are fixed by the contract.
COCKPITS = [
    (1, "muscle_01", "COCKPIT_MUSCLE_01", "Notch", "notch", "transam", "Notch", "E", 32000, 230, "bruiser_02"),
    (2, "muscle_02", "COCKPIT_MUSCLE_02", "Ute", "ute", "restomod", "Ute", "D", 85000, 330, "bruiser_03"),
    (3, "muscle_03", "COCKPIT_MUSCLE_03", "Ragtop", "ragtop", "pony", "Ragtop", "D", 110000, 410, "bruiser_03"),
    (4, "muscle_04", "COCKPIT_MUSCLE_04", "Hardtop", "hardtop", "prostreet", "Hardtop", "C", 240000, 480, "bruiser_01"),
    (5, "muscle_05", "COCKPIT_MUSCLE_05", "Fastback", "fastback", "classic", "Fastback", "C", 310000, 565, "bruiser_01"),
    (6, "muscle_06", "COCKPIT_MUSCLE_06", "Modern", "modern", "modern", "Modern", "B", 850000, 630, "bruiser_04"),
]
COCKPITS = [dict(zip(exotic.COCKPIT_FIELDS, row)) for row in COCKPITS]
# No card images yet: MenuImage and PreviewImage are empty strings.
CARD_IMAGES = {}

# SlotId -> (id stem, donor stem, ModuleFolder, ModuleType, ModuleSlot, EnginePosition, RearEngine)
CORE_SLOTS = {
    "Engine1": ("MODULE_ENGINE_MUSCLE", "MODULE_ENGINE_BRUISER", "Engines", "Engine", "Engine", "Front", False),
    "Engine2": ("MODULE_ENGINE_B_MUSCLE", "MODULE_ENGINE_B_BRUISER", "Engines_B", "Engine", "Engine", "Rear", True),
    "Stabilisers": ("MODULE_STABILISER_MUSCLE", "MODULE_STABILISER_BRUISER", "Stabilisers", "Stabilisers", "Stabilisers", None, None),
    "Boost": ("MODULE_BOOST_MUSCLE", "MODULE_BOOST_BRUISER", "Boost", "Boost", "Boost", None, None),
}

# SlotId -> (id stem, live accessory donor, ModuleFolder)
BODY_SLOTS = {
    "FrontBody": ("MODULE_FRONTBODY_MUSCLE", "MODULE_FRONTBUMPER_LVL1", "FrontBodies"),
    "RearBody": ("MODULE_REARBODY_MUSCLE", "MODULE_REARBUMPER_LVL1", "RearBodies"),
    "SidePods": ("MODULE_SIDEPODS_MUSCLE", "MODULE_SIDEPODS_LVL1", "SidePods"),
    "FrontBumper": ("MODULE_FRONTBUMPER_MUSCLE", "MODULE_FRONTBUMPER_LVL1", "FrontBumpers"),
    "RearBumper": ("MODULE_REARBUMPER_MUSCLE", "MODULE_REARBUMPER_LVL1", "RearBumpers"),
    "RearSpoiler": ("MODULE_REARSPOILER_MUSCLE", "MODULE_REARSPOILER_LVL1", "RearSpoilers"),
}

# Price of a body part of the three hidden slots (SidePods, FrontBumper, RearBumper), by kit. The three stock
# body slots are priced from the kit's core variant price V (12% of the cockpit price): base V / 4, GT V / 2, EVO V.
BODY_PRICE_BY_KIT = [5000, 7000, 8000, 10000, 12000, 16000]
BODY_NEON_PRICE_BY_KIT = [6500, 7000, 7000, 7500, 7500, 8000]

# All six cockpits: three stock body parts (Front Body, Rear Body, Wing); Side Pods, Splitter and Diffuser
# declare no default, start empty and are absorbed by the cockpit.
EMPTY_HIDDEN_SLOT_KITS = (1, 2, 3, 4, 5, 6)

# One stat step of a trim, by slot and kit. GT adds one step to its base part and EVO two. The stat pairs are
# the Exotic ones. Front Body: Downforce and SteeringResponse. Rear Body: less Weight and EngineOutput.
# Wing: Downforce and LateralGrip.
#
# Size: a full EVO set (the three EVO parts of a kit on its own car, against the three base parts) adds 4 to
# 6 PI on cars 01 to 05 and at least 3 PI on car 06, and every single step at least 0.3 PI on its own car.
# A flat stat is worth less the faster the car, so the steps grow with the kit.
#
# The cap limits the steps: any owned part fits any Muscle car, so the EVO parts of every kit are options
# on muscle_06, whose cross-family ceiling must stay at or under CROSS_FAMILY_CAP["limit"]. Kit 6 carries
# the kit 5 steps: larger steps would not raise the set on muscle_06 much, and they are what the ceiling pays for.
# Sets with these steps (EVO set on the kit's own car): 5.16, 4.59, 5.02, 4.96, 4.76, 3.84 PI.
BODY_TRIM_STEPS = {
    "FrontBody": {
        1: {"Downforce": 0.5, "SteeringResponse": 0.25},
        2: {"Downforce": 1, "SteeringResponse": 0.25},
        3: {"Downforce": 0.5, "SteeringResponse": 0.5},
        4: {"Downforce": 1, "SteeringResponse": 0.5},
        5: {"Downforce": 1, "SteeringResponse": 0.75},
        6: {"Downforce": 1, "SteeringResponse": 0.75},
    },
    "RearBody": {
        1: {"Weight": -0.5, "EngineOutput": 0.25},
        2: {"Weight": -0.5, "EngineOutput": 0.25},
        3: {"Weight": -0.5, "EngineOutput": 0.5},
        4: {"Weight": -0.5, "EngineOutput": 0.5},
        5: {"Weight": -0.5, "EngineOutput": 0.75},
        6: {"Weight": -0.5, "EngineOutput": 0.75},
    },
    "RearSpoiler": {
        1: {"Downforce": 0.5, "LateralGrip": 0.25},
        2: {"Downforce": 0.75, "LateralGrip": 0.25},
        3: {"Downforce": 1, "LateralGrip": 0.25},
        4: {"Downforce": 1, "LateralGrip": 0.5},
        5: {"Downforce": 1, "LateralGrip": 0.5},
        6: {"Downforce": 1, "LateralGrip": 0.5},
    },
}
BODY_TRIM_MIN_STEP_PI = 0.3
BODY_TRIM_SET_PI = (3.0, 8.0)   # three EVO parts on the stock car of their kit; TEST narrows it per kit
BODY_TRIM_NO_ROOM = ()
BODY_TRIM_SHRUNK = ()

# ---------------------------------------------------------------------------
# Balance design
# ---------------------------------------------------------------------------

# Muscle character against the Piercer reference. Applied to the Piercer stock profile before the scale
# is solved. Everything else is 1.0.
CHARACTER = {
    "TopSpeed": 1.10,          # up
    "EngineOutput": 1.18,      # up: the class headline
    "BoostForce": 1.20,        # up: a hard shove
    "Weight": 1.20,            # heavier
    "LateralGrip": 0.72,       # down: it does not want to turn
    "SteeringResponse": 0.75,  # down
    "Downforce": 0.75,         # down
    "BrakingForce": 0.90,      # down: heavy to stop
    "BoostDuration": 0.85,     # down: short bursts
}

# Body modules: placeholder stats. The Exotic table is reused by kit number (same LVL1 size, same stat
# families per slot); the flavour text is not, because it describes Exotic parts. Replace both when the
# Muscle parts are designed.
BODY_STATS = {slot: {n: ("Placeholder: the stats of the Exotic kit %d part of this slot." % n, dict(stats))
                     for n, (_, stats) in kits.items()}
              for slot, kits in exotic.BODY_STATS.items()}

# Front Body and Rear Body upgrade paths: the six Exotic path definitions and PathIds, reused (as Exotic
# reuses the Piercer accessory paths by donor). They are not new saved keys.
NEW_UPGRADE_PATHS = exotic.NEW_UPGRADE_PATHS

# The category cap. tier: the highest tier any build may reach. limit: the highest unrounded index the
# cross-family ceiling of any cockpit may have. The shown index of the next tier (A, band 725) starts at an
# unrounded 724.495, and the limit keeps 3 PI under that.
CROSS_FAMILY_CAP = {"tier": "B", "limit": 721.49}


# ---------------------------------------------------------------------------
# Report text (build_balance.write_report asks for it by key). E is the report environment.
# ---------------------------------------------------------------------------

def report_structure(E):
    B = E.B
    full = "; ".join("%s %s %d (stock %d)" % (c["id"], E.analysis["category"][c["id"]]["FULL_BODY"]["Overall"]["Tier"],
                                              E.analysis["category"][c["id"]]["FULL_BODY"]["Overall"]["PerformanceIndex"],
                                              E.cockpits[c["id"]]["stockPI"]) for c in B.COCKPITS)
    return [
        "## Structure",
        "",
        "The structure is the Exotic one, with the Muscle ids (`categories/muscle.py`).",
        "",
        "- **Six cockpits, 144 modules**: 72 core modules (four slots, three variants), 36 base body parts and 36 GT and EVO body parts.",
        "- **Stock build**: cockpit + four Standard core modules + three body defaults (Front Body, Rear Body, Wing). `SidePods`, `FrontBumper` and `RearBumper` declare no default and start empty. Fitting them adds stats on top of the stock total. With all six own-kit parts: %s." % full,
        "- **GT and EVO**: `_GT` and `_EVO` of the Front Body, Rear Body and Wing of every kit. GT adds one stat step to its base part and EVO two (section 6a). The base part costs a quarter of the kit's core variant price, GT half and EVO the whole of it.",
        "- **Every body part is locked to the cockpit of its kit** (`SourceCockpitId`). Once owned, a part fits any Muscle car, and so does a core module of another Muscle family. The cap proof below covers both.",
        "- **Names are placeholders**: the cars carry the blockout cockpit names, and the kit of a car carries the car name. The module names come from `scripts/vehicle_blockouts/specs/muscle.json`.",
        "- **No card images**: `MenuImage` and `PreviewImage` are empty strings.",
        "",
        B.table(["ModuleId", "Name", "Price", "NeonPrice"], B.trim_id_rows(E.modules)),
        "",
    ]


def report_cap_notes(E):
    B = E.B
    first, last = B.COCKPITS[0], B.COCKPITS[-1]
    found = E.analysis["category"][first["id"]]["CAP_MAX"][0]["Overall"]
    return [
        "- **%s target**: %d. The contract asks for the highest target in steps of 5 from 650 down to 610 that holds the cap with an EVO set worth at least 3 PI on that car. Tried with these trim steps (recorded 2026-10-04, not recomputed here): 650 gives a ceiling of 734.22, 645 gives 730.13, 640 gives 726.05 and 635 gives 721.98, all over the limit of %s. At 635 the cap holds (721.46) only if the kit 5 steps are cut to a set worth 3.8 PI on %s and the kit 6 steps to a set worth 3.0 PI on %s: under the 4 PI floor of kit 5. %d is the first target that holds." % (
            last["id"], last["target"], B.fmt(B.CROSS_FAMILY_CAP["limit"]), B.COCKPITS[4]["name"], last["name"], last["target"]),
        "- For information: the cheapest car, %s, with the best cross-family build found rates %s %d (stock %s %d). Its own cockpit holds it far under the cap." % (
            first["name"], found["Tier"], found["PerformanceIndex"], E.cockpits[first["id"]]["stockTier"], E.cockpits[first["id"]]["stockPI"]),
    ]


def report_body_note(E):
    return ["**The body stats are placeholders.** They are the Exotic table, reused by kit number: the same LVL1 size and the same stat families per slot. That table was balanced on the Exotic totals. A Muscle car has less grip, steering and downforce, so the same flat stat is worth more here and the styles of a slot differ more than on Exotic (`body_spread_limit` in `categories/muscle.py`). Retune with the real parts.", ""]


def report_drag_bullet(E):
    worst = max(-E.analysis["drag_plus_one"][c["id"]] for c in E.B.COCKPITS)
    return "- **No body part carries `Drag`.** The reused table has none, and the live LVL1 accessories carry none either. +1 Drag would cost %.2f PI or less on every Muscle car." % E.B.under(worst)


def report_card_rating_note(E):
    B = E.B
    reference = next(c for c in B.COCKPITS if c["id"] == B.RATING_REFERENCE_COCKPIT_ID)
    return "\"Card rating\" is the module card rating (`RatingReferenceCockpitId=%s`): the PI of a stock %s with that part swapped in, or added where the slot starts empty. The \"On\" columns are the PI of each stock car with only this part swapped or added (its own stock part gives its stock PI)." % (
        reference["id"], reference["name"])


def report_cost_notes(E):
    B = E.B
    first = B.COCKPITS[0]
    return [
        "- The Piercer figure includes four LVL3 accessories at 19,000 each. The three Muscle stock body parts come with the cockpit.",
        "- Body and Standard upgrade guides do not scale with the cockpit (live pattern). On %s a Standard engine point (6,050) costs more than a Lightweight engine (%s)." % (
            first["name"], B.fmt(first["price"] * 12 // 100)),
        "- A full Lightweight build costs the same as a full Power build apart from the upgrade choice. Neon is extra: `NeonPrice` per module.",
    ]


def path_findings(E):
    """(lowest gain of a reused path, cloned paths worth nothing at stock, cloned paths that lower PI at stock)."""
    B = E.B
    lowest, dead, harmful = None, [], []
    for slot in B.BODY_ORDER:
        for this_id, entry in E.analysis["path_worth"][slot].items():
            if entry["new"]:
                value = min(entry["gain"].values())
                lowest = value if lowest is None else min(lowest, value)
                continue
            zero = [c["name"] for c in B.COCKPITS if abs(entry["gain"][c["id"]]) < 0.005]
            down = ["%s %.1f" % (c["name"], entry["gain"][c["id"]]) for c in B.COCKPITS if entry["gain"][c["id"]] <= -0.005]
            if zero:
                dead.append("%s `%s` on %s" % (B.RAIL_LABEL[slot], this_id, " and ".join(zero)))
            if down:
                harmful.append("%s `%s` (%s)" % (B.RAIL_LABEL[slot], this_id, ", ".join(down)))
    return lowest, dead, harmful


def report_path_notes(E):
    lowest, dead, harmful = path_findings(E)
    return [
        "- The six reused paths gain PI on every Muscle car (the lowest is %+.2f for three points). None carries `Drag`." % lowest,
        "- The cloned paths are the live Piercer accessory paths, unchanged. Worth nothing at stock: %s. Lower PI at stock: %s." % (
            "; ".join(dead) if dead else "none", "; ".join(harmful) if harmful else "none"),
    ]


def report_cockpit_attribute_notes(E):
    names = sorted(E.cockpits[E.B.COCKPITS[0]["id"]]["attributes"])
    return [
        "Cockpits carry the %d non-colour attributes of the live Piercer cockpit plus three new names (`DefaultFrontBodyModuleId`, `DefaultRearBodyModuleId`, `DefaultRearSpoilerModuleId`; %d in all): %s." % (
            len(names) - 3, len(names), ", ".join("`%s`" % name for name in names)),
        "",
        "A slot that starts empty has no default attribute.",
        "",
        "Not in `balance.json`: the six `Default*Color` attributes (Color3, a paint decision) and the seat offsets. `MenuImage` and `PreviewImage` are empty strings. Legacy cockpit values `Acceleration=70`, `Handling=30`, `Drift=0`, `Braking=100`, `Boost=0`, `Power=40` are the constants on all six live cockpits.",
    ]


def report_flags(E):
    B = E.B
    last = B.COCKPITS[-1]
    row = E.analysis["category"][last["id"]]
    ceiling = row["CAP_CEILING"]["Overall"]
    held = ["%s `%s`" % (c["name"], "`, `".join(E.design[c["id"]]["held_by_tier_below"])) for c in B.COCKPITS if E.design[c["id"]]["held_by_tier_below"]]
    swap = E.analysis["family_swap"]
    flags = [
        "**The category tops out at tier %s.** No build of any Muscle car reaches the next tier, with any Muscle module in any slot (Cap proof). The highest ceiling is %s at %.2f; the next tier starts at 724.495." % (
            B.CROSS_FAMILY_CAP["tier"], last["name"], ceiling["UnroundedPerformanceIndex"]),
        "**%s is %d, not 650.** The cap decides it (Cap proof). A fully upgraded %s tops out at %s %d (highest build found)." % (
            last["name"], last["target"], last["name"], row["CAP_MAX"][0]["Overall"]["Tier"], row["CAP_MAX"][0]["Overall"]["PerformanceIndex"]),
        "**The cap covers Muscle modules only.** A module of another category is not an option in these searches. If modules ever cross categories, the proof has to be redone.",
        "**Body stats and names are placeholders.** The body stats are the Exotic table by kit number (section 6). The car names are the blockout cockpit names.",
        "**Totals held at the car below:** %s. The stock PI still lands on the target (section 3)." % ("; ".join(held) if held else "none"),
        "**Two cars per Piercer reference in D and C.** Ute and Ragtop clone the Vector upgrade paths, Hardtop and Fastback the Viper ones. All live core modules of one type carry the same paths, so this changes nothing today.",
        "**Core modules move between cars, as on Piercer.** %s with the %s Standard set rates %s %d and with the Power set %s %d (section 8). That is inside the cap." % (
            B.COCKPITS[0]["name"], last["name"], swap["category"]["Tier"], swap["category"]["PerformanceIndex"],
            swap["category_power"]["Tier"], swap["category_power"]["PerformanceIndex"]),
        "**Three variants share one `DisplayName`** (the spec display name). Any text that shows only the name cannot tell Standard from Power.",
        "**Road feel is not proven by the rating.** The heavy, low-grip character is a rating profile here. Check in Play.",
    ]
    return ["- " + flag for flag in flags]


REPORT = {
    "checks_note": "",
    "source_doc": "the contract (`categories/muscle.py`)",
    "ladder_word": "car",
    "held_note": "Two cars share a Piercer profile in D and in C, and each car solves its own scale. The lower car of a pair is scaled down from its Piercer, which alone would leave it heavier or slower to recharge than the cheaper car below it.",
    "bar_note": "",
    "stock_body_word": "three",
    "mix_combinations": "216",
    "mix_legend": "Front Body, Rear Body, Wing",
    "picks_legend": "core variants (Front Engine, Rear Engine, Drift Thrusters, Overdrive: S, L or P) then one character per body slot (Front Body, Rear Body, Side Pods, Splitter, Diffuser, Wing: the kit number of a base part, `T` for a GT part, `O` for an EVO part, `-` for empty)",
    "ceiling_history": "",
    "explicit_path_word": "Exotic path, reused",
    # The names the report uses for the cars in running text, by cockpit number.
    "names": {cockpit["n"]: cockpit["name"] for cockpit in COCKPITS},
    "structure": report_structure,
    "cap_notes": report_cap_notes,
    "body_note": report_body_note,
    "drag_bullet": report_drag_bullet,
    "card_rating_note": report_card_rating_note,
    "trim_notes": [
        "- Each kit's steps are sized on its own car: a full EVO set adds 4 to 6 PI on cars 01 to 05 and at least 3 PI on car 06, and every single step at least 0.3 PI. A flat stat is worth less the faster the car, so the steps grow with the kit.",
    ],
    "cost_notes": report_cost_notes,
    "new_paths_note": "Front Body and Rear Body carry explicit `upgradePaths`, the same on all six parts of the slot. They are the six Exotic paths with the Exotic `PathId`s, reused as the contract asks (as Exotic reuses the Piercer accessory paths by donor). They are not new saved keys. None is a live Piercer `PathId` or a legacy upgrade id.",
    "path_notes": report_path_notes,
    "cockpit_attribute_notes": report_cockpit_attribute_notes,
    "flags": report_flags,
    "deviations": [
        "- **muscle_06 target.** 630, chosen by the cap rule (Cap proof). The other five targets are the contract's.",
        "- **Kit names.** The blockout kits are named Trans-Am, Restomod, Pony, Pro Street, Classic and Modern. The contract makes the kit name the car name, so `Tier` on a body part is the car name and the spec is read for module names only.",
        "- **Body stats.** The Exotic table is reused unchanged, as the contract asks. It is not similar-value on the Muscle totals to the Exotic limits, so the Muscle limits are wider (section 6).",
        "- **Floor rule.** The cockpit share has to cover the three stock body parts, which is what the cockpit carries. Exotic still counts all six parts of the kit; the Exotic table does not fit under the Muscle grip and downforce shares that way.",
        "- **Character.** A Muscle car is not at the PI of its Piercer reference, so the character is checked against the Piercer total moved by the car's own scale, not against the Piercer total as it is.",
        "- **Ladder rule.** A lower-is-better total is never worse than on the car below (section 3).",
        "- **No card images.** `MenuImage` and `PreviewImage` are on the donor cockpit, so they are written as empty strings, not left out.",
    ],
    "not_verified": [
        "- Nothing was installed or driven. On-road speed and feel are open for Play.",
        "- The port was not run against the live Luau modules (no gameplay module may be required through MCP).",
        "- The \"highest build found\" columns are searches. The cap and the tier statement in section 7 rest on the ceilings, which are bounds.",
        "- \"Similar overall value\" is measured as PI, on placeholder stats.",
    ],
}

# ---------------------------------------------------------------------------
# What test_balance.py holds this category to. Written out again on purpose: the tests compare the
# generated data with these values, not with the tables above.
# ---------------------------------------------------------------------------

TEST = {
    # No interface document and no mesh data yet: the contract is this file.
    "interface_path": None,
    "mesh_data_path": None,
    "mesh_module_count": None,
    "body_prices": [5000, 7000, 8000, 10000, 12000, 16000],
    "body_neon": [6500, 7000, 7000, 7500, 7500, 8000],
    "stock_body_base_price": {1: 960, 2: 2550, 3: 3300, 4: 7200, 5: 9300, 6: 25500},
    "core_variant_price": {1: 3840, 2: 10200, 3: 13200, 4: 28800, 5: 37200, 6: 102000},
    "trim_prices": {1: {"GT": 1920, "EVO": 3840}, 2: {"GT": 5100, "EVO": 10200}, 3: {"GT": 6600, "EVO": 13200},
                    4: {"GT": 14400, "EVO": 28800}, 5: {"GT": 18600, "EVO": 37200}, 6: {"GT": 51000, "EVO": 102000}},
    # Cockpit price: strictly below the Piercer and the Exotic cockpit of the same tier, rising with the
    # target PI, and the cars in "affordable" at or below the starting Cash.
    "price_rule": {"kind": "below_same_tier",
                   "piercer": {"E": 40000, "D": 120000, "C": 350000, "B": 1100000},
                   "exotic": {"E": 50000, "D": 150000, "C": 440000, "B": 1400000},
                   "starting_cash": 140000, "affordable": ("muscle_01", "muscle_02", "muscle_03")},
    # Character: a Muscle car is not at the PI of its Piercer reference, so each total is compared with the
    # Piercer total moved by the car's solved scale (x scale for higher-is-better, / scale for Weight).
    "character": {"kind": "relative", "up": ("EngineOutput", "BoostForce", "TopSpeed"),
                  "down": ("LateralGrip", "SteeringResponse", "Downforce", "BrakingForce", "BoostDuration"),
                  "weight": "heavier"},
    "ladder_strict": True,
    "tier_family": {"muscle_01": 2, "muscle_02": 3, "muscle_03": 3, "muscle_04": 1, "muscle_05": 1, "muscle_06": 4},
    # The Exotic PathIds, reused.
    "explicit_path_ids": ["DeckCooling", "LightweightDeck", "LightweightNose", "NoseCanards", "SlipstreamNose", "TailStrakes"],
    "explicit_paths_are_new": False,
    "weight_minimum_cockpits": [],
    "trim_min_step_pi": 0.3,
    "trim_set_pi": (3.0, 8.0),
    "trim_set_pi_by_kit": {1: (4.0, 6.0), 2: (4.0, 6.0), 3: (4.0, 6.0), 4: (4.0, 6.0), 5: (4.0, 6.0)},
    "trim_no_room_kits": (),
    "trim_shrunk_kits": (),
    "trim_no_room_ceiling": None,
    # Similar value of the six base styles of a slot. The body stats are the Exotic table, a placeholder that
    # was balanced on the Exotic totals, so the Exotic limits (E 1.0, the rest 0.5) do not hold on the E, D and
    # C cars. These limits are what the placeholder gives, rounded up (measured: E 1.38, D 0.91, C 0.58, B 0.38).
    # Bring them back to the Exotic limits when the Muscle body stats are designed.
    "body_spread_limit": {"E": 1.5, "D": 1.0, "C": 0.6, "B": 0.5, "A": 0.5, "S": 0.5},
    "body_spread_extra": {},
    "body_shown_spread_limit": 2,
    # A whole foreign kit in the stock body slots moves the shown index by at most this (Exotic: 1).
    "whole_kit_shift_limit": 2,
    "full_body_equal_stock": (),
    "ceiling_checks": [],
    # The category cap, written out again: the highest tier and the highest unrounded cross-family ceiling.
    "tier_cap": {"tier": "B", "limit": 721.49},
}

CONFIG = {
    "category_id": CATEGORY_ID,
    "display_name": "Modern Muscle",
    "spec_path": "scripts/vehicle_blockouts/specs/muscle.json",
    "output_dir": "muscle",
    "rating_reference_cockpit_id": RATING_REFERENCE_COCKPIT_ID,
    "cockpits": COCKPITS,
    "card_images": CARD_IMAGES,
    "core_slots": CORE_SLOTS,
    "body_slots": BODY_SLOTS,
    "rail_label": exotic.RAIL_LABEL,
    "body_price_by_kit": BODY_PRICE_BY_KIT,
    "body_neon_price_by_kit": BODY_NEON_PRICE_BY_KIT,
    "empty_hidden_slot_kits": EMPTY_HIDDEN_SLOT_KITS,
    "stock_body_slots": exotic.MESH_STOCK_BODY,
    "stock_body_percent": exotic.STOCK_BODY_PERCENT,
    "body_trims": exotic.BODY_TRIMS,
    "body_trim_steps": BODY_TRIM_STEPS,
    "body_trim_min_step_pi": BODY_TRIM_MIN_STEP_PI,
    "body_trim_set_pi": BODY_TRIM_SET_PI,
    "body_trim_no_room": BODY_TRIM_NO_ROOM,
    "body_trim_shrunk": BODY_TRIM_SHRUNK,
    "character": CHARACTER,
    "body_stats": BODY_STATS,
    "new_upgrade_paths": NEW_UPGRADE_PATHS,
    "spec_kit_name_is_car_name": False,
    "cross_family_cap": CROSS_FAMILY_CAP,
    # The floor rule holds the cockpit share above the three stock body parts, which are what the cockpit carries.
    # (The Exotic placeholder table is too large for the low Muscle grip and downforce shares if all six count.)
    "floor_counts_all_body_slots": False,
    "report": REPORT,
    "test": TEST,
}
