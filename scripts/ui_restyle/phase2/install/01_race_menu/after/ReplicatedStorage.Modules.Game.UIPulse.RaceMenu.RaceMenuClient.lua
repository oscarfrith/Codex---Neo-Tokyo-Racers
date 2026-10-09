-- Owns the Pulse race menu surface: the RaceBrowser layer, the one OpenRaceBrowser listener and the wiring of model and view; it does not own the HUD button that fires the event, the server teleport, the route guide or any Classic race browser.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuClient. Requires: Layers, Input, Data, Presence, RaceMenuModel, RaceMenuView, Core.ConnectionScope, Racing.RaceConfigReader, UI.RouteGuide (all resolved inside start).
--
-- Line numbers in comments refer to the Classic race browser source that API2 5.2 names.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SURFACE = "RaceBrowser" -- claim name (API2 6.2), layer name and DisplayOrder row 170 (459-463)
local OPEN_EVENT = "OpenRaceBrowser" -- 31
local RESOLVE_TIMEOUT = 5 -- seconds per hop; Classic waits without a limit (20-34), start() here never does

local Client = {}
local state

local warned = {}
local function warnOnce(message)
	if not warned[message] then
		warned[message] = true
		warn("[Pulse.RaceMenuClient] " .. message)
	end
end

-- Walks `names` from `root`, waiting at most RESOLVE_TIMEOUT for each hop. nil (and one warning) when a hop is
-- missing; never errors. Exposed for the pure test.
function Client._resolve(root, names, timeout)
	local current = root
	for _, name in ipairs(names) do
		if current == nil then
			break
		end
		local found = current:FindFirstChild(name)
		if not found and (timeout or 0) > 0 then
			found = current:WaitForChild(name, timeout)
		end
		current = found
	end
	if current == nil then
		warnOnce("could not find " .. table.concat(names, "."))
	end
	return current
end

-- require() of a shared look-free module (API2 5.2); nil and one warning when it is missing or fails.
function Client._shared(moduleScript)
	if moduleScript == nil then
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if ok then
		return result
	end
	warnOnce("require failed: " .. tostring(result))
	return nil
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim the surface before anything is created.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	-- 2. Resolve what the Classic owner resolves at 14-34. Bounded: a missing piece degrades, it never blocks.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui") -- 15
	local Input = require(kit.Input)
	local Data = require(kit.Data)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.RaceMenuModel)
	local View = require(script.Parent.RaceMenuView)
	local ConnectionScope = require(ReplicatedStorage.Modules.Core.ConnectionScope)

	local gameModules = Client._resolve(ReplicatedStorage, { "Modules", "Game" }, RESOLVE_TIMEOUT)
	local RaceConfigReader = Client._shared(Client._resolve(gameModules, { "Racing", "RaceConfigReader" }, RESOLVE_TIMEOUT)) -- 22
	local RouteGuide = Client._shared(Client._resolve(gameModules, { "UI", "RouteGuide" }, RESOLVE_TIMEOUT)) -- 24
	local runtime = Client._resolve(player, { "PlayerScripts", "Runtime" }, RESOLVE_TIMEOUT) -- 29
	local runtimeUi = Client._resolve(runtime, { "UI" }, RESOLVE_TIMEOUT) -- 30
	local teleportInvoke = Client._resolve(ReplicatedStorage, { "Remotes", "Racing", "RaceBrowserTeleportInvoke" }, RESOLVE_TIMEOUT) -- 33
	local racingConfig = Client._resolve(ReplicatedStorage, { "Config", "Racing" }, RESOLVE_TIMEOUT) -- 34

	local scope = ConnectionScope.new()

	-- 3. Layer. Open state is the root Visible; ScreenGui.Enabled is never written.
	local layer = Layers.Create(SURFACE, { Frame = "Menu", Scrim = true })

	-- 4. Model. Bindables are looked up when fired, as Classic does (384, 389, 399, 452).
	local model = Model.new({
		RacingConfig = racingConfig,
		RaceConfigReader = RaceConfigReader,
		RouteGuide = RouteGuide,
		TeleportInvoke = teleportInvoke,
		FindBindable = function(folderName, name)
			local folder = runtime and runtime:FindFirstChild(folderName)
			return folder and folder:FindFirstChild(name) or nil
		end,
		Money = function(amount)
			return Data.Money(amount, false)
		end,
		Presence = Presence,
		Wait = task.wait,
		Spawn = task.spawn,
	})

	-- 5. View, hidden.
	local view = View.Mount(layer, model, scope)
	layer.SetVisible(false)

	-- 6. Input that exists only while the menu is open (new in Pulse, API2 5.2): Escape and ButtonB go back or
	-- close; the bumpers step through the filter tabs. Released on close so nothing is taken from driving.
	local openScope = nil
	local function syncOpenInput()
		local isOpen = model.IsOpen()
		if isOpen and not openScope then
			local opened = ConnectionScope.new()
			openScope = opened
			Input.BindBack(opened, function()
				model.Back()
			end)
			-- The filter tabs show on the list page only (the Compact detail page has none).
			Input.BindBumpers(opened, function()
				if model.Page() == "List" then
					model.CycleFilter(-1)
				end
			end, function()
				if model.Page() == "List" then
					model.CycleFilter(1)
				end
			end)
		elseif not isOpen and openScope then
			local closing = openScope
			openScope = nil
			closing:destroy()
		end
	end
	scope:connect(model.Changed, function(reason)
		if reason == "Open" then
			local ok, problem = pcall(syncOpenInput)
			if not ok then
				warnOnce("open input failed: " .. tostring(problem))
			end
		end
	end)
	scope:add(function()
		if openScope then
			openScope:destroy()
			openScope = nil
		end
	end)

	-- 7. The one listener on OpenRaceBrowser (606-608). If the bindable is late it is connected when it appears;
	-- start() does not wait for it.
	local function connectOpen(event)
		scope:connect(event.Event, function()
			model.Toggle()
		end)
	end
	local openEvent = runtimeUi and Client._resolve(runtimeUi, { OPEN_EVENT }, RESOLVE_TIMEOUT) -- 31
	if openEvent and openEvent:IsA("BindableEvent") then
		connectOpen(openEvent)
	else
		scope:task(function()
			local folder = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
			local late = folder:WaitForChild(OPEN_EVENT)
			if late:IsA("BindableEvent") then
				connectOpen(late)
			end
		end)
	end

	Client.Controller = {
		Gui = layer.Gui,
		Layer = layer,
		Model = model,
		View = view,
		Scope = scope,
	}

	-- 8. Neither of these can block or fail start: the cash chip binding and the first money format both reach
	-- the shared Foundation, which may yield once (API2 3.5).
	view.BindCash(player)
	task.spawn(function()
		local ok, problem = pcall(Data.Money, 0, false)
		if not ok then
			warnOnce("Data.Money warm-up failed: " .. tostring(problem))
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
