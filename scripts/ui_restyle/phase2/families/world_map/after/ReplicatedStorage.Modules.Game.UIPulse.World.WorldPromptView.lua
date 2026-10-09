-- Owns how world prompts are drawn under Pulse (a local Style = Custom on known prompts, one screen-anchored banner per showing prompt, the race event card); never a prompt's Enabled, its Triggered handling, the action it performs, or any prompt it does not know.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.World.WorldPromptView. Requires: Layers, Overlay, Presence, World.WorldPromptModel, World.EventCardView, Core.ConnectionScope (all resolved inside start).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SURFACE = "WorldPrompts"
local PROMPT_LAYER = "PulseWorldPrompts"
local CARD_LAYER = "PulseEventCard"
local ROOT_WAIT = 60 -- seconds a scoped root may take to appear before it is given up, off the start thread

-- The scoped roots under Workspace.World that hold every known prompt (API2 5.4). World.Dealership holds the three
-- client-made entrance prompts; the passenger and job prompts hang from vehicles in Runtime.PlayerVehicles.
local ROOTS = {
	{ "RaceRoutes" },
	{ "Runtime", "PlayerVehicles" },
	{ "Interiors", "OwnedGarageInstances" },
	{ "OwnedGarageExteriors" },
	{ "Dealership" },
}

local Client = {}
local state

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.WorldPromptView] " .. message)
end

-- The model that owns the vehicle a prompt hangs from: the nearest ancestor Model carrying OwnerUserId. Event time only.
function Client._owner(instance: Instance?): (number?, Instance?)
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local owner = tonumber(current:GetAttribute("OwnerUserId"))
			if owner then
				return owner, current
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit

	-- 1. Claim first.
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local Overlay = require(kit.Overlay)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.WorldPromptModel)
	local EventCardView = require(script.Parent.EventCardView)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- 2. The banner host and the card exist before any prompt is made Custom (PC 7.2 fail-safe).
	local promptLayer = Layers.Create(PROMPT_LAYER, { Frame = "Hud" })
	local cardLayer = Layers.Create(CARD_LAYER, { Frame = "Hud" })
	local stack = Overlay.PromptStack(promptLayer.Slot("PromptStack"), {}, scope)

	-- The local player's own vehicle, when seated in one: its tier and rating go on the event card.
	local function ownVehicle()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local owner, vehicle = Client._owner(humanoid and humanoid.SeatPart)
		if owner == player.UserId then
			return vehicle
		end
		return nil
	end

	local model = Model.new({
		Presence = Presence,
		LocalUserId = player.UserId,
		Facts = function(prompt, family)
			local facts = { Visitor = player:GetAttribute("OwnedGarageVisitor") == true }
			if family == "EnterVehicle" then
				facts.OwnerUserId = Client._owner(prompt.Parent)
			end
			return facts
		end,
		RaceRequest = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local racing = remotes and remotes:FindFirstChild("Racing")
			local remote = racing and racing:FindFirstChild("RaceRequest")
			return remote and remote:IsA("RemoteFunction") and remote or nil
		end,
		Spawn = task.spawn,
	})
	local card = EventCardView.Mount(cardLayer, model, scope)

	local engineShowing = setmetatable({}, { __mode = "k" }) -- prompt -> true while the engine says it shows
	local showing = {} -- prompt -> { Connections, Banner } while our banner is up
	local cardPrompt

	-- Integrator diagnostics on the PulseWorldPrompts ScreenGui, written only on change: how many banners are up,
	-- and the last banner or handler error.
	local diagnosticGui = promptLayer.Gui
	local shownCount, lastError = 0, ""
	local function writeDiagnostic(name, value)
		if diagnosticGui and diagnosticGui:GetAttribute(name) ~= value then
			pcall(diagnosticGui.SetAttribute, diagnosticGui, name, value)
		end
	end
	local function countShown(delta)
		shownCount = math.max(0, shownCount + delta)
		writeDiagnostic("PulseShownPrompts", shownCount)
	end
	local function noteError(message)
		lastError = string.sub(tostring(message), 1, 200)
		writeDiagnostic("PulseLastPromptError", lastError)
	end
	writeDiagnostic("PulseShownPrompts", shownCount)
	writeDiagnostic("PulseLastPromptError", lastError)

	local function setStyle(prompt, style): boolean
		return (pcall(function()
			if prompt.Style ~= style then
				prompt.Style = style
			end
		end))
	end

	local function hideBanner(prompt, record)
		local entry = showing[prompt]
		if entry then
			showing[prompt] = nil
			for _, connection in entry.Connections do
				connection:Disconnect()
			end
			countShown(-1)
		end
		pcall(stack.Hide, record.Id)
		if cardPrompt == prompt then
			cardPrompt = nil
			pcall(card.Hide)
		end
	end

	-- The per-prompt fail-safe: back to the engine's own prompt UI, and never touched again.
	local function fail(prompt, record, reason)
		warnOnce("a banner failed and its prompt is left to the engine (" .. tostring(prompt.Name) .. "): " .. tostring(reason))
		noteError(tostring(prompt.Name) .. ": " .. tostring(reason))
		model:Apply(prompt, "Fail")
		if record then
			hideBanner(prompt, record)
		end
		setStyle(prompt, Enum.ProximityPromptStyle.Default)
	end

	local function showCard(prompt)
		local zone = prompt.Parent
		if not zone then
			return
		end
		local eventId = zone:GetAttribute("EventId")
		if type(eventId) ~= "string" or eventId == "" then
			return
		end
		local mode = tostring(zone:GetAttribute("Mode") or "TimeTrial") == "Race" and "Race" or "TimeTrial"
		local vehicle = ownVehicle()
		local tier = vehicle and vehicle:GetAttribute("PerformanceTier")
		tier = type(tier) == "string" and string.upper(tier) or ""
		cardPrompt = prompt
		card.Show({
			EventId = eventId,
			Mode = mode,
			RouteId = zone:GetAttribute("RouteId"),
			Tier = tier,
			Rating = vehicle and tonumber(vehicle:GetAttribute("PerformanceIndex")) or nil,
		})
		local key = Model.EventKey(eventId, mode)
		model:FetchEvent(eventId, mode, tier, function(entry)
			card.Update(key, entry)
		end)
	end

	local function showBanner(prompt, record)
		local ok, reason = pcall(function()
			local function props()
				local result = Model.BannerProps(record.Family, prompt)
				-- Touch: the banner is the button, and the engine fires the same Triggered the owner already handles.
				result.OnPress = function()
					pcall(function()
						prompt:InputHoldBegin()
					end)
				end
				result.OnRelease = function()
					pcall(function()
						prompt:InputHoldEnd()
					end)
				end
				return result
			end
			local banner = stack.Show(record.Id, props())
			assert(banner, "the prompt stack gave no banner")
			local function update()
				if showing[prompt] then
					local updated, message = pcall(function()
						stack.Show(record.Id, props())
					end)
					if not updated then
						fail(prompt, record, message)
					end
				end
			end
			local connections = {
				prompt:GetPropertyChangedSignal("ActionText"):Connect(update),
				prompt:GetPropertyChangedSignal("ObjectText"):Connect(update),
				prompt.PromptButtonHoldBegan:Connect(function()
					pcall(banner.SetProgress, 1)
				end),
				prompt.PromptButtonHoldEnded:Connect(function()
					pcall(banner.SetProgress, 0)
				end),
			}
			showing[prompt] = { Connections = connections, Banner = banner }
		end)
		if not ok then
			fail(prompt, record, reason)
			return
		end
		countShown(1)
		if record.Family == "RaceEntry" then
			-- The card is an extra: its failure never costs the banner.
			local cardOk, cardReason = pcall(showCard, prompt)
			if not cardOk then
				warnOnce("the event card failed: " .. tostring(cardReason))
				noteError("event card: " .. tostring(cardReason))
			end
		end
	end

	local function perform(prompt, record, effect)
		if effect == "Custom" then
			if not setStyle(prompt, Enum.ProximityPromptStyle.Custom) then
				fail(prompt, record, "Style could not be set")
			end
		elseif effect == "Show" then
			showBanner(prompt, record)
		elseif effect == "Hide" then
			hideBanner(prompt, record)
		end
	end

	local function guarded(handler)
		return function(...)
			local ok, reason = pcall(handler, ...)
			if not ok then
				warnOnce("a prompt handler failed: " .. tostring(reason))
				noteError("handler: " .. tostring(reason))
			end
		end
	end

	-- 3. Discovery: scoped listeners only. A prompt the engine is already drawing is left alone until it hides.
	local function onAdded(instance)
		if not instance:IsA("ProximityPrompt") or model:Record(instance) or not Model.Classify(instance.Name) then
			return
		end
		local effect, record = model:Apply(instance, engineShowing[instance] and "TrackShowing" or "Track")
		perform(instance, record, effect)
	end
	local function onRemoving(instance)
		if instance:IsA("ProximityPrompt") then
			local record = model:Record(instance)
			if record then
				hideBanner(instance, record)
				model:Forget(instance)
			end
		end
	end

	-- 4. Showing and hiding follow the engine's own signals; nothing here runs per frame.
	scope:connect(ProximityPromptService.PromptShown, guarded(function(prompt)
		engineShowing[prompt] = true
		local custom = prompt.Style == Enum.ProximityPromptStyle.Custom
		local record = model:Record(prompt)
		if not record then
			-- A known prompt outside the scoped roots, or one that showed before its root was found.
			if not Model.Classify(prompt.Name) then
				return
			end
			local _, tracked = model:Apply(prompt, "TrackShowing")
			record = tracked
			if not record or not custom then
				return -- the engine draws it; it is made ours when it hides
			end
			-- Already Custom (ours): nothing else draws it, so it gets its banner now.
		end
		local effect = model:Apply(prompt, custom and "Shown" or "ShownDefault")
		perform(prompt, record, effect)
		-- The fail-safe: a Custom prompt the engine shows has a banner or a rule that hides it, or goes back to Default.
		if custom and record.State ~= "Shown" and record.State ~= "Suppressed" and record.State ~= "Failed" then
			fail(prompt, record, "shown as Custom with no banner (state " .. tostring(record.State) .. ")")
		elseif record.State == "Shown" and not showing[prompt] then
			fail(prompt, record, "state Shown with no banner")
		end
	end))
	scope:connect(ProximityPromptService.PromptHidden, guarded(function(prompt)
		engineShowing[prompt] = nil
		local record = model:Record(prompt)
		if record then
			local effect = model:Apply(prompt, "Hidden")
			perform(prompt, record, effect)
			-- Records are held strongly: one for a prompt that has left the game (outside the scoped roots) is dropped here.
			if not prompt:IsDescendantOf(game) then
				hideBanner(prompt, record)
				model:Forget(prompt)
			end
		end
	end))

	local function refresh()
		for _, change in model:Refresh() do
			perform(change.Prompt, change.Record, change.Effect)
		end
	end
	scope:connect(Presence.Changed, guarded(refresh))
	scope:connect(player:GetAttributeChangedSignal("OwnedGarageVisitor"), guarded(refresh))

	scope:add(function()
		for prompt, entry in showing do
			for _, connection in entry.Connections do
				connection:Disconnect()
			end
			showing[prompt] = nil
		end
		shownCount = 0
		writeDiagnostic("PulseShownPrompts", 0)
	end)

	-- 5. The roots are found off the start thread, each on its own, so start never waits on the world streaming in.
	local function watchRoot(world, path)
		local root = world
		for _, name in path do
			root = root:WaitForChild(name, ROOT_WAIT)
			if not root then
				warnOnce("Workspace.World." .. table.concat(path, ".") .. " was not found; its prompts stay engine-drawn")
				return
			end
		end
		local safeAdded = guarded(onAdded)
		scope:connect(root.DescendantAdded, safeAdded)
		scope:connect(root.DescendantRemoving, guarded(onRemoving))
		for _, descendant in root:GetDescendants() do
			safeAdded(descendant)
		end
	end
	scope:task(function()
		local world = Workspace:WaitForChild("World", ROOT_WAIT)
		if not world then
			warnOnce("Workspace.World was not found; every prompt stays engine-drawn")
			return
		end
		for _, path in ROOTS do
			scope:task(watchRoot, world, path)
		end
	end)

	Client.Controller = { Model = model, Stack = stack, Card = card, PromptLayer = promptLayer, CardLayer = cardLayer, Scope = scope }
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
