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
