-- Neo Tokyo Racers - Capture Current Edit Lighting To Night
-- Arrange Lighting exactly as desired in edit mode, then run this whole file
-- in the Roblox Studio Command Bar. The next Play session will use these values.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if RunService:IsRunning() then
	error("[NTR Lighting Capture] Stop Play mode before capturing edit-mode lighting.")
end

local PRESET_NAME = "ClearNight"
local SKY_NAME = "ClearNightSky"

local shared = ReplicatedStorage:WaitForChild("Shared")
local presetModule = shared
	:WaitForChild("LightingPresets")
	:WaitForChild("LightingPresets")
local skyPresets = shared:WaitForChild("SkyPresets")

local freshModule = presetModule:Clone()
freshModule.Name = "_NTR_LightingPresetsCapture"
freshModule.Parent = ServerStorage

local success, presets = pcall(require, freshModule)
freshModule:Destroy()

if not success or type(presets) ~= "table" then
	error("[NTR Lighting Capture] Could not load LightingPresets: " .. tostring(presets))
end

local function capture(instance, propertyNames)
	local result = {}
	for _, propertyName in ipairs(propertyNames) do
		local ok, value = pcall(function()
			return instance[propertyName]
		end)
		if ok then
			result[propertyName] = value
		end
	end
	return result
end

local function findEffect(className, preferredName)
	local preferred = Lighting:FindFirstChild(preferredName)
	if preferred and preferred.ClassName == className then
		return preferred
	end
	return Lighting:FindFirstChildOfClass(className)
end

local captured = {
	SkyName = SKY_NAME,
	Lighting = capture(Lighting, {
		"ClockTime",
		"Brightness",
		"Ambient",
		"OutdoorAmbient",
		"ColorShift_Top",
		"ColorShift_Bottom",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
		"ExposureCompensation",
		"FogColor",
		"FogEnd",
		"FogStart",
		"ShadowSoftness",
		"GlobalShadows",
	}),
}

local effectSpecs = {
	Atmosphere = {
		ClassName = "Atmosphere",
		Name = "Atmosphere",
		Properties = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
	},
	ColorCorrection = {
		ClassName = "ColorCorrectionEffect",
		Name = "ColorCorrection",
		Properties = {"Brightness", "Contrast", "Saturation", "TintColor", "Enabled"},
	},
	Bloom = {
		ClassName = "BloomEffect",
		Name = "Bloom",
		Properties = {"Intensity", "Size", "Threshold", "Enabled"},
	},
	SunRays = {
		ClassName = "SunRaysEffect",
		Name = "SunRays",
		Properties = {"Intensity", "Spread", "Enabled"},
	},
	DepthOfField = {
		ClassName = "DepthOfFieldEffect",
		Name = "DepthOfField",
		Properties = {"FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity", "Enabled"},
	},
}

for sectionName, spec in pairs(effectSpecs) do
	local effect = findEffect(spec.ClassName, spec.Name)
	if effect then
		captured[sectionName] = capture(effect, spec.Properties)
	end
end

local activeSky = Lighting:FindFirstChild("ActiveSky")
if not activeSky or not activeSky:IsA("Sky") then
	activeSky = Lighting:FindFirstChildOfClass("Sky")
end

if activeSky then
	local oldSky = skyPresets:FindFirstChild(SKY_NAME)
	if oldSky then
		oldSky:Destroy()
	end

	local skyClone = activeSky:Clone()
	skyClone.Name = SKY_NAME
	skyClone.Parent = skyPresets
else
	warn("[NTR Lighting Capture] No Sky found in Lighting; existing ClearNightSky was preserved.")
end

presets[PRESET_NAME] = captured

local function serialize(value, indent)
	indent = indent or 0
	local valueType = typeof(value)

	if valueType == "nil" then
		return "nil"
	elseif valueType == "boolean" or valueType == "number" then
		return tostring(value)
	elseif valueType == "string" then
		return string.format("%q", value)
	elseif valueType == "Color3" then
		return string.format(
			"Color3.new(%.17g, %.17g, %.17g)",
			value.R,
			value.G,
			value.B
		)
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType ~= "table" then
		error("[NTR Lighting Capture] Cannot serialize value type: " .. valueType)
	end

	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local lines = {"{"}
	local childIndent = string.rep("\t", indent + 1)

	for _, key in ipairs(keys) do
		local keySource
		if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then
			keySource = key
		else
			keySource = "[" .. serialize(key, indent + 1) .. "]"
		end

		table.insert(lines, string.format(
			"%s%s = %s,",
			childIndent,
			keySource,
			serialize(value[key], indent + 1)
		))
	end

	table.insert(lines, string.rep("\t", indent) .. "}")
	return table.concat(lines, "\n")
end

presetModule.Source = "local LightingPresets = " .. serialize(presets) .. "\n\nreturn LightingPresets\n"
Lighting:SetAttribute("NTR_LightingPreset", PRESET_NAME)

print("[NTR Lighting Capture] Saved current edit-mode lighting to ClearNight.")
print("[NTR Lighting Capture] Start a fresh Play session to verify it.")
