-- Owns the Pulse onboarding surface: the Onboarding layer, the mark-based target finder, the HUD shortcut locks and the world guide trail; not the screens it points at, nor the saved progress (server).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingClient. Requires: Layers, Tokens, Input, Contracts, Presence, Shell.OnboardingModel, Shell.OnboardingView, Core.ConnectionScope, PresentationAudioBridge, OnboardingGuideTrailRenderer (all resolved inside start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SURFACE = "Onboarding"
local LAYER_NAME = "Onboarding"
local TRAIL_COLOUR_ATTRIBUTE = "TutorialGold"
-- After something changed, look again at these delays (seconds): a screen that opened may draw its marked parts a
-- moment later (fetch first, then draw). Bounded; nothing runs while the game is idle.
local SETTLE_SECONDS = { 0.15, 0.4, 1, 2, 4 }
local DESK_PATH = { "World", "Dealership", "Intro", "Desk", "GarageDeskTrigger" } -- Classic 660
local GARAGES_PATH = { "World", "Interiors", "OwnedGarageInstances" }
local VEHICLES_PATH = { "World", "Runtime", "PlayerVehicles" } -- Classic 673
local NUDGE_ATTRIBUTES = { -- player attributes Classic reads (465-478, 613, 662); a change means "look again"
	"GarageSessionActive", "GarageSessionMode", "RaceSessionActive", "MobileFreeRoamCarMenuOpen", "MobileMajorMenuOpen",
	"OwnedGarageInside", "OnboardingStage",
}
local GATE_ATTRIBUTES = { "StartScreenActive", "FirstDrivePresentationPending", "DrivingControlsOpen", "FullMapOpen" } -- 739-742

local Client = {}
local state

-- Classic 96-105, with PlayerGui passed in. Reads Enabled; never writes it.
function Client._visibleUnder(playerGui)
	return function(object)
		if not (typeof(object) == "Instance" and object:IsA("GuiObject") and object.AbsoluteSize.X > 1 and object.AbsoluteSize.Y > 1) then
			return false
		end
		local at = object
		while at and at ~= playerGui do
			if at:IsA("GuiObject") and not at.Visible then
				return false
			end
			if at:IsA("LayerCollector") and not at.Enabled then
				return false
			end
			at = at.Parent
		end
		return at == playerGui
	end
end

-- The guide trail renderer only ever calls config:GetAttribute (Phase 0 spike 15): this answers the Pulse colour for
-- the one colour attribute and Config.Player.Onboarding for the 30 geometry attributes.
function Client._trailConfig(config, colour)
	local overlay = {}
	function overlay:GetAttribute(name)
		if name == TRAIL_COLOUR_ATTRIBUTE then
			return colour
		end
		return config:GetAttribute(name)
	end
	return overlay
end

-- The target finder the model calls. Everything is read from the Kit.Input mark registry; nothing walks PlayerGui.
-- A page root is {Object = instance, Key = markKey}.
function Client._targets(Input, Contracts, visible)
	local Targets = {}

	-- A registered instance still carries the mark (a pooled tile or a shared page body may have been re-marked).
	local function matches(instance, key)
		local mark = Contracts.Marks[key]
		if not mark then
			return false
		end
		if mark.Name ~= nil and instance.Name ~= mark.Name then
			return false
		end
		if mark.Text ~= nil then
			local ok, text = pcall(function()
				return instance.Text
			end)
			if not ok or string.upper(tostring(text)) ~= string.upper(mark.Text) then
				return false
			end
		end
		if mark.Attributes ~= nil then
			for name, value in pairs(mark.Attributes) do
				if instance:GetAttribute(name) ~= value then
					return false
				end
			end
		end
		return true
	end

	local function shown(key)
		local result = {}
		for _, instance in ipairs(Input.Marked(key)) do
			if matches(instance, key) and visible(instance) then
				table.insert(result, instance)
			end
		end
		return result
	end

	local function layerOf(instance)
		local gui = instance:FindFirstAncestorWhichIsA("LayerCollector")
		if not gui then
			return nil
		end
		return gui:GetAttribute("PulseLayer") or gui.Name
	end

	-- Classic searched inside the page root. The static and live guis of one Pulse layer are siblings, so "inside"
	-- becomes "on the same layer"; when nothing is, every showing instance counts.
	local function near(list, root)
		local layer = root and layerOf(root.Object)
		if not layer then
			return list
		end
		local result = {}
		for _, instance in ipairs(list) do
			if layerOf(instance) == layer then
				table.insert(result, instance)
			end
		end
		return #result > 0 and result or list
	end

	local function firstPerKey(keys, root)
		local result = {}
		for _, key in ipairs(keys) do
			local first = near(shown(key), root)[1]
			if first then
				table.insert(result, first)
			end
		end
		return result
	end

	-- Classic 164-183.
	local function scrollerCards(spec, root)
		local scroller = near(shown(spec.Scroller), root)[1]
		if not scroller then
			return {}
		end
		local scrollerPosition, scrollerSize = scroller.AbsolutePosition, scroller.AbsoluteSize
		local result, fallback = {}, {}
		for _, key in ipairs(spec.Keys) do
			for _, object in ipairs(shown(key)) do
				if object:IsA("GuiButton") and object:IsDescendantOf(scroller) then
					local position, size = object.AbsolutePosition, object.AbsoluteSize
					local intersects = position.X + size.X > scrollerPosition.X and position.X < scrollerPosition.X + scrollerSize.X
						and position.Y + size.Y > scrollerPosition.Y and position.Y < scrollerPosition.Y + scrollerSize.Y
					if intersects then
						table.insert(fallback, object)
						local fullyVisible = position.X >= scrollerPosition.X - 1 and position.X + size.X <= scrollerPosition.X + scrollerSize.X + 1
							and position.Y >= scrollerPosition.Y - 1 and position.Y + size.Y <= scrollerPosition.Y + scrollerSize.Y + 1
						if fullyVisible then
							table.insert(result, object)
						end
					end
				end
			end
		end
		return #result > 0 and result or fallback
	end

	function Targets.Page(_pageId, spec)
		local first = nil
		for _, key in ipairs(spec.All or {}) do
			local list = shown(key)
			if #list == 0 then
				return nil
			end
			first = first or { Object = list[1], Key = key }
		end
		if spec.Any then
			for _, key in ipairs(spec.Any) do
				local list = shown(key)
				if #list > 0 then
					return first or { Object = list[1], Key = key }
				end
			end
			return nil
		end
		return first
	end

	function Targets.Alive(root)
		return type(root) == "table" and typeof(root.Object) == "Instance" and root.Object.Parent ~= nil
			and matches(root.Object, root.Key) and visible(root.Object)
	end

	function Targets.Card(_cardId, spec, root)
		local result = {}
		if spec.Kind == "Group" then
			result = firstPerKey(spec.Keys, root)
			if #result == 0 and spec.Fallback then
				result = firstPerKey(spec.Fallback, root)
			end
		elseif spec.Kind == "Cards" then
			for _, key in ipairs(spec.Keys) do
				for _, object in ipairs(near(shown(key), root)) do
					if object:IsA("GuiButton") then
						table.insert(result, object)
					end
				end
			end
		elseif spec.Kind == "ScrollerCards" then
			result = scrollerCards(spec, root)
		elseif spec.Kind == "Text" then
			for _, key in ipairs(spec.Keys) do
				local object = near(shown(key), root)[1]
				local button = object and (object:IsA("GuiButton") and object or object:FindFirstAncestorWhichIsA("GuiButton"))
				if button and visible(button) then
					table.insert(result, button)
				end
			end
		end
		return #result > 0 and result or nil
	end

	-- Classic 666-671 through the registry: only buttons that carry the mark, and only when the value differs.
	function Targets.ApplyLocks(locks)
		for key, unlocked in pairs(locks) do
			for _, object in ipairs(Input.Marked(key)) do
				if object:IsA("GuiButton") and matches(object, key) then
					if object.Active ~= unlocked then object.Active = unlocked end
					if object.Selectable ~= unlocked then object.Selectable = unlocked end
					if object.AutoButtonColor ~= unlocked then object.AutoButtonColor = unlocked end
				end
			end
		end
	end

	Targets._matches = matches
	Targets._shown = shown
	return Targets
end

-- Follows a fixed child path under root with ChildAdded and ChildRemoved on the nodes that exist. No polling.
-- onChanged(instance or nil) runs when the end of the path appears or goes. Returns a getter.
function Client._followPath(scope, root, names, onChanged)
	local connections = {}
	local current = nil
	local started = false
	local resolve
	local function clear()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	resolve = function()
		clear()
		local at = root
		local found = nil
		for index, name in ipairs(names) do
			local parent = at
			table.insert(connections, parent.ChildAdded:Connect(function(child)
				if child.Name == name then resolve() end
			end))
			table.insert(connections, parent.ChildRemoved:Connect(function(child)
				if child.Name == name then resolve() end
			end))
			local child = parent:FindFirstChild(name)
			if not child then
				break
			end
			at = child
			if index == #names then
				found = child
			end
		end
		if found ~= current or not started then
			started = true
			current = found
			onChanged(found)
		end
	end
	scope:add(clear)
	resolve()
	return function()
		return current
	end
end

local function waitPath(root, ...)
	local at = root
	for _, name in ipairs({ ... }) do
		at = at:WaitForChild(name)
	end
	return at
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The waits Classic makes (OnboardingClient 16-25, 319-320, 713), and no other. None is a font, asset or reply.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local config = waitPath(ReplicatedStorage, "Config", "Player", "Onboarding")
	local gameModules = waitPath(ReplicatedStorage, "Modules", "Game")
	local AudioBridge = require(waitPath(gameModules, "Audio", "PresentationAudioBridge"))
	local GuideTrail = require(waitPath(gameModules, "UI", "OnboardingGuideTrailRenderer"))
	local remotes = waitPath(ReplicatedStorage, "Remotes", "Onboarding")
	local invoke = remotes:WaitForChild("OnboardingInvoke")
	local stateChanged = remotes:WaitForChild("OnboardingStateChanged")
	local runtimeUi = waitPath(player, "PlayerScripts", "Runtime", "UI")
	local loadingState = runtimeUi:WaitForChild("LoadingPresentationState")
	local loadingChanged = runtimeUi:WaitForChild("LoadingPresentationChanged")
	local vehicleSpawned = runtimeUi:WaitForChild("FreeRoamVehicleSpawned")

	-- 3. The rest of the kit and the family. None of these requires yields.
	local Tokens = require(kit.Tokens)
	local Input = require(kit.Input)
	local Contracts = require(kit.Contracts)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.OnboardingModel)
	local View = require(script.Parent.OnboardingView)
	local core = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 4. Layer (hidden until the loading gate opens), model, view.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Bare", Scrim = true })
	layer.SetVisible(false)

	local visible = Client._visibleUnder(playerGui)
	local targets = Client._targets(Input, Contracts, visible)

	-- Classic 672-676, without the WaitForChild chains.
	local vehiclesFolder = Client._followPath(scope, Workspace, VEHICLES_PATH, function() end)
	local function activelyDriving()
		local vehicles = vehiclesFolder()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (vehicles and humanoid) then
			return nil
		end
		for _, vehicle in ipairs(vehicles:GetChildren()) do
			if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId
				and tonumber(vehicle:GetAttribute("DriverUserId")) == player.UserId then
				local seat = vehicle:FindFirstChild("DriverSeat", true)
				if seat and seat:IsA("VehicleSeat") and seat.Occupant == humanoid then
					return { RaceDriving = vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil }
				end
			end
		end
		return nil
	end

	local model = Model.new({
		Remotes = { OnboardingInvoke = invoke },
		Bindables = {
			OpenDrivingControls = function()
				local event = runtimeUi:FindFirstChild("OpenDrivingControlsFromOnboarding")
				return event and event:IsA("BindableEvent") and event or nil
			end,
		},
		Player = player,
		PlayerGui = playerGui,
		LoadingState = loadingState,
		Config = config,
		Presence = Presence,
		Audio = AudioBridge,
		Targets = targets,
		TouchEnabled = function()
			return UserInputService.TouchEnabled
		end,
		ActivelyDriving = activelyDriving,
		Clock = os.clock,
		Spawn = task.spawn,
		Defer = task.defer,
		Delay = task.delay,
		Wait = task.wait,
		Print = print,
		Warn = warn,
	})
	local view = View.Mount(layer, model, scope)

	-- 5. World guide trail: the shared renderer, unchanged, with the Pulse colour laid over its config.
	local trail = GuideTrail.new(Client._trailConfig(config, Tokens.Colour.Cyan))
	scope:add(function()
		trail:Destroy()
	end)

	local nudge
	local deskTrigger = Client._followPath(scope, Workspace, DESK_PATH, function()
		if nudge then nudge() end
	end)
	-- Management desks: one scoped listener on the owned-garage folder replaces the Workspace walk of Classic 646-656.
	local desks = {}
	local deskConnections = {}
	local function isDesk(object)
		return object.Name == "DeskPromptAnchor" and object:IsA("BasePart") and object:FindFirstAncestor("ManagementDesk") ~= nil
	end
	local function clearDesks()
		for _, connection in ipairs(deskConnections) do
			connection:Disconnect()
		end
		table.clear(deskConnections)
		table.clear(desks)
	end
	scope:add(clearDesks)
	Client._followPath(scope, Workspace, GARAGES_PATH, function(folder)
		clearDesks()
		if folder then
			for _, object in ipairs(folder:GetDescendants()) do
				if isDesk(object) then desks[object] = true end
			end
			table.insert(deskConnections, folder.DescendantAdded:Connect(function(object)
				if isDesk(object) then
					desks[object] = true
					if nudge then nudge() end
				end
			end))
			table.insert(deskConnections, folder.DescendantRemoving:Connect(function(object)
				desks[object] = nil
			end))
		end
		if nudge then nudge() end
	end)
	local function nearestDesk()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return nil
		end
		local best, bestDistance = nil, nil
		for desk in pairs(desks) do
			if desk.Parent then
				local distance = (desk.Position - rootPart.Position).Magnitude
				if not bestDistance or distance < bestDistance then
					best, bestDistance = desk, distance
				end
			end
		end
		return best
	end
	local function updateTrail()
		local kind = model:Trail()
		if kind == "Dealership" then
			trail:SetTarget(deskTrigger())
		elseif kind == "GarageDesk" then
			trail:SetTarget(nearestDesk())
		else
			trail:Clear()
		end
	end

	-- 6. Marked instances that decide a page or a lock are watched, so a screen showing or a tab changing is an event.
	local watchKeys = {}
	do
		local seen = {}
		local function add(key)
			if not seen[key] then
				seen[key] = true
				table.insert(watchKeys, key)
			end
		end
		for _, spec in pairs(Model.PageSignals) do
			for _, key in ipairs(spec.All or {}) do add(key) end
			for _, key in ipairs(spec.Any or {}) do add(key) end
		end
		for key in pairs(Model.LockPages) do add(key) end
	end
	local watchedSelf = {}
	local watchedVisible = {}
	local function forget(registry, instance)
		local list = registry[instance]
		if list then
			registry[instance] = nil
			for _, connection in ipairs(list) do
				connection:Disconnect()
			end
		end
	end
	local function watchMarks()
		for _, key in ipairs(watchKeys) do
			local mark = Contracts.Marks[key]
			for _, instance in ipairs(Input.Marked(key)) do
				if not watchedSelf[instance] then
					local list = {}
					watchedSelf[instance] = list
					table.insert(list, instance.AncestryChanged:Connect(function() nudge() end))
					for name in pairs(mark.Attributes or {}) do
						table.insert(list, instance:GetAttributeChangedSignal(name):Connect(function() nudge() end))
					end
					if mark.Text ~= nil then
						table.insert(list, instance:GetPropertyChangedSignal("Text"):Connect(function() nudge() end))
					end
					instance.Destroying:Once(function()
						forget(watchedSelf, instance)
					end)
				end
				local at = instance
				while at and at:IsA("GuiObject") do
					if not watchedVisible[at] then
						local watchedInstance = at
						watchedVisible[watchedInstance] = {
							watchedInstance:GetPropertyChangedSignal("Visible"):Connect(function() nudge() end),
						}
						watchedInstance.Destroying:Once(function()
							forget(watchedVisible, watchedInstance)
						end)
					end
					at = at.Parent
				end
			end
		end
	end
	scope:add(function()
		for instance in pairs(table.clone(watchedSelf)) do forget(watchedSelf, instance) end
		for instance in pairs(table.clone(watchedVisible)) do forget(watchedVisible, instance) end
	end)

	-- 7. One evaluation: locks, watches, the page poll, the cards and the trail. Classic did this five times a second.
	local function evaluate()
		targets.ApplyLocks(model:Locks())
		watchMarks()
		model:Poll()
		view.Render("Evaluate")
		updateTrail()
	end
	local queued = false
	local settleToken = 0
	nudge = function()
		settleToken += 1
		local token = settleToken
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				evaluate()
			end)
		end
		for _, seconds in ipairs(SETTLE_SECONDS) do
			task.delay(seconds, function()
				if token == settleToken and not model:Finished() then
					evaluate()
				end
			end)
		end
	end

	scope:connect(model.Changed, function(reason)
		view.Render(reason)
		if reason == "State" or reason == "PageEnded" or reason == "Gate" then
			nudge()
		end
	end)

	-- 8. Connections: the remote event, the bindables and attributes Classic listens to (713-744), and Presence.
	scope:connect(stateChanged.OnClientEvent, function(newState)
		model:Accept(newState)
	end)
	scope:connect(vehicleSpawned.Event, function()
		model:VehicleSpawned()
		nudge()
	end)
	local presentation = runtimeUi:FindFirstChild("FreeRoamHudPresentationMode")
	if presentation and presentation:IsA("BindableEvent") then
		scope:connect(presentation.Event, function(payload)
			model:PresentationMode(payload)
			nudge()
		end)
	end
	local function refreshGate()
		model:RefreshGate()
	end
	for _, name in ipairs(GATE_ATTRIBUTES) do
		scope:connect(player:GetAttributeChangedSignal(name), refreshGate)
	end
	scope:connect(loadingState:GetAttributeChangedSignal("Active"), refreshGate)
	scope:connect(loadingChanged.Event, refreshGate)
	for _, name in ipairs(NUDGE_ATTRIBUTES) do
		scope:connect(player:GetAttributeChangedSignal(name), function() nudge() end)
	end
	scope:connect(playerGui:GetAttributeChangedSignal("OwnedGarageManagementOpen"), function() nudge() end)
	scope:connect(Presence.Changed, function() nudge() end)
	-- A press that ended may have opened a screen or changed a tab.
	scope:connect(UserInputService.InputEnded, function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
			nudge()
		end
	end)
	-- Sitting in a parked vehicle starts the first-drive controls without a spawn signal (Classic 708).
	local seatedConnection = nil
	local function watchCharacter(character)
		if seatedConnection then
			seatedConnection:Disconnect()
			seatedConnection = nil
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			seatedConnection = humanoid.Seated:Connect(function() nudge() end)
		end
	end
	scope:add(function()
		if seatedConnection then seatedConnection:Disconnect() end
	end)
	scope:connect(player.CharacterAppearanceLoaded, watchCharacter)
	scope:connect(player.CharacterAdded, function(character)
		watchCharacter(character)
		nudge()
	end)
	watchCharacter(player.Character)

	Client.Controller = { Layer = layer, Model = model, View = view, Nudge = nudge, Scope = scope }

	-- 9. Saved progress (its own task: start never waits for the reply), then the loading gate.
	model:Start()
	model:RefreshGate()
	nudge()
	print("[Onboarding] Pulse client active | marks, no polling | saved progress through GetState")
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
