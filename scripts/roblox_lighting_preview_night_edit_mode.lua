-- Neo Tokyo Racers - Edit Mode Night Preview
-- Run this entire file in the Roblox Studio Command Bar.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PRESET_NAME = "ClearNight"
local WINDOW_TAG = "NTR_WindowMaterial"
local WINDOW_VARIANT_NAME = "Windows Night"
local LAMPPOST_LIGHT_TAG = "NTR_NightLamppostLight"

local shared = ReplicatedStorage:WaitForChild("Shared")
local lightingPresets = require(
	shared
		:WaitForChild("LightingPresets")
		:WaitForChild("LightingPresets")
)
local skyPresets = shared:WaitForChild("SkyPresets")

local preset = lightingPresets[PRESET_NAME]
if not preset then
	error("[NTR Lighting Preview] Missing lighting preset: " .. PRESET_NAME)
end

local windowVariant = MaterialService:FindFirstChild(WINDOW_VARIANT_NAME, true)
if not windowVariant or not windowVariant:IsA("MaterialVariant") then
	error("[NTR Lighting Preview] Missing MaterialVariant: " .. WINDOW_VARIANT_NAME)
end

local function getOrCreateEffect(className, name)
	local effect = Lighting:FindFirstChild(name)
	if effect and effect.ClassName == className then
		return effect
	end

	if effect then
		effect:Destroy()
	end

	effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local function applyProperties(instance, properties)
	for propertyName, value in pairs(properties or {}) do
		if instance == Lighting and propertyName == "Fogcolor" then
			propertyName = "FogColor"
		end

		local success, err = pcall(function()
			instance[propertyName] = value
		end)

		if not success then
			warn("[NTR Lighting Preview] Could not apply property:", instance.Name, propertyName, err)
		end
	end
end

local atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere")
local colorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection")
local bloom = getOrCreateEffect("BloomEffect", "Bloom")
local sunRays = getOrCreateEffect("SunRaysEffect", "SunRays")
local depthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField")

applyProperties(Lighting, preset.Lighting)
applyProperties(atmosphere, preset.Atmosphere)
applyProperties(colorCorrection, preset.ColorCorrection)
applyProperties(bloom, preset.Bloom)
applyProperties(sunRays, preset.SunRays)
applyProperties(depthOfField, preset.DepthOfField)

if preset.SkyName then
	local skyTemplate = skyPresets:FindFirstChild(preset.SkyName)
	if not skyTemplate or not skyTemplate:IsA("Sky") then
		error("[NTR Lighting Preview] Missing Sky preset: " .. preset.SkyName)
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end

	local activeSky = skyTemplate:Clone()
	activeSky.Name = "ActiveSky"
	activeSky.Parent = Lighting
end

local windowCount = 0
for _, instance in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do
	if instance:IsA("MeshPart") then
		instance.Material = windowVariant.BaseMaterial
		instance.MaterialVariant = windowVariant.Name
		windowCount += 1
	end
end

local lamppostLightCount = 0
for _, instance in ipairs(CollectionService:GetTagged(LAMPPOST_LIGHT_TAG)) do
	if instance:IsA("SurfaceLight") then
		instance.Enabled = true
		lamppostLightCount += 1
	end
end

Lighting:SetAttribute("NTR_LightingPreset", PRESET_NAME)

print(string.format(
	"[NTR Lighting Preview] Applied %s in edit mode; updated %d windows and enabled %d lamppost lights.",
	PRESET_NAME,
	windowCount,
	lamppostLightCount
))
