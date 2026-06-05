-- Neo Tokyo Racers shared colour picker controller.
-- Phase B module. Pure helpers are safe now; Render is staged for later client adoption.

local ColourPickerController = {}

ColourPickerController.DefaultChannels = { "Primary", "Secondary", "Detail" }

function ColourPickerController.ToHSV(color)
	local ok, h, s, v = pcall(function()
		return color:ToHSV()
	end)
	if ok then
		return h, s, v
	end
	return Color3.toHSV(color)
end

function ColourPickerController.SyncStateFromColor(state, color)
	local h, s, v = ColourPickerController.ToHSV(color)
	state.Hue = h
	state.Saturation = s
	state.Brightness = v
	return h, s, v
end

function ColourPickerController.ColorFromState(state)
	return Color3.fromHSV(state.Hue or 0, state.Saturation or 0, state.Brightness or 1)
end

function ColourPickerController.ChannelTitle(channel)
	if channel == "Neon" then return "Neon" end
	if channel == "ThrustColor" then return "Thrust" end
	if channel == "FrontLights" then return "Front Lights" end
	if channel == "RearLights" then return "Rear Lights" end
	return tostring(channel)
end

function ColourPickerController.ResolveBaseColors(state)
	state = state or {}
	if state.ColorChannel == "ThrustColor" then
		return {
			ThrustColor = (state.Profile and state.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255),
		}
	end

	if state.Stage == "Customise"
		and state.CustomizeTarget
		and state.CustomizeTarget ~= "ALL"
		and state.CustomizeTarget ~= "Cockpit"
		and state.CustomizeTarget ~= "THRUST_COLOR"
	then
		local moduleColorSet = state.Profile
			and state.Profile.ModuleColors
			and state.Profile.ModuleColors[state.CustomizeTarget]
		if moduleColorSet then
			return moduleColorSet
		end
	end

	return (state.Profile and state.Profile.CockpitColors) or {}
end

function ColourPickerController.ApplyHueGradient(gradient)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
		ColorSequenceKeypoint.new(0.34, Color3.fromHSV(0.34, 1, 1)),
		ColorSequenceKeypoint.new(0.51, Color3.fromHSV(0.51, 1, 1)),
		ColorSequenceKeypoint.new(0.68, Color3.fromHSV(0.68, 1, 1)),
		ColorSequenceKeypoint.new(0.85, Color3.fromHSV(0.85, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	})
end

function ColourPickerController.ApplySaturationGradient(gradient, hue)
	gradient.Color = ColorSequence.new(Color3.fromHSV(hue or 0, 0, 1), Color3.fromHSV(hue or 0, 1, 1))
end

function ColourPickerController.ApplyBrightnessGradient(gradient, hue, saturation)
	gradient.Color = ColorSequence.new(
		Color3.fromRGB(0, 0, 0),
		Color3.fromHSV(hue or 0, math.max(saturation or 0, 0.06), 1)
	)
end

function ColourPickerController.RefreshGradients(state, hueGradient, saturationGradient, brightnessGradient)
	if hueGradient then
		ColourPickerController.ApplyHueGradient(hueGradient)
	end
	if saturationGradient then
		ColourPickerController.ApplySaturationGradient(saturationGradient, state.Hue)
	end
	if brightnessGradient then
		ColourPickerController.ApplyBrightnessGradient(brightnessGradient, state.Hue, state.Saturation)
	end
end

local function defaultShortName(name)
	if name == "Hue" then return "H" end
	if name == "Saturation" then return "S" end
	if name == "Brightness" then return "B" end
	return name
end

function ColourPickerController.MakeSlider(context, name, y, value, update)
	local helpers = context.Helpers
	local parent = context.Parent
	local theme = context.Theme
	local userInputService = context.UserInputService
	local connections = context.Connections

	local short = defaultShortName(name)
	helpers.Label(parent, short, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)

	local track = helpers.New("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -72, 0, 15),
		Position = UDim2.fromOffset(24, y + 3),
		BorderSizePixel = 0,
	}, parent)
	helpers.Corner(track, 5)
	helpers.Stroke(track, theme.Accent, 0.35, 1)

	local gradient = helpers.New("UIGradient", {}, track)
	local knob = helpers.New("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.fromOffset(11, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		BorderSizePixel = 0,
	}, track)
	helpers.Corner(knob, 4)

	local valueLabel = helpers.Label(
		parent,
		short == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"),
		UDim2.fromOffset(42, 20),
		UDim2.new(1, -42, 0, y),
		10,
		Enum.TextXAlignment.Left
	)

	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		valueLabel.Text = short == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
		update(rel)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local move = userInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	if connections then
		table.insert(connections, move)
	end

	return gradient
end

function ColourPickerController.Render(context)
	local state = context.State
	local parent = context.Parent
	local helpers = context.Helpers
	local channels = context.Channels or ColourPickerController.DefaultChannels
	local applyCallback = context.ApplyCallback

	helpers.Clear(parent)
	if not table.find(channels, state.ColorChannel) then
		state.ColorChannel = channels[1]
	end

	local baseColors = ColourPickerController.ResolveBaseColors(state)
	local current = baseColors[state.ColorChannel] or Color3.fromRGB(255, 255, 255)
	ColourPickerController.SyncStateFromColor(state, current)

	if context.ChannelFloat then
		helpers.Clear(context.ChannelFloat)
		context.ChannelFloat.Visible = true
		for _, channel in ipairs(channels) do
			local button = helpers.Button(
				context.ChannelFloat,
				ColourPickerController.ChannelTitle(channel),
				UDim2.fromOffset(126, 30),
				UDim2.fromScale(0, 0),
				state.ColorChannel == channel and context.Theme.CardHot or context.Theme.Card
			)
			button.MouseButton1Click:Connect(function()
				state.ColorChannel = channel
				ColourPickerController.Render(context)
			end)
		end
	end

	local swatchPanel = helpers.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(214, 78),
		Position = UDim2.fromOffset(6, 10),
	}, parent)

	for i, preset in ipairs((state.Catalog and state.Catalog.PaintPresets) or {}) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local swatch = helpers.New("TextButton", {
			Text = "",
			BackgroundColor3 = preset.Color,
			Size = UDim2.fromOffset(35, 26),
			Position = UDim2.fromOffset(col * 44, row * 34),
			BorderSizePixel = 0,
		}, swatchPanel)
		helpers.Corner(swatch, 4)
		helpers.Stroke(swatch, context.Theme.Accent, 0.2, 1)
		swatch.MouseButton1Click:Connect(function()
			ColourPickerController.SyncStateFromColor(state, preset.Color)
			applyCallback(state.ColorChannel, preset.Color)
			ColourPickerController.Render(context)
		end)
	end

	local sliderPanel = helpers.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -236, 1, -8),
		Position = UDim2.fromOffset(226, 5),
	}, parent)

	local sliderContext = table.clone(context)
	sliderContext.Parent = sliderPanel

	local hueGradient
	local saturationGradient
	local brightnessGradient

	local function refresh()
		ColourPickerController.RefreshGradients(state, hueGradient, saturationGradient, brightnessGradient)
	end

	hueGradient = ColourPickerController.MakeSlider(sliderContext, "H", 5, state.Hue, function(value)
		state.Hue = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	saturationGradient = ColourPickerController.MakeSlider(sliderContext, "S", 34, state.Saturation, function(value)
		state.Saturation = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	brightnessGradient = ColourPickerController.MakeSlider(sliderContext, "B", 63, state.Brightness, function(value)
		state.Brightness = value
		refresh()
		applyCallback(state.ColorChannel, ColourPickerController.ColorFromState(state))
	end)

	refresh()
end

return ColourPickerController
