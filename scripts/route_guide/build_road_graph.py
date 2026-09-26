"""Build the route-guide road graph from the exported minimap road mask.

Input : scripts/route_guide/road_mask.json (export_road_mask.lua via mask_receiver.py)
Output: scripts/route_guide/RoadGraphData.lua (ModuleScript source, generated data only)
        scripts/route_guide/road_graph_preview.png (+ city crop) for review

Pipeline (pure Python, deterministic):
 1. decode per-row runs into a road pixel set;
 2. morphological closing (3x3) merges dual carriageways split by a 1-2 px median,
    then opening (3x3) removes 1-2 px outline/coast strokes;
 3. drop components smaller than MIN_COMPONENT pixels;
 4. Zhang-Suen thinning to 1 px centrelines;
 5. trace junction-to-junction edges, merging adjacent junction pixels;
 6. prune short dead-end spurs (thinning artefacts, baked-in map icons);
 7. simplify polylines (Ramer-Douglas-Peucker) and convert pixels to world X/Z
    with the minimap calibration (MapCalibrationStuds / MapCalibrationPixels,
    MapCoordinateRotationDegrees = 90, no flips, world centre 0,0).
"""
import json
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
from pngio import write_png  # noqa: E402

CAL_STUDS, CAL_PIXELS = 2850.0, 207.0
STUDS_PER_PIXEL = CAL_STUDS / CAL_PIXELS
MIN_COMPONENT = 400
SPUR_PIXELS = 9
RDP_EPSILON = 1.0
CONTRACT_PIXELS = 4.5  # merge junctions this close (diagonal crossings leave two nearby junctions)
GENERATOR_VERSION = 1

N8 = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0)]


def load_mask(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    road = set()
    for y, row in enumerate(data["rows"]):
        if not row:
            continue
        values = list(map(int, row.split(",")))
        for i in range(0, len(values), 2):
            for x in range(values[i], values[i] + values[i + 1]):
                road.add((x, y))
    return data, road


def dilate(pixels):
    grown = set(pixels)
    for x, y in pixels:
        for dx, dy in N8:
            grown.add((x + dx, y + dy))
    return grown


def closing(road):
    grown = dilate(road)
    return {p for p in grown if all((p[0] + dx, p[1] + dy) in grown for dx, dy in N8)}


def opening(road):
    eroded = {p for p in road if all((p[0] + dx, p[1] + dy) in road for dx, dy in N8)}
    opened = set()
    for x, y in eroded:
        opened.add((x, y))
        for dx, dy in N8:
            opened.add((x + dx, y + dy))
    return opened & road


def components(pixels):
    seen, result = set(), []
    for start in pixels:
        if start in seen:
            continue
        stack, comp = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dx, dy in N8:
                q = (x + dx, y + dy)
                if q in pixels and q not in seen:
                    seen.add(q)
                    stack.append(q)
        result.append(comp)
    return result


def thin(pixels):
    """Zhang-Suen thinning on a pixel set."""
    pixels = set(pixels)
    order = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]  # P2..P9
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            remove = []
            for x, y in pixels:
                n = [((x + dx, y + dy) in pixels) for dx, dy in order]
                b = sum(n)
                if b < 2 or b > 6:
                    continue
                a = sum(1 for i in range(8) if not n[i] and n[(i + 1) % 8])
                if a != 1:
                    continue
                p2, p4, p6, p8 = n[0], n[2], n[4], n[6]
                if step == 0 and (p2 and p4 and p6 or p4 and p6 and p8):
                    continue
                if step == 1 and (p2 and p4 and p8 or p2 and p6 and p8):
                    continue
                remove.append((x, y))
            if remove:
                changed = True
                pixels.difference_update(remove)
    return pixels


def neighbours(p, pixels):
    return [(p[0] + dx, p[1] + dy) for dx, dy in N8 if (p[0] + dx, p[1] + dy) in pixels]


RING = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]


def crossing_number(p, pixels):
    """Empty->road transitions around p: 1 = end, 2 = line (incl. staircases), >= 3 = junction."""
    n = [((p[0] + dx, p[1] + dy) in pixels) for dx, dy in RING]
    return sum(1 for i in range(8) if not n[i] and n[(i + 1) % 8])


def branch_count(p, pixels):
    """Number of 8-connected groups among p's neighbours (branches leaving p)."""
    around = neighbours(p, pixels)
    groups, seen = 0, set()
    for start in around:
        if start in seen:
            continue
        groups += 1
        stack = [start]
        seen.add(start)
        while stack:
            q = stack.pop()
            for r in around:
                if r not in seen and max(abs(r[0] - q[0]), abs(r[1] - q[1])) == 1:
                    seen.add(r)
                    stack.append(r)
    return groups


def remove_blocks(pixels):
    """Delete redundant pixels of 2x2 blocks when removal keeps local connectivity."""
    pixels = set(pixels)
    changed = True
    while changed:
        changed = False
        for p in sorted(pixels):
            if p not in pixels:
                continue
            x, y = p
            in_block = any(all((x + ax, y + ay) in pixels for ax, ay in ((0, 0), (sx, 0), (0, sy), (sx, sy)))
                           for sx in (-1, 1) for sy in (-1, 1))
            if in_block and len(neighbours(p, pixels)) >= 2 and branch_count(p, pixels) == 1:
                pixels.discard(p)
                changed = True
    return pixels


def build_graph(skeleton):
    node_pixels = set()
    for p in skeleton:
        count = len(neighbours(p, skeleton))
        if count <= 1 or crossing_number(p, skeleton) >= 3:
            node_pixels.add(p)
    # Merge touching junction pixels into one node.
    node_of, nodes = {}, []
    for comp in components(node_pixels):
        index = len(nodes)
        nodes.append([sum(q[0] for q in comp) / len(comp), sum(q[1] for q in comp) / len(comp)])
        for q in comp:
            node_of[q] = index
    used, edges = set(), []
    for start in node_pixels:
        for first in neighbours(start, skeleton):
            if first in node_pixels or first in used:
                continue
            path, prev, cur = [start, first], start, first
            seen = {start, first}
            end_node = None
            while True:
                candidates = [q for q in neighbours(cur, skeleton) if q not in seen]
                reached = [q for q in candidates if q in node_pixels and node_of[q] != node_of[start] or q in node_pixels and len(path) > 3]
                if reached:
                    end_node = reached[0]
                    path.append(end_node)
                    break
                line = [q for q in candidates if q not in node_pixels and q not in used]
                if not line:
                    break
                # Staircases offer a diagonal shortcut and an orthogonal step; take the one furthest from prev.
                step = max(line, key=lambda q: (q[0] - prev[0]) ** 2 + (q[1] - prev[1]) ** 2)
                for q in candidates:
                    seen.add(q)
                path.append(step)
                prev, cur = cur, step
            if end_node is not None:
                # Only a completed trace claims its pixels; a failed one may be traced from the other end.
                for q in path[1:-1]:
                    used.add(q)
                edges.append([node_of[start], node_of[end_node], path])
    return nodes, edges


def pixel_length(path):
    return sum(math.dist(path[i], path[i + 1]) for i in range(len(path) - 1))


def prune(nodes, edges):
    changed = True
    while changed:
        changed = False
        deg = [0] * len(nodes)
        for a, b, _ in edges:
            deg[a] += 1
            deg[b] += 1
        keep = []
        for edge in edges:
            a, b, path = edge
            if (deg[a] == 1 or deg[b] == 1) and pixel_length(path) < SPUR_PIXELS and not (deg[a] == 1 and deg[b] == 1 and pixel_length(path) > 3):
                changed = True
                continue
            keep.append(edge)
        edges = [e for e in keep if e[0] != e[1] or pixel_length(e[2]) > SPUR_PIXELS]
    # Drop self-loops and duplicate parallel edges keeping the shortest.
    best = {}
    for a, b, path in edges:
        if a == b:
            continue
        key = (min(a, b), max(a, b))
        if key not in best or pixel_length(path) < pixel_length(best[key][2]):
            best[key] = [a, b, path]
    edges = list(best.values())
    used = sorted({i for a, b, _ in edges for i in (a, b)})
    remap = {old: new for new, old in enumerate(used)}
    nodes = [nodes[i] for i in used]
    edges = [[remap[a], remap[b], path] for a, b, path in edges]
    return nodes, edges


def contract(nodes, edges):
    """Merge junction pairs joined by a very short edge so routes do not jog sideways at crossings."""
    changed = True
    while changed:
        changed = False
        for index, (a, b, path) in enumerate(edges):
            if a != b and pixel_length(path) < CONTRACT_PIXELS:
                ax, ay = nodes[a]
                bx, by = nodes[b]
                nodes[a] = [(ax + bx) / 2, (ay + by) / 2]
                merged = []
                for c, d, other in edges:
                    c = a if c == b else c
                    d = a if d == b else d
                    if c != d:
                        merged.append([c, d, other])
                edges = merged
                changed = True
                break
    return prune(nodes, edges)


def rdp(points, epsilon):
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = math.hypot(dx, dy) or 1.0
    index, dmax = 0, -1.0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        d = abs(dy * px - dx * py + x2 * y1 - y2 * x1) / norm if norm else math.dist(points[i], points[0])
        if d > dmax:
            index, dmax = i, d
    if dmax > epsilon:
        return rdp(points[: index + 1], epsilon)[:-1] + rdp(points[index:], epsilon)
    return [points[0], points[-1]]


def to_world(px, py, size):
    """Pixel (image x right, y down) -> world X/Z, inverse of the HUD mapping."""
    half = size / 2.0
    mx = (px + 0.5 - half) * STUDS_PER_PIXEL
    mz = (py + 0.5 - half) * STUDS_PER_PIXEL
    # HUD: mx = dx*cos - dz*sin, mz = dx*sin + dz*cos with 90 degrees -> mx = -dz, mz = dx.
    return mz, -mx


def main():
    data, road = load_mask(HERE / "road_mask.json")
    size = data["width"]
    closed = closing(road)
    opened = opening(closed)
    kept = set()
    for comp in components(opened):
        if len(comp) >= MIN_COMPONENT:
            kept.update(comp)
    skeleton = remove_blocks(thin(kept))
    nodes, edges = build_graph(skeleton)
    nodes, edges = prune(nodes, edges)
    nodes, edges = contract(nodes, edges)

    world_nodes = [to_world(x, y, size) for x, y in nodes]
    out_edges, polylines = [], []
    for a, b, path in edges:
        # Anchor ends on the merged node centres, then simplify.
        pts = [tuple(nodes[a])] + [(float(x), float(y)) for x, y in path[1:-1]] + [tuple(nodes[b])]
        simple = rdp(pts, RDP_EPSILON)
        world = [to_world(x, y, size) for x, y in simple]
        length = sum(math.dist(world[i], world[i + 1]) for i in range(len(world) - 1))
        out_edges.append((a, b, round(length, 1)))
        polylines.append(world[1:-1])

    lua = ["-- GENERATED by scripts/route_guide/build_road_graph.py from the minimap tiles. Do not edit by hand.",
           "-- Nodes are world X/Z; Edges are {nodeA, nodeB, lengthStuds}; Points[i] are interior X/Z pairs of edge i.",
           "return {",
           f"\tGeneratorVersion = {GENERATOR_VERSION},",
           f"\tSourceTiles = {{ {', '.join(json.dumps(t) for t in data['tiles'])} }},",
           f"\tStudsPerPixel = {STUDS_PER_PIXEL:.6f},",
           "\tNodes = {"]
    for x, z in world_nodes:
        lua.append(f"\t\t{x:.1f}, {z:.1f},")
    lua.append("\t},")
    lua.append("\tEdges = {")
    for a, b, length in out_edges:
        lua.append(f"\t\t{a + 1}, {b + 1}, {length},")
    lua.append("\t},")
    lua.append("\tPoints = {")
    for pts in polylines:
        lua.append("\t\t{" + ", ".join(f"{x:.1f}, {z:.1f}" for x, z in pts) + "},")
    lua.append("\t},")
    lua.append("}")
    (HERE / "RoadGraphData.lua").write_text("\n".join(lua) + "\n", encoding="utf-8")

    # Previews: mask grey, graph cyan, nodes pink.
    draw = {}
    for a, b, path in edges:
        for p in path:
            draw[p] = (43, 225, 218)
    for x, y in nodes:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                draw[(round(x) + dx, round(y) + dy)] = (244, 46, 151)

    def pixel(x, y, x0=0, y0=0, scale=1):
        p = (x0 + x * scale, y0 + y * scale)
        if scale == 1:
            if p in draw:
                return draw[p]
            return (70, 70, 70) if p in road else (18, 18, 18)
        for dx in range(scale):
            for dy in range(scale):
                q = (p[0] + dx, p[1] + dy)
                if q in draw:
                    return draw[q]
        return (70, 70, 70) if p in road else (18, 18, 18)

    write_png(HERE / "road_graph_preview.png", size // 2, size // 2, lambda x, y: pixel(x, y, scale=2))
    write_png(HERE / "road_graph_city.png", 480, 320, lambda x, y: pixel(x, y, 930, 950))
    report = {
        "road_pixels": len(road), "opened_pixels": len(opened), "kept_pixels": len(kept),
        "skeleton_pixels": len(skeleton), "nodes": len(nodes), "edges": len(edges),
        "components_kept": sum(1 for c in components(opened) if len(c) >= MIN_COMPONENT),
        "total_length_studs": round(sum(e[2] for e in out_edges)),
        "lua_bytes": (HERE / "RoadGraphData.lua").stat().st_size,
    }
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
