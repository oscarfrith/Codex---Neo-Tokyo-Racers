"""Find overlapping coplanar same-facing faces (z-fighting risk) between axis-aligned Block parts of the given specs."""
import json, sys, itertools
els = []
for f in sys.argv[1:]:
    for e in json.load(open(f))["elements"]:
        if e["t"] == "part" and e["shape"] == "Block" and all(abs(r) < 1e-6 for r in e["rot"]):
            lo = [e["pos"][i] - e["size"][i] / 2 for i in range(3)]; hi = [e["pos"][i] + e["size"][i] / 2 for i in range(3)]
            els.append((f.split("/")[-1], e["group"], e["name"], lo, hi))
hits = 0
for a, b in itertools.combinations(els, 2):
    for ax in range(3):
        o = [i for i in range(3) if i != ax]
        ov = all(min(a[4][i], b[4][i]) - max(a[3][i], b[3][i]) > 0.05 for i in o)
        if not ov: continue
        for side in (3, 4):
            if abs(a[side][ax] - b[side][ax]) < 0.01:
                plane = a[side][ax]
                if ax == 1 and side == 3 and plane <= 100.01: continue          # on the ground
                pts = []
                for fu in (0.1, 0.5, 0.9):
                    for fv in (0.1, 0.5, 0.9):
                        c = [0, 0, 0]; c[ax] = plane + (-0.05 if side == 3 else 0.05)
                        i, j = o
                        l0, h0 = max(a[3][i], b[3][i]), min(a[4][i], b[4][i]); l1, h1 = max(a[3][j], b[3][j]), min(a[4][j], b[4][j])
                        c[i] = l0 + (h0 - l0) * fu; c[j] = l1 + (h1 - l1) * fv
                        pts.append(c)
                def buried(c):
                    return any(all(p[3][k] - 1e-3 < c[k] < p[4][k] + 1e-3 for k in range(3)) for p in els if p is not a and p is not b)
                if all(buried(c) for c in pts): continue
                hits += 1
                print("coplanar", "xyz"[ax], "min" if side == 3 else "max", round(a[side][ax], 2), a[:3], b[:3])
print("hits", hits)
