-- Neo Tokyo Racers - Vehicle Phase AN spawned upgrade audit
-- Run from the CLIENT Command Bar during the same Play session after:
-- 1. Purchasing Fuel Injection level 1 on Engine1.
-- 2. Finishing customisation and spawning the drivable vehicle.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local vehicles = Workspace
	:WaitForChild("NeoTokyoRacersWorld")
	:WaitForChild("Runtime")
	:WaitForChild("PlayerVehicles")

local vehicle
for _, candidate in ipairs(vehicles:GetChildren()) do
	if candidate:GetAttribute("OwnerUserId") == player.UserId then
		vehicle = candidate
		break
	end
end
assert(vehicle, "No spawned vehicle found for " .. player.Name)

local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
assert(installedRoot, "INSTALLED_MODULES_Runtime is missing")

local engine
for _, module in ipairs(installedRoot:GetChildren()) do
	if module:IsA("Model") and module:GetAttribute("InstalledSlotId") == "Engine1" then
		engine = module
		break
	end
end
assert(engine, "Spawned Engine1 module clone is missing")

local level = engine:GetAttribute("AppliedUpgrade_FuelInjection")
local engineDelta = engine:GetAttribute("PerformanceDelta_EngineOutput")
local speedDelta = engine:GetAttribute("PerformanceDelta_TopSpeed")
local tier = vehicle:GetAttribute("PerformanceTier")
local index = vehicle:GetAttribute("PerformanceIndex")

local warnings = 0
local function check(condition, message)
	if not condition then
		warnings += 1
		warn("[NTR Vehicle Phase AN Spawn Audit] " .. message)
	end
end

check(level == 1, "AppliedUpgrade_FuelInjection expected 1, got " .. tostring(level))
check(typeof(engineDelta) == "number" and engineDelta >= 2, "EngineOutput delta does not include Fuel Injection level 1")
check(typeof(speedDelta) == "number" and speedDelta >= 1, "TopSpeed delta does not include Fuel Injection level 1")
check(typeof(index) == "number", "Spawned PerformanceIndex is missing")
check(typeof(tier) == "string", "Spawned PerformanceTier is missing")

print("[NTR Vehicle Phase AN Spawn Audit] Vehicle: " .. vehicle:GetFullName())
print("[NTR Vehicle Phase AN Spawn Audit] Engine module: " .. tostring(engine:GetAttribute("ModuleId")))
print("[NTR Vehicle Phase AN Spawn Audit] Fuel Injection level: " .. tostring(level))
print("[NTR Vehicle Phase AN Spawn Audit] EngineOutput delta: " .. tostring(engineDelta))
print("[NTR Vehicle Phase AN Spawn Audit] TopSpeed delta: " .. tostring(speedDelta))
print("[NTR Vehicle Phase AN Spawn Audit] Runtime rating: " .. tostring(tier) .. " " .. tostring(index))
print("[NTR Vehicle Phase AN Spawn Audit] Warnings: " .. tostring(warnings))
print("[NTR Vehicle Phase AN Spawn Audit] Read-only audit complete.")
