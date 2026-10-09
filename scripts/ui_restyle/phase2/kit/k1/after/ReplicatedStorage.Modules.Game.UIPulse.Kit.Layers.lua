-- Owns Pulse ScreenGui creation, the DisplayOrder ladder, composition frames and anchored slots; owns no screen content and never switches a gui on or off.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers. Requires: Tokens, Metrics, Contracts.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Contracts = require(script.Parent.Contracts)

local Layers = {}

-- Today's Classic numbers, reused. A <name>Scrim or <name>Live gui takes its own row when it has one, else one lower
-- or one higher than its base (an error if that lands on another row). Wave 2 rows are API2 2.4.
Layers.Order = {
	CanonicalGarageGuiScrim = 39,
	CanonicalGarageGui = 40,
	CanonicalGarageGuiLive = 41,
	OwnedGarageInteriorHUD = 58,
	OwnedGarageInteriorHUDLive = 59,
	RaceRouteGuide_Phase5 = 78,
	PulseWorldPrompts = 80,
	PulseEventCard = 81,
	ActivityHud = 84,
	DesktopFreeRoamHud = 85,
	DesktopFreeRoamHudLive = 86,
	ActivityHudLive = 87, -- 84 + 1 is taken
	FullMapScrim = 89,
	FullMap = 90,
	FullMapLive = 91,
	MobileDriveControls_Phase1 = 96,
	SharedInRaceHUD = 155,
	SharedInRaceHUDLive = 156,
	OwnedGarageBrowserScrim = 168, -- 171 - 1 is taken
	RaceBrowserScrim = 169,
	RaceBrowser = 170,
	OwnedGarageBrowser = 171,
	RaceEntryPresentationScrim = 179,
	RaceEntryPresentation = 180,
	RaceQueueBanner = 190,
	RaceCountdown = 205,
	UnifiedRaceResultsScrim = 219,
	UnifiedRaceResults = 220,
	Onboarding = 990,
	LoadingSafeContentScrim = 1000,
	LoadingSafeContent = 1001,
	SharedTopNotification = 1100,
	SharedConfirmationOverlay = 1250,
	PulseGallery = 1400,
}

-- Classic destroys a stale gui of these two names on start; Pulse does the same and no more.
local REPLACEABLE = { SharedTopNotification = true, SharedConfirmationOverlay = true }

local HALF = 0.5
local DEFAULT_ROOT_NAME = "Root"
local FRAMES = { Hud = true, Menu = true, Scene = true, Bare = true }
-- API2 2.4. Anchors and sizes are set with the positions, because five slots change with class or arrangement.
local SLOT_NAMES = {
	"TopLeft", "TopLeftHud", "TopRight", "TopCentre", "TopCentreHud", "ActionBar", "HudStatus", "RightColumn",
	"SidePanel", "BottomRail", "RailButtons", "BottomRight", "BottomLeft", "BottomCentre", "Centre", "Minimap",
	"Gauge", "HudButtons", "PromptStack",
}

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

-- Side margin and bottom margin (API2 2.4): Compact has one pair; Regular uses the Menu pair for Menu and Scene and
-- the Hud pair for Hud and Bare.
local function margins(ctx: any, frame: string): (number, number)
	local space = Tokens.Space
	if ctx.Class == "Compact" then
		return ctx.Px(space.CompactMargin), ctx.Px(space.CompactBottom)
	end
	if frame == "Menu" or frame == "Scene" then
		return ctx.Px(space.MenuMargin), ctx.Px(space.MenuBottom)
	end
	return ctx.Px(space.HudMargin), ctx.Px(space.HudBottom)
end

-- One entry per slot name: { Anchor: Vector2, X, Y, W, H } in whole pixels of the root. W and H are 0 except for the
-- sized slots (RightColumn, SidePanel, BottomRail). The table of API2 2.4, row by row.
local function slotLayout(ctx: any, frame: string, width: number, height: number): { [string]: any }
	local space = Tokens.Space
	local px = ctx.Px
	local compact = ctx.Class == "Compact"
	local touchDrive = ctx.Arrangement == "TouchDrive"
	local side, bottom = margins(ctx, frame)
	-- The top bar and the chat window are measured from the screen top; the root starts at the safe-area top.
	local barBottom = math.max(0, math.round(ctx.TopBarHeight - ctx.Origin.Y))
	local chat = ctx.ChatKeepOut
	local chatBottom = if chat then math.max(0, math.round(chat.Y - ctx.Origin.Y)) else 0
	local centre = math.floor(width * HALF)
	local right = width - side
	local base = height - bottom
	local gap = px(space.Gap)

	local out = {}
	local function put(name: string, anchorX: number, anchorY: number, x: number, y: number, w: number?, h: number?)
		out[name] = { Anchor = Vector2.new(anchorX, anchorY), X = x, Y = y, W = w or 0, H = h or 0 }
	end

	put("TopLeftHud", 0, 0, side, math.max(barBottom, chatBottom) + space.TopBarGap)
	put("TopCentre", HALF, 0, centre, barBottom + px(space.ToastTopGap))
	-- Sized in width only: its anchor is on the bottom edge, so a height would move children that sit at Position zero.
	put("BottomRail", 0, 1, side, base, math.max(0, width - side), 0)
	put("BottomRight", 1, 1, right, base)
	put("BottomLeft", 0, 1, side, base)
	put("BottomCentre", HALF, 1, centre, base)
	put("Centre", HALF, HALF, centre, math.floor(height * HALF))

	local gaugeHalf
	if compact then
		local top = px(space.CompactTop)
		local touchGap = px(space.TouchGap)
		local columnTop = px(space.CompactRightColumnTop)
		gaugeHalf = math.floor(px(space.CompactGauge) * HALF)
		put("TopLeft", 0, 0, side, top)
		put("TopRight", 1, 0, right, top)
		put("TopCentreHud", HALF, 0, centre, top)
		put("ActionBar", HALF, 0, centre, top)
		put("RightColumn", 1, 0, right, columnTop, px(space.CompactStatPanelWidth), math.max(0, base - columnTop))
		put("SidePanel", 1, 0, right, top, px(space.CompactSidePanelWidth), math.max(0, base - top))
		put("RailButtons", 1, 1, right, base - px(space.CompactTileHeight) - px(space.CompactRailButtonsLift))
		put("PromptStack", HALF, 1, centre, base - px(space.CompactPromptLift))
		if touchDrive then
			local mapTop = top + touchGap
			put("Minimap", 1, 0, right - touchGap, mapTop)
			-- Under the minimap, which is CompactMinimap across.
			put("HudStatus", 1, 0, right, mapTop + px(space.CompactMinimap) + touchGap)
		else
			put("Minimap", 0, 1, side + px(space.MinimapInset), base)
			put("HudStatus", 1, 0, right, top)
		end
	else
		local hud = frame == "Hud"
		local hudTop = px(space.TopRightTop)
		local top = if hud then hudTop else px(space.MenuTopRightTop)
		local hudColumnTop = px(space.HudRightColumnTop)
		local columnTop = if hud then hudColumnTop else px(space.RightColumnTop)
		if hud and touchDrive then
			-- The minimap sits where the column starts; the column goes under it and its label band.
			columnTop = hudColumnTop + px(space.MinimapSize) + px(space.MinimapLabelBand) + gap
		end
		gaugeHalf = math.floor(px(space.GaugeTouchSize) * HALF)
		put("TopLeft", 0, 0, side, barBottom + space.TopBarGap)
		put("TopRight", 1, 0, right, top)
		put("TopCentreHud", HALF, 0, centre, hudTop)
		-- Under the status strip.
		put("ActionBar", 1, 0, right, hudTop + px(space.StatusHeight + space.StatusPad + space.StatusPad) + gap)
		put("HudStatus", 1, 0, right, top)
		put("RightColumn", 1, 0, right, columnTop, px(space.StatPanelWidth), math.max(0, base - columnTop))
		put("SidePanel", 0, 0, 0, 0, px(space.SidePanelWidth), height)
		put("RailButtons", 1, 1, right, base - px(space.TileHeight) - px(space.RailButtonsLift))
		put("PromptStack", HALF, 1, centre, height - px(space.PromptLift))
		if touchDrive then
			put("Minimap", 1, 0, right - px(space.MinimapInset), hudColumnTop)
		else
			-- The frame's bottom-left; the district label goes in the band below.
			put("Minimap", 0, 1, side + px(space.MinimapInset), base - px(space.MinimapLabelBand))
		end
	end

	if touchDrive then
		put("Gauge", HALF, 1, centre, base)
		-- Left of the centred gauge.
		put("HudButtons", 1, 1, centre - gaugeHalf - gap, base)
	else
		put("Gauge", 1, 1, right, base)
		put("HudButtons", HALF, 1, centre, base)
	end
	return out
end

-- Builds Root (and slots) under parent and keeps them laid out for ctx. Returns the layer without Gui fields.
local function compose(parent: Instance, ctx: any, frame: string, rootName: string): any
	local root = newFrame(rootName, nil)
	local slots: { [string]: Frame } = {}
	if frame ~= "Bare" then
		for _, slotName in ipairs(SLOT_NAMES) do
			slots[slotName] = newFrame("Slot" .. slotName, root)
		end
	end

	local function relayout()
		local x, width, height = frameBox(ctx, frame)
		root.Position = UDim2.fromOffset(x, 0)
		root.Size = UDim2.fromOffset(width, height)
		if frame ~= "Bare" then
			local layout = slotLayout(ctx, frame, width, height)
			for _, slotName in ipairs(SLOT_NAMES) do
				local slot = slots[slotName]
				local entry = layout[slotName]
				slot.AnchorPoint = entry.Anchor
				slot.Position = UDim2.fromOffset(entry.X, entry.Y)
				slot.Size = UDim2.fromOffset(entry.W, entry.H)
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

-- The root's name: "Root" unless a Classic reader needs another (DesignRoot, SafeRoot, CanonicalCanvas).
local function rootNameOf(value: any): string
	if value == nil then
		return DEFAULT_ROOT_NAME
	end
	if type(value) ~= "string" or value == "" then
		error("[Pulse.Layers] RootName must be a non-empty string", 3)
	end
	if isTrap(value) then
		error("[Pulse.Layers] RootName '" .. value .. "' is a trap name", 3)
	end
	return value
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

function Layers.Create(name: string, opts: { Frame: string?, Scrim: boolean?, Live: boolean?, RootName: string? }?): any
	local options = opts or {}
	local latch = Layers.Switch()
	assert(latch.Style == "Pulse", "[Pulse.Layers] Create needs the Pulse style; the session is " .. tostring(latch.Style))
	local ok, reason = Layers.Check(name)
	if not ok then
		error("[Pulse.Layers] " .. tostring(reason), 2)
	end
	local frame = frameOf(options.Frame)
	local rootName = rootNameOf(options.RootName)
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
		scrimRoot = newFrame(DEFAULT_ROOT_NAME, nil)
		scrimRoot.Size = UDim2.fromScale(1, 1)
		scrimRoot.Parent = scrimGui
	end

	local gui = newScreenGui(playerGui, guiName, name, order, Enum.ScreenInsets.DeviceSafeInsets)
	if not safeAreaAttached then
		safeAreaAttached = true
		Metrics.AttachSafeArea(gui)
	end

	local layer = compose(gui, Metrics.Screen(), frame, rootName)
	layer.Gui = gui
	layer.ScrimGui = scrimGui
	layer.ScrimRoot = scrimRoot
	return layer
end

function Layers.Stage(parent: GuiObject, ctx: any, frame: string): any
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "[Pulse.Layers] Stage needs a GuiObject parent")
	assert(type(ctx) == "table" and typeof(ctx.Size) == "Vector2", "[Pulse.Layers] Stage needs a Metrics context")
	local layer = compose(parent, ctx, frameOf(frame), DEFAULT_ROOT_NAME)
	Metrics.Bind(layer.Root, ctx)
	return layer
end

return Layers
