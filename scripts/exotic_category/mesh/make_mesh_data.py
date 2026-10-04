"""Build stage_b/data/mesh.json: which uploaded mesh parts make up each Exotic template.

    py -3 scripts/exotic_category/mesh/make_mesh_data.py <asset id>

Input: mesh/export/<car>/<SLOT>_<TRIM>.json (see export.py). The uploaded model asset holds one MeshPart
per module and paint channel, named <car>_<SLOT>_<TRIM>__<channel>. This file tells the content
installer which of those parts belong to which cockpit or ModuleId, with their bounds in cockpit-root
space and the jet sockets. Positions are root space: +X right, +Y up, forward -Z, studs.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "export")
OUT = os.path.join(HERE, "..", "stage_b", "data", "mesh.json")

CARS = {"A": {"cockpit": "exotic_05", "kit": 5, "fileOffsetX": 0.0},
        "B": {"cockpit": "exotic_02", "kit": 2, "fileOffsetX": 20.0},
        "C": {"cockpit": "exotic_01", "kit": 1, "fileOffsetX": 40.0},
        "D": {"cockpit": "exotic_03", "kit": 3, "fileOffsetX": 60.0},
        "E": {"cockpit": "exotic_04", "kit": 4, "fileOffsetX": 80.0},
        "F": {"cockpit": "exotic_06", "kit": 6, "fileOffsetX": 100.0}}
# Cars C to F (cars2.py): nozzle centres of the engines, and the boost nozzles per version.
ENGINE1 = {"C": (5.1, 0.52), "D": (5.1, 0.7), "E": (5.1, 0.68), "F": (5.1, 0.4)}
ENGINE2 = {"C": (5.05, 0.62), "D": (5.05, 0.7), "E": (5.14, 0.88), "F": (5.14, 0.92)}
SLOT_MAP = {"NOSE": "FrontBody", "TAIL": "RearBody", "FPOD": "Engine1", "RPOD": "Engine2", "STAB": "Stabilisers",
            "BOOST": "Boost", "WING": "RearSpoiler"}
TRIM_MAP = {"STD": "STANDARD", "GT": "LIGHTWEIGHT", "EVO": "POWER"}
CORE_PREFIX = {"Engine1": "MODULE_ENGINE_EXOTIC_", "Engine2": "MODULE_ENGINE_B_EXOTIC_",
               "Stabilisers": "MODULE_STABILISER_EXOTIC_", "Boost": "MODULE_BOOST_EXOTIC_"}
BODY_PREFIX = {"FrontBody": "MODULE_FRONTBODY_EXOTIC_", "RearBody": "MODULE_REARBODY_EXOTIC_",
               "RearSpoiler": "MODULE_REARSPOILER_EXOTIC_"}
REAR, DOWN = [0, 0, 1], [0, -1, 0]


def module_id(slot, kit, trim):
    if slot in CORE_PREFIX:
        return f"{CORE_PREFIX[slot]}{kit:02d}_{TRIM_MAP[trim]}"
    return f"{BODY_PREFIX[slot]}{kit:02d}" + ("" if trim == "STD" else "_" + trim)


def sockets(car, slot, trim):
    """Jet sockets in root space. dir is the way the flame points."""
    lvl = ("STD", "GT", "EVO").index(trim)
    a = car == "A"

    def pair(name, x, y, z, d):
        return [{"name": f"{name}_Left", "position": [-x, y, z], "dir": d},
                {"name": f"{name}_Right", "position": [x, y, z], "dir": d}]

    if car in ENGINE1:
        if slot == "Engine1":
            return pair("VFX_EngineJet", ENGINE1[car][0], ENGINE1[car][1], -5.4, REAR)
        if slot == "Engine2":
            return pair("VFX_EngineJet", ENGINE2[car][0], ENGINE2[car][1], 10.6, REAR)
        if slot == "Stabilisers":
            out = []
            for side, sx in (("Left", -4.9), ("Right", 4.9)):
                out.append({"name": f"VFX_StabiliserJet_{side}_Front", "position": [sx, -0.9, -3.3], "dir": DOWN})
                out.append({"name": f"VFX_StabiliserJet_{side}_Rear", "position": [sx, -0.9, 0.4], "dir": DOWN})
            return out
        if slot == "Boost":
            z = 12.0 + lvl * 0.15
            if car == "C":      # one wide slot burner; the full kit stacks a second one below it
                if lvl < 2:
                    return pair("VFX_BoostJet", 0.8, 0.85, z, REAR)
                return (pair("VFX_BoostJet", 0.8, 1.15, z, REAR)
                        + [{"name": "VFX_BoostJet_Top", "position": [0.8, 0.35, z], "dir": REAR},
                           {"name": "VFX_BoostJet_Back", "position": [-0.8, 0.35, z], "dir": REAR}])
            if car == "D":      # fishtail nozzle
                return pair("VFX_BoostJet", 0.7 + lvl * 0.1, 0.82, z + 0.15, REAR)
            if car == "E":      # twin turbines; the full kit adds an outer pair
                out = pair("VFX_BoostJet", 1.0, 1.28, z, REAR)
                if lvl == 2:
                    out += [{"name": "VFX_BoostJet_Top", "position": [1.95, 1.28, 12.0], "dir": REAR},
                            {"name": "VFX_BoostJet_Back", "position": [-1.95, 1.28, 12.0], "dir": REAR}]
                return out
            return pair("VFX_BoostJet", 1.08, 0.25 + lvl * 0.04, z, REAR)
        return []
    if slot == "Engine1":
        return pair("VFX_EngineJet", 5.1 if a else 4.95, 0.68 if a else 0.65, -5.4, REAR)
    if slot == "Engine2":
        up = (0, 0.15, 0.3)[lvl] if a else (0, 0.18, 0.36)[lvl]
        return pair("VFX_EngineJet", 5.12 if a else 4.88, (0.8 if a else 0.82) + up / 2, 10.6, REAR)
    if slot == "Stabilisers":
        x, zf, zr = (4.9, -3.3, 0.4) if a else (4.8, -3.2, 0.3)
        out = []
        for side, sx in (("Left", -x), ("Right", x)):
            out.append({"name": f"VFX_StabiliserJet_{side}_Front", "position": [sx, -0.9, zf], "dir": DOWN})
            out.append({"name": f"VFX_StabiliserJet_{side}_Rear", "position": [sx, -0.9, zr], "dir": DOWN})
        return out
    if slot == "Boost":
        if a:
            out = pair("VFX_BoostJet", 1.1, (0.2, 0.28, 0.34)[lvl], (12.0, 12.3, 12.45)[lvl], REAR)
            if lvl == 2:
                out += [{"name": "VFX_BoostJet_Top", "position": [0.75, 1.5, 11.9], "dir": REAR},
                        {"name": "VFX_BoostJet_Back", "position": [-0.75, 1.5, 11.9], "dir": REAR}]
            return out
        if lvl == 2:
            return ([{"name": "VFX_BoostJet_Back", "position": [0, 1.08, 12.55], "dir": REAR}]
                    + pair("VFX_BoostJet", 0.78, 1.64, 12.3, REAR))
        x, dy, z = ((0.38, 0.38, 12.15), (0.45, 0.42, 12.45))[lvl]
        return [{"name": "VFX_BoostJet_Left", "position": [-x, 1.08 + dy, z], "dir": REAR},
                {"name": "VFX_BoostJet_Right", "position": [x, 1.08 + dy, z], "dir": REAR},
                {"name": "VFX_BoostJet_Back", "position": [-x, 1.08 - dy, z], "dir": REAR},
                {"name": "VFX_BoostJet_Top", "position": [x, 1.08 - dy, z], "dir": REAR}]
    return []


def parts_of(car, fname):
    with open(os.path.join(EXPORT, car, fname)) as f:
        data = json.load(f)
    parts = {}
    for ch, c in data["channels"].items():
        v = c["v"]
        xs, ys, zs = v[0::3], v[1::3], v[2::3]
        mn, mx = (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))
        parts[f"{data['module']}__{ch}"] = {
            "channel": ch,
            "centre": [round((a + b) / 2, 4) for a, b in zip(mn, mx)],
            "size": [round(max(b - a, 0.001), 4) for a, b in zip(mn, mx)],
            "triangles": len(c["t"]) // 6,
        }
    return data["module"], parts


def main(asset_id):
    out = {"assetId": int(asset_id), "turnYDegrees": 180, "cars": CARS, "slotMap": SLOT_MAP, "trimMap": TRIM_MAP,
           "cockpits": {}, "modules": {}}
    for car, info in CARS.items():
        for fname in sorted(os.listdir(os.path.join(EXPORT, car))):
            if not fname.endswith(".json"):
                continue
            slot, trim = fname[:-5].split("_")
            source, parts = parts_of(car, fname)
            if slot == "COCKPIT":
                out["cockpits"][info["cockpit"]] = {"source": source, "car": car, "parts": parts}
                continue
            game_slot = SLOT_MAP[slot]
            out["modules"][module_id(game_slot, info["kit"], trim)] = {
                "source": source, "car": car, "slot": game_slot, "kit": info["kit"], "trim": trim, "parts": parts,
                "sockets": sockets(car, game_slot, trim)}
    with open(OUT, "w", newline="\n") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    new = sorted(k for k in out["modules"] if k.endswith(("_GT", "_EVO")))
    print(len(out["cockpits"]), "cockpits,", len(out["modules"]), "modules,", len(new), "new ids")
    print("\n".join(new))


if __name__ == "__main__":
    main(sys.argv[1])
