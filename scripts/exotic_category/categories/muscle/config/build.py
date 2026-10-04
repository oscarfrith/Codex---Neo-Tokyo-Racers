"""Modern Muscle: the config attributes that sit outside the content installer. Builds a guarded installer.

    py -3 scripts/exotic_category/categories/muscle/config/build.py

No script changes. Six attributes, each with the value it must hold before APPLY:
  Config.UI.GarageReplacement.ModuleArtwork.<SidePods|FrontBumper|RearBumper>  Hidden_muscle = true
      Side Pods, Splitter and Diffuser are left off the Build and Customise rails for Muscle cars.
  Config.UI.GarageReplacement  VariantLabels_muscle = "Lightweight=GT;Power=EVO"
      Core versions show as GT and EVO, as on Exotic.
  Config.UI.GarageReplacement  DealershipHiddenCategories = "bruiser,muscle"   (was "bruiser")
      Muscle is not on sale in the dealership. To show it, set the value back to "bruiser".
  ServerStorage.Config  Flag_VehicleClass_muscle = true
      Studio override read by Core.FeatureFlags. A published server reads the Creator Dashboard config key
      VehicleClass_muscle instead.
AUDIT writes nothing. APPLY writes only when every row holds its expected value or is already the target, and
only over the full install of the content build named in ../out/summary-full.json (rebuild this after a content build).
There is no ROLLBACK build: the place saves. Do not turn the flag off once a saved profile owns a Muscle car.
"""
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PLACE_ID = 93959280828322
GR = ["ReplicatedStorage", "Config", "UI", "GarageReplacement"]
NIL = "__nil__"
ROWS = [
    {"path": GR + ["ModuleArtwork", "SidePods"], "key": "Hidden_muscle", "before": NIL, "value": True},
    {"path": GR + ["ModuleArtwork", "FrontBumper"], "key": "Hidden_muscle", "before": NIL, "value": True},
    {"path": GR + ["ModuleArtwork", "RearBumper"], "key": "Hidden_muscle", "before": NIL, "value": True},
    {"path": GR, "key": "VariantLabels_muscle", "before": NIL, "value": "Lightweight=GT;Power=EVO"},
    {"path": GR, "key": "DealershipHiddenCategories", "before": "bruiser", "value": "bruiser,muscle"},
    {"path": ["ServerStorage", "Config"], "key": "Flag_VehicleClass_muscle", "before": NIL, "value": True},
]
ENGINE = r'''
assert(game.PlaceId == DATA.placeId, "muscle config: wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), "muscle config: stop Play first")
local function find(path)
	local node = game:GetService(path[1])
	for i = 2, #path do node = node and node:FindFirstChild(path[i]) end
	return node
end
local function same(a, b) return typeof(a) == typeof(b) and a == b end
-- The flag only goes on when the category it names is installed by the content installer.
local category = game:GetService("ServerStorage").Assets.Vehicles.Categories:FindFirstChild(DATA.folder)
local report, blockers, plan = {}, 0, {}
if not category or category:GetAttribute("InstalledBy") ~= DATA.marker or category:GetAttribute("FeatureFlag") ~= DATA.flag
	or category:GetAttribute("InstalledScope") ~= "full" or category:GetAttribute("InstalledContentHash") ~= DATA.contentHash then
	blockers += 1
	table.insert(report, "category " .. DATA.folder .. " is not the full install of build " .. string.sub(DATA.contentHash, 1, 8) .. " by " .. DATA.marker)
end
for _, row in ipairs(DATA.rows) do
	local node = find(row.path)
	local name = table.concat(row.path, ".") .. "@" .. row.key
	if not node then
		blockers += 1
		table.insert(report, name .. ": instance missing")
	else
		local now = node:GetAttribute(row.key)
		local before = row.before
		if before == DATA.null then before = nil end
		if same(now, row.value) then
			table.insert(report, name .. ": already " .. tostring(row.value))
		elseif same(now, before) then
			table.insert(report, name .. ": " .. tostring(now) .. " -> " .. tostring(row.value))
			table.insert(plan, {node = node, row = row})
		else
			blockers += 1
			table.insert(report, name .. ": unexpected value " .. tostring(now))
		end
	end
end
if blockers > 0 or MODE == "AUDIT" then
	return table.concat(report, "; ") .. " | blockers=" .. blockers .. " toWrite=" .. #plan .. " mode=" .. MODE .. " (nothing written)"
end
for _, item in ipairs(plan) do item.node:SetAttribute(item.row.key, item.row.value) end
for _, row in ipairs(DATA.rows) do
	assert(same(find(row.path):GetAttribute(row.key), row.value), "muscle config: read-back failed for " .. row.key)
end
return table.concat(report, "; ") .. " | mode=" .. MODE .. " written=" .. #plan
'''


def main():
    # The flag goes on only over the full install of the current content build (out/summary-full.json).
    summary = json.load(io.open(os.path.join(HERE, "..", "out", "summary-full.json"), encoding="utf-8"))
    assert summary["scope"] == "full" and summary["fixture"] is False, "build the full content installer first"
    data = json.dumps({"placeId": PLACE_ID, "folder": "MUSCLE", "marker": "muscle_category/stage_b",
                       "flag": "VehicleClass_muscle", "contentHash": summary["contentHash"], "null": NIL, "rows": ROWS}, sort_keys=True)
    for mode in ("AUDIT", "APPLY"):
        out = 'local MODE = "%s"\nlocal DATA = game:GetService("HttpService"):JSONDecode([==[%s]==])%s' % (mode, data, ENGINE)
        io.open(os.path.join(HERE, "out_%s.lua" % mode.lower()), "w", encoding="utf-8", newline="\n").write(out)
    print("built out_audit.lua and out_apply.lua: %d rows" % len(ROWS))


if __name__ == "__main__":
    main()
