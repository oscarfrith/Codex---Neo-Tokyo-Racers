"""Exotic category, Stage B: build the content installer.

Reads
  scripts/vehicle_blockouts/specs/exotic.json          geometry (flattened with vbspec, as the blockout builder does)
  scripts/exotic_category/balance/balance.json         stats, prices, upgrade paths (another builder owns it)
  scripts/exotic_category/catalogue/catalogue_gen.lua  catalogue generator (another builder owns it)
  roblox/captures/exotic-before/capture.json           live Piercer attribute sets (donors and constants)
  data/*.json in this folder                           ids, colours, seats, sockets, VFX scales, cockpit fixtures
  data/mesh.json                                       uploaded mesh parts for the mesh kits (written by mesh/make_mesh_data.py)
and writes
  out/installer.lua       one self-contained Luau chunk: data + catalogue generator + installer_engine.lua
  out/summary-<scope>.json  what the installer will build (ids, counts, sockets, seats, warnings)
  fingerprints.json       per-group part counts and position sums, to compare with the Studio blockout

Usage:  py -3 scripts/exotic_category/stage_b/build_content.py --mode AUDIT|APPLY|ROLLBACK --scope pilot|full

The mode and scope are baked into out/installer.lua, so the same canonical installer is rebuilt per mode.
Nothing here touches Studio.
"""
import argparse
import hashlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "scripts", "vehicle_blockouts"))
import numpy as np  # noqa: E402
import vbspec  # noqa: E402

SPEC_PATH = os.path.join(REPO, "scripts", "vehicle_blockouts", "specs", "exotic.json")
BALANCE_PATH = os.path.join(REPO, "scripts", "exotic_category", "balance", "balance.json")
CATALOGUE_GEN_PATH = os.path.join(REPO, "scripts", "exotic_category", "catalogue", "catalogue_gen.lua")
CAPTURE_PATH = os.path.join(REPO, "roblox", "captures", "exotic-before", "capture.json")
ENGINE_PATH = os.path.join(HERE, "installer_engine.lua")
DATA_DIR = os.path.join(HERE, "data")
OUT_DIR = os.path.join(HERE, "out")
FINGERPRINTS_PATH = os.path.join(HERE, "fingerprints.json")
MESH_PATH = os.path.join(DATA_DIR, "mesh.json")

MODES = ("AUDIT", "APPLY", "ROLLBACK")
SCOPES = ("pilot", "full")
RAW = ("TopSpeed EngineOutput Weight LateralGrip SteeringResponse HoverStability DriftControl DriftGrip DriftChargeRate "
       "BrakingForce BoostForce BoostDuration BoostRecharge BoostRechargeDelay BoostEfficiency Drag Downforce").split()

# Words the game matches on instance names (paintvfx.md 4.9 and 9, INTERFACE.md IDs).
FORBIDDEN_ANY_MODULE = ("cockpit", "engineon", "engineoff", "booston", "stabiliseron", "stabilizeron")
FORBIDDEN_BODY_MODULE = ("engine", "boost", "stabiliser", "stabilizer")

# Attributes copied from the live donor when balance.json does not set them: notes and flags, never stats or prices.
MODULE_PASSTHROUGH = {
    "BalanceEditable", "BalanceNote", "BoostNotes", "CatalogPublishReady", "CatalogVisible", "HiddenFromCatalog",
    "RetiredFromCatalog", "PreviewImage", "Upgradable", "V2IntegrationReady", "V2Materialised", "V2Published",
    "V2MaterialisationVersion", "Level", "MaxLevel",
}
# Names Stage A adds; they are not on any Piercer donor.
MODULE_OPT_IN = {"CardTitle", "RatingReferenceCockpitId"}
# mesh/INTEGRATION.md E1: body modules are locked to the cockpit of their kit, as core modules are. The
# accessory donors carry neither name. F4: body modules also carry VariantName (Standard, GT, EVO) and
# VariantOrder (10, 20, 30), which the donors lack too. PurchasePrice stays off body modules.
BODY_MODULE_OPT_IN = {"SourceCockpitId", "SourceCockpitDisplayName", "VariantName", "VariantOrder"}
BODY_MODULE_BANNED = ("PurchasePrice",)
BODY_VARIANT = {None: ("Standard", 10), "GT": ("GT", 20), "EVO": ("EVO", 30)}
COCKPIT_OPT_IN = {
    "DefaultFrontBodyModuleId", "DefaultRearBodyModuleId", "DefaultSidePodsModuleId", "DefaultFrontBumperModuleId",
    "DefaultRearBumperModuleId", "DefaultRearSpoilerModuleId", "DriverSeatOffsetX", "DriverSeatOffsetY",
    "DriverSeatOffsetZ", "PassengerSeatOffsetX", "PassengerSeatOffsetY", "PassengerSeatOffsetZ",
}

WHITE = {"__c3": [255, 255, 255]}
COCKPIT_FOLDERS = [
    {"name": "PRIMARY_ReplaceWithPrimaryMeshes", "channel": "P", "attributes": {"PaintChannel": "Primary", "PutMeshesFor": "Primary"}},
    {"name": "SECONDARY_ReplaceWithSecondaryMeshes", "channel": "S", "attributes": {"PaintChannel": "Secondary", "PutMeshesFor": "Secondary"}},
    {"name": "DETAIL_ReplaceWithDetailMeshes", "channel": "D", "attributes": {"PaintChannel": "Detail", "PutMeshesFor": "Detail"}},
    {"name": "GLASS_ReplaceWithGlassMeshes", "channel": "G", "attributes": {"PaintChannel": "Glass", "PutMeshesFor": "Glass"}},
    {"name": "NEON_OptionalLights", "channel": "N", "attributes": {"PaintChannel": "Neon", "PutMeshesFor": "Neon"}},
]
_PRIMARY = {"name": "PRIMARY_ReplaceWithPrimaryMeshes", "channel": "P", "attributes": {"PaintChannel": "Primary", "Purpose": "Put primary-colour meshes here.", "PutMeshesFor": "Primary"}}
_SECONDARY = {"name": "SECONDARY_ReplaceWithSecondaryMeshes", "channel": "S", "attributes": {"PaintChannel": "Secondary", "Purpose": "Put secondary-colour meshes here.", "PutMeshesFor": "Secondary"}}
_DETAIL = {"name": "DETAIL_ReplaceWithDetailMeshes", "channel": "D", "attributes": {"PaintChannel": "Detail", "Purpose": "Put detail-colour meshes here.", "PutMeshesFor": "Detail"}}
_NEON = {"name": "NEON_OptionalLights", "channel": "N", "attributes": {"DefaultColor": WHITE, "PaintChannel": "Neon", "Purpose": "Optional cosmetic lights. Default colour is white.", "PutMeshesFor": "Neon"}}
_LIGHTS = {"name": "LIGHTS_AlwaysOn", "channel": "L", "attributes": {"PaintChannel": "Lights", "Purpose": "Fixed lamps. Always on. Not player-paintable.", "PutMeshesFor": "Lights"}}
_VFX = {"name": "VFXAttachments", "channel": None, "attributes": {"Note": "Actual VFX sockets are Attachments under ModuleRoot. Move/rotate attachments to aim jets."}}
_THRUST = {"name": "THRUST_COLOR_WhiteByDefault", "channel": "T", "attributes": {"DefaultColor": WHITE, "PaintChannel": "ThrustColor", "Purpose": "Included thrust-colour meshes. Default colour is white."}}
# Child order as on the live Piercer modules. The engine adds VehiclePerformanceV2UpgradePaths and the root after these.
MODULE_FOLDERS = {
    "core": [_PRIMARY, _SECONDARY, _DETAIL, _NEON, _VFX, _THRUST],
    "body": [_PRIMARY, _SECONDARY, _DETAIL, _NEON, _VFX],
    "bodyLamps": [_PRIMARY, _SECONDARY, _DETAIL, _NEON, _LIGHTS, _VFX],
    # Mesh modules only (mesh/INTEGRATION.md D10): an engine, stabiliser or boost that carries always-on lamps.
    "coreLamps": [_PRIMARY, _SECONDARY, _DETAIL, _NEON, _LIGHTS, _VFX, _THRUST],
}

# Mesh kits (mesh/INTEGRATION.md). Channel name in data/mesh.json -> part code. Modules carry no glass (D10).
MESH_SHAPE = "mesh"
MESH_MODULE_CODES = {"primary": "P", "secondary": "S", "detail": "D", "glass": "D", "thrust": "T", "neon": "N", "lights": "L", "lights_red": "R"}
MESH_COCKPIT_CODES = {"primary": "P", "secondary": "S", "detail": "D", "glass": "G"}
MESH_CENTRE_TOLERANCE = 0.05


class BuildError(Exception):
    pass


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def clean(value, digits):
    """Round and turn -0.0 into 0.0."""
    return round(float(value), digits) + 0.0


def hex_rgb(text):
    text = text.lstrip("#")
    return [int(text[i:i + 2], 16) for i in (0, 2, 4)]


# ------------------------------------------------------------------------------------------------
# Geometry (same flattening and rounding as scripts/vehicle_blockouts/export_showroom.py)
# ------------------------------------------------------------------------------------------------
def flatten(parts):
    out = []
    for p in vbspec.expand_parts(parts):
        out.append({
            "shape": p["shape"],
            "size": [clean(v, 3) for v in p["size"]],
            "pos": [clean(v, 3) for v in p["pos"]],
            "rot": [clean(v, 2) for v in p["rot"]],
            "ch": p["ch"],
        })
    return out


def built_size(shape, size):
    """Part.Size as scripts/vehicle_blockouts/builder.lua sets it."""
    sx, sy, sz = size
    if shape in ("block", "wedge", MESH_SHAPE):
        return [sx, sy, sz]
    if shape == "ball":
        d = min(sx, sy, sz)
        return [d, d, d]
    if shape == "cyl_x":
        d = min(sy, sz)
        return [sx, d, d]
    if shape == "cyl_y":
        d = min(sx, sz)
        return [sy, d, d]
    if shape == "cyl_z":
        d = min(sx, sy)
        return [sz, d, d]
    raise BuildError("unknown shape %r" % shape)


def fingerprint(parts):
    """[count, sum x, sum |x|, sum y, sum z, sum of size components] of a group in root space."""
    n = len(parts)
    sx = sum(p["pos"][0] for p in parts)
    sax = sum(abs(p["pos"][0]) for p in parts)
    sy = sum(p["pos"][1] for p in parts)
    sz = sum(p["pos"][2] for p in parts)
    ss = sum(sum(built_size(p["shape"], p["size"])) for p in parts)
    return [n, clean(sx, 3), clean(sax, 3), clean(sy, 3), clean(sz, 3), clean(ss, 3)]


def all_fingerprints(spec):
    out = {}
    for cid, c in spec["cockpits"].items():
        out["Cockpit/" + cid] = fingerprint(flatten(c["parts"]))
    for slot, mods in spec["modules"].items():
        for mid, m in mods.items():
            out["%s/%s" % (slot, mid)] = fingerprint(flatten(m["parts"]))
    return out


def mesh_fingerprints(mesh):
    """Per mesh group: the fingerprint of the part bounds in root space and the source part names."""
    out = {}
    groups = [("Cockpit/" + e["source"], e) for e in mesh.get("cockpits", {}).values()]
    groups += [("%s/%s" % (e["slot"], e["source"]), e) for e in mesh.get("modules", {}).values()]
    for key, entry in sorted(groups, key=lambda g: g[0]):
        parts = [{"shape": MESH_SHAPE, "size": p["size"], "pos": p["centre"]} for _, p in sorted(entry["parts"].items())]
        out[key] = {"fingerprint": fingerprint(parts), "parts": sorted(entry["parts"])}
    return out


# ------------------------------------------------------------------------------------------------
# VFX sockets (exotic.md 7.7, paintvfx.md 4.4)
# ------------------------------------------------------------------------------------------------
THRUST_AXIS = {"cyl_x": 0, "cyl_y": 1, "cyl_z": 2, "block": 2, "wedge": 2}


def _orient(d, rule):
    """Pick the sign of an exhaust axis so that it points out of the nozzle."""
    if rule == "back_else_up":
        if d[2] > 0.1:
            return d
        if d[2] < -0.1:
            return -d
        return d if d[1] >= 0 else -d
    if rule == "down_else_back":
        if d[1] < -0.1:
            return d
        if d[1] > 0.1:
            return -d
        return d if d[2] >= 0 else -d
    raise BuildError("unknown direction rule %r" % rule)


def nozzles(parts, rule):
    out = []
    for p in parts:
        if p["ch"] != "thrust":
            continue
        if p["shape"] not in THRUST_AXIS:
            raise BuildError("thrust part with shape %r has no exhaust axis rule" % p["shape"])
        axis = THRUST_AXIS[p["shape"]]
        rot = vbspec.rot_matrix(p["rot"])
        d = _orient(np.array(rot[:, axis], dtype=float), rule)
        others = [p["size"][i] for i in range(3) if i != axis]
        area = math.pi * (min(others) / 2.0) ** 2 if p["shape"].startswith("cyl_") else others[0] * others[1]
        pos = np.array(p["pos"], dtype=float)
        out.append({"pos": pos, "dir": d, "area": area, "face": pos + d * (p["size"][axis] / 2.0)})
    return out


def socket_orientation(d, side):
    """Roblox Orientation (degrees) whose local +Z is d. Orientation = (rx, ry, 0): d = (sin ry cos rx, -sin rx, cos ry cos rx)."""
    rx = -math.degrees(math.asin(max(-1.0, min(1.0, d[1]))))
    if d[1] > 0.999:
        ry = 0.0  # straight up: Orientation (-90, 0, 0), as paintvfx.md gives for a top-exit engine
    elif d[1] < -0.999:
        # Straight down: yaw is free. Piercer yaws its stabiliser sockets -90 (left) and +90 (right), so a
        # multi-jet template row would run along the vehicle. Keep that convention.
        ry = -90.0 if side == "Left" else (90.0 if side == "Right" else 0.0)
    else:
        ry = math.degrees(math.atan2(d[0], d[2]))
    return [clean(rx, 3), clean(ry, 3), 0.0]


def _socket_from(group, label):
    total = sum(n["dir"] * n["area"] for n in group)
    length = float(np.linalg.norm(total))
    if length < 1e-6:
        raise BuildError("%s: nozzle directions cancel out" % label)
    d = total / length
    for n in group:
        if float(np.dot(n["dir"], d)) < 0.9:
            raise BuildError("%s: nozzles in one cluster point different ways; add an override in data/sockets.json" % label)
    centre = sum(n["face"] for n in group) / len(group)
    reach = max(float(np.dot(n["face"] - centre, d)) for n in group)
    return centre + d * reach, d


def _clusters(items, distance):
    """Single-linkage clusters of nozzle centres."""
    groups = []
    for item in items:
        linked = [g for g in groups if any(float(np.linalg.norm(item["pos"] - other["pos"])) < distance for other in g)]
        merged = [item]
        for g in linked:
            merged.extend(g)
            groups.remove(g)
        groups.append(merged)
    return groups


def compute_sockets(shape_key, parts, kind, rules):
    """Sockets for one module shape. kind is 'engine', 'boost' or 'stabiliser' (data/sockets.json)."""
    if shape_key in rules.get("overrides", {}):
        sockets = [dict(s) for s in rules["overrides"][shape_key]]
    else:
        rule = rules[kind]
        eps = rules["sideEpsilon"]
        found = nozzles(parts, rule["direction"])
        if not found:
            raise BuildError("%s has no thrust part; every engine, boost and stabiliser needs a jet" % shape_key)
        sockets = []
        if rule["mode"] == "cluster":
            for group in _clusters(found, rule["mergeDistance"]):
                pos, d = _socket_from(group, shape_key)
                side = "Left" if pos[0] < -eps else ("Right" if pos[0] > eps else ("Top" if d[1] > 0.9 else "Back"))
                sockets.append({"name": rule["prefix"] + side, "template": rule["template"], "pos": pos, "dir": d, "side": side})
        elif rule["mode"] == "corner":
            corners = {}
            for n in found:
                if abs(n["pos"][0]) <= eps:
                    raise BuildError("%s: a stabiliser nozzle sits on the centre line" % shape_key)
                key = ("Left" if n["pos"][0] < 0 else "Right", "Front" if n["pos"][2] < 0 else "Rear")
                corners.setdefault(key, []).append(n)
            for (side, end), group in sorted(corners.items()):
                # Nozzles in one corner may point different ways: the direction with the most nozzle area wins.
                by_dir = []
                for n in group:
                    for g in by_dir:
                        if float(np.dot(g[0]["dir"], n["dir"])) > 0.95:
                            g.append(n)
                            break
                    else:
                        by_dir.append([n])
                best = max(by_dir, key=lambda g: sum(n["area"] for n in g))
                pos, d = _socket_from(best, shape_key)
                sockets.append({"name": rule["prefix"] + side + "_" + end, "template": rule["templateLeft"] if side == "Left" else rule["templateRight"],
                                "pos": pos, "dir": d, "side": side})
        else:
            raise BuildError("unknown socket mode %r" % rule["mode"])
        seen = {}
        for s in sorted(sockets, key=lambda s: (s["name"], float(s["pos"][2]), float(s["pos"][1]))):
            seen[s["name"]] = seen.get(s["name"], 0) + 1
            if seen[s["name"]] > 1:
                s["name"] += str(seen[s["name"]])
        sockets = [{"name": s["name"], "template": s["template"], "position": [clean(v, 4) for v in s["pos"]],
                    "orientation": socket_orientation(s["dir"], s["side"])} for s in sockets]
    sockets.sort(key=lambda s: s["name"])
    if len({s["name"] for s in sockets}) != len(sockets):
        raise BuildError("%s: socket names are not unique" % shape_key)
    if len(sockets) > rules["maxSocketsPerModule"]:
        raise BuildError("%s has %d sockets; the limit is %d" % (shape_key, len(sockets), rules["maxSocketsPerModule"]))
    return sockets


# ------------------------------------------------------------------------------------------------
# Live Piercer reference (from the baseline capture)
# ------------------------------------------------------------------------------------------------
def _attr_value(a):
    if a.get("type") == "Color3":
        return {"__c3": [int(round(a["r"] * 255)), int(round(a["g"] * 255)), int(round(a["b"] * 255))]}
    return a.get("value")


def capture_reference(capture):
    """Cockpit and module attribute sets, and which modules own upgrade path folders, from the capture hierarchy."""
    cockpits, modules, paths = {}, {}, {}

    def walk(node):
        attrs = node.get("attributes") or {}
        if node.get("class_name") == "Model" and isinstance(attrs, dict):
            values = {k: _attr_value(v) for k, v in attrs.items()}
            if "CockpitId" in values:
                cockpits[values["CockpitId"]] = values
            if "ModuleId" in values:
                modules[values["ModuleId"]] = values
                for child in node.get("children", []):
                    if child.get("name") == "VehiclePerformanceV2UpgradePaths":
                        paths[values["ModuleId"]] = [c["name"] for c in child.get("children", []) if c.get("class_name") == "Folder"]
        for child in node.get("children", []):
            walk(child)

    for root in capture["hierarchy"]:
        if root.get("path_parts", [])[:3] == ["ServerStorage", "Assets", "Vehicles"]:
            walk(root)
    if not cockpits or not modules:
        raise BuildError("the capture holds no vehicle templates under ServerStorage.Assets.Vehicles")
    return {"cockpits": cockpits, "modules": modules, "paths": paths}


def piercer_cockpit_constants(reference):
    """Attributes that carry the same value on every live Piercer cockpit."""
    sets = list(reference["cockpits"].values())
    names = set(sets[0])
    for s in sets[1:]:
        names &= set(s)
    return {k: sets[0][k] for k in sorted(names) if all(s[k] == sets[0][k] for s in sets)}


# ------------------------------------------------------------------------------------------------
# Attributes
# ------------------------------------------------------------------------------------------------
def check_value(owner, name, value, problems):
    if isinstance(value, dict):
        c = value.get("__c3")
        if not (isinstance(c, list) and len(c) == 3 and all(isinstance(v, int) and 0 <= v <= 255 for v in c)):
            problems.append("%s.%s: unsupported attribute value %r" % (owner, name, value))
    elif isinstance(value, bool):
        pass
    elif isinstance(value, (int, float)):
        text = repr(float(value))
        if not math.isfinite(value) or "e" in text or (value == 0 and math.copysign(1, value) < 0) or (value != 0 and not (0.0001 <= abs(value) < 2 ** 53)):
            problems.append("%s.%s: number %r is not safe for the catalogue generator" % (owner, name, value))
    elif isinstance(value, str):
        if any(ord(ch) < 32 or ord(ch) > 126 for ch in value):
            problems.append("%s.%s: text is not printable ASCII: %r" % (owner, name, value))
    else:
        problems.append("%s.%s: unsupported attribute type %s" % (owner, name, type(value).__name__))


def merge_attributes(owner, donor, balance, identity, passthrough, derived, fill_from_donor, problems, warnings):
    """Final attribute set = donor notes and flags + balance values + identity. Anything else the donor has must come from balance."""
    out = {}
    missing = []
    for name, value in donor.items():
        if name in identity or name in balance:
            continue
        if name in passthrough:
            out[name] = value
        elif name in derived:
            out[name] = derived[name]
        else:
            missing.append(name)
    if missing:
        if fill_from_donor:
            for name in missing:
                out[name] = donor[name]
            warnings.append("%s: %d attribute(s) taken from the Piercer donor because balance.json does not set them: %s" % (owner, len(missing), ", ".join(sorted(missing))))
        else:
            problems.append("%s: balance.json does not set %s (the Piercer donor has them; use --fill-from-donor to copy the donor values)" % (owner, ", ".join(sorted(missing))))
    for name, value in balance.items():
        if name in identity and identity[name] != value:
            problems.append("%s: balance.json sets %s=%r but the interface fixes it at %r" % (owner, name, value, identity[name]))
        out[name] = value
    out.update(identity)
    for name, value in out.items():
        check_value(owner, name, value, problems)
    return out


SEAT_DECISIONS = ("pending", "measured", "overrides")
SEAT_LIMIT = 40  # VehicleBuildService.addPassengerSeat clamps each passenger axis to +-40


def seat_override_problems(seats, known_cockpit_ids):
    """Shape of data/seats.json overrides: {cockpitId: {"driver": [x, y, z], "passenger": [x, y, z]}}."""
    problems = []
    overrides = seats.get("overrides", {})
    if not isinstance(overrides, dict):
        return ["data/seats.json overrides must be an object"]
    for cid, entry in sorted(overrides.items()):
        if cid not in known_cockpit_ids:
            problems.append("data/seats.json overrides names an unknown cockpit %r" % cid)
            continue
        for who in ("driver", "passenger"):
            value = entry.get(who) if isinstance(entry, dict) else None
            good = isinstance(value, list) and len(value) == 3 and all(
                isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) and abs(v) <= SEAT_LIMIT for v in value)
            if not good:
                problems.append("data/seats.json overrides.%s.%s must be three numbers within +-%d (got %r)" % (cid, who, SEAT_LIMIT, value))
    return problems


def seat_acceptance(seats, cockpit_ids):
    """Have the seat offsets been accepted for these cockpits? Returns ({accepted, decision, summary}, problems).

    The derived seat height rests on rule.rootPartCentreAboveSeatTop, which is an assumption until it is measured
    in the pilot Play test. data/seats.json pilotAcceptance records the outcome:
      pending    nothing measured yet. The pilot may be built and applied; the full scope may not be applied.
      measured   the value was measured in Play. The rule must hold that value, unless every cockpit has an override.
      overrides  no measurement is used: every cockpit in scope carries explicit values in overrides.
    """
    problems = []
    acceptance = seats.get("pilotAcceptance") or {}
    decision = acceptance.get("decision", "pending")
    rule_value = seats["rule"]["rootPartCentreAboveSeatTop"]
    missing = sorted(cid for cid in cockpit_ids if cid not in seats.get("overrides", {}))
    accepted, summary = False, ""
    if decision == "pending":
        summary = "rootPartCentreAboveSeatTop=%s is an assumption that has not been measured in Play" % rule_value
    elif decision == "measured":
        measured = acceptance.get("measuredRootPartCentreAboveSeatTop")
        when = acceptance.get("measuredOn")
        if not (isinstance(measured, (int, float)) and not isinstance(measured, bool) and math.isfinite(measured)):
            problems.append("data/seats.json pilotAcceptance.decision is 'measured' but measuredRootPartCentreAboveSeatTop is not a number")
        elif not (isinstance(when, str) and when.strip()):
            problems.append("data/seats.json pilotAcceptance.decision is 'measured' but measuredOn does not say when and where it was measured")
        elif abs(measured - rule_value) > 0.01 and missing:
            problems.append("data/seats.json: measured rootPartCentreAboveSeatTop is %s but the rule still says %s; set the rule to the measured value, "
                            "or give overrides for %s" % (measured, rule_value, ", ".join(missing)))
        else:
            accepted, summary = True, "measured rootPartCentreAboveSeatTop=%s (%s)" % (measured, when.strip())
    elif decision == "overrides":
        if missing:
            problems.append("data/seats.json pilotAcceptance.decision is 'overrides' but there is no override for %s" % ", ".join(missing))
        else:
            accepted, summary = True, "explicit overrides for every cockpit in scope"
    else:
        problems.append("data/seats.json pilotAcceptance.decision must be one of %s (got %r)" % (", ".join(SEAT_DECISIONS), decision))
    return {"accepted": accepted, "decision": decision, "summary": summary}, problems


def seat_offsets(cockpit_def, parts, seats):
    """parts: the flattened spec cockpit. A mesh cockpit has one too: without an override its driver dummy still places the seat."""
    override = seats.get("overrides", {}).get(cockpit_def["cockpitId"])
    if override:
        return [clean(v, 3) for v in override["driver"]], [clean(v, 3) for v in override["passenger"]]
    torso = [p for p in parts if p["ch"] == "driver" and p["shape"] == "block"]
    if len(torso) != 1:
        raise BuildError("%s: expected one driver torso block in the spec, found %d" % (cockpit_def["cockpitId"], len(torso)))
    x, y, z = torso[0]["pos"]
    rule = seats["rule"]
    seat_y = y - rule["rootPartCentreAboveSeatTop"] - rule["seatSize"][1] / 2.0
    return [clean(x, 3), clean(seat_y, 3), clean(z, 3)], [clean(-x, 3), clean(seat_y, 3), clean(z, 3)]


# ------------------------------------------------------------------------------------------------
# Content
# ------------------------------------------------------------------------------------------------
def native_paints(spec):
    out = {}
    for b in spec["builds"]:
        if vbspec.build_kind(spec, b) == "native":
            out[b["cockpit"]] = b["paint"]
    return out


def module_id(slot, n, variant=None):
    return slot["idPrefix"] + n + ("_" + variant if variant else "")


def load_mesh():
    """data/mesh.json, or an empty table when the file is absent (no mesh kits)."""
    if not os.path.isfile(MESH_PATH):
        return {"cockpits": {}, "modules": {}}
    return load_json(MESH_PATH)


def module_variants(ids, mesh, slot, n):
    """ModuleId suffixes of one slot of one kit. Core: the three variants. Body: none, plus each body trim
    (data/ids.json bodyTrims) that data/mesh.json holds for this kit (mesh/INTEGRATION.md D6)."""
    if slot["kind"] == "core":
        return list(ids["variants"])
    return [None] + [t for t in ids.get("bodyTrims", []) if module_id(slot, n, t) in mesh.get("modules", {})]


def mesh_records(owner, entry, codes, problems):
    """Part records of one mesh group: ["mesh", size, centre, 0, 0, 0, code, source part name], in name order."""
    out = []
    for name, part in sorted(entry["parts"].items()):
        code = codes.get(part.get("channel"))
        good = all(isinstance(part.get(k), list) and len(part[k]) == 3 and all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in part[k])
                   for k in ("centre", "size"))
        if code is None:
            problems.append("%s: mesh part %s has channel %r, which cannot go on this template" % (owner, name, part.get("channel")))
        elif not good or any(v <= 0 for v in part["size"]):
            problems.append("%s: mesh part %s needs a centre and a positive size of three numbers" % (owner, name))
        elif any(ord(ch) < 33 or ord(ch) > 126 for ch in name) or not name.startswith(entry["source"] + "__"):
            problems.append("%s: mesh part name %r must be printable ASCII and start with %s__" % (owner, name, entry["source"]))
        else:
            out.append([MESH_SHAPE] + [clean(v, 4) for v in part["size"]] + [clean(v, 4) for v in part["centre"]] + [0.0, 0.0, 0.0, code, name])
    return out


def mesh_sockets(owner, entry, kind, rules, problems):
    """Sockets of one mesh module from data/mesh.json (D12): name, position in root space, dir = the way the flame points."""
    rule = rules[kind]
    out = []
    for s in entry.get("sockets", []):
        d = np.array(s["dir"], dtype=float)
        length = float(np.linalg.norm(d))
        if length < 1e-6 or not s["name"].startswith(rule["prefix"]):
            problems.append("%s: mesh socket %r needs a direction and a name that starts with %s" % (owner, s.get("name"), rule["prefix"]))
            continue
        x = s["position"][0]
        side = "Left" if x < -rules["sideEpsilon"] else ("Right" if x > rules["sideEpsilon"] else None)
        if kind == "stabiliser":
            if side is None or ("_" + side) not in s["name"]:
                problems.append("%s: stabiliser socket %s must sit on the side its name says" % (owner, s["name"]))
                continue
            template = rule["templateLeft"] if side == "Left" else rule["templateRight"]
        else:
            template = rule["template"]
        out.append({"name": s["name"], "template": template, "position": [clean(v, 4) for v in s["position"]],
                    "orientation": socket_orientation(d / length, side)})
    out.sort(key=lambda s: s["name"])
    if len({s["name"] for s in out}) != len(out):
        problems.append("%s: socket names are not unique" % owner)
    if len(out) > rules["maxSocketsPerModule"]:
        problems.append("%s has %d sockets; the limit is %d" % (owner, len(out), rules["maxSocketsPerModule"]))
    if not out:
        problems.append("%s has no socket; every engine, boost and stabiliser needs a jet" % owner)
    return out


def name_problems(name, is_body_module, in_module, problems, where):
    lower = name.lower()
    if any(ord(ch) < 32 or ord(ch) > 126 for ch in name):
        problems.append("%s: instance name %r is not printable ASCII" % (where, name))
    if in_module:
        for word in FORBIDDEN_ANY_MODULE:
            if word in lower:
                problems.append("%s: instance name %r contains %r" % (where, name, word))
        if is_body_module:
            for word in FORBIDDEN_BODY_MODULE:
                if word in lower:
                    problems.append("%s: body module instance name %r contains %r" % (where, name, word))


_SPEC_CACHE = {}


def load_spec():
    """The validated spec, kept per file state: validation takes about 1.5 s and the tests build many times."""
    stat = os.stat(SPEC_PATH)
    key = (stat.st_size, stat.st_mtime_ns)
    if key not in _SPEC_CACHE:
        spec = vbspec.load(SPEC_PATH)
        errors, _, _ = vbspec.validate(spec)
        if errors:
            raise BuildError("exotic.json does not validate: " + "; ".join(errors[:5]))
        _SPEC_CACHE.clear()
        _SPEC_CACHE[key] = spec
    return _SPEC_CACHE[key]


def build_content(mode="AUDIT", scope="pilot", balance_path=BALANCE_PATH, catalogue_gen_path=CATALOGUE_GEN_PATH,
                  capture_path=CAPTURE_PATH, fill_from_donor=False):
    """Returns (content, report). Raises BuildError with every problem found."""
    if mode not in MODES or scope not in SCOPES:
        raise BuildError("mode must be one of %s and scope one of %s" % (MODES, SCOPES))
    for label, path in (("balance.json", balance_path), ("catalogue_gen.lua", catalogue_gen_path), ("capture.json", capture_path), ("exotic.json", SPEC_PATH)):
        if not os.path.isfile(path):
            raise BuildError("%s is missing: %s\nStage B cannot be built without it. For offline tests use tests/fixtures (see README.md)." % (label, path))
    spec = load_spec()
    balance = load_json(balance_path)
    with open(catalogue_gen_path, "r", encoding="utf-8") as f:
        catalogue_gen = f.read()
    reference = capture_reference(load_json(capture_path))
    ids = load_json(os.path.join(DATA_DIR, "ids.json"))
    colours = load_json(os.path.join(DATA_DIR, "colours.json"))
    seats = load_json(os.path.join(DATA_DIR, "seats.json"))
    socket_rules = load_json(os.path.join(DATA_DIR, "sockets.json"))
    vfx = load_json(os.path.join(DATA_DIR, "vfx.json"))
    fixtures = load_json(os.path.join(DATA_DIR, "cockpit_fixtures.json"))
    mesh = load_mesh()
    mesh_modules, mesh_cockpits = mesh.get("modules", {}), mesh.get("cockpits", {})

    problems, warnings = [], []
    paints = native_paints(spec)
    category_id = ids["category"]["attributes"]["CategoryId"]
    slots = ids["slots"]
    slot_by_id = {s["slotId"]: s for s in slots}
    if [s["slotId"] for s in sorted(slots, key=lambda s: s["order"])] != [s["slotId"] for s in slots]:
        raise BuildError("data/ids.json slots must be listed in Order")
    if set(slot_by_id) != set(spec["modules"]):
        raise BuildError("slot ids in data/ids.json do not match the spec: %s vs %s" % (sorted(slot_by_id), sorted(spec["modules"])))

    cockpit_defs = ids["cockpits"]
    in_scope = [c for c in cockpit_defs if scope == "full" or c["n"] == ids["pilotCockpit"]]
    seat_problems = seat_override_problems(seats, {c["cockpitId"] for c in cockpit_defs})
    if seat_problems:
        raise BuildError("%d problem(s):\n  " % len(seat_problems) + "\n  ".join(seat_problems))
    seats_state, seat_problems = seat_acceptance(seats, [c["cockpitId"] for c in in_scope])
    problems.extend(seat_problems)
    if not seats_state["accepted"] and not seat_problems:
        if scope == "full" and mode == "APPLY":
            problems.append("seat offsets are not accepted, so the full scope cannot be applied: %s. Apply the pilot, run measure_seat.lua in Play, "
                            "then record the result in data/seats.json pilotAcceptance (see README.md, Seat acceptance)" % seats_state["summary"])
        else:
            warnings.append("seat offsets are not accepted yet: %s. The full scope cannot be applied until data/seats.json pilotAcceptance "
                            "records the pilot measurement" % seats_state["summary"])
    constants = piercer_cockpit_constants(reference)
    tier_donor = {}
    for cid, attrs in reference["cockpits"].items():
        tier_donor.setdefault(attrs.get("TargetTier"), cid)

    channels = {
        "P": {"material": "SmoothPlastic", "transparency": 0, "suffix": "primary", "paintChannel": "Primary", "reflectance": colours["reflectance"]["P"], "variant": colours.get("paintVariant", "")},
        "S": {"material": "SmoothPlastic", "transparency": 0, "suffix": "secondary", "paintChannel": "Secondary", "reflectance": colours["reflectance"]["S"]},
        "D": {"material": colours["detailMaterial"], "transparency": 0, "suffix": "detail", "paintChannel": "Detail"},
        "G": {"material": "Glass", "transparency": colours["glassTransparency"], "suffix": "glass", "paintChannel": "Glass", "reflectance": colours["reflectance"]["G"]},
        "N": {"material": "Neon", "transparency": 0, "suffix": "neon", "paintChannel": "Neon"},
        "L": {"material": "Neon", "transparency": 0, "suffix": "lamp", "paintChannel": "Lights"},
        # Mesh modules only: a fixed red lamp. It lives in the folder of channel L (LIGHTS_AlwaysOn).
        "R": {"material": "Neon", "transparency": 0, "suffix": "lampred", "paintChannel": "Lights", "folder": "L"},
        "T": {"material": "Neon", "transparency": 0, "suffix": "thrust", "paintChannel": "ThrustColor"},
    }

    def palette(cockpit_key):
        paint = paints[cockpit_key]
        lamp = paint["neon"] if colours["lamp"] == "kitNeon" else colours["lamp"]
        return {"P": hex_rgb(paint["primary"]), "S": hex_rgb(paint["secondary"]), "D": hex_rgb(colours["detail"]),
                "G": hex_rgb(colours["glass"]), "N": hex_rgb(colours["optionalNeon"]), "L": hex_rgb(lamp), "T": hex_rgb(colours["thrust"])}

    def mesh_palette(cockpit_key):
        # Mesh lamps have fixed colours (D10): white, and red for the lights_red channel.
        out = palette(cockpit_key)
        out["L"] = hex_rgb(colours["meshLamp"])
        out["R"] = list(colours["meshLampRed"])
        return out

    def records(owner, parts, allowed, neon_code):
        out = []
        for p in parts:
            ch = p["ch"]
            if ch == "driver":
                continue
            code = {"primary": "P", "secondary": "S", "detail": "D", "glass": "G", "thrust": "T", "neon": neon_code}.get(ch)
            if code is None or code not in allowed:
                problems.append("%s: a %s part cannot go on this template (allowed channels %s)" % (owner, ch, "".join(sorted(allowed))))
                continue
            out.append([p["shape"]] + p["size"] + p["pos"] + p["rot"] + [code])
        return out

    shapes, fingerprints = {}, {}
    cockpits_out, modules_out = [], []
    all_fp = all_fingerprints(spec)

    # Modules first: cockpits point at them.
    planned_ids = {}
    mesh_used = set()
    for c in in_scope:
        kit = spec["kits"][c["specKit"]]
        for slot in slots:
            spec_id = kit["modules"][slot["slotId"]]
            spec_module = spec["modules"][slot["slotId"]][spec_id]
            core = slot["kind"] == "core"
            slot_folder_set = "core" if core else ("bodyLamps" if slot["lamps"] else "body")

            def spec_shape():
                shape_key = "%s/%s" % (slot["slotId"], spec_id)
                if shape_key in shapes:
                    return shape_key
                parts = flatten(spec_module["parts"])
                allowed = {f["channel"] for f in MODULE_FOLDERS[slot_folder_set] if f["channel"]}
                recs = records(shape_key, parts, allowed, "L" if slot["lamps"] else "N")
                sockets = compute_sockets(shape_key, parts, slot["sockets"], socket_rules) if slot["sockets"] else []
                if not slot["sockets"] and any(p["ch"] == "thrust" for p in parts):
                    problems.append("%s: a body module has a thrust part" % shape_key)
                shapes[shape_key] = {"parts": recs, "sockets": sockets}
                fingerprints[shape_key] = all_fp[shape_key]
                for r in recs:
                    name_problems(r[0] + "_" + channels[r[10]]["suffix"], not core, True, problems, shape_key)
                for s in sockets:
                    name_problems(s["name"], not core, True, problems, shape_key)
                return shape_key

            def mesh_shape(mid, entry):
                """One shape per mesh ModuleId: every trim has its own geometry (D5, D6). Returns (shape key, folder set)."""
                shape_key = "%s/%s" % (slot["slotId"], entry["source"])
                if entry.get("slot") != slot["slotId"] or entry.get("kit") != int(c["n"]):
                    problems.append("%s: data/mesh.json files it under slot %r of kit %r" % (mid, entry.get("slot"), entry.get("kit")))
                if shape_key in shapes:
                    problems.append("%s: mesh source %s is used twice" % (mid, entry["source"]))
                recs = mesh_records(mid, entry, MESH_MODULE_CODES, problems)
                codes = {r[10] for r in recs}
                folder_set = slot_folder_set
                if codes & {"L", "R"} and folder_set != "bodyLamps":
                    folder_set = "coreLamps" if core else "bodyLamps"
                allowed = {f["channel"] for f in MODULE_FOLDERS[folder_set] if f["channel"]}
                for r in recs:
                    if channels[r[10]].get("folder", r[10]) not in allowed:
                        problems.append("%s: mesh part %s (code %s) cannot go on this template" % (mid, r[11], r[10]))
                    name_problems(r[0] + "_" + channels[r[10]]["suffix"], not core, True, problems, shape_key)
                sockets = mesh_sockets(mid, entry, slot["sockets"], socket_rules, problems) if slot["sockets"] else []
                if not slot["sockets"] and entry.get("sockets"):
                    problems.append("%s: a body module has sockets in data/mesh.json" % mid)
                if core != ("T" in codes):
                    problems.append("%s: thrust parts belong on engines, stabilisers and boost, and each of those needs one" % mid)
                for s in sockets:
                    name_problems(s["name"], not core, True, problems, shape_key)
                shapes[shape_key] = {"parts": recs, "sockets": sockets, "mesh": {"fileOffsetX": clean(mesh["cars"][entry["car"]]["fileOffsetX"], 4)}}
                return shape_key, folder_set

            base_display = spec_module["name"]
            for variant in module_variants(ids, mesh, slot, c["n"]):
                mid = module_id(slot, c["n"], variant)
                if mid in planned_ids:
                    problems.append("duplicate ModuleId %s" % mid)
                planned_ids[mid] = slot["slotId"]
                # A body trim is a new ModuleId with the base name plus the trim (D7).
                display = base_display if core or variant is None else "%s %s" % (base_display, variant)
                mesh_entry = mesh_modules.get(mid)
                if mesh_entry is None:
                    shape_key, folder_set = spec_shape(), None
                else:
                    mesh_used.add(mid)
                    shape_key, folder_set = mesh_shape(mid, mesh_entry)
                recs = shapes[shape_key]["parts"]
                entry = balance.get("modules", {}).get(mid)
                if entry is None:
                    problems.append("balance.json has no module %s" % mid)
                    continue
                donor_id = slot["attributeDonor"].replace("{VARIANT}", variant or "")
                donor = reference["modules"].get(donor_id)
                if donor is None:
                    problems.append("%s: attribute donor %s is not in the capture" % (mid, donor_id))
                    continue
                identity = {"ModuleId": mid, "CategoryId": category_id, "ModuleType": slot["moduleType"], "ModuleFolder": slot["moduleFolder"],
                            "ModuleSlot": slot["moduleSlot"], "DisplayName": display, "ModuleName": display, "TemplateType": "Module",
                            "CardTitle": base_display, "RatingReferenceCockpitId": ids["ratingReferenceCockpitId"]}
                derived = {}
                if core:
                    identity.update({"V2PublishedModuleId": mid, "SourceCockpitId": c["cockpitId"],
                                     "EnginePosition": slot["moduleEnginePosition"], "RearEngine": slot["rearEngine"]})
                    derived["SourceCockpitDisplayName"] = c["displayName"]
                else:
                    if variant not in BODY_VARIANT:
                        problems.append("%s: body trim %r has no VariantName and VariantOrder rule" % (mid, variant))
                        continue
                    identity.update({"SourceCockpitId": c["cockpitId"], "SourceCockpitDisplayName": c["displayName"],
                                     "VariantName": BODY_VARIANT[variant][0], "VariantOrder": BODY_VARIANT[variant][1]})
                    for name in sorted(BODY_MODULE_OPT_IN):
                        if name not in entry.get("attributes", {}):
                            problems.append("%s: balance.json does not set %s (INTERFACE.md: a body module carries the cockpit of its kit and its version)" % (mid, name))
                    for banned in BODY_MODULE_BANNED:
                        if banned in entry.get("attributes", {}) or banned in donor:
                            problems.append("%s: body modules carry no %s (INTERFACE.md: Price, the source cockpit and the version only)" % (mid, banned))
                attrs = merge_attributes(mid, donor, entry.get("attributes", {}), identity, MODULE_PASSTHROUGH, derived, fill_from_donor, problems, warnings)
                required = ["Price", "NeonPrice", "UpgradePointCapacity"] + (["PurchasePrice", "VariantName", "VariantOrder"] if core else ["VariantName", "VariantOrder"])
                for name in required:
                    if not isinstance(attrs.get(name), (int, float, str)) or isinstance(attrs.get(name), bool):
                        problems.append("%s: required attribute %s is missing" % (mid, name))
                if attrs.get("V2Materialised") is not True:
                    problems.append("%s: V2Materialised must be true" % mid)
                if attrs.get("RetiredFromCatalog") is not False:
                    problems.append("%s: RetiredFromCatalog must be false" % mid)
                extra = sorted(set(attrs) - set(donor) - MODULE_OPT_IN - (set() if core else BODY_MODULE_OPT_IN))
                if extra:
                    warnings.append("%s: attributes the Piercer donor %s does not have: %s" % (mid, donor_id, ", ".join(extra)))
                item = {"id": mid, "slot": slot["slotId"], "shape": shape_key, "partCount": len(recs),
                        "palette": palette(c["specCockpit"]) if mesh_entry is None else mesh_palette(c["specCockpit"]),
                        "folderPath": [slot["moduleFolder"]] + (["Exotic_" + c["n"]] if core else []), "attributes": attrs}
                if folder_set is not None and folder_set != slot_folder_set:
                    item["folderSet"] = folder_set
                name_problems(mid, not core, True, problems, mid)
                for name in item["folderPath"][1:]:
                    name_problems(name, not core, True, problems, mid)
                has_donor, has_paths = "upgradePathDonor" in entry and entry["upgradePathDonor"], bool(entry.get("upgradePaths"))
                if has_donor == has_paths:
                    problems.append("%s: balance.json must give either upgradePathDonor or upgradePaths (not both, not neither)" % mid)
                elif has_donor:
                    if not reference["paths"].get(entry["upgradePathDonor"]):
                        problems.append("%s: upgradePathDonor %s has no upgrade path folders in the capture" % (mid, entry["upgradePathDonor"]))
                    item["upgradePathDonor"] = entry["upgradePathDonor"]
                else:
                    paths, seen = [], set()
                    for path in entry["upgradePaths"]:
                        pid = path.get("PathId")
                        pattrs = dict(path.get("attributes", {}))
                        if not isinstance(pid, str) or not pid or pid in seen:
                            problems.append("%s: upgrade path needs a unique string PathId (got %r)" % (mid, pid))
                            continue
                        seen.add(pid)
                        if pattrs.setdefault("PathId", pid) != pid:
                            problems.append("%s: upgrade path %s has a different PathId attribute" % (mid, pid))
                        for name, value in pattrs.items():
                            check_value("%s.%s" % (mid, pid), name, value, problems)
                        folder_name = path.get("Name", pid)
                        if any(word in folder_name.lower() for word in FORBIDDEN_ANY_MODULE + (() if core else FORBIDDEN_BODY_MODULE)):
                            warnings.append("%s: upgrade path folder %r contains a word the VFX and paint code matches on; it is not an ancestor of any part, so it is harmless, but INTERFACE.md asks to avoid it" % (mid, folder_name))
                        paths.append({"name": folder_name, "attributes": pattrs})
                    item["upgradePaths"] = paths
                modules_out.append(item)
    scope_numbers = {int(c["n"]) for c in in_scope}
    for mid, entry in sorted(mesh_modules.items()):
        if entry.get("kit") in scope_numbers and mid not in mesh_used:
            problems.append("data/mesh.json names %s, which is not a ModuleId of this scope" % mid)

    for c in in_scope:
        cid = c["cockpitId"]
        spec_cockpit = spec["cockpits"][c["specCockpit"]]
        if spec_cockpit["kit"] != c["specKit"] or spec_cockpit["name"] != c["displayName"]:
            problems.append("%s: data/ids.json disagrees with the spec (kit %s, name %s)" % (cid, spec_cockpit["kit"], spec_cockpit["name"]))
        parts = flatten(spec_cockpit["parts"])
        mesh_entry = mesh_cockpits.get(cid)
        if mesh_entry is None:
            shape_key = "Cockpit/" + c["specCockpit"]
            recs = records(shape_key, parts, {"P", "S", "D", "G"}, "N")
            shapes[shape_key] = {"parts": recs}
            fingerprints[shape_key] = all_fp[shape_key]
        else:
            shape_key = "Cockpit/" + mesh_entry["source"]
            recs = mesh_records(cid, mesh_entry, MESH_COCKPIT_CODES, problems)
            shapes[shape_key] = {"parts": recs, "mesh": {"fileOffsetX": clean(mesh["cars"][mesh_entry["car"]]["fileOffsetX"], 4)}}
        entry = balance.get("cockpits", {}).get(cid)
        if entry is None:
            problems.append("balance.json has no cockpit %s" % cid)
            continue
        donor_id = tier_donor.get(c["tier"])
        if donor_id is None:
            problems.append("%s: no live Piercer cockpit has tier %s" % (cid, c["tier"]))
            continue
        donor = reference["cockpits"][donor_id]
        paint = paints[c["specCockpit"]]
        driver, passenger = seat_offsets(c, parts, seats)
        identity = {"CockpitId": cid, "V2PublishedCockpitId": cid, "CategoryId": category_id, "DisplayName": c["displayName"],
                    "TemplateType": "Cockpit", "MenuImage": c.get("cardImage", ""), "PreviewImage": c.get("cardImage", ""), "TargetTier": c["tier"],
                    "StandardAudioProfileId": donor["StandardAudioProfileId"],
                    "DefaultPrimaryColor": {"__c3": hex_rgb(paint["primary"])}, "DefaultSecondaryColor": {"__c3": hex_rgb(paint["secondary"])},
                    "DefaultDetailColor": {"__c3": hex_rgb(colours["detail"])}, "DefaultNeonColor": {"__c3": hex_rgb(paint["neon"])},
                    "DefaultFrontLightsColor": {"__c3": colours["defaultFrontLights"]}, "DefaultRearLightsColor": {"__c3": colours["defaultRearLights"]},
                    "DriverSeatOffsetX": driver[0], "DriverSeatOffsetY": driver[1], "DriverSeatOffsetZ": driver[2],
                    "PassengerSeatOffsetX": passenger[0], "PassengerSeatOffsetY": passenger[1], "PassengerSeatOffsetZ": passenger[2]}
        # Slots that start empty on this cockpit declare no default (D8). FrontBody and RearBody are required by the game.
        empty_slots = list(c.get("emptySlots", []))
        for slot_id in empty_slots:
            if slot_id not in slot_by_id or slot_by_id[slot_id]["kind"] == "core" or slot_by_id[slot_id]["lamps"]:
                problems.append("%s: data/ids.json emptySlots may only name SidePods, FrontBumper, RearBumper or RearSpoiler (got %r)" % (cid, slot_id))
        for slot in slots:
            default = module_id(slot, c["n"], "STANDARD" if slot["kind"] == "core" else None)
            for name in slot["defaultAttributes"]:
                if slot["slotId"] in empty_slots:
                    if name in entry.get("attributes", {}):
                        problems.append("%s: balance.json sets %s but data/ids.json says slot %s starts empty" % (cid, name, slot["slotId"]))
                else:
                    identity[name] = default
        bal = dict(entry.get("attributes", {}))
        for name, want in (("Price", c["price"]), ("TargetStockPI", c["targetStockPI"])):
            if name in bal and bal[name] != want:
                problems.append("%s: balance.json %s=%r but INTERFACE.md says %r" % (cid, name, bal[name], want))
        passthrough = {k for k in constants if k not in identity}
        attrs = merge_attributes(cid, donor, bal, identity, passthrough, {}, fill_from_donor, problems, warnings)
        # Overrides are applied last, so they get the same checks here that merge_attributes gives everything else.
        for name, value in ids.get("cockpitAttributeOverrides", {}).items():
            if name in identity:
                problems.append("%s: data/ids.json cockpitAttributeOverrides may not change %s (the interface fixes it at %r)" % (cid, name, identity[name]))
            elif name not in attrs:
                problems.append("%s: data/ids.json cockpitAttributeOverrides names %r, which is not an attribute of this cockpit" % (cid, name))
            else:
                check_value(cid, name, value, problems)
                attrs[name] = value
        if attrs.get("V2Materialised") is not True:
            problems.append("%s: V2Materialised must be true" % cid)
        for name in RAW + ["Price"]:
            if not isinstance(attrs.get(name), (int, float)) or isinstance(attrs.get(name), bool):
                problems.append("%s: %s must be a number" % (cid, name))
        extra = sorted(set(attrs) - set(donor) - COCKPIT_OPT_IN)
        if extra:
            warnings.append("%s: attributes the Piercer donor %s does not have: %s" % (cid, donor_id, ", ".join(extra)))
        for name, value in attrs.items():
            if name.startswith("Default") and name.endswith("ModuleId") and value not in planned_ids:
                problems.append("%s: %s=%s is not a module in the %s scope" % (cid, name, value, scope))
        cockpits_out.append({"id": cid, "model": c["model"], "shape": shape_key, "partCount": len(recs), "palette": palette(c["specCockpit"]),
                             "tierDonorCockpitId": donor_id, "attributes": attrs})
        if empty_slots:
            cockpits_out[-1]["emptySlots"] = empty_slots

    scope_cockpits = {c["cockpitId"] for c in in_scope}
    if ids["ratingReferenceCockpitId"] not in scope_cockpits:
        problems.append("ratingReferenceCockpitId %s is not in the %s scope" % (ids["ratingReferenceCockpitId"], scope))
    for name in (f["name"] for group in (COCKPIT_FOLDERS, sum(MODULE_FOLDERS.values(), [])) for f in group):
        name_problems(name, False, True, problems, "folder")
    template_names = {t["name"] for t in vfx["templates"]} | set(vfx["requiredStock"])
    for key, shape in shapes.items():
        for s in shape.get("sockets", []):
            if s["template"] not in template_names:
                problems.append("%s: socket %s names an unknown VFX template %s" % (key, s["name"], s["template"]))
    for t in vfx["templates"]:
        if t["source"] not in vfx["requiredStock"]:
            problems.append("VFX template %s: source %s is not in requiredStock" % (t["name"], t["source"]))
    if problems:
        raise BuildError("%d problem(s):\n  " % len(problems) + "\n  ".join(problems))

    slots_out = []
    for s in slots:
        attributes = {"SlotId": s["slotId"], "DisplayName": s["label"], "RailLabel": s["label"], "ModuleType": s["moduleType"],
                      "AllowedModuleFolder": s["moduleFolder"], "Order": s["order"], "CountLabel": s["countLabel"], "FixedSlot": True}
        if s["enginePosition"]:
            attributes["EnginePosition"] = s["enginePosition"]
        slots_out.append({"slotId": s["slotId"], "attributes": attributes, "mountDonorSlot": s["mountDonorSlot"],
                          "mountAttributes": s.get("mountAttributes"), "defaultAttributes": s["defaultAttributes"], "rootDonor": s["rootDonor"],
                          "folderSet": "core" if s["kind"] == "core" else ("bodyLamps" if s["lamps"] else "body")})
    type_folders = [{"name": s["moduleFolder"], "attributes": {"DisplayName": s["label"], "InterchangeableWithinCategory": True, "ModuleType": s["moduleType"]}} for s in slots]
    fixtures_out = {k: v for k, v in fixtures.items() if not k.startswith("_")}
    fixtures_out["underglow"] = {k: v for k, v in fixtures["underglow"].items() if not k.startswith("_")}
    vfx_out = {"requiredStock": vfx["requiredStock"], "templates": [{k: v for k, v in t.items() if not k.startswith("_")} for t in vfx["templates"]]}

    content = {
        "category": {"folder": ids["category"]["folder"], "afterFolder": ids["category"]["afterFolder"], "attributes": ids["category"]["attributes"]},
        "slots": slots_out,
        "channels": channels,
        "cockpitFolders": COCKPIT_FOLDERS,
        "moduleFolders": MODULE_FOLDERS,
        "moduleTypeFolders": type_folders,
        "shapes": shapes,
        "cockpits": cockpits_out,
        "modules": modules_out,
        "fixtures": fixtures_out,
        "vfx": vfx_out,
        "fingerprints": fingerprints,
    }
    mesh_parts = sorted(r[11] for shape in shapes.values() for r in shape["parts"] if r[0] == MESH_SHAPE)
    if len(set(mesh_parts)) != len(mesh_parts):
        raise BuildError("data/mesh.json: a source part name is used by more than one template")
    if mesh_parts:
        # Inside the content, so the content hash covers the asset id and (through the shapes) every source part name (D15).
        if not (isinstance(mesh.get("assetId"), int) and not isinstance(mesh["assetId"], bool) and mesh["assetId"] > 0) or mesh.get("turnYDegrees") != 180:
            raise BuildError("data/mesh.json needs a positive integer assetId and turnYDegrees 180")
        content["mesh"] = {"assetId": str(mesh["assetId"]), "turnYDegrees": 180, "centreTolerance": MESH_CENTRE_TOLERANCE, "partCount": len(mesh_parts)}
    fixture = bool(balance.get("fixture")) or "STAGE_B_FIXTURE" in catalogue_gen
    with open(ENGINE_PATH, "rb") as f:
        engine_sha = hashlib.sha256(b"\n".join(f.read().splitlines())).hexdigest()
    generator_sha = hashlib.sha256("\n".join(catalogue_gen.splitlines()).encode("utf-8")).hexdigest()
    # The hash covers the engine and the generator too: a repaired engine must replace earlier content on APPLY.
    canonical = json.dumps({"content": content, "scope": scope, "engine": engine_sha, "generator": generator_sha}, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    blockout_check = ids.get("blockoutCheck", "strict")
    if blockout_check not in ("strict", "warn"):
        raise ValueError("data/ids.json blockoutCheck must be strict or warn")
    content["meta"] = {"mode": mode, "scope": scope, "marker": ids["marker"], "placeId": ids["placeId"], "fixture": fixture, "blockoutCheck": blockout_check,
                       "contentHash": hashlib.sha256(canonical.encode("ascii")).hexdigest(), "seats": seats_state}
    report = {
        "mode": mode, "scope": scope, "fixture": fixture, "contentHash": content["meta"]["contentHash"],
        "cockpits": len(cockpits_out), "modules": len(modules_out), "shapes": len(shapes),
        "templateParts": sum(c["partCount"] for c in cockpits_out) + sum(m["partCount"] for m in modules_out),
        "meshAssetId": content["mesh"]["assetId"] if mesh_parts else None, "meshParts": len(mesh_parts),
        "meshCockpits": sorted(c["id"] for c in cockpits_out if c["id"] in mesh_cockpits),
        "meshModules": sorted(mesh_used),
        "sockets": {k: [s["name"] for s in v["sockets"]] for k, v in sorted(shapes.items()) if v.get("sockets")},
        "socketsPerStockVehicle": {c["id"]: len(fixtures["hoverDust"]) + sum(len(shapes[m["shape"]].get("sockets", [])) for m in modules_out
                                                                               if m["id"] in set(v for k, v in c["attributes"].items() if k.startswith("Default") and k.endswith("ModuleId")))
                                   for c in cockpits_out},
        "seatAcceptance": seats_state,
        "seats": {c["id"]: {"driver": [c["attributes"]["DriverSeatOffset" + a] for a in "XYZ"], "passenger": [c["attributes"]["PassengerSeatOffset" + a] for a in "XYZ"]} for c in cockpits_out},
        "warnings": warnings,
        "catalogueGen": catalogue_gen,
    }
    return content, report


def render_installer(content, catalogue_gen):
    data = json.dumps(content, separators=(",", ":"), ensure_ascii=True)
    if "]=====]" in data or "]=====]" in catalogue_gen:
        raise BuildError("the data contains the long-string terminator")
    with open(ENGINE_PATH, "r", encoding="utf-8") as f:
        engine = f.read()
    meta = content["meta"]
    lines = [
        "-- GENERATED by scripts/exotic_category/stage_b/build_content.py. Do not edit: rebuild it.",
        "-- Exotic category, Stage B content installer. mode=%s scope=%s contentHash=%s%s" % (meta["mode"], meta["scope"], meta["contentHash"], " FIXTURE BUILD: NOT INSTALLABLE" if meta["fixture"] else ""),
        "-- Run in Studio Edit (place %d): return loadstring(game:GetService(\"HttpService\"):GetAsync(url, true))()" % meta["placeId"],
        "local STAGE_B_DATA_JSON = [=====[",
        data + "]=====]",
        "local STAGE_B_CATALOGUE_GEN = (function()",
        catalogue_gen.rstrip("\n"),
        "end)()",
        "assert(type(STAGE_B_CATALOGUE_GEN) == \"function\", \"Stage B: catalogue_gen.lua did not return a function\")",
        engine.rstrip("\n"),
        "",
    ]
    text = "\n".join(lines).replace("\r\n", "\n")
    if any(ord(ch) > 126 or (ord(ch) < 32 and ch not in "\n\t") for ch in text):
        raise BuildError("the installer is not ASCII")
    return text


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build the Exotic Stage B content installer.")
    parser.add_argument("--mode", choices=MODES, default="AUDIT")
    parser.add_argument("--scope", choices=SCOPES, default="pilot")
    parser.add_argument("--balance", default=BALANCE_PATH)
    parser.add_argument("--catalogue-gen", default=CATALOGUE_GEN_PATH)
    parser.add_argument("--capture", default=CAPTURE_PATH)
    parser.add_argument("--out", default=os.path.join(OUT_DIR, "installer.lua"))
    parser.add_argument("--fill-from-donor", action="store_true", help="copy Piercer donor values for attributes balance.json does not set (reported as warnings)")
    parser.add_argument("--sample", action="store_true", help="AUDIT only: the result also carries a short text dump of what the dry run built (result.sample)")
    args = parser.parse_args(argv)
    try:
        content, report = build_content(args.mode, args.scope, args.balance, args.catalogue_gen, args.capture, args.fill_from_donor)
        if args.sample:
            if args.mode != "AUDIT":
                raise BuildError("--sample is for AUDIT builds only")
            content["meta"]["sample"] = True
        text = render_installer(content, report.pop("catalogueGen"))
    except BuildError as error:
        print("BUILD FAILED: %s" % error, file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="ascii", newline="\n") as f:
        f.write(text)
    spec = vbspec.load(SPEC_PATH)
    with open(FINGERPRINTS_PATH, "w", encoding="ascii", newline="\n") as f:
        mesh = load_mesh()
        json.dump({"_note": "Generated by build_content.py from scripts/vehicle_blockouts/specs/exotic.json. Per group in root space: [part count, sum x, sum |x|, sum y, sum z, sum of Part.Size components]. The installer AUDIT compares the Studio blockout with these.",
                   "groups": all_fingerprints(spec),
                   "_mesh": "From data/mesh.json: the uploaded asset and, per mesh group (which replaces the spec group of that cockpit or module in the installed content), the same fingerprint over the part bounds plus the source part names. The installer AUDIT checks every part against the loaded asset (name present, centre within 0.05); the Studio blockout is not compared for these groups.",
                   "mesh": {"assetId": mesh.get("assetId"), "groups": mesh_fingerprints(mesh)}}, f, indent=1, sort_keys=True)
        f.write("\n")
    report["bytes"] = len(text)
    report["sha256"] = hashlib.sha256(text.encode("ascii")).hexdigest()
    report["output"] = os.path.relpath(args.out, REPO).replace("\\", "/")
    with open(os.path.join(os.path.dirname(os.path.abspath(args.out)), "summary-%s.json" % args.scope), "w", encoding="ascii", newline="\n") as f:
        json.dump(report, f, indent=1, sort_keys=True)
        f.write("\n")
    brief = {k: report[k] for k in ("mode", "scope", "fixture", "contentHash", "cockpits", "modules", "shapes", "templateParts", "bytes", "sha256", "output")}
    brief["warnings"] = len(report["warnings"])
    print(json.dumps(brief))
    for warning in report["warnings"][:20]:
        print("WARN " + warning, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
