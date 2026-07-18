-- Neo Tokyo Racers - Garage module inventory cleanup dry run
-- NTR_GARAGE_MODULE_INVENTORY_CLEANUP_DRY_RUN_V1
-- Read only. Run during a fresh Play session from Studio's Server Command Bar.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PREFIX = "[NTR Garage Module Cleanup Dry Run] "
if not RunService:IsRunning() or not RunService:IsServer() or Players.LocalPlayer then
	error(PREFIX .. "Run during Play from the Server Command Bar.", 0)
end

local player = Players:GetPlayers()[1]
if not player then error(PREFIX .. "No player is present.", 0) end
local ntr = ServerScriptService:FindFirstChild("NeoTokyoRacers")
local services = ntr and ntr:FindFirstChild("Services")
local garage = services and services:FindFirstChild("Garage")
local playerServices = services and services:FindFirstChild("Player")
local bindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
local getProfile = bindings and bindings:FindFirstChild("GetProfile")
local runtimeModule = garage and garage:FindFirstChild("GarageModuleInventoryRuntime")
if not (getProfile and getProfile:IsA("BindableFunction")) then error(PREFIX .. "GetProfile binding missing.", 0) end
if not (runtimeModule and runtimeModule:IsA("ModuleScript")) then error(PREFIX .. "GarageModuleInventoryRuntime missing; install the guard first.", 0) end

local profile = getProfile:Invoke(player)
if typeof(profile) ~= "table" then error(PREFIX .. "Live profile unavailable.", 0) end
local runtime = require(runtimeModule)
local plan = runtime.PlanCleanup(profile)

local function sortedKeys(dictionary)
	local result = {}
	for key in pairs(dictionary or {}) do table.insert(result, tostring(key)) end
	table.sort(result)
	return result
end

print(PREFIX .. "PLAYER " .. player.Name .. " userId=" .. tostring(player.UserId))
print(PREFIX .. string.format("SUMMARY total=%d delete=%d protect=%d review=%d missingRefs=%d",
	plan.TotalInstances, #plan.DeleteIds, #plan.ProtectedIds, #plan.ReviewIds, #plan.MissingReferences))
print(PREFIX .. "DELETE CANDIDATES BY TEMPLATE")
for _, templateId in ipairs(sortedKeys(plan.DeleteByTemplate)) do
	print(PREFIX .. "  " .. templateId .. " = " .. tostring(plan.DeleteByTemplate[templateId]))
end
print(PREFIX .. "PROTECTED BY SOURCE")
for _, source in ipairs(sortedKeys(plan.ProtectedBySource)) do
	print(PREFIX .. "  " .. source .. " = " .. tostring(plan.ProtectedBySource[source]))
end
print(PREFIX .. "MANUAL REVIEW BY REASON")
for _, reason in ipairs(sortedKeys(plan.ReviewByReason)) do
	print(PREFIX .. "  " .. reason .. " = " .. tostring(plan.ReviewByReason[reason]))
end
for index = 1, math.min(10, #plan.ReviewIds) do
	print(PREFIX .. "  REVIEW SAMPLE " .. tostring(index) .. " = " .. plan.ReviewIds[index])
end
print(PREFIX .. "TOKEN " .. plan.Token)
if #plan.MissingReferences == 0 then
	print(PREFIX .. "PASS all installed slot references resolve before cleanup")
else
	warn(PREFIX .. "BLOCKER missing installed references; do not apply cleanup")
end
print(PREFIX .. "READ ONLY COMPLETE - nothing was deleted, changed, marked dirty, or saved")

