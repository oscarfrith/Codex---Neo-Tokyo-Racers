-- Neo Tokyo Racers - Canonical owned garage replacement
-- NTR_OWNED_GARAGE_CANONICAL_REPLACEMENT_PHASE4_MANAGEMENT_WORKSPACE_STAGING_V3
-- PHASE 4 EXECUTION PATH SUPERSEDED: use
-- scripts/roblox_owned_garage_phase4_missing_objects_recovery.lua against the
-- confirmed partial Phase 4 Studio state. Retained only as Phases 1-3 history.
--
-- CURRENT STATUS: Phase 4 inactive management-workspace staging, no-yield V3.
-- This file is the one canonical installer for the complete approved scope.
-- Phases 1-4 install no active Script/LocalScript, change no profile, do not
-- switch HOME, and do not touch the legacy GarageInstances runtime pool.
-- Future approved continues extend this same file; do not create patch scripts.
--
-- Run only in Studio Edit mode.

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run the owned garage canonical installer in Studio Edit mode.")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Owned Garage Canonical]"
local REVISION = "NTR_OWNED_GARAGE_PHASE4_MANAGEMENT_WORKSPACE_STAGING_V3"
local INSTALL_RUN_ID = HttpService:GenerateGUID(false)
local TESTER_USER_ID = 7915427645

local function findPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do current = current and current:FindFirstChild(segment) end
	return current
end

local function ensure(parent, className, name)
	local object = parent:FindFirstChild(name)
	if object and not object:IsA(className) then error(object:GetFullName() .. " must be " .. className) end
	if not object then object = Instance.new(className); object.Name = name; object.Parent = parent end
	return object
end

local function sourceOf(object)
	local ok, source = pcall(function() return object.Source end)
	return ok and source or nil
end

local function has(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local dataModules = assert(findPath(kit, "Shared.Modules.Data"), "Shared.Modules.Data missing")
local garageServices = assert(findPath(ServerScriptService, "NeoTokyoRacers.Services.Garage"), "Garage services root missing")
local profileService = assert(findPath(ServerScriptService, "NeoTokyoRacers.Services.Player.ProfileService_Active"), "ProfileService_Active missing")
local actionService = assert(garageServices:FindFirstChild("GarageActionController_Shadow_Disabled"), "Garage action owner missing")
local desktopHud = assert(findPath(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active"), "Desktop HUD missing")
local mobileHud = assert(findPath(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active"), "Mobile HUD missing")
local uiControllers = assert(findPath(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"), "UI controllers root missing")

local profileSource = assert(sourceOf(profileService), "ProfileService Source unavailable")
local actionSource = assert(sourceOf(actionService), "Garage action Source unavailable")
local desktopSource = assert(sourceOf(desktopHud), "Desktop HUD Source unavailable")
local mobileSource = assert(sourceOf(mobileHud), "Mobile HUD Source unavailable")

for _, marker in ipairs({
	'ensureBindableFunction(bindings, "GetProfile")',
	'ensureBindableFunction(bindings, "MarkDirty")',
	'ensureBindableFunction(bindings, "ImportProfileSnapshot")',
}) do assert(has(profileSource, marker), "ProfileService baseline mismatch: " .. marker) end
for _, marker in ipairs({
	"local function V91_spawnOwnedVehicleFromFreeRoam",
	"local function V92_despawnVehicle",
	'elseif action == "SpawnOwnedVehicleFromFreeRoam"',
}) do assert(has(actionSource, marker), "Garage action baseline mismatch: " .. marker) end
assert(has(desktopSource, 'actionIcon("Garage", "GarageIcon", "HOME"'), "Desktop HOME baseline mismatch")
assert(has(mobileSource, "garageButton.Activated:Connect"), "Mobile HOME baseline mismatch")
for name,marker in pairs({OwnedGaragePropertyCatalog="NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1",OwnedGarageInteriorStyleCatalog="NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1",OwnedGarageProfileRuntime="NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1",OwnedGarageDisplayAssignmentRuntime="NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V1",OwnedGarageInteriorRuntime="NTR_OWNED_GARAGE_INTERIOR_RUNTIME_V1",OwnedGarageDisplayRuntime="NTR_OWNED_GARAGE_DISPLAY_RUNTIME_V1",OwnedGarageManagementRuntime="NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1",OwnedGarageBrowserController="NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1",OwnedGarageWorkspaceController="NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1"}) do
	local isData=name=="OwnedGaragePropertyCatalog" or name=="OwnedGarageInteriorStyleCatalog"; local isUi=name=="OwnedGarageBrowserController" or name=="OwnedGarageWorkspaceController"; local parent=isData and dataModules or (isUi and uiControllers or garageServices); local object=parent:FindFirstChild(name)
	if object then assert(object:IsA("ModuleScript") and has(sourceOf(object),marker),name.." is not the confirmed Phase 1 owner") end
end

local catalogSource = [==[
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1
local Catalog={}
local properties={
	{
		PropertyId="STARTER_TWO_BAY",
		DisplayName="Kanda Two-Bay",
		District="Kanda Stack Apartments",
		Description="A private two-bay workshop with vehicle display, interior customisation and secure access.",
		Image="",
		TemplateId="StarterTwoBay",
		DisplaySpaceIds={"Space01","Space02"},
		VehicleCapacityContribution=2,
		Price=0,
		Available=true,
		Starter=true,
		SortOrder=10,
	},
}
local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
function Catalog.List()
	local result=clone(properties)
	table.sort(result,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end return a.PropertyId<b.PropertyId end)
	return result
end
function Catalog.ById(propertyId)
	propertyId=tostring(propertyId or "")
	for _,property in ipairs(properties) do if property.PropertyId==propertyId then return clone(property) end end
	return nil
end
function Catalog.SpaceIds(propertyId)
	local property=Catalog.ById(propertyId); return property and clone(property.DisplaySpaceIds) or {}
end
function Catalog.IsSpace(propertyId,slotId)
	for _,candidate in ipairs(Catalog.SpaceIds(propertyId)) do if candidate==tostring(slotId or "") then return true end end
	return false
end
return Catalog
]==]

local interiorStyleCatalogSource = [==[
-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
local Catalog={}
local styles={
	{StyleId="FLOOR_MIDNIGHT",SurfaceGroup="Floor",DisplayName="Midnight Metal",Color=Color3.fromRGB(18,23,31),Material="Metal",SortOrder=10,Default=true},
	{StyleId="FLOOR_GRAPHITE",SurfaceGroup="Floor",DisplayName="Graphite",Color=Color3.fromRGB(48,54,64),Material="Metal",SortOrder=11},
	{StyleId="FLOOR_CLEAN",SurfaceGroup="Floor",DisplayName="Clean Composite",Color=Color3.fromRGB(115,122,132),Material="SmoothPlastic",SortOrder=12},
	{StyleId="WALL_MIDNIGHT",SurfaceGroup="Walls",DisplayName="Midnight Walls",Color=Color3.fromRGB(27,34,45),Material="Metal",SortOrder=20,Default=true},
	{StyleId="WALL_CONCRETE",SurfaceGroup="Walls",DisplayName="Urban Concrete",Color=Color3.fromRGB(76,79,84),Material="Concrete",SortOrder=21},
	{StyleId="WALL_WHITE",SurfaceGroup="Walls",DisplayName="Studio White",Color=Color3.fromRGB(170,176,184),Material="SmoothPlastic",SortOrder=22},
	{StyleId="ROOF_DARK",SurfaceGroup="Roof",DisplayName="Dark Roof",Color=Color3.fromRGB(12,16,23),Material="Metal",SortOrder=30,Default=true},
	{StyleId="ROOF_GRAPHITE",SurfaceGroup="Roof",DisplayName="Graphite Roof",Color=Color3.fromRGB(50,56,67),Material="Metal",SortOrder=31},
	{StyleId="PAD_CYAN",SurfaceGroup="DisplayPads",DisplayName="Cyan Display Pads",Color=Color3.fromRGB(24,61,74),Material="Metal",SortOrder=40,Default=true},
	{StyleId="PAD_MAGENTA",SurfaceGroup="DisplayPads",DisplayName="Magenta Display Pads",Color=Color3.fromRGB(82,28,66),Material="Metal",SortOrder=41},
	{StyleId="PAD_GUNMETAL",SurfaceGroup="DisplayPads",DisplayName="Gunmetal Display Pads",Color=Color3.fromRGB(42,47,55),Material="Metal",SortOrder=42},
	{StyleId="DOOR_STEEL",SurfaceGroup="Doors",DisplayName="Steel Door",Color=Color3.fromRGB(44,54,70),Material="Metal",SortOrder=50,Default=true},
	{StyleId="DOOR_RED",SurfaceGroup="Doors",DisplayName="Signal Red Door",Color=Color3.fromRGB(126,42,52),Material="Metal",SortOrder=51},
}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
function Catalog.List() local result=clone(styles); table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.ById(styleId) for _,style in ipairs(styles) do if style.StyleId==tostring(styleId or "") then return clone(style) end end; return nil end
function Catalog.ForSurface(surfaceGroup) local result={}; for _,style in ipairs(styles) do if style.SurfaceGroup==tostring(surfaceGroup or "") then table.insert(result,clone(style)) end end; table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.DefaultStyles() local result={}; for _,style in ipairs(styles) do if style.Default then result[style.SurfaceGroup]=style.StyleId end end; return result end
function Catalog.IsValid(surfaceGroup,styleId) local style=Catalog.ById(styleId); return style~=nil and style.SurfaceGroup==tostring(surfaceGroup or "") end
return Catalog
]==]

local profileRuntimeSource = [==[
-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
-- Resolve lazily so the module can be compiled before the catalog is installed.
local CatalogCache
local function Catalog()
	if not CatalogCache then
		local source=script:FindFirstChild("OwnedGaragePropertyCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGaragePropertyCatalog")
		CatalogCache=require(source)
	end
	return CatalogCache
end
local StyleCatalogCache
local function StyleCatalog()
	if not StyleCatalogCache then
		local source=script:FindFirstChild("OwnedGarageInteriorStyleCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")
		StyleCatalogCache=require(source)
	end
	return StyleCatalogCache
end
local Runtime={SchemaVersion=2}

local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
local function defaultProperty(propertyId)
	local display={}; for _,slotId in ipairs(Catalog().SpaceIds(propertyId)) do display[slotId]=false end
	return {Owned=true,DisplaySpaces=display,AccessMode="Private",InvitedUserIds={},Customisation={SurfaceStyles=StyleCatalog().DefaultStyles(),Decorations={}}}
end
function Runtime.DefaultGarage()
	return {SchemaVersion=Runtime.SchemaVersion,Revision=0,ActiveGarageId="STARTER_TWO_BAY",Properties={STARTER_TWO_BAY=defaultProperty("STARTER_TWO_BAY")}}
end
function Runtime.Ensure(profile,reset)
	assert(type(profile)=="table","Profile table required")
	if reset==true or type(profile.Garage)~="table" or tonumber(profile.Garage.SchemaVersion)~=Runtime.SchemaVersion then profile.Garage=Runtime.DefaultGarage() end
	local garage=profile.Garage; garage.Properties=type(garage.Properties)=="table" and garage.Properties or {}; garage.Revision=math.max(0,math.floor(tonumber(garage.Revision) or 0))
	for _,definition in ipairs(Catalog().List()) do
		local property=garage.Properties[definition.PropertyId]
		if definition.Starter and type(property)~="table" then property=defaultProperty(definition.PropertyId); garage.Properties[definition.PropertyId]=property end
		if type(property)=="table" then
			property.Owned=property.Owned==true; property.DisplaySpaces=type(property.DisplaySpaces)=="table" and property.DisplaySpaces or {}; property.InvitedUserIds=type(property.InvitedUserIds)=="table" and property.InvitedUserIds or {}; property.Customisation=type(property.Customisation)=="table" and property.Customisation or {SurfaceStyles={},Decorations={}}
			property.Customisation.SurfaceStyles=type(property.Customisation.SurfaceStyles)=="table" and property.Customisation.SurfaceStyles or {}; property.Customisation.Decorations=type(property.Customisation.Decorations)=="table" and property.Customisation.Decorations or {}; for surfaceGroup,styleId in pairs(StyleCatalog().DefaultStyles()) do if not StyleCatalog().IsValid(surfaceGroup,property.Customisation.SurfaceStyles[surfaceGroup]) then property.Customisation.SurfaceStyles[surfaceGroup]=styleId end end
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then property.AccessMode="Private" end
			for _,slotId in ipairs(definition.DisplaySpaceIds) do if property.DisplaySpaces[slotId]==nil then property.DisplaySpaces[slotId]=false end end
			for slotId in pairs(property.DisplaySpaces) do if not Catalog().IsSpace(definition.PropertyId,slotId) then property.DisplaySpaces[slotId]=nil end end
		end
	end
	if not (garage.Properties[garage.ActiveGarageId] and garage.Properties[garage.ActiveGarageId].Owned) then garage.ActiveGarageId="STARTER_TWO_BAY" end
	return garage
end
function Runtime.Validate(profile)
	local garage=Runtime.Ensure(profile,false); local vehicles=type(profile.Vehicles)=="table" and profile.Vehicles or {}; local seen={}
	for garageId,property in pairs(garage.Properties) do
		if property.Owned then
			if not Catalog().ById(garageId) then return false,"Unknown property "..tostring(garageId) end
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then return false,"Invalid access mode: "..tostring(property.AccessMode) end
			for surfaceGroup,styleId in pairs(property.Customisation.SurfaceStyles or {}) do if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Invalid interior style: "..tostring(surfaceGroup).."/"..tostring(styleId) end end
			for slotId,vehicleId in pairs(property.DisplaySpaces) do
				if not Catalog().IsSpace(garageId,slotId) then return false,"Unknown display space "..garageId.."/"..slotId end
				if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then
					vehicleId=tostring(vehicleId); if not vehicles[vehicleId] then return false,"Display vehicle missing: "..vehicleId end
					if seen[vehicleId] then return false,"Vehicle displayed twice: "..vehicleId end; seen[vehicleId]=garageId.."/"..slotId
				end
			end
		end
	end
	return true,{Displayed=seen,Revision=garage.Revision}
end
function Runtime.Snapshot(profile) return clone(Runtime.Ensure(profile,false)) end
function Runtime.Restore(profile,snapshot) profile.Garage=clone(snapshot) end
function Runtime.State(profile)
	local garage=Runtime.Ensure(profile,false); local state=clone(garage); state.SchemaVersion=Runtime.SchemaVersion; return state
end
function Runtime.Assign(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local vehicleId=tostring(args.VehicleId or "")
	local property=garage.Properties[garageId]; if not (property and property.Owned) then return false,"Garage is not owned." end
	if not Catalog().IsSpace(garageId,slotId) then return false,"Display space is invalid." end
	if not (type(profile.Vehicles)=="table" and profile.Vehicles[vehicleId]) then return false,"Vehicle is not owned." end
	for _,other in pairs(garage.Properties) do for otherSlot,assigned in pairs(other.DisplaySpaces or {}) do if tostring(assigned or "")==vehicleId then other.DisplaySpaces[otherSlot]=false end end end
	property.DisplaySpaces[slotId]=vehicleId; garage.Revision+=1
	local valid,message=Runtime.Validate(profile); if not valid then return false,message end
	return true,"Display assignment updated."
end
function Runtime.Clear(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned and Catalog().IsSpace(garageId,slotId)) then return false,"Display space is invalid." end
	property.DisplaySpaces[slotId]=false; garage.Revision+=1; return true,"Display space cleared."
end
function Runtime.SetActive(profile,garageId)
	local garage=Runtime.Ensure(profile,false); garageId=tostring(garageId or ""); if not (garage.Properties[garageId] and garage.Properties[garageId].Owned) then return false,"Garage is not owned." end
	garage.ActiveGarageId=garageId; garage.Revision+=1; return true,"Active garage updated."
end
function Runtime.SetSurfaceStyle(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local surfaceGroup=tostring(args.SurfaceGroup or ""); local styleId=tostring(args.StyleId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Interior style is invalid." end
	property.Customisation.SurfaceStyles[surfaceGroup]=styleId; garage.Revision+=1; return true,"Interior style updated."
end
function Runtime.SetAccessMode(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local accessMode=tostring(args.AccessMode or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if accessMode~="Private" and accessMode~="FriendsOnly" and accessMode~="InviteOnly" and accessMode~="Public" then return false,"Access mode is invalid." end
	property.AccessMode=accessMode; garage.Revision+=1; return true,"Access mode updated."
end
function Runtime.NewRequestId() return HttpService:GenerateGUID(false) end
return Runtime
]==]

local assignmentSource = [==[
-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V1
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Runtime={}
local locks=setmetatable({},{__mode="k"}); local completed=setmetatable({},{__mode="k"})
function Runtime.Apply(player,profile,requestId,operation,args,commit)
	if locks[player] then return {Success=false,Message="Garage request already in progress."} end
	requestId=tostring(requestId or ""); if requestId=="" then return {Success=false,Message="Request id required."} end
	completed[player]=completed[player] or {}; if completed[player][requestId] then return completed[player][requestId] end
	local before=Profile.Snapshot(profile); locks[player]=true
	local ok,result=pcall(function()
		local success,message
		if operation=="Assign" then success,message=Profile.Assign(profile,args)
		elseif operation=="Clear" then success,message=Profile.Clear(profile,args)
		elseif operation=="SetActive" then success,message=Profile.SetActive(profile,args and args.GarageId)
		elseif operation=="SetSurfaceStyle" then success,message=Profile.SetSurfaceStyle(profile,args)
		elseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)
		else success,message=false,"Unknown garage operation." end
		if not success then error(message) end
		local valid,validation=Profile.Validate(profile); if not valid then error(validation) end
		if type(commit)=="function" then local committed,commitMessage=commit(); if committed~=true then error(commitMessage or "Profile commit failed.") end end
		return {Success=true,Message=message,State=Profile.State(profile)}
	end)
	if not ok then Profile.Restore(profile,before); result={Success=false,Message=tostring(result)} end
	locks[player]=nil; completed[player][requestId]=result
	local count=0; for _ in pairs(completed[player]) do count+=1 end; if count>64 then completed[player]={ [requestId]=result } end
	return result
end
function Runtime.Validate(profile) return Profile.Validate(profile) end
return Runtime
]==]

local interiorRuntimeSource = [==[
-- NTR_OWNED_GARAGE_INTERIOR_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Runtime={}
local REQUIRED_MARKERS={"CharacterSpawn","DeskPromptAnchor","FootExitMarker","DriveInMarker","DriveOutMarker"}
local REQUIRED_SPACES={"Space01","Space02"}
local function config()
	return ReplicatedStorage.NeoTokyoRacers.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
end
local function templates()
	return ServerStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("OwnedGarage"):WaitForChild("Templates")
end
function Runtime.AuditTemplate(template)
	if not (template and template:IsA("Model") and template.PrimaryPart) then return false,"Template model/PrimaryPart missing." end
	for _,name in ipairs(REQUIRED_MARKERS) do
		local marker=template:FindFirstChild(name,true)
		if not (marker and marker:IsA("BasePart")) then return false,"Marker missing: "..name end
	end
	local spaces=template:FindFirstChild("DisplaySpaceMarkers")
	if not spaces then return false,"DisplaySpaceMarkers missing." end
	for _,slotId in ipairs(REQUIRED_SPACES) do
		local marker=spaces:FindFirstChild(slotId)
		if not (marker and marker:IsA("BasePart") and marker:GetAttribute("DisplaySpaceId")==slotId) then return false,"Display marker invalid: "..slotId end
	end
	return true,{DisplaySpaces=#REQUIRED_SPACES,TemplateId=template:GetAttribute("OwnedGarageTemplateId")}
end
function Runtime.SlotCFrame(slotIndex)
	slotIndex=math.max(1,math.floor(tonumber(slotIndex) or 1)); local settings=config()
	local columns=math.max(1,math.floor(tonumber(settings:GetAttribute("GridColumns")) or 8)); local index=slotIndex-1
	local base=settings:GetAttribute("InteriorBasePosition"); if typeof(base)~="Vector3" then base=Vector3.new(0,3200,0) end
	local x=(index%columns)*(tonumber(settings:GetAttribute("GridSpacingX")) or 160)
	local z=math.floor(index/columns)*(tonumber(settings:GetAttribute("GridSpacingZ")) or 120)
	return CFrame.new(base+Vector3.new(x,0,z))
end
function Runtime.InstanceName(ownerUserId,propertyId)
	return "OwnedGarage_"..tostring(math.floor(tonumber(ownerUserId) or 0)).."_"..tostring(propertyId or "")
end
function Runtime.Create(parent,ownerUserId,propertyId,templateId,slotIndex)
	if not (parent and parent:IsA("Folder")) then return nil,"Runtime pool folder required." end
	local name=Runtime.InstanceName(ownerUserId,propertyId); local existing=parent:FindFirstChild(name)
	if existing then local valid,message=Runtime.AuditTemplate(existing); if valid then return existing,"Existing" end; return nil,message end
	local limit=math.max(1,math.floor(tonumber(config():GetAttribute("MaxActiveInteriorsPerServer")) or 24))
	local count=0; for _,child in ipairs(parent:GetChildren()) do if child:IsA("Model") then count+=1 end end
	if count>=limit then return nil,"Active interior limit reached." end
	local template=templates():FindFirstChild(tostring(templateId or "")); local valid,message=Runtime.AuditTemplate(template); if not valid then return nil,message end
	local model=template:Clone(); model.Name=name; model:SetAttribute("OwnerUserId",math.floor(tonumber(ownerUserId) or 0)); model:SetAttribute("PropertyId",tostring(propertyId or "")); model:SetAttribute("RuntimeSlotIndex",math.max(1,math.floor(tonumber(slotIndex) or 1)))
	for _,descendant in ipairs(model:GetDescendants()) do if descendant:IsA("ProximityPrompt") then descendant.Enabled=false end end
	model:PivotTo(Runtime.SlotCFrame(slotIndex)); model.Parent=parent
	return model,"Created"
end
function Runtime.Destroy(parent,ownerUserId,propertyId)
	local model=parent and parent:FindFirstChild(Runtime.InstanceName(ownerUserId,propertyId)); if model then model:Destroy(); return true end
	return false
end
return Runtime
]==]

local displayRuntimeSource = [==[
-- NTR_OWNED_GARAGE_DISPLAY_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Runtime={}
local categories=ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles:WaitForChild("Categories")
local function findByAttribute(root,key,value)
	if not root then return nil end
	for _,item in ipairs(root:GetDescendants()) do if item:IsA("Model") and tostring(item:GetAttribute(key) or "")==tostring(value or "") then return item end end
	return nil
end
local function categoryFolder(categoryId)
	local wanted=string.lower(tostring(categoryId or "BRUISER"))
	for _,child in ipairs(categories:GetChildren()) do if string.lower(child.Name)==wanted then return child end end
	return categories:FindFirstChild("BRUISER") or categories:GetChildren()[1]
end
local function cockpitTemplate(categoryId,cockpitId)
	local category=categoryFolder(categoryId); local root=category and (category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS"))
	return findByAttribute(root or category,"CockpitId",cockpitId)
end
local function moduleTemplate(categoryId,moduleId)
	local category=categoryFolder(categoryId); local root=category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
	return findByAttribute(root,"ModuleId",moduleId)
end
local function channel(object)
	local current=object
	while current do
		local value=current:GetAttribute("PaintChannel"); if type(value)=="string" and value~="" then return value end
		if current.Name=="PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
		if current.Name=="SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
		if current.Name=="DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
		if current.Name=="NEON_OptionalLights" then return "Neon" end
		if current.Name=="THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
		current=current.Parent
	end
	return nil
end
local function pathHas(object,text)
	text=string.lower(text); local current=object
	while current do if string.find(string.lower(current.Name),text,1,true) then return true end; current=current.Parent end
	return false
end
local function copyTable(value)
	local result={}; for key,child in pairs(type(value)=="table" and value or {}) do result[key]=child end; return result
end
local function applyColours(model,colours,neonVisible)
	colours=type(colours)=="table" and colours or {}
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			local paint=channel(object)
			if object:GetAttribute("TemplateRole")=="FixedSlotMount" then object.Transparency=1
			elseif paint=="ThrustColor" then object.Color=colours.ThrustColor or Color3.new(1,1,1); object.Material=Enum.Material.Neon; object.Transparency=0
			elseif paint=="Neon" then
				local colour=colours.Neon or Color3.new(1,1,1); if pathHas(object,"cockpit") and pathHas(object,"front") then colour=colours.FrontLights or Color3.fromRGB(252,250,255) end; if pathHas(object,"cockpit") and (pathHas(object,"rear") or pathHas(object,"back")) then colour=colours.RearLights or Color3.fromRGB(255,116,116) end
				object.Color=colour; object.Material=Enum.Material.Neon; object.Transparency=neonVisible and 0 or 1
			elseif paint=="Primary" and colours.Primary then object.Color=colours.Primary
			elseif paint=="Secondary" and colours.Secondary then object.Color=colours.Secondary
			elseif paint=="Detail" and colours.Detail then object.Color=colours.Detail end
		end
	end
end
local function mountFor(vehicle,slotId)
	local root=vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename",true); local slot=root and root:FindFirstChild("SLOT_"..tostring(slotId),true)
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end
local function pivotModule(module,mount)
	local root=module.PrimaryPart or module:FindFirstChild("ModuleRoot_DoNotRename",true); if root then module.PrimaryPart=root end
	local source=module:FindFirstChild("MountAttachment",true); local target=mount and mount:FindFirstChild("MountAttachment")
	if source and target then module:PivotTo(target.WorldCFrame*source.CFrame:Inverse()) elseif mount then module:PivotTo(mount.CFrame) end
end
function Runtime.SanitizeForDisplay(model)
	local removed=0; local parts=0
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("VehicleSeat") or object:IsA("Seat") then object:Destroy(); removed+=1
		elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then object.Enabled=false
		elseif object:IsA("Light") then object.Enabled=false
		elseif object:IsA("BasePart") then object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.Massless=true; object.CastShadow=false; parts+=1 end
	end
	return {Parts=parts,Removed=removed}
end
function Runtime.Build(profile,vehicleId,spaceMarker,parent)
	vehicleId=tostring(vehicleId or ""); if type(profile)~="table" or type(profile.Vehicles)~="table" then return nil,"Profile vehicles missing." end
	local vehicle=profile.Vehicles[vehicleId]; if type(vehicle)~="table" then return nil,"Vehicle is not owned." end
	if not (spaceMarker and spaceMarker:IsA("BasePart") and parent) then return nil,"Display marker/parent missing." end
	local slotId=tostring(spaceMarker:GetAttribute("DisplaySpaceId") or spaceMarker.Name)
	for _,other in ipairs(parent:GetChildren()) do if other:IsA("Model") and other:GetAttribute("OwnedGarageDisplay")==true and other:GetAttribute("VehicleId")==vehicleId and other:GetAttribute("DisplaySpaceId")~=slotId then return nil,"Duplicate display vehicle rejected." end end
	local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[tostring(vehicle.CockpitInstanceId or "")]
	local cockpitId=tostring((type(cockpitInstance)=="table" and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); local categoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "BRUISER")
	local template=cockpitTemplate(categoryId,cockpitId); if not template then return nil,"Cockpit template not found: "..cockpitId end
	local display=template:Clone(); display.Name="DisplayVehicle_"..slotId; display:SetAttribute("OwnedGarageDisplay",true); display:SetAttribute("VehicleId",vehicleId); display:SetAttribute("DisplaySpaceId",slotId); display:SetAttribute("CockpitId",cockpitId)
	local root=display.PrimaryPart or display:FindFirstChild("CockpitRoot_DoNotRename",true); if not root then display:Destroy(); return nil,"Cockpit root missing." end; display.PrimaryPart=root
	local colours=copyTable(vehicle.CockpitColors); colours.ThrustColor=vehicle.ThrustColor or colours.ThrustColor; applyColours(display,colours,true)
	local installedRoot=Instance.new("Folder"); installedRoot.Name="INSTALLED_MODULES_Runtime"; installedRoot.Parent=display; local moduleCount=0; local missingModules=0
	for installedSlot,instanceId in pairs(type(vehicle.InstalledModules)=="table" and vehicle.InstalledModules or {}) do
		local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]; local moduleId=type(instance)=="table" and tostring(instance.TemplateId or "") or ""; local source=moduleId~="" and moduleTemplate(categoryId,moduleId) or nil; local mount=mountFor(display,installedSlot)
		if source and mount then local clone=source:Clone(); clone.Name="DISPLAY_"..tostring(installedSlot).."_"..source.Name; clone.Parent=installedRoot; pivotModule(clone,mount); local moduleColours=copyTable(instance.Colors); moduleColours.ThrustColor=vehicle.ThrustColor or moduleColours.ThrustColor; applyColours(clone,moduleColours,instance.NeonOwned==true); moduleCount+=1 else missingModules+=1 end
	end
	local metrics=Runtime.SanitizeForDisplay(display); local old=parent:FindFirstChild("DisplayVehicle_"..slotId); if old then old:Destroy() end
	display:PivotTo(spaceMarker.CFrame*CFrame.new(0,tonumber(ReplicatedStorage.NeoTokyoRacers.Config.Runtime.OwnedGarage_EditAttributes:GetAttribute("DisplayModelYOffset")) or 3.2,0)*CFrame.Angles(0,math.rad(180),0)); display.Parent=parent
	return display,{VehicleId=vehicleId,CockpitId=cockpitId,Modules=moduleCount,MissingModules=missingModules,Parts=metrics.Parts}
end
function Runtime.Clear(parent,slotId)
	local model=parent and parent:FindFirstChild("DisplayVehicle_"..tostring(slotId or "")); if model and model:GetAttribute("OwnedGarageDisplay")==true then model:Destroy(); return true end
	return false
end
return Runtime
]==]

local managementRuntimeSource = [==[
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local Workspace=game:GetService("Workspace")
local Runtime={}; local started=false
function Runtime.ChooseSlot(displaySpaces,requestedSlotId)
	displaySpaces=type(displaySpaces)=="table" and displaySpaces or {}; requestedSlotId=tostring(requestedSlotId or "")
	if requestedSlotId~="" then
		if displaySpaces[requestedSlotId]~=nil then return requestedSlotId,"Requested" end
		return nil,"Invalid"
	end
	for _,slotId in ipairs({"Space01","Space02"}) do if displaySpaces[slotId]==false or displaySpaces[slotId]==nil or tostring(displaySpaces[slotId])=="" then return slotId,"Empty" end end
	return nil,"Full"
end
function Runtime.Start()
	if started then return true,"AlreadyStarted" end
	local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local remotes=kit.Shared.Remotes.Garage; local invoke=remotes:WaitForChild("OwnedGarageInvoke"); local push=remotes:WaitForChild("OwnedGarageEvent"); local catalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGaragePropertyCatalog")); local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog"))
	local services=ServerScriptService.NeoTokyoRacers.Services; local garage=services.Garage; local Profile=require(garage:WaitForChild("OwnedGarageProfileRuntime")); local Assignment=require(garage:WaitForChild("OwnedGarageDisplayAssignmentRuntime")); local Interior=require(garage:WaitForChild("OwnedGarageInteriorRuntime")); local Display=require(garage:WaitForChild("OwnedGarageDisplayRuntime")); local lifecycle=garage:WaitForChild("OwnedGarageVehicleLifecycleBridge")
	local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local markDirty=bindings:WaitForChild("MarkDirty"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local world=Workspace:WaitForChild("NeoTokyoRacersWorld"); local interiors=world:FindFirstChild("Interiors") or Instance.new("Folder"); interiors.Name="Interiors"; interiors.Parent=world; local pool=interiors:FindFirstChild("OwnedGarageInstances") or Instance.new("Folder"); pool.Name="OwnedGarageInstances"; pool:SetAttribute("OwnedGarageRuntimePool",true); pool.Parent=interiors
	local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local driveOut,exitOnFoot
	local function profileFor(player)
		local profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end
		local oldVersion=type(profile.Garage)=="table" and profile.Garage.SchemaVersion or nil; Profile.Ensure(profile,false); if oldVersion~=Profile.SchemaVersion then markDirty:Invoke(player,"OwnedGarageSchemaV2") end
		return profile
	end
	local function lifecycleCall(action,player,payload)
		payload=type(payload)=="table" and payload or {}; payload.Player=player; local ok,result=pcall(function() return lifecycle:Invoke(action,payload) end)
		if not ok then return {Success=false,Message="Vehicle lifecycle unavailable: "..tostring(result)} end; return type(result)=="table" and result or {Success=false,Message="Invalid vehicle lifecycle response."}
	end
	local function characterRoot(player)
		local character=player.Character; return character and character:FindFirstChild("HumanoidRootPart")
	end
	local function teleportCharacter(player,cframe)
		if typeof(cframe)~="CFrame" then return false,"Destination missing." end; local character=player.Character; local root=characterRoot(player); if not (character and root) then return false,"Character is not ready." end
		character:PivotTo(cframe); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; return true
	end
	local function slotIndex(player)
		if slotByUserId[player.UserId] then return slotByUserId[player.UserId] end; local used={}; for _,index in pairs(slotByUserId) do used[index]=true end; local index=1; while used[index] do index+=1 end; slotByUserId[player.UserId]=index; return index
	end
	local function disconnectPrompts(interior)
		for _,connection in ipairs(promptConnections[interior] or {}) do connection:Disconnect() end; promptConnections[interior]=nil
	end
	local function scheduleUnload(interior,player)
		task.delay(math.max(0,tonumber(settings:GetAttribute("InteriorUnloadDelaySeconds")) or 20),function() if interior and interior.Parent and not sessions[player] then disconnectPrompts(interior); interior:Destroy() end end)
	end
	local function setInside(player,session)
		player:SetAttribute("NTR_OwnedGarageInside",session~=nil); player:SetAttribute("NTR_OwnedGaragePropertyId",session and session.PropertyId or nil); player:SetAttribute("NTR_OwnedGarageOwnerUserId",session and player.UserId or nil)
	end
	local function vehicleName(profile,vehicleId)
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId or "")]; return type(vehicle)=="table" and tostring(vehicle.DisplayName or vehicle.CockpitId or vehicleId) or tostring(vehicleId or "")
	end
	local function applyInteriorStyles(profile,session)
		local property=profile.Garage.Properties[session.PropertyId]; local selected=property and property.Customisation and property.Customisation.SurfaceStyles or {}
		for _,part in ipairs(session.Interior:GetDescendants()) do if part:IsA("BasePart") then local surfaceGroup=part:GetAttribute("SurfaceGroup"); local style=surfaceGroup and styleCatalog.ById(selected[surfaceGroup]); if style and style.SurfaceGroup==surfaceGroup then part.Color=style.Color; local material=Enum.Material[style.Material]; if material then part.Material=material end end end end
		return true
	end
	local function renderDisplays(player,profile,session)
		local property=profile.Garage.Properties[session.PropertyId]; local markers=session.Interior:FindFirstChild("DisplaySpaceMarkers"); if not markers then return false,"Display markers missing." end
		for _,slotId in ipairs({"Space01","Space02"}) do
			Display.Clear(session.Interior,slotId); local marker=markers:FindFirstChild(slotId); local prompt=marker and marker:FindFirstChild("DriveOutPrompt")
			if not prompt and marker then prompt=Instance.new("ProximityPrompt"); prompt.Name="DriveOutPrompt"; prompt.ActionText="Drive Out"; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.GamepadKeyCode=Enum.KeyCode.ButtonX; prompt.HoldDuration=.15; prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.ClickablePrompt=true; prompt.Parent=marker; table.insert(promptConnections[session.Interior],prompt.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then driveOut(player,slotId) end end)) end
			local vehicleId=property.DisplaySpaces[slotId]; prompt.Enabled=vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~=""; prompt.ObjectText=prompt.Enabled and vehicleName(profile,vehicleId) or "Empty Display Space"
			if prompt.Enabled then local model,message=Display.Build(profile,tostring(vehicleId),marker,session.Interior); if not model then return false,message end end
		end
		return true
	end
	local function configurePrompts(player,profile,session)
		promptConnections[session.Interior]=promptConnections[session.Interior] or {}; local list=promptConnections[session.Interior]
		local foot=session.Interior:FindFirstChild("FootExitPrompt",true); if foot then foot.Enabled=true; table.insert(list,foot.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then exitOnFoot(player) end end)) end
		local desk=session.Interior:FindFirstChild("ManageGaragePrompt",true); if desk then desk.Enabled=true; table.insert(list,desk.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then push:FireClient(player,{Type="OpenManagement",PropertyId=session.PropertyId}) end end)) end
		return renderDisplays(player,profile,session)
	end
	local function ensureSession(player,profile,propertyId)
		if sessions[player] then return sessions[player] end; local definition=catalog.ById(propertyId); local property=profile.Garage.Properties[propertyId]; if not (definition and property and property.Owned) then return nil,"Garage is not owned." end
		local interior,message=Interior.Create(pool,player.UserId,propertyId,definition.TemplateId,slotIndex(player)); if not interior then return nil,message end; disconnectPrompts(interior)
		local root=characterRoot(player); local session={Interior=interior,PropertyId=propertyId,ReturnCFrame=root and root.CFrame or settings:GetAttribute("CityFootExitCFrame")}; sessions[player]=session
		applyInteriorStyles(profile,session); local configured,configureMessage=configurePrompts(player,profile,session); if not configured then sessions[player]=nil; setInside(player,nil); scheduleUnload(interior,player); return nil,configureMessage end
		return session
	end
	local function abandonSession(player,session)
		if sessions[player]==session then sessions[player]=nil end; setInside(player,nil); if session and session.Interior then scheduleUnload(session.Interior,player) end
	end
	exitOnFoot=function(player)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; local destination=session.ReturnCFrame; if typeof(destination)~="CFrame" then destination=settings:GetAttribute("CityFootExitCFrame") end
		local ok,message=teleportCharacter(player,destination); if not ok then return {Success=false,Message=message} end; sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); return {Success=true,Message="Returned to the city."}
	end
	local function enterOnFoot(player,profile,propertyId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if driven.Success then return {Success=false,Message="Use Drive In while seated in your vehicle."} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local ok,teleportMessage=teleportCharacter(player,spawn and spawn.CFrame); if not ok then abandonSession(player,session); return {Success=false,Message=teleportMessage} end
		setInside(player,session); return {Success=true,Message="Entered garage.",PropertyId=propertyId}
	end
	local function replacementSlots(profile,propertyId)
		local result={}; local display=profile.Garage.Properties[propertyId].DisplaySpaces; for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=display[slotId]; table.insert(result,{SlotId=slotId,VehicleId=vehicleId,DisplayName=vehicleName(profile,vehicleId)}) end; return result
	end
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.Garage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId); if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local root=characterRoot(player); if not root then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end
		local before=Profile.Snapshot(profile); local requestId=tostring(driven.RequestId or Profile.NewRequestId()); local result=Assignment.Apply(player,profile,requestId,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},function()
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageDriveIn"); if not marked then return false,markMessage end; local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId}); return despawn.Success==true,despawn.Message
		end)
		if not result.Success then abandonSession(player,session); return result end; local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame)
		if not moved then Profile.Restore(profile,before); markDirty:Invoke(player,"OwnedGarageDriveInRollback"); lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame or settings:GetAttribute("CityVehicleExitCFrame")}); abandonSession(player,session); return {Success=false,Message=moveMessage} end
		setInside(player,session); renderDisplays(player,profile,session); return {Success=true,Message=reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage.",PropertyId=propertyId,SlotId=slotId}
	end
	driveOut=function(player,slotId)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local property=profile.Garage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then return {Success=false,Message="Display space is empty."} end
		local spawnCFrame=settings:GetAttribute("CityVehicleExitCFrame"); local result=Assignment.Apply(player,profile,Profile.NewRequestId(),"Clear",{GarageId=session.PropertyId,SlotId=slotId},function()
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageDriveOut"); if not marked then return false,markMessage end; local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame}); return spawned.Success==true,spawned.Message
		end)
		if result.Success then sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}) end; return result
	end
	local function managedOperation(player,profile,operation,args)
		local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId
		local requestId=tostring(args.RequestId or Profile.NewRequestId()); local result=Assignment.Apply(player,profile,requestId,operation,args,function()
			if operation=="Assign" or operation=="Clear" then local rendered,renderMessage=renderDisplays(player,profile,session); if not rendered then return false,renderMessage end elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageManagement:"..operation); return marked==true,markMessage
		end)
		if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else push:FireClient(player,{Type="ManagementUpdated",Operation=operation}) end
		return result
	end
	local function stateFor(player,profile)
		local properties={}; for _,definition in ipairs(catalog.List()) do local property=profile.Garage.Properties[definition.PropertyId]; if property and property.Owned then local filled=0; for _,vehicleId in pairs(property.DisplaySpaces) do if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then filled+=1 end end; table.insert(properties,{PropertyId=definition.PropertyId,DisplayName=definition.DisplayName,District=definition.District,Description=definition.Description,Image=definition.Image,TemplateId=definition.TemplateId,Capacity=#definition.DisplaySpaceIds,Filled=filled}) end end
		local session=sessions[player]; local currentProperty=session and profile.Garage.Properties[session.PropertyId]; local slots={}; local vehicles={}; local surfaceStyles={}
		if currentProperty then
			for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=currentProperty.DisplaySpaces[slotId]; table.insert(slots,{SlotId=slotId,VehicleId=vehicleId,DisplayName=(vehicleId and vehicleId~=false) and vehicleName(profile,vehicleId) or "Empty Display Space"}) end
			for surfaceGroup,styleId in pairs(currentProperty.Customisation.SurfaceStyles or {}) do surfaceStyles[surfaceGroup]=styleId end
		end
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=cockpitId,CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "")}) end end
		table.sort(vehicles,function(a,b) if a.DisplayName~=b.DisplayName then return a.DisplayName<b.DisplayName end return a.VehicleId<b.VehicleId end)
		return {Success=true,Properties=properties,ActiveGarageId=profile.Garage.ActiveGarageId,InGarage=session~=nil,CurrentPropertyId=session and session.PropertyId or nil,Slots=slots,Vehicles=vehicles,SurfaceStyles=surfaceStyles,InteriorStyles=styleCatalog.List(),AccessMode=currentProperty and currentProperty.AccessMode or "Private",Cash=tonumber(profile.Cash or profile.Money or profile.Credits) or 0}
	end
	invoke.OnServerInvoke=function(player,action,args)
		args=type(args)=="table" and args or {}; if locks[player] then return {Success=false,Message="Garage transition already in progress."} end; local now=os.clock(); if action~="GetState" and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1) then return {Success=false,Message="Garage transition is cooling down."} end
		locks[player]=true; local ok,result=pcall(function()
			local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local propertyId=tostring(args.PropertyId or profile.Garage.ActiveGarageId or "STARTER_TWO_BAY")
			if action=="GetState" or action=="GetManagementState" then return stateFor(player,profile)
			elseif action=="EnterSelectedGarage" then local driven=lifecycleCall("GetDrivenVehicle",player,{}); if driven.Success then return enterWithVehicle(player,profile,propertyId,args.ReplacementSlotId) end; return enterOnFoot(player,profile,propertyId)
			elseif action=="EnterOnFoot" then return enterOnFoot(player,profile,propertyId)
			elseif action=="EnterWithVehicle" then return enterWithVehicle(player,profile,propertyId,args.ReplacementSlotId)
			elseif action=="ExitOnFoot" then return exitOnFoot(player)
			elseif action=="DriveOut" then return driveOut(player,tostring(args.SlotId or ""))
			elseif action=="AssignDisplay" then return managedOperation(player,profile,"Assign",{SlotId=tostring(args.SlotId or ""),VehicleId=tostring(args.VehicleId or ""),RequestId=args.RequestId})
			elseif action=="ClearDisplay" then return managedOperation(player,profile,"Clear",{SlotId=tostring(args.SlotId or ""),RequestId=args.RequestId})
			elseif action=="SetInteriorStyle" then return managedOperation(player,profile,"SetSurfaceStyle",{SurfaceGroup=tostring(args.SurfaceGroup or ""),StyleId=tostring(args.StyleId or ""),RequestId=args.RequestId})
			elseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId}) end
			return {Success=false,Message="Unknown owned garage action."}
		end)
		locks[player]=nil; if action~="GetState" then lastRequest[player]=now end; if ok and type(result)=="table" then return result end; warn("[NTR Owned Garage] "..tostring(result)); return {Success=false,Message="Owned garage request failed."}
	end
	Players.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; slotByUserId[player.UserId]=nil; if session and session.Interior then disconnectPrompts(session.Interior); session.Interior:Destroy() end end)
	started=true; print("[NTR Owned Garage] Management runtime active."); return true,"Started"
end
return Runtime
]==]

local browserControllerSource = [==[
-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local ReplicatedStorage=game:GetService("ReplicatedStorage"); local UserInputService=game:GetService("UserInputService"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Mobile=require(kit.Shared.Modules.UI:WaitForChild("RacingMobileScaledDesktopLayout")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local openEvent=script.Parent:WaitForChild("OpenOwnedGarageBrowser")
	local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}
	local gui=Instance.new("ScreenGui"); gui.Name="NTR_OwnedGarageBrowser"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=171; gui.Parent=playerGui
	local overlay=Instance.new("Frame"); overlay.Name="Overlay"; overlay.BackgroundColor3=Color3.new(0,0,0); overlay.BackgroundTransparency=.38; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Visible=false; overlay.Parent=gui
	local shell=UI.Panel(overlay,{Name="OwnedGarageShell",Color=C("PanelDeep"),Transparency=L("PanelTransparency",.08),StrokeColor=C("Outline"),StrokeWidth=L("ShellStrokeWidth",2),StrokeTransparency=.02,Clips=true}); shell.AnchorPoint=Vector2.new(.5,.5); shell.Position=UDim2.fromScale(.5,.5)
	if Mobile.IsEnabled(UserInputService.TouchEnabled) then Mobile.Attach(shell) else shell.Size=UDim2.fromOffset(1200,720); UI.AttachResponsiveScale(shell) end
	UI.Label(shell,{Name="Title",Text="MY GARAGES",Position=UDim2.fromOffset(24,0),Size=UDim2.new(.55,0,0,64),TextSize=T("Heading",22),Role="Heading"}); local divider=Instance.new("Frame"); divider.BorderSizePixel=0; divider.BackgroundColor3=C("Outline"); divider.BackgroundTransparency=.5; divider.Position=UDim2.fromOffset(0,64); divider.Size=UDim2.new(1,0,0,1); divider.Parent=shell
	local content=Instance.new("Frame"); content.BackgroundTransparency=1; content.Position=UDim2.fromOffset(24,88); content.Size=UDim2.new(1,-48,1,-176); content.Parent=shell
	local listScroller=Instance.new("ScrollingFrame"); listScroller.Name="GarageList"; listScroller.BackgroundTransparency=1; listScroller.BorderSizePixel=0; listScroller.Size=UDim2.new(.38,-8,1,0); listScroller.AutomaticCanvasSize=Enum.AutomaticSize.Y; listScroller.CanvasSize=UDim2.fromOffset(0,0); listScroller.ScrollBarThickness=6; listScroller.ScrollBarImageColor3=C("Outline"); listScroller.Parent=content
	local list=Instance.new("Frame"); list.BackgroundTransparency=1; list.Size=UDim2.new(1,-14,0,0); list.AutomaticSize=Enum.AutomaticSize.Y; list.Parent=listScroller; local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,12); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=list
	local detail=Instance.new("Frame"); detail.BackgroundTransparency=1; detail.Position=UDim2.new(.38,8,0,0); detail.Size=UDim2.new(.62,-8,1,0); detail.Parent=content
	local hero=Shared.Panel(detail,"GarageImage",{NoGlow=true}); hero.Size=UDim2.new(1,0,0,290); local heroImage=Instance.new("ImageLabel"); heroImage.Name="Image"; heroImage.BackgroundTransparency=1; heroImage.Position=UDim2.fromOffset(5,5); heroImage.Size=UDim2.new(1,-10,1,-10); heroImage.ScaleType=Enum.ScaleType.Crop; heroImage.Parent=hero; UI.Corner(heroImage,5)
	local placeholder=UI.Label(hero,{Name="Placeholder",Text="GARAGE IMAGE",Size=UDim2.fromScale(1,1),TextSize=T("Heading",20),Color=C("Muted"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}); placeholder.TextTransparency=.25
	local detailTitle=UI.Label(detail,{Name="GarageTitle",Text="",Position=UDim2.fromOffset(0,308),Size=UDim2.new(1,0,0,38),TextSize=T("Heading",26),Role="Heading"}); local district=UI.Label(detail,{Name="District",Text="",Position=UDim2.fromOffset(0,347),Size=UDim2.new(1,0,0,25),TextSize=T("Caption",13),Color=C("Telemetry"),Role="Heading"}); local description=UI.Label(detail,{Name="Description",Text="",Position=UDim2.fromOffset(0,382),Size=UDim2.new(1,0,0,72),TextSize=T("Body",15),Color=C("Text")}); description.TextWrapped=true; description.TextYAlignment=Enum.TextYAlignment.Top
	local capacity=Shared.MetricCard(detail,"Capacity"); capacity.Position=UDim2.fromOffset(0,466); capacity.Size=UDim2.new(1,0,0,54); local capacityText=UI.Label(capacity,{Text="",Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-28,1,0),TextSize=T("Metric",16),Role="Metric",XAlignment=Enum.TextXAlignment.Center})
	local status=UI.Label(shell,{Name="Status",Text="",Position=UDim2.new(0,24,1,-82),Size=UDim2.new(1,-48,0,20),TextSize=T("Caption",11),Color=C("Danger"),Role="Heading",XAlignment=Enum.TextXAlignment.Center}); status.Visible=false
	local exit=Shared.ActionButton(shell,{Name="Exit",Text="EXIT",IconText="×",Size=UDim2.fromOffset(220,48),Color=C("PanelSoft"),StrokeColor=C("Outline")}); exit.Position=UDim2.new(0,24,1,-64)
	local enter=Shared.ActionButton(shell,{Name="Enter",Text="ENTER GARAGE",IconText="E",Size=UDim2.fromOffset(300,48),Color=C("PanelBlue"),StrokeColor=C("Telemetry")}); enter.AnchorPoint=Vector2.new(1,0); enter.Position=UDim2.new(1,-24,1,-64)
	local function presentation(active) local event=script.Parent:FindFirstChild("FreeRoamHudPresentationMode"); if event and event:IsA("BindableEvent") then event:Fire({Owner="OwnedGarageBrowser",Active=active==true,KeepTelemetry=false}) end end
	local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage service unavailable."} end
	local function setStatus(text,good) status.Text=tostring(text or ""); status.TextColor3=good and C("Telemetry") or C("Danger"); status.Visible=status.Text~="" end
	local function clearList() for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end; table.clear(cards) end
	local render
	local function selectProperty(property) selected=property; render() end
	local function renderDetail()
		if not selected then detailTitle.Text="NO GARAGES"; district.Text=""; description.Text="No owned garage properties are available."; capacityText.Text=""; heroImage.Visible=false; placeholder.Visible=true; enter.Visible=false; return end
		detailTitle.Text=string.upper(selected.DisplayName or selected.PropertyId); district.Text=string.upper(selected.District or ""); description.Text=tostring(selected.Description or ""); heroImage.Image=UI.Asset(selected.Image or ""); heroImage.Visible=heroImage.Image~=""; placeholder.Visible=not heroImage.Visible; capacityText.Text=tostring(selected.Filled or 0).." / "..tostring(selected.Capacity or 0).." DISPLAY SPACES"; enter.Visible=true; Shared.SetActionButton(enter,state and state.InGarage and "RETURN TO CITY" or "ENTER GARAGE",nil,state and state.InGarage and "↩" or "E")
	end
	render=function()
		clearList(); for index,property in ipairs(state and state.Properties or {}) do local card=Shared.Card(list,{Name="Garage_"..property.PropertyId,DisplayName=property.DisplayName,Image=UI.Asset(property.Image or ""),Rating=tostring(property.Capacity or 0).." BAYS",Selected=selected and selected.PropertyId==property.PropertyId,Size=UDim2.new(1,0,0,158),ImageHeight=148}); card.LayoutOrder=index; card.Activated:Connect(function() selectProperty(property) end); cards[property.PropertyId]=card end; renderDetail()
	end
	local function close() overlay.Visible=false; presentation(false); setStatus("") end
	local function replacementPrompt(result)
		local shade=Instance.new("Frame"); shade.Name="ReplacementPrompt"; shade.BackgroundColor3=Color3.new(0,0,0); shade.BackgroundTransparency=.18; shade.Size=UDim2.fromScale(1,1); shade.ZIndex=200; shade.Parent=shell; local panel=Shared.Panel(shade,"Panel",{}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(560,330); panel.ZIndex=201; UI.Label(panel,{Text="GARAGE FULL",Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,-40,0,38),TextSize=T("Heading",24),Role="Heading",XAlignment=Enum.TextXAlignment.Center}).ZIndex=202; UI.Label(panel,{Text="Choose the display vehicle to replace. The replaced vehicle stays owned.",Position=UDim2.fromOffset(24,60),Size=UDim2.new(1,-48,0,48),TextSize=T("Body",14),XAlignment=Enum.TextXAlignment.Center}).ZIndex=202
		for index,slot in ipairs(result.Slots or {}) do local button=Shared.ActionButton(panel,{Name=slot.SlotId,Text=tostring(slot.DisplayName or slot.VehicleId),IconText=tostring(index),Size=UDim2.new(1,-48,0,58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*68); button.ZIndex=203; button.Activated:Connect(function() if busy then return end; busy=true; local replaced=request("EnterSelectedGarage",{PropertyId=selected.PropertyId,ReplacementSlotId=slot.SlotId}); busy=false; if replaced.Success then shade:Destroy(); close() else setStatus(replaced.Message,false) end end) end
		local cancel=Shared.ActionButton(panel,{Name="Cancel",Text="CANCEL",IconText="×",Size=UDim2.fromOffset(180,42),Color=C("PanelSoft"),StrokeColor=C("Outline")}); cancel.AnchorPoint=Vector2.new(.5,1); cancel.Position=UDim2.new(.5,0,1,-14); cancel.ZIndex=203; cancel.Activated:Connect(function() shade:Destroy() end)
	end
	local function open()
		local result=request("GetState",{}); if not result.Success then overlay.Visible=true; presentation(true); setStatus(result.Message,false); return end; state=result; selected=nil; for _,property in ipairs(state.Properties or {}) do if property.PropertyId==state.ActiveGarageId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]); render(); overlay.Visible=true; presentation(true); setStatus("")
	end
	exit.Activated:Connect(close); enter.Activated:Connect(function() if busy or not selected then return end; busy=true; local result;if state.InGarage then result=request("ExitOnFoot",{}) else result=request("EnterSelectedGarage",{PropertyId=selected.PropertyId}) end; busy=false; if result.Success then close() elseif result.NeedsReplacement then replacementPrompt(result) else setStatus(result.Message,false) end end); openEvent.Event:Connect(function() if overlay.Visible then close() else open() end end); push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="DriveOut" then close() end end)
	started=true; print("[NTR Owned Garage] Browser controller active."); return true,"Started"
end
return Controller
]==]

local workspaceControllerSource = [==[
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local ReplicatedStorage=game:GetService("ReplicatedStorage"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local uiFolder=script.Parent; local Racing=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local openEvent=uiFolder:WaitForChild("OpenOwnedGarageWorkspace")
	local workspace=WorkspaceUI.new(); workspace.Root.Name="OwnedGarageCanonicalWorkspace"; workspace.Audit=function(self) Shared.AuditPresentation(self.Root,"Owned Garage Workspace"); task.defer(function() if not (self.Root.Visible and self.Root.Parent) then return end; local count=0; for _,child in ipairs(self.Host.Canvas:GetChildren()) do if child.Name=="OwnedGarageCanonicalWorkspace" then count+=1 end end; if count==1 and self.Gui.Name=="CanonicalGarageGui" and self.Scale.Parent==self.Host.Canvas then print("[NTR Owned Garage Workspace] SHARED GEOMETRY PASS") else warn("[NTR Owned Garage Workspace] SHARED GEOMETRY FAIL roots="..tostring(count)) end end) end; local state; local page="DisplaySlots"; local selectedSlot="Space01"; local selectedVehicle; local selectedStyle; local selectedAccess; local busy=false; local imageCache={}; local render
	local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage management is unavailable."} end
	local function imageFor(cockpitId)
		cockpitId=tostring(cockpitId or ""); if imageCache[cockpitId]~=nil then return imageCache[cockpitId] end; local image=""; local categories=kit.Assets.Vehicles:FindFirstChild("Categories"); if categories then for _,candidate in ipairs(categories:GetDescendants()) do if candidate:IsA("Model") and tostring(candidate:GetAttribute("CockpitId") or "")==cockpitId then image=tostring(candidate:GetAttribute("PreviewImage") or candidate:GetAttribute("Image") or ""); break end end end; imageCache[cockpitId]=image; return image
	end
	local function vehicleById(vehicleId) for _,vehicle in ipairs(state and state.Vehicles or {}) do if vehicle.VehicleId==tostring(vehicleId or "") then return vehicle end end end
	local function selectedProperty() for _,property in ipairs(state and state.Properties or {}) do if property.PropertyId==state.CurrentPropertyId then return property end end return (state and state.Properties and state.Properties[1]) end
	local function close() workspace:Hide() end
	local function refresh(nextPage)
		local result=request("GetManagementState",{}); if not result.Success or not result.InGarage then warn("[NTR Owned Garage] "..tostring(result.Message or "Management requires an active garage interior.")); close(); return false end; state=result; if nextPage then page=nextPage end; return true
	end
	local function operate(action,args,nextPage)
		if busy then return end; busy=true; local result=request(action,args); busy=false; if not result.Success then workspace:Message(result.Message or "Garage update failed."); return end; if refresh(nextPage) then render() end
	end
	local function tabs()
		return {
			{Id="Display",Text="DISPLAY CARS",Selected=page=="DisplaySlots" or page=="DisplayVehicles",OnSelect=function() page="DisplaySlots"; selectedVehicle=nil; render() end},
			{Id="Interior",Text="INTERIOR",Selected=page=="Interior",OnSelect=function() page="Interior"; selectedStyle=nil; render() end},
			{Id="Access",Text="ACCESS",Selected=page=="Access",OnSelect=function() page="Access"; selectedAccess=nil; render() end},
		}
	end
	local function statusRenderer(title,body)
		return function(parent)
			local heading=Racing.Label(parent,{Text=string.upper(title),Size=UDim2.new(1,0,0,30),TextSize=16,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); heading:SetAttribute("GeneratedGarageWorkspace",true); heading.LayoutOrder=1
			local copy=Racing.Label(parent,{Text=body,Size=UDim2.new(1,0,0,78),TextSize=12,XAlignment=Enum.TextXAlignment.Center}); copy.TextWrapped=true; copy:SetAttribute("GeneratedGarageWorkspace",true); copy.LayoutOrder=2
		end
	end
	local function baseContext(subtitle,cards)
		local property=selectedProperty(); return {Title="GARAGE MANAGEMENT",Subtitle=subtitle,ShowLeft=true,LeftItems=tabs(),Cards=cards,Cash=state.Cash or 0,CapacityText=tostring(property and property.Filled or 0).."/"..tostring(property and property.Capacity or 0).." DISPLAY SPACES",NextVisible=false,ExitVisible=true,ExitText="CLOSE",OnExit=close,OnCash=function() end,OnCapacity=function() end,CarouselScrollKey="OwnedGarage:"..page,CategoryScrollKey="OwnedGarageTabs",RenderStats=statusRenderer("OWNER WORKSPACE","Choose display vehicles, edit the interior, or prepare property access. Changes are validated and saved by the owned-garage profile runtime.")}
	end
	local function hideEconomyPlus()
		for _,container in ipairs({workspace.Cash,workspace.Capacity}) do for _,child in ipairs(container:GetChildren()) do if child:IsA("GuiButton") and child.Text=="+" then child.Visible=false end end end
	end
	render=function()
		if not state then return end; local cards={}; local context
		if page=="DisplaySlots" then
			local found=false; for _,slot in ipairs(state.Slots or {}) do if slot.SlotId==selectedSlot then found=true end end; if not found and state.Slots and state.Slots[1] then selectedSlot=state.Slots[1].SlotId end
			for index,slot in ipairs(state.Slots or {}) do local vehicle=vehicleById(slot.VehicleId); local row={Id=slot.SlotId,DisplayName=slot.DisplayName,Badge="SPACE "..tostring(index),Image=vehicle and imageFor(vehicle.CockpitId) or "",Selected=slot.SlotId==selectedSlot,Footer=vehicle and "DISPLAYED" or "EMPTY",ActionText="CHOOSE VEHICLE"}; row.OnSelect=function() selectedSlot=slot.SlotId; render() end; row.OnAction=function() page="DisplayVehicles"; selectedVehicle=tostring(slot.VehicleId or ""); if selectedVehicle=="false" then selectedVehicle="" end; render() end; table.insert(cards,row) end
			context=baseContext("Choose a display space to manage.",cards); context.RenderStats=statusRenderer("DISPLAY CARS","Each saved vehicle can appear in only one display space. Reassigning it automatically clears its former display reference; the vehicle itself is never duplicated or deleted.")
		elseif page=="DisplayVehicles" then
			local assigned=""; for _,slot in ipairs(state.Slots or {}) do if slot.SlotId==selectedSlot and slot.VehicleId and slot.VehicleId~=false then assigned=tostring(slot.VehicleId) end end; if not selectedVehicle or selectedVehicle=="" then selectedVehicle=assigned~="" and assigned or (state.Vehicles and state.Vehicles[1] and state.Vehicles[1].VehicleId) end
			for _,vehicle in ipairs(state.Vehicles or {}) do local isAssigned=vehicle.VehicleId==assigned; local row={Id=vehicle.VehicleId,DisplayName=vehicle.DisplayName,Image=imageFor(vehicle.CockpitId),Badge=isAssigned and "DISPLAYED" or nil,Selected=vehicle.VehicleId==selectedVehicle,Footer=isAssigned and "CURRENT SPACE" or "OWNED VEHICLE",ActionText=isAssigned and "REMOVE FROM DISPLAY" or "DISPLAY HERE"}; row.OnSelect=function() selectedVehicle=vehicle.VehicleId; render() end; row.OnAction=function() if isAssigned then operate("ClearDisplay",{SlotId=selectedSlot},"DisplaySlots") else operate("AssignDisplay",{SlotId=selectedSlot,VehicleId=vehicle.VehicleId},"DisplaySlots") end end; table.insert(cards,row) end
			context=baseContext("Choose the saved vehicle for "..selectedSlot..".",cards); context.BackVisible=true; context.BackText="DISPLAY SPACES"; context.OnBack=function() page="DisplaySlots"; render() end; context.EmptyMessage="NO OWNED VEHICLES AVAILABLE"; context.RenderStats=statusRenderer(selectedSlot,"A displayed vehicle remains part of the normal saved vehicle collection and can still be customised or reassigned later.")
		elseif page=="Interior" then
			local styles=state.InteriorStyles or styleCatalog.List(); if not selectedStyle and styles[1] then selectedStyle=styles[1].StyleId end
			for _,style in ipairs(styles) do local current=state.SurfaceStyles and state.SurfaceStyles[style.SurfaceGroup]==style.StyleId; local row={Id=style.StyleId,DisplayName=style.DisplayName,Badge=string.upper(style.SurfaceGroup),Selected=style.StyleId==selectedStyle,Footer=current and "CURRENT" or string.upper(style.Material or "STYLE"),SemanticState=current and "Equipped" or "Shop",CardKind="Listing",ActionText=current and nil or "APPLY STYLE"}; row.OnSelect=function() selectedStyle=style.StyleId; render() end; row.OnAction=function() operate("SetInteriorStyle",{SurfaceGroup=style.SurfaceGroup,StyleId=style.StyleId},"Interior") end; table.insert(cards,row) end
			context=baseContext("Choose editable surface styles for this property.",cards); context.RenderStats=statusRenderer("INTERIOR","Surface presets are catalogue-driven and saved per garage property. New styles can be added without changing the workspace flow.")
		else
			local modes={{Id="Private",Text="PRIVATE",Body="Only the owner can enter."},{Id="FriendsOnly",Text="FRIENDS ONLY",Body="Reserved for friend access."},{Id="InviteOnly",Text="INVITE ONLY",Body="Reserved for explicit invitations."},{Id="Public",Text="PUBLIC",Body="Reserved for public visits."}}; selectedAccess=selectedAccess or state.AccessMode
			for _,mode in ipairs(modes) do local current=mode.Id==state.AccessMode; local row={Id=mode.Id,DisplayName=mode.Text,Badge=current and "CURRENT" or "ACCESS",Selected=mode.Id==selectedAccess,Footer=mode.Body,SemanticState=current and "Equipped" or "Shop",CardKind="Listing",ActionText=current and nil or "SET ACCESS"}; row.OnSelect=function() selectedAccess=mode.Id; render() end; row.OnAction=function() operate("SetAccessMode",{AccessMode=mode.Id},"Access") end; table.insert(cards,row) end
			context=baseContext("Choose the saved access policy for this garage.",cards); context.RenderStats=statusRenderer("ACCESS","The policy is persistent now. Visitor admission remains disabled until the later permission/runtime activation gate is completed.")
		end
		workspace:Show(context); hideEconomyPlus()
	end
	local function open() if refresh("DisplaySlots") then selectedSlot="Space01"; selectedVehicle=nil; selectedStyle=nil; selectedAccess=nil; render() end end
	openEvent.Event:Connect(function() if workspace.Root.Visible then close() else open() end end); push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="OpenManagement" then open() elseif type(message)=="table" and message.Type=="DriveOut" then close() end end)
	started=true; print("[NTR Owned Garage] Workspace controller active."); return true,"Started"
end
return Controller
]==]

local configAttributes = {
	InteriorBasePosition=Vector3.new(0,3200,0), GridColumns=8, GridSpacingX=160, GridSpacingZ=120,
	InteriorUnloadDelaySeconds=20, DisplayModelYOffset=3.2, MaxActiveInteriorsPerServer=24,
	TransitionCooldownSeconds=1, DriveInMaxSpeedMph=5, BrowserReferenceWidth=1200, BrowserReferenceHeight=720,
	TemplateAuditEnabled=true, DebugEnabled=false,
}

local function templatePart(parent,name,size,cframe,colour,material,collision,transparency)
	local part=Instance.new("Part"); part.Name=name; part.Size=size; part.CFrame=cframe; part.Color=colour; part.Material=material or Enum.Material.SmoothPlastic; part.Anchored=true; part.CanCollide=collision==true; part.CanTouch=collision==true; part.CanQuery=collision==true; part.Transparency=transparency or 0; part.TopSurface=Enum.SurfaceType.Smooth; part.BottomSurface=Enum.SurfaceType.Smooth; part.Parent=parent
	return part
end

local function marker(parent,name,cframe,markerType)
	local part=templatePart(parent,name,Vector3.new(4,0.5,4),cframe,Color3.fromRGB(0,255,255),Enum.Material.SmoothPlastic,false,1)
	part:SetAttribute("MarkerType",markerType or name); return part
end

local function buildStarterTwoBayTemplate()
	local model=Instance.new("Model"); model.Name="StarterTwoBay"; model:SetAttribute("OwnedGarageTemplateId","StarterTwoBay"); model:SetAttribute("OwnedGarageTemplateVersion",1); model:SetAttribute("DisplaySpaceCount",2)
	local origin=marker(model,"TemplateOrigin",CFrame.new(),"Origin"); model.PrimaryPart=origin
	local floor=templatePart(model,"Floor",Vector3.new(96,1,64),CFrame.new(0,-0.5,0),Color3.fromRGB(18,23,31),Enum.Material.Metal,true); floor:SetAttribute("SurfaceGroup","Floor")
	local roof=templatePart(model,"Roof",Vector3.new(96,1,64),CFrame.new(0,22.5,0),Color3.fromRGB(12,16,23),Enum.Material.Metal,true); roof:SetAttribute("SurfaceGroup","Roof")
	for _,definition in ipairs({
		{"BackWall",Vector3.new(96,22,1),CFrame.new(0,11,31.5)}, {"LeftWall",Vector3.new(1,22,64),CFrame.new(-48.5,11,0)}, {"RightWall",Vector3.new(1,22,64),CFrame.new(48.5,11,0)},
		{"FrontWallLeft",Vector3.new(34,22,1),CFrame.new(-31,11,-31.5)}, {"FrontWallRight",Vector3.new(34,22,1),CFrame.new(31,11,-31.5)}, {"FrontDoorLintel",Vector3.new(28,6,1),CFrame.new(0,19,-31.5)},
	}) do local wall=templatePart(model,definition[1],definition[2],definition[3],Color3.fromRGB(27,34,45),Enum.Material.Metal,true); wall:SetAttribute("SurfaceGroup","Walls") end
	local trimColour=Color3.fromRGB(231,54,171); templatePart(model,"RearNeonTrim",Vector3.new(70,0.35,0.35),CFrame.new(0,17,30.8),trimColour,Enum.Material.Neon,false)
	local spaces=Instance.new("Folder"); spaces.Name="DisplaySpaceMarkers"; spaces.Parent=model
	for index,x in ipairs({-23,23}) do
		local slotId=string.format("Space%02d",index); local pad=templatePart(model,"DisplayPad_"..slotId,Vector3.new(32,0.35,20),CFrame.new(x,0.2,5),Color3.fromRGB(24,61,74),Enum.Material.Metal,true); pad:SetAttribute("DisplaySpaceId",slotId); pad:SetAttribute("SurfaceGroup","DisplayPads")
		local edge=templatePart(model,"DisplayPadNeon_"..slotId,Vector3.new(30,0.12,18),CFrame.new(x,0.41,5),Color3.fromRGB(41,202,232),Enum.Material.Neon,false); edge:SetAttribute("DisplaySpaceId",slotId)
		local space=marker(spaces,slotId,CFrame.new(x,0.55,5),"DisplaySpace"); space.Size=Vector3.new(30,0.5,18); space:SetAttribute("DisplaySpaceId",slotId)
	end
	local desk=Instance.new("Model"); desk.Name="ManagementDesk"; desk.Parent=model; templatePart(desk,"DeskBase",Vector3.new(12,3.5,4),CFrame.new(37,1.75,23),Color3.fromRGB(35,42,55),Enum.Material.Metal,true); templatePart(desk,"DeskTop",Vector3.new(13,0.5,5),CFrame.new(37,3.75,23),trimColour,Enum.Material.SmoothPlastic,true)
	local deskMarker=marker(desk,"DeskPromptAnchor",CFrame.new(37,4.8,19),"ManagementDesk"); local deskPrompt=Instance.new("ProximityPrompt"); deskPrompt.Name="ManageGaragePrompt"; deskPrompt.ActionText="Manage Garage"; deskPrompt.ObjectText="Garage Desk"; deskPrompt.KeyboardKeyCode=Enum.KeyCode.E; deskPrompt.GamepadKeyCode=Enum.KeyCode.ButtonX; deskPrompt.HoldDuration=0.15; deskPrompt.MaxActivationDistance=10; deskPrompt.RequiresLineOfSight=false; deskPrompt.ClickablePrompt=true; deskPrompt.Enabled=false; deskPrompt.Parent=deskMarker
	marker(model,"CharacterSpawn",CFrame.new(-38,1,-22)*CFrame.Angles(0,math.rad(35),0),"CharacterSpawn")
	local personnelDoor=templatePart(model,"PersonnelDoor",Vector3.new(8,12,0.5),CFrame.new(-38,6,30.8),Color3.fromRGB(44,54,70),Enum.Material.Metal,false); personnelDoor:SetAttribute("SurfaceGroup","Doors")
	local foot=marker(model,"FootExitMarker",CFrame.new(-38,1,25),"FootExit"); local exitPrompt=Instance.new("ProximityPrompt"); exitPrompt.Name="FootExitPrompt"; exitPrompt.ActionText="Exit Garage"; exitPrompt.ObjectText="Garage Door"; exitPrompt.KeyboardKeyCode=Enum.KeyCode.E; exitPrompt.GamepadKeyCode=Enum.KeyCode.ButtonX; exitPrompt.HoldDuration=0.1; exitPrompt.MaxActivationDistance=10; exitPrompt.RequiresLineOfSight=false; exitPrompt.ClickablePrompt=true; exitPrompt.Enabled=false; exitPrompt.Parent=foot
	marker(model,"DriveInMarker",CFrame.new(0,0.5,-21),"DriveIn"); marker(model,"DriveOutMarker",CFrame.new(0,0.5,-38),"DriveOut")
	local decorations=Instance.new("Folder"); decorations.Name="DecorationAnchors"; decorations.Parent=model; for index,x in ipairs({-34,0,34}) do local anchor=marker(decorations,"DecorationAnchor"..index,CFrame.new(x,0.5,25),"Decoration"); anchor:SetAttribute("DecorationAnchorId","Rear"..index) end
	return model
end

local stagedTemplate=buildStarterTwoBayTemplate()

local staged = Instance.new("Folder")
staged.Name = "NTR_OwnedGarageCompileStaging"
local function compile(name, source)
	local module = Instance.new("ModuleScript"); module.Name=name; module.Source=source; module.Parent=staged
	local clone=module:Clone()
	if name=="OwnedGarageProfileRuntime" then
		local catalog=Instance.new("ModuleScript"); catalog.Name="OwnedGaragePropertyCatalog"; catalog.Source=catalogSource; catalog.Parent=clone
		local styles=Instance.new("ModuleScript"); styles.Name="OwnedGarageInteriorStyleCatalog"; styles.Source=interiorStyleCatalogSource; styles.Parent=clone
	end
	clone.Parent=ReplicatedStorage; local ok,result=pcall(require,clone)
	if not (ok and type(result)=="table") then clone:Destroy(); error(name .. " compile/require failed: " .. tostring(result)) end
	if name~="OwnedGarageProfileRuntime" then clone:Destroy(); clone=nil end
	return module,result,clone
end
local _,compiledCatalog=compile("OwnedGaragePropertyCatalog",catalogSource)
local _,compiledStyles=compile("OwnedGarageInteriorStyleCatalog",interiorStyleCatalogSource)
do
	local defaults=compiledStyles.DefaultStyles(); for _,surfaceGroup in ipairs({"Floor","Walls","Roof","DisplayPads","Doors"}) do local style=compiledStyles.ById(defaults[surfaceGroup]); assert(style and style.SurfaceGroup==surfaceGroup and typeof(style.Color)=="Color3" and Enum.Material[style.Material],"Interior style catalogue audit failed: "..surfaceGroup) end
end
local _,compiledProfile,compiledProfileClone=compile("OwnedGarageProfileRuntime",profileRuntimeSource)
local profileAuditOk,profileAuditError=pcall(function()
	local sample={Vehicles={vehicle_a={}}}; compiledProfile.Ensure(sample,true)
	local assigned,message=compiledProfile.Assign(sample,{GarageId="STARTER_TWO_BAY",SlotId="Space01",VehicleId="vehicle_a"}); assert(assigned,message)
	local reassigned=compiledProfile.Assign(sample,{GarageId="STARTER_TWO_BAY",SlotId="Space02",VehicleId="vehicle_a"}); assert(reassigned,"Move assignment audit failed")
	assert(sample.Garage.Properties.STARTER_TWO_BAY.DisplaySpaces.Space01==false,"Duplicate move did not clear former slot")
	local styled,styleMessage=compiledProfile.SetSurfaceStyle(sample,{GarageId="STARTER_TWO_BAY",SurfaceGroup="Walls",StyleId="WALL_CONCRETE"}); assert(styled,styleMessage)
	local invalidStyle=compiledProfile.SetSurfaceStyle(sample,{GarageId="STARTER_TWO_BAY",SurfaceGroup="Walls",StyleId="PAD_CYAN"}); assert(invalidStyle==false,"Cross-surface style validation failed")
	local access,accessMessage=compiledProfile.SetAccessMode(sample,{GarageId="STARTER_TWO_BAY",AccessMode="FriendsOnly"}); assert(access,accessMessage)
	assert(sample.Garage.Properties.STARTER_TWO_BAY.Customisation.SurfaceStyles.Walls=="WALL_CONCRETE" and sample.Garage.Properties.STARTER_TWO_BAY.AccessMode=="FriendsOnly","Management profile audit failed")
	local valid=compiledProfile.Validate(sample); assert(valid,"Sample invariant audit failed")
end)
compiledProfileClone:Destroy(); assert(profileAuditOk,"OwnedGarageProfileRuntime invariant audit failed: "..tostring(profileAuditError))
-- Assignment requires its sibling, so compile it against a temporary sibling set.
local compileRoot=Instance.new("Folder"); compileRoot.Name="NTR_OwnedGarageAssignmentCompile"; compileRoot.Parent=ServerScriptService
local tempProfile=Instance.new("ModuleScript"); tempProfile.Name="OwnedGarageProfileRuntime"; tempProfile.Source=profileRuntimeSource; tempProfile.Parent=compileRoot
local tempCatalog=Instance.new("ModuleScript"); tempCatalog.Name="OwnedGaragePropertyCatalog"; tempCatalog.Source=catalogSource; tempCatalog.Parent=tempProfile
local tempStyles=Instance.new("ModuleScript"); tempStyles.Name="OwnedGarageInteriorStyleCatalog"; tempStyles.Source=interiorStyleCatalogSource; tempStyles.Parent=tempProfile
local tempAssignment=Instance.new("ModuleScript"); tempAssignment.Name="OwnedGarageDisplayAssignmentRuntime"; tempAssignment.Source=assignmentSource; tempAssignment.Parent=compileRoot
local assignmentOk,assignmentResult=pcall(require,tempAssignment)
if assignmentOk and type(assignmentResult)=="table" then
	local fakePlayer=Instance.new("Folder"); local sample={Vehicles={vehicle_a={}}}
	local first=assignmentResult.Apply(fakePlayer,sample,"phase1-idempotency","Assign",{GarageId="STARTER_TWO_BAY",SlotId="Space01",VehicleId="vehicle_a"},function() return true end)
	local firstRevision=sample.Garage and sample.Garage.Revision
	local repeatResult=assignmentResult.Apply(fakePlayer,sample,"phase1-idempotency","Assign",{GarageId="STARTER_TWO_BAY",SlotId="Space02",VehicleId="vehicle_a"},function() return true end)
	assignmentOk=first.Success==true and repeatResult==first and sample.Garage.Revision==firstRevision
	local styleResult=assignmentResult.Apply(fakePlayer,sample,"phase4-style","SetSurfaceStyle",{GarageId="STARTER_TWO_BAY",SurfaceGroup="DisplayPads",StyleId="PAD_MAGENTA"},function() return true end)
	local accessResult=assignmentResult.Apply(fakePlayer,sample,"phase4-access","SetAccessMode",{GarageId="STARTER_TWO_BAY",AccessMode="InviteOnly"},function() return true end)
	assignmentOk=assignmentOk and styleResult.Success==true and accessResult.Success==true and sample.Garage.Properties.STARTER_TWO_BAY.Customisation.SurfaceStyles.DisplayPads=="PAD_MAGENTA" and sample.Garage.Properties.STARTER_TWO_BAY.AccessMode=="InviteOnly"
	if not assignmentOk then assignmentResult="idempotency sample failed" end
	fakePlayer:Destroy()
end
compileRoot:Destroy(); assert(assignmentOk and type(assignmentResult)=="table","OwnedGarageDisplayAssignmentRuntime compile/idempotency failed: "..tostring(assignmentResult))
local _,compiledInterior=compile("OwnedGarageInteriorRuntime",interiorRuntimeSource)
local _,compiledDisplay=compile("OwnedGarageDisplayRuntime",displayRuntimeSource)
local _,compiledManagement=compile("OwnedGarageManagementRuntime",managementRuntimeSource)
local _,compiledBrowser=compile("OwnedGarageBrowserController",browserControllerSource)
local _,compiledWorkspace=compile("OwnedGarageWorkspaceController",workspaceControllerSource)
do
	local emptySlot,emptyReason=compiledManagement.ChooseSlot({Space01=false,Space02="vehicle_b"})
	assert(emptySlot=="Space01" and emptyReason=="Empty","Management empty-slot audit failed")
	local fullSlot,fullReason=compiledManagement.ChooseSlot({Space01="vehicle_a",Space02="vehicle_b"})
	assert(fullSlot==nil and fullReason=="Full","Management full-garage audit failed")
	local replacement,replacementReason=compiledManagement.ChooseSlot({Space01="vehicle_a",Space02="vehicle_b"},"Space02")
	assert(replacement=="Space02" and replacementReason=="Requested","Management replacement audit failed")
	local invalid,invalidReason=compiledManagement.ChooseSlot({Space01=false,Space02=false},"Space99")
	assert(invalid==nil and invalidReason=="Invalid","Management invalid-slot audit failed")
	assert(type(compiledManagement.Start)=="function" and type(compiledBrowser.Start)=="function","Phase 3 start contract audit failed")
	assert(type(compiledWorkspace.Start)=="function" and #compiledStyles.List()>=10 and compiledStyles.IsValid("Walls","WALL_CONCRETE"),"Phase 4 workspace/style contract audit failed")
end
local templateValid,templateSummary=compiledInterior.AuditTemplate(stagedTemplate); assert(templateValid,"StarterTwoBay template audit failed: "..tostring(templateSummary))
local sanitizeSample=Instance.new("Model"); local samplePart=Instance.new("Part"); samplePart.Parent=sanitizeSample; local sampleSeat=Instance.new("VehicleSeat"); sampleSeat.Parent=sanitizeSample; local sampleScript=Instance.new("Script"); sampleScript.Parent=sanitizeSample; local sampleEmitter=Instance.new("ParticleEmitter"); sampleEmitter.Enabled=true; sampleEmitter.Parent=samplePart
local sanitizeSummary=compiledDisplay.SanitizeForDisplay(sanitizeSample); assert(sanitizeSummary.Parts==1 and sanitizeSummary.Removed==2 and sampleEmitter.Enabled==false and samplePart.Anchored==true and samplePart.CanCollide==false,"Display sanitization audit failed"); sanitizeSample:Destroy()
staged:Destroy()

local targets = {
	{ Parent=dataModules, Name="OwnedGaragePropertyCatalog", Source=catalogSource },
	{ Parent=dataModules, Name="OwnedGarageInteriorStyleCatalog", Source=interiorStyleCatalogSource },
	{ Parent=garageServices, Name="OwnedGarageProfileRuntime", Source=profileRuntimeSource },
	{ Parent=garageServices, Name="OwnedGarageDisplayAssignmentRuntime", Source=assignmentSource },
	{ Parent=garageServices, Name="OwnedGarageInteriorRuntime", Source=interiorRuntimeSource },
	{ Parent=garageServices, Name="OwnedGarageDisplayRuntime", Source=displayRuntimeSource },
	{ Parent=garageServices, Name="OwnedGarageManagementRuntime", Source=managementRuntimeSource },
	{ Parent=uiControllers, Name="OwnedGarageBrowserController", Source=browserControllerSource },
	{ Parent=uiControllers, Name="OwnedGarageWorkspaceController", Source=workspaceControllerSource },
}
local snapshots={}; local contractSnapshots={}; local created={}; local createdContainers={}; local configFolder; local configSnapshot; local installedTemplate; local templateCreated=false; local templatesFolder
local ok,err=pcall(function()
	local runtimeConfig=assert(findPath(kit,"Config.Runtime"),"Config.Runtime missing")
	configFolder=runtimeConfig:FindFirstChild("OwnedGarage_EditAttributes")
	if configFolder then
		assert(configFolder:IsA("Folder"),configFolder:GetFullName().." is not a Folder"); configSnapshot=configFolder:GetAttributes()
	else configFolder=Instance.new("Folder"); configFolder.Name="OwnedGarage_EditAttributes"; configFolder.Parent=runtimeConfig; table.insert(createdContainers,configFolder) end
	for key,value in pairs(configAttributes) do if configFolder:GetAttribute(key)==nil then configFolder:SetAttribute(key,value) end end
	local world=assert(Workspace:FindFirstChild("NeoTokyoRacersWorld"),"Workspace.NeoTokyoRacersWorld missing")
	local footExit=findPath(world,"Interactives.GarageInteriorElevatorMVP") or findPath(world,"Dealership.Spawn.VehicleExitSpawnPoint")
	local vehicleExit=findPath(world,"Dealership.Spawn.VehicleExitSpawnPoint") or findPath(world,"Garages.VehicleSpawnPoint")
	assert(footExit and footExit:IsA("BasePart"),"City foot-exit reference missing")
	assert(vehicleExit and vehicleExit:IsA("BasePart"),"City vehicle-exit reference missing")
	if configFolder:GetAttribute("CityFootExitCFrame")==nil then configFolder:SetAttribute("CityFootExitCFrame",footExit.CFrame*CFrame.new(0,3,-8)) end
	if configFolder:GetAttribute("CityVehicleExitCFrame")==nil then configFolder:SetAttribute("CityVehicleExitCFrame",vehicleExit.CFrame) end
	configFolder:SetAttribute("OwnedGarageRevision",REVISION)
	configFolder:SetAttribute("OwnedGarageInstallRunId",INSTALL_RUN_ID)
	local serverKit=assert(ServerStorage:FindFirstChild("NeoTokyoRacers"),"ServerStorage.NeoTokyoRacers missing")
	local ownedRoot=serverKit:FindFirstChild("OwnedGarage")
	if ownedRoot then assert(ownedRoot:IsA("Folder"),ownedRoot:GetFullName().." is not a Folder") else ownedRoot=Instance.new("Folder"); ownedRoot.Name="OwnedGarage"; ownedRoot.Parent=serverKit; table.insert(createdContainers,ownedRoot) end
	templatesFolder=ownedRoot:FindFirstChild("Templates")
	if templatesFolder then assert(templatesFolder:IsA("Folder"),templatesFolder:GetFullName().." is not a Folder") else templatesFolder=Instance.new("Folder"); templatesFolder.Name="Templates"; templatesFolder.Parent=ownedRoot; table.insert(createdContainers,templatesFolder) end
	local previous=templatesFolder:FindFirstChild("StarterTwoBay")
	if previous then
		local valid,message=compiledInterior.AuditTemplate(previous); assert(valid and previous:GetAttribute("OwnedGarageTemplateVersion")==1,"Existing StarterTwoBay is not the confirmed editable template: "..tostring(message)); installedTemplate=previous
	else installedTemplate=stagedTemplate:Clone(); installedTemplate:SetAttribute("OwnedGarageRevision",REVISION); installedTemplate.Parent=templatesFolder; templateCreated=true end
	for _,target in ipairs(targets) do
		local object=target.Parent:FindFirstChild(target.Name)
		if object then assert(object:IsA("ModuleScript"),object:GetFullName().." is not a ModuleScript"); snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}
		else object=Instance.new("ModuleScript"); object.Name=target.Name; table.insert(created,object) end
		object.Source=target.Source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",INSTALL_RUN_ID); if not object.Parent then object.Parent=target.Parent end
	end
	local remoteGarage=assert(findPath(kit,"Shared.Remotes.Garage"),"Shared.Remotes.Garage missing")
	for _,contract in ipairs({
		{Parent=remoteGarage,ClassName="RemoteFunction",Name="OwnedGarageInvoke"},
		{Parent=remoteGarage,ClassName="RemoteEvent",Name="OwnedGarageEvent"},
		{Parent=garageServices,ClassName="BindableFunction",Name="OwnedGarageVehicleLifecycleBridge"},
		{Parent=uiControllers,ClassName="BindableEvent",Name="OpenOwnedGarageBrowser"},
		{Parent=uiControllers,ClassName="BindableEvent",Name="OpenOwnedGarageWorkspace"},
	}) do
		local object=contract.Parent:FindFirstChild(contract.Name)
		if object then assert(object:IsA(contract.ClassName),object:GetFullName().." is not a "..contract.ClassName); contractSnapshots[object]={Revision=object:GetAttribute("OwnedGarageRevision"),StagingInert=object:GetAttribute("OwnedGarageStagingInert"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}
		else object=Instance.new(contract.ClassName); object.Name=contract.Name; object.Parent=contract.Parent; table.insert(created,object) end
		-- Roblox callback members are write-only. Inert staging is proved by the
		-- absence of active starter scripts plus this explicit installation marker;
		-- attempting to read OnServerInvoke/OnInvoke makes Edit-mode installation fail.
		object:SetAttribute("OwnedGarageStagingInert",true)
		object:SetAttribute("OwnedGarageRevision",REVISION)
		object:SetAttribute("OwnedGarageInstallRunId",INSTALL_RUN_ID)
	end
	for _,target in ipairs(targets) do local object=target.Parent:FindFirstChild(target.Name); assert(object and object.Source==target.Source,target.Name.." source audit failed") end
	assert(remoteGarage.OwnedGarageInvoke:IsA("RemoteFunction") and remoteGarage.OwnedGarageEvent:IsA("RemoteEvent"),"Phase 3 remote contract audit failed")
	assert(garageServices.OwnedGarageVehicleLifecycleBridge:IsA("BindableFunction") and uiControllers.OpenOwnedGarageBrowser:IsA("BindableEvent"),"Phase 3 local contract audit failed")
	assert(uiControllers.OpenOwnedGarageWorkspace:IsA("BindableEvent"),"Phase 4 workspace event contract audit failed")
	for _,object in ipairs({remoteGarage.OwnedGarageInvoke,remoteGarage.OwnedGarageEvent,garageServices.OwnedGarageVehicleLifecycleBridge,uiControllers.OpenOwnedGarageBrowser,uiControllers.OpenOwnedGarageWorkspace}) do
		assert(object:GetAttribute("OwnedGarageStagingInert")==true,object:GetFullName().." staging marker audit failed")
	end
	assert(typeof(configFolder:GetAttribute("CityFootExitCFrame"))=="CFrame" and typeof(configFolder:GetAttribute("CityVehicleExitCFrame"))=="CFrame","Phase 3 exit configuration audit failed")
	local starter=compiledCatalog.ById("STARTER_TWO_BAY"); assert(starter and starter.TemplateId=="StarterTwoBay","Starter property audit failed")
	local valid,summary=compiledInterior.AuditTemplate(installedTemplate); assert(valid and summary.DisplaySpaces==2,"Installed template audit failed: "..tostring(summary))
	local slotOne=compiledInterior.SlotCFrame(1); local slotTwo=compiledInterior.SlotCFrame(2); local configuredBase=configFolder:GetAttribute("InteriorBasePosition"); assert(typeof(configuredBase)=="Vector3" and (slotOne.Position-configuredBase).Magnitude<0.01 and (slotTwo.Position-slotOne.Position).Magnitude>=90,"Interior grid audit failed")
	local samplePool=Instance.new("Folder"); local sampleInterior,createMessage=compiledInterior.Create(samplePool,TESTER_USER_ID,"STARTER_TWO_BAY","StarterTwoBay",1); assert(sampleInterior,createMessage)
	local categoriesRoot=assert(findPath(kit,"Assets.Vehicles.Categories"),"Vehicle categories missing"); local cockpit
	for _,candidate in ipairs(categoriesRoot:GetDescendants()) do if candidate:IsA("Model") and tostring(candidate:GetAttribute("CockpitId") or "")~="" then cockpit=candidate; break end end
	assert(cockpit,"No cockpit template available for display audit"); local category=cockpit; while category.Parent~=categoriesRoot do category=category.Parent end
	local sampleProfile={CurrentCategory=category.Name,Vehicles={sample_vehicle={CategoryId=category.Name,CockpitInstanceId="sample_cockpit",InstalledModules={},CockpitColors={}}},OwnedCockpitInstances={sample_cockpit={TemplateId=cockpit:GetAttribute("CockpitId")}},OwnedModuleInstances={}}
	local firstDisplay,displaySummary=compiledDisplay.Build(sampleProfile,"sample_vehicle",sampleInterior.DisplaySpaceMarkers.Space01,sampleInterior); assert(firstDisplay and displaySummary.Parts>0,"Display build audit failed: "..tostring(displaySummary))
	local duplicate,duplicateMessage=compiledDisplay.Build(sampleProfile,"sample_vehicle",sampleInterior.DisplaySpaceMarkers.Space02,sampleInterior); assert(duplicate==nil and string.find(tostring(duplicateMessage),"Duplicate",1,true),"Display duplicate audit failed")
	for _,descendant in ipairs(firstDisplay:GetDescendants()) do assert(not descendant:IsA("Seat") and not descendant:IsA("Script") and not descendant:IsA("LocalScript"),"Unsafe display descendant: "..descendant.ClassName); if descendant:IsA("BasePart") then assert(descendant.Anchored and not descendant.CanCollide and not descendant.CastShadow,"Display part safety audit failed") end end
	samplePool:Destroy()
end)
if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for object,snapshot in pairs(contractSnapshots) do if object.Parent then object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageStagingInert",snapshot.StagingInert); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for _,object in ipairs(created) do if object.Parent then object:Destroy() end end
	if templateCreated and installedTemplate and installedTemplate.Parent then installedTemplate:Destroy() end
	if configFolder and configFolder.Parent and configSnapshot then for key in pairs(configFolder:GetAttributes()) do configFolder:SetAttribute(key,nil) end; for key,value in pairs(configSnapshot) do configFolder:SetAttribute(key,value) end end
	for index=#createdContainers,1,-1 do local object=createdContainers[index]; if object.Parent and #object:GetChildren()==0 then object:Destroy() end end
	stagedTemplate:Destroy()
	error(TAG .. " INSTALL ROLLED BACK: " .. tostring(err))
end
stagedTemplate:Destroy()

print(TAG .. " PHASE 0 EVIDENCE ACCEPTED static=41/2/0 server=3/0/0 client=4/1/0")
print(TAG .. " PHASE 1 FOUNDATION PASS testerUserId=" .. tostring(TESTER_USER_ID))
print(TAG .. " PHASE 2 TEMPLATE/RUNTIME PASS revision=" .. REVISION .. " displaySpaces=2")
print(TAG .. " PHASE 3 ENTRY/EXIT STAGING PASS ui=compiled remotes=inert lifecycleBridge=unowned")
print(TAG .. " PHASE 4 MANAGEMENT WORKSPACE STAGING PASS pages=DisplayCars/Interior/Access sharedWorkspace=true")
print(TAG .. " PHASE 4 NO-YIELD COMMIT PASS runId=" .. INSTALL_RUN_ID .. " placeId=" .. tostring(game.PlaceId))
print(TAG .. " INACTIVE: no HOME, profile, active service, Workspace interior, visible UI, vehicle ownership, or legacy-owner switch was performed.")
