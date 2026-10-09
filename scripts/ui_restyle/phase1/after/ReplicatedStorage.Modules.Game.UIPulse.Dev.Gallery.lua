-- Owns the Studio-only Pulse gallery (ScreenGui PulseGallery, its index and the fixture stage); owns no game surface, remote, profile or player attribute.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Dev.Gallery. Requires: Kit.Tokens, Kit.Metrics, Kit.Layers, Kit.Text, Core.ConnectionScope, Dev.Fixtures children.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Metrics = require(Kit.Metrics)
local Layers = require(Kit.Layers)
local Text = require(Kit.Text)
local ConnectionScope = require(ReplicatedStorage.Modules.Core.ConnectionScope)

local TOOL_FLAG = "PulseGalleryEnabled"
local LAYER_NAME = "PulseGallery"
local DEFAULT_PRESET = "R1080"
local PRESET_ORDER = { "R720", "R1080", "R1440", "C844", "C568" }
-- Stage sizes and top bar values are the API.md section 10 presets, not layout literals.
local PRESETS = {
	R720 = { Size = Vector2.new(1280, 720), Compact = false },
	R1080 = { Size = Vector2.new(1920, 1080), Compact = false },
	R1440 = { Size = Vector2.new(2560, 1440), Compact = false },
	C844 = { Size = Vector2.new(844, 390), Compact = true },
	C568 = { Size = Vector2.new(568, 320), Compact = true },
}
local SLOT_ANCHOR = {
	TopLeft = Vector2.new(0, 0),
	TopRight = Vector2.new(1, 0),
	TopCentre = Vector2.new(0.5, 0),
	RightColumn = Vector2.new(1, 0),
	BottomRail = Vector2.new(0, 1),
	BottomRight = Vector2.new(1, 1),
	BottomCentre = Vector2.new(0.5, 1),
	PromptStack = Vector2.new(0.5, 1),
}
-- Keys while open. BackSlash opens and closes; Home hides the index so the stage can use the whole window.
local NAV_KEYS = {
	[Enum.KeyCode.PageUp] = { "Item", -1 },
	[Enum.KeyCode.PageDown] = { "Item", 1 },
	[Enum.KeyCode.Comma] = { "State", -1 },
	[Enum.KeyCode.Period] = { "State", 1 },
	[Enum.KeyCode.Minus] = { "Preset", -1 },
	[Enum.KeyCode.Equals] = { "Preset", 1 },
}
local HINT = "    PGUP/PGDN ITEM   , . STATE   - = SIZE   HOME INDEX   \\ CLOSE"

local Client = {}
local state
local warned = {}

local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.Gallery] " .. message)
end

local function readString(gui, name)
	local value = gui:GetAttribute(name)
	return if type(value) == "string" then value else ""
end

-- Reads Dev.Fixtures once. A broken fixture module is reported and skipped.
local function readFixtures()
	local items, byId, ids = {}, {}, {}
	local folder = script.Parent:FindFirstChild("Fixtures")
	local modules = {}
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("ModuleScript") then
				table.insert(modules, child)
			end
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	for _, module in ipairs(modules) do
		local ok, list = pcall(require, module)
		if not ok or type(list) ~= "table" then
			warnOnce("fixture module " .. module.Name .. " failed: " .. tostring(list))
		else
			for position, item in ipairs(list) do
				local label = module.Name .. "[" .. position .. "]"
				if type(item) ~= "table" or type(item.Id) ~= "string" or item.Id == "" then
					warnOnce("fixture " .. label .. " has no Id")
				elseif string.find(item.Id, "[,|]") then
					warnOnce("fixture id may not contain a comma or a bar: " .. item.Id)
				elseif byId[item.Id] then
					warnOnce("duplicate fixture id " .. item.Id .. " in " .. module.Name)
				elseif type(item.Mount) ~= "function" or type(item.States) ~= "table" or #item.States == 0 then
					warnOnce("fixture " .. item.Id .. " needs Mount and at least one state")
				else
					byId[item.Id] = item
					table.insert(items, item)
					table.insert(ids, item.Id)
				end
			end
		end
	end
	return items, byId, ids
end

-- Returns item, state entry, preset name (each nil when it cannot be resolved) and an error text.
local function resolve(g)
	local presetName = readString(g.gui, "GalleryPreset")
	if presetName == "" then
		presetName = DEFAULT_PRESET
	end
	local presetError = if PRESETS[presetName] then nil else "unknown preset: " .. presetName
	if presetError then
		presetName = nil
	end
	local itemId = readString(g.gui, "GalleryItem")
	local item = if itemId == "" then g.items[1] else g.byId[itemId]
	if not item then
		return nil, nil, presetName, if #g.items == 0 then "no fixtures registered" else "unknown item: " .. itemId
	end
	local stateId = readString(g.gui, "GalleryState")
	local entry = nil
	if stateId == "" then
		entry = item.States[1]
	else
		for _, candidate in ipairs(item.States) do
			if type(candidate) == "table" and candidate.Id == stateId then
				entry = candidate
				break
			end
		end
	end
	if type(entry) ~= "table" or type(entry.Id) ~= "string" then
		return item, nil, presetName, "unknown state: " .. item.Id .. "|" .. stateId
	end
	return item, entry, presetName, presetError
end

-- Chrome sizes come from tokens through the real screen context; no literals.
local function chromeMetrics(screen)
	local textSize = Text.SizeFor("Label", screen)
	return {
		Pad = screen.Px(Tokens.Space.Gap),
		Row = screen.Px(Tokens.Space.BadgeLarge),
		IndexWidth = screen.Px(Tokens.Space.TileWidth),
		Top = math.floor(screen.TopBarHeight + Tokens.Space.TopBarGap),
		TextSize = textSize,
	}
end

-- Logical rectangle the stage may use, in Root space.
local function stageArea(g)
	local screen = g.screen
	local width, height = math.floor(screen.Size.X), math.floor(screen.Size.Y)
	if not g.chromeVisible then
		return 0, 0, math.max(1, width), math.max(1, height)
	end
	local m = chromeMetrics(screen)
	local x = m.Pad * 2 + m.IndexWidth
	local y = m.Top + (m.Row + m.Pad) * 3
	return x, y, math.max(1, width - x - m.Pad), math.max(1, height - y - m.Pad)
end

local function newFrame(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function paint(button, selected)
	button.BackgroundTransparency = if selected then 0 else 1
	button.TextColor3 = if selected then Tokens.Colour.Ink else Tokens.Colour.TextSecondary
end

local function newButton(name, text, order, m, parent, scope, onActivated)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = Tokens.Colour.White
	button.FontFace = Text.Font("Label")
	button.TextSize = m.TextSize
	button.Text = "  " .. text .. "  "
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(0, m.Row)
	button.AutomaticSize = Enum.AutomaticSize.X
	paint(button, false)
	button.Parent = parent
	scope:connect(button.Activated, onActivated)
	return button
end

local function newList(parent, direction, padding)
	local list = Instance.new("UIListLayout")
	list.Name = "List"
	list.FillDirection = direction
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding)
	list.Parent = parent
	return list
end

local function unmount(g)
	if g.mountScope then
		g.mountScope:destroy()
		g.mountScope = nil
	end
	g.mountedKey = nil
	g.gui:SetAttribute("GalleryMounted", "")
end

-- Builds Root.StageHolder.Stage at the preset size and mounts one fixture state in it.
local function mount(g, item, entry, presetName)
	local preset = PRESETS[presetName]
	local size = preset.Size
	local scope = ConnectionScope.new()
	g.mountScope = scope
	local x, y, availableWidth, availableHeight = stageArea(g)
	local scale = math.min(1, availableWidth / size.X, availableHeight / size.Y)

	local holder = newFrame("StageHolder", nil)
	scope:add(holder)
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.Position = UDim2.fromOffset(
		x + math.floor((availableWidth - size.X * scale) / 2),
		y + math.floor((availableHeight - size.Y * scale) / 2)
	)
	if scale < 1 then
		-- The one static UIScale API.md section 10 allows: the stage is larger than the window.
		local stageScale = Instance.new("UIScale")
		stageScale.Name = "StageScale"
		stageScale.Scale = scale
		stageScale.Parent = holder
	end

	local stage = newFrame("Stage", holder)
	stage.BackgroundColor3 = Tokens.Colour.Slate
	stage.BackgroundTransparency = 0
	stage.Size = UDim2.fromOffset(size.X, size.Y)

	local compact = preset.Compact
	local ctx = Metrics.Fixed({
		Size = size,
		TouchEnabled = compact,
		Input = if compact then "Touch" else "KeyboardAndMouse",
		TopBarHeight = if compact then 52 else 58,
		TopBarKeepOut = if compact then Vector2.new(120, 52) else Vector2.new(208, 58),
	})
	Metrics.Bind(stage, ctx)
	local stageLayer = Layers.Stage(stage, ctx, item.Frame)
	scope:add(stageLayer)

	local parent
	if item.Slot ~= nil then
		parent = stageLayer.Slot(item.Slot)
	else
		parent = newFrame("Centre", stage)
		parent.Size = UDim2.fromOffset(size.X, size.Y)
	end
	holder.Parent = g.root

	local props = if type(entry.Props) == "table" then table.clone(entry.Props) else {}
	local component = item.Mount(parent, props, scope, ctx)

	-- Place a root the fixture left untouched: on the slot anchor, or centred when it has a fixed size.
	local root = if type(component) == "table" then component.Instance else nil
	if typeof(root) == "Instance" and root:IsA("GuiObject") then
		local untouched = root.AnchorPoint == Vector2.new(0, 0) and root.Position == UDim2.fromOffset(0, 0)
		if untouched and item.Slot ~= nil then
			root.AnchorPoint = SLOT_ANCHOR[item.Slot] or Vector2.new(0, 0)
		elseif untouched and root.Size.X.Scale == 0 and root.Size.Y.Scale == 0 then
			root.AnchorPoint = Vector2.new(0.5, 0.5)
			root.Position = UDim2.fromOffset(math.floor(size.X / 2), math.floor(size.Y / 2))
		end
	end
end

local function buildStates(g, item, m)
	if g.stateScope then
		g.stateScope:destroy()
	end
	local scope = ConnectionScope.new()
	g.stateScope = scope
	g.stateButtons = {}
	g.stateItemId = if item then item.Id else ""
	if not item then
		return
	end
	for position, entry in ipairs(item.States) do
		if type(entry) == "table" and type(entry.Id) == "string" then
			local id = entry.Id
			local button = newButton("State" .. position, id, position, m, g.states, scope, function()
				g.gui:SetAttribute("GalleryState", id)
			end)
			scope:add(button)
			g.stateButtons[id] = button
		end
	end
end

-- Index, preset row, state row and status line. Built on first open and again after a resize.
local function buildChrome(g)
	if g.chromeScope then
		g.chromeScope:destroy()
	end
	local scope = ConnectionScope.new()
	g.chromeScope = scope
	local screen = g.screen
	local m = chromeMetrics(screen)
	local width, height = math.floor(screen.Size.X), math.floor(screen.Size.Y)
	local x = m.Pad * 2 + m.IndexWidth
	local areaWidth = math.max(1, width - x - m.Pad)
	local indexHeight = math.max(1, height - m.Top - m.Pad)

	local chrome = newFrame("Chrome", nil)
	chrome.Size = UDim2.fromScale(1, 1)
	chrome.Visible = g.chromeVisible
	scope:add(chrome)

	local index = Instance.new("ScrollingFrame")
	index.Name = "Index"
	index.BackgroundColor3 = Tokens.Colour.Slate
	index.BackgroundTransparency = 1 - Tokens.Opacity.Panel
	index.BorderSizePixel = 0
	index.Position = UDim2.fromOffset(m.Pad, m.Top)
	index.Size = UDim2.fromOffset(m.IndexWidth, indexHeight)
	index.CanvasSize = UDim2.fromOffset(0, #g.items * m.Row)
	index.ScrollingDirection = Enum.ScrollingDirection.Y
	index.ScrollBarThickness = m.Pad
	index.ScrollBarImageColor3 = Tokens.Colour.TextMuted
	index.Parent = chrome
	newList(index, Enum.FillDirection.Vertical, 0)
	local rows = {}
	for position, item in ipairs(g.items) do
		local id = item.Id
		local row = newButton("Item" .. position, id, position, m, index, scope, function()
			g.gui:SetAttribute("GalleryState", "")
			g.gui:SetAttribute("GalleryItem", id)
		end)
		row.AutomaticSize = Enum.AutomaticSize.None
		row.Size = UDim2.new(1, 0, 0, m.Row)
		rows[id] = row
	end

	local presets = newFrame("Presets", chrome)
	presets.Position = UDim2.fromOffset(x, m.Top)
	presets.Size = UDim2.fromOffset(areaWidth, m.Row)
	newList(presets, Enum.FillDirection.Horizontal, m.Pad)
	local presetButtons = {}
	for position, name in ipairs(PRESET_ORDER) do
		local size = PRESETS[name].Size
		local label = name .. " " .. size.X .. "x" .. size.Y
		presetButtons[name] = newButton("Preset" .. name, label, position, m, presets, scope, function()
			g.gui:SetAttribute("GalleryPreset", name)
		end)
	end

	local states = Instance.new("ScrollingFrame")
	states.Name = "States"
	states.BackgroundTransparency = 1
	states.BorderSizePixel = 0
	states.Position = UDim2.fromOffset(x, m.Top + m.Row + m.Pad)
	states.Size = UDim2.fromOffset(areaWidth, m.Row)
	states.CanvasSize = UDim2.fromOffset(0, 0)
	states.AutomaticCanvasSize = Enum.AutomaticSize.X
	states.ScrollingDirection = Enum.ScrollingDirection.X
	states.ScrollBarThickness = 0
	states.Parent = chrome
	newList(states, Enum.FillDirection.Horizontal, m.Pad)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.BorderSizePixel = 0
	status.Position = UDim2.fromOffset(x, m.Top + (m.Row + m.Pad) * 2)
	status.Size = UDim2.fromOffset(areaWidth, m.Row)
	status.FontFace = Text.Font("Label")
	status.TextSize = m.TextSize
	status.TextColor3 = Tokens.Colour.TextSecondary
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Text = ""
	status.Parent = chrome

	g.chrome, g.index, g.states, g.status = chrome, index, states, status
	g.rows, g.presetButtons, g.stateButtons, g.stateItemId = rows, presetButtons, {}, nil
	g.chromeMetrics, g.indexHeight = m, indexHeight
	scope:add(function()
		if g.stateScope then
			g.stateScope:destroy()
			g.stateScope = nil
		end
		g.chrome, g.index, g.states, g.status, g.stateItemId = nil, nil, nil, nil, nil
		g.rows, g.presetButtons, g.stateButtons = {}, {}, {}
	end)
	chrome.Parent = g.root
end

local function refreshChrome(g, item, entry, presetName, message)
	if not g.chrome then
		return
	end
	g.chrome.Visible = g.chromeVisible
	local m = g.chromeMetrics
	local itemId = if item then item.Id else ""
	local stateId = if entry then entry.Id else ""
	for id, button in pairs(g.rows) do
		paint(button, id == itemId)
	end
	for name, button in pairs(g.presetButtons) do
		paint(button, name == presetName)
	end
	if g.stateItemId ~= itemId then
		buildStates(g, item, m)
	end
	for id, button in pairs(g.stateButtons) do
		paint(button, id == stateId)
	end
	if message ~= "" then
		g.status.Text = string.match(message, "^[^\n]*") or message
		g.status.TextColor3 = Tokens.Colour.Danger
	else
		g.status.Text = itemId .. " | " .. stateId .. " | " .. tostring(presetName) .. HINT
		g.status.TextColor3 = Tokens.Colour.TextSecondary
	end
	-- Keep the selected row in view.
	local position = if item then table.find(g.items, item) else nil
	if position then
		local top = (position - 1) * m.Row
		local canvasY = g.index.CanvasPosition.Y
		if top < canvasY then
			g.index.CanvasPosition = Vector2.new(0, top)
		elseif top + m.Row > canvasY + g.indexHeight then
			g.index.CanvasPosition = Vector2.new(0, top + m.Row - g.indexHeight)
		end
	end
end

-- The single path from the attributes to the screen. `force` rebuilds after a resize.
local function apply(g, force)
	local gui = g.gui
	if gui:GetAttribute("GalleryOpen") ~= true then
		if g.mountScope or g.mountedKey then
			unmount(g)
		end
		g.failedKey = nil
		if force and g.chromeScope then
			g.chromeScope:destroy()
			g.chromeScope = nil
		end
		g.layer.SetVisible(false)
		return
	end
	if not g.backdrop then
		local backdrop = newFrame("Backdrop", g.root)
		backdrop.BackgroundColor3 = Tokens.Colour.Ink
		backdrop.BackgroundTransparency = 0
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.ZIndex = 0
		backdrop.Active = true
		g.backdrop = backdrop
	end
	if force or not g.chrome then
		buildChrome(g)
	end
	g.layer.SetVisible(true)

	local item, entry, presetName, problem = resolve(g)
	if problem then
		unmount(g)
		gui:SetAttribute("GalleryError", problem)
		refreshChrome(g, item, entry, presetName, problem)
		return
	end
	-- Publish the defaults that were filled in, so a probe reads what is shown.
	if readString(gui, "GalleryItem") ~= item.Id then
		gui:SetAttribute("GalleryItem", item.Id)
	end
	if readString(gui, "GalleryState") ~= entry.Id then
		gui:SetAttribute("GalleryState", entry.Id)
	end
	if readString(gui, "GalleryPreset") ~= presetName then
		gui:SetAttribute("GalleryPreset", presetName)
	end

	local key = item.Id .. "|" .. entry.Id .. "|" .. presetName
	local message = ""
	if force or (key ~= g.mountedKey and key ~= g.failedKey) then
		unmount(g)
		g.failedKey = nil
		local ok, mountError = xpcall(mount, debug.traceback, g, item, entry, presetName)
		if ok then
			g.mountedKey = key
			gui:SetAttribute("GalleryError", "")
			gui:SetAttribute("GalleryMounted", key)
		else
			unmount(g)
			g.failedKey = key
			message = tostring(mountError)
			gui:SetAttribute("GalleryError", message)
			warnOnce("mount failed for " .. key .. ": " .. message)
		end
	elseif key == g.failedKey then
		message = readString(gui, "GalleryError")
	end
	refreshChrome(g, item, entry, presetName, message)
end

-- Several attribute writes in one step give one apply.
local function schedule(g, force)
	if force then
		g.force = true
	end
	if g.pending then
		return
	end
	g.pending = true
	task.defer(function()
		g.pending = false
		local forced = g.force
		g.force = false
		local ok, message = xpcall(apply, debug.traceback, g, forced)
		if not ok then
			g.gui:SetAttribute("GalleryError", tostring(message))
			warnOnce(tostring(message))
		end
	end)
end

local function step(g, kind, delta)
	local gui = g.gui
	local item, entry, presetName = resolve(g)
	if kind == "Item" then
		local count = #g.items
		if count == 0 then
			return
		end
		local position = (item and table.find(g.items, item)) or (if delta > 0 then 0 else 1)
		local nextItem = g.items[(position - 1 + delta) % count + 1]
		gui:SetAttribute("GalleryState", "")
		gui:SetAttribute("GalleryItem", nextItem.Id)
	elseif kind == "State" then
		if not item then
			return
		end
		local count = #item.States
		local position = (entry and table.find(item.States, entry)) or (if delta > 0 then 0 else 1)
		local nextEntry = item.States[(position - 1 + delta) % count + 1]
		if type(nextEntry) == "table" and type(nextEntry.Id) == "string" then
			gui:SetAttribute("GalleryState", nextEntry.Id)
		end
	else
		local count = #PRESET_ORDER
		local position = (presetName and table.find(PRESET_ORDER, presetName)) or (if delta > 0 then 0 else 1)
		gui:SetAttribute("GalleryPreset", PRESET_ORDER[(position - 1 + delta) % count + 1])
	end
end

local function toolEnabled()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local development = config and config:FindFirstChild("Development")
	local tools = development and development:FindFirstChild("ClientTools")
	return RunService:IsStudio() and tools ~= nil and tools:GetAttribute(TOOL_FLAG) == true
end

function Client.start()
	if state then
		assert(state == "ready", "Client startup already attempted: " .. tostring(state))
		return
	end
	if not toolEnabled() then
		return
	end
	state = "starting"
	local ok, message = xpcall(function()
		Layers.Switch().Claim("Gallery")
		local layer = Layers.Create(LAYER_NAME, { Frame = "Bare" })
		local gui = layer.Gui
		assert(gui, "PulseGallery layer has no ScreenGui")
		layer.SetVisible(false)

		local items, byId, ids = readFixtures()
		local g = {
			layer = layer,
			gui = gui,
			root = layer.Root,
			screen = layer.Metrics,
			scope = ConnectionScope.new(),
			items = items,
			byId = byId,
			chromeVisible = true,
			pending = false,
			force = false,
			rows = {},
			presetButtons = {},
			stateButtons = {},
		}
		gui:SetAttribute("GalleryOpen", false)
		gui:SetAttribute("GalleryItem", "")
		gui:SetAttribute("GalleryState", "")
		gui:SetAttribute("GalleryPreset", DEFAULT_PRESET)
		gui:SetAttribute("GalleryItems", table.concat(ids, ","))
		gui:SetAttribute("GalleryMounted", "")
		gui:SetAttribute("GalleryError", "")

		for _, name in ipairs({ "GalleryOpen", "GalleryItem", "GalleryState", "GalleryPreset" }) do
			g.scope:connect(gui:GetAttributeChangedSignal(name), function()
				schedule(g, false)
			end)
		end
		g.scope:connect(g.screen.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			schedule(g, true)
		end)
		g.scope:connect(UserInputService.InputBegan, function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then
				return
			end
			local key = input.KeyCode
			local open = gui:GetAttribute("GalleryOpen") == true
			if key == Enum.KeyCode.BackSlash then
				gui:SetAttribute("GalleryOpen", not open)
			elseif open and key == Enum.KeyCode.Home then
				g.chromeVisible = not g.chromeVisible
				schedule(g, true)
			elseif open and NAV_KEYS[key] then
				step(g, NAV_KEYS[key][1], NAV_KEYS[key][2])
			end
		end)
		g.scope:task(Text.Preload)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Client
