-- Neo Tokyo Racers - Lighting Phase AR: Add 10 AM And 3 PM
-- Run this whole file once in the Roblox Studio Command Bar while NOT playing.
--
-- Adds independent TenAM and ThreePM preset tables copied from Day, inserts
-- both into the automatic cycle, and expands runtime preview keys to 1-8.
-- It preserves all existing captured preset values and does not recapture the
-- current Edit-mode view. No fragile source-text replacement is used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

if RunService:IsRunning() then error("[NTR Lighting AR] Stop Play mode before installing.") end

local shared = ReplicatedStorage:WaitForChild("Shared")
local presetModule = shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets")
local config = shared:WaitForChild("LightingCycleConfig")
local scheduleModule = config:WaitForChild("LightingCycleSchedule")
local preview = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("TEMP_LightingPreview")
if not presetModule:IsA("ModuleScript") or not scheduleModule:IsA("ModuleScript") or not preview:IsA("LocalScript") then
	error("[NTR Lighting AR] Lighting Phase AQ hierarchy is incomplete; aborted without changes.")
end

local clone = presetModule:Clone(); clone.Name = "_NTR_LightingARFresh"; clone.Parent = ServerStorage
local ok, presets = pcall(require, clone); clone:Destroy()
if not ok or type(presets) ~= "table" or type(presets.Day) ~= "table" then
	error("[NTR Lighting AR] Could not load the confirmed Day preset: " .. tostring(presets))
end

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in pairs(value) do result[deepCopy(key)] = deepCopy(child) end; return result
end

local function serialize(value, indent)
	indent = indent or 0; local kind = typeof(value)
	if kind == "nil" then return "nil"
	elseif kind == "boolean" or kind == "number" then return tostring(value)
	elseif kind == "string" then return string.format("%q", value)
	elseif kind == "Color3" then return string.format("Color3.new(%.17g, %.17g, %.17g)", value.R, value.G, value.B)
	elseif kind == "EnumItem" then return tostring(value)
	elseif kind ~= "table" then error("[NTR Lighting AR] Cannot serialize " .. kind) end
	local keys = {}; for key in pairs(value) do table.insert(keys, key) end
	table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
	local lines = {"{"}
	for _, key in ipairs(keys) do
		local keySource = type(key)=="string" and string.match(key,"^[%a_][%w_]*$") and key or ("["..serialize(key,indent+1).."]")
		table.insert(lines, string.format("%s%s = %s,", string.rep("\t",indent+1), keySource, serialize(value[key],indent+1)))
	end
	table.insert(lines,string.rep("\t",indent).."}"); return table.concat(lines,"\n")
end

if not presets.TenAM then presets.TenAM = deepCopy(presets.Day) end
if not presets.ThreePM then presets.ThreePM = deepCopy(presets.Day) end
presetModule.Source = "local LightingPresets = " .. serialize(presets) .. "\n\nreturn LightingPresets\n"

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
	local effect = Lighting:FindFirstChild(spec[2]) or Instance.new(spec[1]); effect.Name=spec[2]; effect.Parent=Lighting; effects[section]=effect
end
local function props(instance, values)
	for name, value in pairs(values or {}) do pcall(function() instance[name=="Fogcolor" and "FogColor" or name]=value end) end
end
local function apply(index)
	local stage=schedule[index]; if not stage then return end
	local preset=presets[stage.Preset]; if not preset then warn("Missing preset",stage.Preset) return end
	props(Lighting,preset.Lighting); for section,effect in pairs(effects) do props(effect,preset[section]) end
	if preset.SkyName then
		local template=skies:FindFirstChild(preset.SkyName)
		if template then for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end; local sky=template:Clone(); sky.Name="ActiveSky"; sky.Parent=Lighting end
	end
	Lighting:SetAttribute("NTR_LightingPreset",stage.Preset)
	Lighting:SetAttribute("NTR_StreetLightsOn",stage.StreetLightsOn==true)
	Lighting:SetAttribute("NTR_WindowMode",stage.WindowMode or "Day")
	print("[NTR Lighting Preview] Applied",stage.DisplayName or stage.Preset)
end
local function findPreset(name) for index,stage in ipairs(schedule) do if stage.Preset==name then return index end end end
local keys={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
UserInputService.InputBegan:Connect(function(input,processed)
	if processed then return end
	local index=keys[input.KeyCode]
	if input.KeyCode==Enum.KeyCode.M then index=findPreset("Day") end
	if input.KeyCode==Enum.KeyCode.N then index=findPreset("ClearNight") end
	if index then apply(index) end
end)
print("[NTR Lighting Preview] 1 7AM, 2 10AM, 3 Day, 4 3PM, 5 5PM, 6 8PM, 7 Night, 8 4AM; N Night, M Day")
]==]
preview.Disabled = false
config:SetAttribute("PhaseARInstalled", true)

print("[NTR Lighting AR] Added TenAM and ThreePM as independent Day copies.")
print("[NTR Lighting AR] Cycle order: 7AM, 10AM, Day, 3PM, 5PM, 8PM, Night, 4AM.")
print("[NTR Lighting AR] Run the updated Phase AQ audit; expect fail=0.")
