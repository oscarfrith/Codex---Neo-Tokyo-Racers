-- Neo Tokyo Racers - Vehicle Phase AL read-only audit
-- Rerun after editing VehiclePerformance_EditAttributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local Definitions = require(performance:WaitForChild("VehiclePerformanceDefinitions"))
local Calculator = require(performance:WaitForChild("VehiclePerformanceCalculator"))
local Upgrades = require(performance:WaitForChild("VehicleUpgradeDefinitions"))
local config = Definitions.GetConfig()

assert(config, "VehiclePerformance_EditAttributes is missing. Run the Phase AL installer first.")

local warnings = {}
local function addWarning(message)
	table.insert(warnings, message)
	warn("[NTR Vehicle Phase AL Audit] " .. message)
end

for _, headlineName in ipairs(Definitions.HeadlineOrder) do
	local weights = Definitions.GetHeadlineWeights(headlineName)
	local total = 0
	for key, value in pairs(weights) do
		if typeof(value) == "number" then
			total += value
		end
	end
	if math.abs(total - 1) > 0.001 then
		addWarning(headlineName .. " weights total " .. string.format("%.3f", total) .. ", expected 1.000")
	end
end

local overall = Definitions.GetOverallSettings()
local overallTotal = 0
for _, name in ipairs(Definitions.HeadlineOrder) do
	overallTotal += overall[name] or 0
end
if math.abs(overallTotal - 1) > 0.001 then
	addWarning("Overall headline weights total " .. string.format("%.3f", overallTotal) .. ", expected 1.000")
end
if math.abs((overall.BaseContribution or 0) + (overall.BalanceContribution or 0) - 1) > 0.001 then
	addWarning("BaseContribution + BalanceContribution must total 1.000")
end

for _, variableName in ipairs(Definitions.RawVariableOrder) do
	local definition = Definitions.GetNormalization(variableName)
	if typeof(definition.Min) ~= "number" or typeof(definition.Max) ~= "number" or definition.Max <= definition.Min then
		addWarning(variableName .. " normalization range is invalid")
	end
end

local tiers = Definitions.GetTierBands()
if not (tiers.E < tiers.D and tiers.D < tiers.C and tiers.C < tiers.B and tiers.B < tiers.A and tiers.A < tiers.S) then
	addWarning("Tier thresholds must increase E < D < C < B < A < S")
end

local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local counts = { Cockpits = 0, Modules = 0 }
local tierCounts = { E = 0, D = 0, C = 0, B = 0, A = 0, S = 0 }

for _, item in ipairs(categories:GetDescendants()) do
	local isCockpit = item:IsA("Model") and item:GetAttribute("CockpitId") ~= nil
	local isModule = item:IsA("Model") and item:GetAttribute("ModuleId") ~= nil and item:GetAttribute("RetiredFromCatalog") ~= true
	if isCockpit or isModule then
		local result = Calculator.CalculateLegacy(item)
		if isCockpit then counts.Cockpits += 1 else counts.Modules += 1 end
		tierCounts[result.Overall.Tier] += 1
	end
end

local upgradeCount = 0
for _, definitions in pairs(Upgrades.ByModuleType) do
	upgradeCount += #definitions
end

print("[NTR Vehicle Phase AL Audit] Config: " .. config:GetFullName())
print("[NTR Vehicle Phase AL Audit] Cockpits: " .. tostring(counts.Cockpits))
print("[NTR Vehicle Phase AL Audit] Active modules: " .. tostring(counts.Modules))
print("[NTR Vehicle Phase AL Audit] Planned module upgrades: " .. tostring(upgradeCount))
print(string.format(
	"[NTR Vehicle Phase AL Audit] Standalone template tiers: E=%d D=%d C=%d B=%d A=%d S=%d",
	tierCounts.E,
	tierCounts.D,
	tierCounts.C,
	tierCounts.B,
	tierCounts.A,
	tierCounts.S
))
print("[NTR Vehicle Phase AL Audit] Warnings: " .. tostring(#warnings))
print("[NTR Vehicle Phase AL Audit] Read-only audit complete. Gameplay/UI remain on the Phase AK baseline.")
