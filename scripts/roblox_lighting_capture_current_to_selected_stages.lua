-- Neo Tokyo Racers - Capture Current Edit Lighting To Selected Stages
-- Run in the Studio Command Bar while NOT playing.
-- Edit only this list for normal use. Multiple names copy the same current look
-- into independent presets, for example {"FivePM", "SevenAM"}.

local TARGET_PRESETS = {"FivePM"}

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if RunService:IsRunning() then error("[NTR Lighting Capture] Stop Play mode first.") end

local allowed = {Day=true, SevenAM=true, TenAM=true, ThreePM=true, FivePM=true, EightPM=true, ClearNight=true, FourAM=true}
if #TARGET_PRESETS == 0 then error("[NTR Lighting Capture] TARGET_PRESETS is empty.") end
for _, name in ipairs(TARGET_PRESETS) do
	if not allowed[name] then error("[NTR Lighting Capture] Unsupported preset: " .. tostring(name)) end
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local presetModule = shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets")
local skyPresets = shared:WaitForChild("SkyPresets")
local clone = presetModule:Clone(); clone.Name = "_NTR_CaptureFresh"; clone.Parent = ServerStorage
local ok, presets = pcall(require, clone); clone:Destroy()
if not ok or type(presets) ~= "table" then error("[NTR Lighting Capture] Could not load presets: " .. tostring(presets)) end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in pairs(value) do result[copy(key)] = copy(child) end; return result
end
local function capture(instance, names)
	local result = {}
	for _, name in ipairs(names) do local success, value = pcall(function() return instance[name] end); if success then result[name] = value end end
	return result
end
local function effect(className, preferred)
	local found = Lighting:FindFirstChild(preferred)
	return found and found.ClassName == className and found or Lighting:FindFirstChildOfClass(className)
end

local captured = {
	Lighting = capture(Lighting, {"ClockTime","Brightness","Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom","EnvironmentDiffuseScale","EnvironmentSpecularScale","ExposureCompensation","FogColor","FogEnd","FogStart","ShadowSoftness","GlobalShadows"}),
}
local specs = {
	Atmosphere={"Atmosphere","Atmosphere",{"Density","Offset","Color","Decay","Glare","Haze"}},
	ColorCorrection={"ColorCorrectionEffect","ColorCorrection",{"Brightness","Contrast","Saturation","TintColor","Enabled"}},
	Bloom={"BloomEffect","Bloom",{"Intensity","Size","Threshold","Enabled"}},
	SunRays={"SunRaysEffect","SunRays",{"Intensity","Spread","Enabled"}},
	DepthOfField={"DepthOfFieldEffect","DepthOfField",{"FarIntensity","FocusDistance","InFocusRadius","NearIntensity","Enabled"}},
}
for section, spec in pairs(specs) do local found = effect(spec[1], spec[2]); if found then captured[section] = capture(found, spec[3]) end end

local activeSky = Lighting:FindFirstChild("ActiveSky")
if not activeSky or not activeSky:IsA("Sky") then activeSky = Lighting:FindFirstChildOfClass("Sky") end

local function serialize(value, indent)
	indent = indent or 0; local kind = typeof(value)
	if kind == "nil" then return "nil" elseif kind == "boolean" or kind == "number" then return tostring(value)
	elseif kind == "string" then return string.format("%q", value)
	elseif kind == "Color3" then return string.format("Color3.new(%.17g, %.17g, %.17g)", value.R, value.G, value.B)
	elseif kind == "EnumItem" then return tostring(value) elseif kind ~= "table" then error("Cannot serialize " .. kind) end
	local keys = {}; for key in pairs(value) do table.insert(keys, key) end
	table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
	local lines = {"{"}
	for _, key in ipairs(keys) do
		local keySource = type(key)=="string" and string.match(key,"^[%a_][%w_]*$") and key or ("["..serialize(key,indent+1).."]")
		table.insert(lines, string.format("%s%s = %s,", string.rep("\t",indent+1), keySource, serialize(value[key],indent+1)))
	end
	table.insert(lines,string.rep("\t",indent).."}"); return table.concat(lines,"\n")
end

for _, name in ipairs(TARGET_PRESETS) do
	local skyName = name .. "Sky"
	local value = copy(captured); value.SkyName = skyName; presets[name] = value
	if activeSky then
		local old = skyPresets:FindFirstChild(skyName); if old then old:Destroy() end
		local sky = activeSky:Clone(); sky.Name = skyName; sky.Parent = skyPresets
	else
		warn("[NTR Lighting Capture] No active Sky; existing sky asset preserved for", name)
	end
end

presetModule.Source = "local LightingPresets = " .. serialize(presets) .. "\n\nreturn LightingPresets\n"
Lighting:SetAttribute("NTR_LightingPreset", TARGET_PRESETS[1])
print("[NTR Lighting Capture] Saved current edit-mode look to: " .. table.concat(TARGET_PRESETS, ", "))
print("[NTR Lighting Capture] StageVisuals config was intentionally preserved.")
print("[NTR Lighting Capture] Run the selected-stage preview, then start a fresh Play session.")
