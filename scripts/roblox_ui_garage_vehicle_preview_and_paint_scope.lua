-- Neo Tokyo Racers - Canonical vehicle preview snapshots and paint scopes
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE="INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Edit mode, not Play mode")
local REVISION="NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1"

local function need(parent,name,className)
	local object=parent:FindFirstChild(name)
	assert(object and object:IsA(className),"Missing "..parent:GetFullName().."."..name.." ("..className..")")
	return object
end
local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end
local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true)
	assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end
local function replaceRange(source,firstMarker,nextMarker,replacement,label)
	local first=string.find(source,firstMarker,1,true)
	assert(first,"Missing source start anchor: "..label)
	assert(not string.find(source,firstMarker,first+#firstMarker,true),"Duplicate source start anchor: "..label)
	local nextAt=string.find(source,nextMarker,first+#firstMarker,true)
	assert(nextAt,"Missing source end anchor: "..label)
	return string.sub(source,1,first-1)..replacement..string.sub(source,nextAt)
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local controllers=need(clientRoot,"Controllers","Folder")
local previewFolder=need(controllers,"Preview","Folder")
local uiFolder=need(controllers,"UI","Folder")
local previewVehicle=need(previewFolder,"PreviewVehicleController","ModuleScript")
local instancePreview=need(previewFolder,"GarageModuleInstancePreviewAdapter","ModuleScript")
local application=need(uiFolder,"ModuleShopUIController","ModuleScript")
local serverRoot=need(ServerScriptService,"NeoTokyoRacers","Folder")
local garageServices=need(need(serverRoot,"Services","Folder"),"Garage","Folder")
local garageAction=need(garageServices,"GarageActionController_Shadow_Disabled","Script")

assert(string.find(application.Source,"NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1",1,true),"Latest garage presentation baseline missing")
assert(string.find(application.Source,"NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1",1,true),"Atomic module transaction baseline missing")
assert(string.find(instancePreview.Source,"NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1",1,true),"Physical module preview baseline missing")
assert(string.find(garageAction.Source,"NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1",1,true),"Physical module customisation authority missing")

local previewProfileSource=[==[
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
-- Pure client-side projection for browser previews. It never changes ownership or calls the server.
local Resolver={}

local function clone(value,active)
	if typeof(value)~="table" then return value end
	active=active or {}; if active[value] then return active[value] end
	local copy={}; active[value]=copy
	for key,child in pairs(value) do copy[clone(key,active)]=clone(child,active) end
	return copy
end
local function byText(dictionary,key)
	if typeof(dictionary)~="table" or key==nil then return nil end
	local direct=dictionary[key] or dictionary[tostring(key)]; if direct~=nil then return direct end
	for id,item in pairs(dictionary) do if tostring(id)==tostring(key) then return item end end
end
local function defaultColours(cockpit)
	cockpit=cockpit or {}
	return {
		Primary=cockpit.DefaultPrimaryColor or Color3.fromRGB(0,205,230),
		Secondary=cockpit.DefaultSecondaryColor or Color3.fromRGB(235,247,204),
		Detail=cockpit.DefaultDetailColor or Color3.fromRGB(38,44,50),
		Neon=cockpit.DefaultNeonColor or Color3.fromRGB(255,255,255),
		FrontLights=cockpit.DefaultFrontLightsColor or Color3.fromRGB(252,250,255),
		RearLights=cockpit.DefaultRearLightsColor or Color3.fromRGB(255,116,116),
	}
end
local function defaultModules(cockpit)
	cockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId
	return {
		Engine1=engine,
		Engine2=cockpit.DefaultRearEngineModuleId or cockpit.DefaultEngineBModuleId or engine,
		Stabilisers=cockpit.DefaultStabilisersModuleId or cockpit.DefaultStabiliserModuleId,
		Boost=cockpit.DefaultBoostModuleId,
	}
end
local function cleanModules(source)
	local result={}; for slotId,moduleId in pairs(source or {}) do if moduleId~=nil and tostring(moduleId)~="" then result[slotId]=tostring(moduleId) end end; return result
end

function Resolver.Factory(state,row)
	local cockpit=row and row.Cockpit or {}; local colours=defaultColours(cockpit); local installed=cleanModules(defaultModules(cockpit)); local moduleColours={}
	for slotId in pairs(installed) do moduleColours[slotId]={Primary=colours.Primary,Secondary=colours.Secondary,Detail=colours.Detail,Neon=Color3.fromRGB(255,255,255)} end
	return {
		PreviewKind="Factory",CurrentCategory=row and row.CategoryId or state.CategoryId,CurrentCockpit=row and row.CockpitId or cockpit.CockpitId,CurrentVehicleId=nil,
		CockpitColors=colours,ThrustColor=Color3.fromRGB(255,255,255),InstalledModules=installed,ModuleColors=moduleColours,NeonOwned={},Vehicles={},OwnedModuleInstances={},
		Performance=row and row.Performance or nil,
	}
end

function Resolver.Owned(state,row)
	local source=state.Profile or {}; local vehicleId=row and row.VehicleId; local vehicle=byText(source.Vehicles,vehicleId)
	if typeof(vehicle)~="table" then return Resolver.Factory(state,row) end
	local cockpitColours=defaultColours(row and row.Cockpit); for channel,color in pairs(vehicle.CockpitColors or {}) do cockpitColours[channel]=color end
	local installed={}; local moduleColours={}; local neon={}; local levels={}
	for slotId,instanceId in pairs(vehicle.InstalledModules or {}) do
		local instance=byText(source.OwnedModuleInstances,instanceId)
		if typeof(instance)=="table" and instance.TemplateId then
			installed[slotId]=tostring(instance.TemplateId); moduleColours[slotId]=clone(instance.Colors or {}); neon[slotId]=instance.NeonOwned==true; levels[tostring(instance.TemplateId)]=clone(instance.UpgradeLevels or {})
		end
	end
	return {
		PreviewKind="OwnedVehicle",CurrentCategory=vehicle.CategoryId or (row and row.CategoryId) or state.CategoryId,CurrentCockpit=row and row.CockpitId,CurrentVehicleId=tostring(vehicleId),
		CockpitColors=cockpitColours,ThrustColor=vehicle.ThrustColor or Color3.fromRGB(255,255,255),InstalledModules=installed,ModuleColors=moduleColours,NeonOwned=neon,
		Vehicles=source.Vehicles,OwnedModuleInstances=source.OwnedModuleInstances,ModuleUpgradeLevels=levels,Performance=row and row.Performance or nil,
	}
end

function Resolver.ForBrowser(state,row)
	if state and state.ShopMode=="Customisation" and row and row.VehicleId then return Resolver.Owned(state,row) end
	return Resolver.Factory(state,row)
end

return Resolver
]==]
compile("GarageVehiclePreviewProfile",previewProfileSource)

local instanceSource=instancePreview.Source
if not string.find(instanceSource,REVISION,1,true) then
	instanceSource=replaceOnce(instanceSource,
		[[local profile=state and state.Profile; if typeof(profile)~="table" then return nil,nil,nil end]],
		[[local profile=state and (state.PreviewProfile or state.Profile); if typeof(profile)~="table" then return nil,nil,nil end -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1]],
		"installed preview profile")
	instanceSource=replaceOnce(instanceSource,
		[[local instance=ownedInstance(state.Profile,instanceId)]],
		[[local instance=ownedInstance(state.PreviewProfile or state.Profile,instanceId)]],
		"selected preview profile")
	instanceSource=replaceOnce(instanceSource,
		[[local profile=state and state.Profile or {}]],
		[[local profile=state and (state.PreviewProfile or state.Profile) or {}]],
		"resolved preview profile")
	instanceSource=replaceOnce(instanceSource,
		[[local profile=state and state.Profile; local base=profile and profile.Performance]],
		[[local profile=state and (state.PreviewProfile or state.Profile); local base=profile and profile.Performance]],
		"performance preview profile")
end
compile("GarageModuleInstancePreviewAdapter",instanceSource)

local vehicleSource=previewVehicle.Source
if not string.find(vehicleSource,REVISION,1,true) then
	vehicleSource=replaceOnce(vehicleSource,
		[[local state=context.State; if not state then return nil,"State missing" end; local categoriesRoot=context.CategoriesRoot; if not categoriesRoot then return nil,"Categories root missing" end]],
		[[local state=context.State; if not state then return nil,"State missing" end; local profile=state.PreviewProfile or state.Profile or {}; local categoriesRoot=context.CategoriesRoot; if not categoriesRoot then return nil,"Categories root missing" end -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1]],
		"preview build profile")
	vehicleSource=replaceOnce(vehicleSource,
		[[local cockpitId=state.SelectedCockpit or (state.Profile and state.Profile.CurrentCockpit) or "bruiser_01"]],
		[[local cockpitId=state.SelectedCockpit or profile.CurrentCockpit or "bruiser_01"]],
		"preview cockpit source")
	vehicleSource=replaceOnce(vehicleSource,
		[[local cockpitColors={}; for key,value in pairs((state.Profile and state.Profile.CockpitColors) or {}) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116); PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=state.Profile})]],
		[[local cockpitColors={}; for key,value in pairs(profile.CockpitColors or {}) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116); PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})]],
		"preview cockpit appearance")
	vehicleSource=replaceOnce(vehicleSource,
		[[local thrustColor=(state.Profile and state.Profile.ThrustColor) or Color3.new(1,1,1)]],
		[[local thrustColor=profile.ThrustColor or Color3.new(1,1,1)]],
		"preview thrust appearance")
	vehicleSource=replaceOnce(vehicleSource,
		[[local modulesToShow={}; for slotId,moduleId in pairs((state.Profile and state.Profile.InstalledModules) or {}) do modulesToShow[slotId]=moduleId end; for slotId,moduleId in pairs(state.PreviewModules or {}) do modulesToShow[slotId]=moduleId end]],
		[[local modulesToShow={}; for slotId,moduleId in pairs(profile.InstalledModules or {}) do modulesToShow[slotId]=moduleId end; for slotId,moduleId in pairs(state.PreviewModules or {}) do modulesToShow[slotId]=moduleId end]],
		"preview installed modules")
	vehicleSource=replaceOnce(vehicleSource,
		[[PaintClient.ApplyColors(clone,resolved.Colors,resolved.NeonOwned or state.PreviewNeonSlot==slotId,{Profile=state.Profile})]],
		[[PaintClient.ApplyColors(clone,resolved.Colors,resolved.NeonOwned or state.PreviewNeonSlot==slotId,{Profile=profile})]],
		"preview module appearance")

	local applyPaint=[==[
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
function PreviewVehicleController.ApplyPaint(context)
	local state=context.State; local preview=context.Preview or {}; local profile=state and (state.PreviewProfile or state.Profile); local vehicle=preview.Vehicle
	if not (profile and vehicle and vehicle.Parent) then return false end
	local target=tostring(context.Target or "Cockpit"); local channel=tostring(context.Channel or "Primary"); local color=context.Color
	if typeof(color)~="Color3" then return false end
	profile.CockpitColors=profile.CockpitColors or {}; profile.ModuleColors=profile.ModuleColors or {}
	if target=="THRUST_COLOR" then
		profile.ThrustColor=color; local root=preview.Root; if root then root:SetAttribute("ThrustColor",color); root:SetAttribute("ForceThrustPreview",true) end; vehicle:SetAttribute("ThrustColor",color); return true
	elseif target=="Cockpit" then
		profile.CockpitColors[channel]=color
	elseif target=="WholeVehicle" or target=="ALL" then
		if channel~="Neon" then profile.CockpitColors[channel]=color end
		for slotId in pairs(profile.InstalledModules or {}) do profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId][channel]=color end
	else profile.ModuleColors[target]=profile.ModuleColors[target] or {}; profile.ModuleColors[target][channel]=color end
	local cockpitColors={}; for key,value in pairs(profile.CockpitColors) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116)
	PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})
	local installed=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
	if installed then for slotId in pairs(profile.InstalledModules or {}) do local prefix="PREVIEW_"..tostring(slotId).."_"; for _,clone in ipairs(installed:GetChildren()) do if string.sub(clone.Name,1,#prefix)==prefix then PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(profile,slotId),(profile.NeonOwned or {})[slotId]==true,{Profile=profile}) end end end end
	return true
end
]==]
	vehicleSource=replaceRange(vehicleSource,"function PreviewVehicleController.ApplyPaint(context)","return PreviewVehicleController",applyPaint,"scoped preview paint")
end
compile("PreviewVehicleController",vehicleSource)

local applicationSource=application.Source
if not string.find(applicationSource,REVISION,1,true) then
	applicationSource=replaceOnce(applicationSource,
		[[local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController")); local InstancePreview=require(previewFolder:WaitForChild("GarageModuleInstancePreviewAdapter")) -- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1]],
		[[local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController")); local InstancePreview=require(previewFolder:WaitForChild("GarageModuleInstancePreviewAdapter")); local PreviewProfiles=require(previewFolder:WaitForChild("GarageVehiclePreviewProfile")) -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1]],
		"preview profile dependency")
	applicationSource=replaceOnce(applicationSource,
		[[SelectedColorChannel="Primary",PreviewModules={},GarageCameraActive=false}]],
		[[SelectedColorChannel="Primary",PreviewModules={},PreviewProfile=nil,GarageCameraActive=false}]],
		"preview profile state")

	local paintHandler=[==[
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
local function handlePaint(target,channel,color,commit)
	PreviewVehicle.ApplyPaint({State=State,Preview=preview,Target=target,Channel=channel,Color=color})
	if commit~=true then return end
	local result
	if target=="THRUST_COLOR" then result=action:Call("SetThrustColor",{Color=color,ReturnProfile=true})
	elseif target=="WholeVehicle" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true})
	elseif target=="ALL" then
		if channel=="Neon" then result=action:Call("SetModuleColor",{SlotId="ALL",Channel=channel,Color=color,ReturnProfile=true})
		else result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true}) end
	elseif target=="Cockpit" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="CockpitOnly",ReturnProfile=true})
	else result=action:Call("SetModuleColor",{SlotId=target,Channel=channel,Color=color,ReturnProfile=true}) end
	if not (result and result.Success) then local text=result and result.Message or "Colour could not be saved."; buildPreview(); if workspaceUI.Root.Visible then workspaceUI:Message(text) else warn("[NTR Canonical Garage] "..tostring(text)) end end
end
]==]
	applicationSource=replaceRange(applicationSource,"local function handlePaint(target,channel,color,commit)","local cameraRenderConnection",paintHandler,"authoritative paint handler")
	applicationSource=replaceOnce(applicationSource,
		[[State.Catalog=nil; State.Profile=nil; State.SelectedVehicleId=nil; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil; State.Stage="Closed"]],
		[[State.Catalog=nil; State.Profile=nil; State.PreviewProfile=nil; State.SelectedVehicleId=nil; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil; State.Stage="Closed"]],
		"close preview cleanup")
	applicationSource=replaceOnce(applicationSource,
		[[OnCategory=function(id,all) State.BrowseAll=all==true; if id then State.CategoryId=id end; State.SelectedVehicleId=nil; State.NoPreviewYet=true; renderBrowser() end,]],
		[[OnCategory=function(id,all) State.BrowseAll=all==true; if id then State.CategoryId=id end; State.SelectedVehicleId=nil; State.PreviewProfile=nil; State.NoPreviewYet=true; renderBrowser() end,]],
		"category preview cleanup")
	applicationSource=replaceOnce(applicationSource,
		[[OnSelect=function(row) State.SelectedCockpit=row.CockpitId; State.SelectedVehicleId=row.VehicleId; State.CategoryId=row.CategoryId or State.CategoryId; State.NoPreviewYet=false; buildPreview(); PreviewCamera.Reset(State,State.TargetFocus,cameraTransition()); renderBrowser() end,]],
		[[OnSelect=function(row) State.SelectedCockpit=row.CockpitId; State.SelectedVehicleId=row.VehicleId; State.CategoryId=row.CategoryId or State.CategoryId; State.PreviewProfile=PreviewProfiles.ForBrowser(State,row); State.NoPreviewYet=false; buildPreview(); PreviewCamera.Reset(State,State.TargetFocus,cameraTransition()); renderBrowser() end,]],
		"browser preview selection")
	applicationSource=replaceOnce(applicationSource,
		[[if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"]],
		[[if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"]],
		"confirmed vehicle preview handoff")
	applicationSource=replaceOnce(applicationSource,
		[[renderPaint=function() State.Stage="Paint"; browser:Hide(); local c=common("Paint Cockpit"); c.Subtitle="Choose primary, secondary, and detail colours."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Build Modules"; c.ColorChannels={"Primary","Secondary","Detail"}; c.SelectedChannel=State.SelectedColorChannel; c.Colors=State.Profile.CockpitColors or {}; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderPaint() end; c.OnColor=function(ch,color,commit) handlePaint("Cockpit",ch,color,commit) end; c.OnNext=function() State.ModuleMode="Slots"; State.ModuleOptionMode=nil; section("Engine1"); renderBuild() end; workspaceUI:Show(c) end]],
		[[renderPaint=function() State.Stage="Paint"; browser:Hide(); local c=common("Paint Vehicle"); c.Subtitle="Apply primary, secondary, and detail colours across the full vehicle."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Build Modules"; c.ColorChannels={"Primary","Secondary","Detail"}; c.SelectedChannel=State.SelectedColorChannel; c.Colors=State.Profile.CockpitColors or {}; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderPaint() end; c.OnColor=function(ch,color,commit) handlePaint("WholeVehicle",ch,color,commit) end; c.OnNext=function() State.ModuleMode="Slots"; State.ModuleOptionMode=nil; section("Engine1"); buildPreview(); renderBuild() end; workspaceUI:Show(c) end]],
		"whole vehicle initial paint")
end
compile("ModuleShopUIController",applicationSource)

local serverSource=garageAction.Source
if not string.find(serverSource,REVISION,1,true) then
	local cockpitColour=[==[
			elseif action == "SetCockpitColor" then
				local channel = tostring(args.Channel or "Primary")
				local color = args.Color
				local scope = tostring(args.Scope or "WholeVehicle")
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid colour."
				elseif channel ~= "Primary" and channel ~= "Secondary" and channel ~= "Detail" and channel ~= "Neon" and channel ~= "FrontLights" and channel ~= "RearLights" then ok, message = false, "Invalid colour channel."
				elseif scope ~= "WholeVehicle" and scope ~= "CockpitOnly" then ok, message = false, "Invalid cockpit colour scope."
				else
					local oldCockpitColors=V84_cloneDictionary(profile.CockpitColors or {})
					local oldModuleColors=V84_cloneDictionary(profile.ModuleColors or {})
					local oldModuleInstances=V84_cloneDictionary(profile.OwnedModuleInstances or {})
					local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
					local oldVehicleCockpit=typeof(currentVehicle)=="table" and V84_cloneDictionary(currentVehicle.CockpitColors or {}) or nil
					profile.CockpitColors[channel] = color
					if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=V84_cloneDictionary(profile.CockpitColors) end
					if scope == "WholeVehicle" and (channel == "Primary" or channel == "Secondary" or channel == "Detail") then
						V76_syncInstalledModulePaintFromCockpit(profile, channel)
						local captured,captureMessage=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player))
						if not captured then profile.CockpitColors=oldCockpitColors; profile.ModuleColors=oldModuleColors; profile.OwnedModuleInstances=oldModuleInstances; if typeof(currentVehicle)=="table" then currentVehicle.CockpitColors=oldVehicleCockpit end; ok,message=false,captureMessage else ok,message=true,"Vehicle colour updated." end
					else ok,message=true,"Cockpit colour updated." end
				end
				-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
]==]
	serverSource=replaceRange(serverSource,'\t\t\telseif action == "SetCockpitColor" then','\t\t\telseif action == "BuyModule" then',cockpitColour,"scoped cockpit paint action")
	local thrustColour=[==[
			elseif action == "SetThrustColor" then
				local color = args.Color
				if typeof(color) ~= "Color3" then ok, message = false, "Invalid thrust colour." else
					local oldThrust=profile.ThrustColor
					local oldModuleColors=V84_cloneDictionary(profile.ModuleColors or {})
					local oldModuleInstances=V84_cloneDictionary(profile.OwnedModuleInstances or {})
					local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
					local oldVehicleThrust=typeof(currentVehicle)=="table" and currentVehicle.ThrustColor or nil
					profile.ThrustColor = color
					if typeof(currentVehicle)=="table" then currentVehicle.ThrustColor=color end
					for slotId in pairs(profile.InstalledModules) do
						profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
						profile.ModuleColors[slotId].ThrustColor = color
					end
					local captured,captureMessage=V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(player))
					if not captured then profile.ThrustColor=oldThrust; profile.ModuleColors=oldModuleColors; profile.OwnedModuleInstances=oldModuleInstances; if typeof(currentVehicle)=="table" then currentVehicle.ThrustColor=oldVehicleThrust end; ok,message=false,captureMessage else ok,message=true,"Thrust colour updated." end
				end
]==]
	serverSource=replaceRange(serverSource,'\t\t\telseif action == "SetThrustColor" then','\t\t\telseif action == "DespawnVehicle" then',thrustColour,"authoritative thrust paint action")
	serverSource=replaceOnce(serverSource,
		[[if action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" then
				return { Success = ok == true, Message = message, ColorOnly = true }
			end]],
		[[if action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" then
				if args.ReturnProfile==true then return {Success=ok==true,Message=message,Profile=V56_profileForClient(profile)} end
				return { Success = ok == true, Message = message, ColorOnly = true }
			end]],
		"authoritative colour response")
end
compile("GarageActionController_Shadow_Disabled",serverSource)

local failures={}; local function expect(value,message) if not value then table.insert(failures,message) end end
expect(string.find(previewProfileSource,"PreviewKind=\"Factory\"",1,true)~=nil,"factory preview projection missing")
expect(string.find(previewProfileSource,"PreviewKind=\"OwnedVehicle\"",1,true)~=nil,"owned preview projection missing")
expect(string.find(applicationSource,"Scope=\"CockpitOnly\"",1,true)~=nil,"cockpit-only client scope missing")
expect(string.find(applicationSource,"handlePaint(\"WholeVehicle\"",1,true)~=nil,"whole-vehicle initial paint missing")
expect(string.find(serverSource,"V97_ModuleInstances.CaptureAll",1,true)~=nil,"whole-vehicle instance capture missing")
expect(string.find(serverSource,"args.ReturnProfile==true",1,true)~=nil,"authoritative colour response missing")
if #failures>0 then error("[NTR Garage Preview/Paint Scope] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Garage Preview/Paint Scope] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local existingProfile=previewFolder:FindFirstChild("GarageVehiclePreviewProfile")
assert(not existingProfile or existingProfile:IsA("ModuleScript"),"GarageVehiclePreviewProfile has the wrong class")
local createdProfile=existingProfile==nil
local oldProfileSource=existingProfile and existingProfile.Source
local oldInstanceSource=instancePreview.Source
local oldVehicleSource=previewVehicle.Source
local oldApplicationSource=application.Source
local oldServerSource=garageAction.Source

local ok,err=xpcall(function()
	local profileModule=existingProfile or Instance.new("ModuleScript")
	profileModule.Name="GarageVehiclePreviewProfile"; profileModule.Source=previewProfileSource; profileModule.Parent=previewFolder
	instancePreview.Source=instanceSource; previewVehicle.Source=vehicleSource; application.Source=applicationSource; garageAction.Source=serverSource
	assert(profileModule.Source==previewProfileSource and instancePreview.Source==instanceSource and previewVehicle.Source==vehicleSource and application.Source==applicationSource and garageAction.Source==serverSource,"Source readback mismatch")
	print("[NTR Garage Preview/Paint Scope] INSTALL PASS")
	print("Restart Play. Verify factory dealership previews, exact owned-vehicle previews, whole-vehicle Paint Vehicle persistence, cockpit-only Customise paint, module-only paint, and save/rejoin.")
end,debug.traceback)
if not ok then
	pcall(function() instancePreview.Source=oldInstanceSource end); pcall(function() previewVehicle.Source=oldVehicleSource end); pcall(function() application.Source=oldApplicationSource end); pcall(function() garageAction.Source=oldServerSource end)
	if createdProfile then pcall(function() local object=previewFolder:FindFirstChild("GarageVehiclePreviewProfile"); if object then object:Destroy() end end) else pcall(function() existingProfile.Source=oldProfileSource end) end
	error("[NTR Garage Preview/Paint Scope] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
