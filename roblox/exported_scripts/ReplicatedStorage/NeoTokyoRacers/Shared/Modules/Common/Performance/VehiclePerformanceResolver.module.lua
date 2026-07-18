-- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
-- Pure shared calculation owner. It never mutates profiles, assets, ownership, or spawned vehicles.
local V2Calculator=require(script.Parent:WaitForChild("VehiclePerformanceV2Calculator"))
local V2Runtime=require(script.Parent:WaitForChild("VehiclePerformanceV2Runtime"))
local V2Upgrades=require(script.Parent:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local Resolver={}
local baseRatingCache={}

local defaultNames={
	Engine1={"DefaultFrontEngineModuleId","DefaultEngineModuleId"},
	Engine2={"DefaultRearEngineModuleId","DefaultEngineBModuleId"},
	Stabilisers={"DefaultStabilisersModuleId","DefaultStabiliserModuleId"},
	Boost={"DefaultBoostModuleId"},
}

local function idOf(value,attribute)
	if typeof(value)=="Instance" then return tostring(value:GetAttribute(attribute) or value.Name) end
	if typeof(value)=="table" then return tostring(value[attribute] or "") end
	return value~=nil and tostring(value) or ""
end
local function attributeOrField(value,name)
	if typeof(value)=="Instance" then return value:GetAttribute(name) end
	return value and value[name]
end
local function findTemplate(root,attribute,id)
	if not root or id==nil or tostring(id)=="" then return nil end
	for _,item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and tostring(item:GetAttribute(attribute) or item.Name)==tostring(id) and item:GetAttribute("RetiredFromCatalog")~=true then return item end
	end
end
local function first(value,names)
	for _,name in ipairs(names) do local result=attributeOrField(value,name); if result~=nil and tostring(result)~="" then return tostring(result) end end
end
local function byText(dictionary,key)
	if typeof(dictionary)~="table" or key==nil then return nil end
	local direct=dictionary[key] or dictionary[tostring(key)]; if direct~=nil then return direct end
	for id,item in pairs(dictionary) do if tostring(id)==tostring(key) then return item end end
end
local function currentVehicle(profile)
	local id=profile and profile.CurrentVehicleId
	return id and byText(profile.Vehicles,id),id and tostring(id) or nil
end
local function installed(profile,slotId)
	profile=profile or {}; local vehicle=currentVehicle(profile); local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]
	local instance=instanceId and byText(profile.OwnedModuleInstances,instanceId)
	local moduleId=instance and instance.TemplateId or (profile.InstalledModules and profile.InstalledModules[slotId])
	return moduleId and tostring(moduleId) or nil,instance,instanceId and tostring(instanceId) or nil
end
local function moduleSlot(module)
	local explicit=tostring(attributeOrField(module,"ModuleSlot") or "")
	local moduleType=tostring(attributeOrField(module,"ModuleType") or "")
	local folder=string.lower(tostring(attributeOrField(module,"ModuleFolder") or "")); local id=string.upper(idOf(module,"ModuleId")); local position=string.lower(tostring(attributeOrField(module,"EnginePosition") or ""))
	if explicit=="Engine" or moduleType=="Engine" then
		if attributeOrField(module,"RearEngine")==true or position=="rear" or folder=="engines_b" or string.find(id,"MODULE_ENGINE_B_",1,true) then return "Engine2" end
		return "Engine1"
	end
	if explicit~="" then return explicit end
	return moduleType
end

function Resolver.FindCockpit(root,cockpit) if typeof(cockpit)=="Instance" then return cockpit end; return findTemplate(root,"CockpitId",idOf(cockpit,"CockpitId")) end
function Resolver.FindModule(root,module) if typeof(module)=="Instance" then return module end; return findTemplate(root,"ModuleId",idOf(module,"ModuleId")) end
function Resolver.ModuleRaw(root,module,instance)
	local template=Resolver.FindModule(root,module); if not template then return nil end
	return V2Upgrades.ApplyToModuleRaw(template,instance and instance.V2UpgradePoints or {})
end
function Resolver.DefaultBuild(root,cockpit)
	local template=Resolver.FindCockpit(root,cockpit); if not template then return nil,nil,"Cockpit template not found" end
	local modules={}; local bySlot={}
	for slotId,names in pairs(defaultNames) do local moduleId=first(cockpit,names) or first(template,names); local module=findTemplate(root,"ModuleId",moduleId); if not module then return nil,nil,slotId.." default not found: "..tostring(moduleId) end; bySlot[slotId]=module; table.insert(modules,module) end
	return template,modules,bySlot
end
function Resolver.Factory(root,cockpit)
	local template,modules,errorMessage=Resolver.DefaultBuild(root,cockpit); if not template then return nil,errorMessage end
	return V2Runtime.CalculateComponents(template,modules,{})
end
function Resolver.Profile(root,profile)
	profile=profile or {}; if typeof(profile.Performance)=="table" and typeof(profile.Performance.Raw)=="table" and typeof(profile.Performance.Overall)=="table" then return profile.Performance end
	local cockpit=findTemplate(root,"CockpitId",profile.CurrentCockpit); if not cockpit then return nil,"Current cockpit template not found" end
	local modules,allocations={},{}
	for slotId,moduleId in pairs(profile.InstalledModules or {}) do
		local installedId,instance=installed(profile,slotId); moduleId=installedId or moduleId; local template=findTemplate(root,"ModuleId",moduleId)
		if template then table.insert(modules,template); allocations[tostring(template:GetAttribute("ModuleId") or template.Name)]=instance and instance.V2UpgradePoints or {} end
	end
	return V2Runtime.CalculateComponents(cockpit,modules,allocations)
end
function Resolver.Selected(root,profile,slotId,module,instance)
	local base,errorMessage=Resolver.Profile(root,profile); if not base then return nil,nil,errorMessage end
	local selected=Resolver.FindModule(root,module); if not selected then return nil,base,"Selected module template not found" end
	local raw=V2Calculator.CloneRaw(base.Raw); local installedId,installedInstance=installed(profile,slotId)
	if installedId then local old=Resolver.ModuleRaw(root,{ModuleId=installedId},installedInstance); if old then V2Calculator.AddRaw(raw,old,-1) end end
	local replacement=Resolver.ModuleRaw(root,selected,instance); if replacement then V2Calculator.AddRaw(raw,replacement,1) end
	return V2Calculator.Calculate(raw),base
end
function Resolver.ModuleRating(root,module,instance)
	local template=Resolver.FindModule(root,module); if not template then return 0 end
	local moduleId=tostring(template:GetAttribute("ModuleId") or template.Name); local points=instance and instance.V2UpgradePoints; local key=moduleId
	if typeof(points)=="table" then local parts={}; for pathId,value in pairs(points) do table.insert(parts,tostring(pathId).."="..tostring(value)) end; table.sort(parts); key=key.."|"..table.concat(parts,",") end
	if baseRatingCache[key] then return baseRatingCache[key] end
	local reference=findTemplate(root,"CockpitId","bruiser_01"); local cockpit,defaults,bySlot=Resolver.DefaultBuild(root,reference); if not cockpit then return 0 end
	local slotId=moduleSlot(template); local list={}; local replaced=false
	for referenceSlot,default in pairs(bySlot) do if referenceSlot==slotId then table.insert(list,template); replaced=true else table.insert(list,default) end end
	if not replaced then table.insert(list,template) end
	local allocation={ [moduleId]=points or {} }; local result=V2Runtime.CalculateComponents(cockpit,list,allocation); local rating=math.floor(tonumber(result.Overall and result.Overall.PerformanceIndex) or 0)
	baseRatingCache[key]=rating; return rating
end
function Resolver.UpgradeCost(root,module,instance,pathId) -- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1
	local template=Resolver.FindModule(root,module); if not template then return nil end
	return V2Upgrades.NextPointCost(template,instance and instance.V2UpgradePoints or {},pathId)
end
function Resolver.UpgradePreview(root,profile,slotId,module,instance,pathId) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
	local template=Resolver.FindModule(root,module); if not template then return nil,nil,"Module template not found" end
	local ok,preview=V2Upgrades.PreviewPoint(template,instance and instance.V2UpgradePoints or {},pathId)
	if not ok then return nil,nil,preview end
	local proposed={}; for key,value in pairs(instance or {}) do proposed[key]=value end; proposed.V2UpgradePoints=preview.Allocation
	local after,before,errorMessage=Resolver.Selected(root,profile,slotId,template,proposed)
	return after,before,errorMessage,preview
end
function Resolver.ClearCache() table.clear(baseRatingCache) end
return Resolver
