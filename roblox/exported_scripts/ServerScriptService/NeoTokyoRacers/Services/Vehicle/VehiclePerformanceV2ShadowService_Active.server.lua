-- NTR_VEHICLE_PERFORMANCE_V2_PHASE7_SHADOW_SERVICE
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("VehiclePerformanceV2_EditAttributes")
local runtime = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"):WaitForChild("VehiclePerformanceV2Runtime"))
local pending = setmetatable({}, { __mode = "k" })

local function evaluate(vehicle)
	if config:GetAttribute("ShadowComparisonEnabled") ~= true then return end
	if not vehicle:IsA("Model") or not vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime") then return end
	local ok, result = pcall(runtime.CalculateRuntimeVehicle, vehicle)
	if ok then runtime.WriteShadow(vehicle, result) else warn("[NTR V2 Shadow] " .. vehicle:GetFullName() .. ": " .. tostring(result)) end
end

local function schedule(vehicle)
	if pending[vehicle] then return end
	pending[vehicle] = true
	task.delay(0.2, function()
		pending[vehicle] = nil
		if vehicle.Parent then evaluate(vehicle) end
	end)
end

local function consider(item)
	local folder
	if item.Name == "RAW_PERFORMANCE_Runtime" and item:IsA("Folder") then folder = item
	elseif item.Parent and item.Parent.Name == "RAW_PERFORMANCE_Runtime" and item.Parent:IsA("Folder") then folder = item.Parent end
	if folder and folder.Parent and folder.Parent:IsA("Model") then schedule(folder.Parent) end
end

Workspace.DescendantAdded:Connect(consider)
print("[NTR Vehicle Performance V2 Phase 7] Shadow comparison service active; live V1 rating/physics remain authoritative.")
