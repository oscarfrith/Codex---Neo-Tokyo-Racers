-- Owns the Pulse activity HUD host: the ActivityHud layers, the design-pixel root, the context the shared activity views are mounted with, the ActivityEvent listener and the ActivityInvoke calls; not the five shared views, the toast owner, the route guide or any activity rule (the server decides those).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.ActivityHudClient. Requires: Layers, Metrics, Tokens, Text, FreeRoam.ActivityHudView, Core.ConnectionScope, UI.RouteGuide, the shared Activities views (all resolved inside start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SURFACE = "ActivityHud"
local LAYER_NAME = "ActivityHud"
-- Mount order of the shared views (Classic ActivityClient 292).
local VIEW_NAMES = table.freeze({ "CourierClientView", "PassengerClientView", "TaxiClientView", "DuelClientView" })
local RANK_UP_SECONDS = 3.5 -- Classic 266
local RANK_UP_WAIT_LIMIT = 600 -- Classic 255: a rank-up waits for a race to end for at most this long (seconds)
local TOAST_SECONDS = 2.4 -- Classic 61

local Client = {}
local state

-- A small Luau signal (Connect, Fire); connections have Disconnect, so a ConnectionScope can hold them.
local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(callback)
		local connection = { Connected = true }
		handlers[connection] = callback
		function connection:Disconnect()
			handlers[connection] = nil
			connection.Connected = false
		end
		return connection
	end
	function signal:Fire(...)
		for _, callback in pairs(table.clone(handlers)) do
			callback(...)
		end
	end
	return signal
end

-- Pure rules, exported for the tests -----------------------------------------------------------------------

-- Classic ActivityClient 65-67: every reply is an untrusted shape.
function Client._reply(okCall, reply)
	if not okCall then
		return { Ok = false, Message = "Connection problem. Try again." }
	end
	return type(reply) == "table" and reply or { Ok = reply == true }
end

-- The activity theme (PC 2.3 named exception): the shared views assign these to Parts, lights and map markers and
-- pass three of them back as meaning, so every value is a Color3 and Telemetry and HighSpeed differ. All 13 Classic
-- names are kept. Values come from the Pulse tokens; ElectricBlue (courier identity) has no blue in the palette and
-- is Violet.
function Client._theme(Tokens, Text)
	local colour = Tokens.Colour
	return {
		Font = Text and Text.Font("Label") or nil,
		Panel = colour.Slate,
		PanelDeep = colour.Ink,
		PanelSoft = colour.Slate,
		PanelBlue = colour.ScrimBottom,
		Outline = colour.Pink,
		OutlineSoft = colour.Violet,
		Telemetry = colour.Cyan,
		ElectricBlue = colour.Violet,
		HighSpeed = colour.Pink,
		Danger = colour.Danger,
		Text = colour.White,
		Muted = colour.TextMuted,
		Disabled = colour.TextMuted,
	}
end

-- Classic ActivityClient 244-251.
function Client._racing(player)
	if player:GetAttribute("RaceQueueActive") == true then
		return true
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local vehicle = seat and seat:FindFirstAncestorOfClass("Model")
	return vehicle ~= nil and (vehicle:GetAttribute("RaceParticipant") == true or vehicle:GetAttribute("RaceRunId") ~= nil)
end

-- Height of the Pulse bottom row and the gap above it, in design units (px at 1080 on Regular, dp on Compact):
-- the HUD buttons on a Standard arrangement, the centre gauge on TouchDrive (API2 2.4).
function Client._bottomRow(ctx, space)
	local compact = ctx.Class == "Compact"
	local bottom = compact and space.CompactBottom or space.HudBottom
	local row
	if ctx.Arrangement == "TouchDrive" then
		row = compact and space.CompactGauge or space.GaugeTouchSize
	else
		row = compact and math.max(space.CompactHudButton, space.TouchMin) or space.HudButtonHeight
	end
	return bottom + row, compact and space.TouchGap or space.Gap
end

-- How far the design root's bottom edge is lifted so a child that sits `offset` design units above that edge (the
-- Duel button's own hard-coded offset) clears the bottom row. An unknown offset is treated as none.
function Client._rootLift(row, gap, offset)
	return math.max(0, row + gap - (offset or 0))
end

-- The headless model: Classic ActivityClient 52-68, 123-136, 138-186 (state only), 188-216 (state only),
-- 236-241 and 252-268 (state only). deps = { Theme, InvokeServer(action, args), FindNotify() -> BindableEvent?,
-- Clock(), ServerNow(), Delay(seconds, fn), Spawn(fn), WhenNotRacing(fn) }. It creates no instance.
function Client._newModel(deps)
	local changed = newSignal()
	local model = { Theme = deps.Theme, Clock = deps.Clock, ServerNow = deps.ServerNow, Changed = changed }

	function model.Toast(text, seconds)
		local notify = deps.FindNotify()
		if notify then
			notify:Fire(tostring(text), seconds or TOAST_SECONDS)
		end
	end

	-- The one remote call site. Yields.
	function model.Invoke(action, args)
		local okCall, reply = pcall(deps.InvokeServer, action, args or {})
		return Client._reply(okCall, reply)
	end

	function model.Cancel()
		local reply = model.Invoke("Cancel")
		if reply.Ok then
			model.Toast("JOB CANCELLED")
		end
	end

	-- Job strip: the newest Set wins, Clear removes that kind. Changed fires only when the showing line changes
	-- (the shared views re-set an unchanged line several times a second).
	local stripEntries, stripOrder = {}, {}
	local stripShown = nil
	local function stripRefresh()
		local kind = stripOrder[#stripOrder]
		local entry = kind and stripEntries[kind] or nil
		local shown = stripShown
		if entry == nil and shown == nil then
			return
		end
		if entry and shown and shown.Kind == kind and shown.Text == entry.Text and shown.Colour == entry.Colour then
			return
		end
		stripShown = entry and { Kind = kind, Text = entry.Text, Colour = entry.Colour } or nil
		changed:Fire("Strip")
	end
	local Strip = {}
	function Strip.Set(kind, text, colour)
		stripEntries[kind] = { Text = string.upper(tostring(text)), Colour = colour }
		local index = table.find(stripOrder, kind)
		if index then
			table.remove(stripOrder, index)
		end
		table.insert(stripOrder, kind)
		stripRefresh()
	end
	function Strip.Clear(kind)
		stripEntries[kind] = nil
		local index = table.find(stripOrder, kind)
		if index then
			table.remove(stripOrder, index)
		end
		stripRefresh()
	end
	model.Strip = Strip
	function model.StripEntry()
		return stripShown
	end

	-- Offer card: one at a time; a new offer closes the old one. Returns an idempotent close function.
	local currentOffer = nil
	local offerRecord = nil
	function model.Offer(spec)
		if currentOffer then
			currentOffer()
		end
		local buttons = {}
		for index, definition in ipairs(spec.Buttons or {}) do
			buttons[index] = {
				Text = string.upper(tostring(definition.Text or "")),
				Accent = definition.Accent,
				Enabled = definition.Enabled ~= false,
				OnClick = definition.OnClick,
			}
		end
		local timeout = tonumber(spec.Timeout)
		if not (timeout and timeout > 0) then
			timeout = nil
		end
		local record = {
			Title = string.upper(tostring(spec.Title or "")),
			Body = tostring(spec.Body or ""),
			Buttons = buttons,
			Timeout = timeout,
			StartedAt = deps.Clock(),
		}
		local closed = false
		local function close()
			if closed then
				return
			end
			closed = true
			if currentOffer == close then
				currentOffer = nil
			end
			if offerRecord == record then
				offerRecord = nil
				changed:Fire("Offer")
			end
		end
		record.Close = close
		offerRecord = record
		currentOffer = close
		if timeout then
			deps.Delay(timeout, close)
		end
		changed:Fire("Offer")
		return close
	end
	function model.OfferState()
		return offerRecord
	end
	-- A click closes the card, then runs the option in its own task (Classic 172-175). A disabled option does nothing.
	function model.PressOffer(record, index)
		if record == nil or offerRecord ~= record then
			return
		end
		local definition = record.Buttons[index]
		if not definition or not definition.Enabled then
			return
		end
		record.Close()
		if definition.OnClick then
			deps.Spawn(definition.OnClick)
		end
	end

	-- Countdown to a server time; a new one replaces the old one; the view ends it 0.9 s after zero.
	local countdownRecord = nil
	function model.Countdown(goAt, label)
		countdownRecord = { GoAt = tonumber(goAt) or deps.ServerNow(), Label = string.upper(tostring(label or "")) }
		changed:Fire("Countdown")
	end
	function model.CountdownState()
		return countdownRecord
	end
	function model.CountdownEnded(record)
		if record ~= nil and countdownRecord == record then
			countdownRecord = nil
			changed:Fire("Countdown")
		end
	end

	-- JOBS panel retired in Classic: views may still call these; entries are kept and nothing is drawn.
	local jobEntries = {}
	local Jobs = {}
	function Jobs.AddEntry(entry)
		if type(entry) == "table" and entry.Id ~= nil then
			jobEntries[entry.Id] = entry
		end
	end
	function Jobs.Refresh() end
	model.Jobs = Jobs

	-- Rank-up card, deferred while a race is presenting. Runs in its own task so the event handler never waits.
	local rankRecord = nil
	function model.RankUp(payload)
		deps.Spawn(function()
			deps.WhenNotRacing(function()
				local record = { Text = "RANK " .. tostring(payload.Rank or ""), Cash = tonumber(payload.Cash) or 0 }
				rankRecord = record
				changed:Fire("RankUp")
				deps.Delay(RANK_UP_SECONDS, function()
					if rankRecord == record then
						rankRecord = nil
						changed:Fire("RankUp")
					end
				end)
			end)
		end)
	end
	function model.RankUpState()
		return rankRecord
	end

	return model
end

-- Not pure: the pieces start() wires -------------------------------------------------------------------------

-- The design-pixel frame handed to the shared views as ctx.Root, with the programme's one named UIScale outside
-- text holders (API2 6.6 rule 2). Kit components built inside it resolve to a fixed scale-1 context of the same
-- class, so they are scaled once, by the UIScale.
function Client._newDesignRoot(layer, Metrics, Tokens, scope)
	local ctx = layer.Metrics
	local frame = Instance.new("Frame")
	frame.Name = "DesignPixels"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0

	local scale = Instance.new("UIScale")
	scale.Name = "DesignScale"
	scale.Parent = frame

	local scales = Tokens.Scale
	local reference
	if ctx.Class == "Compact" then
		reference = Vector2.new(scales.CompactEnterWidth, scales.CompactRefHeight)
	else
		reference = Vector2.new(scales.RegularRefWidth, scales.RegularRefHeight)
	end
	Metrics.Bind(frame, Metrics.Fixed({ Size = reference, TouchEnabled = ctx.Arrangement == "TouchDrive", Input = ctx.Input }))

	local offset = nil
	local function relayout()
		local factor = ctx.Scale
		local row, gap = Client._bottomRow(ctx, Tokens.Space)
		local lift = Client._rootLift(row, gap, offset)
		if scale.Scale ~= factor then
			scale.Scale = factor
		end
		local size = UDim2.new(1 / factor, 0, 1 / factor, -lift)
		if frame.Size ~= size then
			frame.Size = size
		end
	end
	relayout()
	frame.Parent = layer.Root

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			relayout()
		end)
	end

	local design = { Frame = frame, Scale = scale, Relayout = relayout }
	-- A view places its button above the root's bottom edge with its own offset (Duel: 1, -120 or 1, -84). The
	-- offset is read from the button, so no view number is repeated here.
	function design.Watch(button)
		local function read()
			local position = button.Position
			if position.Y.Scale == 1 then
				local value = -position.Y.Offset
				if value ~= offset then
					offset = value
					relayout()
				end
			end
		end
		scope:connect(button:GetPropertyChangedSignal("Position"), read)
	end
	return design
end

-- World beacons: client-only light pillars under the camera (Classic ActivityClient 219-233, unchanged; world art,
-- so the stud and light numbers are Classic's).
local function newBeacon(theme)
	local beacons = {}
	return function(id, position, colour)
		if beacons[id] then
			beacons[id]:Destroy()
		end
		local pillar = Instance.new("Part")
		pillar.Name = "ActivityBeacon_" .. tostring(id)
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.CanTouch = false
		pillar.CastShadow = false
		pillar.Material = Enum.Material.Neon
		pillar.Color = colour or theme.Telemetry
		pillar.Transparency = 0.45
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(260, 6, 6)
		pillar.CFrame = CFrame.new(position + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Parent = Workspace.CurrentCamera
		local light = Instance.new("PointLight")
		light.Color = colour or theme.Telemetry
		light.Range = 40
		light.Brightness = 2
		light.Parent = pillar
		beacons[id] = pillar
		return function()
			if beacons[id] == pillar then
				beacons[id] = nil
			end
			pillar:Destroy()
		end
	end
end

-- Calls onFree once, as soon as Client._racing(player) is false, or after the Classic limit. Classic re-checks once
-- a second; this re-checks on the signals that can change the answer, so nothing is polled.
local function whenNotRacing(player, onFree)
	if not Client._racing(player) then
		onFree()
		return
	end
	local finished = false
	local fixed = {}
	local humanoidConnection = nil
	local vehicleConnection = nil
	local function unhook()
		if humanoidConnection then
			humanoidConnection:Disconnect()
			humanoidConnection = nil
		end
		if vehicleConnection then
			vehicleConnection:Disconnect()
			vehicleConnection = nil
		end
	end
	local function finish()
		if finished then
			return
		end
		finished = true
		unhook()
		for _, connection in ipairs(fixed) do
			connection:Disconnect()
		end
		onFree()
	end
	local check
	local function hook()
		unhook()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		humanoidConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			check()
		end)
		local seat = humanoid.SeatPart
		local vehicle = seat and seat:FindFirstAncestorOfClass("Model")
		if vehicle then
			vehicleConnection = vehicle.AttributeChanged:Connect(function()
				check()
			end)
		end
	end
	check = function()
		if finished then
			return
		end
		if Client._racing(player) then
			hook()
		else
			finish()
		end
	end
	table.insert(fixed, player:GetAttributeChangedSignal("RaceQueueActive"):Connect(check))
	table.insert(fixed, player.CharacterAdded:Connect(check))
	table.insert(fixed, player.CharacterRemoving:Connect(function()
		task.defer(check)
	end))
	hook()
	task.delay(RANK_UP_WAIT_LIMIT, finish)
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The waits the Classic owner makes (ActivityClient 21-30), minus its two Classic UI requires.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local modules = ReplicatedStorage:WaitForChild("Modules")
	local RouteGuide = require(modules:WaitForChild("Game"):WaitForChild("UI"):WaitForChild("RouteGuide"))
	local activityModules = modules.Game:WaitForChild("Activities")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Activities")
	local invokeRemote = remotes:WaitForChild("ActivityInvoke")
	local eventRemote = remotes:WaitForChild("ActivityEvent")
	local uiFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")

	local Tokens = require(kit.Tokens)
	local Metrics = require(kit.Metrics)
	local Text = require(kit.Text)
	local View = require(script.Parent.ActivityHudView)
	local scope = require(modules:WaitForChild("Core"):WaitForChild("ConnectionScope")).new()

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local theme = Client._theme(Tokens, Text)

	-- 3. OpenJobs is kept so older senders find it; nothing listens (Classic 52-57).
	if not uiFolder:FindFirstChild("OpenJobs") then
		local openJobs = Instance.new("BindableEvent")
		openJobs.Name = "OpenJobs"
		openJobs.Parent = uiFolder
	end

	-- 4. Layers, model, view, design root.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud", RootName = "DesignRoot" })
	local live = Layers.Create(LAYER_NAME, { Frame = "Hud", Live = true })

	local model = Client._newModel({
		Theme = theme,
		InvokeServer = function(action, args)
			return invokeRemote:InvokeServer(action, args)
		end,
		FindNotify = function()
			local notify = uiFolder:FindFirstChild("ShowTopNotification")
			if notify and notify:IsA("BindableEvent") then
				return notify
			end
			return nil
		end,
		Clock = os.clock,
		ServerNow = function()
			return Workspace:GetServerTimeNow()
		end,
		Delay = task.delay,
		Spawn = task.spawn,
		WhenNotRacing = function(onFree)
			whenNotRacing(player, onFree)
		end,
	})
	local view = View.Mount(layer, model, scope, live)
	local design = Client._newDesignRoot(layer, Metrics, Tokens, scope)

	-- 5. Visibility. The full map hides every HUD while it is open (Classic 75-77); root Visible, never Enabled.
	-- The attribute is cached so nothing reached from the frame step reads an attribute.
	local fullMapOpen = player:GetAttribute("FullMapOpen") == true
	local function sync()
		layer.SetVisible(not fullMapOpen)
		live.SetVisible(not fullMapOpen and view.LiveNeeded())
	end
	scope:connect(player:GetAttributeChangedSignal("FullMapOpen"), function()
		fullMapOpen = player:GetAttribute("FullMapOpen") == true
		sync()
	end)
	scope:connect(model.Changed, function(reason)
		view.Render(reason)
		sync()
	end)
	sync()

	-- 6. The context of Classic 270-288, field for field.
	local function button(parent, props)
		local instance = View.Button(parent, props, scope)
		if parent == design.Frame then
			design.Watch(instance)
		end
		return instance
	end
	local function label(parent, props)
		return (View.Label(parent, props, scope, theme))
	end
	local ctx = {
		Player = player,
		Invoke = model.Invoke,
		Gui = layer.Gui,
		Root = design.Frame,
		IsMobile = isMobile,
		Theme = theme,
		RouteGuide = RouteGuide,
		Toast = model.Toast,
		UI = {
			Button = button,
			Label = label,
			Strip = model.Strip,
			Offer = model.Offer,
			Countdown = model.Countdown,
			Beacon = newBeacon(theme),
		},
		Jobs = model.Jobs,
	}
	Client.Context = ctx
	Client.Controller = { Layer = layer, Live = live, Model = model, View = view, Design = design }

	-- 7. Mount the shared views in the Classic order (Classic 291-303).
	local views = {}
	for _, name in ipairs(VIEW_NAMES) do
		local module = activityModules:FindFirstChild(name)
		if module then
			local loaded, activityView = pcall(require, module)
			if loaded and type(activityView) == "table" then
				local mounted, err = pcall(function()
					if activityView.Mount then
						activityView.Mount(ctx)
					end
				end)
				if mounted then
					table.insert(views, activityView)
				else
					warn("[Pulse.ActivityHudClient] " .. name .. " mount failed: " .. tostring(err))
				end
			else
				warn("[Pulse.ActivityHudClient] " .. name .. " failed to load: " .. tostring(activityView))
			end
		end
	end

	-- 8. The one ActivityEvent listener (Classic 305-314).
	scope:connect(eventRemote.OnClientEvent, function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "Rank:Up" then
			model.RankUp(payload)
		end
		for _, activityView in ipairs(views) do
			if activityView.OnEvent then
				local handled, err = pcall(activityView.OnEvent, payload)
				if not handled then
					warn("[Pulse.ActivityHudClient] view event failed: " .. tostring(err))
				end
			end
		end
	end)
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
