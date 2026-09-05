-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
-- Neo Tokyo Racers - Racing Phase 7B Browser Teleport Service
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = game:GetService("ReplicatedStorage")
local shared = game:GetService("ReplicatedStorage")
local racingModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing")
local RaceConfigReader = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceConfigReader"))
local RouteDefinition = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceRouteDefinition"))

local racingRemotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing")
local invoke = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceBrowserTeleportInvoke")

local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Racing")
local browserConfig = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Racing"):WaitForChild("BrowserTeleport")
local lastTeleportByUserId = {}

local function numberValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function worldRoot()
	return game:GetService("Workspace"):FindFirstChild("World")
end

local function vehiclesRoot()
	local world = worldRoot()
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function playerVehicle(player)
	local root = vehiclesRoot()
	for _, vehicle in ipairs(root and root:GetChildren() or {}) do
		if tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
			return vehicle
		end
	end
	return nil
end

local function firstBasePart(folder)
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if item:IsA("BasePart") then
			return item
		end
	end
	return nil
end

local function teleportPointForRoute(route, mode)
	local folder = route and route.Folder
	local points = folder and folder:FindFirstChild("TeleportPoints")
	if not points then return nil end
	mode = tostring(mode or "TimeTrial")
	local preferred = points:FindFirstChild(mode .. "TeleportPoint")
		or points:FindFirstChild(mode .. "StartTeleport")
		or points:FindFirstChild("RaceBrowserTeleportPoint")
		or points:FindFirstChild("StartTeleportPoint")
	if preferred and preferred:IsA("BasePart") then
		return preferred
	end
	return firstBasePart(points)
end

local function seatIsInVehicle(player, vehicle)
	if not vehicle then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
end

local function unseat(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
end

local function zeroCharacterVelocity(character)
	for _, descendant in ipairs(character and character:GetDescendants() or {}) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return false, "Character not ready."
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "Character root not ready."
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	zeroCharacterVelocity(character)
	character:PivotTo(targetCFrame)
	zeroCharacterVelocity(character)
	task.delay(numberValue(browserConfig, "CharacterUnfreezeDelaySeconds", 0.18), function()
		if root and root.Parent then
			root.Anchored = wasAnchored
		end
	end)
	return true, nil
end

local function destroyVehicleAfterClear(player, vehicle)
	if not vehicle then
		return
	end
	vehicle:SetAttribute("RaceBrowserTeleportDespawn", true)
	vehicle:SetAttribute("DriverUserId", nil)
	vehicle:SetAttribute("DriveReady", false)
	vehicle:SetAttribute("ParkedShowcase", false)
	task.wait(numberValue(browserConfig, "VehicleDespawnDelaySeconds", 0.14))
	if vehicle and vehicle.Parent then
		if seatIsInVehicle(player, vehicle) then
			unseat(player)
			task.wait(0.05)
		end
		vehicle:Destroy()
	end
end

local function targetCFrame(point)
	local height = numberValue(browserConfig, "TeleportHeightOffset", 4)
	local forward = numberValue(browserConfig, "TeleportForwardOffset", 0)
	return point.CFrame * CFrame.new(0, height, -forward)
end

local function teleportToEvent(player, payload)
	if player:GetAttribute("OwnedGarageInside")==true then return {Ok=false,Success=false,Message="Exit your garage before teleporting to a race."} end
	payload = typeof(payload) == "table" and payload or {}
	local eventId = tostring(payload.EventId or "")
	local mode = tostring(payload.Mode or "TimeTrial")
	if eventId == "" then
		return { Ok = false, Success = false, Message = "No event selected." }
	end

	local now = os.clock()
	local cooldown = numberValue(browserConfig, "TeleportCooldownSeconds", 1.25)
	local last = lastTeleportByUserId[player.UserId] or 0
	if now - last < cooldown then
		return { Ok = false, Success = false, Message = "Teleport is cooling down." }
	end

	local summary, summaryError = RaceConfigReader.GetEventSummary(eventId, mode)
	if not summary then
		return { Ok = false, Success = false, Message = tostring(summaryError or "Event not found.") }
	end
	local route, routeError = RouteDefinition.GetRouteDefinition(summary.RouteId)
	if not route then
		return { Ok = false, Success = false, Message = tostring(routeError or "Route not found.") }
	end
	local point = teleportPointForRoute(route, mode)
	if not point then
		return { Ok = false, Success = false, Message = "No teleport point exists for this route." }
	end

	local character = player.Character
	if not character then
		return { Ok = false, Success = false, Message = "Character not ready." }
	end
	local vehicle = playerVehicle(player)
	lastTeleportByUserId[player.UserId] = now
	player:SetAttribute("RaceBrowserTeleporting", true)
	player:SetAttribute("RaceBrowserLastTeleportRouteId", tostring(summary.RouteId or ""))
	player:SetAttribute("RaceBrowserLastTeleportEventId", eventId)

	unseat(player)
	task.wait(numberValue(browserConfig, "UnseatSettleSeconds", 0.08))
	local ok, err = teleportCharacter(player, targetCFrame(point))
	if not ok then
		player:SetAttribute("RaceBrowserTeleporting", false)
		return { Ok = false, Success = false, Message = err or "Teleport failed." }
	end
	destroyVehicleAfterClear(player, vehicle)
	task.delay(0.35, function()
		if player and player.Parent then
			player:SetAttribute("RaceBrowserTeleporting", false)
		end
	end)

	return {
		Ok = true,
		Success = true,
		Message = "Teleported to race start.",
		RouteId = summary.RouteId,
		EventId = eventId,
		Mode = mode,
		VehicleDespawned = vehicle ~= nil,
	}
end

invoke.OnServerInvoke = function(player, action, payload)
	if action == "TeleportToRaceStart" then
		local ok, result = pcall(function()
			return teleportToEvent(player, payload)
		end)
		if ok and typeof(result) == "table" then
			return result
		end
		warn("[Racing Phase 7B] Teleport failed: " .. tostring(result))
		return { Ok = false, Success = false, Message = "Teleport failed: " .. tostring(result) }
	end
	return { Ok = false, Success = false, Message = "Unknown race browser teleport action." }
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleportByUserId[player.UserId] = nil
end)

print("[Racing Phase 7B] Browser teleport service active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
