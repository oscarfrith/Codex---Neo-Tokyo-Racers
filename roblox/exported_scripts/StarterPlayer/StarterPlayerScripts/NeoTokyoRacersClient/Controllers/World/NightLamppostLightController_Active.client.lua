local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local WINDOW_TAG = "NTR_WindowMaterial"
local LIGHT_TAG = "NTR_NightLamppostLight"
local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

local function findMaterialVariant(name)
	local candidate = MaterialService:FindFirstChild(name, true)
	if candidate and candidate:IsA("MaterialVariant") then
		return candidate
	end
	return nil
end

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

	if Lighting.Brightness <= NIGHT_BRIGHTNESS_THRESHOLD then
		return true
	end

	local clockTime = Lighting.ClockTime
	return clockTime < 6 or clockTime >= 18
end

local currentNightMode = nil

local function applyWindow(instance, isNight)
	if not instance:IsA("MeshPart") then
		return
	end

	local variant = findMaterialVariant(isNight and NIGHT_VARIANT_NAME or DAY_VARIANT_NAME)
	if not variant then
		warn("[NTR Lighting Runtime] Missing MaterialVariant:", isNight and NIGHT_VARIANT_NAME or DAY_VARIANT_NAME)
		return
	end

	instance.Material = variant.BaseMaterial
	instance.MaterialVariant = variant.Name
end

local function applyLight(instance, isNight)
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

	for _, instance in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do
		applyWindow(instance, isNight)
	end

	for _, instance in ipairs(CollectionService:GetTagged(LIGHT_TAG)) do
		applyLight(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(WINDOW_TAG):Connect(function(instance)
	applyWindow(instance, readNightMode())
end)

CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(function(instance)
	applyLight(instance, readNightMode())
end)

Lighting:GetAttributeChangedSignal(PRESET_ATTRIBUTE):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
	refreshAll(false)
end)

refreshAll(true)
