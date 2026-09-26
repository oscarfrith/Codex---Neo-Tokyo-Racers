"""Build the canonical route-guide installer (AUDIT / APPLY / ROLLBACK).

One guarded migration for Street Life design 10.2:
  creates  ReplicatedStorage.Modules.Game.World.RoadRouting        (ModuleScript)
           ReplicatedStorage.Modules.Game.World.RoadGraphData      (ModuleScript, generated data)
           ReplicatedStorage.Modules.Game.UI.RouteGuide            (ModuleScript)
           ReplicatedStorage.Config.UI.RouteGuide (+ Destinations)  (Folders with attributes)
  edits    DesktopFreeRoamHudUI, MobileFreeRoamHudUI, RaceBrowserClient (exact before-source from the capture)

Usage: py scripts/route_guide/build_installer.py CAPTURE OUTPUT --mode AUDIT|APPLY|ROLLBACK
"""
import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import studio_capture as capture  # noqa: E402
from studio_delivery import lua  # noqa: E402

HERE = ROOT / "scripts" / "route_guide"
RS = ["ReplicatedStorage"]

MODULES = [
    (RS + ["Modules", "Game", "World"], "RoadRouting", "RoadRouting.lua"),
    (RS + ["Modules", "Game", "World"], "RoadGraphData", "RoadGraphData.lua"),
    (RS + ["Modules", "Game", "UI"], "RouteGuide", "RouteGuide.lua"),
]
SOURCES = [
    (RS + ["Modules", "Game", "UI", "DesktopFreeRoamHudUI"], "DesktopFreeRoamHudUI.lua"),
    (RS + ["Modules", "Game", "UI", "MobileFreeRoamHudUI"], "MobileFreeRoamHudUI.lua"),
    (RS + ["Modules", "Game", "Racing", "RaceBrowserClient"], "RaceBrowserClient.lua"),
]
CONFIG_ATTRIBUTES = {
    "Enabled": True,
    "LineWidth": 3,
    "OffRouteStuds": 60,
    "OffRouteSeconds": 1,
    "ReplanMinSeconds": 1,
    "ArriveStuds": 45,
    "ProgressHz": 10,
    "StudsPerMile": 5760,
    "ChipEnabled": True,
    "Owner": "RouteGuide",
}
W = ["Workspace", "World"]
DESTINATIONS = [
    ("Dealership", {"DisplayName": "Dealership", "Kind": "Place", "Order": 1},
     W + ["Dealership", "TeleportPoints", "FreeRoamHudTeleportPoint"]),
    ("MyGarage", {"DisplayName": "My Garage", "Kind": "Place", "Order": 2},
     W + ["OwnedGarageExteriors", "STARTER_TWO_BAY", "DriveInEntrance"]),
    ("Race_ShowroomLoop", {"DisplayName": "Showroom Loop", "Kind": "Race", "RouteId": "ShowroomLoop", "Order": 10},
     W + ["RaceRoutes", "ShowroomLoop", "StartZones", "RaceStartZone"]),
    ("Race_ShiftedCanalSprint", {"DisplayName": "Waterfront Sprint", "Kind": "Race", "RouteId": "ShiftedCanalSprint", "Order": 11},
     W + ["RaceRoutes", "ShiftedCanalSprint", "StartZones", "RaceStartZone"]),
]

ENGINE = r'''
local HttpService = game:GetService("HttpService")
assert(game.PlaceId == bundle.place_id and not game:GetService("RunService"):IsRunning(), "Wrong place or not in Edit")
local function child(parent, name)
	local found
	for _, item in ipairs(parent:GetChildren()) do
		if item.Name == name then assert(not found, "Ambiguous path at " .. name); found = item end
	end
	return found
end
local function resolve(path)
	local current = game
	for _, name in ipairs(path) do
		current = child(current, name)
		assert(current, "Missing path " .. table.concat(path, "."))
	end
	return current
end
local function resolveMaybe(path)
	local current = game
	for _, name in ipairs(path) do
		current = child(current, name)
		if not current then return nil end
	end
	return current
end
local function round(v) return Vector3.new(math.floor(v.X * 10 + 0.5) / 10, math.floor(v.Y * 10 + 0.5) / 10, math.floor(v.Z * 10 + 0.5) / 10) end
local function expectedAttributes(op)
	local attrs = {}
	for k, v in pairs(op.attributes) do attrs[k] = v end
	if op.position_from then attrs.Position = round(resolve(op.position_from).Position) end
	return attrs
end
local function stateOf(op)
	if op.kind == "source" then
		local target = resolve(op.path)
		assert(target.ClassName == op.class_name, "Class drift at " .. op.path[#op.path])
		if target.Source == op.before then return "before" end
		if target.Source == op.after then return "after" end
		return "drift"
	end
	local parent = resolveMaybe(op.parent)
	local existing = parent and child(parent, op.name)
	if not existing then return "before" end
	if existing.ClassName ~= op.class_name then return "drift" end
	if op.kind == "module" then return existing.Source == op.after and "after" or "drift" end
	for k, v in pairs(expectedAttributes(op)) do
		if existing:GetAttribute(k) ~= v then return "drift" end
	end
	return "after"
end
local function apply(op)
	if op.kind == "source" then resolve(op.path).Source = op.after return end
	local item = Instance.new(op.class_name)
	item.Name = op.name
	if op.kind == "module" then item.Source = op.after end
	if op.kind == "folder" then for k, v in pairs(expectedAttributes(op)) do item:SetAttribute(k, v) end end
	item.Parent = resolve(op.parent)
end
local function revert(op)
	if op.kind == "source" then resolve(op.path).Source = op.before return end
	local parent = resolveMaybe(op.parent)
	local existing = parent and child(parent, op.name)
	if existing then existing:Destroy() end
end

for _, op in ipairs(bundle.operations) do
	if op.kind == "source" or op.kind == "module" then
		assert(loadstring(op.after), "After source does not compile: " .. (op.name or op.path[#op.path]))
		if op.before then assert(loadstring(op.before), "Before source does not compile") end
	end
end
local states, summary = {}, { before = 0, after = 0, drift = 0 }
for i, op in ipairs(bundle.operations) do
	states[i] = stateOf(op)
	summary[states[i]] += 1
end
local label = function(op) return op.name or table.concat(op.path, ".") end
if summary.drift > 0 or (summary.before > 0 and summary.after > 0) then
	local detail = {}
	for i, op in ipairs(bundle.operations) do table.insert(detail, label(op) .. "=" .. states[i]) end
	error("Unexpected or partial state; inspect before proceeding: " .. table.concat(detail, ", "))
end
local current = summary.after > 0 and "after" or "before"
if mode == "AUDIT" then return { state = current, operations = #bundle.operations, changed = 0 } end
if (mode == "APPLY" and current == "after") or (mode == "ROLLBACK" and current == "before") then
	return { state = current, operations = #bundle.operations, changed = 0 }
end

local order = {}
if mode == "APPLY" then
	for i = 1, #bundle.operations do order[#order + 1] = i end
else
	for i = #bundle.operations, 1, -1 do order[#order + 1] = i end
end
local done = {}
local ok, err = pcall(function()
	for _, i in ipairs(order) do
		local op = bundle.operations[i]
		if mode == "APPLY" then apply(op) else revert(op) end
		done[#done + 1] = i
	end
	for i, op in ipairs(bundle.operations) do
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


def build(baseline):
    operations = []
    for parent, name, file in MODULES:
        operations.append(dict(kind="module", parent=parent, name=name, class_name="ModuleScript",
                               after=(HERE / file).read_bytes().decode("utf8")))
    config_parent = RS + ["Config", "UI"]
    operations.append(dict(kind="folder", parent=config_parent, name="RouteGuide", class_name="Folder",
                           attributes=CONFIG_ATTRIBUTES))
    operations.append(dict(kind="folder", parent=config_parent + ["RouteGuide"], name="Destinations", class_name="Folder",
                           attributes={"Note": "Route guide destinations. Position is copied from SourcePath by the installer; rerun it after moving a source part."}))
    for name, attributes, source in DESTINATIONS:
        attrs = dict(attributes, SourcePath=".".join(source))
        operations.append(dict(kind="folder", parent=config_parent + ["RouteGuide", "Destinations"], name=name,
                               class_name="Folder", attributes=attrs, position_from=source))
    for path, file in SOURCES:
        matches = [r for r in baseline["manifest"] if r["path_parts"] == path]
        if len(matches) != 1:
            raise ValueError("Source missing or ambiguous in capture: " + ".".join(path))
        record = matches[0]
        operations.append(dict(kind="source", path=path, class_name=record["class_name"],
                               before=(ROOT / record["file"]).read_bytes().decode("utf8"),
                               after=(HERE / file).read_bytes().decode("utf8")))
    return dict(place_id=baseline["place_id"], capture_sha256=baseline["content_sha256"], operations=operations)


def render(bundle, mode):
    return ("-- Generated route-guide installer (scripts/route_guide/build_installer.py). Review the spec and diffs.\n"
            "local bundle = " + lua(bundle) + "\nlocal mode = " + lua(mode) + "\n" + ENGINE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture")
    parser.add_argument("output")
    parser.add_argument("--mode", choices=["AUDIT", "APPLY", "ROLLBACK"], default="AUDIT")
    args = parser.parse_args()
    bundle = build(capture.load(args.capture))
    out = pathlib.Path(args.output).resolve()
    if not out.is_relative_to((ROOT / "scripts").resolve()):
        raise ValueError("Installer must be written under scripts/")
    out.write_text(render(bundle, args.mode), encoding="utf8", newline="\n")
    print(json.dumps(dict(mode=args.mode, operations=len(bundle["operations"]), output=str(out))))


if __name__ == "__main__":
    main()
