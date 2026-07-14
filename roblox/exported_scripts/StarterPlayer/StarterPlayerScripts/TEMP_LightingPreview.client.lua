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
