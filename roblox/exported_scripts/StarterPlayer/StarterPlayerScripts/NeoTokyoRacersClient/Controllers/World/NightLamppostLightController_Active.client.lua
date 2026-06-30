local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local LIGHT_TAG = "NTR_NightLamppostLight"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

local function readNightMode()
	local presetName = Lighting:GetAttribute(PRESET_ATTRIBUTE)

	if type(presetName) == "string" then
		local normalized = string.lower(presetName)

		if string.find(normalized, "night", 1, true) then
			return true
		end

		if string.find(normalized, "day", 1, true) then
			return false
		end
	end

	-- ClearNight currently uses ClockTime 12.1, so Brightness is the reliable
	-- fallback for the existing N/M lighting preview controller.
	return Lighting.Brightness <= NIGHT_BRIGHTNESS_THRESHOLD
end

local currentNightMode = nil

local function applyToLight(instance, isNight)
	if instance:IsA("SurfaceLight") then
		instance.Enabled = isNight
	end
end

local function refreshAll(force)
	local isNight = readNightMode()

	if not force and currentNightMode == isNight then
		return
	end

	currentNightMode = isNight

	for _, instance in ipairs(CollectionService:GetTagged(LIGHT_TAG)) do
		applyToLight(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(function(instance)
	applyToLight(instance, readNightMode())
end)

Lighting:GetAttributeChangedSignal(PRESET_ATTRIBUTE):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
	refreshAll(false)
end)

refreshAll(true)
