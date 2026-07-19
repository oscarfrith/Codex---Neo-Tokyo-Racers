-- NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local invoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
local config = kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("FreeRoamHudTeleport")
local lastTeleportByUserId = {}

local function numberValue(name, fallback)
	local item = config:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function teleportPoint()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local points = dealership and dealership:FindFirstChild("TeleportPoints")
	local point = points and points:FindFirstChild("FreeRoamHudTeleportPoint")
	return point and point:IsA("BasePart") and point or nil
end

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function playerVehicle(player)
	local root = vehiclesRoot()
	for _, vehicle in ipairs(root and root:GetChildren() or {}) do
		if tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then return vehicle end
	end
	return nil
end

local function raceLocked(player, vehicle)
	if player:GetAttribute("NTR_RaceBrowserTeleporting") == true then return true end
	if not vehicle then return false end
	return vehicle:GetAttribute("NTR_RaceParticipant") == true
		or vehicle:GetAttribute("NTR_RaceRunId") ~= nil
		or vehicle:GetAttribute("NTR_RaceFrozen") == true
end

local function unseat(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Sit = false; humanoid.PlatformStand = false end
end

local function zeroVelocity(character)
	for _, item in ipairs(character and character:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			item.AssemblyLinearVelocity = Vector3.zero
			item.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function destroyVehicle(player, vehicle)
	if not vehicle or not vehicle.Parent then return false end
	vehicle:SetAttribute("NTR_FreeRoamHudTeleportDespawn", true)
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("ParkedShowcase", false)
	task.wait(numberValue("VehicleDespawnDelaySeconds", 0.12))
	if vehicle.Parent and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then vehicle:Destroy() end
	return true
end

local function performTeleport(player)
	-- NTR_OWNED_GARAGE_PHASE5_TELEPORT_GUARD_V1
	if player:GetAttribute("NTR_OwnedGarageInside")==true then return {Ok=false,Success=false,Message="Exit your garage before teleporting to the dealership."} end
	local now = os.clock()
	local cooldown = math.max(0, numberValue("CooldownSeconds", 2))
	if now - (lastTeleportByUserId[player.UserId] or 0) < cooldown then
		return { Ok = false, Success = false, Message = "Teleport is cooling down." }
	end
	local point = teleportPoint()
	if not point then return { Ok = false, Success = false, Message = "Dealership teleport point is missing." } end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return { Ok = false, Success = false, Message = "Character is not ready." }
	end
	local vehicle = playerVehicle(player)
	if raceLocked(player, vehicle) then
		return { Ok = false, Success = false, Message = "Dealership teleport is unavailable during a race." }
	end
	lastTeleportByUserId[player.UserId] = now
	player:SetAttribute("NTR_FreeRoamHudTeleporting", true)
	unseat(player)
	task.wait(numberValue("UnseatSettleSeconds", 0.08))
	local wasAnchored = root.Anchored
	root.Anchored = true
	zeroVelocity(character)
	local target = point.CFrame * CFrame.new(0, numberValue("HeightOffset", 4), -numberValue("ForwardOffset", 0))
	character:PivotTo(target)
	zeroVelocity(character)
	local despawned = destroyVehicle(player, vehicle)
	task.delay(numberValue("CharacterUnfreezeDelaySeconds", 0.18), function()
		if root and root.Parent then root.Anchored = wasAnchored end
	end)
	task.delay(0.35, function()
		if player and player.Parent then player:SetAttribute("NTR_FreeRoamHudTeleporting", false) end
	end)
	return { Ok = true, Success = true, Message = "Teleported to dealership.", VehicleDespawned = despawned }
end

invoke.OnServerInvoke = function(player, action)
	if action ~= "TeleportToDealership" then
		return { Ok = false, Success = false, Message = "Unknown teleport action." }
	end
	local ok, result = pcall(performTeleport, player)
	if ok and typeof(result) == "table" then return result end
	warn("[NTR PC Free-Roam UI Phase 4A] Teleport failed: " .. tostring(result))
	player:SetAttribute("NTR_FreeRoamHudTeleporting", false)
	return { Ok = false, Success = false, Message = "Dealership teleport failed." }
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleportByUserId[player.UserId] = nil
end)

print("[NTR PC Free-Roam UI Phase 4A] Dealership teleport service active.")
