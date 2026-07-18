-- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1
-- Resolves presentation data only. No remote calls, profile writes or ownership changes belong here.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Adapter={}
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local Resolver=require(performance:WaitForChild("VehiclePerformanceResolver")) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1

local function moduleColors(profile,slotId,override)
	profile=profile or {}; local cockpit=profile.CockpitColors or {}; local saved=typeof(override)=="table" and override or (profile.ModuleColors and profile.ModuleColors[slotId]) or {}
	return {Primary=saved.Primary or cockpit.Primary or Color3.fromRGB(18,202,224),Secondary=saved.Secondary or cockpit.Secondary or Color3.fromRGB(252,250,255),Detail=saved.Detail or cockpit.Detail or Color3.fromRGB(38,47,55),Neon=saved.Neon or Color3.fromRGB(255,255,255),ThrustColor=profile.ThrustColor or saved.ThrustColor or Color3.fromRGB(255,255,255)}
end

local function ownedInstance(profile,instanceId)
	if typeof(profile)~="table" or instanceId==nil then return nil end
	local owned=profile.OwnedModuleInstances; if typeof(owned)~="table" then return nil end
	local direct=owned[instanceId] or owned[tostring(instanceId)]; if typeof(direct)=="table" then return direct end
	for id,item in pairs(owned) do if tostring(id)==tostring(instanceId) and typeof(item)=="table" then return item end end
	return nil
end

local function currentVehicle(profile)
	local id=tostring(profile and profile.CurrentVehicleId or "")
	return id~="" and profile.Vehicles and profile.Vehicles[id] or nil
end

function Adapter.FindTemplate(categoriesRoot,moduleId)
	if not categoriesRoot or moduleId==nil then return nil end
	for _,item in ipairs(categoriesRoot:GetDescendants()) do
		if item:IsA("Model") and tostring(item:GetAttribute("ModuleId") or item.Name)==tostring(moduleId) then return item end
	end
	return nil
end

function Adapter.Installed(state,slotId)
	local profile=state and (state.PreviewProfile or state.Profile); if typeof(profile)~="table" then return nil,nil,nil end -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
	local vehicle=currentVehicle(profile); local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]
	local instance=ownedInstance(profile,instanceId)
	local moduleId=instance and instance.TemplateId or (profile.InstalledModules and profile.InstalledModules[slotId])
	return moduleId,instance,instanceId and tostring(instanceId) or nil
end

function Adapter.Selected(state,slotId,moduleId)
	if not state or tostring(state.SelectedSlot or "")~=tostring(slotId or "") then return nil,nil end
	local instanceId=state.SelectedModuleInstanceId; if instanceId==nil then return nil,nil end
	local instance=ownedInstance(state.PreviewProfile or state.Profile,instanceId)
	if typeof(instance)~="table" or tostring(instance.TemplateId or "")~=tostring(moduleId or "") then return nil,nil end
	return instance,tostring(instanceId)
end

function Adapter.Resolve(state,slotId,moduleId)
	local instance,instanceId=Adapter.Selected(state,slotId,moduleId)
	if not instance then
		local installedId,installed,installedInstanceId=Adapter.Installed(state,slotId)
		if tostring(installedId or "")==tostring(moduleId or "") then instance,instanceId=installed,installedInstanceId end
	end
	local profile=state and (state.PreviewProfile or state.Profile) or {}
	local colors
	if instance and typeof(instance.Colors)=="table" then
		colors=moduleColors(profile,slotId,instance.Colors)
	else
		colors=moduleColors(profile,slotId)
	end
	local neon=instance and instance.NeonOwned==true or ((profile.NeonOwned or {})[slotId]==true)
	return {Instance=instance,InstanceId=instanceId,Colors=colors,NeonOwned=neon}
end

function Adapter.ModuleRaw(template,instance)
	return Resolver.ModuleRaw(nil,template,instance) or {}
end

function Adapter.ApplyClone(clone,template,resolved)
	if not (clone and template) then return end
	for name,value in pairs(Adapter.ModuleRaw(template,resolved and resolved.Instance)) do clone:SetAttribute(name,value) end
	clone:SetAttribute("PreviewModuleInstanceId",resolved and resolved.InstanceId or "")
	clone:SetAttribute("PreviewUsesSavedCustomisation",resolved and resolved.Instance~=nil)
end

function Adapter.ProfileFingerprint(profile)
	local active={}
	local function encode(value)
		if typeof(value)~="table" then return typeof(value)..":"..tostring(value) end
		if active[value] then return "<cycle>" end; active[value]=true
		local keys={}; for key in pairs(value) do table.insert(keys,key) end; table.sort(keys,function(a,b) return typeof(a)..":"..tostring(a)<typeof(b)..":"..tostring(b) end)
		local result={"{"}; for _,key in ipairs(keys) do table.insert(result,encode(key)); table.insert(result,"="); table.insert(result,encode(value[key])); table.insert(result,";") end; table.insert(result,"}"); active[value]=nil; return table.concat(result)
	end
	return encode(profile or {})
end

function Adapter.Performance(state,categoriesRoot)
	local profile=state and (state.PreviewProfile or state.Profile)
	if not (state and state.Stage=="Build" and state.ModuleMode=="Options" and state.SelectedModuleId and typeof(profile)=="table") then return nil,nil end
	local selectedInstance=Adapter.Selected(state,state.SelectedSlot,state.SelectedModuleId)
	return Resolver.Selected(categoriesRoot,profile,state.SelectedSlot,{ModuleId=state.SelectedModuleId},selectedInstance)
end

return Adapter
