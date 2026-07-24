-- NTR_OWNED_GARAGE_DECORATION_CATALOG_V1
-- NTR_OWNED_GARAGE_TYPED_DECORATION_CATALOG_V2
-- NTR_OWNED_GARAGE_SHARED_FINISH_DECORATION_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_DECORATION
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
local Catalog={Version=3,StarterLoadoutVersion=1,Channels={"Primary","Secondary","Detail","Neon"}}
local zones={{SlotId="WorkshopWall",DisplayName="WORKSHOP WALL",IconKey="Tools",SortOrder=10,Required=true,DefaultItemId="WORKSHOP_STREET",StarterItemId="WORKSHOP_STREET"},{SlotId="StorageWall",DisplayName="STORAGE WALL",IconKey="Box",SortOrder=20,Required=true,DefaultItemId="STORAGE_OPEN_RACK",StarterItemId="STORAGE_OPEN_RACK"},{SlotId="HangoutBay",DisplayName="HANGOUT BAY",IconKey="Chair",SortOrder=30},{SlotId="FeatureCorner",DisplayName="FEATURE CORNER",IconKey="Spark",SortOrder=40},{SlotId="IdentityWall",DisplayName="IDENTITY WALL",IconKey="Image",SortOrder=50},{SlotId="DisplayPlatforms",DisplayName="DISPLAY PLATFORMS",IconKey="Garage",SortOrder=60,StarterItemId="PLATFORM_OPTION_01",AnchorId="TemplateOrigin",AssetGroupId="DisplayPlatforms",HideSurfaceGroup="DisplayPads"}}
local items={
	{ItemId="WORKSHOP_STREET",ZoneId="WorkshopWall",AssetName="StreetWorkshop",DisplayName="Street Workshop",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={45,50,60},Secondary={120,35,45},Detail={210,215,225},Neon={255,60,210}}},
	{ItemId="WORKSHOP_PRECISION",ZoneId="WorkshopWall",AssetName="PrecisionLab",DisplayName="Precision Lab",Price=8000,SortOrder=20,DefaultColors={Primary={35,42,52},Secondary={215,220,225},Detail={90,120,150},Neon={40,220,255}}},
	{ItemId="WORKSHOP_COLLECTOR",ZoneId="WorkshopWall",AssetName="CollectorStudio",DisplayName="Collector Studio",Price=12000,SortOrder=30,DefaultColors={Primary={45,32,28},Secondary={105,70,45},Detail={190,150,85},Neon={255,165,75}}},
	{ItemId="STORAGE_OPEN_RACK",ZoneId="StorageWall",AssetName="OpenRack",DisplayName="Open Rack",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={65,70,80},Secondary={115,35,45},Detail={180,185,195},Neon={255,60,210}}},
	{ItemId="STORAGE_FLUSH",ZoneId="StorageWall",AssetName="FlushCabinets",DisplayName="Flush Cabinets",Price=6000,SortOrder=20,DefaultColors={Primary={28,34,44},Secondary={65,75,90},Detail={160,170,185},Neon={35,215,255}}},
	{ItemId="STORAGE_VAULT",ZoneId="StorageWall",AssetName="DisplayVault",DisplayName="Display Vault",Price=10000,SortOrder=30,DefaultColors={Primary={20,24,32},Secondary={55,65,80},Detail={205,210,220},Neon={180,70,255}}},
	{ItemId="HANGOUT_LOUNGE",ZoneId="HangoutBay",AssetName="NeoLounge",DisplayName="Neo Lounge",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={35,38,48},Secondary={95,45,80},Detail={180,185,200},Neon={255,70,205}}},
	{ItemId="HANGOUT_BILLIARDS",ZoneId="HangoutBay",AssetName="HoloBilliards",DisplayName="Holo Billiards",Price=7500,SortOrder=20,DefaultColors={Primary={28,35,44},Secondary={35,115,105},Detail={180,190,200},Neon={45,255,220}}},
	{ItemId="HANGOUT_SIMULATOR",ZoneId="HangoutBay",AssetName="RacingSimulator",DisplayName="Racing Simulator",Price=9500,SortOrder=30,DefaultColors={Primary={30,34,44},Secondary={115,35,55},Detail={185,190,200},Neon={255,65,150}}},
	{ItemId="FEATURE_AQUARIUM",ZoneId="FeatureCorner",AssetName="NeoAquarium",DisplayName="Neo Aquarium",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={28,36,48},Secondary={55,80,105},Detail={185,200,215},Neon={30,225,255}}},
	{ItemId="FEATURE_GARDEN",ZoneId="FeatureCorner",AssetName="HydroponicGarden",DisplayName="Hydroponic Garden",Price=6500,SortOrder=20,DefaultColors={Primary={35,45,42},Secondary={55,95,65},Detail={170,185,175},Neon={75,255,150}}},
	{ItemId="FEATURE_REACTOR",ZoneId="FeatureCorner",AssetName="ReactorSculpture",DisplayName="Reactor Sculpture",Price=9000,SortOrder=30,DefaultColors={Primary={30,34,45},Secondary={80,55,110},Detail={185,190,205},Neon={175,70,255}}},
	{ItemId="IDENTITY_BLUEPRINT",ZoneId="IdentityWall",AssetName="BlueprintWall",DisplayName="Blueprint Wall",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={30,38,50},Secondary={55,85,120},Detail={195,210,225},Neon={55,200,255}}},
	{ItemId="IDENTITY_TROPHY",ZoneId="IdentityWall",AssetName="TrophyWall",DisplayName="Trophy Wall",Price=5500,SortOrder=20,DefaultColors={Primary={35,35,42},Secondary={105,75,35},Detail={220,185,90},Neon={255,180,55}}},
	{ItemId="IDENTITY_CITY",ZoneId="IdentityWall",AssetName="CityArt",DisplayName="Neo Tokyo Art",Price=7000,SortOrder=30,DefaultColors={Primary={28,30,42},Secondary={80,40,100},Detail={195,180,215},Neon={255,55,220}}},
	{ItemId="PLATFORM_OPTION_01",ZoneId="DisplayPlatforms",AssetGroupId="DisplayPlatforms",AssetName="PlatformOption01",DisplayName="Platform Option 1",Price=0,SortOrder=10,DefaultOwned=true,DefaultColors={Primary={24,30,42},Secondary={48,58,74},Detail={190,200,215},Neon={30,230,255}}},
	{ItemId="PLATFORM_OPTION_02",ZoneId="DisplayPlatforms",AssetGroupId="DisplayPlatforms",AssetName="PlatformOption02",DisplayName="Platform Option 2",Price=6000,SortOrder=20,DefaultColors={Primary={32,28,44},Secondary={80,42,95},Detail={205,190,220},Neon={255,55,220}}},
	{ItemId="PLATFORM_OPTION_03",ZoneId="DisplayPlatforms",AssetGroupId="DisplayPlatforms",AssetName="PlatformOption03",DisplayName="Platform Option 3",Price=9000,SortOrder=30,DefaultColors={Primary={38,42,48},Secondary={105,75,38},Detail={225,205,160},Neon={255,180,55}}},
}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
function Catalog.EncodeColor(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(math.floor((tonumber(value[1] or value.R) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[2] or value.G) or 255)+.5),0,255),math.clamp(math.floor((tonumber(value[3] or value.B) or 255)+.5),0,255)} end; return {255,255,255} end
function Catalog.DecodeColor(value) local c=Catalog.EncodeColor(value); return Color3.fromRGB(c[1],c[2],c[3]) end
function Catalog.Zones() return clone(zones) end
function Catalog.Items(zoneId) local result={}; for _,item in ipairs(items) do if not zoneId or item.ZoneId==tostring(zoneId) then table.insert(result,clone(item)) end end; table.sort(result,function(a,b) return a.SortOrder==b.SortOrder and a.ItemId<b.ItemId or a.SortOrder<b.SortOrder end); return result end
function Catalog.ById(itemId) for _,item in ipairs(items) do if item.ItemId==tostring(itemId or "") then return clone(item) end end end
function Catalog.ZoneById(slotId,slotDefinitions) for _,zone in ipairs(slotDefinitions or zones) do if tostring(zone.SlotId or "")==tostring(slotId or "") then return clone(zone) end end end
function Catalog.IsSlot(slotId,slotDefinitions) return Catalog.ZoneById(slotId,slotDefinitions)~=nil end
local function defaultColors(item) local result={}; for _,channel in ipairs(Catalog.Channels) do result[channel]=Catalog.EncodeColor(item.DefaultColors and item.DefaultColors[channel]) end; return result end
function Catalog.Normalize(value,slotDefinitions)
	value=type(value)=="table" and value or {}; value.OwnedItems=type(value.OwnedItems)=="table" and value.OwnedItems or {}; value.Placements=type(value.Placements)=="table" and value.Placements or {}
	for _,item in ipairs(items) do if item.DefaultOwned then value.OwnedItems[item.ItemId]=true end end
	for slotId,raw in pairs(value.Placements) do
		local itemId=type(raw)=="table" and tostring(raw.ItemId or "") or tostring(raw or ""); local item=Catalog.ById(itemId)
		if not (Catalog.IsSlot(slotId,slotDefinitions) and item and item.ZoneId==slotId) then value.Placements[slotId]=nil else
			local placement=type(raw)=="table" and raw or {}; placement.ItemId=itemId; placement.Colors=type(placement.Colors)=="table" and placement.Colors or {}
			for channel,valueColor in pairs(placement.Colors) do if table.find(Catalog.Channels,channel) and valueColor~=nil then placement.Colors[channel]=Catalog.EncodeColor(valueColor) else placement.Colors[channel]=nil end end
			value.Placements[slotId]=placement
		end
	end
	if math.floor(tonumber(value.StarterLoadoutVersion) or 0)<Catalog.StarterLoadoutVersion then
		for _,zone in ipairs(slotDefinitions or zones) do local item=Catalog.ById(zone.StarterItemId); if item and item.ZoneId==zone.SlotId then value.OwnedItems[item.ItemId]=true; if not value.Placements[zone.SlotId] then value.Placements[zone.SlotId]={ItemId=item.ItemId,Colors={}} end end end
		value.StarterLoadoutVersion=Catalog.StarterLoadoutVersion
	end
	for _,zone in ipairs(slotDefinitions or zones) do if zone.Required and not value.Placements[zone.SlotId] then local item=Catalog.ById(zone.StarterItemId or zone.DefaultItemId); if item then value.OwnedItems[item.ItemId]=true; value.Placements[zone.SlotId]={ItemId=item.ItemId,Colors={}} end end end
	return value
end
function Catalog.Validate(value,slotDefinitions) value=Catalog.Normalize(value,slotDefinitions); for slotId,placement in pairs(value.Placements) do local item=Catalog.ById(placement.ItemId); if not (Catalog.IsSlot(slotId,slotDefinitions) and item and item.ZoneId==slotId and value.OwnedItems[item.ItemId]) then return false,"Invalid decoration placement." end end; return true end
function Catalog.NewPlacement(itemId) local item=Catalog.ById(itemId); return item and {ItemId=item.ItemId,Colors={}} or nil end
function Catalog.ClientState(value,slotDefinitions,capabilities)
	value=Catalog.Normalize(clone(value),slotDefinitions); capabilities=type(capabilities)=="table" and capabilities or {}; local byZone={}; local visibleZones={}
	for _,zone in ipairs(slotDefinitions or zones) do byZone[zone.SlotId]={}; for _,item in ipairs(Catalog.Items(zone.SlotId)) do local cap=capabilities[item.ItemId] or {}; if cap.Available==true then item.ColourChannels=clone(cap.ColourChannels or {}); table.insert(byZone[zone.SlotId],item) end end; if zone.Required or value.Placements[zone.SlotId] or #byZone[zone.SlotId]>0 then table.insert(visibleZones,clone(zone)) end end
	for _,placement in pairs(value.Placements) do local cap=capabilities[placement.ItemId] or {}; local effective={}; for _,channel in ipairs(cap.ColourChannels or {}) do local raw=placement.Colors[channel] or (cap.DefaultColors and cap.DefaultColors[channel]); if raw~=nil then effective[channel]=Catalog.DecodeColor(raw) end end; placement.Colors=effective; placement.ColourChannels=clone(cap.ColourChannels or {}) end
	return {Version=Catalog.Version,StarterLoadoutVersion=value.StarterLoadoutVersion,Zones=visibleZones,ItemsByZone=byZone,OwnedItems=clone(value.OwnedItems),Placements=clone(value.Placements),Channels=clone(Catalog.Channels)}
end

return Catalog
