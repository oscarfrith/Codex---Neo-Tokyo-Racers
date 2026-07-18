-- Neo Tokyo Racers - Canonical vehicle performance resolver and module ratings
-- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1"
local PREFIX = "[NTR Canonical Performance Resolver]"

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
local shared = need(kit, "Shared", "Folder")
local modulesRoot = need(shared, "Modules", "Folder")
local common = need(modulesRoot, "Common", "Folder")
local performance = need(common, "Performance", "Folder")
local categories = need(need(need(kit, "Assets", "Folder"), "Vehicles", "Folder"), "Categories", "Folder")
local v2Definitions = need(performance, "VehiclePerformanceV2Definitions", "ModuleScript")
local v2Calculator = need(performance, "VehiclePerformanceV2Calculator", "ModuleScript")
local v2Runtime = need(performance, "VehiclePerformanceV2Runtime", "ModuleScript")
local v2Upgrades = need(performance, "VehiclePerformanceV2UpgradeRuntime", "ModuleScript")
local upgradeRuntime = need(performance, "VehicleModuleUpgradeRuntime", "ModuleScript")

local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local preview = need(controllers, "Preview", "Folder")
local application = need(ui, "ModuleShopUIController", "ModuleScript")
local cards = need(ui, "GarageModuleCardViewModel", "ModuleScript")
local instancePreview = need(preview, "GarageModuleInstancePreviewAdapter", "ModuleScript")

assert(string.find(application.Source, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3", 1, true), "Canonical garage application baseline missing")
assert(string.find(application.Source, "NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1", 1, true) or string.find(cards.Source, "NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1", 1, true), "Shared module-card baseline missing")
assert(string.find(instancePreview.Source, "NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1", 1, true), "Read-only instance preview baseline missing")
assert(string.find(v2Upgrades.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE7_UPGRADE_RUNTIME", 1, true), "V2 upgrade runtime baseline missing")
assert(string.find(upgradeRuntime.Source, "NTR_VEHICLE_PERFORMANCE_V2_PHASE8_COMPAT_UPGRADE_RUNTIME", 1, true), "Profile upgrade runtime baseline missing")

local rawOrder = {
	"TopSpeed", "EngineOutput", "Weight", "LateralGrip", "SteeringResponse", "HoverStability",
	"DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostForce", "BoostDuration",
	"BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce",
}

local accessoryPaths = {
	FrontBumper = {
		{ "BrakeDucts", "Brake Ducts", { BrakingForce = 3, Weight = 1 } },
		{ "FrontSplitter", "Front Splitter", { Downforce = 3, Drag = 1 } },
		{ "LightweightMounts", "Lightweight Mounts", { Weight = -3, BrakingForce = -1 } },
	},
	RearBumper = {
		{ "RearDiffuser", "Rear Diffuser", { HoverStability = 2, DriftControl = 1, Drag = 1 } },
		{ "LightweightMounts", "Lightweight Mounts", { Weight = -3 } },
	},
	RearSpoiler = {
		{ "DownforcePackage", "Downforce Package", { Downforce = 4, BrakingForce = 1, Drag = 2 } },
		{ "LowDragProfile", "Low-Drag Profile", { Drag = -3, Downforce = -1 } },
		{ "DriftAero", "Drift Aero", { DriftControl = 2, DriftGrip = 1, Drag = 1 } },
	},
	SidePods = {
		{ "CorneringVanes", "Cornering Vanes", { LateralGrip = 2, DriftGrip = 2 } },
		{ "AirflowChannels", "Airflow Channels", { Drag = -1, HoverStability = 1 } },
		{ "LightweightShells", "Lightweight Shells", { Weight = -3 } },
	},
}

local accessoryBasePrice = { FrontBumper = 3025, RearBumper = 3025, RearSpoiler = 3575, SidePods = 3850 }
local accessoryIds = {}
for _, family in ipairs({ "FRONTBUMPER", "REARBUMPER", "REARSPOILER", "SIDEPODS" }) do
	for level = 1, 3 do accessoryIds["MODULE_" .. family .. "_LVL" .. level] = true end
end

local function findModelsById(attributeName)
	local result = {}
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") then
			local id = item:GetAttribute(attributeName)
			if typeof(id) == "string" and id ~= "" and item:GetAttribute("RetiredFromCatalog") ~= true then
				assert(result[id] == nil, "Duplicate active " .. attributeName .. " " .. id)
				result[id] = item
			end
		end
	end
	return result
end

local liveCockpits = findModelsById("CockpitId")
local liveModules = findModelsById("ModuleId")
for id in pairs(accessoryIds) do assert(liveModules[id], "Missing active accessory module " .. id) end

local resolverSource = [==[
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
function Resolver.ClearCache() table.clear(baseRatingCache) end
return Resolver
]==]
compile("VehiclePerformanceResolver", resolverSource)

local upgradeSource = v2Upgrades.Source
if not string.find(upgradeSource, REVISION, 1, true) then
	upgradeSource = replaceOnce(upgradeSource,
		[[local legacyMap = {
	FuelInjection = "Output", PowerConverter = "Velocity", LightweightInternals = "Efficiency", TorqueMapping = "Output",
	VectoringFirmware = "Grip", DriftCalibration = "Drift", ReactiveDampers = "Response", LightweightArms = "Response",
	HighFlowInjectors = "Burst", ExpandedCell = "Endurance", RapidRecharge = "Recovery", LightweightCell = "Endurance",
}]],
		[[local legacyMap = { -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
	FuelInjection = "Output", PowerConverter = "Velocity", LightweightInternals = "Efficiency", TorqueMapping = "Output",
	VectoringFirmware = "Grip", DriftCalibration = "Drift", ReactiveDampers = "Response", LightweightArms = "Response",
	HighFlowInjectors = "Burst", ExpandedCell = "Endurance", RapidRecharge = "Recovery", LightweightCell = "Endurance",
	BrakeDucts = "BrakeDucts", FrontSplitter = "FrontSplitter", LightweightMounts = "LightweightMounts",
	RearDiffuser = "RearDiffuser", DownforcePackage = "DownforcePackage", LowDragProfile = "LowDragProfile", DriftAero = "DriftAero",
	CorneringVanes = "CorneringVanes", AirflowChannels = "AirflowChannels", LightweightShells = "LightweightShells",
}]], "accessory legacy path map")
	upgradeSource = replaceOnce(upgradeSource,
		[[	"HighFlowInjectors", "ExpandedCell", "RapidRecharge", "LightweightCell",
}]],
		[[	"HighFlowInjectors", "ExpandedCell", "RapidRecharge", "LightweightCell",
	"BrakeDucts", "FrontSplitter", "LightweightMounts", "RearDiffuser", "DownforcePackage", "LowDragProfile", "DriftAero", "CorneringVanes", "AirflowChannels", "LightweightShells",
}]], "accessory migration order")
	upgradeSource = replaceOnce(upgradeSource,
		[[				local fraction = path:GetAttribute("DeltaFraction_" .. name)
				if typeof(fraction) == "number" then raw[name] *= 1 + fraction * points end]],
		[[				local fraction = path:GetAttribute("DeltaFraction_" .. name)
				if typeof(fraction) == "number" then raw[name] *= 1 + fraction * points end
				local flat = path:GetAttribute("DeltaFlat_" .. name)
				if typeof(flat) == "number" then raw[name] += flat * points end]], "flat V2 upgrade deltas")
	upgradeSource = replaceOnce(upgradeSource,
		[[	if typeof(migrated.V2UpgradePoints) == "table" then
		migrated.V2UpgradePoints = Runtime.NormalizeAllocation(module, migrated.V2UpgradePoints)
		migrated.V2UpgradeVersion = "V2_PHASE7"
		return migrated, { AlreadyV2 = true, ConvertedPoints = 0, RefundCredit = 0 }
	end
	local allocation, converted, refund = {}, 0, 0
	local legacy = typeof(migrated.UpgradeLevels) == "table" and migrated.UpgradeLevels or {}]],
		[[	local legacy = typeof(migrated.UpgradeLevels) == "table" and migrated.UpgradeLevels or {}
	local hasLegacy = false; for _, level in pairs(legacy) do if (tonumber(level) or 0) > 0 then hasLegacy = true; break end end
	local hasV2 = false; if typeof(migrated.V2UpgradePoints) == "table" then for _, points in pairs(migrated.V2UpgradePoints) do if (tonumber(points) or 0) > 0 then hasV2 = true; break end end end
	if typeof(migrated.V2UpgradePoints) == "table" and (hasV2 or not hasLegacy) then
		migrated.V2UpgradePoints = Runtime.NormalizeAllocation(module, migrated.V2UpgradePoints)
		migrated.V2UpgradeVersion = "V2_PHASE7"
		return migrated, { AlreadyV2 = true, ConvertedPoints = 0, RefundCredit = 0 }
	end
	local allocation, converted, refund = {}, 0, 0]], "legacy accessory instance migration")
end
compile("VehiclePerformanceV2UpgradeRuntime", upgradeSource)

local profileUpgradeSource = upgradeRuntime.Source
if not string.find(profileUpgradeSource, REVISION, 1, true) then
	profileUpgradeSource = replaceOnce(profileUpgradeSource,
		[[	if migration.Version=="V2_PHASE8_LIVE" and migration.RefundApplied==true then return end]],
		[[	if migration.Version=="V2_ACCESSORY_ALIGNMENT_V1" and migration.RefundApplied==true then return end -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1]], "accessory migration gate")
	profileUpgradeSource = replaceOnce(profileUpgradeSource,
		[[	profile.VehiclePerformanceV2Migration={Version="V2_PHASE8_LIVE",RefundApplied=true,RefundCredit=refund,ConvertedPoints=converted,MissingTemplates=missing,MigratedAtUnix=os.time()}]],
		[[	profile.VehiclePerformanceV2Migration={Version="V2_ACCESSORY_ALIGNMENT_V1",RefundApplied=true,RefundCredit=refund,ConvertedPoints=converted,MissingTemplates=missing,MigratedAtUnix=os.time()}]], "accessory migration result")
end
compile("VehicleModuleUpgradeRuntime", profileUpgradeSource)

local cardSource = cards.Source
if not string.find(cardSource, REVISION, 1, true) then
	cardSource = replaceOnce(cardSource,
		[[function ViewModel.Rating(module,instance)
	return math.floor(tonumber(instance and (instance.Rating or instance.PerformanceRating or instance.PerformanceIndex)) or tonumber(module and (module.Rating or module.PerformanceRating or module.PerformanceIndex)) or 0)
end]],
		[[function ViewModel.Rating(module,instance,resolver) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
	if typeof(resolver)=="function" then local ok,value=pcall(resolver,module,instance); if ok and tonumber(value) then return math.floor(tonumber(value)) end end
	return math.floor(tonumber(instance and (instance.Rating or instance.PerformanceRating or instance.PerformanceIndex)) or tonumber(module and (module.Rating or module.PerformanceRating or module.PerformanceIndex)) or 0)
end]], "shared derived rating hook")
	cardSource = replaceOnce(cardSource, [[Rating=ViewModel.Rating(module,item)]], [[Rating=ViewModel.Rating(module,item,context.Rating)]], "owned derived rating")
	cardSource = replaceOnce(cardSource, [[Rating=ViewModel.Rating(module),SourceRating]], [[Rating=ViewModel.Rating(module,nil,context.Rating),SourceRating]], "shop derived rating")
end
compile("GarageModuleCardViewModel", cardSource)

local previewSource = instancePreview.Source
if not string.find(previewSource, REVISION, 1, true) then
	previewSource = replaceOnce(previewSource,
		[[local Calculator=require(performance:WaitForChild("VehiclePerformanceCalculator"))
local Definitions=require(performance:WaitForChild("VehiclePerformanceDefinitions"))
local V2Upgrades=require(performance:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local LegacyDefinitions=require(performance:WaitForChild("VehicleUpgradeDefinitions"))]],
		[[local Resolver=require(performance:WaitForChild("VehiclePerformanceResolver")) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1]], "preview canonical resolver require")
	local moduleTypeStart = string.find(previewSource, "local function moduleType(template)", 1, true)
	local moduleRawEnd = string.find(previewSource, "function Adapter.ApplyClone", moduleTypeStart or 1, true)
	assert(moduleTypeStart and moduleRawEnd, "Missing preview module-raw replacement range")
	previewSource = string.sub(previewSource, 1, moduleTypeStart - 1) .. [==[
function Adapter.ModuleRaw(template,instance)
	return Resolver.ModuleRaw(nil,template,instance) or {}
end

]==] .. string.sub(previewSource, moduleRawEnd)
	local performanceStart = string.find(previewSource, "function Adapter.Performance(state,categoriesRoot)", 1, true)
	local performanceEnd = string.find(previewSource, "\nend\n\nreturn Adapter", performanceStart or 1, true)
	assert(performanceStart and performanceEnd, "Missing preview performance replacement range")
	previewSource = string.sub(previewSource, 1, performanceStart - 1) .. [==[
function Adapter.Performance(state,categoriesRoot)
	local profile=state and (state.PreviewProfile or state.Profile)
	if not (state and state.Stage=="Build" and state.ModuleMode=="Options" and state.SelectedModuleId and typeof(profile)=="table") then return nil,nil end
	local selectedInstance=Adapter.Selected(state,state.SelectedSlot,state.SelectedModuleId)
	return Resolver.Selected(categoriesRoot,profile,state.SelectedSlot,{ModuleId=state.SelectedModuleId},selectedInstance)
end
]==] .. string.sub(previewSource, performanceEnd + 5)
end
compile("GarageModuleInstancePreviewAdapter", previewSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[[local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"); local Calculator=require(performance:WaitForChild("VehiclePerformanceCalculator")); local Racing=require(kit.Shared.Modules.UI.RacingUIComponents)]],
		[[local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"); local PerformanceResolver=require(performance:WaitForChild("VehiclePerformanceResolver")); local Racing=require(kit.Shared.Modules.UI.RacingUIComponents) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1]], "application canonical resolver require")
	applicationSource = replaceOnce(applicationSource,
		[[local function cloneNumbers(source) local out={}; for k,v in pairs(source or {}) do if typeof(v)=="number" then out[k]=v end end; return out end
]], "", "obsolete seven-stat clone helper")
	applicationSource = replaceOnce(applicationSource,
		[[local function enginePosition(m) local explicit=tostring(m and m.EnginePosition or ""); if explicit~="" then return explicit end; if m and (m.RearEngine==true or m.ModuleFolder=="Engines_B" or string.find(tostring(m.ModuleId),"ENGINE_B",1,true)) then return "Rear" end; return "Front" end]],
		[[local function enginePosition(m) local explicit=tostring(m and m.EnginePosition or ""); if explicit~="" then return explicit end; if m and (m.RearEngine==true or m.ModuleFolder=="Engines_B" or string.find(tostring(m.ModuleId),"MODULE_ENGINE_B_",1,true)) then return "Rear" end; return "Front" end]], "unambiguous engine classification")
	local legacyStart = string.find(applicationSource, "local function defaults(c)", 1, true)
	local legacyEnd = string.find(applicationSource, "local function imageValue", legacyStart or 1, true)
	assert(legacyStart and legacyEnd, "Missing application legacy performance range")
	applicationSource = string.sub(applicationSource, 1, legacyStart - 1) .. [==[
local function performanceForCockpit(c) return PerformanceResolver.Factory(categoriesRoot,c) end
local function currentPerformance()
	local instanceNow,instanceBase=InstancePreview.Performance(State,categoriesRoot)
	if instanceNow then return instanceNow,instanceBase end
	local base=PerformanceResolver.Profile(categoriesRoot,State.PreviewProfile or State.Profile)
	return base,base
end
local function moduleRating(module,instance) return PerformanceResolver.ModuleRating(categoriesRoot,module,instance) end
]==] .. string.sub(applicationSource, legacyEnd)
	applicationSource = replaceOnce(applicationSource,
		[[SourceVehicleName=sourceVehicleName})]],
		[[SourceVehicleName=sourceVehicleName,Rating=moduleRating})]], "owned module rating callback")
	applicationSource = replaceOnce(applicationSource,
		[[SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount})]],
		[[SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount,Rating=moduleRating})]], "shop module rating callback")
end
compile("ModuleShopUIController", applicationSource)

local function sourceHas(object, marker) return string.find(object.Source, marker, 1, true) ~= nil end
local function audit()
	local pass, fail = 0, 0
	local function check(condition, message) if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end end
	local resolver = performance:FindFirstChild("VehiclePerformanceResolver")
	check(resolver and resolver:IsA("ModuleScript") and sourceHas(resolver, REVISION), "shared resolver installed")
	check(sourceHas(v2Upgrades, REVISION), "V2 upgrade runtime supports flat accessory paths")
	check(sourceHas(upgradeRuntime, REVISION), "profile migration gate upgraded")
	check(sourceHas(cards, REVISION), "shared cards accept derived ratings")
	check(sourceHas(instancePreview, REVISION) and not string.find(instancePreview.Source, "VehiclePerformanceCalculator", 1, true), "preview uses only canonical resolver")
	check(sourceHas(application, REVISION) and not string.find(application.Source, "CalculateLegacy", 1, true) and not string.find(application.Source, "VehiclePerformanceCalculator", 1, true), "active garage has no legacy calculator path")
	local materialised, paths = 0, 0
	for id in pairs(accessoryIds) do local module=liveModules[id]; if module and module:GetAttribute("V2Materialised")==true then materialised += 1 end; local root=module and module:FindFirstChild("VehiclePerformanceV2UpgradePaths"); if root then paths += #root:GetChildren() end end
	check(materialised==12, "all 12 accessory modules are V2 materialised")
	check(paths==33, "all 33 accessory upgrade paths are present")
	if resolver and resolver:IsA("ModuleScript") then
		local ok, result = pcall(require, resolver); check(ok and typeof(result)=="table", "shared resolver requires successfully")
		if ok then
			local targets={bruiser_02={"E",200},bruiser_03={"D",375},bruiser_01={"C",525},bruiser_04={"B",662},bruiser_05={"A",787},bruiser_06={"S",925}}
			for cockpitId,target in pairs(targets) do local performanceResult=result.Factory(categories,liveCockpits[cockpitId]); local overall=performanceResult and performanceResult.Overall or {}; check(overall.Tier==target[1] and math.abs((tonumber(overall.PerformanceIndex) or 0)-target[2])<=3,cockpitId.." canonical stock target") end
			local sample=result.ModuleRating(categories,liveModules.MODULE_ENGINE_BRUISER_01_POWER,nil); check(sample>0,"derived module rating sample is available")
		end
	end
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d",PREFIX,pass,fail)); assert(fail==0,"Post-install audit failed")
end

if MODE == "AUDIT" then audit(); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local resolver = performance:FindFirstChild("VehiclePerformanceResolver")
if resolver and sourceHas(resolver, REVISION) and sourceHas(application, REVISION) then audit(); print(PREFIX .. " already installed; no changes made"); return end
assert(not resolver, "VehiclePerformanceResolver already exists with an unexpected source")

local oldSources = { [v2Upgrades]=v2Upgrades.Source, [upgradeRuntime]=upgradeRuntime.Source, [cards]=cards.Source, [instancePreview]=instancePreview.Source, [application]=application.Source }
local changedAttributes = {}
local createdRoots = {}
local createdResolver
local function rememberAttribute(object,name)
	changedAttributes[object]=changedAttributes[object] or {}; if changedAttributes[object][name]==nil then changedAttributes[object][name]={Present=object:GetAttribute(name)~=nil,Value=object:GetAttribute(name)} end
end
local function setAttribute(object,name,value) rememberAttribute(object,name); object:SetAttribute(name,value) end
local function rollback(reason)
	for object,source in pairs(oldSources) do pcall(function() object.Source=source end) end
	for _,root in ipairs(createdRoots) do pcall(function() root:Destroy() end) end
	for object,attributes in pairs(changedAttributes) do for name,record in pairs(attributes) do pcall(function() object:SetAttribute(name,record.Present and record.Value or nil) end) end end
	if createdResolver then pcall(function() createdResolver:Destroy() end) end
	error(PREFIX .. " rolled back: " .. tostring(reason),0)
end

local ok, err = pcall(function()
	createdResolver=Instance.new("ModuleScript"); createdResolver.Name="VehiclePerformanceResolver"; createdResolver.Source=resolverSource; createdResolver.Parent=performance
	v2Upgrades.Source=upgradeSource; upgradeRuntime.Source=profileUpgradeSource; cards.Source=cardSource; instancePreview.Source=previewSource; application.Source=applicationSource
	for moduleId in pairs(accessoryIds) do
		local module=liveModules[moduleId]; local slot=tostring(module:GetAttribute("ModuleSlot") or module:GetAttribute("ModuleType")); local level=math.clamp(math.floor(tonumber(module:GetAttribute("Level")) or tonumber(string.match(moduleId,"LVL(%d+)")) or 1),1,3)
		local raw={}; for _,name in ipairs(rawOrder) do raw[name]=0 end
		raw.Weight=level*2
		if slot=="FrontBumper" or slot=="RearBumper" then raw.BrakingForce=level*2
		elseif slot=="RearSpoiler" then raw.TopSpeed=level; raw.LateralGrip=level*2; raw.SteeringResponse=level*2; raw.HoverStability=level*2
		elseif slot=="SidePods" then raw.EngineOutput=level; raw.LateralGrip=level*2; raw.SteeringResponse=level*2; raw.HoverStability=level*2; raw.DriftControl=level*2; raw.DriftGrip=level*2; raw.DriftChargeRate=level*2 end
		for _,name in ipairs(rawOrder) do setAttribute(module,name,raw[name]); setAttribute(module,"PerformanceDelta_"..name,raw[name]) end
		setAttribute(module,"V2Materialised",true); setAttribute(module,"V2MaterialisationVersion","V2_ACCESSORY_ALIGNMENT_V1"); setAttribute(module,"UpgradePointCapacity",6); setAttribute(module,"MaxPointsPerPath",3)
		local base=accessoryBasePrice[slot] or tonumber(module:GetAttribute("UpgradePrice")) or 3500; for point,multiplier in ipairs({1,1.25,1.5,1.85,2.25,2.7}) do setAttribute(module,"Point"..point.."CostGuide",math.floor(base*multiplier+0.5)) end
		assert(not module:FindFirstChild("VehiclePerformanceV2UpgradePaths"),moduleId.." already has an unexpected V2 path root")
		local root=Instance.new("Folder"); root.Name="VehiclePerformanceV2UpgradePaths"; root.Parent=module; table.insert(createdRoots,root)
		for order,definition in ipairs(accessoryPaths[slot] or {}) do local path=Instance.new("Folder"); path.Name=definition[1]; path:SetAttribute("PathId",definition[1]); path:SetAttribute("DisplayName",definition[2]); path:SetAttribute("MaxPoints",3); path:SetAttribute("Order",order); for name,value in pairs(definition[3]) do path:SetAttribute("DeltaFlat_"..name,value) end; path.Parent=root end
	end
	audit()
end)
if not ok then rollback(err) end
print(PREFIX .. " INSTALL COMPLETE - Restart Play, compare dealership/owned PI, then verify module ratings and one accessory upgrade purchase.")
