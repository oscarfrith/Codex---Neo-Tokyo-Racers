-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V5_DECORATION_ANCHORS
-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V6_LIGHTING_SLOTS
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROPERTY_V1
-- NTR_OWNED_GARAGE_TYPED_FIXTURE_PROPERTY_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_PROPERTY
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
local Catalog={DefinitionVersion=6,StateApiVersion=6}
local accessModes={"Private","FriendsOnly","InviteOnly","Public"}
local decorationSlots={
	{SlotId="WorkshopWall",DisplayName="WORKSHOP WALL",IconKey="Tools",SortOrder=10,Required=true,DefaultItemId="WORKSHOP_STREET",StarterItemId="WORKSHOP_STREET",HideTemplateModel="ManagementDesk"},
	{SlotId="StorageWall",DisplayName="STORAGE WALL",IconKey="Box",SortOrder=20,Required=true,DefaultItemId="STORAGE_OPEN_RACK",StarterItemId="STORAGE_OPEN_RACK",HideTemplateModel="shelving left"},
	{SlotId="HangoutBay",DisplayName="HANGOUT BAY",IconKey="Chair",SortOrder=30},
	{SlotId="FeatureCorner",DisplayName="FEATURE CORNER",IconKey="Spark",SortOrder=40},
	{SlotId="IdentityWall",DisplayName="IDENTITY WALL",IconKey="Image",SortOrder=50},
	{SlotId="DisplayPlatforms",DisplayName="DISPLAY PLATFORMS",IconKey="Garage",SortOrder=60,StarterItemId="PLATFORM_OPTION_01",AnchorId="TemplateOrigin",AssetGroupId="DisplayPlatforms",HideSurfaceGroup="DisplayPads"},
}
local properties={{PropertyId="STARTER_TWO_BAY",DisplayName="Kanda Two-Bay",District="Kanda Stack Apartments",Description="A private two-bay workshop with vehicle display, interior customisation and secure access.",Image="",TemplateId="StarterTwoBay",ExteriorSpawnId="STARTER_TWO_BAY",TemplateContractVersion=2,StateSchemaVersion=4,DisplaySpaceIds={"Space01","Space02"},StructureSections={"FrontWall","LeftWall","RightWall","BackWall","Floor","Ceiling"},SurfaceGroups={"Floor","Walls","Roof","DisplayPads","Doors"},DecorationSlots=decorationSlots,DecorationAnchorIds={"WorkshopWall","StorageWall","HangoutBay","FeatureCorner","IdentityWall","DisplayPlatforms"},LightingSlotIds={"Light01","Light02","Light03","Light04"},Capabilities={DisplayCars=true,Structure=true,Decorations=true,Lighting=true,Access=true,Invitations=true,Visitors=false,DriveIn=true,DriveOut=true},UI={BrowserCardKind="GarageProperty",ManagementLayout="TwoBay",HeroAspectRatio=1.7778},VehicleCapacityContribution=2,Price=0,Available=true,Starter=true,SortOrder=10}}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
local function nonEmptyUnique(list,label,key) assert(type(list)=="table" and #list>0,label.." must be a non-empty array"); local seen={}; for _,raw in ipairs(list) do local value=key and tostring(raw[key] or "") or tostring(raw or ""); assert(value~="",label.." contains an empty id"); assert(not seen[value],label.." contains duplicate "..value); seen[value]=true end end
local function validateDefinition(definition,seen)
	local id=tostring(definition.PropertyId or ""); assert(id~="" and not seen[id],"Invalid or duplicate PropertyId "..id); seen[id]=true; assert(tostring(definition.TemplateId or "")~="",id.." TemplateId required"); assert(tostring(definition.ExteriorSpawnId or "")~="",id.." ExteriorSpawnId required")
	nonEmptyUnique(definition.DisplaySpaceIds,id.." DisplaySpaceIds"); nonEmptyUnique(definition.SurfaceGroups,id.." SurfaceGroups"); nonEmptyUnique(definition.DecorationSlots,id.." DecorationSlots","SlotId"); nonEmptyUnique(definition.LightingSlotIds,id.." LightingSlotIds"); assert(type(definition.Capabilities)=="table" and type(definition.UI)=="table",id.." contracts required"); assert((tonumber(definition.VehicleCapacityContribution) or 0)>=#definition.DisplaySpaceIds,id.." capacity cannot be smaller than display spaces"); return true
end
function Catalog.ValidateAll() local seen={}; local starterCount=0; for _,definition in ipairs(properties) do validateDefinition(definition,seen); if definition.Starter then starterCount+=1 end end; assert(starterCount==1,"Exactly one starter owned-garage property is required"); return true,#properties end
function Catalog.List() local result=clone(properties); table.sort(result,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end return a.PropertyId<b.PropertyId end); return result end
function Catalog.ById(propertyId) for _,property in ipairs(properties) do if property.PropertyId==tostring(propertyId or "") then return clone(property) end end end
function Catalog.SpaceIds(propertyId) local property=Catalog.ById(propertyId); return property and clone(property.DisplaySpaceIds) or {} end
function Catalog.IsSpace(propertyId,slotId) for _,candidate in ipairs(Catalog.SpaceIds(propertyId)) do if candidate==tostring(slotId or "") then return true end end; return false end
function Catalog.AccessModes() return clone(accessModes) end
function Catalog.DecorationCategories() return clone(decorationSlots) end
function Catalog.Capabilities(propertyId) local property=Catalog.ById(propertyId); return property and clone(property.Capabilities) or {} end
function Catalog.ClientDefinition(propertyId) local property=Catalog.ById(propertyId); if not property then return nil end; return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,ExteriorSpawnId=property.ExteriorSpawnId,TemplateContractVersion=property.TemplateContractVersion,StateSchemaVersion=property.StateSchemaVersion,DisplaySpaceIds=clone(property.DisplaySpaceIds),StructureSections=clone(property.StructureSections),SurfaceGroups=clone(property.SurfaceGroups),DecorationSlots=clone(property.DecorationSlots),DecorationAnchorIds=clone(property.DecorationAnchorIds),LightingSlotIds=clone(property.LightingSlotIds),Capabilities=clone(property.Capabilities),UI=clone(property.UI)} end
Catalog.ValidateAll()
return Catalog
