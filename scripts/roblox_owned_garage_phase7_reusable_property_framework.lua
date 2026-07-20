-- Neo Tokyo Racers - Owned Garage Phase 7 reusable property framework
-- Run once in Roblox Studio Edit-mode Command Bar after the ProfileService ownership gate passes.
-- This is the canonical Phase 7 installer. Rerun this same file after any repaired validation failure.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 7]"
local REVISION="NTR_OWNED_GARAGE_PHASE7_REUSABLE_PROPERTY_FRAMEWORK_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function has(object,marker)
	return object and object:IsA("LuaSourceContainer") and string.find(object.Source,marker,1,true)~=nil
end
local function replaceOnce(source,old,new,label)
	local first,last=string.find(source,old,1,true)
	assert(first,label.." anchor missing")
	assert(not string.find(source,old,last+1,true),label.." anchor is not unique")
	return string.sub(source,1,first-1)..new..string.sub(source,last+1)
end
local function compile(name,source)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data modules missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"UI controllers missing")

local propertyCatalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"OwnedGaragePropertyCatalog missing")
local profile=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"OwnedGarageProfileRuntime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"OwnedGarageDisplayAssignmentRuntime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"OwnedGarageManagementRuntime missing")
local browser=assert(ui:FindFirstChild("OwnedGarageBrowserController"),"OwnedGarageBrowserController missing")
local workspace=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")

local incomingRevision=tostring(config:GetAttribute("OwnedGarageRevision") or "")
assert(incomingRevision=="NTR_OWNED_GARAGE_PHASE6_ATOMIC_ACTIVATION_V1_1" or incomingRevision==REVISION,"Confirmed Phase 6 V1.1 is not current")
assert(has(profile,"NTR_OWNED_GARAGE_PROFILE_IDENTITY_STABILITY_V1"),"Profile identity-stability repair is missing")
assert(has(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET"),"Phase 6 management owner is missing")
assert(has(browser,"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED"),"Hardened browser baseline is missing")
assert(has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED"),"Hardened workspace baseline is missing")
local profileService=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Player.ProfileService_Active"),"ProfileService_Active missing")
assert(profileService:GetAttribute("SessionOwnershipHardeningVersion")==1 and profileService:GetAttribute("AuthoritativeSessionLifecycleVersion")==1 and has(profileService,"NTR_PROFILE_SERVICE_LIFECYCLE_GENERATION_V1"),"ProfileService ownership gate marker is missing")

local catalogSource=[==[
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT
local Catalog={DefinitionVersion=2,StateApiVersion=2}
local accessModes={"Private","FriendsOnly","InviteOnly","Public"}
local decorationCategories={
	{CategoryId="Plants",DisplayName="PLANTS",IconKey="Leaf",SortOrder=10},
	{CategoryId="Paintings",DisplayName="PAINTINGS",IconKey="Image",SortOrder=20},
	{CategoryId="Furniture",DisplayName="FURNITURE",IconKey="Chair",SortOrder=30},
	{CategoryId="Lighting",DisplayName="LIGHTING",IconKey="Light",SortOrder=40},
	{CategoryId="Storage",DisplayName="STORAGE",IconKey="Box",SortOrder=50},
	{CategoryId="Signs",DisplayName="SIGNS",IconKey="Sign",SortOrder=60},
}
local properties={
	{
		PropertyId="STARTER_TWO_BAY",
		DisplayName="Kanda Two-Bay",
		District="Kanda Stack Apartments",
		Description="A private two-bay workshop with vehicle display, interior customisation and secure access.",
		Image="",
		TemplateId="StarterTwoBay",
		DisplaySpaceIds={"Space01","Space02"},
		StructureSections={"FrontWall","LeftWall","RightWall","BackWall","Floor","Ceiling"},
		SurfaceGroups={"Floor","Walls","Roof","DisplayPads","Doors"},
		DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2"},
		Capabilities={DisplayCars=true,Structure=true,Decorations=true,Lighting=true,Access=true,Invitations=false,Visitors=false,DriveIn=true,DriveOut=true},
		UI={BrowserCardKind="GarageProperty",ManagementLayout="TwoBay",HeroAspectRatio=1.7778},
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
local function nonEmptyUnique(list,label)
	assert(type(list)=="table" and #list>0,label.." must be a non-empty array")
	local seen={}; for _,value in ipairs(list) do value=tostring(value or ""); assert(value~="",label.." contains an empty id"); assert(not seen[value],label.." contains duplicate "..value); seen[value]=true end
end
local function validateDefinition(definition,seen)
	assert(type(definition)=="table","Property definition must be a table")
	local id=tostring(definition.PropertyId or ""); assert(id~="","PropertyId required"); assert(not seen[id],"Duplicate PropertyId "..id); seen[id]=true
	assert(tostring(definition.TemplateId or "")~="",id.." TemplateId required")
	nonEmptyUnique(definition.DisplaySpaceIds,id.." DisplaySpaceIds")
	nonEmptyUnique(definition.SurfaceGroups,id.." SurfaceGroups")
	assert(type(definition.Capabilities)=="table",id.." Capabilities required")
	assert(type(definition.UI)=="table",id.." UI contract required")
	assert((tonumber(definition.VehicleCapacityContribution) or 0)>=#definition.DisplaySpaceIds,id.." capacity cannot be smaller than display spaces")
	return true
end
function Catalog.ValidateAll()
	local seen={}; local starterCount=0
	for _,definition in ipairs(properties) do validateDefinition(definition,seen); if definition.Starter then starterCount+=1 end end
	assert(starterCount==1,"Exactly one starter owned-garage property is required")
	return true,#properties
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
function Catalog.SpaceIds(propertyId) local property=Catalog.ById(propertyId); return property and clone(property.DisplaySpaceIds) or {} end
function Catalog.IsSpace(propertyId,slotId) for _,candidate in ipairs(Catalog.SpaceIds(propertyId)) do if candidate==tostring(slotId or "") then return true end end; return false end
function Catalog.AccessModes() return clone(accessModes) end
function Catalog.DecorationCategories() return clone(decorationCategories) end
function Catalog.Capabilities(propertyId) local property=Catalog.ById(propertyId); return property and clone(property.Capabilities) or {} end
function Catalog.ClientDefinition(propertyId)
	local property=Catalog.ById(propertyId); if not property then return nil end
	return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,DisplaySpaceIds=clone(property.DisplaySpaceIds),StructureSections=clone(property.StructureSections),SurfaceGroups=clone(property.SurfaceGroups),DecorationAnchorIds=clone(property.DecorationAnchorIds),Capabilities=clone(property.Capabilities),UI=clone(property.UI)}
end
Catalog.ValidateAll()
return Catalog
]==]

local assignmentSource=[==[
-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V1
-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Runtime={ApiVersion=2}
local locks=setmetatable({},{__mode="k"}); local completed=setmetatable({},{__mode="k"})
local function revision(profile) return math.max(0,math.floor(tonumber(profile and profile.OwnedGarage and profile.OwnedGarage.Revision) or 0)) end
local function fingerprint(operation,args)
	return table.concat({tostring(operation or ""),tostring(args.GarageId or ""),tostring(args.SlotId or ""),tostring(args.VehicleId or ""),tostring(args.SurfaceGroup or ""),tostring(args.StyleId or ""),tostring(args.AccessMode or "")},"|")
end
local function response(success,message,requestId,baseRevision,currentRevision,extra)
	local result={Success=success==true,Message=tostring(message or ""),RequestId=tostring(requestId or ""),BaseRevision=baseRevision,Revision=currentRevision,ApiVersion=Runtime.ApiVersion}
	for key,value in pairs(type(extra)=="table" and extra or {}) do result[key]=value end
	return result
end
function Runtime.Apply(player,profile,requestId,operation,args,commit)
	requestId=tostring(requestId or ""); args=type(args)=="table" and args or {}; local currentRevision=revision(profile); local baseRevision=tonumber(args.BaseRevision)
	local requestFingerprint=fingerprint(operation,args)
	if locks[player] then return response(false,"Garage request already in progress.",requestId,baseRevision,currentRevision,{Busy=true}) end
	if requestId=="" then return response(false,"Request id required.",requestId,baseRevision,currentRevision) end
	completed[player]=completed[player] or {}
	local previous=completed[player][requestId]
	if previous then
		if previous.Fingerprint~=requestFingerprint or previous.BaseRevision~=baseRevision then return response(false,"Request id was already used for a different garage mutation.",requestId,baseRevision,currentRevision,{RequestIdConflict=true}) end
		local replay={}; for key,value in pairs(previous.Result) do replay[key]=value end; replay.Replayed=true; return replay
	end
	if baseRevision~=nil and baseRevision~=currentRevision then
		local conflict=response(false,"Garage changed while this menu was open. The latest state has been loaded.",requestId,baseRevision,currentRevision,{Conflict=true,CurrentRevision=currentRevision})
		completed[player][requestId]={Fingerprint=requestFingerprint,BaseRevision=baseRevision,Result=conflict}; return conflict
	end
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
		return response(true,message,requestId,baseRevision,revision(profile),{State=Profile.State(profile)})
	end)
	if not ok then Profile.Restore(profile,before); result=response(false,tostring(result),requestId,baseRevision,revision(profile)) end
	locks[player]=nil; completed[player][requestId]={Fingerprint=requestFingerprint,BaseRevision=baseRevision,Result=result}
	local count=0; for _ in pairs(completed[player]) do count+=1 end; if count>64 then completed[player]={[requestId]=completed[player][requestId]} end
	return result
end
function Runtime.ForgetPlayer(player) locks[player]=nil; completed[player]=nil end
function Runtime.Validate(profile) return Profile.Validate(profile) end
return Runtime
]==]

local projected={}
local function setProjected(object,source)
	compile(object.Name,source); projected[object]=source
end
setProjected(propertyCatalog,catalogSource)
setProjected(assignment,assignmentSource)

local managementSource=management.Source
if not string.find(managementSource,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK",1,true) then
	managementSource=replaceOnce(managementSource,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK","management marker")
	managementSource=replaceOnce(managementSource,
		"local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local driveOut,exitOnFoot",
		"local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode=\"k\"}); local driveOut,exitOnFoot",
		"management cache owner")
	managementSource=replaceOnce(managementSource,
		'if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else push:FireClient(player,{Type="ManagementUpdated",Operation=operation}) end\n\t\treturn result',
		'if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else stateCache[player]=nil; push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}) end\n\t\treturn result',
		"management cache invalidation")
	local oldState=[=[	local function stateFor(player,profile)
		local properties={}; for _,definition in ipairs(catalog.List()) do local property=profile.OwnedGarage.Properties[definition.PropertyId]; if property and property.Owned then local filled=0; for _,vehicleId in pairs(property.DisplaySpaces) do if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then filled+=1 end end; table.insert(properties,{PropertyId=definition.PropertyId,DisplayName=definition.DisplayName,District=definition.District,Description=definition.Description,Image=definition.Image,TemplateId=definition.TemplateId,Capacity=#definition.DisplaySpaceIds,Filled=filled}) end end
		local session=sessions[player]; local currentProperty=session and profile.OwnedGarage.Properties[session.PropertyId]; local slots={}; local vehicles={}; local surfaceStyles={}
		if currentProperty then
			for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=currentProperty.DisplaySpaces[slotId]; table.insert(slots,{SlotId=slotId,VehicleId=vehicleId,DisplayName=(vehicleId and vehicleId~=false) and vehicleName(profile,vehicleId) or "Empty Display Space"}) end
			for surfaceGroup,styleId in pairs(currentProperty.Customisation.SurfaceStyles or {}) do surfaceStyles[surfaceGroup]=styleId end
		end
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=cockpitId,CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "")}) end end
		table.sort(vehicles,function(a,b) if a.DisplayName~=b.DisplayName then return a.DisplayName<b.DisplayName end return a.VehicleId<b.VehicleId end)
		return {Success=true,Properties=properties,ActiveGarageId=profile.OwnedGarage.ActiveGarageId,InGarage=session~=nil,CurrentPropertyId=session and session.PropertyId or nil,Slots=slots,Vehicles=vehicles,SurfaceStyles=surfaceStyles,InteriorStyles=styleCatalog.List(),AccessMode=currentProperty and currentProperty.AccessMode or "Private",Cash=tonumber(profile.Cash or profile.Money or profile.Credits) or 0}
	end]=]
	local newState=[=[	local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
	local function vehicleSignature(profile)
		local parts={}; for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpit=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; table.insert(parts,tostring(vehicleId)..":"..tostring((cockpit and cockpit.TemplateId) or vehicle.CockpitId or "")..":"..tostring(vehicle.DisplayName or "")) end end; table.sort(parts); return table.concat(parts,"|")
	end
	local function stateFor(player,profile)
		local session=sessions[player]; local sessionPropertyId=session and session.PropertyId or ""; local revision=math.max(0,math.floor(tonumber(profile.OwnedGarage.Revision) or 0)); local cash=tonumber(profile.Cash or profile.Money or profile.Credits) or 0; local signature=vehicleSignature(profile); local cached=stateCache[player]
		if cached and cached.Revision==revision and cached.SessionPropertyId==sessionPropertyId and cached.VehicleSignature==signature and cached.Cash==cash then local result=clone(cached.State); result.CacheHit=true; return result end
		local properties={}; for _,definition in ipairs(catalog.List()) do local property=profile.OwnedGarage.Properties[definition.PropertyId]; if property and property.Owned then local filled=0; for _,vehicleId in pairs(property.DisplaySpaces) do if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then filled+=1 end end; table.insert(properties,{PropertyId=definition.PropertyId,DisplayName=definition.DisplayName,District=definition.District,Description=definition.Description,Image=definition.Image,TemplateId=definition.TemplateId,Capacity=#definition.DisplaySpaceIds,Filled=filled,Capabilities=definition.Capabilities,UI=definition.UI,Definition=catalog.ClientDefinition(definition.PropertyId)}) end end
		local currentProperty=session and profile.OwnedGarage.Properties[session.PropertyId]; local slots={}; local vehicles={}; local surfaceStyles={}
		if currentProperty then local definition=catalog.ById(session.PropertyId); for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do local vehicleId=currentProperty.DisplaySpaces[slotId]; table.insert(slots,{SlotId=slotId,VehicleId=vehicleId,DisplayName=(vehicleId and vehicleId~=false) and vehicleName(profile,vehicleId) or "Empty Display Space"}) end; for surfaceGroup,styleId in pairs(currentProperty.Customisation.SurfaceStyles or {}) do surfaceStyles[surfaceGroup]=styleId end end
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=cockpitId,CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "")}) end end
		table.sort(vehicles,function(a,b) if a.DisplayName~=b.DisplayName then return a.DisplayName<b.DisplayName end return a.VehicleId<b.VehicleId end)
		local state={Success=true,ApiVersion=catalog.StateApiVersion,DefinitionVersion=catalog.DefinitionVersion,Revision=revision,Properties=properties,ActiveGarageId=profile.OwnedGarage.ActiveGarageId,InGarage=session~=nil,CurrentPropertyId=session and session.PropertyId or nil,Slots=slots,Vehicles=vehicles,SurfaceStyles=surfaceStyles,InteriorStyles=styleCatalog.List(),AccessModes=catalog.AccessModes(),DecorationCategories=catalog.DecorationCategories(),Capabilities=session and catalog.Capabilities(session.PropertyId) or {},AccessMode=currentProperty and currentProperty.AccessMode or "Private",Cash=cash,CacheHit=false}
		stateCache[player]={Revision=revision,SessionPropertyId=sessionPropertyId,VehicleSignature=signature,Cash=cash,State=clone(state)}; return state
	end]=]
	managementSource=replaceOnce(managementSource,oldState,newState,"management state projection")
	managementSource=replaceOnce(managementSource,
		'if action~="GetState" and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1)',
		'if action~="GetState" and action~="GetManagementState" and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1)',
		"read cooldown exemption")
	managementSource=replaceOnce(managementSource,
		'if action~="GetState" then lastRequest[player]=now end',
		'if action~="GetState" and action~="GetManagementState" then lastRequest[player]=now end',
		"read cooldown timestamp exemption")
	managementSource=replaceOnce(managementSource,
		'elseif action=="AssignDisplay" then return managedOperation(player,profile,"Assign",{SlotId=tostring(args.SlotId or ""),VehicleId=tostring(args.VehicleId or ""),RequestId=args.RequestId})\n\t\t\telseif action=="ClearDisplay" then return managedOperation(player,profile,"Clear",{SlotId=tostring(args.SlotId or ""),RequestId=args.RequestId})\n\t\t\telseif action=="SetInteriorStyle" then return managedOperation(player,profile,"SetSurfaceStyle",{SurfaceGroup=tostring(args.SurfaceGroup or ""),StyleId=tostring(args.StyleId or ""),RequestId=args.RequestId})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId}) end',
		'elseif action=="AssignDisplay" then return managedOperation(player,profile,"Assign",{SlotId=tostring(args.SlotId or ""),VehicleId=tostring(args.VehicleId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="ClearDisplay" then return managedOperation(player,profile,"Clear",{SlotId=tostring(args.SlotId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetInteriorStyle" then return managedOperation(player,profile,"SetSurfaceStyle",{SurfaceGroup=tostring(args.SurfaceGroup or ""),StyleId=tostring(args.StyleId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end',
		"revision forwarding")
	managementSource=replaceOnce(managementSource,
		'Players.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; slotByUserId[player.UserId]=nil;',
		'Players.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; stateCache[player]=nil; Assignment.ForgetPlayer(player); slotByUserId[player.UserId]=nil;',
		"player cache cleanup")
end
setProjected(management,managementSource)

local workspaceSource=workspace.Source
if not string.find(workspaceSource,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V3_REVISIONED",1,true) then
	workspaceSource=replaceOnce(workspaceSource,"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED","-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED\n-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V3_REVISIONED","workspace marker")
	workspaceSource=replaceOnce(workspaceSource,
		'local ReplicatedStorage=game:GetService("ReplicatedStorage"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")',
		'local ReplicatedStorage=game:GetService("ReplicatedStorage"); local HttpService=game:GetService("HttpService"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")',
		"workspace request id service")
	workspaceSource=replaceOnce(workspaceSource,
		'local function operate(action,args,nextPage) if busy then return end; busy=true; local result=request(action,args); busy=false; if not result.Success then workspace:Message(result.Message or "Garage update failed."); return end; if refresh(nextPage) then render() end end',
		'local function operate(action,args,nextPage) if busy then return end; args=type(args)=="table" and args or {}; args.BaseRevision=state and state.Revision or nil; args.RequestId=HttpService:GenerateGUID(false); busy=true; local result=request(action,args); busy=false; if not result.Success then if result.Conflict and refresh(nextPage) then render() end; workspace:Message(result.Message or "Garage update failed."); return end; if refresh(nextPage) then render() end end',
		"workspace revision transaction")
end
setProjected(workspace,workspaceSource)

local snapshots={}; local configSnapshot={}
for _,name in ipairs({"OwnedGarageRevision","OwnedGarageInstallRunId","DefinitionVersion","StateApiVersion"}) do configSnapshot[name]=config:GetAttribute(name) end
local ok,problem=pcall(function()
	for object,source in pairs(projected) do
		snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}
		object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	end
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("DefinitionVersion",2); config:SetAttribute("StateApiVersion",2)
	assert(has(propertyCatalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT"),"definition contract did not persist")
	assert(has(assignment,"NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED"),"revisioned assignment contract did not persist")
	assert(has(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK"),"cached state owner did not persist")
	assert(has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V3_REVISIONED"),"revisioned client contract did not persist")
	assert(config:GetAttribute("DefinitionVersion")==2 and config:GetAttribute("StateApiVersion")==2,"framework config versions did not persist")
end)
if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for name,value in pairs(configSnapshot) do config:SetAttribute(name,value) end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sources=4 definitions=1 apiVersion=2 definitionVersion=2 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY ON NEXT PLAY: catalogue-driven property capabilities, dynamic slot projection, revision conflicts, idempotent request replay and keyed state cache.")
print(TAG.." PRESERVED: Phase 6 UI/entry/exit behavior, OwnedGarage schema, vehicle ownership, display assignments and all unrelated systems.")
