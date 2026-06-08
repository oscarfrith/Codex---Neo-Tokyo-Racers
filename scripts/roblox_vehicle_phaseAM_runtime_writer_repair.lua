-- Neo Tokyo Racers - Vehicle Phase AM runtime writer repair
-- Run in the Roblox Studio Command Bar while NOT play-testing.
--
-- Installs a small server service that calculates Phase AM data whenever a
-- player vehicle appears. This avoids relying on the garage controller's
-- internal build-function source shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")

assert(performance:FindFirstChild("VehiclePerformanceRuntime"), "VehiclePerformanceRuntime is missing. Run the Phase AM installer first.")

local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local vehicleServices = services:FindFirstChild("Vehicle")
if not vehicleServices then
	vehicleServices = Instance.new("Folder")
	vehicleServices.Name = "Vehicle"
	vehicleServices.Parent = services
end

local service = vehicleServices:FindFirstChild("VehiclePerformanceRuntimeService_Active")
if service and not service:IsA("Script") then
	error(service:GetFullName() .. " must be a Script")
end
if not service then
	service = Instance.new("Script")
	service.Name = "VehiclePerformanceRuntimeService_Active"
	service.Parent = vehicleServices
end

service.Source = [==[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit
	:WaitForChild("Shared")
	:WaitForChild("Modules")
	:WaitForChild("Common")
	:WaitForChild("Performance")
local PerformanceRuntime = require(performance:WaitForChild("VehiclePerformanceRuntime"))

local vehicles = Workspace
	:WaitForChild("NeoTokyoRacersWorld")
	:WaitForChild("Runtime")
	:WaitForChild("PlayerVehicles")

local pending = {}

local function readLegacyTotals(vehicle)
	local totals = {}
	local folder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	if folder then
		for _, value in ipairs(folder:GetChildren()) do
			if value:IsA("NumberValue") then
				totals[value.Name] = value.Value
			end
		end
	end

	local defaults = {
		TopSpeed = 126,
		Acceleration = 42,
		Handling = 48,
		Drift = 46,
		Braking = 44,
		Weight = 118,
		Boost = 0,
		BoostDuration = 2,
		BoostRecharge = 9,
		BoostRechargeDelay = 0.5,
	}
	for name, fallback in pairs(defaults) do
		local attribute = vehicle:GetAttribute(name)
		if totals[name] == nil then
			totals[name] = typeof(attribute) == "number" and attribute or fallback
		end
	end
	return totals
end

local function writeVehicle(vehicle)
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent == vehicles) then return end
	if pending[vehicle] then return end
	pending[vehicle] = true

	task.spawn(function()
		local deadline = os.clock() + 5
		repeat
			if not vehicle.Parent then
				pending[vehicle] = nil
				return
			end
			if vehicle:FindFirstChild("TOTAL_STATS_Runtime") then break end
			task.wait(0.05)
		until os.clock() >= deadline

		local ok, result = pcall(function()
			local totals = readLegacyTotals(vehicle)
			local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
			local calculated = PerformanceRuntime.CalculateBuild(totals, vehicle, installedRoot)
			PerformanceRuntime.WriteToVehicle(vehicle, calculated)
			return calculated
		end)

		pending[vehicle] = nil
		if ok then
			print(string.format(
				"[NTR Vehicle Phase AM Runtime] Wrote %s %s to %s",
				tostring(result.Overall.Tier),
				tostring(result.Overall.PerformanceIndex),
				vehicle.Name
			))
		else
			warn("[NTR Vehicle Phase AM Runtime] Failed for " .. vehicle:GetFullName() .. ": " .. tostring(result))
		end
	end)
end

vehicles.ChildAdded:Connect(writeVehicle)
for _, vehicle in ipairs(vehicles:GetChildren()) do
	writeVehicle(vehicle)
end

print("[NTR Vehicle Phase AM Runtime] Spawned-vehicle performance writer active.")
]==]

service.Disabled = false
service:SetAttribute("Phase", "AM")
service:SetAttribute("Repair", "RuntimeWriter")

print("[NTR Vehicle Phase AM Repair] Installed " .. service:GetFullName())
print("[NTR Vehicle Phase AM Repair] Start a fresh Play session, spawn a vehicle, then rerun the Phase AM runtime audit.")
