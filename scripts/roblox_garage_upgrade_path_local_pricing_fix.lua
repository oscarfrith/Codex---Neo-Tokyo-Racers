-- Neo Tokyo Racers - Path-local module upgrade pricing
-- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1"
local UI_BASELINE = "NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1"
local PREFIX = "[NTR Garage Path Pricing]"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local performance = need(need(need(need(kit, "Shared", "Folder"), "Modules", "Folder"), "Common", "Folder"), "Performance", "Folder")
local upgrades = need(performance, "VehiclePerformanceV2UpgradeRuntime", "ModuleScript")
local resolver = need(performance, "VehiclePerformanceResolver", "ModuleScript")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local application = need(need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder"), "ModuleShopUIController", "ModuleScript")

assert(string.find(upgrades.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE7_UPGRADE_RUNTIME", 1, true), "Canonical V2 upgrade runtime baseline missing")
assert(string.find(resolver.Source, "NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1", 1, true), "Canonical upgrade-preview resolver baseline missing")
assert(string.find(application.Source, UI_BASELINE, 1, true) or string.find(application.Source, REVISION, 1, true), "Confirmed V1.1 upgrade-card baseline missing; refresh the mirror and regenerate instead of guessing")

local upgradeSource = upgrades.Source
if not string.find(upgradeSource, REVISION, 1, true) then
	upgradeSource = replaceOnce(upgradeSource,
		[[function Runtime.NextPointCost(module, allocation)
	local _, spent, capacity = Runtime.NormalizeAllocation(module, allocation)
	if spent >= capacity then return nil end
	return tonumber(module:GetAttribute("Point" .. tostring(spent + 1) .. "CostGuide")) or 0
end]],
		[[function Runtime.NextPointCost(module, allocation, pathId) -- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1
	local normalized, spent, capacity = Runtime.NormalizeAllocation(module, allocation)
	if spent >= capacity then return nil end
	local point = spent + 1
	if pathId ~= nil then
		local id = tostring(pathId); local root = pathsRoot(module); local path = root and root:FindFirstChild(id)
		if not path then return nil end
		local level = math.max(0, math.floor(tonumber(normalized[id]) or 0)); local maximum = math.max(0, math.floor(tonumber(path:GetAttribute("MaxPoints")) or 3))
		if level >= maximum then return nil end
		point = level + 1
		local override = path:GetAttribute("Point" .. tostring(point) .. "CostGuide")
		if override ~= nil then return math.max(0, tonumber(override) or 0) end
	end
	return math.max(0, tonumber(module:GetAttribute("Point" .. tostring(point) .. "CostGuide")) or 0)
end]], "path-local pricing authority")
	upgradeSource = replaceOnce(upgradeSource,
		[[Points = normalized[id] or 0, MaxPoints = tonumber(path:GetAttribute("MaxPoints")) or 3,
			TotalPoints = spent, Capacity = capacity, NextPointCost = Runtime.NextPointCost(module, normalized),]],
		[[Points = normalized[id] or 0, MaxPoints = tonumber(path:GetAttribute("MaxPoints")) or 3,
			TotalPoints = spent, Capacity = capacity, NextPointCost = Runtime.NextPointCost(module, normalized, id),]], "catalog path quote")
	upgradeSource = replaceOnce(upgradeSource,
		[[local preview = { Cost = Runtime.NextPointCost(module, normalized), Allocation = nextAllocation, RawDelta = rawDelta }]],
		[[local preview = { Cost = Runtime.NextPointCost(module, normalized, pathId), Allocation = nextAllocation, RawDelta = rawDelta }]], "purchase preview path quote")
end
compile("VehiclePerformanceV2UpgradeRuntime", upgradeSource)

local resolverSource = resolver.Source
if not string.find(resolverSource, REVISION, 1, true) then
	resolverSource = replaceOnce(resolverSource,
		[[function Resolver.UpgradePreview(root,profile,slotId,module,instance,pathId) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1]],
		[[function Resolver.UpgradeCost(root,module,instance,pathId) -- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1
	local template=Resolver.FindModule(root,module); if not template then return nil end
	return V2Upgrades.NextPointCost(template,instance and instance.V2UpgradePoints or {},pathId)
end
function Resolver.UpgradePreview(root,profile,slotId,module,instance,pathId) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1]], "resolver authoritative price bridge")
end
compile("VehiclePerformanceResolver", resolverSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[==[			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price))); local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1] -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1]==],
		[==[			local pointCost=PerformanceResolver.UpgradeCost(categoriesRoot,{ModuleId=moduleId},instance,u.UpgradeId); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price))); local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1] -- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1]==], "UI authoritative path quote")
end
compile("ModuleShopUIController", applicationSource)

local function sourceHas(object, marker)
	return string.find(object.Source, marker, 1, true) ~= nil
end

local function audit()
	local pass, fail = 0, 0
	local function check(condition, message)
		if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end
	end
	check(sourceHas(upgrades, REVISION), "shared V2 runtime owns path-local prices")
	check(sourceHas(resolver, REVISION), "resolver exposes the shared authoritative quote")
	check(sourceHas(application, REVISION), "upgrade cards display the shared authoritative quote")
	check(string.find(upgrades.Source, "NextPointCost(module, normalized, pathId)", 1, true) ~= nil, "server purchase preview passes the selected path")
	check(string.find(upgrades.Source, "NextPointCost(module, normalized, id)", 1, true) ~= nil, "catalog passes each individual path")
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d", PREFIX, pass, fail))
	assert(fail == 0, "Post-install audit failed")
end

if MODE == "AUDIT" then audit(); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local alreadyInstalled = sourceHas(upgrades, REVISION) and sourceHas(resolver, REVISION) and sourceHas(application, REVISION)
if alreadyInstalled then audit(); print(PREFIX .. " already installed; no changes made"); return end

local oldSources = {[upgrades]=upgrades.Source, [resolver]=resolver.Source, [application]=application.Source}
local function rollback(reason)
	for object, source in pairs(oldSources) do pcall(function() object.Source = source end) end
	error(PREFIX .. " rolled back: " .. tostring(reason), 0)
end

local ok, err = pcall(function()
	upgrades.Source = upgradeSource
	resolver.Source = resolverSource
	application.Source = applicationSource
	audit()
end)
if not ok then rollback(err) end
print(PREFIX .. " INSTALL COMPLETE - Restart Play and verify upgrading one path changes only that path's next price while the module point budget remains shared.")
