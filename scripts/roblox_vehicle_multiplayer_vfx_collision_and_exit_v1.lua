-- Neo Tokyo Racers - Multiplayer Vehicle VFX, Collision, Parking + Exit V1.1
-- Run once in Roblox Studio Command Bar while NOT playing.
--
-- One canonical installer for:
-- 1) replicated remote vehicle engine/boost/drift VFX state,
-- 2) vehicle-to-vehicle pass-through in free roam and races,
-- 3) slow/parked character collision with >20 mph pass-through,
-- 4) speed-sensitive exit coasting, server-fixed parking and right-side exit.
--
-- Set MODE to "AUDIT" for a read-only committed-state check.

local MODE="INSTALL" -- "INSTALL" or "AUDIT"

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local PhysicsService=game:GetService("PhysicsService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Vehicle Multiplayer VFX Collision Exit V1.1]"
local REVISION="NTR_VEHICLE_MULTIPLAYER_VFX_COLLISION_EXIT_V1_1"
local RUN_ID=HttpService:GenerateGUID(false)

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
	assert(countPlain(source,needle)==1,label.." anchor count changed; refresh and inspect the live mirror before another patch")
	local first=assert(source:find(needle,1,true),label.." anchor missing")
	return source:sub(1,first-1)..replacement..source:sub(first+#needle)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local function ensureFolder(parent,name)
	local item=parent:FindFirstChild(name)
	if not item then
		item=Instance.new("Folder")
		item.Name=name
		item.Parent=parent
	end
	assert(item:IsA("Folder"),item:GetFullName().." must be a Folder")
	return item
end

local function snapshotAttributes(instance)
	local result={}
	for name,value in pairs(instance:GetAttributes()) do result[name]=value end
	return result
end

local function restoreAttributes(instance,snapshot)
	for name in pairs(instance:GetAttributes()) do
		if snapshot[name]==nil then instance:SetAttribute(name,nil) end
	end
	for name,value in pairs(snapshot) do instance:SetAttribute(name,value) end
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local shared=assert(kit:FindFirstChild("Shared"),"NeoTokyoRacers.Shared missing")
local modules=assert(shared:FindFirstChild("Modules"),"Shared.Modules missing")
local clientModules=assert(modules:FindFirstChild("Client"),"Shared.Modules.Client missing")
local visuals=assert(clientModules:FindFirstChild("Visuals"),"Client.Visuals missing")
local audioModules=assert(clientModules:FindFirstChild("Audio"),"Client.Audio missing")

local cachedVfx=assert(visuals:FindFirstChild("CachedThrustVisualRuntime"),"CachedThrustVisualRuntime missing")
local audioController=assert(audioModules:FindFirstChild("VehicleAudioController"),"VehicleAudioController missing")
assert(cachedVfx:IsA("ModuleScript"),cachedVfx:GetFullName().." must be a ModuleScript")
assert(audioController:IsA("ModuleScript"),audioController:GetFullName().." must be a ModuleScript")

local serverRoot=assert(ServerScriptService:FindFirstChild("NeoTokyoRacers"),"ServerScriptService.NeoTokyoRacers missing")
local services=assert(serverRoot:FindFirstChild("Services"),"NeoTokyoRacers.Services missing")
local garageServices=assert(services:FindFirstChild("Garage"),"Services.Garage missing")
local vehicleServices=assert(services:FindFirstChild("Vehicle"),"Services.Vehicle missing")
local audioServices=assert(services:FindFirstChild("Audio"),"Services.Audio missing")
local racingServices=assert(services:FindFirstChild("Racing"),"Services.Racing missing")

local garageAction=assert(garageServices:FindFirstChild("GarageActionController_Shadow_Disabled"),"GarageActionController_Shadow_Disabled missing")
local vehicleAccess=assert(vehicleServices:FindFirstChild("VehicleAccessPromptService_Active"),"VehicleAccessPromptService_Active missing")
local audioStateService=assert(audioServices:FindFirstChild("VehicleAudioStateService_Active"),"VehicleAudioStateService_Active missing")
local raceAssets=assert(racingServices:FindFirstChild("RaceSessionAssetService_Active"),"RaceSessionAssetService_Active missing")
for _,item in ipairs({garageAction,vehicleAccess,audioStateService,raceAssets}) do
	assert(item:IsA("LuaSourceContainer"),item:GetFullName().." must contain source")
end

local runtimeControllers=assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Runtime"),
	"StarterPlayer NeoTokyoRacersClient.Controllers.Runtime missing"
)
local parkedHover=assert(runtimeControllers:FindFirstChild("FreeRoamParkedHoverController_Active"),"FreeRoamParkedHoverController_Active missing")
assert(parkedHover:IsA("LocalScript"),parkedHover:GetFullName().." must be a LocalScript")

assert(raceAssets.Source:find("NTR_RACING_PHASE11E_COLLISION_POLICY",1,true),"Confirmed race participant non-collision policy missing")
assert(raceAssets.Source:find('local PARTICIPANT_GROUP = "NTR_RaceParticipant"',1,true),"Race participant collision-group contract missing")
assert(audioStateService.Source:find("Contract.Validate(payload)",1,true),"Validated vehicle semantic-state boundary missing")
assert(cachedVfx.Source:find("NTR_RACING_PHASE11E_VFX_GATE",1,true),"Race VFX visibility gate missing")

local configRoot=assert(kit:FindFirstChild("Config"),"NeoTokyoRacers.Config missing")
local editable=assert(configRoot:FindFirstChild("Editable"),"Config.Editable missing")
local balance=assert(editable:FindFirstChild("01_GAME_BALANCE_Editable"),"Editable.01_GAME_BALANCE_Editable missing")
local interactions=balance:FindFirstChild("VehicleInteractions")
if interactions then assert(interactions:IsA("Folder"),interactions:GetFullName().." must be a Folder") end

local OLD_VFX_STATE=[==[local function runtimeState(cache)
	local forcePreview = readAttr(cache, "ForceThrustPreview") == true
	local driveReady = readAttr(cache, "DriveReady") == true
	local preview = isPreviewModel(cache.Model)
	local driving = driveReady or forcePreview
	local accelerating = readAttr(cache, "Accelerating") == true
	local boosting = readAttr(cache, "Boosting") == true
	local driftLeft = readAttr(cache, "DriftingLeft") == true
	local driftRight = readAttr(cache, "DriftingRight") == true

	if preview then
		-- PreviewVFXMode is the only garage VFX state contract. The legacy
		-- ForceThrustPreview flag must never turn every effect on in a preview.
		local mode=tostring(readAttr(cache,"PreviewVFXMode") or "Idle")
		local full=mode=="ThrustColour"
		return {
			Driving=true,
			ForcePreview=false,
			Accelerating=full,
			Boosting=full,
			DriftLeft=full,
			DriftRight=full,
			AnyDrift=full,
		}
	end

	return {
		Driving = driving,
		ForcePreview = false,
		Accelerating = accelerating,
		Boosting = boosting,
		DriftLeft = driftLeft,
		DriftRight = driftRight,
		AnyDrift = driftLeft or driftRight,
	}
end
]==]

local NEW_VFX_STATE=[==[local function runtimeState(cache)
	-- NTR_VEHICLE_MULTIPLAYER_VFX_STATE_V1
	local forcePreview = readAttr(cache, "ForceThrustPreview") == true
	local driveReady = readAttr(cache, "DriveReady") == true
	local preview = isPreviewModel(cache.Model)
	local ownerUserId = tonumber(cache.Model and cache.Model:GetAttribute("OwnerUserId"))
	local localVehicle = ownerUserId == LOCAL_PLAYER.UserId
	local driving = driveReady or forcePreview
	local accelerating = readAttr(cache, "Accelerating") == true
	local boosting = readAttr(cache, "Boosting") == true
	local driftLeft = readAttr(cache, "DriftingLeft") == true
	local driftRight = readAttr(cache, "DriftingRight") == true

	if preview then
		-- PreviewVFXMode remains the only garage VFX state contract.
		local mode=tostring(readAttr(cache,"PreviewVFXMode") or "Idle")
		local full=mode=="ThrustColour"
		return {
			Driving=true,
			ForcePreview=false,
			Accelerating=full,
			Boosting=full,
			DriftLeft=full,
			DriftRight=full,
			AnyDrift=full,
		}
	end

	if not localVehicle then
		-- Reuse the existing server-validated semantic presentation transport.
		-- Local driving attributes remain immediate; remote vehicles consume
		-- replicated server attributes and still pass through the race VFX gate.
		local ignition=tostring(readAttr(cache,"NTRAudioIgnition") or "Off")
		local drive=tostring(readAttr(cache,"NTRAudioDrive") or "Idle")
		local boost=tostring(readAttr(cache,"NTRAudioBoost") or "Off")
		local drift=tostring(readAttr(cache,"NTRAudioDrift") or "None")
		driving=driveReady or ignition=="Running"
		accelerating=drive=="Accelerating"
		boosting=boost~="Off"
		driftLeft=drift=="Left"
		driftRight=drift=="Right"
	end

	return {
		Driving = driving,
		ForcePreview = false,
		Accelerating = accelerating,
		Boosting = boosting,
		DriftLeft = driftLeft,
		DriftRight = driftRight,
		AnyDrift = driftLeft or driftRight,
	}
end
]==]

local OLD_AUDIO_LOOP=[==[			for _, state in pairs(tracked) do updateGraph(state, step) end
]==]
local NEW_AUDIO_LOOP=[==[			for _, state in pairs(tracked) do
				if state.Graph then
					updateGraph(state, step)
				elseif state.LocalDriver then
					-- NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1
					-- Keep validated semantic state replication alive when audio
					-- playback is disabled or this vehicle has a silent graph.
					publishLocalState(state, semanticState(state.Vehicle, true), nil)
				end
			end
]==]

local OLD_AUDIO_SERVER_GATE=[==[	if global:GetAttribute("AudioSystemEnabled") ~= true or global:GetAttribute("VehicleAudioEnabled") == false then return end
]==]
local NEW_AUDIO_SERVER_GATE=[==[	-- NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1
	-- Semantic vehicle state also drives remote VFX, so validation/replication
	-- remains active independently from audible playback settings.
]==]

local OLD_PARKED_GATE=[==[	if vehicle:GetAttribute("ParkedShowcase") ~= true then return false end
	if vehicle:GetAttribute("DriverUserId") ~= nil then return false end
]==]
local NEW_PARKED_GATE=[==[	if vehicle:GetAttribute("ParkedShowcase") ~= true then return false end
	if vehicle:GetAttribute("NTR_ParkedFixed") == true or vehicle.PrimaryPart.Anchored then return false end -- NTR_VEHICLE_FIXED_PARKING_V1
	if vehicle:GetAttribute("DriverUserId") ~= nil then return false end
]==]

local OLD_EXIT_BLOCK=[==[	local function V92_vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if seat and seat:IsA("VehicleSeat") then
			return seat.CFrame * CFrame.new(-10, 3, 0)
		end
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if root and root:IsA("BasePart") then
			return root.CFrame * CFrame.new(-10, 3, 0)
		end
		return nil
	end

	local function V92_unseatAndMovePlayer(player, vehicle)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		local exitCFrame = V92_vehicleExitCFrame(vehicle)
		if humanoid then
			humanoid.Sit = false
		end
		if humanoidRoot and exitCFrame then
			humanoidRoot.CFrame = exitCFrame
		end
	end

	local function V56_exitVehicle(player)
		local vehicle = V92_playerVehicle(player)
		V92_unseatAndMovePlayer(player, vehicle)
		if vehicle then
			vehicle:SetAttribute("DriveReady", true)
			vehicle:SetAttribute("DriverUserId", nil)
			vehicle:SetAttribute("ParkedShowcase", true)
			vehicle:SetAttribute("EngineVFXActive", true)
		end
		return true, "Exited vehicle."
	end
]==]

local NEW_EXIT_BLOCK=[==[	-- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
	local function V102_vehicleInteractionSettings()
		local editable=V56_kit:FindFirstChild("Config") and V56_kit.Config:FindFirstChild("Editable")
		local balance=editable and editable:FindFirstChild("01_GAME_BALANCE_Editable")
		return balance and balance:FindFirstChild("VehicleInteractions")
	end

	local function V92_vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local basis=vehicle:FindFirstChild("DriverSeat",true)
		if not (basis and basis:IsA("BasePart")) then
			basis=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		end
		if not (basis and basis:IsA("BasePart")) then return nil end
		local settings=V102_vehicleInteractionSettings()
		local right=math.clamp(V56_number(settings,"ExitRightStuds",6),3,12)
		local up=math.clamp(V56_number(settings,"ExitUpStuds",2.5),1,6)
		return basis.CFrame*CFrame.new(right,up,0)
	end

	local function V92_unseatAndMovePlayer(player, vehicle)
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local exitCFrame=V92_vehicleExitCFrame(vehicle)
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

	local function V102_fixParkedVehicle(vehicle)
		local root=vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true))
		if not (root and root:IsA("BasePart")) then return false end
		vehicle.PrimaryPart=root
		pcall(function() root:SetNetworkOwner(nil) end)
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		root.Anchored=true
		vehicle:SetAttribute("NTR_ParkedFixed",true)
		return true
	end

	local function V56_exitVehicle(player)
		local vehicle=V92_playerVehicle(player)
		if not vehicle then return false,"No vehicle to exit." end
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local seat=humanoid and humanoid.SeatPart
		if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)) then
			return false,"You are not seated in your vehicle."
		end
		if not V102_fixParkedVehicle(vehicle) then return false,"Vehicle root missing." end
		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",nil)
		vehicle:SetAttribute("ParkedShowcase",true)
		vehicle:SetAttribute("EngineVFXActive",true)
		V92_unseatAndMovePlayer(player,vehicle)
		return true,"Exited vehicle."
	end
]==]

local V1_1_EXIT_BLOCK=[==[	-- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
	-- NTR_VEHICLE_SPEED_SENSITIVE_EXIT_COAST_V1_1
	local function V102_vehicleInteractionSettings()
		local editable=V56_kit:FindFirstChild("Config") and V56_kit.Config:FindFirstChild("Editable")
		local balance=editable and editable:FindFirstChild("01_GAME_BALANCE_Editable")
		return balance and balance:FindFirstChild("VehicleInteractions")
	end

	local function V92_vehicleExitCFrame(vehicle)
		if not vehicle then return nil end
		local basis=vehicle:FindFirstChild("DriverSeat",true)
		if not (basis and basis:IsA("BasePart")) then
			basis=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		end
		if not (basis and basis:IsA("BasePart")) then return nil end
		local settings=V102_vehicleInteractionSettings()
		local right=math.clamp(V56_number(settings,"ExitRightStuds",6),3,12)
		local up=math.clamp(V56_number(settings,"ExitUpStuds",2.5),1,6)
		return basis.CFrame*CFrame.new(right,up,0)
	end

	local function V92_unseatAndMovePlayer(player, vehicle)
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local exitCFrame=V92_vehicleExitCFrame(vehicle)
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

	local function V102_fixParkedVehicle(vehicle)
		local root=vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true))
		if not (root and root:IsA("BasePart")) then return false end
		vehicle.PrimaryPart=root
		pcall(function() root:SetNetworkOwner(nil) end)
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		root.Anchored=true
		vehicle:SetAttribute("NTR_ExitCoasting",nil)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",nil)
		vehicle:SetAttribute("NTR_ExitCoastStopReason","Immediate")
		vehicle:SetAttribute("NTR_ParkedFixed",true)
		return true
	end

	local function V102_beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		root.Anchored=false
		vehicle:SetAttribute("NTR_ParkedFixed",nil)
		vehicle:SetAttribute("NTR_ExitCoasting",true)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",Workspace:GetServerTimeNow())
		vehicle:SetAttribute("NTR_ExitCoastStopReason",nil)
		V92_unseatAndMovePlayer(player,vehicle)
		if root.Parent then
			root.AssemblyLinearVelocity=linearVelocity
			root.AssemblyAngularVelocity=angularVelocity
			pcall(function() root:SetNetworkOwner(player) end)
		end
	end

	local function V56_exitVehicle(player)
		local vehicle=V92_playerVehicle(player)
		if not vehicle then return false,"No vehicle to exit." end
		if vehicle:GetAttribute("NTR_RaceParticipant")==true or vehicle:GetAttribute("NTR_RaceRunId")~=nil then
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
		local settings=V102_vehicleInteractionSettings()
		local immediateParkMaxMph=math.clamp(V56_number(settings,"ExitImmediateParkMaxMph",10),0,50)
		local speedMph=horizontalVelocity.Magnitude*0.625

		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",nil)
		vehicle:SetAttribute("ParkedShowcase",true)
		vehicle:SetAttribute("EngineVFXActive",true)

		if speedMph<=immediateParkMaxMph then
			if not V102_fixParkedVehicle(vehicle) then return false,"Vehicle could not be fixed." end
			V92_unseatAndMovePlayer(player,vehicle)
			return true,"Exited and parked vehicle."
		end

		V102_beginExitCoast(player,vehicle,root,linearVelocity,angularVelocity)
		return true,"Exited vehicle while it coasts to a stop."
	end
]==]

local OLD_REENTER_BLOCK=[==[	local function V56_reEnterVehicle(player)
		local vehicle
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then vehicle = candidate; break end
		end
		if not vehicle then return false, "No vehicle nearby." end
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if root then vehicle.PrimaryPart = root; pcall(function() root:SetNetworkOwner(player) end) end
		if not (seat and seat:IsA("VehicleSeat")) then return false, "Driver seat missing." end
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		V56_seatPlayer(player, vehicle, seat)
		return true, "Entered vehicle."
	end
]==]

local NEW_REENTER_BLOCK=[==[	local function V56_reEnterVehicle(player)
		local vehicle
		for _,candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId")==player.UserId then vehicle=candidate break end
		end
		if not vehicle then return false,"No vehicle nearby." end
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		local seat=vehicle:FindFirstChild("DriverSeat",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		if not (seat and seat:IsA("VehicleSeat")) then return false,"Driver seat missing." end
		vehicle.PrimaryPart=root
		root.Anchored=false -- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		vehicle:SetAttribute("NTR_ParkedFixed",nil)
		vehicle:SetAttribute("ParkedShowcase",false)
		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",player.UserId)
		pcall(function() root:SetNetworkOwner(player) end)
		V56_seatPlayer(player,vehicle,seat)
		return true,"Entered vehicle."
end
]==]

local V1_1_REENTER_BLOCK=[==[	local function V56_reEnterVehicle(player)
		local vehicle
		for _,candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId")==player.UserId then vehicle=candidate break end
		end
		if not vehicle then return false,"No vehicle nearby." end
		if vehicle:GetAttribute("NTR_ExitCoasting")==true then return false,"Vehicle is still coasting." end -- NTR_VEHICLE_COAST_REENTRY_GUARD_V1_1
		local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
		local seat=vehicle:FindFirstChild("DriverSeat",true)
		if not (root and root:IsA("BasePart")) then return false,"Vehicle root missing." end
		if not (seat and seat:IsA("VehicleSeat")) then return false,"Driver seat missing." end
		vehicle.PrimaryPart=root
		root.Anchored=false -- NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		vehicle:SetAttribute("NTR_ExitCoasting",nil)
		vehicle:SetAttribute("NTR_ExitCoastStartedAt",nil)
		vehicle:SetAttribute("NTR_ExitCoastStopReason",nil)
		vehicle:SetAttribute("NTR_ParkedFixed",nil)
		vehicle:SetAttribute("ParkedShowcase",false)
		vehicle:SetAttribute("DriveReady",true)
		vehicle:SetAttribute("DriverUserId",player.UserId)
		pcall(function() root:SetNetworkOwner(player) end)
		V56_seatPlayer(player,vehicle,seat)
		return true,"Entered vehicle."
	end
]==]

local OLD_PROMPT_ENTER=[==[local function enterVehicle(player, vehicle, seat)
	if not canEnter(player, vehicle, seat) then return end
	local root = findRoot(vehicle)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		vehicle.PrimaryPart = root
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	end
	vehicle:SetAttribute("DriveReady", true)
	vehicle:SetAttribute("DriverUserId", player.UserId)
	vehicle:SetAttribute("ParkedShowcase", false)
	if humanoidRoot then
		humanoidRoot.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
	end
	if humanoid then
		task.wait(0.05)
		seat:Sit(humanoid)
	end
end
]==]

local NEW_PROMPT_ENTER=[==[local function enterVehicle(player, vehicle, seat)
	if not canEnter(player,vehicle,seat) then return end
	local root=findRoot(vehicle)
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local humanoidRoot=character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end
	vehicle.PrimaryPart=root
	root.Anchored=false -- NTR_VEHICLE_FIXED_PROMPT_REENTRY_V1
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	vehicle:SetAttribute("NTR_ParkedFixed",nil)
	vehicle:SetAttribute("ParkedShowcase",false)
	vehicle:SetAttribute("DriveReady",true)
	vehicle:SetAttribute("DriverUserId",player.UserId)
	pcall(function() root:SetNetworkOwner(player) end)
	if humanoidRoot then humanoidRoot.CFrame=seat.CFrame+Vector3.new(0,2,0) end
	if humanoid then
		task.wait(0.05)
		if canEnter(player,vehicle,seat) then seat:Sit(humanoid) end
	end
end
]==]

local V1_1_PROMPT_CAN_ENTER_OLD=[==[local function canEnter(player, vehicle, seat)
	if not player or not vehicle or not seat then return false end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return false end
	if seat.Occupant ~= nil then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end
]==]

local V1_1_PROMPT_CAN_ENTER_NEW=[==[local function canEnter(player, vehicle, seat)
	if not player or not vehicle or not seat then return false end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return false end
	if vehicle:GetAttribute("NTR_ExitCoasting")==true then return false end -- NTR_VEHICLE_COAST_PROMPT_GUARD_V1_1
	if seat.Occupant ~= nil then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end
]==]

local V1_1_PROMPT_ENABLED_OLD=[==[	prompt.Enabled = seat.Occupant == nil
]==]
local V1_1_PROMPT_ENABLED_NEW=[==[	prompt.Enabled = seat.Occupant == nil and vehicle:GetAttribute("NTR_ExitCoasting")~=true -- NTR_VEHICLE_COAST_PROMPT_VISIBILITY_V1_1
]==]

local V1_1_PARKED_CONFIG_OLD=[==[local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1
]==]
local V1_1_PARKED_CONFIG_NEW=[==[local HOVER_HEIGHT = math.clamp(DriveTuning.Read().HoverHeightStuds, 0.5, 8) -- NTR_DRIVING_HOVER_HEIGHT_CONFIG_VALUE_V1
local INTERACTION_SETTINGS = ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("Editable"):WaitForChild("01_GAME_BALANCE_Editable"):WaitForChild("VehicleInteractions") -- NTR_VEHICLE_EXIT_COAST_DRAG_V1_1
local function interactionNumber(name,fallback,minimum,maximum)
	return math.clamp(tonumber(INTERACTION_SETTINGS:GetAttribute(name)) or fallback,minimum,maximum)
end
]==]

local V1_1_PARKED_DRAG_CREATE_OLD=[==[	local rayParams = RaycastParams.new()
]==]
local V1_1_PARKED_DRAG_CREATE_NEW=[==[	local coastDrag = Instance.new("VectorForce")
	coastDrag.Name = "NTR_ParkedHoverCoastDrag"
	coastDrag.Attachment0 = center
	coastDrag.RelativeTo = Enum.ActuatorRelativeTo.World
	coastDrag.ApplyAtCenterOfMass = true
	coastDrag.Force = Vector3.zero
	coastDrag.Parent = root

	local rayParams = RaycastParams.new()
]==]

local V1_1_PARKED_STATE_OLD=[==[	local state = { Root = root, Align = align, Corners = corners }
]==]
local V1_1_PARKED_STATE_NEW=[==[	local state = { Root = root, Align = align, Corners = corners, CoastDrag = coastDrag }
]==]

local V1_1_PARKED_DRAG_UPDATE_OLD=[==[		local mass = math.max(root.AssemblyMass, 1)
		local liftPerCorner = mass * Workspace.Gravity / math.max(#corners, 1)
]==]
local V1_1_PARKED_DRAG_UPDATE_NEW=[==[		local mass = math.max(root.AssemblyMass, 1)
		if vehicle:GetAttribute("NTR_ExitCoasting")==true then
			local velocity=root.AssemblyLinearVelocity
			local horizontal=Vector3.new(velocity.X,0,velocity.Z)
			local dragPerSecond=interactionNumber("ExitCoastDragPerSecond",0.8,0.05,3)
			coastDrag.Force=-horizontal*mass*dragPerSecond
		else
			coastDrag.Force=Vector3.zero
		end
		local liftPerCorner = mass * Workspace.Gravity / math.max(#corners, 1)
]==]

local COLLISION_SERVICE_SOURCE=[==[
-- NTR_VEHICLE_MULTIPLAYER_COLLISION_LIFECYCLE_V1
-- NTR_VEHICLE_EXIT_COAST_LIFECYCLE_V1_1
-- Canonical server owner for free-roam vehicle/character collision groups.
-- RaceSessionAssetService remains authoritative for active race participants
-- and race arrow/barrier collision.

local Players=game:GetService("Players")
local PhysicsService=game:GetService("PhysicsService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local CHARACTER="NTR_Character"
local SLOW="NTR_VehicleSlow"
local FAST="NTR_VehicleFast"
local RACE="NTR_RaceParticipant"
local RACE_ASSET="NTR_RaceSessionAsset"
local MPH_PER_STUD=0.625

local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local settings=kit:WaitForChild("Config"):WaitForChild("Editable"):WaitForChild("01_GAME_BALANCE_Editable"):WaitForChild("VehicleInteractions")
local vehiclesRoot=Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Runtime"):WaitForChild("PlayerVehicles")
local records=setmetatable({},{__mode="k"})

local function number(name,fallback,minimum,maximum)
	return math.clamp(tonumber(settings:GetAttribute(name)) or fallback,minimum,maximum)
end

local function ensureGroup(name)
	pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
end

local function pair(a,b,collidable)
	PhysicsService:CollisionGroupSetCollidable(a,b,collidable)
end

local function configure()
	for _,name in ipairs({CHARACTER,SLOW,FAST,RACE,RACE_ASSET}) do ensureGroup(name) end
	pair(CHARACTER,CHARACTER,true)
	pair(CHARACTER,"Default",true)
	pair(SLOW,"Default",true)
	pair(FAST,"Default",true)
	pair(SLOW,SLOW,false)
	pair(SLOW,FAST,false)
	pair(FAST,FAST,false)
	pair(SLOW,CHARACTER,true)
	pair(FAST,CHARACTER,false)
	pair(RACE,RACE,false)
	pair(RACE,CHARACTER,false)
	pair(RACE,SLOW,false)
	pair(RACE,FAST,false)
	pair(RACE_ASSET,RACE,true)
	pair(RACE_ASSET,SLOW,false)
	pair(RACE_ASSET,FAST,false)
end

local function setPart(part,group)
	if part:IsA("BasePart") and part.CollisionGroup~=group then part.CollisionGroup=group end
end

local function setModel(model,group)
	for _,item in ipairs(model:GetDescendants()) do setPart(item,group) end
end

local function modelUsesGroup(model,group)
	for _,item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.CollisionGroup==group then return true end
	end
	return false
end

local function characterGroup(character)
	return modelUsesGroup(character,RACE) and RACE or CHARACTER
end

local function raceOwnsVehicle(vehicle)
	if vehicle:GetAttribute("NTR_RaceParticipant")==true then return true end
	local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
	return root and root:IsA("BasePart") and root.CollisionGroup==RACE or false
end

local function registerCharacter(character)
	if not character then return end
	setModel(character,CHARACTER)
	character.DescendantAdded:Connect(function(item)
		if item:IsA("BasePart") then setPart(item,characterGroup(character)) end
	end)
end

local function registerPlayer(player)
	player.CharacterAdded:Connect(registerCharacter)
	if player.Character then registerCharacter(player.Character) end
end

local function finishExitCoast(vehicle,root,reason)
	if not (vehicle and vehicle.Parent and root and root.Parent) then return end
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
	root.Anchored=true
	vehicle:SetAttribute("NTR_ExitCoasting",nil)
	vehicle:SetAttribute("NTR_ExitCoastStartedAt",nil)
	vehicle:SetAttribute("NTR_ExitCoastStopReason",reason)
	vehicle:SetAttribute("NTR_ParkedFixed",true)
	vehicle:SetAttribute("ParkedShowcase",true)
end

local function updateExitCoast(vehicle)
	if vehicle:GetAttribute("NTR_ExitCoasting")~=true then return end
	local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
	if not (root and root:IsA("BasePart")) then return end
	local started=tonumber(vehicle:GetAttribute("NTR_ExitCoastStartedAt")) or Workspace:GetServerTimeNow()
	local elapsed=math.max(0,Workspace:GetServerTimeNow()-started)
	local velocity=root.AssemblyLinearVelocity
	local speedMph=Vector3.new(velocity.X,0,velocity.Z).Magnitude*MPH_PER_STUD
	local settle=number("ExitCoastSettleMph",8,0,50)
	local minimum=number("ExitCoastMinSeconds",0.75,0,5)
	local maximum=math.max(minimum+0.25,number("ExitCoastMaxSeconds",6,1,15))
	if elapsed>=minimum and speedMph<=settle then
		finishExitCoast(vehicle,root,"Settled")
	elseif elapsed>=maximum then
		finishExitCoast(vehicle,root,"SafetyTimeout")
	end
end

local function desiredFreeRoamGroup(vehicle,record)
	local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
	if not (root and root:IsA("BasePart")) then return SLOW end
	if vehicle:GetAttribute("NTR_ExitCoasting")==true then return FAST end
	if vehicle:GetAttribute("NTR_ParkedFixed")==true or root.Anchored then return SLOW end
	local velocity=root.AssemblyLinearVelocity
	local speedMph=Vector3.new(velocity.X,0,velocity.Z).Magnitude*MPH_PER_STUD
	local enter=number("VehiclePassThroughEnterMph",20,1,200)
	local exit=math.min(enter-0.5,number("VehiclePassThroughExitMph",16,0,199))
	if record.Group==FAST then return speedMph<=exit and SLOW or FAST end
	return speedMph>enter and FAST or SLOW
end

local function applyVehicle(vehicle,record,group)
	if record.Group==group then return end
	record.Group=group
	setModel(vehicle,group)
	vehicle:SetAttribute("NTR_VehicleCollisionState",group==FAST and "FastPassThrough" or "SlowCharacterCollision")
end

local function cleanupVehicle(vehicle)
	local record=records[vehicle]
	if not record then return end
	for _,connection in ipairs(record.Connections) do connection:Disconnect() end
	records[vehicle]=nil
end

local function registerVehicle(vehicle)
	if records[vehicle] or not vehicle:IsA("Model") then return end
	local record={Group=nil,Connections={}}
	records[vehicle]=record
	table.insert(record.Connections,vehicle.DescendantAdded:Connect(function(item)
		if not item:IsA("BasePart") then return end
		if raceOwnsVehicle(vehicle) then
			setPart(item,RACE)
		else
			setPart(item,record.Group or SLOW)
		end
	end))
	table.insert(record.Connections,vehicle.Destroying:Connect(function() cleanupVehicle(vehicle) end))
	if not raceOwnsVehicle(vehicle) then
		applyVehicle(vehicle,record,desiredFreeRoamGroup(vehicle,record))
	end
end

configure()
Players.PlayerAdded:Connect(registerPlayer)
for _,player in ipairs(Players:GetPlayers()) do registerPlayer(player) end
vehiclesRoot.ChildAdded:Connect(function(vehicle) task.defer(registerVehicle,vehicle) end)
vehiclesRoot.ChildRemoved:Connect(cleanupVehicle)
for _,vehicle in ipairs(vehiclesRoot:GetChildren()) do registerVehicle(vehicle) end

task.spawn(function()
	while script.Parent do
		local hz=number("CollisionUpdateHz",10,2,30)
		for vehicle,record in pairs(records) do
			if not vehicle.Parent then
				cleanupVehicle(vehicle)
			elseif raceOwnsVehicle(vehicle) then
				-- Do not compete with the existing race participant owner.
				record.Group=RACE
			else
				updateExitCoast(vehicle)
				applyVehicle(vehicle,record,desiredFreeRoamGroup(vehicle,record))
			end
		end
		task.wait(1/hz)
	end
end)

print("[NTR Vehicle Multiplayer VFX Collision Exit V1.1] Collision/coast lifecycle active.")
]==]

local function project()
	local projected={}

	projected.VFX=cachedVfx.Source
	if not projected.VFX:find("NTR_VEHICLE_MULTIPLAYER_VFX_STATE_V1",1,true) then
		projected.VFX=replaceOnce(projected.VFX,OLD_VFX_STATE,NEW_VFX_STATE,"CachedThrustVisualRuntime runtimeState")
	end

	projected.AudioController=audioController.Source
	if not projected.AudioController:find("NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1",1,true) then
		projected.AudioController=replaceOnce(projected.AudioController,OLD_AUDIO_LOOP,NEW_AUDIO_LOOP,"VehicleAudioController silent semantic transport")
	end

	projected.AudioServer=audioStateService.Source
	if not projected.AudioServer:find("NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1",1,true) then
		projected.AudioServer=replaceOnce(projected.AudioServer,OLD_AUDIO_SERVER_GATE,NEW_AUDIO_SERVER_GATE,"VehicleAudioStateService playback-independent validation")
	end

	projected.Parked=parkedHover.Source
	if not projected.Parked:find("NTR_VEHICLE_FIXED_PARKING_V1",1,true) then
		projected.Parked=replaceOnce(projected.Parked,OLD_PARKED_GATE,NEW_PARKED_GATE,"Parked hover fixed-vehicle exclusion")
	end
	if not projected.Parked:find("NTR_VEHICLE_EXIT_COAST_DRAG_V1_1",1,true) then
		projected.Parked=replaceOnce(projected.Parked,V1_1_PARKED_CONFIG_OLD,V1_1_PARKED_CONFIG_NEW,"Parked hover coast config")
		projected.Parked=replaceOnce(projected.Parked,V1_1_PARKED_DRAG_CREATE_OLD,V1_1_PARKED_DRAG_CREATE_NEW,"Parked hover coast drag force")
		projected.Parked=replaceOnce(projected.Parked,V1_1_PARKED_STATE_OLD,V1_1_PARKED_STATE_NEW,"Parked hover coast state")
		projected.Parked=replaceOnce(projected.Parked,V1_1_PARKED_DRAG_UPDATE_OLD,V1_1_PARKED_DRAG_UPDATE_NEW,"Parked hover coast drag update")
	end

	projected.Garage=garageAction.Source
	if not projected.Garage:find("NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1",1,true) then
		projected.Garage=replaceOnce(projected.Garage,OLD_EXIT_BLOCK,NEW_EXIT_BLOCK,"Garage exit/fixed parking")
		projected.Garage=replaceOnce(projected.Garage,OLD_REENTER_BLOCK,NEW_REENTER_BLOCK,"Garage fixed-vehicle re-entry")
	end
	if not projected.Garage:find("NTR_VEHICLE_SPEED_SENSITIVE_EXIT_COAST_V1_1",1,true) then
		projected.Garage=replaceOnce(projected.Garage,NEW_EXIT_BLOCK,V1_1_EXIT_BLOCK,"Garage speed-sensitive exit coast")
		projected.Garage=replaceOnce(projected.Garage,NEW_REENTER_BLOCK,V1_1_REENTER_BLOCK,"Garage coast re-entry guard")
	end

	projected.VehicleAccess=vehicleAccess.Source
	if not projected.VehicleAccess:find("NTR_VEHICLE_FIXED_PROMPT_REENTRY_V1",1,true) then
		projected.VehicleAccess=replaceOnce(projected.VehicleAccess,OLD_PROMPT_ENTER,NEW_PROMPT_ENTER,"Vehicle prompt fixed-vehicle re-entry")
	end
	if not projected.VehicleAccess:find("NTR_VEHICLE_COAST_PROMPT_GUARD_V1_1",1,true) then
		projected.VehicleAccess=replaceOnce(projected.VehicleAccess,V1_1_PROMPT_CAN_ENTER_OLD,V1_1_PROMPT_CAN_ENTER_NEW,"Vehicle coast prompt entry guard")
		projected.VehicleAccess=replaceOnce(projected.VehicleAccess,V1_1_PROMPT_ENABLED_OLD,V1_1_PROMPT_ENABLED_NEW,"Vehicle coast prompt visibility")
	end

	return projected
end

local function audit()
	local service=vehicleServices:FindFirstChild("VehicleCollisionLifecycleService_Active")
	local checks={
		{"remote VFX semantic consumer",cachedVfx.Source:find("NTR_VEHICLE_MULTIPLAYER_VFX_STATE_V1",1,true)~=nil},
		{"race VFX gate preserved",cachedVfx.Source:find("NTR_RACING_PHASE11E_VFX_GATE",1,true)~=nil},
		{"client semantic transport",audioController.Source:find("NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1",1,true)~=nil},
		{"server semantic validation",audioStateService.Source:find("NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1",1,true)~=nil and audioStateService.Source:find("Contract.Validate(payload)",1,true)~=nil},
		{"fixed parked hover exclusion",parkedHover.Source:find("NTR_VEHICLE_FIXED_PARKING_V1",1,true)~=nil},
		{"bounded client coast drag",parkedHover.Source:find("NTR_VEHICLE_EXIT_COAST_DRAG_V1_1",1,true)~=nil},
		{"server fixed parking/right exit",garageAction.Source:find("NTR_VEHICLE_FIXED_PARKING_AND_RIGHT_EXIT_V1",1,true)~=nil},
		{"speed-sensitive server exit coast",garageAction.Source:find("NTR_VEHICLE_SPEED_SENSITIVE_EXIT_COAST_V1_1",1,true)~=nil},
		{"garage coast re-entry guard",garageAction.Source:find("NTR_VEHICLE_COAST_REENTRY_GUARD_V1_1",1,true)~=nil},
		{"prompt fixed-vehicle re-entry",vehicleAccess.Source:find("NTR_VEHICLE_FIXED_PROMPT_REENTRY_V1",1,true)~=nil},
		{"coast prompt guard",vehicleAccess.Source:find("NTR_VEHICLE_COAST_PROMPT_GUARD_V1_1",1,true)~=nil and vehicleAccess.Source:find("NTR_VEHICLE_COAST_PROMPT_VISIBILITY_V1_1",1,true)~=nil},
		{"collision/coast lifecycle service",service and service:IsA("Script") and service.Disabled==false and service.Source:find("NTR_VEHICLE_EXIT_COAST_LIFECYCLE_V1_1",1,true)~=nil},
		{"race collision policy preserved",raceAssets.Source:find("NTR_RACING_PHASE11E_COLLISION_POLICY",1,true)~=nil},
		{"vehicle interaction config",interactions and interactions:GetAttribute("Revision")==REVISION},
	}
	for _,check in ipairs(checks) do
		assert(check[2],"AUDIT FAIL: "..check[1])
	end
	print(TAG.." AUDIT PASS checks="..#checks.." revision="..REVISION)
	return true
end

if MODE=="AUDIT" then
	audit()
	return
end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local projected=project()
for name,source in pairs(projected) do compile(source,name.."_Projected") end
compile(COLLISION_SERVICE_SOURCE,"VehicleCollisionLifecycleService_Active_Projected")

local sources={
	[cachedVfx]=cachedVfx.Source,
	[audioController]=audioController.Source,
	[audioStateService]=audioStateService.Source,
	[parkedHover]=parkedHover.Source,
	[garageAction]=garageAction.Source,
	[vehicleAccess]=vehicleAccess.Source,
}
local sourceAttributes={}
for instance in pairs(sources) do sourceAttributes[instance]=snapshotAttributes(instance) end

local existingService=vehicleServices:FindFirstChild("VehicleCollisionLifecycleService_Active")
if existingService then assert(existingService:IsA("Script"),existingService:GetFullName().." must be a Script") end
local serviceSnapshot=existingService and {
	Source=existingService.Source,
	Disabled=existingService.Disabled,
	Attributes=snapshotAttributes(existingService),
} or nil
local configSnapshot=interactions and snapshotAttributes(interactions) or nil
local createdConfig=interactions==nil

local ok,problem=pcall(function()
	interactions=interactions or ensureFolder(balance,"VehicleInteractions")
	interactions:SetAttribute("VehiclePassThroughEnterMph",20)
	interactions:SetAttribute("VehiclePassThroughExitMph",16)
	interactions:SetAttribute("CollisionUpdateHz",10)
	interactions:SetAttribute("ExitRightStuds",6)
	interactions:SetAttribute("ExitUpStuds",2.5)
	interactions:SetAttribute("ExitImmediateParkMaxMph",10)
	interactions:SetAttribute("ExitCoastSettleMph",8)
	interactions:SetAttribute("ExitCoastMinSeconds",0.75)
	interactions:SetAttribute("ExitCoastMaxSeconds",6)
	interactions:SetAttribute("ExitCoastDragPerSecond",0.8)
	interactions:SetAttribute("Revision",REVISION)
	interactions:SetAttribute("Description","Vehicle collision, fixed parking, right-side exit and bounded exit-coasting tuning.")

	cachedVfx.Source=projected.VFX
	audioController.Source=projected.AudioController
	audioStateService.Source=projected.AudioServer
	parkedHover.Source=projected.Parked
	garageAction.Source=projected.Garage
	vehicleAccess.Source=projected.VehicleAccess

	for instance in pairs(sources) do
		instance:SetAttribute("VehicleMultiplayerRevision",REVISION)
		instance:SetAttribute("VehicleMultiplayerInstallRunId",RUN_ID)
		compile(instance.Source,instance.Name.."_Committed")
	end

	local service=existingService
	if not service then
		service=Instance.new("Script")
		service.Name="VehicleCollisionLifecycleService_Active"
		service.Parent=vehicleServices
	end
	service.Source=COLLISION_SERVICE_SOURCE
	service.Disabled=false
	service:SetAttribute("Revision",REVISION)
	service:SetAttribute("InstallRunId",RUN_ID)
	compile(service.Source,service.Name.."_Committed")

	audit()
end)

if not ok then
	pcall(function()
		for instance,source in pairs(sources) do
			instance.Source=source
			restoreAttributes(instance,sourceAttributes[instance])
		end
		local service=vehicleServices:FindFirstChild("VehicleCollisionLifecycleService_Active")
		if serviceSnapshot and service then
			service.Source=serviceSnapshot.Source
			service.Disabled=serviceSnapshot.Disabled
			restoreAttributes(service,serviceSnapshot.Attributes)
		elseif service and not serviceSnapshot then
			service:Destroy()
		end
		if createdConfig and interactions and interactions.Parent then
			interactions:Destroy()
		elseif interactions and configSnapshot then
			restoreAttributes(interactions,configSnapshot)
		end
	end)
	error(TAG.." rolled back after failure: "..tostring(problem),0)
end

print(TAG.." PASS revision="..REVISION.." runId="..RUN_ID)
print(TAG.." Restart Studio, then use a two-client local server for the documented VFX/collision/race/exit matrix.")
