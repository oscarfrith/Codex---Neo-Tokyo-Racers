-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer exit/park/coast/despawn/re-enter and the OwnedGarageVehicleLifecycleBridge. Extracted verbatim from the GarageServer controller closure
-- (architecture P6); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local Workspace = ctx.Workspace
	local buildVehicle = ctx.buildVehicle
	local coreModulesEquipped = ctx.coreModulesEquipped
	local findCockpit = ctx.findCockpit
	local garageServer_number = ctx.garageServer_number
	local getProfile = ctx.getProfile
	local mirrorLegacyProfileToPersistence = ctx.mirrorLegacyProfileToPersistence
	local playerSpeedMph = ctx.playerSpeedMph
	local rootPart = ctx.rootPart
	local seatPlayer = ctx.seatPlayer
	local selectVehicleInstance = ctx.selectVehicleInstance
	local vehicleSummaries = ctx.vehicleSummaries
	local vehiclesRoot = ctx.vehiclesRoot
	local function garageServer_playerVehicle(player)
		for _, candidate in ipairs(vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end
	local function vehicleInteractionSettings()
		local editable=game:GetService("ReplicatedStorage"):FindFirstChild("Config") and game:GetService("ReplicatedStorage"):WaitForChild("Config"):FindFirstChild("Vehicles")
		local balance=editable and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):FindFirstChild("Authoring")
		return balance and game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles"):WaitForChild("Authoring"):FindFirstChild("VehicleInteractions")
	end

	local function vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local basis=vehicle:FindFirstChild("DriverSeat",true)
		if not (basis and basis:IsA("BasePart")) then
			basis=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		end
		if not (basis and basis:IsA("BasePart")) then return nil end
		local settings=vehicleInteractionSettings()
		local right=math.clamp(garageServer_number(settings,"ExitRightStuds",6),3,12)
		local up=math.clamp(garageServer_number(settings,"ExitUpStuds",2.5),1,6)
		return basis.CFrame*CFrame.new(right,up,0)
	end

	local function unseatAndMovePlayer(player, vehicle)
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local exitCFrame=vehicleExitCFrame(vehicle)
		if humanoid then humanoid.Sit=false end
		if character and exitCFrame then
			character:PivotTo(exitCFrame)
			local humanoidRoot=character:FindFirstChild("HumanoidRootPart")
			if humanoidRoot then
				humanoidRoot.AssemblyLinearVelocity=Vector3.zero
				humanoidRoot.AssemblyAngularVelocity=Vector3.zero
			end
		end
	end

	local function fixParkedVehicle(vehicle)
		local root=vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true))
		if not (root and root:IsA("BasePart")) then return false end
		vehicle.PrimaryPart=root
		pcall(function() root:SetNetworkOwner(nil) end)
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		root.Anchored=true
		vehicle:SetAttribute("ExitCoasting",nil)
		vehicle:SetAttribute("ExitCoastStartedAt",nil)
		vehicle:SetAttribute("ExitCoastStopReason","Immediate")
		vehicle:SetAttribute("ParkedFixed",true)
		return true
	end

	local function beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		root.Anchored=false
		vehicle:SetAttribute("ParkedFixed",nil)
		vehicle:SetAttribute("ExitCoasting",true)
		vehicle:SetAttribute("ExitCoastStartedAt",Workspace:GetServerTimeNow())
		vehicle:SetAttribute("ExitCoastStopReason",nil)
		unseatAndMovePlayer(player,vehicle)
		if root.Parent then
			root.AssemblyLinearVelocity=linearVelocity
			root.AssemblyAngularVelocity=angularVelocity
			pcall(function() root:SetNetworkOwner(player) end)
		end
	end

	local function exitVehicle(player)
		local vehicle=garageServer_playerVehicle(player)
		if not vehicle then return false,"No vehicle to exit." end
		if vehicle:GetAttribute("RaceParticipant")==true or vehicle:GetAttribute("RaceRunId")~=nil then
			return false,"Use the race exit while participating in a race."
		end
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local seat=humanoid and humanoid.SeatPart
		if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)) then
			return false,"You are not seated in your vehicle."
		end
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		vehicle.PrimaryPart=root
		local linearVelocity=root.AssemblyLinearVelocity
		local angularVelocity=root.AssemblyAngularVelocity
		local horizontalVelocity=Vector3.new(linearVelocity.X,0,linearVelocity.Z)
		local settings=vehicleInteractionSettings()
		local immediateParkMaxMph=math.clamp(garageServer_number(settings,"ExitImmediateParkMaxMph",10),0,50)
		local speedMph=horizontalVelocity.Magnitude*0.625

		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",nil)
		vehicle:SetAttribute("ParkedShowcase",true)
		vehicle:SetAttribute("EngineVFXActive",true)

		if speedMph<=immediateParkMaxMph then
			if not fixParkedVehicle(vehicle) then return false,"Vehicle could not be fixed." end
			unseatAndMovePlayer(player,vehicle)
			return true,"Exited and parked vehicle."
		end

		beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		return true,"Exited vehicle while it coasts to a stop."
	end
	local function playerIsSeatedInVehicle(player, vehicle)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
	local function despawnVehicle(player,options)
		options=typeof(options)=="table" and options or {}; local vehicle=garageServer_playerVehicle(player)
		if not vehicle then return false,"No vehicle to despawn.",false end
		local character=player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if playerIsSeatedInVehicle(player,vehicle) then
			if options.PreserveCharacterPosition==true then if humanoid then humanoid.Sit=false end else unseatAndMovePlayer(player,vehicle) end
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

	local function reEnterVehicle(player)
		local vehicle
		for _,candidate in ipairs(vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId")==player.UserId then vehicle=candidate break end
		end
		if not vehicle then return false,"No vehicle nearby." end
		if vehicle:GetAttribute("ExitCoasting")==true then return false,"Vehicle is still coasting." end 
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		local seat=vehicle:FindFirstChild("DriverSeat",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		if not (seat and seat:IsA("VehicleSeat")) then return false,"Driver seat missing." end
		vehicle.PrimaryPart=root
		root.Anchored=false 
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		vehicle:SetAttribute("ExitCoasting",nil)
		vehicle:SetAttribute("ExitCoastStartedAt",nil)
		vehicle:SetAttribute("ExitCoastStopReason",nil)
		vehicle:SetAttribute("ParkedFixed",nil)
		vehicle:SetAttribute("ParkedShowcase",false)
		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",player.UserId)
		pcall(function() root:SetNetworkOwner(player) end)
		seatPlayer(player,vehicle,seat)
		return true,"Entered vehicle."
	end
	local ownedGarageLifecycle=game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage"):WaitForChild("OwnedGarageVehicleLifecycleBridge")
	ownedGarageLifecycle.OnInvoke=function(operation,payload)
		payload=typeof(payload)=="table" and payload or {}; local player=payload.Player
		if not (player and player:IsA("Player")) then return {Success=false,Message="Player is required."} end
		local profile=getProfile(player)
		if operation=="GetDrivenVehicle" then
			local vehicle=garageServer_playerVehicle(player); if not (vehicle and playerIsSeatedInVehicle(player,vehicle)) then return {Success=false,Message="No driven vehicle."} end
			local root=rootPart(vehicle); local vehicleId=tostring(profile.CurrentVehicleId or ""); if vehicleId=="" then return {Success=false,Message="Driven vehicle identity is unavailable."} end
			return {Success=true,VehicleId=vehicleId,SpeedMph=playerSpeedMph(player),VehicleCFrame=root and root.CFrame or nil}
		elseif operation=="DespawnForGarage" then
			local requested=tostring(payload.VehicleId or ""); if requested=="" or requested~=tostring(profile.CurrentVehicleId or "") then return {Success=false,Message="Driven vehicle identity changed."} end
			local ok,message,detached=despawnVehicle(player,{PreserveCharacterPosition=payload.PreserveCharacterPosition==true,WaitForDetach=payload.WaitForDetach==true,DetachTimeoutSeconds=payload.DetachTimeoutSeconds}); return {Success=ok==true and detached~=false,VehicleRemoved=ok==true,Detached=detached~=false,Message=message}
		elseif operation=="SpawnFromGarage" then
			local vehicleId=tostring(payload.VehicleId or ""); local previousVehicleId=tostring(profile.CurrentVehicleId or ""); local selected,message=selectVehicleInstance(profile,{VehicleId=vehicleId}); if not selected then return {Success=false,Message=message} end
			if not coreModulesEquipped(profile) then if previousVehicleId~="" then selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message="Equip at least one engine, stabilisers, and boost before driving."} end
			local vehicle,buildMessage=buildVehicle(player,profile,payload.SpawnCFrame); if not vehicle then if previousVehicleId~="" then selectVehicleInstance(profile,{VehicleId=previousVehicleId}) end; return {Success=false,Message=buildMessage or "Vehicle spawn failed."} end
			mirrorLegacyProfileToPersistence(player,profile,"OwnedGarageDriveOut",true); return {Success=true,Message="Vehicle spawned from garage.",Vehicle=vehicle,VehicleId=vehicleId}
		elseif operation=="GetOwnedGarageVehicleCards" then
			local summaries=vehicleSummaries(profile,player); local cards={}; local displayed={}
			for garageId,property in pairs((profile.OwnedGarage and profile.OwnedGarage.Properties) or {}) do for slotId,vehicleId in pairs(property.DisplaySpaces or {}) do if vehicleId and vehicleId~=false and tostring(vehicleId)~="" then displayed[tostring(vehicleId)]={GarageId=tostring(garageId),SlotId=tostring(slotId)} end end end
			for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if typeof(vehicle)=="table" then
				local id=tostring(vehicleId); local summary=summaries[id] or summaries[vehicleId] or {}; local cockpitInstance=vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or summary.CockpitId or vehicle.CockpitId or ""); local categoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "BRUISER"); local cockpit=findCockpit(categoryId,cockpitId); local image=""
				for _,key in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local value=cockpit and cockpit:GetAttribute(key); if value~=nil and tostring(value)~="" then image=tostring(value); break end; local child=cockpit and cockpit:FindFirstChild(key); if child and child:IsA("StringValue") and child.Value~="" then image=child.Value; break end end
				local overall=summary.Overall or {}; local location=displayed[id]; table.insert(cards,{VehicleId=id,CockpitId=cockpitId,CategoryId=categoryId,DisplayName=tostring(cockpit and cockpit:GetAttribute("DisplayName") or summary.DisplayName or vehicle.DisplayName or cockpitId or id),Image=image,Tier=tostring(overall.Tier or "E"),Rating=math.floor(tonumber(overall.PerformanceIndex) or 0),DisplayedGarageId=location and location.GarageId or nil,DisplayedSlotId=location and location.SlotId or nil})
			end end
			return {Success=true,Vehicles=cards}
		end
		return {Success=false,Message="Unknown owned garage lifecycle operation."}
	end
	ownedGarageLifecycle:SetAttribute("OwnedGarageLifecycleReady",true)

	return exitVehicle, despawnVehicle, reEnterVehicle
end
