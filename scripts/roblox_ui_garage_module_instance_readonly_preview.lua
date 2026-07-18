-- Neo Tokyo Racers - Read-only physical module-instance preview
-- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.
-- This phase patches two isolated client modules with guarded exact anchors.

local MODE = "INSTALL" -- INSTALL or AUDIT
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local previewFolder = need(controllers, "Preview", "Folder")
local uiFolder = need(controllers, "UI", "Folder")
local previewVehicle = need(previewFolder, "PreviewVehicleController", "ModuleScript")
local application = need(uiFolder, "ModuleShopUIController", "ModuleScript")
local existingAdapter = previewFolder:FindFirstChild("GarageModuleInstancePreviewAdapter")
if existingAdapter then assert(existingAdapter:IsA("ModuleScript"), "GarageModuleInstancePreviewAdapter exists with the wrong class") end

assert(string.find(previewVehicle.Source, "NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3", 1, true), "PreviewVehicleController canonical baseline marker missing")
assert(string.find(application.Source, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3", 1, true), "ModuleShopUIController canonical baseline marker missing")

local adapterSource = [==[
-- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1
-- Resolves presentation data only. No remote calls, profile writes or ownership changes belong here.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Adapter={}
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance")
local Calculator=require(performance:WaitForChild("VehiclePerformanceCalculator"))
local Definitions=require(performance:WaitForChild("VehiclePerformanceDefinitions"))
local V2Upgrades=require(performance:WaitForChild("VehiclePerformanceV2UpgradeRuntime"))
local LegacyDefinitions=require(performance:WaitForChild("VehicleUpgradeDefinitions"))

local function moduleColors(profile,slotId,override)
	profile=profile or {}; local cockpit=profile.CockpitColors or {}; local saved=typeof(override)=="table" and override or (profile.ModuleColors and profile.ModuleColors[slotId]) or {}
	return {Primary=saved.Primary or cockpit.Primary or Color3.fromRGB(18,202,224),Secondary=saved.Secondary or cockpit.Secondary or Color3.fromRGB(252,250,255),Detail=saved.Detail or cockpit.Detail or Color3.fromRGB(38,47,55),Neon=saved.Neon or Color3.fromRGB(255,255,255),ThrustColor=profile.ThrustColor or saved.ThrustColor or Color3.fromRGB(255,255,255)}
end

local function ownedInstance(profile,instanceId)
	if typeof(profile)~="table" or instanceId==nil then return nil end
	local owned=profile.OwnedModuleInstances; if typeof(owned)~="table" then return nil end
	local direct=owned[instanceId] or owned[tostring(instanceId)]; if typeof(direct)=="table" then return direct end
	for id,item in pairs(owned) do if tostring(id)==tostring(instanceId) and typeof(item)=="table" then return item end end
	return nil
end

local function currentVehicle(profile)
	local id=tostring(profile and profile.CurrentVehicleId or "")
	return id~="" and profile.Vehicles and profile.Vehicles[id] or nil
end

function Adapter.FindTemplate(categoriesRoot,moduleId)
	if not categoriesRoot or moduleId==nil then return nil end
	for _,item in ipairs(categoriesRoot:GetDescendants()) do
		if item:IsA("Model") and tostring(item:GetAttribute("ModuleId") or item.Name)==tostring(moduleId) then return item end
	end
	return nil
end

function Adapter.Installed(state,slotId)
	local profile=state and state.Profile; if typeof(profile)~="table" then return nil,nil,nil end
	local vehicle=currentVehicle(profile); local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[slotId]
	local instance=ownedInstance(profile,instanceId)
	local moduleId=instance and instance.TemplateId or (profile.InstalledModules and profile.InstalledModules[slotId])
	return moduleId,instance,instanceId and tostring(instanceId) or nil
end

function Adapter.Selected(state,slotId,moduleId)
	if not state or tostring(state.SelectedSlot or "")~=tostring(slotId or "") then return nil,nil end
	local instanceId=state.SelectedModuleInstanceId; if instanceId==nil then return nil,nil end
	local instance=ownedInstance(state.Profile,instanceId)
	if typeof(instance)~="table" or tostring(instance.TemplateId or "")~=tostring(moduleId or "") then return nil,nil end
	return instance,tostring(instanceId)
end

function Adapter.Resolve(state,slotId,moduleId)
	local instance,instanceId=Adapter.Selected(state,slotId,moduleId)
	if not instance then
		local installedId,installed,installedInstanceId=Adapter.Installed(state,slotId)
		if tostring(installedId or "")==tostring(moduleId or "") then instance,instanceId=installed,installedInstanceId end
	end
	local profile=state and state.Profile or {}
	local colors
	if instance and typeof(instance.Colors)=="table" then
		colors=moduleColors(profile,slotId,instance.Colors)
	else
		colors=moduleColors(profile,slotId)
	end
	local neon=instance and instance.NeonOwned==true or ((profile.NeonOwned or {})[slotId]==true)
	return {Instance=instance,InstanceId=instanceId,Colors=colors,NeonOwned=neon}
end

local function moduleType(template)
	local explicit=tostring(template and template:GetAttribute("ModuleType") or "")
	if LegacyDefinitions.ByModuleType[explicit] then return explicit end
	local folder=tostring(template and (template:GetAttribute("ModuleFolder") or (template.Parent and template.Parent.Name)) or "")
	local map={Engines="Engine",Engines_B="Engine",Engine="Engine",Stabilizers="Stabilisers",Stabilisers="Stabilisers",Boost="Boost",FrontBumpers="FrontBumper",FrontBumper="FrontBumper",RearBumpers="RearBumper",RearBumper="RearBumper",RearSpoilers="RearSpoiler",RearSpoiler="RearSpoiler",SidePods="SidePods"}
	return map[folder] or explicit
end

function Adapter.ModuleRaw(template,instance)
	if not template then return {} end
	if template:GetAttribute("V2Materialised")==true then return V2Upgrades.ApplyToModuleRaw(template,instance and instance.V2UpgradePoints or {}) end
	local raw={}
	for _,name in ipairs(Definitions.RawVariableOrder) do raw[name]=tonumber(template:GetAttribute(name)) or tonumber(template:GetAttribute("PerformanceDelta_"..name)) or 0 end
	local levels=instance and instance.UpgradeLevels or {}
	for _,definition in ipairs(LegacyDefinitions.GetForModuleType(moduleType(template))) do
		local level=math.clamp(math.floor(tonumber(levels[definition.UpgradeId]) or 0),0,definition.MaxLevel or 3)
		for name,amount in pairs(definition.EffectsPerLevel or {}) do if level>0 and typeof(amount)=="number" and table.find(Definitions.RawVariableOrder,name) then raw[name]=(raw[name] or 0)+amount*level end end
	end
	return raw
end

function Adapter.ApplyClone(clone,template,resolved)
	if not (clone and template) then return end
	for name,value in pairs(Adapter.ModuleRaw(template,resolved and resolved.Instance)) do clone:SetAttribute(name,value) end
	clone:SetAttribute("PreviewModuleInstanceId",resolved and resolved.InstanceId or "")
	clone:SetAttribute("PreviewUsesSavedCustomisation",resolved and resolved.Instance~=nil)
end

function Adapter.ProfileFingerprint(profile)
	local active={}
	local function encode(value)
		if typeof(value)~="table" then return typeof(value)..":"..tostring(value) end
		if active[value] then return "<cycle>" end; active[value]=true
		local keys={}; for key in pairs(value) do table.insert(keys,key) end; table.sort(keys,function(a,b) return typeof(a)..":"..tostring(a)<typeof(b)..":"..tostring(b) end)
		local result={"{"}; for _,key in ipairs(keys) do table.insert(result,encode(key)); table.insert(result,"="); table.insert(result,encode(value[key])); table.insert(result,";") end; table.insert(result,"}"); active[value]=nil; return table.concat(result)
	end
	return encode(profile or {})
end

function Adapter.Performance(state,categoriesRoot)
	local profile=state and state.Profile; local base=profile and profile.Performance
	if not (state and state.Stage=="Build" and state.ModuleMode=="Options" and state.SelectedModuleId and typeof(base)=="table" and typeof(base.Raw)=="table" and typeof(base.Overall)=="table") then return nil,nil end
	local installedId,installedInstance,installedInstanceId=Adapter.Installed(state,state.SelectedSlot)
	if state.SelectedModuleInstanceId~=nil and tostring(state.SelectedModuleInstanceId)==tostring(installedInstanceId or "") then return base,base end
	local selectedTemplate=Adapter.FindTemplate(categoriesRoot,state.SelectedModuleId); if not selectedTemplate then return nil,nil end
	local selectedInstance=Adapter.Selected(state,state.SelectedSlot,state.SelectedModuleId)
	local raw=Calculator.CloneRaw(base.Raw)
	if installedId then local installedTemplate=Adapter.FindTemplate(categoriesRoot,installedId); if not installedTemplate then return nil,nil end; Calculator.AddRaw(raw,Adapter.ModuleRaw(installedTemplate,installedInstance),-1) end
	Calculator.AddRaw(raw,Adapter.ModuleRaw(selectedTemplate,selectedInstance),1)
	return Calculator.Calculate(raw),base
end

return Adapter
]==]
compile("GarageModuleInstancePreviewAdapter", adapterSource)

local previewSource = previewVehicle.Source
if not string.find(previewSource, REVISION, 1, true) then
	previewSource = replaceOnce(previewSource,
		[[local PaintClient=require(controllersFolder:WaitForChild("Core"):WaitForChild("PaintClient"))]],
		[[local PaintClient=require(controllersFolder:WaitForChild("Core"):WaitForChild("PaintClient"))
local InstancePreview=require(controllersFolder:WaitForChild("Preview"):WaitForChild("GarageModuleInstancePreviewAdapter")) -- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1]],
		"preview adapter require")
	local oldLoop = [[	for slotId,moduleId in pairs(modulesToShow) do local moduleTemplate=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"ModuleId",moduleId); local mount=PreviewVehicleController.GetSlotMount(vehicle,slotId); if moduleTemplate and mount then local clone=moduleTemplate:Clone(); clone.Name="PREVIEW_"..tostring(slotId).."_"..moduleTemplate.Name; clone.Parent=installedRoot; PreviewVehicleController.PivotModuleToSlot(clone,mount); local neonOwned=(state.Profile and state.Profile.NeonOwned) or {}; PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(state.Profile,slotId),neonOwned[slotId]==true or state.PreviewNeonSlot==slotId,{Profile=state.Profile}) end end]]
	local newLoop = [[	for slotId,moduleId in pairs(modulesToShow) do
		local moduleTemplate=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"ModuleId",moduleId); local mount=PreviewVehicleController.GetSlotMount(vehicle,slotId)
		if moduleTemplate and mount then
			local clone=moduleTemplate:Clone(); clone.Name="PREVIEW_"..tostring(slotId).."_"..moduleTemplate.Name; clone.Parent=installedRoot; PreviewVehicleController.PivotModuleToSlot(clone,mount)
			local resolved=InstancePreview.Resolve(state,slotId,moduleId); InstancePreview.ApplyClone(clone,moduleTemplate,resolved)
			PaintClient.ApplyColors(clone,resolved.Colors,resolved.NeonOwned or state.PreviewNeonSlot==slotId,{Profile=state.Profile})
		end
	end]]
	previewSource = replaceOnce(previewSource, oldLoop, newLoop, "preview module clone appearance")
end
compile("PreviewVehicleController", previewSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[[local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController"))]],
		[[local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController")); local InstancePreview=require(previewFolder:WaitForChild("GarageModuleInstancePreviewAdapter")) -- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1]],
		"application preview adapter require")
	applicationSource = replaceOnce(applicationSource,
		[[local function buildPreview() State.GarageCameraActive=true; local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace}); if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end end]],
		[[local function buildPreview()
	local before=InstancePreview.ProfileFingerprint(State.Profile); State.GarageCameraActive=true
	local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace})
	if before~=InstancePreview.ProfileFingerprint(State.Profile) then error("[NTR Module Instance Preview] Read-only invariant failed: preview mutated the client profile") end
	if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end
end]],
		"preview profile mutation guard")
	local oldPerformance = [=[local function currentPerformance()
	local raw=cloneNumbers(State.Profile and State.Profile.TotalStats); local base=Calculator.CalculateLegacy(raw)
	if State.Stage=="Build" and State.ModuleMode=="Options" and State.SelectedModuleId then local installed=moduleById(installedForSlot(State.SelectedSlot)); local selected=moduleById(State.SelectedModuleId); for _,name in ipairs({"TopSpeed","Acceleration","Handling","Drift","Braking","Weight","Boost"}) do if installed then raw[name]=(raw[name] or 0)-(tonumber(installed[name]) or 0) end; if selected then raw[name]=(raw[name] or 0)+(tonumber(selected[name]) or 0) end end end
	return Calculator.CalculateLegacy(raw),base
end]=]
	local newPerformance = [=[local function currentPerformance()
	local instanceNow,instanceBase=InstancePreview.Performance(State,categoriesRoot)
	if instanceNow then return instanceNow,instanceBase end
	local raw=cloneNumbers(State.Profile and State.Profile.TotalStats); local base=Calculator.CalculateLegacy(raw)
	if State.Stage=="Build" and State.ModuleMode=="Options" and State.SelectedModuleId then local installed=moduleById(installedForSlot(State.SelectedSlot)); local selected=moduleById(State.SelectedModuleId); for _,name in ipairs({"TopSpeed","Acceleration","Handling","Drift","Braking","Weight","Boost"}) do if installed then raw[name]=(raw[name] or 0)-(tonumber(installed[name]) or 0) end; if selected then raw[name]=(raw[name] or 0)+(tonumber(selected[name]) or 0) end end end
	return Calculator.CalculateLegacy(raw),base
end]=]
	applicationSource = replaceOnce(applicationSource, oldPerformance, newPerformance, "instance-aware preview performance")
end
compile("ModuleShopUIController", applicationSource)

local failures={}
local function expect(ok,message) if not ok then table.insert(failures,message) end end
expect(string.find(adapterSource,"No remote calls, profile writes or ownership changes belong here",1,true)~=nil,"adapter read-only contract missing")
expect(not string.find(adapterSource,"InvokeServer",1,true),"adapter contains a server invocation")
expect(not string.find(adapterSource,"Instance%.EquippedVehicleId%s*=",1),"adapter contains an ownership write")
expect(string.find(previewSource,"InstancePreview.Resolve(state,slotId,moduleId)",1,true)~=nil,"preview appearance bridge missing")
expect(string.find(previewSource,"InstancePreview.ApplyClone",1,true)~=nil,"preview upgrade bridge missing")
expect(string.find(applicationSource,"InstancePreview.Performance(State,categoriesRoot)",1,true)~=nil,"preview stats bridge missing")
expect(string.find(applicationSource,"Read-only invariant failed: preview mutated the client profile",1,true)~=nil,"preview mutation audit missing")
if #failures>0 then error("[NTR Module Instance Preview] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Module Instance Preview] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldPreviewSource=previewVehicle.Source
local oldApplicationSource=application.Source
local oldAdapterSource=existingAdapter and existingAdapter.Source or nil
local created=false
local ok,err=xpcall(function()
	local adapter=existingAdapter
	if not adapter then adapter=Instance.new("ModuleScript"); adapter.Name="GarageModuleInstancePreviewAdapter"; adapter.Parent=previewFolder; created=true end
	adapter.Source=adapterSource
	previewVehicle.Source=previewSource
	application.Source=applicationSource
	assert(adapter.Source==adapterSource and previewVehicle.Source==previewSource and application.Source==applicationSource,"Source readback mismatch")
	print("[NTR Module Instance Preview] INSTALL PASS - selected physical copies preview saved colours, neon and upgrades without equipping")
	print("Restart Play. Open Build Modules > Owned Modules, click equipped/available/in-use copies, and verify the vehicle plus stat deltas change before EQUIP.")
end,debug.traceback)
if not ok then
	pcall(function() previewVehicle.Source=oldPreviewSource end)
	pcall(function() application.Source=oldApplicationSource end)
	if created then pcall(function() previewFolder.GarageModuleInstancePreviewAdapter:Destroy() end) elseif existingAdapter and oldAdapterSource then pcall(function() existingAdapter.Source=oldAdapterSource end) end
	error("[NTR Module Instance Preview] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
