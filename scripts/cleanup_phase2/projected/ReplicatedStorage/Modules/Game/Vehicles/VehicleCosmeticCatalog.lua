-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_CATALOG_V1_2_AUTHORED_LIGHT_PROPERTIES
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog={}
Catalog.SchemaVersion=1
local root=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement"):WaitForChild("VehicleCosmetics")

local ids={"ThrustColour","Underglow"}
local function folder(id) local item=root:FindFirstChild(tostring(id)); return item and item:IsA("Folder") and item or nil end
local function clone(value) if typeof(value)~="table" then return value end; local result={}; for key,child in pairs(value) do result[key]=clone(child) end; return result end
local function defaultColour(id) local item=folder(id); local value=item and item:GetAttribute("DefaultColor"); return typeof(value)=="Color3" and value or Color3.new(1,1,1) end

function Catalog.Get(id)
	id=tostring(id or "")
	local item=folder(id); if not item then return nil end
	return {
		CosmeticId=id,
		DisplayName=tostring(item:GetAttribute("DisplayName") or id),
		Price=math.max(0,math.floor(tonumber(item:GetAttribute("Price")) or 0)),
		Icon=tostring(item:GetAttribute("Icon") or ""),
		DefaultColor=defaultColour(id),
		Available=item:GetAttribute("Available")~=false,
		SortOrder=math.floor(tonumber(item:GetAttribute("SortOrder")) or 100),
	}
end

function Catalog.List()
	local result={}
	for _,id in ipairs(ids) do local definition=Catalog.Get(id); if definition then table.insert(result,definition) end end
	table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end)
	return result
end

function Catalog.DefaultState()
	return {SchemaVersion=Catalog.SchemaVersion,Unlocks={ThrustColour=false,Underglow=false},Colours={Underglow=defaultColour("Underglow")}}
end

function Catalog.NormalizeVehicle(vehicle)
	if typeof(vehicle)~="table" then return nil end
	local state=typeof(vehicle.Cosmetics)=="table" and vehicle.Cosmetics or {}
	state.SchemaVersion=Catalog.SchemaVersion
	state.Unlocks=typeof(state.Unlocks)=="table" and state.Unlocks or {}
	state.Colours=typeof(state.Colours)=="table" and state.Colours or {}
	for _,id in ipairs(ids) do state.Unlocks[id]=state.Unlocks[id]==true end
	state.Colours.Underglow=typeof(state.Colours.Underglow)=="Color3" and state.Colours.Underglow or defaultColour("Underglow")
	vehicle.Cosmetics=state
	return state
end

function Catalog.IsUnlocked(vehicle,id)
	local state=Catalog.NormalizeVehicle(vehicle)
	return state~=nil and state.Unlocks[tostring(id)]==true
end

local function underglowContainer(object)
	local current=object
	while current do
		if current.Name=="UNDERGLOW_MOUNT_DoNotRename" or current.Name=="UNDERGLOW_EMITTERS_DoNotRename" or current:GetAttribute("VehicleCosmeticId")=="Underglow" then return current end
		current=current.Parent
	end
	return nil
end

local function isUnderglowLight(object)
	if not (object and object:IsA("SurfaceLight")) then return false end
	return object:GetAttribute("VehicleCosmeticId")=="Underglow"
		or object:GetAttribute("LightChannel")=="Underglow"
		or underglowContainer(object)~=nil
end

function Catalog.HasUnderglowMount(model)
	if not model then return false end
	for _,object in ipairs(model:GetDescendants()) do if isUnderglowLight(object) then return true end end
	return false
end

function Catalog.IsProtectedVehicleLight(object)
	if not (object and (object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight"))) then return false end
	if isUnderglowLight(object) then return true end
	local current=object
	while current do
		local channel=tostring(current:GetAttribute("LightChannel") or "")
		if channel=="FrontLights" or channel=="RearLights" then return true end
		if current:GetAttribute("RootCockpitSpotLight")==true or current:GetAttribute("NTRCockpitLightSystem")~=nil then return true end
		-- Current cockpit templates predate the channel attributes but use stable
		-- authored front/rear spotlight-lens names. Preserve those lights too.
		local lower=string.lower(current.Name)
		if string.find(lower,"cockpit",1,true) and (string.find(lower,"front",1,true) or string.find(lower,"rear",1,true) or string.find(lower,"back",1,true)) then return true end
		current=current.Parent
	end
	return false
end

function Catalog.ApplyPresentation(model,vehicle)
	if not model then return {Detected=0,Enabled=0} end
	-- Presentation is read-only: preview builds fingerprint the client profile
	-- and must never mutate it merely because an older vehicle lacks this state.
	local state=typeof(vehicle)=="table" and typeof(vehicle.Cosmetics)=="table" and vehicle.Cosmetics or nil
	local unlocks=state and typeof(state.Unlocks)=="table" and state.Unlocks or {}
	local colours=state and typeof(state.Colours)=="table" and state.Colours or {}
	local unlocked=unlocks.Underglow==true
	local colour=typeof(colours.Underglow)=="Color3" and colours.Underglow or defaultColour("Underglow")
	local definition=folder("Underglow")
	local lights={}
	for _,object in ipairs(model:GetDescendants()) do
		if isUnderglowLight(object) then table.insert(lights,object) end
	end
	table.sort(lights,function(a,b) return a:GetFullName()<b:GetFullName() end)
	local enabledCount=0
	for _,object in ipairs(lights) do
		-- Runtime owns only the saved player colour and purchase visibility.
		-- Brightness, Range, Angle, Face, Shadows and all other presentation
		-- properties remain authored independently on each cockpit template.
		object.Color=colour
		object.Enabled=unlocked
		if unlocked then enabledCount+=1 end
	end
	local detected=#lights
	if definition and definition:GetAttribute("DebugEnabled")==true then
		model:SetAttribute("NTR_UnderglowDetected",detected)
		model:SetAttribute("NTR_UnderglowEnabled",enabledCount)
		model:SetAttribute("NTR_UnderglowUnlocked",unlocked)
		model:SetAttribute("NTR_UnderglowColour",colour)
	end
	return {Detected=detected,Enabled=enabledCount,Unlocked=unlocked,Colour=colour}
end

return Catalog
