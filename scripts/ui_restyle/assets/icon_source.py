"""Single editable source for every Pulse glyph (second pass, 2026-10-09).

Each glyph is SVG markup in a 128 x 128 cell. Ink box: 16..112 (96 px, centred).
House rules for the family:
  * pure white on transparent, tinted at run time
  * one line weight: 9 px (class s). Bare chevrons / tick / plus / close, which have no filled
    mass, use the bold weight 13 px (class b) so they carry at 24 px
  * square, mitred joins and butt caps; boxes get a small chamfer (CR) instead of a radius
  * filled masses where a solid reads better at 24 px; inner detail is cut out at 7 to 8 px so it
    survives the downscale
  * motion glyphs (race_flag, car, drift, gauge needle, boost) lean forward about 8 degrees (SL)
Classes:  f = white fill   s = 9 px stroke   b = 13 px stroke   t = text (Barlow ExtraBold upright)
Helpers:  F(d) fill path, S(d, w) stroke path, B(d) bold stroke path, C(x,y,r) disc, RING,
          CR(...) chamfered box path, SL(markup) forward slant,
          KO(shape, cut) = shape with `cut` knocked out through an SVG mask.
Names and cell order are stable: new glyphs are appended at the end only.
Edit a glyph here, run make_all.py, look at out/contact_sheet_icons.png.
"""
import math

_mask_n = [0]
STROKE = 9
BOLD = 13


def F(d, extra=""):
    return '<path class="f" fill-rule="evenodd" d="%s" %s/>' % (d, extra)


def S(d, w=None, extra=""):
    st = ' style="stroke-width:%s"' % w if w else ""
    return '<path class="s" d="%s"%s %s/>' % (d, st, extra)


def B(d):
    return '<path class="b" d="%s"/>' % d


def C(x, y, r):
    return '<circle class="f" cx="%s" cy="%s" r="%s"/>' % (x, y, r)


def RING(x, y, r, w=STROKE):
    return '<circle class="s" cx="%s" cy="%s" r="%s" style="stroke-width:%s"/>' % (x, y, r, w)


def T(txt, size, y=None, x=64, spacing=0):
    y = 64 + size * 0.355 if y is None else y
    return ('<text class="t" x="%s" y="%.1f" font-size="%s" text-anchor="middle" letter-spacing="%s">%s</text>'
            % (x, y, size, spacing, txt))


def G(inner, transform):
    return '<g transform="%s">%s</g>' % (transform, inner)


def SL(inner, deg=8, cy=64):
    """Forward (italic) slant about the row y = cy."""
    return G(inner, "translate(0 %s) skewX(-%s) translate(0 -%s)" % (cy, deg, cy))


def KO(shape, cut):
    """shape with cut removed (cut may be text, fills or strokes)."""
    _mask_n[0] += 1
    mid = "ko%d" % _mask_n[0]
    return ('<mask id="%s" maskUnits="userSpaceOnUse" x="-64" y="-64" width="256" height="256">'
            '<rect x="-64" y="-64" width="256" height="256" fill="#fff"/><g class="ko">%s</g></mask>'
            '<g mask="url(#%s)">%s</g>' % (mid, cut, mid, shape))


def CLIP(shape, clip_d):
    _mask_n[0] += 1
    cid = "cp%d" % _mask_n[0]
    return '<clipPath id="%s"><path d="%s"/></clipPath><g clip-path="url(#%s)">%s</g>' % (cid, clip_d, cid, shape)


def _poly(pts):
    return "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"


def CR(x0, y0, x1, y1, c=6, k="tl tr br bl"):
    """Box with chamfered corners (the family's corner treatment). k lists the corners to cut."""
    k = k.split()
    p = []
    p += [(x0 + c, y0)] if "tl" in k else [(x0, y0)]
    p += [(x1 - c, y0), (x1, y0 + c)] if "tr" in k else [(x1, y0)]
    p += [(x1, y1 - c), (x1 - c, y1)] if "br" in k else [(x1, y1)]
    p += [(x0 + c, y1), (x0, y1 - c)] if "bl" in k else [(x0, y1)]
    if "tl" in k:
        p.append((x0, y0 + c))
    return _poly(p)


def _star(cx, cy, ro, ri, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return _poly(pts)


def _cog(cx, cy, ro, ri, hole, teeth=8):
    """Cog with tapered teeth: root wider than tip."""
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a = i * step - math.pi / 2
        for frac, r in ((-0.31, ri), (-0.19, ro), (0.19, ro), (0.31, ri)):
            pts.append((cx + r * math.cos(a + frac * step), cy + r * math.sin(a + frac * step)))
    d = _poly(pts)
    d += " M%.1f %.1f a%s %s 0 1 0 0.01 0 Z" % (cx, cy - hole, hole, hole)
    return d


# ---- reusable shapes -------------------------------------------------------
PIN = "M64 16 C43 16 29 31 29 50 C29 76 64 112 64 112 C64 112 99 76 99 50 C99 31 85 16 64 16 Z"
PIN_HOLE = " M64 35 a14 14 0 1 0 0.01 0 Z"

# low hover car, side view, nose right: wedge body, fastback, tail wing, side glass, two hover pads
CAR_SIDE = SL(
    F("M16 82 V47 H26 L30 55 L56 38 H74 L94 54 L109 60 L112 70 V82 H99 a13 13 0 0 0 -26 0 H55 a13 13 0 0 0 -26 0 Z "
      "M58 45 H72 L84 55 H43 Z") +
    F("M32 88 H52 V97 H32 Z") + F("M76 88 H96 V97 H76 Z"), 8, 70)
CAR_SIDE = G(CAR_SIDE, "translate(1 -3)")

# sporty front view with a roof sign (the taxi; also the small in-badge car)
CAR_FRONT = ("M41 34 H87 L99 57 L112 66 V98 H100 V108 H80 V98 H48 V108 H28 V98 H16 V66 L29 57 Z "
             "M46 42 H82 L90 57 H38 Z M24 71 H46 L42 82 H24 Z M104 71 H82 L86 82 H104 Z M55 88 H73 V93 H55 Z")
TAXI = F("M52 16 H76 L81 21 V29 H47 V21 Z") + F(CAR_FRONT)

# combination spanner drawn vertical (open jaw up, ring end down), rotated 45 degrees when placed
SPANNER = (KO(C(64, 25, 24), F("M53 -6 H75 V21 L64 30 L53 21 Z")) + F("M56 40 H72 V94 H56 Z") +
           KO(C(64, 104, 17), C(64, 104, 7)))
SPANNER_PLACED = G(SPANNER, "translate(64 64) rotate(45) scale(0.96) translate(-64 -60.5)")

BOLT = "M76 14 L27 71 H56 L45 114 L101 54 H70 Z"

GARAGE = ("M64 16 L112 48 V112 H100 V58 H28 V112 H16 V48 Z M55 37 H73 V46 H55 Z "
          "M36 66 H92 V74 H36 Z M36 82 H92 V90 H36 Z M36 98 H92 V106 H36 Z")

TAG = KO(F("M16 16 H66 L112 62 L62 112 L16 66 Z M39 29 a10 10 0 1 0 0.01 0 Z"),
         S("M49 79 L79 49", 7) + S("M69 81 L81 69", 7))


def _flag():
    cells = []
    for r in range(3):
        for c in range(4):
            if (r + c) % 2 == 0:
                cells.append("M%d %d h19 v20 h-19 Z" % (30 + c * 19, 14 + r * 20))
    wave = "M30 20 C50 12 70 28 106 18 V70 C70 80 50 64 30 72 Z"
    edge = S("M30 20 C50 12 70 28 106 18 V70 C70 80 50 64 30 72", 4)
    return G(SL(F("M22 16 H30 V112 H22 Z") + CLIP(F(" ".join(cells)) + edge, wave), 8, 64), "translate(1 0)")


FLAG = _flag()

# parcel: isometric box, edges and tape cut out
PARCEL = KO(F("M64 16 L106 40 V88 L64 112 L22 88 V40 Z"),
            S("M22 40 L64 64 L106 40 M64 64 V112", 7) + S("M85 28 L43 52 V72", 8))

BRIEFCASE = (CR(16, 40, 112, 106, 7) + " M48 40 V24 H80 V40 H71 V33 H57 V40 Z M16 64 H56 V72 H16 Z "
             "M72 64 H112 V72 H72 Z")


def _sword():
    """One sword, vertical, crossing point at (64, 64): tapered blade, cross-guard, grip, pommel."""
    blade = "M64 4 L71 16 V86 H57 V16 Z"
    body = F(blade) + F("M45 86 H83 V96 H45 Z") + F("M59 96 H69 V111 H59 Z") + C(64, 115, 7.5)
    halo = F(blade) + S(blade, 10)
    return body, halo


def _swords():
    body, halo = _sword()
    a = "translate(64 66) rotate(45) scale(1.06) translate(-64 -64)"
    b = "translate(64 66) rotate(-45) scale(1.06) translate(-64 -64)"
    return KO(G(body, b), G(halo, a)) + G(body, a)


SWORDS = _swords()

TIMER = (RING(64, 70, 38) + F("M53 16 H75 V25 H53 Z") + F("M60 24 H68 V33 H60 Z") +
         S("M95 39 L103 31") + S("M64 72 V48") + C(64, 71, 7))
NAV_ARROW = "M64 14 L104 112 L64 90 L24 112 Z"
PERSON = "M64 16 a19 19 0 1 0 0.01 0 Z M28 112 V95 C28 77 44 64 64 64 C84 64 100 77 100 95 V112 Z"

BUMPER_L = ("M38 28 H100 a12 12 0 0 1 12 12 V88 a12 12 0 0 1 -12 12 H28 a12 12 0 0 1 -12 -12 V50 "
            "a22 22 0 0 1 22 -22 Z")
TRIGGER = ("M34 16 H94 a10 10 0 0 1 10 10 V74 C104 98 88 112 64 112 C40 112 24 98 24 74 V26 "
           "a10 10 0 0 1 10 -10 Z")
DISC = C(64, 64, 47)


def _players():
    back = C(89, 41, 13) + F("M68 108 V92 C68 77 77 66 90 66 C103 66 112 77 112 92 V108 Z")
    fh, fb = "M48 20 a16 16 0 1 0 0.01 0 Z", "M16 112 V97 C16 80 30 68 48 68 C66 68 80 80 80 97 V112 Z"
    return KO(back, F(fh) + S(fh, 12) + F(fb) + S(fb, 12)) + F(fh) + F(fb)


def _controls():
    out = []
    for y, kx in ((34, 74), (64, 36), (94, 68)):
        out.append(S("M16 %d H%d M%d %d H112" % (y, kx - 5, kx + 21, y)))
        out.append(F(CR(kx, y - 15, kx + 16, y + 15, 4)))
    return "".join(out)


def _medal():
    ribbons = F("M26 16 H48 L72 58 H50 Z") + F("M102 16 H80 L56 58 H78 Z")
    return KO(ribbons, C(64, 82, 35)) + KO(C(64, 82, 30), F(_star(64, 83, 18, 7.6)))


def _drift():
    """Two skid tracks swinging out behind a dart that is pointing off its line of travel."""
    tracks = S("M21 110 C22 76 36 54 66 46", 10) + S("M47 110 C48 90 56 76 76 70", 10)
    dart = G(F("M0 -26 L19 22 L0 11 L-19 22 Z"), "translate(85 42) rotate(58) scale(1.2)")
    return tracks + dart


GLYPHS = [
    # --- row 0: navigation / places
    ("garage", F(GARAGE)),
    ("dealership", TAG),
    ("customise", SPANNER_PLACED),
    ("race_flag", FLAG),
    ("map", KO(F("M16 30 L48 18 L80 30 L112 18 V98 L80 110 L48 98 L16 110 Z"),
               S("M48 18 V98 M80 30 V110", 6) + G(F(PIN), "translate(64 62) scale(0.3 0.36) translate(-64 -64)"))),
    ("settings_cog", F(_cog(64, 64, 48, 37, 17))),
    ("controls", _controls()),
    ("gamepad", G(F("M36 34 H92 C104 34 110 44 112 58 L116 86 C117 97 108 103 100 96 L86 82 H42 L28 96 "
                    "C20 103 11 97 12 86 L16 58 C18 44 24 34 36 34 Z "
                    "M37 46 h10 v8 h8 v10 h-8 v8 h-10 v-8 h-8 v-10 h8 Z "
                    "M82 60 a6.5 6.5 0 1 0 0.01 0 Z M96 46 a6.5 6.5 0 1 0 0.01 0 Z"),
                  "translate(64 64) scale(0.92) translate(-64 -66)")),
    # --- row 1: vehicle / people
    ("car", CAR_SIDE),
    ("passenger", F(PERSON)),
    ("players", _players()),
    ("taxi", TAXI),
    ("parcel", PARCEL),
    ("exit", S("M60 20 H22 V108 H60") + S("M46 64 H92") + F("M88 42 L112 64 L88 86 Z")),
    ("back", G(S("M44 46 H80 a23 23 0 0 1 0 46 H40") + F("M16 46 L47 21 V71 Z"), "translate(0 5)")),
    ("steering_wheel", RING(64, 64, 44) +
        F("M22 54 H106 V66 H84 L70 78 V106 H58 V78 L44 66 H22 Z M64 60 a5 5 0 1 0 0.01 0 Z")),
    # --- row 2: race / reward
    ("trophy", KO(F("M36 16 H92 V44 C92 62 80 74 64 74 C48 74 36 62 36 44 Z"), F(_star(64, 42, 15, 6.4))) +
        F("M58 72 H70 V93 H58 Z") + F("M45 92 H83 L90 100 V112 H38 V100 Z") +
        S("M36 26 H20 V36 C20 49 28 57 40 58") + S("M92 26 H108 V36 C108 49 100 57 88 58")),
    ("medal", _medal()),
    ("star", F(_star(64, 68, 50, 22))),
    ("coin", KO(DISC, T("$", 72))),
    ("timer", TIMER),
    ("loop", S("M101.6 54.3 A40 40 0 1 1 77.7 30.4") + F("M92.7 35.8 L78.7 15.8 L69.1 42.2 Z")),
    ("laps", S("M48 36 H80 a28 28 0 0 1 0 56 H48 a28 28 0 0 1 0 -56 Z") + F("M56 22 L76 36 L56 50 Z") +
        F("M60 80 H68 V106 H60 Z")),
    ("checkpoints", G(F("M34 16 H42 V100 H34 Z") + F("M42 16 L104 40 L42 64 Z") +
                      KO('<ellipse class="s" cx="38" cy="102" rx="19" ry="8" style="stroke-width:6"/>',
                         S("M38 60 V102", 16)), "translate(4 0)")),
    # --- row 3: route / status
    ("pin", F(PIN + PIN_HOLE)),
    ("set_route", KO('<rect class="f" x="30" y="30" width="68" height="68" rx="7" transform="rotate(45 64 64)"/>',
                     S("M46 85 V69 a9 9 0 0 1 9 -9 H70", 9) + F("M68 42 L90 60 L68 78 Z"))),
    ("route", G(S("M38 98 H78 a16 16 0 0 0 0 -32 H50 a16 16 0 0 1 0 -32 H88") + RING(28, 98, 9, 7) + C(99, 34, 13),
                "translate(0 -2)")),
    ("north", KO(C(64, 72, 40), T("N", 50, y=90)) + F("M64 15 L77 32 H51 Z")),
    ("boost", G(F(BOLT), "translate(64 64) scale(0.96) translate(-64 -64)")),
    ("upgrade", F("M64 16 L106 60 H82 V86 H46 V60 H22 Z M40 98 H88 V110 H40 Z")),
    ("lock", F(CR(26, 56, 102, 112, 7) + " M64 70 a9 9 0 0 0 -4 17 V98 H68 V87 a9 9 0 0 0 -4 -17 Z") +
        S("M42 58 V43 a22 22 0 0 1 44 0 V58", 9)),
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
    ("paint", G(F("M55 0 H73 V52 H55 Z M51 59 H77 V73 H51 Z "
                  "M50 80 H78 V92 C78 107 64 112 64 126 C64 112 50 107 50 92 Z"),
                "translate(-4 4) rotate(45 64 64)")),
    ("keycap_blank", '<rect class="f" x="18" y="18" width="92" height="92" rx="14"/>'),
    ("dpad", F("M46 16 H82 V46 H112 V82 H82 V112 H46 V82 H16 V46 H46 Z "
               "M64 23 L75 38 H53 Z M64 105 L75 90 H53 Z M23 64 L38 53 V75 Z M105 64 L90 53 V75 Z")),
    ("pad_select", KO(DISC, '<path class="f" d="M36 44 H74 V72 H36 Z"/>'
                            '<path class="s" style="stroke-width:7" d="M82 56 H90 V84 H52 V78"/>')),
    ("pad_start", KO(DISC, '<path class="s" style="stroke-width:8" d="M38 46 H90 M38 64 H90 M38 82 H90"/>')),
    # --- row 6: gamepad buttons
    ("pad_a", KO(DISC, T("A", 66))),
    ("pad_b", KO(DISC, T("B", 66))),
    ("pad_x", KO(DISC, T("X", 66))),
    ("pad_y", KO(DISC, T("Y", 66))),
    ("pad_lb", KO(F(BUMPER_L), T("LB", 58, y=85, spacing=1))),
    ("pad_rb", KO(G(F(BUMPER_L), "translate(128 0) scale(-1 1)"), T("RB", 58, y=85, spacing=1))),
    ("pad_lt", KO(F(TRIGGER), T("LT", 56, y=79, spacing=1))),
    ("pad_rt", KO(F(TRIGGER), T("RT", 56, y=79, spacing=1))),
    # --- row 7: added in the second pass (append only)
    ("drift", _drift()),
    ("gauge", S("M32.9 101.1 A44 44 0 1 1 95.1 101.1") + F("M57 66 L94 40 L71 77 Z") + C(64, 70, 9)),
]

PURPOSE = {
    "controls": "settings sliders (HUD nav); the CONTROLS button uses gamepad",
    "dealership": "price tag", "customise": "combination spanner",
    "car": "low hover car, side view, nose right",
    "title_mark": "three slashes before a screen title (Pink)",
    "pad_select": "View / Select", "pad_start": "Menu / Start",
    "keycap_blank": "square key; wide keys use keycap_9slice.png",
    "north": "minimap north marker", "steering_wheel": "DRIVE button",
    "passenger": "also single player / profile",
    "checkpoints": "pennant marker on a ground ring",
    "set_route": "directions sign: turn arrow in a diamond",
    "drift": "stat / tip glyph; the touch control art is in touch_controls*.png",
    "gauge": "speed stat glyph",
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


def _in(glyph, scale, cy=64, cx=64):
    return G(glyph, "translate(%s %s) scale(%s) translate(-64 -64)" % (cx, cy, scale))


MAP_ICONS = [
    ("Race", KO(_badge_circle(), _in(FLAG, 0.62, 64, 62))),
    ("TimeTrial", KO(_badge_circle(), _in(TIMER, 0.66, 63))),
    ("Duel", KO(_badge_circle(), _in(SWORDS, 0.66, 63))),
    ("Job", KO(_badge_hex(), _in(F(BRIEFCASE), 0.6, 62))),
    ("TaxiFare", KO(_badge_hex(), _in(TAXI, 0.62))),
    ("CourierPickup", KO(_badge_hex(), _in(PARCEL, 0.62))),
    ("TaxiDrop", KO(_badge_pin(), _in(TAXI, 0.5, 50))),
    ("CourierDrop", KO(_badge_pin(), _in(PARCEL, 0.5, 51))),
    ("Customisation", KO(_badge_square(), _in(SPANNER_PLACED, 0.68))),
    ("Dealership", KO(_badge_square(), _in(TAG, 0.64))),
    ("Garage", KO(_badge_square(), _in(F(GARAGE), 0.64, 62))),
    ("Waypoint", KO(_badge_pin(), C(64, 52, 18))),
    ("Player", F(NAV_ARROW)),
    ("OtherPlayer", C(64, 64, 20) + RING(64, 64, 36, 8)),
]
