-- Neo Tokyo Racers - Lighting Phase AS: Editable Stage Visual Config
-- Run once in Roblox Studio Edit mode.
--
-- Creates easy per-stage folders for window mode, managed street-light enabled
-- state, and managed street-light brightness. Canonically replaces only the
-- two isolated lighting visual controllers. No fragile text replacement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
if RunService:IsRunning() then error("[NTR Lighting AS] Stop Play mode before installing.") end

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = shared:WaitForChild("LightingCycleConfig")
local scheduleModule = config:WaitForChild("LightingCycleSchedule")
local world = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World")
local windowController = world:WaitForChild("WindowMaterialController_Active")
local lightController = world:WaitForChild("NightLamppostLightController_Active")
if not scheduleModule:IsA("ModuleScript") or not windowController:IsA("LocalScript") or not lightController:IsA("LocalScript") then
	error("[NTR Lighting AS] Phase AQ/AR hierarchy is incomplete; aborted without changes.")
end

local clone = scheduleModule:Clone(); clone.Name="_NTR_VisualConfigFresh"; clone.Parent=ServerStorage
local ok, schedule = pcall(require, clone); clone:Destroy()
if not ok or type(schedule)~="table" or #schedule==0 then error("[NTR Lighting AS] Could not load schedule: "..tostring(schedule)) end

if config:GetAttribute("DefaultStreetLightBrightness")==nil then config:SetAttribute("DefaultStreetLightBrightness",1) end
local defaultBrightness=math.max(0,tonumber(config:GetAttribute("DefaultStreetLightBrightness")) or 1)

local visuals = config:FindFirstChild("StageVisuals")
if visuals and not visuals:IsA("Folder") then error("[NTR Lighting AS] StageVisuals exists but is not a Folder.") end
if not visuals then visuals=Instance.new("Folder"); visuals.Name="StageVisuals"; visuals.Parent=config end
visuals:SetAttribute("Purpose", "Edit each child stage: WindowMode, StreetLightsEnabled, StreetLightBrightness")

for _, stage in ipairs(schedule) do
	local folder = visuals:FindFirstChild(stage.Preset)
	if folder and not folder:IsA("Folder") then error("[NTR Lighting AS] Stage visual entry is not a Folder: "..stage.Preset) end
	if not folder then folder=Instance.new("Folder"); folder.Name=stage.Preset; folder.Parent=visuals end
	if folder:GetAttribute("WindowMode")==nil then folder:SetAttribute("WindowMode", stage.WindowMode or "Day") end
	if folder:GetAttribute("StreetLightsEnabled")==nil then folder:SetAttribute("StreetLightsEnabled", stage.StreetLightsOn==true) end
	if folder:GetAttribute("StreetLightBrightness")==nil then folder:SetAttribute("StreetLightBrightness",defaultBrightness) end
end

windowController.Source = [==[
-- NTR Lighting Phase AS - config-backed window-only visual owner
local CollectionService=game:GetService("CollectionService")
local Lighting=game:GetService("Lighting")
local MaterialService=game:GetService("MaterialService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TAG="NTR_WindowMaterial"
local visuals=ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightingCycleConfig"):WaitForChild("StageVisuals")
local function currentFolder() local name=Lighting:GetAttribute("NTR_LightingPreset"); return type(name)=="string" and visuals:FindFirstChild(name) or nil end
local function mode()
	local folder=currentFolder(); local value=folder and folder:GetAttribute("WindowMode")
	if value=="Night" or value=="Day" then return value end
	local fallback=Lighting:GetAttribute("NTR_WindowMode"); return fallback=="Night" and "Night" or "Day"
end
local function variant(name) local found=MaterialService:FindFirstChild(name,true); return found and found:IsA("MaterialVariant") and found or nil end
local function apply(instance)
	if not instance:IsA("MeshPart") then return end
	local selected=variant(mode()=="Night" and "Windows Night" or "Windows Day")
	if not selected then warn("[NTR Lighting AS] Missing window MaterialVariant") return end
	instance.Material=selected.BaseMaterial; instance.MaterialVariant=selected.Name
end
local function refresh() for _,instance in ipairs(CollectionService:GetTagged(TAG)) do apply(instance) end end
local function watch(folder) if folder:IsA("Folder") then folder.AttributeChanged:Connect(refresh) end end
for _,folder in ipairs(visuals:GetChildren()) do watch(folder) end
visuals.ChildAdded:Connect(function(folder) watch(folder); refresh() end)
CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
Lighting:GetAttributeChangedSignal("NTR_LightingPreset"):Connect(refresh)
refresh()
]==]
windowController.Disabled=false

lightController.Source = [==[
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
]==]
lightController.Disabled=false
config:SetAttribute("PhaseASInstalled",true)
print("[NTR Lighting AS] Created StageVisuals config for "..tostring(#schedule).." stages.")
print("[NTR Lighting AS] Each stage has WindowMode, StreetLightsEnabled, and StreetLightBrightness attributes.")
print("[NTR Lighting AS] Visual state is config-owned; environmental capture does not overwrite these attributes.")
print("[NTR Lighting AS] Run the updated audit; expect fail=0.")
