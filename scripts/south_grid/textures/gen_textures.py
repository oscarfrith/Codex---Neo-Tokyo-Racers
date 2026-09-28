"""Procedural generator for the South Grid SG MaterialVariants.
usage: py -3 gen_textures.py [slug ...]   (no args = all procedural variants)
Writes out/<slug>_color.png, _normal.png, _roughness.png (1024, seamless)."""
import sys
import numpy as np
from sglib import *  # noqa

CONC = col(168, 163, 152)
CONC_DARK = col(118, 116, 110)


def concrete_base(seed, px_per_stud, board_studs=1.5, ties=6.0, streak=0.5, tint=CONC):
    """Board-marked concrete. Returns color, height, roughness."""
    rng = np.random.default_rng(seed)
    bh = board_studs * px_per_stud
    nb = max(1, round(N / bh))
    bh = N / nb
    H = np.zeros((N, N), np.float32)
    shade = np.zeros((N, N), np.float32)
    grain = fbm(seed + 1, beta=1.6, ax=10, ay=1)
    for i in range(nb):
        y0, y1 = i * bh, (i + 1) * bh
        # each board row is a run of planks with staggered butt joints
        x = rng.uniform(0, N)
        nplank = rng.integers(1, 3)
        cuts = np.sort(rng.uniform(0, N, nplank))
        edges = list(cuts) + [cuts[0] + N]
        for a, b in zip(edges[:-1], edges[1:]):
            m = rect(a + 1.0, y0 + 0.8, b - 1.0, y1 - 0.8, r=2, soft=2.5)
            off = rng.uniform(-0.25, 0.25)
            H += m * (0.25 + off * 0.3)
            shade += m * off
    H += (grain - 0.5) * 0.18
    # tie holes on a regular grid
    tp = ties * px_per_stud
    nt = max(1, round(N / tp))
    tp = N / nt
    holes = np.zeros((N, N), np.float32)
    for i in range(nt):
        for j in range(nt):
            s = circ_sdf((i + 0.5) * tp, (j + 0.5) * tp, 0.28 * px_per_stud)
            holes = np.maximum(holes, bevel(s, 0.18 * px_per_stud))
    H -= holes * 0.8
    # colour
    low = fbm(seed + 2, beta=2.6)
    mid = fbm(seed + 3, beta=2.0)
    C = tint[None, None, :] * (0.9 + 0.2 * low[..., None])
    C = C * (1 + 0.10 * shade[..., None]) * (0.95 + 0.1 * mid[..., None])
    C = C * (1 + 0.04 * (grain[..., None] - 0.5))
    # rain streaks: vertically stretched noise, stronger below tie holes
    st = fbm(seed + 4, beta=1.8, ax=1, ay=14)
    st = blur(np.clip((st - 0.55) * 2.4, 0, 1), 2.0) * streak
    under = blur(holes, 3)
    trail = np.zeros_like(under)
    for k in range(1, 40, 2):
        trail = np.maximum(trail, np.roll(under, k * 3, 0) * (1 - k / 40))
    st = np.clip(st + trail * 0.6 * streak, 0, 1)
    blot = np.clip((fbm(seed + 5, beta=3.0) - 0.55) * 2.5, 0, 1) * streak
    dirt = np.clip(st * 0.8 + blot * 0.6, 0, 1)
    C = lerp(C, C * col(150, 150, 140) / 0.62 * 0.62, dirt * 0.55)
    C = C * (1 - 0.18 * dirt[..., None])
    C = lerp(C, col(35, 35, 35), holes * 0.8)
    R = 0.86 - 0.08 * st + 0.04 * (grain - 0.5)
    return C.astype(np.float32), H, R


def weathered_concrete():
    slug = "sg_weathered_concrete"
    pps = N / 24
    C, H, R = concrete_base(11, pps, board_studs=1.5, ties=8.0, streak=0.9)
    Hn = blur(H, 1.2)
    nrm = normal_from_height(Hn, 6.0)
    C = bake_light(C, nrm, Hn, amt=0.10, ao=0.5)
    save_set(slug, C, Hn, 6.0, R)


class Canvas:
    def __init__(self, C, H, R):
        self.C, self.H, self.R = C, H, R

    def paint(self, m, c=None, h=None, r=None, hmode="set"):
        if c is not None:
            self.C = lerp(self.C, c if np.ndim(c) == 3 else np.asarray(c)[None, None, :], m)
        if h is not None:
            if hmode == "add":
                self.H = self.H + m * h
            else:
                self.H = lerp(self.H, h, m)
        if r is not None:
            self.R = lerp(self.R, r, m)


PASTELS = [col(170, 214, 190), col(236, 170, 150), col(242, 218, 140), col(160, 198, 226), col(226, 176, 200)]
CURTAINS = [col(232, 220, 196), col(236, 184, 178), col(186, 216, 196), col(182, 200, 226), col(244, 240, 230),
            col(240, 214, 150)]


def glass(x0, y0, x1, y1, lit, rng):
    """Glass pane colour field: sky reflection when unlit, warm interior when lit."""
    t = np.clip((Y - y0) / max(1, y1 - y0), 0, 1)
    if lit:
        top, bot = col(255, 226, 164), col(236, 164, 96)
        g = lerp(top, bot, t)
        g = g * (1 + 0.12 * np.clip(1 - np.abs(pd(X, (x0 + x1) / 2)) / (x1 - x0), 0, 1))[..., None]
    else:
        top, bot = col(150, 178, 204), col(46, 60, 84)
        g = lerp(top, bot, np.clip(t * 1.3, 0, 1))
        diag = (pd(X, x0) + (Y - y0) * 0.6) / max(1, x1 - x0)
        band = np.exp(-((diag - rng.uniform(0.3, 0.9)) / 0.08) ** 2)
        g = g + band[..., None] * 0.14
    return g


def windows_blocks():
    slug = "sg_windows_blocks"
    pps = N / 40
    c = N / 3
    rng = np.random.default_rng(7)
    C, H, R = concrete_base(31, pps, board_studs=2.0, ties=40.0, streak=0.5)
    H = H * 0.3 + 0.75  # facade plane
    cv = Canvas(C, H, R)
    slab = 1.4 * pps
    park = 4.6 * pps  # parapet height
    pier = 1.5 * pps
    kinds = ["win", "win", "open", "win", "shutter", "open", "win", "win", "open"]
    rng.shuffle(kinds)
    litmap = rng.random(9) < 0.3
    pastel_cells = set(np.random.default_rng(3).choice(9, 3, replace=False).tolist())
    k = 0
    for j in range(3):
        y0 = j * c
        ry0, ry1 = y0 + slab, y0 + c - park  # recess (window zone)
        for i in range(3):
            x0 = i * c
            rx0, rx1 = x0 + pier / 2, x0 + c - pier / 2
            kind, lit = kinds[k], litmap[k]
            k += 1
            rec = rect(rx0, ry0, rx1, ry1 + 2)
            # recess back wall, in the shade of the slab above
            sh = np.clip((Y - ry0) / (1.6 * pps), 0, 1)
            wall = col(128, 124, 116)[None, None, :] * (0.62 + 0.38 * sh)[..., None]
            cv.paint(rec, wall, h=0.12, r=0.9)
            fx0, fx1 = rx0 + 1.2 * pps, rx1 - 1.2 * pps
            fy0 = ry0 + 0.9 * pps
            fy1 = ry1 + 2
            if kind == "shutter":
                fr = rect(fx0, fy0, fx1, fy1, soft=1)
                slat = 0.5 + 0.5 * np.sin((Y - fy0) / (0.45 * pps) * np.pi * 2)
                base = [col(196, 190, 176), col(150, 164, 170), col(188, 176, 150)][rng.integers(3)]
                cv.paint(fr, base[None, None, :] * (0.88 + 0.12 * slat)[..., None], h=0.18 + 0.03 * slat, r=0.55)
                cv.paint(rect(fx0, fy0, fx1, fy0 + 0.8 * pps), col(120, 120, 118), h=0.26, r=0.5)
            else:
                npane = 2 if kind == "open" else rng.integers(2, 4)
                frame = rect(fx0, fy0, fx1, fy1)
                cv.paint(frame, col(92, 96, 102), h=0.2, r=0.45)
                pw = (fx1 - fx0) / npane
                f = 0.28 * pps
                for p in range(npane):
                    gx0, gx1 = fx0 + p * pw + f, fx0 + (p + 1) * pw - f
                    gy0, gy1 = fy0 + f, fy1
                    gm = rect(gx0, gy0, gx1, gy1)
                    plit = lit and (kind != "open" or p == 0)
                    cv.paint(gm, glass(gx0, gy0, gx1, gy1, plit, rng), h=0.16, r=0.12)
                    # curtains
                    if kind == "win" and rng.random() < 0.8:
                        cc = CURTAINS[rng.integers(len(CURTAINS))]
                        cw = pw * rng.uniform(0.25, 0.7)
                        left = rng.random() < 0.5
                        cx0, cx1 = (gx0, gx0 + cw) if left else (gx1 - cw, gx1)
                        fold = 0.5 + 0.5 * np.sin((X - cx0) / (0.55 * pps) * np.pi * 2)
                        cm = rect(cx0, gy0, cx1, gy1)
                        ccol = cc[None, None, :] * (0.85 + 0.15 * fold)[..., None]
                        if plit:
                            ccol = ccol * col(255, 236, 200)[None, None, :] * 1.05
                        else:
                            ccol = ccol * 0.8
                        cv.paint(cm * 0.95, ccol, h=0.17, r=0.85)
                if kind == "open":
                    # laundry pole with hanging clothes across the balcony
                    py = ry0 + 1.5 * pps
                    cv.paint(rect(rx0, py - 0.12 * pps, rx1, py + 0.12 * pps), col(200, 200, 205), h=0.5, r=0.4)
                    x = rx0 + 1.0 * pps
                    while x < rx1 - 2.5 * pps:
                        w = rng.uniform(1.6, 2.6) * pps
                        hgt = rng.uniform(2.5, 4.2) * pps
                        cc = [col(236, 90, 120), col(90, 170, 230), col(250, 250, 245), col(250, 200, 70),
                              col(120, 200, 150), col(70, 80, 120), col(240, 140, 80)][rng.integers(7)]
                        shape = rng.integers(3)
                        if shape == 0:  # shirt
                            m = np.maximum(rect(x, py, x + w, py + hgt, r=3),
                                           rect(x - 0.5 * pps, py, x + w + 0.5 * pps, py + 1.0 * pps, r=3))
                        elif shape == 1:  # towel
                            m = rect(x, py, x + w, py + hgt * 1.1, r=2)
                        else:  # trousers
                            m = np.maximum(rect(x, py, x + w * 0.45, py + hgt * 1.2, r=2),
                                           rect(x + w * 0.55, py, x + w, py + hgt * 1.2, r=2))
                            m = np.maximum(m, rect(x, py, x + w, py + 0.8 * pps))
                        fold = 0.9 + 0.1 * np.sin((X - x) / (0.7 * pps) * np.pi * 2)
                        cv.paint(m, cc[None, None, :] * fold[..., None], h=0.45, r=0.9)
                        x += w + rng.uniform(0.4, 1.4) * pps
            # parapet: concrete or pastel infill panel
            pm = rect(rx0 - 1, ry1, rx1 + 1, y0 + c)
            cv.paint(pm, None, h=0.8)
            if (k - 1) in pastel_cells:
                pc = lerp(PASTELS[rng.integers(len(PASTELS))], col(170, 166, 156), 0.3)
                inset = 0.35 * pps
                pan = rect(rx0 + inset, ry1 + inset, rx1 - inset, y0 + c - inset, r=2)
                lowp = fbm(100 + k, beta=2.6)
                ps = fbm(200 + k, beta=1.8, ax=1, ay=10)
                cv.paint(pan, pc[None, None, :] * (0.88 + 0.14 * lowp - 0.08 * ps)[..., None], h=0.84, r=0.6)
                # vertical panel seams
                for s in (1, 2):
                    sx = rx0 + (rx1 - rx0) * s / 3
                    cv.paint(rect(sx - 1.5, ry1 + inset, sx + 1.5, y0 + c - inset) * pan, col(120, 120, 115) * 0 + pc * 0.7,
                             h=0.8)
            # AC unit on the balcony, sitting on the parapet top
            if kind != "shutter" and rng.random() < 0.55:
                aw, ah = 2.8 * pps, 2.2 * pps
                ax = rx0 + 0.6 * pps if rng.random() < 0.5 else rx1 - 0.6 * pps - aw
                am = rect(ax, ry1 - ah, ax + aw, ry1 + 0.6 * pps, r=3)
                cv.paint(am, col(226, 224, 216), h=0.95, r=0.55)
                fan = circ_sdf(ax + aw * 0.36, ry1 - ah * 0.45, 0.78 * pps)
                ring = cov(fan) - cov(fan + 0.12 * pps)
                cv.paint(cov(fan), col(90, 92, 96), h=0.88)
                grill = 0.5 + 0.5 * np.sin(np.hypot(pd(X, ax + aw * 0.36), Y - (ry1 - ah * 0.45)) / (0.18 * pps) * np.pi)
                cv.paint(cov(fan) * grill * 0.6, col(170, 172, 176))
                cv.paint(np.clip(ring, 0, 1), col(200, 200, 196), h=0.93)
                cv.paint(rect(ax + aw * 0.72, ry1 - ah * 0.8, ax + aw * 0.9, ry1 - ah * 0.15), col(190, 188, 180), h=0.93)
        # slab edge band (protrudes)
        sm = rect(-10, y0, N + 10, y0 + slab)
        cv.paint(sm, None, h=1.0)
        cv.C = cv.C * (1 + 0.06 * sm[..., None])
    # piers
    for i in range(3):
        pm = rect(i * c - pier / 2, -10, i * c + pier / 2, N + 10)
        cv.paint(pm, None, h=0.92)
    # grime streaks below slabs and parapet tops, over concrete only
    st = fbm(77, beta=1.8, ax=1, ay=12)
    drip = np.zeros((N, N), np.float32)
    for j in range(3):
        y0 = j * c
        for band_top in (y0 + slab, y0 + c - park):
            d = (Y - band_top) / (2.5 * pps)
            drip = np.maximum(drip, np.where((d > 0) & (d < 1), 1 - d, 0))
    conc = np.clip((cv.H - 0.7) * 5, 0, 1)
    grime = np.clip(drip * (st - 0.35) * 2.5, 0, 1) * conc
    cv.C = cv.C * (1 - 0.22 * grime[..., None])
    Hn = blur(cv.H, 1.0)
    nrm = normal_from_height(Hn, 14.0)
    C = bake_light(cv.C, nrm, Hn, amt=0.10, ao=0.9, ao_sigma=10)
    save_set(slug, C, Hn, 14.0, cv.R)


WHITE = col(228, 224, 212)


def panel_face(cv, x0, y0, x1, y1, r, gap, tone, seed, bev):
    """White precast panel with a soft pillow bevel, inside a dark joint."""
    sdf = rect_sdf(x0 + gap / 2, y0 + gap / 2, x1 - gap / 2, y1 - gap / 2, r)
    m = cov(sdf)
    low = fbm(seed, beta=2.6)
    c = WHITE[None, None, :] * (tone * (0.95 + 0.08 * low))[..., None]
    cv.paint(m, c, r=0.62)
    cv.H = np.maximum(cv.H, m * (0.55 + 0.45 * np.sqrt(bevel(sdf, bev))))
    return sdf


def bolt(cv, cx, cy, rad):
    s = circ_sdf(cx, cy, rad)
    m = cov(s)
    cv.paint(m, col(150, 148, 142), r=0.4)
    cv.H = np.maximum(cv.H, (1.0 + 0.25 * np.sqrt(bevel(s, rad))) * m)
    return m


def streaks_below(masks, seed, length, strength):
    st = fbm(seed, beta=1.8, ax=1, ay=12)
    trail = np.zeros((N, N), np.float32)
    for k in range(1, 30):
        trail = np.maximum(trail, np.roll(masks, int(k * length / 30), 0) * (1 - k / 30))
    return np.clip(trail * (0.4 + st), 0, 1) * strength


def windows_capsule():
    slug = "sg_windows_capsule"
    pps = N / 40
    rng = np.random.default_rng(5)
    cv = Canvas(np.zeros((N, N, 3), np.float32) + col(112, 110, 106), np.zeros((N, N), np.float32),
                np.full((N, N), 0.8, np.float32))
    cs = N / 2
    kinds = ["blind", "plain", "lit", "blind_half"]
    rng.shuffle(kinds)
    boltm = np.zeros((N, N), np.float32)
    rims = np.zeros((N, N), np.float32)
    for j in range(2):
        for i in range(2):
            x0, y0 = i * cs, j * cs
            kind = kinds[j * 2 + i]
            panel_face(cv, x0, y0, x0 + cs, y0 + cs, 1.4 * pps, 0.3 * pps, 1 - 0.04 * rng.random(),
                       40 + i + 2 * j, 1.2 * pps)
            cx, cy = x0 + cs / 2, y0 + cs * 0.47
            ro, ri = 6.4 * pps, 5.3 * pps
            so = circ_sdf(cx, cy, ro)
            si = circ_sdf(cx, cy, ri)
            cv.paint(cov(so + 0.5 * pps), col(205, 202, 192))
            rim = cov(so) * (1 - cov(si))
            rims += rim
            rr = np.hypot(pd(X, cx), pd(Y, cy))
            ring_h = 0.75 + 0.35 * np.clip(1 - np.abs((rr - (ro + ri) / 2) / ((ro - ri) / 2)), 0, 1) ** 0.5
            cv.paint(rim, col(236, 234, 228), r=0.35)
            cv.H = lerp(cv.H, ring_h, rim)
            gm = cov(si)
            g = glass(cx - ri, cy - ri, cx + ri, cy + ri, kind == "lit", rng)
            cv.paint(gm, g, h=0.3, r=0.1)
            if kind.startswith("blind"):
                # Nakagin fan blind: pleated disc, fully or half drawn
                ang = np.arctan2(pd(Y, cy), pd(X, cx))
                pleat = 0.5 + 0.5 * np.cos(ang * 36)
                cover = gm if kind == "blind" else gm * cov(pd(Y, cy) - 0.1 * ri)
                bc = col(236, 226, 200)[None, None, :] * (0.82 + 0.18 * pleat)[..., None]
                cv.paint(cover, bc, h=0.32, r=0.8)
            # inner shadow on the glass under the top of the rim
            sh = np.clip(1 + si / (0.8 * pps), 0, 1) * gm
            top = np.clip(-pd(Y, cy) / ri + 0.3, 0, 1)
            cv.C = cv.C * (1 - 0.35 * (sh * top)[..., None])
            for bx in (0.12, 0.88):
                for by in (0.1, 0.9):
                    boltm = np.maximum(boltm, bolt(cv, x0 + cs * bx, y0 + cs * by, 0.35 * pps))
    dirt = streaks_below(np.clip(rims + boltm, 0, 1), 9, 3.5 * pps, 0.16)
    dirt = blur(dirt * (fbm(10, beta=1.8, ax=1, ay=10) > 0.4), 1.5) * (cv.H > 0.5)
    cv.C = cv.C * (1 - dirt[..., None])
    cv.C = cv.C * (1 - 0.06 * (fbm(12, beta=2.2, ax=1, ay=6) - 0.5)[..., None])
    Hn = blur(cv.H, 1.0)
    nrm = normal_from_height(Hn, 10.0)
    C = bake_light(cv.C, nrm, Hn, amt=0.10, ao=0.8, ao_sigma=8)
    save_set(slug, C, Hn, 10.0, cv.R)


def capsule_panels():
    slug = "sg_capsule_panels"
    pps = N / 16
    rng = np.random.default_rng(15)
    cv = Canvas(np.zeros((N, N, 3), np.float32) + col(118, 116, 110), np.zeros((N, N), np.float32),
                np.full((N, N), 0.85, np.float32))
    cs = N / 2
    boltm = np.zeros((N, N), np.float32)
    for j in range(2):
        for i in range(2):
            x0, y0 = i * cs, j * cs
            panel_face(cv, x0, y0, x0 + cs, y0 + cs, 0.7 * pps, 0.2 * pps, 1 - 0.05 * rng.random(),
                       60 + i + 2 * j, 0.6 * pps)
            # shallow horizontal rib across the middle of each panel
            rib = rect_sdf(x0 + 0.9 * pps, y0 + cs * 0.5 - 0.25 * pps, x0 + cs - 0.9 * pps,
                           y0 + cs * 0.5 + 0.25 * pps, 0.2 * pps)
            cv.H = np.maximum(cv.H, cov(rib) * (1.0 + 0.1 * np.sqrt(bevel(rib, 0.2 * pps))))
            for bx in (0.1, 0.9):
                for by in (0.1, 0.9):
                    boltm = np.maximum(boltm, bolt(cv, x0 + cs * bx, y0 + cs * by, 0.22 * pps))
    dirt = streaks_below(boltm, 16, 2.5 * pps, 0.3)
    dirt = blur(dirt * (fbm(17, beta=1.8, ax=1, ay=10) > 0.35), 2)
    grime = np.zeros((N, N), np.float32)
    for j in range(2):
        yb = (j + 1) * cs - 0.14 * pps
        grime = np.maximum(grime, np.clip(1 - (yb - Y) / (1.4 * pps), 0, 1) * (Y < yb))
    grime *= 0.5 + fbm(18, beta=1.6, ax=1, ay=4)
    face = (cv.H > 0.5).astype(np.float32)
    cv.C = cv.C * (1 - (0.22 * dirt + 0.12 * grime * face)[..., None])
    Hn = blur(cv.H, 1.2)
    nrm = normal_from_height(Hn, 12.0)
    C = bake_light(cv.C, nrm, Hn, amt=0.10, ao=0.7, ao_sigma=8)
    save_set(slug, C, Hn, 12.0, cv.R)


def patched_panels():
    slug = "sg_patched_panels"
    pps = N / 20
    rng = np.random.default_rng(23)
    cv = Canvas(np.zeros((N, N, 3), np.float32) + col(70, 70, 68), np.zeros((N, N), np.float32),
                np.full((N, N), 0.8, np.float32))
    rects = []

    def split(x0, y0, x1, y1, d):
        w, h = x1 - x0, y1 - y0
        stop = d <= 0 or (w <= 6 and h <= 6) or (d < 2 and w <= 10 and h <= 10 and rng.random() < 0.25)
        if stop:
            rects.append((x0, y0, x1, y1))
        elif w >= h:
            c = int(rng.integers(3, w - 2))
            split(x0, y0, x0 + c, y1, d - 1)
            split(x0 + c, y0, x1, y1, d - 1)
        else:
            c = int(rng.integers(3, h - 2))
            split(x0, y0, x1, y0 + c, d - 1)
            split(x0, y0 + c, x1, y1, d - 1)

    split(0, 0, 20, 20, 4)
    pal = PASTELS * 3 + [col(196, 190, 176)]
    rivets = np.zeros((N, N), np.float32)
    for n, (a, b, c2, d) in enumerate(rects):
        x0, y0, x1, y1 = a * pps, b * pps, c2 * pps, d * pps
        g = 0.14 * pps
        sdf = rect_sdf(x0 + g, y0 + g, x1 - g, y1 - g, 0.15 * pps)
        m = cov(sdf)
        base = lerp(pal[rng.integers(len(pal))], col(175, 172, 162), rng.uniform(0.05, 0.25))
        low = fbm(300 + n, beta=2.4)
        kind = rng.integers(3)
        h = 0.6 + 0.4 * np.sqrt(bevel(sdf, 0.25 * pps))
        tone = 0.9 + 0.14 * low
        if kind == 0:  # corrugated sheet
            rib = 0.5 + 0.5 * np.cos((X - x0) / (0.6 * pps) * 2 * np.pi)
            h = h + 0.18 * rib
            tone = tone * (0.93 + 0.1 * rib)
        elif kind == 1:  # flat sheet with a frame lip
            inner = rect_sdf(x0 + 0.5 * pps, y0 + 0.5 * pps, x1 - 0.5 * pps, y1 - 0.5 * pps, 0.1 * pps)
            h = h - 0.08 * cov(inner)
        peel = np.clip((fbm(400 + n, beta=1.9) - 0.68) * 8, 0, 1)
        c = base[None, None, :] * tone[..., None]
        c = lerp(c, col(160, 158, 150)[None, None, :] * (0.9 + 0.1 * low[..., None]), peel * 0.8)
        cv.paint(m, c, r=0.62 + 0.2 * peel)
        cv.H = lerp(cv.H, h, m)
        if rng.random() < 0.6:
            nr = max(2, int((x1 - x0) / (1.6 * pps)))
            for k in range(nr):
                rx = x0 + (k + 0.5) * (x1 - x0) / nr
                for ry in (y0 + 0.45 * pps, y1 - 0.45 * pps):
                    rm = cov(circ_sdf(rx, ry, 0.13 * pps))
                    cv.paint(rm, col(120, 116, 108))
                    cv.H = np.maximum(cv.H, rm * 1.1)
                    rivets = np.maximum(rivets, rm)
    rust = streaks_below(blur(rivets, 1), 31, 2.5 * pps, 0.5)
    rust = blur(rust * (fbm(32, beta=1.8, ax=1, ay=10) > 0.45), 1.5)
    cv.C = lerp(cv.C, cv.C * (col(170, 110, 70) / 0.67), rust * 0.6)
    st = np.clip((fbm(33, beta=1.8, ax=1, ay=12) - 0.5) * 2.5, 0, 1)
    cv.C = cv.C * (1 - 0.12 * blur(st, 2)[..., None])
    Hn = blur(cv.H, 1.0)
    nrm = normal_from_height(Hn, 10.0)
    C = bake_light(cv.C, nrm, Hn, amt=0.10, ao=0.7, ao_sigma=6)
    save_set(slug, C, Hn, 10.0, cv.R)


GEN = {"sg_weathered_concrete": weathered_concrete, "sg_windows_blocks": windows_blocks,
       "sg_windows_capsule": windows_capsule, "sg_capsule_panels": capsule_panels,
       "sg_patched_panels": patched_panels}

if __name__ == "__main__":
    names = sys.argv[1:] or list(GEN)
    for n in names:
        GEN[n]()
        print("wrote", n)
