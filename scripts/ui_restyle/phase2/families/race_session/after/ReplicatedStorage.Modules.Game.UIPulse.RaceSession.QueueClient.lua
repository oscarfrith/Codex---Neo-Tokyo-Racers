-- Owns the Pulse race queue: the single StartRaceQueueRequest listener, the JoinQueue and LeaveQueue calls and the RaceQueueBanner layer; never post-race results.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.QueueClient. Requires: Layers, Tokens, Text, Surface, Controls, Core.ConnectionScope (resolved inside start and _mountView).
--
-- Classic line references: Q = ReplicatedStorage.Modules.Game.Racing.RaceQueueClient.
-- One module (API2 6.2, small owners): Client._new(deps) is the headless queue model, driven by pure tests.
-- deps = {
--   Request = RemoteFunction (RaceQueueRequest),
--   Bindable = (name) -> BindableEvent?,       "FreeRoamHudPresentationMode", "FreeRoamVehicleSpawned" (Q25-26)
--   SetAttribute = (name, value) -> (), GetAttribute = (name) -> any,     on the local player (Q44)
--   Stream = (routeId, index) -> (),            Q27
--   Defer = task.defer, Delay = task.delay, Render = (view) -> () }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LAYER_NAME = "RaceQueueBanner"
local SURFACE = "RaceQueue"

local Client = {}
local state

Client.OWNER = "RaceQueue" -- Q25
Client.KEEP_TELEMETRY = true -- Q25
Client.FAILED_SECONDS = 2 -- Q44
Client.HANDOFF_SECONDS = 0.25 -- Q51
Client.STREAM_SECONDS = 3 -- Q27

-- Q41-53 as a headless model. `view` is { Visible, Title, Status, Players, Starts, LeaveEnabled }.
function Client._new(deps)
	local queued = false -- Q40
	local currentEventName = "RACE QUEUE" -- Q41
	local published = false
	local view = { Visible = false, Title = "RACE QUEUE", Status = "WAITING FOR RACERS", Players = "0 / 0", Starts = "0s",
		LeaveEnabled = true }

	local function render()
		deps.Render(view)
	end

	-- Q24: the one remote call path of this owner.
	local function call(action, payload)
		local ok, result = pcall(function()
			return deps.Request:InvokeServer(action, payload or {})
		end)
		return ok and type(result) == "table" and result
			or { Ok = false, Success = false, Message = tostring(result or "Queue request failed.") }
	end

	-- Q25, fired on change only (API2 5.5).
	local function publish(open)
		open = open == true
		if open == published then
			return
		end
		published = open
		local signal = deps.Bindable("FreeRoamHudPresentationMode")
		if signal then
			signal:Fire({ Owner = Client.OWNER, Active = open, KeepTelemetry = Client.KEEP_TELEMETRY })
		end
	end

	-- Q26.
	local function drivingHandoff()
		local signal = deps.Bindable("FreeRoamVehicleSpawned")
		if signal then
			signal:Fire()
		end
	end

	local function hide() -- Q42
		queued = false
		view.Visible = false
		publish(false)
		render()
	end

	local function show(payload, message) -- Q43
		queued = true
		view.Visible = true
		publish(true)
		if payload.DisplayName and tostring(payload.DisplayName) ~= "" then
			currentEventName = string.upper(tostring(payload.DisplayName))
		end
		view.Title = currentEventName
		view.Status = string.upper(tostring(message or payload.Message or "WAITING FOR RACERS"))
		view.Players = tostring(payload.Count or 0) .. " / " .. tostring(payload.MaxPlayers or 0)
		view.Starts = tostring(payload.SecondsRemaining or 0) .. "s"
		render()
	end

	local model = {}

	-- Q44: the handler of Runtime.Racing.StartRaceQueueRequest. It yields in the join call, as Classic does.
	function model.Start(payload)
		payload = type(payload) == "table" and payload or {}
		currentEventName = string.upper(tostring(payload.DisplayName or "RACE QUEUE"))
		deps.SetAttribute("LastRacingEventId", tostring(payload.EventId or ""))
		deps.SetAttribute("LastRacingVehicleId", tostring(payload.VehicleId or ""))
		show(payload, "JOINING QUEUE")
		local result = call("JoinQueue", { EventId = payload.EventId, VehicleId = payload.VehicleId })
		if result.Ok ~= true and result.Success ~= true then
			view.Status = string.upper(tostring(result.Message or "QUEUE FAILED"))
			render()
			deps.Delay(Client.FAILED_SECONDS, function()
				if not deps.GetAttribute("RaceQueueActive") then
					hide()
				end
			end)
		end
	end

	-- Q45: LEAVE.
	function model.Leave()
		if not queued then
			return
		end
		view.LeaveEnabled = false
		view.Status = "LEAVING QUEUE"
		render()
		local result = call("LeaveQueue", {})
		view.LeaveEnabled = true
		if result.Ok ~= true and result.Success ~= true then
			view.Status = string.upper(tostring(result.Message or "LEAVE FAILED"))
		end
		render()
	end

	-- Q46-53: RaceQueueEvent.
	function model.Handle(payload)
		if type(payload) ~= "table" then
			return
		end
		local kind = tostring(payload.Type or "")
		if kind == "QueueJoined" or kind == "QueueUpdate" then
			show(payload)
		elseif kind == "QueueLeft" or kind == "RaceQueueError" then
			hide()
		elseif kind == "RaceStaged" then
			hide()
		elseif kind == "RaceStarted" then
			hide()
			deps.Defer(deps.Stream, payload.RouteId, payload.NextGateIndex or 1)
			deps.Defer(drivingHandoff)
			deps.Delay(Client.HANDOFF_SECONDS, drivingHandoff)
		elseif kind == "RaceFinished" or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceExitedToStart" then
			hide()
		end
	end

	function model.View()
		return view
	end
	function model.Queued()
		return queued
	end
	return model
end

-- The banner (r14): status over the event name, players, time left, and LEAVE as the only button (Danger).
-- handlers = { OnLeave = () -> () }
function Client._mountView(layer, scope, handlers)
	local kit = script.Parent.Parent.Kit
	local Tokens = require(kit.Tokens)
	local Text = require(kit.Text)
	local Surface = require(kit.Surface)
	local Controls = require(kit.Controls)
	local Space = Tokens.Space
	local ctx = layer.Metrics
	local slot = layer.Slot("TopCentreHud")
	local compact = ctx.Class == "Compact"
	local lists = {}

	local function holder(name, parent, direction, order)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.AutomaticSize = Enum.AutomaticSize.XY
		frame.LayoutOrder = order or 0
		local list = Instance.new("UIListLayout")
		list.Name = "Layout"
		list.FillDirection = direction
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = frame
		frame.Parent = parent
		return frame, list
	end

	local anchor = Instance.new("Frame")
	anchor.Name = "QueueBanner"
	anchor.BackgroundTransparency = 1
	anchor.BorderSizePixel = 0
	anchor.AutomaticSize = Enum.AutomaticSize.XY
	anchor.AnchorPoint = slot.AnchorPoint
	anchor.Parent = slot

	-- Compact: the 22 dp panel padding and row gap alone took 110 of a 300 dp banner, which left no width for the
	-- event name beside PLAYERS, STARTS IN and LEAVE. The touch gap is the padding there and the banner is wider.
	local pad = compact and Space.TouchGap or Space.Pad
	local panel = Surface.Panel(anchor, { Name = "Panel", Pad = pad,
		Width = compact and (Space.CompactPromptWidth + Space.CompactStatPanelWidth) or Space.ModalMaxWidth,
		Height = compact and Space.CompactTileHeight or Space.ListRowHeight }, scope)
	local row, rowList = holder("Row", panel.Content, Enum.FillDirection.Horizontal, 0)
	row.AutomaticSize = Enum.AutomaticSize.None
	row.Size = UDim2.fromScale(1, 1)
	table.insert(lists, rowList)

	local titles = holder("Titles", row, Enum.FillDirection.Vertical, 1)
	local flex = Instance.new("UIFlexItem")
	flex.Name = "Fill"
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = titles
	local status = Text.Label(titles, { Name = "Status", Text = "WAITING FOR RACERS", Role = "Label", Colour = "Cyan",
		Align = "Left", LayoutOrder = 1 }, scope)
	local title = Text.Label(titles, { Name = "Title", Text = "RACE QUEUE", Role = compact and "TileNameSmall" or "TileName",
		Align = "Left", LayoutOrder = 2 }, scope)

	local function stat(name, heading, order)
		local block, list = holder(name, row, Enum.FillDirection.Vertical, order)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local head = Text.Label(block, { Name = "Heading", Text = heading, Role = "Label", Colour = "TextSecondary",
			Align = "Centre", LayoutOrder = 1 }, scope)
		local value = Text.Label(block, { Name = "Value", Text = "", Role = "Status", Align = "Centre", LayoutOrder = 2 }, scope)
		return value, head
	end
	local players, playersHead = stat("Players", "PLAYERS", 2)
	local starts, startsHead = stat("Starts", "STARTS IN", 3)

	local leave = Controls.Button(row, { Name = "Leave", Variant = "Danger", Text = "LEAVE", Icon = "exit", LayoutOrder = 4,
		OnActivated = function()
			if handlers and handlers.OnLeave then
				handlers.OnLeave()
			end
		end }, scope)

	local function layout()
		local padding = UDim.new(0, ctx.Px(pad))
		for _, list in ipairs(lists) do
			if list.Padding ~= padding then
				list.Padding = padding
			end
		end
	end
	layout()
	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			layout()
		end)
	end

	local shown = nil
	local destroyed = false
	local mounted = {}
	function mounted.Render(view)
		if destroyed then
			return
		end
		local visible = view.Visible == true
		if shown ~= visible then
			shown = visible
			layer.SetVisible(visible)
		end
		if not visible then
			return
		end
		status.Set({ Text = view.Status })
		title.Set({ Text = view.Title })
		players.Set({ Text = view.Players })
		starts.Set({ Text = view.Starts })
		leave.Set({ Disabled = view.LeaveEnabled == false })
	end
	function mounted.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, component in ipairs({ status, title, players, playersHead, starts, startsHead, leave, panel }) do
			component.Destroy()
		end
		anchor:Destroy()
	end
	mounted.Instance = anchor
	return mounted
end

-- Q27: ask the server to stream the first gate of the route before the hand-off.
function Client._stream(player, routeId, index)
	local world = Workspace:FindFirstChild("World")
	local routes = world and world:FindFirstChild("RaceRoutes")
	local route = routes and routes:FindFirstChild(tostring(routeId or ""))
	local gate = route and (route:FindFirstChild("Checkpoint" .. tostring(index or 1), true) or route:FindFirstChild("FinishLine", true))
	if gate and gate:IsA("BasePart") then
		pcall(function()
			player:RequestStreamAroundAsync(gate.Position, Client.STREAM_SECONDS)
		end)
	end
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The same waits as Classic (Q13-19).
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local racingRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Racing")
	local request = racingRemotes:WaitForChild("RaceQueueRequest")
	local queueEvent = racingRemotes:WaitForChild("RaceQueueEvent")
	local runtime = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime")
	local startRequest = runtime:WaitForChild("Racing"):WaitForChild("StartRaceQueueRequest")

	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 3. Layer and view, hidden.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud" })
	layer.SetVisible(false)
	local model
	local view = Client._mountView(layer, scope, {
		OnLeave = function()
			model.Leave()
		end,
	})

	-- 4. Model. The two bindables are looked up at each fire, as Classic does (Q25-26).
	model = Client._new({
		Request = request,
		Bindable = function(name)
			local folder = runtime:FindFirstChild("UI")
			local signal = folder and folder:FindFirstChild(name)
			return signal and signal:IsA("BindableEvent") and signal or nil
		end,
		SetAttribute = function(name, value)
			player:SetAttribute(name, value)
		end,
		GetAttribute = function(name)
			return player:GetAttribute(name)
		end,
		Stream = function(routeId, index)
			Client._stream(player, routeId, index)
		end,
		Defer = task.defer,
		Delay = task.delay,
		Render = view.Render,
	})
	view.Render(model.View())

	-- 5. The single listener of StartRaceQueueRequest (Q44) and the queue event (Q46).
	scope:connect(startRequest.Event, model.Start)
	scope:connect(queueEvent.OnClientEvent, model.Handle)

	Client.Controller = { Gui = layer.Gui, Model = model }
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
