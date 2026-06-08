local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceCalculator"))

local Runtime = {}

local function numberAttribute(item, name)
	local value = item and item:GetAttribute(name)
	return typeof(value) == "number" and value or nil
end

local function collectInstalledModels(installedRoot)
	local result = {}
	if not installedRoot then return result end
	for _, item in ipairs(installedRoot:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil then
			table.insert(result, item)
		end
	end
	return result
end

function Runtime.CalculateBuild(legacyTotals, cockpit, installedRoot)
	local raw = Calculator.FromLegacyStats(legacyTotals)

	for _, variableName in ipairs(Definitions.RawVariableOrder) do
		local override = numberAttribute(cockpit, "PerformanceOverride_" .. variableName)
		if override ~= nil then
			raw[variableName] = override
		end
		local cockpitDelta = numberAttribute(cockpit, "PerformanceDelta_" .. variableName)
		if cockpitDelta ~= nil then
			raw[variableName] = (raw[variableName] or 0) + cockpitDelta
		end
	end

	for _, module in ipairs(collectInstalledModels(installedRoot)) do
		for _, variableName in ipairs(Definitions.RawVariableOrder) do
			local delta = numberAttribute(module, "PerformanceDelta_" .. variableName)
			if delta ~= nil then
				raw[variableName] = (raw[variableName] or 0) + delta
			end
		end
	end

	return Calculator.Calculate(raw)
end

local function rewriteNumberFolder(vehicle, name, values)
	local folder = vehicle:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = vehicle
	end
	folder:ClearAllChildren()
	for key, value in pairs(values) do
		if typeof(value) == "number" then
			local number = Instance.new("NumberValue")
			number.Name = key
			number.Value = value
			number.Parent = folder
		end
	end
	return folder
end

function Runtime.WriteToVehicle(vehicle, result)
	assert(typeof(vehicle) == "Instance", "vehicle is required")
	assert(typeof(result) == "table", "performance result is required")

	rewriteNumberFolder(vehicle, "RAW_PERFORMANCE_Runtime", result.Raw or {})
	rewriteNumberFolder(vehicle, "NORMALIZED_PERFORMANCE_Runtime", result.Normalized or {})
	rewriteNumberFolder(vehicle, "HEADLINE_STATS_Runtime", result.Headline or {})

	for key, value in pairs(result.Raw or {}) do
		if typeof(value) == "number" then
			vehicle:SetAttribute("Performance_" .. key, value)
		end
	end

	local overall = result.Overall or {}
	vehicle:SetAttribute("PerformanceIndex", overall.PerformanceIndex or 100)
	vehicle:SetAttribute("PerformanceTier", overall.Tier or "E")
	vehicle:SetAttribute("PerformanceScore", overall.Score or 0)
	vehicle:SetAttribute("PerformanceRuntimeVersion", "AM_1")
end

return Runtime
