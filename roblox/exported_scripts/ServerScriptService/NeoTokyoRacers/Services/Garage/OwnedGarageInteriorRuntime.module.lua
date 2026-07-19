-- NTR_OWNED_GARAGE_INTERIOR_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Runtime={}
local REQUIRED_MARKERS={"CharacterSpawn","DeskPromptAnchor","FootExitMarker","DriveInMarker","DriveOutMarker"}
local REQUIRED_SPACES={"Space01","Space02"}
local function config()
	return ReplicatedStorage.NeoTokyoRacers.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
end
local function templates()
	return ServerStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("OwnedGarage"):WaitForChild("Templates")
end
function Runtime.AuditTemplate(template)
	if not (template and template:IsA("Model") and template.PrimaryPart) then return false,"Template model/PrimaryPart missing." end
	for _,name in ipairs(REQUIRED_MARKERS) do
		local marker=template:FindFirstChild(name,true)
		if not (marker and marker:IsA("BasePart")) then return false,"Marker missing: "..name end
	end
	local spaces=template:FindFirstChild("DisplaySpaceMarkers")
	if not spaces then return false,"DisplaySpaceMarkers missing." end
	for _,slotId in ipairs(REQUIRED_SPACES) do
		local marker=spaces:FindFirstChild(slotId)
		if not (marker and marker:IsA("BasePart") and marker:GetAttribute("DisplaySpaceId")==slotId) then return false,"Display marker invalid: "..slotId end
	end
	return true,{DisplaySpaces=#REQUIRED_SPACES,TemplateId=template:GetAttribute("OwnedGarageTemplateId")}
end
function Runtime.SlotCFrame(slotIndex)
	slotIndex=math.max(1,math.floor(tonumber(slotIndex) or 1)); local settings=config()
	local columns=math.max(1,math.floor(tonumber(settings:GetAttribute("GridColumns")) or 8)); local index=slotIndex-1
	local base=settings:GetAttribute("InteriorBasePosition"); if typeof(base)~="Vector3" then base=Vector3.new(0,3200,0) end
	local x=(index%columns)*(tonumber(settings:GetAttribute("GridSpacingX")) or 160)
	local z=math.floor(index/columns)*(tonumber(settings:GetAttribute("GridSpacingZ")) or 120)
	return CFrame.new(base+Vector3.new(x,0,z))
end
function Runtime.InstanceName(ownerUserId,propertyId)
	return "OwnedGarage_"..tostring(math.floor(tonumber(ownerUserId) or 0)).."_"..tostring(propertyId or "")
end
function Runtime.Create(parent,ownerUserId,propertyId,templateId,slotIndex)
	if not (parent and parent:IsA("Folder")) then return nil,"Runtime pool folder required." end
	local name=Runtime.InstanceName(ownerUserId,propertyId); local existing=parent:FindFirstChild(name)
	if existing then local valid,message=Runtime.AuditTemplate(existing); if valid then return existing,"Existing" end; return nil,message end
	local limit=math.max(1,math.floor(tonumber(config():GetAttribute("MaxActiveInteriorsPerServer")) or 24))
	local count=0; for _,child in ipairs(parent:GetChildren()) do if child:IsA("Model") then count+=1 end end
	if count>=limit then return nil,"Active interior limit reached." end
	local template=templates():FindFirstChild(tostring(templateId or "")); local valid,message=Runtime.AuditTemplate(template); if not valid then return nil,message end
	local model=template:Clone(); model.Name=name; model:SetAttribute("OwnerUserId",math.floor(tonumber(ownerUserId) or 0)); model:SetAttribute("PropertyId",tostring(propertyId or "")); model:SetAttribute("RuntimeSlotIndex",math.max(1,math.floor(tonumber(slotIndex) or 1)))
	for _,descendant in ipairs(model:GetDescendants()) do if descendant:IsA("ProximityPrompt") then descendant.Enabled=false end end
	model:PivotTo(Runtime.SlotCFrame(slotIndex)); model.Parent=parent
	return model,"Created"
end
function Runtime.Destroy(parent,ownerUserId,propertyId)
	local model=parent and parent:FindFirstChild(Runtime.InstanceName(ownerUserId,propertyId)); if model then model:Destroy(); return true end
	return false
end
return Runtime
