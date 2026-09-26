"""Route-line geometry lab: builds candidate road-graph geometries, measures them and draws comparisons.

Usage: py -3 scripts/route_guide/route_line_lab.py            (metrics table + comparison PNGs)
Outputs (scripts/route_guide/): lab_results.json, compare_diagonal.png, compare_ring.png

Coordinates are minimap pixels (pixel k covers [k-0.5, k+0.5]); 1 px = 13.768 studs.
The "true centre" is the midpoint of the road cross-section (perpendicular to the local
direction) in the processed road mask, sampled away from junctions.
"""
import json
import math
import pathlib
import pickle
import random
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import build_road_graph as brg  # noqa: E402
import centreline as cl  # noqa: E402
from pngio import write_png  # noqa: E402

SPP = brg.STUDS_PER_PIXEL
CACHE = HERE / "__pycache__" / "route_lab_base.pickle"


def base_graph():
    """Pixel skeleton graph (steps 1-6 of the generator), cached."""
    key = (brg.MIN_COMPONENT, brg.SPUR_PIXELS, brg.CONTRACT_PIXELS)
    if CACHE.exists():
        stored = pickle.loads(CACHE.read_bytes())
        if stored["key"] == key:
            return stored["value"]
    value = brg.pixel_graph()
    CACHE.parent.mkdir(exist_ok=True)
    CACHE.write_bytes(pickle.dumps({"key": key, "value": value}))
    return value


# ---------------------------------------------------------------- runtime smoothing ports

def smooth_quadratic_old(points, radius_px, samples=5):
    """Port of the previous RoadRouting.Smooth (per-vertex quadratic corner, radius capped at 0.45 segment)."""
    if len(points) < 3 or radius_px <= 0:
        return points
    out = [points[0]]
    for i in range(1, len(points) - 1):
        here = points[i]
        ix, iy = here[0] - points[i - 1][0], here[1] - points[i - 1][1]
        ox, oy = points[i + 1][0] - here[0], points[i + 1][1] - here[1]
        il, ol = math.hypot(ix, iy), math.hypot(ox, oy)
        if il > 1e-3 and ol > 1e-3:
            turn = math.acos(max(-1, min(1, (ix * ox + iy * oy) / (il * ol))))
            if turn < math.radians(4):
                out.append(here)
            else:
                r = min(radius_px, il * 0.45, ol * 0.45)
                a = (here[0] - ix / il * r, here[1] - iy / il * r)
                b = (here[0] + ox / ol * r, here[1] + oy / ol * r)
                for s in range(samples + 1):
                    t = s / samples
                    out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * here[0] + t * t * b[0],
                                (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * here[1] + t * t * b[1]))
    out.append(points[-1])
    return out


def chaikin(points, iterations=3):
    for _ in range(iterations):
        out = [points[0]]
        for i in range(len(points) - 1):
            a, b = points[i], points[i + 1]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(points[-1])
        points = out
    return points


def catmull_rom(points, spacing=2.0, alpha=0.5):
    """Centripetal Catmull-Rom through all points, sampled about every `spacing` px."""
    if len(points) < 3:
        return points
    pts = [points[0]] + list(points) + [points[-1]]
    out = [points[0]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg = math.dist(p1, p2)
        n = max(1, int(seg / spacing))

        def tj(ti, a, b):
            return ti + max(math.dist(a, b), 1e-4) ** alpha
        t0 = 0.0
        t1 = tj(t0, p0, p1)
        t2 = tj(t1, p1, p2)
        t3 = tj(t2, p2, p3)
        for s in range(1, n + 1):
            t = t1 + (t2 - t1) * s / n

            def lerp(a, b, ta, tb):
                w = (t - ta) / (tb - ta)
                return (a[0] + (b[0] - a[0]) * w, a[1] + (b[1] - a[1]) * w)
            a1, a2, a3 = lerp(p0, p1, t0, t1), lerp(p1, p2, t1, t2), lerp(p2, p3, t2, t3)
            b1, b2 = lerp(a1, a2, t0, t2), lerp(a2, a3, t1, t3)
            out.append(lerp(b1, b2, t1, t2))
    return out


# ---------------------------------------------------------------- routes

def graph_routes(nodes, edges, count=160, seed=7):
    """Random node-to-node shortest routes (Dijkstra), as edge chains with directions."""
    import heapq
    adj = {i: [] for i in range(len(nodes))}
    for index, (a, b, pts) in enumerate(edges):
        length = cl.polyline_length(pts)
        adj[a].append((b, index, length))
        adj[b].append((a, index, length))
    rng = random.Random(seed)
    candidates = [i for i in range(len(nodes)) if len(adj[i]) >= 2]
    routes = []
    while len(routes) < count:
        s, g = rng.sample(candidates, 2)
        dist, prev, heap = {s: 0.0}, {}, [(0.0, s)]
        while heap:
            d, n = heapq.heappop(heap)
            if n == g:
                break
            if d > dist[n]:
                continue
            for m, e, length in adj[n]:
                if d + length < dist.get(m, math.inf):
                    dist[m] = d + length
                    prev[m] = (n, e)
                    heapq.heappush(heap, (d + length, m))
        if g not in prev:
            continue
        chain, n = [], g
        while n != s:
            p, e = prev[n]
            chain.append((e, edges[e][0] == p))
            n = p
        chain.reverse()
        if 3 <= len(chain) <= 40:
            routes.append(chain)
    return routes


def route_polyline(edges, chain):
    out = []
    for e, forward in chain:
        pts = edges[e][2] if forward else edges[e][2][::-1]
        out.extend(pts if not out else pts[1:])
    return cl.despike(out)


def demo_route(geo, start, goal):
    nodes, edges = geo
    s = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], start))
    g = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], goal))
    import heapq
    adj = {}
    for index, (a, b, pts) in enumerate(edges):
        length = cl.polyline_length(pts)
        adj.setdefault(a, []).append((b, index, length))
        adj.setdefault(b, []).append((a, index, length))
    dist, prev, heap = {s: 0.0}, {}, [(0.0, s)]
    while heap:
        d, n = heapq.heappop(heap)
        if n == g or d > dist[n]:
            if n == g:
                break
            continue
        for m, e, length in adj.get(n, ()):
            if d + length < dist.get(m, math.inf):
                dist[m], prev[m] = d + length, (n, e)
                heapq.heappush(heap, (d + length, m))
    if g not in prev:
        return None
    chain, n = [], g
    while n != s:
        p, e = prev[n]
        chain.append((e, edges[e][0] == p))
        n = p
    return route_polyline(edges, chain[::-1])


# ---------------------------------------------------------------- metrics

JOG_LOG = []


def junction_jogs(geo, routes, runtime, reach=12.0):
    """Straight-through junctions (route turns < ~36 deg): max sideways jog of the drawn line within
    `reach` px of the node, measured against its own sigma-3px smoothing (0 = clean crossing)."""
    nodes, edges = geo
    jogs = []
    for chain in routes:
        poly = route_polyline(edges, chain)
        cum = [0.0]
        for i in range(1, len(poly)):
            cum.append(cum[-1] + math.dist(poly[i - 1], poly[i]))
        drawn = runtime(poly)
        # node positions along the route = joins between consecutive edges
        joins, walked = [], 0.0
        for e, forward in chain[:-1]:
            walked += cl.polyline_length(edges[e][2])
            joins.append(walked)
        dense = cl.resample(drawn, 0.5)
        dcum = [0.0]
        for i in range(1, len(dense)):
            dcum.append(dcum[-1] + math.dist(dense[i - 1], dense[i]))
        for n_join, j in enumerate(joins):
            if j - reach < 0 or j + reach > cum[-1]:
                continue
            # Skip junction pairs closer than `reach` (lane changes between carriageways are geometry, not jogs).
            if any(abs(other - j) < reach for m, other in enumerate(joins) if m != n_join):
                continue
            # nearest dense sample to the junction, then chord over +-reach along the drawn line
            node = min(range(len(poly)), key=lambda i: abs(cum[i] - j))
            k = min(range(len(dense)), key=lambda i: math.dist(dense[i], poly[node]))
            lo = next((i for i in range(k, -1, -1) if dcum[k] - dcum[i] >= reach), None)
            hi = next((i for i in range(k, len(dense)) if dcum[i] - dcum[k] >= reach), None)
            if lo is None or hi is None:
                continue
            a, b = dense[lo], dense[hi]
            if math.dist(a, b) < 2 * reach * 0.95:  # the route turns here; not a straight crossing
                continue
            # High-frequency sideways error: distance from the line's own sigma-3px smoothing.
            window = dense[max(0, lo - 12):hi + 13]
            smooth = cl.gaussian(window, 6)
            off = lo - max(0, lo - 12)
            jogs.append(max(math.dist(p, q) for p, q in list(zip(window, smooth))[off:off + hi - lo + 1]))
            JOG_LOG.append((jogs[-1], poly[node]))
    return jogs or [0.0]


def metrics(label, geo, routes, grid, junctions, runtime):
    nodes, edges = geo
    devs, offs, rough, reversals, kinks, counts, lengths, turning = [], [], [], 0, 0, [], [], 0.0
    for chain in routes:
        poly = runtime(route_polyline(edges, chain))
        counts.append(len(poly))
        length = cl.polyline_length(poly)
        lengths.append(length)
        dense = cl.resample(poly, 0.5)
        tangents = cl.tangents(dense, 2)
        for (x, y), (tx, ty) in zip(dense, tangents):
            offs.append(cl.outside_distance(grid, x, y))
            if cl.near_junction(junctions, x, y):
                continue
            dev = cl.cross_section_offset(grid, x, y, -ty, tx)
            if dev is not None:
                devs.append(abs(dev))
        smoothed = cl.gaussian(dense, 6)  # sigma 3 px
        rough.extend(math.dist(p, q) for p, q in zip(dense, smoothed) if not cl.near_junction(junctions, *p))
        # Vertex turns of the drawn polyline (what the renderer shows).
        last_sign, last_at, walked, last_kink = 0, -1e9, 0.0, -1e9
        for i in range(1, len(poly) - 1):
            walked += math.dist(poly[i - 1], poly[i])
            turn = cl.turn_angle(poly[i - 1], poly[i], poly[i + 1])
            if cl.near_junction(junctions, *poly[i]):
                continue
            turning += abs(turn)
            if abs(turn) > math.radians(2):
                sign = 1 if turn > 0 else -1
                if last_sign and sign != last_sign and walked - last_at < 30 / SPP:
                    reversals += 1
                last_sign, last_at = sign, walked
            if abs(turn) > math.radians(10) and not cl.near_junction(junctions, *poly[i]):
                kinks += 1
    jogs = junction_jogs(geo, routes, runtime)
    devs.sort()
    rough.sort()
    total = sum(lengths)
    pct = lambda values, q: values[min(len(values) - 1, int(q * len(values)))] if values else 0.0  # noqa: E731
    outside = [o for o in offs if o > 0]
    return {
        "label": label,
        "dev_mean_px": round(sum(devs) / len(devs), 3), "dev_p95_px": round(pct(devs, 0.95), 3), "dev_max_px": round(devs[-1], 3),
        "outside_pct": round(100 * len(outside) / len(offs), 2), "outside_max_px": round(max(offs), 2),
        "rough_rms_px": round(math.sqrt(sum(r * r for r in rough) / len(rough)), 3), "rough_p99_px": round(pct(rough, 0.99), 3),
        "midedge_turn_deg_per_100px": round(math.degrees(turning) / total * 100, 1),
        "reversals_per_1000px": round(reversals / total * 1000, 2),
        "kinks_per_1000px": round(kinks / total * 1000, 2),
        "jog_mean_px": round(sum(jogs) / len(jogs), 3), "jog_p95_px": round(pct(sorted(jogs), 0.95), 3),
        "route_pts_mean": round(sum(counts) / len(counts), 1), "route_pts_max": max(counts),
        "graph_pts": sum(len(e[2]) - 2 for e in edges) + len(nodes),
    }


# ---------------------------------------------------------------- drawing

FONT = {  # 3x5 glyphs, rows top->bottom
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
    "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
    "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
    "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
    "Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
    "6": "011100111101111", "7": "111001010010010", "8": "111101111101111", "9": "111101111001110",
    " ": "000000000000000", "-": "000000111000000", ".": "000000000000010", "+": "000010111010000",
    "/": "001001010100100", "(": "010100100100010", ")": "010001001001010", "=": "000111000111000",
}


class Canvas:
    def __init__(self, w, h, bg=(14, 16, 20)):
        self.w, self.h = w, h
        self.px = [[bg] * w for _ in range(h)]

    def blend(self, x, y, colour, alpha):
        if 0 <= x < self.w and 0 <= y < self.h and alpha > 0:
            r, g, b = self.px[y][x]
            a = min(1.0, alpha)
            self.px[y][x] = (int(r + (colour[0] - r) * a), int(g + (colour[1] - g) * a), int(b + (colour[2] - b) * a))

    def text(self, x, y, s, colour=(255, 255, 255), scale=2):
        for ch in s.upper():
            glyph = FONT.get(ch, FONT[" "])
            for i, bit in enumerate(glyph):
                if bit == "1":
                    for dx in range(scale):
                        for dy in range(scale):
                            self.blend(x + (i % 3) * scale + dx, y + (i // 3) * scale + dy, colour, 1)
            x += 4 * scale

    def thick_polyline(self, pts, width, colour, cap=True):
        """Anti-aliased round-joined stroke (capsule union), pts in canvas pixels."""
        half = width / 2
        cover = {}
        for i in range(len(pts) - 1):
            (ax, ay), (bx, by) = pts[i], pts[i + 1]
            x0, x1 = int(min(ax, bx) - half - 2), int(max(ax, bx) + half + 2)
            y0, y1 = int(min(ay, by) - half - 2), int(max(ay, by) + half + 2)
            dx, dy = bx - ax, by - ay
            ll = dx * dx + dy * dy
            for y in range(max(0, y0), min(self.h, y1 + 1)):
                for x in range(max(0, x0), min(self.w, x1 + 1)):
                    px, py = x + 0.5, y + 0.5
                    t = 0.0 if ll == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ll))
                    d = math.hypot(px - ax - dx * t, py - ay - dy * t)
                    c = max(0.0, min(1.0, half - d + 0.5))
                    if c > cover.get((x, y), 0):
                        cover[(x, y)] = c
        for (x, y), c in cover.items():
            self.blend(x, y, colour, c)


def panel(canvas, ox, oy, pw, ph, crop, zoom, grid, raw, poly_sets, mode):
    """Draw crop (x0, y0) of the map at `zoom` canvas px per map px, then polylines.
    mode 'geometry': thin line; mode 'render': simulated minimap (5 px line, 1.5 px outline at 1.18 UI px/map px)."""
    x0, y0 = crop
    for cy in range(ph):
        for cx in range(pw):
            mx, my = x0 + cx / zoom, y0 + cy / zoom
            ix, iy = int(math.floor(mx + 0.5)), int(math.floor(my + 0.5))
            if 0 <= ix < 2048 and 0 <= iy < 2048:
                if raw[iy * 2048 + ix]:
                    colour = (92, 96, 104)
                elif grid[iy * 2048 + ix]:
                    colour = (52, 56, 62)
                else:
                    colour = (20, 22, 27)
                canvas.px[oy + cy][ox + cx] = colour
    sub = Canvas(pw, ph)
    sub.px = [row[ox:ox + pw] for row in canvas.px[oy:oy + ph]]
    for pts, colour, width, outline in poly_sets:
        mapped = [((x - x0) * zoom, (y - y0) * zoom) for x, y in pts]
        if outline:
            sub.thick_polyline(mapped, width + 2 * outline, (9, 12, 16))
        sub.thick_polyline(mapped, width, colour)
    for cy in range(ph):
        canvas.px[oy + cy][ox:ox + pw] = sub.px[cy]


def main():
    base = base_graph()
    grid, raw = cl.grid_from(base["kept"]), cl.grid_from(base["road"])
    junctions = cl.junction_index(base["nodes"], base["edges"], grid)
    results, geos = [], {}
    r_old = 28 / SPP

    candidates = cl.candidates(base, grid)
    radii, _ = cl.junction_radii(base["nodes"], base["edges"], grid)
    sub = cl.build_centre(base["nodes"], base["edges"], grid, subpixel=True)
    for tol in (0.3, 0.6, 0.8):
        moved, fitted = cl.with_junctions(base["nodes"], base["edges"], sub, radii, grid,
                                          lambda pts, tol=tol: cl.fit_lines_arcs(pts, tol))
        candidates["E%02d" % round(tol * 100)] = (moved, [[a, b, pts] for (a, b, _), pts in zip(base["edges"], fitted)])
    runtimes = {
        "none": lambda p: p,
        "quad28_old": lambda p: smooth_quadratic_old(p, r_old),
        "chaikin3": lambda p: chaikin(p, 3),
        "catmull": lambda p: catmull_rom(p, 2.0),
        "fillet": lambda p: cl.fillet(p, cl.CORNER_RADIUS_PX),
        "fillet+cr": lambda p: catmull_rom(cl.fillet(p, cl.CORNER_RADIUS_PX), 2.0),
    }
    plan = [
        ("A  baseline (pixel skel, RDP1, quad r28)", "A", "quad28_old"),
        ("A2 baseline + chaikin x3", "A", "chaikin3"),
        ("A3 baseline + catmull-rom", "A", "catmull"),
        ("B  gauss skel + RDP.35 + fillet", "B", "fillet"),
        ("C  subpixel xsec + gauss + RDP.35 + fillet", "C", "fillet"),
        ("D  subpixel + line/arc fit + fillet", "D", "fillet"),
        ("E  D + LSQ junctions + fillet (tol 0.45) WINNER", "E", "fillet"),
        ("E2 E + catmull-rom", "E", "fillet+cr"),
        ("F  C + LSQ junctions + fillet", "F", "fillet"),
        ("E  tol 0.30", "E30", "fillet"),
        ("E  tol 0.60", "E60", "fillet"),
        ("E  tol 0.80", "E80", "fillet"),
        ("E  no runtime corner", "E", "none"),
        ("E  old quad r28", "E", "quad28_old"),
    ]
    routes = graph_routes(base["nodes"], candidates["A"][1])
    for label, key, rt in plan:
        geo = candidates[key]
        m = metrics(label, geo, routes, grid, junctions, runtimes[rt])
        m["candidate"], m["runtime"] = key, rt
        results.append(m)
        print(json.dumps(m))
    (HERE / "lab_results.json").write_text(json.dumps(results, indent=1), encoding="utf-8", newline="\n")

    # Comparison images: rows = candidates, columns = geometry zoom | simulated minimap.
    crops = {
        "compare_diagonal.png": ((1085, 800), (150, 105)),
        "compare_ring.png": ((1085, 1060), (130, 110)),
    }
    demos = {
        "compare_diagonal.png": [((1090, 900), (1230, 815)), ((1100, 830), (1225, 900))],
        "compare_ring.png": [((1090, 1150), (1210, 1070)), ((1095, 1075), (1205, 1165))],
    }
    show = [("A", "quad28_old", "A BASELINE"), ("C", "fillet", "C SUBPIXEL+RDP"), ("D", "fillet", "D LINE/ARC FIT"),
            ("E", "fillet", "E FIT+LSQ JUNCTIONS"), ("F", "fillet", "F SUBPIXEL+LSQ")]
    for name, ((x0, y0), (cw, ch)) in crops.items():
        gz, rz = 4, 1.18 * 2.5  # geometry zoom; simulated minimap at 2.5x magnification for viewing
        gw, gh = int(cw * gz), int(ch * gz)
        rw, rh = int(cw * rz), int(ch * rz)
        header = 22
        canvas = Canvas(gw + rw + 30, (max(gh, rh) + header + 10) * len(show) + 10)
        for row, (key, rt, title) in enumerate(show):
            nodes, edges = candidates[key]
            polys = []
            for a, b, pts in edges:
                if any(x0 - 20 <= x <= x0 + cw + 20 and y0 - 20 <= y <= y0 + ch + 20 for x, y in pts[::max(1, len(pts) // 20)] + [pts[-1]]):
                    polys.append(runtimes[rt](pts))
            oy = 10 + row * (max(gh, rh) + header + 10)
            canvas.text(10, oy, title, (230, 230, 230))
            panel(canvas, 10, oy + header, gw, gh, (x0, y0), gz, grid, raw, [(p, (43, 225, 218), 1.6, 0) for p in polys], "geometry")
            # Simulated minimap: demo routes drawn 5 px wide with a 1.5 px outline (UI px, x2.5 for viewing).
            sets = []
            for start, goal in demos[name]:
                route_poly = demo_route(candidates[key], start, goal)
                if route_poly:
                    sets.append((runtimes[rt](route_poly), (43, 225, 218), 5 * 2.5, 1.5 * 2.5))
            panel(canvas, gw + 20, oy + header, rw, rh, (x0, y0), rz / 1.0, grid, raw, sets, "render")
        write_png(HERE / name, canvas.w, canvas.h, lambda x, y: canvas.px[y][x])
        print("wrote", name)


if __name__ == "__main__":
    main()
