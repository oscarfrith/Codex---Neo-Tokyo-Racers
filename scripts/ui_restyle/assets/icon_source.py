"""Single editable source for every Pulse glyph.

Each glyph is SVG markup in a 128 x 128 cell. Ink box: 16..112 (96 px, centred).
Classes:  f = white fill      s = white stroke, 10 px (the house weight)
          b = white stroke, 14 px (bare chevrons / tick / plus, which have no fill mass)
          t = text (Barlow ExtraBold, upright, set by the sheet CSS)
Helpers: F(d) fill path, S(d) stroke path, B(d) bold stroke path, C(x,y,r) disc,
         KO(shape, cut) = shape with `cut` knocked out through an SVG mask.
Edit a glyph here, run make_all.py, look at out/contact_sheet.png.
"""
import math

_mask_n = [0]


def F(d, extra=""):
    return '<path class="f" fill-rule="evenodd" d="%s" %s/>' % (d, extra)


def S(d, extra=""):
    return '<path class="s" d="%s" %s/>' % (d, extra)


def B(d):
    return '<path class="b" d="%s"/>' % d


def C(x, y, r):
    return '<circle class="f" cx="%s" cy="%s" r="%s"/>' % (x, y, r)


def RING(x, y, r, w=10):
    return '<circle class="s" cx="%s" cy="%s" r="%s" style="stroke-width:%s"/>' % (x, y, r, w)


def T(txt, size, y=None, x=64, spacing=0):
    y = 64 + size * 0.355 if y is None else y
    return ('<text class="t" x="%s" y="%.1f" font-size="%s" text-anchor="middle" letter-spacing="%s">%s</text>'
            % (x, y, size, spacing, txt))


def G(inner, transform):
    return '<g transform="%s">%s</g>' % (transform, inner)


def KO(shape, cut):
    """shape with cut removed (cut may be text, fills or strokes)."""
    _mask_n[0] += 1
    mid = "ko%d" % _mask_n[0]
    return ('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="128" height="128">'
            '<rect width="128" height="128" fill="#fff"/><g class="ko">%s</g></mask>'
            '<g mask="url(#%s)">%s</g>' % (mid, cut, mid, shape))


def _poly(pts):
    return "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"


def _star(cx, cy, ro, ri, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return _poly(pts)


def _cog(cx, cy, ro, ri, hole, teeth=8):
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for frac, r in ((-0.30, ri), (-0.17, ro), (0.17, ro), (0.30, ri)):
            pts.append((cx + r * math.cos(a + frac * step), cy + r * math.sin(a + frac * step)))
    d = _poly(pts)
    d += " M%.1f %.1f a%s %s 0 1 0 0.01 0 Z" % (cx, cy - hole, hole, hole)
    return d


# ---- reusable shapes -------------------------------------------------------
PIN = "M64 16 C43 16 30 31 30 50 C30 76 64 112 64 112 C64 112 98 76 98 50 C98 31 85 16 64 16 Z"
PIN_HOLE = " M64 37 a13 13 0 1 0 0.01 0 Z"
CAR = ("M38 28 H90 C94 28 97 30 98 34 L106 56 C110 58 112 62 112 66 V100 H96 V90 H32 V100 H16 V66 "
       "C16 62 18 58 22 56 L30 34 C31 30 34 28 38 28 Z M41 38 H87 L93 55 H35 Z "
       "M24 68 H42 V78 H24 Z M86 68 H104 V78 H86 Z")
TAXI = F("M48 16 H80 V30 H48 Z") + G(F(CAR), "translate(0 10)")
# vertical spanner, open jaw up; rotated 45 degrees when placed
SPANNER = ("M55 3.6 V28 a9 9 0 0 0 18 0 V3.6 A26 26 0 0 1 73 52.4 V116 a9 9 0 0 1 -18 0 V52.4 "
           "A26 26 0 0 1 55 3.6 Z")
SPANNER_PLACED = G(F(SPANNER), "rotate(45 64 64) translate(0 4)")
BOLT = "M74 14 L26 72 H58 L50 114 L102 54 H68 Z"
GARAGE = "M64 18 L112 52 V110 H16 V52 Z M36 62 H92 V72 H36 Z M36 80 H92 V90 H36 Z M36 98 H92 V110 H36 Z"
TAG = "M18 18 H64 L112 66 L66 112 L18 64 Z M42 32 a10 10 0 1 0 0.01 0 Z"
FLAG = ("M20 16 H32 V112 H20 Z M32 20 H108 V74 H32 Z "
        "M51 20 H70 V38 H51 Z M89 20 H108 V38 H89 Z M32 38 H51 V56 H32 Z M70 38 H89 V56 H70 Z "
        "M51 56 H70 V74 H51 Z M89 56 H108 V74 H89 Z")
PARCEL = "M16 22 H112 V44 H16 Z M22 50 H106 V108 H22 Z M52 60 H76 V72 H52 Z"
BRIEFCASE = "M16 40 H112 V106 H16 Z M48 40 V24 H80 V40 H70 V34 H58 V40 Z M16 66 H112 V72 H16 Z"
SWORD = S("M103 19 L44 84") + S("M31 72 L57 96") + S("M44 84 L24 106")
SWORDS = SWORD + G(SWORD, "translate(128 0) scale(-1 1)")
TIMER = (RING(64, 70, 36) + F("M54 16 H74 V28 H54 Z") + S("M64 72 V50", 'style="stroke-width:9"') +
         S("M94 38 L102 30", 'style="stroke-width:9"'))
NAV_ARROW = "M64 14 L104 112 L64 90 L24 112 Z"
PERSON = "M64 18 a17 17 0 1 0 0.01 0 Z M28 110 C28 80 44 62 64 62 C84 62 100 80 100 110 Z"

BUMPER_L = "M34 34 H102 a10 10 0 0 1 10 10 V86 a8 8 0 0 1 -8 8 H24 a8 8 0 0 1 -8 -8 V52 a18 18 0 0 1 18 -18 Z"
TRIGGER = "M36 16 H92 a10 10 0 0 1 10 10 V78 C102 100 86 112 64 112 C42 112 26 100 26 78 V26 a10 10 0 0 1 10 -10 Z"
DISC = C(64, 64, 47)

GLYPHS = [
    # --- row 0: navigation / places
    ("garage", F(GARAGE)),
    ("dealership", F(TAG)),
    ("customise", SPANNER_PLACED),
    ("race_flag", F(FLAG)),
    ("map", F("M16 30 L45 20 V98 L16 108 Z M52 20 L76 30 V108 L52 98 Z M83 30 L112 20 V98 L83 108 Z")),
    ("settings_cog", F(_cog(64, 64, 49, 38, 15))),
    ("controls", S("M16 34 H112 M16 64 H112 M16 94 H112", 'style="stroke-width:8"') +
        F("M72 20 H88 V48 H72 Z M34 50 H50 V78 H34 Z M66 80 H82 V108 H66 Z")),
    ("gamepad", G(F("M36 34 H92 C104 34 110 44 112 58 L116 86 C117 97 108 103 100 96 L86 82 H42 L28 96 "
                    "C20 103 11 97 12 86 L16 58 C18 44 24 34 36 34 Z "
                    "M37 46 h10 v8 h8 v10 h-8 v8 h-10 v-8 h-8 v-10 h8 Z "
                    "M82 60 a6.5 6.5 0 1 0 0.01 0 Z M96 46 a6.5 6.5 0 1 0 0.01 0 Z"),
                  "translate(64 64) scale(0.92) translate(-64 -66)")),
    # --- row 1: vehicle / people
    ("car", F(CAR)),
    ("passenger", F(PERSON)),
    ("players", F("M48 24 a15 15 0 1 0 0.01 0 Z M16 108 C16 80 30 64 48 64 C66 64 80 80 80 108 Z "
                  "M88 32 a12 12 0 1 0 0.01 0 Z M84 66 C100 64 112 78 112 108 H90 C90 90 86 78 78 70 Z")),
    ("taxi", TAXI),
    ("parcel", F(PARCEL)),
    ("exit", S("M58 22 H24 V106 H58") + S("M52 64 H102") + S("M82 42 L104 64 L82 86")),
    ("back", G(S("M44 44 H80 a24 24 0 0 1 0 48 H44") + F("M16 44 L46 20 V68 Z"), "translate(1 6)")),
    ("steering_wheel", RING(64, 64, 43) + C(64, 66, 11) + S("M24 60 H104") + S("M64 66 V104")),
    # --- row 2: race / reward
    ("trophy", F("M36 18 H92 V46 C92 64 80 74 64 74 C48 74 36 64 36 46 Z M57 72 H71 V96 H57 Z M38 96 H90 V110 H38 Z") +
        S("M38 28 H22 V38 C22 50 30 56 40 56", 'style="stroke-width:8"') +
        S("M90 28 H106 V38 C106 50 98 56 88 56", 'style="stroke-width:8"')),
    ("medal", F("M32 16 H54 L64 38 L74 16 H96 L80 54 H48 Z") + RING(64, 82, 25) + C(64, 82, 8)),
    ("star", F(_star(64, 68, 50, 21))),
    ("coin", KO(DISC, T("$", 70))),
    ("timer", TIMER),
    ("loop", S("M97.8 51.7 A36 36 0 1 1 76.3 30.2") + F("M95 37 L83 17 L70 46 Z")),
    ("laps", S("M50 38 H78 a26 26 0 0 1 0 52 H50 a26 26 0 0 1 0 -52 Z") + F("M59 76 H69 V104 H59 Z")),
    ("checkpoints", F("M16 16 H28 V112 H16 Z M100 16 H112 V112 H100 Z M28 22 H100 V34 H28 Z M28 50 H100 V62 H28 Z "
                      "M28 34 H46 V50 H28 Z M64 34 H82 V50 H64 Z")),
    # --- row 3: route / status
    ("pin", F(PIN + PIN_HOLE)),
    ("set_route", G(F(PIN + PIN_HOLE), "translate(84 16) scale(0.66) translate(-64 -16)") +
        C(27, 100, 11) + S("M44 100 H58 M68 100 H84")),
    ("route", S("M30 100 H78 a16 16 0 0 0 0 -32 H50 a16 16 0 0 1 0 -32 H98") + C(27, 100, 11) + C(101, 36, 11)),
    ("north", KO(C(64, 72, 40), T("N", 50, y=90)) + F("M64 16 L76 32 H52 Z")),
    ("boost", G(F(BOLT), "translate(64 64) scale(0.95) translate(-64 -64)")),
    ("upgrade", F("M64 16 L104 60 H80 V86 H48 V60 H24 Z M40 98 H88 V110 H40 Z")),
    ("lock", F("M26 56 H102 V112 H26 Z M64 70 a9 9 0 0 0 -4 17 V98 H68 V87 a9 9 0 0 0 -4 -17 Z") +
        S("M42 58 V43 a22 22 0 0 1 44 0 V58")),
    ("tick", B("M20 66 L50 96 L108 32")),
    # --- row 4: arrows / maths
    ("chevron_left", B("M82 22 L40 64 L82 106")),
    ("chevron_right", B("M46 22 L88 64 L46 106")),
    ("chevron_up", B("M22 82 L64 40 L106 82")),
    ("chevron_down", B("M22 46 L64 88 L106 46")),
    ("plus", B("M64 20 V108 M20 64 H108")),
    ("minus", B("M20 64 H108")),
    ("close", B("M26 26 L102 102 M102 26 L26 102")),
    ("title_mark", F("M42 18 H60 L38 110 H20 Z M68 18 H86 L64 110 H46 Z M94 18 H112 L90 110 H72 Z")),
    # --- row 5: notices / misc
    ("warning", F("M64 17 L112 108 H16 Z M58 46 H70 V78 H58 Z M58 86 H70 V98 H58 Z")),
    ("info", KO(DISC, '<path class="f" d="M57 30 H71 V44 H57 Z M57 54 H71 V98 H57 Z"/>')),
    ("duel", SWORDS),
    ("paint", G(F("M55 4 H73 V66 H55 Z M50 74 H78 V90 C78 106 64 112 64 126 C64 112 50 106 50 90 Z"),
                "rotate(45 64 64)")),
    ("keycap_blank", '<rect class="f" x="18" y="18" width="92" height="92" rx="16"/>'),
    ("dpad", F("M46 16 H82 V46 H112 V82 H82 V112 H46 V82 H16 V46 H46 Z M64 54 a10 10 0 1 0 0.01 0 Z")),
    ("pad_select", KO(DISC, '<path class="f" d="M36 44 H74 V72 H36 Z"/>'
                            '<path class="s" style="stroke-width:7" d="M82 56 H90 V84 H52 V78"/>')),
    ("pad_start", KO(DISC, '<path class="s" style="stroke-width:8" d="M38 46 H90 M38 64 H90 M38 82 H90"/>')),
    # --- row 6: gamepad buttons
    ("pad_a", KO(DISC, T("A", 62))),
    ("pad_b", KO(DISC, T("B", 62))),
    ("pad_x", KO(DISC, T("X", 62))),
    ("pad_y", KO(DISC, T("Y", 62))),
    ("pad_lb", KO(F(BUMPER_L), T("LB", 46, y=81))),
    ("pad_rb", KO(G(F(BUMPER_L), "translate(128 0) scale(-1 1)"), T("RB", 46, y=81))),
    ("pad_lt", KO(F(TRIGGER), T("LT", 46, y=76))),
    ("pad_rt", KO(F(TRIGGER), T("RT", 46, y=76))),
]

PURPOSE = {
    "controls": "settings sliders (HUD nav); the CONTROLS button uses gamepad",
    "dealership": "price tag", "customise": "spanner",
    "title_mark": "three slashes before a screen title (Pink)",
    "pad_select": "View / Select", "pad_start": "Menu / Start",
    "keycap_blank": "square key; wide keys use keycap_9slice.png",
    "north": "minimap north marker", "steering_wheel": "DRIVE button",
    "passenger": "also single player / profile",
}


# ---- map icons: white badge with the glyph knocked out ---------------------
# Shape codes the family; the colour role is applied at run time.
#   circle = activity, rounded square = place, hexagon = job,
#   pin = destination (tip at y = 118, the existing PinTipY 0.9219)
def _badge_circle():
    return C(64, 64, 52)


def _badge_square():
    return '<rect class="f" x="12" y="12" width="104" height="104" rx="18"/>'


def _badge_hex():
    pts = [(64 + 56 * math.cos(math.radians(a)), 64 + 56 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    return F(_poly(pts))


def _badge_pin():
    return F("M64 8 C36 8 18 28 18 52 C18 84 64 118 64 118 C64 118 110 84 110 52 C110 28 92 8 64 8 Z")


def _in(glyph, scale, cy=64):
    return G(glyph, "translate(64 %s) scale(%s) translate(-64 -64)" % (cy, scale))


MAP_ICONS = [
    ("Race", KO(_badge_circle(), _in(F(FLAG), 0.62))),
    ("TimeTrial", KO(_badge_circle(), _in(TIMER, 0.66, 63))),
    ("Duel", KO(_badge_circle(), _in(SWORDS, 0.64))),
    ("Job", KO(_badge_hex(), _in(F(BRIEFCASE), 0.6, 62))),
    ("TaxiFare", KO(_badge_hex(), _in(TAXI, 0.62))),
    ("CourierPickup", KO(_badge_hex(), _in(F(PARCEL), 0.6))),
    ("TaxiDrop", KO(_badge_pin(), _in(TAXI, 0.5, 50))),
    ("CourierDrop", KO(_badge_pin(), _in(F(PARCEL), 0.48, 51))),
    ("Customisation", KO(_badge_square(), _in(SPANNER_PLACED, 0.68))),
    ("Dealership", KO(_badge_square(), _in(F(TAG), 0.64))),
    ("Garage", KO(_badge_square(), _in(F(GARAGE), 0.64, 62))),
    ("Waypoint", KO(_badge_pin(), C(64, 52, 18))),
    ("Player", F(NAV_ARROW)),
    ("OtherPlayer", C(64, 64, 20) + RING(64, 64, 36, 8)),
]
