local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")

local VehicleData = {}
VehicleData.Categories = kit:WaitForChild("VEHICLE_CATEGORIES")
VehicleData.Modules = kit:WaitForChild("MODULES_InterchangeableWithinCategory")

function VehicleData.GetCategories()
	return VehicleData.Categories:GetChildren()
end

function VehicleData.GetCockpits(categoryName)
	local category = VehicleData.Categories:FindFirstChild(categoryName)
	local cockpits = category and category:FindFirstChild("Cockpits")
	return cockpits and cockpits:GetChildren() or {}
end

function VehicleData.GetModuleOptions(categoryName, slotName)
	local categoryModules = VehicleData.Modules:FindFirstChild(categoryName)
	local slot = categoryModules and categoryModules:FindFirstChild(slotName)
	return slot and slot:GetChildren() or {}
end

function VehicleData.ReadStats(instance)
	local stats = {}
	for _, name in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "Power" }) do
		stats[name] = instance and instance:GetAttribute(name) or 0
	end
	return stats
end

return VehicleData
