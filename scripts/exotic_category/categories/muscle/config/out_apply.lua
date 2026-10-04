local MODE = "APPLY"
local DATA = game:GetService("HttpService"):JSONDecode([==[{"contentHash": "ba880c2d2b52bf223f2651600dc1cbb5ca5b614485660f621f3443fe72fde6c2", "flag": "VehicleClass_muscle", "folder": "MUSCLE", "marker": "muscle_category/stage_b", "null": "__nil__", "placeId": 93959280828322, "rows": [{"before": "__nil__", "key": "Hidden_muscle", "path": ["ReplicatedStorage", "Config", "UI", "GarageReplacement", "ModuleArtwork", "SidePods"], "value": true}, {"before": "__nil__", "key": "Hidden_muscle", "path": ["ReplicatedStorage", "Config", "UI", "GarageReplacement", "ModuleArtwork", "FrontBumper"], "value": true}, {"before": "__nil__", "key": "Hidden_muscle", "path": ["ReplicatedStorage", "Config", "UI", "GarageReplacement", "ModuleArtwork", "RearBumper"], "value": true}, {"before": "__nil__", "key": "VariantLabels_muscle", "path": ["ReplicatedStorage", "Config", "UI", "GarageReplacement"], "value": "Lightweight=GT;Power=EVO"}, {"before": "bruiser", "key": "DealershipHiddenCategories", "path": ["ReplicatedStorage", "Config", "UI", "GarageReplacement"], "value": "bruiser,muscle"}, {"before": "__nil__", "key": "Flag_VehicleClass_muscle", "path": ["ServerStorage", "Config"], "value": true}]}]==])
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
