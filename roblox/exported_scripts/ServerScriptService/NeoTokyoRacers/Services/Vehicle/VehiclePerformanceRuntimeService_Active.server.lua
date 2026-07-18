-- NTR_VEHICLE_PERFORMANCE_V2_CANONICAL_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local PerformanceRuntime = require(performance:WaitForChild("VehiclePerformanceRuntime"))
local vehicles = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Runtime"):WaitForChild("PlayerVehicles")
local pending = {}

local function writeVehicle(vehicle)
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent == vehicles) or pending[vehicle] then return end
	pending[vehicle] = true
	task.spawn(function()
		local deadline = os.clock() + 5
		repeat
			if not vehicle.Parent then pending[vehicle] = nil; return end
			if vehicle:GetAttribute("V2Materialised") == true and vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") then break end
			task.wait(0.05)
		until os.clock() >= deadline
		local ok, result = pcall(function()
			local calculated = PerformanceRuntime.CalculateBuild(nil, vehicle, vehicle:FindFirstChild("INSTALLED_MODULES_Runtime"))
			PerformanceRuntime.WriteToVehicle(vehicle, calculated)
			return calculated
		end)
		pending[vehicle] = nil
		if ok then
			print(string.format("[NTR Canonical V2 Runtime] Wrote %s %s to %s", tostring(result.Overall.Tier), tostring(result.Overall.PerformanceIndex), vehicle.Name))
		else warn("[NTR Canonical V2 Runtime] Failed for " .. vehicle:GetFullName() .. ": " .. tostring(result)) end
	end)
end

vehicles.ChildAdded:Connect(writeVehicle)
for _, vehicle in ipairs(vehicles:GetChildren()) do writeVehicle(vehicle) end
print("[NTR Canonical V2 Runtime] Spawned-vehicle performance writer active.")
