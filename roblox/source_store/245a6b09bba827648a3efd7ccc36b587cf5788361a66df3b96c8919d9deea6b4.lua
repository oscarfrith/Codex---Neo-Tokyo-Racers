-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- NTR Lighting Phase AS - config-backed street-light-only visual owner
local CollectionService=game:GetService("CollectionService")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TAG="NightLamppostLight"
local visuals=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("World"):WaitForChild("Lighting"):WaitForChild("StageVisuals")
local function settings()
    if Lighting:GetAttribute("LightingCycleMode")=="Continuous" then
        return Lighting:GetAttribute("StreetLightsOn")==true, math.max(0,tonumber(Lighting:GetAttribute("StreetLightBrightness")) or 2)
    end
	local name=Lighting:GetAttribute("LightingPreset"); local folder=type(name)=="string" and visuals:FindFirstChild(name) or nil
	local enabled=folder and folder:GetAttribute("StreetLightsEnabled"); if type(enabled)~="boolean" then enabled=Lighting:GetAttribute("StreetLightsOn")==true end
	local brightness=folder and tonumber(folder:GetAttribute("StreetLightBrightness")); if not brightness then brightness=1 end
	return enabled,math.max(0,brightness)
end
local function apply(instance) if instance:IsA("Light") then local enabled,brightness=settings(); instance.Brightness=brightness; instance.Enabled=enabled end end
local function refresh() for _,instance in ipairs(CollectionService:GetTagged(TAG)) do apply(instance) end end
local function watch(folder) if folder:IsA("Folder") then folder.AttributeChanged:Connect(refresh) end end
for _,folder in ipairs(visuals:GetChildren()) do watch(folder) end
visuals.ChildAdded:Connect(function(folder) watch(folder); refresh() end)
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(refresh)
Lighting:GetAttributeChangedSignal("StreetLightsOn"):Connect(refresh)
Lighting:GetAttributeChangedSignal("StreetLightBrightness"):Connect(refresh)
Lighting:GetAttributeChangedSignal("LightingCycleMode"):Connect(refresh)
refresh()

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
