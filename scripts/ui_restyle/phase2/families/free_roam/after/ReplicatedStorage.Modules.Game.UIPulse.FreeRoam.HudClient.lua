-- Owns the Pulse free-roam HUD surface on every form factor: the DesktopFreeRoamHud layers, the HUD model and view, their listeners and the HUD frame step; not the touch drive controls, the activity HUD, the full map or any Classic HUD.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudClient. Requires: Kit.Layers, Kit.Overlay, Kit.Perf, Routes, FreeRoam.HudModel, FreeRoam.HudView, Core.ConnectionScope and the shared modules RouteGuide, GarageCatalogClient, MobileDriveInputState, GameplayInputGate, FreeRoamMapPlayerMarkers, Audio.RadioClient (all resolved inside start).
--
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SURFACE = "FreeRoamHud"
local LAYER_NAME = "DesktopFreeRoamHud"
local ROOT_NAME = "DesignRoot"

local Client = {}
local state
local model

-- For the map family (API2 5.4): true while the minimap is on screen. False before start.
function Client.IsMinimapShowing()
	return model ~= nil and model.IsMinimapShowing()
end

-- M41: a value child, then an attribute, then the fallback. Used once per name at start, never per frame.
function Client._read(folder, name, fallback)
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("ValueBase") then return value.Value end
	local attribute = folder and folder:GetAttribute(name)
	if attribute ~= nil then return attribute end
	return fallback
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The instances and shared modules Classic waits for (D21-44, D100, D986). No font, asset or remote reply.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local modules = ReplicatedStorage:WaitForChild("Modules")
	local gameModules = modules:WaitForChild("Game")
	local uiModules = gameModules:WaitForChild("UI")
	local vehicleModules = gameModules:WaitForChild("Vehicles")
	local RouteGuide = require(uiModules:WaitForChild("RouteGuide"))
	local Markers = require(uiModules:WaitForChild("FreeRoamMapPlayerMarkers"))
	local Catalog = require(gameModules:WaitForChild("Garage"):WaitForChild("GarageCatalogClient"))
	local DriveState = require(vehicleModules:WaitForChild("MobileDriveInputState"))
	local InputGate = require(vehicleModules:WaitForChild("GameplayInputGate"))
	local Scope = require(modules:WaitForChild("Core"):WaitForChild("ConnectionScope"))

	local configRoot = ReplicatedStorage:WaitForChild("Config")
	local configUi = configRoot:WaitForChild("UI")
	local hudConfig = configUi:WaitForChild("DesktopFreeRoamHud")
	local layoutConfig = hudConfig:WaitForChild("Layout")
	local defaultsConfig = hudConfig:WaitForChild("Defaults")
	local performanceConfig = configRoot:WaitForChild("Racing"):WaitForChild("PresentationPerformance")
	local markersConfig = configUi:WaitForChild("FreeRoamMapPlayerMarkers")
	local mobileConfig = configUi:FindFirstChild("MobileFreeRoamHud")

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local garageInvoke = remotes:WaitForChild("Garage"):WaitForChild("GarageInvoke")
	local teleportInvoke = remotes:WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
	local runtimeUi = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
	local loadingInvoke = runtimeUi:WaitForChild("LoadingTransitionInvoke")
	local notification = runtimeUi:WaitForChild("ShowTopNotification")
	local onboardingControls = runtimeUi:WaitForChild("OpenDrivingControlsFromOnboarding")
	local categoriesRoot = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VehiclePreviews"):WaitForChild("Categories")

	-- 3. The rest of the kit and the family. None of these requires yields.
	local Overlay = require(kit.Overlay)
	local Perf = require(kit.Perf)
	local Routes = require(pulse.Routes)
	local HudModel = require(script.Parent.HudModel)
	local HudView = require(script.Parent.HudView)
	local scope = Scope.new()
	local read = Client._read

	-- The radio (Audio.RadioClient) owns music playback; the HUD starts it and draws its strip. A radio fault never
	-- fails the HUD. The strip is drawn only when Config.Audio.Radio@ShowStrip is true (off: it was a test control).
	local radio = nil
	local radioModule = gameModules:WaitForChild("Audio"):FindFirstChild("RadioClient")
	if radioModule then
		local okRadio, result = pcall(function()
			return require(radioModule).Start()
		end)
		if not okRadio then
			warn("[Pulse.HudClient] radio failed to start: " .. tostring(result))
		elseif result.State().ShowStrip then
			radio = result
		end
	end

	-- 4. Config, read once (PC 5.1 rule 4). The two readers are Classic's own: _readValue is D121-124, read is M41.
	local modelConfig = {
		ProfileRefreshSeconds = tonumber(HudModel._readValue(layoutConfig, "ProfileRefreshSeconds", 2)) or 2, -- D350
		PauseFreeRoamMapDuringRace = HudModel._readValue(performanceConfig, "PauseFreeRoamMapDuringRace", true) == true, -- D1142
		DefaultControlMode = read(mobileConfig, "DefaultControlMode", "Arrows"), -- M200
	}
	local minimapLayout = {
		MapVisibleStuds = read(layoutConfig, "MapVisibleStuds", 2850),
		MapRotationOffsetDegrees = read(layoutConfig, "MapRotationOffsetDegrees", 0),
		MapSmoothing = read(layoutConfig, "MapSmoothing", 10),
		IconRotates = HudModel._readValue(defaultsConfig, "MapPlayerIconRotates", true) == true, -- D1223
		ZoomEnabled = read(layoutConfig, "MapSpeedZoomEnabled", true) ~= false,
		ZoomStartMph = read(layoutConfig, "MapSpeedZoomStartMph", 40),
		ZoomFullMph = read(layoutConfig, "MapSpeedZoomFullMph", 200),
		ZoomMaxFactor = read(layoutConfig, "MapSpeedZoomMaxFactor", 1.8),
		ZoomOutResponse = read(layoutConfig, "MapSpeedZoomOutResponse", 1.6),
		ZoomInResponse = read(layoutConfig, "MapSpeedZoomInResponse", 0.8),
	}
	local speedGaugeMaxMph = read(layoutConfig, "SpeedGaugeMaxMph", 260)
	local boostBarSmoothing = read(layoutConfig, "BoostBarSmoothing", 14)

	-- 5. Layers. One HUD on every device; MobileFreeRoamHud_Phase1 is never created.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud", RootName = ROOT_NAME })
	local live = Layers.Create(LAYER_NAME, { Frame = "Hud", Live = true, RootName = ROOT_NAME })

	-- 6. Model. The vehicles folder is looked up, never waited for; its listeners bind the first time it is found.
	local vehiclesBound = false
	local function ownedVehicles()
		local world = Workspace:FindFirstChild("World")
		local runtime = world and world:FindFirstChild("Runtime")
		local folder = runtime and runtime:FindFirstChild("PlayerVehicles")
		if not folder then return {} end
		if not vehiclesBound then
			vehiclesBound = true
			local function changed()
				task.defer(function()
					if model then model.VehiclesChanged() end
				end)
			end
			scope:connect(folder.ChildAdded, changed)
			scope:connect(folder.ChildRemoved, changed)
		end
		return folder:GetChildren()
	end
	model = HudModel.new({
		OwnedVehicles = ownedVehicles,
		Player = player,
		PlayerGui = playerGui,
		Remotes = { GarageInvoke = garageInvoke, TeleportInvoke = teleportInvoke },
		-- D608-609: the activities remote is looked up at the press and may be absent.
		FindActivityInvoke = function()
			local folder = remotes:FindFirstChild("Activities")
			return folder and folder:FindFirstChild("ActivityInvoke")
		end,
		Bindables = { Folder = runtimeUi, ShowTopNotification = notification, LoadingTransitionInvoke = loadingInvoke },
		Catalog = Catalog,
		CategoriesRoot = categoriesRoot,
		InputGate = InputGate,
		Confirm = function(options)
			Overlay.Confirm(layer.Root, options)
		end,
		-- D960-962 through Routes (PC 1.5 rule 7): the Classic map until the WorldMap family lands, then the Pulse one.
		OpenFullMap = function()
			local map = Routes.Resolve("FullMapUI")
			return type(map) == "table" and type(map.Open) == "function" and map.Open() and true or false
		end,
		Config = modelConfig,
		TouchEnabled = UserInputService.TouchEnabled,
		GyroscopeEnabled = UserInputService.GyroscopeEnabled,
	})

	-- 7. The map subject (D1143-1146), kept current by listeners so the frame step does no lookup.
	local subject = { Part = nil, VehiclePart = nil }
	local characterScope
	local function refreshSubject()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local _, vehicle = model.OwnedVehicleSeat()
		local vehiclePart = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)) or nil
		if vehiclePart and not vehiclePart:IsA("BasePart") then vehiclePart = nil end
		local part = vehiclePart or root
		if part and not part:IsA("BasePart") then part = nil end
		subject.VehiclePart = vehiclePart
		subject.Part = part
	end
	local function bindCharacter(character)
		if characterScope then characterScope:destroy() end
		characterScope = nil
		if character then
			local own = Scope.new()
			characterScope = own
			local function bindHumanoid(humanoid)
				own:connect(humanoid:GetPropertyChangedSignal("SeatPart"), refreshSubject)
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then bindHumanoid(humanoid) end
			own:connect(character.ChildAdded, function(child)
				if child:IsA("Humanoid") then bindHumanoid(child) end
				refreshSubject()
			end)
		end
		refreshSubject()
	end
	scope:add(function()
		if characterScope then characterScope:destroy() end
	end)
	scope:connect(player.CharacterAdded, bindCharacter)
	scope:connect(player.CharacterRemoving, function()
		bindCharacter(nil)
	end)
	bindCharacter(player.Character)

	-- 8. View and the one frame step. The view is rebuilt only when the class or arrangement changes (API2 6.2).
	local viewScope, view, binding
	local function mount()
		viewScope = Scope.new()
		view = HudView.Mount(layer, model, viewScope, {
			Live = live,
			Player = player,
			MinimapDeps = { Markers = Markers, MarkersConfig = markersConfig, RouteGuide = RouteGuide, Player = player, Layout = minimapLayout },
			DriveState = DriveState,
			Subject = subject,
			Radio = radio,
			SpeedGaugeMaxMph = speedGaugeMaxMph,
			BoostBarSmoothing = boostBarSmoothing,
		})
		view.Render("Mount")
		binding = Perf.Bind("FreeRoamHud", live.Root, view.Step)
	end
	local function unmount()
		if binding then binding.Disconnect() end
		binding = nil
		if view then view.Destroy() end
		view = nil
		if viewScope then viewScope:destroy() end
		viewScope = nil
	end
	scope:add(unmount)
	mount()

	-- 9. Listeners.
	scope:connect(model.Changed, function(reason)
		if reason == "Driving" then refreshSubject() end -- a streamed vehicle may have gained its root part
		if view then view.Render(reason) end
	end)
	scope:connect(layer.Metrics.Changed, function(change)
		if type(change) == "table" and change.Layout and view
			and (view.Class ~= layer.Metrics.Class or view.Arrangement ~= layer.Metrics.Arrangement) then
			unmount()
			mount()
		end
	end)
	for _, name in ipairs(HudModel.PlayerAttributes) do
		scope:connect(player:GetAttributeChangedSignal(name), function()
			model.AttributeChanged(name)
		end)
	end
	for _, name in ipairs(HudModel.PlayerGuiAttributes) do
		scope:connect(playerGui:GetAttributeChangedSignal(name), function()
			model.AttributeChanged(name)
		end)
	end
	-- D986-994.
	scope:connect(onboardingControls.Event, function(options)
		model.OpenControlsFromOnboarding(options)
	end)
	-- D1337-1348.
	local presentationEvent = runtimeUi:FindFirstChild("FreeRoamHudPresentationMode")
	if presentationEvent and presentationEvent:IsA("BindableEvent") then
		scope:connect(presentationEvent.Event, function(message)
			model.PresentationMessage(message)
		end)
	end
	-- D964.
	scope:connect(RouteGuide.Arrived, function(destination)
		model.Arrived(destination)
	end)

	-- 10. Draw the state the listeners may have missed between the model's creation and their connection.
	model.AttributeChanged("Start")

	Client.Controller = { Model = model, Layer = layer, LiveLayer = live, Scope = scope }
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
