-- Owns the Pulse toast surface: the ShowTopNotification bindable and the SharedTopNotification layer; not the callers that fire it, nor any Classic toast.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Toasts.ToastClient. Requires: Layers, Text, Overlay, Routes, Core.ConnectionScope (all resolved inside start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BINDABLE_NAME = "ShowTopNotification"
local LAYER_NAME = "SharedTopNotification"
local FAMILY = "Toasts"

local Client = {}
local state

-- Adopts the bindable. It is Studio-authored (StarterPlayerScripts.Runtime.UI), so it is already there; one is made
-- only if it is truly absent, and never a second one. Exposed for the pure test only.
function Client._bindable(folder)
	local event = folder:FindFirstChild(BINDABLE_NAME) or Instance.new("BindableEvent")
	event.Name = BINDABLE_NAME
	event.Parent = folder
	return event
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(FAMILY)

	-- 2. The bindable, after the same two waits Classic makes. It already exists (Studio-authored), so the two
	-- Classic HUD modules that wait for it at module load never depend on this owner having started.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local runtimeUi = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
	local event = Client._bindable(runtimeUi)

	-- 3. The rest of the kit. None of these requires yields.
	local Text = require(kit.Text)
	local Overlay = require(kit.Overlay)
	local Routes = require(pulse.Routes)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 4. Layer, component, connection. No yield between adopting the bindable and connecting it.
	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud" })
	local toast = Overlay.Toast(layer.Slot("TopCentre"), {}, scope)
	scope:connect(event.Event, function(message, duration)
		toast.Show(message, duration)
	end)

	Client.Controller = {
		Gui = layer.Gui,
		Show = toast.Show,
		Relayout = toast.Relayout,
		Count = toast.Count,
		Instance = toast.Instance,
		Set = toast.Set,
		Destroy = toast.Destroy,
	}

	-- 5. Neither of these can block or fail start.
	task.spawn(function()
		local ok, err = pcall(Text.Preload)
		if not ok then warn("[Pulse.ToastClient] Text.Preload failed: " .. tostring(err)) end
	end)
	task.spawn(function()
		local ok, err = pcall(Routes.StartWatch)
		if not ok then warn("[Pulse.ToastClient] Routes.StartWatch failed: " .. tostring(err)) end
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
