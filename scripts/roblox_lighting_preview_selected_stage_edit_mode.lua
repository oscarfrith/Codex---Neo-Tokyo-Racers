-- Neo Tokyo Racers - Preview One Lighting Stage In Edit Mode
-- Change this one value, then run the whole file in the Studio Command Bar.

local PRESET_NAME = "FivePM" -- SevenAM, TenAM, Day, ThreePM, FivePM, EightPM, ClearNight, FourAM

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
if RunService:IsRunning() then error("[NTR Lighting Preview] Stop Play mode first.") end

local shared = ReplicatedStorage:WaitForChild("Shared")
local skies = shared:WaitForChild("SkyPresets")
local function freshRequire(moduleScript)
	local clone = moduleScript:Clone(); clone.Name = "_NTR_PreviewFresh"; clone.Parent = ServerStorage
	local ok, result = pcall(require, clone); clone:Destroy()
	if not ok or type(result) ~= "table" then error("[NTR Lighting Preview] Could not load " .. moduleScript.Name .. ": " .. tostring(result)) end
	return result
end
local presets = freshRequire(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local schedule = freshRequire(shared:WaitForChild("LightingCycleConfig"):WaitForChild("LightingCycleSchedule"))
local cycleConfig = shared:FindFirstChild("LightingCycleConfig")
local stageVisuals = cycleConfig and cycleConfig:FindFirstChild("StageVisuals")
if not stageVisuals or not stageVisuals:IsA("Folder") then
	error("[NTR Lighting Preview] Missing LightingCycleConfig.StageVisuals. Run scripts/roblox_lighting_phaseAS_stage_visual_config.lua in Edit mode first.")
end
local preset = presets[PRESET_NAME]; if not preset then error("[NTR Lighting Preview] Missing preset: " .. PRESET_NAME) end
local stage
for _, candidate in ipairs(schedule) do if candidate.Preset == PRESET_NAME then stage = candidate break end end
if not stage then error("[NTR Lighting Preview] Preset is not in LightingCycleSchedule: " .. PRESET_NAME) end
local visual = stageVisuals:FindFirstChild(PRESET_NAME)
if not visual or not visual:IsA("Folder") then error("[NTR Lighting Preview] Missing StageVisuals config for preset: "..PRESET_NAME) end
local windowMode = visual:GetAttribute("WindowMode") or stage.WindowMode or "Day"
local streetLightsEnabled = visual:GetAttribute("StreetLightsEnabled")
if type(streetLightsEnabled)~="boolean" then streetLightsEnabled=stage.StreetLightsOn==true end
local streetLightBrightness = math.max(0,tonumber(visual:GetAttribute("StreetLightBrightness")) or 1)

local function getEffect(className, name)
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then return found end
	if found then found:Destroy() end
	found = Instance.new(className); found.Name = name; found.Parent = Lighting; return found
end
local function apply(instance, values)
	for name, value in pairs(values or {}) do
		if instance == Lighting and name == "Fogcolor" then name = "FogColor" end
		local ok, err = pcall(function() instance[name] = value end)
		if not ok then warn("[NTR Lighting Preview] Could not apply", instance.Name, name, err) end
	end
end

apply(Lighting, preset.Lighting)
for section, spec in pairs({Atmosphere={"Atmosphere","Atmosphere"},ColorCorrection={"ColorCorrectionEffect","ColorCorrection"},Bloom={"BloomEffect","Bloom"},SunRays={"SunRaysEffect","SunRays"},DepthOfField={"DepthOfFieldEffect","DepthOfField"}}) do
	apply(getEffect(spec[1], spec[2]), preset[section])
end
if preset.SkyName then
	local template = skies:FindFirstChild(preset.SkyName); if not template or not template:IsA("Sky") then error("[NTR Lighting Preview] Missing Sky: " .. preset.SkyName) end
	for _, child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end
	local sky = template:Clone(); sky.Name = "ActiveSky"; sky.Parent = Lighting
end

local windowVariant = MaterialService:FindFirstChild(windowMode == "Night" and "Windows Night" or "Windows Day", true)
if not windowVariant or not windowVariant:IsA("MaterialVariant") then error("[NTR Lighting Preview] Missing window MaterialVariant") end
local windows, lights = 0, 0
for _, instance in ipairs(CollectionService:GetTagged("NTR_WindowMaterial")) do if instance:IsA("MeshPart") then instance.Material=windowVariant.BaseMaterial; instance.MaterialVariant=windowVariant.Name; windows+=1 end end
for _, instance in ipairs(CollectionService:GetTagged("NTR_NightLamppostLight")) do if instance:IsA("Light") then instance.Brightness=streetLightBrightness; instance.Enabled=streetLightsEnabled; lights+=1 end end
Lighting:SetAttribute("NTR_LightingPreset", PRESET_NAME)
Lighting:SetAttribute("NTR_StreetLightsOn",streetLightsEnabled)
Lighting:SetAttribute("NTR_StreetLightBrightness",streetLightBrightness)
Lighting:SetAttribute("NTR_WindowMode",windowMode)
print(string.format("[NTR Lighting Preview] Applied %s; windows=%s/%d street lights=%s/%d brightness=%.3f",stage.DisplayName or PRESET_NAME,windowMode,windows,tostring(streetLightsEnabled),lights,streetLightBrightness))
