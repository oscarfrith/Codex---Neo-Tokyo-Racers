-- Neo Tokyo Racers - Vehicle Performance V2 Phase 8 atomic live launch
-- Run in Roblox Studio Command Bar in Edit mode after confirmed Phase 7.
--
-- MODE = "PUBLISH" performs the one live catalogue/runtime boundary.
-- MODE = "ROLLBACK_SWITCHES" disables V2 ownership without deleting data/assets.
-- Full asset rollback uses Roblox version history; this script creates no backups.

local MODE = "PUBLISH"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Stop Play before running Vehicle Performance V2 Phase 8")
assert(MODE == "PUBLISH" or MODE == "ROLLBACK_SWITCHES", "MODE must be PUBLISH or ROLLBACK_SWITCHES")

local PREFIX = "[NTR Vehicle Performance V2 Phase 8]"
local passCount, warnCount, failCount = 0, 0, 0
local function pass(message) passCount += 1; print(PREFIX .. " PASS - " .. message) end
local function warnCheck(message) warnCount += 1; warn(PREFIX .. " WARN - " .. message) end
local function fail(message) failCount += 1; warn(PREFIX .. " FAIL - " .. message) end
local function count(dictionary) local n = 0; for _ in pairs(dictionary or {}) do n += 1 end; return n end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local config = shared:WaitForChild("Config"):WaitForChild("VehiclePerformanceV2_EditAttributes")
local performance = shared:WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local categories = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local integration = config:WaitForChild("Integration")

local function setLiveSwitches(enabled)
	config:SetAttribute("ShadowOnly", not enabled)
	config:SetAttribute("ShadowComparisonEnabled", not enabled)
	config:SetAttribute("RuntimeRatingEnabled", enabled)
	config:SetAttribute("RuntimePhysicsEnabled", enabled)
	config:SetAttribute("RuntimeUpgradePurchasesEnabled", enabled)
	config:SetAttribute("RuntimeProfileMigrationEnabled", enabled)
	config:SetAttribute("LiveCataloguePublishEnabled", enabled)
	integration:SetAttribute("LiveRatingOwner", enabled and "VehiclePerformanceV2Runtime" or "V1")
	integration:SetAttribute("LivePhysicsOwner", enabled and "VehiclePerformanceV2RawRuntime" or "VehicleDynamicsModel_V1Compatible")
	integration:SetAttribute("LiveUpgradeOwner", enabled and "VehiclePerformanceV2UpgradeRuntime" or "VehicleModuleUpgradeRuntime_V1")
end

if MODE == "ROLLBACK_SWITCHES" then
	setLiveSwitches(false)
	config:SetAttribute("IntegrationNote", "Phase 8 switch rollback active. Published catalogue and preserved V2/legacy profile data remain intact.")
	config:SetAttribute("SchemaVersion", "V2_PHASE8_SWITCH_ROLLBACK")
	pass("Disabled all live V2 owners while preserving published assets and profile data")
	print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d", PREFIX, passCount, warnCount, failCount))
	print(PREFIX .. " ROLLBACK COMPLETE - Restart Play. V1 rating, physics compatibility, and legacy upgrade paths are authoritative again.")
	return
end

-- Phase 7/staging hard preflight. Nothing mutates before all source and asset
-- contracts below pass.
local schemaVersion = tostring(config:GetAttribute("SchemaVersion") or "")
assert(schemaVersion == "V2_PHASE7_INTEGRATED_SHADOW" or schemaVersion == "V2_PHASE8_ATOMIC_LIVE" or schemaVersion == "V2_PHASE8_SWITCH_ROLLBACK",
	"Confirmed Phase 7/8 config is missing")
local switchValues = {
	config:GetAttribute("RuntimeRatingEnabled"), config:GetAttribute("RuntimePhysicsEnabled"),
	config:GetAttribute("RuntimeUpgradePurchasesEnabled"), config:GetAttribute("RuntimeProfileMigrationEnabled"),
	config:GetAttribute("LiveCataloguePublishEnabled"),
}
local enabledCount = 0
for _, value in ipairs(switchValues) do if value == true then enabledCount += 1 else assert(value == false, "Every live V2 switch must be boolean") end end
assert(enabledCount == 0 or enabledCount == #switchValues, "Phase 8 found a mixed live-switch state; use ROLLBACK_SWITCHES before republishing")

local definitionsV2 = performance:WaitForChild("VehiclePerformanceV2Definitions")
local calculatorV2 = performance:WaitForChild("VehiclePerformanceV2Calculator")
local runtimeV2Module = performance:WaitForChild("VehiclePerformanceV2Runtime")
local upgradeV2Module = performance:WaitForChild("VehiclePerformanceV2UpgradeRuntime")
local dynamicsV2Module = performance:WaitForChild("VehiclePerformanceV2DynamicsAdapter")
assert(string.find(runtimeV2Module.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE7_RUNTIME", 1, true), "Phase 7 V2 runtime marker missing")
assert(string.find(upgradeV2Module.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE7_UPGRADE_RUNTIME", 1, true), "Phase 7 V2 upgrade marker missing")
assert(string.find(dynamicsV2Module.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE7_DYNAMICS_ADAPTER", 1, true), "Phase 7 dynamics marker missing")
pass("Confirmed all Phase 7 isolated owners and disabled live switches")

local staging = ServerStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("VehiclePerformanceV2_Staging")
assert(staging:GetAttribute("GeneratedBy") == "NTR_VEHICLE_PERFORMANCE_V2_PHASE6", "Phase 6 staging ownership marker is missing")
assert(staging:GetAttribute("V2IntegrationReady") == true, "Phase 7 staging integration marker is missing")
local stagedCategory = staging:GetChildren()[1]
assert(stagedCategory and stagedCategory:IsA("Folder"), "Staged category is missing")
local stagedCockpitRoot = stagedCategory:WaitForChild("COCKPITS_ReplaceAssetsHere")
local stagedModuleRoot = stagedCategory:WaitForChild("MODULES_InterchangeableWithinCategory")
local stagedCockpits, stagedModules = {}, {}
for _, item in ipairs(stagedCockpitRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("CockpitId") then stagedCockpits[tostring(item:GetAttribute("CockpitId"))] = item end
end
for _, item in ipairs(stagedModuleRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("ModuleId") then stagedModules[tostring(item:GetAttribute("ModuleId"))] = item end
end
assert(count(stagedCockpits) == 6, "Phase 8 requires six staged cockpits")
assert(count(stagedModules) == 72, "Phase 8 requires 72 staged modules")
for _, item in pairs(stagedCockpits) do assert(item:GetAttribute("V2IntegrationReady") == true, item.Name .. " is not integration-ready") end
for _, item in pairs(stagedModules) do assert(item:GetAttribute("V2IntegrationReady") == true, item.Name .. " is not integration-ready") end
pass("Preflighted six staged cockpits and 72 staged modules")

local liveCategory = categories:FindFirstChild(stagedCategory.Name)
assert(liveCategory, "Live category " .. stagedCategory.Name .. " is missing")
local liveCockpitRoot = liveCategory:FindFirstChild("COCKPITS_ReplaceAssetsHere") or liveCategory:FindFirstChild("Cockpits") or liveCategory:FindFirstChild("COCKPITS")
local liveModuleRoot = liveCategory:FindFirstChild("MODULES_InterchangeableWithinCategory")
assert(liveCockpitRoot and liveModuleRoot, "Live cockpit/module roots are incomplete")

local function findAllByAttribute(root, attributeName, expected)
	local result = {}
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and tostring(item:GetAttribute(attributeName) or "") == tostring(expected) then table.insert(result, item) end
	end
	return result
end

for cockpitId in pairs(stagedCockpits) do
	assert(#findAllByAttribute(liveCockpitRoot, "CockpitId", cockpitId) <= 1, "Duplicate live cockpit id " .. cockpitId)
end
for moduleId in pairs(stagedModules) do
	assert(#findAllByAttribute(liveModuleRoot, "ModuleId", moduleId) <= 1, "Duplicate live module id " .. moduleId)
end
pass("Live catalogue has no conflicting duplicate V2 identities")

local garageController = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local oldCatalogCall = "Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType),"
local newCatalogCall = "Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType, item), -- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_MODULE_CATALOG"
local source = garageController.Source
local oldStart = string.find(source, oldCatalogCall, 1, true)
local newStart = string.find(source, newCatalogCall, 1, true)
assert((oldStart and not newStart) or (newStart and not oldStart), "Garage module-catalog anchor is missing or ambiguous; refresh the live mirror before another patch")
if oldStart then assert(not string.find(source, oldCatalogCall, oldStart + 1, true), "Garage module-catalog anchor is not unique") end
pass("Preflighted the single guarded garage catalogue source anchor")

local calculatorSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_CALCULATOR
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local V2 = require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local Calculator = {}
local function number(value, fallback) return typeof(value) == "number" and value or fallback end
local function enabled()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = kit and kit:FindFirstChild("Shared")
	local config = shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes")
	return config and config:GetAttribute("RuntimeRatingEnabled") == true
end
local function read(source, name, fallback)
	if typeof(source) == "Instance" then return number(source:GetAttribute(name), fallback) end
	if typeof(source) == "table" then return number(source[name], fallback) end
	return fallback
end
function Calculator.FromLegacyStats(source)
	local compatibility = Definitions.GetCompatibilityDefaults()
	local handling, drift = read(source, "Handling", 48), read(source, "Drift", 46)
	local boost = read(source, "BoostForce", read(source, "Boost", 0))
	return { TopSpeed=read(source,"TopSpeed",read(source,"MaxSpeed",126)), EngineOutput=read(source,"EngineOutput",read(source,"Acceleration",42)), Weight=read(source,"Weight",118), LateralGrip=read(source,"LateralGrip",handling), SteeringResponse=read(source,"SteeringResponse",handling), HoverStability=read(source,"HoverStability",handling), DriftControl=read(source,"DriftControl",drift), DriftGrip=read(source,"DriftGrip",drift), DriftChargeRate=read(source,"DriftChargeRate",drift), BrakingForce=read(source,"BrakingForce",read(source,"Braking",44)), BoostForce=boost, BoostDuration=read(source,"BoostDuration",compatibility.DefaultBoostDuration), BoostRecharge=read(source,"BoostRecharge",compatibility.DefaultBoostRecharge), BoostRechargeDelay=read(source,"BoostRechargeDelay",compatibility.DefaultBoostRechargeDelay), BoostEfficiency=read(source,"BoostEfficiency",compatibility.NeutralBoostEfficiency), Drag=read(source,"Drag",compatibility.NeutralDrag), Downforce=read(source,"Downforce",compatibility.NeutralDownforce) }
end
function Calculator.CloneRaw(raw) if enabled() then return V2.CloneRaw(raw) end; local result={}; for _,name in ipairs(Definitions.RawVariableOrder) do result[name]=number(raw and raw[name],0) end; return result end
function Calculator.AddRaw(target,delta,multiplier) if enabled() then return V2.AddRaw(target,delta,multiplier) end; target=target or {}; multiplier=number(multiplier,1); for _,name in ipairs(Definitions.RawVariableOrder) do target[name]=number(target[name],0)+number(delta and delta[name],0)*multiplier end; return target end
function Calculator.NormalizeVariable(variableName,rawValue) local d=Definitions.GetNormalization(variableName); local minimum,maximum=number(d.Min,0),number(d.Max,100); local score=math.clamp((number(rawValue,minimum)-minimum)/math.max(maximum-minimum,0.0001)*100,0,100); return d.LowerIsBetter==true and 100-score or score end
function Calculator.NormalizeRaw(raw) local r={}; for _,name in ipairs(Definitions.RawVariableOrder) do r[name]=Calculator.NormalizeVariable(name,raw[name]) end; return r end
local function average(values,weights) local total,weightTotal=0,0; for key,weight in pairs(weights or {}) do if typeof(weight)=="number" and typeof(values[key])=="number" then total+=values[key]*weight; weightTotal+=weight end end; return weightTotal>0 and total/weightTotal or 0 end
function Calculator.CalculateHeadline(normalized) local r={}; for _,name in ipairs(Definitions.HeadlineOrder) do r[name]=average(normalized,Definitions.GetHeadlineWeights(name)) end; return r end
function Calculator.TierForIndex(index) if enabled() then return V2.TierForIndex(index) end; local b=Definitions.GetTierBands(); for _,item in ipairs({{"S",number(b.S,850)},{"A",number(b.A,725)},{"B",number(b.B,600)},{"C",number(b.C,450)},{"D",number(b.D,300)},{"E",number(b.E,100)}}) do if index>=item[2] then return item[1] end end; return "E" end
function Calculator.CalculateOverall(headline) if enabled() then return V2.CalculateOverall(headline) end; local s=Definitions.GetOverallSettings(); local base=average(headline,s); local values={}; for _,name in ipairs(Definitions.HeadlineOrder) do table.insert(values,number(headline[name],0)) end; table.sort(values); local balance=(values[1]+values[2]+values[3])/3; local score=math.clamp(base*number(s.BaseContribution,0.85)+balance*number(s.BalanceContribution,0.15),0,100); local minimum,maximum=number(s.PerformanceIndexMin,100),number(s.PerformanceIndexMax,999); local index=math.round(minimum+score/100*(maximum-minimum)); return {Score=score,PerformanceIndex=index,Tier=Calculator.TierForIndex(index),BaseScore=base,BalanceScore=balance} end
function Calculator.Calculate(raw) if enabled() then return V2.Calculate(raw) end; local rawCopy=Calculator.CloneRaw(raw); local normalized=Calculator.NormalizeRaw(rawCopy); local headline=Calculator.CalculateHeadline(normalized); return {Raw=rawCopy,Normalized=normalized,Headline=headline,Overall=Calculator.CalculateOverall(headline)} end
function Calculator.CalculateLegacy(source) return Calculator.Calculate(Calculator.FromLegacyStats(source)) end
return Calculator
]==]

local runtimeSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_RUNTIME
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local Calculator = require(script.Parent:WaitForChild("VehiclePerformanceCalculator"))
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}
local function config() local kit=ReplicatedStorage:FindFirstChild("NeoTokyoRacers"); local shared=kit and kit:FindFirstChild("Shared"); return shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes") end
local function v2Enabled() local c=config(); return c and (c:GetAttribute("RuntimeRatingEnabled")==true or c:GetAttribute("RuntimePhysicsEnabled")==true) end
local function numberAttribute(item,name) local value=item and item:GetAttribute(name); return typeof(value)=="number" and value or nil end
local function installed(root) local r={}; if root then for _,item in ipairs(root:GetChildren()) do if item:IsA("Model") and item:GetAttribute("ModuleId")~=nil then table.insert(r,item) end end end; return r end
function Runtime.CalculateBuild(legacyTotals,cockpit,installedRoot)
	if v2Enabled() and cockpit and cockpit:GetAttribute("V2Materialised")==true then return V2Runtime.CalculateComponents(cockpit,installed(installedRoot)) end
	local raw=Calculator.FromLegacyStats(legacyTotals)
	for _,name in ipairs(Definitions.RawVariableOrder) do local override=numberAttribute(cockpit,"PerformanceOverride_"..name); if override~=nil then raw[name]=override end; local delta=numberAttribute(cockpit,"PerformanceDelta_"..name); if delta~=nil then raw[name]=(raw[name] or 0)+delta end end
	for _,module in ipairs(installed(installedRoot)) do for _,name in ipairs(Definitions.RawVariableOrder) do local delta=numberAttribute(module,"PerformanceDelta_"..name); if delta~=nil then raw[name]=(raw[name] or 0)+delta end end end
	return Calculator.Calculate(raw)
end
local function rewrite(vehicle,name,values) local folder=vehicle:FindFirstChild(name); if folder and not folder:IsA("Folder") then folder:Destroy(); folder=nil end; if not folder then folder=Instance.new("Folder"); folder.Name=name; folder.Parent=vehicle end; folder:ClearAllChildren(); for key,value in pairs(values or {}) do if typeof(value)=="number" then local n=Instance.new("NumberValue"); n.Name=key; n.Value=value; n.Parent=folder end end end
function Runtime.WriteToVehicle(vehicle,result)
	rewrite(vehicle,"RAW_PERFORMANCE_Runtime",result.Raw or {}); rewrite(vehicle,"NORMALIZED_PERFORMANCE_Runtime",result.Normalized or result.EffectiveFactor or {}); rewrite(vehicle,"HEADLINE_STATS_Runtime",result.Headline or {})
	for key,value in pairs(result.Raw or {}) do if typeof(value)=="number" then vehicle:SetAttribute("Performance_"..key,value) end end
	local overall=result.Overall or {}; vehicle:SetAttribute("PerformanceIndex",overall.PerformanceIndex or 100); vehicle:SetAttribute("PerformanceTier",overall.Tier or "E"); vehicle:SetAttribute("PerformanceScore",overall.Score or 0); vehicle:SetAttribute("PerformanceRuntimeVersion",v2Enabled() and "V2_PHASE8_LIVE" or "AM_1")
end
return Runtime
]==]

local upgradeSource = [==[
-- NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_UPGRADE_RUNTIME
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(script.Parent:WaitForChild("VehiclePerformanceDefinitions"))
local LegacyDefinitions = require(script.Parent:WaitForChild("VehicleUpgradeDefinitions"))
local V2 = require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local V2Runtime = require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local Runtime = {}
local legacyLevels, profiles = {}, {}
local function config() local kit=ReplicatedStorage:FindFirstChild("NeoTokyoRacers"); local shared=kit and kit:FindFirstChild("Shared"); return shared and shared:FindFirstChild("Config") and shared.Config:FindFirstChild("VehiclePerformanceV2_EditAttributes") end
local function enabled(name) local c=config(); return c and c:GetAttribute(name)==true end
local function playerLevels(player) legacyLevels[player.UserId]=legacyLevels[player.UserId] or {}; return legacyLevels[player.UserId] end
local function currentVehicle(profile) local id=profile and profile.CurrentVehicleId; return id and profile.Vehicles and profile.Vehicles[tostring(id)], id and tostring(id) end
local function currentInstance(profile,slotId,moduleId)
	local vehicle,vehicleId=currentVehicle(profile); local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]; local instance=instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]
	if typeof(instance)=="table" and tostring(instance.TemplateId or "")==tostring(moduleId or "") then return tostring(instanceId),instance end
	for id,candidate in pairs(profile.OwnedModuleInstances or {}) do if typeof(candidate)=="table" and tostring(candidate.TemplateId or "")==tostring(moduleId or "") and tostring(candidate.EquippedVehicleId or "")==tostring(vehicleId or "") then return tostring(id),candidate end end
	return nil,nil
end
local function applyMigration(profile,findModule)
	if not enabled("RuntimeProfileMigrationEnabled") or typeof(profile)~="table" then return end
	profile.OwnedModuleInstances=typeof(profile.OwnedModuleInstances)=="table" and profile.OwnedModuleInstances or {}
	local migration=typeof(profile.VehiclePerformanceV2Migration)=="table" and profile.VehiclePerformanceV2Migration or {}
	if migration.Version=="V2_PHASE8_LIVE" and migration.RefundApplied==true then return end
	local refund,converted,missing=0,0,0
	for _,instance in pairs(profile.OwnedModuleInstances) do
		if typeof(instance)=="table" then local module=findModule(profile.CurrentCategory,tostring(instance.TemplateId or "")); if module then local migrated,report=V2.MigrateModuleInstance(instance,module); for key,value in pairs(migrated) do instance[key]=value end; refund+=tonumber(report.RefundCredit) or 0; converted+=tonumber(report.ConvertedPoints) or 0 else missing+=1 end end
	end
	profile.Cash=(tonumber(profile.Cash) or 0)+refund
	profile.VehiclePerformanceV2Migration={Version="V2_PHASE8_LIVE",RefundApplied=true,RefundCredit=refund,ConvertedPoints=converted,MissingTemplates=missing,MigratedAtUnix=os.time()}
end
function Runtime.GetLevels(player)
	if not enabled("RuntimeUpgradePurchasesEnabled") then return playerLevels(player) end
	local profile=profiles[player.UserId]; local result={}; if not profile then return result end
	local vehicle=currentVehicle(profile)
	for slotId,moduleId in pairs(profile.InstalledModules or {}) do local _,instance=currentInstance(profile,slotId,moduleId); if instance then result[tostring(moduleId)]=instance.V2UpgradePoints or {} end end
	return result
end
function Runtime.GetModuleLevels(player,moduleId) local all=Runtime.GetLevels(player); all[moduleId]=typeof(all[moduleId])=="table" and all[moduleId] or {}; return all[moduleId] end
function Runtime.CatalogForModuleType(moduleType,module)
	if not enabled("RuntimeUpgradePurchasesEnabled") or not module or module:GetAttribute("V2Materialised")~=true then local result={}; for _,d in ipairs(LegacyDefinitions.GetForModuleType(moduleType)) do table.insert(result,{UpgradeId=d.UpgradeId,DisplayName=d.DisplayName,MaxLevel=d.MaxLevel,BasePrice=d.BasePrice,PriceMultiplier=d.PriceMultiplier,EffectsPerLevel=d.EffectsPerLevel}) end; return result end
	local result={}; local base=V2.ApplyToModuleRaw(module,{}); for _,path in ipairs(V2.Catalog(module,{})) do local one={}; one[path.PathId]=1; local after=V2.ApplyToModuleRaw(module,one); local effects={}; for _,name in ipairs(Definitions.RawVariableOrder) do effects[name]=(after[name] or 0)-(base[name] or 0) end; table.insert(result,{UpgradeId=path.PathId,DisplayName=path.DisplayName,MaxLevel=path.MaxPoints,BasePrice=tonumber(module:GetAttribute("Point1CostGuide")) or 0,PriceMultiplier=1,EffectsPerLevel=effects,V2TotalCapacity=path.Capacity}) end; return result
end
function Runtime.Purchase(player,profile,slotId,moduleId,upgradeId,findModule,moduleTypeForModel)
	profiles[player.UserId]=profile
	if enabled("RuntimeUpgradePurchasesEnabled") then applyMigration(profile,findModule); local installedId=profile.InstalledModules and profile.InstalledModules[slotId]; moduleId=moduleId~="" and moduleId or installedId; if installedId~=moduleId then return false,"Install that module before upgrading it." end; local module=moduleId and findModule(profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end; local instanceId=currentInstance(profile,slotId,moduleId); if not instanceId then return false,"Installed module instance not found." end; local ok,preview=V2.PurchasePoint(profile,instanceId,module,upgradeId,{}); if not ok then return false,preview end; return true,(tostring(upgradeId).." upgraded for $"..tostring(preview.Cost)..".") end
	local installedId=profile.InstalledModules and profile.InstalledModules[slotId]; moduleId=moduleId~="" and moduleId or installedId; local module=moduleId and findModule(profile.CurrentCategory,moduleId); local moduleType=module and moduleTypeForModel(module); local definition=moduleType and LegacyDefinitions.Find(moduleType,upgradeId); if not module then return false,"Module not found." end; if not(profile.OwnedModules and profile.OwnedModules[moduleId]) then return false,"You do not own that module." end; if installedId~=moduleId then return false,"Install that module before upgrading it." end; if not definition then return false,"That upgrade is not available for this module." end; local levels=Runtime.GetModuleLevels(player,moduleId); local level=math.clamp(math.floor(tonumber(levels[upgradeId]) or 0),0,definition.MaxLevel or 3); if level>=(definition.MaxLevel or 3) then return false,"Already max level." end; local price=LegacyDefinitions.PriceForLevel(definition,level+1) or 0; if profile.Cash<price then return false,"Not enough cash." end; profile.Cash-=price; levels[upgradeId]=level+1; return true,definition.DisplayName.." upgraded to level "..tostring(level+1).."."
end
function Runtime.ApplyToClone(player,moduleTemplate,moduleClone,moduleTypeForModel)
	if enabled("RuntimeUpgradePurchasesEnabled") and moduleTemplate:GetAttribute("V2Materialised")==true then local profile=profiles[player.UserId]; local slotId=tostring(moduleClone:GetAttribute("InstalledSlotId") or ""); local moduleId=tostring(moduleTemplate:GetAttribute("ModuleId") or moduleTemplate.Name); local _,instance=profile and currentInstance(profile,slotId,moduleId); local raw=V2.ApplyToModuleRaw(moduleTemplate,instance and instance.V2UpgradePoints or {}); for name,value in pairs(raw) do moduleClone:SetAttribute(name,value) end; moduleClone:SetAttribute("V2UpgradePointsApplied",instance and "PROFILE" or "NONE"); return end
	local moduleId=tostring(moduleTemplate:GetAttribute("ModuleId") or moduleTemplate.Name); local moduleType=moduleTypeForModel(moduleTemplate); local levels=Runtime.GetModuleLevels(player,moduleId); for _,definition in ipairs(LegacyDefinitions.GetForModuleType(moduleType)) do local level=math.clamp(math.floor(tonumber(levels[definition.UpgradeId]) or 0),0,definition.MaxLevel or 3); moduleClone:SetAttribute("AppliedUpgrade_"..definition.UpgradeId,level); for name,amount in pairs(definition.EffectsPerLevel or {}) do if level>0 and typeof(amount)=="number" and table.find(Definitions.RawVariableOrder,name) then local attr="PerformanceDelta_"..name; local base=moduleClone:GetAttribute(attr); moduleClone:SetAttribute(attr,(typeof(base)=="number" and base or 0)+amount*level) end end end
end
function Runtime.CalculateProfile(player,profile,legacyTotals,cockpit,findModule,moduleTypeForModel)
	profiles[player.UserId]=profile
	if enabled("RuntimeRatingEnabled") and cockpit and cockpit:GetAttribute("V2Materialised")==true then applyMigration(profile,findModule); local modules,allocations={},{}; for slotId,moduleId in pairs(profile.InstalledModules or {}) do local module=findModule(profile.CurrentCategory,moduleId); if module then table.insert(modules,module); local _,instance=currentInstance(profile,slotId,moduleId); allocations[tostring(module:GetAttribute("ModuleId") or module.Name)]=instance and instance.V2UpgradePoints or {} end end; return V2Runtime.CalculateComponents(cockpit,modules,allocations) end
	local performanceRuntime=require(script.Parent:WaitForChild("VehiclePerformanceRuntime")); local root=Instance.new("Folder"); for slotId,moduleId in pairs(profile.InstalledModules or {}) do local template=findModule(profile.CurrentCategory,moduleId); if template then local clone=template:Clone(); clone:SetAttribute("InstalledSlotId",slotId); Runtime.ApplyToClone(player,template,clone,moduleTypeForModel); clone.Parent=root end end; local result=performanceRuntime.CalculateBuild(legacyTotals,cockpit,root); root:Destroy(); return result
end
return Runtime
]==]

-- Compile the three canonical isolated replacements against fresh dependency
-- clones before changing any live source or catalogue object.
local temp = Instance.new("Folder")
temp.Name = "VehiclePerformanceV2_Phase8PreflightTemp"
temp.Parent = performance
for _, dependency in ipairs({ performance.VehiclePerformanceDefinitions, performance.VehicleUpgradeDefinitions, definitionsV2, calculatorV2, runtimeV2Module, upgradeV2Module, dynamicsV2Module }) do dependency:Clone().Parent = temp end
local tempCalculator = Instance.new("ModuleScript"); tempCalculator.Name = "VehiclePerformanceCalculator"; tempCalculator.Source = calculatorSource; tempCalculator.Parent = temp
local tempRuntime = Instance.new("ModuleScript"); tempRuntime.Name = "VehiclePerformanceRuntime"; tempRuntime.Source = runtimeSource; tempRuntime.Parent = temp
local tempUpgrade = Instance.new("ModuleScript"); tempUpgrade.Name = "VehicleModuleUpgradeRuntime"; tempUpgrade.Source = upgradeSource; tempUpgrade.Parent = temp
local okCalculator, calculatorResult = pcall(require, tempCalculator)
local okRuntime, runtimeResult = pcall(require, tempRuntime)
local okUpgrade, upgradeResult = pcall(require, tempUpgrade)
temp:Destroy()
assert(okCalculator, "Phase 8 compatibility calculator failed to load: " .. tostring(calculatorResult))
assert(okRuntime, "Phase 8 compatibility runtime failed to load: " .. tostring(runtimeResult))
assert(okUpgrade, "Phase 8 compatibility upgrade runtime failed to load: " .. tostring(upgradeResult))
pass("Preflight-loaded all three canonical switch-aware module replacements")

-- Prepare every catalogue clone while still outside the discoverable live root.
local prepared = Instance.new("Folder")
prepared.Name = "VehiclePerformanceV2_Phase8Prepared"
local stalePrepared = staging:FindFirstChild(prepared.Name)
if stalePrepared then
	assert(stalePrepared:IsA("Folder"), stalePrepared:GetFullName() .. " must be a Folder")
	stalePrepared:Destroy()
end
prepared.Parent = staging
for cockpitId, item in pairs(stagedCockpits) do local clone=item:Clone(); clone.Name=item.Name; clone:SetAttribute("CatalogPublishReady",true); clone:SetAttribute("V2Published",true); clone:SetAttribute("V2PublishedCockpitId",cockpitId); clone.Parent=prepared end
for moduleId, item in pairs(stagedModules) do local clone=item:Clone(); clone.Name=item.Name; clone:SetAttribute("CatalogPublishReady",true); clone:SetAttribute("V2Published",true); clone:SetAttribute("RetiredFromCatalog",false); clone:SetAttribute("HiddenFromCatalog",false); clone:SetAttribute("CatalogVisible",true); clone:SetAttribute("V2PublishedModuleId",moduleId); clone.Parent=prepared end
assert(#prepared:GetChildren()==78, "Prepared publication clone count is not 78")
pass("Prepared all 78 publication clones outside live discovery")

-- Canonical isolated source replacements and the one guarded catalogue call.
performance.VehiclePerformanceCalculator.Source = calculatorSource
performance.VehiclePerformanceRuntime.Source = runtimeSource
performance.VehicleModuleUpgradeRuntime.Source = upgradeSource
if oldStart then garageController.Source = string.sub(source,1,oldStart-1)..newCatalogCall..string.sub(source,oldStart+#oldCatalogCall) end
pass("Installed switch-aware rating, physics-data, upgrade, migration, and catalogue owners")

local function ensureFolder(parent,name) local item=parent:FindFirstChild(name); if item then assert(item:IsA("Folder"),item:GetFullName().." must be a Folder"); return item end; item=Instance.new("Folder"); item.Name=name; item.Parent=parent; return item end
for cockpitId, staged in pairs(stagedCockpits) do
	for _, existing in ipairs(findAllByAttribute(liveCockpitRoot,"CockpitId",cockpitId)) do existing:Destroy() end
	local clone=prepared:FindFirstChild(staged.Name); assert(clone,"Missing prepared cockpit "..cockpitId); clone.Parent=liveCockpitRoot
end
for moduleId, staged in pairs(stagedModules) do
	for _, existing in ipairs(findAllByAttribute(liveModuleRoot,"ModuleId",moduleId)) do existing:Destroy() end
	local folderName=tostring(staged:GetAttribute("ModuleFolder") or staged.Parent.Parent.Name); local familyName=staged.Parent.Name
	local family=ensureFolder(ensureFolder(liveModuleRoot,folderName),familyName)
	local clone=prepared:FindFirstChild(staged.Name); assert(clone,"Missing prepared module "..moduleId); clone.Parent=family
end
prepared:Destroy()
pass("Published six cockpits and 72 core modules without touching cosmetic module families")

local liveCockpits, liveModules = {}, {}
for cockpitId in pairs(stagedCockpits) do local matches=findAllByAttribute(liveCockpitRoot,"CockpitId",cockpitId); if #matches==1 and matches[1]:GetAttribute("V2Published")==true then liveCockpits[cockpitId]=matches[1] else fail("Published cockpit validation failed for "..cockpitId) end end
for moduleId in pairs(stagedModules) do local matches=findAllByAttribute(liveModuleRoot,"ModuleId",moduleId); if #matches==1 and matches[1]:GetAttribute("V2Published")==true and matches[1]:GetAttribute("RetiredFromCatalog")~=true then liveModules[moduleId]=matches[1] else fail("Published module validation failed for "..moduleId) end end
if count(liveCockpits)==6 and count(liveModules)==72 then pass("Live catalogue contains exactly one visible copy of every V2 core identity") end

local RuntimeV2 = require(runtimeV2Module)
local profileOrder={"bruiser_02","bruiser_03","bruiser_01","bruiser_04","bruiser_05","bruiser_06"}
local expectedTier={bruiser_02="E",bruiser_03="D",bruiser_01="C",bruiser_04="B",bruiser_05="A",bruiser_06="S"}
local buildsOk=true
for _,cockpitId in ipairs(profileOrder) do local short=string.match(cockpitId,"(%d+)$"); local result=RuntimeV2.CalculateComponents(liveCockpits[cockpitId],{liveModules["MODULE_ENGINE_BRUISER_"..short.."_STANDARD"],liveModules["MODULE_ENGINE_B_BRUISER_"..short.."_STANDARD"],liveModules["MODULE_STABILISER_BRUISER_"..short.."_STANDARD"],liveModules["MODULE_BOOST_BRUISER_"..short.."_STANDARD"]}); print(string.format("%s LIVE STOCK | %s | %s %.2f",PREFIX,cockpitId,result.Overall.Tier,result.Overall.InternalPerformanceIndex)); if result.Overall.Tier~=expectedTier[cockpitId] then buildsOk=false; fail(cockpitId.." live stock tier mismatch") end end
if buildsOk then pass("Published catalogue reproduces all six E-S stock builds") end

if failCount==0 then
	setLiveSwitches(true)
	config:SetAttribute("SchemaVersion","V2_PHASE8_ATOMIC_LIVE")
	config:SetAttribute("SourceSheetRevision","NTR-BAL-009-P8")
	config:SetAttribute("IntegrationNote","Phase 8 live release candidate. V2 rating/raw physics/upgrades/profile migration/catalogue are authoritative; legacy data remains preserved for switch rollback.")
	staging:SetAttribute("CatalogPublishReady",true)
	staging:SetAttribute("PublishedToLive",true)
	staging:SetAttribute("PublishedSchemaVersion","V2_PHASE8_ATOMIC_LIVE")
	pass("Enabled all five V2 live switches only after publication validation")
else
	setLiveSwitches(false)
	warnCheck("Publication validation failed; all V2 switches remain disabled")
end

local allEnabled=config:GetAttribute("RuntimeRatingEnabled")==true and config:GetAttribute("RuntimePhysicsEnabled")==true and config:GetAttribute("RuntimeUpgradePurchasesEnabled")==true and config:GetAttribute("RuntimeProfileMigrationEnabled")==true and config:GetAttribute("LiveCataloguePublishEnabled")==true
if failCount==0 and allEnabled then pass("Atomic live ownership gate is fully enabled") elseif failCount==0 then fail("Atomic live ownership gate is incomplete") end

print(string.format("%s SUMMARY - PASS=%d WARN=%d FAIL=%d",PREFIX,passCount,warnCount,failCount))
if failCount==0 then
	print(PREFIX.." LIVE RELEASE CANDIDATE INSTALLED - Restart Play so ModuleScript caches are fresh.")
	print(PREFIX.." VERIFY - Dealership E-S catalogue, purchase/select, cross-tier module equip, six-point upgrade, spawn, driving, race tier, and save/rejoin.")
	print(PREFIX.." ROLLBACK - Set MODE to ROLLBACK_SWITCHES and rerun this same script. Use Roblox version history only if the published asset catalogue itself must be reverted.")
else
	warn(PREFIX.." BLOCKED - Do not Play-test as V2. Copy the complete Output into chat; the script left V2 switches disabled.")
end
