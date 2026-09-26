"""Sub-pixel road centrelines for the route-guide graph (pure Python, deterministic).

Used by build_road_graph.py (production) and route_line_lab.py (candidate comparison).
Coordinates are minimap pixels; pixel k covers [k-0.5, k+0.5].

Production geometry (candidate E in ROUTE_LINE_OPTIONS.md):
  1. centre points: each skeleton pixel is moved to the midpoint of the road cross-section
     measured perpendicular to the local skeleton direction (sub-pixel), then lightly
     smoothed along the edge (symmetric Gaussian, ends pinned);
  2. junctions: every junction node moves to the least-squares intersection of its incident
     centre lines (fitted just outside the junction mouth); edge points inside the junction
     mouth are dropped so edges run straight into the node;
  3. each edge is fitted with the fewest straight lines and circular arcs within FIT_TOLERANCE,
     so straight streets are exactly straight and curves are true arcs (sampled finely).
"""
import math

SIZE = 2048
XSEC_MAX = 30.0          # px searched each side for a road edge
SMOOTH_SIGMA = 2.0       # px, along-edge smoothing of cross-section midpoints
FIT_TOLERANCE = 0.45     # px, max distance of fitted lines/arcs from the centre points
ARC_SAGITTA = 0.08       # px, max chord error when sampling arcs
ARC_MAX_STEP = math.radians(9)
JUNCTION_LINE_LENGTH = 10.0  # px of centre line (outside the mouth) used to fit junction directions
CORNER_RADIUS_PX = 50 / 13.768  # runtime CornerRadius default (50 studs) in px, used by the lab


# ---------------------------------------------------------------- grid and basic geometry

def grid_from(pixels):
    grid = bytearray(SIZE * SIZE)
    for x, y in pixels:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            grid[y * SIZE + x] = 1
    return grid


def is_road(grid, x, y):
    ix, iy = math.floor(x + 0.5), math.floor(y + 0.5)
    return 0 <= ix < SIZE and 0 <= iy < SIZE and grid[iy * SIZE + ix] == 1


def edge_distance(grid, x, y, nx, ny, maxd=XSEC_MAX):
    """Distance from (x, y) along (nx, ny) to the road boundary (bisection-refined), or None."""
    step, t = 0.25, 0.0
    while t < maxd:
        t += step
        if not is_road(grid, x + nx * t, y + ny * t):
            lo, hi = t - step, t
            for _ in range(6):
                mid = (lo + hi) / 2
                if is_road(grid, x + nx * mid, y + ny * mid):
                    lo = mid
                else:
                    hi = mid
            return (lo + hi) / 2
    return None


def cross_section(grid, x, y, nx, ny):
    """(left, right) edge distances along -n and +n, or None when off-road or unbounded."""
    if not is_road(grid, x, y):
        return None
    right = edge_distance(grid, x, y, nx, ny)
    left = edge_distance(grid, x, y, -nx, -ny)
    if right is None or left is None:
        return None
    return left, right


def cross_section_offset(grid, x, y, nx, ny, max_width=24.0):
    section = cross_section(grid, x, y, nx, ny)
    if not section or section[0] + section[1] > max_width:
        return None
    return (section[1] - section[0]) / 2


def outside_distance(grid, x, y, radius=6):
    if is_road(grid, x, y):
        return 0.0
    ix, iy = math.floor(x + 0.5), math.floor(y + 0.5)
    best = float(radius)
    for qy in range(iy - radius, iy + radius + 1):
        for qx in range(ix - radius, ix + radius + 1):
            if 0 <= qx < SIZE and 0 <= qy < SIZE and grid[qy * SIZE + qx]:
                dx = max(qx - 0.5 - x, 0.0, x - qx - 0.5)
                dy = max(qy - 0.5 - y, 0.0, y - qy - 0.5)
                best = min(best, math.hypot(dx, dy))
    return best


def polyline_length(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def resample(pts, step):
    if len(pts) < 2:
        return list(pts)
    out, carry = [pts[0]], 0.0
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        seg = math.hypot(bx - ax, by - ay)
        t = step - carry
        while t <= seg:
            out.append((ax + (bx - ax) * t / seg, ay + (by - ay) * t / seg))
            t += step
        carry = seg - (t - step)
    if math.dist(out[-1], pts[-1]) > 1e-6:
        out.append(pts[-1])
    return out


def tangents(pts, k):
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[max(0, i - k)], pts[min(n - 1, i + k)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1.0
        out.append((dx / length, dy / length))
    return out


def gaussian(pts, sigma_samples):
    """Symmetric-window Gaussian smoothing; the window shrinks towards the ends so ends stay fixed."""
    n = len(pts)
    if n < 3 or sigma_samples <= 0:
        return list(pts)
    radius = int(math.ceil(2.5 * sigma_samples))
    weights = [math.exp(-0.5 * (k / sigma_samples) ** 2) for k in range(radius + 1)]
    out = []
    for i in range(n):
        half = min(radius, i, n - 1 - i)
        sx = sy = sw = 0.0
        for k in range(-half, half + 1):
            w = weights[abs(k)]
            sx += pts[i + k][0] * w
            sy += pts[i + k][1] * w
            sw += w
        out.append((sx / sw, sy / sw))
    return out


def turn_angle(a, b, c):
    ux, uy = b[0] - a[0], b[1] - a[1]
    vx, vy = c[0] - b[0], c[1] - b[1]
    return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)


def rdp(points, epsilon):
    if len(points) < 3:
        return list(points)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        i, j = stack.pop()
        (x1, y1), (x2, y2) = points[i], points[j]
        dx, dy = x2 - x1, y2 - y1
        norm = math.hypot(dx, dy)
        index, dmax = -1, -1.0
        for k in range(i + 1, j):
            px, py = points[k]
            d = abs(dy * (px - x1) - dx * (py - y1)) / norm if norm > 1e-9 else math.dist(points[k], points[i])
            if d > dmax:
                index, dmax = k, d
        if index >= 0 and dmax > epsilon:
            keep[index] = True
            stack.append((i, index))
            stack.append((index, j))
    return [p for p, k in zip(points, keep) if k]


# ---------------------------------------------------------------- junction bookkeeping

def degrees(nodes, edges):
    deg = [0] * len(nodes)
    for a, b, _ in edges:
        deg[a] += 1
        deg[b] += 1
    return deg


def edge_half_width(grid, pts):
    """Median half width from cross-sections in the middle part of an edge."""
    n = len(pts)
    widths = []
    tans = tangents(pts, 3)
    for i in range(n // 4, max(n // 4 + 1, 3 * n // 4)):
        if 0 <= i < n:
            tx, ty = tans[i]
            section = cross_section(grid, pts[i][0], pts[i][1], -ty, tx)
            if section:
                widths.append(section[0] + section[1])
    if not widths:
        return 3.0
    widths.sort()
    return widths[len(widths) // 2] / 2


def junction_radii(nodes, edges, grid):
    """Mouth radius per node: widest incident half width + 2.5 px of kerb rounding (0 for plain nodes)."""
    deg = degrees(nodes, edges)
    halves = [edge_half_width(grid, [tuple(map(float, p)) for p in path]) for _, _, path in edges]
    widest = [0.0] * len(nodes)
    for (a, b, _), h in zip(edges, halves):
        widest[a] = max(widest[a], h)
        widest[b] = max(widest[b], h)
    radii = []
    for i in range(len(nodes)):
        if deg[i] >= 3:
            radii.append(widest[i] + 2.5)
        elif deg[i] == 1:
            radii.append(widest[i] + 1.5)
        else:
            radii.append(0.0)
    return radii, halves


def junction_index(nodes, edges, grid):
    radii, _ = junction_radii(nodes, edges, grid)
    cells = {}
    for (x, y), r in zip(nodes, radii):
        if r > 0:
            cells.setdefault((int(x // 32), int(y // 32)), []).append((x, y, r))
    return cells


def near_junction(index, x, y):
    cx, cy = int(x // 32), int(y // 32)
    for gx in (cx - 1, cx, cx + 1):
        for gy in (cy - 1, cy, cy + 1):
            for nx, ny, r in index.get((gx, gy), ()):
                if (x - nx) ** 2 + (y - ny) ** 2 < r * r:
                    return True
    return False


# ---------------------------------------------------------------- centre points

def base_points(nodes, a, b, path):
    return [tuple(nodes[a])] + [(float(x), float(y)) for x, y in path[1:-1]] + [tuple(nodes[b])]


def subpixel_points(grid, pts, half_width):
    """Move interior points to cross-section midpoints; unreliable sections keep the skeleton point."""
    tans = tangents(pts, 3)
    out = [pts[0]]
    limit = max(2.0 * half_width + 3.0, 6.0)
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        tx, ty = tans[i]
        section = cross_section(grid, x, y, -ty, tx)
        if section and section[0] + section[1] <= limit:
            shift = (section[1] - section[0]) / 2
            if abs(shift) <= 2.5:
                out.append((x - ty * shift, y + tx * shift))
                continue
        out.append((x, y))
    out.append(pts[-1])
    return out


def smooth_centre(pts, sigma_px=SMOOTH_SIGMA):
    dense = resample(pts, 0.5)
    return gaussian(dense, sigma_px / 0.5)


# ---------------------------------------------------------------- least-squares junctions

def _fit_line(pts):
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    sxx = sum((p[0] - cx) ** 2 for p in pts)
    syy = sum((p[1] - cy) ** 2 for p in pts)
    sxy = sum((p[0] - cx) * (p[1] - cy) for p in pts)
    angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
    dx, dy = math.cos(angle), math.sin(angle)
    rms = math.sqrt(sum(((p[0] - cx) * -dy + (p[1] - cy) * dx) ** 2 for p in pts) / n)
    return (cx, cy), (dx, dy), rms


def _between(pts, start, stop):
    """Points of pts whose arc distance from pts[0] lies in [start, stop]."""
    out, walked = [], 0.0
    for i in range(1, len(pts)):
        walked += math.dist(pts[i - 1], pts[i])
        if walked > stop:
            break
        if walked >= start:
            out.append(pts[i])
    return out


def trim_start(pts, distance):
    """Drop points within `distance` (arc length) of pts[0]; keeps pts[0]."""
    walked = 0.0
    for i in range(1, len(pts)):
        walked += math.dist(pts[i - 1], pts[i])
        if walked >= distance:
            return [pts[0]] + pts[i:]
    return [pts[0], pts[-1]]


def solve_junctions(nodes, edges, centre, radii, grid=None):
    """Least-squares intersection of the incident centre lines for each junction node."""
    incident = {}
    for index, (a, b, _) in enumerate(edges):
        incident.setdefault(a, []).append((index, True))
        incident.setdefault(b, []).append((index, False))
    moved = [tuple(p) for p in nodes]
    for node, items in incident.items():
        if len(items) < 3:
            continue
        r = radii[node]
        rows = []
        for index, forward in items:
            pts = centre[index] if forward else centre[index][::-1]
            window = _between(pts, r, r + JUNCTION_LINE_LENGTH)
            if len(window) < 4:
                continue
            c, d, rms = _fit_line(window)
            weight = 1.0 if rms < 0.35 else 0.3
            rows.append((c, (-d[1], d[0]), weight))
        x0, y0 = nodes[node]
        lam = 0.02 * max(1.0, sum(w for _, _, w in rows))
        a11 = a22 = lam
        a12 = 0.0
        b1, b2 = lam * x0, lam * y0
        for (cx, cy), (nx, ny), w in rows:
            a11 += w * nx * nx
            a12 += w * nx * ny
            a22 += w * ny * ny
            dot = nx * cx + ny * cy
            b1 += w * nx * dot
            b2 += w * ny * dot
        det = a11 * a22 - a12 * a12
        if abs(det) < 1e-9:
            continue
        x = (b1 * a22 - b2 * a12) / det
        y = (a11 * b2 - a12 * b1) / det
        # Keep the solution only when the lines really meet there and it lies on the road.
        miss = max((abs(nx * (x - cx) + ny * (y - cy)) for (cx, cy), (nx, ny), w in rows if w >= 1.0), default=0.0)
        if math.hypot(x - x0, y - y0) > r or miss > 1.5 or (grid is not None and outside_distance(grid, x, y) > 0):
            continue
        moved[node] = (x, y)
    return moved


# ---------------------------------------------------------------- line / arc fitting

def _line_ok(S, pts, tol, end=None):
    if end is not None:
        dx, dy = end[0] - S[0], end[1] - S[1]
    else:
        sxx = sum((p[0] - S[0]) ** 2 for p in pts)
        syy = sum((p[1] - S[1]) ** 2 for p in pts)
        sxy = sum((p[0] - S[0]) * (p[1] - S[1]) for p in pts)
        angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
        dx, dy = math.cos(angle), math.sin(angle)
        if dx * (pts[-1][0] - S[0]) + dy * (pts[-1][1] - S[1]) < 0:
            dx, dy = -dx, -dy
    length = math.hypot(dx, dy)
    if length < 1e-9:
        return None
    dx, dy = dx / length, dy / length
    last = -1e9
    for p in pts:
        vx, vy = p[0] - S[0], p[1] - S[1]
        if abs(vx * -dy + vy * dx) > tol:
            return None
        along = vx * dx + vy * dy
        if along < last - tol:
            return None
        last = max(last, along)
    if end is not None:
        return (end,)
    tip = pts[-1]
    t = (tip[0] - S[0]) * dx + (tip[1] - S[1]) * dy
    return ((S[0] + dx * t, S[1] + dy * t),)


def _circle_through(S, pts, end=None):
    # x^2+y^2+Dx+Ey+F=0 through S:  (x^2+y^2-|S|^2) + D(x-Sx) + E(y-Sy) = 0
    s2 = S[0] ** 2 + S[1] ** 2
    rows = [((p[0] - S[0], p[1] - S[1]), -(p[0] ** 2 + p[1] ** 2 - s2)) for p in pts]
    if end is None:
        a11 = sum(r[0][0] ** 2 for r in rows)
        a12 = sum(r[0][0] * r[0][1] for r in rows)
        a22 = sum(r[0][1] ** 2 for r in rows)
        b1 = sum(r[0][0] * r[1] for r in rows)
        b2 = sum(r[0][1] * r[1] for r in rows)
        det = a11 * a22 - a12 * a12
        if abs(det) < 1e-9:
            return None
        D = (b1 * a22 - b2 * a12) / det
        E = (a11 * b2 - a12 * b1) / det
    else:
        # Also through `end`: ex*D + ey*E = c  ->  (D, E) = p0 + t*q
        ex, ey = end[0] - S[0], end[1] - S[1]
        c = -(end[0] ** 2 + end[1] ** 2 - s2)
        ee = ex * ex + ey * ey
        if ee < 1e-9:
            return None
        p0 = (ex * c / ee, ey * c / ee)
        q = (-ey, ex)
        num = den = 0.0
        for (ax, ay), b in rows:
            aq = ax * q[0] + ay * q[1]
            num += aq * (b - ax * p0[0] - ay * p0[1])
            den += aq * aq
        if den < 1e-12:
            return None
        t = num / den
        D, E = p0[0] + t * q[0], p0[1] + t * q[1]
    cx, cy = -D / 2, -E / 2
    return (cx, cy), math.hypot(S[0] - cx, S[1] - cy)


def _arc_ok(S, pts, tol, end=None, min_radius=3.0, max_radius=4000.0):
    circle = _circle_through(S, pts, end)
    if not circle:
        return None
    (cx, cy), r = circle
    if r < min_radius or r > max_radius:
        return None
    a0 = math.atan2(S[1] - cy, S[0] - cx)
    sweep_sign, last = 0, 0.0
    for p in pts:
        if abs(math.hypot(p[0] - cx, p[1] - cy) - r) > tol:
            return None
        a = math.atan2(p[1] - cy, p[0] - cx) - a0
        a = (a + math.pi) % (2 * math.pi) - math.pi
        if abs(a) > 1e-6:
            sign = 1 if a > 0 else -1
            if sweep_sign and sign != sweep_sign and abs(a) > 0.05:
                return None
            sweep_sign = sweep_sign or sign
        if abs(a) + 1e-9 < abs(last) - tol / r:
            return None
        last = a if abs(a) > abs(last) else last
    tip = end if end is not None else pts[-1]
    a_end = math.atan2(tip[1] - cy, tip[0] - cx) - a0
    a_end = (a_end + math.pi) % (2 * math.pi) - math.pi
    if abs(a_end) < 1e-4:
        return None
    return ("arc", (cx, cy), r, a0, a_end)


def _arc_points(S, arc, end):
    _, (cx, cy), r, a0, sweep = arc
    step = min(ARC_MAX_STEP, 2 * math.acos(max(-1.0, 1 - ARC_SAGITTA / r)))
    n = max(1, int(math.ceil(abs(sweep) / step)))
    out = [(cx + r * math.cos(a0 + sweep * k / n), cy + r * math.sin(a0 + sweep * k / n)) for k in range(1, n)]
    if end is not None:
        out.append(end)
    else:
        out.append((cx + r * math.cos(a0 + sweep), cy + r * math.sin(a0 + sweep)))
    return out


def fit_lines_arcs(pts, tol=FIT_TOLERANCE):
    """Greedy: from the current start, the primitive (line preferred, else arc) that reaches furthest."""
    if len(pts) < 3:
        return list(pts)
    pts = resample(pts, 1.0)
    pts[-1] = tuple(pts[-1])
    n = len(pts)
    if n < 3:
        return list(pts)
    out = [pts[0]]
    S, i = pts[0], 0
    while i < n - 1:
        best = None  # (j, kind, payload)
        for kind in ("line", "arc"):
            misses, j = 0, i + 1
            reach = None
            while j <= n - 1:
                window = pts[i + 1:j + 1]
                final = j == n - 1
                if kind == "line":
                    fit = _line_ok(S, window, tol, pts[-1] if final else None)
                else:
                    fit = _arc_ok(S, window, tol, pts[-1] if final else None) if len(window) >= 3 else None
                if fit:
                    reach, misses = (j, fit), 0
                else:
                    misses += 1
                    if misses > 6:
                        break
                j += 1
            if reach and (best is None or reach[0] > best[0] + (4 if kind == "arc" else 0)):
                best = (reach[0], kind, reach[1])
        if best is None:
            j = i + 1
            out.append(pts[j])
            S, i = pts[j], j
            continue
        j, kind, fit = best
        final = j == n - 1
        if kind == "line":
            out.append(fit[0])
        else:
            out.extend(_arc_points(S, fit, pts[-1] if final else None))
        S, i = out[-1], j
    return out


# ---------------------------------------------------------------- runtime corner fillet (mirror of RoadRouting.Smooth)

def fillet(points, radius, min_turn=math.radians(10), samples=8):
    """Round corners (turn >= min_turn) with a quadratic curve spanning `radius` of arc length each side."""
    n = len(points)
    if n < 3 or radius <= 0:
        return list(points)
    cum = [0.0]
    for i in range(1, n):
        cum.append(cum[-1] + math.dist(points[i - 1], points[i]))
    corners = [i for i in range(1, n - 1) if abs(turn_angle(points[i - 1], points[i], points[i + 1])) >= min_turn]
    if not corners:
        return list(points)

    def at(distance):
        distance = max(0.0, min(cum[-1], distance))
        lo, hi = 0, n - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if cum[mid] <= distance:
                lo = mid
            else:
                hi = mid
        seg = cum[hi] - cum[lo]
        t = 0.0 if seg <= 0 else (distance - cum[lo]) / seg
        a, b = points[lo], points[hi]
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

    out, cursor, last_end = [points[0]], 1, 0.0
    for k, i in enumerate(corners):
        prev_c = cum[corners[k - 1]] if k > 0 else 0.0
        next_c = cum[corners[k + 1]] if k + 1 < len(corners) else cum[-1]
        r = min(radius, (cum[i] - prev_c) * (0.5 if k > 0 else 1.0), (next_c - cum[i]) * (0.5 if k + 1 < len(corners) else 1.0))
        start = max(cum[i] - r, last_end)
        if r < 0.05 or start >= cum[i]:
            continue
        while cursor < n - 1 and cum[cursor] <= start:
            if cum[cursor] > last_end + 1e-9:
                out.append(points[cursor])
            cursor += 1
        a, v, b = at(start), points[i], at(cum[i] + r)
        # Use the actual tangents at a and b so dense (curved) approaches join without a kink.
        turn = abs(turn_angle(a, v, b))
        steps = max(2, int(math.ceil(samples * turn / (math.pi / 2))))
        for s in range(steps + 1):
            t = s / steps
            out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * v[0] + t * t * b[0],
                        (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * v[1] + t * t * b[1]))
        last_end = cum[i] + r
        while cursor < n - 1 and cum[cursor] <= last_end:
            cursor += 1
    for j in range(cursor, n):
        if cum[j] > last_end + 1e-9 or j == n - 1:
            out.append(points[j])
    clean = [out[0]]
    for q in out[1:]:
        if math.dist(q, clean[-1]) > 1e-4:
            clean.append(q)
    clean[-1] = points[-1]
    return clean


# ---------------------------------------------------------------- candidate builders

def build_centre(nodes, edges, grid, subpixel=True):
    _, halves = junction_radii(nodes, edges, grid)
    centre = []
    for (a, b, path), h in zip(edges, halves):
        pts = base_points(nodes, a, b, path)
        if subpixel:
            pts = subpixel_points(grid, pts, h)
        centre.append(smooth_centre(pts))
    return centre


def clean_ends(pts, near=1.5, hook=3.0, hook_turn=math.radians(60)):
    """Drop interior points that form tiny tails or hooks next to an edge's end nodes."""
    pts = list(pts)
    for _ in range(2):
        while len(pts) > 2:
            d = math.dist(pts[0], pts[1])
            if d < near or (len(pts) > 2 and d < hook and abs(turn_angle(pts[0], pts[1], pts[2])) > hook_turn):
                del pts[1]
            else:
                break
        pts.reverse()
    return pts


def despike(pts, max_leg=120 / 13.768, min_turn=math.radians(120)):
    """Mirror of the runtime despike in RoadRouting.FindRoute: remove short doubling-back vertices."""
    pts = list(pts)
    i = 1
    while i < len(pts) - 1:
        if (abs(turn_angle(pts[i - 1], pts[i], pts[i + 1])) >= min_turn
                and min(math.dist(pts[i - 1], pts[i]), math.dist(pts[i], pts[i + 1])) < max_leg):
            del pts[i]
            i = max(1, i - 1)
        else:
            i += 1
    return pts


def inside_road(grid, pts, tolerance=0.35):
    return all(outside_distance(grid, x, y, 2) <= tolerance for x, y in resample(pts, 0.5))


def with_junctions(nodes, edges, centre, radii, grid, finish):
    """Junction nodes at least-squares intersections; each edge trimmed inside the junction mouths so it
    runs straight into its node, then finished (fitted). Falls back to shorter trims, then to the
    untrimmed centre line, whenever a result would leave the road."""
    moved = solve_junctions(nodes, edges, centre, radii, grid)
    deg = degrees(nodes, edges)
    out = []
    for (a, b, _), pts in zip(edges, centre):
        length = polyline_length(pts)
        ra = radii[a] if deg[a] >= 3 else 0.0
        rb = radii[b] if deg[b] >= 3 else 0.0
        result = None
        for share in (1.0, 0.5, 0.0):
            ta, tb = ra * share, rb * share
            if ta + tb >= length * 0.8:
                trial = [moved[a], moved[b]]
            else:
                trial = list(pts)
                if ta > 0:
                    trial = trim_start(trial, ta)
                if tb > 0:
                    trial = trim_start(trial[::-1], tb)[::-1]
                trial[0], trial[-1] = moved[a], moved[b]
            fitted = clean_ends(finish(trial))
            if inside_road(grid, fitted):
                result = fitted
                break
        if result is None:
            fallback = [tuple(nodes[a])] + list(pts[1:-1]) + [tuple(nodes[b])]
            result = clean_ends(finish(fallback))
            if not inside_road(grid, result):
                result = fallback
        out.append(result)
    return moved, out


def candidates(base, grid):
    nodes, edges = base["nodes"], base["edges"]
    radii, _ = junction_radii(nodes, edges, grid)
    result = {}
    result["A"] = (nodes, [[a, b, rdp(base_points(nodes, a, b, p), 1.0)] for a, b, p in edges])
    skel = build_centre(nodes, edges, grid, subpixel=False)
    result["B"] = (nodes, [[a, b, rdp(pts, 0.35)] for (a, b, _), pts in zip(edges, skel)])
    sub = build_centre(nodes, edges, grid, subpixel=True)
    result["C"] = (nodes, [[a, b, rdp(pts, 0.35)] for (a, b, _), pts in zip(edges, sub)])
    result["D"] = (nodes, [[a, b, fit_lines_arcs(pts)] for (a, b, _), pts in zip(edges, sub)])
    moved, fitted = with_junctions(nodes, edges, sub, radii, grid, fit_lines_arcs)
    result["E"] = (moved, [[a, b, pts] for (a, b, _), pts in zip(edges, fitted)])
    moved, simple = with_junctions(nodes, edges, sub, radii, grid, lambda pts: rdp(pts, 0.35))
    result["F"] = (moved, [[a, b, pts] for (a, b, _), pts in zip(edges, simple)])
    return result


def production(base, grid):
    """Candidate E: sub-pixel centres, least-squares junctions, line/arc fit."""
    nodes, edges = base["nodes"], base["edges"]
    radii, _ = junction_radii(nodes, edges, grid)
    sub = build_centre(nodes, edges, grid, subpixel=True)
    moved, fitted = with_junctions(nodes, edges, sub, radii, grid, fit_lines_arcs)
    return moved, [[a, b, pts] for (a, b, _), pts in zip(edges, fitted)]
