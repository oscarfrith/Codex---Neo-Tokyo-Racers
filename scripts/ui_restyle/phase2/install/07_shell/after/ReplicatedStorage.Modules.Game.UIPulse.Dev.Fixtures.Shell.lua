-- Owns the gallery items for the Shell family (onboarding callout and objective cards, loading view, start-screen menu); no game state, remote, profile or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Shell. Requires: Tokens, Layers, Text, Input, Controls, Metrics, Shell.OnboardingModel (static tables), Shell.OnboardingView, ReplicatedFirst.Loading.LoadingScreenViewPulse, ReplicatedFirst.Loading.StartScreenPulse (all resolved on the first mount).
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local cache
local function modules()
	if not cache then
		local pulse = script.Parent.Parent.Parent
		local kit = pulse.Kit
		cache = {
			Tokens = require(kit.Tokens),
			Metrics = require(kit.Metrics),
			Layers = require(kit.Layers),
			Text = require(kit.Text),
			Input = require(kit.Input),
			Controls = require(kit.Controls),
			Model = require(pulse.Shell.OnboardingModel),
			View = require(pulse.Shell.OnboardingView),
		}
	end
	return cache
end

local function loadingModule(name)
	local folder = ReplicatedFirst:FindFirstChild("Loading")
	local module = folder and folder:FindFirstChild(name)
	assert(module, "ReplicatedFirst.Loading." .. name .. " is not installed")
	return require(module)
end

local function checkKeys(item, allowed, patch)
	assert(type(patch) == "table", item .. " fixture expects a table")
	for key in pairs(patch) do
		if not allowed[key] then error(string.format("%s fixture: unknown key '%s'", item, tostring(key)), 3) end
	end
end

local function stageOf(parent)
	return parent:FindFirstAncestor("Stage") or parent
end

local function newSignal()
	local handlers = {}
	local signal = {}
	function signal.Connect(_, handler)
		local connection = {}
		handlers[connection] = handler
		function connection.Disconnect()
			handlers[connection] = nil
		end
		return connection
	end
	function signal.Fire(_, ...)
		for _, handler in pairs(table.clone(handlers)) do handler(...) end
	end
	return signal
end

-- A canned stand-in for Shell.OnboardingModel: the getters the view reads, nothing else. The real model's pure
-- rules are borrowed for the hint text so no player-facing string is typed twice.
local function fakeModel(Model, props, target)
	local model = { GateOpen = props.Gate ~= false, ActivePage = props.Page, ActiveIndex = props.Index or 1,
		ActiveObjects = props.Page and { target } or nil, Order = props.Order or {}, Changed = newSignal(),
		State = { SeenPages = {}, Completed = { FirstVehiclePurchased = props.Purchased == true } } }
	function model:CardId()
		local page = self.ActivePage and Model.Pages[self.ActivePage]
		return page and page[self.ActiveIndex] or nil
	end
	function model:IsAction()
		return Model.ActionSteps[self:CardId() or ""] == true
	end
	function model:CalloutVisible()
		return self.GateOpen and self.ActivePage ~= nil and self.ActiveObjects ~= nil
	end
	function model:ObjectivesVisible()
		return self.GateOpen and #self.Order > 0
	end
	function model:ObjectiveOrder()
		return self.Order
	end
	function model:ObjectiveHint(index)
		return Model.ObjectiveHint(self, index)
	end
	function model:Advance()
		if not self.ActivePage then return end
		self.ActiveIndex = self.ActiveIndex % #Model.Pages[self.ActivePage] + 1
		self.ActiveObjects = { target }
		self.Changed:Fire("Callout")
	end
	function model:TargetLost() end
	function model:ActionActivated()
		self:Advance()
	end
	return model
end

local ONBOARDING_KEYS = { Page = true, Index = true, Corner = true, Order = true, Purchased = true, Gate = true }

local function mountOnboarding(parent, props, scope, ctx)
	local m = modules()
	checkKeys("Shell.Onboarding", ONBOARDING_KEYS, props)
	local Space = m.Tokens.Space
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Bare")
	layer.Root.Name = "OnboardingFixture"

	-- The thing the callout points at: one kit button placed where a real target of that page would sit.
	local target = m.Controls.Button(layer.Root, { Name = "FixtureTarget", Variant = "Default", Text = "TARGET",
		OnActivated = function() end }, scope)
	local margin = ctx.Px(Space.MenuMargin)
	local width, height = math.floor(ctx.Size.X), math.floor(ctx.Size.Y)
	local targetWidth, targetHeight = ctx.Px(Space.StepperWidth), ctx.Px(Space.ButtonHeight)
	local corner = props.Corner or "TopRight"
	local x, y = width - margin - targetWidth, ctx.Px(Space.RightColumnTop)
	if corner == "BottomLeft" then
		x, y = margin, height - margin - targetHeight
	elseif corner == "BottomRight" then
		y = height - margin - targetHeight
	elseif corner == "Centre" then
		x, y = math.floor((width - targetWidth) / 2), math.floor((height - targetHeight) / 2)
	end
	target.Instance.Position = UDim2.fromOffset(x, y)
	target.Instance.Visible = props.Page ~= nil

	local model = fakeModel(m.Model, props, target.Instance)
	local view = m.View.Mount(layer, model, scope)
	local connection = model.Changed:Connect(function(reason)
		view.Render(reason)
	end)

	local component = { Instance = layer.Root }
	function component.Set(patch)
		checkKeys("Shell.Onboarding", ONBOARDING_KEYS, patch)
		if patch.Order ~= nil then model.Order = patch.Order end
		if patch.Gate ~= nil then model.GateOpen = patch.Gate ~= false end
		if patch.Purchased ~= nil then model.State.Completed.FirstVehiclePurchased = patch.Purchased == true end
		if patch.Index ~= nil then model.ActiveIndex = patch.Index end
		view.Render("Fixture")
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		connection.Disconnect()
		view.Destroy()
		target.Destroy()
		layer.Destroy()
	end
	return component
end

local LOADING_KEYS = { Status = true, Progress = true }

local function mountLoading(parent, props, _scope, ctx)
	local m = modules()
	checkKeys("Shell.Loading", LOADING_KEYS, props)
	local LoadingView = loadingModule("LoadingScreenViewPulse")
	local stage = stageOf(parent)
	local holder = Instance.new("Frame")
	holder.Name = "LoadingFixture"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = stage
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = holder
	local safeRoot = Instance.new("Frame")
	safeRoot.Name = "SafeRoot"
	safeRoot.BackgroundTransparency = 1
	safeRoot.BorderSizePixel = 0
	safeRoot.Size = UDim2.fromScale(1, 1)
	safeRoot.Parent = holder

	local config = {}
	function config:GetAttribute(_name)
		return nil -- every loading setting falls back to its code default; no artwork is requested
	end
	local view = LoadingView._mount({ Tokens = m.Tokens, Metrics = m.Metrics, Layers = m.Layers, Text = m.Text }, safeRoot,
		background, ctx, config, function(visible)
			holder.Visible = visible
		end)
	view:Show(props.Status)
	view:SetProgressImmediate(props.Progress or 0)

	local component = { Instance = holder }
	function component.Set(patch)
		checkKeys("Shell.Loading", LOADING_KEYS, patch)
		if patch.Status ~= nil then view:SetStatus(patch.Status) end
		if patch.Progress ~= nil then view:SetProgressImmediate(patch.Progress) end
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		view:Destroy()
		holder:Destroy()
	end
	return component
end

local START_KEYS = { Busy = true, PlayText = true, ShopText = true }
local PLAY_TEXT, SHOP_TEXT = "PLAY", "SHOP" -- the Classic defaults (StartScreenPlayText, StartScreenShopText)

local function mountStartScreen(parent, props, scope, ctx)
	local m = modules()
	checkKeys("Shell.StartScreen", START_KEYS, props)
	local StartScreen = loadingModule("StartScreenPulse")
	local built = StartScreen._buildMenu({ Tokens = m.Tokens, Metrics = m.Metrics, Layers = m.Layers, Text = m.Text,
		Input = m.Input, Controls = m.Controls }, stageOf(parent), ctx, scope, { Play = PLAY_TEXT, Shop = SHOP_TEXT })
	local state = table.clone(props)
	local function apply()
		built.SetBusy(state.Busy == true, state.PlayText or PLAY_TEXT, state.ShopText or SHOP_TEXT)
	end
	apply()
	local component = { Instance = built.Menu }
	function component.Set(patch)
		checkKeys("Shell.StartScreen", START_KEYS, patch)
		for key, value in pairs(patch) do state[key] = value end
		apply()
	end
	local destroyed = false
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		built.Menu:Destroy()
	end
	return component
end

return {
	{
		Id = "Shell.Onboarding",
		Frame = "Hud",
		States = {
			{ Id = "CalloutShortcut", Props = { Page = "GarageShortcut", Corner = "TopRight", Order = { 2 } } },
			{ Id = "CalloutLongest", Props = { Page = "PaintShop", Corner = "Centre" } },
			{ Id = "CalloutFourCards", Props = { Page = "TimeTrialSetup", Index = 3, Corner = "TopRight" } },
			{ Id = "CalloutAction", Props = { Page = "RaceBrowser", Index = 2, Corner = "BottomRight" } },
			{ Id = "CalloutLowTarget", Props = { Page = "GarageHome", Corner = "BottomLeft" } },
			{ Id = "ObjectiveOne", Props = { Order = { 1 } } },
			{ Id = "ObjectiveOneAfterPurchase", Props = { Order = { 1 }, Purchased = true } },
			{ Id = "ObjectivesTwoAndThree", Props = { Order = { 2, 3 } } },
			{ Id = "Empty", Props = {} },
			{ Id = "HiddenByLoading", Props = { Page = "Dealership", Order = { 1 }, Gate = false } },
		},
		Mount = mountOnboarding,
	},
	{
		Id = "Shell.Loading",
		Frame = "Bare",
		States = {
			{ Id = "LoadingWorld", Props = { Status = "LOADING WORLD", Progress = 0.64 } },
			{ Id = "Begin", Props = { Status = "LOADING PULSE RACERS", Progress = 0.02 } },
			{ Id = "Longest", Props = { Status = "TRAVELLING TO DEALERSHIP", Progress = 0.94 } },
			{ Id = "TimedOut", Props = { Status = "TRANSITION TIMED OUT", Progress = 0.98 } },
			{ Id = "Ready", Props = { Status = "READY", Progress = 1 } },
		},
		Mount = mountLoading,
	},
	{
		Id = "Shell.StartScreen",
		Frame = "Menu",
		States = {
			{ Id = "Ready", Props = {} },
			{ Id = "Entering", Props = { Busy = true, PlayText = "ENTERING" } },
			{ Id = "Travelling", Props = { Busy = true, ShopText = "TRAVELLING" } },
			{ Id = "ShopFailed", Props = { Busy = false, ShopText = "SHOP - TRY AGAIN" } },
		},
		Mount = mountStartScreen,
	},
}
