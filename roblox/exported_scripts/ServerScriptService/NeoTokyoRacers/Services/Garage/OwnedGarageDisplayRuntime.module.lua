-- NTR_OWNED_GARAGE_DISPLAY_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Runtime={}
local categories=ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles:WaitForChild("Categories")
local function findByAttribute(root,key,value)
	if not root then return nil end
	for _,item in ipairs(root:GetDescendants()) do if item:IsA("Model") and tostring(item:GetAttribute(key) or "")==tostring(value or "") then return item end end
	return nil
end
local function categoryFolder(categoryId)
	local wanted=string.lower(tostring(categoryId or "BRUISER"))
	for _,child in ipairs(categories:GetChildren()) do if string.lower(child.Name)==wanted then return child end end
	return categories:FindFirstChild("BRUISER") or categories:GetChildren()[1]
end
local function cockpitTemplate(categoryId,cockpitId)
	local category=categoryFolder(categoryId); local root=category and (category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS"))
	return findByAttribute(root or category,"CockpitId",cockpitId)
end
local function moduleTemplate(categoryId,moduleId)
	local category=categoryFolder(categoryId); local root=category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
	return findByAttribute(root,"ModuleId",moduleId)
end
local function channel(object)
	local current=object
	while current do
		local value=current:GetAttribute("PaintChannel"); if type(value)=="string" and value~="" then return value end
		if current.Name=="PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
		if current.Name=="SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
		if current.Name=="DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
		if current.Name=="NEON_OptionalLights" then return "Neon" end
		if current.Name=="THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
		current=current.Parent
	end
	return nil
end
local function pathHas(object,text)
	text=string.lower(text); local current=object
	while current do if string.find(string.lower(current.Name),text,1,true) then return true end; current=current.Parent end
	return false
end
local function copyTable(value)
	local result={}; for key,child in pairs(type(value)=="table" and value or {}) do result[key]=child end; return result
end
local function applyColours(model,colours,neonVisible)
	colours=type(colours)=="table" and colours or {}
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			local paint=channel(object)
			if object:GetAttribute("TemplateRole")=="FixedSlotMount" then object.Transparency=1
			elseif paint=="ThrustColor" then object.Color=colours.ThrustColor or Color3.new(1,1,1); object.Material=Enum.Material.Neon; object.Transparency=0
			elseif paint=="Neon" then
				local colour=colours.Neon or Color3.new(1,1,1); if pathHas(object,"cockpit") and pathHas(object,"front") then colour=colours.FrontLights or Color3.fromRGB(252,250,255) end; if pathHas(object,"cockpit") and (pathHas(object,"rear") or pathHas(object,"back")) then colour=colours.RearLights or Color3.fromRGB(255,116,116) end
				object.Color=colour; object.Material=Enum.Material.Neon; object.Transparency=neonVisible and 0 or 1
			elseif paint=="Primary" and colours.Primary then object.Color=colours.Primary
			elseif paint=="Secondary" and colours.Secondary then object.Color=colours.Secondary
			elseif paint=="Detail" and colours.Detail then object.Color=colours.Detail end
		end
	end
end
local function mountFor(vehicle,slotId)
	local root=vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename",true); local slot=root and root:FindFirstChild("SLOT_"..tostring(slotId),true)
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end
local function pivotModule(module,mount)
	local root=module.PrimaryPart or module:FindFirstChild("ModuleRoot_DoNotRename",true); if root then module.PrimaryPart=root end
	local source=module:FindFirstChild("MountAttachment",true); local target=mount and mount:FindFirstChild("MountAttachment")
	if source and target then module:PivotTo(target.WorldCFrame*source.CFrame:Inverse()) elseif mount then module:PivotTo(mount.CFrame) end
end
function Runtime.SanitizeForDisplay(model)
	local removed=0; local parts=0
	for _,object in ipairs(model:GetDescendants()) do
		if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("VehicleSeat") or object:IsA("Seat") then object:Destroy(); removed+=1
		elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("Smoke") or object:IsA("Fire") or object:IsA("Sparkles") then object.Enabled=false
		elseif object:IsA("Light") then object.Enabled=false
		elseif object:IsA("BasePart") then object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.Massless=true; object.CastShadow=false; parts+=1 end
	end
	return {Parts=parts,Removed=removed}
end
function Runtime.Build(profile,vehicleId,spaceMarker,parent)
	vehicleId=tostring(vehicleId or ""); if type(profile)~="table" or type(profile.Vehicles)~="table" then return nil,"Profile vehicles missing." end
	local vehicle=profile.Vehicles[vehicleId]; if type(vehicle)~="table" then return nil,"Vehicle is not owned." end
	if not (spaceMarker and spaceMarker:IsA("BasePart") and parent) then return nil,"Display marker/parent missing." end
	local slotId=tostring(spaceMarker:GetAttribute("DisplaySpaceId") or spaceMarker.Name)
	for _,other in ipairs(parent:GetChildren()) do if other:IsA("Model") and other:GetAttribute("OwnedGarageDisplay")==true and other:GetAttribute("VehicleId")==vehicleId and other:GetAttribute("DisplaySpaceId")~=slotId then return nil,"Duplicate display vehicle rejected." end end
	local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[tostring(vehicle.CockpitInstanceId or "")]
	local cockpitId=tostring((type(cockpitInstance)=="table" and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); local categoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "BRUISER")
	local template=cockpitTemplate(categoryId,cockpitId); if not template then return nil,"Cockpit template not found: "..cockpitId end
	local display=template:Clone(); display.Name="DisplayVehicle_"..slotId; display:SetAttribute("OwnedGarageDisplay",true); display:SetAttribute("VehicleId",vehicleId); display:SetAttribute("DisplaySpaceId",slotId); display:SetAttribute("CockpitId",cockpitId)
	local root=display.PrimaryPart or display:FindFirstChild("CockpitRoot_DoNotRename",true); if not root then display:Destroy(); return nil,"Cockpit root missing." end; display.PrimaryPart=root
	local colours=copyTable(vehicle.CockpitColors); colours.ThrustColor=vehicle.ThrustColor or colours.ThrustColor; applyColours(display,colours,true)
	local installedRoot=Instance.new("Folder"); installedRoot.Name="INSTALLED_MODULES_Runtime"; installedRoot.Parent=display; local moduleCount=0; local missingModules=0
	for installedSlot,instanceId in pairs(type(vehicle.InstalledModules)=="table" and vehicle.InstalledModules or {}) do
		local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]; local moduleId=type(instance)=="table" and tostring(instance.TemplateId or "") or ""; local source=moduleId~="" and moduleTemplate(categoryId,moduleId) or nil; local mount=mountFor(display,installedSlot)
		if source and mount then local clone=source:Clone(); clone.Name="DISPLAY_"..tostring(installedSlot).."_"..source.Name; clone.Parent=installedRoot; pivotModule(clone,mount); local moduleColours=copyTable(instance.Colors); moduleColours.ThrustColor=vehicle.ThrustColor or moduleColours.ThrustColor; applyColours(clone,moduleColours,instance.NeonOwned==true); moduleCount+=1 else missingModules+=1 end
	end
	local metrics=Runtime.SanitizeForDisplay(display); local old=parent:FindFirstChild("DisplayVehicle_"..slotId); if old then old:Destroy() end
	display:PivotTo(spaceMarker.CFrame*CFrame.new(0,tonumber(ReplicatedStorage.NeoTokyoRacers.Config.Runtime.OwnedGarage_EditAttributes:GetAttribute("DisplayModelYOffset")) or 3.2,0)*CFrame.Angles(0,math.rad(180),0)); display.Parent=parent
	return display,{VehicleId=vehicleId,CockpitId=cockpitId,Modules=moduleCount,MissingModules=missingModules,Parts=metrics.Parts}
end
function Runtime.Clear(parent,slotId)
	local model=parent and parent:FindFirstChild("DisplayVehicle_"..tostring(slotId or "")); if model and model:GetAttribute("OwnedGarageDisplay")==true then model:Destroy(); return true end
	return false
end
return Runtime
