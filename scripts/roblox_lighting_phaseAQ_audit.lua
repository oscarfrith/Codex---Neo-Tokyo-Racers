-- Neo Tokyo Racers - Lighting Phase AQ Read-Only Audit
-- Run in Edit mode. Makes no persistent changes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
if RunService:IsRunning() then error("[NTR Lighting AQ Audit] Stop Play mode and run this from Edit mode.") end
local pass, warnCount, fail = 0, 0, 0
local function check(ok, label, warning)
	if ok then pass+=1; print("[PASS]", label)
	elseif warning then warnCount+=1; warn("[WARN] " .. label)
	else fail+=1; warn("[FAIL] " .. label) end
end
local function freshRequire(moduleScript)
	local clone = moduleScript:Clone(); clone.Name = "_NTR_AuditFresh"; clone.Parent = ServerStorage
	local ok, result = pcall(require, clone); clone:Destroy(); return ok, result
end
local function sourceHas(scriptObject, marker)
	local ok, source = pcall(function() return scriptObject and scriptObject.Source end)
	return ok and type(source)=="string" and string.find(source,marker,1,true) ~= nil
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local config = shared and shared:FindFirstChild("LightingCycleConfig")
local presetModule = shared and shared:FindFirstChild("LightingPresets") and shared.LightingPresets:FindFirstChild("LightingPresets")
local scheduleModule = config and config:FindFirstChild("LightingCycleSchedule")
check(config and config:IsA("Folder"), "LightingCycleConfig folder exists")
check(config and config:GetAttribute("PhaseAQInstalled") == true, "Phase AQ marker exists")
check(config and config:GetAttribute("PhaseARInstalled") == true, "Phase AR marker exists")
check(config and config:GetAttribute("PhaseASInstalled") == true, "Phase AS marker exists")
check(type(config and config:GetAttribute("BaseDurationSeconds")) == "number", "BaseDurationSeconds is editable")
check(scheduleModule and scheduleModule:IsA("ModuleScript"), "LightingCycleSchedule exists")
check(presetModule and presetModule:IsA("ModuleScript"), "LightingPresets exists")
local stageVisuals = config and config:FindFirstChild("StageVisuals")
check(stageVisuals and stageVisuals:IsA("Folder"), "StageVisuals config folder exists")

local expected = {"SevenAM","TenAM","Day","ThreePM","FivePM","EightPM","ClearNight","FourAM"}
if presetModule then
	local ok, presets = freshRequire(presetModule)
	check(ok and type(presets)=="table", "LightingPresets loads")
	if ok then for _, name in ipairs(expected) do check(type(presets[name])=="table", "Preset exists: " .. name) end end
end
if stageVisuals then
	for _, name in ipairs(expected) do
		local folder=stageVisuals:FindFirstChild(name)
		check(folder and folder:IsA("Folder"),"Visual config exists: "..name)
		if folder then
			check(folder:GetAttribute("WindowMode")=="Day" or folder:GetAttribute("WindowMode")=="Night","WindowMode valid: "..name)
			check(type(folder:GetAttribute("StreetLightsEnabled"))=="boolean","StreetLightsEnabled valid: "..name)
			check(type(folder:GetAttribute("StreetLightBrightness"))=="number","StreetLightBrightness valid: "..name)
		end
	end
end
if scheduleModule then
	local ok, schedule = freshRequire(scheduleModule)
	check(ok and type(schedule)=="table" and #schedule==8, "Schedule contains eight stages")
	if ok then
		local total=0; for _, stage in ipairs(schedule) do total += tonumber(stage.DurationWeight) or 0 end
		check(total==10, "Duration weights total 10 (Day/Night doubled)")
		local dark = {}; for _, stage in ipairs(schedule) do dark[stage.Preset] = stage.StreetLightsOn == true end
		check(dark.EightPM and dark.ClearNight and dark.FourAM, "8 PM, Night, and 4 AM street lights enabled")
	end
end

local service = ServerScriptService:FindFirstChild("NeoTokyoRacers")
service = service and service:FindFirstChild("Services") and service.Services:FindFirstChild("World") and service.Services.World:FindFirstChild("Lighting") and service.Services.World.Lighting:FindFirstChild("LightingService_Active")
check(service and service:IsA("Script") and not service.Disabled, "LightingService_Active enabled", game:GetService("RunService"):IsClient())
local world = StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
world = world and world:FindFirstChild("Controllers") and world.Controllers:FindFirstChild("World")
local windows = world and world:FindFirstChild("WindowMaterialController_Active")
local lamps = world and world:FindFirstChild("NightLamppostLightController_Active")
check(sourceHas(windows,"config-backed window-only visual owner"), "Window controller uses stage visual config")
check(sourceHas(lamps,"config-backed street-light-only visual owner"), "Street-light controller uses stage visual config")
check(type(Lighting:GetAttribute("NTR_LightingPreset"))=="string" or not game:GetService("RunService"):IsRunning(), "Runtime preset signal available", true)
print(string.format("[NTR Lighting AQ Audit] pass=%d warn=%d fail=%d", pass, warnCount, fail))
