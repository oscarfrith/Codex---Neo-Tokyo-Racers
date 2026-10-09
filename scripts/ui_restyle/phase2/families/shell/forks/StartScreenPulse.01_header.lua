-- Owns the Pulse start-screen menu (Play and Shop) over the loading view; the flow, the loading-runtime calls, the temporary config edits and the Play and Shop behaviours are carried from Classic unchanged.
-- Pulse UI (phase2). ReplicatedFirst.Loading.StartScreenPulse. Requires: Kit.Tokens, Kit.Metrics, Kit.Layers, Kit.Text, Kit.Input, Kit.Controls, Core.ConnectionScope (resolved inside Run), ReplicatedFirst.Loading.LoadingTransitionRuntime.

-- Logic-identical fork of ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient, lines 20 to 328
-- (forks/StartScreenPulse.json lists the replaced spans; everything else below is the text of that file, unindented
-- as it is there). InitialLoadingAndStartScreenClient calls Run() and returns when the Shell family is Pulse, so
-- exactly one start-screen flow calls Begin and writes StartScreenActive.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StartScreen = {}

local SURFACE = "StartScreen"
local MENU_ZINDEX = 40 -- Classic 120: above Status and ProgressTrack (22, 23)
local KIT_WAIT_SECONDS = 20
local KIT_PATH = { "Modules", "Game", "UIPulse", "Kit" }
-- Every kit module the ones used below reach through script.Parent, so none is required before it has replicated.
local KIT_MODULES = { "Sprites", "Contracts", "Tokens", "Metrics", "Layers", "Text", "Surface", "Input", "Controls" }

local kitCache
-- YIELDS on the first call only, and for at most KIT_WAIT_SECONDS per instance; then errors (a reported failed state).
local function loadKit()
	if kitCache then
		return kitCache
	end
	local folder = ReplicatedStorage
	for _, name in ipairs(KIT_PATH) do
		local child = folder:WaitForChild(name, KIT_WAIT_SECONDS)
		assert(child, "[Pulse.StartScreenPulse] " .. name .. " did not arrive under " .. folder:GetFullName())
		folder = child
	end
	for _, name in ipairs(KIT_MODULES) do
		assert(folder:WaitForChild(name, KIT_WAIT_SECONDS), "[Pulse.StartScreenPulse] Kit." .. name .. " did not arrive")
	end
	local core = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Core", KIT_WAIT_SECONDS)
	local scopeModule = core and core:WaitForChild("ConnectionScope", KIT_WAIT_SECONDS)
	assert(scopeModule, "[Pulse.StartScreenPulse] Core.ConnectionScope did not arrive")
	kitCache = {
		Tokens = require(folder.Tokens),
		Metrics = require(folder.Metrics),
		Layers = require(folder.Layers),
		Text = require(folder.Text),
		Input = require(folder.Input),
		Controls = require(folder.Controls),
		Scope = require(scopeModule),
	}
	return kitCache
end
-- Test and gallery seam: replace with a function returning the same table.
StartScreen._kit = loadKit

-- Claim refuses until ClientBase has committed the routes, which is after this screen is up. The latch publishes
-- UIStyleCommitted on its own ModuleScript; the claim is made when that turns true, never after a downgrade.
local function claimWhenCommitted(surface)
	local latchModule = ReplicatedFirst:FindFirstChild("UIStyleSwitch")
	if not latchModule then
		return
	end
	local okLatch, latch = pcall(require, latchModule)
	if not okLatch or type(latch) ~= "table" then
		return
	end
	local connection = nil
	local function try()
		if latch.Style ~= "Pulse" then
			return true
		end
		if latchModule:GetAttribute("UIStyleCommitted") ~= true then
			return false
		end
		local ok, problem = pcall(latch.Claim, surface)
		if not ok then
			warn("[Pulse.StartScreenPulse] " .. tostring(problem))
		end
		return true
	end
	if try() then
		return
	end
	connection = latchModule:GetAttributeChangedSignal("UIStyleCommitted"):Connect(function()
		if try() and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

-- The menu: kit buttons in a Menu stage on SafeRoot. Shop left, Play right and focused for pad and keyboard.
-- Regular: READY over a centred row in BottomCentre. Compact: the row in BottomRight. No portrait branch.
-- -> {Menu = stage root, Play = Component, Shop = Component, SetBusy = (busy, playText, shopText) -> ()}
function StartScreen._buildMenu(kit, safeRoot, ctx, scope, texts)
	local Tokens, Layers, Text, Input, Controls = kit.Tokens, kit.Layers, kit.Text, kit.Input, kit.Controls
	local compact = ctx.Class == "Compact"
	local stage = Layers.Stage(safeRoot, ctx, "Menu")
	stage.Root.Name = "StartScreenActions"
	stage.Root.ZIndex = MENU_ZINDEX
	scope:add(stage.Destroy)

	local slot = stage.Slot(compact and "BottomRight" or "BottomCentre")
	local holder = Instance.new("Frame")
	holder.Name = "Buttons"
	holder.AnchorPoint = slot.AnchorPoint
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Parent = slot
	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = compact and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, ctx.Px(Tokens.Space.Gap))
	list.Parent = holder

	if not compact then
		Text.Label(holder, { Name = "Ready", Text = "READY", Role = "SectionHead", Colour = "Cyan", Align = "Centre",
			Shadow = true, LayoutOrder = 1 }, scope)
	end
	-- The kept handlers further down connect to the buttons' own Activated signal, exactly as Classic does.
	local function handledByFlow() end
	local row = Controls.ButtonRow(holder, { Name = "Row", Place = "None", Align = compact and "Right" or "Centre", LayoutOrder = 2,
		Buttons = {
			{ Id = "Shop", Variant = "Default", Text = texts.Shop, Icon = "dealership", OnActivated = handledByFlow },
			{ Id = "Play", Variant = "Main", Text = texts.Play, Icon = "steering_wheel", OnActivated = handledByFlow },
		} }, scope)
	local play, shop = row.Button("Play"), row.Button("Shop")

	local focus = Input.FocusGroup(scope)
	focus.Add(shop.Instance, 1)
	focus.Add(play.Instance, 2)
	focus.Enter(play.Instance)
	if ctx.Changed then
		-- A pad or keyboard picked up after the menu appeared: give it Play.
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Input == true then
				focus.Enter(play.Instance)
			end
		end)
	end

	local function setBusy(busy, playText, shopText)
		play.Set({ Disabled = busy == true, Text = playText })
		shop.Set({ Disabled = busy == true, Text = shopText })
	end
	return { Menu = stage.Root, Play = play, Shop = shop, SetBusy = setBusy }
end

function StartScreen.Run()
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")

