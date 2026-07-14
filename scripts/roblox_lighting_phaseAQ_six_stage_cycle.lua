-- Neo Tokyo Racers - Lighting Phase AQ: Six-Stage Automatic Cycle
-- Run this whole file once in the Roblox Studio Command Bar while NOT playing.
--
-- IMPORTANT: this installer captures the CURRENT edit-mode Lighting/effects/Sky
-- into FivePM. Prepare the desired 5 PM look before running it.
--
-- Safe scope:
--   * Preserves the existing Day and ClearNight preset values.
--   * Captures current edit-mode lighting into FivePM.
--   * Initializes SevenAM from FivePM and EightPM/FourAM from ClearNight only
--     when those presets do not already exist.
--   * Canonically replaces only the isolated lighting service/controllers/tool.
--   * Creates no in-game backups and does not touch driving/UI/racing/VFX/LOD.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

if RunService:IsRunning() then
	error("[NTR Lighting AQ] Stop Play mode before installing/capturing FivePM.")
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local presetModule = shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets")
local skyPresets = shared:WaitForChild("SkyPresets")
local dayVariant = MaterialService:FindFirstChild("Windows Day", true)
local nightVariant = MaterialService:FindFirstChild("Windows Night", true)

if not dayVariant or not dayVariant:IsA("MaterialVariant") or not nightVariant or not nightVariant:IsA("MaterialVariant") then
	error("[NTR Lighting AQ] Missing Windows Day / Windows Night MaterialVariants. Phase AP must be installed first.")
end

-- Complete preflight before the first mutation, so an unexpected hierarchy
-- aborts cleanly instead of leaving a partial install.
local lightingRoot = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("World"):WaitForChild("Lighting")
local lightingService = lightingRoot:FindFirstChild("LightingService_Active")
local worldControllers = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World")
local windowController = worldControllers:FindFirstChild("WindowMaterialController_Active")
local lamppostController = worldControllers:FindFirstChild("NightLamppostLightController_Active")
local preview = StarterPlayer.StarterPlayerScripts:FindFirstChild("TEMP_LightingPreview")
local existingConfigFolder = shared:FindFirstChild("LightingCycleConfig")

if not lightingService or not lightingService:IsA("Script") then error("[NTR Lighting AQ] Missing isolated LightingService_Active.") end
if not windowController or not windowController:IsA("LocalScript") then error("[NTR Lighting AQ] Missing WindowMaterialController_Active.") end
if not lamppostController or not lamppostController:IsA("LocalScript") then error("[NTR Lighting AQ] Missing NightLamppostLightController_Active.") end
if not preview or not preview:IsA("LocalScript") then error("[NTR Lighting AQ] Missing intentional TEMP_LightingPreview LocalScript.") end
if existingConfigFolder and not existingConfigFolder:IsA("Folder") then error("[NTR Lighting AQ] LightingCycleConfig exists but is not a Folder.") end

local function freshRequire(moduleScript)
	local clone = moduleScript:Clone()
	clone.Name = "_NTR_FreshRequire"
	clone.Parent = ServerStorage
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok or type(result) ~= "table" then
		error("[NTR Lighting AQ] Could not load " .. moduleScript:GetFullName() .. ": " .. tostring(result))
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

local function captureProperties(instance, names)
	local result = {}
	for _, name in ipairs(names) do
		local ok, value = pcall(function()
			return instance[name]
		end)
		if ok then
			result[name] = value
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

local function captureCurrentPreset(skyName)
	local result = {
		SkyName = skyName,
		Lighting = captureProperties(Lighting, {
			"ClockTime", "Brightness", "Ambient", "OutdoorAmbient",
			"ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale",
			"EnvironmentSpecularScale", "ExposureCompensation", "FogColor",
			"FogEnd", "FogStart", "ShadowSoftness", "GlobalShadows",
		}),
	}

	local specs = {
		Atmosphere = {"Atmosphere", "Atmosphere", {"Density", "Offset", "Color", "Decay", "Glare", "Haze"}},
		ColorCorrection = {"ColorCorrectionEffect", "ColorCorrection", {"Brightness", "Contrast", "Saturation", "TintColor", "Enabled"}},
		Bloom = {"BloomEffect", "Bloom", {"Intensity", "Size", "Threshold", "Enabled"}},
		SunRays = {"SunRaysEffect", "SunRays", {"Intensity", "Spread", "Enabled"}},
		DepthOfField = {"DepthOfFieldEffect", "DepthOfField", {"FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity", "Enabled"}},
	}

	for sectionName, spec in pairs(specs) do
		local effect = findEffect(spec[1], spec[2])
		if effect then
			result[sectionName] = captureProperties(effect, spec[3])
		end
	end

	return result
end

local function replaceSky(name, sourceSky)
	if not sourceSky then
		return false
	end
	local old = skyPresets:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local clone = sourceSky:Clone()
	clone.Name = name
	clone.Parent = skyPresets
	return true
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
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType ~= "table" then
		error("[NTR Lighting AQ] Cannot serialize value type: " .. valueType)
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
		table.insert(lines, string.format("%s%s = %s,", string.rep("\t", indent + 1), keySource, serialize(value[key], indent + 1)))
	end
	table.insert(lines, string.rep("\t", indent) .. "}")
	return table.concat(lines, "\n")
end

local presets = freshRequire(presetModule)
if not presets.Day or not presets.ClearNight then
	error("[NTR Lighting AQ] Existing Day and ClearNight presets are required; aborted before source changes.")
end

local activeSky = Lighting:FindFirstChild("ActiveSky")
if not activeSky or not activeSky:IsA("Sky") then
	activeSky = Lighting:FindFirstChildOfClass("Sky")
end
if not activeSky then
	error("[NTR Lighting AQ] No active Sky found. FivePM was not captured; add/preview the intended Sky and rerun.")
end

presets.FivePM = captureCurrentPreset("FivePMSky")
replaceSky("FivePMSky", activeSky)

if not presets.SevenAM then
	presets.SevenAM = deepCopy(presets.FivePM)
	presets.SevenAM.SkyName = "SevenAMSky"
	if activeSky then
		replaceSky("SevenAMSky", activeSky)
	end
end

if not presets.TenAM then
	presets.TenAM = deepCopy(presets.Day)
end
if not presets.ThreePM then
	presets.ThreePM = deepCopy(presets.Day)
end

if not presets.EightPM then
	presets.EightPM = deepCopy(presets.ClearNight)
end
if not presets.FourAM then
	presets.FourAM = deepCopy(presets.EightPM)
end

presetModule.Source = "local LightingPresets = " .. serialize(presets) .. "\n\nreturn LightingPresets\n"

local configFolder = existingConfigFolder
if not configFolder then
	configFolder = Instance.new("Folder")
	configFolder.Name = "LightingCycleConfig"
	configFolder.Parent = shared
end

local defaultAttributes = {
	AutoCycleEnabled = true,
	BaseDurationSeconds = 300,
	ManualStage = "Day",
	SynchronizeAcrossServers = true,
}
for name, value in pairs(defaultAttributes) do
	if configFolder:GetAttribute(name) == nil then
		configFolder:SetAttribute(name, value)
	end
end
configFolder:SetAttribute("PhaseAQInstalled", true)
configFolder:SetAttribute("PhaseARInstalled", true)

local scheduleModule = configFolder:FindFirstChild("LightingCycleSchedule")
if scheduleModule and not scheduleModule:IsA("ModuleScript") then
	error("[NTR Lighting AQ] LightingCycleSchedule exists but is not a ModuleScript.")
end
if not scheduleModule then
	scheduleModule = Instance.new("ModuleScript")
	scheduleModule.Name = "LightingCycleSchedule"
	scheduleModule.Parent = configFolder
end
scheduleModule.Source = [==[
-- Edit this ordered table to change stage order, relative duration, or visual flags.
-- BaseDurationSeconds lives on the parent LightingCycleConfig Folder.
return {
	{Preset = "SevenAM",    DisplayName = "7 AM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "TenAM",      DisplayName = "10 AM",  DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "Day",        DisplayName = "Day",    DurationWeight = 2, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "ThreePM",    DisplayName = "3 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "FivePM",     DisplayName = "5 PM",   DurationWeight = 1, StreetLightsOn = false, WindowMode = "Day"},
	{Preset = "EightPM",    DisplayName = "8 PM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "ClearNight", DisplayName = "Night",  DurationWeight = 2, StreetLightsOn = true,  WindowMode = "Night"},
	{Preset = "FourAM",     DisplayName = "4 AM",   DurationWeight = 1, StreetLightsOn = true,  WindowMode = "Night"},
}
]==]

lightingService.Source = [==[
-- NTR Lighting Phase AQ/AR - isolated eight-stage server owner
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local presets = require(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local skyPresets = shared:WaitForChild("SkyPresets")
local config = shared:WaitForChild("LightingCycleConfig")
local schedule = require(config:WaitForChild("LightingCycleSchedule"))

local function getOrCreateEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then existing:Destroy() end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local effects = {
	Atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere"),
	ColorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection"),
	Bloom = getOrCreateEffect("BloomEffect", "Bloom"),
	SunRays = getOrCreateEffect("SunRaysEffect", "SunRays"),
	DepthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField"),
}

local function applyProperties(instance, properties)
	for propertyName, value in pairs(properties or {}) do
		if instance == Lighting and propertyName == "Fogcolor" then propertyName = "FogColor" end
		local ok, err = pcall(function() instance[propertyName] = value end)
		if not ok then warn("[NTR Lighting AQ] Could not apply", instance.Name, propertyName, err) end
	end
end

local function applySky(name)
	if not name then return end
	local template = skyPresets:FindFirstChild(name)
	if not template or not template:IsA("Sky") then
		warn("[NTR Lighting AQ] Missing Sky preset:", name)
		return
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then child:Destroy() end
	end
	local clone = template:Clone()
	clone.Name = "ActiveSky"
	clone.Parent = Lighting
end

local currentPreset
local function applyStage(stage, index, endsAtUnix)
	local preset = presets[stage.Preset]
	if not preset then
		warn("[NTR Lighting AQ] Missing preset:", stage.Preset)
		return
	end
	if currentPreset ~= stage.Preset then
		applyProperties(Lighting, preset.Lighting)
		for section, effect in pairs(effects) do applyProperties(effect, preset[section]) end
		applySky(preset.SkyName)
		currentPreset = stage.Preset
		print("[NTR Lighting AQ] Applied stage:", stage.DisplayName or stage.Preset)
	end
	Lighting:SetAttribute("NTR_LightingPreset", stage.Preset)
	Lighting:SetAttribute("NTR_StreetLightsOn", stage.StreetLightsOn == true)
	Lighting:SetAttribute("NTR_WindowMode", stage.WindowMode or "Day")
	Lighting:SetAttribute("NTR_LightingStageIndex", index)
	Lighting:SetAttribute("NTR_LightingStageEndsAtUnix", endsAtUnix or 0)
end

local localCycleStartedAt = os.clock()
local function stageFromCycle()
	local base = math.max(1, tonumber(config:GetAttribute("BaseDurationSeconds")) or 300)
	local total = 0
	for _, stage in ipairs(schedule) do total += base * math.max(0.01, tonumber(stage.DurationWeight) or 1) end
	local synchronized = config:GetAttribute("SynchronizeAcrossServers") ~= false
	local now = synchronized and os.time() or (os.clock() - localCycleStartedAt)
	local position = now % total
	local cursor = 0
	for index, stage in ipairs(schedule) do
		local duration = base * math.max(0.01, tonumber(stage.DurationWeight) or 1)
		if position < cursor + duration then
			local remaining = cursor + duration - position
			return stage, index, synchronized and (os.time() + math.ceil(remaining)) or 0
		end
		cursor += duration
	end
	return schedule[1], 1, 0
end

local function manualStage()
	local wanted = tostring(config:GetAttribute("ManualStage") or "Day")
	for index, stage in ipairs(schedule) do
		if stage.Preset == wanted then return stage, index end
	end
	warn("[NTR Lighting AQ] Invalid ManualStage; using Day:", wanted)
	return schedule[1], 1
end

while true do
	local stage, index, endsAt
	if config:GetAttribute("AutoCycleEnabled") == false then
		stage, index = manualStage()
		endsAt = 0
	else
		stage, index, endsAt = stageFromCycle()
	end
	applyStage(stage, index, endsAt)
	task.wait(1)
end
]==]
lightingService.Disabled = false

windowController.Source = [==[
-- NTR Lighting Phase AQ - window-only visual owner
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local TAG = "NTR_WindowMaterial"
local function variant(name)
	local found = MaterialService:FindFirstChild(name, true)
	return found and found:IsA("MaterialVariant") and found or nil
end
local function isNight()
	local explicit = Lighting:GetAttribute("NTR_WindowMode")
	if explicit == "Night" then return true elseif explicit == "Day" then return false end
	return Lighting.Brightness <= 1
end
local function apply(instance)
	if not instance:IsA("MeshPart") then return end
	local selected = variant(isNight() and "Windows Night" or "Windows Day")
	if not selected then warn("[NTR Lighting AQ] Missing window MaterialVariant") return end
	instance.Material = selected.BaseMaterial
	instance.MaterialVariant = selected.Name
end
local function refresh()
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do apply(instance) end
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
Lighting:GetAttributeChangedSignal("NTR_WindowMode"):Connect(refresh)
refresh()
]==]
windowController.Disabled = false

lamppostController.Source = [==[
-- NTR Lighting Phase AQ - street-light-only visual owner
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TAG = "NTR_NightLamppostLight"
local function enabled()
	local explicit = Lighting:GetAttribute("NTR_StreetLightsOn")
	if type(explicit) == "boolean" then return explicit end
	return Lighting.Brightness <= 1
end
local function apply(instance)
	if instance:IsA("Light") then instance.Enabled = enabled() end
end
local function refresh()
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do apply(instance) end
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
Lighting:GetAttributeChangedSignal("NTR_StreetLightsOn"):Connect(refresh)
refresh()
]==]
lamppostController.Disabled = false

preview.Source = [==[
-- NTR Lighting Phase AR runtime preview: 1-8 select stages; N=Night, M=Day.
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local presets = require(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local skies = shared:WaitForChild("SkyPresets")
local schedule = require(shared:WaitForChild("LightingCycleConfig"):WaitForChild("LightingCycleSchedule"))
local effects = {}
for section, spec in pairs({Atmosphere={"Atmosphere","Atmosphere"},ColorCorrection={"ColorCorrectionEffect","ColorCorrection"},Bloom={"BloomEffect","Bloom"},SunRays={"SunRaysEffect","SunRays"},DepthOfField={"DepthOfFieldEffect","DepthOfField"}}) do
	local effect = Lighting:FindFirstChild(spec[2]) or Instance.new(spec[1])
	effect.Name = spec[2]; effect.Parent = Lighting; effects[section] = effect
end
local function props(instance, values)
	for name, value in pairs(values or {}) do pcall(function() instance[name == "Fogcolor" and "FogColor" or name] = value end) end
end
local function apply(index)
	local stage = schedule[index]; if not stage then return end
	local preset = presets[stage.Preset]; if not preset then warn("Missing preset", stage.Preset) return end
	props(Lighting, preset.Lighting); for section, effect in pairs(effects) do props(effect, preset[section]) end
	if preset.SkyName then
		local template = skies:FindFirstChild(preset.SkyName)
		if template then for _, child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end; local sky=template:Clone(); sky.Name="ActiveSky"; sky.Parent=Lighting end
	end
	Lighting:SetAttribute("NTR_LightingPreset", stage.Preset)
	Lighting:SetAttribute("NTR_StreetLightsOn", stage.StreetLightsOn == true)
	Lighting:SetAttribute("NTR_WindowMode", stage.WindowMode or "Day")
	print("[NTR Lighting Preview] Applied", stage.DisplayName or stage.Preset)
end
local function findPreset(name)
	for index, stage in ipairs(schedule) do if stage.Preset == name then return index end end
end
local keys = {[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local index = keys[input.KeyCode]
	if input.KeyCode == Enum.KeyCode.M then index = findPreset("Day") end
	if input.KeyCode == Enum.KeyCode.N then index = findPreset("ClearNight") end
	if index then apply(index) end
end)
print("[NTR Lighting Preview] 1 7AM, 2 10AM, 3 Day, 4 3PM, 5 5PM, 6 8PM, 7 Night, 8 4AM; N Night, M Day")
]==]
preview.Disabled = false

Lighting:SetAttribute("NTR_LightingPreset", "FivePM")
Lighting:SetAttribute("NTR_StreetLightsOn", false)
Lighting:SetAttribute("NTR_WindowMode", "Day")

print("[NTR Lighting AQ] Installed eight-stage cycle and captured current edit-mode settings into FivePM.")
print("[NTR Lighting AQ] SevenAM initialized from FivePM; EightPM/FourAM initialized from ClearNight when missing.")
print("[NTR Lighting AQ] TenAM/ThreePM initialized from Day when missing.")
print("[NTR Lighting AQ] Default base duration: " .. tostring(configFolder:GetAttribute("BaseDurationSeconds")) .. " seconds.")
print("[NTR Lighting AQ] Next: run the audit, then start Play and verify stages with keys 1-8.")
