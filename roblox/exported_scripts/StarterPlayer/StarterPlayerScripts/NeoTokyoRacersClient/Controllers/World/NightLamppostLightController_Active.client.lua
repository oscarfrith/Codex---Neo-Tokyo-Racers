-- NTR Lighting Phase AS - config-backed street-light-only visual owner
local CollectionService=game:GetService("CollectionService")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TAG="NTR_NightLamppostLight"
local visuals=ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightingCycleConfig"):WaitForChild("StageVisuals")
local function settings()
	local name=Lighting:GetAttribute("NTR_LightingPreset"); local folder=type(name)=="string" and visuals:FindFirstChild(name) or nil
	local enabled=folder and folder:GetAttribute("StreetLightsEnabled"); if type(enabled)~="boolean" then enabled=Lighting:GetAttribute("NTR_StreetLightsOn")==true end
	local brightness=folder and tonumber(folder:GetAttribute("StreetLightBrightness")); if not brightness then brightness=1 end
	return enabled,math.max(0,brightness)
end
local function apply(instance) if instance:IsA("Light") then local enabled,brightness=settings(); instance.Brightness=brightness; instance.Enabled=enabled end end
local function refresh() for _,instance in ipairs(CollectionService:GetTagged(TAG)) do apply(instance) end end
local function watch(folder) if folder:IsA("Folder") then folder.AttributeChanged:Connect(refresh) end end
for _,folder in ipairs(visuals:GetChildren()) do watch(folder) end
visuals.ChildAdded:Connect(function(folder) watch(folder); refresh() end)
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
Lighting:GetAttributeChangedSignal("NTR_LightingPreset"):Connect(refresh)
refresh()
