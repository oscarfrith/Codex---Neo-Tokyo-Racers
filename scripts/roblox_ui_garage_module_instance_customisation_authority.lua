-- Neo Tokyo Racers - Physical module-instance customisation authority
-- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_AUTHORITY_V1
-- Run once in EDIT mode. This phase does not change card layout or reassignment policy.

local MODE = "INSTALL" -- INSTALL or AUDIT
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

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

local serverRoot = need(ServerScriptService, "NeoTokyoRacers", "Folder")
local garage = need(need(serverRoot, "Services", "Folder"), "Garage", "Folder")
local controller = need(garage, "GarageActionController_Shadow_Disabled", "Script")

local runtimeSource = [==[
-- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_RUNTIME_V1
local Runtime={}

local function clone(value)
	if typeof(value)~="table" then return value end
	local result={}; for key,child in pairs(value) do result[key]=clone(child) end; return result
end

local function currentVehicle(profile)
	local id=tostring(profile and profile.CurrentVehicleId or "")
	return id~="" and profile.Vehicles and profile.Vehicles[id] or nil,id
end

function Runtime.ResolveSlot(profile,slotId)
	local vehicle,vehicleId=currentVehicle(profile); local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]; local instance=instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]
	return vehicle,vehicleId,instanceId and tostring(instanceId) or nil,instance
end

function Runtime.CaptureSlot(profile,slotId,levelsByModule)
	local _,_,_,instance=Runtime.ResolveSlot(profile,slotId); if typeof(instance)~="table" then return false,"Installed module instance not found for "..tostring(slotId) end
	local colors=profile.ModuleColors and profile.ModuleColors[slotId]; if typeof(colors)=="table" then instance.Colors=clone(colors) else instance.Colors=typeof(instance.Colors)=="table" and instance.Colors or {} end
	if profile.NeonOwned and profile.NeonOwned[slotId]~=nil then instance.NeonOwned=profile.NeonOwned[slotId]==true else instance.NeonOwned=instance.NeonOwned==true end
	local templateId=tostring(instance.TemplateId or ""); local levels=typeof(levelsByModule)=="table" and levelsByModule[templateId] or nil; if typeof(levels)=="table" then instance.UpgradeLevels=clone(levels) else instance.UpgradeLevels=typeof(instance.UpgradeLevels)=="table" and instance.UpgradeLevels or {} end
	return true,instance
end

function Runtime.CaptureAll(profile,levelsByModule)
	local vehicle=currentVehicle(profile); if not vehicle then return false,"Current vehicle not found" end
	for slotId in pairs(vehicle.InstalledModules or {}) do local ok,message=Runtime.CaptureSlot(profile,slotId,levelsByModule); if not ok then return false,message end end
	return true
end

function Runtime.HydrateSlot(profile,slotId)
	local _,_,_,instance=Runtime.ResolveSlot(profile,slotId); if typeof(instance)~="table" then return false,"Installed module instance not found for "..tostring(slotId) end
	profile.ModuleColors=typeof(profile.ModuleColors)=="table" and profile.ModuleColors or {}; profile.NeonOwned=typeof(profile.NeonOwned)=="table" and profile.NeonOwned or {}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	instance.Colors=typeof(instance.Colors)=="table" and instance.Colors or {}; instance.UpgradeLevels=typeof(instance.UpgradeLevels)=="table" and instance.UpgradeLevels or {}
	profile.ModuleColors[slotId]=clone(instance.Colors); profile.NeonOwned[slotId]=instance.NeonOwned==true; profile.ModuleUpgradeLevels[tostring(instance.TemplateId or "")]=clone(instance.UpgradeLevels)
	return true
end

function Runtime.HydrateAll(profile)
	local vehicle=currentVehicle(profile); if not vehicle then return false,"Current vehicle not found" end
	profile.ModuleColors={}; profile.NeonOwned={}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	for slotId in pairs(vehicle.InstalledModules or {}) do local ok,message=Runtime.HydrateSlot(profile,slotId); if not ok then return false,message end end
	return true
end

function Runtime.ReconcileReferences(profile)
	local references={}; local repaired=0
	for vehicleId,vehicle in pairs(profile.Vehicles or {}) do
		for slotId,instanceIdValue in pairs((typeof(vehicle)=="table" and vehicle.InstalledModules) or {}) do
			local instanceId=tostring(instanceIdValue); local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[instanceId]
			if typeof(instance)~="table" then return false,"Missing instance "..instanceId.." referenced by "..tostring(vehicleId).."."..tostring(slotId) end
			if references[instanceId] then return false,"Instance "..instanceId.." is referenced by more than one slot" end
			references[instanceId]={VehicleId=tostring(vehicleId),SlotId=tostring(slotId)}
		end
	end
	for instanceIdValue,instance in pairs(profile.OwnedModuleInstances or {}) do
		local instanceId=tostring(instanceIdValue); if typeof(instance)~="table" then return false,"Invalid module instance record "..instanceId end
		local reference=references[instanceId]; local desired=reference and reference.VehicleId or nil
		if tostring(instance.EquippedVehicleId or "")~=tostring(desired or "") then instance.EquippedVehicleId=desired; repaired+=1 end
	end
	return true,repaired
end

function Runtime.Validate(profile)
	local references={}
	for vehicleId,vehicle in pairs(profile.Vehicles or {}) do
		for slotId,instanceIdValue in pairs((typeof(vehicle)=="table" and vehicle.InstalledModules) or {}) do
			local instanceId=tostring(instanceIdValue); local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[instanceId]
			if typeof(instance)~="table" then return false,"Missing instance "..instanceId.." referenced by "..tostring(vehicleId).."."..tostring(slotId) end
			if references[instanceId] then return false,"Instance "..instanceId.." is referenced by more than one slot" end
			references[instanceId]={VehicleId=tostring(vehicleId),SlotId=tostring(slotId)}
			if tostring(instance.EquippedVehicleId or "")~=tostring(vehicleId) then return false,"Instance "..instanceId.." owner does not match its vehicle reference" end
		end
	end
	for instanceIdValue,instance in pairs(profile.OwnedModuleInstances or {}) do
		local instanceId=tostring(instanceIdValue); if typeof(instance)~="table" then return false,"Invalid module instance record "..instanceId end
		local owner=tostring(instance.EquippedVehicleId or ""); local reference=references[instanceId]
		if owner~="" and (not reference or reference.VehicleId~=owner) then return false,"Equipped instance "..instanceId.." has no matching slot reference" end
		if owner=="" and reference then return false,"Available instance "..instanceId.." is still referenced by a vehicle" end
		if typeof(instance.Colors)~="table" or typeof(instance.UpgradeLevels)~="table" or typeof(instance.NeonOwned)~="boolean" then return false,"Instance customisation shape is incomplete for "..instanceId end
	end
	return true
end

return Runtime
]==]
compile("GarageModuleInstanceCustomizationRuntime", runtimeSource)

local source=controller.Source
local requireAnchor=[[local V96_ModuleInventory = require(script.Parent:WaitForChild("GarageModuleInventoryRuntime")) -- NTR_GARAGE_MODULE_INVENTORY_GUARD_V1]]
local runtimeDeclaration=[[local V97_ModuleInstances = require(script.Parent:WaitForChild("GarageModuleInstanceCustomizationRuntime")) -- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1]]
local malformedDeclaration=requireAnchor.."\t"..runtimeDeclaration
local correctDeclaration=requireAnchor.."\n\t"..runtimeDeclaration
if string.find(source,malformedDeclaration,1,true) then
	source=replaceOnce(source,malformedDeclaration,correctDeclaration,"comment-swallowed module instance runtime require")
elseif not string.find(source,"NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1",1,true) then
	source=replaceOnce(source,requireAnchor,correctDeclaration,"module instance runtime require")
else
	assert(string.find(source,correctDeclaration,1,true),"Module instance bridge marker exists but its declaration is not on an executable line")
end
if not string.find(source,"V97_ModuleInstances.CaptureSlot",1,true) then

	local equipAnchor=[==[		if not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then
			return false, "That module does not fit this slot."
		end

		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}]==]
	local equipAfter=[==[		if not V86_moduleFitsSlot(module, slotId, mount and V56_string(mount, "AllowedModuleFolder", "")) then
			return false, "That module does not fit this slot."
		end

		if vehicleId == profile.CurrentVehicleId and typeof(vehicle.InstalledModules)=="table" and vehicle.InstalledModules[slotId] then
			local captured,captureMessage=V97_ModuleInstances.CaptureSlot(profile,slotId,V77_ModuleUpgrades.GetLevels(profile._Player)); if not captured then return false,captureMessage end
		end
		local validBefore,validationBefore=V97_ModuleInstances.Validate(profile); if not validBefore then return false,"Module inventory validation failed before equip: "..tostring(validationBefore) end
		vehicle.InstalledModules = typeof(vehicle.InstalledModules) == "table" and vehicle.InstalledModules or {}]==]
	source=replaceOnce(source,equipAnchor,equipAfter,"equip capture and preflight")

	local equipReturn=[==[		return true, "Module instance equipped."]==]
	local equipReturnAfter=[==[		if vehicleId == profile.CurrentVehicleId then local hydrated,hydrateMessage=V97_ModuleInstances.HydrateSlot(profile,slotId); if not hydrated then return false,hydrateMessage end end
		local validAfter,validationAfter=V97_ModuleInstances.Validate(profile); if not validAfter then error("Module inventory validation failed after equip: "..tostring(validationAfter)) end
		return true, "Module instance equipped."]==]
	source=replaceOnce(source,equipReturn,equipReturnAfter,"equip hydration and postflight")

	local selectReturn=[==[		return true, "Vehicle selected."
	end

	local function V89_selectVehicleInstance]==]
	local selectReturnAfter=[==[		local hydrated,hydrateMessage=V97_ModuleInstances.HydrateAll(profile); if not hydrated then return false,hydrateMessage end
		return true, "Vehicle selected."
	end

	local function V89_selectVehicleInstance]==]
	source=replaceOnce(source,selectReturn,selectReturnAfter,"vehicle selection hydration")

	local colorEnd=[==[					ok, message = true, "Colour updated."
				end
			elseif action == "UpgradeModule" then]==]
	local colorEndAfter=[==[					ok, message = true, "Colour updated."
				end
				if ok then if slotId=="ALL" then ok,message=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) else ok,message=V97_ModuleInstances.CaptureSlot(profile,slotId,V77_ModuleUpgrades.GetLevels(player)) end end
			elseif action == "UpgradeModule" then]==]
	source=replaceOnce(source,colorEnd,colorEndAfter,"colour instance capture")

	local upgradeEnd=[==[				V56_setLeaderstats(player, profile)
			elseif action == "Upgrade" then]==]
	local upgradeEndAfter=[==[				V56_setLeaderstats(player, profile)
				if ok then local captured,captureMessage=V97_ModuleInstances.CaptureSlot(profile,tostring(args.SlotId or ""),V77_ModuleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "Upgrade" then]==]
	source=replaceOnce(source,upgradeEnd,upgradeEndAfter,"upgrade instance capture")

	local neonEnd=[==[					V56_setLeaderstats(player, profile)
				end
			elseif action == "SetThrustColor" then]==]
	local neonEndAfter=[==[					V56_setLeaderstats(player, profile)
				end
				if ok then local captured,captureMessage=V97_ModuleInstances.CaptureSlot(profile,slotId,V77_ModuleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "SetThrustColor" then]==]
	source=replaceOnce(source,neonEnd,neonEndAfter,"neon instance capture")

	local thrustEnd=[==[					ok, message = true, "Thrust colour updated."
				end
			elseif action == "DespawnVehicle" then]==]
	local thrustEndAfter=[==[					ok, message = true, "Thrust colour updated."
				end
				if ok then local captured,captureMessage=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)); if not captured then ok,message=false,captureMessage end end
			elseif action == "DespawnVehicle" then]==]
	source=replaceOnce(source,thrustEnd,thrustEndAfter,"thrust instance capture")

	local persistenceBoundary=[==[			if ok == true then
				-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
			end]==]
	local persistenceBoundaryAfter=[==[			if ok == true then
				local validProfile,validationMessage=V97_ModuleInstances.Validate(profile); if not validProfile then error("Module instance invariant failed before persistence after "..tostring(action)..": "..tostring(validationMessage)) end
				-- NTR_GARAGE_LEGACY_TO_INSTANCE_SYNC_RETIRED_V1
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
			end]==]
	source=replaceOnce(source,persistenceBoundary,persistenceBoundaryAfter,"persistence invariant boundary")
end
if not string.find(source,"NTR_GARAGE_MODULE_REFERENCE_RECONCILE_V1",1,true) then
	local requestInventoryAnchor=[==[			V84_ensureInstanceInventory(profile) -- canonical shape only; no grants or migration
			local ok, message]==]
	local requestInventoryAfter=[==[			V84_ensureInstanceInventory(profile) -- canonical shape only; no grants or migration
			-- NTR_GARAGE_MODULE_REFERENCE_RECONCILE_V1
			local referencesOk,referencesResult=V97_ModuleInstances.ReconcileReferences(profile)
			if not referencesOk then return {Success=false,Message="Module inventory reference repair failed: "..tostring(referencesResult),Profile=V56_profileForClient(profile)} end
			if tonumber(referencesResult) and referencesResult>0 then print("[NTR Module Instance Authority] Reconciled "..tostring(referencesResult).." stale owner flag(s) from canonical vehicle-slot references") end
			local ok, message]==]
	source=replaceOnce(source,requestInventoryAnchor,requestInventoryAfter,"request-time module reference reconciliation")
end
compile("GarageActionController",source)

local existing=garage:FindFirstChild("GarageModuleInstanceCustomizationRuntime")
if existing then assert(existing:IsA("ModuleScript"),"GarageModuleInstanceCustomizationRuntime exists with the wrong class") end

local failures={}
local function expect(ok,message) if not ok then table.insert(failures,message) end end
expect(string.find(source,"NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1",1,true)~=nil,"controller bridge missing")
expect(string.find(source,correctDeclaration,1,true)~=nil,"controller bridge declaration is not executable")
expect(string.find(source,"V97_ModuleInstances.CaptureSlot",1,true)~=nil,"slot capture calls missing")
expect(string.find(source,"V97_ModuleInstances.HydrateAll",1,true)~=nil,"vehicle hydration call missing")
expect(string.find(source,"V97_ModuleInstances.Validate",1,true)~=nil,"reference validation calls missing")
expect(string.find(source,"Module instance invariant failed before persistence",1,true)~=nil,"persistence invariant boundary missing")
expect(string.find(source,"NTR_GARAGE_MODULE_REFERENCE_RECONCILE_V1",1,true)~=nil,"request-time reference reconciliation missing")
expect(string.find(runtimeSource,"function Runtime.ReconcileReferences",1,true)~=nil,"reference reconciliation runtime missing")
if #failures>0 then error("[NTR Module Instance Authority] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Module Instance Authority] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local originalSource=controller.Source
local created=false
local oldRuntimeSource=existing and existing.Source or nil
local ok,err=xpcall(function()
	local runtime=existing
	if not runtime then runtime=Instance.new("ModuleScript"); runtime.Name="GarageModuleInstanceCustomizationRuntime"; runtime.Parent=garage; created=true end
	runtime.Source=runtimeSource
	controller.Source=source
	assert(runtime.Source==runtimeSource and controller.Source==source,"Source readback mismatch")
	print("[NTR Module Instance Authority] INSTALL PASS - physical customisation authority plus canonical reference reconciliation")
	print("Restart Play. Customise one module, swap away/back, then rejoin and verify its colours, neon and upgrades return with that same copy.")
end,debug.traceback)
if not ok then
	pcall(function() controller.Source=originalSource end)
	if created then pcall(function() garage.GarageModuleInstanceCustomizationRuntime:Destroy() end) elseif existing and oldRuntimeSource then pcall(function() existing.Source=oldRuntimeSource end) end
	error("[NTR Module Instance Authority] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
