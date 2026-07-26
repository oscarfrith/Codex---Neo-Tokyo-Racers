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

-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
local function completePhysicalColours(profile,vehicle,instance)
	instance.Colors=typeof(instance.Colors)=="table" and instance.Colors or {}
	local cockpitColors=(typeof(vehicle)=="table" and typeof(vehicle.CockpitColors)=="table" and vehicle.CockpitColors)
		or (typeof(profile.CockpitColors)=="table" and profile.CockpitColors)
		or {}
	local repaired=0
	for _,channel in ipairs({"Primary","Secondary","Detail"}) do
		if typeof(instance.Colors[channel])~="Color3" and typeof(cockpitColors[channel])=="Color3" then
			instance.Colors[channel]=cockpitColors[channel]
			repaired+=1
		end
	end
	if typeof(instance.Colors.Neon)~="Color3" then
		instance.Colors.Neon=typeof(cockpitColors.Neon)=="Color3" and cockpitColors.Neon or Color3.new(1,1,1)
		repaired+=1
	end
	if typeof(instance.Colors.ThrustColor)~="Color3" then
		local thrust=(typeof(vehicle)=="table" and typeof(vehicle.ThrustColor)=="Color3" and vehicle.ThrustColor)
			or (typeof(profile.ThrustColor)=="Color3" and profile.ThrustColor)
			or (typeof(cockpitColors.ThrustColor)=="Color3" and cockpitColors.ThrustColor)
		if typeof(thrust)=="Color3" then instance.Colors.ThrustColor=thrust; repaired+=1 end
	end
	return repaired
end

function Runtime.HydrateSlot(profile,slotId)
	local vehicle,_,_,instance=Runtime.ResolveSlot(profile,slotId); if typeof(instance)~="table" then return false,"Installed module instance not found for "..tostring(slotId) end
	profile.ModuleColors=typeof(profile.ModuleColors)=="table" and profile.ModuleColors or {}; profile.NeonOwned=typeof(profile.NeonOwned)=="table" and profile.NeonOwned or {}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	local repaired=completePhysicalColours(profile,vehicle,instance); instance.UpgradeLevels=typeof(instance.UpgradeLevels)=="table" and instance.UpgradeLevels or {}
	profile.ModuleColors[slotId]=clone(instance.Colors); profile.NeonOwned[slotId]=instance.NeonOwned==true; profile.ModuleUpgradeLevels[tostring(instance.TemplateId or "")]=clone(instance.UpgradeLevels)
	return true,instance,repaired
end

function Runtime.HydrateAll(profile)
	local vehicle=currentVehicle(profile); if not vehicle then return false,"Current vehicle not found" end
	profile.ModuleColors={}; profile.NeonOwned={}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	local repaired=0
	for slotId in pairs(vehicle.InstalledModules or {}) do local ok,message,count=Runtime.HydrateSlot(profile,slotId); if not ok then return false,message end; repaired+=tonumber(count) or 0 end
	return true,"Module instance state hydrated.",repaired
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
