-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3
-- NTR_PRESENTATION_AUDIO_PREVIEW_PROFILE_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PreviewVehicleController={}
local controllersFolder=script.Parent.Parent
local PaintClient=require(controllersFolder:WaitForChild("Core"):WaitForChild("PaintClient"))
local InstancePreview=require(controllersFolder:WaitForChild("Preview"):WaitForChild("GarageModuleInstancePreviewAdapter")) -- NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local VehicleCosmetics=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_VEHICLE_COSMETIC_PREVIEW_V1
local PathResolver=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("PathResolver"))
local cfg=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
PreviewVehicleController.PreviewFolderName="HOVER_RACING_V2_LOCAL_PREVIEW"
local previewPadReported=false
local function number(name,fallback) local value=cfg:GetAttribute(name); if typeof(value)=="number" then return value end; local child=cfg:FindFirstChild(name); return tonumber(child and child.Value) or fallback end
function PreviewVehicleController.FindTemplateByAttribute(root,attr,value) if not root or value==nil then return nil end; for _,item in ipairs(root:GetDescendants()) do if item:GetAttribute(attr)==value then return item end end end
function PreviewVehicleController.GetPreviewRoot(workspaceRef,previewState)
	workspaceRef=workspaceRef or workspace; previewState=previewState or {}; if previewState.Root and previewState.Root.Parent then return previewState.Root end
	local existing=workspaceRef:FindFirstChild(PreviewVehicleController.PreviewFolderName); if existing then previewState.Root=existing; return existing end
	local root=Instance.new("Folder"); root.Name=PreviewVehicleController.PreviewFolderName; root.Parent=workspaceRef; previewState.Root=root; return root
end
function PreviewVehicleController.ClearRoot(root) if root then root:ClearAllChildren() end end
function PreviewVehicleController.GetSlotMount(vehicle,slotId) local root=vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename",true); local slot=root and root:FindFirstChild("SLOT_"..tostring(slotId)); return slot and slot:FindFirstChild("Mount_DoNotRename") end
function PreviewVehicleController.PivotModuleToSlot(moduleClone,mount)
	local root=moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename",true); if root then moduleClone.PrimaryPart=root end
	local moduleAttachment=moduleClone:FindFirstChild("MountAttachment",true); local mountAttachment=mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then moduleClone:PivotTo(mountAttachment.WorldCFrame*moduleAttachment.CFrame:Inverse()) elseif mount then moduleClone:PivotTo(mount.CFrame) end
end
function PreviewVehicleController.ModuleColors(profile,slotId) profile=profile or {}; return PaintClient.ModuleColors(profile,slotId,profile.CockpitColors or {},profile.ModuleColors and profile.ModuleColors[slotId] or {}) end
function PreviewVehicleController.ClearPreviewModules(state) state.PreviewModules={}; state.SelectedModuleId=nil end
local function previewCFrame(state)
	local ok,pad=pcall(PathResolver.GaragePreviewPad)
	if ok and pad and pad:IsA("BasePart") then
		if not previewPadReported then print("[NTR Garage Preview] PAD PASS "..pad:GetFullName()); previewPadReported=true end
		return pad.CFrame*CFrame.new(0,number("PreviewPadYOffset",0),0),pad
	end
	local fallback=state.Catalog and state.Catalog.PreviewPosition or Vector3.new(860,104,-1749); warn("[NTR Garage Preview] PAD FALLBACK - GaragePreviewPad unavailable")
	return CFrame.new(fallback),nil
end
function PreviewVehicleController.Build(context)
	local state=context.State; if not state then return nil,"State missing" end; local profile=state.PreviewProfile or state.Profile or {}; local categoriesRoot=context.CategoriesRoot; if not categoriesRoot then return nil,"Categories root missing" end -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
	local preview=context.Preview or {}; local root=PreviewVehicleController.GetPreviewRoot(context.Workspace,preview); PreviewVehicleController.ClearRoot(root)
	local cockpitId=state.SelectedCockpit or profile.CurrentCockpit or "bruiser_01"; local template=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"CockpitId",cockpitId); if not template then return nil,"Cockpit template not found: "..tostring(cockpitId) end
	local vehicle=template:Clone(); vehicle.Name="LOCAL_PREVIEW_"..tostring(cockpitId); vehicle.Parent=root; preview.Vehicle=vehicle; local primary=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true); if primary then vehicle.PrimaryPart=primary end
	local placement,pad=previewCFrame(state); vehicle:PivotTo(placement); state.PreviewPadCFrame=placement; preview.Pad=pad
	local cockpitColors={}; for key,value in pairs(profile.CockpitColors or {}) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116); PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})
	local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)
	local previewAudioProfileId=currentVehicle and (currentVehicle.ResolvedAudioProfileId or currentVehicle.AudioProfileId) or template:GetAttribute("StandardAudioProfileId") or "GENERIC_STANDARD_AUDIO"; root:SetAttribute("PreviewAudioProfileId",tostring(previewAudioProfileId))
	local thrustColor=profile.ThrustColor or Color3.new(1,1,1); root:SetAttribute("ThrustColor",thrustColor); root:SetAttribute("ForceThrustPreview",state.ThrustPreviewActive==true); vehicle:SetAttribute("ThrustColor",thrustColor)
	local installedRoot=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder"); installedRoot.Name="INSTALLED_MODULES_Runtime"; installedRoot.Parent=vehicle; installedRoot:ClearAllChildren()
	local modulesToShow={}; for slotId,moduleId in pairs(profile.InstalledModules or {}) do modulesToShow[slotId]=moduleId end; for slotId,moduleId in pairs(state.PreviewModules or {}) do modulesToShow[slotId]=moduleId end
	for slotId,moduleId in pairs(modulesToShow) do
		local moduleTemplate=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"ModuleId",moduleId); local mount=PreviewVehicleController.GetSlotMount(vehicle,slotId)
		if moduleTemplate and mount then
			local clone=moduleTemplate:Clone(); clone.Name="PREVIEW_"..tostring(slotId).."_"..moduleTemplate.Name; clone.Parent=installedRoot; PreviewVehicleController.PivotModuleToSlot(clone,mount)
			local resolved=InstancePreview.Resolve(state,slotId,moduleId); InstancePreview.ApplyClone(clone,moduleTemplate,resolved)
			PaintClient.ApplyColors(clone,resolved.Colors,resolved.NeonOwned or state.PreviewNeonSlot==slotId,{Profile=profile})
		end
	end
	local boxCFrame=vehicle:GetBoundingBox(); state.TargetFocus=boxCFrame.Position; preview.Focus=boxCFrame.Position; return vehicle,nil
end
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
function PreviewVehicleController.ApplyPaint(context)
	local state=context.State; local preview=context.Preview or {}; local profile=state and (state.PreviewProfile or state.Profile); local vehicle=preview.Vehicle
	if not (profile and vehicle and vehicle.Parent) then return false end
	local target=tostring(context.Target or "Cockpit"); local channel=tostring(context.Channel or "Primary"); local color=context.Color
	if typeof(color)~="Color3" then return false end
	profile.CockpitColors=profile.CockpitColors or {}; profile.ModuleColors=profile.ModuleColors or {}
	local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
	if target=="THRUST_COLOR" then
		profile.ThrustColor=color; if currentVehicle then currentVehicle.ThrustColor=color end
		local root=preview.Root; if root then root:SetAttribute("ThrustColor",color); root:SetAttribute("ForceThrustPreview",true) end; vehicle:SetAttribute("ThrustColor",color); return true
	elseif target=="UNDERGLOW" then
		local cosmetics=VehicleCosmetics.NormalizeVehicle(currentVehicle); if cosmetics then cosmetics.Colours.Underglow=color end
	elseif target=="Cockpit" then
		profile.CockpitColors[channel]=color
	elseif target=="WholeVehicle" or target=="ALL" then
		profile.CockpitColors[channel]=color
		for slotId in pairs(profile.InstalledModules or {}) do
			if channel~="Neon" or (profile.NeonOwned or {})[slotId]==true then profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId][channel]=color end
		end
		if channel=="Neon" then local cosmetics=VehicleCosmetics.NormalizeVehicle(currentVehicle); if cosmetics and cosmetics.Unlocks.Underglow then cosmetics.Colours.Underglow=color end end
	else profile.ModuleColors[target]=profile.ModuleColors[target] or {}; profile.ModuleColors[target][channel]=color end
	if currentVehicle then currentVehicle.CockpitColors=profile.CockpitColors end
	local cockpitColors={}; for key,value in pairs(profile.CockpitColors) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116)
	PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile}); VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)
	local installed=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
	if installed then for slotId in pairs(profile.InstalledModules or {}) do local prefix="PREVIEW_"..tostring(slotId).."_"; for _,clone in ipairs(installed:GetChildren()) do if string.sub(clone.Name,1,#prefix)==prefix then PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(profile,slotId),(profile.NeonOwned or {})[slotId]==true,{Profile=profile}) end end end end
	return true
end
return PreviewVehicleController
