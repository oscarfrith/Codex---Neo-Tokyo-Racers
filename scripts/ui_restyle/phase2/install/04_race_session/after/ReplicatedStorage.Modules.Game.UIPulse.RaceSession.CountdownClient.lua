-- Owns the Pulse race countdown: the RaceCountdown layer, the five-to-GO schedule and the CountdownPresentationReady attribute; not the HUD, the staging or the fade.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.CountdownClient. Requires: Layers, Text, BigNumber, Core.ConnectionScope (resolved inside start and _mountView).
--
-- Classic line references: C = ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient.
-- One module (API2 6.2, small owners): the decision logic is Client._kind, _maximum, _seconds and Client._new(deps),
-- which pure tests drive with fakes. deps = { Now, Spawn, Delay, Wait, Config = (name, fallback) -> number, Render = (view) -> () }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LAYER_NAME = "RaceCountdown"
local SURFACE = "RaceCountdown"

local Client = {}
local state

Client.GET_READY = "GET READY" -- C28
Client.GO = "GO!" -- C58
Client.TICK_SECONDS = 0.03 -- C49
Client.GO_SECONDS = 0.85 -- C32 fallback
Client.COUNTDOWN_SECONDS = 5 -- C37 fallback

-- C55-59: what each RaceEvent kind does. Pure.
function Client._kind(kind)
	if kind == "TimeTrialStaged" or kind == "RaceStaged" or kind == "TimeTrialCountdownReveal" or kind == "RaceCountdownReveal" then
		return "hide"
	elseif kind == "TimeTrialCountdownScheduled" or kind == "RaceCountdownScheduled" then
		return "schedule"
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
		return "show"
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		return "go"
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceFinished"
		or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceExitedToStart" or kind == "RaceQueueError" then
		return "hide"
	end
	return nil
end

-- C37. Pure.
function Client._maximum(countdown, configured)
	return math.max(1, math.floor(tonumber(countdown) or configured))
end

-- C44. Pure.
function Client._seconds(remaining, maximum)
	return math.clamp(math.ceil(remaining), 1, maximum)
end

-- C30-60 as a headless controller. `view` is { Visible, Heading, Text, Go }.
function Client._new(deps)
	local token = 0
	local view = { Visible = false, Heading = Client.GET_READY, Text = "5", Go = false }

	local function render()
		deps.Render(view)
	end

	local function hide() -- C31
		token += 1
		view.Visible = false
		render()
	end

	local function show(text, isGo) -- C32
		token += 1
		local mine = token
		view.Visible = true
		view.Heading = isGo and "" or Client.GET_READY
		view.Text = text
		view.Go = isGo == true
		render()
		if isGo then
			deps.Delay(deps.Config("GoDuration", Client.GO_SECONDS), function()
				if token == mine then
					view.Visible = false
					render()
				end
			end)
		end
	end

	local function schedule(payload) -- C33-52
		token += 1
		local mine = token
		local goAt = tonumber(payload.GoAtServerTime)
		local maximum = Client._maximum(payload.Countdown, deps.Config("CountdownSeconds", Client.COUNTDOWN_SECONDS))
		if not goAt then
			show(tostring(maximum), false)
			return
		end
		deps.Spawn(function()
			local previous = nil
			while token == mine do
				local remaining = goAt - deps.Now()
				if remaining <= 0 then
					return
				end
				local seconds = Client._seconds(remaining, maximum)
				if seconds ~= previous then
					previous = seconds
					view.Visible = true
					view.Heading = Client.GET_READY
					view.Text = tostring(seconds)
					view.Go = false
					render()
				end
				deps.Wait(Client.TICK_SECONDS)
			end
		end)
	end

	local controller = {}
	function controller.Handle(payload) -- C53-60
		if type(payload) ~= "table" then
			return
		end
		local action = Client._kind(tostring(payload.Type or ""))
		if action == "hide" then
			hide()
		elseif action == "schedule" then
			schedule(payload)
		elseif action == "show" then
			show(tostring(payload.Countdown or ""), false)
		elseif action == "go" then
			show(Client.GO, true)
		end
	end
	function controller.View()
		return view
	end
	return controller
end

-- The drawing: GET READY, the number as BigNumber sprites (role Countdown), GO! in Cyan. No panel (r14, c09).
function Client._mountView(layer, scope)
	local kit = script.Parent.Parent.Kit
	local Tokens = require(kit.Tokens)
	local Text = require(kit.Text)
	local BigNumber = require(kit.BigNumber)
	local ctx = layer.Metrics
	local slot = layer.Slot("Centre")

	local card = Instance.new("Frame")
	card.Name = "CountdownCard"
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.AutomaticSize = Enum.AutomaticSize.XY
	card.AnchorPoint = slot.AnchorPoint
	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	card.Parent = slot

	local heading = Text.Label(card, { Name = "Heading", Text = Client.GET_READY, Role = "SectionHead", Align = "Centre",
		Shadow = true, LayoutOrder = 1 }, scope)
	local number = BigNumber.New(card, { Name = "Number", Text = "5", Role = "Countdown", Align = "Centre", MaxCells = 2,
		LayoutOrder = 2 }, scope)
	local go = Text.Label(card, { Name = "Go", Text = Client.GO, Role = "ScreenTitle", Colour = "Cyan", Align = "Centre",
		Shadow = true, Visible = false, LayoutOrder = 3 }, scope)

	local function layout()
		local padding = UDim.new(0, ctx.Px(Tokens.Space.Gap))
		if list.Padding ~= padding then
			list.Padding = padding
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
		heading.Set({ Text = view.Heading, Visible = view.Heading ~= "" })
		local digits = (not view.Go) and string.match(tostring(view.Text), "^%d+$") or nil
		if digits then
			number.SetText(string.sub(digits, -2))
		end
		number.Set({ Visible = digits ~= nil })
		go.Set({ Text = view.Go and tostring(view.Text) or Client.GO, Visible = view.Go == true })
	end
	function mounted.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		heading.Destroy()
		number.Destroy()
		go.Destroy()
		card:Destroy()
	end
	mounted.Instance = card
	return mounted
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. The same waits as Classic (C12-14, C61).
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local raceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceEvent")
	local runtimeRacing = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("Racing")

	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- C17-18, read at use (never in a frame step); a missing folder gives the Classic fallbacks.
	local function config(name, fallback)
		local root = ReplicatedStorage:FindFirstChild("Config")
		local racing = root and root:FindFirstChild("Racing")
		local flow = racing and racing:FindFirstChild("FlowUI")
		local item = flow and flow:FindFirstChild(name)
		return item and item:IsA("NumberValue") and item.Value or fallback
	end

	-- 3. Layer and view, hidden.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud" })
	layer.SetVisible(false)
	local view = Client._mountView(layer, scope)

	-- 4. Controller and the one listener (C53).
	local controller = Client._new({
		Now = function()
			return Workspace:GetServerTimeNow()
		end,
		Spawn = task.spawn,
		Delay = task.delay,
		Wait = task.wait,
		Config = config,
		Render = view.Render,
	})
	view.Render(controller.View())
	scope:connect(raceEvent.OnClientEvent, controller.Handle)
	Client.Controller = { Gui = layer.Gui, Handle = controller.Handle, View = controller.View }

	-- 5. Last statement, after connecting (C61; RaceTransitionClient waits for it at its line 265).
	runtimeRacing:SetAttribute("CountdownPresentationReady", true)
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
