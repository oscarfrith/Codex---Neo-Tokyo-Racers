-- Neo Tokyo Racers - Racing Phase 7B Race Browser Teleport
-- Run in Roblox Studio Command Bar in Edit mode.
--
-- Replaces Phase 7 waypointing with a server-authoritative teleport to an
-- editable per-route teleport point. This phase does not edit reward config.
-- It patches the isolated RaceBrowserClient_Active; if that source shape is
-- not the Phase 7 shape, it stops and asks for a fresh mirror/inspection.

local MODE = "INSTALL" -- INSTALL or SMOKE

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(("Existing %s is %s, expected %s"):format(existing:GetFullName(), existing.ClassName, className))
		end
		return existing
	end
	local item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end

local function setValue(parent, className, name, value)
	local item = child(parent, className, name)
	item.Value = value
	return item
end

local function replaceOnce(source, old, new, label)
	local first = string.find(source, old, 1, true)
	if not first then
		error("[NTR Racing Phase 7B] Could not find source anchor: " .. label .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, old, first + #old, true)
	if second then
		error("[NTR Racing Phase 7B] Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, first + #old)
end

local function serviceSource()
	return [====[
-- Neo Tokyo Racers - Racing Phase 7B Browser Teleport Service
-- NTR_RACING_PHASE7B_BROWSER_TELEPORT_SERVICE

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared = kit:WaitForChild("Shared")
local racingModules = shared:WaitForChild("Modules"):WaitForChild("Racing")
local RaceConfigReader = require(racingModules:WaitForChild("RaceConfigReader"))
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

local racingRemotes = shared:WaitForChild("Remotes"):WaitForChild("Racing")
local invoke = racingRemotes:WaitForChild("RaceBrowserTeleportInvoke")

local config = kit:WaitForChild("Config"):WaitForChild("Racing")
local browserConfig = config:WaitForChild("BrowserTeleport")
local lastTeleportByUserId = {}

local function numberValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function worldRoot()
	return Workspace:FindFirstChild("NeoTokyoRacersWorld")
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
	vehicle:SetAttribute("NTR_RaceBrowserTeleportDespawn", true)
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
	player:SetAttribute("NTR_RaceBrowserTeleporting", true)
	player:SetAttribute("NTR_RaceBrowserLastTeleportRouteId", tostring(summary.RouteId or ""))
	player:SetAttribute("NTR_RaceBrowserLastTeleportEventId", eventId)

	unseat(player)
	task.wait(numberValue(browserConfig, "UnseatSettleSeconds", 0.08))
	local ok, err = teleportCharacter(player, targetCFrame(point))
	if not ok then
		player:SetAttribute("NTR_RaceBrowserTeleporting", false)
		return { Ok = false, Success = false, Message = err or "Teleport failed." }
	end
	destroyVehicleAfterClear(player, vehicle)
	task.delay(0.35, function()
		if player and player.Parent then
			player:SetAttribute("NTR_RaceBrowserTeleporting", false)
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
		warn("[NTR Racing Phase 7B] Teleport failed: " .. tostring(result))
		return { Ok = false, Success = false, Message = "Teleport failed: " .. tostring(result) }
	end
	return { Ok = false, Success = false, Message = "Unknown race browser teleport action." }
end

Players.PlayerRemoving:Connect(function(player)
	lastTeleportByUserId[player.UserId] = nil
end)

print("[NTR Racing Phase 7B] Browser teleport service active.")
]====]
end

local function ensureTeleportPoint(route)
	local points = child(route, "Folder", "TeleportPoints")
	local point = points:FindFirstChild("RaceBrowserTeleportPoint")
	if not point then
		point = Instance.new("Part")
		point.Name = "RaceBrowserTeleportPoint"
		point.Anchored = true
		point.CanCollide = false
		point.CanTouch = false
		point.CanQuery = true
		point.Transparency = 0.45
		point.Color = Color3.fromRGB(70, 255, 190)
		point.Material = Enum.Material.Neon
		point.Size = Vector3.new(8, 1, 8)
		point.Parent = points

		local startZones = route:FindFirstChild("StartZones")
		local source = startZones and (startZones:FindFirstChild("TimeTrialStartZone") or startZones:FindFirstChild("RaceStartZone") or startZones:FindFirstChildWhichIsA("BasePart"))
		if source and source:IsA("BasePart") then
			point.CFrame = source.CFrame * CFrame.new(14, 2, 0)
		else
			point.CFrame = CFrame.new(0, 12, 0)
		end
		point:SetAttribute("NTR_RaceBrowserTeleportPoint", true)
		point:SetAttribute("EditMe", "Move this part to where players should arrive from the Race browser.")
	end
	return point
end

local function patchBrowserClient()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local browser = playerScripts
		:WaitForChild("NeoTokyoRacersClient")
		:WaitForChild("Controllers")
		:WaitForChild("Racing")
		:WaitForChild("RaceBrowserClient_Active")
	if not browser:IsA("LocalScript") then
		error("[NTR Racing Phase 7B] RaceBrowserClient_Active is not a LocalScript")
	end
	local source = browser.Source
	if string.find(source, "NTR_RACING_PHASE7B_TELEPORT_CLIENT", 1, true) then
		if string.find(source, "NTR_RACING_PHASE7B_CLOSE_ON_TELEPORT", 1, true) then
			return
		end
		source = replaceOnce(source,
			[[local teleportBusy = false]],
			[[local teleportBusy = false
local setOpen = nil -- NTR_RACING_PHASE7B_CLOSE_ON_TELEPORT]],
			"teleport close forward declaration")
		source = replaceOnce(source,
			[[	fireFreeRoamVehicleExited()
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."]],
			[[	fireFreeRoamVehicleExited()
	if setOpen then
		setOpen(false)
	end
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."]],
			"close browser after teleport success")
		source = replaceOnce(source,
			[[local function setOpen(open)]],
			[[setOpen = function(open)]],
			"setOpen forward assignment")
		browser.Source = source
		return
	end
	source = replaceOnce(source,
		[[local openEvent = uiFolder:WaitForChild("OpenRaceBrowser")]],
		[[local openEvent = uiFolder:WaitForChild("OpenRaceBrowser")
local raceBrowserTeleportInvoke = shared:WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceBrowserTeleportInvoke")
-- NTR_RACING_PHASE7B_TELEPORT_CLIENT]],
		"teleport remote declaration")
	source = replaceOnce(source,
		[[local waypoint = nil
local waypointBillboard = nil
local waypointTarget = nil
local waypointTicker = 0]],
		[[local teleportBusy = false
local setOpen = nil -- NTR_RACING_PHASE7B_CLOSE_ON_TELEPORT]],
		"remove waypoint state")
	source = replaceOnce(source,
		[[local function clearWaypoint()
	if waypoint then waypoint:Destroy() end
	waypoint = nil
	waypointBillboard = nil
	waypointTarget = nil
end

local function setWaypoint(part, summary)
	clearWaypoint()
	if not part then
		subtitle.Text = "No start zone was found for this event."
		return
	end
	local rootFolder = Workspace:FindFirstChild("_NTR_ClientOnly")
	if not rootFolder then
		rootFolder = Instance.new("Folder")
		rootFolder.Name = "_NTR_ClientOnly"
		rootFolder.Parent = Workspace
	end

	local marker = Instance.new("Part")
	marker.Name = "RaceBrowserWaypoint"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = part.CFrame + Vector3.new(0, readNumber(browserConfig, "WaypointHeight", 14), 0)
	marker.Parent = rootFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RaceBrowserWaypointGui"
	billboard.Adornee = marker
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(readNumber(browserConfig, "WaypointWidth", 220), readNumber(browserConfig, "WaypointHeightPixels", 58))
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Parent = marker

	local t = theme()
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	pill.BackgroundTransparency = readNumber(browserConfig, "WaypointBackgroundTransparency", 0.28)
	pill.BorderSizePixel = 0
	pill.Size = UDim2.fromScale(1, 1)
	pill.Parent = billboard
	corner(pill, 8)
	stroke(pill, t.Selected, 1.5, 0.15)

	local text = label(pill, tostring(summary.DisplayName or "RACE START") .. "\nENTER ZONE + PRESS E", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 10 or 12, t.Accent, true)
	text.Name = "Text"
	text.TextXAlignment = Enum.TextXAlignment.Center

	waypoint = marker
	waypointBillboard = billboard
	waypointTarget = part
	subtitle.Text = "Waypoint set. Drive to the start zone and press E / tap the prompt to open the entry menu."
end]],
		[[local function fireFreeRoamVehicleExited()
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end

local function teleportToStart(row)
	if teleportBusy then
		return
	end
	if not row then
		subtitle.Text = "Select an event first."
		return
	end
	teleportBusy = true
	subtitle.Text = "Teleporting and clearing your current vehicle..."
	local ok, result = pcall(function()
		return raceBrowserTeleportInvoke:InvokeServer("TeleportToRaceStart", {
			EventId = row.Summary.EventId,
			Mode = row.Summary.Mode,
		})
	end)
	teleportBusy = false
	if not ok or typeof(result) ~= "table" or (result.Ok ~= true and result.Success ~= true) then
		subtitle.Text = (typeof(result) == "table" and tostring(result.Message or result.Error)) or "Teleport failed."
		return
	end
	fireFreeRoamVehicleExited()
	if setOpen then
		setOpen(false)
	end
	subtitle.Text = "Teleported. Enter the start zone and press E / tap to open the entry menu."
end]],
		"replace waypoint helpers with teleport helper")
	source = replaceOnce(source,
		[[local function setOpen(open)]],
		[[setOpen = function(open)]],
		"setOpen forward assignment")
	source = replaceOnce(source,
		[[	local track = button(detail, "TrackStart", "TRACK START", t.Buy)
	track.Position = UDim2.new(0, 10, 1, -50)
	track.Size = UDim2.new(0.55, -15, 0, 40)
	track.MouseButton1Click:Connect(function()
		setWaypoint(row.StartZone, summary)
	end)

	local clearButton = button(detail, "ClearWaypoint", "CLEAR", t.Back)
	clearButton.Position = UDim2.new(0.55, 5, 1, -50)
	clearButton.Size = UDim2.new(0.45, -15, 0, 40)
	clearButton.MouseButton1Click:Connect(function()
		clearWaypoint()
		subtitle.Text = "Waypoint cleared."
	end)]],
		[[	local track = button(detail, "TrackStart", "TELEPORT TO START", t.Buy)
	track.Position = UDim2.new(0, 10, 1, -50)
	track.Size = UDim2.new(1, -20, 0, 40)
	track.MouseButton1Click:Connect(function()
		teleportToStart(row)
	end)]],
		"track start button")
	source = replaceOnce(source,
		[[		subtitle.Text = "Browse events, set a waypoint, then enter the start zone to open the race entry menu."]],
		[[		subtitle.Text = "Browse events, teleport near the start, then enter the zone to open the race entry menu."]],
		"open subtitle")
	source = replaceOnce(source,
		[[RunService.Heartbeat:Connect(function(dt)
	waypointTicker += dt
	if waypointTicker < 0.25 then return end
	waypointTicker = 0
	if waypoint and waypoint.Parent and waypointTarget and waypointTarget.Parent then
		waypoint.CFrame = waypointTarget.CFrame + Vector3.new(0, readNumber(browserConfig, "WaypointHeight", 14), 0)
		local pill = waypointBillboard and waypointBillboard:FindFirstChild("Pill")
		local text = pill and pill:FindFirstChild("Text")
		if text and text:IsA("TextLabel") then
			text.Text = "RACE START\n" .. formatDistance(distanceTo(waypointTarget))
		end
	end
end)

ensureGui()]],
		[[ensureGui()]],
		"remove waypoint heartbeat")
	browser.Source = source
end

local function install()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local shared = kit:WaitForChild("Shared")
	local remotes = child(shared, "Folder", "Remotes")
	local racingRemotes = child(remotes, "Folder", "Racing")
	child(racingRemotes, "RemoteFunction", "RaceBrowserTeleportInvoke")

	local racingConfig = child(kit:WaitForChild("Config"), "Folder", "Racing")
	local browserTeleport = child(racingConfig, "Folder", "BrowserTeleport")
	setValue(browserTeleport, "NumberValue", "TeleportCooldownSeconds", 1.25)
	setValue(browserTeleport, "NumberValue", "TeleportHeightOffset", 4)
	setValue(browserTeleport, "NumberValue", "TeleportForwardOffset", 0)
	setValue(browserTeleport, "NumberValue", "UnseatSettleSeconds", 0.08)
	setValue(browserTeleport, "NumberValue", "VehicleDespawnDelaySeconds", 0.14)
	setValue(browserTeleport, "NumberValue", "CharacterUnfreezeDelaySeconds", 0.18)

	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local routes = world:WaitForChild("RaceRoutes")
	for _, route in ipairs(routes:GetChildren()) do
		if route:IsA("Folder") or route:IsA("Model") then
			ensureTeleportPoint(route)
		end
	end

	local services = child(ServerScriptService, "Folder", "NeoTokyoRacers")
	services = child(services, "Folder", "Services")
	local racingServices = child(services, "Folder", "Racing")
	local service = child(racingServices, "Script", "RaceBrowserTeleportService_Active")
	service.Source = serviceSource()
	service.Disabled = false

	patchBrowserClient()

	print("[NTR Racing Phase 7B] Installed race browser teleport service and client patch.")
	print("[NTR Racing Phase 7B] Move each route's TeleportPoints.RaceBrowserTeleportPoint to tune arrival location.")
	print("[NTR Racing Phase 7B] Reward config untouched.")
end

local function smoke()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local invoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing"):FindFirstChild("RaceBrowserTeleportInvoke")
	assert(invoke and invoke:IsA("RemoteFunction"), "RaceBrowserTeleportInvoke missing")
	local service = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):FindFirstChild("RaceBrowserTeleportService_Active")
	assert(service and service:IsA("Script") and service.Disabled == false, "RaceBrowserTeleportService_Active missing/disabled")
	local browser = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing"):FindFirstChild("RaceBrowserClient_Active")
	assert(browser and string.find(browser.Source, "NTR_RACING_PHASE7B_TELEPORT_CLIENT", 1, true), "RaceBrowser client teleport patch missing")
	assert(string.find(browser.Source, "NTR_RACING_PHASE7B_CLOSE_ON_TELEPORT", 1, true), "RaceBrowser close-on-teleport patch missing")
	local routes = Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("RaceRoutes")
	local pointCount = 0
	for _, route in ipairs(routes:GetChildren()) do
		local points = route:FindFirstChild("TeleportPoints")
		local point = points and points:FindFirstChild("RaceBrowserTeleportPoint")
		if point and point:IsA("BasePart") then
			pointCount += 1
		end
	end
	assert(pointCount > 0, "No route teleport points found")
	local rewards = kit:WaitForChild("Config"):WaitForChild("Racing"):FindFirstChild("Rewards")
	assert(rewards == nil or (rewards:FindFirstChild("TimeTrial") and rewards:FindFirstChild("Race")), "Rewards folder shape looks unexpected")
	print("[NTR Racing Phase 7B] Smoke passed. Teleport points found: " .. tostring(pointCount))
end

if MODE == "INSTALL" then
	install()
	smoke()
elseif MODE == "SMOKE" then
	smoke()
else
	error("Unknown MODE: " .. tostring(MODE))
end
