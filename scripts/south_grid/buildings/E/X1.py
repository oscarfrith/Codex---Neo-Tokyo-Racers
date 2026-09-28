"""X1 - the South Grid gate over the x=0 boulevard (owner E). P09 core east face (x=-125) -> P10 frame F1 west face (x=125).
A 6-storey Blocks housing slab (deck top Y440, roof Y520, z 4970..5030) with balconies, laundry and a graffiti fascia,
slung over a pair of Metabolist glazed tubes (Y391-409, z 4984 / 5016) on concrete hangers, and crowned by a
Fuji-style frame holding a steel sphere over the road centre (top Y622): the gate's silhouette from the boulevard.
Road surface Y200: tube underside Y391 clears it by 191 studs.
"""
from elib import *  # noqa: F401,F403

s, rng = new_spec("X1", "Gate Bridge", "hybrid")
OUT = HERE / "X1.json"
X0, X1_ = -125, 125
ZN, ZS = 4978, 5022   # window mass faces; balconies project 8 more (centre line z=5000)
DECK = 440.0
NS = 6                # storeys above the deck
ys = [DECK + i * ST for i in range(NS + 1)]
ROOF = ys[NS]         # 520

s.group("Gate Slab")
box(s, X0, X1_, DECK - 14, DECK, ZN - 9, ZS + 9, color=CONC_D, name="DeckStructure")
box(s, X0 + 5, X1_ - 5, DECK - 13, DECK - 4, ZN - 10.2, ZN - 9, var="SG Graffiti A", color=(200, 200, 200), name="FasciaGraffitiN")
box(s, X0 + 5, X1_ - 5, DECK - 13, DECK - 4, ZS + 9, ZS + 10.2, var="SG Graffiti B", color=(200, 200, 200), name="FasciaGraffitiS")
box(s, X0 + 5, X1_ - 5, DECK - 3.4, DECK - 2.8, ZN - 10.4, ZN - 9, mat="Neon", var="", color=NEON_PINK, name="FasciaNeon")
box(s, X0 + 5, X1_ - 5, DECK - 3.4, DECK - 2.8, ZS + 9, ZS + 10.4, mat="Neon", var="", color=NEON_CYAN, name="FasciaNeon")
win_box(s, X0, X1_, DECK, ROOF, ZN, ZS, name="SlabWindows")
n = 6
bw = (X1_ - X0) / n
for face, plane in (("N", ZN), ("S", ZS)):
    for i in range(1, NS):
        v = "SG Patched Panels" if (i + (face == "S")) % 3 else "SG Weathered Concrete"
        fbox(s, face, plane, 0, 8, X0, X1_, ys[i] - 1.2, ys[i] + 4.8, mat="SmoothPlastic" if "Patched" in v else "Concrete",
             var=v, color=PATCH if "Patched" in v else CONC, name="BalconyRow")
    for j in range(n + 1):
        u = X0 + j * bw
        u0, u1 = max(X0, u - 1.2 - (1.2 if j == n else 0)), min(X1_, u + 1.2 + (1.2 if j == 0 else 0))
        fbox(s, face, plane, 0, 8.6, u0, u1, DECK, ROOF, color=CONC_D, name="BalconyFin")
    for i in range(1, NS):
        for j in range(n):
            uc = X0 + (j + 0.5) * bw
            r = rng.random()
            if r < 0.3 and i < NS - 1:
                fkit(s, "laundry_line_36", face, plane, 8.6, uc, ys[i + 1] - 1.2 - 3.6, layer="LOD2",
                     color=rng.choice([(230, 120, 150), (120, 170, 230), (240, 230, 210), (240, 200, 90), (150, 210, 160)]))
            elif r < 0.45 and i < NS - 1:
                fbox(s, face, plane, 0.2, 7.6, uc - bw / 2 + 1.2, uc + bw / 2 - 1.2, ys[i] + 4.8, ys[i + 1] - 1.2,
                     mat="SmoothPlastic", var="SG Patched Panels",
                     color=rng.choice([(200, 225, 205), (235, 190, 175), (235, 222, 170), (190, 214, 232)]), name="EnclosedBalcony")
            elif r < 0.58:
                fkit(s, "ac_cluster", face, plane, 10, uc + rng.choice([-12, 12]), ys[i] + 1.3, layer="LOD2")
box(s, X0, X1_, ROOF, ROOF + 3, ZN - 9, ZS + 9, color=CONC_D, name="SlabRoof")
parapet(s, X0, X1_, ZN - 9, ZS + 9, ROOF + 3, h=4)
R3 = ROOF + 3

s.group("Sphere Crown")
for xp in (-52, 40):
    box(s, xp, xp + 12, R3, R3 + 87, 4982, 5018, var="SG Capsule Panels", color=WHITE, name="CrownPost")
box(s, -56, 56, R3 + 87, R3 + 99, 4980, 5020, var="SG Capsule Panels", color=WHITE, name="CrownBeam")
box(s, -50, 50, R3 + 92, R3 + 92.6, 4979.4, 4980, mat="Neon", var="", color=NEON_AMBER, name="CrownNeon")
box(s, -50, 50, R3 + 92, R3 + 92.6, 5020, 5020.6, mat="Neon", var="", color=NEON_AMBER, name="CrownNeon")
box(s, -16, 16, R3, R3 + 4, 4984, 5016, color=CONC_D, name="SphereSeat")
s.part("Ball", (72, 72, 72), (0, R3 + 4 + 36, 5000), mat="Metal", var="", color=(196, 200, 206), name="GateSphere")
s.kit("antenna_mast", (0, R3 + 99 + 30, 5000))

s.group("Roof Life")
s.kit("rooftop_shack", (-96, R3 + 6, 4998), rot=(0, 0, 0), color=(120, 150, 160))
s.kit("rooftop_shack", (92, R3 + 6, 5002), rot=(0, 180, 0), color=(170, 120, 100))
s.kit("water_tank", (-72, R3 + 11, 5010))
s.kit("dish_cluster", (72, R3 + 6, 4990), rot=(0, 0, 0), layer="LOD2")

s.group("Tube Pair")
TY = 400.0
for zc in (4984, 5016):
    for i in range(6):
        s.kit("bridge_tube_40", (X0 + 5 + 20 + 40 * i, TY, zc))
    for xc in (X0 + 2.5, X1_ - 2.5):
        box(s, xc - 2.5, xc + 2.5, TY - 12, TY + 12, zc - 12, zc + 12, var="SG Capsule Panels", color=WHITE, name="TubeCollar")
    for xh in (-80, 0, 80):
        box(s, xh - 2, xh + 2, TY + 9, DECK - 14, zc - 2, zc + 2, color=CONC_D, name="Hanger")
        box(s, xh - 3, xh + 3, TY + 7, TY + 11, zc - 10, zc + 10, color=CONC_D, name="HangerSaddle")

if __name__ == "__main__":
    s.save(OUT)
