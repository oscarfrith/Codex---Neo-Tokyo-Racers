-- Owns the paint controls of the garage (channel switch, hue, saturation and brightness sliders, preset swatches); it does not own paint state, the 3D preview, or any remote: it reports a colour and whether it is committed.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.PaintView. Requires: Tokens, Surface, Controls.
--
-- The one place in the family that builds colours: the paint named exception of programme contract 2.3 (swatches)
-- and API2 3.6 (Slider.Gradient, Swatch.Colour). The slider ramps and the preset palette are the Classic ones
-- (GarageWorkspaceUI L261-263, L282-283); a colour is only ever reported to the caller, which decides what is sent.
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)

local PaintView = {}

local Space = Tokens.Space
local HUES = table.freeze({ 0, 0.07, 0.14, 0.31, 0.43, 0.51, 0.60, 0.68, 0.76, 0.86, 0.93 }) -- GarageWorkspaceUI L282
local HUE_STOPS = table.freeze({ 0, 0.17, 0.33, 0.5, 0.67, 0.83, 1 }) -- GarageWorkspaceUI L261
local CHANNEL_TEXT = table.freeze({
	Primary = "Primary", Secondary = "Secondary", Detail = "Detail", Neon = "Neon", FrontLights = "Front lights",
	RearLights = "Rear lights", ThrustColor = "Thrust", Underglow = "Underglow",
})

-- Pure. GarageWorkspaceUI L283 (paletteColour): two rows of thirteen presets. Row 1: white, dark grey, eleven
-- light hues. Row 2: light grey, black, eleven deep hues.
function PaintView._palette(): { { Color3 } }
	local rows = { {}, {} }
	rows[1][1] = Color3.new(1, 1, 1)
	rows[2][1] = Color3.fromRGB(180, 180, 184)
	rows[1][2] = Color3.fromRGB(66, 66, 72)
	rows[2][2] = Color3.new(0, 0, 0)
	for _, hue in ipairs(HUES) do
		table.insert(rows[1], Color3.fromHSV(hue, 0.48, 1))
		table.insert(rows[2], Color3.fromHSV(hue, 0.86, 0.42))
	end
	return rows
end

-- Pure. The colour the sliders start from. GarageUI L523 starts an unset channel at Color3.new(1,1,1)
-- (`colours[channel]=typeof(value)=="Color3" and value or Color3.new(1,1,1)`): pure white, not the kit's White
-- token (243,240,255), so the first colour saved from an untouched channel is the one Classic would save.
function PaintView._seed(current: any): Color3
	if typeof(current) == "Color3" then
		return current
	end
	return Color3.new(1, 1, 1)
end

-- Pure. GarageWorkspaceUI L261-263: the three slider ramps for the current hue and saturation.
function PaintView._ramps(hue: number, saturation: number): (ColorSequence, ColorSequence, ColorSequence)
	local stops = {}
	for _, stop in ipairs(HUE_STOPS) do
		table.insert(stops, ColorSequenceKeypoint.new(stop, Color3.fromHSV(stop, 1, 1)))
	end
	return ColorSequence.new(stops),
		ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1)),
		ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(hue, saturation, 1))
end

-- Pure. The value text beside each slider (previews r04a, c14).
function PaintView._valueText(index: number, value: number): string
	if index == 1 then
		return tostring(math.floor(value * 360 + 0.5)) .. "\u{00B0}"
	end
	return tostring(math.floor(value * 100 + 0.5)) .. "%"
end

-- Pure. How many of `count` cells of `side` px with `gap` between them fit in `width` px.
function PaintView._fit(width: number, side: number, gap: number, count: number): number
	if side <= 0 then
		return 0
	end
	return math.clamp(math.floor((width + gap) / (side + gap)), 0, count)
end

-- Pure. Do the presets stand clear of the controls? Both are screen px down from the top of the stage. `slack` is
-- how far the controls' box may reach into the preset row: its lower edge is touch padding under the slider bar.
function PaintView._presetsClear(controlsBottom: number, paletteTop: number, slack: number): boolean
	return controlsBottom - slack <= paletteTop
end

-- Pure. The Regular panel's height: its start height, or what the channel switch and the sliders need with the
-- gaps between them and the panel padding, whichever is larger.
function PaintView._panelHeight(start: number, tabsHeight: number, sliderHeights: { number }, gap: number, pad: number): number
	local height = tabsHeight + pad + pad
	for _, slider in ipairs(sliderHeights) do
		height += gap + slider
	end
	return math.max(start, height)
end

local function plainFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function listLayout(parent: Instance, horizontal: boolean, gap: number, wraps: boolean?)
	local layout = Instance.new("UIListLayout")
	layout.Name = "List"
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	if wraps then
		layout.Wraps = true
	end
	layout.Parent = parent
	return layout
end

--[[ PaintView.New(controlsParent, paletteParent, props, scope, ctx)
	controlsParent  the stage's TopLeft slot. Regular: the controls panel is built in it and Place(top) puts it
	                under the header. Compact: only its position is read (Place measures from it).
	paletteParent   the stage's BottomRail slot (anchor 0,1): the presets sit where the tile row is. Compact: the
	                controls are docked in it too, on the presets, so the middle of the screen stays clear.
	props           { OnChannel = (channel) -> (), OnColour = (channel, colour, commit) -> () }
	Returns { Controls: Frame, Palette: Frame, Place(top), ButtonLine(), Show(paint, token), Hide(), Destroy() }.
	paint = { Target, Channels = {string}, Selected = string, Colours = {[channel] = Color3} } from the model.
]]
function PaintView.New(controlsParent: GuiObject, paletteParent: GuiObject, props: any, scope: any, ctx: any)
	local compact = ctx.Class == "Compact"
	local gap = ctx.Px(Space.Gap)
	local bag = {}
	local destroyed = false
	local hsv = { 0, 0, 1 }
	local channel: string? = nil
	local shownToken: any = nil
	local channelSig = ""
	local settingUp = false
	local wanted = false -- Show was called and Hide was not
	local fitHeight: any = nil
	local syncPalette: any = nil
	local limitTop = 0 -- Compact: how far down from controlsParent the docked block must stay (Place)

	-- Controls: a slate panel on Regular (tabs over three sliders); a bare row on Compact (preview c14), docked
	-- at the foot of the screen on the presets instead of standing under the header.
	local controls = plainFrame("PaintControls", compact and paletteParent or controlsParent)
	controls.Visible = false
	local content: GuiObject = controls
	local sliderWidth = ctx.Px(compact and Space.CompactStatPanelWidth or Space.ListWidth)
	if compact then
		controls.AnchorPoint = Vector2.new(0, 1)
		controls.Size = UDim2.fromOffset(sliderWidth * 3 + gap * 2, ctx.Px(Space.CompactStatusHeight + Space.TouchMin + Space.TouchMin))
		listLayout(controls, false, gap)
	else
		controls.Size = UDim2.fromOffset(sliderWidth, ctx.Px(Space.StatPanelHeight - Space.ButtonHeight - Space.ButtonHeight))
		local panel = Surface.Panel(controls, { Name = "Panel" }, scope)
		table.insert(bag, panel)
		content = panel.Content
		listLayout(content, false, gap)
	end

	local tabs = Controls.Tabs(content, {
		Name = "Channels",
		Style = "Segment",
		Tabs = { { Id = "Primary", Text = CHANNEL_TEXT.Primary } },
		Selected = "Primary",
		LayoutOrder = 1,
		OnSelected = function(id)
			if not settingUp and props.OnChannel then
				props.OnChannel(id)
			end
		end,
	}, scope)
	table.insert(bag, tabs)

	local sliderRow = plainFrame("Sliders", content)
	sliderRow.LayoutOrder = 2
	listLayout(sliderRow, compact, gap)
	local sliders = {}
	local sliderHolders = {}
	local swatches = {}
	-- The width of one slider. Regular: the panel content width, which grows with the channel switch (below).
	local holderWidth = compact and sliderWidth or (sliderWidth - ctx.Px(Space.Pad) - ctx.Px(Space.Pad))

	local function colour(): Color3
		return Color3.fromHSV(hsv[1], hsv[2], hsv[3])
	end

	local function emit(commit: boolean)
		if channel and props.OnColour then
			props.OnColour(channel, colour(), commit)
		end
	end

	local function markPreset(chosen: any)
		for _, entry in ipairs(swatches) do
			entry.Component.Set({ Selected = entry == chosen })
		end
	end

	-- Slider positions, value texts and ramps from hsv. Writes only what moved (Set compares).
	local function refresh()
		local hueRamp, saturationRamp, brightnessRamp = PaintView._ramps(hsv[1], hsv[2])
		local ramps = { hueRamp, saturationRamp, brightnessRamp }
		for index, slider in ipairs(sliders) do
			slider.Set({ Value = hsv[index], ValueText = PaintView._valueText(index, hsv[index]), Gradient = ramps[index] })
		end
	end

	local LABELS = { "Hue", "Saturation", "Brightness" } -- GarageWorkspaceUI L278
	for index = 1, 3 do
		local holder = plainFrame("Slider" .. index, sliderRow)
		holder.LayoutOrder = index
		-- Sized before the slider is built, so the slider fills it (a slider takes its parent's width).
		sliderHolders[index] = holder
		holder.Size = UDim2.fromOffset(holderWidth, ctx.Px(Space.SliderHeight))
		local slider = Controls.Slider(holder, {
			Name = LABELS[index],
			Label = LABELS[index],
			Value = hsv[index],
			ValueText = PaintView._valueText(index, hsv[index]),
			OnChanged = function(value)
				-- GarageWorkspaceUI L275: a drag previews; nothing is committed until release.
				hsv[index] = math.clamp(tonumber(value) or 0, 0, 1)
				markPreset(nil)
				refresh()
				emit(false)
			end,
			OnReleased = function(value)
				-- GarageWorkspaceUI L276.
				hsv[index] = math.clamp(tonumber(value) or 0, 0, 1)
				refresh()
				emit(true)
			end,
		}, scope)
		table.insert(bag, slider)
		sliders[index] = slider
		local function fitHolder()
			local height = slider.Instance.Size.Y.Offset
			if height > 0 and holder.Size.Y.Offset ~= height then
				holder.Size = UDim2.fromOffset(holderWidth, height)
			end
			if fitHeight then
				fitHeight()
			end
		end
		fitHolder()
		table.insert(bag, scope:connect(slider.Instance:GetPropertyChangedSignal("Size"), fitHolder))
	end
	sliderRow.AutomaticSize = Enum.AutomaticSize.XY

	-- Regular: the panel is as tall as what it holds. A labelled slider is taller than SliderHeight, and with
	-- the start height alone the third slider ended below the panel's lower hairline.
	-- Compact: the docked row is as tall as the channel switch and the tallest slider with the gap between them
	-- (a touch tab row and a labelled touch slider are both taller than their drawn tokens), so the presets under
	-- it and the button row beside it are measured from its real box.
	local startHeight = controls.Size.Y.Offset
	fitHeight = function()
		if destroyed then
			return
		end
		if compact then
			local tallest = 0
			for _, holder in ipairs(sliderHolders) do
				tallest = math.max(tallest, holder.Size.Y.Offset)
			end
			local size = UDim2.fromOffset(
				math.max(sliderWidth * 3 + gap * 2, tabs.Instance.Size.X.Offset),
				tabs.Instance.Size.Y.Offset + gap + tallest
			)
			if controls.Size ~= size then
				controls.Size = size
			end
			if syncPalette then
				syncPalette()
			end
			return
		end
		local heights = {}
		for index, holder in ipairs(sliderHolders) do
			heights[index] = holder.Size.Y.Offset
		end
		local height = PaintView._panelHeight(startHeight, tabs.Instance.Size.Y.Offset, heights, gap, ctx.Px(Space.Pad))
		if controls.Size.Y.Offset ~= height then
			controls.Size = UDim2.fromOffset(controls.Size.X.Offset, height)
		end
	end
	fitHeight()

	-- Regular: the panel is as wide as its channel switch needs (a car with four channels is wider than the
	-- default panel: capture paint_tab drew NEON outside it), and the sliders follow.
	local function fitWidth()
		if destroyed or compact then
			return
		end
		local pad = ctx.Px(Space.Pad)
		local width = math.max(sliderWidth, tabs.Instance.Size.X.Offset + pad + pad)
		if controls.Size.X.Offset ~= width then
			controls.Size = UDim2.fromOffset(width, controls.Size.Y.Offset)
		end
		holderWidth = width - pad - pad
		for _, holder in ipairs(sliderHolders) do
			if holder.Size.X.Offset ~= holderWidth then
				holder.Size = UDim2.fromOffset(holderWidth, holder.Size.Y.Offset)
			end
		end
	end
	fitWidth()
	table.insert(bag, scope:connect(tabs.Instance:GetPropertyChangedSignal("Size"), function()
		fitWidth()
		fitHeight()
	end))

	-- Presets, where the tile row is. Regular: both rows. Compact: the first row only, as many as fit.
	local palette = plainFrame("PaintPalette", paletteParent)
	palette.AnchorPoint = Vector2.new(0, 1)
	palette.Visible = false
	listLayout(palette, true, gap, true)
	local rows = PaintView._palette()
	local perRow = #rows[1]
	for rowIndex, row in ipairs(rows) do
		for column, preset in ipairs(row) do
			local entry = { Colour = preset, Row = rowIndex }
			entry.Component = Controls.Swatch(palette, {
				Name = "Preset" .. rowIndex .. "_" .. column,
				Colour = preset,
				LayoutOrder = (rowIndex - 1) * perRow + column,
				OnActivated = function()
					-- GarageWorkspaceUI L284: a preset is a commit.
					local h, s, v = Color3.toHSV(preset)
					hsv[1], hsv[2], hsv[3] = h, s, v
					markPreset(entry)
					refresh()
					emit(true)
				end,
			}, scope)
			table.insert(bag, entry.Component)
			table.insert(swatches, entry)
		end
	end

	-- Compact: the controls stand on the presets, and the two together must stay under what Place was given (the
	-- header, and the stat panel when one shows). On the shortest phones they do not (568x320 with a stat panel):
	-- the presets are then left out and the controls stand on the foot of the screen; the three sliders reach
	-- every colour. Positions are stage offsets: the two slots, and the frames in them.
	syncPalette = function()
		if destroyed then
			return
		end
		local clear = true
		if compact then
			local lift = palette.Size.Y.Offset + gap
			local blockTop = paletteParent.Position.Y.Offset - lift - controls.Size.Y.Offset
			clear = PaintView._presetsClear(controlsParent.Position.Y.Offset + limitTop, blockTop, gap)
			local position = UDim2.fromOffset(0, clear and -lift or 0)
			if controls.Position ~= position then
				controls.Position = position
			end
		end
		local visible = wanted and clear
		if palette.Visible ~= visible then
			palette.Visible = visible
		end
	end

	local function layoutPalette()
		if destroyed or #swatches == 0 then
			return
		end
		local side = swatches[1].Component.Instance.Size.X.Offset
		local available = math.max(0, math.floor(ctx.Size.X) - paletteParent.Position.X.Offset - paletteParent.Position.X.Offset)
		local columns = PaintView._fit(available, side, gap, perRow)
		local shownRows = compact and 1 or #rows
		for index, entry in ipairs(swatches) do
			local column = (index - 1) % perRow + 1
			entry.Component.Set({ Visible = entry.Row <= shownRows and column <= columns })
		end
		palette.Size = UDim2.fromOffset(columns * side + math.max(0, columns - 1) * gap, shownRows * side + (shownRows - 1) * gap)
		syncPalette()
	end
	layoutPalette()
	table.insert(bag, scope:connect(controlsParent:GetPropertyChangedSignal("Position"), syncPalette))
	table.insert(bag, scope:connect(swatches[1].Component.Instance:GetPropertyChangedSignal("Size"), layoutPalette))
	table.insert(bag, scope:connect(paletteParent:GetPropertyChangedSignal("Position"), layoutPalette))

	local self = { Controls = controls, Palette = palette }

	-- top: screen px down from the top of controlsParent to the first free line under the header (and, on
	-- Compact, under anything else the docked block must not reach). Regular: the panel goes there. Compact: the
	-- block stays docked at the foot and only the presets depend on it. Call it before Show.
	function self.Place(top: number)
		if destroyed then
			return
		end
		if compact then
			if limitTop ~= top then
				limitTop = top
				syncPalette()
			end
			return
		end
		local position = UDim2.fromOffset(0, top)
		if controls.Position ~= position then
			controls.Position = position
		end
	end

	-- Compact: screen px from paletteParent's line (the foot of the stage) up to the middle of the channel
	-- switch, as a negative offset, so the screen can stand its button row on that line. nil on Regular.
	function self.ButtonLine(): number?
		if not compact then
			return nil
		end
		return controls.Position.Y.Offset - controls.Size.Y.Offset + math.floor(tabs.Instance.Size.Y.Offset / 2)
	end

	-- token is the model's page token: a new page (or a channel change, which is a new page) re-seeds the sliders;
	-- a message or a Cash change on the same page leaves a drag in progress alone.
	function self.Show(paint: any, token: any)
		if destroyed then
			return
		end
		local list = {}
		local parts = {}
		for _, name in ipairs(paint.Channels) do
			table.insert(list, { Id = name, Text = CHANNEL_TEXT[name] or name })
			table.insert(parts, name)
		end
		local signature = table.concat(parts, ",")
		settingUp = true
		if signature ~= channelSig then
			channelSig = signature
			tabs.Set({ Tabs = list, Selected = paint.Selected })
		else
			tabs.Set({ Selected = paint.Selected })
		end
		settingUp = false
		channel = paint.Selected
		if token ~= shownToken then
			shownToken = token
			local h, s, v = Color3.toHSV(PaintView._seed(paint.Colours and paint.Colours[paint.Selected]))
			hsv[1], hsv[2], hsv[3] = h, s, v
			markPreset(nil)
			refresh()
		end
		if not controls.Visible then
			controls.Visible = true
		end
		wanted = true
		syncPalette()
	end

	function self.Hide()
		if destroyed then
			return
		end
		shownToken = nil
		wanted = false
		if controls.Visible then
			controls.Visible = false
		end
		syncPalette()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, item in ipairs(bag) do
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			else
				item.Destroy()
			end
		end
		controls:Destroy()
		palette:Destroy()
	end

	return self
end

return PaintView
