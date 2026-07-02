-- Persistence Phase 17 colour picker Color3 repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if cockpit/customisation
-- colour UI fails inside renderColourPicker with:
--
--   NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:1928: attempt to call a nil value
--
-- The picker can receive persisted/encoded colour tables instead of raw Color3
-- values. This repair keeps the UI unchanged but normalizes common colour shapes
-- before HSV conversion.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Colour Picker Color3 Repair"

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

if findPlain(source, "NTR_PERSISTENCE_PHASE17_COLOR3_PICKER_REPAIR") then
	info("PASS: colour picker Color3 repair is already installed.")
else
	local oldBlock = [[local function toHSV(color)
	local ok, h, s, v = pcall(function() return color:ToHSV() end)
	if ok then return h, s, v end
	return Color3.toHSV(color)
end

local function syncPicker(color)
	local h, s, v = toHSV(color)
	State.Hue, State.Saturation, State.Brightness = h, s, v
end

local function pickerColor()
	return Color3.fromHSV(State.Hue, State.Saturation, State.Brightness)
end]]

	local newBlock = [[-- NTR_PERSISTENCE_PHASE17_COLOR3_PICKER_REPAIR
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

local function toHSV(color)
	color = NTR_phase17Color3(color, Color3.fromRGB(255, 255, 255))
	local ok, h, s, v = pcall(function()
		return color:ToHSV()
	end)
	if ok then
		return h, s, v
	end
	return 0, 0, 1
end

local function syncPicker(color)
	local h, s, v = toHSV(color)
	State.Hue = tonumber(h) or 0
	State.Saturation = tonumber(s) or 0
	State.Brightness = tonumber(v) or 1
end

local function pickerColor()
	return Color3.fromHSV(tonumber(State.Hue) or 0, tonumber(State.Saturation) or 0, tonumber(State.Brightness) or 1)
end]]

	source = replaceOnce(source, oldBlock, newBlock, "Phase 17 robust colour picker HSV helpers")
	bootstrap.Source = source
	bootstrap:SetAttribute("PersistencePhase17ColorPickerColor3Repair", true)
	info("PASS: installed robust colour normalization for the cockpit/module colour picker.")
end

local finalSource = bootstrap.Source
assert(findPlain(finalSource, "NTR_PERSISTENCE_PHASE17_COLOR3_PICKER_REPAIR"), "Colour picker repair marker missing after install.")
assert(findPlain(finalSource, "local function NTR_phase17Color3(value, fallback)"), "Colour coercion helper missing after install.")
info("Next: stop Play, start a fresh Play session, enter the dealership, choose a cockpit, and confirm the paint swatches/sliders show.")
