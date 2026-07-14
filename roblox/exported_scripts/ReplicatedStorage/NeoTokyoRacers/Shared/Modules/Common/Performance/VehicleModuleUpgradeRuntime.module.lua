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
