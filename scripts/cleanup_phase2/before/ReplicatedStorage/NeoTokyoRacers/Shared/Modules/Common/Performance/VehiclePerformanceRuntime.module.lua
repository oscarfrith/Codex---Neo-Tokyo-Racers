-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
-- Compatibility-shaped API with one unconditional V2 calculation owner.
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}

local function installed(root)
	local result = {}
	if root then
		for _, item in ipairs(root:GetChildren()) do
			if item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil then table.insert(result, item) end
		end
	end
	return result
end

function Runtime.CalculateBuild(_legacyTotals, cockpit, installedRoot)
	assert(cockpit and cockpit:GetAttribute("V2Materialised") == true, "Canonical V2 cockpit is not materialised")
	return V2Runtime.CalculateComponents(cockpit, installed(installedRoot), {})
end

local function rewrite(vehicle, name, values)
	local folder = vehicle:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then folder:Destroy(); folder = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = name; folder.Parent = vehicle end
	folder:ClearAllChildren()
	for key, value in pairs(values or {}) do
		if typeof(value) == "number" then local number = Instance.new("NumberValue"); number.Name = key; number.Value = value; number.Parent = folder end
	end
end

function Runtime.WriteToVehicle(vehicle, result)
	rewrite(vehicle, "RAW_PERFORMANCE_Runtime", result.Raw or {})
	rewrite(vehicle, "NORMALIZED_PERFORMANCE_Runtime", result.Normalized or result.EffectiveFactor or {})
	rewrite(vehicle, "HEADLINE_STATS_Runtime", result.Headline or {})
	for key, value in pairs(result.Raw or {}) do if typeof(value) == "number" then vehicle:SetAttribute("Performance_" .. key, value) end end
	local overall = result.Overall or {}
	vehicle:SetAttribute("PerformanceIndex", overall.PerformanceIndex or 100)
	vehicle:SetAttribute("PerformanceTier", overall.Tier or "E")
	vehicle:SetAttribute("PerformanceScore", overall.Score or 0)
	vehicle:SetAttribute("PerformanceRuntimeVersion", "V2_CANONICAL_RUNTIME_V1")
end

return Runtime
