-- Owns Pulse ScreenGui creation, the DisplayOrder ladder, composition frames and anchored slots; owns no screen content and never switches a gui on or off.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers. Requires: Tokens, Metrics, Contracts.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Contracts = require(script.Parent.Contracts)

local Layers = {}

-- Today's Classic numbers, reused. A <name>Scrim or <name>Live row is added here by the phase that needs
-- one where the default (one lower, one higher) would land on another row.
Layers.Order = {
	CanonicalGarageGui = 40,
	OwnedGarageInteriorHUD = 58,
	RaceRouteGuide_Phase5 = 78,
	ActivityHud = 84,
	DesktopFreeRoamHud = 85,
	FullMap = 90,
	MobileDriveControls_Phase1 = 96,
	SharedInRaceHUD = 155,
	RaceBrowser = 170,
	OwnedGarageBrowser = 171,
	RaceEntryPresentation = 180,
	RaceQueueBanner = 190,
	RaceCountdown = 205,
	UnifiedRaceResults = 220,
	Onboarding = 990,
	SharedTopNotification = 1100,
	SharedConfirmationOverlay = 1250,
	PulseGallery = 1400,
}

-- Classic destroys a stale gui of these two names on start; Pulse does the same and no more.
local REPLACEABLE = { SharedTopNotification = true, SharedConfirmationOverlay = true }

local HALF = 0.5
local FRAMES = { Hud = true, Menu = true, Scene = true, Bare = true }
local SLOT_ANCHORS = {
	TopLeft = Vector2.new(0, 0),
	TopRight = Vector2.new(1, 0),
	TopCentre = Vector2.new(HALF, 0),
	RightColumn = Vector2.new(1, 0),
	BottomRail = Vector2.new(0, 1),
	BottomRight = Vector2.new(1, 1),
	BottomCentre = Vector2.new(HALF, 1),
	PromptStack = Vector2.new(HALF, 1),
}
local SLOT_NAMES = { "TopLeft", "TopRight", "TopCentre", "RightColumn", "BottomRail", "BottomRight", "BottomCentre", "PromptStack" }

local switchModule
local safeAreaAttached = false

local function isTrap(name: string): boolean
	return Contracts.Trap[name] == true or Contracts.TrapDescendants[name] == true
end

function Layers.Check(name: string): (boolean, string?)
	if type(name) ~= "string" or name == "" then
		return false, "layer name must be a non-empty string"
	end
	if isTrap(name) then
		return false, "'" .. name .. "' is a trap name"
	end
	if Layers.Order[name] == nil then
		return false, "'" .. name .. "' is not in Layers.Order"
	end
	return true, nil
end

function Layers.Switch(): any
	if not switchModule then
		-- ClientBase has already required the latch, so this does not yield.
		local latch = ReplicatedFirst:FindFirstChild("UIStyleSwitch")
		assert(latch, "[Pulse.Layers] ReplicatedFirst.UIStyleSwitch is missing")
		switchModule = require(latch)
	end
	return switchModule
end

local function newFrame(name: string, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- Root box inside the safe area: x offset, width, height, all whole pixels.
local function frameBox(ctx: any, frame: string): (number, number, number)
	local width = math.floor(ctx.Size.X)
	local height = math.floor(ctx.Size.Y)
	local limit: number? = nil
	if frame == "Hud" then
		limit = Tokens.Scale.HudMaxAspect
	elseif frame == "Menu" then
		limit = Tokens.Scale.MenuMaxAspect
	end
	local boxWidth = width
	if limit then
		boxWidth = math.min(width, math.round(height * limit))
	end
	return math.floor((width - boxWidth) * HALF), boxWidth, height
end

-- Side margin and bottom margin for a frame (API section 8: Menu values for Menu, Hud values otherwise).
local function margins(ctx: any, frame: string): (number, number)
	if frame == "Menu" then
		return ctx.Px(Tokens.Space.MenuMargin), ctx.Px(Tokens.Space.MenuBottom)
	end
	return ctx.Px(Tokens.Space.HudMargin), ctx.Px(Tokens.Space.HudBottom)
end

local function slotPositions(ctx: any, frame: string, width: number, height: number): { [string]: Vector2 }
	local side, bottom = margins(ctx, frame)
	-- The top bar is measured from the screen top; the root starts at the safe-area top.
	local barBottom = math.max(0, math.round(ctx.TopBarHeight - ctx.Origin.Y))
	local centre = math.floor(width * HALF)
	local topRight = Vector2.new(width - side, ctx.Px(Tokens.Space.TopRightTop))
	local bottomCentre = Vector2.new(centre, height - bottom)
	return {
		TopLeft = Vector2.new(side, barBottom + Tokens.Space.TopBarGap),
		TopRight = topRight,
		TopCentre = Vector2.new(centre, barBottom + ctx.Px(Tokens.Space.ToastTopGap)),
		BottomRight = Vector2.new(width - side, height - bottom),
		BottomCentre = bottomCentre,
		BottomRail = Vector2.new(side, height - bottom),
		-- Provisional until Phases 2 to 4 fix them.
		RightColumn = topRight,
		PromptStack = bottomCentre,
	}
end

-- Builds Root (and slots) under parent and keeps them laid out for ctx. Returns the layer without Gui fields.
local function compose(parent: Instance, ctx: any, frame: string): any
	local root = newFrame("Root", nil)
	local slots: { [string]: Frame } = {}
	if frame ~= "Bare" then
		for _, slotName in ipairs(SLOT_NAMES) do
			local slot = newFrame("Slot" .. slotName, root)
			slot.AnchorPoint = SLOT_ANCHORS[slotName]
			slot.Size = UDim2.fromOffset(0, 0)
			slots[slotName] = slot
		end
	end

	local function relayout()
		local x, width, height = frameBox(ctx, frame)
		root.Position = UDim2.fromOffset(x, 0)
		root.Size = UDim2.fromOffset(width, height)
		if frame ~= "Bare" then
			for slotName, position in pairs(slotPositions(ctx, frame, width, height)) do
				slots[slotName].Position = UDim2.fromOffset(position.X, position.Y)
			end
		end
	end
	relayout()
	root.Parent = parent

	local connection: RBXScriptConnection? = nil
	if ctx.Changed then
		connection = ctx.Changed:Connect(function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			relayout()
		end)
	end

	local layer = {}
	layer.Root = root
	layer.Metrics = ctx
	function layer.Slot(name: string): Frame
		local slot = slots[name]
		if not slot then
			error("[Pulse.Layers] no slot '" .. tostring(name) .. "' in a " .. frame .. " frame", 2)
		end
		return slot
	end
	function layer.SetVisible(visible: boolean)
		root.Visible = visible == true
		if layer.ScrimRoot then
			layer.ScrimRoot.Visible = visible == true
		end
	end
	local destroyed = false
	function layer.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if layer.ScrimGui then
			layer.ScrimGui:Destroy()
		end
		if layer.Gui then
			layer.Gui:Destroy()
		end
		root:Destroy()
	end
	return layer
end

local function frameOf(value: any): string
	local frame = value or "Hud"
	if FRAMES[frame] ~= true then
		error("[Pulse.Layers] unknown frame '" .. tostring(frame) .. "'", 3)
	end
	return frame
end

-- DisplayOrder for a derived gui (<name>Scrim, <name>Live): its own row, else base + offset when that is free.
local function derivedOrder(base: string, derived: string, offset: number): number
	local own = Layers.Order[derived]
	if own ~= nil then
		return own
	end
	local order = Layers.Order[base] + offset
	for other, value in pairs(Layers.Order) do
		if value == order then
			error("[Pulse.Layers] '" .. derived .. "' would share DisplayOrder " .. order .. " with '" .. other
				.. "'; add a row to Layers.Order", 3)
		end
	end
	return order
end

local function newScreenGui(playerGui: Instance, name: string, layerName: string, order: number, insets: Enum.ScreenInsets): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = insets
	if insets == Enum.ScreenInsets.None then
		gui.ClipToDeviceSafeArea = false
	end
	gui.DisplayOrder = order
	gui:SetAttribute("UIStyle", "Pulse")
	gui:SetAttribute("PulseLayer", layerName)
	gui.Parent = playerGui
	return gui
end

-- Errors unless the name is free in PlayerGui. A stale Classic gui is removed only for the two shared names.
local function claimName(playerGui: Instance, name: string)
	if isTrap(name) then
		error("[Pulse.Layers] '" .. name .. "' is a trap name", 3)
	end
	local existing = playerGui:FindFirstChild(name)
	if not existing then
		return
	end
	if existing:GetAttribute("UIStyle") == "Pulse" then
		error("[Pulse.Layers] a Pulse '" .. name .. "' already exists", 3)
	end
	if REPLACEABLE[name] ~= true then
		error("[Pulse.Layers] PlayerGui already has a child named '" .. name .. "'", 3)
	end
	existing:Destroy()
end

function Layers.Create(name: string, opts: { Frame: string?, Scrim: boolean?, Live: boolean? }?): any
	local options = opts or {}
	local latch = Layers.Switch()
	assert(latch.Style == "Pulse", "[Pulse.Layers] Create needs the Pulse style; the session is " .. tostring(latch.Style))
	local ok, reason = Layers.Check(name)
	if not ok then
		error("[Pulse.Layers] " .. tostring(reason), 2)
	end
	local frame = frameOf(options.Frame)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	assert(playerGui, "[Pulse.Layers] PlayerGui is not available")

	local guiName = name
	local order = Layers.Order[name]
	if options.Live == true then
		guiName = name .. "Live"
		order = derivedOrder(name, guiName, 1)
	end
	local scrimName = name .. "Scrim"
	local scrimOrder = nil
	if options.Scrim == true then
		scrimOrder = derivedOrder(name, scrimName, -1)
		claimName(playerGui, scrimName)
	end
	claimName(playerGui, guiName)

	local scrimGui: ScreenGui? = nil
	local scrimRoot: Frame? = nil
	if scrimOrder then
		scrimGui = newScreenGui(playerGui, scrimName, name, scrimOrder, Enum.ScreenInsets.None)
		-- A tint covers the whole screen, notch included, so it is the one root sized by scale.
		scrimRoot = newFrame("Root", nil)
		scrimRoot.Size = UDim2.fromScale(1, 1)
		scrimRoot.Parent = scrimGui
	end

	local gui = newScreenGui(playerGui, guiName, name, order, Enum.ScreenInsets.DeviceSafeInsets)
	if not safeAreaAttached then
		safeAreaAttached = true
		Metrics.AttachSafeArea(gui)
	end

	local layer = compose(gui, Metrics.Screen(), frame)
	layer.Gui = gui
	layer.ScrimGui = scrimGui
	layer.ScrimRoot = scrimRoot
	return layer
end

function Layers.Stage(parent: GuiObject, ctx: any, frame: string): any
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "[Pulse.Layers] Stage needs a GuiObject parent")
	assert(type(ctx) == "table" and typeof(ctx.Size) == "Vector2", "[Pulse.Layers] Stage needs a Metrics context")
	local layer = compose(parent, ctx, frameOf(frame))
	Metrics.Bind(layer.Root, ctx)
	return layer
end

return Layers
