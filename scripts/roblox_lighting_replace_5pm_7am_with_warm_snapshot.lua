-- Neo Tokyo Racers - Replace FivePM And SevenAM With Warm Snapshot
-- Run this whole file once in Roblox Studio Edit mode.
--
-- Replaces only the FivePM/SevenAM environment presets and their separate Sky
-- assets using the user-provided 2026-07-13T23:28:12Z snapshot. StageVisuals
-- window mode, street-light enabled state, and brightness are preserved.
-- No in-game backups and no fragile source-text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if RunService:IsRunning() then
	error("[NTR Warm Snapshot] Stop Play mode and run this from Edit mode.")
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local presetModule = shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets")
local skyPresets = shared:WaitForChild("SkyPresets")
local cycleConfig = shared:WaitForChild("LightingCycleConfig")
local stageVisuals = cycleConfig:FindFirstChild("StageVisuals")

if not presetModule:IsA("ModuleScript") then
	error("[NTR Warm Snapshot] LightingPresets is not a ModuleScript.")
end
if not skyPresets:IsA("Folder") then
	error("[NTR Warm Snapshot] SkyPresets is not a Folder.")
end

local function freshRequire(moduleScript, cloneName)
	local clone = moduleScript:Clone()
	clone.Name = cloneName
	clone.Parent = ServerStorage
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok or type(result) ~= "table" then
		error("[NTR Warm Snapshot] Could not load LightingPresets: " .. tostring(result))
	end
	return result
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local replacement = {
	Atmosphere = {
		Color = Color3.new(0.43921571969985962, 0.35686275362968445, 0.32549020648002625),
		Decay = Color3.new(0.86666673421859741, 0.63921570777893066, 0.62352943420410156),
		Density = 0.2370000034570694,
		Glare = 6.900000095367432,
		Haze = 5.400000095367432,
		Offset = 0,
	},
	Bloom = {
		Enabled = true,
		Intensity = 1,
		Size = 10,
		Threshold = 0.699999988079071,
	},
	ColorCorrection = {
		Brightness = 0,
		Contrast = 0.20000000298023224,
		Enabled = true,
		Saturation = 0.4000000059604645,
		TintColor = Color3.new(0.88235300779342651, 0.94509810209274292, 1),
	},
	DepthOfField = {
		Enabled = false,
		FarIntensity = 0.08399999886751175,
		FocusDistance = 0.05000000074505806,
		InFocusRadius = 10,
		NearIntensity = 0.75,
	},
	Lighting = {
		Ambient = Color3.new(1, 0.94509804248809814, 0.91764706373214722),
		Brightness = 0.2199999988079071,
		ClockTime = 13.699999809265137,
		ColorShift_Bottom = Color3.new(0, 0, 0),
		ColorShift_Top = Color3.new(0.4901961088180542, 0.46666669845581055, 0.40784317255020142),
		EnvironmentDiffuseScale = 0.20100000500679016,
		EnvironmentSpecularScale = 1,
		ExposureCompensation = -0.44999998807907104,
		FogColor = Color3.new(0.75294119119644165, 0.75294119119644165, 0.75294119119644165),
		FogEnd = 100000,
		FogStart = 0,
		GeographicLatitude = 189,
		GlobalShadows = true,
		OutdoorAmbient = Color3.new(0.90980398654937744, 0.84705889225006104, 0.81176477670669556),
		ShadowSoftness = 0.20000000298023224,
	},
	SunRays = {
		Enabled = false,
		Intensity = 0.05000000074505806,
		Spread = 0.7129999995231628,
	},
}

local skyProperties = {
	CelestialBodiesShown = true,
	MoonAngularSize = 11,
	MoonTextureId = "rbxasset://sky/moon.jpg",
	SkyboxBk = "rbxassetid://18351376859",
	SkyboxDn = "rbxassetid://18351374919",
	SkyboxFt = "rbxassetid://18351376800",
	SkyboxLf = "rbxassetid://18351376469",
	SkyboxOrientation = Vector3.new(0, 90, 0),
	SkyboxRt = "rbxassetid://18351376457",
	SkyboxUp = "rbxassetid://18351377189",
	StarCount = 3000,
	SunAngularSize = 21,
	SunTextureId = "rbxasset://sky/sun.jpg",
}

-- Validate every supplied Sky property before touching either stored Sky.
local skyProbe = Instance.new("Sky")
skyProbe.Name = "_NTR_WarmSnapshotSkyProbe"
skyProbe.Parent = ServerStorage
for propertyName, value in pairs(skyProperties) do
	local ok, err = pcall(function()
		skyProbe[propertyName] = value
	end)
	if not ok then
		skyProbe:Destroy()
		error("[NTR Warm Snapshot] Sky preflight failed for " .. propertyName .. ": " .. tostring(err))
	end
end
skyProbe:Destroy()

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
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType ~= "table" then
		error("[NTR Warm Snapshot] Cannot serialize value type: " .. valueType)
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

local presets = freshRequire(presetModule, "_NTR_WarmSnapshotRead")
local targets = {
	{PresetName = "FivePM", SkyName = "FivePMSky"},
	{PresetName = "SevenAM", SkyName = "SevenAMSky"},
}
for _, target in ipairs(targets) do
	local existingSky = skyPresets:FindFirstChild(target.SkyName)
	if existingSky and not existingSky:IsA("Sky") then
		error("[NTR Warm Snapshot] Existing Sky target is not a Sky: " .. existingSky:GetFullName())
	end
end

for _, target in ipairs(targets) do
	local preset = deepCopy(replacement)
	preset.SkyName = target.SkyName
	presets[target.PresetName] = preset

	local sky = skyPresets:FindFirstChild(target.SkyName)
	if not sky then
		sky = Instance.new("Sky")
		sky.Name = target.SkyName
		sky.Parent = skyPresets
	end
	for propertyName, value in pairs(skyProperties) do
		local ok, err = pcall(function()
			sky[propertyName] = value
		end)
		if not ok then
			error("[NTR Warm Snapshot] Could not set " .. target.SkyName .. "." .. propertyName .. ": " .. tostring(err))
		end
	end
end

presetModule.Source = "local LightingPresets = " .. serialize(presets) .. "\n\nreturn LightingPresets\n"

local verified = freshRequire(presetModule, "_NTR_WarmSnapshotVerify")
for _, presetName in ipairs({"FivePM", "SevenAM"}) do
	local preset = verified[presetName]
	if not preset
		or preset.Lighting.ClockTime ~= replacement.Lighting.ClockTime
		or preset.Lighting.ExposureCompensation ~= replacement.Lighting.ExposureCompensation
		or preset.Atmosphere.Glare ~= replacement.Atmosphere.Glare
		or preset.Bloom.Intensity ~= replacement.Bloom.Intensity
	then
		error("[NTR Warm Snapshot] Verification failed for " .. presetName)
	end
end

if stageVisuals then
	for _, presetName in ipairs({"FivePM", "SevenAM"}) do
		local folder = stageVisuals:FindFirstChild(presetName)
		if folder then
			print(string.format(
				"[NTR Warm Snapshot] Preserved %s visual config: WindowMode=%s StreetLightsEnabled=%s StreetLightBrightness=%s",
				presetName,
				tostring(folder:GetAttribute("WindowMode")),
				tostring(folder:GetAttribute("StreetLightsEnabled")),
				tostring(folder:GetAttribute("StreetLightBrightness"))
			))
		end
	end
end

presetModule:SetAttribute("WarmSnapshotAppliedAt", os.date("%Y-%m-%d %H:%M:%S"))
presetModule:SetAttribute("WarmSnapshotSourceUTC", "2026-07-13T23:28:12Z")

print("[NTR Warm Snapshot] Replaced FivePM and SevenAM with the warm Picture 2 snapshot.")
print("[NTR Warm Snapshot] Preview FivePM and SevenAM in Edit mode, then refresh the Studio mirror.")
