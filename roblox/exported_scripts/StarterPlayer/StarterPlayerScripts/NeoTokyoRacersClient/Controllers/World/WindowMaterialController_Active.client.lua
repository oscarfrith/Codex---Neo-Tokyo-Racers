local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local WINDOW_TAG = "NTR_WindowMaterial"
local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

local function waitForMaterialVariant(name)
	local variant = MaterialService:FindFirstChild(name, true)

	while not variant do
		MaterialService.DescendantAdded:Wait()
		variant = MaterialService:FindFirstChild(name, true)
	end

	return variant
end

local dayVariant = waitForMaterialVariant(DAY_VARIANT_NAME)
local nightVariant = waitForMaterialVariant(NIGHT_VARIANT_NAME)

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

local function applyToPart(instance, isNight)
	if not instance:IsA("MeshPart") then
		return
	end

	local variant = isNight and nightVariant or dayVariant
	instance.Material = variant.BaseMaterial
	instance.MaterialVariant = variant.Name
end

local function refreshAll(force)
	local isNight = readNightMode()

	if not force and currentNightMode == isNight then
		return
	end

	currentNightMode = isNight

	for _, instance in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do
		applyToPart(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(WINDOW_TAG):Connect(function(instance)
	applyToPart(instance, readNightMode())
end)

Lighting:GetAttributeChangedSignal(PRESET_ATTRIBUTE):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
	refreshAll(false)
end)

refreshAll(true)
