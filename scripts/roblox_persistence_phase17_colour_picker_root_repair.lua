-- Persistence Phase 17 colour picker root repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if cockpit/customisation
-- colour UI still fails inside renderColourPicker after the earlier targeted
-- Color3/slider repairs.
--
-- Root cause:
-- The current patched bootstrap can repeatedly fail while constructing the old
-- compact drag-slider block. Rather than chasing shifted line numbers, this
-- replaces the entire renderColourPicker function with a compact self-contained
-- picker that uses swatches plus RGB step buttons. It keeps the same server
-- callbacks and colour channels, but removes the fragile drag signal path.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Colour Picker Root Repair"

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
assert(findPlain(source, "local function renderColourPicker(parent, channels, applyCallback)"), "Expected renderColourPicker in active client bootstrap.")
assert(findPlain(source, "renderCockpitPaint = function()"), "Expected renderCockpitPaint anchor after renderColourPicker.")

local newPicker = [=[
-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_ROOT_REPAIR
local function NTR_phase17ColorComponent(value)
	local numberValue = tonumber(value)
	if not numberValue then
		return nil
	end
	if numberValue > 1 then
		numberValue = numberValue / 255
	end
	return math.clamp(numberValue, 0, 1)
end

local function NTR_phase17Color3(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "table" then
		local r = NTR_phase17ColorComponent(value.R or value.r or value.Red or value.red or value[1])
		local g = NTR_phase17ColorComponent(value.G or value.g or value.Green or value.green or value[2])
		local b = NTR_phase17ColorComponent(value.B or value.b or value.Blue or value.blue or value[3])
		if r and g and b then
			return Color3.new(r, g, b)
		end
	end
	return fallback or Color3.fromRGB(255, 255, 255)
end

local function NTR_phase17ColorByte(color, channel)
	color = NTR_phase17Color3(color)
	return math.clamp(math.floor(((color[channel] or 0) * 255) + 0.5), 0, 255)
end

local function NTR_phase17Connect(signal, callback)
	if not signal or not signal.Connect then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:Connect(callback)
	end)
	if ok then
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
		baseColors = { ThrustColor = NTR_phase17Color3((State.Profile and State.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255)) }
	elseif State.Stage == "Customise" and State.CustomizeTarget and State.CustomizeTarget ~= "ALL" and State.CustomizeTarget ~= "Cockpit" and State.CustomizeTarget ~= "THRUST_COLOR" then
		local moduleColorSet = State.Profile and State.Profile.ModuleColors and State.Profile.ModuleColors[State.CustomizeTarget]
		if moduleColorSet then
			baseColors = moduleColorSet
		end
	end

	local current = NTR_phase17Color3(baseColors[State.ColorChannel], Color3.fromRGB(255, 255, 255))
	State.Hue, State.Saturation, State.Brightness = current:ToHSV()

	clear(UI.ColorChannelFloat)
	UI.ColorChannelFloat.Visible = true
	for _, channel in ipairs(channels) do
		local channelButton = button(UI.ColorChannelFloat, channelTitle(channel), UDim2.fromOffset(126, 30), UDim2.fromScale(0, 0), State.ColorChannel == channel and Theme.CardHot or Theme.Card)
		NTR_phase17Connect(channelButton.MouseButton1Click, function()
			State.ColorChannel = channel
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local preview = new("Frame", {
		BackgroundColor3 = current,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromOffset(6, 10),
	}, parent)
	corner(preview, 5)
	stroke(preview, Theme.Accent, 0.25, 1)

	local swatchPanel = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(214, 78),
		Position = UDim2.fromOffset(94, 10),
	}, parent)
	for i, preset in ipairs((State.Catalog and State.Catalog.PaintPresets) or {}) do
		local col = (i - 1) % 4
		local row = math.floor((i - 1) / 4)
		local presetColor = NTR_phase17Color3(preset.Color, Color3.fromRGB(255, 255, 255))
		local swatch = new("TextButton", {
			Text = "",
			BackgroundColor3 = presetColor,
			Size = UDim2.fromOffset(35, 26),
			Position = UDim2.fromOffset(col * 44, row * 34),
			BorderSizePixel = 0,
		}, swatchPanel)
		corner(swatch, 4)
		stroke(swatch, Theme.Accent, 0.2, 1)
		NTR_phase17Connect(swatch.MouseButton1Click, function()
			current = presetColor
			preview.BackgroundColor3 = current
			State.Hue, State.Saturation, State.Brightness = current:ToHSV()
			applyCallback(State.ColorChannel, current)
			renderColourPicker(parent, channels, applyCallback)
		end)
	end

	local controls = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -326, 0, 86),
		Position = UDim2.fromOffset(320, 6),
	}, parent)

	local values = {
		R = NTR_phase17ColorByte(current, "R"),
		G = NTR_phase17ColorByte(current, "G"),
		B = NTR_phase17ColorByte(current, "B"),
	}

	local function applyCurrent()
		current = Color3.fromRGB(values.R, values.G, values.B)
		preview.BackgroundColor3 = current
		State.Hue, State.Saturation, State.Brightness = current:ToHSV()
		applyCallback(State.ColorChannel, current)
	end

	local function row(name, y)
		label(controls, name, UDim2.fromOffset(18, 22), UDim2.fromOffset(0, y), 11, Enum.TextXAlignment.Left)
		local minus = button(controls, "-", UDim2.fromOffset(30, 22), UDim2.fromOffset(28, y), Theme.Card)
		local valueLabel = label(controls, tostring(values[name]), UDim2.fromOffset(42, 22), UDim2.fromOffset(64, y), 11, Enum.TextXAlignment.Center)
		local plus = button(controls, "+", UDim2.fromOffset(30, 22), UDim2.fromOffset(112, y), Theme.Card)
		local bar = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(39, 48, 49),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -158, 0, 10),
			Position = UDim2.fromOffset(152, y + 6),
		}, controls)
		corner(bar, 4)
		local fill = new("Frame", {
			BackgroundColor3 = name == "R" and Color3.fromRGB(255, 80, 80) or (name == "G" and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(90, 155, 255)),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(values[name] / 255, 1),
		}, bar)
		corner(fill, 4)
		local function refresh(delta)
			values[name] = math.clamp(values[name] + delta, 0, 255)
			valueLabel.Text = tostring(values[name])
			fill.Size = UDim2.fromScale(values[name] / 255, 1)
			applyCurrent()
		end
		NTR_phase17Connect(minus.MouseButton1Click, function()
			refresh(-8)
		end)
		NTR_phase17Connect(plus.MouseButton1Click, function()
			refresh(8)
		end)
	end

	row("R", 4)
	row("G", 31)
	row("B", 58)
end


]=]

source = replaceRange(source, "local function renderColourPicker(parent, channels, applyCallback)", "renderCockpitPaint = function()", newPicker, "Phase 17 root colour picker replacement")
bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ColorPickerRootRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_ROOT_REPAIR"), "Root colour picker repair marker missing after install.")
assert(not findPlain(finalSource, "local function compactSlider(name, y, value, update)"), "Old compact slider helper still exists after root repair.")
info("PASS: replaced fragile drag-slider colour picker with robust swatch/RGB-step picker.")
info("Next: stop Play, start a fresh Play session, enter the dealership, choose a cockpit, and confirm paint/customisation controls render.")
