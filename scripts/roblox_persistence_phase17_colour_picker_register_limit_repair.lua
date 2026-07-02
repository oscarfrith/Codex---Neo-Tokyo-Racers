-- Persistence Phase 17 colour picker register-limit repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play reports:
--
--   Out of local registers when trying to allocate mobileInputState: exceeded limit 200
--
-- Root cause:
-- The active client bootstrap is already near Roblox's 200 local-register limit.
-- The colour picker repair ladder can leave extra top-level local helper
-- functions behind. This removes those bulky helper blocks and reinstalls the
-- robust swatch/RGB-step picker through NTRPersistencePhase15 table methods
-- instead of more top-level locals.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Colour Picker Register Repair"

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

local function removeRangeIfPresent(source, startText, endText, label)
	local startIndex = findPlain(source, startText)
	if not startIndex then
		return source, false
	end
	local endIndex = findPlain(source, endText, startIndex + #startText)
	assert(endIndex, "Found start but not end while removing " .. label .. ". Refresh the Studio mirror before another Phase 17 client repair.")
	return string.sub(source, 1, startIndex - 1) .. string.sub(source, endIndex), true
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "renderCockpitPaint = function()"), "Expected renderCockpitPaint anchor after colour picker.")

local hasPhase15LocalTable = findPlain(source, "local NTRPersistencePhase15 = {}") ~= nil
local hasPhase15GlobalTable = findPlain(source, "NTRPersistencePhase15 = NTRPersistencePhase15 or {}") ~= nil

local removedColor3Block = false
source, removedColor3Block = removeRangeIfPresent(
	source,
	"-- NTR_PERSISTENCE_PHASE17_COLOR3_PICKER_REPAIR",
	"local function makeSlider(parent, name, y, value, update)",
	"old Phase 17 Color3 picker helper block"
)

local removedMakeSlider = false
source, removedMakeSlider = removeRangeIfPresent(
	source,
	"local function makeSlider(parent, name, y, value, update)",
	"local function channelTitle(channel)",
	"unused legacy makeSlider helper"
)

local leanPicker = [=[
-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_REGISTER_REPAIR
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

function NTRPersistencePhase15.ColorByte(color, channel)
	color = NTRPersistencePhase15.Color3Value(color)
	return math.clamp(math.floor(((color[channel] or 0) * 255) + 0.5), 0, 255)
end

function NTRPersistencePhase15.SafeConnectPicker(signal, callback)
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
		R = NTRPersistencePhase15.ColorByte(current, "R"),
		G = NTRPersistencePhase15.ColorByte(current, "G"),
		B = NTRPersistencePhase15.ColorByte(current, "B"),
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
		NTRPersistencePhase15.SafeConnectPicker(minus.MouseButton1Click, function()
			refresh(-8)
		end)
		NTRPersistencePhase15.SafeConnectPicker(plus.MouseButton1Click, function()
			refresh(8)
		end)
	end

	row("R", 4)
	row("G", 31)
	row("B", 58)
end


]=]

if hasPhase15LocalTable or hasPhase15GlobalTable then
	leanPicker = string.gsub(leanPicker, "NTRPersistencePhase15 = NTRPersistencePhase15 or %{%}\n\n", "", 1)
end

if findPlain(source, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_ROOT_REPAIR") then
	source = replaceRange(
		source,
		"-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_ROOT_REPAIR",
		"renderCockpitPaint = function()",
		leanPicker,
		"Phase 17 bulky root colour picker replacement"
	)
elseif findPlain(source, "local function renderColourPicker(parent, channels, applyCallback)") then
	source = replaceRange(
		source,
		"local function renderColourPicker(parent, channels, applyCallback)",
		"renderCockpitPaint = function()",
		leanPicker,
		"Phase 17 lean colour picker replacement"
	)
else
	error("Could not find any colour picker function to replace. Refresh the Studio mirror before another Phase 17 client repair.")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17ColorPickerRegisterRepair", true)

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR_PICKER_REGISTER_REPAIR"), "Register-limit colour picker marker missing after install.")
assert(not findPlain(finalSource, "-- NTR_PERSISTENCE_PHASE17_COLOR3_PICKER_REPAIR"), "Old Color3 picker local-helper block still exists after cleanup.")
assert(not findPlain(finalSource, "-- NTR_PERSISTENCE_PHASE17_COLOR_PICKER_ROOT_REPAIR"), "Bulky root picker marker still exists after cleanup.")
assert(not findPlain(finalSource, "local function NTR_phase17ColorComponent"), "Top-level local colour component helper still exists after cleanup.")
assert(not findPlain(finalSource, "local function makeSlider(parent, name, y, value, update)"), "Unused legacy makeSlider helper still exists after cleanup.")

info("PASS: installed lean table-backed colour picker.")
info("PASS: Phase 15 helper table source form: local=" .. tostring(hasPhase15LocalTable) .. ", global=" .. tostring(hasPhase15GlobalTable))
info("PASS: removed old Color3 helper block: " .. tostring(removedColor3Block))
info("PASS: removed unused makeSlider helper: " .. tostring(removedMakeSlider))
info("Next: stop Play, start a fresh Play session, and confirm the client no longer hits the mobileInputState register limit.")
