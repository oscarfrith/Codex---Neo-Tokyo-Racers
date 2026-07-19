-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V1
-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
-- Resolve lazily so the module can be compiled before the catalog is installed.
local CatalogCache
local function Catalog()
	if not CatalogCache then
		local source=script:FindFirstChild("OwnedGaragePropertyCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGaragePropertyCatalog")
		CatalogCache=require(source)
	end
	return CatalogCache
end
local StyleCatalogCache
local function StyleCatalog()
	if not StyleCatalogCache then
		local source=script:FindFirstChild("OwnedGarageInteriorStyleCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")
		StyleCatalogCache=require(source)
	end
	return StyleCatalogCache
end
local Runtime={SchemaVersion=2}

local function clone(value)
	if type(value)~="table" then return value end
	local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy
end
local function defaultProperty(propertyId)
	local display={}; for _,slotId in ipairs(Catalog().SpaceIds(propertyId)) do display[slotId]=false end
	return {Owned=true,DisplaySpaces=display,AccessMode="Private",InvitedUserIds={},Customisation={SurfaceStyles=StyleCatalog().DefaultStyles(),Decorations={}}}
end
function Runtime.DefaultGarage()
	return {SchemaVersion=Runtime.SchemaVersion,Revision=0,TesterResetToken="",ActiveGarageId="STARTER_TWO_BAY",Properties={STARTER_TWO_BAY=defaultProperty("STARTER_TWO_BAY")}}
end
function Runtime.Ensure(profile,reset)
	assert(type(profile)=="table","Profile table required")
	if reset==true or type(profile.OwnedGarage)~="table" or tonumber(profile.OwnedGarage.SchemaVersion)~=Runtime.SchemaVersion then profile.OwnedGarage=Runtime.DefaultGarage() end
	local garage=profile.OwnedGarage; garage.Properties=type(garage.Properties)=="table" and garage.Properties or {}; garage.Revision=math.max(0,math.floor(tonumber(garage.Revision) or 0)); garage.TesterResetToken=tostring(garage.TesterResetToken or "")
	for _,definition in ipairs(Catalog().List()) do
		local property=garage.Properties[definition.PropertyId]
		if definition.Starter and type(property)~="table" then property=defaultProperty(definition.PropertyId); garage.Properties[definition.PropertyId]=property end
		if type(property)=="table" then
			property.Owned=property.Owned==true; property.DisplaySpaces=type(property.DisplaySpaces)=="table" and property.DisplaySpaces or {}; property.InvitedUserIds=type(property.InvitedUserIds)=="table" and property.InvitedUserIds or {}; property.Customisation=type(property.Customisation)=="table" and property.Customisation or {SurfaceStyles={},Decorations={}}
			property.Customisation.SurfaceStyles=type(property.Customisation.SurfaceStyles)=="table" and property.Customisation.SurfaceStyles or {}; property.Customisation.Decorations=type(property.Customisation.Decorations)=="table" and property.Customisation.Decorations or {}; for surfaceGroup,styleId in pairs(StyleCatalog().DefaultStyles()) do if not StyleCatalog().IsValid(surfaceGroup,property.Customisation.SurfaceStyles[surfaceGroup]) then property.Customisation.SurfaceStyles[surfaceGroup]=styleId end end
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then property.AccessMode="Private" end
			for _,slotId in ipairs(definition.DisplaySpaceIds) do if property.DisplaySpaces[slotId]==nil then property.DisplaySpaces[slotId]=false end end
			for slotId in pairs(property.DisplaySpaces) do if not Catalog().IsSpace(definition.PropertyId,slotId) then property.DisplaySpaces[slotId]=nil end end
		end
	end
	if not (garage.Properties[garage.ActiveGarageId] and garage.Properties[garage.ActiveGarageId].Owned) then garage.ActiveGarageId="STARTER_TWO_BAY" end
	return garage
end
function Runtime.Validate(profile)
	local garage=Runtime.Ensure(profile,false); local vehicles=type(profile.Vehicles)=="table" and profile.Vehicles or {}; local seen={}
	for garageId,property in pairs(garage.Properties) do
		if property.Owned then
			if not Catalog().ById(garageId) then return false,"Unknown property "..tostring(garageId) end
			if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then return false,"Invalid access mode: "..tostring(property.AccessMode) end
			for surfaceGroup,styleId in pairs(property.Customisation.SurfaceStyles or {}) do if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Invalid interior style: "..tostring(surfaceGroup).."/"..tostring(styleId) end end
			for slotId,vehicleId in pairs(property.DisplaySpaces) do
				if not Catalog().IsSpace(garageId,slotId) then return false,"Unknown display space "..garageId.."/"..slotId end
				if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then
					vehicleId=tostring(vehicleId); if not vehicles[vehicleId] then return false,"Display vehicle missing: "..vehicleId end
					if seen[vehicleId] then return false,"Vehicle displayed twice: "..vehicleId end; seen[vehicleId]=garageId.."/"..slotId
				end
			end
		end
	end
	return true,{Displayed=seen,Revision=garage.Revision}
end
function Runtime.Snapshot(profile) return clone(Runtime.Ensure(profile,false)) end
function Runtime.Restore(profile,snapshot) profile.OwnedGarage=clone(snapshot) end
function Runtime.State(profile)
	local garage=Runtime.Ensure(profile,false); local state=clone(garage); state.SchemaVersion=Runtime.SchemaVersion; return state
end
function Runtime.Assign(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local vehicleId=tostring(args.VehicleId or "")
	local property=garage.Properties[garageId]; if not (property and property.Owned) then return false,"Garage is not owned." end
	if not Catalog().IsSpace(garageId,slotId) then return false,"Display space is invalid." end
	if not (type(profile.Vehicles)=="table" and profile.Vehicles[vehicleId]) then return false,"Vehicle is not owned." end
	for _,other in pairs(garage.Properties) do for otherSlot,assigned in pairs(other.DisplaySpaces or {}) do if tostring(assigned or "")==vehicleId then other.DisplaySpaces[otherSlot]=false end end end
	property.DisplaySpaces[slotId]=vehicleId; garage.Revision+=1
	local valid,message=Runtime.Validate(profile); if not valid then return false,message end
	return true,"Display assignment updated."
end
function Runtime.Clear(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local slotId=tostring(args.SlotId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned and Catalog().IsSpace(garageId,slotId)) then return false,"Display space is invalid." end
	property.DisplaySpaces[slotId]=false; garage.Revision+=1; return true,"Display space cleared."
end
function Runtime.SetActive(profile,garageId)
	local garage=Runtime.Ensure(profile,false); garageId=tostring(garageId or ""); if not (garage.Properties[garageId] and garage.Properties[garageId].Owned) then return false,"Garage is not owned." end
	garage.ActiveGarageId=garageId; garage.Revision+=1; return true,"Active garage updated."
end
function Runtime.SetSurfaceStyle(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local surfaceGroup=tostring(args.SurfaceGroup or ""); local styleId=tostring(args.StyleId or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Interior style is invalid." end
	property.Customisation.SurfaceStyles[surfaceGroup]=styleId; garage.Revision+=1; return true,"Interior style updated."
end
function Runtime.SetAccessMode(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local accessMode=tostring(args.AccessMode or ""); local property=garage.Properties[garageId]
	if not (property and property.Owned) then return false,"Garage is not owned." end
	if accessMode~="Private" and accessMode~="FriendsOnly" and accessMode~="InviteOnly" and accessMode~="Public" then return false,"Access mode is invalid." end
	property.AccessMode=accessMode; garage.Revision+=1; return true,"Access mode updated."
end
function Runtime.NewRequestId() return HttpService:GenerateGUID(false) end
return Runtime
