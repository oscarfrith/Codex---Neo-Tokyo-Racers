-- Neo Tokyo Racers - Vehicle Cosmetics and Empty Module Routes V1.2
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Adds vehicle-specific Thrust Colour and true SurfaceLight Underglow purchases,
-- atomic All-Neon editing, protected front/rear lights, direct paint sliders,
-- and return-aware empty-module navigation.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Vehicle Cosmetics and Empty Routes V1.2]"
local RUN_ID=HttpService:GenerateGUID(false)
local REVISION="NTR_CUSTOMISATION_VEHICLE_COSMETICS_EMPTY_ROUTES_V1_2_AUTHORED_LIGHT_PROPERTIES"

local function countPlain(source,needle)
	local count,cursor=0,1
	while true do
		local first,last=source:find(needle,cursor,true)
		if not first then return count end
		count+=1
		cursor=last+1
	end
end

local function replaceOnce(source,needle,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,needle)==1,label.." anchor count changed")
	local first=assert(source:find(needle,1,true),label.." anchor missing")
	return source:sub(1,first-1)..replacement..source:sub(first+#needle)
end

local function replaceAllPlain(source,needle,replacement,expected,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,needle)==expected,label.." anchor count changed")
	local pieces={}
	local cursor=1
	while true do
		local first,last=source:find(needle,cursor,true)
		if not first then table.insert(pieces,source:sub(cursor)); break end
		table.insert(pieces,source:sub(cursor,first-1))
		table.insert(pieces,replacement)
		cursor=last+1
	end
	return table.concat(pieces)
end

local function replaceBetween(source,firstMarker,lastMarker,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,firstMarker)==1,label.." first marker count changed")
	assert(countPlain(source,lastMarker)==1,label.." last marker count changed")
	local first=assert(source:find(firstMarker,1,true),label.." first marker missing")
	local last=assert(source:find(lastMarker,first+#firstMarker,true),label.." last marker missing")
	return source:sub(1,first-1)..replacement..source:sub(last)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local function ensureFolder(parent,name,created)
	local item=parent:FindFirstChild(name)
	if item then assert(item:IsA("Folder"),item:GetFullName().." must be a Folder") else item=Instance.new("Folder"); item.Name=name; item.Parent=parent; table.insert(created,item) end
	return item
end

local function attributesSnapshot(instance)
	local result={}
	for name,value in pairs(instance:GetAttributes()) do result[name]=value end
	return result
end

local function restoreAttributes(instance,snapshot)
	for name in pairs(instance:GetAttributes()) do if snapshot[name]==nil then instance:SetAttribute(name,nil) end end
	for name,value in pairs(snapshot) do instance:SetAttribute(name,value) end
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local shared=assert(kit:FindFirstChild("Shared"),"NeoTokyoRacers.Shared missing")
local modules=assert(shared:FindFirstChild("Modules"),"NeoTokyoRacers.Shared.Modules missing")
local dataModules=assert(modules:FindFirstChild("Data"),"Shared.Modules.Data missing")
local config=assert(kit:FindFirstChild("Config"),"NeoTokyoRacers.Config missing")
local uiConfig=assert(config:FindFirstChild("UI"),"NeoTokyoRacers.Config.UI missing")
local replacement=assert(uiConfig:FindFirstChild("GarageReplacement"),"GarageReplacement config missing")
local categories=assert(kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles") and kit.Assets.Vehicles:FindFirstChild("Categories"),"Vehicle categories missing")

local controllerRoot=assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers"),
	"NeoTokyoRacersClient.Controllers missing"
)
local uiControllers=assert(controllerRoot:FindFirstChild("UI"),"Controllers.UI missing")
local previewControllers=assert(controllerRoot:FindFirstChild("Preview"),"Controllers.Preview missing")
local moduleShop=assert(uiControllers:FindFirstChild("ModuleShopUIController"),"ModuleShopUIController missing")
local previewVehicle=assert(previewControllers:FindFirstChild("PreviewVehicleController"),"PreviewVehicleController missing")
local thrustPreview=assert(previewControllers:FindFirstChild("ThrustPreviewController_Active"),"ThrustPreviewController_Active missing")

local garageServices=assert(
	ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage"),
	"Garage services missing"
)
local garageAction=assert(garageServices:FindFirstChild("GarageActionController_Shadow_Disabled"),"GarageActionController missing")
local ownedDisplay=assert(garageServices:FindFirstChild("OwnedGarageDisplayRuntime"),"OwnedGarageDisplayRuntime missing")
local legacyDisplay=assert(garageServices:FindFirstChild("GarageDisplayRuntime"),"GarageDisplayRuntime missing")
local schema=assert(dataModules:FindFirstChild("PlayerProfileSchema"),"PlayerProfileSchema missing")
local cachedThrust=assert(
	modules:FindFirstChild("Client")
		and modules.Client:FindFirstChild("Visuals")
		and modules.Client.Visuals:FindFirstChild("CachedThrustVisualRuntime"),
	"CachedThrustVisualRuntime missing"
)

for _,instance in ipairs({moduleShop,previewVehicle,schema,cachedThrust,ownedDisplay,legacyDisplay}) do assert(instance:IsA("ModuleScript"),instance:GetFullName().." must be a ModuleScript") end
for _,instance in ipairs({garageAction,thrustPreview}) do assert(instance:IsA("LuaSourceContainer"),instance:GetFullName().." must contain source") end

assert(moduleShop.Source:find("NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1",1,true),"Confirmed three-workshop UI baseline missing")
assert(garageAction.Source:find("NTR_CUSTOMISATION_NEON_CAPABILITY_PROJECTION_V1",1,true),"Confirmed neon server baseline missing")
assert(previewVehicle.Source:find("NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1",1,true),"Confirmed preview paint baseline missing")
assert(cachedThrust.Source:find("NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1",1,true),"Confirmed cached thrust owner missing")
assert(thrustPreview.Source:find("NTR_THRUST_PREVIEW_STALE_LIVE_CALL_REMOVED_V1",1,true),"Confirmed thrust preview bridge missing")

local CATALOG_SOURCE=[==[
-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_CATALOG_V1_2_AUTHORED_LIGHT_PROPERTIES
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog={}
Catalog.SchemaVersion=1
local root=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement"):WaitForChild("VehicleCosmetics")

local ids={"ThrustColour","Underglow"}
local function folder(id) local item=root:FindFirstChild(tostring(id)); return item and item:IsA("Folder") and item or nil end
local function clone(value) if typeof(value)~="table" then return value end; local result={}; for key,child in pairs(value) do result[key]=clone(child) end; return result end
local function defaultColour(id) local item=folder(id); local value=item and item:GetAttribute("DefaultColor"); return typeof(value)=="Color3" and value or Color3.new(1,1,1) end

function Catalog.Get(id)
	id=tostring(id or "")
	local item=folder(id); if not item then return nil end
	return {
		CosmeticId=id,
		DisplayName=tostring(item:GetAttribute("DisplayName") or id),
		Price=math.max(0,math.floor(tonumber(item:GetAttribute("Price")) or 0)),
		Icon=tostring(item:GetAttribute("Icon") or ""),
		DefaultColor=defaultColour(id),
		Available=item:GetAttribute("Available")~=false,
		SortOrder=math.floor(tonumber(item:GetAttribute("SortOrder")) or 100),
	}
end

function Catalog.List()
	local result={}
	for _,id in ipairs(ids) do local definition=Catalog.Get(id); if definition then table.insert(result,definition) end end
	table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end)
	return result
end

function Catalog.DefaultState()
	return {SchemaVersion=Catalog.SchemaVersion,Unlocks={ThrustColour=false,Underglow=false},Colours={Underglow=defaultColour("Underglow")}}
end

function Catalog.NormalizeVehicle(vehicle)
	if typeof(vehicle)~="table" then return nil end
	local state=typeof(vehicle.Cosmetics)=="table" and vehicle.Cosmetics or {}
	state.SchemaVersion=Catalog.SchemaVersion
	state.Unlocks=typeof(state.Unlocks)=="table" and state.Unlocks or {}
	state.Colours=typeof(state.Colours)=="table" and state.Colours or {}
	for _,id in ipairs(ids) do state.Unlocks[id]=state.Unlocks[id]==true end
	state.Colours.Underglow=typeof(state.Colours.Underglow)=="Color3" and state.Colours.Underglow or defaultColour("Underglow")
	vehicle.Cosmetics=state
	return state
end

function Catalog.IsUnlocked(vehicle,id)
	local state=Catalog.NormalizeVehicle(vehicle)
	return state~=nil and state.Unlocks[tostring(id)]==true
end

local function underglowContainer(object)
	local current=object
	while current do
		if current.Name=="UNDERGLOW_MOUNT_DoNotRename" or current.Name=="UNDERGLOW_EMITTERS_DoNotRename" or current:GetAttribute("VehicleCosmeticId")=="Underglow" then return current end
		current=current.Parent
	end
	return nil
end

local function isUnderglowLight(object)
	if not (object and object:IsA("SurfaceLight")) then return false end
	return object:GetAttribute("VehicleCosmeticId")=="Underglow"
		or object:GetAttribute("LightChannel")=="Underglow"
		or underglowContainer(object)~=nil
end

function Catalog.HasUnderglowMount(model)
	if not model then return false end
	for _,object in ipairs(model:GetDescendants()) do if isUnderglowLight(object) then return true end end
	return false
end

function Catalog.IsProtectedVehicleLight(object)
	if not (object and (object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight"))) then return false end
	if isUnderglowLight(object) then return true end
	local current=object
	while current do
		local channel=tostring(current:GetAttribute("LightChannel") or "")
		if channel=="FrontLights" or channel=="RearLights" then return true end
		if current:GetAttribute("RootCockpitSpotLight")==true or current:GetAttribute("NTRCockpitLightSystem")~=nil then return true end
		-- Current cockpit templates predate the channel attributes but use stable
		-- authored front/rear spotlight-lens names. Preserve those lights too.
		local lower=string.lower(current.Name)
		if string.find(lower,"cockpit",1,true) and (string.find(lower,"front",1,true) or string.find(lower,"rear",1,true) or string.find(lower,"back",1,true)) then return true end
		current=current.Parent
	end
	return false
end

function Catalog.ApplyPresentation(model,vehicle)
	if not model then return {Detected=0,Enabled=0} end
	-- Presentation is read-only: preview builds fingerprint the client profile
	-- and must never mutate it merely because an older vehicle lacks this state.
	local state=typeof(vehicle)=="table" and typeof(vehicle.Cosmetics)=="table" and vehicle.Cosmetics or nil
	local unlocks=state and typeof(state.Unlocks)=="table" and state.Unlocks or {}
	local colours=state and typeof(state.Colours)=="table" and state.Colours or {}
	local unlocked=unlocks.Underglow==true
	local colour=typeof(colours.Underglow)=="Color3" and colours.Underglow or defaultColour("Underglow")
	local definition=folder("Underglow")
	local lights={}
	for _,object in ipairs(model:GetDescendants()) do
		if isUnderglowLight(object) then table.insert(lights,object) end
	end
	table.sort(lights,function(a,b) return a:GetFullName()<b:GetFullName() end)
	local enabledCount=0
	for _,object in ipairs(lights) do
		-- Runtime owns only the saved player colour and purchase visibility.
		-- Brightness, Range, Angle, Face, Shadows and all other presentation
		-- properties remain authored independently on each cockpit template.
		object.Color=colour
		object.Enabled=unlocked
		if unlocked then enabledCount+=1 end
	end
	local detected=#lights
	if definition and definition:GetAttribute("DebugEnabled")==true then
		model:SetAttribute("NTR_UnderglowDetected",detected)
		model:SetAttribute("NTR_UnderglowEnabled",enabledCount)
		model:SetAttribute("NTR_UnderglowUnlocked",unlocked)
		model:SetAttribute("NTR_UnderglowColour",colour)
	end
	return {Detected=detected,Enabled=enabledCount,Unlocked=unlocked,Colour=colour}
end

return Catalog
]==]

local SERVER_RUNTIME_SOURCE=[==[
-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_SERVER_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog"))
local Runtime={}

local function clone(value) if typeof(value)~="table" then return value end; local result={}; for key,child in pairs(value) do result[key]=clone(child) end; return result end
local function current(profile)
	local id=tostring(profile and profile.CurrentVehicleId or "")
	local vehicle=id~="" and profile.Vehicles and profile.Vehicles[id]
	if typeof(vehicle)~="table" then return nil,nil,"Vehicle instance not found." end
	return vehicle,Catalog.NormalizeVehicle(vehicle)
end
local function restore(target,snapshot) for key in pairs(target) do target[key]=nil end; for key,value in pairs(snapshot) do target[key]=clone(value) end end

function Runtime.Ensure(profile)
	if typeof(profile)~="table" then return end
	for _,vehicle in pairs(typeof(profile.Vehicles)=="table" and profile.Vehicles or {}) do Catalog.NormalizeVehicle(vehicle) end
end

function Runtime.Purchase(profile,cosmeticId,cockpit)
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	local definition=Catalog.Get(cosmeticId)
	if not (definition and definition.Available) then return false,"Vehicle cosmetic is unavailable." end
	if cosmeticId=="Underglow" and not Catalog.HasUnderglowMount(cockpit) then return false,"Underglow is not supported by this vehicle." end
	if state.Unlocks[cosmeticId]==true then return true,"Vehicle cosmetic already unlocked." end
	local price=definition.Price
	if (tonumber(profile.Cash) or 0)<price then return false,"Not enough cash." end
	profile.Cash=(tonumber(profile.Cash) or 0)-price
	state.Unlocks[cosmeticId]=true
	if cosmeticId=="Underglow" then state.Colours.Underglow=state.Colours.Underglow or definition.DefaultColor end
	return true,"Vehicle cosmetic unlocked."
end

function Runtime.SetColour(profile,cosmeticId,colour,captureAll)
	if typeof(colour)~="Color3" then return false,"Invalid cosmetic colour." end
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	if state.Unlocks[cosmeticId]~=true then return false,"Purchase this vehicle cosmetic first." end
	if cosmeticId=="Underglow" then state.Colours.Underglow=colour; return true,"Underglow colour updated." end
	if cosmeticId~="ThrustColour" then return false,"Unknown vehicle cosmetic." end
	local snapshot={ThrustColor=profile.ThrustColor,VehicleThrust=vehicle.ThrustColor,ModuleColors=clone(profile.ModuleColors or {}),Instances=clone(profile.OwnedModuleInstances or {})}
	profile.ThrustColor=colour
	vehicle.ThrustColor=colour
	for slotId in pairs(profile.InstalledModules or {}) do profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId].ThrustColor=colour end
	local ok,result=typeof(captureAll)=="function" and captureAll() or true
	if not ok then
		profile.ThrustColor=snapshot.ThrustColor; vehicle.ThrustColor=snapshot.VehicleThrust
		restore(profile.ModuleColors,snapshot.ModuleColors); restore(profile.OwnedModuleInstances,snapshot.Instances)
		return false,tostring(result or "Thrust colour could not be captured.")
	end
	return true,"Thrust colour updated."
end

function Runtime.SetAllNeon(profile,colour,captureAll)
	if typeof(colour)~="Color3" then return false,"Invalid neon colour." end
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	local snapshot={Cockpit=clone(profile.CockpitColors or {}),VehicleCockpit=clone(vehicle.CockpitColors or {}),ModuleColors=clone(profile.ModuleColors or {}),Instances=clone(profile.OwnedModuleInstances or {}),Cosmetics=clone(vehicle.Cosmetics)}
	profile.CockpitColors=profile.CockpitColors or {}; profile.CockpitColors.Neon=colour
	vehicle.CockpitColors=clone(profile.CockpitColors)
	for slotId in pairs(profile.InstalledModules or {}) do
		if profile.NeonOwned and profile.NeonOwned[slotId]==true then profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId].Neon=colour end
	end
	if state.Unlocks.Underglow==true then state.Colours.Underglow=colour end
	local ok,result=typeof(captureAll)=="function" and captureAll() or true
	if not ok then
		restore(profile.CockpitColors,snapshot.Cockpit); restore(vehicle.CockpitColors,snapshot.VehicleCockpit)
		restore(profile.ModuleColors,snapshot.ModuleColors); restore(profile.OwnedModuleInstances,snapshot.Instances); vehicle.Cosmetics=snapshot.Cosmetics
		return false,tostring(result or "Neon colour could not be captured.")
	end
	return true,"All owned neon updated."
end

return Runtime
]==]

local projected={}
projected.Schema=schema.Source
if not projected.Schema:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_SCHEMA_V1",1,true) then
	projected.Schema=replaceOnce(projected.Schema,
		'local HttpService = game:GetService("HttpService")',
		'local HttpService = game:GetService("HttpService")\nlocal VehicleCosmetics = require(script.Parent:WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_VEHICLE_COSMETIC_SCHEMA_V1',
		"PlayerProfileSchema catalogue require")
	projected.Schema=replaceOnce(projected.Schema,
		'\tprofile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}',
		'\tprofile.Vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}\n\tfor _, vehicle in pairs(profile.Vehicles) do VehicleCosmetics.NormalizeVehicle(vehicle) end',
		"PlayerProfileSchema vehicle normalisation")
end

projected.Action=garageAction.Source
if not projected.Action:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_ACTION_BRIDGE_V1",1,true) then
	projected.Action=replaceOnce(projected.Action,
		'\tlocal V98_ModuleTransactions = require(script.Parent:WaitForChild("GarageModuleTransactionRuntime")) -- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1',
		'\tlocal V98_ModuleTransactions = require(script.Parent:WaitForChild("GarageModuleTransactionRuntime")) -- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1\n\tlocal V101_VehicleCosmetics = require(script.Parent:WaitForChild("VehicleCosmeticServerRuntime")) -- NTR_CUSTOMISATION_VEHICLE_COSMETIC_ACTION_BRIDGE_V1\n\tlocal V101_CosmeticCatalog = require(V56_kit.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog"))',
		"GarageAction cosmetic requires")
	projected.Action=replaceOnce(projected.Action,
		'\t\tSetThrustColor = true,\n\t\tSpawnVehicle = false,',
		'\t\tSetThrustColor = true,\n\t\tBuyVehicleCosmetic = true,\n\t\tSetVehicleCosmeticColor = true,\n\t\tSetAllNeonColor = true,\n\t\tSpawnVehicle = false,',
		"GarageAction mutation allowlist")
	projected.Action=replaceOnce(projected.Action,
		'\t\t\tThrustColor = profile.ThrustColor,\n\t\t\tSource = sourceName or "PersistencePhase14",',
		'\t\t\tThrustColor = profile.ThrustColor,\n\t\t\tCosmetics = V101_CosmeticCatalog.DefaultState(),\n\t\t\tSource = sourceName or "PersistencePhase14",',
		"GarageAction vehicle default cosmetics")
	projected.Action=replaceOnce(projected.Action,
		'\t\tlocal catalog = {\n\t\t\tCategories = {},\n\t\t\tPaintPresets = {},',
		'\t\tlocal catalog = {\n\t\t\tCategories = {},\n\t\t\tPaintPresets = {},\n\t\t\tVehicleCosmetics = V101_CosmeticCatalog.List(),',
		"GarageAction cosmetic catalogue projection")
	projected.Action=replaceOnce(projected.Action,
		'\tlocal function V56_profileForClient(profile)\n\t\tV56_normalizeProfile(profile)',
		'\tlocal function V56_profileForClient(profile)\n\t\tV56_normalizeProfile(profile)\n\t\tV101_VehicleCosmetics.Ensure(profile)',
		"GarageAction profile cosmetic normalisation")
	projected.Action=replaceOnce(projected.Action,
		'\t\tV56_applyColors(vehicle, profile.CockpitColors, true)\n\n\t\tlocal installedRoot',
		'\t\tV56_applyColors(vehicle, profile.CockpitColors, true)\n\t\tlocal cosmeticVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]\n\t\tV101_CosmeticCatalog.ApplyPresentation(vehicle,cosmeticVehicle)\n\n\t\tlocal installedRoot',
		"GarageAction spawned underglow presentation")
	projected.Action=replaceOnce(projected.Action,
		'\t\t\telseif action == "SetCockpitColor" then',
		'\t\t\telseif action == "BuyVehicleCosmetic" then\n\t\t\t\tlocal cockpit=V56_findCockpit(profile.CurrentCategory,profile.CurrentCockpit)\n\t\t\t\tok,message=V101_VehicleCosmetics.Purchase(profile,tostring(args.CosmeticId or ""),cockpit)\n\t\t\t\tV56_setLeaderstats(player,profile)\n\t\t\telseif action == "SetVehicleCosmeticColor" then\n\t\t\t\tok,message=V101_VehicleCosmetics.SetColour(profile,tostring(args.CosmeticId or ""),args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)\n\t\t\telseif action == "SetAllNeonColor" then\n\t\t\t\tok,message=V101_VehicleCosmetics.SetAllNeon(profile,args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)\n\t\t\telseif action == "SetCockpitColor" then',
		"GarageAction cosmetic actions")
	projected.Action=replaceBetween(projected.Action,
		'\t\t\telseif action == "SetThrustColor" then',
		'\t\t\telseif action == "DespawnVehicle" then',
		'\t\t\telseif action == "SetThrustColor" then\n\t\t\t\t-- Compatibility action remains gated by the vehicle-specific entitlement.\n\t\t\t\tok,message=V101_VehicleCosmetics.SetColour(profile,"ThrustColour",args.Color,function() return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player)) end)\n',
		"GarageAction gated thrust compatibility")
	projected.Action=replaceOnce(projected.Action,
		'\t\t\tif action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" then',
		'\t\t\tif action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" or action == "SetVehicleCosmeticColor" or action == "SetAllNeonColor" then',
		"GarageAction colour response")
end

projected.Preview=previewVehicle.Source
if not projected.Preview:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_PREVIEW_V1",1,true) then
	projected.Preview=replaceOnce(projected.Preview,
		'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")',
		'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")\nlocal VehicleCosmetics=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_VEHICLE_COSMETIC_PREVIEW_V1',
		"Preview ordered cosmetic require")
	projected.Preview=replaceOnce(projected.Preview,
		'PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})\n\tlocal thrustColor=',
		'PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})\n\tlocal currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)\n\tlocal thrustColor=',
		"Preview underglow build")
	local PREVIEW_APPLY=[==[function PreviewVehicleController.ApplyPaint(context)
	local state=context.State; local preview=context.Preview or {}; local profile=state and (state.PreviewProfile or state.Profile); local vehicle=preview.Vehicle
	if not (profile and vehicle and vehicle.Parent) then return false end
	local target=tostring(context.Target or "Cockpit"); local channel=tostring(context.Channel or "Primary"); local color=context.Color
	if typeof(color)~="Color3" then return false end
	profile.CockpitColors=profile.CockpitColors or {}; profile.ModuleColors=profile.ModuleColors or {}
	local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
	if target=="THRUST_COLOR" then
		profile.ThrustColor=color; if currentVehicle then currentVehicle.ThrustColor=color end
		local root=preview.Root; if root then root:SetAttribute("ThrustColor",color); root:SetAttribute("ForceThrustPreview",true) end; vehicle:SetAttribute("ThrustColor",color); return true
	elseif target=="UNDERGLOW" then
		local cosmetics=VehicleCosmetics.NormalizeVehicle(currentVehicle); if cosmetics then cosmetics.Colours.Underglow=color end
	elseif target=="Cockpit" then
		profile.CockpitColors[channel]=color
	elseif target=="WholeVehicle" or target=="ALL" then
		profile.CockpitColors[channel]=color
		for slotId in pairs(profile.InstalledModules or {}) do
			if channel~="Neon" or (profile.NeonOwned or {})[slotId]==true then profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId][channel]=color end
		end
		if channel=="Neon" then local cosmetics=VehicleCosmetics.NormalizeVehicle(currentVehicle); if cosmetics and cosmetics.Unlocks.Underglow then cosmetics.Colours.Underglow=color end end
	else profile.ModuleColors[target]=profile.ModuleColors[target] or {}; profile.ModuleColors[target][channel]=color end
	if currentVehicle then currentVehicle.CockpitColors=profile.CockpitColors end
	local cockpitColors={}; for key,value in pairs(profile.CockpitColors) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116)
	PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile}); VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)
	local installed=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
	if installed then for slotId in pairs(profile.InstalledModules or {}) do local prefix="PREVIEW_"..tostring(slotId).."_"; for _,clone in ipairs(installed:GetChildren()) do if string.sub(clone.Name,1,#prefix)==prefix then PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(profile,slotId),(profile.NeonOwned or {})[slotId]==true,{Profile=profile}) end end end end
	return true
end
]==]
	projected.Preview=replaceBetween(projected.Preview,
		'function PreviewVehicleController.ApplyPaint(context)',
		'return PreviewVehicleController',
		PREVIEW_APPLY,
		"Preview paint application")
end

projected.ThrustPreview=thrustPreview.Source
if not projected.ThrustPreview:find("NTR_CUSTOMISATION_PROTECTED_VEHICLE_LIGHTS_V1",1,true) then
	projected.ThrustPreview=replaceOnce(projected.ThrustPreview,
		'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")',
		'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")\nlocal VehicleCosmetics=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_PROTECTED_VEHICLE_LIGHTS_V1',
		"Thrust preview protected-light require")
	projected.ThrustPreview=replaceOnce(projected.ThrustPreview,
		'elseif isPreviewToggle(object) and not insideRuntimeHost(object,root) then',
		'elseif isPreviewToggle(object) and not VehicleCosmetics.IsProtectedVehicleLight(object) and not insideRuntimeHost(object,root) then',
		"Thrust preview protected-light guard")
end

projected.CachedThrust=cachedThrust.Source
if not projected.CachedThrust:find("NTR_CUSTOMISATION_PROTECTED_VEHICLE_LIGHTS_V1",1,true) then
	projected.CachedThrust=replaceOnce(projected.CachedThrust,
		'local kit = ReplicatedStorage:WaitForChild(KIT_NAME)',
		'local kit = ReplicatedStorage:WaitForChild(KIT_NAME)\nlocal VehicleCosmetics = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_PROTECTED_VEHICLE_LIGHTS_V1',
		"Cached thrust protected-light require")
	projected.CachedThrust=replaceOnce(projected.CachedThrust,
		'\tlocal kind = classifyVFX(object)\n\tif kind and isToggleable(object) then',
		'\tlocal kind = classifyVFX(object)\n\tif VehicleCosmetics.IsProtectedVehicleLight(object) then kind=nil end\n\tif kind and isToggleable(object) then',
		"Cached thrust protected-light guard")
end

projected.UI=moduleShop.Source
if not projected.UI:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_UI_V1",1,true) then
	projected.UI=replaceOnce(projected.UI,
		'PreviewModules={},PreviewProfile=nil,GarageCameraActive=false}',
		'PreviewModules={},PreviewProfile=nil,ReturnWorkshop=nil,GarageCameraActive=false}',
		"UI return route state")
	local HANDLE_PAINT=[==[local function handlePaint(target,channel,color,commit)
	PreviewVehicle.ApplyPaint({State=State,Preview=preview,Target=target,Channel=channel,Color=color})
	if commit~=true then return end
	local result
	if target=="THRUST_COLOR" then result=action:Call("SetVehicleCosmeticColor",{CosmeticId="ThrustColour",Color=color,ReturnProfile=true})
	elseif target=="UNDERGLOW" then result=action:Call("SetVehicleCosmeticColor",{CosmeticId="Underglow",Color=color,ReturnProfile=true})
	elseif target=="WholeVehicle" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true})
	elseif target=="ALL" then
		if channel=="Neon" then result=action:Call("SetAllNeonColor",{Color=color,ReturnProfile=true})
		else result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true}) end
	elseif target=="Cockpit" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="CockpitOnly",ReturnProfile=true})
	else result=action:Call("SetModuleColor",{SlotId=target,Channel=channel,Color=color,ReturnProfile=true}) end
	if not (result and result.Success) then local text=result and result.Message or "Colour could not be saved."; buildPreview(); if workspaceUI.Root.Visible then workspaceUI:Message(text) else warn("[NTR Canonical Garage] "..tostring(text)) end end
end
]==]
	projected.UI=replaceBetween(projected.UI,'local function handlePaint(target,channel,color,commit)','local cameraRenderConnection',HANDLE_PAINT,"UI paint action bridge")
	projected.UI=replaceOnce(projected.UI,
		'local function equipInstance(row,allowReassign)',
		[==[local function compatibleOwnedRows(slotId)
	local s=slot(slotId); if not s then return {} end
	local _,installedInstance=installedForSlot(slotId)
	return ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
end
local function returnFromModuleRoute()
	local route=State.ReturnWorkshop; State.ReturnWorkshop=nil
	if not route then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; renderBuild(); return end
	State.CustomizeTarget=route.Target
	if route.Workshop=="Upgrade" then State.CustomizeMode="Upgrades"; renderUpgrade() else State.CustomizeMode="Overview"; renderPaintShop() end
end
local function routeToAddModule(slotId,workshop)
	clearTransientModulePreview(); State.ReturnWorkshop={Target=slotId,Workshop=workshop}; State.SelectedSlot=slotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(slotId); renderBuild()
end
local function missingModuleCard(c,target,workshop)
	local owned=#compatibleOwnedRows(target)>0
	table.insert(c.Cards,{Id="__MODULE_UNLOCK",EmptyPlus=true,DisplayName=owned and "EQUIP TO UNLOCK" or "BUY TO UNLOCK",OnSelect=function() routeToAddModule(target,workshop) end})
end
local function equipInstance(row,allowReassign)]==],
		"UI module return helpers")
	projected.UI=replaceOnce(projected.UI,
		'\t\tbuildPreview()\n\t\trenderBuild()\n\telse',
		'\t\tbuildPreview()\n\t\tif State.ReturnWorkshop then returnFromModuleRoute() else renderBuild() end\n\telse',
		"UI owned equip return route")
	projected.UI=replaceOnce(projected.UI,
		'\telseif State.ModuleMode=="Sources" then\n\t\ttable.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end})\n\t\ttable.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})',
		'\telseif State.ModuleMode=="Sources" then\n\t\tlocal ownedRows=compatibleOwnedRows(State.SelectedSlot)\n\t\tif #ownedRows==0 then table.insert(c.Cards,{Id="Owned",CardKind="Listing",DisplayName="Owned Modules",Footer="BUY MODULE",SemanticState="Locked",LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon"))})\n\t\telse table.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end}) end\n\t\ttable.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})',
		"UI locked Owned Modules source")
	projected.UI=replaceOnce(projected.UI,
		'clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild(); message("Module purchased and equipped.")',
		'clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); if State.ReturnWorkshop then returnFromModuleRoute() else renderBuild() end; message("Module purchased and equipped.")',
		"UI purchased module return route")
	projected.UI=replaceOnce(projected.UI,
		'\t\telseif State.ModuleMode=="Sources" then\n\t\t\tState.ModuleMode="Slots"\n\t\t\tbuildPreview()\n\t\t\trenderBuild()',
		'\t\telseif State.ModuleMode=="Sources" then\n\t\t\tif State.ReturnWorkshop then returnFromModuleRoute() else State.ModuleMode="Slots"; buildPreview(); renderBuild() end',
		"UI source Back return route")
	projected.UI=replaceOnce(projected.UI,
		'\tif not moduleId then\n\t\tc.EmptyMessage="INSTALL A MODULE IN ADD MODULES FIRST"\n\t\treturn\n\tend',
		'\tif not moduleId then missingModuleCard(c,target,"Upgrade"); return end',
		"UI upgrade missing module card")
	projected.UI=replaceOnce(projected.UI,
		'local function paintChannels(target)\n\tif target=="THRUST_COLOR" then return {"ThrustColor"} end\n\tif target=="UNDERGLOW" then return {"Neon"} end\n\tif target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end\n\tif target=="ALL" then return {"Primary","Secondary","Detail"} end',
		'local function paintChannels(target)\n\tif target=="THRUST_COLOR" then return {"ThrustColor"} end\n\tif target=="UNDERGLOW" then return {"Underglow"} end\n\tif target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end\n\tif target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end',
		"UI paint channels")
	projected.UI=replaceOnce(projected.UI,
		'\t\telseif target=="UNDERGLOW" then\n\t\t\tvalue=firstBulkNeon()',
		'\t\telseif target=="UNDERGLOW" then\n\t\t\tlocal vehicle=State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]; value=vehicle and vehicle.Cosmetics and vehicle.Cosmetics.Colours and vehicle.Cosmetics.Colours.Underglow',
		"UI underglow colour")
	local PAINT_RAIL=[==[local function currentCosmetics()
	local vehicle=State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]
	return vehicle and vehicle.Cosmetics
end
local function cosmeticOwned(id) local state=currentCosmetics(); return state and state.Unlocks and state.Unlocks[id]==true end
local function cosmeticDefinition(id) for _,item in ipairs((State.Catalog and State.Catalog.VehicleCosmetics) or {}) do if item.CosmeticId==id then return item end end end
local function modeForPaintTarget(id)
	if id=="ALL" or id=="Cockpit" then return "Colour" end
	if id=="THRUST_COLOR" then return cosmeticOwned("ThrustColour") and "Colour" or "Overview" end
	if id=="UNDERGLOW" then return cosmeticOwned("Underglow") and "Colour" or "Overview" end
	return "Overview"
end
local function paintTargetRail(c,target)
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Customise")) do
		local id=art.TargetId
		local special=id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR"
		local physical=slot(id)~=nil
		if special or physical then
			table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=target==id,Muted=physical and not installedForSlot(id),OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id; State.CustomizeMode=modeForPaintTarget(id); State.SelectedPaintAction=nil; local channels=paintChannels(id); State.SelectedColorChannel=channels[1]; if physical then section(id) else section("ALL") end; renderPaintShop() end})
			if id=="THRUST_COLOR" then
				table.insert(c.LeftItems,{Id="UNDERGLOW",Text="Underglow",Image=navIcon("UnderglowIcon"),ImageZoom=1.04,Selected=target=="UNDERGLOW",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="UNDERGLOW"; State.CustomizeMode=modeForPaintTarget("UNDERGLOW"); State.SelectedPaintAction=nil; State.SelectedColorChannel="Underglow"; section("ALL"); renderPaintShop() end})
			end
		end
	end
end

local function addCosmeticPurchaseCard(c,target,id,actionIconScale)
	local definition=cosmeticDefinition(id); if not definition or definition.Available==false then c.EmptyMessage="NOT AVAILABLE FOR THIS VEHICLE"; return end
	local price=math.max(0,math.floor(tonumber(definition.Price) or 0)); local affordable=(tonumber(State.Profile.Cash) or 0)>=price; local selected=State.SelectedPaintAction==id
	table.insert(c.Cards,{Id=id,Image=imageValue(definition.Icon),ImageZoom=actionIconScale,DisplayName=definition.DisplayName,Badge=Shared.FormatMoney(price),BadgeColor=affordable and Color3.fromRGB(89,255,102) or Color3.fromRGB(225,56,70),Selected=selected,ActionText=selected and "BUY" or nil,OnSelect=function() State.SelectedPaintAction=id; renderPaintShop() end,OnAction=function()
		local result=action:Call("BuyVehicleCosmetic",{CosmeticId=id}); State.SelectedPaintAction=nil
		if result and result.Success then State.CustomizeMode="Colour"; local channels=paintChannels(target); State.SelectedColorChannel=channels[1]; buildPreview(); renderPaintShop() else renderPaintShop(); message(result and result.Message or "Purchase could not be completed.") end
	end})
end

]==]
	projected.UI=replaceBetween(projected.UI,'local function paintTargetRail(c,target)','local function addPaintOverviewCards',PAINT_RAIL,"UI paint target and purchase helpers")
	projected.UI=replaceOnce(projected.UI,
		'\tlocal physical=slot(target)~=nil\n\tif physical and not installedForSlot(target) then\n\t\tc.EmptyMessage="INSTALL A MODULE IN ADD MODULES FIRST"\n\t\treturn\n\tend\n\tif target=="UNDERGLOW" and not hasOwnedNeon() then\n\t\tc.EmptyMessage="BUY NEON LIGHTS FOR A MODULE FIRST"\n\t\treturn\n\tend\n\ttable.insert(c.Cards,{Id="Paint"',
		'\tlocal physical=slot(target)~=nil\n\tif physical and not installedForSlot(target) then missingModuleCard(c,target,"Paint"); return end\n\tif target=="THRUST_COLOR" then addCosmeticPurchaseCard(c,target,"ThrustColour",actionIconScale); return end\n\tif target=="UNDERGLOW" then addCosmeticPurchaseCard(c,target,"Underglow",actionIconScale); return end\n\ttable.insert(c.Cards,{Id="Paint"',
		"UI special cosmetics and missing paint module")
	projected.UI=replaceOnce(projected.UI,
		'\t\tc.OnColor=function(channel,color,commit) handlePaint(target=="UNDERGLOW" and "ALL" or target,channel,color,commit) end',
		'\t\tc.OnColor=function(channel,color,commit) handlePaint(target,channel,color,commit) end',
		"UI underglow paint target")
	projected.UI=replaceOnce(projected.UI,
		'\t\tif State.CustomizeMode=="Colour" then\n\t\t\tState.CustomizeMode="Overview"\n\t\t\trenderPaintShop()',
		'\t\tif State.CustomizeMode=="Colour" then\n\t\t\tif target=="ALL" or target=="Cockpit" or target=="THRUST_COLOR" or target=="UNDERGLOW" then buildPreview(); renderHub() else State.CustomizeMode="Overview"; renderPaintShop() end',
		"UI direct slider Back")
	projected.UI=replaceAllPlain(projected.UI,
		'State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; State.SelectedPaintAction=nil; renderPaintShop()',
		'State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; State.SelectedPaintAction=nil; State.SelectedColorChannel="Primary"; renderPaintShop()',
		2,
		"UI direct All paint entry")
	projected.UI=replaceOnce(projected.UI,
		'-- NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1',
		'-- NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1\n\t-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_UI_V1',
		"UI revision marker")
end

projected.OwnedDisplay=ownedDisplay.Source
if not projected.OwnedDisplay:find("NTR_CUSTOMISATION_UNDERGLOW_DISPLAY_V1",1,true) then
	projected.OwnedDisplay=replaceOnce(projected.OwnedDisplay,
		'local categories=ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles:WaitForChild("Categories")',
		'local categories=ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles:WaitForChild("Categories")\nlocal VehicleCosmetics=require(ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_UNDERGLOW_DISPLAY_V1',
		"Owned display cosmetic require")
	projected.OwnedDisplay=replaceOnce(projected.OwnedDisplay,
		'\tlocal metrics=Runtime.SanitizeForDisplay(display); local old=parent:FindFirstChild("DisplayVehicle_"..slotId);',
		'\tlocal metrics=Runtime.SanitizeForDisplay(display); VehicleCosmetics.ApplyPresentation(display,vehicle); local old=parent:FindFirstChild("DisplayVehicle_"..slotId);',
		"Owned display underglow apply")
end

projected.LegacyDisplay=legacyDisplay.Source
if not projected.LegacyDisplay:find("NTR_CUSTOMISATION_UNDERGLOW_DISPLAY_V1",1,true) then
	projected.LegacyDisplay=replaceOnce(projected.LegacyDisplay,
		'local categoriesRoot = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")',
		'local categoriesRoot = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")\nlocal VehicleCosmetics = require(kit.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_UNDERGLOW_DISPLAY_V1',
		"Legacy display cosmetic require")
	projected.LegacyDisplay=replaceOnce(projected.LegacyDisplay,
		'\tsanitizeDisplay(display)\n\n\tlocal pad',
		'\tsanitizeDisplay(display)\n\tVehicleCosmetics.ApplyPresentation(display,vehicle)\n\n\tlocal pad',
		"Legacy display underglow apply")
end

for name,source in pairs(projected) do compile(source,name.."_Projected") end
compile(CATALOG_SOURCE,"VehicleCosmeticCatalog_Projected")
compile(SERVER_RUNTIME_SOURCE,"VehicleCosmeticServerRuntime_Projected")

local created={}
local attributeSnapshots={}
local sourceSnapshots={}
local objectSnapshots={}

local function rememberAttributes(instance)
	if not attributeSnapshots[instance] then attributeSnapshots[instance]=attributesSnapshot(instance) end
end
local function rememberSource(instance)
	if not sourceSnapshots[instance] then sourceSnapshots[instance]=instance.Source end
end

local ok,problem=pcall(function()
	local cosmeticConfig=ensureFolder(replacement,"VehicleCosmetics",created)
	local defaults={
		ThrustColour={DisplayName="Thrust Colour",Price=5000,Icon=tostring(replacement:GetAttribute("ModuleColourIcon") or ""),DefaultColor=Color3.new(1,1,1),Available=true,SortOrder=10},
		Underglow={DisplayName="Underglow",Price=5000,Icon=tostring((replacement:FindFirstChild("NavigationIcons") and replacement.NavigationIcons:GetAttribute("UnderglowIcon")) or replacement:GetAttribute("ModuleNeonIcon") or ""),DefaultColor=Color3.new(1,1,1),Available=true,SortOrder=20,DebugEnabled=false,LightPropertyMode="AuthoredPerVehicle"},
	}
	for id,values in pairs(defaults) do
		local folder=ensureFolder(cosmeticConfig,id,created); rememberAttributes(folder)
		for name,value in pairs(values) do if folder:GetAttribute(name)==nil then folder:SetAttribute(name,value) end end
		if id=="Underglow" then
			-- Retire V1.1 global light styling. These properties now live on
			-- each authored SurfaceLight inside its cockpit template.
			for _,name in ipairs({"Brightness","Range","Angle","MaxEmitters"}) do folder:SetAttribute(name,nil) end
		end
		folder:SetAttribute("CosmeticId",id)
	end
	rememberAttributes(cosmeticConfig); cosmeticConfig:SetAttribute("SchemaVersion",1); cosmeticConfig:SetAttribute("Revision",REVISION)

	local catalog=dataModules:FindFirstChild("VehicleCosmeticCatalog")
	if catalog then assert(catalog:IsA("ModuleScript"),catalog:GetFullName().." must be a ModuleScript"); rememberSource(catalog); rememberAttributes(catalog) else catalog=Instance.new("ModuleScript"); catalog.Name="VehicleCosmeticCatalog"; catalog.Parent=dataModules; table.insert(created,catalog) end
	catalog.Source=CATALOG_SOURCE; catalog:SetAttribute("Revision",REVISION)

	local serverRuntime=garageServices:FindFirstChild("VehicleCosmeticServerRuntime")
	if serverRuntime then assert(serverRuntime:IsA("ModuleScript"),serverRuntime:GetFullName().." must be a ModuleScript"); rememberSource(serverRuntime); rememberAttributes(serverRuntime) else serverRuntime=Instance.new("ModuleScript"); serverRuntime.Name="VehicleCosmeticServerRuntime"; serverRuntime.Parent=garageServices; table.insert(created,serverRuntime) end
	serverRuntime.Source=SERVER_RUNTIME_SOURCE; serverRuntime:SetAttribute("Revision",REVISION)

	local function hasUnderglowContainer(object)
		local current=object
		while current do
			if current.Name=="UNDERGLOW_MOUNT_DoNotRename" or current.Name=="UNDERGLOW_EMITTERS_DoNotRename" or current:GetAttribute("VehicleCosmeticId")=="Underglow" then return true end
			current=current.Parent
		end
		return false
	end
	local function authoredUnderglowLight(object)
		return object:IsA("SurfaceLight") and (
			object:GetAttribute("VehicleCosmeticId")=="Underglow"
			or object:GetAttribute("LightChannel")=="Underglow"
			or hasUnderglowContainer(object)
		)
	end

	local cockpitCount,emitterCount,emitterPartCount,largestEmitterCount=0,0,0,0
	for _,cockpit in ipairs(categories:GetDescendants()) do
		if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId")~=nil then
			local root=cockpit:FindFirstChild("CockpitRoot_DoNotRename",true)
			assert(root and root:IsA("BasePart"),cockpit:GetFullName().." CockpitRoot_DoNotRename missing")
			local emitters=ensureFolder(root,"UNDERGLOW_EMITTERS_DoNotRename",created)
			rememberAttributes(emitters)
			emitters:SetAttribute("VehicleCosmeticId","Underglow")
			emitters:SetAttribute("EmitterContractVersion",2)
			local cockpitEmitters=0
			for _,object in ipairs(cockpit:GetDescendants()) do
				if authoredUnderglowLight(object) then
					if not objectSnapshots[object] then objectSnapshots[object]={Kind="SurfaceLight",Attributes=attributesSnapshot(object),Enabled=object.Enabled} end
					object:SetAttribute("VehicleCosmeticId","Underglow"); object:SetAttribute("PaintChannel","Underglow"); object:SetAttribute("LightChannel","Underglow")
					-- Templates stay dark until the current saved vehicle owns
					-- underglow. Every other light property remains authored.
					object.Enabled=false
					local part=object.Parent
					if part and part:IsA("BasePart") then
						if not objectSnapshots[part] then objectSnapshots[part]={Kind="BasePart",Attributes=attributesSnapshot(part),Anchored=part.Anchored,CanCollide=part.CanCollide,CanTouch=part.CanTouch,CanQuery=part.CanQuery,Massless=part.Massless,Transparency=part.Transparency,CastShadow=part.CastShadow} end
						part:SetAttribute("VehicleCosmeticId","Underglow"); part:SetAttribute("PaintChannel","Underglow")
						part.Anchored=false; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false; part.Massless=true; part.Transparency=1; part.CastShadow=false
						emitterPartCount+=1
					end
					cockpitEmitters+=1
					emitterCount+=1
				end
			end
			assert(cockpitEmitters>0,cockpit:GetFullName().." has no authored underglow SurfaceLight")
			largestEmitterCount=math.max(largestEmitterCount,cockpitEmitters)
			cockpitCount+=1
		end
	end
	assert(cockpitCount>0 and emitterCount>=cockpitCount,"No cockpit templates received the underglow emitter contract")

	for instance,source in pairs({
		[schema]=projected.Schema,[garageAction]=projected.Action,[previewVehicle]=projected.Preview,[thrustPreview]=projected.ThrustPreview,
		[cachedThrust]=projected.CachedThrust,[moduleShop]=projected.UI,[ownedDisplay]=projected.OwnedDisplay,[legacyDisplay]=projected.LegacyDisplay,
	}) do rememberSource(instance); rememberAttributes(instance); instance.Source=source; instance:SetAttribute("VehicleCosmeticsRevision",REVISION); compile(instance.Source,instance.Name.."_Committed") end

	assert(schema.Source:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_SCHEMA_V1",1,true),"Schema bridge missing")
	assert(garageAction.Source:find("BuyVehicleCosmetic",1,true) and garageAction.Source:find("SetAllNeonColor",1,true),"Server actions missing")
	assert(moduleShop.Source:find('DisplayName=owned and "EQUIP TO UNLOCK" or "BUY TO UNLOCK"',1,true),"Empty module CTA missing")
	assert(moduleShop.Source:find('if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end',1,true),"All Neon channel missing")
	assert(thrustPreview.Source:find("IsProtectedVehicleLight",1,true) and cachedThrust.Source:find("IsProtectedVehicleLight",1,true),"Protected light guards missing")
	assert(catalog.Source:find("NTR_CUSTOMISATION_VEHICLE_COSMETIC_CATALOG_V1_2_AUTHORED_LIGHT_PROPERTIES",1,true) and catalog.Source:find("Runtime owns only the saved player colour",1,true),"Authored light-property catalogue missing")
	assert(catalog.Source:find("ApplyPresentation",1,true) and serverRuntime.Source:find("SetAllNeon",1,true),"Cosmetic runtimes missing")
	print(TAG.." EMITTER AUDIT cockpits="..cockpitCount.." lights="..emitterCount.." parts="..emitterPartCount.." largestVehicleEmitterCount="..largestEmitterCount)
	if largestEmitterCount>4 then warn(TAG.." MOBILE WARN: a cockpit has "..largestEmitterCount.." underglow SurfaceLights; profile that vehicle on low-end mobile.") end
end)

if not ok then
	pcall(function()
		for instance,source in pairs(sourceSnapshots) do if instance.Parent then instance.Source=source end end
		for instance,snapshot in pairs(attributeSnapshots) do if instance.Parent then restoreAttributes(instance,snapshot) end end
		for instance,snapshot in pairs(objectSnapshots) do
			if instance.Parent then
				restoreAttributes(instance,snapshot.Attributes)
				if snapshot.Kind=="SurfaceLight" and instance:IsA("SurfaceLight") then instance.Enabled=snapshot.Enabled
				elseif snapshot.Kind=="BasePart" and instance:IsA("BasePart") then instance.Anchored=snapshot.Anchored; instance.CanCollide=snapshot.CanCollide; instance.CanTouch=snapshot.CanTouch; instance.CanQuery=snapshot.CanQuery; instance.Massless=snapshot.Massless; instance.Transparency=snapshot.Transparency; instance.CastShadow=snapshot.CastShadow end
			end
		end
		for index=#created,1,-1 do local instance=created[index]; if instance.Parent then instance:Destroy() end end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS revision="..REVISION.." sources=8 emitterContract=authored-per-vehicle cosmetics=ThrustColour/Underglow allNeon=atomic")
print(TAG.." READY: restart Studio, then verify each cockpit preserves authored Brightness/Range/Angle/Face/Shadows on preview/live/display vehicles, protected front/rear lights, mobile quality, Drive, vehicle switch, and save/rejoin.")
