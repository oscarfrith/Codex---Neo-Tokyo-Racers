-- Owns the Pulse race-entry surface: the RaceEntryPresentation layer, the one listener on RaceEntryPresentationRequest and the wiring of model to views; it does not own spawning, queueing or staging (RaceEntryMenuClient and RaceLifecyclePresentationClient keep those).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceEntry.RaceEntryClient. Requires: Layers, Surface, Data, Presence, RaceEntryModel, SetupView, RecordsView, VehicleView, Core.ConnectionScope, Garage.GarageCatalogClient, Racing.RaceConfigReader (all resolved inside start).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SURFACE = "RaceEntry"
local LAYER_NAME = "RaceEntryPresentation"
local MISSING_WARN_SECONDS = 10

local Client = {}
local state

-- Pure. Walks `names` under `root` with FindFirstChild; nil when any step is missing. Never yields.
function Client._find(root, names)
	local current = root
	for _, name in ipairs(names) do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- The four objects Classic waits for at its lines 22, 23, 38 and 39.
local WANTED = {
	RaceRequest = { Root = "Storage", Path = { "Remotes", "Racing", "RaceRequest" } },
	GarageInvoke = { Root = "Storage", Path = { "Remotes", "Garage", "GarageInvoke" } },
	Request = { Root = "Scripts", Path = { "Runtime", "Racing", "RaceEntryPresentationRequest" } },
	LegacyAction = { Root = "Scripts", Path = { "Runtime", "Racing", "RaceEntryLegacyAction" } },
}

-- Pure. roots = {Storage = Instance, Scripts = Instance?}. Returns the found table and the list of missing keys.
function Client._resolve(roots)
	local found, missing = {}, {}
	for key, want in pairs(WANTED) do
		local instance = Client._find(roots[want.Root], want.Path)
		if instance then
			found[key] = instance
		else
			table.insert(missing, key)
		end
	end
	table.sort(missing)
	return found, missing
end

-- The same four, waited for one step at a time (only used when something was not there yet).
local function waitFor(roots)
	local found = {}
	for key, want in pairs(WANTED) do
		local current = roots[want.Root]
		for _, name in ipairs(want.Path) do
			current = current:WaitForChild(name)
		end
		found[key] = current
	end
	return found
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. Modules. None of these requires waits on an asset, a font or a remote.
	local Surface = require(kit.Surface)
	local Data = require(kit.Data)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.RaceEntryModel)
	local SetupView = require(script.Parent.SetupView)
	local RecordsView = require(script.Parent.RecordsView)
	local VehicleView = require(script.Parent.VehicleView)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()
	local catalogModule = Client._find(ReplicatedStorage, { "Modules", "Game", "Garage", "GarageCatalogClient" })
	local readerModule = Client._find(ReplicatedStorage, { "Modules", "Game", "Racing", "RaceConfigReader" })
	assert(catalogModule and readerModule, "GarageCatalogClient or RaceConfigReader is missing")
	local Catalog = require(catalogModule)
	local RaceConfig = require(readerModule)

	-- 3. The layer and its tint. Closed at start: the root is hidden, nothing is built until the first open.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local layer = Layers.Create(LAYER_NAME, { Frame = "Menu", Scrim = true })
	if layer.ScrimRoot then
		Surface.Scrim(layer.ScrimRoot, { Kind = "Menu" }, scope)
	end
	layer.SetVisible(false)

	-- 4. Model and views, wired once the Classic objects are known.
	local function wire(found)
		local config = ReplicatedStorage:FindFirstChild("Config")
		local model = Model.new({
			Remotes = { RaceRequest = found.RaceRequest, GarageInvoke = found.GarageInvoke },
			Bindables = {
				LegacyAction = found.LegacyAction,
				PresentationMode = function()
					local event = Client._find(player, { "PlayerScripts", "Runtime", "UI", "FreeRoamHudPresentationMode" })
					return (event and event:IsA("BindableEvent")) and event or nil
				end,
			},
			Catalog = Catalog,
			RaceConfig = RaceConfig,
			Money = function(amount)
				return Data.Money(amount, false)
			end,
			UserId = player.UserId,
			RaceRewards = Client._find(config, { "Racing", "Rewards", "Race" }),
			RaceCatalogEvent = function(eventId)
				return Client._find(config, { "Racing", "RaceCatalog", eventId })
			end,
			Copy = function(name)
				local value = Client._find(config, { "UI", "Racing", "Copy", name })
				return (value and value:IsA("StringValue")) and value.Value or nil
			end,
			PreviewCategories = function()
				return Client._find(ReplicatedStorage, { "Assets", "VehiclePreviews", "Categories" })
			end,
			Presence = Presence,
			Spawn = task.spawn,
		})
		local views = {
			SetupView.Mount(layer, model, scope),
			RecordsView.Mount(layer, model, scope),
			VehicleView.Mount(layer, model, scope),
		}

		-- One render for the screen. Each view takes the model's snapshot for the current revision and draws
		-- nothing from an overtaken one, so a late reply never draws into a newer page.
		local shown = false
		local warned = false
		local function render(reason)
			local ok, problem = pcall(function()
				for _, view in ipairs(views) do
					view.Render(reason)
				end
			end)
			local open = model.IsOpen()
			if not ok then
				if not warned then
					warned = true
					warn("[Pulse.RaceEntryClient] render failed: " .. tostring(problem))
				end
				-- A page that cannot be drawn must not hold the player: leave as EXIT does.
				if open then
					model.Exit()
				end
				open = model.IsOpen()
			end
			if open ~= shown then
				shown = open
				layer.SetVisible(open)
			end
		end
		scope:connect(model.Changed, render)
		scope:connect(found.Request.Event, function(entryPayload)
			model.Open(entryPayload)
		end)
		Client.Controller = { Gui = layer.Gui, Model = model, Render = render }
	end

	local roots = { Storage = ReplicatedStorage, Scripts = player:FindFirstChild("PlayerScripts") }
	local found, missing = Client._resolve(roots)
	if #missing == 0 then
		wire(found)
	else
		-- Start does not wait for them. They are Studio-authored and normally present; if one is late the
		-- screen is wired when it arrives, and a missing one is reported once instead of hanging the entry.
		local wired = false
		task.spawn(function()
			roots.Scripts = roots.Scripts or player:WaitForChild("PlayerScripts")
			local late = waitFor(roots)
			wired = true
			wire(late)
		end)
		task.delay(MISSING_WARN_SECONDS, function()
			if not wired then
				warn("[Pulse.RaceEntryClient] race entry is not wired; still waiting for: " .. table.concat(missing, ", "))
			end
		end)
	end
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
