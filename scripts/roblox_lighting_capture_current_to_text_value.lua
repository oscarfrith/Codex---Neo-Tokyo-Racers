-- Neo Tokyo Racers - Capture Current Lighting Setup To A StringValue
-- Run this whole file in the Roblox Studio Command Bar while NOT playing.
--
-- Read-only toward the lighting system: it does not change presets, Lighting,
-- effects, Sky, windows, street lights, or runtime scripts. It only creates or
-- refreshes one StringValue containing a deterministic Lua table snapshot.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	error("[NTR Lighting Text Capture] Stop Play mode and run this from Edit mode.")
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local cycleConfig = shared:WaitForChild("LightingCycleConfig")
local OUTPUT_NAME = "CurrentLightingCaptureText"

local function captureProperties(instance, propertyNames)
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

local currentPreset = Lighting:GetAttribute("NTR_LightingPreset")
if type(currentPreset) ~= "string" or currentPreset == "" then
	currentPreset = "Unspecified"
end

local snapshot = {
	Format = "NTRLightingTextCaptureV1",
	CapturedAtUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	CurrentPreset = currentPreset,
	Lighting = captureProperties(Lighting, {
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
		"GeographicLatitude",
		"GlobalShadows",
		"ShadowSoftness",
	}),
}

local effectSpecs = {
	Atmosphere = {
		ClassName = "Atmosphere",
		Name = "Atmosphere",
		Properties = {"Density", "Offset", "Color", "Decay", "Glare", "Haze"},
	},
	Bloom = {
		ClassName = "BloomEffect",
		Name = "Bloom",
		Properties = {"Enabled", "Intensity", "Size", "Threshold"},
	},
	Blur = {
		ClassName = "BlurEffect",
		Name = "Blur",
		Properties = {"Enabled", "Size"},
	},
	ColorCorrection = {
		ClassName = "ColorCorrectionEffect",
		Name = "ColorCorrection",
		Properties = {"Enabled", "Brightness", "Contrast", "Saturation", "TintColor"},
	},
	DepthOfField = {
		ClassName = "DepthOfFieldEffect",
		Name = "DepthOfField",
		Properties = {"Enabled", "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity"},
	},
	SunRays = {
		ClassName = "SunRaysEffect",
		Name = "SunRays",
		Properties = {"Enabled", "Intensity", "Spread"},
	},
}

for sectionName, spec in pairs(effectSpecs) do
	local effect = findEffect(spec.ClassName, spec.Name)
	if effect then
		snapshot[sectionName] = captureProperties(effect, spec.Properties)
	end
end

local activeSky = Lighting:FindFirstChild("ActiveSky")
if not activeSky or not activeSky:IsA("Sky") then
	activeSky = Lighting:FindFirstChildOfClass("Sky")
end
if activeSky then
	snapshot.Sky = captureProperties(activeSky, {
		"CelestialBodiesShown",
		"MoonAngularSize",
		"MoonTextureId",
		"SkyboxBk",
		"SkyboxDn",
		"SkyboxFt",
		"SkyboxLf",
		"SkyboxOrientation",
		"SkyboxRt",
		"SkyboxUp",
		"StarCount",
		"SunAngularSize",
		"SunTextureId",
	})
	snapshot.Sky.SourceName = activeSky.Name
end

local stageVisuals = cycleConfig:FindFirstChild("StageVisuals")
local visualFolder = stageVisuals and stageVisuals:FindFirstChild(currentPreset)
if visualFolder and visualFolder:IsA("Folder") then
	snapshot.StageVisualConfig = {
		WindowMode = visualFolder:GetAttribute("WindowMode"),
		StreetLightsEnabled = visualFolder:GetAttribute("StreetLightsEnabled"),
		StreetLightBrightness = visualFolder:GetAttribute("StreetLightBrightness"),
	}
end

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
		return string.format("Color3.new(%.17g, %.17g, %.17g)", value.R, value.G, value.B)
	elseif valueType == "Vector3" then
		return string.format("Vector3.new(%.17g, %.17g, %.17g)", value.X, value.Y, value.Z)
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType ~= "table" then
		error("[NTR Lighting Text Capture] Cannot serialize value type: " .. valueType)
	end

	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local lines = {"{"}
	for _, key in ipairs(keys) do
		local keySource = type(key) == "string" and string.match(key, "^[%a_][%w_]*$") and key
			or ("[" .. serialize(key, indent + 1) .. "]")
		table.insert(lines, string.format(
			"%s%s = %s,",
			string.rep("\t", indent + 1),
			keySource,
			serialize(value[key], indent + 1)
		))
	end
	table.insert(lines, string.rep("\t", indent) .. "}")
	return table.concat(lines, "\n")
end

local output = cycleConfig:FindFirstChild(OUTPUT_NAME)
if output and not output:IsA("StringValue") then
	error("[NTR Lighting Text Capture] Existing output is not a StringValue: " .. output:GetFullName())
end
if not output then
	output = Instance.new("StringValue")
	output.Name = OUTPUT_NAME
	output.Parent = cycleConfig
end

output.Value = "return " .. serialize(snapshot) .. "\n"
output:SetAttribute("CapturedAtUTC", snapshot.CapturedAtUTC)
output:SetAttribute("CapturedPreset", currentPreset)
output:SetAttribute("Format", snapshot.Format)

print("[NTR Lighting Text Capture] Saved current setup to " .. output:GetFullName())
print("[NTR Lighting Text Capture] Characters: " .. tostring(#output.Value))
print("[NTR Lighting Text Capture] Select the StringValue and copy its Value property.")
