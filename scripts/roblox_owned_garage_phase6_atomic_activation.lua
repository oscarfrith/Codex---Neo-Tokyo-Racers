-- Neo Tokyo Racers - Owned Garage Phase 6 atomic activation
-- Run once in Roblox Studio Edit-mode Command Bar after confirmed Phase 5 mirror.
-- Activates the canonical owned-garage stack and retires only the superseded physical-garage owners.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 6]"
local REVISION="NTR_OWNED_GARAGE_PHASE6_ATOMIC_ACTIVATION_V1_1"
local RUN_ID=HttpService:GenerateGUID(false)
local TESTER_USER_ID=7915427645

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
local function replaceAllExact(source,old,new,expected,label)
	local count=0; local cursor=1; local pieces={}
	while true do local first,last=string.find(source,old,cursor,true); if not first then table.insert(pieces,string.sub(source,cursor)); break end; count+=1; table.insert(pieces,string.sub(source,cursor,first-1)); table.insert(pieces,new); cursor=last+1 end
	assert(count==expected,label.." expected "..expected.." replacements, found "..count)
	return table.concat(pieces)
end
local function compile(name,source)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local services=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"UI controllers missing")
local worldControllers=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World"),"World controllers missing")
local remotes=assert(find(kit,"Shared.Remotes.Garage"),"Garage remotes missing")
local lifecycle=assert(services:FindFirstChild("OwnedGarageVehicleLifecycleBridge"),"OwnedGarageVehicleLifecycleBridge missing")

assert(config:GetAttribute("OwnedGarageRevision")=="NTR_OWNED_GARAGE_PHASE5_MOBILE_SAFETY_HARDENING_V1","Phase 5 revision is not current")
for _,contract in ipairs({
	{find(services,"OwnedGarageProfileRuntime"),"NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1"},
	{find(services,"OwnedGarageManagementRuntime"),"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1"},
	{find(ui,"OwnedGarageBrowserController"),"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED"},
	{find(ui,"OwnedGarageWorkspaceController"),"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V2_HARDENED"},
	{find(ui,"GarageInteriorModeController"),"NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V1"},
	{find(ui,"GarageInteriorTransitionController"),"NTR_OWNED_GARAGE_TRANSITION_CONTROLLER_V1"},
	{find(ui,"DesktopFreeRoamHudController_Active"),"NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1"},
	{find(ui,"MobileFreeRoamHudController_Active"),"NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1"},
	{find(services,"GarageActionController_Shadow_Disabled"),"NTR_OWNED_GARAGE_PHASE5_EXTERNAL_ACTION_GUARD_V1"},
}) do assert(has(contract[1],contract[2]),"Phase 5 contract missing: "..tostring(contract[2])) end
for _,name in ipairs({"OwnedGarageInvoke","OwnedGarageEvent"}) do assert(remotes:FindFirstChild(name),name.." missing") end
for _,name in ipairs({"OpenOwnedGarageBrowser","OpenOwnedGarageWorkspace"}) do assert(ui:FindFirstChild(name),name.." missing") end

local profile=services.OwnedGarageProfileRuntime
local management=services.OwnedGarageManagementRuntime
local action=services.GarageActionController_Shadow_Disabled
local desktop=ui.DesktopFreeRoamHudController_Active
local mobile=ui.MobileFreeRoamHudController_Active
local projected={}
local function project(object,marker,transform)
	local source=object.Source
	if not string.find(source,marker,1,true) then source=transform(source); assert(string.find(source,marker,1,true),object.Name.." marker missing after projection") end
	compile(object.Name,source); projected[object]=source
end

project(profile,"NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED",function(source)
	source=replaceAllExact(source,"profile.Garage","profile.OwnedGarage",5,"profile namespace")
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1","-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1\n-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED","profile marker")
	source=replaceOnce(source,
		'return {SchemaVersion=Runtime.SchemaVersion,Revision=0,ActiveGarageId="STARTER_TWO_BAY",Properties={STARTER_TWO_BAY=defaultProperty("STARTER_TWO_BAY")}}',
		'return {SchemaVersion=Runtime.SchemaVersion,Revision=0,TesterResetToken="",ActiveGarageId="STARTER_TWO_BAY",Properties={STARTER_TWO_BAY=defaultProperty("STARTER_TWO_BAY")}}',
		"profile reset token")
	source=replaceOnce(source,
		'local garage=profile.OwnedGarage; garage.Properties=type(garage.Properties)=="table" and garage.Properties or {}; garage.Revision=math.max(0,math.floor(tonumber(garage.Revision) or 0))',
		'local garage=profile.OwnedGarage; garage.Properties=type(garage.Properties)=="table" and garage.Properties or {}; garage.Revision=math.max(0,math.floor(tonumber(garage.Revision) or 0)); garage.TesterResetToken=tostring(garage.TesterResetToken or "")',
		"profile token normalization")
	return source
end)

project(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET",function(source)
	source=replaceAllExact(source,"profile.Garage","profile.OwnedGarage",12,"management namespace")
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET","management marker")
	source=replaceOnce(source,
		'local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local markDirty=bindings:WaitForChild("MarkDirty"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")',
		'local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local markDirty=bindings:WaitForChild("MarkDirty"); local saveNow=bindings:WaitForChild("SaveNow"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")',
		"management save binding")
	source=replaceOnce(source,
		'\tlocal function profileFor(player)\n\t\tlocal profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end\n\t\tlocal oldVersion=type(profile.OwnedGarage)=="table" and profile.OwnedGarage.SchemaVersion or nil; Profile.Ensure(profile,false); if oldVersion~=Profile.SchemaVersion then markDirty:Invoke(player,"OwnedGarageSchemaV2") end\n\t\treturn profile\n\tend',
		'\tlocal function profileFor(player)\n\t\tlocal profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end\n\t\tlocal resetToken=tostring(settings:GetAttribute("TesterResetToken") or ""); local resetUserId=math.floor(tonumber(settings:GetAttribute("TesterResetUserId")) or 0); local existing=type(profile.OwnedGarage)=="table" and profile.OwnedGarage or nil; local shouldReset=player.UserId==resetUserId and resetToken~="" and tostring(existing and existing.TesterResetToken or "")~=resetToken; local oldVersion=existing and existing.SchemaVersion or nil\n\t\tProfile.Ensure(profile,shouldReset); if shouldReset then profile.OwnedGarage.TesterResetToken=resetToken; local marked,markMessage=markDirty:Invoke(player,"OwnedGarageTesterReset:"..resetToken); if not marked then return nil,tostring(markMessage or "Tester reset could not be marked dirty.") end; local saved,saveMessage=saveNow:Invoke(player); if not saved then warn("[NTR Owned Garage] Tester reset save deferred: "..tostring(saveMessage)) end elseif oldVersion~=Profile.SchemaVersion then markDirty:Invoke(player,"OwnedGarageSchemaV2") end\n\t\treturn profile\n\tend',
		"management tester reset")
	source=replaceOnce(source,
		'\tPlayers.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; slotByUserId[player.UserId]=nil; if session and session.Interior then disconnectPrompts(session.Interior); session.Interior:Destroy() end end)',
		'\t-- NTR_OWNED_GARAGE_PHASE6_CHARACTER_CLEANUP_V1\n\tlocal function watchCharacter(player,character) local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",10); if humanoid then humanoid.Died:Connect(function() local session=sessions[player]; if session then abandonSession(player,session) end end) end end\n\tPlayers.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end); for _,player in ipairs(Players:GetPlayers()) do player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end\n\tPlayers.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; slotByUserId[player.UserId]=nil; setInside(player,nil); if session and session.Interior then disconnectPrompts(session.Interior); session.Interior:Destroy() end end)',
		"management character cleanup")
	return source
end)

project(action,"NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1",function(source)
	source=replaceOnce(source,
		'\t\tif not okConvert or typeof(converted) ~= "table" then\n\t\t\twarn("[NTR Persistence Phase 4] Legacy profile conversion failed: " .. tostring(converted))\n\t\t\treturn\n\t\tend\n\t\tlocal okImport, importOk, importMessage = pcall(function()',
		'\t\tif not okConvert or typeof(converted) ~= "table" then\n\t\t\twarn("[NTR Persistence Phase 4] Legacy profile conversion failed: " .. tostring(converted))\n\t\t\treturn\n\t\tend\n\t\t-- NTR_OWNED_GARAGE_PHASE6_PERSISTENCE_PRESERVE_V1\n\t\tlocal currentSaved=bindings.GetProfile:Invoke(player); if typeof(currentSaved)=="table" and typeof(currentSaved.OwnedGarage)=="table" then converted.OwnedGarage=V87_cloneValue(currentSaved.OwnedGarage) end\n\t\tlocal okImport, importOk, importMessage = pcall(function()',
		"vehicle import preservation")
	local bridgeSource=[[
	-- NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1
	local V100_ownedGarageLifecycle=script.Parent:WaitForChild("OwnedGarageVehicleLifecycleBridge")
	V100_ownedGarageLifecycle.OnInvoke=function(operation,payload)
		payload=typeof(payload)=="table" and payload or {}; local player=payload.Player
		if not (player and player:IsA("Player")) then return {Success=false,Message="Player is required."} end
		local profile=V56_getProfile(player)
		if operation=="GetDrivenVehicle" then
			local vehicle=V92_playerVehicle(player); if not (vehicle and V94_playerIsSeatedInVehicle(player,vehicle)) then return {Success=false,Message="No driven vehicle."} end
			local root=V91_rootPart(vehicle); local vehicleId=tostring(profile.CurrentVehicleId or ""); if vehicleId=="" then return {Success=false,Message="Driven vehicle identity is unavailable."} end
			return {Success=true,VehicleId=vehicleId,SpeedMph=V91_playerSpeedMph(player),VehicleCFrame=root and root.CFrame or nil}
		elseif operation=="DespawnForGarage" then
			local requested=tostring(payload.VehicleId or ""); if requested=="" or requested~=tostring(profile.CurrentVehicleId or "") then return {Success=false,Message="Driven vehicle identity changed."} end
			local ok,message=V92_despawnVehicle(player); return {Success=ok==true,Message=message}
		elseif operation=="SpawnFromGarage" then
			local vehicleId=tostring(payload.VehicleId or ""); local previousVehicleId=tostring(profile.CurrentVehicleId or ""); local selected,message=V89_selectVehicleInstance(profile,{VehicleId=vehicleId}); if not selected then return {Success=false,Message=message} end
			if not V76_coreModulesEquipped(profile) then if previousVehicleId~="" then V89_selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message="Equip at least one engine, stabilisers, and boost before driving."} end
			local vehicle,buildMessage=V56_buildVehicle(player,profile,payload.SpawnCFrame); if not vehicle then if previousVehicleId~="" then V89_selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message=buildMessage or "Vehicle spawn failed."} end
			V80_mirrorLegacyProfileToPersistence(player,profile,"OwnedGarageDriveOut",true); return {Success=true,Message="Vehicle spawned from garage.",Vehicle=vehicle,VehicleId=vehicleId}
		end
		return {Success=false,Message="Unknown owned garage lifecycle operation."}
	end
	V100_ownedGarageLifecycle:SetAttribute("OwnedGarageLifecycleReady",true)
]]
	source=replaceOnce(source,"\n\tV56_invoke.OnServerInvoke = function(player, action, args)","\n"..bridgeSource.."\n\tV56_invoke.OnServerInvoke = function(player, action, args)","lifecycle bridge hook")
	return source
end)

project(desktop,"NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1",function(source)
	return replaceOnce(source,
		'\tlocal garageAction = actionIcon("Garage", "GarageIcon", "HOME", function()\n\t\tif not interiorInvoke then showToast("GARAGE SERVICE NOT READY", false); return end\n\t\tlocal ok, result = pcall(function() return interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId }) end)\n\t\tshowToast(ok and result and result.Ok and "ENTERED GARAGE" or "GARAGE ENTRY FAILED", ok and result and result.Ok == true)\n\tend)',
		'\t-- NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1\n\tlocal garageAction = actionIcon("Garage", "GarageIcon", "HOME", function()\n\t\tif not fireUiEvent("OpenOwnedGarageBrowser") then showToast("MY GARAGES NOT READY", false) end\n\tend)',
		"desktop HOME switch")
end)

project(mobile,"NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1",function(source)
	return replaceOnce(source,
		'garageButton.Activated:Connect(function() if not interiorInvoke then showToast("GARAGE SERVICE NOT READY",false); return end; local ok,r=pcall(function() return interiorInvoke:InvokeServer("VisitGarage",{OwnerUserId=player.UserId}) end); showToast(ok and r and r.Ok and "ENTERED GARAGE" or "GARAGE ENTRY FAILED",ok and r and r.Ok==true) end)',
		'-- NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1\ngarageButton.Activated:Connect(function() if not fire("OpenOwnedGarageBrowser") then showToast("MY GARAGES NOT READY",false) end end)',
		"mobile HOME switch")
end)

local serverStarterSource=[==[
-- NTR_OWNED_GARAGE_SERVICE_ACTIVE_V1
local runtime=require(script.Parent:WaitForChild("OwnedGarageManagementRuntime"))
local ok,message=runtime.Start()
assert(ok,"Owned garage management failed to start: "..tostring(message))
script:SetAttribute("OwnedGarageRuntimeStarted",true)
print("[NTR Owned Garage] Canonical server service active.")
]==]
local clientStarterSource=[==[
-- NTR_OWNED_GARAGE_CLIENT_ACTIVE_V1
local order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}
for _,name in ipairs(order) do local controller=require(script.Parent:WaitForChild(name)); local ok,message=controller.Start(); assert(ok,"Owned garage client failed: "..name.." / "..tostring(message)) end
script:SetAttribute("OwnedGarageClientStarted",true)
print("[NTR Owned Garage] Canonical client active.")
]==]
compile("OwnedGarageService_Active",serverStarterSource); compile("OwnedGarageClient_Active",clientStarterSource)

local function requiredChild(parent,name,label)
	local object=parent:FindFirstChild(name)
	assert(object,label.." missing")
	return object
end
local legacy={
	requiredChild(services,"GarageInteriorService_Active","legacy interior service"),
	requiredChild(services,"GarageInteriorCustomizationService_Active","legacy interior customisation service"),
	requiredChild(worldControllers,"GarageInteriorClient_Active","legacy interior client"),
	requiredChild(worldControllers,"GarageInteriorCustomizationClient_Active","legacy customisation client"),
	requiredChild(worldControllers,"GarageAccessClient_Active","legacy access client"),
}
for _,object in ipairs(legacy) do assert(object:IsA("LuaSourceContainer") and object.Disabled==false,object:GetFullName().." is not the expected enabled legacy owner") end
local legacyEntrancePrompt=assert(find(game:GetService("Workspace"),"NeoTokyoRacersWorld.Interactives.GarageInteriorElevatorMVP.EnterPrivateGaragePrompt"),"legacy private-garage entrance prompt missing")
assert(legacyEntrancePrompt:IsA("ProximityPrompt"),"legacy private-garage entrance has wrong class")

local snapshots={}; local created={}; local configSnapshot={}; local contractSnapshot={}
for _,name in ipairs({"OwnedGarageRevision","OwnedGarageInstallRunId","ActivationEnabled","TesterResetUserId","TesterResetToken"}) do configSnapshot[name]=config:GetAttribute(name) end
for _,object in ipairs({remotes.OwnedGarageInvoke,remotes.OwnedGarageEvent,lifecycle,ui.OpenOwnedGarageBrowser,ui.OpenOwnedGarageWorkspace}) do contractSnapshot[object]={Inert=object:GetAttribute("OwnedGarageStagingInert"),Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")} end

local ok,problem=pcall(function()
	for object,source in pairs(projected) do snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}; object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	local function installScript(parent,name,className,source,marker)
		local object=parent:FindFirstChild(name)
		if object then assert(object.ClassName==className,name.." has wrong class"); snapshots[object]={Source=object.Source,Disabled=object.Disabled,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}
		else object=Instance.new(className); object.Name=name; table.insert(created,object) end
		object.Source=source; object.Disabled=false; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID); if not object.Parent then object.Parent=parent end; assert(has(object,marker),name.." source verification failed"); return object
	end
	installScript(services,"OwnedGarageService_Active","Script",serverStarterSource,"NTR_OWNED_GARAGE_SERVICE_ACTIVE_V1")
	installScript(ui,"OwnedGarageClient_Active","LocalScript",clientStarterSource,"NTR_OWNED_GARAGE_CLIENT_ACTIVE_V1")
	for _,object in ipairs(legacy) do snapshots[object]={Disabled=object.Disabled,Superseded=object:GetAttribute("OwnedGarageSuperseded"),Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}; object.Disabled=true; object:SetAttribute("OwnedGarageSuperseded",true); object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	snapshots[legacyEntrancePrompt]={Enabled=legacyEntrancePrompt.Enabled,Superseded=legacyEntrancePrompt:GetAttribute("OwnedGarageSuperseded"),Revision=legacyEntrancePrompt:GetAttribute("OwnedGarageRevision"),RunId=legacyEntrancePrompt:GetAttribute("OwnedGarageInstallRunId")}; legacyEntrancePrompt.Enabled=false; legacyEntrancePrompt:SetAttribute("OwnedGarageSuperseded",true); legacyEntrancePrompt:SetAttribute("OwnedGarageRevision",REVISION); legacyEntrancePrompt:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	for object in pairs(contractSnapshot) do object:SetAttribute("OwnedGarageStagingInert",false); object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	config:SetAttribute("ActivationEnabled",true); config:SetAttribute("TesterResetUserId",TESTER_USER_ID); config:SetAttribute("TesterResetToken",REVISION); config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	assert(has(profile,"NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED"),"namespaced profile missing")
	assert(has(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET"),"management reset contract missing")
	assert(has(action,"NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1") and has(action,"NTR_OWNED_GARAGE_PHASE6_PERSISTENCE_PRESERVE_V1"),"vehicle bridge contracts missing")
	assert(has(desktop,"NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1") and has(mobile,"NTR_OWNED_GARAGE_PHASE6_HOME_SWITCH_V1"),"HOME switch missing")
	assert(services.OwnedGarageService_Active.Disabled==false and ui.OwnedGarageClient_Active.Disabled==false,"canonical starters are not enabled")
	for _,object in ipairs(legacy) do assert(object.Disabled==true,"legacy owner remained enabled: "..object.Name) end; assert(legacyEntrancePrompt.Enabled==false,"legacy entrance prompt remained enabled")
end)

if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then if snapshot.Source then object.Source=snapshot.Source end; if snapshot.Disabled~=nil then object.Disabled=snapshot.Disabled end; if snapshot.Enabled~=nil then object.Enabled=snapshot.Enabled end; object:SetAttribute("OwnedGarageSuperseded",snapshot.Superseded); object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for _,object in ipairs(created) do if object.Parent then object:Destroy() end end
	for object,snapshot in pairs(contractSnapshot) do if object.Parent then object:SetAttribute("OwnedGarageStagingInert",snapshot.Inert); object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for name,value in pairs(configSnapshot) do config:SetAttribute(name,value) end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sources=5 starters=2 legacyRetired=6 testerUserId="..TESTER_USER_ID.." revision="..REVISION.." runId="..RUN_ID)
print(TAG.." ACTIVATED ON NEXT PLAY: canonical service/client, HOME browser, lifecycle bridge, namespaced persistence and one-token tester owned-garage reset.")
print(TAG.." PRESERVED: vehicle/cockpit/module data and profile.Garage capacity remain authoritative and are not reset.")
