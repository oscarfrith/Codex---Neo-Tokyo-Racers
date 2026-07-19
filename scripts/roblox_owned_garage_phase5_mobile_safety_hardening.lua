-- Neo Tokyo Racers - Owned Garage Phase 5 mobile/safety/performance hardening
-- Run once in Roblox Studio Edit-mode Command Bar after Phase 4 audit 18/0.
-- Transactional and inactive: stages client controllers and conditional safety guards only.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 5]"
local REVISION="NTR_OWNED_GARAGE_PHASE5_MOBILE_SAFETY_HARDENING_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function has(object,marker) return object and string.find(object.Source,marker,1,true)~=nil end
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
local services=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"UI controllers missing")
local racingServices=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Racing"),"Racing services missing")
local uiServices=assert(find(ServerScriptService,"NeoTokyoRacers.Services.UI"),"UI services missing")

assert(config:GetAttribute("OwnedGarageRevision")=="NTR_OWNED_GARAGE_PHASE4_MANAGEMENT_WORKSPACE_RECOVERY_V1","Phase 4 recovery revision is not current")
for _,contract in ipairs({
	{find(kit,"Shared.Modules.Data.OwnedGarageInteriorStyleCatalog"),"NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1"},
	{find(ui,"OwnedGarageBrowserController"),"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1"},
	{find(ui,"OwnedGarageWorkspaceController"),"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1"},
	{find(services,"OwnedGarageManagementRuntime"),"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1"},
}) do assert(has(contract[1],contract[2]),"Phase 4 source contract missing: "..tostring(contract[2])) end
assert(find(ui,"OpenOwnedGarageBrowser") and find(ui,"OpenOwnedGarageWorkspace"),"Owned garage open events missing")

local desktop=assert(find(ui,"DesktopFreeRoamHudController_Active"),"Desktop free-roam HUD missing")
local mobile=assert(find(ui,"MobileFreeRoamHudController_Active"),"Mobile free-roam HUD missing")
local browser=assert(find(ui,"OwnedGarageBrowserController"),"Owned garage browser missing")
local workspaceController=assert(find(ui,"OwnedGarageWorkspaceController"),"Owned garage workspace missing")
local garageAction=assert(find(services,"GarageActionController_Shadow_Disabled"),"Garage action owner missing")
local dealershipTeleport=assert(find(uiServices,"FreeRoamHudTeleportService_Active"),"Dealership teleport service missing")
local raceTeleport=assert(find(racingServices,"RaceBrowserTeleportService_Active"),"Race browser teleport service missing")

local projected={}
local function project(object,marker,transform)
	local source=object.Source
	if not string.find(source,marker,1,true) then source=transform(source); assert(string.find(source,marker,1,true),object.Name.." marker was not installed") end
	compile(object.Name,source); projected[object]=source
end

project(desktop,"NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1",function(source)
	source=replaceOnce(source,
		"\tleftCluster.Visible = not racingPresentationActive and not carPanel.Visible\n\tbottomActions.Visible = driving and not racingPresentationActive",
		"\t-- NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1\n\tlocal ownedGarageInside = player:GetAttribute(\"NTR_OwnedGarageInside\") == true\n\tleftCluster.Visible = not racingPresentationActive and not carPanel.Visible\n\tif minimap then minimap.Visible = not ownedGarageInside end\n\tbottomActions.Visible = driving and not racingPresentationActive",
		"desktop minimap visibility")
	source=replaceOnce(source,
		"\tif not (racingPresentationActive and readValue(racingPerformanceConfig, \"PauseFreeRoamMapDuringRace\", true) == true) then",
		"\tif not ownedGarageInside and not (racingPresentationActive and readValue(racingPerformanceConfig, \"PauseFreeRoamMapDuringRace\", true) == true) then",
		"desktop minimap update")
	return source
end)

project(mobile,"NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1",function(source)
	return replaceOnce(source,
		"\tlocal localMajorMenuOpen=modal.Visible or shade.Visible\n\tmapFrame.Visible=not telemetryOnly and not localMajorMenuOpen cash.Visible=not telemetryOnly and not localMajorMenuOpen nav.Visible=not telemetryOnly and not localMajorMenuOpen",
		"\tlocal localMajorMenuOpen=modal.Visible or shade.Visible\n\t-- NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1\n\tlocal ownedGarageInside=player:GetAttribute(\"NTR_OwnedGarageInside\")==true\n\tmapFrame.Visible=not ownedGarageInside and not telemetryOnly and not localMajorMenuOpen cash.Visible=not telemetryOnly and not localMajorMenuOpen nav.Visible=not telemetryOnly and not localMajorMenuOpen",
		"mobile minimap visibility")
end)

project(garageAction,"NTR_OWNED_GARAGE_PHASE5_EXTERNAL_ACTION_GUARD_V1",function(source)
	return replaceOnce(source,
		'\t\tif player:GetAttribute("NTR_RaceQueueActive")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle") then return {Ok=false,Success=false,Message="Leave the race queue before changing vehicles."} end',
		'\t\tif player:GetAttribute("NTR_RaceQueueActive")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle") then return {Ok=false,Success=false,Message="Leave the race queue before changing vehicles."} end\n\t\t-- NTR_OWNED_GARAGE_PHASE5_EXTERNAL_ACTION_GUARD_V1\n\t\tif player:GetAttribute("NTR_OwnedGarageInside")==true and (action=="SelectVehicleInstance" or action=="SpawnOwnedVehicleFromFreeRoam" or action=="SpawnVehicle" or action=="DespawnVehicle" or action=="ExitVehicle" or action=="ReEnterVehicle") then return {Ok=false,Success=false,Message="Use the garage display spaces or exit door while inside your garage."} end',
		"garage external vehicle guard")
end)

project(dealershipTeleport,"NTR_OWNED_GARAGE_PHASE5_TELEPORT_GUARD_V1",function(source)
	return replaceOnce(source,
		"local function performTeleport(player)\n",
		"local function performTeleport(player)\n\t-- NTR_OWNED_GARAGE_PHASE5_TELEPORT_GUARD_V1\n\tif player:GetAttribute(\"NTR_OwnedGarageInside\")==true then return {Ok=false,Success=false,Message=\"Exit your garage before teleporting to the dealership.\"} end\n",
		"dealership teleport guard")
end)

project(raceTeleport,"NTR_OWNED_GARAGE_PHASE5_TELEPORT_GUARD_V1",function(source)
	return replaceOnce(source,
		"local function teleportToEvent(player, payload)\n",
		"local function teleportToEvent(player, payload)\n\t-- NTR_OWNED_GARAGE_PHASE5_TELEPORT_GUARD_V1\n\tif player:GetAttribute(\"NTR_OwnedGarageInside\")==true then return {Ok=false,Success=false,Message=\"Exit your garage before teleporting to a race.\"} end\n",
		"race teleport guard")
end)

project(browser,"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED",function(source)
	source=replaceOnce(source,
		"-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1\nlocal Controller={}; local started=false",
		"-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1\n-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED\nlocal Controller={}; local started=false; local closeCurrent=function() end; local isOpenCurrent=function() return false end\nfunction Controller.Close(reason) closeCurrent(reason) end\nfunction Controller.IsOpen() return isOpenCurrent() end",
		"browser controller API")
	source=replaceOnce(source,
		"\tif Mobile.IsEnabled(UserInputService.TouchEnabled) then Mobile.Attach(shell) else shell.Size=UDim2.fromOffset(1200,720); UI.AttachResponsiveScale(shell) end",
		"\tlocal layoutScale; if Mobile.IsEnabled(UserInputService.TouchEnabled) then layoutScale=Mobile.Attach(shell) else shell.Size=UDim2.fromOffset(1200,720); layoutScale=UI.AttachResponsiveScale(shell) end\n\tlocal settings=kit.Config.Runtime:WaitForChild(\"OwnedGarage_EditAttributes\")\n\tlocal function hardenTouch() if not UserInputService.TouchEnabled then return end; local scale=math.max(layoutScale and layoutScale.Scale or 1,.01); local minimum=math.ceil(math.max(32,tonumber(settings:GetAttribute(\"MinimumTouchTargetPixels\")) or 44)/scale); for _,object in ipairs(overlay:GetDescendants()) do if object:IsA(\"GuiButton\") then local original=object:GetAttribute(\"NTR_OwnedGarageOriginalSize\"); if typeof(original)~=\"UDim2\" then original=object.Size; object:SetAttribute(\"NTR_OwnedGarageOriginalSize\",original) end; if original.Y.Scale==0 then object.Size=UDim2.new(original.X.Scale,original.X.Offset,0,math.max(original.Y.Offset,minimum)) end end end end\n\tif layoutScale then layoutScale:GetPropertyChangedSignal(\"Scale\"):Connect(function() if overlay.Visible then task.defer(hardenTouch) end end) end",
		"browser touch adapter")
	source=replaceOnce(source,
		'\tlocal exit=Shared.ActionButton(shell,{Name="Exit",Text="EXIT",IconText="×",Size=UDim2.fromOffset(220,48),Color=C("PanelSoft"),StrokeColor=C("Outline")}); exit.Position=UDim2.new(0,24,1,-64)\n\tlocal enter=Shared.ActionButton(shell,{Name="Enter",Text="ENTER GARAGE",IconText="E",Size=UDim2.fromOffset(300,48),Color=C("PanelBlue"),StrokeColor=C("Telemetry")}); enter.AnchorPoint=Vector2.new(1,0); enter.Position=UDim2.new(1,-24,1,-64)',
		'\tlocal exit=Shared.ActionButton(shell,{Name="Exit",Text="EXIT",IconText="×",Size=UDim2.fromOffset(220,48),Color=C("PanelSoft"),StrokeColor=C("Outline")}); exit.AnchorPoint=Vector2.new(0,1); exit.Position=UDim2.new(0,24,1,-16)\n\tlocal enter=Shared.ActionButton(shell,{Name="Enter",Text="ENTER GARAGE",IconText="E",Size=UDim2.fromOffset(300,48),Color=C("PanelBlue"),StrokeColor=C("Telemetry")}); enter.AnchorPoint=Vector2.new(1,1); enter.Position=UDim2.new(1,-24,1,-16); if UserInputService.TouchEnabled then status.Position=UDim2.new(0,24,1,-150) end',
		"browser bottom actions")
	source=replaceOnce(source,
		'\tlocal function close() overlay.Visible=false; presentation(false); setStatus("") end',
		'\tlocal function close() for _,child in ipairs(shell:GetChildren()) do if child.Name=="ReplacementPrompt" then child:Destroy() end end; overlay.Visible=false; presentation(false); setStatus("") end; closeCurrent=close; isOpenCurrent=function() return overlay.Visible end',
		"browser close contract")
	source=replaceOnce(source,
		'panel.Size=UDim2.fromOffset(560,330); panel.ZIndex=201;',
		'local touchPrompt=UserInputService.TouchEnabled; panel.Size=UDim2.fromOffset(touchPrompt and 720 or 560,touchPrompt and 600 or 330); panel.ZIndex=201;',
		"browser replacement panel")
	source=replaceOnce(source,
		'Size=UDim2.new(1,-48,0,58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*68);',
		'Size=UDim2.new(1,-48,0,touchPrompt and 112 or 58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*(touchPrompt and 124 or 68));',
		"browser replacement slots")
	source=replaceOnce(source,
		'\t\tlocal cancel=Shared.ActionButton(panel,{Name="Cancel",Text="CANCEL",IconText="×",Size=UDim2.fromOffset(180,42),Color=C("PanelSoft"),StrokeColor=C("Outline")}); cancel.AnchorPoint=Vector2.new(.5,1); cancel.Position=UDim2.new(.5,0,1,-14); cancel.ZIndex=203; cancel.Activated:Connect(function() shade:Destroy() end)',
		'\t\tlocal cancel=Shared.ActionButton(panel,{Name="Cancel",Text="CANCEL",IconText="×",Size=UDim2.fromOffset(180,touchPrompt and 112 or 42),Color=C("PanelSoft"),StrokeColor=C("Outline")}); cancel.AnchorPoint=Vector2.new(.5,1); cancel.Position=UDim2.new(.5,0,1,-14); cancel.ZIndex=203; cancel.Activated:Connect(function() shade:Destroy() end); task.defer(hardenTouch)',
		"browser replacement touch")
	source=replaceOnce(source,
		'\t\tlocal result=request("GetState",{}); if not result.Success then overlay.Visible=true; presentation(true); setStatus(result.Message,false); return end; state=result;',
		'\t\tlocal result=request("GetState",{}); if not result.Success then overlay.Visible=true; presentation(true); setStatus(result.Message,false); task.defer(hardenTouch); return end; state=result;',
		"browser failure touch")
	source=replaceOnce(source,
		'render(); overlay.Visible=true; presentation(true); setStatus("")',
		'render(); overlay.Visible=true; presentation(true); setStatus(""); task.defer(hardenTouch)',
		"browser open touch")
	return source
end)

project(workspaceController,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED",function(source)
	source=replaceOnce(source,
		"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1\nlocal Controller={}; local started=false",
		"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1\n-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED\nlocal Controller={}; local started=false; local closeCurrent=function() end; local isOpenCurrent=function() return false end\nfunction Controller.Close(reason) closeCurrent(reason) end\nfunction Controller.IsOpen() return isOpenCurrent() end",
		"workspace controller API")
	source=replaceOnce(source,
		'\tlocal workspace=WorkspaceUI.new(); workspace.Root.Name="OwnedGarageCanonicalWorkspace"; workspace.Audit=function(self) Shared.AuditPresentation(self.Root,"Owned Garage Workspace") end',
		'\tlocal workspace=WorkspaceUI.new(); workspace.Root.Name="OwnedGarageCanonicalWorkspace"; workspace.Audit=function(self) Shared.AuditPresentation(self.Root,"Owned Garage Workspace") end\n\tlocal settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes"); local UserInputService=game:GetService("UserInputService")\n\tlocal function presentation(active) local event=uiFolder:FindFirstChild("FreeRoamHudPresentationMode"); if event and event:IsA("BindableEvent") then event:Fire({Owner="OwnedGarageWorkspace",Active=active==true,KeepTelemetry=false}) end end\n\tlocal function hardenTouch() if not UserInputService.TouchEnabled then return end; local scale=math.max(workspace.Scale and workspace.Scale.Scale or 1,.01); local minimum=math.ceil(math.max(32,tonumber(settings:GetAttribute("MinimumTouchTargetPixels")) or 44)/scale); for _,object in ipairs(workspace.Root:GetDescendants()) do if object:IsA("GuiButton") then local original=object:GetAttribute("NTR_OwnedGarageOriginalSize"); if typeof(original)~="UDim2" then original=object.Size; object:SetAttribute("NTR_OwnedGarageOriginalSize",original) end; if original.Y.Scale==0 then object.Size=UDim2.new(original.X.Scale,original.X.Offset,0,math.max(original.Y.Offset,minimum)) elseif object.Parent and object.Parent.Name=="CardActionPopup" then local popup=object.Parent; local popupOriginal=popup:GetAttribute("NTR_OwnedGarageOriginalSize") or popup.Size; popup:SetAttribute("NTR_OwnedGarageOriginalSize",popupOriginal); popup.Size=UDim2.new(popupOriginal.X.Scale,popupOriginal.X.Offset,0,math.max(popupOriginal.Y.Offset,minimum)) end end end end',
		"workspace touch adapter")
	source=replaceOnce(source,
		'\tlocal function close() workspace:Hide() end',
		'\tlocal function close() workspace:Hide(); presentation(false) end; closeCurrent=close; isOpenCurrent=function() return workspace.Root.Visible end',
		"workspace close contract")
	source=replaceOnce(source,
		'\t\tworkspace:Show(view); hidePlus()',
		'\t\tworkspace:Show(view); hidePlus(); presentation(true); task.defer(hardenTouch)',
		"workspace open hardening")
	source=replaceOnce(source,
		'\topenEvent.Event:Connect(function() if workspace.Root.Visible then close() else open() end end);',
		'\tif workspace.Scale then workspace.Scale:GetPropertyChangedSignal("Scale"):Connect(function() if workspace.Root.Visible then task.defer(hardenTouch) end end) end; openEvent.Event:Connect(function() if workspace.Root.Visible then close() else open() end end);',
		"workspace scale listener")
	return source
end)

local modeSource=[==[
-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
	local function publish() playerGui:SetAttribute("NTR_OwnedGarageInteriorMode",player:GetAttribute("NTR_OwnedGarageInside")==true) end
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(publish); publish(); started=true
	print("[NTR Owned Garage] Interior HUD policy active."); return true,"Started"
end
return Controller
]==]

local transitionSource=[==[
-- NTR_OWNED_GARAGE_TRANSITION_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local player=Players.LocalPlayer; local ui=script.Parent
	local Browser=require(ui:WaitForChild("OwnedGarageBrowserController")); local Workspace=require(ui:WaitForChild("OwnedGarageWorkspaceController")); local presentation=ui:WaitForChild("FreeRoamHudPresentationMode")
	local function closeOwned() Browser.Close("Transition"); Workspace.Close("Transition") end
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then closeOwned() end end)
	player.CharacterAdded:Connect(function() task.defer(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then closeOwned() end end) end)
	presentation.Event:Connect(function(message) if typeof(message)~="table" or message.Active~=true then return end; local owner=tostring(message.Owner or ""); if owner~="OwnedGarageBrowser" and owner~="OwnedGarageWorkspace" then closeOwned() end end)
	started=true; print("[NTR Owned Garage] Transition cleanup active."); return true,"Started"
end
return Controller
]==]
compile("GarageInteriorModeController",modeSource); compile("GarageInteriorTransitionController",transitionSource)

local snapshots={}; local created={}; local configSnapshot={}
for _,name in ipairs({"MinimumTouchTargetPixels","SuppressMinimapInside","BlockExternalVehicleActionsInside","BlockExternalTeleportActionsInside","OwnedGarageRevision","OwnedGarageInstallRunId"}) do configSnapshot[name]=config:GetAttribute(name) end
local ok,problem=pcall(function()
	for object,source in pairs(projected) do snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}; object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	local function installModule(name,source,marker)
		local object=ui:FindFirstChild(name)
		if object then assert(object:IsA("ModuleScript"),name.." has wrong class"); snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId"),Inert=object:GetAttribute("OwnedGarageStagingInert")}
		else object=Instance.new("ModuleScript"); object.Name=name; table.insert(created,object) end
		object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID); object:SetAttribute("OwnedGarageStagingInert",true); if not object.Parent then object.Parent=ui end; assert(has(object,marker),name.." verification failed")
	end
	installModule("GarageInteriorModeController",modeSource,"NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V1")
	installModule("GarageInteriorTransitionController",transitionSource,"NTR_OWNED_GARAGE_TRANSITION_CONTROLLER_V1")
	config:SetAttribute("MinimumTouchTargetPixels",44); config:SetAttribute("SuppressMinimapInside",true); config:SetAttribute("BlockExternalVehicleActionsInside",true); config:SetAttribute("BlockExternalTeleportActionsInside",true); config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	for object,source in pairs(projected) do assert(object.Source==source,object.Name.." readback mismatch") end
	assert(has(ui.GarageInteriorModeController,"NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V1"),"mode controller missing")
	assert(has(ui.GarageInteriorTransitionController,"NTR_OWNED_GARAGE_TRANSITION_CONTROLLER_V1"),"transition controller missing")
end)
if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId); object:SetAttribute("OwnedGarageStagingInert",snapshot.Inert) end end
	for _,object in ipairs(created) do if object.Parent then object:Destroy() end end
	for name,value in pairs(configSnapshot) do config:SetAttribute(name,value) end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sources=7 controllers=2 touchMin=44 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." INACTIVE: no service/controller was started, HOME was not switched, and no profile/session/vehicle/interior was changed.")
print(TAG.." NEXT: refresh the Studio mirror; Phase 6 will perform the one atomic activation and runtime verification.")
