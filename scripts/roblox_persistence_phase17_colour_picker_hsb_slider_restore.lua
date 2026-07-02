-- Persistence Phase 17 colour picker HSB slider restore.
--
-- Run from Roblox Studio Command Bar in Edit mode after the register-limit
-- repair if the temporary RGB +/- picker works but should be restored to the
-- original Hue/Saturation/Brightness drag-slider style.
--
-- This keeps the register-safe table-backed helpers from the previous repair,
-- but renders draggable HSB gradient sliders instead of RGB step buttons.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Colour Picker HSB Restore"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceRange(source, startText, endText, replacement, label)
	local startIndex = findPlain(source, startText)
	assert(startIndex, "Could not find start anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 client repair.")
	local endIndex = findPlain(source, endText, startIndex + #startText)
	assert(endIndex, "Could not find end anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 client repair.")
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "renderCockpitPaint = function()"), "Expected renderCockpitPaint anchor after colour picker.")

local hsbPicker = [=[
-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_HSB_RESTORE
NTRPersistencePhase15 = NTRPersistencePhase15 or {}

function NTRPersistencePhase15.ColorComponent(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return nil
	end
	if numberValue > 1 then
		numberValue = numberValue / 255
	end
	return math.clamp(numberValue, 0, 1)
end

function NTRPersistencePhase15.Color3Value(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "table" then
		local r = NTRPersistencePhase15.ColorComponent(value.R or value.r or value.Red or value.red or value[1])
		local g = NTRPersistencePhase15.ColorComponent(value.G or value.g or value.Green or value.green or value[2])
		local b = NTRPersistencePhase15.ColorComponent(value.B or value.b or value.Blue or value.blue or value[3])
		if r and g and b then
			return Color3.new(r, g, b)
		end
	end
	return fallback or Color3.fromRGB(255, 255, 255)
end

function NTRPersistencePhase15.SafeConnectPicker(signal, callback)
	if not signal or not signal.Connect then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:Connect(callback)
	end)
	if ok and connection then
		table.insert(pickerConnections, connection)
		return connection
	end
	return nil
end

local function renderColourPicker(parent, channels, applyCallback)
	if disconnectPickerInputs then
		pcall(disconnectPickerInputs)
	end
	clear(parent)
	channels = channels or { "Primary", "Secondary", "Detail" }
	if not table.find(channels, State.ColorChannel) then
		State.ColorChannel = channels[1]
	end

	local baseColors = State.Profile and State.Profile.CockpitColors or {}
	if State.ColorChannel == "ThrustColor" then
		baseColors = { ThrustColor = NTRPersistencePhase15.Color3Value((State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255)) }
	elseif State.Stage == "Customise" and State.CustomizeTarget and State.CustomizeTarget ~= "ALL" and State.CustomizeTarget ~= "Cockpit" and State.CustomizeTarget ~= "THRUST_COLOR" then
		local moduleColorSet = State.Profile and State.Profile.ModuleColors and State.Profile.ModuleColors[State.CustomizeTarget]
		if moduleColorSet then
			baseColors = moduleColorSet
		end
	end

	local current = NTRPersistencePhase15.Color3Value(baseColors[State.ColorChannel], Color3.fromRGB(255, 255, 255))
	State.Hue, State.Saturation, State.Brightness = current:ToHSV()

	clear(UI.ColorChannelFloat)
	UI.ColorChannelFloat.Visible = true
	for _, channel in ipairs(channels) do
		local channelButton = button(UI.ColorChannelFloat, channelTitle(channel), UDim2.fromOffset(126, 30), UDim2.fromScale(0, 0), State.ColorChannel == channel and Theme.CardHot or Theme.Card)
		NTRPersistencePhase15.SafeConnectPicker(channelButton.MouseButton1Click, function()
			State.ColorChannel = channel
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local swatchPanel = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(214, 78),
		Position = UDim2.fromOffset(6, 10),
	}, parent)
	for i, preset in ipairs((State.Catalog and State.Catalog.PaintPresets) or {}) do
		local col = (i - 1) % 4
		local rowIndex = math.floor((i - 1) / 4)
		local presetColor = NTRPersistencePhase15.Color3Value(preset.Color, Color3.fromRGB(255, 255, 255))
		local swatch = new("TextButton", {
			Text = "",
			BackgroundColor3 = presetColor,
			Size = UDim2.fromOffset(35, 26),
			Position = UDim2.fromOffset(col * 44, rowIndex * 34),
			BorderSizePixel = 0,
		}, swatchPanel)
		corner(swatch, 4)
		stroke(swatch, Theme.Accent, 0.2, 1)
		NTRPersistencePhase15.SafeConnectPicker(swatch.MouseButton1Click, function()
			current = presetColor
			State.Hue, State.Saturation, State.Brightness = current:ToHSV()
			applyCallback(State.ColorChannel, current)
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local sliderPanel = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -236, 1, -8),
		Position = UDim2.fromOffset(226, 5),
	}, parent)

	local hueGradient
	local satGradient
	local briGradient

	local function pickerColor()
		return Color3.fromHSV(tonumber(State.Hue) or 0, tonumber(State.Saturation) or 0, tonumber(State.Brightness) or 1)
	end

	local function applyCurrent()
		current = pickerColor()
		applyCallback(State.ColorChannel, current)
	end

	local function compactSlider(name, y, value, update)
		value = tonumber(value) or 0
		label(sliderPanel, name, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
		local track = new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Size = UDim2.new(1, -72, 0, 15),
			Position = UDim2.fromOffset(24, y + 3),
			BorderSizePixel = 0,
		}, sliderPanel)
		corner(track, 5)
		stroke(track, Theme.Accent, 0.35, 1)
		local gradient = new("UIGradient", {}, track)
		local knob = new("Frame", {
			BackgroundColor3 = Theme.Accent,
			Size = UDim2.fromOffset(11, 22),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.clamp(value, 0, 1), 0.5),
			BorderSizePixel = 0,
		}, track)
		corner(knob, 4)
		local valueLabel = label(sliderPanel, name == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"), UDim2.fromOffset(42, 20), UDim2.new(1, -42, 0, y), 10, Enum.TextXAlignment.Left)
		local dragging = false
		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			valueLabel.Text = name == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
			update(rel)
			applyCurrent()
		end
		NTRPersistencePhase15.SafeConnectPicker(track.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		NTRPersistencePhase15.SafeConnectPicker(track.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		NTRPersistencePhase15.SafeConnectPicker(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		NTRPersistencePhase15.SafeConnectPicker(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		return gradient
	end

	local function refreshGradients()
		if hueGradient then
			hueGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
				ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
				ColorSequenceKeypoint.new(0.34, Color3.fromHSV(0.34, 1, 1)),
				ColorSequenceKeypoint.new(0.51, Color3.fromHSV(0.51, 1, 1)),
				ColorSequenceKeypoint.new(0.68, Color3.fromHSV(0.68, 1, 1)),
				ColorSequenceKeypoint.new(0.85, Color3.fromHSV(0.85, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
			})
		end
		if satGradient then
			satGradient.Color = ColorSequence.new(Color3.fromHSV(State.Hue, 0, math.max(State.Brightness, 0.2)), Color3.fromHSV(State.Hue, 1, math.max(State.Brightness, 0.2)))
		end
		if briGradient then
			briGradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromHSV(State.Hue, math.max(State.Saturation, 0.06), 1))
		end
	end

	hueGradient = compactSlider("H", 5, State.Hue, function(v)
		State.Hue = v
		refreshGradients()
	end)
	satGradient = compactSlider("S", 34, State.Saturation, function(v)
		State.Saturation = v
		refreshGradients()
	end)
	briGradient = compactSlider("B", 63, State.Brightness, function(v)
		State.Brightness = v
		refreshGradients()
	end)
	refreshGradients()
end


]=]

if findPlain(source, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_REGISTER_REPAIR") then
	source = replaceRange(
		source,
		"-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_REGISTER_REPAIR",
		"renderCockpitPaint = function()",
		hsbPicker,
		"Phase 17 RGB picker to HSB slider restore"
	)
elseif findPlain(source, "local function renderColourPicker(parent, channels, applyCallback)") then
	source = replaceRange(
		source,
		"local function renderColourPicker(parent, channels, applyCallback)",
		"renderCockpitPaint = function()",
		hsbPicker,
		"Phase 17 colour picker HSB replacement"
	)
else
	error("Could not find colour picker to replace. Refresh the Studio mirror before another Phase 17 client repair.")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ColorPickerHSBRestore", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_HSB_RESTORE"), "HSB colour picker marker missing after install.")
assert(findPlain(finalSource, "compactSlider(\"H\", 5, State.Hue"), "Hue slider missing after install.")
assert(findPlain(finalSource, "ColorSequenceKeypoint.new(0.17"), "Hue gradient missing after install.")
assert(not findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_REGISTER_REPAIR"), "Old RGB register-repair picker marker still exists after install.")

info("PASS: restored register-safe HSB gradient sliders for the colour picker.")
info("Next: stop Play, start a fresh Play session, and verify cockpit/customisation colours use draggable H/S/B sliders again.")
