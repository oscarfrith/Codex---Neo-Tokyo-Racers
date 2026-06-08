-- Neo Tokyo Racers - Vehicle Phase AM read-only runtime audit
-- Run while play-testing, after spawning the drivable vehicle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local Definitions = require(performance:WaitForChild("VehiclePerformanceDefinitions"))
local config = Definitions.GetConfig()
local runtimeConfig = config and config:FindFirstChild("RuntimeIntegration")

local warnings = {}
local function addWarning(message)
	table.insert(warnings, message)
	warn("[NTR Vehicle Phase AM Audit] " .. message)
end

local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
local runtime = world and world:FindFirstChild("Runtime")
local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
if not vehicles then
	addWarning("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles is missing")
end

local vehicle
local player = Players.LocalPlayer
for _, candidate in ipairs(vehicles and vehicles:GetChildren() or {}) do
	if not player or candidate:GetAttribute("OwnerUserId") == player.UserId then
		vehicle = candidate
		break
	end
end
if not vehicle and vehicles then
	vehicle = vehicles:GetChildren()[1]
end
if not vehicle then
	addWarning("No spawned player vehicle found. Run this audit during Play after SpawnVehicle.")
end

local function checkNumberFolder(folderName, expectedNames)
	local folder = vehicle and vehicle:FindFirstChild(folderName)
	if not (folder and folder:IsA("Folder")) then
		addWarning(folderName .. " is missing")
		return 0
	end
	local valid = 0
	for _, name in ipairs(expectedNames) do
		local value = folder:FindFirstChild(name)
		if not (value and value:IsA("NumberValue")) then
			addWarning(folderName .. "." .. name .. " is missing")
		else
			valid += 1
		end
	end
	return valid
end

local rawCount = checkNumberFolder("RAW_PERFORMANCE_Runtime", Definitions.RawVariableOrder)
local normalizedCount = checkNumberFolder("NORMALIZED_PERFORMANCE_Runtime", Definitions.RawVariableOrder)
local headlineCount = checkNumberFolder("HEADLINE_STATS_Runtime", Definitions.HeadlineOrder)

if vehicle then
	if typeof(vehicle:GetAttribute("PerformanceIndex")) ~= "number" then
		addWarning("PerformanceIndex attribute is missing")
	end
	if typeof(vehicle:GetAttribute("PerformanceTier")) ~= "string" then
		addWarning("PerformanceTier attribute is missing")
	end
	if vehicle:GetAttribute("PerformanceRuntimeVersion") ~= "AM_1" then
		addWarning("PerformanceRuntimeVersion is not AM_1")
	end
end

if not runtimeConfig then
	addWarning("RuntimeIntegration config folder is missing")
end

print("[NTR Vehicle Phase AM Audit] Vehicle: " .. (vehicle and vehicle:GetFullName() or "none"))
print("[NTR Vehicle Phase AM Audit] Raw variables: " .. tostring(rawCount) .. "/" .. tostring(#Definitions.RawVariableOrder))
print("[NTR Vehicle Phase AM Audit] Normalized variables: " .. tostring(normalizedCount) .. "/" .. tostring(#Definitions.RawVariableOrder))
print("[NTR Vehicle Phase AM Audit] Headline stats: " .. tostring(headlineCount) .. "/" .. tostring(#Definitions.HeadlineOrder))
if vehicle then
	print("[NTR Vehicle Phase AM Audit] Rating: " .. tostring(vehicle:GetAttribute("PerformanceTier")) .. " " .. tostring(vehicle:GetAttribute("PerformanceIndex")))
end
print("[NTR Vehicle Phase AM Audit] Physics enabled: " .. tostring(runtimeConfig and runtimeConfig:GetAttribute("PhysicsEnabled") == true))
print("[NTR Vehicle Phase AM Audit] Warnings: " .. tostring(#warnings))
print("[NTR Vehicle Phase AM Audit] Read-only audit complete.")
