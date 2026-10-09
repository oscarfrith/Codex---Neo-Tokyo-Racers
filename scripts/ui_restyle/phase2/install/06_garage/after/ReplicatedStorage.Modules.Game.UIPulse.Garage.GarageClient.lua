-- Owns start-up of the Pulse dealership and customise garage (the GarageUI entry): claims the surface, creates the two garage layers, builds the model, mounts the view when a page first shows, closes the session when a draw faults, listens to the three garage-open events; it does not own garage state (GarageModel), drawing (GarageScreenView), the owned-garage desk or browser, or the entrance prompts.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageClient. Requires: Layers, Perf, Presence, GarageModel, GarageScreenView, Core.ConnectionScope; shared (unchanged) GarageCatalogClient, GarageModuleCardViewModel, PresentationAudioBridge, PreviewVehicleClient, PreviewCameraClient, GarageModuleInstancePreviewAdapter, GarageVehiclePreviewProfile, VehiclePerformanceResolver, VehicleCatalog, GaragePropertyCatalog.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Kit = script.Parent.Parent.Kit
local Layers = require(Kit.Layers)
local Perf = require(Kit.Perf)
local Presence = require(Kit.Presence)
local GarageModel = require(script.Parent.GarageModel)
local GarageScreenView = require(script.Parent.GarageScreenView)

local SURFACE = "Garage"
local LAYER = "CanonicalGarageGui"
local CANVAS = "CanonicalCanvas"

local Client = {}
local state

local warned = {}
local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[Pulse.GarageClient] " .. message)
	end
end

-- GarageUI L151: the three entry events live in PlayerScripts.Runtime.Dealership and are created here when the
-- sender has not made them yet. An instance of that name that is not a BindableEvent is replaced, as in Classic.
function Client._introEvent(folder: Instance, name: string): BindableEvent
	local event = folder:FindFirstChild(name)
	if event and not event:IsA("BindableEvent") then
		event:Destroy()
		event = nil
	end
	if not event then
		local created = Instance.new("BindableEvent")
		created.Name = name
		created.Parent = folder
		event = created
	end
	return event :: BindableEvent
end

-- Pure. Wraps a render function. A fault is reported through report(message) and, unless a recovery is already
-- running, recover(done) is called once; the caller ends the session there and calls done() when it has finished.
-- Faults raised while the recovery runs (its own closing draw) are reported and start no second recovery.
-- Returns draw(reason) -> boolean.
function Client._protect(render: (any) -> (), report: (any) -> (), recover: (() -> ()) -> ()): (any) -> boolean
	local recovering = false
	return function(reason)
		local ok, message = pcall(render, reason)
		if ok then
			return true
		end
		report(message)
		if not recovering then
			recovering = true
			recover(function()
				recovering = false
			end)
		end
		return false
	end
end

-- GarageUI L696: event name -> open mode. One listener each; no other Pulse module may connect to these.
Client._entries = table.freeze({
	table.freeze({ Event = "OpenGarageFromIntro", Mode = "Dealership" }),
	table.freeze({ Event = "OpenOwnedCockpitCustomisation", Mode = "Customisation" }),
	table.freeze({ Event = "OpenDrivingVehicleCustomisation", Mode = "DriveIn" }),
})

-- Replicated Cash for the dealership tiles' muted-price state (Classic: GarageBrowserUI L34, BindReplicatedCash).
-- Read only; no wait: late leaderstats arrive through ChildAdded.
local function watchCash(player: Player, scope: any, callback: (number) -> ())
	local function bindValue(value: Instance)
		if value:IsA("IntValue") or value:IsA("NumberValue") then
			scope:connect(value.Changed, function(amount)
				callback(tonumber(amount) or 0)
			end)
			callback(tonumber(value.Value) or 0)
		end
	end
	local function bindStats(stats: Instance)
		local cash = stats:FindFirstChild("Cash")
		if cash then
			bindValue(cash)
			return
		end
		local connection
		connection = scope:connect(stats.ChildAdded, function(child)
			if child.Name == "Cash" then
				connection:Disconnect()
				bindValue(child)
			end
		end)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		bindStats(stats)
		return
	end
	local connection
	connection = scope:connect(player.ChildAdded, function(child)
		if child.Name == "leaderstats" then
			connection:Disconnect()
			bindStats(child)
		end
	end)
end

local function run()
	-- 1. Claim the surface before anything is created.
	Layers.Switch().Claim(SURFACE)

	-- 2. Resolve. The waits are the ones the Classic owner makes at its lines 1-17, 42-43 and 89 (instances that
	-- exist at start); nothing here waits on a font, an asset or a remote reply.
	local player = Players.LocalPlayer
	local modules = ReplicatedStorage:WaitForChild("Modules")
	local game_ = modules:WaitForChild("Game")
	local garage = game_:WaitForChild("Garage")
	local vehicles = game_:WaitForChild("Vehicles")
	local runtime = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime")
	local uiFolder = runtime:WaitForChild("UI")
	local dealership = runtime:WaitForChild("Dealership")
	local replacement = ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local deps = {
		Player = player,
		Workspace = Workspace,
		Remotes = {
			GarageInvoke = remotes:WaitForChild("Garage"):WaitForChild("GarageInvoke"),
			GarageSessionRequest = remotes:WaitForChild("UI"):WaitForChild("GarageSessionRequest"),
		},
		Bindables = { LoadingTransitionInvoke = uiFolder:WaitForChild("LoadingTransitionInvoke") },
		Folders = { UI = uiFolder, Dealership = dealership },
		Config = { Replacement = replacement, Artwork = replacement:FindFirstChild("ModuleArtwork") },
		CategoriesRoot = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VehiclePreviews"):WaitForChild("Categories"),
		Modules = {
			CatalogTransport = require(garage:WaitForChild("GarageCatalogClient")),
			VehicleCatalog = require(vehicles:WaitForChild("VehicleCatalog")),
			ModuleCards = require(game_:WaitForChild("UI"):WaitForChild("GarageModuleCardViewModel")),
			AudioBridge = require(game_:WaitForChild("Audio"):WaitForChild("PresentationAudioBridge")),
			PreviewVehicle = require(garage:WaitForChild("PreviewVehicleClient")),
			PreviewCamera = require(garage:WaitForChild("PreviewCameraClient")),
			InstancePreview = require(garage:WaitForChild("GarageModuleInstancePreviewAdapter")),
			PreviewProfiles = require(garage:WaitForChild("GarageVehiclePreviewProfile")),
			PerformanceResolver = require(vehicles:WaitForChild("Performance"):WaitForChild("VehiclePerformanceResolver")),
			PropertyCatalog = require(garage:WaitForChild("GaragePropertyCatalog")),
		},
		Defer = task.defer,
		Warn = warn,
		CameraGui = nil,
	}
	local ConnectionScope = require(modules:WaitForChild("Core"):WaitForChild("ConnectionScope"))
	local scope = ConnectionScope.new()

	-- 3. Layers: the static garage layer (root CanonicalCanvas, with its scrim) and the live one above it. Both
	-- are empty and the live one hidden until a page first shows. The static root stays visible and empty: the
	-- owned-garage desk parents its own root there and shows without one of our sessions.
	local layer = Layers.Create(LAYER, { Frame = "Scene", Scrim = true, RootName = CANVAS })
	local live = Layers.Create(LAYER, { Frame = "Scene", Live = true })
	live.SetVisible(false)
	deps.CameraGui = layer.Gui -- PreviewCameraClient.Update skips a disabled gui; this one is never disabled

	-- 4. Model. No instance and no remote call until an entry event arrives.
	local model = GarageModel.new(deps)
	local controller = { Model = model, View = nil, Layer = layer, Live = live, Scope = scope }

	-- 5. View: nothing is built at start. The view is mounted the first time the model has something to show,
	-- inside the protected draw below, so a kit fault (the kit throws on any unknown prop) can never fail start()
	-- and leave the entrance waiting for a listener.
	local view, viewScope = nil, nil
	local function dropView()
		local oldView, oldScope = view, viewScope
		view, viewScope, controller.View = nil, nil, nil
		if oldView then
			pcall(oldView.Destroy)
		end
		if oldScope then
			oldScope:destroy()
		end
		pcall(live.SetVisible, false)
	end
	scope:add(dropView)

	local function render(reason)
		if view == nil then
			if model.Showing() == nil and model.Modal() == nil then
				return -- closed and never drawn: both layers are still empty
			end
			viewScope = ConnectionScope.new()
			view = GarageScreenView.Mount(layer, model, viewScope, { Live = live })
			controller.View = view
			view.BindCash(player) -- records the player; the chip binds when the status strip is first built
		end
		view.Render(reason)
	end

	-- A drawing fault used to be caught and reported only: the session stayed active on the preview camera with
	-- no Exit or Drive drawn. Now the fault is warned once, then the session is ended through the model's Exit
	-- sequence (loading Begin, session End, close, loading Complete; the server clears GarageSessionActive on
	-- End) with a toast, and the broken view is released so the next entry builds a fresh one. Deferred: the
	-- fault is raised inside a model transition, which finishes first (it may still complete a loading
	-- generation).
	local draw = Client._protect(render, function(message)
		warnOnce("render", "render failed; closing the garage: " .. tostring(message))
	end, function(done)
		task.defer(function()
			local ok, message = pcall(model.Abort)
			if not ok then
				warnOnce("abort", "closing after a render fault failed: " .. tostring(message))
			end
			dropView()
			done()
		end)
	end)
	scope:add(model.Changed:Connect(draw))

	-- 6. Entry events (GarageUI L695-696). Connected before the optional parts below, so the entrance always
	-- finds its listener once start() has reached this line.
	for _, entry in ipairs(Client._entries) do
		local mode = entry.Mode
		scope:connect(Client._introEvent(dealership, entry.Event).Event, function(payload)
			model.Open(mode, payload)
		end)
	end

	-- 7. Optional parts. None of them may fail start(): each is protected and reported once.
	local function optional(name: string, body: () -> ())
		local ok, message = pcall(body)
		if not ok then
			warnOnce(name, name .. " failed: " .. tostring(message))
		end
	end

	-- GarageUI L131: the preview camera step. Kit.Perf runs it only while the live layer root shows, which is
	-- exactly while a dealership or customise page shows.
	optional("camera step", function()
		scope:add(Perf.Bind("GarageCamera", live.Root, model.CameraStep))
	end)

	optional("Cash watch", function()
		watchCash(player, scope, model.SetReplicatedCash)
	end)

	-- API2 5.7: GarageSessionActive (server-written) stays the only garage-open signal; Presence mirrors it so
	-- other Pulse owners need not poll it.
	optional("presence", function()
		local releasePresence = nil
		local function mirrorSession()
			local open = player:GetAttribute("GarageSessionActive") == true
			if open and not releasePresence then
				releasePresence = Presence.Open(SURFACE, "Garage")
			elseif not open and releasePresence then
				releasePresence()
				releasePresence = nil
			end
		end
		scope:connect(player:GetAttributeChangedSignal("GarageSessionActive"), mirrorSession)
		mirrorSession()
	end)

	Client.Controller = controller
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
