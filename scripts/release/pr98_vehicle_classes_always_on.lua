-- Command Bar / execute_luau (Edit), PR98 only. Removes the FeatureFlag attribute from the Exotic and Muscle
-- category folders, so GarageServer and GarageCatalogService treat both classes as always enabled (no attribute =
-- enabled, like Piercer). Live servers read these flags from Creator Dashboard configs with default off, and PR98's
-- universe has none, so the dealership listed no vehicles. Idempotent.
-- Back: set FeatureFlag = "VehicleClass_exotic" on EXOTIC and "VehicleClass_muscle" on MUSCLE.
assert(game.PlaceId == 103397770260610, "wrong place: PR98 only")
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local categories = game.ServerStorage.Assets.Vehicles.Categories
local EXPECT = { EXOTIC = "VehicleClass_exotic", MUSCLE = "VehicleClass_muscle" }
local out = {}
for name, key in EXPECT do
	local folder = categories:FindFirstChild(name)
	assert(folder, name .. " category folder is missing")
	local now = folder:GetAttribute("FeatureFlag")
	assert(now == nil or now == key, name .. " carries an unexpected FeatureFlag: " .. tostring(now))
	folder:SetAttribute("FeatureFlag", nil)
	table.insert(out, name .. ": " .. tostring(now) .. " -> " .. tostring(folder:GetAttribute("FeatureFlag")))
end
table.sort(out)
return table.concat(out, "; ")
