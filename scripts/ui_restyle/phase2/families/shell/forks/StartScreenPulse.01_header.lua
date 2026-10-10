-- Owns the Pulse start-screen menu (logo, Play and Shop) over the loading view; the flow, the loading-runtime calls, the temporary config edits and the Play and Shop behaviours are carried from Classic unchanged.
-- Pulse UI (phase2). ReplicatedFirst.Loading.StartScreenPulse. Requires: Kit.Tokens, Kit.Metrics, Kit.Layers, Kit.Text, Kit.Input, Kit.Controls, Core.ConnectionScope (resolved inside Run), ReplicatedFirst.Loading.LoadingTransitionRuntime.

-- Logic-identical fork of ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient, lines 20 to 328
-- (forks/StartScreenPulse.json lists the replaced spans; everything else below is the text of that file, unindented
-- as it is there). InitialLoadingAndStartScreenClient calls Run() when the Shell family is Pulse and returns only when
-- Run() returned true. Run() returns false only when it stopped BEFORE Begin (kit not available, or an error ahead
-- of Begin); from Begin onwards it returns true or raises, so exactly one start-screen flow calls Begin and writes
-- StartScreenActive.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StartScreen = {}

local SURFACE = "StartScreen"
local MENU_ZINDEX = 40 -- Classic 120: above Status and ProgressTrack (22, 23)
local KIT_WAIT_SECONDS = 5 -- one budget for the whole kit, not per instance; then Run() returns false (Classic start screen)
local KIT_PATH = { "Modules", "Game", "UIPulse", "Kit" }
-- Every kit module the ones used below reach through script.Parent, so none is required before it has replicated.
local KIT_MODULES = { "Sprites", "Contracts", "Tokens", "Metrics", "Layers", "Text", "Surface", "Input", "Controls" }

local kitCache
-- YIELDS on the first call only, for at most KIT_WAIT_SECONDS in total. -> kit table, or nil and the reason; never errors.
local function loadKit()
	if kitCache then
		return kitCache
	end
	local deadline = os.clock() + KIT_WAIT_SECONDS
	local function child(parent, name)
		return parent:FindFirstChild(name) or parent:WaitForChild(name, math.max(0.05, deadline - os.clock()))
	end
	local folder = ReplicatedStorage
	for _, name in ipairs(KIT_PATH) do
		local found = child(folder, name)
		if not found then
			return nil, name .. " did not arrive under " .. folder:GetFullName()
		end
		folder = found
	end
	for _, name in ipairs(KIT_MODULES) do
		if not child(folder, name) then
			return nil, "Kit." .. name .. " did not arrive"
		end
	end
	local core = child(ReplicatedStorage.Modules, "Core")
	local scopeModule = core and child(core, "ConnectionScope")
	if not scopeModule then
		return nil, "Core.ConnectionScope did not arrive"
	end
	local ok, loaded = pcall(function()
		return {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Layers = require(folder.Layers),
			Text = require(folder.Text),
			Input = require(folder.Input),
			Controls = require(folder.Controls),
			Scope = require(scopeModule),
		}
	end)
	if not ok then
		return nil, tostring(loaded)
	end
	kitCache = loaded
	return kitCache
end
-- Test and gallery seam: replace with a function returning the same table (or nil and a reason).
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
-- Regular: READY over a centred row in BottomCentre (preview r19b). Compact: the row in BottomRight. No portrait
-- branch. The size class is read each time the screen context changes, not once: this runs at ReplicatedFirst time,
-- when the viewport may not be measured yet, and a first answer of Compact used to leave a Regular screen with the
-- Compact placement for good.
-- -> {Menu = stage root, Play = Component, Shop = Component, SetBusy = (busy, playText, shopText) -> ()}
local LOGO_DEFAULT = "rbxassetid://86895264649881" -- scripts/ui_restyle/assets/out/logo_pulse_racers.png, 1024x519
local LOGO_ASPECT = 1024 / 519
-- Start-screen motion (Oscar, 2026-10-10): one slow move that eases to a stop and then holds, never a loop. The
-- artwork pushes in and slides right; the logo grows a little and slides the other way, so the two read as layers.
local MOTION_SECONDS = 75
local ART_ZOOM = 0.09 -- added to the artwork frame's scale over the move
local ART_TRAVEL = 0.03 -- of the screen width, to the right; the zoom keeps the edges covered
local LOGO_GROW = 1.05
local LOGO_TRAVEL = 0.02 -- of the logo width, to the left

local function logoAsset()
	local node = game:GetService("ReplicatedStorage")
	for _, name in ipairs({ "Config", "UI", "Pulse", "Assets" }) do
		node = node and node:FindFirstChild(name)
	end
	local value = node and node:GetAttribute("Logo")
	if type(value) == "string" then
		return value
	end
	return LOGO_DEFAULT
end

function StartScreen._buildMenu(kit, safeRoot, ctx, scope, texts)
	local Tokens, Layers, Text, Input, Controls = kit.Tokens, kit.Layers, kit.Text, kit.Input, kit.Controls
	local stage = Layers.Stage(safeRoot, ctx, "Menu")
	stage.Root.Name = "StartScreenActions"
	stage.Root.ZIndex = MENU_ZINDEX
	scope:add(stage.Destroy)

	local holder = Instance.new("Frame")
	holder.Name = "Buttons"
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	holder.Parent = stage.Slot("BottomCentre") -- the parts below read the stage's context through it; place() seats it

	local ready = Text.Label(holder, { Name = "Ready", Text = "READY", Role = "SectionHead", Colour = "Cyan", Align = "Centre",
		Shadow = true, LayoutOrder = 1 }, scope)
	-- The kept handlers further down connect to the buttons' own Activated signal, exactly as Classic does.
	local function handledByFlow() end
	local row = Controls.ButtonRow(holder, { Name = "Row", Place = "None", Align = "Centre", LayoutOrder = 2,
		Buttons = {
			{ Id = "Shop", Variant = "Default", Text = texts.Shop, Icon = "dealership", OnActivated = handledByFlow },
			{ Id = "Play", Variant = "Main", Text = texts.Play, Icon = "steering_wheel", OnActivated = handledByFlow },
		} }, scope)
	local play, shop = row.Button("Play"), row.Button("Shop")

	-- The game logo, top right over the artwork's sky. One image; the id is Config.UI.Pulse.Assets@Logo when that
	-- attribute is set, otherwise the uploaded default. An empty attribute hides it. place() seats the holder; the
	-- image inside drifts a few pixels and breathes very slightly (two endless tweens, stopped with the scope).
	local logoHolder = Instance.new("Frame")
	logoHolder.Name = "LogoHolder"
	logoHolder.AnchorPoint = Vector2.new(1, 0)
	logoHolder.BackgroundTransparency = 1
	logoHolder.BorderSizePixel = 0
	local logoAspect = Instance.new("UIAspectRatioConstraint")
	logoAspect.AspectRatio = LOGO_ASPECT
	logoAspect.DominantAxis = Enum.DominantAxis.Height
	logoAspect.Parent = logoHolder
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.5)
	logo.Size = UDim2.fromScale(1, 1)
	logo.BackgroundTransparency = 1
	logo.BorderSizePixel = 0
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Image = logoAsset()
	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo
	logo.Parent = logoHolder
	logoHolder.Visible = logo.Image ~= ""
	logoHolder.Parent = stage.Root
	do
		local TweenService = game:GetService("TweenService")
		local info = TweenInfo.new(MOTION_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local moves = {}
		if logoHolder.Visible then
			table.insert(moves, TweenService:Create(logo, info, { Position = UDim2.fromScale(0.5 - LOGO_TRAVEL, 0.5) }))
			table.insert(moves, TweenService:Create(logoScale, info, { Scale = LOGO_GROW }))
		end
		-- The artwork frame belongs to the loading view, which holds it still on the start screen and resets it on its
		-- next Show. It is found by name beside this gui; a stage with no loading view (the gallery) has none.
		local gui = safeRoot:FindFirstAncestorOfClass("ScreenGui")
		local scrim = gui and gui.Parent and gui.Parent:FindFirstChild(gui.Name .. "Scrim")
		local art = scrim and scrim:FindFirstChild("ArtworkMotion", true)
		if art and art:IsA("GuiObject") then
			local scale = art.Size.X.Scale + ART_ZOOM
			table.insert(moves, TweenService:Create(art, info, { Position = UDim2.fromScale(0.5 + ART_TRAVEL, 0.5),
				Size = UDim2.fromScale(scale, scale) }))
		end
		for _, move in ipairs(moves) do move:Play() end
		-- Cancelled when the menu ends, so nothing is still writing the frame when the loading view next shows it.
		scope:add(function()
			for _, move in ipairs(moves) do move:Cancel() end
		end)
	end

	local function place()
		local compact = ctx.Class == "Compact"
		logoHolder.Position = UDim2.fromScale(0.975, compact and 0.04 or 0.05)
		logoHolder.Size = UDim2.fromScale(0.6, compact and 0.42 or 0.38)
		local slot = stage.Slot(compact and "BottomRight" or "BottomCentre")
		holder.AnchorPoint = slot.AnchorPoint
		list.HorizontalAlignment = compact and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, ctx.Px(Tokens.Space.Gap))
		ready.Set({ Visible = not compact })
		row.Set({ Align = compact and "Right" or "Centre" })
		holder.Parent = slot
	end
	place()

	local focus = Input.FocusGroup(scope)
	focus.Add(shop.Instance, 1)
	focus.Add(play.Instance, 2)
	focus.Enter(play.Instance)
	if ctx.Changed then
		-- A pad or keyboard picked up after the menu appeared: give it Play.
		scope:connect(ctx.Changed, function(change)
			if not (type(change) == "table" and change.Layout == false) then
				place()
			end
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

-- -> true when this flow reached Begin (it then owns the start screen to the end, including every release path);
-- false when it stopped before Begin, so the caller runs the Classic flow. An error after Begin is raised again.
function StartScreen.Run()
local began = false
local ok, problem = pcall(function()
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")
