-- Owns the Pulse results entry: claims the surface, creates UnifiedRaceResults and wires RaceEvent to the results model; not the HUD, the queue or the rewards.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.ResultsClient. Requires: Layers, ResultsModel, ResultsView, Core.ConnectionScope (resolved inside start).
--
-- Classic line references: R = ReplicatedStorage.Modules.Game.Racing.RaceTimeTrialResultCoachClient.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LAYER_NAME = "UnifiedRaceResults"
local SURFACE = "RaceResults"

local Client = {}
local state

-- Where each bindable lives under PlayerScripts.Runtime (R22, R93-94, R102, R193).
Client._bindableFolders = {
	RaceTransitionRequest = "Racing",
	StartRaceQueueRequest = "Racing",
	FreeRoamHudPresentationMode = "UI",
	FreeRoamVehicleExited = "UI",
}

-- Looked up at each fire, as Classic does for all but the transition request.
function Client._bindable(runtime, name)
	local folderName = Client._bindableFolders[name]
	local folder = folderName and runtime:FindFirstChild(folderName)
	local event = folder and folder:FindFirstChild(name)
	return event and event:IsA("BindableEvent") and event or nil
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. Remotes and bindables, with the waits the Classic owner makes (R14, R18-22).
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local racingRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Racing")
	local raceEvent = racingRemotes:WaitForChild("RaceEvent")
	local raceRequest = racingRemotes:WaitForChild("RaceRequest")
	local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
	local runtime = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime")
	runtime:WaitForChild("Racing"):WaitForChild("RaceTransitionRequest")

	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 3. Layer (Menu frame with its scrim gui), hidden.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Menu", Scrim = true })
	layer.SetVisible(false)

	-- 4. Model and view.
	local Model = require(script.Parent.ResultsModel)
	local View = require(script.Parent.ResultsView)
	local model = Model.new({
		Remotes = { RaceRequest = raceRequest, RaceQueueRequest = queueRequest },
		Bindable = function(name)
			return Client._bindable(runtime, name)
		end,
		UserId = player.UserId,
		GetAttribute = function(name)
			return player:GetAttribute(name)
		end,
		OnAttribute = function(name, handler)
			local connection = player:GetAttributeChangedSignal(name):Connect(handler)
			return function()
				connection:Disconnect()
			end
		end,
		Spawn = task.spawn,
		Delay = task.delay,
		Now = os.clock,
	})
	local view = View.Mount(layer, model, scope)
	scope:connect(model.Changed, function(reason)
		view.Render(reason)
	end)
	view.Render("start")

	-- 5. The one listener (R214).
	scope:connect(raceEvent.OnClientEvent, model.Handle)

	Client.Controller = { Gui = layer.Gui, Model = model, View = view }
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
