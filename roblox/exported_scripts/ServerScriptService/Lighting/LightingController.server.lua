local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local LightingPresets = require(
	Shared
		:WaitForChild("LightingPresets")
		:WaitForChild("LightingPresets")
)

local SkyPresets = Shared:WaitForChild("SkyPresets")

-- Change this between "Day" and "ClearNight" for testing.
local CURRENT_PRESET = "Day"

local function getOrCreateEffect(className, name)
	local existing = Lighting:FindFirstChild(name)

	if existing then
		return existing
	end

	local newEffect = Instance.new(className)
	newEffect.Name = name
	newEffect.Parent = Lighting

	return newEffect
end

local atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere")
local colorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection")
local bloom = getOrCreateEffect("BloomEffect", "Bloom")
local sunRays = getOrCreateEffect("SunRaysEffect", "SunRays")
local depthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField")

local function applyProperties(instance, properties)
	if not properties then
		return
	end

	for propertyName, value in pairs(properties) do
		local success, err = pcall(function()
			instance[propertyName] = value
		end)

		if not success then
			warn("Could not apply property:", instance.Name, propertyName, err)
		end
	end
end

local function clearCurrentSky()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applySky(skyName)
	if not skyName then
		return
	end

	local skyTemplate = SkyPresets:FindFirstChild(skyName)

	if not skyTemplate then
		warn("Sky preset not found:", skyName)
		return
	end

	clearCurrentSky()

	local newSky = skyTemplate:Clone()
	newSky.Name = "ActiveSky"
	newSky.Parent = Lighting
end

local function applyLightingPreset(presetName)
	local preset = LightingPresets[presetName]

	if not preset then
		warn("Lighting preset does not exist:", presetName)
		return
	end

	applyProperties(Lighting, preset.Lighting)
	applyProperties(atmosphere, preset.Atmosphere)
	applyProperties(colorCorrection, preset.ColorCorrection)
	applyProperties(bloom, preset.Bloom)
	applyProperties(sunRays, preset.SunRays)
	applyProperties(depthOfField, preset.DepthOfField)

	applySky(preset.SkyName)

	print("Applied lighting preset:", presetName)
end

applyLightingPreset(CURRENT_PRESET)