-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET
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
	local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local markDirty=bindings:WaitForChild("MarkDirty"); local saveNow=bindings:WaitForChild("SaveNow"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local world=Workspace:WaitForChild("NeoTokyoRacersWorld"); local interiors=world:FindFirstChild("Interiors") or Instance.new("Folder"); interiors.Name="Interiors"; interiors.Parent=world; local pool=interiors:FindFirstChild("OwnedGarageInstances") or Instance.new("Folder"); pool.Name="OwnedGarageInstances"; pool:SetAttribute("OwnedGarageRuntimePool",true); pool.Parent=interiors
	local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local driveOut,exitOnFoot
	local function profileFor(player)
		local profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end
		local resetToken=tostring(settings:GetAttribute("TesterResetToken") or ""); local resetUserId=math.floor(tonumber(settings:GetAttribute("TesterResetUserId")) or 0); local existing=type(profile.OwnedGarage)=="table" and profile.OwnedGarage or nil; local shouldReset=player.UserId==resetUserId and resetToken~="" and tostring(existing and existing.TesterResetToken or "")~=resetToken; local oldVersion=existing and existing.SchemaVersion or nil
		Profile.Ensure(profile,shouldReset); if shouldReset then profile.OwnedGarage.TesterResetToken=resetToken; local marked,markMessage=markDirty:Invoke(player,"OwnedGarageTesterReset:"..resetToken); if not marked then return nil,tostring(markMessage or "Tester reset could not be marked dirty.") end; local saved,saveMessage=saveNow:Invoke(player); if not saved then warn("[NTR Owned Garage] Tester reset save deferred: "..tostring(saveMessage)) end elseif oldVersion~=Profile.SchemaVersion then markDirty:Invoke(player,"OwnedGarageSchemaV2") end
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
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local selected=property and property.Customisation and property.Customisation.SurfaceStyles or {}
		for _,part in ipairs(session.Interior:GetDescendants()) do if part:IsA("BasePart") then local surfaceGroup=part:GetAttribute("SurfaceGroup"); local style=surfaceGroup and styleCatalog.ById(selected[surfaceGroup]); if style and style.SurfaceGroup==surfaceGroup then part.Color=style.Color; local material=Enum.Material[style.Material]; if material then part.Material=material end end end end
		return true
	end
	local function renderDisplays(player,profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local markers=session.Interior:FindFirstChild("DisplaySpaceMarkers"); if not markers then return false,"Display markers missing." end
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
		if sessions[player] then return sessions[player] end; local definition=catalog.ById(propertyId); local property=profile.OwnedGarage.Properties[propertyId]; if not (definition and property and property.Owned) then return nil,"Garage is not owned." end
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
		local result={}; local display=profile.OwnedGarage.Properties[propertyId].DisplaySpaces; for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=display[slotId]; table.insert(result,{SlotId=slotId,VehicleId=vehicleId,DisplayName=vehicleName(profile,vehicleId)}) end; return result
	end
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
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
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then return {Success=false,Message="Display space is empty."} end
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
		local properties={}; for _,definition in ipairs(catalog.List()) do local property=profile.OwnedGarage.Properties[definition.PropertyId]; if property and property.Owned then local filled=0; for _,vehicleId in pairs(property.DisplaySpaces) do if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then filled+=1 end end; table.insert(properties,{PropertyId=definition.PropertyId,DisplayName=definition.DisplayName,District=definition.District,Description=definition.Description,Image=definition.Image,TemplateId=definition.TemplateId,Capacity=#definition.DisplaySpaceIds,Filled=filled}) end end
		local session=sessions[player]; local currentProperty=session and profile.OwnedGarage.Properties[session.PropertyId]; local slots={}; local vehicles={}; local surfaceStyles={}
		if currentProperty then
			for _,slotId in ipairs({"Space01","Space02"}) do local vehicleId=currentProperty.DisplaySpaces[slotId]; table.insert(slots,{SlotId=slotId,VehicleId=vehicleId,DisplayName=(vehicleId and vehicleId~=false) and vehicleName(profile,vehicleId) or "Empty Display Space"}) end
			for surfaceGroup,styleId in pairs(currentProperty.Customisation.SurfaceStyles or {}) do surfaceStyles[surfaceGroup]=styleId end
		end
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=cockpitId,CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "")}) end end
		table.sort(vehicles,function(a,b) if a.DisplayName~=b.DisplayName then return a.DisplayName<b.DisplayName end return a.VehicleId<b.VehicleId end)
		return {Success=true,Properties=properties,ActiveGarageId=profile.OwnedGarage.ActiveGarageId,InGarage=session~=nil,CurrentPropertyId=session and session.PropertyId or nil,Slots=slots,Vehicles=vehicles,SurfaceStyles=surfaceStyles,InteriorStyles=styleCatalog.List(),AccessMode=currentProperty and currentProperty.AccessMode or "Private",Cash=tonumber(profile.Cash or profile.Money or profile.Credits) or 0}
	end
	invoke.OnServerInvoke=function(player,action,args)
		args=type(args)=="table" and args or {}; if locks[player] then return {Success=false,Message="Garage transition already in progress."} end; local now=os.clock(); if action~="GetState" and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1) then return {Success=false,Message="Garage transition is cooling down."} end
		locks[player]=true; local ok,result=pcall(function()
			local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local propertyId=tostring(args.PropertyId or profile.OwnedGarage.ActiveGarageId or "STARTER_TWO_BAY")
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
	-- NTR_OWNED_GARAGE_PHASE6_CHARACTER_CLEANUP_V1
	local function watchCharacter(player,character) local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",10); if humanoid then humanoid.Died:Connect(function() local session=sessions[player]; if session then abandonSession(player,session) end end) end end
	Players.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end); for _,player in ipairs(Players:GetPlayers()) do player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end
	Players.PlayerRemoving:Connect(function(player) local session=sessions[player]; sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; slotByUserId[player.UserId]=nil; setInside(player,nil); if session and session.Interior then disconnectPrompts(session.Interior); session.Interior:Destroy() end end)
	started=true; print("[NTR Owned Garage] Management runtime active."); return true,"Started"
end
return Runtime
