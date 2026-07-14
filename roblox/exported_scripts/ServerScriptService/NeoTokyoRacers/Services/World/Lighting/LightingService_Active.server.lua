-- NTR Lighting Phase AQ - isolated six-stage server owner
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
