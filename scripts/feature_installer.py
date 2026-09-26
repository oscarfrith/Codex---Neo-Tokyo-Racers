"""Build one canonical, guarded feature installer (AUDIT / APPLY / ROLLBACK) from spec JSON files.

Generalises scripts/route_guide/build_installer.py for the Street Life features. Operations
(see docs/architecture/activities-contract.md "feature_installer spec format"):
  source    existing script body; before-source comes from the verified capture (exact bytes)
  module    new ModuleScript {parent, name, file}
  folder    new Folder {parent, name, attributes}
  instance  new instance {parent, name, class, properties, attributes, tags}
  attribute attribute on an existing captured instance {path, key, value}; before from the capture
Typed values: {"type": "Vector3"|"Color3"|"CFrame"|"UDim2"|"Enum", "value": ...};
Enum values are "EnumType.Item" (e.g. "Material.Neon"). Operations apply in order and roll back in reverse.

Usage: py scripts/feature_installer.py CAPTURE OUTPUT --mode AUDIT spec1.json [spec2.json ...]
"""
import argparse
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import studio_capture as capture  # noqa: E402
from studio_delivery import lua  # noqa: E402

TYPED = {"Vector3", "Color3", "CFrame", "UDim2", "Enum"}


def typed(value):
    """JSON value -> bundle value; typed values become {__t, v} tables decoded in Lua."""
    if isinstance(value, dict):
        if value.get("type") not in TYPED:
            raise ValueError("Unsupported typed value: " + json.dumps(value))
        raw = value["value"]
        if value["type"] == "Enum":
            if not (isinstance(raw, str) and raw.count(".") == 1):
                raise ValueError("Enum values must be 'EnumType.Item'")
        elif not (isinstance(raw, list) and all(isinstance(x, (int, float)) and math.isfinite(x) for x in raw)):
            raise ValueError("Typed numeric values must be finite lists")
        return {"__t": value["type"], "v": raw}
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    raise ValueError("Unsupported value: " + repr(value))


def path_ok(path):
    return isinstance(path, list) and path and all(isinstance(p, str) and p for p in path)


def build(specs, baseline):
    nodes = {tuple(n["path_parts"]): n for n in capture.nodes(baseline["hierarchy"])}
    operations, seen = [], set()
    for spec in specs:
        if spec.get("lane") not in ("Fast", "Standard", "High-Risk") or not spec.get("task"):
            raise ValueError("Each spec needs task and lane")
        for request in spec["operations"]:
            kind = request["kind"]
            if kind == "source":
                path = request["path"]
                if not path_ok(path):
                    raise ValueError("Invalid path")
                matches = [r for r in baseline["manifest"] if r["path_parts"] == path]
                if len(matches) != 1:
                    raise ValueError("Source missing or ambiguous in capture: " + ".".join(path))
                record = matches[0]
                op = dict(kind="source", path=path, class_name=record["class_name"],
                          before=(ROOT / record["file"]).read_bytes().decode("utf8"),
                          after=(ROOT / request["file"]).read_bytes().decode("utf8"))
                identity = ("source", tuple(path))
            elif kind in ("module", "folder", "instance"):
                parent, name = request["parent"], request["name"]
                if not path_ok(parent) or not isinstance(name, str) or not name:
                    raise ValueError("Invalid parent/name")
                if tuple(parent + [name]) in nodes:
                    raise ValueError("Create target already exists in the capture: " + ".".join(parent + [name]))
                class_name = {"module": "ModuleScript", "folder": "Folder"}.get(kind, request.get("class"))
                if not isinstance(class_name, str) or not class_name:
                    raise ValueError("Instance ops need class")
                op = dict(kind=kind, parent=parent, name=name, class_name=class_name,
                          attributes={k: typed(v) for k, v in (request.get("attributes") or {}).items()},
                          properties={k: typed(v) for k, v in (request.get("properties") or {}).items()},
                          tags=list(request.get("tags") or []))
                if kind == "module":
                    op["after"] = (ROOT / request["file"]).read_bytes().decode("utf8")
                identity = ("create", tuple(parent), name)
            elif kind == "attribute":
                path, key = request["path"], request["key"]
                if not path_ok(path) or not isinstance(key, str) or not key or key.startswith("RBX"):
                    raise ValueError("Invalid attribute op")
                node = nodes.get(tuple(path))
                if node is None:
                    raise ValueError("Attribute target not in capture: " + ".".join(path))
                old = dict(node.get("attributes") or {}).get(key)
                if old and old["type"] not in ("string", "boolean", "number"):
                    raise ValueError("Non-primitive attribute " + key)
                value = request["value"]
                if value is not None and type(value) not in (str, bool, int, float):
                    raise ValueError("Attribute ops take primitive values")
                op = dict(kind="attribute", path=path, key=key, before=old["value"] if old else None, after=value)
                identity = ("attribute", tuple(path), key)
            else:
                raise ValueError("Unknown op kind " + kind)
            if identity in seen:
                raise ValueError("Duplicate operation " + repr(identity))
            seen.add(identity)
            operations.append(op)
    return dict(place_id=baseline["place_id"], capture_sha256=baseline["content_sha256"],
                tasks=[s["task"] for s in specs], operations=operations)


ENGINE = r'''
assert(game.PlaceId == bundle.place_id and not game:GetService("RunService"):IsRunning(), "Wrong place or not in Edit")
local CollectionService = game:GetService("CollectionService")
local function child(parent, name)
	local found
	for _, item in ipairs(parent:GetChildren()) do
		if item.Name == name then assert(not found, "Ambiguous path at " .. name); found = item end
	end
	return found
end
local function resolveMaybe(path)
	local current = game
	for _, name in ipairs(path) do
		current = child(current, name)
		if not current then return nil end
	end
	return current
end
local function resolve(path) return assert(resolveMaybe(path), "Missing path " .. table.concat(path, ".")) end
local function decode(value)
	if type(value) ~= "table" then return value end
	local v = value.v
	if value.__t == "Vector3" then return Vector3.new(v[1], v[2], v[3]) end
	if value.__t == "Color3" then return Color3.new(v[1], v[2], v[3]) end
	if value.__t == "UDim2" then return UDim2.new(v[1], v[2], v[3], v[4]) end
	if value.__t == "CFrame" then
		if #v == 3 then return CFrame.new(v[1], v[2], v[3]) end
		return CFrame.new(table.unpack(v))
	end
	if value.__t == "Enum" then
		local enumType, item = string.match(v, "^(%w+)%.(%w+)$")
		return Enum[enumType][item]
	end
	error("Unknown typed value")
end
local function same(a, b)
	if typeof(a) == "number" and typeof(b) == "number" then return math.abs(a - b) < 1e-4 end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then return (a - b).Magnitude < 1e-3 end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		-- Part colours are stored at 8-bit precision.
		return math.abs(a.R - b.R) < 6e-3 and math.abs(a.G - b.G) < 6e-3 and math.abs(a.B - b.B) < 6e-3
	end
	return a == b
end
local label = function(op) return op.name or (table.concat(op.path, ".") .. (op.key and ("@" .. op.key) or "")) end
local function stateOf(op)
	if op.kind == "source" then
		local target = resolve(op.path)
		assert(target.ClassName == op.class_name, "Class drift at " .. label(op))
		if target.Source == op.before then return "before" end
		if target.Source == op.after then return "after" end
		return "drift"
	end
	if op.kind == "attribute" then
		local value = resolve(op.path):GetAttribute(op.key)
		if value == op.after then return "after" end
		if value == op.before then return "before" end
		return "drift"
	end
	local parent = resolveMaybe(op.parent)
	local existing = parent and child(parent, op.name)
	if not existing then return "before" end
	if existing.ClassName ~= op.class_name then return "drift" end
	if op.kind == "module" and existing.Source ~= op.after then return "drift" end
	for k, v in pairs(op.attributes) do if not same(existing:GetAttribute(k), decode(v)) then return "drift" end end
	for k, v in pairs(op.properties) do if not same(existing[k], decode(v)) then return "drift" end end
	for _, tag in ipairs(op.tags) do if not CollectionService:HasTag(existing, tag) then return "drift" end end
	return "after"
end
local function apply(op)
	if op.kind == "source" then resolve(op.path).Source = op.after return end
	if op.kind == "attribute" then resolve(op.path):SetAttribute(op.key, op.after) return end
	local item = Instance.new(op.class_name)
	item.Name = op.name
	if op.kind == "module" then item.Source = op.after end
	for k, v in pairs(op.properties) do item[k] = decode(v) end
	for k, v in pairs(op.attributes) do item:SetAttribute(k, decode(v)) end
	for _, tag in ipairs(op.tags) do CollectionService:AddTag(item, tag) end
	item.Parent = resolve(op.parent)
end
local function revert(op)
	if op.kind == "source" then resolve(op.path).Source = op.before return end
	if op.kind == "attribute" then resolve(op.path):SetAttribute(op.key, op.before) return end
	local parent = resolveMaybe(op.parent)
	local existing = parent and child(parent, op.name)
	if existing then
		-- Listed children were removed first (reverse order); anything left was not created by this installer.
		assert(#existing:GetChildren() == 0, "Refusing to remove " .. label(op) .. ": it contains items this installer did not create")
		existing:Destroy()
	end
end
for _, op in ipairs(bundle.operations) do
	if op.kind == "source" or op.kind == "module" then
		assert(loadstring(op.after), "After source does not compile: " .. label(op))
		if op.before then assert(loadstring(op.before), "Before source does not compile: " .. label(op)) end
	end
end
local states, summary = {}, { before = 0, after = 0, drift = 0 }
for i, op in ipairs(bundle.operations) do
	states[i] = stateOf(op)
	summary[states[i]] += 1
end
if summary.drift > 0 or (summary.before > 0 and summary.after > 0) then
	local detail = {}
	for i, op in ipairs(bundle.operations) do if states[i] ~= "before" or summary.after > 0 then table.insert(detail, label(op) .. "=" .. states[i]) end end
	error("Unexpected or partial state; inspect before proceeding: " .. table.concat(detail, ", "))
end
local current = summary.after > 0 and "after" or "before"
if mode == "AUDIT" then return { state = current, operations = #bundle.operations, changed = 0 } end
if (mode == "APPLY" and current == "after") or (mode == "ROLLBACK" and current == "before") then
	return { state = current, operations = #bundle.operations, changed = 0 }
end
local order = {}
if mode == "APPLY" then for i = 1, #bundle.operations do order[#order + 1] = i end
else for i = #bundle.operations, 1, -1 do order[#order + 1] = i end end
local done = {}
local ok, err = pcall(function()
	for _, i in ipairs(order) do
		local op = bundle.operations[i]
		if mode == "APPLY" then apply(op) else revert(op) end
		done[#done + 1] = i
	end
	for _, op in ipairs(bundle.operations) do
		assert(stateOf(op) == (mode == "APPLY" and "after" or "before"), "Post-write audit failed at " .. label(op))
	end
end)
if not ok then
	local failures = {}
	for k = #done, 1, -1 do
		local op = bundle.operations[done[k]]
		local restored, why = pcall(function() if mode == "APPLY" then revert(op) else apply(op) end end)
		if not restored then table.insert(failures, label(op) .. ": " .. tostring(why)) end
	end
	error(tostring(err) .. (#failures > 0 and ("; RECOVERY INCOMPLETE: " .. table.concat(failures, "; ")) or "; restored attempted changes"))
end
return { state = mode == "APPLY" and "after" or "before", operations = #bundle.operations, changed = #done }
'''


def render(bundle, mode):
    return ("-- Generated feature installer (scripts/feature_installer.py). Review specs and diffs.\n"
            "local bundle = " + lua(bundle) + "\nlocal mode = " + lua(mode) + "\n" + ENGINE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture")
    parser.add_argument("output")
    parser.add_argument("specs", nargs="+")
    parser.add_argument("--mode", choices=["AUDIT", "APPLY", "ROLLBACK"], default="AUDIT")
    args = parser.parse_args()
    specs = [json.loads(pathlib.Path(p).read_text(encoding="utf8")) for p in args.specs]
    bundle = build(specs, capture.load(args.capture))
    out = pathlib.Path(args.output).resolve()
    if not out.is_relative_to((ROOT / "scripts").resolve()):
        raise ValueError("Installer must be written under scripts/")
    out.write_text(render(bundle, args.mode), encoding="utf8", newline="\n")
    print(json.dumps(dict(mode=args.mode, tasks=bundle["tasks"], operations=len(bundle["operations"]), output=str(out))))


if __name__ == "__main__":
    main()
