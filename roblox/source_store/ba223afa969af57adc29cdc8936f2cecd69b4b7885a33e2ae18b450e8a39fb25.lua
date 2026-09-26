-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Development").ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
LightingPreviewEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
-- NTR Lighting Phase AR runtime preview: 1-8 select stages; N=Night, M=Day.
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = game:GetService("ReplicatedStorage")
local presets = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LightingPresets"))
local skies = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("World"):WaitForChild("Skies")
local schedule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LightingSchedule"))
local renderer=require(ReplicatedStorage.Modules.Game.World.LightingClient)
if renderer.isContinuous() then
    local runtime=game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("World")
    local cycleConfig=ReplicatedStorage.Config.World.Lighting
    local keys={[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.N]=7,[Enum.KeyCode.M]=3}
    local connection=UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.KeyCode==Enum.KeyCode.R then runtime:SetAttribute("LightingPreviewCycleSeconds",nil); return end
        local index=keys[input.KeyCode]; if not index then return end
        local position=0
        for i=1,index-1 do position+=(cycleConfig:GetAttribute("BaseDurationSeconds") or 90)*schedule[i].DurationWeight end
        runtime:SetAttribute("LightingPreviewCycleSeconds",position)
    end)
    script.Destroying:Once(function() connection:Disconnect(); runtime:SetAttribute("LightingPreviewCycleSeconds",nil) end)
    return
end

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
	Lighting:SetAttribute("LightingPreset",stage.Preset)
	Lighting:SetAttribute("StreetLightsOn",stage.StreetLightsOn==true)
	Lighting:SetAttribute("WindowMode",stage.WindowMode or "Day")
	print("[Lighting Preview] Applied",stage.DisplayName or stage.Preset)
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
print("[Lighting Preview] 1 7AM, 2 10AM, 3 Day, 4 3PM, 5 5PM, 6 8PM, 7 Night, 8 4AM; N Night, M Day")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
