-- Owns the Pulse full map entry: the FullMap layers, the map input (M, Escape, ButtonSelect, pointer, pad), the frame step and, while open, RouteGuide.Update; not the free-roam HUD, the minimap or any Classic map owner.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.WorldMap.FullMapClient. Requires: Layers, Input, Perf, Presence, Routes, Map.MapCanvas, WorldMap.FullMapModel, WorldMap.FullMapView, Core.ConnectionScope, UI.RouteGuide, UI.MapMarkers, UI.MapMath, UI.FreeRoamMapPlayerMarkers, Vehicles.GameplayInputGate (all resolved inside start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local SURFACE = "FullMap"
local LAYER_NAME = "FullMap"
local HUD_ENTRY = "DesktopFreeRoamHudUI"

local Client = {}
local state
local api -- set once started

-- The API other code calls (FullMapUI 20-23). The HUD reaches it through Routes.Resolve("FullMapUI").
function Client.Open(): boolean
	return api ~= nil and api.open() or false
end
function Client.Close()
	if api then
		api.close()
	end
end
function Client.Toggle(): boolean
	return api ~= nil and api.toggle() or false
end
function Client.IsOpen(): boolean
	return api ~= nil and api.isOpen() or false
end

-- Pure rules, exported for the tests. ---------------------------------------------------------------------------
-- Key pan direction (FullMapUI 777-781). isDown(keyCode) -> boolean.
function Client._moveVector(isDown): (number, number)
	local x, y = 0, 0
	if isDown(Enum.KeyCode.A) or isDown(Enum.KeyCode.Left) then
		x -= 1
	end
	if isDown(Enum.KeyCode.D) or isDown(Enum.KeyCode.Right) then
		x += 1
	end
	if isDown(Enum.KeyCode.W) or isDown(Enum.KeyCode.Up) then
		y -= 1
	end
	if isDown(Enum.KeyCode.S) or isDown(Enum.KeyCode.Down) then
		y += 1
	end
	return x, y
end

-- FullMapUI 726.
function Client._isGamepad(kindName: any): boolean
	return type(kindName) == "string" and string.find(kindName, "Gamepad", 1, true) ~= nil
end

-- What a key does while the map is open (FullMapUI 681-691): "ZoomIn" | "ZoomOut" | "Centre" | "ShowAll" | "Clear" | nil.
function Client._keyCommand(code: Enum.KeyCode): string?
	if code == Enum.KeyCode.E or code == Enum.KeyCode.Equals or code == Enum.KeyCode.KeypadPlus then
		return "ZoomIn"
	elseif code == Enum.KeyCode.Q or code == Enum.KeyCode.Minus or code == Enum.KeyCode.KeypadMinus then
		return "ZoomOut"
	elseif code == Enum.KeyCode.C then
		return "Centre"
	elseif code == Enum.KeyCode.F then
		return "ShowAll"
	elseif code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
		return "Clear"
	end
	return nil
end

-- What a pad button does while the map is open (FullMapUI 703-715).
function Client._padCommand(code: Enum.KeyCode): string?
	if code == Enum.KeyCode.ButtonA then
		return "Tap"
	elseif code == Enum.KeyCode.ButtonB then
		return "Close"
	elseif code == Enum.KeyCode.ButtonX then
		return "Clear"
	elseif code == Enum.KeyCode.ButtonY then
		return "Centre"
	elseif code == Enum.KeyCode.ButtonL1 then
		return "ZoomOut"
	elseif code == Enum.KeyCode.ButtonR1 then
		return "ZoomIn"
	end
	return nil
end

-- True when a map-view point (screen pixels from the top-left corner) is on the Roblox top-left buttons: the map
-- covers the whole screen, so a tap on the Roblox menu or chat button would otherwise also set a waypoint.
-- barHeight and keepOutX are the Metrics TopBarHeight and TopBarKeepOut.X.
function Client._inTopBar(point: Vector2, barHeight: number, keepOutX: number): boolean
	return point.Y < barHeight and point.X < keepOutX
end

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.FullMapClient] " .. message)
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim first.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The waits the Classic owner makes (FullMapUI 29-48); none is on a font, an asset or a remote reply.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local modules = ReplicatedStorage:WaitForChild("Modules")
	local uiModules = modules:WaitForChild("Game"):WaitForChild("UI")
	local RouteGuide = require(uiModules:WaitForChild("RouteGuide"))
	local MapMarkers = require(uiModules:WaitForChild("MapMarkers"))
	local MapMath = require(uiModules:WaitForChild("MapMath"))
	uiModules:WaitForChild("MapTileSet")
	local PlayerMarkers = require(uiModules:WaitForChild("FreeRoamMapPlayerMarkers"))
	local InputGate = require(modules.Game:WaitForChild("Vehicles"):WaitForChild("GameplayInputGate"))
	local uiConfig = ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI")
	local hudConfig = uiConfig:WaitForChild("DesktopFreeRoamHud")
	local layoutConfig = hudConfig:WaitForChild("Layout")
	hudConfig:WaitForChild("Defaults")
	local markerConfig = uiConfig:WaitForChild("FreeRoamMapPlayerMarkers")
	local config = uiConfig:WaitForChild("FullMap", 10) -- optional: every tunable has a default
	local uiFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")

	local Input = require(kit.Input)
	local Perf = require(kit.Perf)
	local Presence = require(kit.Presence)
	local Routes = require(pulse.Routes)
	local MapCanvas = require(pulse.Map.MapCanvas)
	local Model = require(script.Parent.FullMapModel)
	local View = require(script.Parent.FullMapView)
	local ConnectionScope = require(modules:WaitForChild("Core"):WaitForChild("ConnectionScope"))
	local scope = ConnectionScope.new()

	-- 3. Layers. The map surface is drawn in FullMapScrim, the static chrome in FullMap; FullMapLive is the root
	-- the frame step is bound to. All hidden until the first open.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Menu", Scrim = true })
	local live = Layers.Create(LAYER_NAME, { Frame = "Menu", Live = true })

	-- FullMapUI 243-257.
	local function subject()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local current = seat
		while current and current ~= Workspace do
			if current:IsA("Model") and tonumber(current:GetAttribute("OwnerUserId")) == player.UserId then
				local root = current.PrimaryPart or current:FindFirstChild("CockpitRoot_DoNotRename", true)
				if root and root:IsA("BasePart") then
					return root, current
				end
			end
			current = current.Parent
		end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root and root:IsA("BasePart") and root or nil, nil
	end

	-- 4. Model, view.
	local model = Model.new({
		Player = player,
		PlayerGui = playerGui,
		RouteGuide = RouteGuide,
		MapMarkers = MapMarkers,
		MapMath = MapMath,
		InputGate = InputGate,
		Presence = Presence,
		Calibration = MapCanvas.Calibration,
		Config = function(name)
			return config and config:GetAttribute(name)
		end,
		Subject = subject,
		PlayerCount = function()
			return #Players:GetPlayers()
		end,
		IsCompact = function()
			return layer.Metrics.Class == "Compact"
		end,
		Delay = task.delay,
		RotationOffset = MapMath.Finite(MapCanvas._readValue(layoutConfig, "MapRotationOffsetDegrees", 0), 0),
	})
	local view = View.Mount(layer, model, scope, {
		PlayerMarkers = PlayerMarkers,
		MarkerConfig = markerConfig:IsA("Folder") and markerConfig or nil,
	})
	layer.SetVisible(false)
	live.SetVisible(false)

	-- The HUD owner answers "is the minimap showing" (replaces the PlayerGui walk of FullMapUI 464-478). Resolved
	-- once, off the start thread: Resolve may yield and a context-action handler must not.
	local hud
	scope:task(function()
		local ok, result = pcall(Routes.Resolve, HUD_ENTRY)
		if ok and type(result) == "table" then
			hud = result
		else
			warnOnce("the HUD entry did not resolve; the map opens by click only: " .. tostring(result))
		end
	end)
	local function minimapShowing(): boolean
		local check = hud and hud.IsMinimapShowing
		if type(check) ~= "function" then
			return false
		end
		local ok, showing = pcall(check)
		return ok and showing == true
	end
	local function toggle(): boolean
		return model:Toggle(minimapShowing())
	end

	local function command(name, anchor)
		if name == "ZoomIn" then
			model:ZoomStep(1, anchor)
		elseif name == "ZoomOut" then
			model:ZoomStep(-1, anchor)
		elseif name == "Centre" then
			model:CentreOnPlayer()
		elseif name == "ShowAll" then
			model:ShowAll()
		elseif name == "Clear" then
			model:ClearWaypoint()
		elseif name == "Close" then
			model:Close()
		elseif name == "Tap" then
			local centre = model.View.Centre
			model:Tap(centre, view.HitTest(centre))
		end
	end

	-- 5. Open and close: layers, the pad action (bound only while open), the vehicle race watch.
	local openScope
	local function padAction(_, inputState, input)
		if not model:IsOpen() then
			return Enum.ContextActionResult.Pass
		end
		local code = input.KeyCode
		if code == Enum.KeyCode.Thumbstick1 then
			if inputState == Enum.UserInputState.End then
				model:SetStick(0, 0)
			else
				model:SetStick(input.Position.X, input.Position.Y)
			end
			return Enum.ContextActionResult.Sink
		end
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		command(Client._padCommand(code))
		return Enum.ContextActionResult.Sink
	end
	local function closeIfBlocked()
		model:CloseIfBlocked()
	end
	-- The open map is driven by the pad action (A sets a waypoint at the crosshair), not by GUI selection. A
	-- selection left on the HUD, or one Roblox makes on ButtonSelect, would take ButtonA and the stick, so it is
	-- cleared while the map is open and put back on close. A layer drawn above the map keeps its focus.
	local savedFocus
	local function clearFocus()
		local current = GuiService.SelectedObject
		if not current then
			return
		end
		local gui = current:FindFirstAncestorWhichIsA("ScreenGui")
		if gui and gui.DisplayOrder > layer.Gui.DisplayOrder then
			return
		end
		GuiService.SelectedObject = nil
	end
	scope:connect(model.Changed, function(reason)
		if reason == "Open" then
			if openScope then
				openScope:destroy()
			end
			openScope = ConnectionScope.new()
			local vehicle = model.SubjectVehicle
			if vehicle then
				openScope:connect(vehicle:GetAttributeChangedSignal("RaceParticipant"), closeIfBlocked)
				openScope:connect(vehicle:GetAttributeChangedSignal("RaceRunId"), closeIfBlocked)
			end
			Input.BindAction(openScope, "FullMapPad", padAction, Enum.ContextActionPriority.High.Value + 50,
				Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY,
				Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.Thumbstick1)
			savedFocus = GuiService.SelectedObject
			clearFocus()
			openScope:connect(GuiService:GetPropertyChangedSignal("SelectedObject"), clearFocus)
			layer.SetVisible(true)
			live.SetVisible(true)
		elseif reason == "Close" then
			if openScope then
				openScope:destroy()
				openScope = nil
			end
			live.SetVisible(false)
			layer.SetVisible(false)
			local back = savedFocus
			savedFocus = nil
			if back and back:IsDescendantOf(game) and GuiService.SelectedObject == nil then
				GuiService.SelectedObject = back
			end
		end
	end)
	scope:add(function()
		if openScope then
			openScope:destroy()
			openScope = nil
		end
	end)

	-- 6. What closes the map (FullMapUI 449-461 polled each frame; these are the same facts as signals).
	for _, name in Model.Blocking do
		scope:connect(player:GetAttributeChangedSignal(name), closeIfBlocked)
	end
	scope:connect(playerGui:GetAttributeChangedSignal("OwnedGarageManagementOpen"), closeIfBlocked)
	scope:connect(GuiService.MenuOpened, function()
		model:Close()
	end)
	local presentation = uiFolder:FindFirstChild("FreeRoamHudPresentationMode")
	if presentation and presentation:IsA("BindableEvent") then
		scope:connect(presentation.Event, function(payload)
			model:SetPresentation(payload)
		end)
	end

	-- 7. Waypoint reconcile and legend (FullMapUI 278-293, 353-357).
	scope:connect(RouteGuide.Changed, function(active)
		model:OnRouteChanged(active)
	end)
	scope:connect(RouteGuide.Arrived, function(destination)
		model:OnArrived(destination)
	end)
	scope:connect(MapMarkers.Changed, function()
		model:MarkLegendDirty()
	end)
	scope:connect(Players.PlayerAdded, function()
		model:MarkLegendDirty()
	end)
	scope:connect(Players.PlayerRemoving, function()
		model:MarkLegendDirty()
	end)

	-- 8. The subject is cached for the step and refreshed on the events that change it.
	local seatConnection
	local function watchCharacter(character)
		if seatConnection then
			seatConnection:Disconnect()
			seatConnection = nil
		end
		if not character then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		if player.Character ~= character then
			return
		end
		if humanoid then
			seatConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
				model:RefreshSubject()
			end)
		end
		model:RefreshSubject()
	end
	scope:connect(player.CharacterAdded, watchCharacter)
	scope:add(function()
		if seatConnection then
			seatConnection:Disconnect()
			seatConnection = nil
		end
	end)
	scope:task(watchCharacter, player.Character)

	-- 9. Pointer input (FullMapUI 612-665). Read from UserInputService; a press over a chrome block is not the map's.
	local function pointerBegan(input)
		if not model:IsOpen() then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if view.OverChrome(input.Position) then
			return
		end
		local point = view.ToLocal(input.Position)
		if not model:InsideView(point) then
			return
		end
		local metrics = layer.Metrics
		if Client._inTopBar(point, metrics.TopBarHeight, metrics.TopBarKeepOut.X) then
			return
		end
		model:PointerBegan(kind == Enum.UserInputType.Touch and input or "Mouse", point)
	end
	scope:connect(UserInputService.InputChanged, function(input)
		if not model:IsOpen() then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseWheel then
			local point = view.ToLocal(input.Position)
			if model:InsideView(point) and not view.OverChrome(input.Position) then
				model:ZoomStep(input.Position.Z > 0 and 1 or -1, point)
			end
		elseif kind == Enum.UserInputType.MouseMovement then
			model:PointerMoved("Mouse", view.ToLocal(input.Position))
		elseif kind == Enum.UserInputType.Touch then
			model:PointerMoved(input, view.ToLocal(input.Position))
		elseif kind == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
			model:SetStick(input.Position.X, input.Position.Y)
		end
	end)
	scope:connect(UserInputService.InputEnded, function(input)
		local key = input.UserInputType == Enum.UserInputType.Touch and input
			or (input.UserInputType == Enum.UserInputType.MouseButton1 and "Mouse" or nil)
		if not key then
			return
		end
		local tap = model:PointerEnded(key)
		if tap then
			model:Tap(tap, view.HitTest(tap))
		end
	end)

	-- 10. Keyboard (FullMapUI 668-692): Escape always closes; M toggles; the rest only while open.
	scope:connect(UserInputService.InputBegan, function(input, processed)
		pointerBegan(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			model:Close()
			return
		end
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			toggle()
			return
		end
		if model:IsOpen() then
			command(Client._keyCommand(input.KeyCode))
		end
	end)

	-- 11. ButtonSelect (FullMapUI 718-723): the Classic action name, permanent.
	Input.BindAction(scope, "FullMapToggle", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if model:IsOpen() then
			model:Close()
			return Enum.ContextActionResult.Sink
		end
		if toggle() then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonSelect)

	local function updateInputKind(kind)
		model:SetUsingGamepad(Client._isGamepad(kind and kind.Name))
	end
	scope:connect(UserInputService.LastInputTypeChanged, updateInputKind)
	updateInputKind(UserInputService:GetLastInputType())

	-- 12. The one frame step. It runs only while FullMapLive's root shows. While the map is open it is the one
	-- caller of RouteGuide.Update (API2 5.3: the HUD does not call it while FullMapOpen).
	local mapView = {}
	local getRouteState = type(RouteGuide.GetRouteState) == "function" and RouteGuide.GetRouteState or nil
	if not getRouteState then
		warnOnce("RouteGuide.GetRouteState is missing; the full map draws no route line")
	end
	local function isDown(code)
		return UserInputService:IsKeyDown(code)
	end
	local binding = Perf.Bind("FullMap", live.Root, function(dt)
		if not model:IsOpen() then
			return
		end
		local moveX, moveY = 0, 0
		if not UserInputService:GetFocusedTextBox() then
			moveX, moveY = Client._moveVector(isDown)
		end
		model:Step(dt, moveX, moveY)
		model:FillView(mapView)
		local root = model.SubjectRoot
		if root and root.Parent ~= nil then
			RouteGuide.Update(root.Position)
		end
		view.Step(mapView, getRouteState and getRouteState() or nil)
	end)
	scope:add(binding)

	Client.Controller = { Model = model, View = view, Layer = layer, Live = live, Scope = scope }
	api = {
		open = function()
			return model:Open()
		end,
		close = function()
			model:Close()
		end,
		toggle = toggle,
		isOpen = function()
			return model:IsOpen()
		end,
	}
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
