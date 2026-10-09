-- Owns the Pulse in-race HUD entry: claims the surface, creates SharedInRaceHUD and SharedInRaceHUDLive, wires RaceEvent to the model; not the countdown, queue, results or the gauge.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.RaceHudClient. Requires: Layers, RaceHudModel, RaceHudView, Core.ConnectionScope (resolved inside start).
--
-- Classic line references: S = ReplicatedStorage.Modules.Game.Racing.RaceSessionPresentationClient.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LAYER_NAME = "SharedInRaceHUD"
local SURFACE = "RaceHud"

local Client = {}
local state

-- S36-40.
local function mapValue(folder, name, className, fallback)
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA(className) then
		return item.Value
	end
	return fallback
end

-- S29: a config value that is an id, a content string or empty.
function Client._asset(value)
	value = tostring(value or "")
	if value == "" then
		return ""
	end
	local prefix = "rbxassetid://" -- the content prefix, not an id (S29); lint exception requested in NOTES.md
	if string.find(value, prefix, 1, true) then
		return value
	end
	local id = string.match(value, "%d+")
	return id and prefix .. id or value
end

local function racingConfig()
	local config = ReplicatedStorage:FindFirstChild("Config")
	return config and config:FindFirstChild("Racing") or nil
end

-- S30.
local function eventFolder(mode, eventId)
	local racing = racingConfig()
	local catalog = racing and racing:FindFirstChild(mode == "Race" and "RaceCatalog" or "TimeTrialCatalog")
	if not catalog then
		return nil
	end
	local direct = catalog:FindFirstChild(tostring(eventId or ""))
	if direct then
		return direct
	end
	for _, candidate in ipairs(catalog:GetChildren()) do
		if tostring(candidate:GetAttribute("EventId") or "") == tostring(eventId or "") then
			return candidate
		end
	end
	return nil
end

-- S31.
local function eventMapImage(mode, eventId)
	local event = eventFolder(mode, eventId)
	if not event then
		return ""
	end
	local value = event:GetAttribute("RaceHudMapImage")
	local child = event:FindFirstChild("RaceHudMapImage")
	if (value == nil or value == "") and child and child:IsA("StringValue") then
		value = child.Value
	end
	return Client._asset(value)
end

-- S41-47.
local function routeIdFor(mode, eventId)
	local event = eventFolder(mode, eventId)
	local value = event and (event:GetAttribute("RouteId") or event:GetAttribute("RaceRouteId"))
	local child = event and (event:FindFirstChild("RouteId") or event:FindFirstChild("RaceRouteId"))
	if (value == nil or value == "") and child and child:IsA("StringValue") then
		value = child.Value
	end
	return tostring(value and value ~= "" and value or eventId or "")
end

-- S66-75.
local function mapAnchor(folder, routeId)
	if not folder then
		return nil
	end
	if mapValue(folder, "UseConfiguredWorldAnchor", "BoolValue", false) then
		return Vector3.new(mapValue(folder, "WorldAnchorX", "NumberValue", 0), 0, mapValue(folder, "WorldAnchorZ", "NumberValue", 0))
	end
	local world = Workspace:FindFirstChild("World")
	local routes = world and world:FindFirstChild("RaceRoutes")
	local route = routes and routes:FindFirstChild(routeId)
	local name = mapValue(folder, "AnchorPartName", "StringValue", "FinishLine")
	local part = route and route:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		return part.Position
	end
	return nil
end

-- S48-54 and S216-231: the raw values of one event's route map. The model applies the guards (PrepareMap).
function Client._mapConfig(mode, eventId)
	local racing = racingConfig()
	local catalog = racing and racing:FindFirstChild("HudMapCatalog")
	local routeId = routeIdFor(mode, eventId)
	local folder = catalog and catalog:FindFirstChild(routeId)
	local image = mapValue(folder, "Image", "StringValue", "")
	image = image ~= "" and Client._asset(image) or eventMapImage(mode, eventId)
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local racingUi = ui and ui:FindFirstChild("Racing")
	local inRace = racingUi and racingUi:FindFirstChild("InRace")
	return {
		Enabled = folder ~= nil and mapValue(folder, "Enabled", "BoolValue", false),
		Anchor = mapAnchor(folder, routeId),
		ImageWidth = mapValue(folder, "ImageWidthPixels", "NumberValue", nil),
		ImageHeight = mapValue(folder, "ImageHeightPixels", "NumberValue", nil),
		StudsPerPixel = mapValue(folder, "StudsPerPixel", "NumberValue", nil),
		RotationDegrees = mapValue(folder, "MapRotationDegrees", "NumberValue", nil),
		FlipX = mapValue(folder, "FlipX", "BoolValue", false),
		FlipY = mapValue(folder, "FlipY", "BoolValue", false),
		StartPixelX = mapValue(folder, "StartPixelX", "NumberValue", nil),
		StartPixelY = mapValue(folder, "StartPixelY", "NumberValue", nil),
		Clamp = mapValue(folder, "ClampMarkersToMap", "BoolValue", true),
		Smoothing = mapValue(folder, "Smoothing", "NumberValue", nil),
		MarkerRotationOffset = mapValue(folder, "MarkerRotationOffsetDegrees", "NumberValue", nil),
		PlayerMarkerScale = mapValue(folder, "PlayerMarkerScale", "NumberValue", nil),
		Image = image,
		Opacity = mapValue(inRace, "MapOpacity", "NumberValue", nil),
	}
end

-- S55-65.
function Client._subject(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("BasePart") then
		local vehicle = seat:FindFirstAncestorOfClass("Model")
		local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		if root and root:IsA("BasePart") then
			return root
		end
		return seat
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. Remotes and bindables, with the waits the Classic owner makes (S15-17, S161-163).
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local racingRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Racing")
	local raceEvent = racingRemotes:WaitForChild("RaceEvent")
	local raceRequest = racingRemotes:WaitForChild("RaceRequest")
	local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
	local runtime = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime")
	local transitionRequest = runtime:WaitForChild("Racing"):FindFirstChild("RaceTransitionRequest")
	local uiFolder = runtime:FindFirstChild("UI")
	local freeRoamMode = uiFolder and uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
	local bindables = {
		RaceTransitionRequest = transitionRequest and transitionRequest:IsA("BindableEvent") and transitionRequest or nil,
		FreeRoamHudPresentationMode = freeRoamMode and freeRoamMode:IsA("BindableEvent") and freeRoamMode or nil,
	}

	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 3. Layers: static and live (API2 5.5). Both start hidden; the view shows them with the session.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud" })
	local live = Layers.Create(LAYER_NAME, { Frame = "Hud", Live = true })
	layer.SetVisible(false)
	live.SetVisible(false)

	-- 4. Model and view.
	local Model = require(script.Parent.RaceHudModel)
	local View = require(script.Parent.RaceHudView)
	local model = Model.new({
		Remotes = { RaceRequest = raceRequest, RaceQueueRequest = queueRequest },
		Bindable = function(name)
			return bindables[name]
		end,
		UserId = player.UserId,
		MapConfig = Client._mapConfig,
		Subject = function()
			return Client._subject(player)
		end,
		Clock = os.clock,
		Spawn = task.spawn,
		Delay = task.delay,
		Wait = task.wait,
	})
	local view = View.Mount(layer, model, scope, { Live = live })
	scope:connect(model.Changed, function(reason)
		view.Render(reason)
	end)
	view.Render("start")

	-- 5. The marker subject follows the seat and the character by event (no timed lookup).
	local humanoidConnection = nil
	local function watchCharacter(character)
		if humanoidConnection then
			humanoidConnection:Disconnect()
			humanoidConnection = nil
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoidConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(model.RefreshSubject)
		end
		model.RefreshSubject()
	end
	scope:connect(player.CharacterAdded, function(character)
		watchCharacter(character)
		-- The Humanoid can arrive after the character; watch again once it is there.
		scope:connect(character.ChildAdded, function(child)
			if child:IsA("Humanoid") and player.Character == character then
				watchCharacter(character)
			end
		end)
	end)
	scope:add(function()
		if humanoidConnection then
			humanoidConnection:Disconnect()
			humanoidConnection = nil
		end
	end)
	watchCharacter(player.Character)

	-- 6. The one listener (S303).
	scope:connect(raceEvent.OnClientEvent, model.Handle)

	Client.Controller = { Gui = layer.Gui, LiveGui = live.Gui, Model = model, View = view }
end

function Client.start()
	if state then
		assert(state == "ready", "Client startup already attempted: " .. tostring(state))
		return
	end
	state = "starting"
	local ok, message = xpcall(run, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Client
