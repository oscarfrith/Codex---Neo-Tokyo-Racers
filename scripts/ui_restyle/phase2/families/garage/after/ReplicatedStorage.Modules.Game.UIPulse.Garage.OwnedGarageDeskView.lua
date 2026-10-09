-- Owns the Pulse drawing of the owned-garage desk (the OwnedGarageCanonicalWorkspace root and what is shown in it); not the desk's state, pages, remote calls or OwnedGarageManagementOpen, which stay in the fork Garage.OwnedGarageWorkspaceUI, and not the CanonicalGarageGui layer, which Garage.GarageClient creates.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageDeskView. Requires: Kit.Layers, Kit.Metrics, Kit.Tokens, Kit.Contracts, Kit.Surface, Kit.Controls, Kit.Collections, Kit.Data, Kit.Input, Kit.Presence, Core.ConnectionScope, Garage.GarageCompat.
-- Interface the fork codes against (Classic UI.GarageWorkspaceUI, as used by UI.OwnedGarageWorkspaceUI): new(); .Root (Name, Visible, Active); .TouchMapEnabled; :Show(view); :RefreshCards(view); :Message(text); :Hide(); :IsTouchBlocked(position).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = script.Parent.Parent.Kit

local ROOT_NAME = "OwnedGarageCanonicalWorkspace"
local HOST_GUI = "CanonicalGarageGui"
local HOST_ROOT = "CanonicalCanvas"
local PRESENCE_SURFACE = "OwnedGarageWorkspace"
local UNAVAILABLE_TEXT = "Garage unavailable"
-- The tutorial pages the desk fork names (Classic UI.OwnedGarageWorkspaceUI line 126). Each has a mark key Page.<id>.
local PAGE_IDS = { "GarageHome", "DisplayCars", "GarageAssetFamilies", "BuildStructure", "BuildDecorations" }
local TIERS = { E = true, D = true, C = true, B = true, A = true, S = true }
-- Classic UI.GarageWorkspaceUI 282-283: the preset hues of the colour page, and the saturation and value of its two rows.
local PALETTE_HUES = { 0, 0.07, 0.14, 0.31, 0.43, 0.51, 0.60, 0.68, 0.76, 0.86, 0.93 }

local DeskView = {}
DeskView.__index = DeskView

local warned = {}
local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[Pulse.OwnedGarageDeskView] " .. message)
end

-- Pure. One desk card row of the fork becomes the props of one kit Tile. `money` formats a price; `marks` is
-- Kit.Contracts.Marks. Nothing here decides anything: affordability is the PriceColor the fork already computed.
function DeskView._tile(row, money, marks)
	local id = tostring(row.Id or "")
	local item = {
		Key = id,
		Title = tostring(row.DisplayName or row.Id or ""),
		Sub = row.Footer,
		ChipLeft = row.VehicleName,
		Image = row.Image ~= "" and row.Image or nil,
		State = row.Selected == true and "Selected" or "Default",
		Status = "None",
		MarkKey = marks["Card." .. id] and ("Card." .. id) or "Card",
	}
	if row.SemanticState == "Locked" then
		item.Status = "Locked"
	elseif row.Price ~= nil and row.PriceColor ~= nil then
		item.Status = "Unaffordable"
	elseif row.SemanticState == "Equipped" then
		item.Status = "Fitted"
	elseif row.Footer == "OWNED" then
		item.Status = "Owned"
	end
	if row.Price ~= nil and row.SemanticState ~= "Locked" then
		item.Price = money(row.Price)
	end
	if type(row.Badge) == "string" then
		local tier, rating = string.match(row.Badge, "^(%a)%s+(.+)$")
		if tier and TIERS[tier] then
			item.Tier = tier
			item.Rating = tonumber(rating)
		end
	end
	if row.EmptyPlus then
		item.ChipRight = "EMPTY"
		item.ChipRightKind = "Pink"
	end
	return item
end

-- Pure. The id of the selected left item, or the first id (the kit's Tabs needs one), or nil when there are none.
function DeskView._selectedTab(items)
	local first = nil
	for _, item in ipairs(items or {}) do
		local id = tostring(item.Id or item.Text or "")
		first = first or id
		if item.Selected == true then
			return id
		end
	end
	return first
end

-- Pure. "1/2 DISPLAY SPACES" -> "1 / 2"; anything else passes through.
function DeskView._spaces(capacityText)
	local text = tostring(capacityText or "")
	local used, capacity = string.match(text, "^(%d+)%s*/%s*(%d+)")
	if used then
		return used .. " / " .. capacity
	end
	return text
end

-- The fork calls new() with no argument. `options.Fixture = true` is for the gallery only: the Cash chip is left
-- unbound and no Presence entry is opened; the fixture parents Root itself before Show.
function DeskView.new(options)
	local self = setmetatable({}, DeskView)
	self._fixture = type(options) == "table" and options.Fixture == true
	self.TouchMapEnabled = false
	self._built = false
	self._context = nil
	self._action = nil
	self._rendering = false
	self._surfaces = {}
	local root = Instance.new("Frame")
	root.Name = ROOT_NAME
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	self.Root = root
	return self
end

-- The desk is drawn inside the garage layer that Garage.GarageClient creates. It is looked up by its reserved names
-- when the desk first shows; nothing is created here and nothing of that layer is written.
function DeskView:_attach()
	if self.Root.Parent then
		return true
	end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild(HOST_GUI)
	local canvas = gui and gui:FindFirstChild(HOST_ROOT)
	if not (canvas and canvas:IsA("GuiObject")) then
		warnOnce("host", HOST_GUI .. "." .. HOST_ROOT .. " was not found; the desk cannot be drawn")
		return false
	end
	self.Root.Parent = canvas
	if not canvas.Visible then
		warnOnce("hidden", HOST_ROOT .. " is hidden; the desk is drawn under it and will not show until it is visible")
	end
	return true
end

function DeskView:_track(component)
	if component and component.Instance then
		table.insert(self._surfaces, component.Instance)
	end
	return component
end

function DeskView:_build()
	local Layers = require(kit.Layers)
	local Metrics = require(kit.Metrics)
	local Tokens = require(kit.Tokens)
	local Contracts = require(kit.Contracts)
	local Controls = require(kit.Controls)
	local Collections = require(kit.Collections)
	local Data = require(kit.Data)
	local Input = require(kit.Input)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")

	local scope = require(scopeModule).new()
	local root = self.Root
	local ctx = Metrics.Of(root)
	self._scope = scope
	self._ctx = ctx
	self._kit = { Tokens = Tokens, Controls = Controls, Collections = Collections, Data = Data, Input = Input, Marks = Contracts.Marks, Surface = require(kit.Surface) }

	-- One host per tutorial page, marked once, plus a plain one. The stage moves between them, so the page marks
	-- (TutorialWorkspace, TutorialPageId) are never typed here and nothing is created on a page change.
	local hosts = {}
	local function host(name, markKey)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Visible = false
		frame.Parent = root
		if markKey then
			Input.Mark(frame, markKey)
		end
		return frame
	end
	hosts[""] = host("Page", nil)
	for _, id in ipairs(PAGE_IDS) do
		hosts[id] = host("Page_" .. id, "Page." .. id)
	end
	self._hosts = hosts
	self._activeHost = hosts[""]

	local stageHolder = Instance.new("Frame")
	stageHolder.Name = "Stage"
	stageHolder.BackgroundTransparency = 1
	stageHolder.BorderSizePixel = 0
	stageHolder.Size = UDim2.fromScale(1, 1)
	stageHolder.Parent = hosts[""]
	self._stageHolder = stageHolder
	local layer = Layers.Stage(stageHolder, ctx, "Scene")
	self._layer = layer

	local topLeft = layer.Slot("TopLeft")
	self._header = self:_track(Controls.Header(topLeft, { Title = "GARAGE MANAGEMENT", Sub = "", Shadow = true }, scope))
	local tabsHolder = Instance.new("Frame")
	tabsHolder.Name = "TabsHolder"
	tabsHolder.BackgroundTransparency = 1
	tabsHolder.BorderSizePixel = 0
	tabsHolder.AutomaticSize = Enum.AutomaticSize.XY
	tabsHolder.Parent = topLeft
	self._tabsHolder = tabsHolder

	self._cluster = self:_track(Data.StatusCluster(layer.Slot("TopRight"), { Mode = "Garage", Spaces = "", ShowPlus = false }, scope))
	local player = Players.LocalPlayer
	if player and self._cluster.Cash and not self._fixture then
		self._cluster.Cash.Bind(player)
	end

	self._rowsByKey = {}
	self._rail = self:_track(Collections.Rail(layer.Slot("BottomRail"), {
		Heading = "MANAGE",
		Count = "",
		SelectOn = "Activate", -- a card here navigates or starts a server preview: gamepad focus only highlights
		OnSelected = function(key)
			if self._rendering then
				return
			end
			local row = self._rowsByKey[key]
			if row and row.OnSelect then
				row.OnSelect()
			end
		end,
	}, scope))
	Input.Mark(self._rail.Instance, "TutorialCardScroller")

	self._buttons = self:_track(Controls.ButtonRow(layer.Slot("RailButtons"), {
		Align = "Right",
		Buttons = {
			{
				Id = "Back",
				Variant = "Default",
				Text = "BACK",
				Icon = "back",
				OnActivated = function()
					local context = self._context
					if context and context.OnBack then
						context.OnBack()
					end
				end,
			},
			{
				Id = "Exit",
				Variant = "Default",
				Text = "EXIT",
				Icon = "exit",
				OnActivated = function()
					local context = self._context
					if context and context.OnExit then
						context.OnExit()
					end
				end,
			},
			{
				Id = "Next",
				Variant = "Main",
				Text = "SAVE",
				OnActivated = function()
					local context = self._context
					if context and context.OnNext then
						context.OnNext()
					end
				end,
			},
			{
				Id = "Action",
				Variant = "Main",
				Text = "",
				OnActivated = function()
					local action = self._action
					if action and action.OnActivate then
						action.OnActivate()
					end
				end,
			},
		},
	}, scope))

	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout then
			self:_layout()
		end
	end)
	self:_layout()
	self._built = true
end

function DeskView:_layout()
	local ctx = self._ctx
	local space = self._kit.Tokens.Space
	self._tabsHolder.Position = UDim2.fromOffset(0, self._header.Height() + ctx.Px(space.HeaderTabsGap))
end

function DeskView:_ensure()
	if self._built then
		return true
	end
	if self._buildFailed or not self:_attach() then
		return false
	end
	local ok, problem = xpcall(function()
		self:_build()
	end, debug.traceback)
	if not ok then
		self._buildFailed = true
		warnOnce("build", "view build failed; the desk will not be drawn: " .. tostring(problem))
		return false
	end
	return true
end

-- The left items of the fork (mode tabs or location tabs) as one tab row; mark Categories (onboarding AC1, AD1).
function DeskView:_renderTabs(context)
	local items = context.ShowLeft ~= false and context.LeftItems or {}
	local tabs = self._tabs
	if #items == 0 then
		if tabs then
			tabs.Set({ Visible = false })
		end
		return
	end
	local byId = {}
	local list = {}
	local signature = {}
	for index, item in ipairs(items) do
		local id = tostring(item.Id or item.Text or "")
		byId[id] = item
		list[index] = { Id = id, Text = tostring(item.Text or item.Id or "") }
		signature[index] = id .. "=" .. list[index].Text
	end
	self._leftById = byId
	local selected = DeskView._selectedTab(items)
	local key = table.concat(signature, "|")
	if not tabs then
		tabs = self:_track(self._kit.Controls.Tabs(self._tabsHolder, {
			Tabs = list,
			Selected = selected,
			OnSelected = function(id)
				if self._rendering then
					return
				end
				local item = self._leftById and self._leftById[id]
				if item and item.OnSelect then
					item.OnSelect()
				end
			end,
		}, self._scope))
		self._kit.Input.Mark(tabs.Instance, "Categories")
		self._tabs = tabs
		self._tabsKey = key
	elseif self._tabsKey ~= key then
		tabs.Set({ Tabs = list, Selected = selected, Visible = true })
		self._tabsKey = key
	else
		tabs.Set({ Visible = true })
		tabs.Select(selected)
	end
end

-- A second, small tab row for the colour or material channel (Classic RenderChannelTabs).
function DeskView:_renderChannels(slotName, parent, channels, selected, onChannel)
	local field = "_channels" .. slotName
	local tabs = self[field]
	if not channels or #channels == 0 or not parent then
		if tabs then
			tabs.Set({ Visible = false })
		end
		return
	end
	local list = {}
	for index, channel in ipairs(channels) do
		list[index] = { Id = tostring(channel), Text = string.upper(tostring(channel)) }
	end
	local key = table.concat(channels, "|")
	local chosen = tostring(selected or channels[1])
	self[field .. "Handler"] = onChannel
	if not tabs then
		tabs = self:_track(self._kit.Controls.Tabs(parent, {
			Tabs = list,
			Selected = chosen,
			Style = "Segment",
			OnSelected = function(id)
				if self._rendering then
					return
				end
				local handler = self[field .. "Handler"]
				if handler then
					handler(id)
				end
			end,
		}, self._scope))
		self[field] = tabs
		self[field .. "Key"] = key
	elseif self[field .. "Key"] ~= key then
		tabs.Set({ Tabs = list, Selected = chosen, Visible = true })
		self[field .. "Key"] = key
	else
		tabs.Set({ Visible = true })
		tabs.Select(chosen)
	end
end

function DeskView:_renderCards(context)
	local parts = self._kit
	local rail = self._rail
	if self._paint then
		self._paint.panel.Set({ Visible = false })
	end
	rail.Set({ Visible = true })

	local cards = context.Cards or {}
	local items = {}
	local rowsByKey = {}
	local selectedKey = nil
	local money = function(amount)
		return parts.Data.Money(amount, false)
	end
	for index, row in ipairs(cards) do
		local item = DeskView._tile(row, money, parts.Marks)
		items[index] = item
		rowsByKey[item.Key] = row
		if row.Selected == true then
			selectedKey = item.Key
		end
	end
	self._rowsByKey = rowsByKey
	rail.SetItems(items)
	if selectedKey then
		rail.Select(selectedKey)
	end
	if #cards == 0 and context.EmptyMessage then
		rail.SetHeading(tostring(context.EmptyMessage), "")
	else
		rail.SetHeading("MANAGE", tostring(#cards))
	end
	self:_renderChannels("Material", rail.HeadingRight, context.MaterialChannels, context.SelectedChannel, context.OnChannel)

	-- Classic 243-248: the action belongs to the card whose id it names; with no such card there is no action.
	local action = nil
	local selectedAction = context.SelectedAction
	if type(selectedAction) == "table" and selectedAction.Text and selectedAction.OnActivate and rowsByKey[tostring(selectedAction.RowId or "")] then
		action = selectedAction
	end
	self._action = action
	self._buttons.Button("Action").Set({ Visible = action ~= nil, Text = action and string.upper(tostring(action.Text)) or "" })
end

-- The colour page (Classic RenderPaint 252-286): channel tabs, hue, saturation and brightness, the current colour
-- and the preset swatches. OnColor(channel, colour, commit) is the fork's; commit is true on release or a preset.
function DeskView:_renderPaint(context)
	local parts = self._kit
	local space = parts.Tokens.Space
	self._action = nil
	self._buttons.Button("Action").Set({ Visible = false })
	self._rail.Set({ Visible = false })
	self:_renderChannels("Material", nil, nil, nil, nil)

	local channels = context.ColorChannels or {}
	local selected = context.SelectedChannel or channels[1]
	local paint = self._paint
	if not selected then
		if paint then
			paint.panel.Set({ Visible = false })
		end
		return
	end
	if not paint then
		paint = { hsv = { 0, 0, 1 }, sliders = {}, swatches = {} }
		self._paint = paint
		local width = space.ModalMaxWidth
		local height = 3 * space.SliderHeight + 3 * space.ButtonHeight + 6 * space.Gap + 2 * space.Pad
		paint.panel = self:_track(parts.Surface.Panel(self._layer.Slot("BottomLeft"), { Name = "PaintControls", Width = width, Height = height }, self._scope))
		paint.panel.Instance.AnchorPoint = Vector2.new(0, 1)
		local content = paint.panel.Content
		local column = Instance.new("UIListLayout")
		column.Name = "Layout"
		column.FillDirection = Enum.FillDirection.Vertical
		column.SortOrder = Enum.SortOrder.LayoutOrder
		column.Padding = UDim.new(0, self._ctx.Px(space.Gap))
		column.Parent = content
		local function row(name, order)
			local frame = Instance.new("Frame")
			frame.Name = name
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.AutomaticSize = Enum.AutomaticSize.XY
			frame.LayoutOrder = order
			frame.Parent = content
			local layout = Instance.new("UIListLayout")
			layout.Name = "Layout"
			layout.FillDirection = Enum.FillDirection.Horizontal
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, self._ctx.Px(space.Gap))
			layout.Parent = frame
			return frame
		end
		paint.channelRow = row("Channels", 1)

		local function colour()
			return Color3.fromHSV(paint.hsv[1], paint.hsv[2], paint.hsv[3])
		end
		local function emit(commit)
			local current = self._context
			if current and current.OnColor and paint.channel then
				current.OnColor(paint.channel, colour(), commit == true)
			end
		end
		function paint.refresh()
			local hue, saturation = paint.hsv[1], paint.hsv[2]
			paint.sliders[1].Set({ Value = paint.hsv[1] })
			paint.sliders[2].Set({ Value = paint.hsv[2], Gradient = ColorSequence.new(Color3.fromHSV(0, 0, 1), Color3.fromHSV(hue, 1, 1)) })
			paint.sliders[3].Set({ Value = paint.hsv[3], Gradient = ColorSequence.new(Color3.fromHSV(0, 0, 0), Color3.fromHSV(hue, saturation, 1)) })
			paint.current.Set({ Colour = colour() })
		end
		local hueKeys = {}
		for index, stop in ipairs({ 0, 0.17, 0.33, 0.5, 0.67, 0.83, 1 }) do
			hueKeys[index] = ColorSequenceKeypoint.new(stop, Color3.fromHSV(stop, 1, 1))
		end
		local labels = { "HUE", "SATURATION", "BRIGHTNESS" }
		for index = 1, 3 do
			paint.sliders[index] = parts.Controls.Slider(content, {
				Name = labels[index],
				Label = labels[index],
				Value = paint.hsv[index],
				Gradient = index == 1 and ColorSequence.new(hueKeys) or nil,
				LayoutOrder = 1 + index,
				OnChanged = function(value)
					if self._rendering then
						return
					end
					paint.hsv[index] = math.clamp(tonumber(value) or 0, 0, 1)
					paint.refresh()
					emit(false)
				end,
				OnReleased = function()
					if self._rendering then
						return
					end
					emit(true)
				end,
			}, self._scope)
		end
		-- Two preset rows as Classic 283: white and grey, dark grey and black, then a light and a deep tone per hue.
		for rowIndex = 1, 2 do
			local frame = row("Palette" .. rowIndex, 4 + rowIndex)
			if rowIndex == 1 then
				paint.current = parts.Controls.Swatch(frame, { Name = "CurrentColour", Colour = colour(), Selected = true, LayoutOrder = 0, OnActivated = function() end }, self._scope)
			end
			local presets = {
				rowIndex == 1 and Color3.fromHSV(0, 0, 1) or Color3.fromHSV(0, 0, 0.71),
				rowIndex == 1 and Color3.fromHSV(0.667, 0.083, 0.282) or Color3.fromHSV(0, 0, 0),
			}
			for _, hue in ipairs(PALETTE_HUES) do
				table.insert(presets, rowIndex == 1 and Color3.fromHSV(hue, 0.48, 1) or Color3.fromHSV(hue, 0.86, 0.42))
			end
			for column_, preset in ipairs(presets) do
				local swatch = parts.Controls.Swatch(frame, {
					Name = "Palette" .. rowIndex .. "_" .. (column_ + 2),
					Colour = preset,
					LayoutOrder = column_,
					OnActivated = function()
						if self._rendering then
							return
						end
						local h, s, v = Color3.toHSV(preset)
						paint.hsv = { h, s, v }
						paint.refresh()
						emit(true)
					end,
				}, self._scope)
				table.insert(paint.swatches, swatch)
			end
		end
	end
	paint.panel.Set({ Visible = true })
	paint.channel = selected
	local current = (context.Colors and context.Colors[selected]) or Color3.fromHSV(0, 0, 1)
	local h, s, v = Color3.toHSV(current)
	paint.hsv = { h, s, v }
	paint.refresh()
	self:_renderChannels("Paint", paint.channelRow, channels, selected, context.OnChannel)
end

function DeskView:_apply(context, full)
	self._context = context
	self._rendering = true
	local ok, problem = xpcall(function()
		local id = tostring(context.TutorialPageId or "")
		local host = self._hosts[id] or self._hosts[""]
		if host ~= self._activeHost then
			self._activeHost.Visible = false
			self._stageHolder.Parent = host
			self._activeHost = host
		end
		host.Visible = true

		self._header.Set({ Title = string.upper(tostring(context.Title or "GARAGE")), Sub = tostring(context.Subtitle or "") })
		local buttons = self._buttons
		buttons.Button("Back").Set({ Visible = context.BackVisible == true, Text = tostring(context.BackText or "BACK") })
		if full then
			buttons.Button("Next").Set({ Visible = context.NextVisible ~= false, Text = tostring(context.NextText or "DRIVE") })
			buttons.Button("Exit").Set({ Visible = context.ExitVisible == true, Text = tostring(context.ExitText or "EXIT") })
			self:_renderTabs(context)
			self._cluster.Set({ Spaces = DeskView._spaces(context.CapacityText) })
		end
		if full and context.ColorChannels then
			self:_renderPaint(context)
		else
			self:_renderCards(context)
		end
		self:_layout()
	end, debug.traceback)
	self._rendering = false
	if not ok then
		warnOnce("apply", "render failed: " .. tostring(problem))
	end
	return ok
end

-- Pure. The close function of a fork view, or nil. Classic UI.OwnedGarageWorkspaceUI line 126 gives every view
-- OnExit = close, and close (line 37) is the Classic close path: it clears PlayerGui@OwnedGarageManagementOpen,
-- hides the workspace and, inside a garage, cancels the previews and tells the server the desk is shut.
function DeskView._closeOf(context)
	local close = type(context) == "table" and context.OnExit or nil
	return type(close) == "function" and close or nil
end

-- The desk could not be attached, built or drawn. It used to be shown anyway: an empty root with
-- OwnedGarageManagementOpen true and no Exit to press. Now nothing is shown, the fork's own close runs (so the
-- attribute is cleared by its Classic owner, not written here) and the player is told. Deferred: Show is called
-- from inside the fork's open or render, which finishes its own statement first.
function DeskView:_fail(context)
	self.Root.Visible = false
	self._context = nil
	self._action = nil
	if self._releasePresence then
		self._releasePresence()
		self._releasePresence = nil
	end
	if self._fixture then
		return
	end
	local close = DeskView._closeOf(context)
	if close then
		task.defer(close)
	else
		warnOnce("close", "the failed desk has no OnExit to close through; OwnedGarageManagementOpen was not cleared")
	end
	local ok, problem = pcall(function()
		require(script.Parent.GarageCompat).Notify(UNAVAILABLE_TEXT)
	end)
	if not ok then
		warnOnce("notify", "toast failed: " .. tostring(problem))
	end
end

function DeskView:Show(context)
	if not self:_ensure() then
		self:_fail(context)
		return
	end
	self.Root.Visible = true
	if not self._releasePresence and not self._fixture then
		self._releasePresence = require(kit.Presence).Open(PRESENCE_SURFACE, "Garage")
	end
	if not self:_apply(context, true) then
		self:_fail(context)
	end
end

function DeskView:RefreshCards(context)
	if self._built then
		self:_apply(context, false)
	else
		self._context = context
	end
end

function DeskView:Message(text)
	if self._built then
		self._header.Set({ Sub = tostring(text or "") })
	end
end

function DeskView:Hide()
	self.Root.Visible = false
	self._context = nil
	self._action = nil
	if self._releasePresence then
		self._releasePresence()
		self._releasePresence = nil
	end
end

local function shown(object, root)
	local current = object
	while current and current ~= root do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current == root
end

-- Gallery only: releases everything the view built.
function DeskView:Destroy()
	self:Hide()
	if self._scope then
		self._scope:destroy()
		self._scope = nil
	end
	self._built = false
	self._buildFailed = true
	self.Root:Destroy()
end

-- Read by the touch camera guard through the fork's IsCameraTouchBlocked: is this screen point on a desk surface?
function DeskView:IsTouchBlocked(position)
	if not (self.TouchMapEnabled and self.Root.Visible and position) then
		return false
	end
	for _, object in ipairs(self._surfaces) do
		if object.Parent and shown(object, self.Root) then
			local origin, size = object.AbsolutePosition, object.AbsoluteSize
			if size.X > 0 and size.Y > 0 and position.X >= origin.X and position.X <= origin.X + size.X and position.Y >= origin.Y and position.Y <= origin.Y + size.Y then
				return true
			end
		end
	end
	return false
end

return DeskView
