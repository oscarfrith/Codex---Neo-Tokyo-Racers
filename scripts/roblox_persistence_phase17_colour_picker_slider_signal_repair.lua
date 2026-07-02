-- Persistence Phase 17 colour picker slider signal repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if cockpit/customisation
-- colour UI still fails after the Color3 repair with:
--
--   NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:1962: attempt to call a nil value
--
-- Studio line 1962 maps to the compact slider InputBegan connection after the
-- previous repair. This keeps the UI the same, but makes slider signal hookups
-- guarded so a missing/odd GuiObject signal cannot stop the whole paint menu.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Colour Slider Signal Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, oldText, newText, label)
	local first = findPlain(source, oldText)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 17 client repair.")
	local second = findPlain(source, oldText, first + #oldText)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another Phase 17 client repair.")
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, "local function renderColourPicker(parent, channels, applyCallback)"), "Expected renderColourPicker in active client bootstrap.")

if findPlain(source, "NTR_PERSISTENCE_PHASE17_COLOR_SLIDER_SIGNAL_REPAIR") then
	info("PASS: colour slider signal repair is already installed.")
else
	local oldBlock = [[	local function compactSlider(name, y, value, update)
		label(sliderPanel, name, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
		local track = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, -72, 0, 15), Position = UDim2.fromOffset(24, y + 3), BorderSizePixel = 0 }, sliderPanel)
		corner(track, 5)
		stroke(track, Theme.Accent, 0.35, 1)
		local gradient = new("UIGradient", {}, track)
		local knob = new("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(11, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), BorderSizePixel = 0 }, track)
		corner(knob, 4)
		local valueLabel = label(sliderPanel, name == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"), UDim2.fromOffset(42, 20), UDim2.new(1, -42, 0, y), 10, Enum.TextXAlignment.Left)
		local dragging = false
		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			valueLabel.Text = name == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
			update(rel)
		end
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		track.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
		end)
		local move = UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		table.insert(pickerConnections, move)
		return gradient
	end]]

	local newBlock = [[	-- NTR_PERSISTENCE_PHASE17_COLOR_SLIDER_SIGNAL_REPAIR
	local function compactSlider(name, y, value, update)
		value = tonumber(value) or (name == "H" and 0 or 1)
		update = typeof(update) == "function" and update or function() end
		label(sliderPanel, name, UDim2.fromOffset(18, 20), UDim2.fromOffset(0, y), 10, Enum.TextXAlignment.Left)
		local track = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, -72, 0, 15), Position = UDim2.fromOffset(24, y + 3), BorderSizePixel = 0 }, sliderPanel)
		corner(track, 5)
		stroke(track, Theme.Accent, 0.35, 1)
		local gradient = new("UIGradient", {}, track)
		local knob = new("Frame", { BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(11, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), BorderSizePixel = 0 }, track)
		corner(knob, 4)
		local valueLabel = label(sliderPanel, name == "H" and tostring(math.floor(value * 360)) or (tostring(math.floor(value * 100)) .. "%"), UDim2.fromOffset(42, 20), UDim2.new(1, -42, 0, y), 10, Enum.TextXAlignment.Left)
		local dragging = false
		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			valueLabel.Text = name == "H" and tostring(math.floor(rel * 360)) or (tostring(math.floor(rel * 100)) .. "%")
			update(rel)
		end
		local function safeConnect(signal, callback)
			if typeof(signal) ~= "RBXScriptSignal" then
				return
			end
			local ok, connection = pcall(function()
				return signal:Connect(callback)
			end)
			if ok and connection then
				table.insert(pickerConnections, connection)
			end
		end
		safeConnect(track.MouseButton1Down, function(x)
			dragging = true
			setFromX(x)
		end)
		safeConnect(track.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X)
			end
		end)
		safeConnect(track.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		safeConnect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		safeConnect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X)
			end
		end)
		return gradient
	end]]

	source = replaceOnce(source, oldBlock, newBlock, "Phase 17 compact colour slider signal hookup")
	bootstrap.Source = source
	bootstrap:SetAttribute("PersistencePhase17ColorSliderSignalRepair", true)
	info("PASS: installed guarded colour slider signal hookups.")
end

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR_SLIDER_SIGNAL_REPAIR"), "Colour slider signal repair marker missing after install.")
info("Next: stop Play, start a fresh Play session, enter the dealership, choose a cockpit, and confirm paint controls render.")
