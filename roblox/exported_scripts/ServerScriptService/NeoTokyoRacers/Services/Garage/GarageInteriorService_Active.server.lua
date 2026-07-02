-- NTR Persistence Phase 21-23 Garage Interior Service Canonical Source

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 23 GarageInteriorService]"

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local garageRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage")
local invoke = garageRemotes:WaitForChild("GarageInteriorInvoke")
local transition = garageRemotes:WaitForChild("GarageInteriorTransition")

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local interiors = world:WaitForChild("Interiors")
local garageRoot = interiors:WaitForChild("GarageInstances")
local interactives = world:WaitForChild("Interactives")
local GarageDisplayRuntime = require(script.Parent:WaitForChild("GarageDisplayRuntime"))

local activeSlotsByUserId = {}
local returnCFramesByUserId = {}
local promptConnections = {}
local garageInvitesByOwnerUserId = {}

local VALID_ACCESS_MODES = {
	Private = true,
	FriendsOnly = true,
	InviteOnly = true,
	Public = true,
}

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function setPartDefaults(part)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makePart(parent, name, size, cframe, color, material)
	local part = ensureChild(parent, "Part", name)
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	setPartDefaults(part)
	return part
end

local function slotIndexFor(player)
	local userId = player.UserId
	if activeSlotsByUserId[userId] then
		return activeSlotsByUserId[userId]
	end
	local used = {}
	for _, index in pairs(activeSlotsByUserId) do
		used[index] = true
	end
	local index = 1
	while used[index] do
		index += 1
	end
	activeSlotsByUserId[userId] = index
	return index
end

local function interiorBaseCFrame(player)
	local basePosition = garageRoot:GetAttribute("InteriorBasePosition")
	if typeof(basePosition) ~= "Vector3" then
		basePosition = Vector3.new(0, 1200, 0)
	end
	local spacing = tonumber(garageRoot:GetAttribute("InteriorSlotSpacing")) or 260
	return CFrame.new(basePosition + Vector3.new((slotIndexFor(player) - 1) * spacing, 0, 0))
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function fallbackCityCFrame(player)
	local dealershipExit = findPath(world, { "Dealership", "Spawn", "VehicleExitSpawnPoint" })
	if dealershipExit and dealershipExit:IsA("BasePart") then
		return dealershipExit.CFrame * CFrame.new(0, 4, -6), "DealershipExit"
	end
	local vehicleSpawn = findPath(world, { "SpawnPoints", "VehicleSpawnPoint" })
	if vehicleSpawn and vehicleSpawn:IsA("BasePart") then
		return vehicleSpawn.CFrame * CFrame.new(0, 4, -8), "VehicleSpawnPoint"
	end
	local root = getCharacterRoot(player)
	if root then
		return root.CFrame, "CurrentCharacter"
	end
	return CFrame.new(0, 12, 0), "WorldOrigin"
end

local function teleportCharacter(player, cframe)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return false, "MissingHumanoidRootPart"
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function connectReturnPrompt(model)
	local prompt = model:FindFirstChild("ReturnToCityPrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if promptConnections[prompt] then
		return
	end
	promptConnections[prompt] = prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer then
			local ok, err = pcall(function()
				invoke.OnServerInvoke(triggeringPlayer, "ReturnToCity", { Source = "Prompt" })
			end)
			if not ok then
				warn(TAG .. " Return prompt failed: " .. tostring(err))
			end
		end
	end)
end

local function ensureInterior(player)
	local name = "GarageInterior_" .. tostring(player.UserId)
	local model = garageRoot:FindFirstChild(name)
	if model and model:IsA("Model") then
		connectReturnPrompt(model)
		return model
	end

	model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("AccessMode", player:GetAttribute("NTR_Phase23GarageAccessMode") or "Private")
	model:SetAttribute("PersistencePhase21PrivateGarageInteriorMVP", true)
	model:SetAttribute("PersistencePhase23SameServerGarageVisits", true)
	model.Parent = garageRoot

	local base = interiorBaseCFrame(player)
	local floor = makePart(model, "Floor", Vector3.new(80, 1, 54), base, Color3.fromRGB(18, 24, 30), Enum.Material.Metal)
	model.PrimaryPart = floor
	makePart(model, "BackWall", Vector3.new(80, 18, 1), base * CFrame.new(0, 9, 27), Color3.fromRGB(29, 36, 46), Enum.Material.Metal)
	makePart(model, "LeftWall", Vector3.new(1, 18, 54), base * CFrame.new(-40, 9, 0), Color3.fromRGB(25, 31, 40), Enum.Material.Metal)
	makePart(model, "RightWall", Vector3.new(1, 18, 54), base * CFrame.new(40, 9, 0), Color3.fromRGB(25, 31, 40), Enum.Material.Metal)
	makePart(model, "CeilingLight", Vector3.new(42, 0.4, 3), base * CFrame.new(0, 15, 0), Color3.fromRGB(210, 80, 190), Enum.Material.Neon)
	makePart(model, "VehicleDisplayPad", Vector3.new(24, 0.35, 16), base * CFrame.new(0, 0.8, 2), Color3.fromRGB(45, 75, 88), Enum.Material.Neon)

	local spawn = makePart(model, "GarageSpawnPoint", Vector3.new(4, 0.4, 4), base * CFrame.new(-28, 1.05, -18), Color3.fromRGB(100, 255, 170), Enum.Material.Neon)
	spawn.Transparency = 0.25
	spawn:SetAttribute("Purpose", "Character spawn inside private garage.")

	local returnPad = makePart(model, "ReturnToCityPad", Vector3.new(7, 0.4, 7), base * CFrame.new(28, 1.05, -18), Color3.fromRGB(255, 110, 210), Enum.Material.Neon)
	local prompt = ensureChild(returnPad, "ProximityPrompt", "ReturnToCityPrompt")
	prompt.ActionText = "Return"
	prompt.ObjectText = "City Elevator"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false

	connectReturnPrompt(model)
	return model
end

local function setAccessMode(player, payload)
	local mode = tostring(payload and payload.AccessMode or "Private")
	if not VALID_ACCESS_MODES[mode] then
		return { Ok = false, Error = "InvalidAccessMode" }
	end
	local model = ensureInterior(player)
	model:SetAttribute("AccessMode", mode)
	player:SetAttribute("NTR_Phase23GarageAccessMode", mode)
	return {
		Ok = true,
		AccessMode = mode,
		InteriorId = model.Name,
	}
end

local function inviteVisitor(player, payload)
	local targetUserId = tonumber(payload and payload.UserId)
	if not targetUserId then
		return { Ok = false, Error = "MissingUserId" }
	end
	garageInvitesByOwnerUserId[player.UserId] = garageInvitesByOwnerUserId[player.UserId] or {}
	garageInvitesByOwnerUserId[player.UserId][targetUserId] = true
	return {
		Ok = true,
		OwnerUserId = player.UserId,
		UserId = targetUserId,
	}
end

local function isInvited(ownerUserId, visitorUserId)
	local inviteSet = garageInvitesByOwnerUserId[ownerUserId]
	return inviteSet and inviteSet[visitorUserId] == true
end

local function canVisitGarage(visitor, owner, model)
	if visitor == owner then
		return true, "Owner"
	end
	local mode = tostring(model:GetAttribute("AccessMode") or "Private")
	if mode == "Public" then
		return true, "Public"
	elseif mode == "FriendsOnly" then
		local ok, result = pcall(function()
			return visitor:IsFriendsWith(owner.UserId)
		end)
		return ok and result == true, "FriendsOnly"
	elseif mode == "InviteOnly" then
		return isInvited(owner.UserId, visitor.UserId), "InviteOnly"
	end
	return false, "Private"
end

local function findPlayerInServerByUserId(userId)
	userId = tonumber(userId)
	if not userId then
		return nil
	end
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == userId then
			return candidate
		end
	end
	return nil
end

local function enterOwnGarage(player)
	return invoke.OnServerInvoke(player, "VisitGarage", { OwnerUserId = player.UserId })
end

local function visitGarage(player, payload)
	local ownerUserId = tonumber(payload and payload.OwnerUserId)
	if not ownerUserId then
		return { Ok = false, Error = "MissingOwnerUserId" }
	end
	local owner = findPlayerInServerByUserId(ownerUserId)
	if not owner then
		return { Ok = false, Error = "OwnerNotInServer" }
	end

	local model = ensureInterior(owner)
	local allowed, accessReason = canVisitGarage(player, owner, model)
	if not allowed then
		return {
			Ok = false,
			Error = "AccessDenied",
			AccessMode = tostring(model:GetAttribute("AccessMode") or "Private"),
			AccessReason = accessReason,
		}
	end

	local root = getCharacterRoot(player)
	if root then
		returnCFramesByUserId[player.UserId] = root.CFrame
	else
		returnCFramesByUserId[player.UserId] = fallbackCityCFrame(player)
	end

	local displayResult = GarageDisplayRuntime.RefreshDisplayVehicle(owner, model)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)
	if not spawn or not spawn:IsA("BasePart") then
		return { Ok = false, Error = "MissingGarageSpawnPoint" }
	end

	transition:FireClient(player, { Step = "FadeOut", Label = player == owner and "Entering garage" or "Visiting garage" })
	task.wait(0.15)
	local ok, err = teleportCharacter(player, spawn.CFrame * CFrame.new(0, 4, 0))
	if not ok then
		return { Ok = false, Error = err }
	end

	local mode = tostring(model:GetAttribute("AccessMode") or "Private")
	player:SetAttribute("NTR_Phase21InPrivateGarage", true)
	player:SetAttribute("NTR_Phase21GarageInteriorId", model.Name)
	player:SetAttribute("NTR_Phase21GarageAccessMode", mode)
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", owner.UserId)
	player:SetAttribute("NTR_Phase23VisitAccessMode", mode)
	transition:FireClient(player, { Step = "Stream", Label = "Loading garage", Position = spawn.Position })

	return {
		Ok = true,
		InteriorId = model.Name,
		OwnerUserId = owner.UserId,
		AccessMode = mode,
		AccessReason = accessReason,
		DisplayOk = typeof(displayResult) == "table" and displayResult.Ok == true,
		DisplayName = typeof(displayResult) == "table" and displayResult.DisplayName or nil,
		DisplayError = typeof(displayResult) == "table" and displayResult.Error or nil,
	}
end

local function returnToCity(player)
	local cframe = returnCFramesByUserId[player.UserId]
	local source = "SavedReturnCFrame"
	if typeof(cframe) ~= "CFrame" then
		cframe, source = fallbackCityCFrame(player)
	end

	transition:FireClient(player, { Step = "FadeOut", Label = "Returning to city" })
	task.wait(0.15)
	local ok, err = teleportCharacter(player, cframe)
	if not ok then
		return { Ok = false, Error = err }
	end

	player:SetAttribute("NTR_Phase21InPrivateGarage", false)
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", nil)
	player:SetAttribute("NTR_Phase23VisitAccessMode", nil)
	transition:FireClient(player, { Step = "Stream", Label = "Loading city", Position = cframe.Position })

	return {
		Ok = true,
		ReturnSource = source,
	}
end

local function getState(player)
	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
	local display = model and model:FindFirstChild("DisplayVehicle_Runtime") or nil
	return {
		Ok = true,
		InGarage = player:GetAttribute("NTR_Phase21InPrivateGarage") == true,
		InteriorId = interiorId,
		InteriorExists = model ~= nil,
		AccessMode = player:GetAttribute("NTR_Phase21GarageAccessMode"),
		DisplayExists = display ~= nil,
		DisplayName = display and display.Name or nil,
		DisplaySource = display and display:GetAttribute("DisplaySource") or nil,
		VisitingOwnerUserId = player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId"),
		VisitAccessMode = player:GetAttribute("NTR_Phase23VisitAccessMode"),
	}
end

local function connectEntryPrompt()
	local elevator = interactives:FindFirstChild("GarageInteriorElevatorMVP")
	local prompt = elevator and elevator:FindFirstChild("EnterPrivateGaragePrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if promptConnections[prompt] then
		return
	end
	promptConnections[prompt] = prompt.Triggered:Connect(function(player)
		enterOwnGarage(player)
	end)
end

invoke.OnServerInvoke = function(player, action, payload)
	if action == "EnterOwnGarage" then
		return enterOwnGarage(player)
	elseif action == "VisitGarage" then
		return visitGarage(player, payload)
	elseif action == "SetAccessMode" then
		return setAccessMode(player, payload)
	elseif action == "InviteVisitor" then
		return inviteVisitor(player, payload)
	elseif action == "ReturnToCity" then
		return returnToCity(player)
	elseif action == "GetState" then
		return getState(player)
	end
	return { Ok = false, Error = "UnknownAction" }
end

Players.PlayerRemoving:Connect(function(player)
	returnCFramesByUserId[player.UserId] = nil
	activeSlotsByUserId[player.UserId] = nil
	garageInvitesByOwnerUserId[player.UserId] = nil
	local model = garageRoot:FindFirstChild("GarageInterior_" .. tostring(player.UserId))
	if model then
		model:Destroy()
	end
end)

connectEntryPrompt()
script:SetAttribute("PersistencePhase23CanonicalService", true)
print(TAG .. " ready.")
