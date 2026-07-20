-- Neo Tokyo Racers - Owned Garage Phase 8 transition completion
-- Run once in Roblox Studio Edit mode after confirmed/mirrored Phase 8 V1.8.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local Workspace=game:GetService("Workspace")
local TAG="[NTR Owned Garage Transition Completion]"
local REVISION="NTR_OWNED_GARAGE_PHASE8_TRANSITION_COMPLETION_V1"
local BASE_REVISION="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_8"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function has(object,marker) return object and object:IsA("LuaSourceContainer") and string.find(object.Source,marker,1,true)~=nil end
local function replaceOnce(source,old,new,label)
	local first,last=string.find(source,old,1,true); assert(first,label.." anchor missing"); assert(not string.find(source,old,last+1,true),label.." anchor is not unique")
	return string.sub(source,1,first-1)..new..string.sub(source,last+1)
end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data modules missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local preview=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview"),"Preview controllers missing")
local world=assert(Workspace:FindFirstChild("NeoTokyoRacersWorld"),"NeoTokyoRacersWorld missing")
local catalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"OwnedGaragePropertyCatalog missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"OwnedGarageManagementRuntime missing")
local action=assert(garage:FindFirstChild("GarageActionController_Shadow_Disabled"),"GarageActionController missing")
local thrust=assert(preview:FindFirstChild("ThrustPreviewController_Active"),"ThrustPreviewController_Active missing")
local OLD_THRUST_REFRESH='\tlocal playerVehicle=getPlayerVehicle(); local playerColor=playerVehicle and (playerVehicle:GetAttribute("ThrustColor") or Color3.new(1,1,1)); if playerVehicle~=cachedPlayerVehicle or playerColor~=cachedPlayerColor then cachedPlayerVehicle,cachedPlayerColor=playerVehicle,playerColor; applyThrustOnly(playerVehicle,playerColor or Color3.new(1,1,1),nil) end'
local NEW_THRUST_REFRESH='\tlocal playerVehicle=getPlayerVehicle(); local playerColor=playerVehicle and (playerVehicle:GetAttribute("ThrustColor") or Color3.new(1,1,1)); if playerVehicle~=cachedPlayerVehicle or playerColor~=cachedPlayerColor then cachedPlayerVehicle,cachedPlayerColor=playerVehicle,playerColor end'

local installed=config:GetAttribute("OwnedGarageRevision")
assert(installed==BASE_REVISION or installed==REVISION,"Phase 8 V1.8 transition baseline is not current")
for object,marker in pairs({
	[catalog]="NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY",
	[management]="NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY",
	[action]="NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1",
	[thrust]="NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1",
}) do assert(has(object,marker),"Required baseline contract missing: "..marker) end
assert(installed==REVISION or string.find(thrust.Source,OLD_THRUST_REFRESH,1,true) or string.find(thrust.Source,NEW_THRUST_REFRESH,1,true),"Expected stale or repaired thrust refresh contract is absent or changed")
assert(typeof(config:GetAttribute("CityFootExitCFrame"))=="CFrame","CityFootExitCFrame seed missing")
assert(typeof(config:GetAttribute("CityVehicleExitCFrame"))=="CFrame","CityVehicleExitCFrame seed missing")

local projected={}
local function project(object,marker,transform)
	local source=object.Source
	if not string.find(source,marker,1,true) then source=transform(source); assert(string.find(source,marker,1,true),object.Name.." marker missing after projection") end
	compile(object.Name,source); projected[object]=source
end

project(catalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY","-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY\n-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS","catalog exterior marker")
	source=replaceOnce(source,'\t\tTemplateId="StarterTwoBay",','\t\tTemplateId="StarterTwoBay",\n\t\tExteriorSpawnId="STARTER_TWO_BAY",',"starter exterior id")
	source=replaceOnce(source,'\tassert(tostring(definition.TemplateId or "")~="",id.." TemplateId required")','\tassert(tostring(definition.TemplateId or "")~="",id.." TemplateId required"); assert(tostring(definition.ExteriorSpawnId or "")~="",id.." ExteriorSpawnId required")',"exterior definition validation")
	source=replaceOnce(source,'return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,TemplateContractVersion=property.TemplateContractVersion','return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,ExteriorSpawnId=property.ExteriorSpawnId,TemplateContractVersion=property.TemplateContractVersion',"client exterior definition")
	return source
end)

project(action,"NTR_OWNED_GARAGE_PHASE8_TRANSITION_DESPAWN_HANDSHAKE_V1",function(source)
	source=replaceOnce(source,"\t-- NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1","\t-- NTR_OWNED_GARAGE_PHASE6_LIFECYCLE_BRIDGE_V1\n\t-- NTR_OWNED_GARAGE_PHASE8_TRANSITION_DESPAWN_HANDSHAKE_V1","lifecycle transition marker")
	local old=[==[
	local function V92_despawnVehicle(player)
		local vehicle = V92_playerVehicle(player)
		if not vehicle then
			return false, "No vehicle to despawn."
		end
		if V94_playerIsSeatedInVehicle(player, vehicle) then
			V92_unseatAndMovePlayer(player, vehicle)
		else
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(vehicle) then
				humanoid.Sit = false
			end
		end
		vehicle:Destroy()
		return true, "Vehicle despawned."
	end
]==]
	local new=[==[
	local function V92_despawnVehicle(player,options)
		options=typeof(options)=="table" and options or {}; local vehicle=V92_playerVehicle(player)
		if not vehicle then return false,"No vehicle to despawn.",false end
		local character=player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if V94_playerIsSeatedInVehicle(player,vehicle) then
			if options.PreserveCharacterPosition==true then if humanoid then humanoid.Sit=false end else V92_unseatAndMovePlayer(player,vehicle) end
		elseif humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(vehicle) then humanoid.Sit=false end
		vehicle:Destroy()
		local detached=true
		if options.WaitForDetach==true and humanoid then
			local deadline=os.clock()+math.clamp(tonumber(options.DetachTimeoutSeconds) or 1,.1,3)
			while humanoid.Parent and humanoid.SeatPart and os.clock()<deadline do task.wait() end
			detached=humanoid.SeatPart==nil
		end
		return true,detached and "Vehicle despawned." or "Vehicle removed but seat detachment was not confirmed.",detached
	end
]==]
	source=replaceOnce(source,old,new,"garage-aware despawn helper")
	source=replaceOnce(source,'\t\t\tlocal ok,message=V92_despawnVehicle(player); return {Success=ok==true,Message=message}','\t\t\tlocal ok,message,detached=V92_despawnVehicle(player,{PreserveCharacterPosition=payload.PreserveCharacterPosition==true,WaitForDetach=payload.WaitForDetach==true,DetachTimeoutSeconds=payload.DetachTimeoutSeconds}); return {Success=ok==true and detached~=false,VehicleRemoved=ok==true,Detached=detached~=false,Message=message}',"garage despawn handshake response")
	return source
end)

project(thrust,"NTR_THRUST_PREVIEW_STALE_LIVE_CALL_REMOVED_V1",function(source)
	source=replaceOnce(source,"-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1","-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1\n-- NTR_THRUST_PREVIEW_STALE_LIVE_CALL_REMOVED_V1","thrust repair marker")
	if string.find(source,OLD_THRUST_REFRESH,1,true) then return replaceOnce(source,OLD_THRUST_REFRESH,NEW_THRUST_REFRESH,"stale live thrust call") end
	assert(string.find(source,NEW_THRUST_REFRESH,1,true),"Repaired thrust refresh contract is absent or changed")
	return source
end)

project(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS","management transition marker")
	local oldChoose=[==[
function Runtime.ChooseSlot(displaySpaces,requestedSlotId)
	displaySpaces=type(displaySpaces)=="table" and displaySpaces or {}; requestedSlotId=tostring(requestedSlotId or "")
	if requestedSlotId~="" then
		if displaySpaces[requestedSlotId]~=nil then return requestedSlotId,"Requested" end
		return nil,"Invalid"
	end
	for _,slotId in ipairs({"Space01","Space02"}) do if displaySpaces[slotId]==false or displaySpaces[slotId]==nil or tostring(displaySpaces[slotId])=="" then return slotId,"Empty" end end
	return nil,"Full"
end
]==]
	local newChoose=[==[
function Runtime.ChooseSlot(displaySpaces,requestedSlotId,orderedSlotIds)
	displaySpaces=type(displaySpaces)=="table" and displaySpaces or {}; requestedSlotId=tostring(requestedSlotId or ""); orderedSlotIds=type(orderedSlotIds)=="table" and orderedSlotIds or {"Space01","Space02"}
	if requestedSlotId~="" then if displaySpaces[requestedSlotId]~=nil then return requestedSlotId,"Requested" end; return nil,"Invalid" end
	for _,slotId in ipairs(orderedSlotIds) do if displaySpaces[slotId]==false or displaySpaces[slotId]==nil or tostring(displaySpaces[slotId])=="" then return slotId,"Empty" end end
	return nil,"Full"
end
]==]
	source=replaceOnce(source,oldChoose,newChoose,"definition-ordered display slots")
	source=replaceOnce(source,'\tlocal world=Workspace:WaitForChild("NeoTokyoRacersWorld"); local interiors=world:FindFirstChild("Interiors") or Instance.new("Folder");','\tlocal world=Workspace:WaitForChild("NeoTokyoRacersWorld"); local exteriorRoot=world:WaitForChild("OwnedGarageExteriors"); local interiors=world:FindFirstChild("Interiors") or Instance.new("Folder");',"exterior root")
	local oldTeleport=[==[
	local function teleportCharacter(player,cframe)
		if typeof(cframe)~="CFrame" then return false,"Destination missing." end; local character=player.Character; local root=characterRoot(player); if not (character and root) then return false,"Character is not ready." end
		character:PivotTo(cframe); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; return true
	end
]==]
	local newTeleport=[==[
	local function teleportCharacter(player,cframe)
		if typeof(cframe)~="CFrame" then return false,"Destination missing." end
		local attempts=math.clamp(math.floor(tonumber(settings:GetAttribute("GarageTeleportAttempts")) or 2),1,4); local tolerance=math.max(4,tonumber(settings:GetAttribute("GarageTeleportVerifyDistanceStuds")) or 12)
		for _=1,attempts do local character=player.Character; local root=characterRoot(player); if not (character and root) then return false,"Character is not ready." end; character:PivotTo(cframe); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; task.wait(); root=characterRoot(player); if root and (root.Position-cframe.Position).Magnitude<=tolerance then return true end end
		return false,"Character teleport could not be verified."
	end
	local function exteriorCFrame(propertyId,markerName)
		local definition=catalog.ById(propertyId); local exteriorId=definition and tostring(definition.ExteriorSpawnId or "") or ""; local folder=exteriorId~="" and exteriorRoot:FindFirstChild(exteriorId); local marker=folder and folder:FindFirstChild(markerName)
		if not (marker and marker:IsA("BasePart")) then return nil,"Exterior spawn missing for "..tostring(propertyId).."/"..tostring(markerName) end; return marker.CFrame
	end
]==]
	source=replaceOnce(source,oldTeleport,newTeleport,"verified teleport helper")
	source=replaceOnce(source,'\t\tlocal root=characterRoot(player); local session={Interior=interior,PropertyId=propertyId,ReturnCFrame=root and root.CFrame or settings:GetAttribute("CityFootExitCFrame")}; sessions[player]=session','\t\tlocal session={Interior=interior,PropertyId=propertyId}; sessions[player]=session',"property-owned return destination")
	local oldFoot=[==[
	exitOnFoot=function(player)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; local destination=session.ReturnCFrame; if typeof(destination)~="CFrame" then destination=settings:GetAttribute("CityFootExitCFrame") end
		local ok,message=teleportCharacter(player,destination); if not ok then return {Success=false,Message=message} end; sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); return {Success=true,Message="Returned to the city."}
	end
]==]
	local newFoot=[==[
	exitOnFoot=function(player)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; session.Transition="FootExit"; applyPromptPolicy(session)
		local destination,destinationMessage=exteriorCFrame(session.PropertyId,"FootExitSpawn"); if not destination then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=destinationMessage} end
		local ok,message=teleportCharacter(player,destination); if not ok then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=message} end; sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); return {Success=true,Message="Returned to the city."}
	end
]==]
	source=replaceOnce(source,oldFoot,newFoot,"property foot exit")
	source=replaceOnce(source,'\t\tlocal result={}; local display=profile.OwnedGarage.Properties[propertyId].DisplaySpaces; for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=display[slotId]; table.insert(result,{SlotId=slotId,VehicleId=vehicleId,DisplayName=vehicleName(profile,vehicleId)}) end; return result','\t\tlocal result={}; local display=profile.OwnedGarage.Properties[propertyId].DisplaySpaces; local definition=catalog.ById(propertyId); for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do local vehicleId=display[slotId]; table.insert(result,{SlotId=slotId,VehicleId=vehicleId,DisplayName=vehicleName(profile,vehicleId)}) end; return result',"dynamic replacement slots")
	local oldEnter=[==[
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId); if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local root=characterRoot(player); if not root then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end
		local before=Profile.Snapshot(profile); local result=command(player,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},"OwnedGarageDriveIn",tostring(driven.RequestId or Profile.NewRequestId()),profile.OwnedGarage.Revision)
		if type(result)~="table" or not result.Success then abandonSession(player,session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId}); if not despawn.Success then compensate(player,before,result.Revision,"OwnedGarageDriveInDespawnRollback"); abandonSession(player,session); return {Success=false,Message=despawn.Message or "Vehicle could not enter the garage."} end
		local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame); if not moved then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame or settings:GetAttribute("CityVehicleExitCFrame")}); compensate(player,before,result.Revision,"OwnedGarageDriveInTeleportRollback"); abandonSession(player,session); return {Success=false,Message=moveMessage} end
		setInside(player,session); local committed=getProfile:Invoke(player); local rendered,renderMessage=false,"Committed profile unavailable."; if type(committed)=="table" then rendered,renderMessage=renderDisplays(player,committed,session) end; return {Success=true,Message=reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage.",PropertyId=propertyId,SlotId=slotId,Revision=result.Revision,PresentationWarning=rendered and nil or renderMessage}
	end
]==]
	local newEnter=[==[
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local existingSlot; for candidate,assigned in pairs(property.DisplaySpaces or {}) do if tostring(assigned or "")==tostring(driven.VehicleId) then existingSlot=tostring(candidate); break end end
		local definition=catalog.ById(propertyId); local slotId,reason=existingSlot,"Existing"; if not slotId then slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId,definition and definition.DisplaySpaceIds) end; if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; if not characterRoot(player) then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end; session.Transition="DriveIn"; applyPromptPolicy(session)
		local before=Profile.Snapshot(profile); local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId,PreserveCharacterPosition=true,WaitForDetach=true,DetachTimeoutSeconds=settings:GetAttribute("GarageSeatDetachTimeoutSeconds")}); if not despawn.Success then if despawn.VehicleRemoved then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}) end; abandonSession(player,session); return {Success=false,Message=despawn.Message or "Vehicle could not enter the garage."} end
		local result={Success=true,Revision=profile.OwnedGarage.Revision}; local changed=existingSlot==nil
		if changed then result=command(player,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},"OwnedGarageDriveIn",tostring(driven.RequestId or Profile.NewRequestId()),profile.OwnedGarage.Revision) end
		if type(result)~="table" or not result.Success then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}); abandonSession(player,session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame); if not moved then local restored=not changed or compensate(player,before,result.Revision,"OwnedGarageDriveInTeleportRollback"); if restored then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}) end; abandonSession(player,session); return {Success=false,Message=restored and moveMessage or (moveMessage.." Saved assignment recovery also failed; vehicle remains stored.")} end
		session.Transition=nil; setInside(player,session); local committed=getProfile:Invoke(player); local rendered,renderMessage=false,"Committed profile unavailable."; if type(committed)=="table" then rendered,renderMessage=renderDisplays(player,committed,session) end; return {Success=true,Message=existingSlot and "Vehicle returned to its display space." or (reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage."),PropertyId=propertyId,SlotId=slotId,Revision=result.Revision,PresentationWarning=rendered and nil or renderMessage}
	end
]==]
	source=replaceOnce(source,oldEnter,newEnter,"verified drive-in transition")
	local oldDrive=[==[
	driveOut=function(player,slotId)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message="Display space is empty."} end
		local before=Profile.Snapshot(profile); local result=command(player,"Clear",{GarageId=session.PropertyId,SlotId=slotId},"OwnedGarageDriveOut",Profile.NewRequestId(),profile.OwnedGarage.Revision); if type(result)~="table" or not result.Success then session.Transition=nil; applyPromptPolicy(session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawnCFrame=settings:GetAttribute("CityVehicleExitCFrame"); local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame}); if not spawned.Success then compensate(player,before,result.Revision,"OwnedGarageDriveOutSpawnRollback"); session.Transition=nil; applyPromptPolicy(session); local restored=getProfile:Invoke(player); if type(restored)=="table" then renderDisplays(player,restored,session) end; return {Success=false,Message=spawned.Message or "Vehicle could not leave the garage."} end
		sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}); return {Success=true,Message="Vehicle spawned from garage.",VehicleId=tostring(vehicleId),Revision=result.Revision}
	end
]==]
	local newDrive=[==[
	driveOut=function(player,slotId)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message="Display space is empty."} end
		local spawnCFrame,spawnMessage=exteriorCFrame(session.PropertyId,"VehicleExitSpawn"); if not spawnCFrame then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=spawnMessage} end
		local before=Profile.Snapshot(profile); local result=command(player,"Clear",{GarageId=session.PropertyId,SlotId=slotId},"OwnedGarageDriveOut",Profile.NewRequestId(),profile.OwnedGarage.Revision); if type(result)~="table" or not result.Success then session.Transition=nil; applyPromptPolicy(session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame}); if not spawned.Success then compensate(player,before,result.Revision,"OwnedGarageDriveOutSpawnRollback"); session.Transition=nil; applyPromptPolicy(session); local restored=getProfile:Invoke(player); if type(restored)=="table" then renderDisplays(player,restored,session) end; return {Success=false,Message=spawned.Message or "Vehicle could not leave the garage."} end
		sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}); return {Success=true,Message="Vehicle spawned from garage.",VehicleId=tostring(vehicleId),Revision=result.Revision}
	end
]==]
	source=replaceOnce(source,oldDrive,newDrive,"property vehicle exit")
	return source
end)

local sourceSnapshots={}; local created={}; local configSnapshot={}; local markerAttributeSnapshots={}
for _,name in ipairs({"OwnedGarageRevision","OwnedGarageInstallRunId","ExteriorSpawnContractVersion","GarageTeleportVerifyDistanceStuds","GarageTeleportAttempts","GarageSeatDetachTimeoutSeconds"}) do configSnapshot[name]=config:GetAttribute(name) end
local function create(className,name,parent)
	local object=Instance.new(className); object.Name=name; object.Parent=parent; table.insert(created,object); return object
end
local function folder(parent,name) local object=parent:FindFirstChild(name); if object then assert(object:IsA("Folder"),object:GetFullName().." must be a Folder"); return object end; return create("Folder",name,parent) end
local function marker(parent,name,seed)
	local object=parent:FindFirstChild(name); if object then assert(object:IsA("BasePart"),object:GetFullName().." must be a BasePart"); return object end
	object=create("Part",name,parent); object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; object.Transparency=1; object.Size=Vector3.new(6,1,10); object.CFrame=seed; return object
end

local ok,problem=pcall(function()
	local exteriorRoot=folder(world,"OwnedGarageExteriors"); local starter=folder(exteriorRoot,"STARTER_TWO_BAY"); local footSeed=config:GetAttribute("CityFootExitCFrame")
	local foot=marker(starter,"FootExitSpawn",footSeed); local vehicle=marker(starter,"VehicleExitSpawn",footSeed*CFrame.new(0,-3.2,-38))
	for object,role in pairs({[foot]="FootExitSpawn",[vehicle]="VehicleExitSpawn"}) do markerAttributeSnapshots[object]={PropertyId=object:GetAttribute("OwnedGaragePropertyId"),Role=object:GetAttribute("OwnedGarageMarkerRole")}; object:SetAttribute("OwnedGaragePropertyId","STARTER_TWO_BAY"); object:SetAttribute("OwnedGarageMarkerRole",role) end
	for object,source in pairs(projected) do sourceSnapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}; object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	config:SetAttribute("ExteriorSpawnContractVersion",1); config:SetAttribute("GarageTeleportVerifyDistanceStuds",12); config:SetAttribute("GarageTeleportAttempts",2); config:SetAttribute("GarageSeatDetachTimeoutSeconds",1); config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	assert(has(catalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS"),"Exterior catalogue contract missing")
	assert(has(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS"),"Verified management transition contract missing")
	assert(has(action,"NTR_OWNED_GARAGE_PHASE8_TRANSITION_DESPAWN_HANDSHAKE_V1"),"Garage despawn handshake contract missing")
	assert(has(thrust,"NTR_THRUST_PREVIEW_STALE_LIVE_CALL_REMOVED_V1") and not string.find(thrust.Source,"applyThrustOnly(playerVehicle",1,true),"Stale thrust call remains")
	assert(foot.Parent==starter and vehicle.Parent==starter and foot:IsA("BasePart") and vehicle:IsA("BasePart"),"Starter exterior markers missing")
	local definition=loadstring(catalog.Source,"=OwnedGaragePropertyCatalogAudit"); assert(definition,"Projected catalogue audit compile failed")
end)
if not ok then
	for object,snapshot in pairs(sourceSnapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for object,snapshot in pairs(markerAttributeSnapshots) do if object.Parent then object:SetAttribute("OwnedGaragePropertyId",snapshot.PropertyId); object:SetAttribute("OwnedGarageMarkerRole",snapshot.Role) end end
	for index=#created,1,-1 do local object=created[index]; if object and object.Parent then object:Destroy() end end
	for name,value in pairs(configSnapshot) do config:SetAttribute(name,value) end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sources=4 exteriorMarkers=2 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: verified drive-in handoff, property-owned exits, preserved target display slots, and stale thrust call removed.")
