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
